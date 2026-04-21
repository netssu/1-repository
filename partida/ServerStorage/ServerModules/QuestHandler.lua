type QuestType = "summon_unit" | "finish_level" | "kills" | "clear_waves_multiplayer" | "finish_any_story_level" | "reach_wave"
type QuestCategory = "story" | "daily" | "weekly" | "infinite" | "event"
type UpdateProgressAdditionalParem = { AddAmount : number, World : number?, Level : number?, Wave : number? }
type AdditionalQuestInfo = { QuestCategory : QuestCategory }

local HttpsService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local BadgeService = game:GetService("BadgeService")

local Message = game.ReplicatedStorage.Events.Client.Message
local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)

local QuestHelper = require(game.ReplicatedStorage.Modules.QuestHelper)

local DailyQuestTimeInterval = 86400 --one day cycle in seconds
local WeeklyQuestTimeInterval = 604800 --one week cycle in seconds

-- translate table into instances
function DeepLoadedInstance(parent : Instance, table : table) : boolean	-- will return if its successful or not / can handle string and numbers atm
	for index, element in table do
		if typeof(element) == "table" then

			local folder = Instance.new("Folder")
			folder.Name = index
			local success = DeepLoadedInstance(folder, element)
			folder.Parent = parent
			if not success then
				return false
			end

		else

			local basicValues = {
				number = "NumberValue",
				boolean = "BoolValue",
				string = "StringValue"
			}

			local elementType = typeof(element)
			if not basicValues[elementType] then 
				warn(`DeepLoadedInstance does not support {element} type`) 
				return false 
			end

			local newInstance = Instance.new(basicValues[elementType])
			newInstance.Name = index
			newInstance.Value = element
			newInstance.Parent = parent

		end
	end

	return true

end

