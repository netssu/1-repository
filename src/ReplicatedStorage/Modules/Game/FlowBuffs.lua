--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataGuard: any = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)
local FlowsData: any = require(ReplicatedStorage.Modules.Data.FlowsData)

export type FlowBuffValues = {
	Speed: number,
	Throw: number,
	CooldownReduction: number,
	Dribble: number,
	StaminaCostReduction: number,
	TackleStunReduction: number,
}

export type FlowDefinition = {
	Id: string,
	Buffs: FlowBuffValues,
	AnimationId: string?,
}

type FlowBuffAttributeName =
	"Speed"
	| "Throw"
	| "CooldownReduction"
	| "Dribble"
	| "StaminaCostReduction"
	| "TackleStunReduction"

type SpeedOptions = {
	IgnoreFlowBuff: boolean?,
	Reason: string?,
}

local FlowBuffs = {}

FlowBuffs.ATTR_FLOW_PERCENT = "FTFlowPercent"
FlowBuffs.ATTR_FLOW_ACTIVE = "FTFlowActive"
FlowBuffs.ATTR_FLOW_READY = "FTFlowReady"
FlowBuffs.ATTR_FLOW_TYPE = "FTFlowType"

FlowBuffs.MAX_FLOW_PERCENT = 100
FlowBuffs.ACTIVATION_THRESHOLD = 40
FlowBuffs.PASSIVE_GAIN_AMOUNT = 5
FlowBuffs.PASSIVE_GAIN_INTERVAL = 30
FlowBuffs.DRAIN_STEP = 1
FlowBuffs.DRAIN_INTERVAL = 1

local DEFAULT_SELECTED_SLOT: number = 1
local EMPTY_FLOW_ID: string = ""
local DEFAULT_FLOW_ANIMATION_ID: string = "rbxassetid://134076888722710"
local ASSETS_FOLDER_NAME: string = "Assets"
local EFFECTS_FOLDER_NAME: string = "Effects"
local AURAS_FOLDER_NAME: string = "Auras"

local ZERO_BUFFS: FlowBuffValues = table.freeze({
	Speed = 0,
	Throw = 0,
	CooldownReduction = 0,
	Dribble = 0,
	StaminaCostReduction = 0,
	TackleStunReduction = 0,
})

local DEFINITIONS: {[string]: FlowDefinition} = {
	GalaxyAura = {
		Id = "GalaxyAura",
		Buffs = {
			Speed = 3,
			Throw = 55,
			CooldownReduction = 0.12,
			Dribble = 8,
			StaminaCostReduction = 0.12,
			TackleStunReduction = 0.18,
		},
		AnimationId = DEFAULT_FLOW_ANIMATION_ID,
	},
	WarriorAura = {
		Id = "WarriorAura",
		Buffs = {
			Speed = 4,
			Throw = 20,
			CooldownReduction = 0.05,
			Dribble = 10,
			StaminaCostReduction = 0.08,
			TackleStunReduction = 0.25,
		},
		AnimationId = DEFAULT_FLOW_ANIMATION_ID,
	},
	DarkMatter = {
		Id = "DarkMatter",
		Buffs = {
			Speed = 2,
			Throw = 35,
			CooldownReduction = 0.2,
			Dribble = 6,
			StaminaCostReduction = 0.2,
			TackleStunReduction = 0.12,
		},
		AnimationId = DEFAULT_FLOW_ANIMATION_ID,
	},
	PhantomAura = {
		Id = "PhantomAura",
		Buffs = {
			Speed = 2,
			Throw = 70,
			CooldownReduction = 0.08,
			Dribble = 14,
			StaminaCostReduction = 0.1,
			TackleStunReduction = 0.1,
		},
		AnimationId = DEFAULT_FLOW_ANIMATION_ID,
	},
	MegaAura = {
		Id = "MegaAura",
		Buffs = {
			Speed = 2,
			Throw = 25,
			CooldownReduction = 0.06,
			Dribble = 5,
			StaminaCostReduction = 0.1,
			TackleStunReduction = 0.08,
		},
		AnimationId = DEFAULT_FLOW_ANIMATION_ID,
	},
}

FlowBuffs.BUFF_ATTRIBUTE_NAMES = table.freeze({
	"Speed",
	"Throw",
	"CooldownReduction",
	"Dribble",
	"StaminaCostReduction",
	"TackleStunReduction",
})

local function GetCharacterAttribute(Player: Player, AttributeName: string): any
	local Character: Model? = Player.Character
	if not Character then
		return nil
	end
	return Character:GetAttribute(AttributeName)
end

local function GetAttribute(Player: Player, AttributeName: string): any
	local Value: any = Player:GetAttribute(AttributeName)
	if Value ~= nil then
		return Value
	end
	return GetCharacterAttribute(Player, AttributeName)
end

