local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local Upgarades = require(ReplicatedStorage.Upgrades)
local PlayerGUI = game:GetService("Players").LocalPlayer.PlayerGui

ReplicatedStorage.Remotes.DisplayUnit.OnClientEvent:Connect(function(modelName)
	workspace.Info.DisplayingUnit.Value = true
	
	
	
	
	local model = nil
	for i,v in ReplicatedStorage.Towers:GetDescendants()  do
		if v:IsA("Model") and v.Name == modelName then
			model = v
			warn(model)
		end
	end
	
	ViewModule.Hatch({
		Upgarades[modelName],
		model,
		nil,
		true
	})
	
	
	
	-- 1406
end)