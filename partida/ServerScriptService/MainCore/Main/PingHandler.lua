local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GetPing = ReplicatedStorage.Functions.GetPing

GetPing.OnServerInvoke = function()
	return true
end

return {}