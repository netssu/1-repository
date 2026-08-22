------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataModules: Folder = modules:WaitForChild("Data")
local dataUtility = require(dataModules:WaitForChild("DataUtility"))
local challengesData = require(dataModules:WaitForChild("ChallengesData"))
local inventoryFolder: Folder = dataModules:WaitForChild("Inventory")
local inventoryCatalogs: { [string]: any } = {
	Suit = require(inventoryFolder:WaitForChild("Suit")),
	Helmets = require(inventoryFolder:WaitForChild("Helmets")),
	Livery = require(inventoryFolder:WaitForChild("Livery")),
}

------------------//CONSTANTS
local NORMAL_QUESTS_PATH: string = "Profile.Quests"
local PREMIUM_QUESTS_PATH: string = "Profile.RacingPass.Quests"
local RACING_PASS_OWNED_PATH: string = "Profile.RacingPass.RacingpassOwned"
local CASH_PATH: string = "Currency.Cash"
local XP_PATH: string = "Currency.XP"
local RACE_PASS_XP_PATH: string = "Currency.RacePassXP"
local REWARD_OWNED_PATHS: { [string]: string } = {
	Suit = "Inventory.Owned.Suit",
	Helmets = "Inventory.Owned.Helmets",
	Livery = "Inventory.Owned.Livery",
}
local MAX_EVENT_AMOUNT: number = 100

type EventContext = challengesData.EventContext
type DataConnection = {
	disconnect: (self: DataConnection) -> (),
}
type EventRequest = {
	Name: string,
	Amount: number,
	Context: EventContext?,
}
type RaceResult = {
	Position: number?,
	Track: string?,
	Livery: string?,
	FastestLap: boolean?,
	PersonalBest: boolean?,
	Overtakes: number?,
	AttackModeUses: number?,
}

------------------//VARIABLES
local playerConnections: { [number]: { DataConnection } } = {}

------------------//FUNCTIONS
local function get_profile(data: any): { [string]: any }?
	if type(data) ~= "table" or type(data.Profile) ~= "table" then
		return nil
	end

	return data.Profile
end

local function get_inventory_items(data: any, rewardType: string): { string }?
	local inventory = type(data) == "table" and data.Inventory
	local owned = type(inventory) == "table" and inventory.Owned
	local items = type(owned) == "table" and owned[rewardType]
	return if type(items) == "table" then items else nil
end

local function is_known_reward_item(rewardType: string, rewardItem: string): boolean
	local catalog = inventoryCatalogs[rewardType]
	return catalog ~= nil and type(catalog.Items) == "table" and type(catalog.Items[rewardItem]) == "table"
end

local function contains_item(items: { string }, itemName: string): boolean
	for _, ownedItem in items do
		if ownedItem == itemName then
			return true
		end
	end

	return false
end

local function normalize_context(context: any): EventContext
	if type(context) ~= "table" then
		return {}
	end

	return {
		Track = if type(context.Track) == "string" then context.Track else nil,
		Livery = if type(context.Livery) == "string" then context.Livery else nil,
	}
end

local function refresh_expired_categories(root: { [string]: any }, now: number): boolean
	local changed = false
	for categoryName, category in root do
		if type(category) ~= "table" then
			continue
		end

		local refreshSeconds = challengesData.REFRESH_SECONDS[categoryName]
		local lastRefresh = tonumber(category.LastRefresh) or 0
		if lastRefresh <= 0 then
			category.LastRefresh = now
			changed = true
		elseif refreshSeconds and now - lastRefresh >= refreshSeconds then
			challengesData.reset_category(category, categoryName, now)
			changed = true
		end
	end

	return changed
end

local function increment_matching_challenges(
	root: { [string]: any },
	events: { EventRequest }
): boolean
	local changed = false
	for _, category in root do
		if type(category) ~= "table" then
			continue
		end

		for slotName, challenge in category do
			if slotName == "LastRefresh" or type(challenge) ~= "table" or challenge.Completed == true then
				continue
			end

			for _, event in events do
				if challengesData.matches(challenge, event.Name, event.Context) then
					local goal = tonumber(challenge.QuestGoal) or 0
					local currentProgress = tonumber(challenge.QuestProgress) or 0
					local nextProgress = math.clamp(currentProgress + event.Amount, 0, goal)
					if nextProgress ~= currentProgress then
						challenge.QuestProgress = nextProgress
						changed = true
					end
				end
			end
		end
	end

	return changed
