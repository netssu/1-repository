local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService('ServerStorage')
local ErrorModule = require(ServerStorage.ServerModules.ErrorService)
local Upgrades = require(ReplicatedStorage.Upgrades)

local TowerSpecialisation = require(ServerStorage.ServerModules.TowerSpecialisation)

local TowerFunctions = require(game.ServerScriptService.Main.TowerFunctions)
local upgradesModule = require(game.ReplicatedStorage.Upgrades)
local UnitName = upgradesModule[script.Parent.Name]
local TowerGUI = ReplicatedStorage["TOWER BUFF GUI"]
local TowerInfo = require(game.ReplicatedStorage.Modules.Helpers.TowerInfo)


local function mag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

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

local Duplicates = {}
local EchoCounter = 0
local SupportFunctions = {
	["Echo"] = function(Model : Model, upgradestats)
		EchoCounter += 1

		local config = Model:FindFirstChild("Config")
		if not config:FindFirstChild("TowerNumber") then
			local towerNum = Instance.new("IntValue")
			towerNum.Name = "TowerNumber"
			towerNum.Value = EchoCounter
			towerNum.Parent = config
		end

		for _, v in ipairs(Model:FindFirstChild("Head"):GetChildren()) do
			if v:IsA("BillboardGui") then
				v:Destroy()
			end
		end

		local num = config:FindFirstChild("Upgrades")

		local NewGUI = TowerGUI:Clone()
		NewGUI.Parent = Model:FindFirstChild("Head")
		NewGUI.Frame.Buffing.Text = "Type Buff: DMG"
		NewGUI.Frame.Percent.Text = tostring(Upgrades["Echo"].Upgrades[num.Value].Damage) .. "%"

		num.Changed:Connect(function()
			NewGUI.Frame.Percent.Text = tostring(Upgrades["Echo"].Upgrades[num.Value].Damage) .. "%" 
		end)
	end,


	["Tech"] = function(Model : Model, upgradestats)
		EchoCounter += 1

		local config = Model:FindFirstChild("Config")
		if not config:FindFirstChild("TowerNumber") then
			local towerNum = Instance.new("IntValue")
			towerNum.Name = "TowerNumber"
			towerNum.Value = EchoCounter
			towerNum.Parent = config
		end

		for _, v in ipairs(Model:FindFirstChild("Head"):GetChildren()) do
			if v:IsA("BillboardGui") then
				v:Destroy()
			end
		end

		local num = config:FindFirstChild("Upgrades")

		local NewGUI = TowerGUI:Clone()
		NewGUI.Parent = Model:FindFirstChild("Head")
		NewGUI.Frame.Buffing.Text = "Type Buff: Cooldown"
		NewGUI.Frame.Percent.Text =  tostring(Upgrades["Tech"].Upgrades[num.Value].Damage) .. "%"

		num.Changed:Connect(function()
			NewGUI.Frame.Percent.Text =  tostring(Upgrades["Tech"].Upgrades[num.Value].Damage) .. "%"
		end)
	end,


	["Mas Med"] = function(Model : Model, upgradestats)
		EchoCounter += 1

		local config = Model:FindFirstChild("Config")
		if not config:FindFirstChild("TowerNumber") then
			local towerNum = Instance.new("IntValue")
			towerNum.Name = "TowerNumber"
			towerNum.Value = EchoCounter
			towerNum.Parent = config
		end

		for _, v in ipairs(Model:FindFirstChild("Head"):GetChildren()) do
			if v:IsA("BillboardGui") then
				v:Destroy()
			end
		end

		local num = config:FindFirstChild("Upgrades")

		local NewGUI = TowerGUI:Clone()
		NewGUI.Parent = Model:FindFirstChild("Head")
		NewGUI.Frame.Buffing.Text = "Type Buff: DMG"
		NewGUI.Frame.Percent.Text =  tostring(Upgrades["Mas Med"].Upgrades[num.Value].Damage) .. "%" 

		num.Changed:Connect(function()
			NewGUI.Frame.Percent.Text =  tostring(Upgrades["Mas Med"].Upgrades[num.Value].Damage) .. "%" 
		end)
	end,
	
	["Captain"] = function(Model : Model, upgradestats)
		EchoCounter += 1

		local config = Model:FindFirstChild("Config")
		if not config:FindFirstChild("TowerNumber") then
			local towerNum = Instance.new("IntValue")
			towerNum.Name = "TowerNumber"
			towerNum.Value = EchoCounter
			towerNum.Parent = config
		end

		for _, v in ipairs(Model:FindFirstChild("Head"):GetChildren()) do
			if v:IsA("BillboardGui") then
				v:Destroy()
			end
		end

		local num = config:FindFirstChild("Upgrades")

		local NewGUI = TowerGUI:Clone()
		NewGUI.Parent = Model:FindFirstChild("Head")
		NewGUI.Frame.Buffing.Text = "Type Buff: DMG"
		NewGUI.Frame.Percent.Text = tostring(Upgrades["Captain"].Upgrades[num.Value].Damage) .. "%"

		num.Changed:Connect(function()
			print(NewGUI, NewGUI.Parent)
			NewGUI:FindFirstChild("Frame").Percent.Text = tostring(Upgrades["Captain"].Upgrades[num.Value].Damage) .. "%" 
		end)
	end,
	
	["Colonel"] = function(Model : Model, upgradestats)
		EchoCounter += 1

		local config = Model:FindFirstChild("Config")
		if not config:FindFirstChild("TowerNumber") then
			local towerNum = Instance.new("IntValue")
			towerNum.Name = "TowerNumber"
			towerNum.Value = EchoCounter
			towerNum.Parent = config
		end

		for _, v in ipairs(Model:FindFirstChild("Head"):GetChildren()) do
			if v:IsA("BillboardGui") then
				v:Destroy()
			end
		end

		local num = config:FindFirstChild("Upgrades")

		local NewGUI = TowerGUI:Clone()
		NewGUI.Parent = Model:FindFirstChild("Head")
		NewGUI.Frame.Buffing.Text = "Type Buff: Range"
		NewGUI.Frame.Percent.Text = tostring(Upgrades["Colonel"].Upgrades[num.Value].Damage) .. "%"

		num.Changed:Connect(function()
			print(NewGUI, NewGUI.Parent)
			NewGUI:FindFirstChild("Frame").Percent.Text = tostring(Upgrades["Colonel"].Upgrades[num.Value].Damage) .. "%" 
		end)
	end,

	["Grand Moth Tarin"] = function(Model : Model, upgradestats)
		EchoCounter += 1

		local config = Model:FindFirstChild("Config")
		if not config:FindFirstChild("TowerNumber") then
			local towerNum = Instance.new("IntValue")
			towerNum.Name = "TowerNumber"
			towerNum.Value = EchoCounter
			towerNum.Parent = config
		end

		for _, v in ipairs(Model:FindFirstChild("Head"):GetChildren()) do
			if v:IsA("BillboardGui") then
				v:Destroy()
			end
		end

		local num = config:FindFirstChild("Upgrades")

		local NewGUI = TowerGUI:Clone()
		NewGUI.Parent = Model:FindFirstChild("Head")
		NewGUI.Frame.Buffing.Text = "Type Buff: DMG"
		NewGUI.Frame.Percent.Text = tostring(Upgrades["Grand Moth Tarin"].Upgrades[num.Value].Damage) .. "%"

		num.Changed:Connect(function()
			print(NewGUI, NewGUI.Parent)
			NewGUI:FindFirstChild("Frame").Percent.Text = tostring(Upgrades["Grand Moth Tarin"].Upgrades[num.Value].Damage) .. "%" 
		end)
	end,
}

