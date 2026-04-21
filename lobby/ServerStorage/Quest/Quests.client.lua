print("oi2")
local TweenService = game:GetService("TweenService")
local BadgeService = game:GetService("BadgeService")

local RedeemQuest = game.ReplicatedStorage.Functions.RedeemQuest

local QuestHelper = require(game.ReplicatedStorage.Modules.QuestHelper)
local UIHandler = require(game.ReplicatedStorage.Modules.Client.UIHandler)

local Player = game.Players.LocalPlayer
local QuestsData = Player.QuestsData

local Main = script.Parent.QuestFrame.Frame.Quests.Contents
local TemplatesFolder = Main.Templates
local QuestHolder = Main
local QuestCategoryList = script.Parent.QuestFrame.Frame.Bottom_Bar.Bottom_Bar
local RefreshTracker = script.Parent.QuestFrame.Frame.Refresh_Tracker

local TrackQuests = {}
local CurrentTransitionTween = nil
local CategoriesUI = {}
local TotalCategories = 0
local UpdatedTimerCallbacks = {

}

local function numbertotime(number)
	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) %60
	local Seconds = math.floor(number % 60)

	if Mintus < 10 and Hours > 0 then
		Mintus = "0"..Mintus
	end

	if Seconds < 10 then
		Seconds = "0"..Seconds
	end

	if Hours > 0 then
		return `{Hours}:{Mintus}:{Seconds}`
	else
		return `{Mintus}:{Seconds}`
	end
end

function QuestAdded(quest : Folder)

	local function isComplete()
		return quest.QuestProgress.Amount.Value >= quest.QuestInfo.QuestRequirement.Amount.Value
	end

	local function activateClaimButton()
		local trackerData = TrackQuests[quest.GUID.Value]
		if not trackerData then return end

		for _, ui in trackerData.Guis do
			ui.Contents.Claim.Visible = true
			--ui.Claim.TextLabel.Text = "Claim"

			ui.Contents.Claim.MouseButton1Down:Connect(function() RedeemQuest:InvokeServer(quest.GUID.Value) end)

		end
	end

	local function updateQuestProgress()
		local trackerData = TrackQuests[quest.GUID.Value]
		if not trackerData then return end
		local questCompleted, questAmount, questRequireAmount = QuestHelper.IsQuestComplete(Player, quest)

		for _, ui in trackerData.Guis do
			ui.Contents.Progress.Text = `Progress: {questAmount}/{questRequireAmount}`
			ui.Contents.Incomplete.Contents.ProgressBar.Front.Size = UDim2.fromScale(questAmount/questRequireAmount, 1)
		end

		if questCompleted then
			activateClaimButton()
		end
	end
	
	
	local baseLayoutOrder = {	--used for when its in all category
		daily = 0,
		weekly = 100,
		infinite = 200,
		story = 300,
		event = 400
	}

	--load quest to ui
	local loadedList = {
		QuestInfo = false,
		QuestCategory = false,
		QuestDescription = false
	}

	local allLoaded = false
	repeat 
		local loadCount = 0
		for name, loaded in loadedList do
			if loaded then loadCount += 1 continue end

			if name == "QuestDescription" and loadedList["QuestInfo"] then
				loadedList[name] = quest.QuestInfo:FindFirstChild(name)
			else
				loadedList[name] = quest:FindFirstChild(name)
			end


		end
		if loadCount == 3 then
			allLoaded = true
		end
		task.wait(0.1)
	until allLoaded or quest.Parent == nil

	if not allLoaded then return end

	local questInfo = loadedList["QuestInfo"] --quest:WaitForChild("QuestInfo")
	local questCategory = loadedList["QuestCategory"]--quest:WaitForChild("QuestCategory")
	local questDescription = loadedList["QuestDescription"]--questInfo:WaitForChild("QuestDescription")

	if quest.QuestCategory.Value == "story" then
		local completeQuest = QuestHelper.IsQuestComplete(Player, quest)
		if questInfo.QuestRequirement.World.Value ~= Player.StoryProgress.World.Value and not completeQuest then
			return
		end
	end

	local catClone = TemplatesFolder.QuestTemplate:Clone()
	catClone.Contents.Text.Title.Text = questInfo.QuestName.Value
	catClone.Contents.Text.Subtext.Text = questInfo.QuestDescription.Value
	catClone.Visible = true
	catClone.LayoutOrder = baseLayoutOrder[quest.QuestCategory.Value] + quest.LayoutOrder.Value
	--catClone.QuestProgress.Text = `{quest.QuestProgress.Amount.Value}/{questInfo.QuestRequirement.Amount.Value}`
	catClone.Parent = QuestHolder.Internal[quest.QuestCategory.Value]
	
	--Display the rewards
	for _, reward in questInfo.QuestReward:GetChildren() do
		if reward.Name == "Badge" then
			local success, badgeAsyncInfo = pcall(function() return BadgeService:GetBadgeInfoAsync(reward.Value)  end) 
			if not success then continue end
			catClone.Contents.Rewards_Frame.Bar[reward.Name].Visible = true
			catClone.Contents.Rewards_Frame.Bar[reward.Name].Contents.Icon.Image =`rbxassetid://{badgeAsyncInfo.IconImageId}` 


		elseif catClone.Contents.Rewards_Frame.Bar:FindFirstChild(reward.Name) then
			catClone.Contents.Rewards_Frame.Bar[reward.Name].Visible = true
			catClone.Contents.Rewards_Frame.Bar[reward.Name].Contents.Amount.Text = `x{reward.Value}`
		else
			warn(`reward type cannot be find for {reward.Name} in Quest`)
		end
	end
	

	
	local allClone = catClone:Clone()
	allClone.Parent = QuestHolder.Internal.all

	local trackerData = {
		Guis = {
			catClone,
			allClone
		}
	}

	TrackQuests[quest.GUID.Value] = trackerData
	updateQuestProgress()
	quest.QuestProgress.Amount.Changed:Connect(updateQuestProgress)
	
	if questInfo:FindFirstChild("ExpireTime") then
		catClone.Contents.ExpireTimer.Visible = true
		allClone.Contents.ExpireTimer.Visible = true
		
		local disconnect; disconnect = ListenForUpdatedTime(function(currentTime)
			if quest.Parent == nil or catClone.Parent == nil then
				disconnect()
				return
			end
			local timeRemaining = questInfo.ExpireTime.Value - currentTime
			catClone.Contents.ExpireTimer.Text = `{numbertotime( timeRemaining )}`
			allClone.Contents.ExpireTimer.Text = `{numbertotime( timeRemaining )}`
		end)
	end
	
