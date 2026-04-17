if true then return end

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MPS = game:GetService("MarketplaceService")

-- Player Setup
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--repeat task.wait() until player:FindFirstChild("DataLoaded")

-- Remotes
local ClaimQuestReward = ReplicatedStorage.Remotes.Quests.ClaimQuestReward

-- Quest Data
local questData = player.Quests
local dailyData = questData.DailyQuests
local weeklyData = questData.WeeklyQuests
local storyData = questData.StoryQuests
local infiniteData = questData.InfiniteQuests
--local eventData = questData.EventQuests

-- UI References
local questFrame = playerGui.CoreGameUI.Quests.QuestFrame.Main
local refreshTracker = questFrame.Refresh_Tracker
local quests = questFrame.Quests
local questHolders = quests.Contents
local buttons = questFrame.Parent.Buttons
local title = questFrame.Title

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

questFrame.X_Close.Activated:Connect(function()
	_G.CloseAll("QuestFrame")
end)

local transitioning = false
local currentCategory = "All"
local order = {
	[1] = "All",
	[2] = "Daily",
	[3] = "Weekly",
	[4] = "Story",
	[5] = "Infinite",
	[6] = "Event"
}

local QuestCategoryList = {}
for _, page in ipairs(questHolders:GetChildren()) do
	if page:IsA("ScrollingFrame") then
		QuestCategoryList[page.Name] = page
	end
end
QuestCategoryList[currentCategory].Visible = true
title.Text = currentCategory.." Quests"

local function SwitchToCategory(categoryName)
	if categoryName == currentCategory or transitioning then return end

	local incoming: ScrollingFrame = QuestCategoryList[categoryName]
	local outgoing: ScrollingFrame = QuestCategoryList[currentCategory]

	if not incoming or not outgoing then return end

	local currentIndex, newIndex
	for i, name in ipairs(order) do
		if name == currentCategory then currentIndex = i end
		if name == categoryName then newIndex = i end
	end

	if not currentIndex or not newIndex then return end

	local direction = (newIndex > currentIndex) and 1 or -1

	incoming.Position = UDim2.fromScale(0.5 + direction, 0.5)
	incoming.Visible = true

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local inTween = TweenService:Create(incoming, tweenInfo, {
		Position = UDim2.fromScale(0.5, 0.5)
	})
	local outTween = TweenService:Create(outgoing, tweenInfo, {
		Position = UDim2.fromScale(0.5 - direction, 0.5)
	})

	transitioning = true
	inTween:Play()
	outTween:Play()

	inTween.Completed:Connect(function()
		outgoing.Visible = false
		transitioning = false
		title.Text = categoryName.." Quests"
		currentCategory = categoryName
	end)
end

SwitchToCategory("All")

local function getCurrentPart(questline)
	for _, part in ipairs(questline.Parts:GetChildren()) do
		if not part.Claimed.Value then
			return part or nil
		end
	end
end

local function setupRewardDisplay(rewards, holder)
	local rewardTexts = {}

	for _, existing in ipairs(holder:GetChildren()) do
		if existing:IsA("GuiObject") then
			existing:Destroy()
		end
	end

	for _, rewardFolder in pairs(rewards:GetChildren()) do
		local amount = rewardFolder:FindFirstChild("Amount")
		if amount and amount.Value > 0 then
			local rewardTemp = script.Templates.RewardTemp:Clone()
			rewardTemp.Contents.Amount.Text = "+" .. amount.Value
			rewardTemp.Name = rewardFolder.Name
			rewardTemp.Contents.Icon.Image = ItemImages[rewardFolder.Name] and "rbxassetid://"..ItemImages[rewardFolder.Name] or ""

			rewardTemp.Parent = holder
		end
	end
end

