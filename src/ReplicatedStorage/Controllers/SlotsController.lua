local SlotsController = {}

-- // Services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // Dependencies
local Signal = require(ReplicatedStorage.Packages.Signal)
local GachaGuiUtil = require(ReplicatedStorage.Controllers.GachaGuiUtil)
local NotificationController = require(ReplicatedStorage.Controllers.NotificationController)
local ProductsData = require(ReplicatedStorage.Modules.Data.ProductsData)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

local LocalPlayer = Players.LocalPlayer

local DEFAULT_PRICE_TEXT = "0 R$"
local PRODUCT_INFO_TYPE = Enum.InfoType.Product

local _initialized = false
local _priceTextByType: {[string]: string} = {
	Flow = DEFAULT_PRICE_TEXT,
	Style = DEFAULT_PRICE_TEXT,
}

SlotsController.PriceTextChanged = Signal.new()

local function getSlotProductId(slotType: string): number?
	local productId = ProductsData.GetSlotProductId(slotType)
	return if typeof(productId) == "number" then productId else nil
end

local function formatRobuxPrice(amount: any): string
	local numericAmount = tonumber(amount) or 0
	return string.format("%s R$", GachaGuiUtil.FormatMoney(math.max(0, math.floor(numericAmount))))
end

local function setPriceText(slotType: string, priceText: string): ()
	if _priceTextByType[slotType] == priceText then
		return
	end

	_priceTextByType[slotType] = priceText
	SlotsController.PriceTextChanged:Fire(slotType, priceText)
end

local function fetchProductPriceText(slotType: string): ()
	local productId = getSlotProductId(slotType)
	if not productId then
		return
	end

	task.spawn(function()
		local success, info = pcall(function()
			local getter = MarketplaceService.GetProductInfoAsync or MarketplaceService.GetProductInfo
			return getter(MarketplaceService, productId, PRODUCT_INFO_TYPE)
		end)

		if not success or typeof(info) ~= "table" then
			warn(`[SlotsController] Failed to resolve price text for {slotType} slot product`)
			return
		end

		local priceInRobux = info.PriceInRobux
		if typeof(priceInRobux) ~= "number" then
			return
		end

		setPriceText(slotType, formatRobuxPrice(priceInRobux))
	end)
end

local function notifyPurchasePrepareError(errorCode: string?)
	if errorCode == "PREVIOUS_SLOT_LOCKED" then
		NotificationController.Notify("Slot locked", "Unlock the previous slot first.")
		return
	end
	if errorCode == "ALREADY_MAXED" then
		NotificationController.Notify("All slots unlocked", "You already unlocked every slot.")
		return
	end
	if errorCode == "PRODUCT_NOT_CONFIGURED" then
		NotificationController.Notify("Unavailable", "This slot product is not configured right now.")
		return
	end

	NotificationController.Notify("Unavailable", "This slot can't be purchased right now.")
end

function SlotsController.GetSlotPriceText(slotType: string): string
	return _priceTextByType[slotType] or DEFAULT_PRICE_TEXT
end

function SlotsController.GetSlotProductId(slotType: string): number?
	return getSlotProductId(slotType)
end

function SlotsController.PromptPurchaseSlot(slotType: string, slotIndex: number)
	local preparedResult = Packets.Slots:Fire("PreparePurchaseSlot", {
		SlotType = slotType,
		SlotIndex = slotIndex,
	})

	if typeof(preparedResult) ~= "table" or preparedResult.Success ~= true then
		notifyPurchasePrepareError(if typeof(preparedResult) == "table" then preparedResult.ErrorCode else nil)
		return
	end

	local productId = preparedResult.ProductId
	if typeof(productId) ~= "number" then
		NotificationController.Notify("Unavailable", "This slot product is not configured right now.")
		return
	end

	MarketplaceService:PromptProductPurchase(LocalPlayer, productId)
end

function SlotsController.Init()
	if _initialized then
		return
	end
	_initialized = true

	fetchProductPriceText("Flow")
	fetchProductPriceText("Style")
end

return SlotsController
