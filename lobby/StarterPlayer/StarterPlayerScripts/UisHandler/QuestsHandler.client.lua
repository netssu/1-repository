-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- CONSTANTS
local ItemImages = {
	['Gems'] = 131476601794300,
	['Coins'] = 72741365992086,
	['Lucky Crystal'] = 76937275295988,
	['Fortunate Crystal'] = 108934606157397,
	['PowerPoint'] = 78796346246015,
	['TraitPoint'] = 122847918518753,
	['Junk Offering'] = 131781912445273,
	['LuckySpins'] = 98492072936946,
	['2x Gems'] = 121901800310394,
	['2x XP'] = 91092267447650,
	['2x Coins'] = 136969685087178,
	['RaidsRefresh'] = 131015417255816,
	["PlayerExp"] = 107130172159241,
	["Exp"] = 137556731795988,
}

local ORDER = {
	[1] = "ALL",
	[2] = "Daily",
	[3] = "Weekly",
	[4] = "Story",
	[5] = "Infinite",
	[6] = "Event"
}

-- VARIABLES
local player = Players.LocalPlayer
repeat task.wait(0.1) until player:FindFirstChild("DataLoaded")

local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local QuestsRemotes = Remotes:WaitForChild("Quests")
local ClaimQuestReward = QuestsRemotes:WaitForChild("ClaimQuestReward")
local questData = player:WaitForChild("Quests", math.huge)

local newUI = playerGui:WaitForChild("NewUI")
local questFrame = newUI:WaitForChild("Quests")
local bottomBars = questFrame:WaitForChild("BottomBars")
local dailyRefreshUI = bottomBars:WaitForChild("DailyRefresh")
local weeklyRefreshUI = bottomBars:WaitForChild("WeeklyRefresh")

local selectionFrame = questFrame:WaitForChild("Selection")
local mainContainer = questFrame:WaitForChild("Main")
local contentContainer = mainContainer:WaitForChild("Content")
local title = questFrame:WaitForChild("Header"):FindFirstChild("Title") or questFrame:WaitForChild("Header") 

local currentCategory = "ALL"

-- ENCONTRANDO OS TEMPLATES BASEADOS NA PRINT
local QuestTemplate = contentContainer:FindFirstChild("1") or contentContainer:FindFirstChild("QuestTemplate")
if QuestTemplate then QuestTemplate.Visible = false end

local RewardTemplate = nil
if QuestTemplate then
	local rewardsFrame = QuestTemplate:FindFirstChild("Rewards_Frame")
	local rewardsBar = rewardsFrame and rewardsFrame:FindFirstChild("Bar")
	RewardTemplate = rewardsBar and rewardsBar:FindFirstChild("RewardTemp")
	if RewardTemplate then RewardTemplate.Visible = false end
end

--=========================================
-- ⏰ SISTEMA DE TEMPO (Protegido no Topo)
-- Movi para cá para garantir que as barras funcionem mesmo que as Quests deem erro!
--=========================================
task.spawn(function()
	local function formatTime(seconds)
		local h = math.floor(seconds / 3600)
		local m = math.floor((seconds % 3600) / 60)
		local s = seconds % 60
		return string.format("%03d:%02d:%02d", h, m, s)
	end

	while task.wait(1) do
		local now = os.date("!*t")
		local currentTime = os.time(now)
		local weekday = now.wday
		local daysUntilNextMonday = (9 - weekday) % 7
		daysUntilNextMonday = daysUntilNextMonday == 0 and 7 or daysUntilNextMonday
		local daysSinceLastMonday = (weekday - 2) % 7

		local function timeAtDayOffset(offset)
			local offsetDay = {year = now.year, month = now.month, day = now.day + offset, hour = 0, min = 0, sec = 0}
			return os.time(offsetDay)
		end

		local lastMonday = timeAtDayOffset(-daysSinceLastMonday)
		local nextMonday = timeAtDayOffset(daysUntilNextMonday)

		-- Atualização Segura da Barra Semanal (Procura em qualquer nível de pasta)
		local weeklyProgress = math.clamp((currentTime - lastMonday) / (nextMonday - lastMonday), 0, 1)
		if weeklyRefreshUI then
			local fill = weeklyRefreshUI:FindFirstChild("Fill", true)
			local timerLabel = weeklyRefreshUI:FindFirstChild("Timer", true) or weeklyRefreshUI:FindFirstChild("TextLabel", true)
			if fill then fill.Size = UDim2.new(weeklyProgress, 0, 1, 0) end
			if timerLabel then timerLabel.Text = formatTime(nextMonday - currentTime) end
		end

		-- Atualização Segura da Barra Diária
		local secondsInDay = 86400
		local secondsPassedToday = now.hour * 3600 + now.min * 60 + now.sec
		local dailyProgress = math.clamp(secondsPassedToday / secondsInDay, 0, 1)
		if dailyRefreshUI then
			local fill = dailyRefreshUI:FindFirstChild("Fill", true)
			local timerLabel = dailyRefreshUI:FindFirstChild("Timer", true) or dailyRefreshUI:FindFirstChild("TextLabel", true)
			if fill then fill.Size = UDim2.new(dailyProgress, 0, 1, 0) end
			if timerLabel then timerLabel.Text = formatTime(secondsInDay - secondsPassedToday) end
		end
	end
end)


