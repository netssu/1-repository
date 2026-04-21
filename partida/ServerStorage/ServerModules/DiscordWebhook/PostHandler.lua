local postHandler = {}
postHandler.__index = postHandler
postHandler.__newindex = function() error('Cannot add new index') end
postHandler.__metatable = 'Meta table locked'

local DISCROD_URL = 'https://discordapp.com/api/webhooks/'
local HTTP_SERV = game:GetService('HttpService')
local DEF_WAIT = 0.1
local DEBUG = false

local function sendPost(msg, webhookId, webHookToken, incWait)
	
	if DEBUG then
		print(msg)
	end
	
	return pcall(HTTP_SERV.RequestAsync, HTTP_SERV, {
		Url = DISCROD_URL .. webhookId .. '/' .. webHookToken .. (incWait and '?wait=true' or ''),
		Method  = 'POST',
		Headers = {
			['Content-Type'] = 'application/json'
		},
		Body = tostring(msg)
	})
end

local function defFailedCallback(res, msg)
	warn('Discord webhook failed ' .. (res.StatusCode and  ' with http ' .. res.StatusCode or ''))
	warn(tostring(msg))
	warn(res.Body)
	return true	
end

local function processHeader(limits, header)
	-- process api limits passed back in the head
	limits.availableRequests = tonumber(header['x-ratelimit-remaining'])
	limits.requestLimit = tonumber(header['x-ratelimit-limit'])
	limits.waitTime = header['retry-after'] and tonumber(header['retry-after']) / 100 or DEF_WAIT
end

function postHandler:QueueMessage(msg)
	if #self.queue > self.maxQueueSize then
		warn('Max queue size exceeded')
		return
	end
	
	self.queue[#self.queue+1] = msg
	
	if not self.running and self.enabled then
		self:Resume()
	end
end

function postHandler:Resume()
	local threadStatus = coroutine.status(self.thread)
	if threadStatus == 'suspended' then
		self.running = true
		coroutine.resume(self.thread)
	else
		warn('Cannot resume queue processing thead expected suspended but got ' .. threadStatus)
	end
end

function postHandler:Pause()
	self.running = false
end

function postHandler:SuccessCallback(func)
	assert(typeof(func) == 'function', 'Argument 1 expected function but got ' .. typeof(func))
	
	self.successCallback = func
end

function postHandler:FailedCallback(func)
	assert(typeof(func) == 'function', 'Argument 1 expected function but got ' .. typeof(func))
	
	self.failedCallback = func
end

function postHandler.new(webhookId, webHookToken)
	
	local data = {
		queue = {},
		maxQueueSize = 200,
		resultWait = false,
		webhookId = webhookId,
		webHookToken = webHookToken,
		enabled = true,
		running = false,
		failedCallback = defFailedCallback,
		successCallback = function() end,
		limits = {
			waitTime = 0,
			requestLimit = 0,
			availableRequests = 0
		}
	}
	
	data.thread = coroutine.create(function()
		while data.enabled do
			if #data.queue > 0 and data.running then
				
				local msg = data.queue[1]
				local suc, res = sendPost(msg, data.webhookId, data.webHookToken, data.resultWait)
				
				if suc and res.StatusCode == 200 or res.StatusCode == 204 then
					table.remove(data.queue, 1)
					processHeader(data.limits, res.Headers)
					pcall(data.successCallback, res, msg)
					if DEBUG then
						print('success')
					end
				elseif suc and res.StatusCode == 429 then
					processHeader(data.limits, res.Headers)
					if DEBUG then
						print('wait', data.limits.waitTime)
					end
				else
					local suc2, remove = pcall(data.failedCallback, res, msg)
					if suc2 and remove then
						table.remove(data.queue, 1)
					end
				end
				
				wait(data.limits.waitTime)			
			else
				data.running = false
				coroutine.yield()
			end
		end
	end)
	
	return setmetatable(data, postHandler)
end

return postHandler