local TowerFunctions = require(game.ServerScriptService.Main.TowerFunctions)
local upgradesModule = require(game.ReplicatedStorage.Upgrades)
local UnitName = upgradesModule[script.Parent.Name]

local function giveMoneyToOwner(tower)
	local ownerName = tower.Config.Owner.Value
	local player = game.Players:FindFirstChild(ownerName)
	if player then
		local currentTowerUpgrade = tower.Config.Upgrades.Value
		
		local upgradeStats = UnitName["Upgrades"][script.Parent.Config.Upgrades.Value]
		local moneyToGive
		if currentTowerUpgrade <= #upgradeStats then
			moneyToGive = upgradeStats[currentTowerUpgrade].Money
		else
			moneyToGive = upgradeStats.Money
		end

		if moneyToGive then
			if tower.Config:FindFirstChild("Shiny").Value then moneyToGive *= 1.15 end
			
			player.Money.Value += moneyToGive 
			
		end
	end
end

local currentWave = workspace.Info.Wave.Value

while true do
	workspace.Info.Wave.Changed:Wait()
	if workspace.Info.Wave.Value > currentWave then
		currentWave = workspace.Info.Wave.Value
		giveMoneyToOwner(script.Parent)
		game.ReplicatedStorage.Events.VFX_Remote:FireAllClients({UnitName.Name,UnitName["Upgrades"][script.Parent.Config.Upgrades.Value].AttackName},script.Parent.HumanoidRootPart)
		game.ReplicatedStorage.Events.AnimateTower:FireAllClients(script.Parent, "Attack", script.Parent)
	end
	task.wait(0.1)
end
