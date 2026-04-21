local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EquipAura = ReplicatedStorage.Remotes.EquipAura
local AuraHandling = require(ServerScriptService.ProfileServiceMain.Main.AuraHandling)

EquipAura.OnServerEvent:Connect(function(plr, aura)
	if aura then
		AuraHandling.equipAura(plr, aura)
	end
end)

return {}