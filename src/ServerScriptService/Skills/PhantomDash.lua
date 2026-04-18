--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local Workspace: Workspace = game:GetService("Workspace")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)

type DashState = {
	Active: boolean,
	AlignAttachment: Attachment?,
	AlignAttachmentOwned: boolean,
	AlignPosition: AlignPosition?,
	Character: Model?,
	MoveToken: number,
	MoveTween: Tween?,
	OrientationAttachment: Attachment?,
	OrientationConstraint: AlignOrientation?,
	OriginalAutoRotate: boolean?,
	AutoRotateHumanoid: Humanoid?,
	EndQueued: boolean,
	Ended: boolean,
	FailsafeToken: number,
	LastDirection: Vector3,
	NetworkOwnerRoot: BasePart?,
	OriginalNetworkOwner: Player?,
	Started: boolean,
	Token: number,
}

--// CONSTANTS
local ZERO: number = 0
local ONE: number = 1

local TOKEN_MAX: number = 65535

local DASH_SPEED: number = 160
local WALK_MAX_FORCE: number = 900000
local DASH_MAX_FORCE: number = 1800000
local END_MAX_FORCE: number = 80000
local WALK_RESPONSIVENESS: number = 180
local DASH_RESPONSIVENESS: number = 400
local END_RESPONSIVENESS: number = 100
local NORMAL_DASH_DISTANCE_MULTIPLIER: number = 2.4
local AWAKEN_DASH_DISTANCE_MULTIPLIER: number = 3.1
local DASH_FAILSAFE_TIME: number = 3
local MIN_DIRECTION_MAGNITUDE: number = 0.01
local DIRECTION_DOT_WARNING: number = 0.85
local LOCK_LERP_ALPHA: number = 0.35
local DASH_COLLISION_CLEARANCE: number = 1.1
local DASH_COLLISION_NORMAL_DOT: number = -0.1
local DASH_COLLISION_MIN_STEP: number = 0.05
local ORIENTATION_MAX_TORQUE: number = 1000000000
local ORIENTATION_RESPONSIVENESS_PRE: number = 180
local ORIENTATION_RESPONSIVENESS_DASH: number = 320
local ORIENTATION_RIGIDITY_PRE: boolean = false
local ORIENTATION_RIGIDITY_DASH: boolean = true
local END_SLOW_DURATION: number = 0.12
local WALK_RIGIDITY_ENABLED: boolean = false
local DASH_RIGIDITY_ENABLED: boolean = true
local END_RIGIDITY_ENABLED: boolean = true
local ZERO_VECTOR: Vector3 = Vector3.new(ZERO, ZERO, ZERO)
local FALLBACK_DIRECTION: Vector3 = Vector3.new(ONE, ZERO, ZERO)

local ATTR_INVULNERABLE: string = "Invulnerable"
local ATTR_SCORING_PAUSE_LOCKED: string = "FTScoringPauseLocked"
local ATTR_AWAKEN_ACTIVE: string = "AwakenActive"

local ALIGN_POSITION_NAME: string = "PhantomDashAlign"
local ROOT_ATTACHMENT_NAME: string = "RootAttachment"
local ALIGN_ATTACHMENT_NAME: string = "PhantomDashAlignAttachment"
local ORIENTATION_ATTACHMENT_NAME: string = "PhantomDashOrientationAttachment"
local ORIENTATION_CONSTRAINT_NAME: string = "PhantomDashOrientation"

local MARKER_POINT1: string = "point1"
local MARKER_POINT2: string = "point2"
local SKILL_TYPE_NAME: string = "PhantomDash"

local DEBUG_ENABLED: boolean = false

local DashStates: {[Player]: DashState} = {}

local function FireReplicator(Player: Player, Action: string, Token: number): ()
	local Payload = {
		Type = SKILL_TYPE_NAME,
		Action = Action,
		Token = Token,
		SourceUserId = Player.UserId,
	}

	for _, Observer in Players:GetPlayers() do
		local Success: boolean, ErrorMessage: any = pcall(function()
			Packets.Replicator:FireClient(Observer, Payload)
		end)
		if not Success and DEBUG_ENABLED then
			warn(string.format("PhantomDash: Replicator fire failed: %s", tostring(ErrorMessage)))
		end
	end
