------------------//CONSTANTS
local QUEST_SLOT_NAMES: { string } = { "QuestOne", "QuestTwo", "QuestThree", "QuestFour" }
local CATEGORY_NAMES: { string } = { "Daily", "Weekly", "Monthly", "VIP" }
local REFRESH_SECONDS: { [string]: number } = {
	Daily = 24 * 60 * 60,
	Weekly = 7 * 24 * 60 * 60,
	Monthly = 30 * 24 * 60 * 60,
	VIP = 7 * 24 * 60 * 60,
}
local SUPPORTED_EVENTS: { [string]: boolean } = {
	RaceComplete = true,
	TopThree = true,
	Podium = true,
	FastestLap = true,
	Overtake = true,
	PersonalBest = true,
	AttackMode = true,
	LiveryWin = true,
	Win = true,
	TrackRace = true,
	PlayTime = true,
}

export type Definition = {
	Id: string,
	Event: string,
	Goal: number,
	RewardCash: number,
	RewardXP: number,
	RewardItemType: string?,
	RewardItem: string?,
	Track: string?,
	Livery: string?,
}

export type EventContext = {
	Track: string?,
	Livery: string?,
}

local DEFINITIONS: { [string]: { Definition } } = {
	Daily = {
		{ Id = "DailyRaces", Event = "RaceComplete", Goal = 3, RewardCash = 800, RewardXP = 100 },
		{ Id = "DailyTopThree", Event = "TopThree", Goal = 1, RewardCash = 700, RewardXP = 120 },
		{ Id = "DailyFastestLap", Event = "FastestLap", Goal = 1, RewardCash = 900, RewardXP = 140 },
		{ Id = "DailyAttackMode", Event = "AttackMode", Goal = 2, RewardCash = 850, RewardXP = 120 },
	},
	Weekly = {
		{ Id = "WeeklyPodiums", Event = "Podium", Goal = 5, RewardCash = 3000, RewardXP = 350 },
		{ Id = "WeeklyOvertakes", Event = "Overtake", Goal = 15, RewardCash = 3500, RewardXP = 400 },
		{ Id = "WeeklyPersonalBest", Event = "PersonalBest", Goal = 3, RewardCash = 3200, RewardXP = 420 },
		{ Id = "WeeklyOwnedLiveryWins", Event = "LiveryWin", Livery = "Default", Goal = 2, RewardCash = 3000, RewardXP = 360 },
	},
	Monthly = {
		{ Id = "MonthlyRaces", Event = "RaceComplete", Goal = 30, RewardCash = 8000, RewardXP = 650 },
		{ Id = "MonthlyTopThree", Event = "TopThree", Goal = 15, RewardCash = 9000, RewardXP = 700, RewardItemType = "Helmets", RewardItem = "Deep Blue" },
		{ Id = "MonthlyFastestLaps", Event = "FastestLap", Goal = 8, RewardCash = 9500, RewardXP = 750, RewardItemType = "Suit", RewardItem = "LazaRacing" },
		{ Id = "MonthlyOwnedLiveryWins", Event = "LiveryWin", Livery = "Dark Blue", Goal = 3, RewardCash = 8500, RewardXP = 680 },
	},
	VIP = {
		{ Id = "VipOvertakes", Event = "Overtake", Goal = 25, RewardCash = 10000, RewardXP = 500, RewardItemType = "Livery", RewardItem = "Red" },
		{ Id = "VipPersonalBest", Event = "PersonalBest", Goal = 5, RewardCash = 11000, RewardXP = 550, RewardItemType = "Helmets", RewardItem = "Cream" },
		{ Id = "VipWins", Event = "Win", Goal = 5, RewardCash = 12000, RewardXP = 600, RewardItemType = "Suit", RewardItem = "Black" },
		{ Id = "VipOwnedLiveryWins", Event = "LiveryWin", Livery = "Porsche", Goal = 3, RewardCash = 10500, RewardXP = 520 },
	},
}

------------------//FUNCTIONS
local function create_challenge(definition: Definition): { [string]: any }
	return {
		QuestId = definition.Id,
		QuestType = definition.Event,
		QuestTrack = definition.Track,
		QuestLivery = definition.Livery,
		QuestProgress = 0,
		QuestGoal = definition.Goal,
		RewardCash = definition.RewardCash,
		RewardXP = definition.RewardXP,
		RewardItemType = definition.RewardItemType,
		RewardItem = definition.RewardItem,
		Completed = false,
	}
end

local function create_category(categoryName: string): { [string]: any }
	local category = { LastRefresh = 0 }
	local definitions = DEFINITIONS[categoryName]
	if not definitions then
		return category
	end

	for index, slotName in QUEST_SLOT_NAMES do
		local definition = definitions[index]
		if definition then
			category[slotName] = create_challenge(definition)
		end
	end

	return category
end

local function create_root(): { [string]: any }
	local root = {}
	for _, categoryName in CATEGORY_NAMES do
		root[categoryName] = create_category(categoryName)
	end
	return root
