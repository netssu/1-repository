--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local PlayerIdentity: any = require(ReplicatedStorage.Modules.Game.PlayerIdentity)

local ATTR_STUNNED: string = "FTStunned"
local ATTR_INVULNERABLE: string = "Invulnerable"
local ATTR_CHARGING_THROW: string = "FTChargingThrow"
local ATTR_CAN_ACT: string = "FTCanAct"
local ATTR_CAN_SPIN: string = "FTCanSpin"
local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local ATTR_MATCH_CUTSCENE_LOCKED: string = "FTMatchCutsceneLocked"
local ATTR_PERFECT_PASS_CUTSCENE_LOCKED: string = "FTPerfectPassCutsceneLocked"
local ATTR_CUTSCENE_HUD_HIDDEN: string = "FTCutsceneHudHidden"
local BALL_DATA_NAME: string = "FTBallData"
local BALL_POSSESSION_ATTR: string = "FTBall_Possession"

local GAME_STATE_FOLDER: string = "FTGameState"
local INTERMISSION_ACTIVE_NAME: string = "IntermissionActive"
local COUNTDOWN_ACTIVE_NAME: string = "CountdownActive"
local EXTRA_POINT_ACTIVE_NAME: string = "ExtraPointActive"
local MATCH_STARTED_NAME: string = "MatchStarted"
local BALL_CARRIER_NAME: string = "BallCarrier"

local CachedGameStateFolder: Folder? = nil
local CachedStateValues: {[string]: BoolValue} = {}
local CachedBallCarrierValue: ObjectValue? = nil

local function getGameStateFolder(): Folder?
	if CachedGameStateFolder and CachedGameStateFolder.Parent then
		return CachedGameStateFolder
	end
	local gameState = ReplicatedStorage:FindFirstChild(GAME_STATE_FOLDER)
	if gameState and gameState:IsA("Folder") then
		CachedGameStateFolder = gameState
		return gameState
	end
	CachedGameStateFolder = nil
	return nil
end

local function getBoolValue(Name: string): boolean
	local cachedValue: BoolValue? = CachedStateValues[Name]
	if cachedValue and cachedValue.Parent then
		return cachedValue.Value
	end

	local gameState = getGameStateFolder()
	if not gameState then
		return false
	end
	local value = gameState:FindFirstChild(Name)
	if value and value:IsA("BoolValue") then
		CachedStateValues[Name] = value
		return value.Value
	end
	return false
end

local function isBlockedByAttributes(Player: Player, Character: Model?): boolean
	if Player:GetAttribute(ATTR_STUNNED) == true then
		return true
	end
	if Player:GetAttribute(ATTR_INVULNERABLE) == true then
		return true
	end
	if Player:GetAttribute(ATTR_CHARGING_THROW) == true then
		return true
	end
	if Player:GetAttribute(ATTR_CAN_ACT) == false then
		return true
	end
	if Player:GetAttribute(ATTR_CAN_SPIN) == false then
		return true
	end
	if Player:GetAttribute(ATTR_SKILL_LOCKED) == true then
		return true
	end
	if Player:GetAttribute(ATTR_MATCH_CUTSCENE_LOCKED) == true then
		return true
	end
	if Player:GetAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED) == true then
		return true
	end
	if Player:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true then
		return true
	end

	if not Character then
		return false
	end
	if Character:GetAttribute(ATTR_STUNNED) == true then
		return true
	end
	if Character:GetAttribute(ATTR_INVULNERABLE) == true then
		return true
	end
	if Character:GetAttribute(ATTR_CHARGING_THROW) == true then
		return true
	end
	if Character:GetAttribute(ATTR_CAN_ACT) == false then
		return true
	end
	if Character:GetAttribute(ATTR_CAN_SPIN) == false then
		return true
	end
	if Character:GetAttribute(ATTR_SKILL_LOCKED) == true then
		return true
	end
	if Character:GetAttribute(ATTR_MATCH_CUTSCENE_LOCKED) == true then
		return true
	end
	if Character:GetAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED) == true then
		return true
	end
	if Character:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true then
		return true
	end
	return false
end

local function getBallCarrierValue(): ObjectValue?
	local cachedValue: ObjectValue? = CachedBallCarrierValue
	if cachedValue and cachedValue.Parent then
		return cachedValue
	end

	local gameState = getGameStateFolder()
	if not gameState then
		return nil
	end

	local value = gameState:FindFirstChild(BALL_CARRIER_NAME)
	if value and value:IsA("ObjectValue") then
		CachedBallCarrierValue = value
		return value
	end

	CachedBallCarrierValue = nil
	return nil
end

local function isHoldingBall(Player: Player): boolean
	local ballCarrierValue: ObjectValue? = getBallCarrierValue()
	if ballCarrierValue and ballCarrierValue.Value == Player then
		return true
	end

	local ballData: Instance? = ReplicatedStorage:FindFirstChild(BALL_DATA_NAME)
	if not ballData then
		return false
	end

	local possessionId: any = ballData:GetAttribute(BALL_POSSESSION_ATTR)
	if typeof(possessionId) ~= "number" or possessionId <= 0 then
		return false
	end

	return possessionId == PlayerIdentity.GetIdValue(Player)
end

local SkillClientGuard = {}

function SkillClientGuard.IsHoldingBall(Player: Player): boolean
	return isHoldingBall(Player)
end

function SkillClientGuard.CanUseSkill(Player: Player): boolean
	local character = Player.Character
	if isBlockedByAttributes(Player, character) then
		return false
	end
	if getBoolValue(INTERMISSION_ACTIVE_NAME) then
		return false
	end
	if getBoolValue(COUNTDOWN_ACTIVE_NAME) then
		return false
	end
	if getBoolValue(EXTRA_POINT_ACTIVE_NAME) then
		return false
	end
	if not getBoolValue(MATCH_STARTED_NAME) then
		return false
	end
	return true
end

function SkillClientGuard.CanUseAwaken(Player: Player): boolean
	if not isHoldingBall(Player) then
		return false
	end
	if not SkillClientGuard.CanUseSkill(Player) then
		return false
	end
	if RunService:IsStudio() then
		return true
	end
	return true
end

return SkillClientGuard
