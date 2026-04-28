local tInfo = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(game.ReplicatedStorage.Modules.MathFormat)

local upgradesModule = require(ReplicatedStorage.Upgrades)
local traitsModule = require(ReplicatedStorage.Traits)

local DEBUG_ATTRIBUTE = "TowerDamageDebug"
local DEBUG_PREFIX = "[TowerDamageDebug]"

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

local function debugWarn(...)
	if isDamageDebugEnabled() then
		warn(DEBUG_PREFIX, ...)
	end
end

local function getBuffSource(buff)
	if not buff:IsA("ObjectValue") then
		return nil
	end

	local source = buff.Value
	if source and source.Parent then
		return source
	end

	return nil
end

local function removeInvalidBuff(tower, buff, reason)
	debugWarn("Removing invalid buff", buff:GetFullName(), "tower", tower:GetFullName(), "reason", reason)
	buff:Destroy()
end

function tInfo.GetRange(tower: Model, placeholder)
	local towerData = upgradesModule[tower.Name]
	local upgradeLevel = 1

	if not towerData or not towerData.Upgrades then
		error("Missing upgrade data for tower: " .. tostring(tower.Name))
	end

	if not placeholder then
		local config = tower:FindFirstChild("Config")
		if config then
			local upgradesValue = config:FindFirstChild("Upgrades")
			if upgradesValue and typeof(upgradesValue.Value) == "number" then
				upgradeLevel = upgradesValue.Value
			end
		end
	end

	local config = towerData.Upgrades[upgradeLevel]


	if not config or not config.Range then
		warn("No valid config or range found for tower:", tower)
		return 1
	end

	local baseRange = config.Range
	local range = baseRange

	local cosmicCrusaderBuff = if game.Workspace:GetAttribute("CosmicCrusader") == true
		then traitsModule.Traits["Cosmic Crusader"].TowerBuffs.Range or 1
		else 1

	if not placeholder then
		local traitName = tower:FindFirstChild("Config") and tower.Config:FindFirstChild("Trait") and tower.Config.Trait.Value or nil
		if traitName and traitName ~= "" then
			local traitData = traitsModule.Traits[traitName]
			if traitData and traitData.Range and traitData.Range ~= 0 then
				range *= 1 + (traitData.Range / 100)
			end
		end

		range *= cosmicCrusaderBuff

		if tower:FindFirstChild("Buffs") then
			for _, buff in ipairs(tower.Buffs:GetChildren()) do
				local numberValue = buff:FindFirstChildOfClass("NumberValue")
				if numberValue and numberValue.Name == "Range" then
					range *= 1 + (numberValue.Value / 100)
				end
			end
		end

		local shiny = tower:FindFirstChild("Config") and tower.Config:FindFirstChild("Shiny")
		if shiny and shiny.Value then
			range *= 1.15
		end
	end

	return Format.Round(range, 1)
end

