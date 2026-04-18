--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)

type LaserState = {
	Active: boolean,
	AutoRotateHumanoid: Humanoid?,
	AutoSequenceToken: number,
	Character: Model?,
	Ended: boolean,
	ExpectedSegment: number,
	ActiveSegment: number,
	FailsafeToken: number,
	Forward: Vector3,
	MoveTween: Tween?,
	NetworkOwnerRoot: BasePart?,
	OriginalAutoRotate: boolean?,
	OriginalNetworkOwner: Player?,
	Origin: Vector3,
	Right: Vector3,
	Token: number,
}

--// CONSTANTS
local ZERO: number = 0
local ONE: number = 1
local TWO: number = 2
local THREE: number = 3
local FOUR: number = 4
local HALF: number = 0.5
local NEGATIVE_ONE: number = -ONE

local TOKEN_MAX: number = 65535

local MIN_DIRECTION_MAGNITUDE: number = 0.01
local FALLBACK_FORWARD: Vector3 = Vector3.new(ONE, ZERO, ZERO)
local UP_VECTOR: Vector3 = Vector3.new(ZERO, ONE, ZERO)
local VECTOR3_ZERO: Vector3 = Vector3.new(ZERO, ZERO, ZERO)

local DEBUG_ENABLED: boolean = false

local SEGMENT_TIME: number = 0.2
local SEGMENT_FORWARD_DISTANCE: number = 16
local SEGMENT_SIDE_DISTANCE: number = 8
local SEGMENT_EASING_STYLE: Enum.EasingStyle = Enum.EasingStyle.Quad
local SEGMENT_EASING_DIRECTION: Enum.EasingDirection = Enum.EasingDirection.InOut
local SEGMENT_GAP_TIME: number = 0.04
local AUTO_SEQUENCE_START_DELAY: number = 0.05
local SEGMENT_SNAP_DISTANCE: number = 1.5
local SEGMENT_RETURN_DELAY: number = 0.08

local SEGMENT_ONE_INDEX: number = ONE
local SEGMENT_TWO_INDEX: number = TWO
local SEGMENT_THREE_INDEX: number = THREE
local SEGMENT_FOUR_INDEX: number = FOUR
local SEGMENT_MAX_INDEX: number = SEGMENT_FOUR_INDEX
local SEGMENT_RETURN_FORWARD_INDEX: number = SEGMENT_THREE_INDEX

local SIDE_LEFT: number = NEGATIVE_ONE
local SIDE_RIGHT: number = ONE
local SIDE_CENTER: number = ZERO
local SIDE_RETURN_BIAS_RIGHT: number = HALF

local SEGMENT_FORWARD_MULTIPLIERS: {number} = {
	SEGMENT_ONE_INDEX,
	SEGMENT_TWO_INDEX,
	SEGMENT_THREE_INDEX,
	SEGMENT_RETURN_FORWARD_INDEX,
}

local SEGMENT_SIDE_MULTIPLIERS: {number} = {
	SIDE_LEFT,
	SIDE_RIGHT,
	SIDE_LEFT,
	SIDE_RETURN_BIAS_RIGHT,
}

local DEVIL_FAILSAFE_TIME: number = 5

local ATTR_INVULNERABLE: string = "Invulnerable"

local MARKER_POINT1: string = "point1"
local MARKER_POINT2: string = "point2"
local MARKER_POINT3: string = "point3"
local MARKER_POINT4: string = "point4"
local MARKER_POINT5: string = "point5"
local MARKER_POINT6: string = "point6"
local MARKER_POINT7: string = "point7"
local SKILL_TYPE_NAME: string = "DevilLaser"

local LaserStates: {[Player]: LaserState} = {}

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
			warn(string.format("DevilLaser: Replicator fire failed: %s", tostring(ErrorMessage)))
		end
	end
end

local function DebugPrint(Message: string, Player: Player?): ()
	if not DEBUG_ENABLED then
		return
	end
	if Player then
		print(string.format("[DevilLaser] %s (%s)", Message, Player.Name))
		return
	end
	print(string.format("[DevilLaser] %s", Message))
end

