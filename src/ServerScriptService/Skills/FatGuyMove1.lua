--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local FTBallService: any = require(ServerScriptService.Services.BallService)
local FatGuySkillUtils = require(script.Parent.Utils.FatGuySkillUtils)

local MOVE1_SKILL_ALIASES: {string} = {
	"Move1",
	"Move 1",
}

local CHARGE_ANIMATION_ID: string = "rbxassetid://95262290724141"
local JUMP_ANIMATION_ID: string = "rbxassetid://80290482361953"
local CHARGE_LOOP_SOUND_ID: number = 138534073059943
local BLOCK_SOUND_ID: number = 134808598079734
local MOVE1_VFX_OFFSET: Vector3 = Vector3.new(0.305, 1.271, 0.023)
local BLOCK_EFFECT_OFFSET: Vector3 = Vector3.new(0, 2.2, 0)

local REPLICATOR_TYPE: string = "FatGuyMove1"
local ATTR_AWAKEN_ACTIVE: string = "AwakenActive"
local TIMELINE_FPS: number = 60
local JUMP_FREEZE_TIME: number = 0.53
local TOTAL_TIMELINE_FRAMES: number = 300
local NORMAL_BALL_SEARCH_RADIUS: number = 64
local AWAKEN_BALL_SEARCH_RADIUS: number = 112
local NORMAL_CHARGE_ANIMATION_SPEED: number = 1
local AWAKEN_CHARGE_ANIMATION_SPEED: number = 1.5
local CHARGE_TO_JUMP_BLEND_TIME: number = 0.04
local JUMP_FREEZE_SPEED: number = 0.01
local TRACK_TIME_EPSILON: number = 1 / TIMELINE_FPS
local VFX_DESTROY_DELAY: number = 3
local JUMP_PRIORITY_BUFFER: number = 0.35
local ASCENT_BASE_DURATION: number = 0.66
local ASCENT_PER_LEVEL: number = 0.16
local MAX_ASCENT_DURATION: number = 1
local APEX_HOLD_BASE_DURATION: number = 1.25
local APEX_HOLD_PER_LEVEL: number = 0.16
local MAX_APEX_HOLD_DURATION: number = 1.75
local ANIMATION_STOP_FADE_TIME: number = 0.14
local MIN_DESCENT_DURATION: number = 0.55
local MIN_POST_SLOW_RESUME_DURATION: number = 0.55
local MIN_RESUME_ANIMATION_SPEED: number = 0.12
local APEX_BLOCK_TRIGGER_DISTANCE: number = 0.35
local ASCENT_EASING_STYLE: Enum.EasingStyle = Enum.EasingStyle.Quint
local ASCENT_EASING_DIRECTION: Enum.EasingDirection = Enum.EasingDirection.Out
local DESCENT_EASING_STYLE: Enum.EasingStyle = Enum.EasingStyle.Quint
local DESCENT_EASING_DIRECTION: Enum.EasingDirection = Enum.EasingDirection.In
local MAX_CHARGE_LEVEL: number = 2
local NORMAL_HEIGHT_PER_LEVEL: number = 16
local AWAKEN_HEIGHT_PER_LEVEL: number = 20

local ZERO: number = 0
local ONE: number = 1
local MOVE1_SOUND_VOLUME: number = 0.5
local CHARGE_LOOP_SOUND_NAME: string = "FatGuyMove1ChargeLoop"

type SkillSession = any

type SkillContext = {[string]: any}

local ActiveTokens: {[Player]: number} = {}
local StopConflictingAnimations: (Character: Model, PreserveTrack: AnimationTrack?) -> ()
local CHARGED_EFFECT_NAMES: {string} = { "Charge", "Change", "Changed", "Charged" }
local LEAP_EFFECT_NAMES: {string} = { "Leap" }
local BLOCK_EFFECT_NAMES: {string} = { "Block" }

local function NextToken(Current: number?): number
	return (Current or ZERO) + ONE
end

