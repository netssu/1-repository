local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UIHandling = require(ReplicatedStorage.Modules.Client.UIHandler)

ReplicatedStorage.Remotes.UI.Blackout.OnClientEvent:Connect(function()
	UIHandling.Transition(true)
end)

return {}