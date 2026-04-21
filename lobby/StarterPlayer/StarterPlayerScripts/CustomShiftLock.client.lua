local ReplicatedStorage = game:GetService('ReplicatedStorage')
local mod = require(script:WaitForChild("SmoothShiftLock"));

--mod:Disable()

local elevatorEvent = ReplicatedStorage.Events:WaitForChild("Elevator")
local RaidElevatorEvent = ReplicatedStorage.Events.RaidElevator
local leavingEvent = ReplicatedStorage.Remotes.Elevator.LeavingElevator

RaidElevatorEvent.OnClientEvent:Connect(function()
	mod:Disable()
	mod:ToggleShiftLock(false)
end)

elevatorEvent.OnClientEvent:Connect(function()
	mod:Disable()
	mod:ToggleShiftLock(false)
end)

leavingEvent.OnClientEvent:Connect(function()
	mod:Enable()
end)