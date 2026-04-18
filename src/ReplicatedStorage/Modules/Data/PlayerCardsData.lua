------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local Assets = ReplicatedStorage:WaitForChild("Assets")
local PlayerCardsFolder = Assets:WaitForChild("PlayerCards")

------------------//VARIABLES
local PlayerCardsData = {}
local CARD_ASSET_WAIT_TIMEOUT = 1
local MIN_OVR = 49
local MID_OVR = 79
local MAX_OVR = 99
local MAX_STAT_PROGRESS = 1000
local EARLY_PROGRESS_THRESHOLD = 0.05
local LATE_PROGRESS_EXPONENT = 1.35

local function findPlayerCardAsset(cardNames)
	for _, cardName in ipairs(cardNames) do
		local cardAsset = PlayerCardsFolder:FindFirstChild(cardName)
		if cardAsset then
			return cardAsset
		end

		local directPlayerCardsFolder = ReplicatedStorage:FindFirstChild("PlayerCards")
		if directPlayerCardsFolder then
			cardAsset = directPlayerCardsFolder:FindFirstChild(cardName)
			if cardAsset then
				return cardAsset
			end
		end
	end

	local primaryCardName = cardNames[1]
	local cardAsset = PlayerCardsFolder:WaitForChild(primaryCardName, CARD_ASSET_WAIT_TIMEOUT)
	if cardAsset then
		return cardAsset
	end

	local directPlayerCardsFolder = ReplicatedStorage:FindFirstChild("PlayerCards")
		or ReplicatedStorage:WaitForChild("PlayerCards", CARD_ASSET_WAIT_TIMEOUT)
	if directPlayerCardsFolder then
		for _, cardName in ipairs(cardNames) do
			cardAsset = directPlayerCardsFolder:FindFirstChild(cardName)
			if cardAsset then
				return cardAsset
			end
		end

		cardAsset = directPlayerCardsFolder:WaitForChild(primaryCardName, CARD_ASSET_WAIT_TIMEOUT)
		if cardAsset then
			return cardAsset
		end
	end

	warn("PlayerCardsData: Card asset not found - " .. table.concat(cardNames, ", "))
	return nil
end

PlayerCardsData.Cards = {
	["Blue Card"] = {
		Id = "BLUE",
		Name = "Blue Player Card",
		Card = PlayerCardsFolder:WaitForChild("Blue"),
		Image = "rbxassetid://126978557027910",
		Rarity = "Rare",
		Weight = 200,
	},
	["Orange Card"] = {
		Id = "ORANGE",
		Name = "Orange Player Card",
		Card = PlayerCardsFolder:WaitForChild("Orange"),
		Image = "rbxassetid://72353134023537",
		Rarity = "Epic",
		Weight = 50,
	},
	["Red Card"] = {
		Id = "RED",
		Name = "Red Player Card",
		Card = PlayerCardsFolder:WaitForChild("Red"),
		Image = "rbxassetid://130718868659417",
		Rarity = "Legendary",
		Weight = 10,
	},
	["VIP"] = {
		Id = "VIP",
		Name = "VIP",
		Card = findPlayerCardAsset({ "VIP", "Vip", "VIP Card", "Vip Card" }),
		Image = "",
		Rarity = "Exclusive",
		Weight = 0,
	},
	["DIAMOND"] = {
		Id = "DIAMOND",
		Name = "DIAMOND",
		Card = findPlayerCardAsset({ "DIAMOND", "Diamond", "DIAMOND Card", "Diamond Card" }),
		Image = "",
		Rarity = "Exclusive",
		Weight = 0,
	},
}

------------------//FUNCTIONS
function PlayerCardsData.GetCard(cardName)
	local card = PlayerCardsData.Cards[cardName]
	if not card then
		warn("PlayerCardsData: Card not found - " .. tostring(cardName))
		return nil
	end
	return card
end

function PlayerCardsData.GetCardImage(cardName)
	local card = PlayerCardsData.GetCard(cardName)
	if not card then return nil end

	if type(card.Image) ~= "string" or card.Image == "" then
		return nil
	end

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "Card_" .. card.Id
	imageLabel.BackgroundTransparency = 1
	imageLabel.Size = UDim2.fromScale(1, 1)
	imageLabel.Image = card.Image
	imageLabel.ScaleType = Enum.ScaleType.Fit
	imageLabel.Visible = true
	return imageLabel
end

local function NormalizeStatProgress(value: number?): number
	local numericValue = tonumber(value) or 0
	return math.clamp(numericValue, 0, MAX_STAT_PROGRESS) / MAX_STAT_PROGRESS
end

function PlayerCardsData.GetOverallRating(touchdowns: number?, passing: number?, tackles: number?): number
	local averageProgress = (
		NormalizeStatProgress(touchdowns)
		+ NormalizeStatProgress(passing)
		+ NormalizeStatProgress(tackles)
	) / 3

	local rating: number
	if averageProgress <= EARLY_PROGRESS_THRESHOLD then
		local earlyAlpha = averageProgress / EARLY_PROGRESS_THRESHOLD
		rating = MIN_OVR + ((MID_OVR - MIN_OVR) * earlyAlpha)
	else
		local lateAlpha = (averageProgress - EARLY_PROGRESS_THRESHOLD) / (1 - EARLY_PROGRESS_THRESHOLD)
		rating = MID_OVR + ((MAX_OVR - MID_OVR) * (lateAlpha ^ LATE_PROGRESS_EXPONENT))
	end

	return math.clamp(math.floor(rating + 0.5), MIN_OVR, MAX_OVR)
end

------------------//INIT
return PlayerCardsData
