local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PrestigeZone = ReplicatedStorage.Remotes.Prestige.Prestige
local Zone = require(ReplicatedStorage.Modules.Zone)
local container = script.Parent
local zone = Zone.new(container)


zone.playerEntered:Connect(function(plr)
	if plr.Character:FindFirstChild('Humanoid') and plr ~= nil then	
		PrestigeZone:FireClient(plr, true)
	end
end)


zone.playerExited:Connect(function(plr)
	if plr.Character and plr.Character:FindFirstChild('Humanoid') and plr ~= nil then 
		PrestigeZone:FireClient(plr, false)
	end
end)