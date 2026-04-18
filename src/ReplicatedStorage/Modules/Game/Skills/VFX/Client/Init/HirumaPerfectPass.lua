--!strict

local Lighting: Lighting = game:GetService("Lighting")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GameplayGuiVisibility: any = require(ReplicatedStorage.Modules.Game.GameplayGuiVisibility)
local CutsceneVisibility: any = require(ReplicatedStorage.Modules.Game.CutsceneVisibility)
local CutsceneRigUtils: any = require(script.Parent.CutsceneRigUtils)
local PerfectPassTimeline: any = require(script.Parent.Timelines.HirumaPerfectPassTimeline)
local CameraController: any = require(ReplicatedStorage.Controllers.CameraController)
local FOVController: any = require(ReplicatedStorage.Controllers.FOVController)

type PerfectPassAction = "Emit" | "Enable" | "Disable" | "SetProperty"
type PerfectPassEvent = {
	Frame: number,
	Action: PerfectPassAction,
	Path: string?,
	Property: string?,
	Value: any?,
	Amount: number?,
}

type AssetPack = {
	Container: Instance,
	LightingSource: Instance,
	PrincipalSource: Instance,
	VFXSource: Instance,
	SceneAssetsSource: Model?,
}

type RuntimeState = {
	Active: boolean,
	Token: number,
	Clones: {Instance},
	Connections: {RBXScriptConnection},
	Tracks: {AnimationTrack},
	WorkspaceRoots: {[string]: Instance},
	WorkspaceRootList: {Instance},
	LightingRoots: {[string]: Instance},
	LightingRootList: {Instance},
	PathCache: {[string]: Instance},
	EventBuckets: {[number]: {PerfectPassEvent}},
	EnableTargetCache: {[Instance]: {Instance}},
	EmitTargetCache: {[Instance]: {ParticleEmitter}},
	TimelineStartAt: number,
	NextFrame: number,
	CamPart: BasePart?,
	PrevCameraType: Enum.CameraType?,
	PrevCameraSubject: Instance?,
	PrevCameraCFrame: CFrame?,
	PrevCameraFov: number?,
	PrevMouseBehavior: Enum.MouseBehavior?,
	PrevMouseIconEnabled: boolean?,
	CameraBound: boolean,
	CameraReleased: boolean,
	CameraCompleted: boolean,
	HiddenCharacterState: any,
	HiddenGameplayArtifactState: any,
	HiddenGameplayArtifactRefreshAt: number,
	TimelineCompleted: boolean,
	RugbyBallCompleted: boolean,
	ServerToken: number?,
	ServerCompletionSent: boolean,
	SourceActorModel: Model?,
	LocalSourceRoot: BasePart?,
	LocalSourceHumanoid: Humanoid?,
	LocalSourceRootAnchoredBefore: boolean?,
	LocalSourceHumanoidAutoRotateBefore: boolean?,
	LocalSourceHumanoidWalkSpeedBefore: number?,
	LocalSourceHumanoidJumpPowerBefore: number?,
	LocalSourceHumanoidJumpHeightBefore: number?,
	LocalSourceHumanoidUseJumpPowerBefore: boolean?,
	LocalPlayerSkillLockedBefore: boolean?,
	LocalCharacterSkillLockedBefore: boolean?,
	SceneDelta: Vector3,
	SceneRotation: CFrame?,
	SceneAnchorPosition: Vector3?,
}

type CutscenePayload = {
	SourceUserId: number,
	AnchorPosition: Vector3,
	AnchorForward: Vector3,
	Duration: number,
	ServerToken: number,
	EnemyOneUserId: number?,
	EnemyTwoUserId: number?,
	ReceiverUserId: number?,
}

type ActorDefinition = {
	Name: string,
	AnimationId: string,
}

type ActorAppearancePlan = {
	SourcePlayer: Player?,
	FallbackModel: Model?,
	TeamNumber: number?,
}

local Controller = {}

local ZERO: number = 0
local ONE: number = 1
local TWO: number = 2
local NEGATIVE_ONE: number = -1
local EPSILON: number = 0.0001
local CAMERA_BIND_PRIORITY: number = Enum.RenderPriority.Camera.Value + ONE
local EFFECT_DISABLE_DELAY: number = 0.03
local TIMELINE_PADDING: number = 0.15
local COMPLETION_RECOVERY_PADDING: number = 0.25
local RUGBY_BALL_TIMEOUT_PADDING: number = 5
local RUGBY_BALL_END_EPSILON: number = 0.05
local GAMEPLAY_ARTIFACT_REFRESH_INTERVAL: number = 0.12
local DEFAULT_WALKSPEED: number = 16
local DEFAULT_JUMPPOWER: number = 50
local DEFAULT_JUMPHEIGHT: number = 7.2
local GROUND_RAY_HEIGHT: number = 24
local GROUND_RAY_DISTANCE: number = 80
local GROUND_CLEARANCE: number = 0.8
local GROUND_OFFSET_MIN: number = 0.25
local GROUND_SNAP_EPSILON: number = 0.05
local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local ATTR_CUTSCENE_HUD_HIDDEN: string = "FTCutsceneHudHidden"
local FOV_REQUEST_ID: string = "HirumaPerfectPass::FOV"

local ASSETS_FOLDER_NAME: string = "Assets"
local CHARS_FOLDER_NAME: string = "Chars"
local SKILLS_FOLDER_NAME: string = "Skills"
local HIRUMA_FOLDER_NAME: string = "Hiruma"
local PERFECT_PASS_FOLDER_NAME: string = "PerfectPass"
local LIGHTING_FOLDER_NAME: string = "Lighting"
local PRINCIPAL_FOLDER_NAME: string = "Principal"
local VFX_FOLDER_NAME: string = "VFX"
local CAM_TEMPLATE_NAME: string = "Cam"
local RUGBY_BALL_TEMPLATE_NAME: string = "Rugby Ball"
local CAM_PART_NAME: string = "CamPart"

local PLAYER_ANIMATION_ID_1: string = "rbxassetid://99559528594805"
local PLAYER_ANIMATION_ID_2: string = "rbxassetid://81058310126191"
local PLAYER_ANIMATION_ID_5: string = "rbxassetid://138287143446844"
local PLAYER_ANIMATION_ID_7: string = "rbxassetid://89930416397899"
local PLAYER_ANIMATION_ID_10: string = "rbxassetid://90370067949767"
local CAM_ANIMATION_ID: string = "rbxassetid://89180310576323"
local RUGBY_BALL_ANIMATION_ID: string = "rbxassetid://110392321133932"
local LocalPlayer: Player = Players.LocalPlayer

local REFERENCE_ANCHOR_POSITION: Vector3 = Vector3.new(-46.046, 714.268, 5.49)
local SCENE_ASSETS_OFFSET_FROM_PLAYER: Vector3 = Vector3.new(-7.806, 9.093, -0.104)
local DEFAULT_CUTSCENE_DURATION: number = 516 / 60
local CAMERA_BIND_NAME: string = "HirumaPerfectPassCamera"
local SHIFTLOCK_BLOCKER_NAME: string = "HirumaPerfectPass"
local SOURCE_ACTOR_TEMPLATE_NAME: string = "Player 7"
local END_MARKER_NAME: string = "End"
local FALLBACK_FORWARD: Vector3 = Vector3.new(0, 0, -1)
local ROOT_ALIGNMENT_PART_NAMES: {string} = {
	"Torso",
	"UpperTorso",
	"HumanoidRootPart",
}

local ACTOR_DEFINITIONS: {ActorDefinition} = {
	{
		Name = "Player 1",
		AnimationId = PLAYER_ANIMATION_ID_1,
	},
	{
		Name = "Player 2",
		AnimationId = PLAYER_ANIMATION_ID_2,
	},
	{
		Name = "Player 5",
		AnimationId = PLAYER_ANIMATION_ID_5,
	},
	{
		Name = "Player 7",
		AnimationId = PLAYER_ANIMATION_ID_7,
	},
	{
		Name = "Player 10",
		AnimationId = PLAYER_ANIMATION_ID_10,
	},
}

local function IsPrincipalTemplateName(Name: string): boolean
	if Name == CAM_TEMPLATE_NAME or Name == RUGBY_BALL_TEMPLATE_NAME then
		return true
	end

	for _, ActorDefinition in ACTOR_DEFINITIONS do
		if ActorDefinition.Name == Name then
			return true
		end
	end

	return false
end