end

local function GetDashState(Player: Player): DashState
	local Existing: DashState? = DashStates[Player]
	if Existing then
		return Existing
	end
	local NewState: DashState = {
		Active = false,
		AlignAttachment = nil,
		AlignAttachmentOwned = false,
		AlignPosition = nil,
		Character = nil,
		MoveToken = ZERO,
		MoveTween = nil,
		OrientationAttachment = nil,
		OrientationConstraint = nil,
		OriginalAutoRotate = nil,
		AutoRotateHumanoid = nil,
		EndQueued = false,
		Ended = false,
		FailsafeToken = ZERO,
		LastDirection = ZERO_VECTOR,
		NetworkOwnerRoot = nil,
		OriginalNetworkOwner = nil,
		Started = false,
		Token = ZERO,
	}
	DashStates[Player] = NewState
	return NewState
end

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

local function ClearAlignPosition(State: DashState): ()
	if State.MoveTween then
		State.MoveTween:Cancel()
		State.MoveTween:Destroy()
		State.MoveTween = nil
	end
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

local function RestoreNetworkOwner(_Player: Player, State: DashState): ()
	local Root: BasePart? = State.NetworkOwnerRoot
	if not Root then
		State.NetworkOwnerRoot = nil
		State.OriginalNetworkOwner = nil
		return
	end
	if not Root.Parent then
		State.NetworkOwnerRoot = nil
		State.OriginalNetworkOwner = nil
		return
	end
	local RestoreOwner: Player? = State.OriginalNetworkOwner
	if RestoreOwner then
		pcall(function()
			Root:SetNetworkOwner(RestoreOwner)
		end)
	else
		pcall(function()
			Root:SetNetworkOwnershipAuto(true)
		end)
	end
	State.NetworkOwnerRoot = nil
	State.OriginalNetworkOwner = nil
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

local function ClearDash(Player: Player, State: DashState): ()
	local Token: number = State.Token
	local ShouldNotify: boolean = not State.Ended
	local Character: Model? = State.Character
	local Root: BasePart? = if Character then Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	ClearAlignPosition(State)
	ClearOrientation(State)
	RestoreNetworkOwner(Player, State)
	if Root then
		Root.AssemblyAngularVelocity = ZERO_VECTOR
	end
	if State.AutoRotateHumanoid then
		State.AutoRotateHumanoid.AutoRotate = State.OriginalAutoRotate == true
		State.AutoRotateHumanoid = nil
		State.OriginalAutoRotate = nil
	end
	SetInvulnerable(Player, State.Character, false)
	GlobalFunctions.SetSkillLock(Player, State.Character, false)
	State.Active = false
	State.Started = false
	State.Ended = true
	State.EndQueued = false
	State.Character = nil
	State.LastDirection = ZERO_VECTOR
	if ShouldNotify then
		FireReplicator(Player, "End", Token)
	end
end

local function FlattenDirection(Direction: Vector3): Vector3
	return Vector3.new(Direction.X, ZERO, Direction.Z)
end

local function ResolveDirection(Root: BasePart, Direction: Vector3): Vector3
	local Flat: Vector3 = FlattenDirection(Direction)
	if Flat.Magnitude < MIN_DIRECTION_MAGNITUDE then
		local Look: Vector3 = Root.CFrame.LookVector
		Flat = FlattenDirection(Look)
	end
	if Flat.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return FALLBACK_DIRECTION
	end
	return Flat.Unit
end

local function ResolveActivationDirection(Root: BasePart): Vector3
	local VelocityDirection: Vector3 = FlattenDirection(Root.AssemblyLinearVelocity)
	if VelocityDirection.Magnitude >= MIN_DIRECTION_MAGNITUDE then
		return VelocityDirection.Unit
	end
	return ResolveDirection(Root, Root.CFrame.LookVector)
end

local function GetLockedDirection(Root: BasePart, State: DashState): Vector3
	local LockedDirection: Vector3 = State.LastDirection
	if LockedDirection.Magnitude < MIN_DIRECTION_MAGNITUDE then
		LockedDirection = ResolveDirection(Root, Root.CFrame.LookVector)
		State.LastDirection = LockedDirection
	end
	return LockedDirection
end