end

local function normalize_challenge(existing: any, definition: Definition): { [string]: any }
	if type(existing) ~= "table" or existing.QuestId ~= definition.Id then
		return create_challenge(definition)
	end

	existing.QuestType = definition.Event
	existing.QuestTrack = definition.Track
	existing.QuestLivery = definition.Livery
	existing.QuestProgress = math.clamp(tonumber(existing.QuestProgress) or 0, 0, definition.Goal)
	existing.QuestGoal = definition.Goal
	existing.RewardCash = definition.RewardCash
	existing.RewardXP = definition.RewardXP
	existing.RewardItemType = definition.RewardItemType
	existing.RewardItem = definition.RewardItem
	existing.Completed = existing.Completed == true
	return existing
end

local function ensure_root(root: any): { [string]: any }
	if type(root) ~= "table" then
		return create_root()
	end

	for _, categoryName in CATEGORY_NAMES do
		local category = root[categoryName]
		if type(category) ~= "table" then
			root[categoryName] = create_category(categoryName)
			continue
		end

		category.LastRefresh = tonumber(category.LastRefresh) or 0
		local definitions = DEFINITIONS[categoryName]
		for index, slotName in QUEST_SLOT_NAMES do
			local definition = definitions[index]
			if definition then
				category[slotName] = normalize_challenge(category[slotName], definition)
			end
		end
	end

	return root
end

local function reset_category(category: any, categoryName: string, refreshTime: number): ()
	if type(category) ~= "table" then
		return
	end

	local definitions = DEFINITIONS[categoryName]
	if not definitions then
		return
	end

	for index, slotName in QUEST_SLOT_NAMES do
		local definition = definitions[index]
		if definition then
			category[slotName] = create_challenge(definition)
		end
	end
	category.LastRefresh = refreshTime
end

local function get_definition_by_id(challengeId: any): Definition?
	if type(challengeId) ~= "string" then
		return nil
	end

	for _, definitions in DEFINITIONS do
		for _, definition in definitions do
			if definition.Id == challengeId then
				return definition
			end
		end
	end

	return nil
end

local function get_event(challenge: any): string?
	if type(challenge) ~= "table" then
		return nil
	end
	return if type(challenge.QuestType) == "string" then challenge.QuestType else nil
end

local function matches(challenge: any, eventName: string, context: EventContext?): boolean
	if get_event(challenge) ~= eventName then
		return false
	end

	local requiredTrack = challenge.QuestTrack
	if requiredTrack and (not context or context.Track ~= requiredTrack) then
		return false
	end

	local requiredLivery = challenge.QuestLivery
	if requiredLivery and (not context or context.Livery ~= requiredLivery) then
		return false
	end

	return true
end

local function format_objective(challenge: any): string
	local progress = math.min(tonumber(challenge.QuestProgress) or 0, tonumber(challenge.QuestGoal) or 0)
	local goal = tonumber(challenge.QuestGoal) or 0
	local eventName = get_event(challenge)

	if eventName == "RaceComplete" then
		return ("Complete %d/%d races using any car"):format(progress, goal)
	elseif eventName == "TopThree" then
		return ("Finish in the Top 3: %d/%d"):format(progress, goal)
	elseif eventName == "Podium" then
		return ("Earn %d/%d podium finishes"):format(progress, goal)
	elseif eventName == "FastestLap" then
		return ("Set %d/%d fastest laps"):format(progress, goal)
	elseif eventName == "Overtake" then
		return ("Complete %d/%d overtakes"):format(progress, goal)
	elseif eventName == "PersonalBest" then
		return ("Beat your lap record %d/%d times"):format(progress, goal)
	elseif eventName == "TrackRace" then
		return ("Complete %d/%d races at %s using any car"):format(progress, goal, tostring(challenge.QuestTrack))
	elseif eventName == "AttackMode" then
		return ("Use Attack Mode %d/%d times"):format(progress, goal)
	elseif eventName == "LiveryWin" then
		return ("Win %d/%d races using %s car"):format(progress, goal, tostring(challenge.QuestLivery))
	elseif eventName == "Win" then
		return ("Win %d/%d races"):format(progress, goal)
	elseif eventName == "PlayTime" then
		return ("Play for %d/%d minutes"):format(progress, goal)
	end

	return ("%d/%d"):format(progress, goal)
end

------------------//INIT
return {
	CATEGORY_NAMES = CATEGORY_NAMES,
	QUEST_SLOT_NAMES = QUEST_SLOT_NAMES,
	REFRESH_SECONDS = REFRESH_SECONDS,
	DEFINITIONS = DEFINITIONS,
	SUPPORTED_EVENTS = SUPPORTED_EVENTS,
	create_root = create_root,
	ensure_root = ensure_root,
	reset_category = reset_category,
	get_definition_by_id = get_definition_by_id,
	get_event = get_event,
	matches = matches,
	format_objective = format_objective,
}
