------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

------------------//CONSTANTS
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local QuestConfig = require(ReplicatedStorage.Modules.Datas.QuestConfig)

------------------//VARIABLES
local activeObservers = {}
local sessionCache = {}

local assets = ReplicatedStorage:WaitForChild("Assets")

local remotesFolder = assets:FindFirstChild("Remotes") or Instance.new("Folder", assets)
remotesFolder.Name = "Remotes"

local claimRemote = remotesFolder:FindFirstChild("ClaimQuest") or Instance.new("RemoteFunction", remotesFolder)
claimRemote.Name = "ClaimQuest"

local completedRemote = remotesFolder:FindFirstChild("QuestCompleted") or Instance.new("RemoteEvent", remotesFolder)
completedRemote.Name = "QuestCompleted"

------------------//HELPER FUNCTIONS
local function count_dictionary(dict)
	if type(dict) ~= "table" then return 0 end
	local count = 0
	for _ in pairs(dict) do count += 1 end
	return count
end

local function save_quests(player, questsTable)
	DataUtility.server.set(player, "Quests", questsTable)
end

local function get_quest_by_id(quests, questId)
	if not quests then return nil end
	for index, quest in ipairs(quests) do
		if quest.Id == questId then return quest, index end
	end
	return nil, nil
end

local function create_single_quest(excludeTypes)
	local typeKeys = {}
	for key in pairs(QuestConfig.TYPES) do
		if not excludeTypes or not excludeTypes[key] then
			table.insert(typeKeys, key)
		end
	end

	if #typeKeys == 0 then
		for key in pairs(QuestConfig.TYPES) do table.insert(typeKeys, key) end
	end

	local randomType = typeKeys[math.random(1, #typeKeys)]
	local config = QuestConfig.TYPES[randomType]
	local amount = math.random(config.Range.Min, config.Range.Max)

	return {
		Id = HttpService:GenerateGUID(false),
		Type = randomType,
		Goal = amount,
		Progress = 0,
		Reward = math.floor(amount * config.RewardPerUnit),
		Claimed = false
	}
end

------------------//CORE FUNCTIONS
local function update_quest_progress(player, questId, newProgress)
	local quests = DataUtility.server.get(player, "Quests")
	if not quests then return end

	local quest = get_quest_by_id(quests, questId)
	if not quest or quest.Claimed or quest.Progress >= quest.Goal then return end

	local wasComplete = quest.Progress >= quest.Goal
	quest.Progress = math.min(newProgress, quest.Goal)

	if not wasComplete and quest.Progress >= quest.Goal then
		local config = QuestConfig.TYPES[quest.Type]
		local questTitle = config and config.Title or "Quest"
		completedRemote:FireClient(player, questTitle)
	end

	save_quests(player, quests)
end

local function process_data_change(player, path, newValue)
	local quests = DataUtility.server.get(player, "Quests")
	if not quests then return end

	local cacheKey = player.UserId .. "_" .. path
	local oldValue = sessionCache[cacheKey]

	for _, quest in ipairs(quests) do
		if quest.Claimed then continue end

		local config = QuestConfig.TYPES[quest.Type]
		if not config or config.WatchPath ~= path then continue end

		if config.InteractionType == "Increment" then
			if oldValue == nil then
				sessionCache[cacheKey] = newValue
				continue
			end

			local delta = (tonumber(newValue) or 0) - (tonumber(oldValue) or 0)
			if delta > 0 then
				update_quest_progress(player, quest.Id, quest.Progress + delta)
			end

		elseif config.InteractionType == "TableCount" then
			local countNew = count_dictionary(newValue)
			local countOld = count_dictionary(oldValue)

			if countNew > countOld then
				local difference = countNew - countOld
				update_quest_progress(player, quest.Id, quest.Progress + difference)
			end

		elseif config.InteractionType == "Threshold" then
			local currentValue = tonumber(newValue) or 0
			if currentValue >= quest.Goal then
				update_quest_progress(player, quest.Id, quest.Goal)
			end
		end
	end

	sessionCache[cacheKey] = newValue
end

local function setup_observers(player)
	if activeObservers[player.UserId] then
		for _, conn in pairs(activeObservers[player.UserId]) do
			conn:Disconnect()
		end
	end
	activeObservers[player.UserId] = {}

	local pathsToWatch = {}
	for _, config in pairs(QuestConfig.TYPES) do
		pathsToWatch[config.WatchPath] = true
	end

	for path in pairs(pathsToWatch) do
		local currentValue = DataUtility.server.get(player, path)

		if not activeObservers[player.UserId] then break end

		sessionCache[player.UserId .. "_" .. path] = currentValue

		local connection = DataUtility.server.bind(player, path, function(newValue)
			process_data_change(player, path, newValue)
		end)

		if not activeObservers[player.UserId] then
			if connection then
				connection:Disconnect()
			end
			break
		end

		table.insert(activeObservers[player.UserId], connection)
	end
end

local function generate_daily_quests(player)
	local newQuests = {}
	local usedTypes = {}

	for i = 1, QuestConfig.QUESTS_PER_DAY do
		local quest = create_single_quest(usedTypes)
		usedTypes[quest.Type] = true
		table.insert(newQuests, quest)
	end

	DataUtility.server.set(player, "Quests", newQuests)
	return newQuests
end

local function claim_quest(player, questId)
	local quests = DataUtility.server.get(player, "Quests")
	if not quests then return false end

	local quest, index = get_quest_by_id(quests, questId)
	if not quest then return false end

	if quest.Progress >= quest.Goal then
		local rewardAmount = quest.Reward

		local currentCoins = DataUtility.server.get(player, "Coins") or 0
		DataUtility.server.set(player, "Coins", currentCoins + rewardAmount)

		local usedTypes = {}
		for _, q in ipairs(quests) do
			if q.Id ~= questId then 
				usedTypes[q.Type] = true
			end
		end

		table.remove(quests, index)

		local newQuest = create_single_quest(usedTypes)
		table.insert(quests, newQuest)

		save_quests(player, quests)

		return rewardAmount 
	end

	return false
end

local function cleanup_player(player)
	if activeObservers[player.UserId] then
		for _, conn in pairs(activeObservers[player.UserId]) do
			conn:Disconnect()
		end
		activeObservers[player.UserId] = nil
	end

	for key in pairs(sessionCache) do
		if string.find(key, "^" .. player.UserId) then
			sessionCache[key] = nil
		end
	end
end

------------------//INIT
DataUtility.server.ensure_remotes()
claimRemote.OnServerInvoke = claim_quest

Players.PlayerAdded:Connect(function(player)
	task.wait(1) 

	if not player.Parent then return end

	local quests = DataUtility.server.get(player, "Quests")

	if not player.Parent then return end

	if not quests or #quests == 0 then
		generate_daily_quests(player)
	end

	setup_observers(player)
end)

Players.PlayerRemoving:Connect(cleanup_player)