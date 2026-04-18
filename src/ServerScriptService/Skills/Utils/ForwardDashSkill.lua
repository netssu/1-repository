--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local Workspace: Workspace = game:GetService("Workspace")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)

type CFrameTrackKeyframe = {
	Frame: number,
	RelativeCFrame: CFrame,
}

type CFrameTrackConfig = {
	Keyframes: {CFrameTrackKeyframe},
	Fps: number?,
	WorldOffset: Vector3,
	WorldOrientationOffset: Vector3?,
	UseWorldSpacePositionOffset: boolean?,
	UseAbsoluteOrientationOffset: boolean?,
	AnchorRootToFirstKeyframe: boolean?,
	InterpolateBetweenKeyframes: boolean?,
	PreserveStartHeight: boolean?,
	PreserveStartOrientation: boolean?,
	ApplyToCharacterPivot: boolean?,
	UseTrackBasePositionOnly: boolean?,
	UseFlatRootOrientation: boolean?,
}

type DashState = {
	Active: boolean,
	Character: Model?,
	Token: number,
	Started: boolean,
	Ended: boolean,
	EndQueued: boolean,
	MoveToken: number,
	FailsafeToken: number,
	LastDirection: Vector3,
	AlignPosition: AlignPosition?,
	AlignAttachment: Attachment?,
	AlignAttachmentOwned: boolean,
	OrientationAttachment: Attachment?,
	OrientationConstraint: AlignOrientation?,
	OriginalAutoRotate: boolean?,
	AutoRotateHumanoid: Humanoid?,
	OriginalWalkSpeed: number?,
	OriginalJumpPower: number?,
	OriginalJumpHeight: number?,
	OriginalUseJumpPower: boolean?,
	NetworkOwnerRoot: BasePart?,
	OriginalNetworkOwner: Player?,
}

type ResolveStartDirectionCallback = (
	Player: Player,
	Character: Model,
	Root: BasePart,
	State: DashState,
	DefaultDirection: Vector3
) -> Vector3?

type ResolveDashDirectionCallback = (
	Player: Player,
	Character: Model,
	Root: BasePart,
	State: DashState,
	CurrentDirection: Vector3
) -> Vector3?

type DashLifecycleCallback = (Player: Player, Character: Model, Root: BasePart, State: DashState, Token: number) -> ()
type DashClearedCallback = (Player: Player, Character: Model?, Root: BasePart?, State: DashState, Token: number) -> ()

type ForwardDashConfig = {
	TypeName: string,
	DashSpeed: number,
	FailsafeTime: number,
	EndSlowDuration: number,
	PostEndMovementLockDuration: number?,
	ApplyDashVelocity: boolean?,
	ApplyDashAlignPosition: boolean?,
	DashMaxForce: number?,
	DashResponsiveness: number?,
	DashRigidityEnabled: boolean?,
	EndMaxForce: number?,
	EndResponsiveness: number?,
	EndRigidityEnabled: boolean?,
	DashDirectionLerpAlpha: number?,
	CFrameTrack: CFrameTrackConfig?,
	AlignPositionName: string,
	AlignAttachmentName: string,
	OrientationAttachmentName: string,
	OrientationConstraintName: string,
	ResolveStartDirection: ResolveStartDirectionCallback?,
	ResolveDashDirection: ResolveDashDirectionCallback?,
	OnSkillActivated: DashLifecycleCallback?,
	OnDashStarted: DashLifecycleCallback?,
	OnDashCleared: DashClearedCallback?,
}

local ForwardDashSkill = {}

local ZERO: number = 0
local ONE: number = 1
local TOKEN_MAX: number = 65535
local MIN_DIRECTION_MAGNITUDE: number = 0.01
local WALK_MAX_FORCE: number = 900000
local DASH_MAX_FORCE: number = 1800000
local END_MAX_FORCE: number = 2200000
local WALK_RESPONSIVENESS: number = 180
local DASH_RESPONSIVENESS: number = 400
local END_RESPONSIVENESS: number = 500
local END_RIGIDITY_ENABLED: boolean = true
local WALK_RIGIDITY_ENABLED: boolean = false
local DASH_RIGIDITY_ENABLED: boolean = true
local ORIENTATION_MAX_TORQUE: number = 1000000000
local ORIENTATION_RESPONSIVENESS: number = 320
local DASH_COLLISION_CLEARANCE: number = 1.1
local DASH_COLLISION_NORMAL_DOT: number = -0.1
local DASH_COLLISION_MIN_STEP: number = 0.05
local END_POSITION_SETTLE_MIN_DURATION: number = 0.01
local DEFAULT_CFRAME_TRACK_FPS: number = 60
local MIN_CFRAME_TRACK_FPS: number = 1
local KEYFRAME_TIME_EPSILON: number = 1 / 240
local ZERO_VECTOR: Vector3 = Vector3.zero
local FALLBACK_DIRECTION: Vector3 = Vector3.new(1, 0, 0)
local ATTR_INVULNERABLE: string = "Invulnerable"
local ATTR_SCORING_PAUSE_LOCKED: string = "FTScoringPauseLocked"
local ROOT_ATTACHMENT_NAME: string = "RootAttachment"
local PHASE_ACTION_START: string = "Start"
local PHASE_ACTION_END: string = "End"

