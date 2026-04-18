--!strict

local ProgressionUtil = {}

local DEFAULT_LEVEL = 0
local DEFAULT_EXP = 0
local BASE_EXP_REQUIREMENT = 1000
local EXP_REQUIREMENT_STEP = 1000

export type ProgressionResult = {
	Level: number,
	Exp: number,
	GainedExp: number,
	LevelUps: number,
	RequiredExp: number,
}

function ProgressionUtil.NormalizeLevel(value: any): number
	local numericValue = tonumber(value) or DEFAULT_LEVEL
	return math.max(DEFAULT_LEVEL, math.floor(numericValue))
end

function ProgressionUtil.NormalizeExp(value: any): number
	local numericValue = tonumber(value) or DEFAULT_EXP
	return math.max(DEFAULT_EXP, math.floor(numericValue))
end

function ProgressionUtil.GetRequiredExpForLevel(level: any): number
	local normalizedLevel = ProgressionUtil.NormalizeLevel(level)
	return BASE_EXP_REQUIREMENT + (normalizedLevel * EXP_REQUIREMENT_STEP)
end

function ProgressionUtil.AddExp(currentLevel: any, currentExp: any, gainedExp: any): ProgressionResult
	local resolvedLevel = ProgressionUtil.NormalizeLevel(currentLevel)
	local resolvedExp = ProgressionUtil.NormalizeExp(currentExp)
	local resolvedGain = math.max(0, math.floor(tonumber(gainedExp) or 0))
	local levelUps = 0

	resolvedExp += resolvedGain

	while true do
		local requiredExp = ProgressionUtil.GetRequiredExpForLevel(resolvedLevel)
		if resolvedExp < requiredExp then
			break
		end

		resolvedExp -= requiredExp
		resolvedLevel += 1
		levelUps += 1
	end

	return {
		Level = resolvedLevel,
		Exp = resolvedExp,
		GainedExp = resolvedGain,
		LevelUps = levelUps,
		RequiredExp = ProgressionUtil.GetRequiredExpForLevel(resolvedLevel),
	}
end

return ProgressionUtil
