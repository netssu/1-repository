--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillAssetPreloader: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillAssetPreloader)
local SkillReplicator: any = require(ReplicatedStorage.Modules.Game.Skills.VFX)
local ClientSkillVFX: any = require(ReplicatedStorage.Modules.Game.Skills.VFX.Client.Init)

local SkillVFXController: {[string]: any} = {}
local LocalPlayer: Player = Players.LocalPlayer

function SkillVFXController.Start(_self: typeof(SkillVFXController)): ()
	task.spawn(function()
		SkillAssetPreloader.PreloadForCharacter(LocalPlayer.Character)
	end)

	SkillReplicator.Init()
	ClientSkillVFX.Init()

	LocalPlayer.CharacterAdded:Connect(function(Character: Model)
		task.spawn(function()
			SkillAssetPreloader.PreloadForCharacter(Character)
		end)
		SkillReplicator.Cleanup()
		ClientSkillVFX.Cleanup()
	end)

	LocalPlayer.CharacterRemoving:Connect(function()
		SkillReplicator.Cleanup()
		ClientSkillVFX.Cleanup()
	end)
end

return SkillVFXController

