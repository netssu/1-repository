--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local RunService: RunService = game:GetService("RunService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local PlayerDataManager: any = require(ReplicatedStorage.Packages.PlayerDataManager)
local SharedSkills: any = require(ReplicatedStorage.Modules.Game.Skills)
local Utility: any = require(ReplicatedStorage.Modules.Game.Utility)
local FlowBuffs: any = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local FTPlayerService: any = require(script.Parent.PlayerService)
local FTBallService: any = require(script.Parent.BallService)
local SkillCooldownStore: any = require(script.Utils.SkillCooldownStore)
local SkillExecutionLock: any = require(script.Utils.SkillExecutionLock)
local SkillModuleRegistry: any = require(script.Utils.SkillModuleRegistry)
local SkillServerGuard: any = require(script.Utils.SkillServerGuard)

local SkillsFolder: Folder = ServerScriptService:WaitForChild("Skills") :: Folder

type SkillDefinition = {
	Id: string,
	Name: string,
	Cooldown: number,
	Benefit: string,
	VFXPath: string,
	Module: string,
	VFX: any,
	Input: any?,
	RequiresBall: boolean?,
	BlocksWhenHoldingBall: boolean?,
}

type SkillInputBehavior = {
	Mode: string,
}

type SkillHoldState = {
	Token: number,
	SlotIndex: number,
	StartedAt: number,
	Released: boolean,
	ReleasedAt: number?,
	HoldDuration: number,
	Active: boolean,
}

local FTSkillService: {[string]: any} = {}

--// CONSTANTS
local ZERO: number = 0
local ONE: number = 1

local DROP_INTERVAL_SECONDS: number = 60
local MIN_SLOT_INDEX: number = ONE
local MAX_SLOT_INDEX: number = 3
local DEFAULT_SELECTED_SLOT: number = ONE
local STUDIO_DEFAULT_STYLE_ID: string = "SenaKobayakawa"
local STUDIO_DEFAULT_STYLE_SLOT_KEY: string = "Slot1"
local HIRUMA_STYLE_ID: string = "Hiruma"
local HIRUMA_THROW_MODULE_NAME: string = "HirumaThrow"
local HIRUMA_AWAKEN_CUTSCENE_SOUND_ID: number = 85191165659657

local SKILL_EXECUTION_LOCK_WINDOW: number = 0.2
local AWAKEN_EXECUTION_LOCK_WINDOW: number = 0.35

local ATTR_AWAKEN_READY: string = "AwakenReady"
local ATTR_AWAKEN_ACTIVE: string = "AwakenActive"

local GAME_STATE_FOLDER: string = "FTGameState"
local MATCH_STARTED_NAME: string = "MatchStarted"

local AWAKEN_STATUS_READY: string = "Ready"
local AWAKEN_STATUS_START: string = "Start"
local AWAKEN_STATUS_END: string = "End"
local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local DEFAULT_WALKSPEED: number = 16
local DEFAULT_JUMPPOWER: number = 50
local DEFAULT_JUMPHEIGHT: number = 7.2
local STUDIO_ALWAYS_READY_AWAKEN: boolean = RunService:IsStudio()
local EMPTY_AIM_TARGET: Vector3 = Vector3.zero
local SKILL_HOLD_ACTION_BEGIN: number = 1
local SKILL_HOLD_ACTION_RELEASE: number = 2
local HOLD_INPUT_MODE: string = "Hold"

type AwakenState = {
	Ready: boolean,
	Active: boolean,
	EndTime: number,
	Token: number,
}

type CutsceneLockState = {
	Active: boolean,
	Token: number,
	Character: Model?,
	RootAnchoredBefore: boolean?,
	HumanoidAutoRotateBefore: boolean?,
	HumanoidWalkSpeedBefore: number?,
	HumanoidJumpPowerBefore: number?,
	HumanoidJumpHeightBefore: number?,
	HumanoidUseJumpPowerBefore: boolean?,
}

type PlayerState = {
	Cooldowns: {[string]: number},
	Awaken: AwakenState,
	CutsceneLock: CutsceneLockState,
	SkillHolds: {[number]: SkillHoldState},
}

local PlayerStates: {[Player]: PlayerState} = {}
local LastMatchStarted: boolean = false
local HoldStateTokenCounter: number = ZERO

local SkillsData: any = SharedSkills
local RequestLock: any = SkillExecutionLock.new(SKILL_EXECUTION_LOCK_WINDOW)
local SkillRegistry: any = SkillModuleRegistry.new(SkillsFolder)

local function IsPlayerInMatch(Player: Player): boolean
	return FTPlayerService:IsPlayerInMatch(Player)
end

local function IsFiniteNumber(Value: number): boolean
	return Value == Value and Value > -math.huge and Value < math.huge
end

local function SanitizeAimTarget(AimTarget: any): Vector3?
	if typeof(AimTarget) ~= "Vector3" then
		return nil
	end
	if AimTarget == EMPTY_AIM_TARGET then
		return nil
	end
	if not IsFiniteNumber(AimTarget.X) or not IsFiniteNumber(AimTarget.Y) or not IsFiniteNumber(AimTarget.Z) then
		return nil
	end
	return Utility.ClampToMap(AimTarget)
end

local function SanitizeCutsceneCFrame(Target: any): CFrame?
	if typeof(Target) ~= "CFrame" then
		return nil
	end

	local Components = {Target:GetComponents()}
	for _, Component in Components do
		if not IsFiniteNumber(Component) then
			return nil
		end
	end

	local Position: Vector3 = Utility.ClampToMap(Target.Position)
	return CFrame.fromMatrix(Position, Target.XVector, Target.YVector, Target.ZVector)
end

local ResolveAlignmentPart: (Character: Model) -> BasePart?

local function AlignCharacterToCFrame(Character: Model, TargetCFrame: CFrame): ()
	local AlignmentPart: BasePart? = ResolveAlignmentPart(Character)
	if not AlignmentPart then
		return
	end

	local CharacterPivot: CFrame = Character:GetPivot()
	local AlignmentOffset: CFrame = CharacterPivot:ToObjectSpace(AlignmentPart.CFrame)
	Character:PivotTo(TargetCFrame * AlignmentOffset:Inverse())

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end
end

ResolveAlignmentPart = function(Character: Model): BasePart?
	for _, PartName in { "Torso", "UpperTorso", "HumanoidRootPart" } do
		local Part: Instance? = Character:FindFirstChild(PartName, true)
		if Part and Part:IsA("BasePart") then
			return Part
		end
	end
	return Character:FindFirstChildWhichIsA("BasePart", true)
end

local function EnsurePlayerState(Player: Player): PlayerState
	local Existing: PlayerState? = PlayerStates[Player]
	if Existing then
		return Existing
	end
	local NewState: PlayerState = {
		Cooldowns = {},
		Awaken = {
			Ready = false,
			Active = false,
			EndTime = ZERO,
			Token = ZERO,
		},
		CutsceneLock = {
			Active = false,
			Token = ZERO,
			Character = nil,
			RootAnchoredBefore = nil,
			HumanoidAutoRotateBefore = nil,
			HumanoidWalkSpeedBefore = nil,
			HumanoidJumpPowerBefore = nil,
			HumanoidJumpHeightBefore = nil,
			HumanoidUseJumpPowerBefore = nil,
		},
		SkillHolds = {},
	}
	PlayerStates[Player] = NewState
	return NewState
end

local function GetSkillInputBehavior(Skill: SkillDefinition?): SkillInputBehavior
	return SkillsData.GetSkillInputBehavior(Skill)
end

local function NextHoldStateToken(): number
	HoldStateTokenCounter += ONE
	return HoldStateTokenCounter
end

local function GetSkillHoldState(Player: Player, SlotIndex: number): SkillHoldState?
	local StateData: PlayerState = EnsurePlayerState(Player)
	return StateData.SkillHolds[SlotIndex]
end

local function CreateSkillHoldState(Player: Player, SlotIndex: number): SkillHoldState?
	local StateData: PlayerState = EnsurePlayerState(Player)
	if StateData.SkillHolds[SlotIndex] ~= nil then
		return nil
	end

	local HoldState: SkillHoldState = {
		Token = NextHoldStateToken(),
		SlotIndex = SlotIndex,
		StartedAt = os.clock(),
		Released = false,
		ReleasedAt = nil,
		HoldDuration = ZERO,
		Active = true,
	}
	StateData.SkillHolds[SlotIndex] = HoldState
	return HoldState
end

local function MarkSkillHoldReleased(Player: Player, SlotIndex: number, HoldDuration: number): ()
	local HoldState: SkillHoldState? = GetSkillHoldState(Player, SlotIndex)
	if not HoldState or not HoldState.Active then
		return
	end

	HoldState.Released = true
	HoldState.ReleasedAt = os.clock()
	HoldState.HoldDuration = math.max(HoldDuration, ZERO)
end

local function ClearSkillHoldState(Player: Player, SlotIndex: number, Token: number?): ()
	local StateData: PlayerState = EnsurePlayerState(Player)
	local HoldState: SkillHoldState? = StateData.SkillHolds[SlotIndex]
	if not HoldState then
		return
	end
	if Token ~= nil and HoldState.Token ~= Token then
		return
	end

	HoldState.Active = false
	StateData.SkillHolds[SlotIndex] = nil
end

local function ClearAllSkillHoldStates(StateData: PlayerState): ()
	for SlotIndex, HoldState in StateData.SkillHolds do
		HoldState.Active = false
		StateData.SkillHolds[SlotIndex] = nil
	end
end

local function SetAwakenAttributes(Player: Player, Ready: boolean, Active: boolean): ()
	Player:SetAttribute(ATTR_AWAKEN_READY, Ready)
	Player:SetAttribute(ATTR_AWAKEN_ACTIVE, Active)
	local Character: Model? = Player.Character
	if Character then
		Character:SetAttribute(ATTR_AWAKEN_READY, Ready)
		Character:SetAttribute(ATTR_AWAKEN_ACTIVE, Active)
	end
end

local function SetSkillLockAttributes(Player: Player, Locked: boolean): ()
	Player:SetAttribute(ATTR_SKILL_LOCKED, Locked)
	local Character: Model? = Player.Character
	if Character then
		Character:SetAttribute(ATTR_SKILL_LOCKED, Locked)
	end
end

local function SyncAwakenToCharacter(Player: Player, Character: Model): ()
	local StateData: PlayerState = EnsurePlayerState(Player)
	Character:SetAttribute(ATTR_AWAKEN_READY, StateData.Awaken.Ready)
	Character:SetAttribute(ATTR_AWAKEN_ACTIVE, StateData.Awaken.Active)
end

local function ResetCutsceneLockState(StateData: PlayerState): ()
	local CutsceneLock: CutsceneLockState = StateData.CutsceneLock
	CutsceneLock.Active = false
	CutsceneLock.Token = ZERO
	CutsceneLock.Character = nil
	CutsceneLock.RootAnchoredBefore = nil
	CutsceneLock.HumanoidAutoRotateBefore = nil
	CutsceneLock.HumanoidWalkSpeedBefore = nil
	CutsceneLock.HumanoidJumpPowerBefore = nil
	CutsceneLock.HumanoidJumpHeightBefore = nil
	CutsceneLock.HumanoidUseJumpPowerBefore = nil
end

local function ApplyCutsceneMovementLock(Character: Model, StateData: PlayerState): ()
	local CutsceneLock: CutsceneLockState = StateData.CutsceneLock
	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		CutsceneLock.RootAnchoredBefore = Root.Anchored
		Root.Anchored = true
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return
	end

	CutsceneLock.HumanoidAutoRotateBefore = HumanoidInstance.AutoRotate
	CutsceneLock.HumanoidWalkSpeedBefore = HumanoidInstance.WalkSpeed
	CutsceneLock.HumanoidJumpPowerBefore = HumanoidInstance.JumpPower
	CutsceneLock.HumanoidJumpHeightBefore = HumanoidInstance.JumpHeight
	CutsceneLock.HumanoidUseJumpPowerBefore = HumanoidInstance.UseJumpPower

	HumanoidInstance.AutoRotate = false
	HumanoidInstance.WalkSpeed = ZERO
	if HumanoidInstance.UseJumpPower then
		HumanoidInstance.JumpPower = ZERO
	else
		HumanoidInstance.JumpHeight = ZERO
	end
	HumanoidInstance.PlatformStand = false
	HumanoidInstance.Sit = false
end

local ForceRestoreCharacterMovement: (Player: Player) -> ()

local function ReleaseAwakenCutsceneLock(Player: Player, Token: number?): ()
	local StateData: PlayerState = EnsurePlayerState(Player)
	local CutsceneLock: CutsceneLockState = StateData.CutsceneLock
	if not CutsceneLock.Active then
		return
	end
	if Token ~= nil and CutsceneLock.Token ~= Token then
		return
	end

	local Character: Model? = Player.Character
	if Character and Character.Parent ~= nil then
		local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Root then
			Root.AssemblyLinearVelocity = Vector3.zero
			Root.AssemblyAngularVelocity = Vector3.zero
			if CutsceneLock.RootAnchoredBefore ~= nil then
				Root.Anchored = CutsceneLock.RootAnchoredBefore
			else
				Root.Anchored = false
			end
		end

		local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
		if HumanoidInstance then
			HumanoidInstance.UseJumpPower = true
			if CutsceneLock.HumanoidWalkSpeedBefore ~= nil and CutsceneLock.HumanoidWalkSpeedBefore > ZERO then
				HumanoidInstance.WalkSpeed =
					FlowBuffs.ResolveRestoredWalkSpeed(Player, CutsceneLock.HumanoidWalkSpeedBefore, DEFAULT_WALKSPEED)
			elseif HumanoidInstance.WalkSpeed <= ZERO then
				FlowBuffs.ApplyHumanoidWalkSpeed(Player, HumanoidInstance, DEFAULT_WALKSPEED)
			end
			if CutsceneLock.HumanoidJumpPowerBefore ~= nil and CutsceneLock.HumanoidJumpPowerBefore > ZERO then
				HumanoidInstance.JumpPower = CutsceneLock.HumanoidJumpPowerBefore
			else
				HumanoidInstance.JumpPower = DEFAULT_JUMPPOWER
			end
			if CutsceneLock.HumanoidJumpHeightBefore ~= nil and CutsceneLock.HumanoidJumpHeightBefore > ZERO then
				HumanoidInstance.JumpHeight = CutsceneLock.HumanoidJumpHeightBefore
			elseif HumanoidInstance.JumpHeight <= ZERO then
				HumanoidInstance.JumpHeight = DEFAULT_JUMPHEIGHT
			end
			HumanoidInstance.AutoRotate = true
			HumanoidInstance.PlatformStand = false
			HumanoidInstance.Sit = false
		end
	end

	ResetCutsceneLockState(StateData)
	SetSkillLockAttributes(Player, false)
end

local function StartAwakenCutsceneLock(Player: Player, Token: number, Duration: number): ()
	local StateData: PlayerState = EnsurePlayerState(Player)
	if StateData.CutsceneLock.Active then
		ReleaseAwakenCutsceneLock(Player, nil)
	end

	ResetCutsceneLockState(StateData)
	StateData.CutsceneLock.Active = true
	StateData.CutsceneLock.Token = Token
	StateData.CutsceneLock.Character = Player.Character

	SetSkillLockAttributes(Player, true)

	local Character: Model? = Player.Character
	if Character then
		ApplyCutsceneMovementLock(Character, StateData)
	end

	local LockDuration: number = math.max(Duration, ZERO)
	if LockDuration <= ZERO then
		ReleaseAwakenCutsceneLock(Player, Token)
		return
	end

	task.delay(LockDuration, function()
		ReleaseAwakenCutsceneLock(Player, Token)
		ForceRestoreCharacterMovement(Player)
	end)
end

local function HandleAwakenCutsceneEnded(Player: Player, FinalCFrame: CFrame?): ()
	local StateData: PlayerState = EnsurePlayerState(Player)
	if not StateData.Awaken.Active then
		return
	end
	if not StateData.CutsceneLock.Active then
		return
	end
	local Character: Model? = Player.Character
	local SanitizedCFrame: CFrame? = SanitizeCutsceneCFrame(FinalCFrame)
	if Character and SanitizedCFrame then
		AlignCharacterToCFrame(Character, SanitizedCFrame)
	end
	ReleaseAwakenCutsceneLock(Player, StateData.Awaken.Token)
	ForceRestoreCharacterMovement(Player)
end

ForceRestoreCharacterMovement = function(Player: Player): ()
	local Character: Model? = Player.Character
	if not Character then
		return
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		Root.Anchored = false
		Root.AssemblyLinearVelocity = Vector3.new(ZERO, ZERO, ZERO)
		Root.AssemblyAngularVelocity = Vector3.new(ZERO, ZERO, ZERO)
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return
	end

	if HumanoidInstance.WalkSpeed <= ZERO then
		FlowBuffs.ApplyHumanoidWalkSpeed(Player, HumanoidInstance, DEFAULT_WALKSPEED)
	end

	if HumanoidInstance.UseJumpPower ~= true then
		HumanoidInstance.UseJumpPower = true
	end
	if HumanoidInstance.UseJumpPower then
		if HumanoidInstance.JumpPower <= ZERO then
			HumanoidInstance.JumpPower = DEFAULT_JUMPPOWER
		end
	elseif HumanoidInstance.JumpHeight <= ZERO then
		HumanoidInstance.JumpHeight = DEFAULT_JUMPHEIGHT
	end

	HumanoidInstance.AutoRotate = true
	HumanoidInstance.PlatformStand = false
	HumanoidInstance.Sit = false
end

local function ResetAwakenState(Player: Player, SuppressStudioReady: boolean?): ()
	local StateData: PlayerState = EnsurePlayerState(Player)
	StateData.Awaken.Ready = false
	StateData.Awaken.Active = false
	StateData.Awaken.EndTime = ZERO
	StateData.Awaken.Token += ONE
	ClearAllSkillHoldStates(StateData)
	SkillCooldownStore.ClearAll(StateData.Cooldowns)
	RequestLock:Release(Player)
	SetAwakenAttributes(Player, false, false)
	ReleaseAwakenCutsceneLock(Player, nil)
	SetSkillLockAttributes(Player, false)
	ForceRestoreCharacterMovement(Player)
	Packets.AwakenStatus:FireClient(Player, AWAKEN_STATUS_END, ZERO)
	if STUDIO_ALWAYS_READY_AWAKEN and SuppressStudioReady ~= true then
		StateData.Awaken.Ready = true
		SetAwakenAttributes(Player, true, false)
		Packets.AwakenStatus:FireClient(Player, AWAKEN_STATUS_READY, ZERO)
	end
end

local function ResetAllAwakenStates(): ()
	for _, PlayerItem in Players:GetPlayers() do
		ResetAwakenState(PlayerItem)
	end
end

local function GetStyleIdForPlayer(Player: Player): string
	local SelectedSlot: number = PlayerDataManager:Get(Player, {"SelectedSlot"}) or DEFAULT_SELECTED_SLOT
	local Slots: {[string]: string} = PlayerDataManager:Get(Player, {"StyleSlots"}) or {}
	return SkillsData.ResolveStyleFromSlots(SelectedSlot, Slots)
end

local function BroadcastAwakenCutscene(SourcePlayer: Player, StyleId: string, CutsceneDuration: number): ()
	if CutsceneDuration <= ZERO then
		return
	end

	local SourceUserId: number = SourcePlayer.UserId
	for _, PlayerItem in Players:GetPlayers() do
		if not FTPlayerService:IsPlayerInMatch(PlayerItem) then
			continue
		end
		if StyleId == HIRUMA_STYLE_ID then
			Packets.PlaySound:FireClient(PlayerItem, HIRUMA_AWAKEN_CUTSCENE_SOUND_ID, false)
		end
		if PlayerItem ~= SourcePlayer then
			Packets.AwakenCutscene:FireClient(PlayerItem, StyleId, SourceUserId, CutsceneDuration)
		end
	end
end

local function ResolveSkillForPlayer(Player: Player, SlotIndex: number, IsAwaken: boolean): SkillDefinition?
	local StyleId: string = GetStyleIdForPlayer(Player)
	local SkillList: {SkillDefinition}? = SkillsData.GetSkillList(StyleId, IsAwaken)
	if not SkillList then
		return nil
	end
	return SkillList[SlotIndex]
end

local GrantAwakenReady: (Player: Player) -> ()

local function IsHoldingBallForSkillBlock(Player: Player, Character: Model?): boolean
	local BallState = FTBallService:GetBallState()
	if BallState and BallState:GetPossession() == Player then
		return true
	end

	local ExternalHolder: Model? = FTBallService:GetExternalHolder()
	return Character ~= nil and ExternalHolder == Character
end

local function ExecuteSkill(Player: Player, SlotIndex: number, AimTarget: Vector3?, HoldState: SkillHoldState?): ()
	local Character: Model? = Player.Character
	if not SkillServerGuard.CanUseSkill(Player, Character, SlotIndex, MIN_SLOT_INDEX, MAX_SLOT_INDEX, IsPlayerInMatch) then
		return
	end
	local StateData: PlayerState = EnsurePlayerState(Player)
	local Skill: SkillDefinition? = ResolveSkillForPlayer(Player, SlotIndex, StateData.Awaken.Active)
	if not Skill then
		return
	end
	local InputBehavior: SkillInputBehavior = GetSkillInputBehavior(Skill)
	if InputBehavior.Mode == HOLD_INPUT_MODE and HoldState == nil then
		return
	end
	if SkillsData.BlocksWhenHoldingBall(Skill) and IsHoldingBallForSkillBlock(Player, Character) then
		return
	end
	if SkillsData.RequiresBall(Skill) then
		local BallState = FTBallService:GetBallState()
		if not BallState or BallState:GetPossession() ~= Player then
			return
		end
	end
	local CooldownKey: string = SkillCooldownStore.BuildKey(Skill.Id, StateData.Awaken.Active)
	local Now: number = os.clock()
	if not SkillCooldownStore.IsReady(StateData.Cooldowns, CooldownKey, Now) then
		return
	end
	local Executor = SkillRegistry:ResolveExecutor(Skill.Module)
	if not Executor then
		return
	end
	if not RequestLock:TryAcquire(Player, SKILL_EXECUTION_LOCK_WINDOW) then
		return
	end
	local ActiveCharacter: Model? = Player.Character
	if not ActiveCharacter or ActiveCharacter ~= Character then
		return
	end
	local AdjustedCooldown: number = FlowBuffs.ApplyCooldownReduction(Player, Skill.Cooldown)
	SkillCooldownStore.Begin(StateData.Cooldowns, CooldownKey, AdjustedCooldown, Now)
	Packets.SkillCooldown:FireClient(Player, SlotIndex, AdjustedCooldown)
	task.spawn(function()
		local Ok: boolean, ErrorMessage: any = pcall(function()
			local SkillContext: {[string]: any}? = nil
			if Skill.Module == HIRUMA_THROW_MODULE_NAME and AimTarget then
				SkillContext = {
					AimTarget = AimTarget,
				}
			end
			if HoldState then
				SkillContext = SkillContext or {}
				SkillContext.HoldState = HoldState
			end
			(Executor :: any)(ActiveCharacter, SkillContext)
		end)
		if HoldState then
			ClearSkillHoldState(Player, SlotIndex, HoldState.Token)
		end
		if not Ok then
			warn(string.format("FTSkillService: failed skill '%s' for %s: %s", Skill.Id, Player.Name, tostring(ErrorMessage)))
		end
	end)
end

local function ActivateAwaken(Player: Player): ()
	local Character: Model? = Player.Character
	if not SkillServerGuard.CanUseAwaken(Player, Character, IsPlayerInMatch) then
		return
	end
	if not Character then
		return
	end
	local StateData: PlayerState = EnsurePlayerState(Player)
	if StateData.Awaken.Active then
		return
	end
	if not STUDIO_ALWAYS_READY_AWAKEN and not StateData.Awaken.Ready then
		return
	end
	local BallState = FTBallService:GetBallState()
	if not BallState or BallState:GetPossession() ~= Player then
		return
	end
	local StyleId: string = GetStyleIdForPlayer(Player)
	local Duration: number = SkillsData.GetAwakenDuration(StyleId)
	if Duration <= ZERO then
		return
	end
	local CutsceneDuration: number = SkillsData.GetAwakenCutsceneDuration(StyleId)
	if not RequestLock:TryAcquire(Player, AWAKEN_EXECUTION_LOCK_WINDOW) then
		return
	end
	local TotalDuration: number = Duration + math.max(CutsceneDuration, ZERO)
	StateData.Awaken.Active = true
	StateData.Awaken.Ready = false
	StateData.Awaken.Token += ONE
	local Token: number = StateData.Awaken.Token
	StateData.Awaken.EndTime = os.clock() + TotalDuration
	SetAwakenAttributes(Player, false, true)
	StartAwakenCutsceneLock(Player, Token, CutsceneDuration)
	BroadcastAwakenCutscene(Player, StyleId, CutsceneDuration)
	Packets.AwakenStatus:FireClient(Player, AWAKEN_STATUS_START, Duration)
	task.delay(TotalDuration, function()
		if StateData.Awaken.Token ~= Token then
			return
		end
		StateData.Awaken.Active = false
		StateData.Awaken.EndTime = ZERO
		SetAwakenAttributes(Player, false, false)
		ReleaseAwakenCutsceneLock(Player, Token)
		SetSkillLockAttributes(Player, false)
		ForceRestoreCharacterMovement(Player)
		Packets.AwakenStatus:FireClient(Player, AWAKEN_STATUS_END, ZERO)
		if STUDIO_ALWAYS_READY_AWAKEN then
			GrantAwakenReady(Player)
		end
	end)
end

GrantAwakenReady = function(Player: Player): ()
	local StateData: PlayerState = EnsurePlayerState(Player)
	if StateData.Awaken.Ready or StateData.Awaken.Active then
		return
	end
	StateData.Awaken.Ready = true
	StateData.Awaken.Active = false
	StateData.Awaken.EndTime = ZERO
	StateData.Awaken.Token += ONE
	SetAwakenAttributes(Player, true, false)
	Packets.AwakenStatus:FireClient(Player, AWAKEN_STATUS_READY, ZERO)
end

local function GetEligiblePlayers(): {Player}
	local Eligible: {Player} = {}
	for _, PlayerItem in Players:GetPlayers() do
		if not IsPlayerInMatch(PlayerItem) then
			continue
		end
		local Character: Model? = PlayerItem.Character
		if SkillServerGuard.IsBlockedByAttributes(PlayerItem, Character) then
			continue
		end
		local StateData: PlayerState = EnsurePlayerState(PlayerItem)
		if not StateData.Awaken.Ready and not StateData.Awaken.Active then
			table.insert(Eligible, PlayerItem)
		end
	end
	return Eligible
end

local function SelectRandomPlayer(List: {Player}): Player?
	local Count: number = #List
	if Count <= ZERO then
		return nil
	end
	local Index: number = math.random(ONE, Count)
	return List[Index]
end

local function StartDropScheduler(): ()
	task.spawn(function()
		while true do
			task.wait(DROP_INTERVAL_SECONDS)
			if not SkillServerGuard.IsSkillWindowOpen() then
				continue
			end
			local Eligible: {Player} = GetEligiblePlayers()
			local Chosen: Player? = SelectRandomPlayer(Eligible)
			if Chosen then
				GrantAwakenReady(Chosen)
			end
		end
	end)
end

local function WarmupSkillModules(): ()
	local ModuleNames: {string} = SkillsData.GetAllSkillModuleNames()
	if #ModuleNames <= ZERO then
		for _, Child in SkillsFolder:GetChildren() do
			if Child:IsA("ModuleScript") then
				table.insert(ModuleNames, Child.Name)
			end
		end
	end
	SkillRegistry:Warmup(ModuleNames)
end

local function BindMatchState(): ()
	task.spawn(function()
		local StateInstance: Instance = ReplicatedStorage:WaitForChild(GAME_STATE_FOLDER)
		local FolderInstance: Folder = StateInstance :: Folder
		local MatchStartedValue: BoolValue? = FolderInstance:FindFirstChild(MATCH_STARTED_NAME) :: BoolValue?
		if not MatchStartedValue then
			return
		end
		LastMatchStarted = MatchStartedValue.Value
		MatchStartedValue.Changed:Connect(function()
			if LastMatchStarted and not MatchStartedValue.Value then
				ResetAllAwakenStates()
			end
			LastMatchStarted = MatchStartedValue.Value
		end)
	end)
end

local function HandlePlayerAdded(Player: Player): ()
	EnsurePlayerState(Player)
	if STUDIO_ALWAYS_READY_AWAKEN then
		pcall(function()
			local SelectedSlot: any = PlayerDataManager:Get(Player, {"SelectedSlot"})
			if typeof(SelectedSlot) ~= "number" or SelectedSlot < 1 or SelectedSlot > 4 then
				PlayerDataManager:Set(Player, {"SelectedSlot"}, DEFAULT_SELECTED_SLOT)
			end
		end)
		pcall(function()
			local StudioDefaultStyle: any = PlayerDataManager:Get(Player, {"StyleSlots", STUDIO_DEFAULT_STYLE_SLOT_KEY})
			if typeof(StudioDefaultStyle) ~= "string" or StudioDefaultStyle == "" then
				PlayerDataManager:Set(Player, {"StyleSlots", STUDIO_DEFAULT_STYLE_SLOT_KEY}, STUDIO_DEFAULT_STYLE_ID)
			end
		end)
	end
	if STUDIO_ALWAYS_READY_AWAKEN then
		SetAwakenAttributes(Player, true, false)
	else
		SetAwakenAttributes(Player, false, false)
	end
	SetSkillLockAttributes(Player, false)
	Player.CharacterAdded:Connect(function(Character: Model)
		local StateData: PlayerState = EnsurePlayerState(Player)
		SyncAwakenToCharacter(Player, Character)
		Character:SetAttribute(ATTR_SKILL_LOCKED, StateData.CutsceneLock.Active)
		if StateData.CutsceneLock.Active then
			StateData.CutsceneLock.Character = Character
			ApplyCutsceneMovementLock(Character, StateData)
		end
	end)
	if Player.Character then
		local StateData: PlayerState = EnsurePlayerState(Player)
		SyncAwakenToCharacter(Player, Player.Character)
		Player.Character:SetAttribute(ATTR_SKILL_LOCKED, StateData.CutsceneLock.Active)
		if StateData.CutsceneLock.Active then
			StateData.CutsceneLock.Character = Player.Character
			ApplyCutsceneMovementLock(Player.Character, StateData)
		end
	end
	if STUDIO_ALWAYS_READY_AWAKEN then
		GrantAwakenReady(Player)
	end
end

local function HandlePlayerRemoving(Player: Player): ()
	RequestLock:Release(Player)
	local StateData: PlayerState? = PlayerStates[Player]
	if StateData then
		ClearAllSkillHoldStates(StateData)
	end
	PlayerStates[Player] = nil
end

function FTSkillService.Init(_self: typeof(FTSkillService)): ()
	Packets.SkillRequest.OnServerEvent:Connect(function(Player: Player, SlotIndex: number, AimTarget: Vector3)
		if typeof(SlotIndex) ~= "number" then
			return
		end
		local ParsedSlot: number = math.floor(SlotIndex)
		if ParsedSlot ~= SlotIndex then
			return
		end
		ExecuteSkill(Player, ParsedSlot, SanitizeAimTarget(AimTarget), nil)
	end)
	Packets.SkillHoldRequest.OnServerEvent:Connect(function(
		Player: Player,
		SlotIndex: number,
		ActionId: number,
		HoldDuration: number,
		AimTarget: Vector3
	)
		if typeof(SlotIndex) ~= "number" or typeof(ActionId) ~= "number" then
			return
		end
		local ParsedSlot: number = math.floor(SlotIndex)
		local ParsedAction: number = math.floor(ActionId)
		if ParsedSlot ~= SlotIndex or ParsedAction ~= ActionId then
			return
		end

		local SanitizedHoldDuration: number =
			if type(HoldDuration) == "number" and IsFiniteNumber(HoldDuration) then math.max(HoldDuration, ZERO) else ZERO

		if ParsedAction == SKILL_HOLD_ACTION_RELEASE then
			MarkSkillHoldReleased(Player, ParsedSlot, SanitizedHoldDuration)
			return
		end
		if ParsedAction ~= SKILL_HOLD_ACTION_BEGIN then
			return
		end

		local StateData: PlayerState = EnsurePlayerState(Player)
		local Skill: SkillDefinition? = ResolveSkillForPlayer(Player, ParsedSlot, StateData.Awaken.Active)
		if not Skill then
			return
		end

		local InputBehavior: SkillInputBehavior = GetSkillInputBehavior(Skill)
		if InputBehavior.Mode ~= HOLD_INPUT_MODE then
			return
		end

		local HoldState: SkillHoldState? = CreateSkillHoldState(Player, ParsedSlot)
		if not HoldState then
			return
		end

		ExecuteSkill(Player, ParsedSlot, SanitizeAimTarget(AimTarget), HoldState)
	end)
	Packets.AwakenRequest.OnServerEvent:Connect(function(Player: Player)
		ActivateAwaken(Player)
	end)
	Packets.AwakenCutsceneEnded.OnServerEvent:Connect(function(Player: Player, FinalCFrame: CFrame)
		HandleAwakenCutsceneEnded(Player, FinalCFrame)
	end)
	Players.PlayerAdded:Connect(HandlePlayerAdded)
	Players.PlayerRemoving:Connect(HandlePlayerRemoving)
	for _, PlayerItem in Players:GetPlayers() do
		HandlePlayerAdded(PlayerItem)
	end
	BindMatchState()
end

function FTSkillService.Start(_self: typeof(FTSkillService)): ()
	WarmupSkillModules()
	StartDropScheduler()
end

function FTSkillService.ResetPlayer(_self: typeof(FTSkillService), Player: Player): ()
	ResetAwakenState(Player, true)
end

return FTSkillService
