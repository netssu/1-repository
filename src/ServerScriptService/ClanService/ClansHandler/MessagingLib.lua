local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")

local module = {}

local messageQueue = {}
local isProcessing = false
local RATE_LIMIT = 150 / 60 -- 2.5 messages per second
local MIN_INTERVAL = 1 / RATE_LIMIT

local function processQueue()
	if isProcessing then return end
	isProcessing = true

	while #messageQueue > 0 do
		local item = table.remove(messageQueue, 1)
		local success, err = pcall(function()
			MessagingService:PublishAsync(item.channel, item.data)
		end)

		if not success then
			task.spawn(function()
				error("[MessagingService] Failed to publish:" .. err)
			end)
			
			task.spawn(function()
				warn(debug.traceback("Require called from:", 2))
			end)
		end

		task.wait(MIN_INTERVAL)
	end

	isProcessing = false
end

function module.PublishMessageAsync(channel, data)
	table.insert(messageQueue, {
		channel = channel,
		data = data
	})
	task.spawn(processQueue)
	return true
end

return module