local function FireReplicator(Player: Player, Token: number, Action: string, ExtraData: {[string]: any}?): ()
	local Payload: {[string]: any} = {
		Type = REPLICATOR_TYPE,
		Action = Action,
		Token = Token,
	}

	if ExtraData then
		for Key, Value in ExtraData do
			Payload[Key] = Value
		end
	end

	local Success: boolean, ErrorMessage: any = pcall(function()
		Packets.Replicator:FireClient(Player, Payload)
	end)

	if not Success then
		warn(string.format("FatGuyMove1 replicator failed for %s: %s", Player.Name, tostring(ErrorMessage)))
	end
end

local function WaitDuration(IsActive: () -> boolean, Duration: number): boolean
	return FatGuySkillUtils.RunHeartbeatLoop(Duration, IsActive, function()
		return true
	end)
end

local function ProtectAnimationTrack(
	IsActive: () -> boolean,
	Character: Model,
	Track: AnimationTrack?,
	ExpectedVisualDuration: number
): ()
	if not Track then
		return
	end

	FatGuySkillUtils.RunHeartbeatLoop(ExpectedVisualDuration, IsActive, function()
		StopConflictingAnimations(Character, Track)

		return true
	end)
end

local function GetFreezeTimePosition(Track: AnimationTrack?): number
	local DesiredTime: number = JUMP_FREEZE_TIME
	if not Track or Track.Length <= ZERO then
		return DesiredTime
	end

	return math.max(ZERO, math.min(DesiredTime, Track.Length - TRACK_TIME_EPSILON))
end

local function ResolveResumeAnimationSpeed(TrackResumeDuration: number, ResumeMoveDuration: number): number
	if TrackResumeDuration <= ZERO or ResumeMoveDuration <= ZERO then
		return ONE
	end

	return math.clamp(TrackResumeDuration / ResumeMoveDuration, MIN_RESUME_ANIMATION_SPEED, ONE)
end

local function IsAwakenActive(Player: Player, Character: Model): boolean
	return Player:GetAttribute(ATTR_AWAKEN_ACTIVE) == true or Character:GetAttribute(ATTR_AWAKEN_ACTIVE) == true
end

local function TryCatchNearbyBall(Session: SkillSession, SearchRadius: number): boolean
	return FTBallService:TryCatchByPlayer(Session.Player, SearchRadius, true)
end

local function ResolveAscentDuration(ChargeLevel: number, HeightBonus: number): number
	if HeightBonus <= ZERO then
		return ZERO
	end

	local EffectiveLevel: number = math.clamp(ChargeLevel, ZERO, MAX_CHARGE_LEVEL)
	return math.min(ASCENT_BASE_DURATION + (EffectiveLevel * ASCENT_PER_LEVEL), MAX_ASCENT_DURATION)
end

local function ResolveApexHoldDuration(ChargeLevel: number, HeightBonus: number): number
	local EffectiveLevel: number
	if HeightBonus <= ZERO then
		EffectiveLevel = ZERO
	else
		EffectiveLevel = math.clamp(ChargeLevel, ONE, MAX_CHARGE_LEVEL)
	end

	return math.min(APEX_HOLD_BASE_DURATION + (EffectiveLevel * APEX_HOLD_PER_LEVEL), MAX_APEX_HOLD_DURATION)
end

local function ResolveBallSearchRadius(AwakenActive: boolean): number
	return if AwakenActive then AWAKEN_BALL_SEARCH_RADIUS else NORMAL_BALL_SEARCH_RADIUS
end

local function ResolveJumpStartAndLandingPositions(Session: SkillSession): (Vector3, Vector3)
	Session.RootGroundOffset = FatGuySkillUtils.ResolveRootGroundOffset(Session.Root, Session.Humanoid)

	local CurrentPosition: Vector3 = Session.Root.Position
	local LandingPosition: Vector3 =
		FatGuySkillUtils.AlignRootToGround(CurrentPosition, Session.RootGroundOffset)
	local StartPosition: Vector3 = Vector3.new(
		CurrentPosition.X,
		math.max(CurrentPosition.Y, LandingPosition.Y),
		CurrentPosition.Z
	)

	return StartPosition, LandingPosition
end

local function ResolveHorizontalDistance(FromPosition: Vector3, ToPosition: Vector3): number
	local Delta: Vector3 = ToPosition - FromPosition
	return Vector3.new(Delta.X, ZERO, Delta.Z).Magnitude
end