local function IsScoringPauseLocked(Player: Player, Character: Model?): boolean
	if Player:GetAttribute(ATTR_SCORING_PAUSE_LOCKED) == true then
		return true
	end
	if Character and Character:GetAttribute(ATTR_SCORING_PAUSE_LOCKED) == true then
		return true
	end
	return false
end

local function IsAwakenActive(Player: Player, Character: Model): boolean
	return Player:GetAttribute(ATTR_AWAKEN_ACTIVE) == true or Character:GetAttribute(ATTR_AWAKEN_ACTIVE) == true
end

local function DirectionToCFrame(Direction: Vector3): CFrame
	return CFrame.new(ZERO_VECTOR, ZERO_VECTOR + Direction)
end

local function CreateDashCollisionParams(Character: Model): RaycastParams
	local Params: RaycastParams = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.IgnoreWater = true
	Params.FilterDescendantsInstances = { Character }
	return Params
end

local function ResolveDashCollision(
	Character: Model,
	Root: BasePart,
	LockedDirection: Vector3,
	StepDistance: number,
	CollisionParams: RaycastParams
): (Vector3, boolean)
	if StepDistance <= DASH_COLLISION_MIN_STEP then
		return Root.Position + (LockedDirection * StepDistance), false
	end

	local CastSize: Vector3 = Vector3.new(
		math.max(Root.Size.X * 0.8, 1),
		math.max(Root.Size.Y * 0.75, 2),
		math.max(Root.Size.Z * 0.8, 1)
	)
	local CastResult: RaycastResult? = Workspace:Blockcast(Root.CFrame, CastSize, LockedDirection * StepDistance, CollisionParams)
	if not CastResult then
		return Root.Position + (LockedDirection * StepDistance), false
	end

	local HitPart: Instance? = CastResult.Instance
	if not HitPart or not HitPart:IsA("BasePart") then
		return Root.Position + (LockedDirection * StepDistance), false
	end
	if HitPart:IsDescendantOf(Character) or not HitPart.CanCollide then
		return Root.Position + (LockedDirection * StepDistance), false
	end

	local HitNormal: Vector3 = Vector3.new(CastResult.Normal.X, ZERO, CastResult.Normal.Z)
	if HitNormal.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return Root.Position + (LockedDirection * StepDistance), false
	end
	if HitNormal.Unit:Dot(LockedDirection) > DASH_COLLISION_NORMAL_DOT then
		return Root.Position + (LockedDirection * StepDistance), false
	end

	local SafeDistance: number = math.max(CastResult.Distance - DASH_COLLISION_CLEARANCE, ZERO)
	return Root.Position + (LockedDirection * SafeDistance), true
end

local function EnsureOrientationLock(Player: Player, Root: BasePart, State: DashState): ()
	local LockedDirection: Vector3 = GetLockedDirection(Root, State)
	local Attachment: Attachment? = State.OrientationAttachment
	if not Attachment or Attachment.Parent ~= Root then
		if Attachment then
			Attachment:Destroy()
		end
		Attachment = Instance.new("Attachment")
		Attachment.Name = ORIENTATION_ATTACHMENT_NAME
		Attachment.Parent = Root
		State.OrientationAttachment = Attachment
	end
	local Constraint: AlignOrientation? = State.OrientationConstraint
	local Responsiveness: number = if State.Started then ORIENTATION_RESPONSIVENESS_DASH else ORIENTATION_RESPONSIVENESS_PRE
	local RigidityEnabled: boolean = if State.Started then ORIENTATION_RIGIDITY_DASH else ORIENTATION_RIGIDITY_PRE
	if not Constraint or Constraint.Parent ~= Root then
		if Constraint then
			Constraint:Destroy()
		end
		Constraint = Instance.new("AlignOrientation")
		Constraint.Name = ORIENTATION_CONSTRAINT_NAME
		Constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
		Constraint.Attachment0 = Attachment
		Constraint.MaxTorque = ORIENTATION_MAX_TORQUE
		Constraint.Responsiveness = Responsiveness
		Constraint.RigidityEnabled = RigidityEnabled
		Constraint.CFrame = DirectionToCFrame(LockedDirection)
		Constraint.Parent = Root
		State.OrientationConstraint = Constraint
		if DEBUG_ENABLED then
			print("PhantomDash: OrientationLock created", Player.Name, "Locked", LockedDirection)
		end
	else
		Constraint.Responsiveness = Responsiveness
		Constraint.RigidityEnabled = RigidityEnabled
		Constraint.CFrame = DirectionToCFrame(LockedDirection)
	end
