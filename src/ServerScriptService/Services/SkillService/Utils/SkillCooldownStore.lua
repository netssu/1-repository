--!strict

export type CooldownMap = {[string]: number}

local COOLDOWN_PREFIX_NORMAL: string = "N_"
local COOLDOWN_PREFIX_AWAKEN: string = "A_"

local SkillCooldownStore = {}

function SkillCooldownStore.BuildKey(SkillId: string, IsAwaken: boolean): string
	local Prefix: string = if IsAwaken then COOLDOWN_PREFIX_AWAKEN else COOLDOWN_PREFIX_NORMAL
	return Prefix .. SkillId
end

function SkillCooldownStore.IsReady(Cooldowns: CooldownMap, CooldownKey: string, Now: number): boolean
	local ReadyAt: number? = Cooldowns[CooldownKey]
	if not ReadyAt then
		return true
	end
	return Now >= ReadyAt
end

function SkillCooldownStore.Begin(Cooldowns: CooldownMap, CooldownKey: string, Duration: number, Now: number): number
	local SafeDuration: number = if typeof(Duration) == "number" then Duration else 0
	local SafeNow: number = if typeof(Now) == "number" then Now else os.clock()
	local ReadyAt: number = SafeNow + math.max(SafeDuration, 0)
	Cooldowns[CooldownKey] = ReadyAt
	return ReadyAt
end

function SkillCooldownStore.ClearAll(Cooldowns: CooldownMap): ()
	table.clear(Cooldowns)
end

return SkillCooldownStore
