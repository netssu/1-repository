-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Modules
local QuestConfig = require(game.ReplicatedStorage.Configs.QuestConfig)

-- Remotes
local ClaimQuestReward = ReplicatedStorage.Remotes.Quests.ClaimQuestReward
local RefreshQuests = ReplicatedStorage.Remotes.Quests.RefreshClientQuests

ClaimQuestReward.OnServerInvoke = function(player, quest)
	local response = QuestConfig.ClaimReward(player, quest)
	return response
end

local function refreshDaily(player, data, amount)
	local lastRefresh = data.LastRefresh
	local currentDay = os.date("*t").day
	local quests = data.Quests

	if lastRefresh.Value == currentDay then return end

	quests:ClearAllChildren()

	for i = 1,amount do
		QuestConfig.CreateQuest(player, quests, nil, true, true, "Daily")
	end

	lastRefresh.Value = currentDay
	
	RefreshQuests:FireClient(player, "Daily")
	return true
end

local function refreshWeekly(player, data, amount)
	local lastRefresh = data.LastRefresh
	local currentWeek = math.floor(os.date("*t").yday / 7)
	local quests = data.Quests

	if lastRefresh.Value == currentWeek then
		return
	end

	quests:ClearAllChildren()

	for i = 1, amount do
		QuestConfig.CreateQuest(player, quests, nil, true, true, "Weekly")
	end

	lastRefresh.Value = currentWeek
	
	RefreshQuests:FireClient(player, "Weekly")
	return true
end

local function generateStory(player, data)
	local quests = data.Quests or {}
	local playerQuestNames = {}

	for _, quest in ipairs(quests:GetChildren()) do
		if quest.Name then
			playerQuestNames[quest.Name] = true
		end
	end

	for id, config in QuestConfig.QuestConfigs do
		if config.Group and table.find(config.Group, "Story") then
			QuestConfig.CreateQuest(player, quests, nil, true, false, "Story", "Questline")
		end
	end
end

local function generateInfinite(player, data)
	local quests = data.Quests or {}
	local playerQuestNames = {}

	for _, quest in ipairs(quests:GetChildren()) do
		if quest.Name then
			playerQuestNames[quest.Name] = true
		end
	end

	for id, config in QuestConfig.QuestConfigs do
		if config.Group and table.find(config.Group, "Story") then
			QuestConfig.CreateQuest(player, quests, nil, true, false, "Infinite", "Infinite")
		end
	end
end

local function UpdateQuests(player)
	local questMappings = {
		{data = player.Quests.DailyQuests.Quests, type = "Daily"},
		{data = player.Quests.WeeklyQuests.Quests, type = "Weekly"},
		{data = player.Quests.StoryQuests.Quests, type = "Story"},
		{data = player.Quests.InfiniteQuests.Quests, type = "Infinite"},
		{data = player.Quests.EventQuests.Quests, type = "Event"},
		{data = player.BattlepassData.Quests, type = "Battlepass"},
	}
	
	

	for _, quest in ipairs(questMappings) do
		QuestConfig.UpdateQuests(player, quest.data, quest.type)
		if quest.type == "Infinite" then
			QuestConfig.UpdateProgress(quest.data, "ClearInfinite", 0)
		end
	end
end


game.Players.PlayerAdded:Connect(function(player)
	repeat task.wait() until player:FindFirstChild("DataLoaded")
	--print("LOADED NOW FOR QUESTS")
	
	UpdateQuests(player)

	local questData = player.Quests
	local dailyData = questData.DailyQuests
	local weeklyData = questData.WeeklyQuests
	local storyData = questData.StoryQuests
	local infiniteData = questData.InfiniteQuests
	--local eventData = questData.EventQuests
	
	refreshDaily(player, dailyData, 5)
	refreshWeekly(player, weeklyData, 5)
	generateStory(player, storyData)
	generateInfinite(player, infiniteData)
	
	
	workspace:GetAttributeChangedSignal("Day"):Connect(function()
		refreshDaily(player, dailyData, 5)
		refreshWeekly(player, weeklyData, 5)
	end)
end)
