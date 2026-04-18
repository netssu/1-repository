local SlotService = {}

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Dependencies
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PlayerDataGuard = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local ProductsData = require(ReplicatedStorage.Modules.Data.ProductsData)

local VALID_SLOT_TYPES = { Style = true, Flow = true }
local MAX_SLOTS_BY_TYPE = {
	Style = 4,
	Flow = 6,
}

export type PurchaseResult = {
	Success: boolean,
	ErrorCode: string?,
	ProductId: number?,
	UnlockedSlot: number?,
}

local function getUnlockedPath(slotType: string): { string }
	return { if slotType == "Style" then "UnlockedStyleSlots" else "UnlockedFlowSlots" }
end

local function getUnlockedSlotsInternal(player: Player, slotType: string): { number }
	local unlockedPath = getUnlockedPath(slotType)
	local unlockedList, hasData = PlayerDataGuard.GetOrDefault(player, unlockedPath, {})
	if not hasData then
		return { 1 }
	end
	return unlockedList
end

local function isSlotUnlocked(player: Player, slotType: string, slotIndex: number): boolean
	return table.find(getUnlockedSlotsInternal(player, slotType), slotIndex) ~= nil
end

local function getNextPurchasableSlot(player: Player, slotType: string): number?
	local maxSlots = MAX_SLOTS_BY_TYPE[slotType]
	if not maxSlots then
		return nil
	end

	for slotIndex = 2, maxSlots do
		if not isSlotUnlocked(player, slotType, slotIndex) and isSlotUnlocked(player, slotType, slotIndex - 1) then
			return slotIndex
		end
	end

	return nil
end

local function unlockSlot(player: Player, slotType: string, slotIndex: number): ()
	local unlockedPath = getUnlockedPath(slotType)
	local unlockedList = getUnlockedSlotsInternal(player, slotType)

	if table.find(unlockedList, slotIndex) then
		return
	end

	table.insert(unlockedList, slotIndex)
	table.sort(unlockedList)
	PlayerDataManager:Set(player, unlockedPath, unlockedList)
end

function SlotService.GetUnlockedSlots(player: Player, slotType: string): { number }
	return getUnlockedSlotsInternal(player, slotType)
end

function SlotService.PreparePurchase(player: Player, slotType: string, slotIndex: number): PurchaseResult
	if not VALID_SLOT_TYPES[slotType] then
		return { Success = false, ErrorCode = "INVALID_SLOT_TYPE" }
	end

	local maxSlots = MAX_SLOTS_BY_TYPE[slotType]
	if typeof(slotIndex) ~= "number" or slotIndex < 2 or not maxSlots or slotIndex > maxSlots then
		return { Success = false, ErrorCode = "INVALID_SLOT_INDEX" }
	end

	local nextPurchasableSlot = getNextPurchasableSlot(player, slotType)
	if not nextPurchasableSlot then
		return { Success = false, ErrorCode = "ALREADY_MAXED" }
	end

	if nextPurchasableSlot ~= slotIndex then
		return { Success = false, ErrorCode = "PREVIOUS_SLOT_LOCKED" }
	end

	local productId = ProductsData.GetSlotProductId(slotType)
	if typeof(productId) ~= "number" then
		return { Success = false, ErrorCode = "PRODUCT_NOT_CONFIGURED" }
	end

	return {
		Success = true,
		ProductId = productId,
	}
end

function SlotService.GrantNextSlot(player: Player, slotType: string): PurchaseResult
	if not VALID_SLOT_TYPES[slotType] then
		return { Success = false, ErrorCode = "INVALID_SLOT_TYPE" }
	end

	local nextPurchasableSlot = getNextPurchasableSlot(player, slotType)
	if not nextPurchasableSlot then
		return { Success = true }
	end

	unlockSlot(player, slotType, nextPurchasableSlot)
	return {
		Success = true,
		UnlockedSlot = nextPurchasableSlot,
	}
end

function SlotService.Init()
	Packets.Slots.OnServerInvoke = function(player: Player, action: string, data: { any }): any
		if action == "PreparePurchaseSlot" then
			if typeof(data) ~= "table" then
				return { Success = false, ErrorCode = "INVALID_DATA" }
			end

			local slotType = data.SlotType
			local slotIndex = data.SlotIndex
			if typeof(slotType) ~= "string" or typeof(slotIndex) ~= "number" then
				return { Success = false, ErrorCode = "INVALID_DATA" }
			end

			return SlotService.PreparePurchase(player, slotType, slotIndex)
		elseif action == "GetUnlockedSlots" then
			if typeof(data) ~= "table" then
				return {}
			end

			local slotType = data.SlotType
			if typeof(slotType) ~= "string" then
				return {}
			end

			return SlotService.GetUnlockedSlots(player, slotType)
		elseif action == "GetProducts" then
			return {
				Flow = ProductsData.GetSlotProductId("Flow"),
				Style = ProductsData.GetSlotProductId("Style"),
			}
		elseif action == "PurchaseSlot" then
			return { Success = false, ErrorCode = "LEGACY_SLOT_PURCHASE_DISABLED" }
		end

		return { Success = false, ErrorCode = "UNKNOWN_ACTION" }
	end
end

export type SlotService = typeof(SlotService)

return SlotService