local function NextToken(Current: number): number
	local NextValue: number = Current + ONE
	if NextValue > TOKEN_MAX then
		return ZERO
	end
	return NextValue
end

local function SetInvulnerable(Player: Player, Character: Model?, Enabled: boolean): ()
	Player:SetAttribute(ATTR_INVULNERABLE, Enabled)
	if Character then
		Character:SetAttribute(ATTR_INVULNERABLE, Enabled)
	end
end

local function ResolveDirection(Direction: Vector3, Fallback: Vector3?): Vector3
	local Flat: Vector3 = GlobalFunctions.FlattenDirection(Direction)
	if Flat.Magnitude >= MIN_DIRECTION_MAGNITUDE then
		return Flat.Unit
	end

	local FallbackDirection: Vector3 = Fallback or FALLBACK_DIRECTION
	local FallbackFlat: Vector3 = GlobalFunctions.FlattenDirection(FallbackDirection)
	if FallbackFlat.Magnitude >= MIN_DIRECTION_MAGNITUDE then
		return FallbackFlat.Unit
	end

	return FALLBACK_DIRECTION
end

local function CaptureNetworkOwner(Root: BasePart, State: DashState): ()
	State.NetworkOwnerRoot = Root
	State.OriginalNetworkOwner = nil
	pcall(function()
		State.OriginalNetworkOwner = Root:GetNetworkOwner()
	end)
	pcall(function()
		Root:SetNetworkOwnershipAuto(false)
		Root:SetNetworkOwner(nil)
	end)
end

local function RestoreNetworkOwner(State: DashState): ()
	local Root: BasePart? = State.NetworkOwnerRoot
	if not Root or Root.Parent == nil then
		State.NetworkOwnerRoot = nil
		State.OriginalNetworkOwner = nil
		return
	end

	if State.OriginalNetworkOwner then
		pcall(function()
			Root:SetNetworkOwner(State.OriginalNetworkOwner)
		end)
	else
		pcall(function()
			Root:SetNetworkOwnershipAuto(true)
		end)
	end

	State.NetworkOwnerRoot = nil
	State.OriginalNetworkOwner = nil
end

local function CreateCollisionParams(Character: Model): RaycastParams
	local Params: RaycastParams = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Character }
	Params.IgnoreWater = true
	return Params
end

local function ResolveDashCollision(
	Character: Model,
	Root: BasePart,
	Direction: Vector3,
	StepDistance: number,
	CollisionParams: RaycastParams
): (Vector3, boolean)
	if StepDistance <= DASH_COLLISION_MIN_STEP then
		return Root.Position + (Direction * StepDistance), false
	end

	local CastSize: Vector3 = Vector3.new(
		math.max(Root.Size.X * 0.8, 1),
		math.max(Root.Size.Y * 0.75, 2),
		math.max(Root.Size.Z * 0.8, 1)
	)
	local CastResult: RaycastResult? = Workspace:Blockcast(Root.CFrame, CastSize, Direction * StepDistance, CollisionParams)
	if not CastResult then
		return Root.Position + (Direction * StepDistance), false
	end

	local HitPart: Instance? = CastResult.Instance
	if not HitPart or not HitPart:IsA("BasePart") or HitPart:IsDescendantOf(Character) or not HitPart.CanCollide then
		return Root.Position + (Direction * StepDistance), false
	end

	local HitNormal: Vector3 = GlobalFunctions.FlattenDirection(CastResult.Normal)
	if HitNormal.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return Root.Position + (Direction * StepDistance), false
	end
	if HitNormal.Unit:Dot(Direction) > DASH_COLLISION_NORMAL_DOT then
		return Root.Position + (Direction * StepDistance), false
	end

	local SafeDistance: number = math.max(CastResult.Distance - DASH_COLLISION_CLEARANCE, ZERO)
	return Root.Position + (Direction * SafeDistance), true
end

local function DirectionToCFrame(Direction: Vector3): CFrame
	return CFrame.new(ZERO_VECTOR, ZERO_VECTOR + Direction)
end

local function HasCFrameTrack(Config: ForwardDashConfig): boolean
	return Config.CFrameTrack ~= nil
end

local function ShouldApplyDashVelocity(Config: ForwardDashConfig): boolean
	return Config.ApplyDashVelocity ~= false
end

local function ShouldApplyDashAlignPosition(Config: ForwardDashConfig): boolean
	return Config.ApplyDashAlignPosition ~= false
end

local function ShouldCaptureNetworkOwnership(Config: ForwardDashConfig): boolean
	return ShouldApplyDashAlignPosition(Config) or HasCFrameTrack(Config)