local function setupQuestTemplate(quest, questTemp)
	local titleText = nil
	local description = quest:FindFirstChild("Description")
	local progress = quest:FindFirstChild("Progress")
	local goal = quest:FindFirstChild("Goal")
	local claim = questTemp.ClaimButton
	local questType = quest.Parent.Parent

	questTemp:SetAttribute("QuestType", questType.Name or "Unknown")

	local function updateProgressBar(currentProgress, progressGoal)
		setupRewardDisplay(quest.Reward, questTemp.Rewards_Frame.Bar)

		local ratio = 0
		local progressValue = 0
		local goalValue = 0

		if currentProgress and progressGoal and progressGoal.Value ~= 0 then
			progressValue = currentProgress.Value
			goalValue = progressGoal.Value
			ratio = math.clamp(progressValue / goalValue, 0, 1)
		end

		if questTemp and questTemp:FindFirstChild("ClaimButton") then
			local bar = questTemp.MainProgress.Progress.Bar
			local label = questTemp:FindFirstChild("ClaimButton"):FindFirstChild("TextLabel")
			if bar and label then
				bar.Size = UDim2.new(ratio, 0, 1, 0)
				questTemp.Progress.Text = ("Progress %d/%d"):format(progressValue, goalValue)

				label.Text = progressValue >= goalValue and "Completed" or "Incomplete"
			end
		end
	end

	if progress and goal then
		titleText = quest:FindFirstChild("QuestName") and quest.QuestName.Value or nil
		updateProgressBar(progress, goal)

		progress.Changed:Connect(function()
			updateProgressBar(progress, goal)
		end)
		
		goal.Changed:Connect(function()
			updateProgressBar(progress, goal)
		end)
	else
		local part = nil
		
		local partProgress = nil 
		local partGoal = nil
		local partClaimed = nil

		local function updatePartInformation()
			part = getCurrentPart(quest)
			if not part then claim.TextLabel.Text = "Finished" return end
			
			
			partProgress = part:FindFirstChild("Progress")
			partGoal = part:FindFirstChild("Goal")
			partClaimed = part:FindFirstChild("Claimed")
			
			titleText = part:FindFirstChild("PartName").Value
			
			if titleText then
				questTemp.Title.Text = titleText
			end
			
			local ratio = math.clamp(partProgress.Value / partGoal.Value, 0, 1)
			questTemp.MainProgress.Progress.Bar.Size = UDim2.new(ratio, 0, 1, 0)
			questTemp.Progress.Text = ("Progress %d/%d"):format(partProgress.Value, partGoal.Value)

			if partProgress.Value >= partGoal.Value then
				claim.TextLabel.Text = "Completed"
			else
				claim.TextLabel.Text = "Incomplete"
			end
			
			partProgress.Changed:Connect(updatePartInformation)
			partClaimed.Changed:Connect(updatePartInformation)
			
			
			setupRewardDisplay(part.Reward, questTemp.Rewards_Frame.Bar)
		end
		
		updatePartInformation()


	end

	if titleText then
		questTemp.Title.Text = titleText
	end
	if description then
		questTemp.Description.Text = description.Value
	end

	local function claimQuest()
		if claim.TextLabel.Text == 'Claimed' then return end
		local response = ClaimQuestReward:InvokeServer(quest)
		if response then
			claim.TextLabel.Text = "Claimed"
		end
	end

	claim.Activated:Connect(claimQuest)
	questTemp.Claim.Event:Connect(claimQuest)

	local wipe = quest:FindFirstChild("Wipe")
	if wipe and wipe.Value then
		local ancestryConn

		ancestryConn = quest.AncestryChanged:Connect(function(child, parent)
			if not parent then
				if questTemp and questTemp.Parent then
					questTemp:Destroy()
				end
				if ancestryConn then
					ancestryConn:Disconnect()
				end
			end
		end)
	end
end