-- return a set of quest based on given list and the quantity to return
function GetRandomQuest(QuestList : table, Quantity : number)

	local allQuest = {}
	for _, quest in QuestList do
		table.insert(allQuest, quest)
	end

	Quantity = math.min(#allQuest, Quantity) --in the event that there are not enough different quests
	local randomNumberList = {}
	for i = 1, Quantity do
		local randomNumber = math.random(1, #allQuest)
		while table.find(randomNumberList, randomNumber) do
			randomNumber = math.random(1, #allQuest)
			task.wait()
		end
		table.insert(randomNumberList, randomNumber)
	end

	local selectedQuests = {}
	for _, number in randomNumberList do
		table.insert(selectedQuests, allQuest[number])
	end

	return selectedQuests
end

local DataQuest = require(game.ReplicatedStorage.Data.Quests)

local QuestHandler = {}

-- handle client redeem communication and time cycle along with giving the quests
function QuestHandler.Init()

	if PlaceData.Lobby == game.PlaceId then
		game.ReplicatedStorage.Functions.RedeemQuest.OnServerInvoke = QuestHandler.RedeemQuest
	end

	local lastTime = 0
	local refreshInterval = 5
	local initialReconcile = {}
	RunService.Heartbeat:Connect(function()
		if os.time() - lastTime < refreshInterval then
			return
		end

		lastTime = os.time()
		for _, player in Players:GetPlayers() do
			if not player:FindFirstChild("DataLoaded") then continue end
			if not player:FindFirstChild("QuestsData") then continue end

			QuestHandler.ExpireQuests(player)
			if (os.time() - player.QuestsData.LastDailyQuestTime.Value) > DailyQuestTimeInterval then
				player.QuestsData.LastDailyQuestTime.Value = os.time()
				QuestHandler.GiveDailyQuest(player)
			end
			if (os.time() - player.QuestsData.LastWeeklyQuestTime.Value) > WeeklyQuestTimeInterval then
				player.QuestsData.LastWeeklyQuestTime.Value = os.time()
				QuestHandler.GiveWeeklyQuest(player)
			end
			if not initialReconcile[player] == true then
				initialReconcile[player] = true
				QuestHandler.ReconcileQuests(player)
				QuestHandler.GiveStoryQuest(player)
				QuestHandler.GiveEventQuest(player)
			end
		end

	end)

end

-- mark complete_all_daily and complete_all_weekly as complete if their perspective category is completed
function QuestHandler.ReconcileQuests(Player)	--in the event that questinfo has been updated
	local quests = Player.QuestsData.Quests



	if #QuestHelper.GetQuestsByCategory(Player, "daily") == 1 then
		QuestHandler.UpdateQuestProgress(Player, "complete_all_daily", {AddAmount = 1})
	end
	if #QuestHelper.GetQuestsByCategory(Player, "weekly") == 1 then
		QuestHandler.UpdateQuestProgress(Player, "complete_all_weekly", {AddAmount = 1})
	end

	local eventQuests = QuestHelper.GetQuestsByCategory(Player, "event")
	for _, quest in eventQuests do
		local matchFromData = false
		for _, questData in DataQuest.Event do
			if questData.QuestId == quest.QuestInfo.QuestId.Value then
				matchFromData = true
			end
		end

		if not matchFromData then
			quest:Destroy()
		end

	end

end

-- give a set of 6 quest chosen at random from weekly data in DataQuest
-- give custom quest that require all daily category quest to be completed
-- give infinite quest if player has not receive it
-- give story quest if player has not receive it
function QuestHandler.GiveDailyQuest(Player : Player)

	--remove old daily
	for _, quest in QuestHelper.GetQuestsByCategory(Player, "daily") do
		quest:Destroy()
	end

	-- Daily
	local completedAllQuest = {
		QuestName = "Daily Completed", 
		QuestDescription = "Complete all daily quests", 
		QuestReward = {
			Gems = 500,
			TraitPoint = 3
		}, 
		QuestRequirement = {
			Type = "complete_all_daily", 
			Amount = 1
		}
	}

	local layoutOrderCounter = 1
	QuestHandler.GenerateQuest(Player, completedAllQuest, {QuestCategory = "daily", LayoutOrder = layoutOrderCounter})
	for _, questInfo in GetRandomQuest(DataQuest.Daily, 6)  do
		layoutOrderCounter += 1
		QuestHandler.GenerateQuest(Player, questInfo, {QuestCategory = "daily", LayoutOrder = layoutOrderCounter})
	end


	--Infinite
	local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)
	local availableWorlds = table.clone(StoryModeStats.Worlds)
	local worldSelected = {}
	repeat
		local randomWorldname = availableWorlds[math.random(1, #availableWorlds)]
		if table.find(worldSelected, randomWorldname) then continue end
		table.insert(worldSelected, randomWorldname)
		task.wait()
	until #worldSelected == 3 or #worldSelected == #availableWorlds

	table.sort(worldSelected, function(worldAName, worldBName)
		return table.find(availableWorlds, worldAName) < table.find(availableWorlds, worldBName)
	end)

	for i, worldName in worldSelected do
		local reach10Wave = {
			QuestName = `{worldName} - Infinite I`, 
			QuestDescription = `Reach Wave 10 on {worldName} Infinite Mode`, 
			QuestReward = {
				Gems = 100
			}, 
			QuestRequirement = {
				Type = "reach_wave", 
				Amount = 1,
				Wave = 10,
				World = table.find(availableWorlds, worldName)
			},
			ExpireTime = os.time() + DailyQuestTimeInterval
		}

		local reach25Wave = {
			QuestName = `{worldName} - Infinite II`, 
			QuestDescription = `Reach Wave 25 on {worldName} Infinite Mode`, 
			QuestReward = {
				Gems = 150
			}, 
			QuestRequirement = {
				Type = "reach_wave", 
				Amount = 1,
				Wave = 25,
				World = table.find(availableWorlds, worldName)
			},
			ExpireTime = os.time() + DailyQuestTimeInterval
		}

		local reach50Wave = {
			QuestName = `{worldName} - Infinite III`, 
			QuestDescription = `Reach Wave 50 on {worldName} Infinite Mode`, 
			QuestReward = {
				Gems = 250,
				TraitPoint = 1
			}, 
			QuestRequirement = {
				Type = "reach_wave", 
				Amount = 1,
				Wave = 50,
				World = table.find(availableWorlds, worldName)
			},
			ExpireTime = os.time() + DailyQuestTimeInterval
		}

		local baseAdd = (i - 1) * 3
		QuestHandler.GenerateQuest(Player, reach10Wave, {QuestCategory = "infinite", LayoutOrder = baseAdd + 1})
		QuestHandler.GenerateQuest(Player, reach25Wave, {QuestCategory = "infinite", LayoutOrder = baseAdd + 2})
		QuestHandler.GenerateQuest(Player, reach50Wave, {QuestCategory = "infinite", LayoutOrder = baseAdd + 3})
	end

end

function QuestHandler.GiveStoryQuest(Player)
	local layoutOrderCounter = 1
	for _, questInfo in DataQuest.Story do
		QuestHandler.GenerateQuest(Player, questInfo, {QuestCategory = "story", LayoutOrder = layoutOrderCounter})
		layoutOrderCounter += 1
	end
end

function QuestHandler.GiveEventQuest(Player)
	local layoutOrderCounter = 1
	for _, questInfo in DataQuest.Event do
		QuestHandler.GenerateQuest(Player, questInfo, {QuestCategory = "event", LayoutOrder = layoutOrderCounter})
		layoutOrderCounter += 1
	end
end

-- give a set of 6 quest chosen at random from weekly data in DataQuest
-- give custom quest that require all weekly category quest to be completed
function QuestHandler.GiveWeeklyQuest(Player : Player)

	for _, quest in QuestHelper.GetQuestsByCategory(Player, "weekly") do
		quest:Destroy()
	end

	local completedAllQuest = {
		QuestName = "Weekly Completed", 
		QuestDescription = "Complete all weekly Quests", 
		QuestReward = {
			Gems = 2000,
			TraitPoint = 10
		}, 
		QuestRequirement = {
			Type = "complete_all_weekly", 
			Amount = 1
		}
	}

	local layoutOrderCounter = 1

	QuestHandler.GenerateQuest(Player, completedAllQuest, {QuestCategory = "weekly", LayoutOrder = layoutOrderCounter})
	for _, questInfo in GetRandomQuest(DataQuest.Weekly, 6)  do
		layoutOrderCounter += 1
		QuestHandler.GenerateQuest(Player, questInfo, {QuestCategory = "weekly", LayoutOrder = layoutOrderCounter})
	end

end

-- find player quest that match given QuestGUID and reward player if progress fullfill the questrequirement
function QuestHandler.RedeemQuest(Player : Player, QuestGUID : string)
	if not Player:FindFirstChild("DataLoaded") or not Player:FindFirstChild("QuestsData") then return end

	local questsData = Player.QuestsData
	local quest = questsData.Quests:FindFirstChild(QuestGUID)

	if not quest then return end

	local questCompleted = QuestHelper.IsQuestComplete(Player, quest)

	if not questCompleted then return end

	for _, reward in quest.QuestInfo.QuestReward:GetChildren() do
		if reward.Name == "Gems" then
			local multiplier = 1
			pcall(function()
				if Player.OwnGamePasses["x2 Gems"].Value == true then
					multiplier = 2
				end
			end)

			Player.Gems.Value += reward.Value * multiplier
		elseif reward.Name == "TraitPoint" then
			Player.TraitPoint.Value += reward.Value
		elseif reward.Name == "Badge" then
			local badgeInfoAsync = BadgeService:GetBadgeInfoAsync(reward.Value)
			if not badgeInfoAsync or IsEnabled == false then return false end
			local awarded,error = pcall(BadgeService.AwardBadge, BadgeService, Player.UserId, reward.Value)
			print(awarded, error)
			if not awarded then return false end
		elseif reward.Name == "Eggs" then
			Player.EventData.Easter.Eggs.Value += reward.Value
		else
			warn(`reward type {reward.Name}, cannot be added to player data`)
		end
	end

	if quest.QuestCategory.Value == "daily" then
		if #QuestHelper.GetQuestsByCategory(Player, "daily") == 2 then
			QuestHandler.UpdateQuestProgress(Player, "complete_all_daily", {AddAmount = 1})
		end
	end
	if quest.QuestCategory.Value == "weekly" then
		if #QuestHelper.GetQuestsByCategory(Player, "weekly") == 2 then
			QuestHandler.UpdateQuestProgress(Player, "complete_all_weekly", {AddAmount = 1})
		end
	end
	if quest.QuestInfo:FindFirstChild("IsUnique") and quest.QuestInfo.IsUnique.Value == true then
		local boolValue = Instance.new("BoolValue")
		boolValue.Name = quest.QuestInfo.QuestId.Value
		boolValue.Value = true
		boolValue.Parent = questsData.UniqueQuestsCompleted
	end

	Message:FireClient(Player, "Redeemed Quest", Color3.fromRGB(0, 255, 8))
	quest:Destroy()
end

-- create the necessary data for a quest and load the table data as instances
function QuestHandler.GenerateQuest(Player : Player, QuestInfo : table, AdditionalInfo : AdditionalQuestInfo)

	local playerQuestsData =  Player.QuestsData
	local uniqueQuestsCompleted = playerQuestsData.UniqueQuestsCompleted
	local playerQuests = playerQuestsData.Quests

	local GUID = HttpsService:GenerateGUID(false)
	local quest = {
		[GUID] = {
			QuestInfo = QuestInfo,
			GUID = GUID,
			TimeCreated = os.time(),
			QuestProgress = {
				Amount = 0
			},
			QuestCategory = AdditionalInfo.QuestCategory,
			LayoutOrder = AdditionalInfo.LayoutOrder
		}
	}

	if QuestInfo.IsUnique then

		if  uniqueQuestsCompleted:FindFirstChild(QuestInfo.QuestId) and uniqueQuestsCompleted[QuestInfo.QuestId].Value == true then return end

		local questList = QuestHelper.GetQuestsByCategory(Player, AdditionalInfo.QuestCategory)
		for _, quest in questList do
			if quest.QuestInfo.QuestId.Value == QuestInfo.QuestId then
				return
			end
		end

	end

	DeepLoadedInstance(playerQuests, quest)

end

-- update given player quests based on the quest type and how much to increase it by
function QuestHandler.UpdateQuestProgress(Player : Player, QuestType : QuestType, AdditionalParem : UpdateProgressAdditionalParem)

	if not Player:FindFirstChild("DataLoaded") or not Player:FindFirstChild("QuestsData") then return end
	for _, quest in Player.QuestsData.Quests:GetChildren() do
		if quest.QuestInfo.QuestRequirement.Type.Value ~= QuestType then continue end

		if QuestType == "finish_level" then
			if AdditionalParem.World ~= quest.QuestInfo.QuestRequirement.World.Value then
				continue
			end
			if AdditionalParem.Level ~= quest.QuestInfo.QuestRequirement.Level.Value then
				continue
			end
		end
		if QuestType == "reach_wave" then
			if quest.QuestInfo.QuestRequirement.World.Value ~= AdditionalParem.World then
				continue
			end
			if quest.QuestInfo.QuestRequirement.Wave.Value ~= AdditionalParem.Wave then
				continue
			end
		end
		if QuestType == "clear_waves" then
			if quest.QuestInfo.QuestRequirement.World.Value ~= AdditionalParem.World then
				continue
			end
		end
		if QuestType == "summon_rarity_unit" then
			if quest.QuestInfo.QuestRequirement.Rarity.Value ~= AdditionalParem.Rarity then
				continue
			end
		end
		quest.QuestProgress.Amount.Value = math.clamp(quest.QuestProgress.Amount.Value + AdditionalParem.AddAmount, 0, quest.QuestInfo.QuestRequirement.Amount.Value)

	end

end

-- check for all exiesting quest from player, and remove any quest that has expire time and time has pass current utc time
function QuestHandler.ExpireQuests(Player)
	local questsData = Player:FindFirstChild("QuestsData")
	local quests = questsData and questsData:FindFirstChild("Quests") or nil
	if not quests then return end

	for _, quest in quests:GetChildren() do
		if not quest.QuestInfo:FindFirstChild("ExpireTime") then continue end
		if quest.QuestInfo.ExpireTime.Value > os.time() then continue end
		quest:Destroy()

	end

end


return QuestHandler
