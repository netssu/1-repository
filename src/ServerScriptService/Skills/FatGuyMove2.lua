--!strict

local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local FatGuySkillUtils = require(script.Parent.Utils.FatGuySkillUtils)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)

local MOVE2_SKILL_ALIASES: {string} = {
	"Move2",
	"Move 2",
}

local MOVE2_ANIMATION_ID: string = "rbxassetid://112856364360709"
local MOVE2_ARMOR_SOUND_ID: number = 135519466185722
local MOVE2_VFX_OFFSET: Vector3 = Vector3.new(-0.046, -1.047, 0)

local REPLICATOR_TYPE: string = "FatGuyMove2"
local ATTR_AWAKEN_ACTIVE: string = "AwakenActive"
local TIMELINE_FPS: number = 60
local TOTAL_TIMELINE_FRAMES: number = 300
local PRE_END_SLOWDOWN_LEAD_TIME: number = 0.28
local NORMAL_DASH_DISTANCE: number = 150
local AWAKEN_DASH_DISTANCE: number = 180
local MOVE2_PLAYBACK_SPEED: number = 1.5
local MOVE2_SPEED_MULTIPLIER: number = 0.5
local DASH_HEADSTART_BLEND: number = 0.28
local MOVE2_DURATION: number = TOTAL_TIMELINE_FRAMES / TIMELINE_FPS
local PLAYBACK_TIMELINE_FPS: number = TIMELINE_FPS * MOVE2_PLAYBACK_SPEED
local PLAYBACK_MOVE2_DURATION: number = MOVE2_DURATION / MOVE2_PLAYBACK_SPEED
local VFX_DESTROY_DELAY: number = 0.15
local TRACK_END_GRACE: number = 0.45

local ATTACHMENT_NAME: string = "FatGuyMove2Attachment"
local ALIGN_ORIENTATION_NAME: string = "FatGuyMove2AlignOrientation"
local BODY_VELOCITY_NAME: string = "FatGuyMove2BodyVelocity"

local ORIENTATION_MAX_TORQUE: number = 1200000
local ORIENTATION_RESPONSIVENESS: number = 110
local ORIENTATION_RIGIDITY_ENABLED: boolean = false
local NORMAL_BODY_VELOCITY_FORCE: number = 250000
local AWAKEN_BODY_VELOCITY_FORCE: number = 360000

local ZERO: number = 0
local ONE: number = 1
local MOVE2_SOUND_VOLUME: number = 0.5
local ORIENTATION_BASE_CFRAME: CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1), Vector3.yAxis)
local MOVE2_SOUND_NAME: string = "FatGuyMove2ArmorActivate"
local SPEED_LINES_FRAME: number = 26
local STEP1_MARKER_NAME: string = "step1"
local STEP2_MARKER_NAME: string = "step2"
local ARMOR_MARKER_NAME: string = "armor"

local ActiveTokens: {[Player]: number} = {}

local function NextToken(Current: number?): number
	return (Current or ZERO) + ONE
end

local function FireReplicator(Player: Player, Token: number, Action: string, Duration: number?): ()
	local Success: boolean, ErrorMessage: any = pcall(function()
		Packets.Replicator:FireClient(Player, {
			Type = REPLICATOR_TYPE,
			Action = Action,
			Token = Token,
			Duration = Duration,
		})
	end)
	if not Success then
		warn(string.format("FatGuyMove2 replicator failed for %s: %s", Player.Name, tostring(ErrorMessage)))
	end
end

local function WaitUntilTrackStops(
	IsActive: () -> boolean,
	Track: AnimationTrack?,
	MaxDuration: number
): ()
	local TrackStopped: boolean = Track == nil
	local Connection: RBXScriptConnection? = nil

	if Track then
		Connection = Track.Stopped:Connect(function()
			TrackStopped = true
		end)
	end

	FatGuySkillUtils.RunHeartbeatLoop(MaxDuration, IsActive, function()
		return not TrackStopped
	end)

	if Connection and Connection.Connected then
		Connection:Disconnect()
	end