local State: RuntimeState = {
	Active = false,
	Token = 0,
	Clones = {},
	Connections = {},
	Tracks = {},
	WorkspaceRoots = {},
	WorkspaceRootList = {},
	LightingRoots = {},
	LightingRootList = {},
	PathCache = {},
	EventBuckets = {},
	EnableTargetCache = {},
	EmitTargetCache = {},
	TimelineStartAt = ZERO,
	NextFrame = ZERO,
	CamPart = nil,
	PrevCameraType = nil,
	PrevCameraSubject = nil,
	PrevCameraCFrame = nil,
	PrevCameraFov = nil,
	PrevMouseBehavior = nil,
	PrevMouseIconEnabled = nil,
	CameraBound = false,
	CameraReleased = false,
	CameraCompleted = true,
	HiddenCharacterState = nil,
	HiddenGameplayArtifactState = nil,
	HiddenGameplayArtifactRefreshAt = ZERO,
	TimelineCompleted = false,
	RugbyBallCompleted = true,
	ServerToken = nil,
	ServerCompletionSent = false,
	SourceActorModel = nil,
	LocalSourceRoot = nil,
	LocalSourceHumanoid = nil,
	LocalSourceRootAnchoredBefore = nil,
	LocalSourceHumanoidAutoRotateBefore = nil,
	LocalSourceHumanoidWalkSpeedBefore = nil,
	LocalSourceHumanoidJumpPowerBefore = nil,
	LocalSourceHumanoidJumpHeightBefore = nil,
	LocalSourceHumanoidUseJumpPowerBefore = nil,
	LocalPlayerSkillLockedBefore = nil,
	LocalCharacterSkillLockedBefore = nil,
	SceneDelta = Vector3.zero,
	SceneRotation = nil,
	SceneAnchorPosition = nil,
}

local CachedEventBuckets: {[number]: {PerfectPassEvent}}? = nil
local CachedTimelineMaxFrame: number = ZERO
local CachedAssetPack: AssetPack? = nil
local CachedFallbackModels: {Model}? = nil

local Cleanup: () -> ()
local TryCompleteCutscene: (number) -> ()
local ForceCompleteCutscene: (number) -> ()
local ReleaseCameraLock: () -> ()
local GetCameraBindName: () -> string
local ApplyCutsceneFov: (Value: number, TweenInfoOverride: TweenInfo?) -> ()
local ClearCutsceneFov: () -> ()
local ResolveFinalSourceCFrame: () -> CFrame?
local ApplyFinalLocalSourcePosition: () -> ()

ApplyCutsceneFov = function(Value: number, TweenInfoOverride: TweenInfo?): ()
	FOVController.AddRequest(FOV_REQUEST_ID, Value, nil, {
		TweenInfo = TweenInfoOverride or TweenInfo.new(0),
	})
end

ClearCutsceneFov = function(): ()
	FOVController.RemoveRequest(FOV_REQUEST_ID)
end

local function IsTokenActive(Token: number): boolean
	return State.Active and State.Token == Token
end

local function NotifyServerCutsceneEnded(ServerToken: number, FinalCFrame: any): ()
	if State.ServerCompletionSent then
		return
	end
	State.ServerCompletionSent = true
	if Packets and Packets.PerfectPassCutsceneEnded and Packets.PerfectPassCutsceneEnded.Fire then
		Packets.PerfectPassCutsceneEnded:Fire(ServerToken, FinalCFrame)
	end
end

local function SetLocalCutsceneHudHidden(Active: boolean): ()
	if not LocalPlayer then
		return
	end
	LocalPlayer:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, Active)
	local Character: Model? = LocalPlayer.Character
	if Character then
		Character:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, Active)
	end
	if Active then
		GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
	end
end

local function SetPerfectPassShiftlockBlocked(Blocked: boolean): ()
	if not CameraController then
		return
	end
	if CameraController.SetShiftlockBlocked then
		CameraController:SetShiftlockBlocked(SHIFTLOCK_BLOCKER_NAME, Blocked)
	end
end

local function RefreshShiftlockState(): ()
	if not CameraController then
		return
	end
	if CameraController.RefreshShiftlockState then
		CameraController:RefreshShiftlockState()
	end
end

local function GetCampo(): Instance?
	local GameFolder: Instance? = workspace:FindFirstChild("Game")
	if not GameFolder then
		return nil
	end
	return GameFolder:FindFirstChild("Campo")
end

local function GetGroundY(Position: Vector3): number?
	local Campo: Instance? = GetCampo()
	if not Campo then
		return nil
	end

	local Params: RaycastParams = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Campo }

	local Origin: Vector3 = Position + Vector3.new(0, GROUND_RAY_HEIGHT, 0)
	local Result: RaycastResult? = workspace:Raycast(Origin, Vector3.new(0, -GROUND_RAY_DISTANCE, 0), Params)
	return Result and Result.Position.Y or nil
end

local function GetCampoPlaneY(): number?
	local Campo: Instance? = GetCampo()
	if not Campo then
		return nil
	end
	if Campo:IsA("BasePart") then
		return Campo.Position.Y + (Campo.Size.Y * 0.5)
	end
	if Campo:IsA("Model") then
		local CampoCFrame: CFrame, CampoSize: Vector3 = Campo:GetBoundingBox()
		return CampoCFrame.Position.Y + (CampoSize.Y * 0.5)
	end
	return nil
end

local function ResolveRootGroundOffset(Root: BasePart, HumanoidInstance: Humanoid): number
	local BaseOffset: number = (Root.Size.Y * 0.5) + math.max(HumanoidInstance.HipHeight, ZERO)
	local GroundY: number? = GetGroundY(Root.Position)
	if GroundY ~= nil then
		local MeasuredOffset: number = Root.Position.Y - GroundY
		if MeasuredOffset > GROUND_OFFSET_MIN then
			return math.max(MeasuredOffset, BaseOffset)
		end
	end
	return BaseOffset
end

local function AlignRootAboveGround(Position: Vector3, RootOffset: number): Vector3
	local GroundY: number? = GetGroundY(Position)
	if GroundY ~= nil then
		return Vector3.new(Position.X, GroundY + RootOffset + GROUND_CLEARANCE, Position.Z)
	end

	local PlaneY: number? = GetCampoPlaneY()
	if PlaneY ~= nil then
		return Vector3.new(Position.X, PlaneY + RootOffset + GROUND_CLEARANCE, Position.Z)
	end

	return Position
end

local function LiftLocalSourceCharacterAboveGroundIfNeeded(): ()
	local Character: Model? = Players.LocalPlayer.Character
	if not Character then
		return
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		return
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return
	end

	local GroundedPosition: Vector3 = AlignRootAboveGround(
		Root.Position,
		ResolveRootGroundOffset(Root, HumanoidInstance)
	)
	local LiftAmount: number = GroundedPosition.Y - Root.Position.Y
	if LiftAmount <= GROUND_SNAP_EPSILON then
		return
	end

	Character:PivotTo(Character:GetPivot() + Vector3.new(0, LiftAmount, 0))
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	HumanoidInstance:ChangeState(Enum.HumanoidStateType.Running)
end

function TryCompleteCutscene(Token: number): ()
	if not IsTokenActive(Token) then
		return
	end
	if not State.TimelineCompleted or not State.CameraCompleted then
		return
	end
	ApplyFinalLocalSourcePosition()
	if State.ServerToken ~= nil then
		NotifyServerCutsceneEnded(State.ServerToken, ResolveFinalSourceCFrame())
	end
	Cleanup()
end

function ForceCompleteCutscene(Token: number): ()
	if not IsTokenActive(Token) then
		return
	end

	State.TimelineCompleted = true
	State.CameraCompleted = true
	State.RugbyBallCompleted = true
	ReleaseCameraLock()
	TryCompleteCutscene(Token)
end

ReleaseCameraLock = function(): ()
	if State.CameraReleased then
		return
	end
	State.CameraReleased = true

	if State.CameraBound then
		RunService:UnbindFromRenderStep(GetCameraBindName())
		State.CameraBound = false
	end

	local Camera: Camera? = workspace.CurrentCamera
	if Camera then
		if State.PrevCameraType then
			Camera.CameraType = State.PrevCameraType
		end
		if State.PrevCameraSubject then
			Camera.CameraSubject = State.PrevCameraSubject
		end
		if State.PrevCameraCFrame then
			Camera.CFrame = State.PrevCameraCFrame
		end
	end
	ClearCutsceneFov()

	if State.PrevMouseBehavior ~= nil then
		UserInputService.MouseBehavior = State.PrevMouseBehavior
	end
	if State.PrevMouseIconEnabled ~= nil then
		UserInputService.MouseIconEnabled = State.PrevMouseIconEnabled
	end

	State.PrevCameraType = nil
	State.PrevCameraSubject = nil
	State.PrevCameraCFrame = nil
	State.PrevCameraFov = nil
	State.PrevMouseBehavior = nil
	State.PrevMouseIconEnabled = nil
end

