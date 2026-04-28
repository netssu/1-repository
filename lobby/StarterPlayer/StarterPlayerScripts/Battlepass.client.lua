-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MPS = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
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

local skipProducts = {
	[1] = {Normal = 3279744329, Gift = 3281245102},
	[5] = {Normal = 3286932503, Gift = 3286932640},
	[10] = {Normal = 3279744407, Gift = 3280425048},
}

-- VARIABLES
local BpConfig = require(ReplicatedStorage.Configs.BattlepassConfig)
local EpConfig = require(ReplicatedStorage.EpisodeConfig)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

repeat task.wait() until player:FindFirstChild("DataLoaded")

local ClaimBattlepassReward = ReplicatedStorage.Remotes.Quests.ClaimBattlepassReward
local ClaimQuestReward = ReplicatedStorage.Remotes.Quests.ClaimQuestReward
local Functions = ReplicatedStorage:WaitForChild("Functions")
local GetMarketInfoByName = Functions:WaitForChild("GetMarketInfoByName")
local BuyEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Buy")

local bpData = player.BattlepassData

-- Correção de carregamento (evita o erro "CoreGameUI is not a valid member")
local CoreGameUI = playerGui:WaitForChild("CoreGameUI")
local GiftFolder = CoreGameUI:WaitForChild("Gift")
local GiftFrame = GiftFolder:WaitForChild("GiftFrame")
local SelectedGiftId = GiftFolder:WaitForChild("SelectedGiftId")

local newBpFrame = playerGui:WaitForChild("NewUI"):WaitForChild("BattlepassFrame")
local Main = newBpFrame:WaitForChild("Main")
local ContentHolder = Main:WaitForChild("Content")

local RewardHolder = ContentHolder:WaitForChild("Contents")
local QuestFrame = ContentHolder:WaitForChild("Pass_Quests")
local TopFrame = ContentHolder:WaitForChild("Top")

-- Extraindo e limpando os Templates
local TierTemplate = RewardHolder:WaitForChild("1"):Clone()
RewardHolder:WaitForChild("1"):Destroy()

local QuestTemplate = QuestFrame:WaitForChild("Contents"):WaitForChild("QuestTemplate"):Clone()
QuestFrame:WaitForChild("Contents"):WaitForChild("QuestTemplate"):Destroy()

local PremiumOverlay = ContentHolder:WaitForChild("Premium Battlepass")
local PurchasesContents = newBpFrame:WaitForChild("Purchases"):WaitForChild("Contents")

local Season = BpConfig.GetSeason()
local Tiers = BpConfig.Tiers[Season]
local lastInfTier = bpData.Tier.Value
local showingQuests = false

-- FUNCTIONS
local function formatTime(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function scaleBar(min, max, bar)
	local targetScale = math.clamp(min / max, 0, 1)
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bar, tweenInfo, {Size = UDim2.new(targetScale, 0, 1, 0)}):Play()
end

local function setupFrame(frame, reward, tierNum)
	if reward.Special then
		if reward.Special == "Unit" then
			local displayIcon = frame.Image.Icon
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
			frame.Image.Icon.Image = "rbxassetid://"..ItemImages[reward.Title]
		else
			warn("image nf for: "..reward.Title)
		end 
	end

	if reward.Amount then
		frame.Multiplier.Text = tostring(reward.Amount)
	end
	if tierNum then
		frame.Title.Text = tostring(tierNum)
	end
end

local function updateStatus(tier)
	local tierName = "Tier" .. tier
	local tierFrame = RewardHolder:FindFirstChild(tierName)
	if not tierFrame then return end

	local tierData = bpData.TiersClaimed:FindFirstChild(tierName)
	if not tierData then return end

	local freeClaimed = false
	local premiumClaimed = false

	local free = tierData:FindFirstChild("Free")
	local premium = tierData:FindFirstChild("Premium")

	if free and free.Value then freeClaimed = true end
	if premium and premium.Value then premiumClaimed = true end

	if freeClaimed then
		tierFrame.Free.Btn.Visible = false
		tierFrame.Free.Image.Icon.ImageTransparency = 0.5
	end

	if premiumClaimed then
		tierFrame.Premium.Btn.Visible = false
		tierFrame.Premium.Image.Icon.ImageTransparency = 0.5
	end
end

