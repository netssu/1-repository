local ServerStorage = game:GetService("ServerStorage")
local module = {}
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ServerScriptService= game:GetService("ServerScriptService")

local events = ReplicatedStorage:WaitForChild("Events")
local animateTowerEvent = events:WaitForChild("AnimateTower")
local fireAbilityEvent = events:WaitForChild("FireAbility")

local functions = ReplicatedStorage:WaitForChild("Functions")
local requestTowerFunction = functions:WaitForChild("RequestTower")
local sellTowerFunction = functions:WaitForChild("SellTower")
local changeModeFunction = functions:WaitForChild("ChangeTowerMode")
local requestAbilityFunction = functions:WaitForChild("RequestAbility")

local upgradesModule = require(ReplicatedStorage.Upgrades)
local traitsModule = require(ReplicatedStorage.Traits)
local TowerSpecialisation = require(ServerStorage.ServerModules.TowerSpecialisation)
local TowerInfo = require(ReplicatedStorage.Modules.Helpers.TowerInfo)
local Auras = require(ReplicatedStorage.Modules.Auras)

local function waitForDamageDelay(delayTime)
	if typeof(delayTime) ~= "number" or delayTime <= 0 then
		return
	end

	local gameSpeed = 1
	local infoFolder = workspace:FindFirstChild("Info")
	local gameSpeedValue = infoFolder and infoFolder:FindFirstChild("GameSpeed")

	if gameSpeedValue and gameSpeedValue:IsA("NumberValue") and gameSpeedValue.Value > 0 then
		gameSpeed = gameSpeedValue.Value
	end

	task.wait(delayTime / gameSpeed)
end

function statusEffects(config:Configuration,target2:Model)
	if config:FindFirstChild("BurningDamage") and config:FindFirstChild("BurningDuration") then
		local burningDamage = config.BurningDamage.Value
		local burningDuration = config.BurningDuration.Value
		target2.Burn:Fire(burningDuration,burningDamage,1)
	elseif config:FindFirstChild("PoisonDamage") and config:FindFirstChild("PoisonDuration") then
		local PoisonDamage = config.PoisonDamage.Value
		local PoisonDuration = config.PoisonDuration.Value
		target2.Poison:Fire(PoisonDuration,PoisonDamage,1)
	elseif config:FindFirstChild("FreezeDamage") and config:FindFirstChild("FreezeDuration") then
		local FreezeDamage = config.FreezeDamage.Value
		local FreezeDuration = config.FreezeDuration.Value
		target2.Freeze:Fire(FreezeDuration,FreezeDamage,1)
	elseif config:FindFirstChild("CursedPercent") then
		local CursedPercent = config.CursedPercent.Value
		target2.Curse:Fire(CursedPercent)
	elseif config:FindFirstChild("BleedPercent") and config:FindFirstChild("BleedDuration") then
		local BleedPercent = config.BleedPercent.Value
		local BleedDuration = config.BleedDuration.Value
		target2.Bleed:Fire(BleedDuration,BleedPercent,1)
	end
end

module.TakeDamage = require(script.DealDamage)

module.AOE = function(newTower:Model, damage:number)
	local multiplier = 0
	local config = newTower.Config
	local damage = damage or TowerInfo.GetDamage(newTower)
	local player = game.Players:FindFirstChild(config.Owner.Value) or game.Players:FindFirstChildOfClass("Player")
	local team = newTower:GetAttribute('Team')
	local targetMobs = nil
	if team then
		targetMobs = workspace[team .. 'Mobs']:GetChildren()
	else
		targetMobs = workspace.Mobs:GetChildren()
	end

	for i, target2 in targetMobs do
		pcall(function()
			if newTower:FindFirstChild("HumanoidRootPart") then
				local distance = (newTower.HumanoidRootPart.Position - target2.HumanoidRootPart.Position).Magnitude
				if distance < TowerInfo.GetRange(newTower) then
					if target2:FindFirstChild("Type").Value == newTower.Config:FindFirstChild("Type").Value or newTower.Config:FindFirstChild("Type").Value == "Hybrid" then

						module.TakeDamage(target2.Humanoid,newTower,damage)
						statusEffects(config,target2)
					end
				end
			end
		end)
	end
end

