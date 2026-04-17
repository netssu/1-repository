-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MPS = game:GetService("MarketplaceService")

-- Modules
local BpConfig = require(game.ReplicatedStorage.Configs.BattlepassConfig)
local EpConfig = require(game.ReplicatedStorage.EpisodeConfig)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

-- Data Loading
local player = game.Players.LocalPlayer
local playerGui = player.PlayerGui

repeat task.wait() until player:FindFirstChild("DataLoaded")

-- Remotes
local ClaimBattlepassReward = ReplicatedStorage.Remotes.Quests.ClaimBattlepassReward
local ClaimQuestReward = ReplicatedStorage.Remotes.Quests.ClaimQuestReward

-- Variables
local bpData = player.BattlepassData


local bpFrame = playerGui:WaitForChild("CoreGameUI").Battlepass.BattlepassFrame
local shop = bpFrame.Side_Shop
local rewardHolder = bpFrame.Core.Contents.Rewards_Frame.Bar
local TierFrame = script.TierTemplate
local GiftFolder = playerGui.CoreGameUI.Gift
local GiftFrame = GiftFolder.GiftFrame
local PremiumFrame = bpFrame.Core["Premium Battlepass"]
local QuestFrame = bpFrame.Core.Pass_Quests
local RewardFrame = bpFrame.Core.Contents
local SelectedGiftId = GiftFolder.SelectedGiftId
local Functions = game.ReplicatedStorage:WaitForChild("Functions")
local GetMarketInfoByName = Functions:WaitForChild("GetMarketInfoByName")
local BuyEvent = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("Buy")

local Season = BpConfig.GetSeason()
local Tiers = BpConfig.Tiers[Season]
local lastInfTier = bpData.Tier.Value

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


-- Helper funcs

local function formatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", h, m, s)
end


function NewTokenUI(ui)
	local BuyButton = ui:WaitForChild("Buy")
	local GiftButton = ui:WaitForChild("Gift")
	
	
	local Info = GetMarketInfoByName:InvokeServer(ui.Parent.Name) --Market.GetInfoOfName(ui.Name)

	warn(Info)

	BuyButton.MouseButton1Down:Connect(function()
		BuyEvent:FireServer(Info.Id)
	end)

	GiftButton.MouseButton1Down:Connect(function()
		SelectedGiftId.Value = Info.GiftId
		GiftFrame.Visible = true
	end)

end

function NewOtherTokenUI(ui)
	for i,v in ui:GetChildren() do
		if v:IsA("Frame") then
			for i,value in v:GetChildren() do
				warn("Value is: ", value.Name)
				local BuyButton = value:WaitForChild("Buy")
				local GiftButton = value:WaitForChild("Gift")
				
				local Info = GetMarketInfoByName:InvokeServer(value.Parent.Name) --Market.GetInfoOfName(ui.Name)

				BuyButton.MouseButton1Down:Connect(function()
					BuyEvent:FireServer(Info.Id)
				end)

				GiftButton.MouseButton1Down:Connect(function()
					SelectedGiftId.Value = Info.GiftId
					GiftFrame.Visible = true
				end)		
			end
		end
	end

end

bpFrame.Core.X_Close.Activated:Connect(function()
	_G.CloseAll("BattlepassFrame")
end)

bpFrame.Core["Premium Battlepass"].Contents.Buy.Activated:Connect(function()
	MPS:PromptProductPurchase(player, 3296909141)
end)

local skipProducts = {
	[1] = {Normal = 3279744329, Gift = 3281245102},
	[5] = {Normal = 3286932503, Gift = 3286932640},
	[10] = {Normal = 3279744407, Gift = 3280425048},
}

for _, skipFrame in ipairs(shop.Contents:GetChildren()) do
	if skipFrame:IsA("Frame") and skipFrame.Name:find("Skip_") then
		local skipAmount = tonumber(skipFrame.Name:match("Skip_(%d+)"))
		if skipProducts[skipAmount] then
			skipFrame.Contents.Buy.Activated:Connect(function()
				MPS:PromptProductPurchase(player, skipProducts[skipAmount].Normal)
			end)
		end
	end
