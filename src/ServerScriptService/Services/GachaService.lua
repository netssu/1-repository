local GachaService = {}

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketPlaceService = game:GetService("MarketplaceService")

-- MODULES
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local GachaManager = require(ReplicatedStorage.Modules.Game.GachaManager)
local Packet = require(ReplicatedStorage.Modules.Game.Packets)

-- CONSTANTS
local SPIN_COST = 1
local SPIN_COOLDOWN = 1.5

local SKIP_SPIN_COOLDOWN = 0.5
local MAX_SLOTS_BY_TYPE = {
	Style = 4,
	Flow = 6,
}


-- STATE
local playersDebounce = {}

local function getSelectedSlotPath(gachaType: string): { string }
	return { if gachaType == "Flow" then "SelectedFlowSlot" else "SelectedSlot" }
end

local function resolveSlotNumber(gachaType: string, value: any): number
	local maxSlots = MAX_SLOTS_BY_TYPE[gachaType] or 1
	if typeof(value) ~= "number" then
		return 1
	end
	local slotNumber = math.floor(value)
	if slotNumber < 1 or slotNumber > maxSlots then
		return 1
	end
	return slotNumber
end

local function parseEquipPayload(slotPayload: any): (number?, string?)
	if typeof(slotPayload) == "string" then
		local slotType, slotNumberText = string.match(slotPayload, "^(%a+):(%d+)$")
		if slotType and slotNumberText then
			local normalizedSlotType = string.lower(slotType)
			if normalizedSlotType == "flow" then
				return tonumber(slotNumberText), "Flow"
			elseif normalizedSlotType == "style" then
				return tonumber(slotNumberText), "Style"
			end
			return tonumber(slotNumberText), nil
		end
		return tonumber(slotPayload), nil
	end
	if typeof(slotPayload) == "number" then
		return slotPayload, nil
	end
	return nil, nil
end

function GachaService:OnSpinRequest(player, gachaType, isLuckySpin)
	print(isLuckySpin)
	if gachaType ~= "Style" and gachaType ~= "Flow" then
		return
	end

	local currencyKey
	if isLuckySpin then
		currencyKey = `{gachaType}LuckySpins`
	else
		currencyKey = (gachaType == "Style") and "SpinStyle" or "SpinFlow"
	end

	local slotsKey = (gachaType == "Style") and "StyleSlots" or "FlowSlots"

	local currentSpins = PlayerDataManager:Get(player, { currencyKey })
	local isSkipSpinActivated = PlayerDataManager:Get(player, { "Settings", "SkipSpinActivated" })

	local localDebounce = playersDebounce[player]
	if not isSkipSpinActivated and typeof(localDebounce) == "number" and tick() - localDebounce < SPIN_COOLDOWN then
		return "Spin on cooldown"
	elseif isSkipSpinActivated and typeof(localDebounce) == "number" and tick() - localDebounce < SKIP_SPIN_COOLDOWN then
		return "Spin on cooldown"
	end

	if currentSpins == nil or currentSpins < SPIN_COST then
		warn(player.Name .. " has insufficient spins.")
		 return "Insufficient spins"
	end

	playersDebounce[player] = tick()
	PlayerDataManager:Set(player, { currencyKey }, currentSpins - SPIN_COST)

	local rollOptions = isLuckySpin and { MinRarity = "Rare" } or nil
	local resultId, resultData = GachaManager.Roll(gachaType, rollOptions)

	if resultId and resultData then
		local currentSlotNum = resolveSlotNumber(gachaType, PlayerDataManager:Get(player, getSelectedSlotPath(gachaType)))
		local slotKey = "Slot" .. tostring(currentSlotNum)
		PlayerDataManager:Set(player, { slotsKey, slotKey }, resultId)
		Packet.SpinResult:FireClient(player, gachaType, resultId, resultData)
	else
		PlayerDataManager:Set(player, { currencyKey }, currentSpins)
		Packet.SpinResult:FireClient(player, gachaType, nil, nil)
	end

	return true
end

function GachaService:OnEquipRequest(player, slotNumber, slotType)
	local resolvedSlotType = if slotType == "Flow" then "Flow" else "Style"
	local maxSlots = MAX_SLOTS_BY_TYPE[resolvedSlotType]
	if type(slotNumber) ~= "number" or slotNumber < 1 or slotNumber > maxSlots then
		return
	end
	local selectedPath = getSelectedSlotPath(resolvedSlotType)
	PlayerDataManager:Set(player, selectedPath, math.floor(slotNumber))
end

function GachaService:Start()
	Packet.RequestSpin.OnServerInvoke = function(player, gachaType, isLuckySpin)
		return self:OnSpinRequest(player, gachaType, isLuckySpin)
	end

	if Packet.RequestEquip then
		Packet.RequestEquip.OnServerEvent:Connect(function(player, slotPayload)
			local slotNumber, slotType = parseEquipPayload(slotPayload)
			self:OnEquipRequest(player, slotNumber, slotType)
		end)
	else
		warn("WARNING: Create the RemoteEvent 'RequestEquip' in Packets!")
	end

	if Packet.RequestSkipSpin then
		Packet.RequestSkipSpin.OnServerInvoke = function(player)
			local success, hasSkip = pcall(function()
				return MarketPlaceService:UserOwnsGamePassAsync(player.UserId, 1729754185)
			end) --PlayerDataManager:Get(player, {"Gamepass", "SkipSpin"})
			if not success or not hasSkip then
				MarketPlaceService:PromptGamePassPurchase(player, 1729754185)
				return nil
			end

			local currentState = PlayerDataManager:Get(player, { "Settings", "SkipSpinActivated" })
			PlayerDataManager:Set(player, { "Settings", "SkipSpinActivated" }, not currentState)

			return not currentState
		end
	end

	print("GachaService started.")
end

return GachaService
