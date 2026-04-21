local ServerStorage = game:GetService("ServerStorage")
local MobsSpecification = require(ServerStorage.ServerModules.MobsSpecification)

local DEBUFF_RANGE = 15
local DEBUFF_TYPE = "Damage Decrease"
local DEBUFF_AMOUNT = 30

-- Tracks currently debuffed towers
local debuffedTowers = {}

local function mag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

task.spawn(function()
	while task.wait(0.5) do
		local mob = script.Parent
		if not mob or not mob.Parent then return end

		local mobPos = mob:GetPivot().Position
		local currentInRange = {}

		for _, tower in workspace.Towers:GetChildren() do
			if tower == mob then continue end

			local towerPos = tower:GetPivot().Position
			local distance = mag(mobPos, towerPos)

			if distance < DEBUFF_RANGE then
				currentInRange[tower] = true

				if not debuffedTowers[tower] then
					-- Apply debuff
					MobsSpecification.applyEffect(mob, tower, "Debuff", DEBUFF_TYPE, DEBUFF_AMOUNT)
					debuffedTowers[tower] = true
					print(mob.Name .. " applied debuff to: " .. tower.Name)
				end
			end
		end

		for tower in pairs(debuffedTowers) do
			if not currentInRange[tower] or not tower:IsDescendantOf(workspace) then
				MobsSpecification.clearEffectsFromSource(mob, tower, DEBUFF_TYPE)
				debuffedTowers[tower] = nil
				print(mob.Name .. " removed debuff from: " .. tower.Name)
			end
		end
	end
end)