end


local function setupFrame(frame, reward)
	if reward.Special then
		if reward.Special == "Unit" then
			local displayIcon = frame.Reward.Contents.DisplayIcon
			local isShiny = reward.Title:find("SHINY") ~= nil
			local unitName = isShiny and reward.Title:split("SHINY ")[2] or reward.Title
			
			local newVP = ViewPortModule.CreateViewPort(unitName, isShiny)
			if newVP then
				newVP.ZIndex = displayIcon.ZIndex
				newVP.Position = displayIcon.Position
				newVP.Size = displayIcon.Size
				newVP.AnchorPoint = displayIcon.AnchorPoint
				newVP.Parent = displayIcon.Parent
				displayIcon:Destroy()
			end
		end
	else
		if ItemImages[reward.Title] then
		--print(reward.Title)
			frame.Reward.Contents.DisplayIcon.Image = "rbxassetid://"..ItemImages[reward.Title]
		else
			warn("image nf for: "..reward.Title)
		end 

	end
	
	if reward.Amount then
		frame.Reward.Contents.AmountLabel.Text = tostring(reward.Amount)
	end
end

for _, ui in bpFrame.Core["Premium Battlepass"]:GetChildren() do
	NewTokenUI(ui)
end

for _, ui in bpFrame:GetChildren() do
	if ui.Name == "Side_Shop" then
		NewOtherTokenUI(ui.Contents)
	end
end

local function updateStatus(tier)
	local tierName = "Tier" .. tier
	--print("Updating status for:", tierName)

	local tierFrame = rewardHolder:FindFirstChild(tierName)
	if not tierFrame then
		return
	end
	
	task.spawn(function()
		for i = 1, tier do
			if bpData.Tier.Value >= i then
				local fillerTier = rewardHolder:FindFirstChild("Tier"..i)
				if fillerTier then
					fillerTier.TierDisplay.Level_Template.Contents.Locked.Visible = false
				end
			end
		end
	end)

	local tierData = bpData.TiersClaimed:FindFirstChild(tierName)
	if not tierData then
		--warn("No tier data found for", tierName)
		return
	end

	local freeClaimed = false
	local premiumClaimed = false

	if tierData then
		local free = tierData:FindFirstChild("Free")
		local premium = tierData:FindFirstChild("Premium")

		if free and free.Value then
			freeClaimed = true
		end

		if premium and premium.Value then
			premiumClaimed = true
		end
	end

	local freeBorders = tierFrame.FreeFrame.Reward.Contents.Border
	local premiumBorders = tierFrame.PremiumFrame.Reward.Contents.Border

	local freeClaimedGradient = freeBorders:FindFirstChild("Claimed")
	local freeUnclaimedGradient = freeBorders:FindFirstChild("Unclaimed")

	local premiumClaimedGradient = premiumBorders:FindFirstChild("Claimed")
	local premiumUnclaimedGradient = premiumBorders:FindFirstChild("Unclaimed")

	if freeClaimedGradient and freeUnclaimedGradient then
		freeClaimedGradient.Enabled = freeClaimed
		freeUnclaimedGradient.Enabled = not freeClaimed
	end

	if premiumClaimedGradient and premiumUnclaimedGradient then
		premiumClaimedGradient.Enabled = premiumClaimed
		premiumUnclaimedGradient.Enabled = not premiumClaimed
	end
end