end

local function IsAwakenActive(Player: Player, Character: Model): boolean
	return Player:GetAttribute(ATTR_AWAKEN_ACTIVE) == true or Character:GetAttribute(ATTR_AWAKEN_ACTIVE) == true
end

local function CreateDashControllers(
	Root: BasePart,
	Forward: Vector3,
	BodyVelocityForce: number
): (Attachment, BodyVelocity, AlignOrientation)
	local AttachmentInstance: Attachment = Instance.new("Attachment")
	AttachmentInstance.Name = ATTACHMENT_NAME
	AttachmentInstance.Parent = Root

	local BodyVelocityInstance: BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocityInstance.Name = BODY_VELOCITY_NAME
	BodyVelocityInstance.MaxForce = Vector3.new(BodyVelocityForce, ZERO, BodyVelocityForce)
	BodyVelocityInstance.P = 25000
	BodyVelocityInstance.Velocity = Vector3.zero
	BodyVelocityInstance.Parent = Root

	local AlignOrientationInstance: AlignOrientation = Instance.new("AlignOrientation")
	AlignOrientationInstance.Name = ALIGN_ORIENTATION_NAME
	AlignOrientationInstance.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrientationInstance.Attachment0 = AttachmentInstance
	AlignOrientationInstance.ReactionTorqueEnabled = false
	AlignOrientationInstance.MaxTorque = ORIENTATION_MAX_TORQUE
	AlignOrientationInstance.Responsiveness = ORIENTATION_RESPONSIVENESS
	AlignOrientationInstance.RigidityEnabled = ORIENTATION_RIGIDITY_ENABLED
	AlignOrientationInstance.CFrame = ORIENTATION_BASE_CFRAME
	AlignOrientationInstance.Parent = Root

	local FlattenedForward: Vector3 = Vector3.new(Forward.X, ZERO, Forward.Z)
	if FlattenedForward.Magnitude > 0.001 then
		AlignOrientationInstance.CFrame = CFrame.lookAt(Vector3.zero, FlattenedForward.Unit, Vector3.yAxis)
	end

	return AttachmentInstance, BodyVelocityInstance, AlignOrientationInstance
end