local functions = {
	['Ground'] = function(upgradeStats)
		if upgradeStats.Damage <= 0 then return end

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
			target = TowerFunctions.FindTarget(script.Parent)
		until target ~= nil

		if script.Parent.Animations:FindFirstChild(upgradeStats.AnimName) then
			game.ReplicatedStorage.Events.AnimateTower:FireAllClients(script.Parent, upgradeStats.AnimName, target)
		end

		local newTargetPosition = Vector3.new(target.HumanoidRootPart.Position.X, script.Parent.TowerBasePart.Position.Y, target.HumanoidRootPart.Position.Z)
		local targetCFrame = CFrame.lookAt(script.Parent.TowerBasePart.Position, newTargetPosition)
		script.Parent:PivotTo(targetCFrame)

		game.ReplicatedStorage.Events.VFX_Remote:FireAllClients({UnitName.Name, upgradeStats.AttackName}, script.Parent.HumanoidRootPart, target)

		TowerFunctions.DamageFunction(script.Parent, target)

		local attackDuration = 0
		for i, v in upgradeStats.MultiDamageDelays do
			attackDuration += v
		end
		task.wait(TowerInfo.GetCooldown(script.Parent))
	end,

	--["Hybrid"] = function(upgradeStats)
	--	local target = nil
	--	repeat
	--		task.wait(0.1)
	--		target = TowerFunctions.FindTarget(script.Parent)
	--	until target ~= nil

	--	if script.Parent.Animations:FindFirstChild(upgradeStats.AnimName) then
	--		game.ReplicatedStorage.Events.AnimateTower:FireAllClients(script.Parent, upgradeStats.AnimName, target)
	--	end

	--	local newTargetPosition = Vector3.new(target.HumanoidRootPart.Position.X,script.Parent.TowerBasePart.Position.Y,target.HumanoidRootPart.Position.Z) 
	--	local targetCFrame = CFrame.lookAt(script.Parent.TowerBasePart.Position, newTargetPosition)
	--	script.Parent.TowerBasePart.CFrame = targetCFrame

	--	--print(UnitName.Name, upgradeStats.AttackName)
	--	game.ReplicatedStorage.Events.VFX_Remote:FireAllClients({UnitName.Name,upgradeStats.AttackName},script.Parent.HumanoidRootPart,target)

	--	TowerFunctions.DamageFunction(script.Parent,target)

	--	local attackDuration = 0
	--	for i, v in upgradeStats.MultiDamageDelays do
	--		attackDuration += v
	--	end
	--	task.wait(TowerInfo.GetCooldown(script.Parent))
	--end,
	['Support'] = function(upgradeStats)
		warn(script.Parent:GetDescendants())
		SupportFunctions[script.Parent.Name](script.Parent, upgradeStats)
		--repeat
		--	task.wait(0.1)
		--	unit = TowerFunctions.FindTarget(script.Parent)
		--until unit ~= nil
		--print(unit)

		if upgradeStats.AnimName then
			game.ReplicatedStorage.Events.AnimateTower:FireAllClients(script.Parent, upgradeStats.AnimName)
		end
		
		game.ReplicatedStorage.Events.VFX_Remote:FireAllClients({UnitName.Name,upgradeStats.AttackName},script.Parent.HumanoidRootPart)

		--TowerFunctions.DamageFunction(script.Parent,unit)
		local BuffType = upgradeStats.AOEType
		local amount = upgradeStats.Damage
		local range = upgradeStats.Range
		
		for i,v in workspace.Towers:GetChildren() do
			if v == script.Parent then continue end
			
			if mag(script.Parent:GetPivot().Position, v:GetPivot().Position) < range then
				TowerSpecialisation.applyBuff(script.Parent, v, BuffType, amount)
			end
		end

		task.wait(TowerInfo.GetCooldown(script.Parent))
	end,
	
}

while task.wait() do
   --ErrorModule.wrap(main)
	local upgradeStats = UnitName["Upgrades"][script.Parent.Config.Upgrades.Value]
	print(upgradeStats, upgradeStats.Type)
	functions[upgradeStats.Type](upgradeStats)
end