local function ResolveAutomaticChargeLevel(AwakenActive: boolean, HeightBonus: number): number
	if HeightBonus <= ZERO then
		return ZERO
	end

	local HeightPerLevel: number = if AwakenActive then AWAKEN_HEIGHT_PER_LEVEL else NORMAL_HEIGHT_PER_LEVEL
	if HeightPerLevel <= ZERO then
		return ZERO
	end

	return math.clamp(math.ceil(HeightBonus / HeightPerLevel), ZERO, MAX_CHARGE_LEVEL)
end

local function ResolveAutomaticJumpHeight(
	Session: SkillSession,
	StartPosition: Vector3,
	SearchRadius: number
): number
	local BallState = FTBallService:GetBallState()
	local BallPart: BasePart? = FTBallService:GetBallInstance()
	if not BallState or not BallPart then
		return ZERO
	end
	if BallState:GetPossession() ~= nil or FTBallService:GetExternalHolder() ~= nil then
		return ZERO
	end
	if not BallState:IsInAir() then
		return ZERO
	end
	if ResolveHorizontalDistance(Session.Root.Position, BallPart.Position) > SearchRadius then
		return ZERO
	end

	return math.max(BallPart.Position.Y - StartPosition.Y, ZERO)
end

StopConflictingAnimations = function(Character: Model, PreserveTrack: AnimationTrack?): ()
	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return
	end

	for _, Track in HumanoidInstance:GetPlayingAnimationTracks() do
		if Track ~= PreserveTrack and Track.IsPlaying then
			pcall(function()
				Track:Stop(CHARGE_TO_JUMP_BLEND_TIME)
			end)
		end
	end
end