module.Splash = function(newTower:Model, targetCFrame, damage:number)

	local config = newTower.Config
	local damage = damage or TowerInfo.GetDamage(newTower)
	local player = game.Players:FindFirstChild(config.Owner.Value) or game.Players:FindFirstChildOfClass("Player")

	if newTower.Config.AOEType.Value == "Splash" then
		local team = newTower:GetAttribute('Team')
		local targetMobs = nil

		if team then
			targetMobs = workspace[team .. 'Mobs']:GetChildren()
		else
			targetMobs = workspace.Mobs:GetChildren()
		end

		for i, target2 in targetMobs do
			if target2.Parent and target2:FindFirstChild('HumanoidRootPart') then

				local distance = (target2.HumanoidRootPart.Position - targetCFrame.Position).Magnitude

				-- debug
				--print('splash')
				--print(config.AOESize.Value)

				if distance < config.AOESize.Value then
					local targetType = target2:FindFirstChild("Type")
					local towerType = newTower.Config:FindFirstChild("Type")
					if targetType and towerType and (targetType.Value == towerType.Value or towerType.Value == "Hybrid") then
						module.TakeDamage(target2.Humanoid,newTower,damage)
						statusEffects(config,target2)
					end
				end
			end
		end
	end
end

module.ConeAOE = function(mainPart:BasePart,tower:Model,aoesize:number,damage:number,priorityTarget:Model?)
	if not mainPart then
		return 0
	end

	local angle = 10
	angle = aoesize or tower.Config.AOESize.Value
	local damage = damage or TowerInfo.GetDamage(tower)
	local range = 10
	--local rangemultiplier = 1
	local coneAngle = 1-((angle/90)/2)
	local enemies = {}
	local closestEnemies = {}
	range = TowerInfo.GetRange(tower)

	--local totalrange = config.Range*(CosmicCrusaderBuff+rangemultiplier)
	--local range = totalrange
	local team = tower:GetAttribute('Team')
	local targetMobs = nil

	if team then
		targetMobs = workspace[team .. 'Mobs']:GetChildren()
	else
		targetMobs = workspace.Mobs:GetChildren()
	end

	local hitCount = 0

	for i, v in targetMobs do
		if v:IsA("Model") and v:FindFirstChild('HumanoidRootPart') then
			if (v.HumanoidRootPart.Position - mainPart.Position).magnitude < range then
				local TowerToEnemy = (v.HumanoidRootPart.Position - mainPart.Position).Unit
				local LookV = mainPart.CFrame.LookVector

				local Product = TowerToEnemy:Dot(LookV)
				if Product >= coneAngle then
					table.insert(enemies,v)
				end
			end
		end
	end
	for o=1,#enemies do
		if #enemies > 0 then
			local enemy = nil
			local distance = math.huge
			for i, v in enemies do
				if (v.HumanoidRootPart.Position - mainPart.Position).magnitude < distance then
					enemy = v
					distance = (v.HumanoidRootPart.Position - mainPart.Position).magnitude
				end
			end
			if enemy then
				table.remove(enemies,table.find(enemies,enemy))
				table.insert(closestEnemies,enemy)
			end
		end
	end
	for i, v in closestEnemies do
		if v:FindFirstChild("Type") then
			local targetType = v:FindFirstChild("Type")
			local towerType = tower.Config:FindFirstChild("Type")
			if targetType and towerType and (targetType.Value == towerType.Value or towerType.Value == "Hybrid") then
				hitCount += 1
				module.TakeDamage(v.Humanoid,tower,damage)
			end
		end
	end

	if hitCount == 0 and priorityTarget then
		local priorityHumanoid = priorityTarget:FindFirstChildOfClass("Humanoid")
		local priorityRoot = priorityTarget:FindFirstChild("HumanoidRootPart")
		local targetType = priorityTarget:FindFirstChild("Type")
		local towerType = tower.Config:FindFirstChild("Type")
		local rangePart = tower:FindFirstChild("HumanoidRootPart") or mainPart
		local distance = priorityRoot and (priorityRoot.Position - rangePart.Position).Magnitude
		local validType = targetType and towerType and (targetType.Value == towerType.Value or towerType.Value == "Hybrid")

		if priorityHumanoid and priorityRoot and distance <= range and validType then
			hitCount += 1
			module.TakeDamage(priorityHumanoid,tower,damage)
		end
	end

	return hitCount
end

local Traits = require(ReplicatedStorage.Traits)

