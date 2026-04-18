local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local FlipbookModule = require(ReplicatedStorage.Modules.Game.FlipbookModule)
local ShineModule = require(ReplicatedStorage.Modules.Game.ShineModule)
local Trove = require(ReplicatedStorage.Packages.Trove)

local CosmeticsModule = require(ReplicatedStorage.Modules.Data.CosmeticsData)
local EmotesData = require(ReplicatedStorage.Modules.Data.EmotesData)
local PlayerCardsData = require(ReplicatedStorage.Modules.Data.PlayerCardsData)

local Reward = {}

local DATA_MODULES = {
	["Cosmetics"] = { Data = CosmeticsModule.Items, Module = CosmeticsModule },
	["Emotes"] = { Data = EmotesData.Emotes, Module = EmotesData },
	["Player"] = { Data = PlayerCardsData.Cards, Module = PlayerCardsData }
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(169, 169, 169),
	Rare = Color3.fromRGB(0, 112, 221),
	Epic = Color3.fromRGB(163, 53, 238),
	Legendary = Color3.fromRGB(255, 165, 0)
}

local MULTI_ITEM_ANIMATION_DELAY = 0.2
local ITEM_ENTRY_DURATION = 0.55
local SINGLE_ITEM_REVEAL_SETTLE_DELAY = 0
local MULTI_ITEM_REVEAL_SETTLE_DELAY = 0.12
local PLAYER_CARD_FINAL_SIZE = UDim2.new(0.233, 0, 0.651, 0)

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PackGui = PlayerGui:WaitForChild("Pack") :: ScreenGui
local RewardFrame = PackGui:WaitForChild("RewardFrame")
local ContentFrame = RewardFrame:WaitForChild("Content")
local RewardsFrame = ContentFrame:WaitForChild("Rewards")
local InsetFrame = RewardsFrame:WaitForChild("inset")

local isAnimating = false
local animationQueue = {}
local assetsLoaded = false

local function preloadAssets()
	if assetsLoaded then return end
	local assetsToPreload = {}
	local rarityNames = {"Common", "Rare", "Epic", "Legendary"}
	for _, rarityName in ipairs(rarityNames) do
		local rarityAsset = Assets.UI:FindFirstChild(rarityName)
		if rarityAsset and rarityAsset:IsA("ImageLabel") and rarityAsset.Image ~= "" then
			table.insert(assetsToPreload, rarityAsset.Image)
		end
	end
	if #assetsToPreload > 0 then
		task.spawn(function()
			pcall(function() ContentProvider:PreloadAsync(assetsToPreload) end)
			assetsLoaded = true
		end)
	end
end

local function calculateItemChance(itemName: string, cardType: string): number
	local moduleInfo = DATA_MODULES[cardType]
	if not moduleInfo then return 0 end
	local pool = moduleInfo.Data

	local totalWeight = 0
	local itemWeight = 0

	for _, item in pairs(pool) do
		if item.Weight then
			totalWeight = totalWeight + item.Weight
			if item.Name == itemName then
				itemWeight = item.Weight
			end
		end
	end

	if totalWeight == 0 then return 0 end
	return math.floor((itemWeight / totalWeight) * 100)
end

local function createRewardItem(itemData: any, index: number): any
	local rarityAsset = Assets.UI:FindFirstChild(itemData.Rarity)
	if not rarityAsset then return nil end
	local cardClone = rarityAsset:Clone()
	return cardClone
end

local function createPlayerCardItem(itemData: any, index: number): any
	local playerCardsFolder = Assets:FindFirstChild("PlayerCards")
	if not playerCardsFolder then return nil end

	local imageId = itemData.ImageId or itemData.Image
	local cardLookupName = itemData.Key or itemData.Name
	local cardAsset

	if imageId then
		cardAsset = playerCardsFolder:FindFirstChild(cardLookupName)
		if not cardAsset then
			cardAsset = playerCardsFolder:FindFirstChild("Blue")
		end
	end

	if not cardAsset then return nil end
	local cardClone = cardAsset:Clone()

	if cardClone:IsA("GuiObject") then
		cardClone.Size = PLAYER_CARD_FINAL_SIZE
	end

	if imageId then
		if cardClone:IsA("ImageLabel") or cardClone:IsA("ImageButton") then
			cardClone.Image = imageId
		elseif cardClone:FindFirstChild("Image") then
			cardClone.Image.Image = imageId
		end
	end
	return cardClone
end