local function FreezeLocalSourceCharacter(SourceUserId: number): ()
	if Players.LocalPlayer.UserId ~= SourceUserId then
		return
	end

	local Character: Model? = Players.LocalPlayer.Character
	if not Character then
		return
	end

	State.LocalPlayerSkillLockedBefore = Players.LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true
	State.LocalCharacterSkillLockedBefore = Character:GetAttribute(ATTR_SKILL_LOCKED) == true
	Players.LocalPlayer:SetAttribute(ATTR_SKILL_LOCKED, true)
	Character:SetAttribute(ATTR_SKILL_LOCKED, true)

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		State.LocalSourceRoot = Root
		State.LocalSourceRootAnchoredBefore = Root.Anchored
		Root.Anchored = true
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return
	end

	State.LocalSourceHumanoid = HumanoidInstance
	State.LocalSourceHumanoidAutoRotateBefore = HumanoidInstance.AutoRotate
	State.LocalSourceHumanoidWalkSpeedBefore = HumanoidInstance.WalkSpeed
	State.LocalSourceHumanoidJumpPowerBefore = HumanoidInstance.JumpPower
	State.LocalSourceHumanoidJumpHeightBefore = HumanoidInstance.JumpHeight
	State.LocalSourceHumanoidUseJumpPowerBefore = HumanoidInstance.UseJumpPower
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

local function RestoreLocalSourceCharacter(): ()
	local Character: Model? = Players.LocalPlayer.Character
	if Character and State.LocalCharacterSkillLockedBefore ~= nil then
		Character:SetAttribute(ATTR_SKILL_LOCKED, State.LocalCharacterSkillLockedBefore == true)
	end
	if State.LocalPlayerSkillLockedBefore ~= nil then
		Players.LocalPlayer:SetAttribute(ATTR_SKILL_LOCKED, State.LocalPlayerSkillLockedBefore == true)
	end

	local Root: BasePart? = State.LocalSourceRoot
	if Root and Root.Parent ~= nil then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
		if State.LocalSourceRootAnchoredBefore ~= nil then
			Root.Anchored = State.LocalSourceRootAnchoredBefore
		else
			Root.Anchored = false
		end
	end

	local HumanoidInstance: Humanoid? = State.LocalSourceHumanoid
	if HumanoidInstance and HumanoidInstance.Parent ~= nil then
		HumanoidInstance.UseJumpPower = State.LocalSourceHumanoidUseJumpPowerBefore ~= false
		if State.LocalSourceHumanoidAutoRotateBefore ~= nil then
			HumanoidInstance.AutoRotate = State.LocalSourceHumanoidAutoRotateBefore
		else
			HumanoidInstance.AutoRotate = true
		end
		if State.LocalSourceHumanoidWalkSpeedBefore ~= nil and State.LocalSourceHumanoidWalkSpeedBefore > ZERO then
			HumanoidInstance.WalkSpeed = State.LocalSourceHumanoidWalkSpeedBefore
		elseif HumanoidInstance.WalkSpeed <= ZERO then
			HumanoidInstance.WalkSpeed = DEFAULT_WALKSPEED
		end
		if HumanoidInstance.UseJumpPower then
			if State.LocalSourceHumanoidJumpPowerBefore ~= nil and State.LocalSourceHumanoidJumpPowerBefore > ZERO then
				HumanoidInstance.JumpPower = State.LocalSourceHumanoidJumpPowerBefore
			else
				HumanoidInstance.JumpPower = DEFAULT_JUMPPOWER
			end
		else
			if State.LocalSourceHumanoidJumpHeightBefore ~= nil and State.LocalSourceHumanoidJumpHeightBefore > ZERO then
				HumanoidInstance.JumpHeight = State.LocalSourceHumanoidJumpHeightBefore
			elseif HumanoidInstance.JumpHeight <= ZERO then
				HumanoidInstance.JumpHeight = DEFAULT_JUMPHEIGHT
			end
		end
		HumanoidInstance.PlatformStand = false
		HumanoidInstance.Sit = false
	end

	LiftLocalSourceCharacterAboveGroundIfNeeded()

	State.LocalSourceRoot = nil
	State.LocalSourceHumanoid = nil
	State.LocalSourceRootAnchoredBefore = nil
	State.LocalSourceHumanoidAutoRotateBefore = nil
	State.LocalSourceHumanoidWalkSpeedBefore = nil
	State.LocalSourceHumanoidJumpPowerBefore = nil
	State.LocalSourceHumanoidJumpHeightBefore = nil
	State.LocalSourceHumanoidUseJumpPowerBefore = nil
	State.LocalPlayerSkillLockedBefore = nil
	State.LocalCharacterSkillLockedBefore = nil
	task.defer(RefreshShiftlockState)
end

local function TrackClone(Clone: Instance): ()
	table.insert(State.Clones, Clone)
end

local function TrackConnection(Connection: RBXScriptConnection): ()
	table.insert(State.Connections, Connection)
end

local function RegisterWorkspaceRootTree(RootInstance: Instance): ()
	table.insert(State.WorkspaceRootList, RootInstance)
	if State.WorkspaceRoots[RootInstance.Name] == nil then
		State.WorkspaceRoots[RootInstance.Name] = RootInstance
	end
end

local function RegisterLightingRootTree(RootInstance: Instance): ()
	table.insert(State.LightingRootList, RootInstance)
	if State.LightingRoots[RootInstance.Name] == nil then
		State.LightingRoots[RootInstance.Name] = RootInstance
	end
end

local function TrackAnimationTrack(Track: AnimationTrack): ()
	table.insert(State.Tracks, Track)
end

function GetCameraBindName(): string
	return CAMERA_BIND_NAME .. "_" .. tostring(Players.LocalPlayer.UserId)
end

local function MoveInstanceByDelta(InstanceItem: Instance, Delta: Vector3): ()
	if Delta.Magnitude <= 0.0001 then
		return
	end
	if InstanceItem:IsA("Model") then
		InstanceItem:PivotTo(InstanceItem:GetPivot() + Delta)
		return
	end
	if InstanceItem:IsA("BasePart") then
		InstanceItem.CFrame += Delta
	end
end

local function EnforceGameplayHudArtifactsHidden(Force: boolean?): ()
	local Now: number = os.clock()
	if not Force and Now < State.HiddenGameplayArtifactRefreshAt then
		return
	end

	State.HiddenGameplayArtifactRefreshAt = Now + GAMEPLAY_ARTIFACT_REFRESH_INTERVAL
	State.HiddenGameplayArtifactState = CutsceneVisibility.HideGameplayArtifacts(
		LocalPlayer,
		State.HiddenGameplayArtifactState
	)
end

local function GetPlanarDirection(Direction: Vector3): Vector3?
	local FlatDirection: Vector3 = Vector3.new(Direction.X, ZERO, Direction.Z)
	if FlatDirection.Magnitude <= EPSILON then
		return nil
	end
	return FlatDirection.Unit
end

local function BuildSceneRotation(AnchorPosition: Vector3, ReferenceForward: Vector3, TargetForward: Vector3): CFrame?
	local FlatReferenceForward: Vector3? = GetPlanarDirection(ReferenceForward)
	local FlatTargetForward: Vector3? = GetPlanarDirection(TargetForward)
	if not FlatReferenceForward or not FlatTargetForward then
		return nil
	end

	local Dot: number = math.clamp(FlatReferenceForward:Dot(FlatTargetForward), -ONE, ONE)
	local CrossY: number = FlatReferenceForward.Z * FlatTargetForward.X - FlatReferenceForward.X * FlatTargetForward.Z
	local Angle: number = math.atan2(CrossY, Dot)
	if math.abs(Angle) <= EPSILON then
		return nil
	end

	return CFrame.new(AnchorPosition) * CFrame.Angles(ZERO, Angle, ZERO) * CFrame.new(-AnchorPosition)
end

local function ApplySceneTransformToInstance(InstanceItem: Instance): ()
	if State.SceneDelta.Magnitude > EPSILON then
		MoveInstanceByDelta(InstanceItem, State.SceneDelta)
	end
	if not State.SceneRotation then
		return
	end
	if InstanceItem:IsA("Model") then
		InstanceItem:PivotTo(State.SceneRotation * InstanceItem:GetPivot())
		return
	end
	if InstanceItem:IsA("BasePart") then
		InstanceItem.CFrame = State.SceneRotation * InstanceItem.CFrame
	end
end

local function TransformSceneCFrame(SceneCFrame: CFrame): CFrame
	local Result: CFrame = SceneCFrame + State.SceneDelta
	if State.SceneRotation then
		Result = State.SceneRotation * Result
	end
	return Result
end

local function SplitPath(PathValue: string): {string}
	local Segments: {string} = {}
	for Segment in string.gmatch(PathValue, "[^%.]+") do
		local Clean: string = string.gsub(string.gsub(Segment, "^%s+", ""), "%s+$", "")
		if Clean ~= "" then
			table.insert(Segments, Clean)
		end
	end
	return Segments