local function setupInfTemp(tier)
	local function updateClaimBorders(frame, claimed)
		frame.Reward.Contents.Border.Unclaimed.Enabled = not claimed
		frame.Reward.Contents.Border.Claimed.Enabled = claimed
	end
	
	local infRewards = bpData.InfiniteRewards
	local tierFolder = infRewards:FindFirstChild("Tier"..tier)
	if not tierFolder or rewardHolder:FindFirstChild("Tier"..tier) then
		return
	end
	
	local rewardName = tierFolder.Reward.Value

	local TierTemp = TierFrame:Clone()
	TierTemp.Name = "Tier"..tier
	TierTemp.TierDisplay.Level_Template.Contents.Locked.Visible = false
	TierTemp.TierDisplay.Level_Template.Contents.TextLabel.Text = "Tier #"..tier
	
	local freeFolder = tierFolder:WaitForChild("Free")
	local premFolder = tierFolder:WaitForChild("Premium")

	local freeAmount = freeFolder.Amount and freeFolder.Amount.Value or 0
	local premiumAmount = premFolder.Amount and premFolder.Amount.Value or 0

	local freeClaimed = freeFolder.Claimed.Value
	local premiumClaimed = premFolder.Claimed.Value

	updateClaimBorders(TierTemp.FreeFrame, freeClaimed)
	updateClaimBorders(TierTemp.PremiumFrame, premiumClaimed)

	freeFolder.Claimed.Changed:Connect(function()
		updateClaimBorders(TierTemp.FreeFrame, freeFolder.Claimed.Value)
	end)
	premFolder.Claimed.Changed:Connect(function()
		updateClaimBorders(TierTemp.PremiumFrame, premFolder.Claimed.Value)
	end)

	setupFrame(TierTemp.FreeFrame, {Amount = freeAmount, Title = rewardName})
	setupFrame(TierTemp.PremiumFrame, {Amount = premiumAmount, Title = rewardName})

	TierTemp.FreeFrame.Reward.Activated:Connect(function()
		ClaimBattlepassReward:FireServer(tier, false)
	end)
	TierTemp.PremiumFrame.Reward.Activated:Connect(function()
		ClaimBattlepassReward:FireServer(tier, true)
	end)

	TierTemp.Parent = rewardHolder
end

local function premiumVis()
	PremiumFrame.Visible = not bpData.Premium.Value  
end
premiumVis()
bpData.Premium.Changed:Connect(premiumVis)

local function scaleBar(min, max, bar)
	bar.Size = UDim2.new(min / max, 0, 1, 0)
end

local function updateExpBar()
	local Exp = bpData.Exp.Value
	local Tier = bpData.Tier.Value
	local expRequired = BpConfig.ExpReq(bpData.Tier.Value)
	scaleBar(Exp, expRequired, bpFrame.Core.Main_Reward.Refresh_Bar.Contents.Bar)
	bpFrame.Core.Main_Reward.XPDisplay.Text = Exp.."/"..expRequired
	bpFrame.Core.Main_Reward.TierDisplay.Text = "Tier "..Tier
end

updateExpBar()
bpData.Exp.Changed:Connect(updateExpBar)
bpData.Tier.Changed:Connect(function()
	local tier = bpData.Tier.Value
	lastInfTier = bpData.Tier.Value

	updateExpBar()
	if tier > #BpConfig.Tiers[BpConfig.GetSeason()] then
		for tier = #BpConfig.Tiers[BpConfig.GetSeason()] + 1, lastInfTier do
			setupInfTemp(tier)
		end
	end

	task.wait(0.3)
	updateStatus(tier)
end)

local function init()
	for _, reward in ipairs(rewardHolder:GetChildren()) do
		if reward:IsA("Frame") then
			reward:Destroy()
		end
	end
	
	for tier, rewardData in Tiers do
		local free = rewardData.Free
		local premium = rewardData.Premium

		local TierTemp = TierFrame:Clone()

		-- Display
		TierTemp.TierDisplay.Level_Template.Contents.TextLabel.Text = "Tier #"..tier
		TierTemp.Name = "Tier"..tier

		setupFrame(TierTemp.FreeFrame, free)
		setupFrame(TierTemp.PremiumFrame, premium)
		
		TierTemp.FreeFrame.Reward.Activated:Connect(function()
			ClaimBattlepassReward:FireServer(tier, false)
			task.wait(0.5)
			updateStatus(tier)
		end)
		
		TierTemp.PremiumFrame.Reward.Activated:Connect(function()
			ClaimBattlepassReward:FireServer(tier, true)
			task.wait(0.5)
			updateStatus(tier)
		end)

		TierTemp.Parent = rewardHolder
		updateStatus(tier)
	end
	
	
	for tier = #BpConfig.Tiers[BpConfig.GetSeason()] + 1, lastInfTier do
		setupInfTemp(tier)
	end
