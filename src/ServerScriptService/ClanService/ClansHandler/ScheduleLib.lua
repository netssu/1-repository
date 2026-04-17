local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ClansDataStore = DataStoreService:GetDataStore("Clans")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Warning = ReplicatedStorage.ServerWarningEvent

local module = {}

module.WriteQueue = {} -- table.insert()
module.WriteQueueData = {} -- dictionary
module.WriteQueueResponse = {} -- dictionary

module.ReadQueue = {}
module.ReadQueueData = {}
module.ReadQueueResponse = {}

local tpawn = task.spawn

local count = 0

function module.ScheduleWriteAsync(Key, Data)
	count += 1

	Warning:FireAllClients(`Num: {count}`)
	Warning:FireAllClients(`Key that we are writing into: {Key}`)
	
	local ticket = HttpService:GenerateGUID(false)
	local response = nil
	local Signal = Instance.new('BindableEvent')
	
	if not Data then
		task.spawn(function()
			local result = debug.traceback("", 2)
			error(`CRITICAL ERROR INVOLVED: {Key}, {Data}: {result}`)
		end)
	end
	
	module.WriteQueueData[ticket] = {
		Key = Key, 
		Data = Data, -- where Data = Transform Function 
		Signal = Signal
	}
	table.insert(module.WriteQueue, ticket)
	Signal.Event:Wait()
	
	Signal:Destroy()
	response = module.WriteQueueResponse[ticket]
	module.WriteQueueResponse[ticket] = nil
	
	return response
end

function module.ScheduleReadAsync(Key)
	local ticket = HttpService:GenerateGUID(false)
	local response = nil
	local Signal = Instance.new('BindableEvent')

	module.ReadQueueData[ticket] = {
		Key = Key, 
		Signal = Signal
	}
	table.insert(module.ReadQueue, ticket)
	Signal.Event:Wait()
	Signal:Destroy()
	response = module.ReadQueueResponse[ticket]
	module.ReadQueueResponse[ticket] = nil
	
	--[[
	response example:
	{
		Message = response
		ErrorCode = true
	}
	--]]

	return response
end

return module