local function GetState(Player: Player): LaserState
	local Existing: LaserState? = LaserStates[Player]
	if Existing then
		return Existing
	end
	local NewState: LaserState = {
		Active = false,
		AutoRotateHumanoid = nil,
		AutoSequenceToken = ZERO,
		Character = nil,
		Ended = false,
		ExpectedSegment = SEGMENT_ONE_INDEX,
		ActiveSegment = ZERO,
		FailsafeToken = ZERO,
		Forward = FALLBACK_FORWARD,
		MoveTween = nil,
		NetworkOwnerRoot = nil,
		OriginalAutoRotate = nil,
		OriginalNetworkOwner = nil,
		Origin = Vector3.new(ZERO, ZERO, ZERO),
		Right = Vector3.new(ZERO, ZERO, ONE),
		Token = ZERO,
	}
	LaserStates[Player] = NewState
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

local function RestoreNetworkOwner(State: LaserState): ()
	local Root: BasePart? = State.NetworkOwnerRoot
	if not Root or not Root.Parent then
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

local function CaptureNetworkOwner(Root: BasePart, State: LaserState): ()
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

local function ClearMoveTween(State: LaserState): ()
	if State.MoveTween then
		State.MoveTween:Cancel()
		State.MoveTween:Destroy()
		State.MoveTween = nil
	end
end

local function FlattenDirection(Direction: Vector3): Vector3
	return Vector3.new(Direction.X, ZERO, Direction.Z)
end

local function ResolveForward(Root: BasePart): Vector3
	local Flat: Vector3 = FlattenDirection(Root.CFrame.LookVector)
	if Flat.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return FALLBACK_FORWARD
	end
	return Flat.Unit
end

local function ResolveRight(Forward: Vector3): Vector3
	local Right: Vector3 = Forward:Cross(UP_VECTOR)
	if Right.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return Vector3.new(ZERO, ZERO, ONE)
	end
	return Right.Unit
end

local function ResetRootVelocity(Root: BasePart): ()
	Root.AssemblyLinearVelocity = VECTOR3_ZERO
	Root.AssemblyAngularVelocity = VECTOR3_ZERO
end

local function GetSegmentTarget(State: LaserState, SegmentIndex: number): Vector3
	if SegmentIndex < SEGMENT_ONE_INDEX or SegmentIndex > SEGMENT_MAX_INDEX then
		return State.Origin
	end
	local ForwardMultiplier: number = SEGMENT_FORWARD_MULTIPLIERS[SegmentIndex] or ONE
	local SideMultiplier: number = SEGMENT_SIDE_MULTIPLIERS[SegmentIndex] or ZERO
	local ForwardOffset: Vector3 = State.Forward * (SEGMENT_FORWARD_DISTANCE * ForwardMultiplier)
	local SideOffset: Vector3 = State.Right * (SEGMENT_SIDE_DISTANCE * SideMultiplier)
	return State.Origin + ForwardOffset + SideOffset
end

local function GetSegmentTargetCFrame(State: LaserState, SegmentIndex: number): CFrame
	local Target: Vector3 = GetSegmentTarget(State, SegmentIndex)
	return CFrame.lookAt(Target, Target + State.Forward, UP_VECTOR)
end

local function StartSegment(Player: Player, Root: BasePart, State: LaserState, SegmentIndex: number): ()
	if SegmentIndex ~= State.ExpectedSegment then
		DebugPrint(string.format("StartSegment ignored idx=%d expected=%d", SegmentIndex, State.ExpectedSegment), Player)
		return
	end
	if State.ActiveSegment ~= ZERO then
		DebugPrint(string.format("StartSegment ignored idx=%d active=%d", SegmentIndex, State.ActiveSegment), Player)
		return
	end
	State.ActiveSegment = SegmentIndex
	ClearMoveTween(State)
	ResetRootVelocity(Root)
	local TargetCFrame: CFrame = GetSegmentTargetCFrame(State, SegmentIndex)
	local TargetPosition: Vector3 = TargetCFrame.Position
	DebugPrint(string.format("StartSegment idx=%d target=(%.2f, %.2f, %.2f)", SegmentIndex, TargetPosition.X, TargetPosition.Y, TargetPosition.Z), Player)
	local MoveTween: Tween = TweenService:Create(Root, TweenInfo.new(SEGMENT_TIME, SEGMENT_EASING_STYLE, SEGMENT_EASING_DIRECTION), {
		CFrame = TargetCFrame,
	})
	State.MoveTween = MoveTween
	MoveTween.Completed:Connect(function(PlaybackState: Enum.PlaybackState)
		if State.ActiveSegment ~= SegmentIndex then
			return
		end
		DebugPrint(string.format("Segment tween complete idx=%d state=%s", SegmentIndex, tostring(PlaybackState)), Player)
	end)
	MoveTween:Play()
