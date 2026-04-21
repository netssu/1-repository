local DataStoreService = game:GetService("DataStoreService")
local ClansDataStore = DataStoreService:GetDataStore("Clans")
local ScheduleLib = require(script.Parent)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Warning = ReplicatedStorage.ServerWarningEvent
local THROTTLE = 0.9

local attempts = 5
local PcallThrottle = 1

local tpawn = task.spawn

local function attemptCall(fn)
	local attempted = 0
	local success = false
	local s, result = nil, nil

	repeat 
		s, result = pcall(fn)

		if s then
			success = true
		else
			attempted += 1

			Warning:FireAllClients("Datastore operation failed:", result)
		end
		task.wait(PcallThrottle)
	until attempted == attempts or success

	return success, result
end

while true do
	local s,e = pcall(function()
		if ScheduleLib.WriteQueue[1] and ScheduleLib.WriteQueueData[ScheduleLib.WriteQueue[1]] then
			local ticket = ScheduleLib.WriteQueue[1]
			local data = ScheduleLib.WriteQueueData[ticket]
			local key = data.Key

			local count = 0

			for i,v in ScheduleLib.WriteQueue do
				if ScheduleLib.WriteQueueData[v] and ScheduleLib.WriteQueueData[v].Key == data.Key then
					count += 1
				end
			end

			if count ~= 1 and false then -- temporarily disabling merge function to see if it fixes gems
				local processFunctions = {}
				local signals = {}
				local i = 1
				local ticketsProcessed = {}

				while i <= #ScheduleLib.WriteQueue do
					local queueId = ScheduleLib.WriteQueue[i]
					if queueId == nil then break end

					local entry = ScheduleLib.WriteQueueData[queueId]
					if entry and entry.Key == key then
						table.insert(signals, entry.Signal)
						table.insert(processFunctions, entry.Data)
						table.insert(ticketsProcessed, queueId)
						table.remove(ScheduleLib.WriteQueue, i)
					else
						i += 1
					end
				end

				local mergedFunction = function(source)
					for _, fn in ipairs(processFunctions) do
						source = fn(source)
					end
					return source
				end

				local capturedResult = nil

				local func = function()
					ClansDataStore:UpdateAsync(key, function(source)
						source = mergedFunction(source)
						capturedResult = source
						return source
					end)
					return capturedResult
				end

				local success, result = attemptCall(func)


				Warning:FireAllClients(result)
				Warning:FireAllClients(`UpdateAsync result: {success}`)

				if typeof(result) ~= 'table' then -- this is just to fix any write issues - POSSIBLY the issue with clan gems :(
					success.Success = false
					success.Message = nil
				end

				for _, ticketId in ipairs(ticketsProcessed) do
					ScheduleLib.WriteQueueResponse[ticketId] = {
						Success = success,
						Message = result
					}
					ScheduleLib.WriteQueueData[ticketId] = nil
				end

				for _, signal in ipairs(signals) do
					signal:Fire()
				end
			else
				local capturedResult = nil

				local func = function()
					ClansDataStore:UpdateAsync(data.Key, function(source)
						source = data.Data(source)
						capturedResult = source
						return source
					end)
					return capturedResult
				end

				local success, result = attemptCall(func)


				Warning:FireAllClients(result)
				Warning:FireAllClients(`UpdateAsync result: {success}`)

				ScheduleLib.WriteQueueResponse[ticket] = {
					Success = success,
					Message = result
				}

				ScheduleLib.WriteQueueData[ticket] = nil
				data.Signal:Fire()
				table.remove(ScheduleLib.WriteQueue, 1)
			end
		end
	end)

	if not s then
		Warning:FireAllClients(e)
	end

	local s,e = pcall(function()
		if ScheduleLib.ReadQueue[1] then
			local ticket = ScheduleLib.ReadQueue[1]
			local data = ScheduleLib.ReadQueueData[ticket]

			local func = function()
				return ClansDataStore:GetAsync(data.Key)
			end

			local success, result = attemptCall(func)

			local responseData = {
				Message = result,
				Success = success
			}

			ScheduleLib.ReadQueueResponse[ticket] = responseData
			ScheduleLib.ReadQueueData[ticket] = nil

			data.Signal:Fire()

			table.remove(ScheduleLib.ReadQueue, 1)
		end
	end)

	if not s then
		Warning:FireAllClients(e)
	end

	task.wait(THROTTLE)
end