local function setupInfTemp(tier)
	local infRewards = bpData.InfiniteRewards
	local tierFolder = infRewards:FindFirstChild("Tier"..tier)
	if not tierFolder or RewardHolder:FindFirstChild("Tier"..tier) then return end

	local rewardName = tierFolder.Reward.Value

	local TierTemp = TierTemplate:Clone()
	TierTemp.Name = "Tier"..tier

	local freeFolder = tierFolder:WaitForChild("Free")
	local premFolder = tierFolder:WaitForChild("Premium")

	local freeAmount = freeFolder.Amount and freeFolder.Amount.Value or 0
	local premiumAmount = premFolder.Amount and premFolder.Amount.Value or 0

	setupFrame(TierTemp.Free, {Amount = freeAmount, Title = rewardName}, tier)
	setupFrame(TierTemp.Premium, {Amount = premiumAmount, Title = rewardName}, tier)

	local function syncClaimVisuals()
		if freeFolder.Claimed.Value then
			TierTemp.Free.Btn.Visible = false
			TierTemp.Free.Image.Icon.ImageTransparency = 0.5
		end
		if premFolder.Claimed.Value then
			TierTemp.Premium.Btn.Visible = false
			TierTemp.Premium.Image.Icon.ImageTransparency = 0.5
		end
	end
	syncClaimVisuals()

	freeFolder.Claimed.Changed:Connect(syncClaimVisuals)
	premFolder.Claimed.Changed:Connect(syncClaimVisuals)

	TierTemp.Free.Btn.Activated:Connect(function()
		ClaimBattlepassReward:FireServer(tier, false)
	end)
	TierTemp.Premium.Btn.Activated:Connect(function()
		ClaimBattlepassReward:FireServer(tier, true)
	end)

	TierTemp.Parent = RewardHolder
end

local function premiumVis()
	if not showingQuests then
		PremiumOverlay.Visible = not bpData.Premium.Value  
	end
end

local function updateExpBar()
	local Exp = bpData.Exp.Value
	local Tier = bpData.Tier.Value
	local expRequired = BpConfig.ExpReq(bpData.Tier.Value)

	scaleBar(Exp, expRequired, TopFrame.Bar.Bar.Fill)
	TopFrame.Text.Exp.Text = Exp.."/"..expRequired
	TopFrame.Text.Tier.Text = "Tier "..Tier
end

local function toggleQuest()
	showingQuests = not showingQuests

	-- Oculta ou exibe os frames para deixar a tela limpa
	RewardHolder.Visible = not showingQuests
	QuestFrame.Visible = showingQuests

	local passesFrame = ContentHolder:FindFirstChild("Passes")
	if passesFrame then
		passesFrame.Visible = not showingQuests
	end

	local dividerFrame = ContentHolder:FindFirstChild("Divider")
	if dividerFrame then
		dividerFrame.Visible = not showingQuests
	end

	if showingQuests then
		PremiumOverlay.Visible = false
	else
		premiumVis()
	end

	local txtLabel = TopFrame.Button:FindFirstChild("ActualText")
	if txtLabel then
		txtLabel.Text = showingQuests and "REWARDS" or "QUESTS"
	end
end

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

		local temp = QuestTemplate:Clone()
		temp.Name = questID

		local textFrame = temp.Contents.TextFrame
		textFrame.Title.Text = name
		textFrame.Subtext.Text = desc

		local rewards = quest.Reward
		local rewardTexts = {}

		for _, rewardFolder in pairs(rewards:GetChildren()) do
			local amount = rewardFolder:FindFirstChild("Amount")
			if amount and amount.Value > 0 then
				table.insert(rewardTexts, "+" .. amount.Value .. " " .. rewardFolder.Name)
			end
		end

		temp.Contents.Reward_Amount.Text = table.concat(rewardTexts, ", ")

		local claim = temp.Contents.Claim

		if quest.Claimed.Value then
			claim.ImageTransparency = 0.5
		end

		claim.Activated:Connect(function()
			local progress = quest.Progress.Value
			local goal = quest.Goal.Value
			if progress >= goal and not quest.Claimed.Value then
				local response = ClaimQuestReward:InvokeServer(quest)
				if response then
					claim.ImageTransparency = 0.5
				end
			end
		end)

		local function updateProgress()
			local progress = quest.Progress.Value
			local goal = quest.Goal.Value
			textFrame.Progress.Text = "Progress " .. progress .. "/" .. goal

			if progress >= goal and quest.Claimed.Value == false then
				claim.ImageTransparency = 0
			end
		end

		updateProgress()
		scaleBar(quest.Progress.Value, quest.Goal.Value, temp.Contents.Fill_Bg)

		quest.Progress.Changed:Connect(function()
			updateProgress()
			scaleBar(quest.Progress.Value, quest.Goal.Value, temp.Contents.Fill_Bg)
		end)

		temp.Parent = holder
	end