end

local function add_reward_to_data(
	data: any,
	challenge: { [string]: any },
	isPremium: boolean,
	changedPaths: { [string]: boolean }
): boolean
	local currency = type(data) == "table" and data.Currency
	if type(currency) ~= "table" then
		return false
	end

	local rewardCash = tonumber(challenge.RewardCash) or 0
	local rewardXp = tonumber(challenge.RewardXP) or 0
	if rewardCash < 0 or rewardXp < 0 then
		return false
	end

	local rewardType = challenge.RewardItemType
	local rewardItem = challenge.RewardItem
	if rewardType ~= nil or rewardItem ~= nil then
		if type(rewardType) ~= "string" or type(rewardItem) ~= "string" then
			return false
		end
		if not REWARD_OWNED_PATHS[rewardType] or not is_known_reward_item(rewardType, rewardItem) then
			return false
		end
	end

	currency.Cash = (tonumber(currency.Cash) or 0) + rewardCash
	changedPaths[CASH_PATH] = true

	local xpPath = if isPremium then RACE_PASS_XP_PATH else XP_PATH
	local xpField = if isPremium then "RacePassXP" else "XP"
	currency[xpField] = (tonumber(currency[xpField]) or 0) + rewardXp
	changedPaths[xpPath] = true

	if rewardType == nil and rewardItem == nil then
		return true
	end

	local ownedItems = get_inventory_items(data, rewardType :: string)
	if not ownedItems then
		return false
	end
	if not contains_item(ownedItems, rewardItem :: string) then
		table.insert(ownedItems, rewardItem :: string)
	end
	changedPaths[REWARD_OWNED_PATHS[rewardType :: string]] = true
	return true
end

local function complete_ready_challenges(
	data: any,
	root: { [string]: any },
	isPremium: boolean,
	changedPaths: { [string]: boolean }
): boolean
	local profile = get_profile(data)
	local racingPass = profile and profile.RacingPass
	if isPremium and (type(racingPass) ~= "table" or racingPass.RacingpassOwned ~= true) then
		return false
	end

	local changed = false
	for _, category in root do
		if type(category) ~= "table" then
			continue
		end

		for slotName, challenge in category do
			if slotName == "LastRefresh" or type(challenge) ~= "table" or challenge.Completed == true then
				continue
			end

			local progress = tonumber(challenge.QuestProgress) or 0
			local goal = tonumber(challenge.QuestGoal) or 0
			if progress >= goal and add_reward_to_data(data, challenge, isPremium, changedPaths) then
				challenge.Completed = true
				changed = true
			end
		end
	end

	return changed
end

local function build_event_request(eventName: any, amount: any, context: any): EventRequest?
	if type(eventName) ~= "string" or not challengesData.SUPPORTED_EVENTS[eventName] then
		return nil
	end

	local safeAmount = math.clamp(math.floor(tonumber(amount) or 1), 1, MAX_EVENT_AMOUNT)
	return {
		Name = eventName,
		Amount = safeAmount,
		Context = normalize_context(context),
	}
end

local function refresh_player_data(player: Player): boolean
	local questRoot = dataUtility.server.get(player, NORMAL_QUESTS_PATH)
	if type(questRoot) ~= "table" then
		return false
	end

	local didUpdate = dataUtility.server.update(player, function(data: any): { [string]: any }?
		local profile = get_profile(data)
		local racingPass = profile and profile.RacingPass
		if not profile or type(racingPass) ~= "table" then
			return nil
		end

		profile.Quests = challengesData.ensure_root(profile.Quests)
		racingPass.Quests = challengesData.ensure_root(racingPass.Quests)
		local now = os.time()
		refresh_expired_categories(profile.Quests, now)
		refresh_expired_categories(racingPass.Quests, now)
		return {
			[NORMAL_QUESTS_PATH] = profile.Quests,
			[PREMIUM_QUESTS_PATH] = racingPass.Quests,
		}
	end)
	return didUpdate
end