local function animateTextLabel(textLabel: TextLabel, itemData: any)
	if not textLabel then return end
	textLabel.Text = itemData.Name
	textLabel.TextTransparency = 1
	textLabel.Size = UDim2.new(0, 0, 0, 0)
	textLabel.Visible = true
	local originalSize = UDim2.new(1, 0, 0.2, 0)
	TweenService:Create(textLabel, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0, Size = originalSize
	}):Play()
end

local function animatePercentageLabel(textLabel: TextLabel, chance: number)
	if not textLabel then return end
	textLabel.Text = chance .. "%"
	textLabel.TextTransparency = 1
	textLabel.Size = UDim2.new(0, 0, 0, 0)
	textLabel.Visible = true
	local originalSize = UDim2.new(1, 0, 0.2, 0)
	TweenService:Create(textLabel, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0, Size = originalSize
	}):Play()
end

local function animateTextLabelExit(textLabel) 
    TweenService:Create(textLabel, TweenInfo.new(0.3), {TextTransparency=1, Size=UDim2.new(0,0,0,0)}):Play() 
end
local function animatePercentageLabelExit(textLabel)
    TweenService:Create(textLabel, TweenInfo.new(0.3), {TextTransparency=1, Size=UDim2.new(0,0,0,0)}):Play()
end

local function animateItemEntrance(
	item: any,
	delay: number,
	itemData: any,
	cardType: string?,
	postRevealDelay: number,
	onComplete: () -> ()
)
	task.delay(delay, function()
		if not item or not item.Parent then onComplete() return end

		if item:IsA("GuiObject") then
			local originalSize = item.Size
			item.Size = UDim2.new(0, 0, 0, 0)
			local bounceTween = TweenService:Create(item, TweenInfo.new(ITEM_ENTRY_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = originalSize
			})
			bounceTween:Play()
			bounceTween.Completed:Wait()
		end
		
		local isPlayerCardItem = cardType == "Player"

		if not isPlayerCardItem then
			local itemLabel = item:FindFirstChild("Item")
			if itemLabel then animateTextLabel(itemLabel, itemData) end

			local percentageLabel = item:FindFirstChild("Percentage") or item:FindFirstChild("Porcentagem")
			if percentageLabel then
				local chance = calculateItemChance(itemData.Name, cardType or "Cosmetics")
				animatePercentageLabel(percentageLabel, chance)
			end
		end

		if postRevealDelay > 0 then
			task.wait(postRevealDelay)
		end
		onComplete()
	end)
end

local function layoutItems(containerFrame: Frame, items: {any})
	local itemsPerRow = 3
	local spacing = 20
	local currentRow = 0
	local currentCol = 0

	for i, item in ipairs(items) do
		local isLargeItem = (item:FindFirstChild("Image") ~= nil)
		local itemWidth = isLargeItem and 350 or 140
		local itemHeight = isLargeItem and 425 or 170

		if item:IsA("GuiObject") then
			if item.Size.X.Scale == 0 and item.Size.X.Offset == 0 and item.Size.Y.Scale == 0 and item.Size.Y.Offset == 0 then
				item.Size = UDim2.new(0, itemWidth, 0, itemHeight)
			end
			item.Position = UDim2.new(0.5, 0, 0.499, 0)
		end
		
		currentCol = currentCol + 1
		if currentCol >= itemsPerRow then
			currentCol = 0
			currentRow = currentRow + 1
		end
	end
end

