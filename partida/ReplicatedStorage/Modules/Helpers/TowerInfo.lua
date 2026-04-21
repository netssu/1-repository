local tInfo = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(game.ReplicatedStorage.Modules.MathFormat)

local upgradesModule = require(ReplicatedStorage.Upgrades)
local traitsModule = require(ReplicatedStorage.Traits)

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
			if buff:FindFirstChildOfClass('NumberValue') and buff:FindFirstChildOfClass('NumberValue').Name == 'DMG' then
				local towerApplied = buff.Value
				local config = towerApplied:FindFirstChild("Config")
				if config then
					warn(buff.Name)
					local upgradeStats = upgradesModule[buff.Name]["Upgrades"][config.Upgrades.Value]
					local amount = 1 + (upgradeStats.Damage or 0) / 100
					warn(amount)
					if tower.Config:FindFirstChild("Shiny") and tower.Config.Shiny.Value then
						amount *= 1.15
					end
					buffMulti *= amount
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
				local towerApplied = buff.Value
				local config = towerApplied:FindFirstChild("Config")
				if config then
					local upgradeStats = upgradesModule[buff.Name] and upgradesModule[buff.Name].Upgrades and upgradesModule[buff.Name].Upgrades[config.Upgrades.Value]
					if upgradeStats and upgradeStats.Cooldown then
						local amount = upgradeStats.Cooldown / 100
						if tower.Config:FindFirstChild("Shiny") and tower.Config.Shiny.Value then
							amount *= 1.15
						end
						totalBuffBonus += amount
						warn(`Applied Cooldown Buff for {buff.Name}: -{amount * 100}%`)
					else
						warn(`Warning: No Cooldown data for {buff.Name} at Upgrade {config.Upgrades.Value}`)
					end
				else
					warn(`Warning: Missing tower config for buff {buff.Name}`)
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
