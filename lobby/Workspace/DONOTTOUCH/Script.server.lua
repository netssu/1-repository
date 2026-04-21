local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Zone = require(ReplicatedStorage.Modules.Zone)
local zone = Zone.new(script.Parent)


local AuraHandling = require(ServerScriptService.ProfileServiceMain.Main.AuraHandling)


if game.PlaceId ~= 117137931466956 then
	script.Parent:Destroy()
else
	zone.playerEntered:Connect(function(plr)
		plr.Gems.Value += 50000
		plr.TraitPoint.Value += 400
		local Player = plr
		
		Player.PlayerLevel.Value = 3000
		Player.OwnGamePasses['Premium Season Pass'].Value = true
		Player.EpisodePass.Premium.Value = true
		Player.LuckySpins.Value += 5
		Player.RaidLimitData.Attempts.Value = 10
		
		for i,v: Folder in Player.WorldStats:GetChildren() do	
			if v:IsA('Folder') then
				for _, act in v.LevelStats:GetChildren() do
					act.Clears.Value += 1
					act.FastestTime.Value = 500
				end
			end
		end
		
		Player.StoryProgress.World.Value = 100
		Player.StoryProgress.Level.Value = 5
		
		
		
		for i,v in plr.Items:GetChildren() do
			v.Value = 2000
		end
		
		for i,v in plr.OwnGamePasses:GetChildren() do
			v.Value = true
		end
		
		plr.OwnedTowers:ClearAllChildren()
		

		for i, folder in ReplicatedStorage.Towers:GetChildren() do
			if folder:IsA('Folder') then
				for _, unit in folder:GetChildren() do
					task.wait(.05)
					_G.createTower(plr.OwnedTowers, unit.Name)
				end
			end
		end
		
		for i,v in ReplicatedStorage.Auras:GetChildren() do
			AuraHandling.giveAura(plr, v.Name)
		end
	end)
end