local function record_events(player: Player, events: { EventRequest }): boolean
	if #events == 0 then
		return false
	end

	local didUpdate = dataUtility.server.update(player, function(data: any): { [string]: any }?
		local profile = get_profile(data)
		local racingPass = profile and profile.RacingPass
		if not profile or type(racingPass) ~= "table" then
			return nil
		end

		profile.Quests = challengesData.ensure_root(profile.Quests)
		racingPass.Quests = challengesData.ensure_root(racingPass.Quests)
		local now = os.time()
		refresh_expired_categories(profile.Quests, now)
		refresh_expired_categories(racingPass.Quests, now)
		increment_matching_challenges(profile.Quests, events)
		increment_matching_challenges(racingPass.Quests, events)

		local changedPaths: { [string]: boolean } = {}
		complete_ready_challenges(data, profile.Quests, false, changedPaths)
		complete_ready_challenges(data, racingPass.Quests, true, changedPaths)

		local changes: { [string]: any } = {
			[NORMAL_QUESTS_PATH] = profile.Quests,
			[PREMIUM_QUESTS_PATH] = racingPass.Quests,
		}
		for path in changedPaths do
			if path == CASH_PATH then
				changes[path] = data.Currency.Cash
			elseif path == XP_PATH then
				changes[path] = data.Currency.XP
			elseif path == RACE_PASS_XP_PATH then
				changes[path] = data.Currency.RacePassXP
			else
				local rewardType = path:match("^Inventory%.Owned%.(.+)$")
				if rewardType then
					changes[path] = data.Inventory.Owned[rewardType]
				end
			end
		end
		return changes
	end)

	return didUpdate
end

local function bind_player(player: Player): ()
	local connections: { DataConnection } = {}
	local connection = dataUtility.server.bind(player, RACING_PASS_OWNED_PATH, function()
		refresh_player_data(player)
	end)
	if connection then
		table.insert(connections, connection :: DataConnection)
	end
	playerConnections[player.UserId] = connections
	task.spawn(function()
		refresh_player_data(player)
	end)
end

local function unbind_player(player: Player): ()
	local connections = playerConnections[player.UserId]
	if not connections then
		return
	end

	for _, connection in connections do
		connection:disconnect()
	end
	playerConnections[player.UserId] = nil
end

------------------//MAIN FUNCTIONS
local challengesService = {}

function challengesService.refresh_player(player: Player): boolean
	return refresh_player_data(player)
end

function challengesService.record_event(player: Player, eventName: string, amount: number?, context: EventContext?): boolean
	local request = build_event_request(eventName, amount, context)
	return if request then record_events(player, { request }) else false
end

function challengesService.record_events(player: Player, events: { EventRequest }): boolean
	local validEvents: { EventRequest } = {}
	for _, event in events do
		local request = build_event_request(event.Name, event.Amount, event.Context)
		if request then
			table.insert(validEvents, request)
		end
	end
	return record_events(player, validEvents)
end

function challengesService.record_race_result(player: Player, result: RaceResult): boolean
	if type(result) ~= "table" then
		return false
	end

	local events: { EventRequest } = {
		{ Name = "RaceComplete", Amount = 1, Context = normalize_context(result) },
	}
	local position = tonumber(result.Position)
	if position and position <= 3 then
		table.insert(events, { Name = "TopThree", Amount = 1, Context = normalize_context(result) })
		table.insert(events, { Name = "Podium", Amount = 1, Context = normalize_context(result) })
	end
	if position == 1 then
		table.insert(events, { Name = "Win", Amount = 1, Context = normalize_context(result) })
	end
	if result.FastestLap == true then
		table.insert(events, { Name = "FastestLap", Amount = 1, Context = normalize_context(result) })
	end
	if result.PersonalBest == true then
		table.insert(events, { Name = "PersonalBest", Amount = 1, Context = normalize_context(result) })
	end

	local overtakes = tonumber(result.Overtakes) or 0
	if overtakes > 0 then
		table.insert(events, { Name = "Overtake", Amount = overtakes, Context = normalize_context(result) })
	end
	local attackModeUses = tonumber(result.AttackModeUses) or 0
	if attackModeUses > 0 then
		table.insert(events, { Name = "AttackMode", Amount = attackModeUses, Context = normalize_context(result) })
	end

	return challengesService.record_events(player, events)
end

function challengesService.add_playtime_minutes(player: Player, minutes: number): boolean
	return challengesService.record_event(player, "PlayTime", minutes)
end

function challengesService.enable(): ()
	for _, player in Players:GetPlayers() do
		bind_player(player)
	end
	Players.PlayerAdded:Connect(bind_player)
	Players.PlayerRemoving:Connect(unbind_player)
end

------------------//INIT
return challengesService