return function(Character: Model): ()
	local Session = FatGuySkillUtils.BeginSkill(Character, {
		AnchorRoot = false,
		CaptureNetworkOwner = true,
		ForcePhysicsState = true,
	})
	if not Session then
		return
	end

	local Player: Player = Session.Player
	local AwakenActive: boolean = IsAwakenActive(Player, Session.Character)
	local DashDistance: number = if AwakenActive then AWAKEN_DASH_DISTANCE else NORMAL_DASH_DISTANCE
	local BodyVelocityForce: number = if AwakenActive then AWAKEN_BODY_VELOCITY_FORCE else NORMAL_BODY_VELOCITY_FORCE
	local Token: number = NextToken(ActiveTokens[Player])
	ActiveTokens[Player] = Token

	local function IsCurrent(): boolean
		return ActiveTokens[Player] == Token and FatGuySkillUtils.IsSessionActive(Session)
	end

	local DashTrack: AnimationTrack? = nil
	local SkillVfx: Instance? = nil
	local DashAttachment: Attachment? = nil
	local DashBodyVelocity: BodyVelocity? = nil
	local DashAlignOrientation: AlignOrientation? = nil
	local ReplicatorStarted: boolean = false
	local EffectsStoppedEarly: boolean = false
	local SlowdownStarted: boolean = false
	local DashTrackConnections: {RBXScriptConnection} = {}

	local function TrackDashConnection(Connection: RBXScriptConnection): ()
		table.insert(DashTrackConnections, Connection)
	end

	local function DisconnectDashTrackConnections(): ()
		for _, Connection in DashTrackConnections do
			if Connection.Connected then
				Connection:Disconnect()
			end
		end
		table.clear(DashTrackConnections)
	end

	local function StopReplicatedEffects(): ()
		if not ReplicatorStarted then
			return
		end

		FireReplicator(Player, Token, "End", nil)
		ReplicatorStarted = false
	end

	local function StartDashSlowdown(): ()
		if SlowdownStarted then
			return
		end

		SlowdownStarted = true
		if not EffectsStoppedEarly then
			EffectsStoppedEarly = true
			FatGuySkillUtils.DisableVfxEffects(SkillVfx)
		end
		if ReplicatorStarted then
			FireReplicator(Player, Token, "Slowdown", nil)
		end
	end

	FatGuySkillUtils.RegisterCleanup(Session, function()
		DisconnectDashTrackConnections()
	end)

	FatGuySkillUtils.RegisterCleanup(Session, function()
		FatGuySkillUtils.StopCharacterSound(Session.Character, MOVE2_SOUND_NAME)
		if DashTrack then
			DashTrack:Stop(0)
			DashTrack:Destroy()
			DashTrack = nil
		end
		if DashAlignOrientation then
			DashAlignOrientation:Destroy()
			DashAlignOrientation = nil
		end
		if DashBodyVelocity then
			DashBodyVelocity:Destroy()
			DashBodyVelocity = nil
		end
		if DashAttachment then
			DashAttachment:Destroy()
			DashAttachment = nil
		end
		if SkillVfx then
			FatGuySkillUtils.CleanupVfxInstance(SkillVfx, VFX_DESTROY_DELAY)
			SkillVfx = nil
		end
		Session.Root.AssemblyLinearVelocity = Vector3.zero
		Session.Root.AssemblyAngularVelocity = Vector3.zero
		StopReplicatedEffects()
		if ActiveTokens[Player] == Token then
			ActiveTokens[Player] = nil
		end
	end)

	local Success: boolean, ErrorMessage: any = xpcall(function()
		FatGuySkillUtils.WarmAnimations(Session.Character, {
			MOVE2_ANIMATION_ID,
		})

		SkillVfx = FatGuySkillUtils.SpawnAttachedVfx(Session, MOVE2_SKILL_ALIASES, MOVE2_VFX_OFFSET)

		local function HandleDashMarker(MarkerName: string): ()
			if MarkerName == STEP1_MARKER_NAME then
				FatGuySkillUtils.TriggerNamedEffects(SkillVfx, { "OrangeStep2" })
				FatGuySkillUtils.DisableNamedEffects(SkillVfx, { "OrangeStep2" })
				return
			end
			if MarkerName == STEP2_MARKER_NAME then
				FatGuySkillUtils.TriggerNamedEffects(SkillVfx, { "OrangeStep" })
				FatGuySkillUtils.DisableNamedEffects(SkillVfx, { "OrangeStep" })
				return
			end
			if MarkerName == ARMOR_MARKER_NAME then
				FatGuySkillUtils.TriggerNamedEffects(SkillVfx, { "ArmorActivate" })
				FatGuySkillUtils.EnableNamedEffects(SkillVfx, { "Armor" })
				FatGuySkillUtils.DisableNamedEffects(SkillVfx, { "ArmorActivate" })
				FatGuySkillUtils.PlayReusableCharacterSound(
					Session.Character,
					MOVE2_SOUND_NAME,
					MOVE2_ARMOR_SOUND_ID,
					MOVE2_SOUND_VOLUME
				)
				FireReplicator(Player, Token, "ArmorActivate", nil)
			end
		end

		FatGuySkillUtils.ScheduleFrameEvents({
			{
				Frame = SPEED_LINES_FRAME,
				Callback = function()
					FatGuySkillUtils.TriggerNamedEffects(SkillVfx, { "SpeedLines" })
					FatGuySkillUtils.PlayReusableCharacterSound(
						Session.Character,
						MOVE2_SOUND_NAME,
						MOVE2_ARMOR_SOUND_ID,
						MOVE2_SOUND_VOLUME
					)
				end,
			},
		}, IsCurrent, PLAYBACK_TIMELINE_FPS)

		DashTrack = FatGuySkillUtils.LoadAnimationTrack(Session.Character, MOVE2_ANIMATION_ID)
		if DashTrack then
			DashTrack.Priority = Enum.AnimationPriority.Action
			DashTrack:Play(0.05, ONE, MOVE2_PLAYBACK_SPEED)
			TrackDashConnection(DashTrack:GetMarkerReachedSignal(STEP1_MARKER_NAME):Connect(function()
				if IsCurrent() then
					HandleDashMarker(STEP1_MARKER_NAME)
				end
			end))
			TrackDashConnection(DashTrack:GetMarkerReachedSignal(STEP2_MARKER_NAME):Connect(function()
				if IsCurrent() then
					HandleDashMarker(STEP2_MARKER_NAME)
				end
			end))
			TrackDashConnection(DashTrack:GetMarkerReachedSignal(ARMOR_MARKER_NAME):Connect(function()
				if IsCurrent() then
					HandleDashMarker(ARMOR_MARKER_NAME)
				end
			end))
		end

		DashAttachment, DashBodyVelocity, DashAlignOrientation = CreateDashControllers(Session.Root, Session.Forward, BodyVelocityForce)

		local DashDuration: number =
			if DashTrack and DashTrack.Length > 0
			then DashTrack.Length / MOVE2_PLAYBACK_SPEED
			else PLAYBACK_MOVE2_DURATION
		FireReplicator(Player, Token, "Start", DashDuration)
		ReplicatorStarted = true

		task.delay(math.max(DashDuration - PRE_END_SLOWDOWN_LEAD_TIME, 0), function()
			if not IsCurrent() then
				return
			end

			StartDashSlowdown()
		end)

		local TrackStopped: boolean = DashTrack == nil
		local TrackConnection: RBXScriptConnection? = nil
		if DashTrack then
			TrackConnection = DashTrack.Stopped:Connect(function()
				TrackStopped = true
			end)
			TrackDashConnection(TrackConnection)
		end

		local BaseDashSpeed: number = (DashDistance / math.max(DashDuration, 0.001)) * MOVE2_SPEED_MULTIPLIER
		FatGuySkillUtils.RunHeartbeatLoop(DashDuration, IsCurrent, function(Elapsed: number, _DeltaTime: number)
			if TrackStopped then
				return false
			end

			local Alpha: number = math.clamp(Elapsed / math.max(DashDuration, 0.001), ZERO, ONE)
			local AcceleratedAlpha: number = TweenService:GetValue(Alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			local DistanceAlpha: number = (Alpha * DASH_HEADSTART_BLEND) + (AcceleratedAlpha * (ONE - DASH_HEADSTART_BLEND))
			local SpeedScale: number = 0.65 + (DistanceAlpha * 2.35)
			if DashAlignOrientation then
				DashAlignOrientation.CFrame = CFrame.lookAt(Vector3.zero, Session.Forward, Vector3.yAxis)
			end

			local DashSpeed: number = BaseDashSpeed * SpeedScale
			local HorizontalVelocity: Vector3 = Vector3.new(
				Session.Forward.X * DashSpeed,
				ZERO,
				Session.Forward.Z * DashSpeed
			)
			if DashBodyVelocity then
				DashBodyVelocity.Velocity = HorizontalVelocity
			end
			Session.Root.AssemblyLinearVelocity = HorizontalVelocity
			Session.Root.AssemblyAngularVelocity = Vector3.zero
			return Alpha < ONE
		end)

		if not IsCurrent() then
			return
		end

		StartDashSlowdown()

		if DashBodyVelocity then
			DashBodyVelocity.Velocity = Vector3.zero
		end

		WaitUntilTrackStops(IsCurrent, DashTrack, TRACK_END_GRACE)
	end, debug.traceback)

	FatGuySkillUtils.EndSkill(Session)

	if not Success then
		warn(string.format("FatGuyMove2 failed for %s: %s", Player.Name, tostring(ErrorMessage)))
	end
end
