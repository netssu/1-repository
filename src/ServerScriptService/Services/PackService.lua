------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

------------------//MODULES
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local PlayerDataGuard = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)

local CosmeticsModule = require(ReplicatedStorage.Modules.Data.CosmeticsData)
local EmotesData = require(ReplicatedStorage.Modules.Data.EmotesData)
local PlayerCardsData = require(ReplicatedStorage.Modules.Data.PlayerCardsData)

------------------//CONSTANTS
local PACK_CONFIG = {
	["Cosmetics"] = {
		Pool = CosmeticsModule.Items,
		SavePath = "OwnedCosmetics",
		Cost = 100,
	},
	["Emotes"] = {
		Pool = EmotesData.Emotes,
		SavePath = "OwnedEmotes",
		Cost = 500,
	},
	["Player"] = {
		Pool = PlayerCardsData.Cards,
		SavePath = "OwnedCards",
		Cost = 250,
	},
}

------------------//VARIABLES
local PackService = {}
local _purchaseDebounce = {}

------------------//PRIVATE FUNCTIONS

local function GetRolledItemData(_packType, config)
	local totalWeight = 0

	for _, data in pairs(config.Pool) do
		totalWeight = totalWeight + (data.Weight or 1)
	end

	if totalWeight <= 0 then
		return nil, "EmptyPool"
	end

	local randomVal = math.random(1, totalWeight)
	local counter = 0

	for key, data in pairs(config.Pool) do
		counter = counter + (data.Weight or 1)
		if randomVal <= counter then
			return key, data
		end
	end

	return nil, "RollFailed"
end

local function BuildResponseTable(wonItemKey, wonItemData)
	return {
		Success = true,
		Key = wonItemKey,
		Name = wonItemData.Name,
		Rarity = wonItemData.Rarity,
		ImageId = wonItemData.ImageId or wonItemData.Image,
		AnimationId = wonItemData.AnimationId,
		Model = wonItemData.Model and wonItemData.Model.Name or nil,
	}
end

------------------//PUBLIC FUNCTIONS

function PackService.RollGacha(player, packType)
	local config = PACK_CONFIG[packType]
	if not config then
		return nil, "InvalidPack"
	end

	local wonItemKey, wonItemData = GetRolledItemData(packType, config)
	if not wonItemKey then
		return nil, wonItemData
	end

	PlayerDataManager:Insert(player, { config.SavePath }, wonItemKey)
	print(player.Name .. " bought (Robux) " .. packType .. " and won: " .. wonItemKey)

	return BuildResponseTable(wonItemKey, wonItemData)
end

local function ProcessOpenPack(player, packType)
	if _purchaseDebounce[player.UserId] then
		return HttpService:JSONEncode({ Success = false, Reason = "PurchaseInProgress" })
	end
	_purchaseDebounce[player.UserId] = true

	local config = PACK_CONFIG[packType]
	if not config then
		_purchaseDebounce[player.UserId] = nil
		return HttpService:JSONEncode({ Success = false, Reason = "InvalidPack" })
	end

	local currentYen, hasYenData = PlayerDataGuard.GetOrDefault(player, { "Yen" }, 0)
	if not hasYenData or type(currentYen) ~= "number" then
		_purchaseDebounce[player.UserId] = nil
		return HttpService:JSONEncode({ Success = false, Reason = "DataUnavailable" })
	end

	if currentYen < config.Cost then
		_purchaseDebounce[player.UserId] = nil
		return HttpService:JSONEncode({ Success = false, Reason = "InsufficientFunds" })
	end

	local wonItemKey, wonItemData = GetRolledItemData(packType, config)
	if not wonItemKey then
		_purchaseDebounce[player.UserId] = nil
		return HttpService:JSONEncode({ Success = false, Reason = wonItemData or "RollFailed" })
	end

	PlayerDataManager:Increment(player, { "Yen" }, -config.Cost)
	PlayerDataManager:Insert(player, { config.SavePath }, wonItemKey)
	print(player.Name .. " opened (Yen) " .. packType .. " and won: " .. wonItemKey)

	_purchaseDebounce[player.UserId] = nil
	return HttpService:JSONEncode(BuildResponseTable(wonItemKey, wonItemData))
end

------------------//INIT

function PackService.Start()
	Packets.Summon.OnServerInvoke = function(player, packType)
		return ProcessOpenPack(player, packType)
	end

	Players.PlayerRemoving:Connect(function(player)
		_purchaseDebounce[player.UserId] = nil
	end)

	print("[PackService] Initialized and listening to Packets.Summon")
end

return PackService