end

function QuestRemove(quest : Folder)
	local trackerData = TrackQuests[quest.Name]
	if not trackerData then return end
	TrackQuests[quest.Name] = nil

	for _, ui in trackerData.Guis do
		TweenService:Create(ui, TweenInfo.new(0.1), {Size = UDim2.fromScale(0,0)}):Play()

		task.delay(0.1, function()
			ui:Destroy()
		end)
	end
end

function UpdateQuestCategory(category : string)
	local categoryUI = QuestCategoryList[category]
	local newMainXPosition =  -categoryUI.LayoutOrder + 1 --+ 0.5 -- + 0.495 + 0.5

	--for _, ui in CategoriesUI do
	--	if ui.Name == category then
	--		ui.UISelected.Visible = true
	--	else
	--		ui.UISelected.Visible = false
	--	end
	--end

	CurrentTransitionTween = TweenService:Create(QuestHolder.Internal, TweenInfo.new(0.2), {
		Position = UDim2.fromScale(newMainXPosition, 0.5)
	})
	CurrentTransitionTween:Play()

end

function ListenForUpdatedTime(callback : (currentTime : number) -> ())
	if typeof(callback) ~= "function" then warn("GIVEN ARGUMENT IS NOT A FUNCTION") return end
	table.insert(UpdatedTimerCallbacks, callback)
	
	local insertedIndex = #UpdatedTimerCallbacks
	local alreadyDisconnected = false
	local function disconnect()
		if alreadyDisconnected then return end
		if UpdatedTimerCallbacks[insertedIndex] == callback then
			table.remove(UpdatedTimerCallbacks, insertedIndex)
			alreadyDisconnected = true
		end
	end
	
	return disconnect
end

script.Parent.QuestFrame.Frame.X_Close.Activated:Connect(function()
	_G.CloseAll()
	UIHandler.EnableAllButtons()
end)

QuestsData.Quests.ChildAdded:Connect(QuestAdded)
QuestsData.Quests.ChildRemoved:Connect(QuestRemove)

for _, quest in QuestsData.Quests:GetChildren() do
	pcall(QuestAdded, quest)
end

for _, button in QuestCategoryList:GetChildren() do
	if not button:IsA("GuiButton") then continue end
	TotalCategories += 1
	CategoriesUI[button.Name] = button
	button.MouseButton1Down:Connect(function() UpdateQuestCategory(button.Name) end)
end

for _, ui : GuiBase in RefreshTracker:GetChildren() do
	local refreshInfo
	local list = {
		Daily_Reset_Bar = {
			ResetTimeInterval = 86400,
			LastResetDataValue = QuestsData.LastDailyQuestTime
		},
		Weekly_Reset_Bar = {
			ResetTimeInterval = 604800,
			LastResetDataValue = QuestsData.LastWeeklyQuestTime
		}
	}

	refreshInfo = list[ui.Name]
	if not refreshInfo then continue end

	local bar = ui.Contents.Bar
	local timer = ui.Contents.Timer

	ListenForUpdatedTime(function(currentTime)
		local timeRemaining = math.max(
			0, 
			refreshInfo.ResetTimeInterval - (currentTime - refreshInfo.LastResetDataValue.Value)
		)
		local percent = math.clamp( 
			timeRemaining/refreshInfo.ResetTimeInterval,
			0,
			1
		)
		
		bar.Size = UDim2.fromScale(percent, 1)
		timer.Text = numbertotime(timeRemaining)
	end)

end


UpdateQuestCategory("all")

local lastTimeCheck = 0
game["Run Service"].Heartbeat:Connect(function()
	if tick() - lastTimeCheck < 1 then return end
	lastTimeCheck = tick()
	for index, func in UpdatedTimerCallbacks do
		func(os.time())
	end
end)