end

local function EnsureAlignPosition(Player: Player, Root: BasePart, State: DashState): AlignPosition
	local AlignInstance: AlignPosition? = State.AlignPosition
	if AlignInstance and AlignInstance.Parent == Root then
		return AlignInstance
	end
	if AlignInstance then
		AlignInstance:Destroy()
	end

	local Attachment: Attachment? = Root:FindFirstChild(ROOT_ATTACHMENT_NAME) :: Attachment?
	local Owned: boolean = false
	if not Attachment or not Attachment:IsA("Attachment") then
		Attachment = Instance.new("Attachment")
		Attachment.Name = ALIGN_ATTACHMENT_NAME
		Attachment.Parent = Root
		Owned = true
	end

	AlignInstance = Instance.new("AlignPosition")
	AlignInstance.Name = ALIGN_POSITION_NAME
	AlignInstance.Mode = Enum.PositionAlignmentMode.OneAttachment
	AlignInstance.Attachment0 = Attachment
	AlignInstance.RigidityEnabled = WALK_RIGIDITY_ENABLED
	AlignInstance.MaxForce = WALK_MAX_FORCE
	AlignInstance.Responsiveness = WALK_RESPONSIVENESS
	AlignInstance.Position = Root.Position
	AlignInstance.Parent = Root

	State.AlignPosition = AlignInstance
	State.AlignAttachment = Attachment
	State.AlignAttachmentOwned = Owned

	if DEBUG_ENABLED then
		print("PhantomDash: AlignPosition created", Player.Name)
	end

	return AlignInstance
end

local function StopMoveTween(State: DashState): ()
	if State.MoveTween then
		State.MoveTween:Cancel()
		State.MoveTween:Destroy()
		State.MoveTween = nil
	end
end

local BeginEndSlowdown: (Player, DashState, number) -> ()

local function StartDashMove(Player: Player, State: DashState, Token: number): ()
	State.MoveToken += ONE
	local MoveToken: number = State.MoveToken
	local DashCharacter: Model? = Player.Character
	if not DashCharacter then
		return
	end
	local DashDistanceMultiplier: number =
		if IsAwakenActive(Player, DashCharacter) then AWAKEN_DASH_DISTANCE_MULTIPLIER else NORMAL_DASH_DISTANCE_MULTIPLIER
	local CollisionParams: RaycastParams = CreateDashCollisionParams(DashCharacter)
	task.spawn(function()
		local LastTime: number = os.clock()
		while true do
			if not State.Active then
				return
			end
			if State.Token ~= Token then
				return
			end
			if State.MoveToken ~= MoveToken then
				return
			end
			if not State.Started or State.EndQueued or State.Ended then
				return
			end
			local CurrentCharacter: Model? = Player.Character
			if not CurrentCharacter then
				return
			end
			if CurrentCharacter ~= DashCharacter then
				return
			end
			if IsScoringPauseLocked(Player, CurrentCharacter) then
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

			local LockedDirection: Vector3 = GetLockedDirection(Root, State)
			Root.AssemblyAngularVelocity = ZERO_VECTOR
			EnsureOrientationLock(Player, Root, State)

			local AlignInstance: AlignPosition = EnsureAlignPosition(Player, Root, State)
			AlignInstance.MaxForce = DASH_MAX_FORCE
			AlignInstance.Responsiveness = DASH_RESPONSIVENESS
			AlignInstance.RigidityEnabled = DASH_RIGIDITY_ENABLED

			local StepDistance: number = DASH_SPEED * DeltaTime * DashDistanceMultiplier
			local TargetPosition: Vector3, HitWall: boolean =
				ResolveDashCollision(CurrentCharacter, Root, LockedDirection, StepDistance, CollisionParams)
			AlignInstance.Position = TargetPosition
			if HitWall then
				Root.AssemblyLinearVelocity = ZERO_VECTOR
				BeginEndSlowdown(Player, State, Token)
				return
			end
			Root.AssemblyLinearVelocity = LockedDirection * DASH_SPEED

			RunService.Heartbeat:Wait()
		end
	end)