function Reward.ShowRewards(items: {any}, cardType: string?)
	local currentCardType = cardType or "Cosmetics"
	preloadAssets()

	if isAnimating then
		table.insert(animationQueue, {
			Items = items,
			CardType = currentCardType,
		})
		return
	end
	isAnimating = true

	for _, child in ipairs(InsetFrame:GetChildren()) do child:Destroy() end

	RewardFrame.BackgroundTransparency = 0
	RewardFrame.Visible = true

	TweenService:Create(RewardFrame, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.25
	}):Play()

	local itemObjects = {}

	for i, itemData in ipairs(items) do
		local itemObject
		local isPlayerCardReward = currentCardType == "Player"

		if isPlayerCardReward then
			itemObject = createPlayerCardItem(itemData, i)
		else
			itemObject = createRewardItem(itemData, i)
		end

		if itemObject then
			itemObject.Name = itemData.Name
			itemObject.Parent = InsetFrame

			local moduleInfo = DATA_MODULES[currentCardType]
			local moduleScript = moduleInfo and moduleInfo.Module
			local viewportCreated = false

			if moduleScript and moduleScript.GetItemViewport then
				local viewport = moduleScript.GetItemViewport(itemData.Name)
				if viewport then
					
					local targetParent = itemObject:FindFirstChild("Icon")
					if targetParent then
                        -- Limpa placeholders antigos se houver
                        local oldItem = targetParent:FindFirstChild("ITEM")
                        if oldItem then oldItem:Destroy() end
                        
						viewport.Parent = targetParent
						viewport.Size = UDim2.fromScale(1, 1)
						viewport.Position = UDim2.fromScale(0.5, 0.5)
						viewport.AnchorPoint = Vector2.new(0.5, 0.5)
                        viewport.ZIndex = 5 -- Garante que fique acima do fundo
					else
						viewport.Parent = itemObject
					end
					viewportCreated = true
				end
			end

			if not viewportCreated then
				if not isPlayerCardReward then
					local percentageLabel = itemObject:FindFirstChild("Percentage") or itemObject:FindFirstChild("Porcentagem")
					if percentageLabel then
						local chance = calculateItemChance(itemData.Name, currentCardType)
						percentageLabel.Text = chance .. "%"
						percentageLabel.Visible = true
					end
				end

				-- Fallback para AnimationId ou Model simples
				if itemData.AnimationId then
					local dummy = Assets:FindFirstChild("Dummy")
					local itemFolder = itemObject.Icon:FindFirstChild("ITEM")
					local worldModel = itemFolder and itemFolder:FindFirstChild("WorldModel")
					if dummy and worldModel then
						local dummyClone = dummy:Clone()
						dummyClone.Parent = worldModel
						local humanoid = dummyClone:FindFirstChildOfClass("Humanoid")
						if humanoid then
							local animation = Instance.new("Animation")
							animation.AnimationId = itemData.AnimationId
							humanoid:LoadAnimation(animation):Play()
						end
					end
				elseif itemData.Model and not viewportCreated then
					local itemFolder = itemObject.Icon:FindFirstChild("ITEM")
					local worldModel = itemFolder and itemFolder:FindFirstChild("WorldModel")
					if worldModel then
						local modelName = itemData.Model
						local model = Assets:FindFirstChild(modelName) or Assets:FindFirstChild("Cosmetics") and Assets.Cosmetics:FindFirstChild(modelName)
						if model then
							local modelClone = model:Clone()
							modelClone.Parent = worldModel
						end
					end
				end
			end
			-- // FIM DA LOGICA VIEWPORT //

			-- Efeitos Visuais (Brilho/Flipbook)
			if not isPlayerCardReward then
                local trove = Trove.new()
				task.spawn(function()
					ShineModule.Animate(itemObject, {
						_trove = trove,
						additional_params = {
							tweenDuration = 1.5,
							shimmerDelay = 0.2,
							rarity = itemData.Rarity
						}
					})
				end)
			end
			table.insert(itemObjects, itemObject)
		end
	end

	if #itemObjects == 0 then
		Reward.CloseRewards()
		isAnimating = false
		return
	end
	layoutItems(InsetFrame, itemObjects)
	
	local currentIndex = 1
	local hasMultipleRewards = #itemObjects > 1
	local revealDelay = SINGLE_ITEM_REVEAL_SETTLE_DELAY
	if hasMultipleRewards then
		revealDelay = MULTI_ITEM_REVEAL_SETTLE_DELAY
	end
	local function animateNext()
		if currentIndex > #itemObjects then
            local closeButton = RewardFrame:FindFirstChild("CloseButton")
			if closeButton then
				closeButton.MouseButton1Click:Once(function() Reward.CloseRewards() end)
			end
			task.delay(4, function() if RewardFrame.Visible then Reward.CloseRewards() end end)
			return
		end
		local itemObject = itemObjects[currentIndex]
		local itemData = items[currentIndex]
		animateItemEntrance(itemObject, 0, itemData, currentCardType, revealDelay, function()
			currentIndex = currentIndex + 1
			if currentIndex <= #itemObjects then
				task.wait(MULTI_ITEM_ANIMATION_DELAY)
			end
			animateNext()
		end)
	end
	animateNext()
end

function Reward.CloseRewards()
    if not RewardFrame.Visible then return end
    RewardFrame.Visible = false
	for _, child in ipairs(InsetFrame:GetChildren()) do child:Destroy() end
	isAnimating = false
	if #animationQueue > 0 then
		local nextReward = table.remove(animationQueue, 1)
		Reward.ShowRewards(nextReward.Items, nextReward.CardType)
	end
end

function Reward.Start()
	preloadAssets()
end

return Reward