local function NormalizeAnimationId(Value: any): string?
	if typeof(Value) == "number" then
		Value = tostring(math.floor(Value + 0.5))
	end
	if typeof(Value) ~= "string" then
		return nil
	end

	local TrimmedValue: string = string.gsub(string.gsub(Value, "^%s+", ""), "%s+$", "")
	if TrimmedValue == "" then
		return ""
	end

	if string.sub(TrimmedValue, 1, #"rbxassetid://") == "rbxassetid://" then
		return TrimmedValue
	end

	if string.match(TrimmedValue, "^%d+$") then
		return "rbxassetid://" .. TrimmedValue
	end

	return TrimmedValue
end

local function ResolveAurasFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	local EffectsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(EFFECTS_FOLDER_NAME)
	if not EffectsFolder then
		return nil
	end

	return EffectsFolder:FindFirstChild(AURAS_FOLDER_NAME)
end

local function ResolveAuraTemplate(FlowId: string): Instance?
	local AurasFolder: Instance? = ResolveAurasFolder()
	if not AurasFolder then
		return nil
	end

	local FlowData: any = FlowsData[FlowId]
	local AuraModelName: string =
		if FlowData and typeof(FlowData.AuraModelName) == "string" and FlowData.AuraModelName ~= ""
			then FlowData.AuraModelName
			else FlowId

	return AurasFolder:FindFirstChild(AuraModelName)
end

local function ResolveBuffValue(
	AuraTemplate: Instance?,
	AttributeName: FlowBuffAttributeName,
	FallbackDefinition: FlowDefinition?
): number
	if AuraTemplate then
		local AttributeValue: any = AuraTemplate:GetAttribute(AttributeName)
		if typeof(AttributeValue) == "number" then
			return AttributeValue
		end
	end

	if FallbackDefinition then
		local FallbackValue: any = FallbackDefinition.Buffs[AttributeName]
		if typeof(FallbackValue) == "number" then
			return FallbackValue
		end
	end

	return 0
end

local function ResolveAnimationId(AuraTemplate: Instance?, FlowId: string, FallbackDefinition: FlowDefinition?): string?
	if AuraTemplate then
		local AttributeAnimationId: string? = NormalizeAnimationId(AuraTemplate:GetAttribute("AnimationId"))
		if AttributeAnimationId ~= nil then
			return AttributeAnimationId
		end
	end

	local FlowData: any = FlowsData[FlowId]
	local FlowDataAnimationId: string? = NormalizeAnimationId(FlowData and FlowData.AnimationId)
	if FlowDataAnimationId ~= nil then
		return FlowDataAnimationId
	end

	if FallbackDefinition and type(FallbackDefinition.AnimationId) == "string" then
		return FallbackDefinition.AnimationId
	end

	return DEFAULT_FLOW_ANIMATION_ID
end

local function ResolveDynamicDefinition(FlowId: string): FlowDefinition?
	local AuraTemplate: Instance? = ResolveAuraTemplate(FlowId)
	if not AuraTemplate then
		return nil
	end

	local FallbackDefinition: FlowDefinition? = DEFINITIONS[FlowId]
	return {
		Id = FlowId,
		Buffs = {
			Speed = ResolveBuffValue(AuraTemplate, "Speed", FallbackDefinition),
			Throw = ResolveBuffValue(AuraTemplate, "Throw", FallbackDefinition),
			CooldownReduction = ResolveBuffValue(AuraTemplate, "CooldownReduction", FallbackDefinition),
			Dribble = ResolveBuffValue(AuraTemplate, "Dribble", FallbackDefinition),
			StaminaCostReduction = ResolveBuffValue(AuraTemplate, "StaminaCostReduction", FallbackDefinition),
			TackleStunReduction = ResolveBuffValue(AuraTemplate, "TackleStunReduction", FallbackDefinition),
		},
		AnimationId = ResolveAnimationId(AuraTemplate, FlowId, FallbackDefinition),
	}
end

function FlowBuffs.GetDefinition(FlowId: string?): FlowDefinition?
	if typeof(FlowId) ~= "string" or FlowId == EMPTY_FLOW_ID then
		return nil
	end

	local DynamicDefinition: FlowDefinition? = ResolveDynamicDefinition(FlowId)
	if DynamicDefinition then
		return DynamicDefinition
	end

	return DEFINITIONS[FlowId]
end

function FlowBuffs.GetEquippedFlowId(Player: Player): string?
	local SelectedSlot: number = PlayerDataGuard.GetOrDefault(Player, { "SelectedFlowSlot" }, DEFAULT_SELECTED_SLOT)
	if typeof(SelectedSlot) ~= "number" then
		SelectedSlot = PlayerDataGuard.GetOrDefault(Player, { "SelectedSlot" }, DEFAULT_SELECTED_SLOT)
	end
	local FlowSlots: {[string]: string} = PlayerDataGuard.GetOrDefault(Player, { "FlowSlots" }, {})
	local SlotKey: string = "Slot" .. tostring(SelectedSlot)
	local FlowId: any = FlowSlots[SlotKey]
	if typeof(FlowId) ~= "string" or FlowId == EMPTY_FLOW_ID then
		return nil
	end
	return FlowId
end

function FlowBuffs.IsFlowActive(Player: Player): boolean
	return GetAttribute(Player, FlowBuffs.ATTR_FLOW_ACTIVE) == true
end

function FlowBuffs.GetFlowPercent(Player: Player): number
	local Value: any = GetAttribute(Player, FlowBuffs.ATTR_FLOW_PERCENT)
	if typeof(Value) ~= "number" then
		return 0
	end
	return math.clamp(math.round(Value), 0, FlowBuffs.MAX_FLOW_PERCENT)
end

function FlowBuffs.GetActiveFlowId(Player: Player): string?
	if not FlowBuffs.IsFlowActive(Player) then
		return nil
	end
	local FlowId: any = GetAttribute(Player, FlowBuffs.ATTR_FLOW_TYPE)
	if typeof(FlowId) ~= "string" or FlowId == EMPTY_FLOW_ID then
		return nil
	end
	return FlowId
end

function FlowBuffs.GetActiveBuffs(Player: Player): FlowBuffValues
	local FlowId: string? = FlowBuffs.GetActiveFlowId(Player)
	local Definition: FlowDefinition? = FlowBuffs.GetDefinition(FlowId)
	if not Definition then
		return ZERO_BUFFS
	end
	return Definition.Buffs
end

function FlowBuffs.ApplySpeedBuff(Player: Player, BaseSpeed: number, Options: SpeedOptions?): number
	if typeof(BaseSpeed) ~= "number" then
		return 0
	end
	if BaseSpeed <= 0 then
		return BaseSpeed
	end
	if Options and Options.IgnoreFlowBuff == true then
		return BaseSpeed
	end
	if Options and Options.Reason == "Stun" then
		return BaseSpeed
	end
	local Buffs: FlowBuffValues = FlowBuffs.GetActiveBuffs(Player)
	return BaseSpeed + Buffs.Speed
end

function FlowBuffs.ApplyHumanoidWalkSpeed(Player: Player, Humanoid: Humanoid, BaseSpeed: number, Options: SpeedOptions?): number
	local ResolvedSpeed: number = FlowBuffs.ApplySpeedBuff(Player, BaseSpeed, Options)
	Humanoid.WalkSpeed = ResolvedSpeed
	return ResolvedSpeed
end

function FlowBuffs.ResolveRestoredWalkSpeed(Player: Player, StoredSpeed: number?, DefaultBaseSpeed: number): number
	if typeof(StoredSpeed) ~= "number" or StoredSpeed <= 0 then
		return FlowBuffs.ApplySpeedBuff(Player, DefaultBaseSpeed)
	end
	if FlowBuffs.IsFlowActive(Player) and StoredSpeed <= DefaultBaseSpeed then
		return FlowBuffs.ApplySpeedBuff(Player, DefaultBaseSpeed)
	end
	return StoredSpeed
end

function FlowBuffs.ApplyThrowDistanceBuff(Player: Player, BaseDistance: number): number
	if typeof(BaseDistance) ~= "number" then
		return 0
	end
	local Buffs: FlowBuffValues = FlowBuffs.GetActiveBuffs(Player)
	return math.max(BaseDistance + Buffs.Throw, 0)
end

function FlowBuffs.ApplyCooldownReduction(Player: Player, BaseCooldown: number): number
	if typeof(BaseCooldown) ~= "number" then
		return 0
	end
	local Buffs: FlowBuffValues = FlowBuffs.GetActiveBuffs(Player)
	return math.max(BaseCooldown * (1 - Buffs.CooldownReduction), 0)
end

function FlowBuffs.ApplyStaminaCostReduction(Player: Player, BaseCost: number): number
	if typeof(BaseCost) ~= "number" then
		return 0
	end
	local Buffs: FlowBuffValues = FlowBuffs.GetActiveBuffs(Player)
	return math.max(BaseCost * (1 - Buffs.StaminaCostReduction), 0)
end

function FlowBuffs.ApplyTackleStunReduction(Player: Player, BaseDuration: number): number
	if typeof(BaseDuration) ~= "number" then
		return 0
	end
	local Buffs: FlowBuffValues = FlowBuffs.GetActiveBuffs(Player)
	return math.max(BaseDuration * (1 - Buffs.TackleStunReduction), 0)
end

function FlowBuffs.GetDribbleBonus(Player: Player): number
	local Buffs: FlowBuffValues = FlowBuffs.GetActiveBuffs(Player)
	return Buffs.Dribble
end

return FlowBuffs
