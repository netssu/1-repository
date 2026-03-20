--[[
    GoatAnalytics SDK - Batch Queue
    Queues analytics events and flushes them to the API in batches.
    Groups events by userId+sessionId. Retries on failure with exponential backoff.
]]

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Parent.Shared.Config)

local BatchQueue = {}
BatchQueue.__index = BatchQueue

export type BatchQueueConfig = {
	appId: string,
	apiKey: string,
	endpoint: string?,
	batchSize: number?,
	flushInterval: number?,
	maxQueueSize: number?,
}

export type EnrichedEvent = {
	eventType: string,
	eventId: string,
	timestamp: number,
	properties: {[string]: any},
	userId: string,
	sessionId: string,
}

function BatchQueue.new(config: BatchQueueConfig)
	local self = setmetatable({}, BatchQueue)
	self._appId = config.appId
	self._apiKey = config.apiKey
	self._endpoint = config.endpoint or Config.DEFAULT.API_ENDPOINT
	self._batchSize = config.batchSize or Config.DEFAULT.BATCH_SIZE
	self._flushInterval = config.flushInterval or Config.DEFAULT.FLUSH_INTERVAL
	self._maxQueueSize = config.maxQueueSize or Config.DEFAULT.MAX_QUEUE_SIZE
	self._queue = {} :: {EnrichedEvent}
	self._flushing = false
	self._running = false
	return self
end

-- Start the periodic flush timer
function BatchQueue:start()
	if self._running then
		return
	end
	self._running = true

	task.spawn(function()
		while self._running do
			task.wait(self._flushInterval)
			if #self._queue > 0 and not self._flushing then
				self:flush()
			end
		end
	end)
end

-- Stop the periodic flush timer and flush remaining events
function BatchQueue:stop()
	self._running = false
	if #self._queue > 0 then
		self:flush()
	end
end

-- Add an enriched event to the queue
function BatchQueue:add(event: EnrichedEvent)
	-- Drop oldest events if queue is full
	if #self._queue >= self._maxQueueSize then
		table.remove(self._queue, 1)
		warn("[GoatAnalytics] Queue full — dropped oldest event")
	end

	table.insert(self._queue, event)

	-- Auto-flush if batch size reached
	if #self._queue >= self._batchSize and not self._flushing then
		task.spawn(function()
			self:flush()
		end)
	end
end

-- Group events by userId+sessionId for the API payload format
local function groupEvents(events: {EnrichedEvent}): {{userId: string, sessionId: string, events: {any}}}
	local groups: {[string]: {userId: string, sessionId: string, events: {any}}} = {}
	local order: {string} = {}

	for _, event in events do
		local key = event.userId .. ":" .. event.sessionId
		if not groups[key] then
			groups[key] = {
				userId = event.userId,
				sessionId = event.sessionId,
				events = {},
			}
			table.insert(order, key)
		end

		-- Ensure properties is never an empty array (Roblox JSONEncode encodes {} as [])
		local props = event.properties
		if props == nil or (type(props) == "table" and next(props) == nil) then
			props = nil  -- omit empty properties entirely (optional field)
		end

		table.insert(groups[key].events, {
			eventType = event.eventType,
			eventId = event.eventId,
			timestamp = event.timestamp,
			properties = props,
		})
	end

	local result = {}
	for _, key in order do
		table.insert(result, groups[key])
	end
	return result
end

-- Send a batch to the API with retry logic
function BatchQueue:_sendBatch(grouped: {userId: string, sessionId: string, events: {any}})
	local MAX_RETRIES = 3
	local BASE_DELAY = 2

	for attempt = 1, MAX_RETRIES do
		local payload = HttpService:JSONEncode({
			appId = self._appId,
			userId = grouped.userId,
			sessionId = grouped.sessionId,
			timestamp = os.time() * 1000,
			events = grouped.events,
			sdkVersion = Config.DEFAULT.SDK_VERSION,
			clientVersion = Config.DEFAULT.SDK_VERSION,
		})

		local success, response = pcall(function()
			return HttpService:RequestAsync({
				Url = self._endpoint,
				Method = "POST",
				Headers = {
					["Authorization"] = "Bearer " .. self._apiKey,
					["Content-Type"] = "application/json",
				},
				Body = payload,
			})
		end)

		if success and response.Success then
			return -- Sent successfully
		end

		local statusCode = if success then response.StatusCode else "network error"
		local body = if success then response.Body else tostring(response)

		if attempt < MAX_RETRIES then
			local delay = BASE_DELAY * (2 ^ (attempt - 1))
			warn(`[GoatAnalytics] ERROR IN BATCH QUEUE: {body}`)
			warn(`[GoatAnalytics] Batch send failed (attempt {attempt}/{MAX_RETRIES}, status: {statusCode}): {body}. Retrying in {delay}s...`)
			task.wait(delay)
		else
			warn(`[GoatAnalytics] Batch send failed after {MAX_RETRIES} attempts (status: {statusCode}): {body}. Events dropped.`)
		end
	end
end

-- Flush all queued events to the API
function BatchQueue:flush()
	if self._flushing or #self._queue == 0 then
		return
	end

	self._flushing = true

	-- Take all events from the queue
	local events = self._queue
	self._queue = {}

	-- Group by user+session and send each group
	local groups = groupEvents(events)
	for _, group in groups do
		self:_sendBatch(group)
	end

	self._flushing = false
end

return BatchQueue