end

local function FindChildBySegments(Current: Instance, Segments: {string}, StartIndex: number): (Instance?, number)
	for LastIndex = #Segments, StartIndex, NEGATIVE_ONE do
		local Name: string = table.concat(Segments, ".", StartIndex, LastIndex)
		local Found: Instance? = Current:FindFirstChild(Name)
		if Found then
			return Found, LastIndex
		end
	end
	for LastIndex = #Segments, StartIndex, NEGATIVE_ONE do
		local Name: string = table.concat(Segments, ".", StartIndex, LastIndex)
		local Found: Instance? = Current:FindFirstChild(Name, true)
		if Found then
			return Found, LastIndex
		end
	end
	return nil, StartIndex
end

local function ResolveWorkspaceRootByName(Name: string): Instance?
	local Cached: Instance? = State.WorkspaceRoots[Name]
	if Cached and Cached.Parent ~= nil then
		return Cached
	end

	local LowerName: string = string.lower(Name)
	for Index = #State.WorkspaceRootList, ONE, NEGATIVE_ONE do
		local RootInstance: Instance = State.WorkspaceRootList[Index]
		if RootInstance.Parent == nil then
			continue
		end
		if string.lower(RootInstance.Name) == LowerName then
			State.WorkspaceRoots[Name] = RootInstance
			return RootInstance
		end
	end

	for Index = #State.WorkspaceRootList, ONE, NEGATIVE_ONE do
		local RootInstance: Instance = State.WorkspaceRootList[Index]
		if RootInstance.Parent == nil then
			continue
		end

		local DirectChild: Instance? = RootInstance:FindFirstChild(Name)
		if DirectChild then
			State.WorkspaceRoots[Name] = DirectChild
			return DirectChild
		end

		local RecursiveChild: Instance? = RootInstance:FindFirstChild(Name, true)
		if RecursiveChild then
			State.WorkspaceRoots[Name] = RecursiveChild
			return RecursiveChild
		end
	end

	local DirectRoot: Instance? = workspace:FindFirstChild(Name)
	if DirectRoot then
		State.WorkspaceRoots[Name] = DirectRoot
		return DirectRoot
	end

	local RecursiveRoot: Instance? = workspace:FindFirstChild(Name, true)
	if RecursiveRoot then
		State.WorkspaceRoots[Name] = RecursiveRoot
	end
	return RecursiveRoot
end

local function ResolveLightingRootByName(Name: string): Instance?
	local Cached: Instance? = State.LightingRoots[Name]
	if Cached and Cached.Parent ~= nil then
		return Cached
	end

	local LowerName: string = string.lower(Name)
	for Index = #State.LightingRootList, ONE, NEGATIVE_ONE do
		local RootInstance: Instance = State.LightingRootList[Index]
		if RootInstance.Parent == nil then
			continue
		end
		if string.lower(RootInstance.Name) == LowerName then
			State.LightingRoots[Name] = RootInstance
			return RootInstance
		end
	end

	local DirectRoot: Instance? = Lighting:FindFirstChild(Name)
	if DirectRoot then
		State.LightingRoots[Name] = DirectRoot
		return DirectRoot
	end

	local RecursiveRoot: Instance? = Lighting:FindFirstChild(Name, true)
	if RecursiveRoot then
		State.LightingRoots[Name] = RecursiveRoot
	end
	return RecursiveRoot
end

local function ResolvePath(PathValue: string): Instance?
	local Cached: Instance? = State.PathCache[PathValue]
	if Cached and Cached.Parent ~= nil then
		return Cached
	end

	local Segments: {string} = SplitPath(PathValue)
	if #Segments <= 0 then
		return nil
	end

	local RootInstance: Instance? = nil
	local StartIndex: number = ONE

	if Segments[ONE] == "Lighting" then
		RootInstance = Lighting
		StartIndex = TWO
		if Segments[TWO] then
			local LightingRoot: Instance? = ResolveLightingRootByName(Segments[TWO])
			if LightingRoot then
				RootInstance = LightingRoot
				StartIndex = 3
			end
		end
	elseif Segments[ONE] == "Workspace" then
		if Segments[TWO] == "CurrentCamera" then
			RootInstance = workspace.CurrentCamera
			StartIndex = 3
		elseif Segments[TWO] then
			local WorkspaceRoot: Instance? = ResolveWorkspaceRootByName(Segments[TWO])
			if WorkspaceRoot then
				RootInstance = WorkspaceRoot
				StartIndex = 3
			else
				RootInstance = workspace
				StartIndex = TWO
			end
		end
	end

	if not RootInstance then
		return nil
	end
	if StartIndex > #Segments then
		State.PathCache[PathValue] = RootInstance
		return RootInstance
	end

	local Current: Instance = RootInstance
	local Index: number = StartIndex
	while Index <= #Segments do
		local Found: Instance?, LastIndex: number = FindChildBySegments(Current, Segments, Index)
		if not Found then
			return nil
		end
		Current = Found
		Index = LastIndex + ONE
	end

	State.PathCache[PathValue] = Current
	return Current
end

local function GetOrCreateAnimator(Parent: Instance): Animator
	local Existing: Animator? = Parent:FindFirstChildOfClass("Animator")
	if Existing then
		return Existing
	end
	local AnimatorInstance: Animator = Instance.new("Animator")
	AnimatorInstance.Parent = Parent
	return AnimatorInstance
end

local function FindHumanoidInModel(Model: Model): Humanoid?
	local DirectHumanoid: Humanoid? = Model:FindFirstChildOfClass("Humanoid")
	if DirectHumanoid then
		return DirectHumanoid
	end
	return Model:FindFirstChildWhichIsA("Humanoid", true)
end

local function ResolveAnimatedRigModel(Model: Model): Model
	local HumanoidInstance: Humanoid? = FindHumanoidInModel(Model)
	if HumanoidInstance and HumanoidInstance.Parent and HumanoidInstance.Parent:IsA("Model") then
		return HumanoidInstance.Parent
	end

	local AnimationControllerInstance: AnimationController? = Model:FindFirstChildWhichIsA("AnimationController", true)
	if AnimationControllerInstance and AnimationControllerInstance.Parent and AnimationControllerInstance.Parent:IsA("Model") then
		return AnimationControllerInstance.Parent
	end

	return Model
end

local function GetAnimatorFromModel(Model: Instance): Animator?
	if not Model:IsA("Model") then
		return nil
	end

	local HumanoidInstance: Humanoid? = FindHumanoidInModel(Model)
	if HumanoidInstance then
		return GetOrCreateAnimator(HumanoidInstance)
	end
	local AnimationControllerInstance: AnimationController? = Model:FindFirstChildWhichIsA("AnimationController", true)
	if AnimationControllerInstance then
		return GetOrCreateAnimator(AnimationControllerInstance)
	end
	return nil
end

local function LoadAnimationTrack(Target: Instance, AnimationId: string): AnimationTrack?
	local AnimatorInstance: Animator? = GetAnimatorFromModel(Target)
	if not AnimatorInstance then
		return nil
	end

	local AnimationInstance: Animation = Instance.new("Animation")
	AnimationInstance.AnimationId = AnimationId
	local Track: AnimationTrack = AnimatorInstance:LoadAnimation(AnimationInstance)
	AnimationInstance:Destroy()
	Track.Looped = false
	Track.Priority = Enum.AnimationPriority.Action
	return Track
end

local function StartAnimationTrack(Track: AnimationTrack): ()
	Track:Play(0)
	TrackAnimationTrack(Track)
end

local function TrackNaturalTrackCompletion(Token: number, Track: AnimationTrack, Callback: () -> ()): ()
	local Connection: RBXScriptConnection? = nil
	Connection = RunService.Heartbeat:Connect(function()
		if Connection == nil then
			return
		end
		if not IsTokenActive(Token) then
			Connection:Disconnect()
			Connection = nil
			return
		end

		local Length: number = Track.Length
		if Length <= ZERO or Track.IsPlaying then
			return
		end
		if Track.TimePosition + RUGBY_BALL_END_EPSILON < Length then
			return
		end

		Connection:Disconnect()
		Connection = nil
		Callback()
	end)
	TrackConnection(Connection)
end

local function FindModelRootPart(Model: Model): BasePart?
	local Root: BasePart? = Model:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	if Root then
		return Root
	end
	local RigModel: Model = ResolveAnimatedRigModel(Model)
	if RigModel.PrimaryPart then
		return RigModel.PrimaryPart
	end
	if Model.PrimaryPart then
		return Model.PrimaryPart
	end
	return Model:FindFirstChildWhichIsA("BasePart", true)
end