--=========================================
-- 🛡️ FUNÇÕES PRINCIPAIS DE MISSÕES
--=========================================
local function getUI(parent, name)
	if not parent then return nil end
	local exact = parent:FindFirstChild(name)
	if exact then return exact end
	for _, child in ipairs(parent:GetChildren()) do
		if string.lower(child.Name) == string.lower(name) then return child end
	end
	return nil
end

local function getCurrentPart(questline)
	if not questline then return nil end
	local partsFolder = questline:FindFirstChild("Parts")
	if not partsFolder then return nil end -- Proteção extra contra pastas inexistentes

	for _, part in ipairs(partsFolder:GetChildren()) do
		local claimed = part:FindFirstChild("Claimed")
		if claimed and not claimed.Value then
			return part
		end
	end
	return nil
end

local function setupRewardDisplay(rewards, holder)
	if not holder or not rewards or not RewardTemplate then return end

	for _, existing in ipairs(holder:GetChildren()) do
		if existing:IsA("GuiObject") and existing ~= RewardTemplate and existing.Name ~= "UIListLayout" then
			existing:Destroy()
		end
	end

	for _, rewardFolder in pairs(rewards:GetChildren()) do
		local amount = rewardFolder:FindFirstChild("Amount")
		if amount and amount.Value > 0 then
			local rewardTemp = RewardTemplate:Clone()
			local contents = rewardTemp:FindFirstChild("Contents") or rewardTemp

			local amountLabel = contents:FindFirstChild("Amount")
			local iconImage = contents:FindFirstChild("Icon")

			if amountLabel then amountLabel.Text = "+" .. amount.Value end
			if iconImage then iconImage.Image = ItemImages[rewardFolder.Name] and "rbxassetid://"..ItemImages[rewardFolder.Name] or "" end

			rewardTemp.Name = rewardFolder.Name
			rewardTemp.Visible = true
			rewardTemp.Parent = holder
		end
	end
end