end

local function GetPostEndMovementLockDuration(Config: ForwardDashConfig): number
	return math.max(Config.PostEndMovementLockDuration or ZERO, ZERO)
end

local function SafeRunDashCallback(CallbackName: string, Callback: any, ...: any): ()
	if Callback == nil then
		return
	end

	local Success: boolean, ErrorMessage: any = pcall(Callback, ...)
	if not Success then
		warn(string.format("ForwardDashSkill.%s callback failed: %s", CallbackName, tostring(ErrorMessage)))
	end
end

local function ResolveOffsetTransformCFrame(
	SourceCFrame: CFrame,
	PositionOffset: Vector3,
	OrientationOffset: Vector3?,
	UseWorldSpacePositionOffset: boolean?,
	UseAbsoluteOrientationOffset: boolean?
): CFrame
	local RotationOffset: Vector3 = OrientationOffset or ZERO_VECTOR
	local RotationOffsetCFrame: CFrame = CFrame.fromOrientation(
		math.rad(RotationOffset.X),
		math.rad(RotationOffset.Y),
		math.rad(RotationOffset.Z)
	)
	local Position: Vector3 =
		if UseWorldSpacePositionOffset == true
		then SourceCFrame.Position + PositionOffset
		else (SourceCFrame * CFrame.new(PositionOffset)).Position
	local Rotation: CFrame =
		if UseAbsoluteOrientationOffset == true
		then RotationOffsetCFrame
		else (SourceCFrame - SourceCFrame.Position) * RotationOffsetCFrame
	return CFrame.new(Position) * Rotation
end

local function ResolveKeyframeTime(Frame: number, FramesPerSecond: number): number
	return math.max(Frame, ZERO) / FramesPerSecond
end

local function ResolveFlatRootCFrame(Root: BasePart, State: DashState, TrackConfig: CFrameTrackConfig): CFrame
	if TrackConfig.UseFlatRootOrientation == false then
		return Root.CFrame
	end

	local Direction: Vector3 = ResolveDirection(Root.CFrame.LookVector, State.LastDirection)
	return CFrame.lookAt(Root.Position, Root.Position + Direction)
end

local function SampleRelativeCFrameAtTime(
	Keyframes: {CFrameTrackKeyframe},
	FramesPerSecond: number,
	ElapsedTime: number,
	InterpolateBetweenKeyframes: boolean
): CFrame
	local CurrentKeyframe: CFrameTrackKeyframe = Keyframes[1]
	local CurrentTime: number = ResolveKeyframeTime(CurrentKeyframe.Frame, FramesPerSecond)

	if ElapsedTime <= CurrentTime + KEYFRAME_TIME_EPSILON then
		return CurrentKeyframe.RelativeCFrame
	end

	for Index = 2, #Keyframes do
		local NextKeyframe: CFrameTrackKeyframe = Keyframes[Index]
		local NextTime: number = ResolveKeyframeTime(NextKeyframe.Frame, FramesPerSecond)
		if ElapsedTime <= NextTime + KEYFRAME_TIME_EPSILON then
			if not InterpolateBetweenKeyframes then
				return CurrentKeyframe.RelativeCFrame
			end

			local SegmentDuration: number = math.max(NextTime - CurrentTime, KEYFRAME_TIME_EPSILON)
			local Alpha: number = math.clamp((ElapsedTime - CurrentTime) / SegmentDuration, ZERO, ONE)
			return CurrentKeyframe.RelativeCFrame:Lerp(NextKeyframe.RelativeCFrame, Alpha)
		end

		CurrentKeyframe = NextKeyframe
		CurrentTime = NextTime
	end

	return CurrentKeyframe.RelativeCFrame
end

