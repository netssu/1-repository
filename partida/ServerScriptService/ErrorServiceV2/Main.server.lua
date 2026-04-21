local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local errorEvent = ReplicatedStorage:WaitForChild("ServerErrorEvent")

local blacklist = {
	"The experience doesn't have",
	'💥 Caught Server Error: 💥',
	'Failed to load sound',
	'Animation failed'
}

LogService.MessageOut:Connect(function(result, messageType)
	local foundanyBlacklist = false
	
	for i,v in blacklist do
		if string.find(result, v) then
			foundanyBlacklist = true
		end
	end
	
	if messageType == Enum.MessageType.MessageError and not foundanyBlacklist and not RunService:IsStudio() then
		local errorResult = '💥 Caught Server Error: 💥' .. result
		errorEvent:FireAllClients(errorResult)
	end
end)