local function setupQuestTemplate(quest, questTemp)
	local titleText = nil
	local description = quest:FindFirstChild("Description")
	local progress = quest:FindFirstChild("Progress")
	local goal = quest:FindFirstChild("Goal")
	local questType = quest.Parent and quest.Parent.Parent or {Name = "Unknown"}

	local claim = questTemp:FindFirstChild("Claim") or questTemp:FindFirstChild("Bg") or questTemp
	questTemp:SetAttribute("QuestType", questType.Name or "Unknown")

	local rewardsFrame = questTemp:FindFirstChild("Rewards_Frame")
	local rewardsBar = rewardsFrame and rewardsFrame:FindFirstChild("Bar")

	local function updateProgressBar(currentProgress, progressGoal)
		pcall(function() -- Evita crash na interface caso os valores do servidor falhem
			local rewardFolder = quest:FindFirstChild("Reward")
			if rewardsBar and rewardFolder then setupRewardDisplay(rewardFolder, rewardsBar) end

			local ratio, progressValue, goalValue = 0, 0, 0
			if currentProgress and progressGoal and progressGoal.Value ~= 0 then
				progressValue = currentProgress.Value
				goalValue = progressGoal.Value
				ratio = math.clamp(progressValue / goalValue, 0, 1)
			end

			local barFrame = questTemp:FindFirstChild("Bar")
			local innerBar = barFrame and barFrame:FindFirstChild("Bar")
			local fillBar = innerBar and innerBar:FindFirstChild("Fill")
			local progressTextLabel = questTemp:FindFirstChild("Progress")

			if fillBar then fillBar.Size = UDim2.new(ratio, 0, 1, 0) end
			if progressTextLabel then progressTextLabel.Text = ("PROGRESS %d/%d"):format(progressValue, goalValue) end

			local statusLabel = claim:FindFirstChild("TextLabel") or claim:FindFirstChild("Status")
			if statusLabel then
				statusLabel.Text = progressValue >= goalValue and "Completed" or "Incomplete"
			end
		end)
	end

	if progress and goal then
		local questNameObj = quest:FindFirstChild("QuestName")
		titleText = questNameObj and questNameObj.Value or nil
		updateProgressBar(progress, goal)
		progress.Changed:Connect(function() updateProgressBar(progress, goal) end)
		goal.Changed:Connect(function() updateProgressBar(progress, goal) end)
	else
		local part, partProgress, partGoal, partClaimed = nil, nil, nil, nil

		local function updatePartInformation()
			local success, err = pcall(function() -- Escudo de segurança para a linha 157
				part = getCurrentPart(quest)
				local statusLabel = claim:FindFirstChild("TextLabel") or claim:FindFirstChild("Status")

				if not part then 
					if statusLabel then statusLabel.Text = "Finished" end
					return 
				end

				partProgress = part:FindFirstChild("Progress")
				partGoal = part:FindFirstChild("Goal")
				partClaimed = part:FindFirstChild("Claimed")

				local partNameObj = part:FindFirstChild("PartName")
				titleText = partNameObj and partNameObj.Value or nil

				local titleQuestLabel = questTemp:FindFirstChild("TitleQuest")
				if titleText and titleQuestLabel then titleQuestLabel.Text = titleText end

				local ratio = 0
				if partProgress and partGoal and partGoal.Value ~= 0 then
					ratio = math.clamp(partProgress.Value / partGoal.Value, 0, 1)
				end

				local barFrame = questTemp:FindFirstChild("Bar")
				local innerBar = barFrame and barFrame:FindFirstChild("Bar")
				local fillBar = innerBar and innerBar:FindFirstChild("Fill")
				if fillBar then fillBar.Size = UDim2.new(ratio, 0, 1, 0) end

				local progressTextLabel = questTemp:FindFirstChild("Progress")
				if progressTextLabel and partProgress and partGoal then
					progressTextLabel.Text = ("PROGRESS %d/%d"):format(partProgress.Value, partGoal.Value)
				end

				if statusLabel and partProgress and partGoal then
					statusLabel.Text = partProgress.Value >= partGoal.Value and "Completed" or "Incomplete"
				end

				local rewardFolder = part:FindFirstChild("Reward")
				if rewardsBar and rewardFolder then setupRewardDisplay(rewardFolder, rewardsBar) end
			end)

			if not success then
				warn("[Quests] Erro silenciado ao atualizar parte da missão (provável ausência de dados do servidor):", err)
			end
		end

		updatePartInformation()

		if partProgress then partProgress.Changed:Connect(updatePartInformation) end
		if partClaimed then partClaimed.Changed:Connect(updatePartInformation) end
	end

	local titleQuestLabel = questTemp:FindFirstChild("TitleQuest")
	if titleText and titleQuestLabel then titleQuestLabel.Text = titleText end

	local descLabel = questTemp:FindFirstChild("Description")
	if description and descLabel then descLabel.Text = description.Value end

	local function claimQuest()
		local response = ClaimQuestReward:InvokeServer(quest)
		local statusLabel = claim:FindFirstChild("TextLabel") or claim:FindFirstChild("Status")
		if response and statusLabel then statusLabel.Text = "Claimed" end
	end

	if claim:IsA("GuiButton") then claim.Activated:Connect(claimQuest) end
	local claimEvent = questTemp:FindFirstChild("Claim")
	if claimEvent and typeof(claimEvent) == "BindableEvent" then claimEvent.Event:Connect(claimQuest) end

	local wipe = quest:FindFirstChild("Wipe")
	if wipe and wipe.Value then
		local ancestryConn
		ancestryConn = quest.AncestryChanged:Connect(function(child, parent)
			if not parent then
				if questTemp and questTemp.Parent then questTemp:Destroy() end
				if ancestryConn then ancestryConn:Disconnect() end
			end
		end)
	end
end

-- RENDERIZAÇÃO SINGLE-PAGE
local function renderQuests(category)
	if not QuestTemplate then return end

	for _, child in ipairs(contentContainer:GetChildren()) do
		if child:IsA("GuiObject") and child ~= QuestTemplate and child.Name ~= "UIListLayout" then
			child:Destroy()
		end
	end

	local function spawnQuests(folderName)
		local data = questData:FindFirstChild(folderName)
		local questsFolder = data and data:FindFirstChild("Quests")
		if not questsFolder then return end

		for _, quest in ipairs(questsFolder:GetChildren()) do
			local questTemp = QuestTemplate:Clone()
			questTemp.Name = quest.Name
			questTemp.Visible = true
			setupQuestTemplate(quest, questTemp)
			questTemp.Parent = contentContainer
		end
	end

	if category == "ALL" then
		for _, name in ipairs(ORDER) do
			if name ~= "ALL" then
				spawnQuests(name .. "Quests")
			end
		end
	else
		spawnQuests(category .. "Quests")
	end
end

local function SwitchToCategory(categoryName)
	if currentCategory == categoryName then return end
	currentCategory = categoryName

	if title and title:IsA("TextLabel") then
		title.Text = categoryName .. " Quests"
	end

	renderQuests(currentCategory)
end

-- INIT
local function init()
	for index, questType in ipairs(ORDER) do
		local categoryFolder = getUI(selectionFrame, questType)
		if categoryFolder then
			categoryFolder.LayoutOrder = index 
			local button = categoryFolder:FindFirstChild("Btn")

			if button and button:IsA("GuiButton") then
				button.Activated:Connect(function() 
					SwitchToCategory(questType) 
				end)
			end
		end
	end

	if title and title:IsA("TextLabel") then title.Text = currentCategory.." Quests" end
	renderQuests(currentCategory)
end

task.wait(1)
init()

QuestsRemotes.RefreshClientQuests.OnClientEvent:Connect(function(refreshType)
	if currentCategory == "ALL" or currentCategory == refreshType then
		renderQuests(currentCategory)
	end
end)