local module = {}

local A = 465.12
local B = 1.075

function module.getXPForLevel(level) -- XP required for a specific level
	return math.round(A * (B ^ level))
end

function module.getXPToNextLevel(level) -- XP difference between current and next level
	return module.getXPForLevel(level + 1)
end

function module.getTotalXPToLevel(level) -- Total XP needed to reach a level
	local total = 0
	for i = 1, level do
		total += module.getXPForLevel(i)
	end
	return total
end

function module.getLevelFromXP(totalXP) -- Calculates level and XP into current level from total XP
	local level = 0
	local accumulated = 0
	while true do
		level += 1
		local xpForLevel = module.getXPForLevel(level)
		if accumulated + xpForLevel > totalXP then
			break
		end
		accumulated += xpForLevel
	end
	return level - 1, totalXP - accumulated
end

--[[
local level, xpIntoLevel = module.getLevelFromXP(totalXP)
local xpNeeded = module.getXPToNextLevel(level)

-- Show on UI:
-- "XP: " .. xpIntoLevel .. " / " .. xpNeeded
--]]


return module