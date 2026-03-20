--[[
    GoatAnalytics SDK - Client Analytics
    Client-side event tracking. Sends events to the server via RemoteEvent.
    The client NEVER has access to the API key or makes HTTP requests.

    Usage (from a LocalScript):
        local Analytics = require(path.to.GoatAnalytics)
        Analytics:trackInteraction("button_click", "shop_button")
        Analytics:trackProgression("complete", "level_3", 1500)
        Analytics:track("custom_event", { eventName = "tutorial_step", step = 3 })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Shared.Types)

local ClientAnalytics = {}
ClientAnalytics.__index = ClientAnalytics

-- Rate limiting: max 10 events/second
local RATE_LIMIT = 10
local RATE_WINDOW = 1 -- second

local remoteEvent: RemoteEvent? = nil
local eventTimestamps: {number} = {}
local initialized = false

-- Wait for the server to create the RemoteEvent
local function getRemoteEvent(): RemoteEvent?
	if remoteEvent then
		return remoteEvent
	end

	remoteEvent = ReplicatedStorage:WaitForChild("GoatAnalyticsEvent", 10) :: RemoteEvent?
	if not remoteEvent then
		warn("[GoatAnalytics] RemoteEvent not found — is the server SDK initialized?")
	end

	return remoteEvent
end

-- Check if we're within rate limits
local function checkRateLimit(): boolean
	local now = tick()
	-- Remove timestamps outside the window
	while #eventTimestamps > 0 and eventTimestamps[1] < now - RATE_WINDOW do
		table.remove(eventTimestamps, 1)
	end

	if #eventTimestamps >= RATE_LIMIT then
		return false
	end

	table.insert(eventTimestamps, now)
	return true
end

-- Send an event to the server
local function sendEvent(eventType: string, properties: {[string]: any}?)
	if not checkRateLimit() then
		warn("[GoatAnalytics] Client rate limit exceeded — event dropped")
		return
	end

	local remote = getRemoteEvent()
	if not remote then
		return
	end

	remote:FireServer({
		eventType = eventType,
		properties = properties or {},
		clientTimestamp = tick(),
	})
end

--[[
    Track a generic event.
    @param eventType — One of Types.EventType values
    @param properties — Event-specific properties (see EventSchema for required fields)
]]
function ClientAnalytics:track(eventType: string, properties: {[string]: any}?)
	if not Types._validEventTypes[eventType] then
		warn(`[GoatAnalytics] Invalid event type: {eventType}`)
		return
	end
	sendEvent(eventType, properties)
end

--[[
    Track a UI interaction event.
    @param action — What the user did (e.g. "button_click", "menu_open")
    @param target — What they interacted with (optional)
    @param value — Numeric value associated with the interaction (optional)
]]
function ClientAnalytics:trackInteraction(action: string, target: string?, value: number?)
	sendEvent(Types.EventType.INTERACTION, {
		action = action,
		target = target,
		value = value,
	})
end

--[[
    Track a progression event.
    @param status — "start", "complete", or "fail"
    @param level — Level/stage identifier (e.g. "world_1_level_3")
    @param score — Optional score achieved
]]
function ClientAnalytics:trackProgression(status: string, level: string, score: number?)
	sendEvent(Types.EventType.PROGRESSION, {
		status = status,
		level = level,
		score = score,
	})
end

--[[
    Track a custom event.
    @param eventName — Name of the custom event
    @param properties — Additional properties (optional)
]]
function ClientAnalytics:trackCustom(eventName: string, properties: {[string]: any}?)
	local props = properties or {}
	props.eventName = eventName
	sendEvent(Types.EventType.CUSTOM, props)
end

-- Initialize client-side tracking (called automatically on require)
function ClientAnalytics:_init()
	if initialized then
		return
	end
	initialized = true
	getRemoteEvent()
end

ClientAnalytics:_init()

return ClientAnalytics
