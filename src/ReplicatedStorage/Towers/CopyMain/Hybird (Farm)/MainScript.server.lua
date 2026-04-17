local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerFunctions = require(game.ServerScriptService.Main.TowerFunctions)
local upgradesModule = require(game.ReplicatedStorage.Upgrades)
local UnitName = upgradesModule[script.Parent.Name]
local TowerInfo = require(game.ReplicatedStorage.Modules.Helpers.TowerInfo)
local currentWave = workspace.Info.Wave.Value
local upgradeStats = UnitName["Upgrades"][script.Parent.Config.Upgrades.Value]

local function giveMoneyToOwner(tower)
	warn("Hybrid money giver")
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
		
		
		warn(moneyToGive)
		
		if moneyToGive then
			if tower.Config:FindFirstChild("Shiny").Value then moneyToGive *= 1.15 end

			player.Money.Value += moneyToGive 

		end
	end
end


local FarmHybridFunctions = {
	['Ground'] = function(upgradeStats)
		warn(upgradeStats.Damage)
		if upgradeStats.Damage <= 0 then return end
		warn(upgradeStats)
		warn("Attacking")
		
		
		if upgradeStats.Money then
			if not script.Parent:FindFirstChild("LastMoneyWave") then
				local waveVal = Instance.new("IntValue")
				waveVal.Name = "LastMoneyWave"
				waveVal.Value = 0
				waveVal.Parent = script.Parent
			end

			local wave = workspace.Info:FindFirstChild("Wave")
			local lastGivenWave = script.Parent:FindFirstChild("LastMoneyWave")
			if wave and lastGivenWave and wave.Value > lastGivenWave.Value then
				lastGivenWave.Value = wave.Value
				giveMoneyToOwner(script.Parent)
			end
		end

		local target = nil
		repeat
			task.wait(0.1)
			warn("Looking for target...")
			target = TowerFunctions.FindTarget(script.Parent)
		until target ~= nil

		if script.Parent.Animations:FindFirstChild(upgradeStats.AnimName) then
			warn("Animating")
			game.ReplicatedStorage.Events.AnimateTower:FireAllClients(script.Parent, upgradeStats.AnimName, target)
		end

		local newTargetPosition = Vector3.new(target.HumanoidRootPart.Position.X, script.Parent.TowerBasePart.Position.Y, target.HumanoidRootPart.Position.Z)
		local targetCFrame = CFrame.lookAt(script.Parent.TowerBasePart.Position, newTargetPosition)
		script.Parent.TowerBasePart.CFrame = targetCFrame

		game.ReplicatedStorage.Events.VFX_Remote:FireAllClients({UnitName.Name, upgradeStats.AttackName}, script.Parent.HumanoidRootPart, target)

		TowerFunctions.DamageFunction(script.Parent, target)

		local attackDuration = 0
		for i, v in upgradeStats.MultiDamageDelays do
			attackDuration += v
		end
		warn(TowerInfo.GetCooldown(script.Parent))
		task.wait(TowerInfo.GetCooldown(script.Parent))
	end,
}



task.spawn(function()
	while true do
		local upgradeLevel = script.Parent.Config.Upgrades.Value
		local upgradeStats = UnitName["Upgrades"][upgradeLevel]
		FarmHybridFunctions["Ground"](upgradeStats)
		task.wait(0.1)
	end
end)

task.spawn(function()
	local lastWave = workspace.Info.Wave.Value
	while true do
		workspace.Info.Wave.Changed:Wait()
		local currentWave = workspace.Info.Wave.Value
		if currentWave > lastWave then
			lastWave = currentWave
			giveMoneyToOwner(script.Parent)
		end
	end
end)
