-- // Services

local Players = game:GetService("Players")

-- // Paths

local Info = workspace.Info
local Raid = Info.Raid
local GameOver = Info.GameOver
local Victory = Info.Victory

-- // Functions

Players.PlayerAdded:Connect(function(player: Player)
	repeat task.wait() until player:FindFirstChild("BattlepassData") and game.Workspace.Info.GameRunning.Value

	local Tasks = player.BattlepassData.Tasks
	Victory.Changed:Connect(function()
		if GameOver.Value == true and Victory.Value == true and Raid.Value == true then
			for _, item in pairs(Tasks:GetChildren()) do
				if item.Name == "extreme3" or item.Name == "medium3" or item.Name == "dani4" then
					item.Value += 1
				end
			end
		end
	end)
	
	GameOver.Changed:Connect(function()
		for _, item in pairs(Tasks:GetChildren()) do
			if item.Name == "extreme1" or item.Name == "medium1" or item.Name == "dani1" then
				item.Value += player.Kills.Value
			if item.Name == "extreme5" or item.Name == "medium5" or item.Name == "dani5" and workspace.Info.Wave.Value >= 1 then
				item.Value += workspace.Info.Wave.Value
			end
			
				if item.Name == "extreme6" or item.Name == "medium6" or item.Name == "dani6" and workspace.Info.Wave.Value >= 1 and game.Workspace.Info.Infinity.Value == true then
					item.Value += workspace.Info.Wave.Value
				end
			end
		end
	end)
	
	game.ReplicatedStorage.Events.Client.BossDead.OnServerEvent:Connect(function(player1)
		local Tasks2 = player1.BattlepassData.Tasks
		
		for _, item in pairs(Tasks2:GetChildren()) do
			if item.Name == "extreme4" or item.Name == "medium4" or item.Name == "dani2" then
				item.Value += 1
			end
		end
	end)
end)