local function ResolveCutscenePart(Model: Model?): BasePart?
	if not Model then
		return nil
	end

	local Root: BasePart? = FindModelRootPart(Model)
	if Root then
		return Root
	end

	for _, PartName in ROOT_ALIGNMENT_PART_NAMES do
		local Part: Instance? = Model:FindFirstChild(PartName, true)
		if Part and Part:IsA("BasePart") then
			return Part
		end
	end

	return Model:FindFirstChildWhichIsA("BasePart", true)
end

ResolveFinalSourceCFrame = function(): CFrame?
	local ActorPart: BasePart? = ResolveCutscenePart(State.SourceActorModel)
	if ActorPart then
		return ActorPart.CFrame
	end

	local LocalRoot: BasePart? = State.LocalSourceRoot
	if LocalRoot and LocalRoot.Parent ~= nil then
		return LocalRoot.CFrame
	end

	local Character: Model? = LocalPlayer.Character
	if not Character then
		return nil
	end

	local CharacterPart: BasePart? = ResolveCutscenePart(Character)
	if CharacterPart then
		return CharacterPart.CFrame
	end

	return Character:GetPivot()
end

ApplyFinalLocalSourcePosition = function(): ()
	if State.LocalSourceRoot == nil then
		return
	end

	local Character: Model? = LocalPlayer.Character
	if not Character then
		return
	end

	local AlignmentPart: BasePart? = ResolveCutscenePart(Character)
	local ActorPart: BasePart? = ResolveCutscenePart(State.SourceActorModel)
	if not AlignmentPart or not ActorPart then
		return
	end

	local CharacterPivot: CFrame = Character:GetPivot()
	local AlignmentOffset: CFrame = CharacterPivot:ToObjectSpace(AlignmentPart.CFrame)
	Character:PivotTo(ActorPart.CFrame * AlignmentOffset:Inverse())

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function SyncFinalSourceState(Token: number): ()
	if not IsTokenActive(Token) or State.LocalSourceRoot == nil then
		return
	end

	local FinalCFrame: CFrame? = ResolveFinalSourceCFrame()
	if not FinalCFrame then
		return
	end

	ApplyFinalLocalSourcePosition()
	if State.ServerToken ~= nil then
		NotifyServerCutsceneEnded(State.ServerToken, FinalCFrame)
	end
end

local function TrackSourceEndMarker(Token: number, Track: AnimationTrack): ()
	local Connection: RBXScriptConnection = Track:GetMarkerReachedSignal(END_MARKER_NAME):Connect(function()
		SyncFinalSourceState(Token)
	end)
	TrackConnection(Connection)
end

local function PrepareAnimatedModel(Model: Model): ()
	local HumanoidInstance: Humanoid? = FindHumanoidInModel(Model)
	if HumanoidInstance then
		HumanoidInstance.AutoRotate = false
		HumanoidInstance.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		HumanoidInstance.PlatformStand = false
		HumanoidInstance.Sit = false
	end

	local RootPart: BasePart? = FindModelRootPart(Model)
	for _, Descendant in Model:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.Anchored = Descendant == RootPart
			Descendant.CanCollide = false
			Descendant.CanTouch = false
			Descendant.CanQuery = false
			Descendant.Massless = true
			Descendant.AssemblyLinearVelocity = Vector3.zero
			Descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function ClearActorAppearance(ActorModel: Model): ()
	local RigModel: Model = ResolveAnimatedRigModel(ActorModel)
	for _, Descendant in RigModel:GetDescendants() do
		if Descendant:IsA("Accessory")
			or Descendant:IsA("Shirt")
			or Descendant:IsA("Pants")
			or Descendant:IsA("ShirtGraphic")
			or Descendant:IsA("BodyColors")
			or Descendant:IsA("CharacterMesh")
		then
			Descendant:Destroy()
		end
	end

	local Head: BasePart? = RigModel:FindFirstChild("Head", true) :: BasePart?
	if not Head then
		return
	end
	for _, Child in Head:GetChildren() do
		if (Child:IsA("Decal") or Child:IsA("Texture")) and string.lower(Child.Name) == "face" then
			Child:Destroy()
		end
	end
end

local function ApplyPlayerAppearance(PlayerItem: Player, ActorModel: Model): boolean
	local SourceCharacter: Model? = PlayerItem.Character
	if not SourceCharacter or SourceCharacter.Parent == nil then
		return false
	end

	local Success: boolean = pcall(function()
		CutsceneRigUtils.ApplyPlayerAppearance(PlayerItem, ActorModel, {
			AccessoryMode = "HairOnly",
		})
	end)
	return Success
end

local function ResolveCharsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
		or ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME, 10)
	if not AssetsFolder then
		return nil
	end

	local CharsFolder: Instance? = AssetsFolder:FindFirstChild(CHARS_FOLDER_NAME)
	if CharsFolder then
		return CharsFolder
	end

	return AssetsFolder:FindFirstChild(CHARS_FOLDER_NAME, true)
end

