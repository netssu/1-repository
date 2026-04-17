local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Traits = require(ReplicatedStorage.Modules.Traits)

local function generateTraitDescription(traitData)
	local descriptions = {}

	-- Handle regular stats
	if traitData.Damage and traitData.Damage > 0 then
		table.insert(descriptions, "Increases damage by " .. traitData.Damage .. "%")
	end

	if traitData.Range and traitData.Range > 0 then
		table.insert(descriptions, "increases range by " .. traitData.Range .. "%")
	end

	if traitData.Cooldown and traitData.Cooldown > 0 then
		table.insert(descriptions, "decreases cooldown by " .. traitData.Cooldown .. "%")
	end

	if traitData.BossDamage and traitData.BossDamage > 0 then
		table.insert(descriptions, "increases boss damage by " .. traitData.BossDamage .. "%")
	end

	if traitData.Money and traitData.Money > 0 then
		table.insert(descriptions, "increases money by " .. traitData.Money .. "%")
	end

	if traitData.Exp and traitData.Exp > 0 then
		table.insert(descriptions, "increases experience by " .. traitData.Exp .. "%")
	end

	-- Handle tower buffs (global buffs)
	if traitData.TowerBuffs then
		local towerBuffs = {}

		if traitData.TowerBuffs.Damage and traitData.TowerBuffs.Damage ~= 1 then
			local damagePercent = math.floor((traitData.TowerBuffs.Damage - 1) * 100)
			if damagePercent > 0 then
				table.insert(towerBuffs, "damage by " .. damagePercent .. "%")
			elseif damagePercent < 0 then
				table.insert(towerBuffs, "damage by " .. math.abs(damagePercent) .. "%")
			end
		end

		if traitData.TowerBuffs.Range and traitData.TowerBuffs.Range ~= 1 then
			local rangePercent = math.floor((traitData.TowerBuffs.Range - 1) * 100)
			if rangePercent > 0 then
				table.insert(towerBuffs, "range by " .. rangePercent .. "%")
			elseif rangePercent < 0 then
				table.insert(towerBuffs, "range by " .. math.abs(rangePercent) .. "%")
			end
		end

		if traitData.TowerBuffs.Cooldown and traitData.TowerBuffs.Cooldown ~= 1 then
			local cooldownPercent = math.floor((1 - traitData.TowerBuffs.Cooldown) * 100)
			if cooldownPercent > 0 then
				table.insert(towerBuffs, "cooldown by " .. cooldownPercent .. "%")
			elseif cooldownPercent < 0 then
				table.insert(towerBuffs, "cooldown by " .. math.abs(cooldownPercent) .. "%")
			end
		end

		if #towerBuffs > 0 then
			local towerBuffString = "Global Buffs: increases " .. table.concat(towerBuffs, ", increases ")
			table.insert(descriptions, towerBuffString)
		end
	end

	-- Join all descriptions
	if #descriptions == 0 then
		return "No stat bonuses"
	elseif #descriptions == 1 then
		-- Capitalize first letter of single description
		local desc = descriptions[1]
		return desc:sub(1,1):upper() .. desc:sub(2)
	else
		-- Capitalize first description, join with commas
		local result = descriptions[1]:sub(1,1):upper() .. descriptions[1]:sub(2)
		for i = 2, #descriptions do
			result = result .. ", " .. descriptions[i]
		end
		return result
	end
end

for i,v in script.Parent:GetChildren() do
	if v:IsA('GuiBase2d') then
		local traitData = Traits.Traits[v.Name]
		if traitData then
			v.Contents.Subtext.Text = generateTraitDescription(traitData)
		elseif v:FindFirstChild('Contents') then
			v.Contents.Subtext.Text = 'Error'
		end
	end
end