local function refreshQuests(questType)
	local holder: ScrollingFrame = questHolders:FindFirstChild(questType)
	if not holder then warn("Quest type: "..questType.." not found for refresh.") return end
	
	for _, frame in ipairs(holder:GetChildren()) do
		if frame:IsA("Frame") then
			frame:Destroy()
		end
	end
	
	local data = questData:FindFirstChild(questType.."Quests")
	if not data then warn("No quest data found for: "..questType.."Quests") end

	for _, quest in ipairs(data.Quests:GetChildren()) do
		local questTemp = script.Templates.QuestTemplate:Clone()
		questTemp.Name = quest.Name

		setupQuestTemplate(quest, questTemp)
		questTemp.Parent = holder

		local allClone = script.Templates.QuestTemplate:Clone()
		allClone.Name = quest.Name
		setupQuestTemplate(quest, allClone)
		allClone.Parent = questHolders.All
	end
end


local function init()
	for index, questType in order do
		local button: GuiButton = buttons:FindFirstChild(questType)
		if button then
			button.LayoutOrder = index
			button.Activated:Connect(function()
				SwitchToCategory(questType)
			end)
		end

		local data = questData:FindFirstChild(questType.."Quests")
		if not data then warn("No quest data found for: "..questType.."Quests") end

		local questFol = data and data.Quests or nil
		local holder = questHolders:FindFirstChild(questType)

		if questFol then
			for _, quest in ipairs(questFol:GetChildren()) do
				local questTemp = script.Templates.QuestTemplate:Clone()
				questTemp.Name = quest.Name

				setupQuestTemplate(quest, questTemp)
				questTemp.Parent = holder

				local allClone = script.Templates.QuestTemplate:Clone()
				allClone.Name = quest.Name
				setupQuestTemplate(quest, allClone)
				allClone.Parent = questHolders.All
			end
		end
	end
end

init()

spawn(function()
	while task.wait(1) do
		local now = os.date("!*t")
		local currentTime = os.time(now)

		local weekday = now.wday
		local daysUntilNextMonday = (9 - weekday) % 7
		daysUntilNextMonday = daysUntilNextMonday == 0 and 7 or daysUntilNextMonday
		local daysSinceLastMonday = (weekday - 2) % 7

		local function timeAtDayOffset(offset)
			local offsetDay = {
				year = now.year,
				month = now.month,
				day = now.day + offset,
				hour = 0,
				min = 0,
				sec = 0
			}
			return os.time(offsetDay)
		end

		local lastMonday = timeAtDayOffset(-daysSinceLastMonday)
		local nextMonday = timeAtDayOffset(daysUntilNextMonday)

		local totalWeekSeconds = nextMonday - lastMonday
		local secondsPassedThisWeek = currentTime - lastMonday
		local weeklyProgress = math.clamp(secondsPassedThisWeek / totalWeekSeconds, 0, 1)

		refreshTracker.Weekly_Reset_Bar.Contents.Bar.Size = UDim2.new(weeklyProgress, 0, 1, 0)

		local function formatTime(seconds)
			local h = math.floor(seconds / 3600)
			local m = math.floor((seconds % 3600) / 60)
			local s = seconds % 60
			return string.format("%03d:%02d:%02d", h, m, s)
		end

		refreshTracker.Weekly_Reset_Bar.Contents.Timer.Text = formatTime(nextMonday - currentTime)

		local secondsInDay = 86400
		local secondsPassedToday = now.hour * 3600 + now.min * 60 + now.sec
		local dailyProgress = math.clamp(secondsPassedToday / secondsInDay, 0, 1)

		refreshTracker.Daily_Reset_Bar.Contents.Bar.Size = UDim2.new(dailyProgress, 0, 1, 0)
		refreshTracker.Daily_Reset_Bar.Contents.Timer.Text = formatTime(secondsInDay - secondsPassedToday)
	end
end)


ReplicatedStorage.Remotes.Quests.RefreshClientQuests.OnClientEvent:Connect(function(refreshType)
	refreshQuests(refreshType)
end)