end

BeginEndSlowdown = function(Player: Player, State: DashState, Token: number): ()
	if State.EndQueued then
		return
	end
	State.EndQueued = true
	State.MoveToken += ONE
	StopMoveTween(State)
	local Character: Model? = Player.Character
	if not Character then
		ClearDash(Player, State)
		return
	end
	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		ClearDash(Player, State)
		return
	end
	local AlignInstance: AlignPosition = EnsureAlignPosition(Player, Root, State)
	AlignInstance.MaxForce = END_MAX_FORCE
	AlignInstance.Responsiveness = END_RESPONSIVENESS
	AlignInstance.RigidityEnabled = END_RIGIDITY_ENABLED
	AlignInstance.Position = Root.Position
	Root.AssemblyAngularVelocity = ZERO_VECTOR
	EnsureOrientationLock(Player, Root, State)
	task.delay(END_SLOW_DURATION, function()
		if State.Token ~= Token then
			return
		end
		if State.Ended then
			return
		end
		ClearDash(Player, State)
	end)
end

local function HandleMarker(Player: Player, Token: number, MarkerName: string): ()
	local State: DashState? = DashStates[Player]
	if not State then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleMarker missing state", Player.Name, MarkerName)
		end
		return
	end
	if not State.Active then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleMarker inactive", Player.Name, MarkerName)
		end
		return
	end
	if State.Token ~= Token then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleMarker token mismatch", Player.Name, Token, State.Token)
		end
		return
	end
	if MarkerName == MARKER_POINT1 then
		if State.Started then
			if DEBUG_ENABLED then
				print("PhantomDash: HandleMarker point1 already started", Player.Name)
			end
			return
		end
		local Character: Model? = Player.Character
		if not Character then
			if DEBUG_ENABLED then
				print("PhantomDash: HandleMarker point1 missing character", Player.Name)
			end
			return
		end
		local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not Root then
			if DEBUG_ENABLED then
				print("PhantomDash: HandleMarker point1 missing root", Player.Name)
			end
			return
		end
		if DEBUG_ENABLED then
			print("PhantomDash: HandleMarker point1", Player.Name)
		end
		State.Started = true
		State.Ended = false
		StartDashMove(Player, State, Token)
		return
	end
	if MarkerName == MARKER_POINT2 then
		if State.Ended or State.EndQueued then
			if DEBUG_ENABLED then
				print("PhantomDash: HandleMarker point2 already ended", Player.Name)
			end
			return
		end
		if DEBUG_ENABLED then
			print("PhantomDash: HandleMarker point2", Player.Name)
		end
		BeginEndSlowdown(Player, State, Token)
	end
end

local function HandleDirection(Player: Player, Token: number, Direction: Vector3): ()
	local State: DashState? = DashStates[Player]
	if not State then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection missing state", Player.Name)
		end
		return
	end
	if not State.Active then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection inactive", Player.Name)
		end
		return
	end
	if State.Token ~= Token then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection token mismatch", Player.Name, Token, State.Token)
		end
		return
	end
	if State.Ended then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection ended", Player.Name)
		end
		return
	end
	if State.EndQueued then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection end queued", Player.Name)
		end
		return
	end
	local Character: Model? = Player.Character
	if not Character then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection missing character", Player.Name)
		end
		return
	end
	if State.Started then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection ignored (started)", Player.Name)
		end
		return
	end
	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		if DEBUG_ENABLED then
			print("PhantomDash: HandleDirection missing root", Player.Name)
		end
		return
	end
	local ForwardDirection: Vector3 = ResolveDirection(Root, Root.CFrame.LookVector)
	local InputDirection: Vector3 = ResolveDirection(Root, Direction)
	local UpdatedDirection: Vector3 = InputDirection
	local PreviousDirection: Vector3 = State.LastDirection
	local SmoothedDirection: Vector3 = UpdatedDirection
	if PreviousDirection.Magnitude >= MIN_DIRECTION_MAGNITUDE then
		local LerpValue: Vector3 = PreviousDirection:Lerp(UpdatedDirection, LOCK_LERP_ALPHA)
		if LerpValue.Magnitude >= MIN_DIRECTION_MAGNITUDE then
			SmoothedDirection = LerpValue.Unit
		end
	end
	State.LastDirection = SmoothedDirection
	EnsureOrientationLock(Player, Root, State)
	if DEBUG_ENABLED then
		print("PhantomDash: LockDirection update", Player.Name, "Locked", State.LastDirection)
	end
	if DEBUG_ENABLED then
		local LockedDirection: Vector3 = State.LastDirection
		local DirectionDot: number = ForwardDirection:Dot(LockedDirection)
		if DirectionDot < DIRECTION_DOT_WARNING then
			print("PhantomDash: HandleDirection pre-point1 drift", Player.Name, "Forward", ForwardDirection, "Locked", LockedDirection, "Input", InputDirection, "Dot", DirectionDot)
		else
			print("PhantomDash: HandleDirection pre-point1", Player.Name, "Forward", ForwardDirection, "Locked", LockedDirection, "Input", InputDirection, "Dot", DirectionDot)
		end
	end