local function ResolveRandomFallbackModel(): Model?
	if CachedFallbackModels and #CachedFallbackModels > 0 then
		return CachedFallbackModels[math.random(1, #CachedFallbackModels)]
	end

	local CandidateModels: {Model} = {}
	local CharsFolder: Instance? = ResolveCharsFolder()
	if CharsFolder then
		for _, Child in CharsFolder:GetChildren() do
			if Child:IsA("Model") then
				table.insert(CandidateModels, Child)
			end
		end

		if #CandidateModels <= 0 then
			for _, Descendant in CharsFolder:GetDescendants() do
				if Descendant:IsA("Model") and Descendant:FindFirstChildWhichIsA("Humanoid", true) then
					table.insert(CandidateModels, Descendant)
				end
			end
		end
	end

	if #CandidateModels <= 0 then
		return nil
	end

	CachedFallbackModels = CandidateModels
	return CandidateModels[math.random(1, #CandidateModels)]
end

local function ResolveValidSourcePlayer(PlayerItem: Player?): Player?
	if not PlayerItem then
		return nil
	end

	local Character: Model? = PlayerItem.Character
	if not Character or Character.Parent == nil then
		return nil
	end

	return PlayerItem
end

local function ResolveOppositeTeamNumber(TeamNumber: number?): number?
	if TeamNumber == 1 then
		return 2
	end
	if TeamNumber == 2 then
		return 1
	end
	return nil
end

local function ApplyFallbackAppearance(ActorModel: Model, FallbackModel: Model?): ()
	if FallbackModel and FallbackModel.Parent ~= nil then
		pcall(function()
			CutsceneRigUtils.ApplyModelAppearance(FallbackModel, ActorModel, {
				AccessoryMode = "HairOnly",
			})
		end)
	end
end

local function ApplyTeamAppearance(ActorModel: Model, TeamNumber: number?): ()
	if TeamNumber and TeamNumber > ZERO then
		CutsceneRigUtils.ApplyTeamAppearanceByNumber(TeamNumber, ActorModel)
	end
end

local function ApplyAppearancePlan(ActorModel: Model, Plan: ActorAppearancePlan?): ()
	if not Plan then
		return
	end

	local SourcePlayer: Player? = ResolveValidSourcePlayer(Plan.SourcePlayer)
	if not (SourcePlayer and ApplyPlayerAppearance(SourcePlayer, ActorModel)) then
		ApplyFallbackAppearance(ActorModel, Plan.FallbackModel)
	end

	ApplyTeamAppearance(ActorModel, Plan.TeamNumber)
end

local function ResolvePlayer(UserId: number?): Player?
	if type(UserId) ~= "number" then
		return nil
	end
	if UserId <= 0 then
		return nil
	end
	return Players:GetPlayerByUserId(math.floor(UserId + 0.5))
end

local function BuildActorAppearancePlans(Payload: CutscenePayload): {[string]: ActorAppearancePlan}
	local SourcePlayer: Player? = ResolveValidSourcePlayer(ResolvePlayer(Payload.SourceUserId))
	local ReceiverPlayer: Player? = ResolveValidSourcePlayer(ResolvePlayer(Payload.ReceiverUserId))
	local EnemyOnePlayer: Player? = ResolveValidSourcePlayer(ResolvePlayer(Payload.EnemyOneUserId))
	local EnemyTwoPlayer: Player? = ResolveValidSourcePlayer(ResolvePlayer(Payload.EnemyTwoUserId))

	local SourceTeamNumber: number? = if SourcePlayer then CutsceneRigUtils.GetPlayerTeamNumber(SourcePlayer) else nil
	if not SourceTeamNumber and ReceiverPlayer then
		SourceTeamNumber = CutsceneRigUtils.GetPlayerTeamNumber(ReceiverPlayer)
	end

	local OppositeTeamNumber: number? = ResolveOppositeTeamNumber(SourceTeamNumber)
	if not OppositeTeamNumber and EnemyOnePlayer then
		OppositeTeamNumber = CutsceneRigUtils.GetPlayerTeamNumber(EnemyOnePlayer)
	end
	if not OppositeTeamNumber and EnemyTwoPlayer then
		OppositeTeamNumber = CutsceneRigUtils.GetPlayerTeamNumber(EnemyTwoPlayer)
	end

	local function BuildPlan(SourcePlayerForPlan: Player?, TeamNumber: number?): ActorAppearancePlan
		local ActualPlayer: Player? = ResolveValidSourcePlayer(SourcePlayerForPlan)
		return {
			SourcePlayer = ActualPlayer,
			FallbackModel = if ActualPlayer then nil else ResolveRandomFallbackModel(),
			TeamNumber = TeamNumber,
		}
	end

	return {
		["Player 1"] = BuildPlan(EnemyOnePlayer, OppositeTeamNumber),
		["Player 2"] = BuildPlan(EnemyTwoPlayer, OppositeTeamNumber),
		["Player 5"] = BuildPlan(nil, OppositeTeamNumber),
		["Player 7"] = BuildPlan(SourcePlayer, SourceTeamNumber),
		["Player 10"] = BuildPlan(ReceiverPlayer, SourceTeamNumber),
	}
end

local function FindPrincipalChild(PrincipalSource: Instance, Name: string): Instance?
	local DirectChild: Instance? = PrincipalSource:FindFirstChild(Name)
	if DirectChild then
		return DirectChild
	end
	return PrincipalSource:FindFirstChild(Name, true)
end

local function ResolveSourceAnchorCFrame(Payload: CutscenePayload): CFrame
	return CFrame.new(Payload.AnchorPosition)
end

local function HideMatchCharacters(): ()
	State.HiddenCharacterState = CutsceneVisibility.HideMatchPlayers(State.HiddenCharacterState, {
		HideEffects = true,
		HideBillboards = true,
	})
end

local function CloneActorFromTemplate(
	TemplateInstance: Instance,
	Name: string,
	AnchorCFrame: CFrame,
	AppearancePlan: ActorAppearancePlan?
): Model?
	if not TemplateInstance:IsA("Model") then
		return nil
	end

	local ActorModel: Model = TemplateInstance:Clone()
	ApplyAppearancePlan(ActorModel, AppearancePlan)

	ActorModel.Name = Name
	ActorModel.Parent = workspace
	TrackClone(ActorModel)

	local TemplatePivot: CFrame = TemplateInstance:GetPivot()
	local TemplateRoot: BasePart? = FindModelRootPart(TemplateInstance)
	if TemplateRoot then
		local RootOffset: CFrame = TemplatePivot:ToObjectSpace(TemplateRoot.CFrame)
		local TargetRootCFrame: CFrame = CFrame.fromMatrix(
			AnchorCFrame.Position,
			TemplateRoot.CFrame.XVector,
			TemplateRoot.CFrame.YVector,
			TemplateRoot.CFrame.ZVector
		)
		ActorModel:PivotTo(TargetRootCFrame * RootOffset:Inverse())
	else
		local TargetCFrame: CFrame =
			CFrame.fromMatrix(AnchorCFrame.Position, TemplatePivot.XVector, TemplatePivot.YVector, TemplatePivot.ZVector)
		ActorModel:PivotTo(TargetCFrame)
	end
	if State.SceneRotation then
		ActorModel:PivotTo(State.SceneRotation * ActorModel:GetPivot())
	end
	PrepareAnimatedModel(ActorModel)
	RegisterWorkspaceRootTree(ActorModel)
	return ActorModel
end

local function CloneGenericPrincipalModel(TemplateInstance: Instance): Instance
	local Clone: Instance = TemplateInstance:Clone()
	Clone.Parent = workspace
	TrackClone(Clone)
	ApplySceneTransformToInstance(Clone)
	RegisterWorkspaceRootTree(Clone)
	if Clone:IsA("Model") then
		PrepareAnimatedModel(Clone)
	end
	return Clone
end

local function IsAssetPackAlive(AssetPackInstance: AssetPack?): boolean
	if not AssetPackInstance then
		return false
	end
	if AssetPackInstance.Container.Parent == nil then
		return false
	end
	if AssetPackInstance.LightingSource.Parent == nil then
		return false
	end
	if AssetPackInstance.PrincipalSource.Parent == nil then
		return false
	end
	if AssetPackInstance.VFXSource.Parent == nil then
		return false
	end
	if AssetPackInstance.SceneAssetsSource and AssetPackInstance.SceneAssetsSource.Parent == nil then
		return false
	end
	return true
end

local function FindAssetPack(): AssetPack?
	if IsAssetPackAlive(CachedAssetPack) then
		return CachedAssetPack
	end

	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	local SkillsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(SKILLS_FOLDER_NAME)
	local HirumaFolder: Instance? = SkillsFolder and SkillsFolder:FindFirstChild(HIRUMA_FOLDER_NAME)
	local PerfectPassFolder: Instance? = HirumaFolder and HirumaFolder:FindFirstChild(PERFECT_PASS_FOLDER_NAME)

	local function ResolveFromContainer(Container: Instance?): AssetPack?
		if not Container then
			return nil
		end
		local LightingSource: Instance? = Container:FindFirstChild(LIGHTING_FOLDER_NAME)
		local PrincipalSource: Instance? = Container:FindFirstChild(PRINCIPAL_FOLDER_NAME)
		local VFXSource: Instance? = Container:FindFirstChild(VFX_FOLDER_NAME)
		local SceneAssetsCandidate: Instance? = Container:FindFirstChild(ASSETS_FOLDER_NAME)
		local SceneAssetsSource: Model? = nil
		if SceneAssetsCandidate and SceneAssetsCandidate:IsA("Model") then
			SceneAssetsSource = SceneAssetsCandidate
			PrincipalSource = SceneAssetsSource
			VFXSource = SceneAssetsSource
		end
		if not LightingSource or not PrincipalSource or not VFXSource then
			return nil
		end
		return {
			Container = Container,
			LightingSource = LightingSource,
			PrincipalSource = PrincipalSource,
			VFXSource = VFXSource,
			SceneAssetsSource = SceneAssetsSource,
		}
	end

	local DirectPack: AssetPack? = ResolveFromContainer(PerfectPassFolder)
	if DirectPack then
		CachedAssetPack = DirectPack
		return DirectPack
	end

	for _, SearchRoot in {ReplicatedStorage, workspace} do
		local Candidate: Instance? = SearchRoot:FindFirstChild(PERFECT_PASS_FOLDER_NAME, true)
		local Pack: AssetPack? = ResolveFromContainer(Candidate)
		if Pack then
			CachedAssetPack = Pack
			return Pack
		end
	end

	return nil
end

local function CloneLightingAssets(AssetPack: AssetPack): ()
	for _, Item in AssetPack.LightingSource:GetChildren() do
		local Clone: Instance = Item:Clone()
		Clone.Parent = Lighting
		TrackClone(Clone)
		RegisterLightingRootTree(Clone)
	end
end

local function CloneVFXAssets(AssetPack: AssetPack): ()
	for _, Item in AssetPack.VFXSource:GetChildren() do
		if AssetPack.SceneAssetsSource and IsPrincipalTemplateName(Item.Name) then
			continue
		end
		local Clone: Instance = Item:Clone()
		Clone.Parent = workspace
		TrackClone(Clone)
		ApplySceneTransformToInstance(Clone)
		RegisterWorkspaceRootTree(Clone)
	end
end

local function SetupCamera(CamTemplate: Instance): Model?
	if not CamTemplate:IsA("Model") then
		return
	end

	local CamModel: Model = CamTemplate:Clone()
	CamModel.Parent = workspace
	TrackClone(CamModel)
	ApplySceneTransformToInstance(CamModel)
	PrepareAnimatedModel(CamModel)
	RegisterWorkspaceRootTree(CamModel)

	local CamPart: BasePart? = CamModel:FindFirstChild(CAM_PART_NAME, true) :: BasePart?
	if not CamPart then
		return
	end
	State.CamPart = CamPart

	local Camera: Camera? = workspace.CurrentCamera
	if not Camera then
		return
	end

	State.PrevCameraType = Camera.CameraType
	State.PrevCameraSubject = Camera.CameraSubject
	State.PrevCameraCFrame = Camera.CFrame
	State.PrevCameraFov = Camera.FieldOfView
	State.PrevMouseBehavior = UserInputService.MouseBehavior
	State.PrevMouseIconEnabled = UserInputService.MouseIconEnabled

	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CameraSubject = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	if State.CameraBound then
		RunService:UnbindFromRenderStep(GetCameraBindName())
	end
	RunService:BindToRenderStep(GetCameraBindName(), CAMERA_BIND_PRIORITY, function()
		if not State.Active then
			return
		end
		local CurrentCamera: Camera? = workspace.CurrentCamera
		if not CurrentCamera then
			return
		end
		EnforceGameplayHudArtifactsHidden()
		CurrentCamera.CameraType = Enum.CameraType.Scriptable
		CurrentCamera.CameraSubject = nil
		if State.CamPart and State.CamPart.Parent ~= nil then
			CurrentCamera.CFrame = State.CamPart.CFrame
		end
	end)
	State.CameraBound = true
	return CamModel
end

local function BuildEventBuckets(): ({[number]: {PerfectPassEvent}}, number)
	if CachedEventBuckets then
		return CachedEventBuckets, CachedTimelineMaxFrame
	end

	local Buckets: {[number]: {PerfectPassEvent}} = {}
	local MaxFrame: number = ZERO
	for _, Event in PerfectPassTimeline.Events :: {PerfectPassEvent} do
		if Event.Frame > MaxFrame then
			MaxFrame = Event.Frame
		end
		local Bucket: {PerfectPassEvent}? = Buckets[Event.Frame]
		if not Bucket then
			Bucket = {}
			Buckets[Event.Frame] = Bucket
		end
		table.insert(Bucket, Event)
	end

	CachedEventBuckets = Buckets
	CachedTimelineMaxFrame = MaxFrame
	return Buckets, MaxFrame
end

local function SupportsEnabledState(Target: Instance): boolean
	return Target:IsA("ParticleEmitter")
		or Target:IsA("Beam")
		or Target:IsA("Trail")
		or Target:IsA("Light")
		or Target:IsA("PostEffect")
		or Target:IsA("Highlight")
		or Target:IsA("Fire")
		or Target:IsA("Smoke")
		or Target:IsA("Sparkles")
end

local function ResolveEnabledTargets(Target: Instance): {Instance}
	local CachedTargets: {Instance}? = State.EnableTargetCache[Target]
	if CachedTargets then
		return CachedTargets
	end

	local Targets: {Instance} = {}
	if SupportsEnabledState(Target) then
		table.insert(Targets, Target)
	else
		for _, Descendant in Target:GetDescendants() do
			if SupportsEnabledState(Descendant) then
				table.insert(Targets, Descendant)
			end
		end
	end

	State.EnableTargetCache[Target] = Targets
	return Targets
end

local function ResolveEmitTargets(Target: Instance): {ParticleEmitter}
	local CachedTargets: {ParticleEmitter}? = State.EmitTargetCache[Target]
	if CachedTargets then
		return CachedTargets
	end

	local Targets: {ParticleEmitter} = {}
	if Target:IsA("ParticleEmitter") then
		table.insert(Targets, Target)
	else
		for _, Descendant in Target:GetDescendants() do
			if Descendant:IsA("ParticleEmitter") then
				table.insert(Targets, Descendant)
			end
		end
	end

	State.EmitTargetCache[Target] = Targets
	return Targets
end

local function SetEnabledRecursive(Target: Instance, Enabled: boolean): ()
	for _, EnabledTarget in ResolveEnabledTargets(Target) do
		local EnabledInstance: any = EnabledTarget
		if EnabledInstance.Enabled ~= Enabled then
			EnabledInstance.Enabled = Enabled
		end
	end
end

local function EmitRecursive(Target: Instance, Amount: number): ()
	local EmitAmount: number = math.max(math.floor(Amount), ONE)
	for _, Emitter in ResolveEmitTargets(Target) do
		Emitter:Emit(EmitAmount)
	end
end

local function ToCFrame(Value: any): CFrame?
	if type(Value) ~= "table" then
		return nil
	end
	if #Value < 12 then
		return nil
	end
	local X: number = tonumber(Value[1]) or ZERO
	local Y: number = tonumber(Value[2]) or ZERO
	local Z: number = tonumber(Value[3]) or ZERO
	local R00: number = tonumber(Value[4]) or ONE
	local R01: number = tonumber(Value[5]) or ZERO
	local R02: number = tonumber(Value[6]) or ZERO
	local R10: number = tonumber(Value[7]) or ZERO
	local R11: number = tonumber(Value[8]) or ONE
	local R12: number = tonumber(Value[9]) or ZERO
	local R20: number = tonumber(Value[10]) or ZERO
	local R21: number = tonumber(Value[11]) or ZERO
	local R22: number = tonumber(Value[12]) or ONE
	return CFrame.new(X, Y, Z, R00, R01, R02, R10, R11, R12, R20, R21, R22)
end

local function SetProperty(Target: Instance, Property: string, Value: any): ()
	if State.CameraReleased and Target == workspace.CurrentCamera then
		return
	end

	if Property == "FieldOfView" and Target == workspace.CurrentCamera and type(Value) == "number" then
		ApplyCutsceneFov(Value)
		return
	end

	if Property == "CFrame" then
		local Parsed: CFrame? = ToCFrame(Value)
		if not Parsed then
			return
		end
		local SceneCFrame: CFrame = TransformSceneCFrame(Parsed)
		if Target:IsA("Model") then
			Target:PivotTo(SceneCFrame)
			return
		end
		if Target:IsA("BasePart") then
			Target.CFrame = SceneCFrame
		end
		return
	end

	pcall(function()
		(Target :: any)[Property] = Value
	end)
end

local function ExecuteEvent(Token: number, Event: PerfectPassEvent): ()
	if not IsTokenActive(Token) then
		return
	end
	if not Event.Path then
		return
	end

	local Target: Instance? = ResolvePath(Event.Path)
	if not Target then
		return
	end

	if Event.Action == "Emit" then
		EmitRecursive(Target, Event.Amount or ONE)
		return
	end
	if Event.Action == "Enable" then
		SetEnabledRecursive(Target, true)
		return
	end
	if Event.Action == "Disable" then
		SetEnabledRecursive(Target, false)
		return
	end
	if Event.Action == "SetProperty" and Event.Property then
		SetProperty(Target, Event.Property, Event.Value)
	end
end

function Cleanup(): ()
	local PendingServerToken: number? = if State.Active then State.ServerToken else nil
	local PendingServerCompletionSent: boolean = State.ServerCompletionSent
	State.Active = false
	if PendingServerToken ~= nil and not PendingServerCompletionSent then
		NotifyServerCutsceneEnded(PendingServerToken, ResolveFinalSourceCFrame())
	end
	SetPerfectPassShiftlockBlocked(false)
	SetLocalCutsceneHudHidden(false)
	ReleaseCameraLock()
	RestoreLocalSourceCharacter()
	CutsceneVisibility.RestoreCharacters(State.HiddenCharacterState)
	CutsceneVisibility.RestoreGameplayArtifacts(State.HiddenGameplayArtifactState)
	State.HiddenCharacterState = nil
	State.HiddenGameplayArtifactState = nil

	for _, Track in State.Tracks do
		pcall(function()
			Track:Stop(EFFECT_DISABLE_DELAY)
		end)
		pcall(function()
			Track:Destroy()
		end)
	end
	table.clear(State.Tracks)

	for _, Connection in State.Connections do
		Connection:Disconnect()
	end
	table.clear(State.Connections)

	for _, Clone in State.Clones do
		Clone:Destroy()
	end
	table.clear(State.Clones)

	table.clear(State.WorkspaceRoots)
	table.clear(State.WorkspaceRootList)
	table.clear(State.LightingRoots)
	table.clear(State.LightingRootList)
	table.clear(State.PathCache)
	State.EventBuckets = {}
	table.clear(State.EnableTargetCache)
	table.clear(State.EmitTargetCache)

	State.CamPart = nil
	State.TimelineStartAt = ZERO
	State.NextFrame = ZERO
	State.PrevCameraType = nil
	State.PrevCameraSubject = nil
	State.PrevCameraCFrame = nil
	State.PrevCameraFov = nil
	State.PrevMouseBehavior = nil
	State.PrevMouseIconEnabled = nil
	State.CameraReleased = false
	State.CameraCompleted = true
	State.TimelineCompleted = false
	State.RugbyBallCompleted = true
	State.ServerToken = nil
	State.ServerCompletionSent = false
	State.SourceActorModel = nil
	State.HiddenGameplayArtifactRefreshAt = ZERO
	State.SceneDelta = Vector3.zero
	State.SceneRotation = nil
	State.SceneAnchorPosition = nil
end

local function ScheduleCompletionRecovery(Token: number, Duration: number, MaxFrame: number): ()
	local TimelineDuration: number = MaxFrame / (PerfectPassTimeline.FPS or 60)
	local RecoveryAfter: number = math.max(Duration, TimelineDuration) + COMPLETION_RECOVERY_PADDING
	task.delay(RecoveryAfter, function()
		ForceCompleteCutscene(Token)
	end)
end

local function ScheduleFailsafeCleanup(Token: number, Duration: number, MaxFrame: number): ()
	local TimelineDuration: number = MaxFrame / (PerfectPassTimeline.FPS or 60)
	local CleanupAfter: number = math.max(Duration, TimelineDuration) + TIMELINE_PADDING + RUGBY_BALL_TIMEOUT_PADDING
	task.delay(CleanupAfter, function()
		if IsTokenActive(Token) then
			if State.ServerToken ~= nil then
				NotifyServerCutsceneEnded(State.ServerToken, ResolveFinalSourceCFrame())
			end
			Cleanup()
		end
	end)
end

local function StartTimeline(Token: number): ()
	local EventBuckets: {[number]: {PerfectPassEvent}}, MaxFrame: number = BuildEventBuckets()
	State.EventBuckets = EventBuckets
	State.TimelineStartAt = os.clock()
	State.NextFrame = ZERO

	local TimelineFps: number = PerfectPassTimeline.FPS or 60
	local Connection: RBXScriptConnection
	Connection = RunService.Heartbeat:Connect(function()
		if not IsTokenActive(Token) then
			return
		end

		EnforceGameplayHudArtifactsHidden()
		local Elapsed: number = os.clock() - State.TimelineStartAt
		local CurrentFrame: number = math.floor(Elapsed * TimelineFps)
		while State.NextFrame <= CurrentFrame do
			local Frame: number = State.NextFrame
			local Bucket: {PerfectPassEvent}? = State.EventBuckets[Frame]
			if Bucket then
				for _, Event in Bucket do
					ExecuteEvent(Token, Event)
				end
			end
			if Frame >= MaxFrame then
				State.TimelineCompleted = true
				State.NextFrame = MaxFrame + ONE
				Connection:Disconnect()
				TryCompleteCutscene(Token)
				return
			end
			State.NextFrame += ONE
		end
	end)
	TrackConnection(Connection)
end

local function StartCutscene(Payload: CutscenePayload): ()
	Cleanup()

	local AssetPack: AssetPack? = FindAssetPack()
	if not AssetPack then
		return
	end

	State.Token += ONE
	local Token: number = State.Token
	State.Active = true
	SetPerfectPassShiftlockBlocked(true)
	SetLocalCutsceneHudHidden(true)
	EnforceGameplayHudArtifactsHidden(true)
	State.CameraReleased = false
	State.CameraCompleted = false
	State.ServerToken = Payload.ServerToken
	State.ServerCompletionSent = false
	State.TimelineCompleted = false
	State.RugbyBallCompleted = true

	local Delta: Vector3 = Payload.AnchorPosition - REFERENCE_ANCHOR_POSITION
	if AssetPack.SceneAssetsSource then
		local TargetAssetsPosition: Vector3 = Payload.AnchorPosition + SCENE_ASSETS_OFFSET_FROM_PLAYER
		Delta = TargetAssetsPosition - AssetPack.SceneAssetsSource:GetPivot().Position
	end
	State.SceneDelta = Delta
	State.SceneAnchorPosition = Payload.AnchorPosition

	local ReferenceForward: Vector3 = FALLBACK_FORWARD
	local SourceActorTemplate: Instance? = FindPrincipalChild(AssetPack.PrincipalSource, SOURCE_ACTOR_TEMPLATE_NAME)
	if SourceActorTemplate and SourceActorTemplate:IsA("Model") then
		local SourceTemplateRoot: BasePart? = FindModelRootPart(SourceActorTemplate)
		if SourceTemplateRoot then
			ReferenceForward = GetPlanarDirection(SourceTemplateRoot.CFrame.LookVector) or FALLBACK_FORWARD
		end
	end
	State.SceneRotation = BuildSceneRotation(Payload.AnchorPosition, ReferenceForward, Payload.AnchorForward)
	local SourceAnchorCFrame: CFrame = ResolveSourceAnchorCFrame(Payload)
	local ActorAppearancePlans: {[string]: ActorAppearancePlan} = BuildActorAppearancePlans(Payload)
	local PendingAnimations: {{Target: Instance, AnimationId: string, IsRugbyBall: boolean?, IsSourceActor: boolean?}} = {}
	local PendingTracks: {AnimationTrack} = {}
	local CamTrack: AnimationTrack? = nil
	local RugbyBallTrack: AnimationTrack? = nil

	CloneLightingAssets(AssetPack)
	CloneVFXAssets(AssetPack)
	HideMatchCharacters()
	FreezeLocalSourceCharacter(Payload.SourceUserId)

	local CamTemplate: Instance? = FindPrincipalChild(AssetPack.PrincipalSource, CAM_TEMPLATE_NAME)
	if CamTemplate then
		local CamModel: Model? = SetupCamera(CamTemplate)
		if CamModel then
			table.insert(PendingAnimations, {
				Target = CamModel,
				AnimationId = CAM_ANIMATION_ID,
			})
		end
	end

	for _, ActorDefinition in ACTOR_DEFINITIONS do
		local TemplateInstance: Instance? = FindPrincipalChild(AssetPack.PrincipalSource, ActorDefinition.Name)
		if TemplateInstance then
			local ActorModel: Model? = CloneActorFromTemplate(
				TemplateInstance,
				ActorDefinition.Name,
				SourceAnchorCFrame,
				ActorAppearancePlans[ActorDefinition.Name]
			)
			if ActorModel then
				if ActorDefinition.Name == SOURCE_ACTOR_TEMPLATE_NAME then
					State.SourceActorModel = ActorModel
				end
				table.insert(PendingAnimations, {
					Target = ActorModel,
					AnimationId = ActorDefinition.AnimationId,
					IsSourceActor = ActorDefinition.Name == SOURCE_ACTOR_TEMPLATE_NAME,
				})
			end
		end
	end

	local RugbyBallTemplate: Instance? = FindPrincipalChild(AssetPack.PrincipalSource, RUGBY_BALL_TEMPLATE_NAME)
	if RugbyBallTemplate then
		local RugbyBallClone: Instance = CloneGenericPrincipalModel(RugbyBallTemplate)
		table.insert(PendingAnimations, {
			Target = RugbyBallClone,
			AnimationId = RUGBY_BALL_ANIMATION_ID,
			IsRugbyBall = true,
		})
	end

	for _, PendingAnimation in PendingAnimations do
		local Track: AnimationTrack? = LoadAnimationTrack(PendingAnimation.Target, PendingAnimation.AnimationId)
		if Track then
			if PendingAnimation.AnimationId == CAM_ANIMATION_ID then
				CamTrack = Track
			end
			if PendingAnimation.IsRugbyBall then
				RugbyBallTrack = Track
			end
			if PendingAnimation.IsSourceActor then
				TrackSourceEndMarker(Token, Track)
			end
			table.insert(PendingTracks, Track)
		end
	end

	for _, Track in PendingTracks do
		StartAnimationTrack(Track)
	end

	if CamTrack then
		TrackNaturalTrackCompletion(Token, CamTrack, function()
			if not IsTokenActive(Token) then
				return
			end
			State.CameraCompleted = true
			ReleaseCameraLock()
			TryCompleteCutscene(Token)
		end)
	else
		State.CameraCompleted = true
	end

	if RugbyBallTrack then
		State.RugbyBallCompleted = false
		TrackNaturalTrackCompletion(Token, RugbyBallTrack, function()
			if not IsTokenActive(Token) then
				return
			end
			State.RugbyBallCompleted = true
			TryCompleteCutscene(Token)
		end)
	end

	EnforceGameplayHudArtifactsHidden(true)
	StartTimeline(Token)
	ScheduleCompletionRecovery(Token, Payload.Duration, PerfectPassTimeline.MaxFrame or 516)
	ScheduleFailsafeCleanup(Token, Payload.Duration, PerfectPassTimeline.MaxFrame or 516)
end

function Controller.Cleanup(): ()
	Cleanup()
end

function Controller.Play(
	SourceUserId: number,
	AnchorPosition: Vector3,
	AnchorForward: Vector3,
	Duration: number,
	ServerToken: number,
	EnemyOneUserId: number?,
	EnemyTwoUserId: number?,
	ReceiverUserId: number?
): ()
	if typeof(SourceUserId) ~= "number"
		or typeof(AnchorPosition) ~= "Vector3"
		or typeof(AnchorForward) ~= "Vector3"
		or typeof(ServerToken) ~= "number"
	then
		return
	end

	StartCutscene({
		SourceUserId = math.floor(SourceUserId + 0.5),
		AnchorPosition = AnchorPosition,
		AnchorForward = GetPlanarDirection(AnchorForward) or FALLBACK_FORWARD,
		Duration = if typeof(Duration) == "number" and Duration > ZERO then Duration else DEFAULT_CUTSCENE_DURATION,
		ServerToken = math.floor(ServerToken + 0.5),
		EnemyOneUserId = EnemyOneUserId,
		EnemyTwoUserId = EnemyTwoUserId,
		ReceiverUserId = ReceiverUserId,
	})
end

return Controller
