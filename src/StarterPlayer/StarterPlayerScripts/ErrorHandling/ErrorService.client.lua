local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerErrorEvent = ReplicatedStorage.ServerErrorEvent
local WarningEvent = ReplicatedStorage.ServerWarningEvent

ServerErrorEvent.OnClientEvent:Connect(function(errMsg)
    error(errMsg)
end)

WarningEvent.OnClientEvent:Connect(function(errMsg)
	warn(errMsg)
end)