end

local function CompleteSegment(Player: Player, Root: BasePart, State: LaserState, SegmentIndex: number): ()
	if State.ActiveSegment ~= SegmentIndex then
		DebugPrint(string.format("CompleteSegment ignored idx=%d active=%d", SegmentIndex, State.ActiveSegment), Player)
		return
	end
	ClearMoveTween(State)
	local TargetCFrame: CFrame = GetSegmentTargetCFrame(State, SegmentIndex)
	local Distance: number = (Root.Position - TargetCFrame.Position).Magnitude
	if Distance > SEGMENT_SNAP_DISTANCE then
		DebugPrint(string.format("CompleteSegment snap idx=%d dist=%.2f", SegmentIndex, Distance), Player)
		Root:PivotTo(TargetCFrame)
	end
	ResetRootVelocity(Root)
	State.ActiveSegment = ZERO
	State.ExpectedSegment = SegmentIndex + ONE
end

local function EndLaser(Player: Player, State: LaserState): ()
	if State.Ended then
		return
	end
	State.Ended = true
	State.Active = false
	ClearMoveTween(State)
	RestoreNetworkOwner(State)
	DebugPrint("EndLaser", Player)
	if State.AutoRotateHumanoid then
		State.AutoRotateHumanoid.AutoRotate = State.OriginalAutoRotate == true
		State.AutoRotateHumanoid = nil
		State.OriginalAutoRotate = nil
	end
	SetInvulnerable(Player, State.Character, false)
	GlobalFunctions.SetSkillLock(Player, State.Character, false)
	FireReplicator(Player, "End", State.Token)
	State.Character = nil
end

local function HandleMarker(Player: Player, Token: number, MarkerName: string): ()
	local State: LaserState? = LaserStates[Player]
	if not State or not State.Active or State.Token ~= Token then
		DebugPrint(string.format("HandleMarker ignored marker=%s token=%d", MarkerName, Token), Player)
		return
	end
	if State.Ended then
		DebugPrint(string.format("HandleMarker after end marker=%s", MarkerName), Player)
		return
	end
	local Character: Model? = Player.Character
	if not Character then
		EndLaser(Player, State)
		return
	end
	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		DebugPrint("HandleMarker missing root", Player)
		EndLaser(Player, State)
		return
	end

	DebugPrint(string.format("HandleMarker marker=%s expected=%d active=%d", MarkerName, State.ExpectedSegment, State.ActiveSegment), Player)

	if MarkerName == MARKER_POINT1 then
		StartSegment(Player, Root, State, SEGMENT_ONE_INDEX)
		return
	end
	if MarkerName == MARKER_POINT2 then
		CompleteSegment(Player, Root, State, SEGMENT_ONE_INDEX)
		return
	end
	if MarkerName == MARKER_POINT3 then
		StartSegment(Player, Root, State, SEGMENT_TWO_INDEX)
		return
	end
	if MarkerName == MARKER_POINT4 then
		CompleteSegment(Player, Root, State, SEGMENT_TWO_INDEX)
		return
	end
	if MarkerName == MARKER_POINT5 then
		StartSegment(Player, Root, State, SEGMENT_THREE_INDEX)
		return
	end
	if MarkerName == MARKER_POINT6 then
		CompleteSegment(Player, Root, State, SEGMENT_THREE_INDEX)
		local Token: number = State.Token
		task.delay(SEGMENT_RETURN_DELAY, function()
			if not State.Active then
				return
			end
			if State.Token ~= Token then
				return
			end
			StartSegment(Player, Root, State, SEGMENT_FOUR_INDEX)
		end)
		return
	end
	if MarkerName == MARKER_POINT7 then
		CompleteSegment(Player, Root, State, SEGMENT_FOUR_INDEX)
		EndLaser(Player, State)
	end
end

