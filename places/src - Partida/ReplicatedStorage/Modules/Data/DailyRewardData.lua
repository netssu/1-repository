------------------//CONSTANTS
local dailyRewardData = {}

export type Reward = {
	Id: number,
	Type: string,
	Amount: number?,
	Item: string?,
	UnlockAfter: number,
	DuplicateCash: number?,
}

export type State = {
	CycleStart: number,
	Claimed: { [string]: boolean },
}

local SECONDS_PER_DAY: number = 24 * 60 * 60

dailyRewardData.REWARD_INTERVAL_SECONDS = SECONDS_PER_DAY
dailyRewardData.Items = {
	{
		Id = 1,
		Type = "Cash",
		Amount = 500,
		UnlockAfter = 0 * SECONDS_PER_DAY,
	},
	{
		Id = 2,
		Type = "XP",
		Amount = 150,
		UnlockAfter = 1 * SECONDS_PER_DAY,
	},
	{
		Id = 3,
		Type = "Cash",
		Amount = 1000,
		UnlockAfter = 2 * SECONDS_PER_DAY,
	},
	{
		Id = 4,
		Type = "RacePassXP",
		Amount = 250,
		UnlockAfter = 3 * SECONDS_PER_DAY,
	},
	{
		Id = 5,
		Type = "Helmets",
		Item = "Green",
		UnlockAfter = 4 * SECONDS_PER_DAY,
		DuplicateCash = 750,
	},
	{
		Id = 6,
		Type = "Cash",
		Amount = 2500,
		UnlockAfter = 5 * SECONDS_PER_DAY,
	},
	{
		Id = 7,
		Type = "XP",
		Amount = 750,
		UnlockAfter = 6 * SECONDS_PER_DAY,
	},
	{
		Id = 8,
		Type = "Livery",
		Item = "Dark Blue",
		UnlockAfter = 7 * SECONDS_PER_DAY,
		DuplicateCash = 1500,
	},
} :: { Reward }

dailyRewardData.CYCLE_SECONDS = SECONDS_PER_DAY * #dailyRewardData.Items

------------------//FUNCTIONS
local function copy_claimed(source: any): ({ [string]: boolean }, boolean)
	local claimed: { [string]: boolean } = {}
	if type(source) ~= "table" then
		return claimed, true
	end

	local changed = false
	for key, value in source do
		if value == true then
			claimed[tostring(key)] = true
			if type(key) ~= "string" then
				changed = true
			end
		else
			changed = true
		end
	end

	return claimed, changed
end

function dailyRewardData.create_state(now: number?): State
	return {
		CycleStart = now or os.time(),
		Claimed = {},
	}
end

function dailyRewardData.normalize_state(rawState: any, now: number?): (State, boolean)
	local currentTime = now or os.time()
	if type(rawState) ~= "table" then
		return dailyRewardData.create_state(currentTime), true
	end

	local cycleStart = tonumber(rawState.CycleStart) or 0
	local cycleExpired = currentTime - cycleStart >= dailyRewardData.CYCLE_SECONDS
	local invalidCycleStart = cycleStart <= 0 or cycleStart - currentTime > 60
	if cycleExpired or invalidCycleStart then
		return dailyRewardData.create_state(currentTime), true
	end

	local claimed, changed = copy_claimed(rawState.Claimed)
	return {
		CycleStart = cycleStart,
		Claimed = claimed,
	}, changed
end

function dailyRewardData.get_reward(rewardId: number): Reward?
	for _, reward in dailyRewardData.Items do
		if reward.Id == rewardId then
			return reward
		end
	end

	return nil
end

function dailyRewardData.get_reward_count(): number
	return #dailyRewardData.Items
end

function dailyRewardData.get_unlock_time(state: State, rewardId: number): number
	local reward = dailyRewardData.get_reward(rewardId)
	return state.CycleStart + (reward and reward.UnlockAfter or 0)
end

function dailyRewardData.get_remaining_time(state: State, rewardId: number, now: number?): number
	local currentTime = now or os.time()
	return math.max(0, dailyRewardData.get_unlock_time(state, rewardId) - currentTime)
end

function dailyRewardData.is_claimed(state: State, rewardId: number): boolean
	return state.Claimed[tostring(rewardId)] == true
end

function dailyRewardData.is_unlocked(state: State, rewardId: number, now: number?): boolean
	return dailyRewardData.get_remaining_time(state, rewardId, now) <= 0
end

function dailyRewardData.can_claim(state: State, rewardId: number, now: number?): boolean
	return not dailyRewardData.is_claimed(state, rewardId)
		and dailyRewardData.is_unlocked(state, rewardId, now)
end

------------------//INIT
return dailyRewardData