return function(Character: Model, _Context: SkillContext?): ()
	local Session: SkillSession = FatGuySkillUtils.BeginSkill(Character, {
		AnchorRoot = true,
		CaptureNetworkOwner = false,
		ForcePhysicsState = false,
		StartInvulnerable = false,
	})
	if not Session then
		return
	end

	local Player: Player = Session.Player
	local AwakenActive: boolean = IsAwakenActive(Player, Session.Character)
	local ChargeAnimationSpeed: number =
		if AwakenActive then AWAKEN_CHARGE_ANIMATION_SPEED else NORMAL_CHARGE_ANIMATION_SPEED
	local Token: number = NextToken(ActiveTokens[Player])
	ActiveTokens[Player] = Token

	local function IsCurrent(): boolean
		return ActiveTokens[Player] == Token and FatGuySkillUtils.IsSessionActive(Session)
	end

	local ChargeTrack: AnimationTrack? = nil
	local JumpTrack: AnimationTrack? = nil
	local SkillVfx: Instance? = nil
	local ReplicatorStarted: boolean = false
	local ChargeLevel: number = ZERO
	local SkillVfxReleased: boolean = false

	local function ReleaseLeapEffectsOnJumpTransition(): ()
		FatGuySkillUtils.ReleaseNamedEffects(SkillVfx, LEAP_EFFECT_NAMES, {
			EnableEffects = false,
		})
	end

	local function ReleaseSkillVfx(): ()
		if SkillVfxReleased or not SkillVfx then
			return
		end

		SkillVfxReleased = true
		FatGuySkillUtils.ReleaseAttachedVfx(SkillVfx)
	end

	FatGuySkillUtils.RegisterCleanup(Session, function()
		FatGuySkillUtils.StopCharacterSound(Session.Character, CHARGE_LOOP_SOUND_NAME)
		if ChargeTrack then
			ChargeTrack:Stop(0)
			ChargeTrack:Destroy()
			ChargeTrack = nil
		end
		if JumpTrack then
			JumpTrack:Stop(0)
			JumpTrack:Destroy()
			JumpTrack = nil
		end
		if SkillVfx then
			ReleaseSkillVfx()
			FatGuySkillUtils.CleanupVfxInstance(SkillVfx, VFX_DESTROY_DELAY)
			SkillVfx = nil
		end
		if Session.Root.Parent ~= nil then
			local RestoredPosition: Vector3 =
				FatGuySkillUtils.AlignRootToGround(Session.Root.Position, Session.RootGroundOffset)
			FatGuySkillUtils.SetCharacterTransform(Session, RestoredPosition, Session.Root.CFrame.LookVector)
		end
		FTBallService:ClearCatchPriority(Player)
		if ReplicatorStarted then
			FireReplicator(Player, Token, "End", nil)
			ReplicatorStarted = false
		end
		if ActiveTokens[Player] == Token then
			ActiveTokens[Player] = nil
		end
	end)

	local Success: boolean, ErrorMessage: any = xpcall(function()
		FatGuySkillUtils.WarmAnimations(Session.Character, {
			CHARGE_ANIMATION_ID,
			JUMP_ANIMATION_ID,
		})

		SkillVfx = FatGuySkillUtils.SpawnAttachedVfx(Session, MOVE1_SKILL_ALIASES, MOVE1_VFX_OFFSET, {
			AttachToRoot = true,
			PreserveRotation = true,
			UseCharacterPivot = true,
			UseWorldSpaceOffset = true,
			UseWeldAttachment = true,
		})
		FatGuySkillUtils.TriggerNamedEffects(SkillVfx, CHARGED_EFFECT_NAMES)

		ChargeTrack = FatGuySkillUtils.LoadAnimationTrack(Session.Character, CHARGE_ANIMATION_ID)
		JumpTrack = FatGuySkillUtils.LoadAnimationTrack(Session.Character, JUMP_ANIMATION_ID)

		if ChargeTrack then
			ChargeTrack.Priority = Enum.AnimationPriority.Action3
			ChargeTrack.Looped = true
			ChargeTrack:Play(0.05, ONE, ChargeAnimationSpeed)
			FatGuySkillUtils.PlayLoopingCharacterSound(
				Session.Character,
				CHARGE_LOOP_SOUND_NAME,
				CHARGE_LOOP_SOUND_ID,
				MOVE1_SOUND_VOLUME
			)
		end
		if JumpTrack then
			JumpTrack.Priority = Enum.AnimationPriority.Action4
		end

		local JumpTrackStopped: boolean = JumpTrack == nil
		local JumpTrackStoppedConnection: RBXScriptConnection? = nil
		if JumpTrack then
			JumpTrackStoppedConnection = JumpTrack.Stopped:Connect(function()
				JumpTrackStopped = true
			end)
		end
		FatGuySkillUtils.RegisterCleanup(Session, function()
			if JumpTrackStoppedConnection and JumpTrackStoppedConnection.Connected then
				JumpTrackStoppedConnection:Disconnect()
			end
		end)

		FireReplicator(Player, Token, "Start", {
			Level = ChargeLevel,
		})
		ReplicatorStarted = true

		if not WaitDuration(IsCurrent, CHARGE_TO_JUMP_BLEND_TIME) then
			return
		end
		if not IsCurrent() then
			return
		end

		local BlockEmitted: boolean = false
		local function EmitBlockAtApex(): ()
			if BlockEmitted or not IsCurrent() then
				return
			end
			BlockEmitted = true
			local Head: BasePart? = Session.Character:FindFirstChild("Head") :: BasePart?
			FireReplicator(Player, Token, "Block", {
				Level = ChargeLevel,
			})
			FatGuySkillUtils.PlayCharacterSound(Session.Character, BLOCK_SOUND_ID, MOVE1_SOUND_VOLUME)
			FatGuySkillUtils.TriggerNamedEffects(
				SkillVfx,
				BLOCK_EFFECT_NAMES,
				if Head
					then {
						AnchorPart = Head,
						Offset = BLOCK_EFFECT_OFFSET,
						AttachToAnchor = true,
					}
					else nil
			)
			FatGuySkillUtils.DetachNamedEffects(SkillVfx, BLOCK_EFFECT_NAMES)
		end

		if ChargeTrack then
			ChargeTrack:Stop(CHARGE_TO_JUMP_BLEND_TIME)
		end
		FatGuySkillUtils.StopCharacterSound(Session.Character, CHARGE_LOOP_SOUND_NAME)
		FatGuySkillUtils.DisableNamedEffects(SkillVfx, CHARGED_EFFECT_NAMES)
		FatGuySkillUtils.DetachNamedEffects(SkillVfx, CHARGED_EFFECT_NAMES)

		FatGuySkillUtils.SetSessionInvulnerable(Session, true)
		StopConflictingAnimations(Session.Character, JumpTrack)

		if JumpTrack then
			JumpTrack:Play(CHARGE_TO_JUMP_BLEND_TIME, ONE, ONE)
		end

		ReleaseLeapEffectsOnJumpTransition()
		local StartPosition: Vector3
		local LandingPosition: Vector3
		StartPosition, LandingPosition = ResolveJumpStartAndLandingPositions(Session)
		local BallSearchRadius: number = ResolveBallSearchRadius(AwakenActive)
		local HeightBonus: number = ResolveAutomaticJumpHeight(Session, StartPosition, BallSearchRadius)
		ChargeLevel = ResolveAutomaticChargeLevel(AwakenActive, HeightBonus)
		if ChargeLevel > ZERO then
			FireReplicator(Player, Token, "ChargeLevel", {
				Level = ChargeLevel,
			})
		end

		FireReplicator(Player, Token, "Jump", {
			Level = ChargeLevel,
		})

		local HasJumpBoost: boolean = HeightBonus > ZERO
		local JumpTrackDuration: number = FatGuySkillUtils.GetTrackDuration(JumpTrack, TOTAL_TIMELINE_FRAMES, TIMELINE_FPS)
		local JumpPlaybackSpeed: number = ONE
		local JumpFreezeActive: boolean = false

		local FreezeTimePosition: number = GetFreezeTimePosition(JumpTrack)
		local JumpLookVector: Vector3 = Session.Root.CFrame.LookVector
		local AscentDuration: number = ResolveAscentDuration(ChargeLevel, HeightBonus)
		local ApexHoldDuration: number = ResolveApexHoldDuration(ChargeLevel, HeightBonus)
		local FreezeHoldDuration: number = ApexHoldDuration
		local TrackResumeDuration: number = math.max(JumpTrackDuration - FreezeTimePosition, ZERO)
		local ResumeMoveDuration: number = if HeightBonus > ZERO
			then math.max(TrackResumeDuration, MIN_DESCENT_DURATION)
			else math.max(TrackResumeDuration, MIN_POST_SLOW_RESUME_DURATION)
		local ResumeAnimationSpeed: number = ResolveResumeAnimationSpeed(TrackResumeDuration, ResumeMoveDuration)
		local JumpAnimationProtectionEnabled: boolean = true
		local JumpAnimationProtectionDuration: number =
			math.max(AscentDuration + ApexHoldDuration + ResumeMoveDuration, CHARGE_TO_JUMP_BLEND_TIME)
		local JumpPriorityDuration: number = JumpAnimationProtectionDuration + JUMP_PRIORITY_BUFFER
		local PeakPosition: Vector3 = StartPosition + Vector3.new(0, HeightBonus, 0)
		FatGuySkillUtils.SetCharacterTransform(Session, StartPosition, JumpLookVector)

		FTBallService:SetCatchPriority(Player, BallSearchRadius, JumpPriorityDuration)
		task.spawn(function()
			FatGuySkillUtils.RunHeartbeatLoop(JumpPriorityDuration, IsCurrent, function()
				TryCatchNearbyBall(Session, BallSearchRadius)
				return true
			end)
		end)
		task.spawn(function()
			ProtectAnimationTrack(
				function(): boolean
					return IsCurrent() and JumpAnimationProtectionEnabled and not JumpTrackStopped
				end,
				Session.Character,
				JumpTrack,
				JumpAnimationProtectionDuration
			)
		end)

		local function ApplyJumpFreezePlayback(): ()
			JumpPlaybackSpeed = JUMP_FREEZE_SPEED
			JumpFreezeActive = true
			if not JumpTrack then
				return
			end

			pcall(function()
				if JumpTrack.IsPlaying then
					JumpTrack.TimePosition = FreezeTimePosition
					JumpTrack:AdjustSpeed(JumpPlaybackSpeed)
				end
			end)
		end

		task.spawn(function()
			FatGuySkillUtils.RunHeartbeatLoop(
				math.max(math.min(FreezeTimePosition, JumpTrackDuration), ZERO) + TRACK_TIME_EPSILON,
				function(): boolean
					return IsCurrent() and JumpAnimationProtectionEnabled and not JumpFreezeActive
				end,
				function(Elapsed: number): boolean
					local ShouldFreeze: boolean = Elapsed + TRACK_TIME_EPSILON >= FreezeTimePosition
					if JumpTrack then
						local CurrentTimePosition: number = ZERO
						local ReadSucceeded: boolean = pcall(function()
							CurrentTimePosition = JumpTrack.TimePosition
						end)
						if ReadSucceeded and CurrentTimePosition + TRACK_TIME_EPSILON >= FreezeTimePosition then
							ShouldFreeze = true
						end
					end
					if not ShouldFreeze then
						return true
					end

					ApplyJumpFreezePlayback()
					return false
				end
			)
		end)

		if HasJumpBoost and HeightBonus > ZERO and AscentDuration > ZERO then
			task.spawn(function()
				FatGuySkillUtils.RunHeartbeatLoop(AscentDuration + TRACK_TIME_EPSILON, function(): boolean
					return IsCurrent() and not BlockEmitted
				end, function(): boolean
					if (Session.Root.Position - PeakPosition).Magnitude <= APEX_BLOCK_TRIGGER_DISTANCE then
						EmitBlockAtApex()
						return false
					end
					return true
				end)
			end)
			FatGuySkillUtils.TweenCharacterPosition(
				Session,
				StartPosition,
				PeakPosition,
				AscentDuration,
				IsCurrent,
				{
					EasingStyle = ASCENT_EASING_STYLE,
					EasingDirection = ASCENT_EASING_DIRECTION,
					Forward = JumpLookVector,
				}
			)
		else
			WaitDuration(IsCurrent, FreezeTimePosition)
		end
		if not IsCurrent() then
			return
		end

		EmitBlockAtApex()
		local FreezePosePosition: Vector3 = if HeightBonus > ZERO then PeakPosition else LandingPosition
		FatGuySkillUtils.SetCharacterTransform(Session, FreezePosePosition, JumpLookVector)
		ApplyJumpFreezePlayback()

		local function MaintainJumpPose(): boolean
			if HeightBonus > ZERO then
				FatGuySkillUtils.SetCharacterTransform(Session, PeakPosition, JumpLookVector)
			else
				FatGuySkillUtils.SetCharacterTransform(Session, LandingPosition, JumpLookVector)
			end
			return true
		end

		FatGuySkillUtils.RunHeartbeatLoop(FreezeHoldDuration, IsCurrent, function()
			if JumpTrack then
				pcall(function()
					if JumpTrack.IsPlaying then
						JumpTrack.TimePosition = FreezeTimePosition
						JumpTrack:AdjustSpeed(JumpPlaybackSpeed)
					end
				end)
			end
			return MaintainJumpPose()
		end)
		if not IsCurrent() then
			return
		end

		if JumpTrack then
			JumpPlaybackSpeed = ResumeAnimationSpeed
			pcall(function()
				if JumpTrack.IsPlaying then
					JumpTrack.TimePosition = FreezeTimePosition
					JumpTrack:AdjustSpeed(JumpPlaybackSpeed)
				end
			end)
		end

		if HeightBonus > ZERO then
			FatGuySkillUtils.TweenCharacterPosition(
				Session,
				PeakPosition,
				LandingPosition,
				ResumeMoveDuration,
				IsCurrent,
				{
					EasingStyle = DESCENT_EASING_STYLE,
					EasingDirection = DESCENT_EASING_DIRECTION,
					Forward = JumpLookVector,
				}
			)
		else
			FatGuySkillUtils.RunHeartbeatLoop(ResumeMoveDuration, IsCurrent, function()
				FatGuySkillUtils.SetCharacterTransform(Session, LandingPosition, JumpLookVector)
				return true
			end)
		end

		JumpAnimationProtectionEnabled = false
		if JumpTrack and not JumpTrackStopped then
			pcall(function()
				JumpTrack:Stop(ANIMATION_STOP_FADE_TIME)
			end)
		end
		ReleaseSkillVfx()
	end, debug.traceback)

	FatGuySkillUtils.EndSkill(Session)

	if not Success then
		warn(string.format("FatGuyMove1 failed for %s: %s", Player.Name, tostring(ErrorMessage)))
	end
end
