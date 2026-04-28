local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerInfo = require(ReplicatedStorage.Modules.Helpers.TowerInfo)
local Auras = require(ReplicatedStorage.Modules.Auras)
local upgradesModule = require(ReplicatedStorage.Upgrades)

local function getGameSpeed()
	local info = workspace:FindFirstChild("Info")
	local gameSpeed = info and info:FindFirstChild("GameSpeed")
	if gameSpeed and gameSpeed.Value > 0 then
		return gameSpeed.Value
	end

	return 1
end

local DEBUG_ATTRIBUTE = "TowerDamageDebug"
local DEBUG_PREFIX = "[TowerDamageDebug]"
local debugWarningTimes = {}

local function isDamageDebugEnabled()
	if workspace:GetAttribute(DEBUG_ATTRIBUTE) == true then
		return true
	end

	local info = workspace:FindFirstChild("Info")
	if not info then
		return false
	end

	if info:GetAttribute(DEBUG_ATTRIBUTE) == true then
		return true
	end

	local debugValue = info:FindFirstChild(DEBUG_ATTRIBUTE)
	return debugValue and debugValue:IsA("BoolValue") and debugValue.Value == true
end

local function getDebugName(value)
	if typeof(value) == "Instance" then
		local ok, fullName = pcall(function()
			return value:GetFullName()
		end)
		return if ok then fullName else value.Name
	end

	return tostring(value)
end

local function markDamageDebug(tower, target, reason, details)
	if typeof(tower) ~= "Instance" then
		return
	end

	pcall(function()
		tower:SetAttribute("LastDamageDebugAt", os.clock())
		tower:SetAttribute("LastDamageDebugReason", tostring(reason))
		tower:SetAttribute("LastDamageDebugTarget", getDebugName(target))
		if details ~= nil then
			tower:SetAttribute("LastDamageDebugDetails", tostring(details))
		end
	end)
end

local function debugDamage(tower, target, reason, details, always)
	markDamageDebug(tower, target, reason, details)

	local debugEnabled = isDamageDebugEnabled()
	if not debugEnabled and not always then
		return
	end

	local key = `{getDebugName(tower)}:{reason}`
	local now = os.clock()
	if not debugEnabled and debugWarningTimes[key] and now - debugWarningTimes[key] < 5 then
		return
	end
	debugWarningTimes[key] = now

	warn(DEBUG_PREFIX, reason, "tower", getDebugName(tower), "target", getDebugName(target), details or "")
end