end

local function updateExpireTimer()
	local now = os.date("!*t")
	local nextMidnight = {year = now.year, month = now.month, day = now.day + 1, hour = 0, min = 0, sec = 0}
	local expireTime = os.time(nextMidnight)
	local timeLeft = expireTime - os.time(os.date("!*t"))
	QuestFrame.ExpireTimer.Text = "Expires in: " .. formatTime(timeLeft)
end

-- INIT
local function init()
	for _, reward in ipairs(RewardHolder:GetChildren()) do
		if reward:IsA("Frame") and reward.Name:find("Tier") then
			reward:Destroy()
		end
	end

	for tier, rewardData in Tiers do
		local free = rewardData.Free
		local premium = rewardData.Premium

		local TierTemp = TierTemplate:Clone()
		TierTemp.Name = "Tier"..tier

		setupFrame(TierTemp.Free, free, tier)
		setupFrame(TierTemp.Premium, premium, tier)

		TierTemp.Free.Btn.Activated:Connect(function()
			ClaimBattlepassReward:FireServer(tier, false)
			task.wait(0.5)
			updateStatus(tier)
		end)

		TierTemp.Premium.Btn.Activated:Connect(function()
			ClaimBattlepassReward:FireServer(tier, true)
			task.wait(0.5)
			updateStatus(tier)
		end)

		TierTemp.Parent = RewardHolder
		updateStatus(tier)
	end

	for tier = #BpConfig.Tiers[BpConfig.GetSeason()] + 1, lastInfTier do
		setupInfTemp(tier)
	end
end

-- Connections & Initial Calls
TopFrame.Button.Btn.Activated:Connect(toggleQuest)

premiumVis()
bpData.Premium.Changed:Connect(premiumVis)

updateExpBar()
bpData.Exp.Changed:Connect(updateExpBar)
bpData.Tier.Changed:Connect(function()
	local tier = bpData.Tier.Value
	lastInfTier = bpData.Tier.Value

	updateExpBar()
	if tier > #BpConfig.Tiers[BpConfig.GetSeason()] then
		for t = #BpConfig.Tiers[BpConfig.GetSeason()] + 1, lastInfTier do
			setupInfTemp(t)
		end
	end

	task.wait(0.3)
	updateStatus(tier)
end)

-- Purchases Setup (Skip Tiers)
for _, skipFrame in ipairs(PurchasesContents:GetChildren()) do
	if skipFrame:IsA("Frame") and skipFrame.Name:find("Skip") then
		local skipAmount = tonumber(skipFrame.Name:match("%d+"))
		if skipAmount and skipProducts[skipAmount] then
			skipFrame.Button.Btn.Activated:Connect(function()
				MPS:PromptProductPurchase(player, skipProducts[skipAmount].Normal)
			end)
			local btnGift = skipFrame:FindFirstChild("ButtomGift")
			if btnGift then
				btnGift.Activated:Connect(function()
					MPS:PromptProductPurchase(player, skipProducts[skipAmount].Gift)
				end)
			end
		end
	end
end

-- Premium Overlay & Purchases Premium Button Logic
task.spawn(function()
	local info = GetMarketInfoByName:InvokeServer("Premium Battlepass")
	if info then
		-- Botões do Overlay
		PremiumOverlay.Contents.Buy.Activated:Connect(function()
			BuyEvent:FireServer(info.Id)
		end)
		PremiumOverlay.Contents.Gift.Activated:Connect(function()
			SelectedGiftId.Value = info.GiftId
			GiftFrame.Visible = true
		end)

		-- Botões da aba Purchases
		local purchPrem = PurchasesContents:FindFirstChild("PremiumBattlepass")
		if purchPrem then
			local buyBtn = purchPrem:FindFirstChild("Button") and purchPrem.Button:FindFirstChild("Btn")
			if buyBtn then
				buyBtn.Activated:Connect(function()
					BuyEvent:FireServer(info.Id)
				end)
			end

			local giftBtn = purchPrem:FindFirstChild("ButtomGift")
			if giftBtn then
				giftBtn.Activated:Connect(function()
					SelectedGiftId.Value = info.GiftId
					GiftFrame.Visible = true
				end)
			end
		end
	end
end)

QuestFrame.Visible = false

refreshQuests()
bpData.LastRefresh.Changed:Connect(refreshQuests)

init()	

task.spawn(function()
	while true do
		task.wait(1)
		updateExpireTimer()

		if Season ~= BpConfig.GetSeason() then
			Season = BpConfig.GetSeason()
			init()	
		end
	end
end)