end

init()	


-- QUESTS

local toggleButton = bpFrame.Core.Main_Reward.Quests
local showingQuests = false

local function toggleQuest()
	showingQuests = not showingQuests

	RewardFrame.Visible = not showingQuests
	QuestFrame.Visible = showingQuests
	
	if showingQuests then
		PremiumFrame.Visible = false
	else
		premiumVis()
	end

	toggleButton.Contents.Contents.Txt.Text = showingQuests and "REWARDS" or "QUESTS"
end

toggleButton.Activated:Connect(toggleQuest)

local function refreshQuests()
	local quests = bpData.Quests
	local holder = QuestFrame.Contents

	for _, questTemp in ipairs(holder:GetChildren()) do
		if questTemp:IsA("Frame") then
			questTemp:Destroy()
		end
	end

	for _, quest in pairs(quests:GetChildren()) do
		local questID = quest.Name
		local name = quest.QuestName.Value or "Unknown Quest"
		local desc = quest.Description.Value or "Unknown Desc"

		local temp = script.QuestTemplate:Clone()
		temp.Name = questID

		local info = temp.Contents.QuestInfo
		info.Title.Text = name
		info.Desc.Text = desc
		
		
		local rewards = quest.Reward
		local rewardTexts = {}

		for _, rewardFolder in pairs(rewards:GetChildren()) do
			local amount = rewardFolder:FindFirstChild("Amount")
			if amount and amount.Value > 0 then
				table.insert(rewardTexts, "+" .. amount.Value .. " " .. rewardFolder.Name)
			end
		end

		temp.Contents.Rewards.Text = table.concat(rewardTexts, ", ")


		local claim = temp.Contents.Claim
		if quest.Claimed.Value then
			claim.Contents.TextLabel.Text = "Claimed"
		end
		
		claim.Activated:Connect(function()
			local progress = quest.Progress.Value
			local goal = quest.Goal.Value
			if progress >= goal then
				local response = ClaimQuestReward:InvokeServer(quest)
				print("QUEST RESPONSE CLIENT:", response)
				if response then
					claim.Contents.TextLabel.Text = "Claimed"
				end
			end
		end)

		local function updateProgress()
			local progress = quest.Progress.Value
			local goal = quest.Goal.Value
			temp.Contents.Progress.Text = "Progress " .. progress .. "/" .. goal

			if progress >= goal and quest.Claimed.Value == false then
				claim.Contents.TextLabel.Text = "Claim"
			end
		end

		updateProgress()
		scaleBar(quest.Progress.Value, quest.Goal.Value, claim.Contents.ProgressBar.Front)

		quest.Progress.Changed:Connect(function()
			updateProgress()
			scaleBar(quest.Progress.Value, quest.Goal.Value, claim.Contents.ProgressBar.Front)
		end)

		temp.Parent = holder
	end

end

refreshQuests()
bpData.LastRefresh.Changed:Connect(refreshQuests)

local function updateExpireTimer()
	local now = os.date("!*t")
	local nextMidnight = {
		year = now.year,
		month = now.month,
		day = now.day + 1,
		hour = 0,
		min = 0,
		sec = 0
	}

	local expireTime = os.time(nextMidnight)
	local timeLeft = expireTime - os.time(os.date("!*t"))
	QuestFrame.ExpireTimer.Text = "Expires in: " .. formatTime(timeLeft)
end


while true do
	task.wait(1)
	updateExpireTimer()
	
	local countdown = BpConfig.SeasonDuration()
	bpFrame.Core.Countdown.Text = countdown
	
	task.spawn(function()
		if Season ~= BpConfig.GetSeason() then
			--Update
			Season = BpConfig.GetSeason()
			init()	
		end
	end)
end