module.FindTarget = function(newTower:Model)
	if newTower:GetAttribute("Possessed") == true then
		return nil 
	end
	local bestTarget = nil
	local bestWaypoint = nil
	local bestDistance = nil
	local bestHealth = nil
	local map = nil

	local info = workspace.Info
	if not info.Versus.Value then
		map = workspace.Map:FindFirstChildOfClass("Folder")
	else
		map = workspace
	end



	local mode = newTower.Config.TargetMode.Value
	local towerType = newTower.Config.Type.Value
	local range = TowerInfo.GetRange(newTower)

	local mobTarget = nil
	local foundTeam = newTower:GetAttribute('Team')

	if foundTeam then
		mobTarget = workspace[foundTeam .. 'Mobs']:GetChildren() 
	else
		mobTarget = workspace.Mobs:GetChildren()
	end

	for i, mob in mobTarget do
		if not mob:FindFirstChild("HumanoidRootPart") then continue end
		if not mob:FindFirstChild("Type") then continue end
		if towerType ~= "Hybrid" and mob.Type.Value ~= towerType then continue end

		local newMobPositionForTower = Vector3.new(
			mob.HumanoidRootPart.Position.X,
			newTower.HumanoidRootPart.Position.Y,
			mob.HumanoidRootPart.Position.Z
		)

		local distanceToMob = (newMobPositionForTower - newTower.HumanoidRootPart.Position).Magnitude
		local distanceToWaypoint = nil

		if not info.Versus.Value then
			if map:FindFirstChild("Waypoints") then
				local newMobPositionForPoint = Vector3.new(
					mob.HumanoidRootPart.Position.X,
					map.Waypoints[mob.MovingTo.Value].Position.Y,
					mob.HumanoidRootPart.Position.Z
				)
				distanceToWaypoint = (newMobPositionForPoint - map.Waypoints[mob.MovingTo.Value].Position).Magnitude
			else
				local waypoint = map["Waypoints" .. mob.PathNumber.Value][mob.MovingTo.Value]
				local newMobPositionForPoint = Vector3.new(
					mob.HumanoidRootPart.Position.X,
					waypoint.Position.Y,
					mob.HumanoidRootPart.Position.Z
				)
				distanceToWaypoint = (newMobPositionForPoint - waypoint.Position).Magnitude
			end
		else
			local team = mob:GetAttribute('Team')
			local newMobPositionForPoint = Vector3.new(
				mob.HumanoidRootPart.Position.X,
				map[team .. 'Waypoints'][mob.MovingTo.Value].Position.Y,
				mob.HumanoidRootPart.Position.Z
			)
			distanceToWaypoint = (newMobPositionForPoint - map[team .. 'Waypoints'][mob.MovingTo.Value].Position).Magnitude
		end

		if distanceToMob <= range then
			if mode == "Near" then
				range = distanceToMob
				bestTarget = mob
			elseif mode == "First" then
				if not bestWaypoint or mob.MovingTo.Value >= bestWaypoint then
					if bestWaypoint and mob.MovingTo.Value > bestWaypoint then
						bestWaypoint = mob.MovingTo.Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					elseif not bestDistance or distanceToWaypoint < bestDistance then
						bestWaypoint = bestWaypoint or mob.MovingTo.Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					end
				end
			elseif mode == "Last" then
				if not bestWaypoint or mob.MovingTo.Value <= bestWaypoint then
					if bestWaypoint and mob.MovingTo.Value < bestWaypoint then
						bestWaypoint = mob.MovingTo.Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					elseif not bestDistance or distanceToWaypoint > bestDistance then
						bestWaypoint = bestWaypoint or mob.MovingTo.Value
						bestDistance = distanceToWaypoint
						bestTarget = mob
					end
				end
			elseif mode == "Strong" then
				if not bestHealth or mob.Humanoid.Health > bestHealth then
					bestHealth = mob.Humanoid.Health
					bestTarget = mob
				end
			elseif mode == "Weak" then
				if not bestHealth or mob.Humanoid.Health < bestHealth then
					bestHealth = mob.Humanoid.Health
					bestTarget = mob
				end
			end
		end
	end

	return bestTarget
end

local function getMag(part, distance)
	return (part - distance).Magnitude
end


module.SpawnerFindTarget = function(vehicle:Model)
	local targets = {}
	local map = nil
	local info = workspace.Info


	if not info:FindFirstChild('Versus') or not info.Versus.Value then -- versus goes away for some reason??? idk
		map = workspace.Map:FindFirstChildOfClass("Folder")
	else
		map = workspace
	end

	local newTower = vehicle.OwnedBy.Value
	local mode = newTower.Config.TargetMode.Value
	local towerType = newTower.Config.Type.Value
	local range = TowerInfo.GetRange(newTower)

	local mobTarget = nil
	local foundTeam = newTower:GetAttribute('Team')

	if foundTeam then
		mobTarget = workspace[foundTeam .. 'Mobs']:GetChildren() 
	else
		mobTarget = workspace.Mobs:GetChildren()
	end

	local Range = vehicle:GetAttribute('Range')
	local planePos = vehicle:GetPivot().Position
	local filteredPlanePos = Vector3.new(planePos.X, 0, planePos.Z)

	for i, mob:Model in mobTarget do
		if not mob:FindFirstChild("HumanoidRootPart") then continue end
		if not mob:FindFirstChild("Type") then continue end

		local distanceToWaypoint = nil

		if newTower.Config.AOEType.Value == "Splash" then
			local mobPos = mob:GetPivot().Position
			local filteredPos = Vector3.new(mobPos.X, 0, mobPos.Z)

			if getMag(filteredPlanePos, filteredPos) < Range then
				table.insert(targets, mob)
			end
		end
	end

	return targets