end

local function HandlePlayerAdded(Player: Player): ()
	Player.CharacterRemoving:Connect(function(Character: Model)
		local State: DashState? = DashStates[Player]
		if not State then
			return
		end
		if State.Character ~= Character then
			return
		end
		ClearDash(Player, State)
	end)
end

local function HandlePlayerRemoving(Player: Player): ()
	local State: DashState? = DashStates[Player]
	if not State then
		return
	end
	ClearDash(Player, State)
	DashStates[Player] = nil
end

Packets.SkillMarker.OnServerEvent:Connect(function(Player: Player, SkillType: string, Token: number, MarkerName: string)
	if typeof(SkillType) ~= "string" or SkillType ~= SKILL_TYPE_NAME then
		return
	end
	if typeof(Token) ~= "number" then
		return
	end
	if typeof(MarkerName) ~= "string" then
		return
	end
	HandleMarker(Player, Token, MarkerName)
end)

Packets.SkillDirection.OnServerEvent:Connect(function(Player: Player, SkillType: string, Token: number, Direction: Vector3)
	if typeof(SkillType) ~= "string" or SkillType ~= SKILL_TYPE_NAME then
		return
	end
	if typeof(Token) ~= "number" then
		return
	end
	if typeof(Direction) ~= "Vector3" then
		return
	end
	HandleDirection(Player, Token, Direction)
end)

Players.PlayerAdded:Connect(HandlePlayerAdded)
Players.PlayerRemoving:Connect(HandlePlayerRemoving)
for _, PlayerItem in Players:GetPlayers() do
	HandlePlayerAdded(PlayerItem)
end

return function(Character: Model): ()
	local Player: Player? = Players:GetPlayerFromCharacter(Character)
	if not Player then
		if DEBUG_ENABLED then
			print("PhantomDash: Skill start missing player")
		end
		return
	end
	local State: DashState = GetDashState(Player)
	ClearDash(Player, State)
	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance then
		State.AutoRotateHumanoid = HumanoidInstance
		State.OriginalAutoRotate = HumanoidInstance.AutoRotate
		HumanoidInstance.AutoRotate = false
	end
	State.Token = NextToken(State.Token)
	State.Active = true
	State.Started = false
	State.Ended = false
	State.Character = Character
	State.FailsafeToken += ONE
	GlobalFunctions.SetSkillLock(Player, Character, true)
	local FailsafeToken: number = State.FailsafeToken
	local Token: number = State.Token

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		if DEBUG_ENABLED then
			print("PhantomDash: Skill start", Player.Name)
		end
		CaptureNetworkOwner(Root, State)
		State.LastDirection = ResolveActivationDirection(Root)
		if DEBUG_ENABLED then
			print("PhantomDash: LockDirection", Player.Name, "Locked", State.LastDirection)
		end
		SetInvulnerable(Player, Character, true)
		State.Started = true
		StartDashMove(Player, State, Token)
	end

	FireReplicator(Player, "Start", Token)

	task.delay(DASH_FAILSAFE_TIME, function()
		if State.Token ~= Token then
			return
		end
		if State.FailsafeToken ~= FailsafeToken then
			return
		end
		if not State.Active then
			return
		end
		ClearDash(Player, State)
	end)
end