local function RunAutoSequence(Player: Player, Root: BasePart, State: LaserState, Token: number, SequenceToken: number): ()
	task.spawn(function()
		task.wait(AUTO_SEQUENCE_START_DELAY)
		if not State.Active or State.Token ~= Token or State.AutoSequenceToken ~= SequenceToken then
			return
		end
		DebugPrint("AutoSequence start", Player)

		StartSegment(Player, Root, State, SEGMENT_ONE_INDEX)
		task.wait(SEGMENT_TIME + SEGMENT_GAP_TIME)
		if State.Active and State.Token == Token and State.AutoSequenceToken == SequenceToken then
			CompleteSegment(Player, Root, State, SEGMENT_ONE_INDEX)
		end

		StartSegment(Player, Root, State, SEGMENT_TWO_INDEX)
		task.wait(SEGMENT_TIME + SEGMENT_GAP_TIME)
		if State.Active and State.Token == Token and State.AutoSequenceToken == SequenceToken then
			CompleteSegment(Player, Root, State, SEGMENT_TWO_INDEX)
		end

		StartSegment(Player, Root, State, SEGMENT_THREE_INDEX)
		task.wait(SEGMENT_TIME + SEGMENT_GAP_TIME)
		if State.Active and State.Token == Token and State.AutoSequenceToken == SequenceToken then
			CompleteSegment(Player, Root, State, SEGMENT_THREE_INDEX)
		end

		task.wait(SEGMENT_RETURN_DELAY)
		StartSegment(Player, Root, State, SEGMENT_FOUR_INDEX)
		task.wait(SEGMENT_TIME + SEGMENT_GAP_TIME)
		if State.Active and State.Token == Token and State.AutoSequenceToken == SequenceToken then
			CompleteSegment(Player, Root, State, SEGMENT_FOUR_INDEX)
			EndLaser(Player, State)
		end
	end)
end

local function HandlePlayerAdded(Player: Player): ()
	Player.CharacterRemoving:Connect(function(Character: Model)
		local State: LaserState? = LaserStates[Player]
		if not State or State.Character ~= Character then
			return
		end
		EndLaser(Player, State)
	end)
end

local function HandlePlayerRemoving(Player: Player): ()
	local State: LaserState? = LaserStates[Player]
	if not State then
		return
	end
	EndLaser(Player, State)
	LaserStates[Player] = nil
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

Players.PlayerAdded:Connect(HandlePlayerAdded)
Players.PlayerRemoving:Connect(HandlePlayerRemoving)
for _, PlayerItem in Players:GetPlayers() do
	HandlePlayerAdded(PlayerItem)
end

return function(Character: Model): ()
	local Player: Player? = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end
	local State: LaserState = GetState(Player)
	EndLaser(Player, State)
	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance then
		State.AutoRotateHumanoid = HumanoidInstance
		State.OriginalAutoRotate = HumanoidInstance.AutoRotate
		HumanoidInstance.AutoRotate = false
	end
	State.Token = NextToken(State.Token)
	State.Active = true
	State.Ended = false
	State.ExpectedSegment = SEGMENT_ONE_INDEX
	State.ActiveSegment = ZERO
	State.Character = Character
	State.FailsafeToken += ONE
	State.AutoSequenceToken += ONE
	GlobalFunctions.SetSkillLock(Player, Character, true)
	local FailsafeToken: number = State.FailsafeToken
	local Token: number = State.Token
	local SequenceToken: number = State.AutoSequenceToken

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		CaptureNetworkOwner(Root, State)
		State.Origin = Root.Position
		State.Forward = ResolveForward(Root)
		State.Right = ResolveRight(State.Forward)
		SetInvulnerable(Player, Character, true)
		ResetRootVelocity(Root)
		Root:PivotTo(CFrame.lookAt(State.Origin, State.Origin + State.Forward, UP_VECTOR))
		DebugPrint(string.format("Skill start token=%d origin=(%.2f, %.2f, %.2f)", Token, State.Origin.X, State.Origin.Y, State.Origin.Z), Player)
		DebugPrint(string.format("Forward=(%.2f, %.2f, %.2f) Right=(%.2f, %.2f, %.2f)", State.Forward.X, State.Forward.Y, State.Forward.Z, State.Right.X, State.Right.Y, State.Right.Z), Player)
		RunAutoSequence(Player, Root, State, Token, SequenceToken)
	else
		DebugPrint("Skill start missing root", Player)
	end

	FireReplicator(Player, "Start", Token)

	task.delay(DEVIL_FAILSAFE_TIME, function()
		if State.Token ~= Token then
			return
		end
		if State.FailsafeToken ~= FailsafeToken then
			return
		end
		if not State.Active then
			return
		end
		EndLaser(Player, State)
	end)
end