end

local function getAOESize(config: Configuration, upgradeStats)
	local aoeSize = config:FindFirstChild("AOESize")
	if aoeSize and aoeSize:IsA("ValueBase") then
		return aoeSize.Value
	end

	return upgradeStats.AOESize or 0
end

module.DamageFunction = function(tower:Model,target:Model)
	if not tower or not tower.Parent then
		return
	end

	local config = tower:FindFirstChild("Config")
	if not config then
		return
	end

	local upgradeValue = config:FindFirstChild("Upgrades")
	local unitUpgrades = upgradesModule[tower.Name]
	local upgradeStats = unitUpgrades and unitUpgrades.Upgrades and upgradeValue and unitUpgrades.Upgrades[upgradeValue.Value]
	if not upgradeStats then
		return
	end

	local damage = TowerInfo.GetDamage(tower, target)
	local targetHumanoid = target and target:FindFirstChildOfClass("Humanoid")
	local targetRoot = target and target:FindFirstChild("HumanoidRootPart")

	local function damageTarget()
		if targetHumanoid then
			module.TakeDamage(targetHumanoid, tower, damage)
		end
	end

	if upgradeStats.Type == "Spawner" then
		damageTarget()
		return
	end

	local towerRoot = tower:FindFirstChild("HumanoidRootPart")
	local splashPositionPart = tower:FindFirstChild("SplashPositionPart")
	if not splashPositionPart then
		splashPositionPart = Instance.new("Part")
		splashPositionPart.Name = "SplashPositionPart"
		splashPositionPart.Size = Vector3.new(0.01,0.01,0.01)
		splashPositionPart.CanCollide = false
		splashPositionPart.CanTouch = false
		splashPositionPart.CanQuery = false
		splashPositionPart.Anchored = true
		splashPositionPart.Transparency = 1
		Instance.new("Attachment",splashPositionPart)
		splashPositionPart.Parent = tower
	end

	if targetRoot and towerRoot then
		splashPositionPart.CFrame = CFrame.new(targetRoot.Position) * CFrame.new(0,towerRoot.Size.Y*-1.45,0)
	elseif towerRoot then
		splashPositionPart.CFrame = towerRoot.CFrame*CFrame.new(0,towerRoot.Size.Y*-1.45,-getAOESize(config, upgradeStats)*1.5)
	end

	local delays = upgradeStats.MultiDamageDelays
	local delayCount = if typeof(delays) == "table" then #delays else 0
	local aoeType = upgradeStats.AOEType

	if aoeType == "Cone" then
		local mainPart = tower:FindFirstChild("TowerBasePart") or towerRoot
		if not mainPart then
			damageTarget()
			return
		end

		if delayCount > 0 then
			for i=1, delayCount do
				waitForDamageDelay(delays[i])
				module.ConeAOE(mainPart,tower,upgradeStats.AOESize,damage/delayCount,target)
			end
		else
			module.ConeAOE(mainPart,tower,upgradeStats.AOESize,damage,target)
		end
	elseif aoeType == "Splash" then
		if not targetRoot then
			damageTarget()
			return
		end

		if delayCount > 0 then
			local targetCFrame = targetRoot.CFrame
			local firstHit = true
			for i=1, delayCount do
				if firstHit then
					local possibleNewTarget = module.FindTarget(tower)
					local possibleNewRoot = possibleNewTarget and possibleNewTarget:FindFirstChild("HumanoidRootPart")
					targetCFrame = (possibleNewRoot and possibleNewRoot.CFrame) or targetCFrame
					firstHit = false
				end
				waitForDamageDelay(delays[i])
				module.Splash(tower,targetCFrame,damage/delayCount)
			end
		else
			module.Splash(tower,targetRoot.CFrame,damage)
		end
	elseif aoeType == "AOE" then
		if delayCount > 0 then
			for i=1, delayCount do
				waitForDamageDelay(delays[i])
				module.AOE(tower,damage/delayCount)
			end
		else
			module.AOE(tower,damage)
		end
	else
		damageTarget()
	end
end


return module