function tInfo.GetDamage(tower: Model, enemy: Model?)
	local damage = tower.Config:FindFirstChild("Damage") and tower.Config.Damage.Value or 0
	local baseDamage = damage
	local buffMulti = 1
	local multiplier = 1

	if tower:FindFirstChild('Buffs') then
		for _, buff in tower.Buffs:GetChildren() do
			local buffValue = buff:FindFirstChildOfClass('NumberValue')
			if buffValue and buffValue.Name == 'DMG' then
				local towerApplied = getBuffSource(buff)
				if not towerApplied then
					removeInvalidBuff(tower, buff, "missing source tower")
					continue
				end

				local config = towerApplied:FindFirstChild("Config")
				if config then
					local upgradeValue = config:FindFirstChild("Upgrades")
					local sourceData = upgradesModule[buff.Name] or upgradesModule[towerApplied.Name]
					local upgradeStats = sourceData and sourceData.Upgrades and upgradeValue and sourceData.Upgrades[upgradeValue.Value]
					local buffPercent = if upgradeStats and upgradeStats.Damage then upgradeStats.Damage else buffValue.Value
					local amount = 1 + (buffPercent or 0) / 100
					if tower.Config:FindFirstChild("Shiny") and tower.Config.Shiny.Value then
						amount *= 1.15
					end
					buffMulti *= amount
				else
					removeInvalidBuff(tower, buff, "source tower missing Config")
				end
			end
		end
	end

	local traitName = tower.Config:FindFirstChild("Trait") and tower.Config.Trait.Value
	if traitName and traitsModule.Traits[traitName] and enemy and enemy:FindFirstChild("IsBoss") and enemy.IsBoss.Value == true then
		multiplier += (traitsModule.Traits[traitName].BossDamage or 0) / 100
	end

	local CosmicCrusaderBuff = if workspace:GetAttribute("CosmicCrusader") then traitsModule.Traits["Cosmic Crusader"].TowerBuffs.Damage else 1

	if buffMulti > traitsModule.Traits["Cosmic Crusader"].TowerBuffs.Damage then
		CosmicCrusaderBuff = 1
	end

	local modifiedDamage = math.round(baseDamage * buffMulti)
	modifiedDamage = math.round(modifiedDamage * CosmicCrusaderBuff)
	modifiedDamage = math.round(modifiedDamage * multiplier)

	return math.abs(modifiedDamage)
end


function tInfo.GetCooldown(tower: Model)
	local baseCooldown = tower.Config:FindFirstChild("Cooldown") and tower.Config.Cooldown.Value or 1
	local totalBuffBonus = 0
	local gameSpeed = game.Workspace.Info:FindFirstChild("GameSpeed") and game.Workspace.Info.GameSpeed.Value or 1

	if tower:FindFirstChild("Buffs") then
		for _, buff in ipairs(tower.Buffs:GetChildren()) do
			local numberValue = buff:FindFirstChildOfClass("NumberValue")
			if numberValue and numberValue.Name == "AOE" then
				local towerApplied = getBuffSource(buff)
				if not towerApplied then
					removeInvalidBuff(tower, buff, "missing source tower")
					continue
				end

				local config = towerApplied:FindFirstChild("Config")
				if config then
					local upgradeValue = config:FindFirstChild("Upgrades")
					local sourceData = upgradesModule[buff.Name] or upgradesModule[towerApplied.Name]
					local upgradeStats = sourceData and sourceData.Upgrades and upgradeValue and sourceData.Upgrades[upgradeValue.Value]
					if upgradeStats and upgradeStats.Cooldown then
						local amount = upgradeStats.Cooldown / 100
						if tower.Config:FindFirstChild("Shiny") and tower.Config.Shiny.Value then
							amount *= 1.15
						end
						totalBuffBonus += amount
						debugWarn(`Applied Cooldown Buff for {buff.Name}: -{amount * 100}%`)
					else
						local upgradeDebug = if upgradeValue then upgradeValue.Value else "?"
						debugWarn(`Warning: No Cooldown data for {buff.Name} at Upgrade {upgradeDebug}`)
					end
				else
					removeInvalidBuff(tower, buff, "source tower missing Config")
				end
			end
		end
	end

	local traitMultiplier = 1
	local traitName = tower.Config:FindFirstChild("Trait") and tower.Config.Trait.Value
	if traitName and traitsModule.Traits[traitName] and traitsModule.Traits[traitName].Cooldown then
		traitMultiplier = 1 - (traitsModule.Traits[traitName].Cooldown / 100)
	end

	local cosmicMultiplier = 1
	if game.Workspace:GetAttribute("CosmicCrusader") == true then
		local cosmicCooldown = traitsModule.Traits["Cosmic Crusader"].TowerBuffs.Cooldown
		if cosmicCooldown then
			cosmicMultiplier = 1 - (cosmicCooldown / 100)
		end
	end

	local buffMultiplier = 1 - totalBuffBonus
	local finalCooldown = baseCooldown * traitMultiplier * cosmicMultiplier * buffMultiplier
	finalCooldown /= gameSpeed

	return finalCooldown
end


return tInfo