return function(humanoid:Humanoid,tower:Model,damage)
	local enemy = humanoid and humanoid.Parent
	if not enemy then
		debugDamage(tower, nil, "missing enemy parent", nil, true)
		return false
	end

	if not tower or not tower.Parent then
		debugDamage(tower, enemy, "missing tower", nil, true)
		return false
	end

	local config = tower:FindFirstChild("Config")
	if not config then
		debugDamage(tower, enemy, "tower missing Config", nil, true)
		return false
	end

	local function getFallbackDamage()
		local damageValue = config:FindFirstChild("Damage")
		if damageValue and typeof(damageValue.Value) == "number" then
			return damageValue.Value
		end

		return 0
	end

	local okDamage, damageOrError = pcall(function()
		return math.round(damage or TowerInfo.GetDamage(tower, enemy))
	end)

	if okDamage then
		damage = damageOrError
	else
		debugDamage(tower, enemy, "GetDamage error inside DealDamage, using Config.Damage fallback", damageOrError, true)
		damage = math.round(getFallbackDamage())
	end

	if typeof(damage) ~= "number" then
		debugDamage(tower, enemy, "damage was not numeric inside DealDamage, using Config.Damage fallback", damage, true)
		damage = math.round(getFallbackDamage())
	end

	local upgradeValue = config:FindFirstChild("Upgrades")
	local towerData = upgradesModule[tower.Name]
	local upgradeStats = towerData and towerData.Upgrades and upgradeValue and towerData.Upgrades[upgradeValue.Value]
	if not upgradeStats then
		debugDamage(tower, enemy, "missing upgrade stats inside DealDamage; debuffs skipped", tower.Name, true)
	end

	if upgradeStats and upgradeStats.EnemyDebuffs then
		local debuffs = upgradeStats.EnemyDebuffs
		local slowData = debuffs.Slowness
		if slowData and not enemy:GetAttribute("Slowness") then
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local originalSpeedValue = enemy:FindFirstChild("OriginalSpeed")
				local originalSpeed = if originalSpeedValue then originalSpeedValue.Value else enemy:GetAttribute("OriginalSpeed") or humanoid.WalkSpeed
				enemy:SetAttribute("OriginalSpeed", originalSpeed)

				Auras.AddAura(enemy, "Slowness", slowData.Duration)
				enemy:SetAttribute("Slowness", true)

				local factor = slowData.SlowFactor or slowData.Debuff or 0.8
				enemy:SetAttribute("SlownessFactor", factor)
				humanoid.WalkSpeed = originalSpeed * getGameSpeed() * factor

				task.delay(slowData.Duration, function()
					if humanoid and humanoid.Parent then
						enemy:SetAttribute("Slowness", false)
						enemy:SetAttribute("SlownessFactor", nil)
						humanoid.WalkSpeed = originalSpeed * getGameSpeed()
					end
				end)
			end
		end
	end

	local enemyRoot = enemy.PrimaryPart or enemy:FindFirstChild("HumanoidRootPart")
	local healthBeforeDamageDealt = humanoid.Health
	local enemyType = enemy:FindFirstChild("Type")
	local towerType = config:FindFirstChild("Type")

	if enemyType and towerType and (enemyType.Value == towerType.Value or towerType.Value == "Hybrid") then
		if config:FindFirstChild("FreezeDuration") then
			local FreezeDamage = 0
			if config:FindFirstChild("FreezeDamage") then
				FreezeDamage = config.FreezeDamage.Value
			end
			local FreezePriority = 1
			if config:FindFirstChild("FreezePriority") then
				FreezePriority = config.FreezePriority.Value
			end
			local NoIce = false
			if config:FindFirstChild("NoIce") then
				NoIce = config.NoIce.Value
			end
			local freezeEvent = enemy:FindFirstChild("Freeze")
			if freezeEvent then
				freezeEvent:Fire(config.FreezeDuration.Value,FreezeDamage,FreezePriority,NoIce)
			end
		elseif config:FindFirstChild("BurningDuration") then
			local BurningDamage = 0
			if config:FindFirstChild("BurningDamage") then
				BurningDamage = config.BurningDamage.Value
			end
			local BurningPriority = 1
			if config:FindFirstChild("BurningPriority") then
				BurningPriority = config.BurningPriority.Value
			end
			local burnEvent = enemy:FindFirstChild("Burn")
			if burnEvent then
				burnEvent:Fire(config.BurningDuration.Value,BurningDamage,BurningPriority)
			end
		elseif config:FindFirstChild("PoisonDuration") then
			local PoisonDamage = 0
			if config:FindFirstChild("PoisonDamage") then
				PoisonDamage = config.PoisonDamage.Value
			end
			local PoisonPriority = 1
			if config:FindFirstChild("PoisonPriority") then
				PoisonPriority = config.PoisonPriority.Value
			end
			local poisonEvent = enemy:FindFirstChild("Poison")
			if poisonEvent then
				poisonEvent:Fire(config.PoisonDuration.Value,PoisonDamage,PoisonPriority)
			end
		elseif config:FindFirstChild("BleedDuration") then
			local BleedPercent = 0
			if config:FindFirstChild("BleedPercent") then
				BleedPercent = config.BleedPercent.Value
			end
			local BleedPriority = 1
			if config:FindFirstChild("BleedPriority") then
				BleedPriority = config.BleedPriority.Value
			end
			local bleedEvent = enemy:FindFirstChild("Bleed")
			if bleedEvent then
				bleedEvent:Fire(config.BleedDuration.Value,BleedPercent,BleedPriority)
			end
		elseif config:FindFirstChild("CursedPercent") then
			local curseEvent = enemy:FindFirstChild("Curse")
			if curseEvent then
				curseEvent:Fire(config.CursedPercent.Value)
			end
		end
	end

	local appliedDamage = damage
	local totalDamage = config:FindFirstChild("TotalDamage")
	if totalDamage then
		totalDamage.Value += appliedDamage
	end

	local okTakeDamage, takeDamageError = pcall(function()
		humanoid:TakeDamage(appliedDamage)
	end)
	if not okTakeDamage then
		debugDamage(tower, enemy, "Humanoid:TakeDamage failed", takeDamageError, true)
		return false
	end

	if isDamageDebugEnabled() then
		debugDamage(tower, enemy, "damage applied", `damage={appliedDamage} health={healthBeforeDamageDealt}->{humanoid.Health}`, false)
		if not enemyRoot then
			debugDamage(tower, enemy, "damage indicator skipped because target has no root", nil, false)
		end
	end

	if config:FindFirstChild("Owner") and damage > 0 then
		--print(tower.Config)
		local player = game.Players:FindFirstChild(config.Owner.Value) or game.Players:FindFirstChildOfClass("Player")
		if player and player:IsA("Player") and enemyRoot then
			ReplicatedStorage.Events.VFX_Remote:FireClient(player,"DamageIndicator",appliedDamage,enemyRoot)
		end

		if player then
			local RawDamage = player:GetAttribute("RawDamage") or 0
			player.Damage.Value += appliedDamage
			player:SetAttribute("RawDamage", RawDamage + appliedDamage)
		end

		if player then

			if healthBeforeDamageDealt > 0 and humanoid.Health <= 0 then

				local playerTower;
				for _, towerObject in player.OwnedTowers:GetChildren() do
					if towerObject.Name == tower.Name and towerObject:GetAttribute("Equipped") then
						playerTower = towerObject
						break
					end
				end




				if playerTower then
					local Kills = player:WaitForChild("Kills")
					Kills.Value = Kills.Value + 1

					player.Stats.Kills.Value += 1
					player:FindFirstChild("MedalKills").Value += 1
					--warn(player:FindFirstChild("MedalKills").Value)


					if workspace.Info.SpecialEvent.Value then
						player.Stats.YounglingsEnded.Value += 1
					end
				end
			end
		end
	end

	return true
end
