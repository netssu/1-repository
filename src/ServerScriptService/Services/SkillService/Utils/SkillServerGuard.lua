--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local ATTR_STUNNED: string = "FTStunned"
local ATTR_INVULNERABLE: string = "Invulnerable"
local ATTR_CHARGING_THROW: string = "FTChargingThrow"
local ATTR_CAN_ACT: string = "FTCanAct"
local ATTR_CAN_SPIN: string = "FTCanSpin"
local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local ATTR_MATCH_CUTSCENE_LOCKED: string = "FTMatchCutsceneLocked"

local GAME_STATE_FOLDER: string = "FTGameState"
local INTERMISSION_ACTIVE_NAME: string = "IntermissionActive"
local COUNTDOWN_ACTIVE_NAME: string = "CountdownActive"
local EXTRA_POINT_ACTIVE_NAME: string = "ExtraPointActive"
local MATCH_STARTED_NAME: string = "MatchStarted"

local SkillServerGuard = {}
local CachedGameStateFolder: Folder? = nil
local CachedStateValues: {[string]: BoolValue} = {}

local function GetGameStateFolder(): Folder?
	if CachedGameStateFolder and CachedGameStateFolder.Parent then
		return CachedGameStateFolder
	end
	local GameStateFolder: Instance? = ReplicatedStorage:FindFirstChild(GAME_STATE_FOLDER)
	if GameStateFolder and GameStateFolder:IsA("Folder") then
		CachedGameStateFolder = GameStateFolder
		return GameStateFolder
	end
	CachedGameStateFolder = nil
	return nil
end

local function GetStateBoolValue(Name: string): boolean
	local CachedValue: BoolValue? = CachedStateValues[Name]
	if CachedValue and CachedValue.Parent then
		return CachedValue.Value
	end

	local GameStateFolder: Folder? = GetGameStateFolder()
	if not GameStateFolder then
		return false
	end
	local ValueInstance: Instance? = GameStateFolder:FindFirstChild(Name)
	if not ValueInstance or not ValueInstance:IsA("BoolValue") then
		return false
	end
	CachedStateValues[Name] = ValueInstance
	return ValueInstance.Value
end

local function IsAttributeTrue(Target: Instance?, AttributeName: string): boolean
	if not Target then
		return false
	end
	return Target:GetAttribute(AttributeName) == true
end

local function IsAttributeFalse(Target: Instance?, AttributeName: string): boolean
	if not Target then
		return false
	end
	return Target:GetAttribute(AttributeName) == false
end

function SkillServerGuard.IsBlockedByAttributes(Player: Player, Character: Model?): boolean
	if IsAttributeTrue(Player, ATTR_STUNNED) then
		return true
	end
	if IsAttributeTrue(Character, ATTR_STUNNED) then
		return true
	end
	if IsAttributeTrue(Player, ATTR_INVULNERABLE) then
		return true
	end
	if IsAttributeTrue(Character, ATTR_INVULNERABLE) then
		return true
	end
	if IsAttributeTrue(Player, ATTR_CHARGING_THROW) then
		return true
	end
	if IsAttributeTrue(Character, ATTR_CHARGING_THROW) then
		return true
	end
	if IsAttributeFalse(Player, ATTR_CAN_ACT) then
		return true
	end
	if IsAttributeFalse(Character, ATTR_CAN_ACT) then
		return true
	end
	if IsAttributeFalse(Player, ATTR_CAN_SPIN) then
		return true
	end
	if IsAttributeFalse(Character, ATTR_CAN_SPIN) then
		return true
	end
	if IsAttributeTrue(Player, ATTR_SKILL_LOCKED) then
		return true
	end
	if IsAttributeTrue(Character, ATTR_SKILL_LOCKED) then
		return true
	end
	if IsAttributeTrue(Player, ATTR_MATCH_CUTSCENE_LOCKED) then
		return true
	end
	if IsAttributeTrue(Character, ATTR_MATCH_CUTSCENE_LOCKED) then
		return true
	end
	return false
end

function SkillServerGuard.IsSkillWindowOpen(): boolean
	if GetStateBoolValue(INTERMISSION_ACTIVE_NAME) then
		return false
	end
	if GetStateBoolValue(COUNTDOWN_ACTIVE_NAME) then
		return false
	end
	if GetStateBoolValue(EXTRA_POINT_ACTIVE_NAME) then
		return false
	end
	if not GetStateBoolValue(MATCH_STARTED_NAME) then
		return false
	end
	return true
end

function SkillServerGuard.CanUseSkill(
	Player: Player,
	Character: Model?,
	SlotIndex: number,
	MinSlot: number,
	MaxSlot: number,
	IsPlayerInMatch: (Player: Player) -> boolean
): boolean
	if SlotIndex < MinSlot or SlotIndex > MaxSlot then
		return false
	end
	if not Character then
		return false
	end
	if not IsPlayerInMatch(Player) then
		return false
	end
	if not SkillServerGuard.IsSkillWindowOpen() then
		return false
	end
	if SkillServerGuard.IsBlockedByAttributes(Player, Character) then
		return false
	end
	return true
end

function SkillServerGuard.CanUseAwaken(
	Player: Player,
	Character: Model?,
	IsPlayerInMatch: (Player: Player) -> boolean
): boolean
	if not Character then
		return false
	end
	if not IsPlayerInMatch(Player) then
		return false
	end
	if not SkillServerGuard.IsSkillWindowOpen() then
		return false
	end
	if SkillServerGuard.IsBlockedByAttributes(Player, Character) then
		return false
	end
	return true
end

return SkillServerGuard
