
local module = {}


local base = 10
local baseCost = 10000
local maxLevel = 100
local growthRate = 1.055

function module.getCalculatedUpgradeCost(level)
	if level == 0 then
		return baseCost
	else
		return math.floor(module.getCalculatedUpgradeCost(level - 1) * growthRate + 0.5)
	end
end

function module.getMemberCapFromLevel(level: IntValue)
	return base + level
end

return module