function ForwardDashSkill.Create(Config: ForwardDashConfig): (Character: Model) -> ()
	local DashStates: {[Player]: DashState} = {}
	local OrderedCFrameTrackKeyframes: {CFrameTrackKeyframe}? = nil
	local CFrameTrackFps: number = DEFAULT_CFRAME_TRACK_FPS
	local DashMaxForce: number =
		if type(Config.DashMaxForce) == "number" and Config.DashMaxForce == Config.DashMaxForce and Config.DashMaxForce > ZERO
		then Config.DashMaxForce
		else DASH_MAX_FORCE
	local DashResponsiveness: number =
		if type(Config.DashResponsiveness) == "number"
			and Config.DashResponsiveness == Config.DashResponsiveness
			and Config.DashResponsiveness > ZERO
		then Config.DashResponsiveness
		else DASH_RESPONSIVENESS
	local DashRigidityEnabled: boolean =
		if type(Config.DashRigidityEnabled) == "boolean" then Config.DashRigidityEnabled else DASH_RIGIDITY_ENABLED
	local EndMaxForce: number =
		if type(Config.EndMaxForce) == "number" and Config.EndMaxForce == Config.EndMaxForce and Config.EndMaxForce > ZERO
		then Config.EndMaxForce
		else END_MAX_FORCE
	local EndResponsiveness: number =
		if type(Config.EndResponsiveness) == "number"
			and Config.EndResponsiveness == Config.EndResponsiveness
			and Config.EndResponsiveness > ZERO
		then Config.EndResponsiveness
		else END_RESPONSIVENESS
	local EndRigidityEnabled: boolean =
		if type(Config.EndRigidityEnabled) == "boolean" then Config.EndRigidityEnabled else END_RIGIDITY_ENABLED
	local DashDirectionLerpAlpha: number =
		if type(Config.DashDirectionLerpAlpha) == "number"
			and Config.DashDirectionLerpAlpha == Config.DashDirectionLerpAlpha
			and Config.DashDirectionLerpAlpha > -math.huge
			and Config.DashDirectionLerpAlpha < math.huge
		then math.clamp(Config.DashDirectionLerpAlpha, ZERO, ONE)
		else ONE

	if Config.CFrameTrack then
		OrderedCFrameTrackKeyframes = table.clone(Config.CFrameTrack.Keyframes)
		table.sort(OrderedCFrameTrackKeyframes, function(Left: CFrameTrackKeyframe, Right: CFrameTrackKeyframe): boolean
			return Left.Frame < Right.Frame
		end)
		CFrameTrackFps = math.max(Config.CFrameTrack.Fps or DEFAULT_CFRAME_TRACK_FPS, MIN_CFRAME_TRACK_FPS)
	end

	local function GetState(Player: Player): DashState
		local Existing: DashState? = DashStates[Player]
		if Existing then
			return Existing
		end

		local State: DashState = {
			Active = false,
			Character = nil,
			Token = ZERO,
			Started = false,
			Ended = false,
			EndQueued = false,
			MoveToken = ZERO,
			FailsafeToken = ZERO,
			LastDirection = ZERO_VECTOR,
			AlignPosition = nil,
			AlignAttachment = nil,
			AlignAttachmentOwned = false,
			OrientationAttachment = nil,
			OrientationConstraint = nil,
			OriginalAutoRotate = nil,
			AutoRotateHumanoid = nil,
			OriginalWalkSpeed = nil,
			OriginalJumpPower = nil,
			OriginalJumpHeight = nil,
			OriginalUseJumpPower = nil,
			NetworkOwnerRoot = nil,
			OriginalNetworkOwner = nil,
		}

		DashStates[Player] = State
		return State
	end

	local function SmoothDashDirection(CurrentDirection: Vector3, TargetDirection: Vector3): Vector3
		if DashDirectionLerpAlpha >= ONE then
			return TargetDirection
		end

		local Blended: Vector3 = CurrentDirection:Lerp(TargetDirection, DashDirectionLerpAlpha)
		if Blended.Magnitude >= MIN_DIRECTION_MAGNITUDE then
			return Blended.Unit
		end

		return TargetDirection
	end

	local function UpdateDashDirection(Player: Player, Character: Model, Root: BasePart, State: DashState): ()
		local ResolveDashDirection: ResolveDashDirectionCallback? = Config.ResolveDashDirection
		if ResolveDashDirection == nil then
			return
		end

		local CurrentDirection: Vector3 = ResolveDirection(State.LastDirection, Root.CFrame.LookVector)
		local Success: boolean, Result: any =
			pcall(ResolveDashDirection, Player, Character, Root, State, CurrentDirection)
		if not Success then
			warn(string.format("ForwardDashSkill.ResolveDashDirection failed: %s", tostring(Result)))
			return
		end
		if typeof(Result) ~= "Vector3" then
			return
		end

		local TargetDirection: Vector3 = ResolveDirection(Result, CurrentDirection)
		State.LastDirection = SmoothDashDirection(CurrentDirection, TargetDirection)
	end

	local function FireReplicator(Player: Player, Action: string, Token: number): ()
		local Payload = {
			Type = Config.TypeName,
			Action = Action,
			Token = Token,
			SourceUserId = Player.UserId,
		}

		for _, Observer in Players:GetPlayers() do
			Packets.Replicator:FireClient(Observer, Payload)
		end
	end

	local function ClearAlignPosition(State: DashState): ()
		if State.AlignPosition then
			State.AlignPosition:Destroy()
			State.AlignPosition = nil
		end
		if State.AlignAttachmentOwned and State.AlignAttachment then
			State.AlignAttachment:Destroy()
		end
		State.AlignAttachment = nil
		State.AlignAttachmentOwned = false
		State.MoveToken = ZERO
	end

	local function ClearOrientation(State: DashState): ()
		if State.OrientationConstraint then
			State.OrientationConstraint:Destroy()
			State.OrientationConstraint = nil
		end
		if State.OrientationAttachment then
			State.OrientationAttachment:Destroy()
			State.OrientationAttachment = nil
		end
	end

	local function RestoreMovementLock(Player: Player, State: DashState, Character: Model?, Token: number): ()
		if State.Token ~= Token then
			return
		end

		local CurrentCharacter: Model? = Character
		local ShouldRestoreHumanoid: boolean = CurrentCharacter ~= nil and CurrentCharacter.Parent ~= nil
		if not ShouldRestoreHumanoid then
			CurrentCharacter = Player.Character
		end

		local HumanoidInstance: Humanoid? =
			if ShouldRestoreHumanoid and CurrentCharacter then CurrentCharacter:FindFirstChildOfClass("Humanoid") else nil
		if HumanoidInstance and CurrentCharacter then
			HumanoidInstance.AutoRotate = State.OriginalAutoRotate == true
			if State.OriginalWalkSpeed ~= nil then
				HumanoidInstance.WalkSpeed = State.OriginalWalkSpeed
			end

			local UseJumpPower: boolean = State.OriginalUseJumpPower ~= false
			HumanoidInstance.UseJumpPower = UseJumpPower
			if UseJumpPower then
				if State.OriginalJumpPower ~= nil then
					HumanoidInstance.JumpPower = State.OriginalJumpPower
				end
			elseif State.OriginalJumpHeight ~= nil then
				HumanoidInstance.JumpHeight = State.OriginalJumpHeight
			end

			HumanoidInstance.PlatformStand = false
			HumanoidInstance.Sit = false
			HumanoidInstance:Move(ZERO_VECTOR, false)
		end

		State.AutoRotateHumanoid = nil
		State.OriginalAutoRotate = nil
		State.OriginalWalkSpeed = nil
			State.OriginalJumpPower = nil
			State.OriginalJumpHeight = nil
			State.OriginalUseJumpPower = nil

		GlobalFunctions.SetSkillLock(Player, CurrentCharacter, false)
	end

	local function ClearDash(Player: Player, State: DashState): ()
		local Token: number = State.Token
		local ShouldNotify: boolean = State.Active and not State.Ended
		local Character: Model? = State.Character
		local Root: BasePart? = if Character then Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil

		ClearAlignPosition(State)
		ClearOrientation(State)
		RestoreNetworkOwner(State)

		if Root then
			Root.AssemblyLinearVelocity = ZERO_VECTOR
			Root.AssemblyAngularVelocity = ZERO_VECTOR
		end

		SetInvulnerable(Player, Character, false)

		State.Active = false
		State.Started = false
		State.Ended = true
		State.EndQueued = false
		State.LastDirection = ZERO_VECTOR
		SafeRunDashCallback("OnDashCleared", Config.OnDashCleared, Player, Character, Root, State, Token)
		State.Character = nil

		local PostEndMovementLockDuration: number = GetPostEndMovementLockDuration(Config)
		if PostEndMovementLockDuration <= ZERO then
			RestoreMovementLock(Player, State, Character, Token)
		else
			task.delay(PostEndMovementLockDuration, function()
				RestoreMovementLock(Player, State, Character, Token)
			end)
		end

		if ShouldNotify then
			FireReplicator(Player, "End", Token)
		end
	end

	local function EnsureOrientationLock(Root: BasePart, State: DashState): ()
		local Attachment: Attachment? = State.OrientationAttachment
		if not Attachment or Attachment.Parent ~= Root then
			if Attachment then
				Attachment:Destroy()
			end
			Attachment = Instance.new("Attachment")
			Attachment.Name = Config.OrientationAttachmentName
			Attachment.Parent = Root
			State.OrientationAttachment = Attachment
		end

		local Constraint: AlignOrientation? = State.OrientationConstraint
		if not Constraint or Constraint.Parent ~= Root then
			if Constraint then
				Constraint:Destroy()
			end
			Constraint = Instance.new("AlignOrientation")
			Constraint.Name = Config.OrientationConstraintName
			Constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
			Constraint.Attachment0 = Attachment
			Constraint.MaxTorque = ORIENTATION_MAX_TORQUE
			Constraint.Responsiveness = ORIENTATION_RESPONSIVENESS
			Constraint.RigidityEnabled = true
			Constraint.Parent = Root
			State.OrientationConstraint = Constraint
		end

		Constraint.CFrame = DirectionToCFrame(State.LastDirection)
		Constraint.Responsiveness = ORIENTATION_RESPONSIVENESS
	end

	local function EnsureAlignPosition(Root: BasePart, State: DashState): AlignPosition
		local Existing: AlignPosition? = State.AlignPosition
		if Existing and Existing.Parent == Root then
			return Existing
		end
		if Existing then
			Existing:Destroy()
		end

		local Attachment: Attachment? = Root:FindFirstChild(ROOT_ATTACHMENT_NAME) :: Attachment?
		local Owned: boolean = false
		if not Attachment or not Attachment:IsA("Attachment") then
			Attachment = Instance.new("Attachment")
			Attachment.Name = Config.AlignAttachmentName
			Attachment.Parent = Root
			Owned = true
		end

		local AlignInstance: AlignPosition = Instance.new("AlignPosition")
		AlignInstance.Name = Config.AlignPositionName
		AlignInstance.Mode = Enum.PositionAlignmentMode.OneAttachment
		AlignInstance.Attachment0 = Attachment
		AlignInstance.MaxForce = WALK_MAX_FORCE
		AlignInstance.Responsiveness = WALK_RESPONSIVENESS
		AlignInstance.RigidityEnabled = WALK_RIGIDITY_ENABLED
		AlignInstance.Position = Root.Position
		AlignInstance.Parent = Root

		State.AlignPosition = AlignInstance
		State.AlignAttachment = Attachment
		State.AlignAttachmentOwned = Owned

		return AlignInstance
	end

	local function BeginEndSlowdown(Player: Player, State: DashState, Token: number): ()
		if not ShouldApplyDashAlignPosition(Config) then
			ClearDash(Player, State)
			return
		end

		if State.EndQueued then
			return
		end

		State.EndQueued = true
		State.MoveToken += ONE
		local EndMoveToken: number = State.MoveToken

		local Character: Model? = Player.Character
		local Root: BasePart? = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not Character or not Root then
			ClearDash(Player, State)
			return
		end

		local AlignInstance: AlignPosition = EnsureAlignPosition(Root, State)
		AlignInstance.MaxForce = EndMaxForce
		AlignInstance.Responsiveness = EndResponsiveness
		AlignInstance.RigidityEnabled = EndRigidityEnabled
		local StopPosition: Vector3 = Root.Position
		AlignInstance.Position = StopPosition
		Root.AssemblyLinearVelocity = ZERO_VECTOR
		Root.AssemblyAngularVelocity = ZERO_VECTOR
		EnsureOrientationLock(Root, State)

		task.spawn(function()
			local StartTime: number = os.clock()
			local HoldDuration: number = math.max(Config.EndSlowDuration, END_POSITION_SETTLE_MIN_DURATION)

			while os.clock() - StartTime < HoldDuration do
				if State.Token ~= Token or State.Ended or State.MoveToken ~= EndMoveToken then
					return
				end

				AlignInstance.Position = StopPosition
				Root.AssemblyLinearVelocity = ZERO_VECTOR
				Root.AssemblyAngularVelocity = ZERO_VECTOR
				RunService.Heartbeat:Wait()
			end

			if State.Token ~= Token or State.Ended or State.MoveToken ~= EndMoveToken then
				return
			end

			ClearDash(Player, State)
		end)
	end

	local function StartDashMove(Player: Player, State: DashState, Token: number): ()
		if not ShouldApplyDashAlignPosition(Config) then
			return
		end

		State.MoveToken += ONE
		local MoveToken: number = State.MoveToken
		local DashCharacter: Model? = Player.Character
		if not DashCharacter then
			return
		end

		local CollisionParams: RaycastParams = CreateCollisionParams(DashCharacter)
		task.spawn(function()
			local LastTime: number = os.clock()
			while true do
				if not State.Active or State.Token ~= Token or State.MoveToken ~= MoveToken then
					return
				end
				if not State.Started or State.EndQueued or State.Ended then
					return
				end

				local CurrentCharacter: Model? = Player.Character
				if not CurrentCharacter or CurrentCharacter ~= DashCharacter then
					return
				end
				if Player:GetAttribute(ATTR_SCORING_PAUSE_LOCKED) == true
					or CurrentCharacter:GetAttribute(ATTR_SCORING_PAUSE_LOCKED) == true
				then
					ClearDash(Player, State)
					return
				end

				local Root: BasePart? = CurrentCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not Root then
					return
				end

				local Now: number = os.clock()
				local DeltaTime: number = math.clamp(Now - LastTime, 1 / 240, 1 / 20)
				LastTime = Now

				UpdateDashDirection(Player, CurrentCharacter, Root, State)
				local AlignInstance: AlignPosition = EnsureAlignPosition(Root, State)
				AlignInstance.MaxForce = DashMaxForce
				AlignInstance.Responsiveness = DashResponsiveness
				AlignInstance.RigidityEnabled = DashRigidityEnabled

				EnsureOrientationLock(Root, State)

				local StepDistance: number = Config.DashSpeed * DeltaTime
				local TargetPosition: Vector3, HitWall: boolean =
					ResolveDashCollision(CurrentCharacter, Root, State.LastDirection, StepDistance, CollisionParams)
				AlignInstance.Position = TargetPosition
				if ShouldApplyDashVelocity(Config) then
					Root.AssemblyLinearVelocity = State.LastDirection * Config.DashSpeed
				end
				Root.AssemblyAngularVelocity = ZERO_VECTOR

				if HitWall then
					Root.AssemblyLinearVelocity = ZERO_VECTOR
					Root.AssemblyAngularVelocity = ZERO_VECTOR
					BeginEndSlowdown(Player, State, Token)
					return
				end

				RunService.Heartbeat:Wait()
			end
		end)
	end

	local function StartCFrameTrackMove(Player: Player, State: DashState, Token: number): ()
		local TrackConfig: CFrameTrackConfig? = Config.CFrameTrack
		local Keyframes: {CFrameTrackKeyframe}? = OrderedCFrameTrackKeyframes
		if not TrackConfig or not Keyframes or #Keyframes <= 0 then
			return
		end

		State.MoveToken += ONE
		local MoveToken: number = State.MoveToken
		local DashCharacter: Model? = Player.Character
		local Root: BasePart? = DashCharacter and DashCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not DashCharacter or not Root then
			return
		end

		local RootAnchorCFrame: CFrame = ResolveFlatRootCFrame(Root, State, TrackConfig)
		local BaseCFrame: CFrame = ResolveOffsetTransformCFrame(
			RootAnchorCFrame,
			TrackConfig.WorldOffset,
			TrackConfig.WorldOrientationOffset,
			TrackConfig.UseWorldSpacePositionOffset,
			TrackConfig.UseAbsoluteOrientationOffset
		)
		local TrackBaseCFrame: CFrame =
			if TrackConfig.UseTrackBasePositionOnly == true
			then CFrame.new(BaseCFrame.Position)
			else BaseCFrame
		local FirstRelativeCFrame: CFrame = Keyframes[1].RelativeCFrame
		local InterpolateBetweenKeyframes: boolean = TrackConfig.InterpolateBetweenKeyframes == true
		local PreserveStartOrientation: boolean = TrackConfig.PreserveStartOrientation == true
		local PreservedRotationCFrame: CFrame = RootAnchorCFrame - RootAnchorCFrame.Position

		task.spawn(function()
			local StartTime: number = os.clock()

			while true do
				if not State.Active or State.Token ~= Token or State.MoveToken ~= MoveToken then
					return
				end
				if not State.Started or State.Ended then
					return
				end

				local CurrentCharacter: Model? = Player.Character
				local CurrentRoot: BasePart? =
					CurrentCharacter and CurrentCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not CurrentCharacter or CurrentCharacter ~= DashCharacter or not CurrentRoot then
					return
				end
				if Player:GetAttribute(ATTR_SCORING_PAUSE_LOCKED) == true
					or CurrentCharacter:GetAttribute(ATTR_SCORING_PAUSE_LOCKED) == true
				then
					ClearDash(Player, State)
					return
				end

				local ElapsedTime: number = os.clock() - StartTime
				local SampledRelativeCFrame: CFrame = SampleRelativeCFrameAtTime(
					Keyframes,
					CFrameTrackFps,
					ElapsedTime,
					InterpolateBetweenKeyframes
				)
				local TargetCFrame: CFrame
				if TrackConfig.AnchorRootToFirstKeyframe == true then
					local RelativeDelta: CFrame = FirstRelativeCFrame:ToObjectSpace(SampledRelativeCFrame)
					TargetCFrame = RootAnchorCFrame:ToWorldSpace(RelativeDelta)
				else
					TargetCFrame = TrackBaseCFrame:ToWorldSpace(SampledRelativeCFrame)
				end

				if PreserveStartOrientation then
					TargetCFrame = CFrame.new(TargetCFrame.Position) * PreservedRotationCFrame
				end

				if TrackConfig.PreserveStartHeight == true then
					local TargetPosition: Vector3 = TargetCFrame.Position
					local PreservedPosition: Vector3 = Vector3.new(
						TargetPosition.X,
						RootAnchorCFrame.Position.Y,
						TargetPosition.Z
					)
					TargetCFrame = CFrame.new(PreservedPosition) * (TargetCFrame - TargetCFrame.Position)
				end

				if TrackConfig.ApplyToCharacterPivot == true then
					CurrentCharacter:PivotTo(TargetCFrame)
				else
					CurrentRoot:PivotTo(TargetCFrame)
				end
				CurrentRoot.AssemblyLinearVelocity = ZERO_VECTOR
				CurrentRoot.AssemblyAngularVelocity = ZERO_VECTOR
				State.LastDirection = ResolveDirection(TargetCFrame.LookVector, State.LastDirection)
				RunService.Heartbeat:Wait()
			end
		end)
	end

	local function HandleStartMarker(Player: Player, Token: number): ()
		local State: DashState? = DashStates[Player]
		if not State or not State.Active or State.Token ~= Token or State.Started then
			return
		end

		local Character: Model? = Player.Character
		local Root: BasePart? = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not Character or not Root then
			return
		end

		State.Character = Character
		local DefaultDirection: Vector3 = ResolveDirection(Root.CFrame.LookVector, State.LastDirection)
		local StartedDirection: Vector3 = DefaultDirection
		local ResolveStartDirection: ResolveStartDirectionCallback? = Config.ResolveStartDirection
		if ResolveStartDirection ~= nil then
			local Success: boolean, Result: any =
				pcall(ResolveStartDirection, Player, Character, Root, State, DefaultDirection)
			if Success and typeof(Result) == "Vector3" then
				StartedDirection = ResolveDirection(Result, DefaultDirection)
			elseif not Success then
				warn(string.format("ForwardDashSkill.ResolveStartDirection failed: %s", tostring(Result)))
			end
		end
		State.LastDirection = StartedDirection
		State.Started = true
		State.Ended = false
		SafeRunDashCallback("OnDashStarted", Config.OnDashStarted, Player, Character, Root, State, Token)
		if HasCFrameTrack(Config) then
			StartCFrameTrackMove(Player, State, Token)
			return
		end
		StartDashMove(Player, State, Token)
	end

	local function HandleEndMarker(Player: Player, Token: number): ()
		local State: DashState? = DashStates[Player]
		if not State or not State.Active or State.Token ~= Token or State.Ended then
			return
		end

		BeginEndSlowdown(Player, State, Token)
	end

	Packets.SkillPhase.OnServerEvent:Connect(function(Player: Player, SkillType: string, Token: number, Action: string)
		if typeof(SkillType) ~= "string" or SkillType ~= Config.TypeName then
			return
		end
		if typeof(Token) ~= "number" then
			return
		end
		if typeof(Action) ~= "string" then
			return
		end

		local ParsedToken: number = math.floor(Token + 0.5)
		if Action == PHASE_ACTION_START then
			HandleStartMarker(Player, ParsedToken)
			return
		end
		if Action == PHASE_ACTION_END then
			HandleEndMarker(Player, ParsedToken)
		end
	end)

	local function BindCharacterRemoving(Player: Player): ()
		Player.CharacterRemoving:Connect(function(Character: Model)
			local State: DashState? = DashStates[Player]
			if not State or State.Character ~= Character then
				return
			end

			ClearDash(Player, State)
		end)
	end

	Players.PlayerAdded:Connect(BindCharacterRemoving)
	for _, Player in Players:GetPlayers() do
		BindCharacterRemoving(Player)
	end

	Players.PlayerRemoving:Connect(function(Player: Player)
		local State: DashState? = DashStates[Player]
		if not State then
			return
		end

		ClearDash(Player, State)
		DashStates[Player] = nil
	end)

	return function(Character: Model): ()
		local Player: Player? = Players:GetPlayerFromCharacter(Character)
		if not Player then
			return
		end

		local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not Root then
			return
		end

		local State: DashState = GetState(Player)
		ClearDash(Player, State)

		local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
		if HumanoidInstance then
			State.AutoRotateHumanoid = HumanoidInstance
			State.OriginalAutoRotate = HumanoidInstance.AutoRotate
			State.OriginalWalkSpeed = HumanoidInstance.WalkSpeed
			State.OriginalJumpPower = HumanoidInstance.JumpPower
			State.OriginalJumpHeight = HumanoidInstance.JumpHeight
			State.OriginalUseJumpPower = HumanoidInstance.UseJumpPower
			HumanoidInstance.AutoRotate = false
			HumanoidInstance.WalkSpeed = ZERO
			if HumanoidInstance.UseJumpPower then
				HumanoidInstance.JumpPower = ZERO
			else
				HumanoidInstance.JumpHeight = ZERO
			end
			HumanoidInstance.PlatformStand = false
			HumanoidInstance.Sit = false
			HumanoidInstance:Move(ZERO_VECTOR, false)
		end

		State.Token = NextToken(State.Token)
		State.Active = true
		State.Started = false
		State.Ended = false
		State.EndQueued = false
		State.Character = Character
		State.FailsafeToken += ONE
		State.LastDirection = ResolveDirection(Root.CFrame.LookVector, FALLBACK_DIRECTION)
		Root.AssemblyLinearVelocity = ZERO_VECTOR
		Root.AssemblyAngularVelocity = ZERO_VECTOR

		GlobalFunctions.SetSkillLock(Player, Character, true)
		SetInvulnerable(Player, Character, true)
		if ShouldCaptureNetworkOwnership(Config) then
			CaptureNetworkOwner(Root, State)
		end
		SafeRunDashCallback("OnSkillActivated", Config.OnSkillActivated, Player, Character, Root, State, State.Token)
		FireReplicator(Player, "Start", State.Token)
		if HasCFrameTrack(Config) then
			State.Character = Character
			State.Started = true
			State.Ended = false
			StartCFrameTrackMove(Player, State, State.Token)
		end

		local FailsafeToken: number = State.FailsafeToken
		local Token: number = State.Token
		task.delay(Config.FailsafeTime, function()
			if State.Token ~= Token or State.FailsafeToken ~= FailsafeToken or not State.Active then
				return
			end

			ClearDash(Player, State)
		end)
	end
end

return ForwardDashSkill
