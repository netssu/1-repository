--!strict

local Lighting: Lighting = game:GetService("Lighting")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GameplayGuiVisibility: any = require(ReplicatedStorage.Modules.Game.GameplayGuiVisibility)
local CutsceneVisibility: any = require(ReplicatedStorage.Modules.Game.CutsceneVisibility)
local CameraController: any = require(ReplicatedStorage.Controllers.CameraController)
local FOVController: any = require(ReplicatedStorage.Controllers.FOVController)
local SkillAssetPreloader: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillAssetPreloader)
local CutsceneRigUtils: any = require(script.Parent.CutsceneRigUtils)
local SkillVfxUtils: any = require(script.Parent.SkillVfxUtils)

type TimelineEvent = {
	Frame: number,
	Action: "Emit" | "Enable" | "Disable" | "SetProperty" | "MarkerCode",
	Path: string?,
	Property: string?,
	Value: any?,
	Amount: number?,
	Code: string?,
}

type TimelineModule = {
	FPS: number?,
	MaxFrame: number?,
	Events: { TimelineEvent },
}

type ControllerConfig = {
	StyleAliases: { string },
	SceneAliases: { string },
	UseStyleFolderAsSceneContainer: boolean?,
	UseSourceCharacterAsActor: boolean?,
	HideSourceCharacter: boolean?,
	GuiContainerAliases: { string }?,
	WorkspaceSourceAliases: { string }?,
	VfxModelAliases: { string },
	PlayerModelAliases: { string },
	VictimModelAliases: { string }?,
	ActorWorkspaceRootNames: { string }?,
	ActorAlignmentPartName: string?,
	PrincipalContainerAliases: { string }?,
	PrincipalPlayerTemplateAliases: { string }?,
	AlignSceneRootToPrincipalPlayerTemplate: boolean?,
	CameraModelAliases: { string }?,
	CameraPartAliases: { string }?,
	PreserveCameraModelAnchors: boolean?,
	PlayerAnimationId: string?,
	VictimAnimationId: string?,
	CameraAnimationId: string?,
	PlayerAnimationAliases: { string }?,
	VictimAnimationAliases: { string }?,
	CameraAnimationAliases: { string }?,
	CleanupOnCameraAnimationEnd: boolean?,
	HideMatchPlayers: boolean?,
	WorkspaceRootAliases: { [string]: { string } }?,
	LightingRootAliases: { [string]: { string } }?,
	LightingSourceAliases: { string }?,
	SkipMarkerCodeIfContains: { string }?,
	AuthoredPlayerPosition: Vector3,
	AuthoredVfxModelPosition: Vector3,
	AuthoredCameraPosition: Vector3?,
	FixedVfxHeight: number?,
	CutsceneDuration: number,
	CameraBindName: string?,
	DisableCamera: boolean?,
	ShiftlockBlockerName: string,
	Timeline: TimelineModule,
}

type RuntimeState = {
	Active: boolean,
	Token: number,
	SourcePlayer: Player?,
	ShouldNotifyServer: boolean,
	ServerCompletionSent: boolean,
	Clones: { Instance },
	Connections: { RBXScriptConnection },
	Tracks: { AnimationTrack },
	WorkspaceRoots: { [string]: Instance },
	WorkspaceRootList: { Instance },
	LightingRoots: { [string]: Instance },
	LightingRootList: { Instance },
	GuiRoots: { [string]: Instance },
	GuiRootList: { Instance },
	PathCache: { [string]: Instance },
	HiddenBallAttrInstances: { Instance },
	HiddenBallAttrBefore: { [Instance]: boolean },
	HiddenBallAttrHadValue: { [Instance]: boolean },
	HiddenBallLocalTransparency: { [BasePart]: number },
	HiddenBallTransparency: { [Instance]: number },
	HiddenBallVisualTargets: { [Instance]: boolean },
	CachedBallData: Instance?,
	CachedBallContainer: Instance?,
	CachedBallVisual: Instance?,
	HiddenCharacterState: any,
	HiddenGameplayArtifactState: any,
	ActorModel: Model?,
	VictimModel: Model?,
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
	PrevCameraType: Enum.CameraType?,
	PrevCameraSubject: Instance?,
	PrevCameraCFrame: CFrame?,
	PrevCameraFov: number?,
	PrevMouseBehavior: Enum.MouseBehavior?,
	PrevMouseIconEnabled: boolean?,
	CameraBound: boolean,
	CameraReleased: boolean,
	CamPart: BasePart?,
	LastAppliedCutsceneFov: number?,
	LastGameplayArtifactRefreshAt: number,
	LastBallHiddenRefreshAt: number,
	MovedWorkspacePartCFrames: { [BasePart]: CFrame },
	EventBuckets: { [number]: { TimelineEvent } },
	TimelineStartAt: number,
	NextFrame: number,
}

type AwakenController = {
	HandleStatus: (Status: string, Duration: number) -> (),
	Cleanup: () -> (),
	PlayForPlayer: (SourcePlayer: Player, CutsceneDuration: number?) -> (),
}

local SceneBundleAwakenController = {}

local LocalPlayer: Player = Players.LocalPlayer

local ZERO: number = 0
local ONE: number = 1
local HALF: number = 0.5
local NEGATIVE_ONE: number = -1
local GROUND_RAYCAST_HEIGHT: number = 32
local GROUND_RAYCAST_DEPTH: number = 192
local ROOT_ALIGNMENT_PART_NAMES: { string } = {
	"HumanoidRootPart",
	"UpperTorso",
	"Torso",
}

local ASSETS_FOLDER_NAME: string = "Assets"
local SKILLS_FOLDER_NAME: string = "Skills"
local GAME_FOLDER_NAME: string = "Game"
local FOOTBALL_CONTAINER_NAME: string = "Football"
local FOOTBALL_VISUAL_NAME: string = "FootballVisual"
local BALL_DATA_NAME: string = "FTBallData"
local BALL_CUTSCENE_HIDDEN_ATTR: string = "FTBall_CutsceneHidden"

local DEFAULT_WALKSPEED: number = 16
local DEFAULT_JUMPPOWER: number = 50
local DEFAULT_JUMPHEIGHT: number = 7.2
local CAMERA_BIND_PRIORITY: number = Enum.RenderPriority.Camera.Value + ONE
local CLEANUP_PADDING: number = 0.1
local CLEANUP_VISUAL_SETTLE_FRAMES: number = 2
local CAMERA_RELEASE_MARKER: string = "__ReleaseCamera__"
local REMOTE_SOURCE_RESOLVE_TIMEOUT: number = 1
local REMOTE_SOURCE_RESOLVE_STEP: number = 0.05
local TRACK_PLAY_RETRY_ATTEMPTS: number = 6
local TRACK_PLAY_RETRY_DELAY: number = 0.08
local TRACK_START_EPSILON: number = 1 / 120
local TRACK_START_VERIFY_HEARTBEATS: number = 4
local FOV_UPDATE_EPSILON: number = 0.001
local GAMEPLAY_ARTIFACT_REFRESH_INTERVAL: number = 0.2
local HIDDEN_BALL_REFRESH_INTERVAL: number = 0.2

local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local ATTR_AWAKEN_CUTSCENE_ACTIVE: string = "FTAwakenCutsceneActive"
local ATTR_CUTSCENE_HUD_HIDDEN: string = "FTCutsceneHudHidden"

local function NewState(): RuntimeState
	return {
		Active = false,
		Token = 0,
		SourcePlayer = nil,
		ShouldNotifyServer = false,
		ServerCompletionSent = false,
		Clones = {},
		Connections = {},
		Tracks = {},
		WorkspaceRoots = {},
		WorkspaceRootList = {},
		LightingRoots = {},
		LightingRootList = {},
		GuiRoots = {},
		GuiRootList = {},
		PathCache = {},
		HiddenBallAttrInstances = {},
		HiddenBallAttrBefore = {},
		HiddenBallAttrHadValue = {},
		HiddenBallLocalTransparency = {},
		HiddenBallTransparency = {},
		HiddenBallVisualTargets = {},
		CachedBallData = nil,
		CachedBallContainer = nil,
		CachedBallVisual = nil,
		HiddenCharacterState = nil,
		HiddenGameplayArtifactState = nil,
		ActorModel = nil,
		VictimModel = nil,
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
		PrevCameraType = nil,
		PrevCameraSubject = nil,
		PrevCameraCFrame = nil,
		PrevCameraFov = nil,
		PrevMouseBehavior = nil,
		PrevMouseIconEnabled = nil,
		CameraBound = false,
		CameraReleased = false,
		CamPart = nil,
		LastAppliedCutsceneFov = nil,
		LastGameplayArtifactRefreshAt = NEGATIVE_ONE,
		LastBallHiddenRefreshAt = NEGATIVE_ONE,
		MovedWorkspacePartCFrames = {},
		EventBuckets = {},
		TimelineStartAt = ZERO,
		NextFrame = ZERO,
	}
end

local function GetPlayerGui(): PlayerGui?
	return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function ResolveSourceCharacter(PlayerItem: Player): (Model?, BasePart?)
	local Deadline: number = os.clock() + REMOTE_SOURCE_RESOLVE_TIMEOUT
	repeat
		local Character: Model? = PlayerItem.Character
		local Root: BasePart? = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if Character and Root then
			return Character, Root
		end
		task.wait(REMOTE_SOURCE_RESOLVE_STEP)
	until os.clock() >= Deadline

	local Character: Model? = PlayerItem.Character
	local Root: BasePart? = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return Character, Root
end

local function FindClosestVictimPlayer(SourcePlayer: Player, SourceRootPosition: Vector3): Player?
	local ClosestPlayer: Player? = nil
	local ClosestDistanceSq: number = math.huge

	for _, Candidate in Players:GetPlayers() do
		if Candidate == SourcePlayer then
			continue
		end

		local CandidateCharacter: Model? = Candidate.Character
		local CandidateRoot: BasePart? = CandidateCharacter
			and CandidateCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not CandidateRoot then
			continue
		end

		local DistanceSq: number = (CandidateRoot.Position - SourceRootPosition).Magnitude ^ 2
		if DistanceSq < ClosestDistanceSq then
			ClosestDistanceSq = DistanceSq
			ClosestPlayer = Candidate
		end
	end

	return ClosestPlayer
end

local function SplitPath(PathValue: string): { string }
	local Segments: { string } = {}
	for Segment in string.gmatch(PathValue, "[^%.]+") do
		local Clean: string = string.gsub(string.gsub(Segment, "^%s+", ""), "%s+$", "")
		if Clean ~= "" then
			table.insert(Segments, Clean)
		end
	end
	return Segments
end

local function FindChildBySegments(Current: Instance, Segments: { string }, StartIndex: number): (Instance?, number)
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

function SceneBundleAwakenController.new(Config: ControllerConfig): AwakenController
	local State: RuntimeState = NewState()
	local VfxOffset: Vector3 = Config.AuthoredVfxModelPosition - Config.AuthoredPlayerPosition
	local CachedSceneContainer: Instance? = nil
	local CachedVfxTemplate: Model? = nil
	local CachedVfxTemplateContainer: Instance? = nil
	local PreparedRuntimeVfxModel: Model? = nil
	local PreparedRuntimeVfxTemplate: Model? = nil
	local PreparingRuntimeVfxModel: boolean = false

	local function AppendUniqueInstance(Targets: { Instance }, Seen: { [Instance]: boolean }, Candidate: Instance?): ()
		if not Candidate or Seen[Candidate] then
			return
		end

		Seen[Candidate] = true
		table.insert(Targets, Candidate)
	end

	local function AppendUniqueBasePart(Targets: { BasePart }, Seen: { [BasePart]: boolean }, Candidate: Instance?): ()
		if not Candidate or not Candidate:IsA("BasePart") or Seen[Candidate] then
			return
		end

		Seen[Candidate] = true
		table.insert(Targets, Candidate)
	end

	local CleanupState: (NotifyServer: boolean?) -> ()

	local function GetCameraBindName(): string
		local BaseName: string = Config.CameraBindName or Config.ShiftlockBlockerName or "AwakenCamera"
		return BaseName .. "_" .. tostring(LocalPlayer.UserId)
	end

	local function GetFovRequestId(): string
		return GetCameraBindName() .. "::FOV"
	end

	local function ApplyCutsceneFov(Value: number, TweenInfoOverride: TweenInfo?): ()
		if
			State.LastAppliedCutsceneFov ~= nil
			and math.abs(State.LastAppliedCutsceneFov - Value) <= FOV_UPDATE_EPSILON
		then
			return
		end

		State.LastAppliedCutsceneFov = Value
		FOVController.AddRequest(GetFovRequestId(), Value, nil, {
			TweenInfo = TweenInfoOverride or TweenInfo.new(0),
		})
	end

	local function ClearCutsceneFov(): ()
		State.LastAppliedCutsceneFov = nil
		FOVController.RemoveRequest(GetFovRequestId())
	end

	local function IsTokenActive(Token: number): boolean
		return State.Active and State.Token == Token
	end

	local function TrackClone(Clone: Instance): ()
		table.insert(State.Clones, Clone)
	end

	local function TrackConnection(Connection: RBXScriptConnection): ()
		table.insert(State.Connections, Connection)
	end

	local function TrackAnimationTrack(Track: AnimationTrack): ()
		table.insert(State.Tracks, Track)
	end

	local RegisterWorkspaceRootTree: (Root: Instance) -> ()

	local function RegisterActorWorkspaceRoots(ActorModel: Model): ()
		RegisterWorkspaceRootTree(ActorModel)

		local ActorWorkspaceRootNames: { string }? = Config.ActorWorkspaceRootNames
		if not ActorWorkspaceRootNames then
			return
		end

		for _, RootName in ActorWorkspaceRootNames do
			State.WorkspaceRoots[RootName] = ActorModel
		end
	end

	local function GetPartBottomY(Part: BasePart): number
		local HalfSize: Vector3 = Part.Size * HALF
		local LowestY: number = math.huge

		for _, XSign in { -ONE, ONE } do
			for _, YSign in { -ONE, ONE } do
				for _, ZSign in { -ONE, ONE } do
					local Corner: Vector3 = Part.CFrame:PointToWorldSpace(
						Vector3.new(HalfSize.X * XSign, HalfSize.Y * YSign, HalfSize.Z * ZSign)
					)
					if Corner.Y < LowestY then
						LowestY = Corner.Y
					end
				end
			end
		end

		return LowestY
	end

	local function ShouldUsePartForGrounding(Part: BasePart, IgnoredParts: { [Instance]: boolean }?): boolean
		if IgnoredParts and IgnoredParts[Part] then
			return false
		end
		if Part.Name == "HumanoidRootPart" then
			return false
		end
		if Part:FindFirstAncestorWhichIsA("Accessory") then
			return false
		end
		if Part:FindFirstAncestorOfClass("Tool") then
			return false
		end
		return true
	end

	local function GetModelBottomY(Model: Model, IgnoredParts: { [Instance]: boolean }?): number?
		local LowestY: number? = nil

		for _, Descendant in Model:GetDescendants() do
			if not Descendant:IsA("BasePart") then
				continue
			end
			if not ShouldUsePartForGrounding(Descendant, IgnoredParts) then
				continue
			end

			local PartBottomY: number = GetPartBottomY(Descendant)
			if LowestY == nil or PartBottomY < LowestY then
				LowestY = PartBottomY
			end
		end

		return LowestY
	end

	local function GetRootToGroundOffset(
		Model: Model,
		RootPart: BasePart,
		IgnoredParts: { [Instance]: boolean }?
	): number?
		local BottomY: number? = GetModelBottomY(Model, IgnoredParts)
		if BottomY == nil then
			return nil
		end
		return RootPart.Position.Y - BottomY
	end

	local function GetGroundYAtPosition(Position: Vector3, Filter: { Instance }): number?
		local Params: RaycastParams = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.IgnoreWater = true

		local FilterDescendantsInstances: { Instance } = {}
		for _, Item in Filter do
			table.insert(FilterDescendantsInstances, Item)
		end
		if workspace.CurrentCamera then
			table.insert(FilterDescendantsInstances, workspace.CurrentCamera)
		end
		Params.FilterDescendantsInstances = FilterDescendantsInstances

		local Origin: Vector3 = Position + Vector3.new(ZERO, GROUND_RAYCAST_HEIGHT, ZERO)
		local Result: RaycastResult? =
			workspace:Raycast(Origin, Vector3.new(ZERO, -GROUND_RAYCAST_DEPTH, ZERO), Params)
		if Result then
			return Result.Position.Y
		end
		return nil
	end

	local function BuildTargetRootCFrame(
		PlayerTemplate: Model,
		PositionPart: BasePart,
		Character: Model,
		Root: BasePart
	): CFrame
		local TargetPosition: Vector3 = PositionPart.Position
		local CharacterGroundOffset: number? = GetRootToGroundOffset(Character, Root, nil)

		if CharacterGroundOffset ~= nil then
			local IgnoredTemplateParts: { [Instance]: boolean } = {
				[PositionPart] = true,
			}
			local TemplateGroundOffset: number? = GetRootToGroundOffset(PlayerTemplate, PositionPart, IgnoredTemplateParts)

			if TemplateGroundOffset ~= nil then
				TargetPosition = Vector3.new(
					TargetPosition.X,
					PositionPart.Position.Y - TemplateGroundOffset + CharacterGroundOffset,
					TargetPosition.Z
				)
			else
				local GroundY: number? = GetGroundYAtPosition(TargetPosition, { Character, PlayerTemplate })
				if GroundY ~= nil then
					TargetPosition = Vector3.new(TargetPosition.X, GroundY + CharacterGroundOffset, TargetPosition.Z)
				end
			end
		end

		return CFrame.fromMatrix(
			TargetPosition,
			PositionPart.CFrame.XVector,
			PositionPart.CFrame.YVector,
			PositionPart.CFrame.ZVector
		)
	end

	local function AlignCharacterToPositionPart(Character: Model, PlayerTemplate: Model): Vector3?
		local Root: BasePart? = CutsceneRigUtils.FindModelRootPart(Character)
		if not Root then
			return nil
		end

		local PositionPartName: string = Config.ActorAlignmentPartName or "Position"
		local PositionPart: Instance? = PlayerTemplate:FindFirstChild(PositionPartName, true)
		if not PositionPart or not PositionPart:IsA("BasePart") then
			return nil
		end

		local TargetRootCFrame: CFrame = BuildTargetRootCFrame(PlayerTemplate, PositionPart, Character, Root)
		local CharacterPivot: CFrame = Character:GetPivot()
		local RootOffset: CFrame = CharacterPivot:ToObjectSpace(Root.CFrame)
		local TargetCharacterPivot: CFrame = TargetRootCFrame * RootOffset:Inverse()
		Character:PivotTo(TargetCharacterPivot)
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
		return PositionPart.Position
	end

	local function SubtreeHasVisualEffects(RootInstance: Instance): boolean
		if RootInstance:IsA("ParticleEmitter")
			or RootInstance:IsA("Beam")
			or RootInstance:IsA("Trail")
			or RootInstance:IsA("Light")
		then
			return true
		end

		for _, Descendant in RootInstance:GetDescendants() do
			if Descendant:IsA("ParticleEmitter")
				or Descendant:IsA("Beam")
				or Descendant:IsA("Trail")
				or Descendant:IsA("Light")
			then
				return true
			end
		end

		return false
	end

	local function ShouldCloneVisualEffectChild(Child: Instance): boolean
		if Child:IsA("BasePart")
			or Child:IsA("Humanoid")
			or Child:IsA("Animator")
			or Child:IsA("AnimationController")
			or Child:IsA("Motor6D")
			or Child:IsA("Weld")
			or Child:IsA("WeldConstraint")
			or Child:IsA("ManualWeld")
			or Child:IsA("Decal")
			or Child:IsA("Texture")
		then
			return false
		end

		return SubtreeHasVisualEffects(Child)
	end

	local function CloneVisualCharacterEffects(SourceCharacter: Model, TargetCharacter: Model): ()
		local PositionPartName: string = Config.ActorAlignmentPartName or "Position"

		for _, SourcePart in SourceCharacter:GetDescendants() do
			if not SourcePart:IsA("BasePart") then
				continue
			end
			if SourcePart.Name == PositionPartName then
				continue
			end

			local TargetPart: Instance? = TargetCharacter:FindFirstChild(SourcePart.Name, true)
			if not TargetPart or not TargetPart:IsA("BasePart") then
				continue
			end

			for _, SourceChild in SourcePart:GetChildren() do
				if not ShouldCloneVisualEffectChild(SourceChild) then
					continue
				end

				local Clone: Instance = SourceChild:Clone()
				Clone.Parent = TargetPart
				TrackClone(Clone)
			end
		end
	end

	local function ResolveRuntimeActorReferenceModel(RuntimeVfxModel: Model): Model?
		local ActorModelInstance: Instance? =
			CutsceneRigUtils.FindChildByAliases(RuntimeVfxModel, Config.PlayerModelAliases, true)
		if ActorModelInstance and ActorModelInstance:IsA("Model") then
			return ActorModelInstance
		end
		return nil
	end

	local function ResolvePrincipalPlayerTemplate(SceneContainer: Instance): Model?
		local PrincipalContainerAliases: { string }? = Config.PrincipalContainerAliases
		local PrincipalContainer: Instance? = nil
		if PrincipalContainerAliases then
			PrincipalContainer = CutsceneRigUtils.FindChildByAliases(SceneContainer, PrincipalContainerAliases, true)
		else
			PrincipalContainer = CutsceneRigUtils.FindChildByAliases(SceneContainer, { "Principal" }, true)
		end

		local TemplateAliases: { string } = Config.PrincipalPlayerTemplateAliases or Config.PlayerModelAliases
		local SearchRoot: Instance = PrincipalContainer or SceneContainer
		local PlayerTemplate: Instance? = CutsceneRigUtils.FindChildByAliases(SearchRoot, TemplateAliases, true)
		if PlayerTemplate and PlayerTemplate:IsA("Model") then
			return PlayerTemplate
		end

		return nil
	end

	local function AlignSceneRootToPrincipalPlayerTemplate(
		SceneContainer: Instance,
		SceneRoot: Model,
		Character: Model
	): Vector3?
		local Root: BasePart? = CutsceneRigUtils.FindModelRootPart(Character)
		if not Root then
			return nil
		end

		local PlayerTemplate: Model? = ResolvePrincipalPlayerTemplate(SceneContainer)
		if not PlayerTemplate then
			return nil
		end

		local PositionPartName: string = Config.ActorAlignmentPartName or "Position"
		local PositionPart: Instance? = PlayerTemplate:FindFirstChild(PositionPartName, true)
		if not PositionPart or not PositionPart:IsA("BasePart") then
			return nil
		end

		local TargetRootCFrame: CFrame = BuildTargetRootCFrame(PlayerTemplate, PositionPart, Character, Root)
		local ScenePivot: CFrame = SceneRoot:GetPivot()
		local RootOffset: CFrame = ScenePivot:ToObjectSpace(Root.CFrame)
		SceneRoot:PivotTo(TargetRootCFrame * RootOffset:Inverse())
		return PositionPart.Position
	end

	function RegisterWorkspaceRootTree(Root: Instance): ()
		table.insert(State.WorkspaceRootList, Root)
		State.WorkspaceRoots[Root.Name] = Root
	end

	local function RegisterLightingRootTree(Root: Instance): ()
		table.insert(State.LightingRootList, Root)
		State.LightingRoots[Root.Name] = Root
	end

	local function RegisterGuiRootTree(Root: Instance): ()
		table.insert(State.GuiRootList, Root)
		State.GuiRoots[Root.Name] = Root
	end

	local function EnforceGameplayHudArtifactsHidden(): ()
		State.HiddenGameplayArtifactState =
			CutsceneVisibility.HideGameplayArtifacts(LocalPlayer, State.HiddenGameplayArtifactState)
	end

	local function RefreshGameplayHudArtifactsHidden(Force: boolean?): ()
		local Now: number = os.clock()
		if Force ~= true and State.LastGameplayArtifactRefreshAt >= ZERO then
			if Now - State.LastGameplayArtifactRefreshAt < GAMEPLAY_ARTIFACT_REFRESH_INTERVAL then
				return
			end
		end

		State.LastGameplayArtifactRefreshAt = Now
		EnforceGameplayHudArtifactsHidden()
	end

	local function WaitForAnimationRigReady(MaxAttempts: number): ()
		for _ = 1, MaxAttempts do
			RunService.Heartbeat:Wait()
		end
	end

	local function EnsureTrackPlaying(Track: AnimationTrack, Token: number): ()
		local function TryPlay(AttemptsLeft: number): ()
			if AttemptsLeft <= ZERO or not IsTokenActive(Token) or Track.Parent == nil then
				return
			end

			local BaselineTimePosition: number = Track.TimePosition
			pcall(function()
				if Track.IsPlaying then
					Track:AdjustSpeed(1)
				else
					Track:Play(0, 1, 1)
				end
			end)

			task.spawn(function()
				for _ = 1, TRACK_START_VERIFY_HEARTBEATS do
					if not IsTokenActive(Token) or Track.Parent == nil then
						return
					end

					RunService.Heartbeat:Wait()
					if Track.TimePosition > math.max(BaselineTimePosition, TRACK_START_EPSILON) then
						return
					end
				end

				if not IsTokenActive(Token) or Track.Parent == nil then
					return
				end
				if Track.TimePosition > math.max(BaselineTimePosition, TRACK_START_EPSILON) then
					return
				end

				pcall(function()
					Track:Stop(0)
				end)

				task.delay(TRACK_PLAY_RETRY_DELAY, function()
					TryPlay(AttemptsLeft - ONE)
				end)
			end)
		end

		TryPlay(TRACK_PLAY_RETRY_ATTEMPTS)
	end

	local function ResolveAnimationTemplate(SceneContainer: Instance, Aliases: { string }?): Animation?
		if not Aliases then
			return nil
		end
		return CutsceneRigUtils.FindAnimationByAliases(SceneContainer, Aliases, true)
	end

	local function TrackBallHiddenAttributeInstance(InstanceItem: Instance): ()
		for _, TrackedInstance in State.HiddenBallAttrInstances do
			if TrackedInstance == InstanceItem then
				return
			end
		end

		local PreviousValue: any = InstanceItem:GetAttribute(BALL_CUTSCENE_HIDDEN_ATTR)
		State.HiddenBallAttrBefore[InstanceItem] = PreviousValue == true
		State.HiddenBallAttrHadValue[InstanceItem] = PreviousValue ~= nil
		table.insert(State.HiddenBallAttrInstances, InstanceItem)
	end

	local function SetBallVisualHidden(Target: Instance): ()
		if Target:IsA("BasePart") then
			if State.HiddenBallLocalTransparency[Target] == nil then
				State.HiddenBallLocalTransparency[Target] = Target.LocalTransparencyModifier
			end
			Target.LocalTransparencyModifier = ONE
			return
		end

		if Target:IsA("Decal") or Target:IsA("Texture") then
			if State.HiddenBallTransparency[Target] == nil then
				State.HiddenBallTransparency[Target] = Target.Transparency
			end
			Target.Transparency = ONE
		end
	end

	local function HideBallVisualTree(Target: Instance?): ()
		if not Target then
			return
		end
		if State.HiddenBallVisualTargets[Target] and Target.Parent ~= nil then
			return
		end

		State.HiddenBallVisualTargets[Target] = true

		SetBallVisualHidden(Target)
		for _, Descendant in Target:GetDescendants() do
			SetBallVisualHidden(Descendant)
		end
	end

	local function ResolveBallContainer(): Instance?
		local CachedBallContainer: Instance? = State.CachedBallContainer
		if CachedBallContainer and CachedBallContainer.Parent ~= nil then
			return CachedBallContainer
		end

		local GameFolder: Instance? = workspace:FindFirstChild(GAME_FOLDER_NAME)
		if GameFolder then
			local FootballContainer: Instance? = GameFolder:FindFirstChild(FOOTBALL_CONTAINER_NAME)
			if FootballContainer then
				State.CachedBallContainer = FootballContainer
				return FootballContainer
			end
		end

		local RealBall: any = rawget(_G, "FT_REAL_BALL")
		if typeof(RealBall) == "Instance" and RealBall.Parent ~= nil then
			State.CachedBallContainer = RealBall
			return RealBall
		end

		local FoundBallContainer: Instance? = workspace:FindFirstChild(FOOTBALL_CONTAINER_NAME, true)
		State.CachedBallContainer = FoundBallContainer
		return FoundBallContainer
	end

	local function ResolveBallVisual(): Instance?
		local CachedBallVisual: Instance? = State.CachedBallVisual
		if CachedBallVisual and CachedBallVisual.Parent ~= nil then
			return CachedBallVisual
		end

		local BallContainer: Instance? = ResolveBallContainer()
		if BallContainer then
			local ContainerVisual: Instance? = BallContainer:FindFirstChild(FOOTBALL_VISUAL_NAME)
			if ContainerVisual then
				State.CachedBallVisual = ContainerVisual
				return ContainerVisual
			end
		end

		local VisualBall: any = rawget(_G, "FT_VISUAL_BALL")
		if typeof(VisualBall) == "Instance" and VisualBall.Parent ~= nil then
			State.CachedBallVisual = VisualBall
			return VisualBall
		end

		local FoundBallVisual: Instance? = workspace:FindFirstChild(FOOTBALL_VISUAL_NAME, true)
		State.CachedBallVisual = FoundBallVisual
		return FoundBallVisual
	end

	local function MaintainHiddenBall(): ()
		local BallData: Instance? = State.CachedBallData
		if not BallData or BallData.Parent == nil then
			BallData = ReplicatedStorage:FindFirstChild(BALL_DATA_NAME)
			State.CachedBallData = BallData
		end

		if BallData then
			TrackBallHiddenAttributeInstance(BallData)
			if BallData:GetAttribute(BALL_CUTSCENE_HIDDEN_ATTR) ~= true then
				BallData:SetAttribute(BALL_CUTSCENE_HIDDEN_ATTR, true)
			end
		end

		local BallContainer: Instance? = ResolveBallContainer()
		if BallContainer then
			TrackBallHiddenAttributeInstance(BallContainer)
			if BallContainer:GetAttribute(BALL_CUTSCENE_HIDDEN_ATTR) ~= true then
				BallContainer:SetAttribute(BALL_CUTSCENE_HIDDEN_ATTR, true)
			end
			HideBallVisualTree(BallContainer)
		end

		local BallVisual: Instance? = ResolveBallVisual()
		if BallVisual and BallVisual ~= BallContainer then
			HideBallVisualTree(BallVisual)
		end
	end

	local function RefreshHiddenBall(Force: boolean?): ()
		local Now: number = os.clock()
		if Force ~= true and State.LastBallHiddenRefreshAt >= ZERO then
			if Now - State.LastBallHiddenRefreshAt < HIDDEN_BALL_REFRESH_INTERVAL then
				return
			end
		end

		State.LastBallHiddenRefreshAt = Now
		MaintainHiddenBall()
	end

	local function RestoreHiddenBall(): ()
		for _, InstanceItem in State.HiddenBallAttrInstances do
			if InstanceItem.Parent == nil then
				continue
			end

			if State.HiddenBallAttrHadValue[InstanceItem] then
				InstanceItem:SetAttribute(BALL_CUTSCENE_HIDDEN_ATTR, State.HiddenBallAttrBefore[InstanceItem] == true)
			else
				InstanceItem:SetAttribute(BALL_CUTSCENE_HIDDEN_ATTR, nil)
			end
		end
		table.clear(State.HiddenBallAttrInstances)
		table.clear(State.HiddenBallAttrBefore)
		table.clear(State.HiddenBallAttrHadValue)

		for Part, PreviousModifier in State.HiddenBallLocalTransparency do
			if Part.Parent ~= nil then
				Part.LocalTransparencyModifier = PreviousModifier
			end
		end
		table.clear(State.HiddenBallLocalTransparency)

		for InstanceItem, PreviousTransparency in State.HiddenBallTransparency do
			if InstanceItem.Parent == nil then
				continue
			end

			if InstanceItem:IsA("Decal") or InstanceItem:IsA("Texture") then
				InstanceItem.Transparency = PreviousTransparency
			end
		end
		table.clear(State.HiddenBallTransparency)
		table.clear(State.HiddenBallVisualTargets)
		State.CachedBallData = nil
		State.CachedBallContainer = nil
		State.CachedBallVisual = nil
	end

	local function SetLocalAwakenCutsceneActive(Active: boolean): ()
		LocalPlayer:SetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE, Active)
		local Character: Model? = LocalPlayer.Character
		if Character then
			Character:SetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE, Active)
		end
		if Active then
			GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
		end
	end

	local function SetLocalCutsceneHudHidden(Active: boolean): ()
		LocalPlayer:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, Active)
		local Character: Model? = LocalPlayer.Character
		if Character then
			Character:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, Active)
		end
		if Active then
			GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
		end
	end

	local function SetShiftlockBlocked(Blocked: boolean): ()
		if not CameraController then
			return
		end
		if CameraController.SetShiftlockBlocked then
			CameraController:SetShiftlockBlocked(Config.ShiftlockBlockerName, Blocked)
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

	local function NotifyServerAwakenCutsceneEnded(): ()
		if State.ServerCompletionSent then
			return
		end
		local function ResolveCutscenePart(Model: Model?): BasePart?
			if not Model then
				return nil
			end

			local RootPart: BasePart? = CutsceneRigUtils.FindModelRootPart(Model)
			if RootPart then
				return RootPart
			end

			for _, PartName in ROOT_ALIGNMENT_PART_NAMES do
				local Part: Instance? = Model:FindFirstChild(PartName, true)
				if Part and Part:IsA("BasePart") then
					return Part
				end
			end
			return Model:FindFirstChildWhichIsA("BasePart", true)
		end

		local FinalCFrame: CFrame? = nil
		local FinalPart: BasePart? = ResolveCutscenePart(State.ActorModel)
		if FinalPart then
			FinalCFrame = FinalPart.CFrame
		elseif State.LocalSourceRoot and State.LocalSourceRoot.Parent ~= nil then
			FinalCFrame = State.LocalSourceRoot.CFrame
		else
			local Character: Model? = LocalPlayer.Character
			local CharacterPart: BasePart? = Character and ResolveCutscenePart(Character) or nil
			if CharacterPart then
				FinalCFrame = CharacterPart.CFrame
			elseif Character then
				FinalCFrame = Character:GetPivot()
			end
		end
		if not FinalCFrame then
			return
		end
		State.ServerCompletionSent = true
		Packets.AwakenCutsceneEnded:Fire(FinalCFrame)
	end

	local function ApplyFinalLocalSourcePosition(): ()
		if not State.ShouldNotifyServer then
			return
		end
		local Character: Model? = LocalPlayer.Character
		if not Character then
			return
		end

		local AlignmentPart: BasePart? = CutsceneRigUtils.FindModelRootPart(Character)
		if not AlignmentPart then
			for _, PartName in ROOT_ALIGNMENT_PART_NAMES do
				local Part: Instance? = Character:FindFirstChild(PartName, true)
				if Part and Part:IsA("BasePart") then
					AlignmentPart = Part
					break
				end
			end
		end
		if not AlignmentPart then
			AlignmentPart = Character:FindFirstChildWhichIsA("BasePart", true)
		end
		local ActorModel: Model? = State.ActorModel
		if not AlignmentPart or not ActorModel then
			return
		end

		local ActorPart: BasePart? = CutsceneRigUtils.FindModelRootPart(ActorModel)
		if not ActorPart then
			for _, PartName in ROOT_ALIGNMENT_PART_NAMES do
				local Part: Instance? = ActorModel:FindFirstChild(PartName, true)
				if Part and Part:IsA("BasePart") then
					ActorPart = Part
					break
				end
			end
		end
		if not ActorPart then
			ActorPart = ActorModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if not ActorPart then
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

	local function HasAlias(Name: string, Aliases: { string }): boolean
		local NormalizedName: string = CutsceneRigUtils.NormalizeName(Name)
		for _, Alias in Aliases do
			if CutsceneRigUtils.NormalizeName(Alias) == NormalizedName then
				return true
			end
		end
		return false
	end

	local function GetVfxTemplate(Container: Instance): Model?
		if CachedVfxTemplateContainer == Container and CachedVfxTemplate and CachedVfxTemplate.Parent ~= nil then
			return CachedVfxTemplate
		end

		local Candidate: Instance? = CutsceneRigUtils.FindChildByAliases(Container, Config.VfxModelAliases, false)
		if not Candidate then
			Candidate = CutsceneRigUtils.FindChildByAliases(Container, Config.VfxModelAliases, true)
		end
		if Candidate and Candidate:IsA("Model") then
			CachedVfxTemplateContainer = Container
			CachedVfxTemplate = Candidate
			return Candidate
		end

		CachedVfxTemplateContainer = Container
		CachedVfxTemplate = nil
		return nil
	end

	local function IsValidSceneContainer(Container: Instance): boolean
		local VfxTemplate: Model? = GetVfxTemplate(Container)
		if not VfxTemplate then
			return false
		end

		if Config.UseSourceCharacterAsActor == true then
			return true
		end

		local PlayerModel: Instance? = CutsceneRigUtils.FindChildByAliases(VfxTemplate, Config.PlayerModelAliases, true)
		if not PlayerModel or not PlayerModel:IsA("Model") then
			return false
		end

		return true
	end

	local function FindSceneContainer(): Instance?
		if
			CachedSceneContainer
			and CachedSceneContainer.Parent ~= nil
			and IsValidSceneContainer(CachedSceneContainer)
		then
			return CachedSceneContainer
		end

		CachedSceneContainer = nil

		local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
		local SkillsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(SKILLS_FOLDER_NAME)
		if SkillsFolder then
			local StyleFolder: Instance? = CutsceneRigUtils.FindChildByAliases(SkillsFolder, Config.StyleAliases, false)
			if StyleFolder then
				if Config.UseStyleFolderAsSceneContainer == true and IsValidSceneContainer(StyleFolder) then
					CachedSceneContainer = StyleFolder
					return StyleFolder
				end

				local SceneFolder: Instance? = CutsceneRigUtils.FindChildByAliases(StyleFolder, Config.SceneAliases, false)
				if SceneFolder and IsValidSceneContainer(SceneFolder) then
					CachedSceneContainer = SceneFolder
					return SceneFolder
				end
			end
		end

		for _, SearchRoot in { ReplicatedStorage, workspace } do
			if Config.UseStyleFolderAsSceneContainer == true then
				for _, Descendant in SearchRoot:GetDescendants() do
					if not HasAlias(Descendant.Name, Config.StyleAliases) then
						continue
					end

					if IsValidSceneContainer(Descendant) then
						CachedSceneContainer = Descendant
						return Descendant
					end
				end
			end

			for _, Descendant in SearchRoot:GetDescendants() do
				if not HasAlias(Descendant.Name, Config.SceneAliases) then
					continue
				end

				local Parent: Instance? = Descendant.Parent
				if not Parent or not HasAlias(Parent.Name, Config.StyleAliases) then
					continue
				end

				if IsValidSceneContainer(Descendant) then
					CachedSceneContainer = Descendant
					return Descendant
				end
			end
		end

		return nil
	end

	local function DestroyPreparedRuntimeVfxModel(): ()
		if PreparedRuntimeVfxModel then
			PreparedRuntimeVfxModel:Destroy()
			PreparedRuntimeVfxModel = nil
		end
		PreparedRuntimeVfxTemplate = nil
		PreparingRuntimeVfxModel = false
	end

	local function PrepareRuntimeVfxModelAsync(): ()
		if PreparingRuntimeVfxModel then
			return
		end
		if PreparedRuntimeVfxModel and PreparedRuntimeVfxModel.Parent == nil then
			return
		end

		local SceneContainer: Instance? = FindSceneContainer()
		if not SceneContainer then
			return
		end

		local VfxTemplate: Model? = GetVfxTemplate(SceneContainer)
		if not VfxTemplate then
			return
		end

		PreparingRuntimeVfxModel = true
		task.spawn(function()
			local Clone: Model = VfxTemplate:Clone()
			if not PreparingRuntimeVfxModel then
				Clone:Destroy()
				return
			end

			DestroyPreparedRuntimeVfxModel()
			PreparedRuntimeVfxModel = Clone
			PreparedRuntimeVfxTemplate = VfxTemplate
			PreparingRuntimeVfxModel = false
		end)
	end

	local function HideSourceCharacter(SourcePlayer: Player): ()
		if Config.HideSourceCharacter == false then
			return
		end

		if Config.HideMatchPlayers == true then
			State.HiddenCharacterState =
				CutsceneVisibility.HidePlayers(Players:GetPlayers(), State.HiddenCharacterState, {
					HideEffects = true,
					HideBillboards = true,
				})
			return
		end

		State.HiddenCharacterState = CutsceneVisibility.HidePlayers({ SourcePlayer }, State.HiddenCharacterState, {
			HideEffects = true,
			HideBillboards = true,
		})
	end

	local function FreezeLocalSourceCharacter(SourcePlayer: Player): ()
		if SourcePlayer ~= LocalPlayer then
			return
		end

		local Character: Model? = LocalPlayer.Character
		if not Character then
			return
		end

		State.LocalPlayerSkillLockedBefore = LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true
		State.LocalCharacterSkillLockedBefore = Character:GetAttribute(ATTR_SKILL_LOCKED) == true
		LocalPlayer:SetAttribute(ATTR_SKILL_LOCKED, true)
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
		local Character: Model? = LocalPlayer.Character
		local IsLocalAwakenSource: boolean = State.SourcePlayer == LocalPlayer or State.ShouldNotifyServer
		local ShouldForceReleaseLocalCharacter: boolean = IsLocalAwakenSource
			or State.LocalSourceRoot ~= nil
			or State.LocalSourceHumanoid ~= nil
			or State.LocalPlayerSkillLockedBefore ~= nil
			or State.LocalCharacterSkillLockedBefore ~= nil

		if Character and (State.LocalCharacterSkillLockedBefore ~= nil or ShouldForceReleaseLocalCharacter) then
			if IsLocalAwakenSource then
				Character:SetAttribute(ATTR_SKILL_LOCKED, false)
			else
				Character:SetAttribute(ATTR_SKILL_LOCKED, State.LocalCharacterSkillLockedBefore == true)
			end
		end
		if State.LocalPlayerSkillLockedBefore ~= nil or ShouldForceReleaseLocalCharacter then
			if IsLocalAwakenSource then
				LocalPlayer:SetAttribute(ATTR_SKILL_LOCKED, false)
			else
				LocalPlayer:SetAttribute(ATTR_SKILL_LOCKED, State.LocalPlayerSkillLockedBefore == true)
			end
		end

		local function RestoreRootState(Root: BasePart?): ()
			if not Root or Root.Parent == nil then
				return
			end

			Root.AssemblyLinearVelocity = Vector3.zero
			Root.AssemblyAngularVelocity = Vector3.zero
			if IsLocalAwakenSource then
				Root.Anchored = false
			elseif State.LocalSourceRootAnchoredBefore ~= nil then
				Root.Anchored = State.LocalSourceRootAnchoredBefore
			else
				Root.Anchored = false
			end
		end

		local function RestoreHumanoidState(HumanoidInstance: Humanoid?): ()
			if not HumanoidInstance or HumanoidInstance.Parent == nil then
				return
			end

			if State.LocalSourceHumanoidUseJumpPowerBefore ~= nil then
				HumanoidInstance.UseJumpPower = State.LocalSourceHumanoidUseJumpPowerBefore
			end

			if IsLocalAwakenSource then
				HumanoidInstance.AutoRotate = true
			elseif State.LocalSourceHumanoidAutoRotateBefore ~= nil then
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
				if
					State.LocalSourceHumanoidJumpPowerBefore ~= nil
					and State.LocalSourceHumanoidJumpPowerBefore > ZERO
				then
					HumanoidInstance.JumpPower = State.LocalSourceHumanoidJumpPowerBefore
				else
					HumanoidInstance.JumpPower = DEFAULT_JUMPPOWER
				end
			else
				if
					State.LocalSourceHumanoidJumpHeightBefore ~= nil
					and State.LocalSourceHumanoidJumpHeightBefore > ZERO
				then
					HumanoidInstance.JumpHeight = State.LocalSourceHumanoidJumpHeightBefore
				elseif HumanoidInstance.JumpHeight <= ZERO then
					HumanoidInstance.JumpHeight = DEFAULT_JUMPHEIGHT
				end
			end

			HumanoidInstance.PlatformStand = false
			HumanoidInstance.Sit = false
			HumanoidInstance:Move(Vector3.zero, false)
			pcall(function()
				HumanoidInstance:ChangeState(Enum.HumanoidStateType.GettingUp)
				HumanoidInstance:ChangeState(Enum.HumanoidStateType.Running)
			end)
			pcall(function()
				HumanoidInstance:ChangeState(Enum.HumanoidStateType.Landed)
			end)
		end

		local Root: BasePart? = State.LocalSourceRoot
		if (not Root or Root.Parent == nil) and Character then
			Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
		RestoreRootState(State.LocalSourceRoot)
		if Root ~= State.LocalSourceRoot then
			RestoreRootState(Root)
		end

		local HumanoidInstance: Humanoid? = State.LocalSourceHumanoid
		if (not HumanoidInstance or HumanoidInstance.Parent == nil) and Character then
			HumanoidInstance = Character:FindFirstChildOfClass("Humanoid")
		end
		RestoreHumanoidState(State.LocalSourceHumanoid)
		if HumanoidInstance ~= State.LocalSourceHumanoid then
			RestoreHumanoidState(HumanoidInstance)
		end

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

	local function ResolveConfiguredAliases(Lookup: { [string]: { string } }?, Name: string): { string }?
		if not Lookup then
			return nil
		end

		local DirectAliases: { string }? = Lookup[Name]
		if DirectAliases then
			return DirectAliases
		end

		local NormalizedName: string = CutsceneRigUtils.NormalizeName(Name)
		for Key, Aliases in Lookup do
			if CutsceneRigUtils.NormalizeName(Key) == NormalizedName then
				return Aliases
			end
		end

		return nil
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

		local ConfiguredAliases: { string }? = ResolveConfiguredAliases(Config.WorkspaceRootAliases, Name)
		if ConfiguredAliases then
			for Index = #State.WorkspaceRootList, ONE, NEGATIVE_ONE do
				local RootInstance: Instance = State.WorkspaceRootList[Index]
				if RootInstance.Parent == nil then
					continue
				end

				local AliasMatch: Instance? = CutsceneRigUtils.FindChildByAliases(RootInstance, ConfiguredAliases, true)
				if AliasMatch then
					State.WorkspaceRoots[Name] = AliasMatch
					return AliasMatch
				end
			end

			local AliasRoot: Instance? = CutsceneRigUtils.FindChildByAliases(workspace, ConfiguredAliases, true)
			if AliasRoot then
				State.WorkspaceRoots[Name] = AliasRoot
				return AliasRoot
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

	local function RestoreMovedWorkspaceParts(): ()
		for Part, OriginalCFrame in State.MovedWorkspacePartCFrames do
			if Part.Parent == nil then
				continue
			end
			Part.CFrame = OriginalCFrame
		end
		table.clear(State.MovedWorkspacePartCFrames)
	end

	local function MoveWorkspaceRootByOffset(RootName: string, OffsetY: number): ()
		local Root: Instance? = ResolveWorkspaceRootByName(RootName)
		if not Root then
			return
		end

		local Delta: Vector3 = Vector3.new(ZERO, OffsetY, ZERO)
		local function StoreAndMove(Candidate: BasePart): ()
			if State.MovedWorkspacePartCFrames[Candidate] == nil then
				State.MovedWorkspacePartCFrames[Candidate] = Candidate.CFrame
			end
			Candidate.CFrame += Delta
		end

		if Root:IsA("BasePart") then
			StoreAndMove(Root)
		end

		for _, Descendant in Root:GetDescendants() do
			if Descendant:IsA("BasePart") then
				StoreAndMove(Descendant)
			end
		end
	end

	local function ResolveGuiRootByName(Name: string): Instance?
		local Cached: Instance? = State.GuiRoots[Name]
		if Cached and Cached.Parent ~= nil then
			return Cached
		end

		local PlayerGui: PlayerGui? = GetPlayerGui()
		if not PlayerGui then
			return nil
		end

		local LowerName: string = string.lower(Name)
		for Index = #State.GuiRootList, ONE, NEGATIVE_ONE do
			local RootInstance: Instance = State.GuiRootList[Index]
			if RootInstance.Parent == nil then
				continue
			end

			if string.lower(RootInstance.Name) == LowerName then
				State.GuiRoots[Name] = RootInstance
				return RootInstance
			end
		end

		local DirectRoot: Instance? = PlayerGui:FindFirstChild(Name)
		if DirectRoot then
			State.GuiRoots[Name] = DirectRoot
			return DirectRoot
		end

		local RecursiveRoot: Instance? = PlayerGui:FindFirstChild(Name, true)
		if RecursiveRoot then
			State.GuiRoots[Name] = RecursiveRoot
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

		local ConfiguredAliases: { string }? = ResolveConfiguredAliases(Config.LightingRootAliases, Name)
		if ConfiguredAliases then
			for Index = #State.LightingRootList, ONE, NEGATIVE_ONE do
				local RootInstance: Instance = State.LightingRootList[Index]
				if RootInstance.Parent == nil then
					continue
				end

				local AliasMatch: Instance? = CutsceneRigUtils.FindChildByAliases(RootInstance, ConfiguredAliases, true)
				if AliasMatch then
					State.LightingRoots[Name] = AliasMatch
					return AliasMatch
				end
			end

			local AliasRoot: Instance? = CutsceneRigUtils.FindChildByAliases(Lighting, ConfiguredAliases, true)
			if AliasRoot then
				State.LightingRoots[Name] = AliasRoot
				return AliasRoot
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

		local Segments: { string } = SplitPath(PathValue)
		if #Segments <= ZERO then
			return nil
		end

		local Current: Instance?
		local Index: number = ONE
		local RootSegment: string = Segments[ONE]

		if RootSegment == "Workspace" then
			Index = 2
			if Config.DisableCamera ~= true and Segments[Index] == "CurrentCamera" then
				Current = workspace.CurrentCamera
				Index += ONE
			elseif Segments[Index] then
				Current = ResolveWorkspaceRootByName(Segments[Index])
				Index += ONE
			else
				Current = workspace
			end
		elseif RootSegment == "StarterGui" or RootSegment == "PlayerGui" then
			local PlayerGui: PlayerGui? = GetPlayerGui()
			if not PlayerGui then
				return nil
			end

			Index = 2
			if Segments[Index] then
				Current = ResolveGuiRootByName(Segments[Index])
				Index += ONE
			else
				Current = PlayerGui
			end
		elseif RootSegment == "Lighting" then
			Index = 2
			if Segments[Index] then
				Current = ResolveLightingRootByName(Segments[Index])
				Index += ONE
			else
				Current = Lighting
			end
		end

		if not Current then
			return nil
		end

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

	local function WaitForVisualCleanupToSettle(): ()
		for _ = 1, CLEANUP_VISUAL_SETTLE_FRAMES do
			RunService.Heartbeat:Wait()
		end
	end

	local function ReleaseCameraLock(): ()
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
		State.CamPart = nil
	end

	CleanupState = function(NotifyServer: boolean?): ()
		local HadCutsceneState: boolean = State.Active
			or State.SourcePlayer ~= nil
			or #State.Tracks > ZERO
			or #State.Clones > ZERO
			or #State.Connections > ZERO
			or State.CamPart ~= nil
			or State.LocalSourceRoot ~= nil
			or State.LocalSourceHumanoid ~= nil
			or State.LocalSourceRootAnchoredBefore ~= nil
			or State.LocalSourceHumanoidAutoRotateBefore ~= nil
			or State.LocalSourceHumanoidWalkSpeedBefore ~= nil
			or State.LocalSourceHumanoidJumpPowerBefore ~= nil
			or State.LocalSourceHumanoidJumpHeightBefore ~= nil
			or State.LocalSourceHumanoidUseJumpPowerBefore ~= nil
			or State.LocalPlayerSkillLockedBefore ~= nil
			or State.LocalCharacterSkillLockedBefore ~= nil
		local ShouldNotifyServer: boolean = NotifyServer == true and State.ShouldNotifyServer

		State.Active = false
		if HadCutsceneState then
			ApplyFinalLocalSourcePosition()
		end

		CutsceneVisibility.RestoreCharacters(State.HiddenCharacterState)
		CutsceneVisibility.RestoreGameplayArtifacts(State.HiddenGameplayArtifactState)
		State.HiddenCharacterState = nil
		State.HiddenGameplayArtifactState = nil

		for _, Track in State.Tracks do
			pcall(function()
				Track:Stop()
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

		if HadCutsceneState then
			RestoreHiddenBall()
			RestoreMovedWorkspaceParts()
			RestoreLocalSourceCharacter()
			WaitForVisualCleanupToSettle()
			ReleaseCameraLock()
			SetShiftlockBlocked(false)
			SetLocalCutsceneHudHidden(false)
			SetLocalAwakenCutsceneActive(false)
		end

		if ShouldNotifyServer then
			NotifyServerAwakenCutsceneEnded()
		end

		table.clear(State.WorkspaceRoots)
		table.clear(State.WorkspaceRootList)
		table.clear(State.LightingRoots)
		table.clear(State.LightingRootList)
		table.clear(State.GuiRoots)
		table.clear(State.GuiRootList)
		table.clear(State.PathCache)
		table.clear(State.EventBuckets)
		table.clear(State.MovedWorkspacePartCFrames)

		State.SourcePlayer = nil
		State.ActorModel = nil
		State.VictimModel = nil
		State.ShouldNotifyServer = false
		State.ServerCompletionSent = false
		State.CameraReleased = false
		State.LastAppliedCutsceneFov = nil
		State.LastGameplayArtifactRefreshAt = NEGATIVE_ONE
		State.LastBallHiddenRefreshAt = NEGATIVE_ONE
		State.TimelineStartAt = ZERO
		State.NextFrame = ZERO
	end

	local function CloneGuiAssets(SceneContainer: Instance): ()
		local PlayerGui: PlayerGui? = GetPlayerGui()
		if not PlayerGui then
			return
		end

		local ClonedSources: { [Instance]: boolean } = {}

		local function CloneGuiRoot(Item: Instance): ()
			if Item:IsA("LayerCollector") then
				if ClonedSources[Item] then
					return
				end

				ClonedSources[Item] = true
				local Clone: Instance = Item:Clone()
				Clone.Parent = PlayerGui
				TrackClone(Clone)
				RegisterGuiRootTree(Clone)
				return
			end

			for _, Child in Item:GetChildren() do
				CloneGuiRoot(Child)
			end
		end

		local ExplicitGuiContainer: Instance? = nil
		if Config.GuiContainerAliases then
			ExplicitGuiContainer = CutsceneRigUtils.FindChildByAliases(SceneContainer, Config.GuiContainerAliases, true)
		end

		if ExplicitGuiContainer then
			CloneGuiRoot(ExplicitGuiContainer)
			return
		end

		for _, Child in SceneContainer:GetChildren() do
			CloneGuiRoot(Child)
		end
	end

	local function CloneLightingInstance(Source: Instance, ClonedSources: { [Instance]: boolean }): ()
		if ClonedSources[Source] then
			return
		end

		ClonedSources[Source] = true
		local Clone: Instance = Source:Clone()
		Clone.Parent = Lighting
		TrackClone(Clone)
		RegisterLightingRootTree(Clone)
	end

	local function CloneLightingAssets(SceneContainer: Instance): ()
		local ClonedSources: { [Instance]: boolean } = {}

		local LightingContainer: Instance? = SceneContainer:FindFirstChild("Lighting")
		if not LightingContainer then
			LightingContainer = CutsceneRigUtils.FindChildByAliases(SceneContainer, { "Lighting" }, true)
		end
		if LightingContainer then
			for _, Child in LightingContainer:GetChildren() do
				CloneLightingInstance(Child, ClonedSources)
			end
			for _, Descendant in LightingContainer:GetDescendants() do
				if Descendant:IsA("Atmosphere") then
					CloneLightingInstance(Descendant, ClonedSources)
				end
			end
		end

		if not Config.LightingSourceAliases then
			return
		end

		for _, Alias in Config.LightingSourceAliases do
			local Source: Instance? = Lighting:FindFirstChild(Alias)
			if not Source then
				Source = Lighting:FindFirstChild(Alias, true)
			end
			if Source then
				CloneLightingInstance(Source, ClonedSources)
			end
		end
	end

	local function StartMaintenance(Token: number): ()
		local Connection: RBXScriptConnection = RunService.Heartbeat:Connect(function()
			if not IsTokenActive(Token) then
				return
			end
			RefreshGameplayHudArtifactsHidden(false)
			RefreshHiddenBall(false)

			local Root: BasePart? = State.LocalSourceRoot
			if Root and Root.Parent ~= nil then
				Root.Anchored = true
				Root.AssemblyLinearVelocity = Vector3.zero
				Root.AssemblyAngularVelocity = Vector3.zero
			end

			local HumanoidInstance: Humanoid? = State.LocalSourceHumanoid
			if HumanoidInstance and HumanoidInstance.Parent ~= nil then
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
		end)
		TrackConnection(Connection)
	end

	local function CloneVfxModel(SceneContainer: Instance, RootPosition: Vector3): Model?
		local TargetPosition: Vector3 = RootPosition + VfxOffset
		if Config.FixedVfxHeight then
			TargetPosition = Vector3.new(TargetPosition.X, Config.FixedVfxHeight, TargetPosition.Z)
		end

		local function MovePrimaryClone(CloneModel: Model): Model
			CutsceneRigUtils.MoveInstanceToPosition(CloneModel, TargetPosition)
			return CloneModel
		end

		local WorkspaceSourceAliases: { string }? = Config.WorkspaceSourceAliases
		if WorkspaceSourceAliases then
			local WorkspaceSource: Instance? =
				CutsceneRigUtils.FindChildByAliases(SceneContainer, WorkspaceSourceAliases, true)
			if WorkspaceSource then
				local PrimaryClone: Model? = nil
				for _, Child in WorkspaceSource:GetChildren() do
					local Clone: Instance = Child:Clone()
					Clone.Parent = workspace
					TrackClone(Clone)
					RegisterWorkspaceRootTree(Clone)
					if not PrimaryClone and Clone:IsA("Model") and HasAlias(Child.Name, Config.VfxModelAliases) then
						PrimaryClone = Clone
					end
				end
				if PrimaryClone then
					task.defer(PrepareRuntimeVfxModelAsync)
					return MovePrimaryClone(PrimaryClone)
				end
			end
		end

		local VfxTemplate: Model? = GetVfxTemplate(SceneContainer)
		if not VfxTemplate then
			return nil
		end

		local Clone: Model
		if
			PreparedRuntimeVfxModel
			and PreparedRuntimeVfxModel.Parent == nil
			and PreparedRuntimeVfxTemplate == VfxTemplate
		then
			Clone = PreparedRuntimeVfxModel
			PreparedRuntimeVfxModel = nil
			PreparedRuntimeVfxTemplate = nil
		else
			Clone = VfxTemplate:Clone()
		end
		Clone.Parent = workspace
		TrackClone(Clone)
		RegisterWorkspaceRootTree(Clone)
		task.defer(PrepareRuntimeVfxModelAsync)

		return MovePrimaryClone(Clone)
	end

	local function SetupActor(
		SceneContainer: Instance,
		RuntimeVfxModel: Model,
		SourcePlayer: Player,
		SourceCharacter: Model?,
		Token: number
	): ()
		local ActorModel: Model? = nil
		if Config.UseSourceCharacterAsActor == true then
			ActorModel = SourceCharacter
			if not ActorModel then
				return
			end

			State.ActorModel = ActorModel
			RegisterActorWorkspaceRoots(ActorModel)

			if Config.AlignSceneRootToPrincipalPlayerTemplate == true then
				AlignSceneRootToPrincipalPlayerTemplate(SceneContainer, RuntimeVfxModel, ActorModel)
			end

			local RuntimeActorReferenceModel: Model? = ResolveRuntimeActorReferenceModel(RuntimeVfxModel)
			if RuntimeActorReferenceModel then
				CloneVisualCharacterEffects(RuntimeActorReferenceModel, ActorModel)
				AlignCharacterToPositionPart(ActorModel, RuntimeActorReferenceModel)
			end
		else
			local ActorModelInstance: Instance? =
				CutsceneRigUtils.FindChildByAliases(RuntimeVfxModel, Config.PlayerModelAliases, true)
			if not ActorModelInstance or not ActorModelInstance:IsA("Model") then
				return
			end

			ActorModel = ActorModelInstance
			State.ActorModel = ActorModel

			CutsceneRigUtils.ApplyPlayerAppearance(SourcePlayer, ActorModel)
			CutsceneRigUtils.PrepareAnimatedModel(ActorModel)
			RegisterActorWorkspaceRoots(ActorModel)
		end

		local Track: AnimationTrack? = nil
		local PlayerAnimationTemplate: Animation? =
			ResolveAnimationTemplate(SceneContainer, Config.PlayerAnimationAliases)
		if PlayerAnimationTemplate then
			Track = CutsceneRigUtils.LoadAnimationTrackFromTemplate(ActorModel, PlayerAnimationTemplate)
		elseif type(Config.PlayerAnimationId) == "string" and Config.PlayerAnimationId ~= "" then
			Track = CutsceneRigUtils.LoadAnimationTrack(ActorModel, Config.PlayerAnimationId)
		end
		if not Track then
			return
		end

		Track:Play(0, 1, 1)
		EnsureTrackPlaying(Track, Token)
		TrackAnimationTrack(Track)
	end

	local function ResolveVictimSourcePlayer(SourcePlayer: Player, SourceRoot: BasePart): Player
		local ClosestVictimPlayer: Player? = FindClosestVictimPlayer(SourcePlayer, SourceRoot.Position)
		if ClosestVictimPlayer then
			return ClosestVictimPlayer
		end

		return SourcePlayer
	end

	local function SetupVictim(
		SceneContainer: Instance,
		RuntimeVfxModel: Model,
		SourcePlayer: Player,
		SourceRoot: BasePart,
		Token: number
	): ()
		if not Config.VictimModelAliases or #Config.VictimModelAliases <= ZERO then
			return
		end

		local VictimModelInstance: Instance? =
			CutsceneRigUtils.FindChildByAliases(RuntimeVfxModel, Config.VictimModelAliases, true)
		if not VictimModelInstance or not VictimModelInstance:IsA("Model") then
			return
		end

		local VictimModel: Model = VictimModelInstance
		State.VictimModel = VictimModel

		local VictimSourcePlayer: Player = ResolveVictimSourcePlayer(SourcePlayer, SourceRoot)
		CutsceneRigUtils.ApplyPlayerAppearance(VictimSourcePlayer, VictimModel)
		CutsceneRigUtils.PrepareAnimatedModel(VictimModel)

		local Track: AnimationTrack? = nil
		local VictimAnimationTemplate: Animation? =
			ResolveAnimationTemplate(SceneContainer, Config.VictimAnimationAliases)
		if VictimAnimationTemplate then
			Track = CutsceneRigUtils.LoadAnimationTrackFromTemplate(VictimModel, VictimAnimationTemplate)
		elseif type(Config.VictimAnimationId) == "string" and Config.VictimAnimationId ~= "" then
			Track = CutsceneRigUtils.LoadAnimationTrack(VictimModel, Config.VictimAnimationId)
		end
		if not Track then
			return
		end

		Track:Play(0, 1, 1)
		EnsureTrackPlaying(Track, Token)
		TrackAnimationTrack(Track)
	end

	local function ResolveCameraModelForCutscene(SceneContainer: Instance, RuntimeVfxModel: Model): Model?
		local CameraModelAliases: { string }? = Config.CameraModelAliases
		if not CameraModelAliases then
			return nil
		end

		local RuntimeCameraModel: Instance? =
			CutsceneRigUtils.FindChildByAliases(RuntimeVfxModel, CameraModelAliases, true)
		if RuntimeCameraModel and RuntimeCameraModel:IsA("Model") then
			return RuntimeCameraModel
		end

		local TemplateCameraModel: Instance? =
			CutsceneRigUtils.FindChildByAliases(SceneContainer, CameraModelAliases, true)
		if not TemplateCameraModel or not TemplateCameraModel:IsA("Model") then
			return nil
		end

		local CameraClone: Model = TemplateCameraModel:Clone()
		CameraClone.Parent = workspace
		TrackClone(CameraClone)
		RegisterWorkspaceRootTree(CameraClone)

		local AuthoredCameraPosition: Vector3? = Config.AuthoredCameraPosition
		if AuthoredCameraPosition then
			local ActorModel: Model? = State.ActorModel
			local ActorRoot: BasePart? = if ActorModel then CutsceneRigUtils.FindModelRootPart(ActorModel) else nil
			if ActorRoot then
				local CameraOffset: Vector3 = AuthoredCameraPosition - Config.AuthoredPlayerPosition
				CutsceneRigUtils.MoveInstanceToPosition(CameraClone, ActorRoot.Position + CameraOffset)
			end
		end

		return CameraClone
	end

	local function SetupCamera(SceneContainer: Instance, RuntimeVfxModel: Model, Token: number): ()
		if Config.DisableCamera == true or not Config.CameraModelAliases or not Config.CameraPartAliases then
			return
		end

		local CameraModelInstance: Model? = ResolveCameraModelForCutscene(SceneContainer, RuntimeVfxModel)
		if not CameraModelInstance then
			return
		end

		if Config.PreserveCameraModelAnchors ~= true then
			CutsceneRigUtils.PrepareAnimatedModel(CameraModelInstance)
		end

		local CamPartInstance: Instance? =
			CutsceneRigUtils.FindChildByAliases(CameraModelInstance, Config.CameraPartAliases, true)
		local CamPart: BasePart? = if CamPartInstance and CamPartInstance:IsA("BasePart")
			then CamPartInstance
			else CameraModelInstance:FindFirstChildWhichIsA("BasePart", true)

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
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
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

			CurrentCamera.CameraType = Enum.CameraType.Scriptable
			CurrentCamera.CameraSubject = nil
			if State.CamPart and State.CamPart.Parent ~= nil then
				CurrentCamera.CFrame = State.CamPart.CFrame
			end
		end)
		State.CameraBound = true

		local Track: AnimationTrack? = nil
		local CameraAnimationTemplate: Animation? = if Config.CameraAnimationAliases
			then ResolveAnimationTemplate(SceneContainer, Config.CameraAnimationAliases)
			else nil
		if CameraAnimationTemplate then
			Track = CutsceneRigUtils.LoadAnimationTrackFromTemplate(CameraModelInstance, CameraAnimationTemplate)
		elseif type(Config.CameraAnimationId) == "string" and Config.CameraAnimationId ~= "" then
			Track = CutsceneRigUtils.LoadAnimationTrack(CameraModelInstance, Config.CameraAnimationId)
		end
		if not Track then
			return
		end

		Track:Play(0, 1, 1)
		EnsureTrackPlaying(Track, Token)
		if Config.CleanupOnCameraAnimationEnd == true then
			Track.Stopped:Connect(function()
				if not IsTokenActive(Token) then
					return
				end
				CleanupState(true)
			end)
		end
		TrackAnimationTrack(Track)
	end

	--[[
	local function SetupCamera(SceneContainer: Instance, RuntimeVfxModel: Model, Token: number): ()
		local CameraModelInstance: Instance? =
			CutsceneRigUtils.FindChildByAliases(RuntimeVfxModel, Config.CameraModelAliases, true)
		if not CameraModelInstance or not CameraModelInstance:IsA("Model") then
			return
		end

		-- 1. ForÃ§ar InicializaÃ§Ã£o do Animator
		local CameraAnimationTarget: Instance =
			CameraModelInstance:FindFirstChildWhichIsA("AnimationController", true) or CameraModelInstance
		local Animator: Animator? = CameraAnimationTarget:FindFirstChildOfClass("Animator")
		if not Animator then
			Animator = Instance.new("Animator")
			if CameraAnimationTarget:IsA("AnimationController") then
				Animator.Parent = CameraAnimationTarget
			end
		end

		-- 2. EstabilizaÃ§Ã£o do Rig (Ancoragem TemporÃ¡ria)
		CutsceneRigUtils.PrepareAnimatedModel(CameraModelInstance)

		local function ResolveCameraPart(ModelInstance: Model): BasePart?
			for _, PartName in {"camera", "Camera"} do
				local Part: Instance? = ModelInstance:FindFirstChild(PartName, true)
				if Part and Part:IsA("BasePart") then
					return Part
				end
			end

			local AliasPart: Instance? = CutsceneRigUtils.FindChildByAliases(ModelInstance, Config.CameraPartAliases, true)
			if AliasPart and AliasPart:IsA("BasePart") then
				return AliasPart
			end

			for _, PartName in {"CamPart", "CameraPart", "RootPart", "HumanoidRootPart"} do
				local Part: Instance? = ModelInstance:FindFirstChild(PartName, true)
				if Part and Part:IsA("BasePart") then
					return Part
				end
			end

			if ModelInstance.PrimaryPart then
				return ModelInstance.PrimaryPart
			end

			local ModelRootPart: BasePart? = CutsceneRigUtils.FindModelRootPart(ModelInstance)
			if ModelRootPart then
				return ModelRootPart
			end

			return ModelInstance:FindFirstChildWhichIsA("BasePart", true)
		end

		local CamPart: BasePart? = ResolveCameraPart(CameraModelInstance)
		if not CamPart then
			return
		end

		State.CamPart = CamPart
		State.CameraFrameProvider = CamPart

		local Camera: Camera? = workspace.CurrentCamera
		if not Camera then
			return
		end

		-- 3. Salvar Estado Anterior
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
			if not State.Active or not State.CamPart then
				return
			end

			local CurrentCamera: Camera? = workspace.CurrentCamera
			if not CurrentCamera then
				return
			end

			CurrentCamera.CameraType = Enum.CameraType.Scriptable
			CurrentCamera.CameraSubject = nil
			if State.CamPart and State.CamPart.Parent ~= nil then
				CurrentCamera.CFrame = State.CamPart.CFrame
			end
		end)
		State.CameraBound = true

		-- 4. Carregar a AnimaÃ§Ã£o com Warmup
		local Track: AnimationTrack? = nil
		local CameraAnimationTemplate: Animation? = ResolveAnimationTemplate(SceneContainer, Config.CameraAnimationAliases)
		if CameraAnimationTemplate then
			Track = CutsceneRigUtils.LoadAnimationTrackFromTemplate(
				CameraModelInstance,
				CameraAnimationTemplate,
				Enum.AnimationPriority.Action,
				true
			)
		elseif type(Config.CameraAnimationId) == "string" and Config.CameraAnimationId ~= "" then
			Track = CutsceneRigUtils.LoadAnimationTrack(
				CameraModelInstance,
				Config.CameraAnimationId,
				Enum.AnimationPriority.Action,
				true
			)
		end

		if not Track then
			return
		end

		-- 5. Iniciar a AnimaÃ§Ã£o e Aguardar o Primeiro Frame
		Track:Play(0, 1, 1)
		TrackAnimationTrack(Track)

		-- Pequeno delay para garantir que o Animator processou o Play
		WaitForAnimationRigReady(TRACK_START_VERIFY_HEARTBEATS)
		if IsTokenActive(Token) and (not Track.IsPlaying or Track.TimePosition <= TRACK_START_EPSILON) then
			Track:Play(0, 1, 1)
		end

		-- 6. Bindar a CÃ¢mera com Prioridade MÃ¡xima e ForÃ§ar CFrame
		if false then
			RunService:BindToRenderStep(GetCameraBindName(), CAMERA_BIND_PRIORITY, function()
			if not State.Active or not State.CamPart then
				return
			end

			local CurrentCamera: Camera? = workspace.CurrentCamera
			if not CurrentCamera then
				return
			end

			EnforceGameplayHudArtifactsHidden()
			CurrentCamera.CameraType = Enum.CameraType.Scriptable
			CurrentCamera.CameraSubject = nil

			-- ForÃ§ar o CFrame da cÃ¢mera para o CamPart animado
			CurrentCamera.CFrame = State.CamPart.CFrame
		end)
		State.CameraBound = true
		end

		-- 7. Monitoramento Ativo da ReproduÃ§Ã£o
		EnsureTrackPlaying(Track, Token)

		if Config.CleanupOnCameraAnimationEnd == true then
			Track.Stopped:Connect(function()
				if not IsTokenActive(Token) then
					return
				end
				CleanupState(true)
			end)
		end
	end

	local function SetupCameraRobust(SceneContainer: Instance, RuntimeVfxModel: Model, Token: number): ()
		local CameraModelInstance: Instance? =
			CutsceneRigUtils.FindChildByAliases(RuntimeVfxModel, Config.CameraModelAliases, true)
		if not CameraModelInstance or not CameraModelInstance:IsA("Model") then
			CameraDebug("Nenhum CameraModel foi encontrado no bundle do awaken")
			return
		end

		local function DescribeBasePartList(Parts: {BasePart}, MaxItems: number?): string
			if #Parts <= ZERO then
				return "(nenhum)"
			end

			local Descriptions: {string} = {}
			local Limit: number = math.max(MaxItems or #Parts, ONE)
			local DisplayCount: number = math.min(#Parts, Limit)
			for Index = 1, DisplayCount do
				Descriptions[Index] = DescribeInstance(Parts[Index])
			end
			if #Parts > DisplayCount then
				table.insert(Descriptions, string.format("... (+%d restantes)", #Parts - DisplayCount))
			end
			return table.concat(Descriptions, " | ")
		end

		local function DescribeInstanceList(Instances: {Instance}, MaxItems: number?): string
			if #Instances <= ZERO then
				return "(nenhum)"
			end

			local Descriptions: {string} = {}
			local Limit: number = math.max(MaxItems or #Instances, ONE)
			local DisplayCount: number = math.min(#Instances, Limit)
			for Index = 1, DisplayCount do
				Descriptions[Index] = DescribeInstance(Instances[Index])
			end
			if #Instances > DisplayCount then
				table.insert(Descriptions, string.format("... (+%d restantes)", #Instances - DisplayCount))
			end
			return table.concat(Descriptions, " | ")
		end

		local function DescribeCameraFrameProviderList(
			Providers: {CameraFrameProvider},
			MaxItems: number?
		): string
			if #Providers <= ZERO then
				return "(nenhum)"
			end

			local Descriptions: {string} = {}
			local Limit: number = math.max(MaxItems or #Providers, ONE)
			local DisplayCount: number = math.min(#Providers, Limit)
			for Index = 1, DisplayCount do
				Descriptions[Index] = DescribeInstance(Providers[Index])
			end
			if #Providers > DisplayCount then
				table.insert(Descriptions, string.format("... (+%d restantes)", #Providers - DisplayCount))
			end
			return table.concat(Descriptions, " | ")
		end

		local function BuildCameraAliasLookup(): {[string]: boolean}
			local AliasLookup: {[string]: boolean} = {}
			for _, Alias in Config.CameraPartAliases do
				AliasLookup[CutsceneRigUtils.NormalizeName(Alias)] = true
			end
			for _, Alias in {
				"camera",
				"Camera",
				"CamPart",
				"CameraPart",
				"CameraAttachment",
				"CamAttachment",
				"RootPart",
				"HumanoidRootPart",
				"FovPart",
				"FOVPart",
			} do
				AliasLookup[CutsceneRigUtils.NormalizeName(Alias)] = true
			end
			return AliasLookup
		end

		local function CollectCameraAnchorParts(ModelInstance: Model): {BasePart}
			local Anchors: {BasePart} = {}
			local Seen: {[BasePart]: boolean} = {}
			local AliasLookup: {[string]: boolean} = BuildCameraAliasLookup()

			local function AddAnchor(Candidate: Instance?): ()
				AppendUniqueBasePart(Anchors, Seen, Candidate)
			end

			for _, PartName in {
				"camera",
				"Camera",
				"CamPart",
				"CameraPart",
				"RootPart",
				"HumanoidRootPart",
				"FovPart",
				"FOVPart",
			} do
				AddAnchor(ModelInstance:FindFirstChild(PartName, true))
			end

			for _, Descendant in ModelInstance:GetDescendants() do
				if Descendant:IsA("BasePart")
					and AliasLookup[CutsceneRigUtils.NormalizeName(Descendant.Name)]
				then
					AddAnchor(Descendant)
				end
			end

			for _, Descendant in ModelInstance:GetDescendants() do
				if not Descendant:IsA("BasePart") then
					continue
				end

				local NormalizedName: string = CutsceneRigUtils.NormalizeName(Descendant.Name)
				if string.find(NormalizedName, "camera", 1, true) or string.sub(NormalizedName, 1, 3) == "cam" then
					AddAnchor(Descendant)
				end
			end

			AddAnchor(CutsceneRigUtils.FindChildByAliases(ModelInstance, Config.CameraPartAliases, true))
			AddAnchor(ModelInstance.PrimaryPart)
			AddAnchor(CutsceneRigUtils.FindModelRootPart(ModelInstance))
			AddAnchor(ModelInstance:FindFirstChildWhichIsA("BasePart", true))

			return Anchors
		end

		local function ResolveNamedCameraFrameProviders(
			ModelInstance: Model,
			AnchorParts: {BasePart}
		): {CameraFrameProvider}
			local Candidates: {CameraFrameProvider} = {}
			local Seen: {[Instance]: boolean} = {}
			local AliasLookup: {[string]: boolean} = BuildCameraAliasLookup()

			local function AddProvider(Candidate: Instance?): ()
				AppendUniqueCameraFrameProvider(Candidates, Seen, Candidate)
			end

			for _, ProviderName in {
				"camera",
				"Camera",
				"CamPart",
				"CameraPart",
				"CameraAttachment",
				"CamAttachment",
				"RootPart",
				"HumanoidRootPart",
				"FovPart",
				"FOVPart",
			} do
				AddProvider(ModelInstance:FindFirstChild(ProviderName, true))
			end

			AddProvider(CutsceneRigUtils.FindChildByAliases(ModelInstance, Config.CameraPartAliases, true))

			for _, Descendant in ModelInstance:GetDescendants() do
				if not Descendant:IsA("BasePart") and not Descendant:IsA("Attachment") then
					continue
				end
				if AliasLookup[CutsceneRigUtils.NormalizeName(Descendant.Name)] then
					AddProvider(Descendant)
				end
			end

			for _, Descendant in ModelInstance:GetDescendants() do
				if not Descendant:IsA("BasePart") and not Descendant:IsA("Attachment") then
					continue
				end

				local NormalizedName: string = CutsceneRigUtils.NormalizeName(Descendant.Name)
				if string.find(NormalizedName, "camera", 1, true) or string.sub(NormalizedName, 1, 3) == "cam" then
					AddProvider(Descendant)
				end
			end

			for _, AnchorPart in AnchorParts do
				AddProvider(AnchorPart)
				for _, Descendant in AnchorPart:GetDescendants() do
					if Descendant:IsA("Attachment") then
						AddProvider(Descendant)
					end
				end
			end

			return Candidates
		end

		local function ResolveAllCameraFrameProviders(
			ModelInstance: Model,
			NamedProviders: {CameraFrameProvider}
		): {CameraFrameProvider}
			local Candidates: {CameraFrameProvider} = {}
			local Seen: {[Instance]: boolean} = {}

			for _, Candidate in NamedProviders do
				AppendUniqueCameraFrameProvider(Candidates, Seen, Candidate)
			end

			for _, Descendant in ModelInstance:GetDescendants() do
				if Descendant:IsA("Attachment") then
					AppendUniqueCameraFrameProvider(Candidates, Seen, Descendant)
				end
			end

			for _, Descendant in ModelInstance:GetDescendants() do
				if Descendant:IsA("BasePart") then
					AppendUniqueCameraFrameProvider(Candidates, Seen, Descendant)
				end
			end

			return Candidates
		end

		local function ResolveCameraAnimationTargets(ModelInstance: Model): {Instance}
			local Targets: {Instance} = {}
			local Seen: {[Instance]: boolean} = {}
			local SeenAnimators: {[Animator]: boolean} = {}

			local function AppendTarget(Candidate: Instance?, PreferAnimationController: boolean?): ()
				if not Candidate or Seen[Candidate] then
					return
				end

				local AnimatorInstance: Animator? =
					CutsceneRigUtils.GetAnimatorFromModel(Candidate, PreferAnimationController)
				if AnimatorInstance and SeenAnimators[AnimatorInstance] then
					return
				end

				Seen[Candidate] = true
				if AnimatorInstance then
					SeenAnimators[AnimatorInstance] = true
				end
				table.insert(Targets, Candidate)
			end

			AppendTarget(ModelInstance:FindFirstChildWhichIsA("AnimationController", true), nil)
			for _, Descendant in ModelInstance:GetDescendants() do
				if Descendant:IsA("AnimationController") then
					AppendTarget(Descendant, nil)
				end
			end

			AppendTarget(ModelInstance:FindFirstChildOfClass("Humanoid"), nil)
			AppendTarget(ModelInstance:FindFirstChildWhichIsA("Humanoid", true), nil)
			for _, Descendant in ModelInstance:GetDescendants() do
				if Descendant:IsA("Humanoid") then
					AppendTarget(Descendant, nil)
				end
			end

			if #Targets <= ZERO then
				AppendTarget(ModelInstance, true)
			end

			return Targets
		end

		local function SwitchCameraFallbackMode(FallbackMode: CameraControlMode, Reason: string): ()
			if State.CameraBound then
				RunService:UnbindFromRenderStep(GetCameraBindName())
				State.CameraBound = false
			end

			State.CameraControlMode = FallbackMode
			State.CameraFrameProvider = nil
			State.CamPart = nil

			local CurrentCamera: Camera? = workspace.CurrentCamera
			if CurrentCamera then
				CurrentCamera.CameraType = Enum.CameraType.Scriptable
				CurrentCamera.CameraSubject = nil
				if State.CameraLastRigCFrame then
					CurrentCamera.CFrame = State.CameraLastRigCFrame
				end
			end

			CameraDebug(string.format("Fallback de camera ativado | mode=%s | reason=%s", FallbackMode, Reason))
		end

		local function WaitForTrackAdvance(Track: AnimationTrack): boolean
			local LastTimePosition: number = Track.TimePosition
			for _ = 1, CAMERA_TRACK_VALIDATION_HEARTBEATS do
				if not IsTokenActive(Token) then
					return false
				end

				RunService.Heartbeat:Wait()
				if Track.TimePosition > LastTimePosition + TRACK_START_EPSILON then
					return true
				end
				if Track.IsPlaying and Track.TimePosition > TRACK_START_EPSILON then
					return true
				end

				LastTimePosition = math.max(LastTimePosition, Track.TimePosition)
			end

			return Track.IsPlaying and Track.TimePosition > TRACK_START_EPSILON
		end

		local function SelectMovingCameraFrameProvider(
			Candidates: {CameraFrameProvider},
			SampleHeartbeats: number,
			SampleLabel: string
		): (CameraFrameProvider?, number)
			local InitialCFrames: {[Instance]: CFrame} = {}
			for _, Candidate in Candidates do
				local InitialCFrame: CFrame? = GetCameraFrameProviderCFrame(Candidate)
				if InitialCFrame then
					InitialCFrames[Candidate] = InitialCFrame
				end
			end

			WaitForAnimationRigReady(SampleHeartbeats)

			local BestProvider: CameraFrameProvider? = nil
			local BestMotionScore: number = ZERO
			for _, Candidate in Candidates do
				local InitialCFrame: CFrame? = InitialCFrames[Candidate]
				local CurrentCFrame: CFrame? = GetCameraFrameProviderCFrame(Candidate)
				if not InitialCFrame or not CurrentCFrame then
					continue
				end

				local PositionDelta: number = (CurrentCFrame.Position - InitialCFrame.Position).Magnitude
				local LookDot: number =
					math.clamp(InitialCFrame.LookVector:Dot(CurrentCFrame.LookVector), NEGATIVE_ONE, ONE)
				local AngleDelta: number = math.acos(LookDot)
				local MotionScore: number = PositionDelta + AngleDelta

				CameraDebug(
					string.format(
						"Leitura de movimento | sample=%s | provider=%s | posDelta=%.5f | angleDelta=%.5f | score=%.5f",
						SampleLabel,
						DescribeInstance(Candidate),
						PositionDelta,
						AngleDelta,
						MotionScore
					)
				)

				if PositionDelta > CAMERA_PART_POSITION_EPSILON or AngleDelta > CAMERA_PART_ANGLE_EPSILON then
					if not BestProvider or MotionScore > BestMotionScore then
						BestProvider = Candidate
						BestMotionScore = MotionScore
					end
				end
			end

			return BestProvider, BestMotionScore
		end

		local CameraAnchorParts: {BasePart} = CollectCameraAnchorParts(CameraModelInstance)
		local NamedCameraFrameProviders: {CameraFrameProvider} =
			ResolveNamedCameraFrameProviders(CameraModelInstance, CameraAnchorParts)
		local AllCameraFrameProviders: {CameraFrameProvider} =
			ResolveAllCameraFrameProviders(CameraModelInstance, NamedCameraFrameProviders)
		local NamedProviderLookup: {[Instance]: boolean} = {}
		for _, Provider in NamedCameraFrameProviders do
			NamedProviderLookup[Provider] = true
		end

		if #AllCameraFrameProviders <= ZERO then
			CameraDebug(
				string.format(
					"Nenhum provider de camera (BasePart/Attachment/Bone) foi encontrado em %s",
					DescribeInstance(CameraModelInstance)
				)
			)
			return
		end

		CameraDebug(string.format("CameraModel resolvido: %s", DescribeInstance(CameraModelInstance)))
		if #CameraAnchorParts > ZERO then
			CameraDebug(string.format("Partes ancora de camera: %s", DescribeBasePartList(CameraAnchorParts, 10)))
		end
		CameraDebug(
			string.format(
				"Providers nomeados de camera: %s",
				DescribeCameraFrameProviderList(NamedCameraFrameProviders, 12)
			)
		)
		if #AllCameraFrameProviders > #NamedCameraFrameProviders then
			CameraDebug(
				string.format(
					"Providers expandidos de camera (%d total): %s",
					#AllCameraFrameProviders,
					DescribeCameraFrameProviderList(AllCameraFrameProviders, 18)
				)
			)
		end

		CutsceneRigUtils.PrepareAnimatedModel(CameraModelInstance)
		SetActiveCameraFrameProvider(
			NamedCameraFrameProviders[1] or AllCameraFrameProviders[1],
			"provider inicial antes da validacao da animacao"
		)

		local Camera: Camera? = workspace.CurrentCamera
		if not Camera then
			CameraDebug("workspace.CurrentCamera retornou nil durante o setup")
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
		State.CameraControlMode = "Rig"

		CameraDebug(
			string.format(
				"Camera travada em Scriptable | prevType=%s | prevFov=%.3f",
				tostring(State.PrevCameraType),
				State.PrevCameraFov or ZERO
			)
		)

		if State.CameraBound then
			RunService:UnbindFromRenderStep(GetCameraBindName())
		end
		RunService:BindToRenderStep(GetCameraBindName(), CAMERA_BIND_PRIORITY, function()
			if not State.Active or State.CameraControlMode ~= "Rig" then
				return
			end

			local CurrentCamera: Camera? = workspace.CurrentCamera
			if not CurrentCamera then
				return
			end

			EnforceGameplayHudArtifactsHidden()
			CurrentCamera.CameraType = Enum.CameraType.Scriptable
			CurrentCamera.CameraSubject = nil

			if not State.CameraFrameProvider then
				SwitchCameraFallbackMode(
					if State.CameraHasTimelineCFrame then "Timeline" else "Hold",
					"State.CameraFrameProvider ficou nil durante o RenderStep"
				)
				return
			end

			if State.CameraFrameProvider.Parent == nil then
				SwitchCameraFallbackMode(
					if State.CameraHasTimelineCFrame then "Timeline" else "Hold",
					"Provider de camera foi removido da hierarquia durante o RenderStep"
				)
				return
			end

			local ProviderCFrame: CFrame? = GetCameraFrameProviderCFrame(State.CameraFrameProvider)
			if not ProviderCFrame then
				SwitchCameraFallbackMode(
					if State.CameraHasTimelineCFrame then "Timeline" else "Hold",
					"Nao foi possivel ler o CFrame do provider ativo durante o RenderStep"
				)
				return
			end

			CurrentCamera.CFrame = ProviderCFrame
			State.CameraLastRigCFrame = ProviderCFrame
		end)
		State.CameraBound = true
		CameraDebug("BindToRenderStep da camera foi registrado")

		local CameraAnimationTemplate: Animation? = ResolveAnimationTemplate(SceneContainer, Config.CameraAnimationAliases)
		local CameraAnimationId: string? = if type(Config.CameraAnimationId) == "string" and Config.CameraAnimationId ~= ""
			then Config.CameraAnimationId
			else nil
		if not CameraAnimationTemplate and not CameraAnimationId then
			SwitchCameraFallbackMode(
				if State.CameraHasTimelineCFrame then "Timeline" else "Hold",
				"Nenhuma animacao de camera foi configurada"
			)
			return
		end

		local function LoadCameraTrackForTarget(AnimationTarget: Instance): AnimationTrack?
			local PreferAnimationController: boolean? = if AnimationTarget:IsA("Model") then true else nil
			if CameraAnimationTemplate then
				return CutsceneRigUtils.LoadAnimationTrackFromTemplate(
					AnimationTarget,
					CameraAnimationTemplate,
					Enum.AnimationPriority.Action,
					PreferAnimationController
				)
			end

			if CameraAnimationId then
				return CutsceneRigUtils.LoadAnimationTrack(
					AnimationTarget,
					CameraAnimationId,
					Enum.AnimationPriority.Action,
					PreferAnimationController
				)
			end

			return nil
		end

		local function StartCameraFrameProviderWatchdog(
			Candidates: {CameraFrameProvider},
			AnimationTarget: Instance
		): ()
			if #Candidates <= ZERO then
				return
			end

			local LastCFrames: {[Instance]: CFrame} = {}
			for _, Candidate in Candidates do
				local CandidateCFrame: CFrame? = GetCameraFrameProviderCFrame(Candidate)
				if CandidateCFrame then
					LastCFrames[Candidate] = CandidateCFrame
				end
			end

			local ElapsedHeartbeats: number = ZERO
			local Connection: RBXScriptConnection
			Connection = RunService.Heartbeat:Connect(function()
				if not IsTokenActive(Token) or State.CameraReleased or State.CameraControlMode ~= "Rig" then
					Connection:Disconnect()
					return
				end

				ElapsedHeartbeats += ONE

				local BestProvider: CameraFrameProvider? = nil
				local BestMotionScore: number = ZERO
				for _, Candidate in Candidates do
					local LastCFrame: CFrame? = LastCFrames[Candidate]
					local CurrentCFrame: CFrame? = GetCameraFrameProviderCFrame(Candidate)
					if not CurrentCFrame then
						continue
					end

					if LastCFrame then
						local PositionDelta: number = (CurrentCFrame.Position - LastCFrame.Position).Magnitude
						local LookDot: number =
							math.clamp(LastCFrame.LookVector:Dot(CurrentCFrame.LookVector), NEGATIVE_ONE, ONE)
						local AngleDelta: number = math.acos(LookDot)
						local MotionScore: number = PositionDelta + AngleDelta
						if PositionDelta > CAMERA_PART_POSITION_EPSILON or AngleDelta > CAMERA_PART_ANGLE_EPSILON then
							if not BestProvider or MotionScore > BestMotionScore then
								BestProvider = Candidate
								BestMotionScore = MotionScore
							end
						end
					end

					LastCFrames[Candidate] = CurrentCFrame
				end

				if BestProvider then
					if BestProvider ~= State.CameraFrameProvider then
						SetActiveCameraFrameProvider(
							BestProvider,
							string.format(
								"watchdog detectou movimento apos %d heartbeats | target=%s | source=%s",
								ElapsedHeartbeats,
								DescribeInstance(AnimationTarget),
								if NamedProviderLookup[BestProvider] then "named" else "exhaustive"
							)
						)
						CameraDebug(
							string.format(
								"Provider alternativo ativado | target=%s | provider=%s | motionScore=%.5f",
								DescribeInstance(AnimationTarget),
								DescribeInstance(BestProvider),
								BestMotionScore
							)
						)
					else
						CameraDebug(
							string.format(
								"Provider inicial confirmou movimento | target=%s | provider=%s | motionScore=%.5f | elapsedHeartbeats=%d",
								DescribeInstance(AnimationTarget),
								DescribeInstance(BestProvider),
								BestMotionScore,
								ElapsedHeartbeats
							)
						)
					end

					Connection:Disconnect()
					return
				end

				if ElapsedHeartbeats >= CAMERA_FRAME_PROVIDER_WATCHDOG_HEARTBEATS then
					CameraDebug(
						string.format(
							"Watchdog da camera expirou sem detectar movimento | target=%s | providerMantido=%s",
							DescribeInstance(AnimationTarget),
							DescribeInstance(State.CameraFrameProvider)
						)
					)
					Connection:Disconnect()
				end
			end)
			TrackConnection(Connection)
			CameraDebug(
				string.format(
					"Watchdog de provider iniciado | target=%s | totalCandidates=%d",
					DescribeInstance(AnimationTarget),
					#Candidates
				)
			)
		end

		local function TryAnimationTarget(AnimationTarget: Instance): AnimationTrack?
			CameraDebug(string.format("Testando alvo de animacao: %s", DescribeInstance(AnimationTarget)))

			local Track: AnimationTrack? = LoadCameraTrackForTarget(AnimationTarget)
			if not Track then
				CameraDebug(string.format("Falha ao carregar track no alvo: %s", DescribeInstance(AnimationTarget)))
				return nil
			end

			Track:Play(0, 1, 1)
			WaitForAnimationRigReady(TRACK_START_VERIFY_HEARTBEATS)
			if IsTokenActive(Token) and (not Track.IsPlaying or Track.TimePosition <= TRACK_START_EPSILON) then
				CameraDebug(
					string.format(
						"Track ainda nao iniciou, repetindo Play | target=%s | isPlaying=%s | time=%.5f",
						DescribeInstance(AnimationTarget),
						tostring(Track.IsPlaying),
						Track.TimePosition
					)
				)
				Track:Play(0, 1, 1)
			end

			local TrackAdvanced: boolean = WaitForTrackAdvance(Track)
			CameraDebug(
				string.format(
					"Resultado do Play | target=%s | advanced=%s | isPlaying=%s | time=%.5f",
					DescribeInstance(AnimationTarget),
					tostring(TrackAdvanced),
					tostring(Track.IsPlaying),
					Track.TimePosition
				)
			)

			if not TrackAdvanced then
				CameraDebug(
					string.format(
						"Alvo descartado | target=%s | reason=track nao avancou",
						DescribeInstance(AnimationTarget)
					)
				)
				pcall(function()
					Track:Stop(0)
				end)
				pcall(function()
					Track:Destroy()
				end)
				return nil
			end

			local MovingProvider: CameraFrameProvider?, MotionScore: number =
				SelectMovingCameraFrameProvider(
					AllCameraFrameProviders,
					CAMERA_PART_MOVEMENT_HEARTBEATS,
					"initial"
				)
			if MovingProvider then
				SetActiveCameraFrameProvider(
					MovingProvider,
					string.format(
						"validado na janela inicial | target=%s | source=%s",
						DescribeInstance(AnimationTarget),
						if NamedProviderLookup[MovingProvider] then "named" else "exhaustive"
					)
				)
				CameraDebug(
					string.format(
						"Provider validado com sucesso | target=%s | provider=%s | motionScore=%.5f | source=%s",
						DescribeInstance(AnimationTarget),
						DescribeInstance(MovingProvider),
						MotionScore,
						if NamedProviderLookup[MovingProvider] then "named" else "exhaustive"
					)
				)
			else
				CameraDebug(
					string.format(
						"Track avancou, mas nenhum provider se moveu na janela inicial | target=%s | mantendo providerInicial=%s | watchdog=true",
						DescribeInstance(AnimationTarget),
						DescribeInstance(State.CameraFrameProvider)
					)
				)
				StartCameraFrameProviderWatchdog(AllCameraFrameProviders, AnimationTarget)
			end

			return Track
		end

		local AnimationTargets: {Instance} = ResolveCameraAnimationTargets(CameraModelInstance)
		if #AnimationTargets <= ZERO then
			SwitchCameraFallbackMode(
				if State.CameraHasTimelineCFrame then "Timeline" else "Hold",
				"Nenhum AnimationController, Humanoid ou Model valido foi encontrado para animar a camera"
			)
			return
		end
		CameraDebug(string.format("Alvos de animacao disponiveis: %s", DescribeInstanceList(AnimationTargets, 8)))

		local Track: AnimationTrack? = nil
		for _, AnimationTarget in AnimationTargets do
			Track = TryAnimationTarget(AnimationTarget)
			if Track then
				break
			end
		end
		if not Track then
			SwitchCameraFallbackMode(
				if State.CameraHasTimelineCFrame then "Timeline" else "Hold",
				"Nenhum alvo de animacao conseguiu carregar ou avancar a track da camera"
			)
			return
		end

		TrackAnimationTrack(Track)
		EnsureTrackPlaying(Track, Token)
		CameraDebug(
			string.format(
				"Camera online com sucesso | controlMode=%s | activeProvider=%s",
				State.CameraControlMode,
				DescribeInstance(State.CameraFrameProvider)
			)
		)

		if Config.CleanupOnCameraAnimationEnd == true then
			Track.Stopped:Connect(function()
				if not IsTokenActive(Token) then
					return
				end
				CleanupState(true)
			end)
		end
	end

]]

	local function BuildEventBuckets(): ({ [number]: { TimelineEvent } }, number)
		local Buckets: { [number]: { TimelineEvent } } = {}
		local MaxFrame: number = ZERO
		local LastCameraFieldOfView: number? = nil

		for _, Event in Config.Timeline.Events do
			if Config.DisableCamera == true and Event.Path == "Workspace.CurrentCamera" then
				continue
			end

			if
				Event.Action == "SetProperty"
				and Event.Path == "Workspace.CurrentCamera"
				and Event.Property == "FieldOfView"
				and type(Event.Value) == "number"
			then
				local EventFov: number = Event.Value
				if
					LastCameraFieldOfView ~= nil
					and math.abs(LastCameraFieldOfView - EventFov) <= FOV_UPDATE_EPSILON
				then
					continue
				end

				LastCameraFieldOfView = EventFov
			end

			if Event.Frame > MaxFrame then
				MaxFrame = Event.Frame
			end

			local Bucket: { TimelineEvent }? = Buckets[Event.Frame]
			if not Bucket then
				Bucket = {}
				Buckets[Event.Frame] = Bucket
			end
			table.insert(Bucket, Event)
		end

		return Buckets, math.max(MaxFrame, Config.Timeline.MaxFrame or ZERO)
	end

	local function SetEnabledRecursive(Target: Instance, Enabled: boolean): ()
		local function Apply(InstanceItem: Instance): boolean
			local Success: boolean = pcall(function()
				(InstanceItem :: any).Enabled = Enabled
			end)
			if Success then
				return true
			end

			local VisibleSuccess: boolean = pcall(function()
				(InstanceItem :: any).Visible = Enabled
			end)
			return VisibleSuccess
		end

		if Apply(Target) then
			return
		end

		for _, Descendant in Target:GetDescendants() do
			if
				Descendant:IsA("ParticleEmitter")
				or Descendant:IsA("Beam")
				or Descendant:IsA("Trail")
				or Descendant:IsA("Light")
				or Descendant:IsA("PostEffect")
				or Descendant:IsA("LayerCollector")
				or Descendant:IsA("GuiObject")
			then
				Apply(Descendant)
			end
		end
	end

	local function EmitRecursive(Target: Instance, Amount: number): ()
		local EmitAmount: number = math.max(math.floor(Amount), ONE)
		local EmittedParticle: boolean = false
		if Target:IsA("ParticleEmitter") then
			Target:Emit(EmitAmount)
			EmittedParticle = true
		end

		for _, Descendant in Target:GetDescendants() do
			if Descendant:IsA("ParticleEmitter") then
				Descendant:Emit(EmitAmount)
				EmittedParticle = true
			end
		end

		if EmittedParticle then
			return
		end

		SkillVfxUtils.Emit(Target)
	end

	local function ToColor3(Value: any): Color3?
		if type(Value) ~= "table" or #Value < 3 then
			return nil
		end

		local R: number = tonumber(Value[1]) or ZERO
		local G: number = tonumber(Value[2]) or ZERO
		local B: number = tonumber(Value[3]) or ZERO
		return Color3.new(R, G, B)
	end

	local function ToCFrame(Value: any): CFrame?
		if type(Value) ~= "table" or #Value < 12 then
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
		if Property == "AttachToPart" then
			return
		end

		if State.CameraReleased and Target == workspace.CurrentCamera then
			return
		end

		if Property == "FieldOfView" and Target == workspace.CurrentCamera and type(Value) == "number" then
			ApplyCutsceneFov(Value)
			return
		end

		if type(Value) == "table" and #Value == 3 then
			local ParsedColor: Color3? = ToColor3(Value)
			if ParsedColor then
				local Success: boolean = pcall(function()
					(Target :: any)[Property] = ParsedColor
				end)
				if Success then
					return
				end
			end
		end

		if Property == "CFrame" then
			local ParsedCFrame: CFrame? = ToCFrame(Value)
			if not ParsedCFrame then
				return
			end

			if Target:IsA("Model") then
				Target:PivotTo(ParsedCFrame)
				return
			end
			if Target:IsA("BasePart") then
				Target.CFrame = ParsedCFrame
				return
			end
			return
		end

		pcall(function()
			(Target :: any)[Property] = Value
		end)
	end

	local function HandleMarkerCode(Event: TimelineEvent): ()
		local EventCode: string = Event.Code or ""
		if EventCode == CAMERA_RELEASE_MARKER then
			if Config.DisableCamera ~= true then
				CleanupState(true)
			end
			return
		end

		if Config.SkipMarkerCodeIfContains then
			for _, Pattern in Config.SkipMarkerCodeIfContains do
				if Pattern ~= "" and string.find(EventCode, Pattern, ONE, true) ~= nil then
					return
				end
			end
		end

		local OffsetText: string? = string.match(EventCode, "yOffset%s*=%s*([%-%d%.]+)")
		if OffsetText ~= nil then
			local OffsetY: number? = tonumber(OffsetText)
			if OffsetY ~= nil then
				local TargetsMapRoot: boolean =
					string.find(EventCode, "mapModel", ONE, true) ~= nil
					or string.find(EventCode, "WaitForChild(\"Map\")", ONE, true) ~= nil
					or string.find(EventCode, "WaitForChild('Map')", ONE, true) ~= nil
				if TargetsMapRoot then
					MoveWorkspaceRootByOffset("Map", OffsetY)
				end
			end
		end

		local Processed: { [string]: boolean } = {}
		for RootName in string.gmatch(EventCode, "workspace%.([%w_]+)") do
			if Processed[RootName] then
				continue
			end
			Processed[RootName] = true
			local Target: Instance? = ResolveWorkspaceRootByName(RootName)
			if Target then
				CutsceneRigUtils.EmitFromAttributes(Target)
			end
		end
		for RootName in string.gmatch(EventCode, "workspace%[%s*[\"']([^\"']+)[\"']%s*%]") do
			if Processed[RootName] then
				continue
			end
			Processed[RootName] = true
			local Target: Instance? = ResolveWorkspaceRootByName(RootName)
			if Target then
				CutsceneRigUtils.EmitFromAttributes(Target)
			end
		end
	end

	local function ExecuteEvent(Token: number, Event: TimelineEvent): ()
		if not IsTokenActive(Token) then
			return
		end

		if Event.Action == "MarkerCode" then
			HandleMarkerCode(Event)
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

	local function StartTimeline(Token: number): number
		local Buckets: { [number]: { TimelineEvent } }, MaxFrame: number = BuildEventBuckets()
		State.EventBuckets = Buckets
		State.TimelineStartAt = os.clock()
		State.NextFrame = ZERO

		local TimelineFps: number = Config.Timeline.FPS or 60
		local Connection: RBXScriptConnection
		Connection = RunService.Heartbeat:Connect(function()
			if not IsTokenActive(Token) then
				Connection:Disconnect()
				return
			end

			local Elapsed: number = os.clock() - State.TimelineStartAt
			local CurrentFrame: number = math.floor(Elapsed * TimelineFps)
			while State.NextFrame <= CurrentFrame do
				local Frame: number = State.NextFrame
				local Bucket: { TimelineEvent }? = State.EventBuckets[Frame]
				if Bucket then
					for _, Event in Bucket do
						ExecuteEvent(Token, Event)
					end
				end
				if Frame >= MaxFrame then
					Connection:Disconnect()
					return
				end
				State.NextFrame += ONE
			end
		end)
		TrackConnection(Connection)

		return MaxFrame
	end

	local function ScheduleCleanup(Token: number, Duration: number): ()
		task.delay(math.max(Duration, ZERO) + CLEANUP_PADDING, function()
			if not IsTokenActive(Token) then
				return
			end
			CleanupState(true)
		end)
	end

	local function BeginCutscene(SourcePlayer: Player, CutsceneDuration: number?): ()
		CleanupState(false)
		SkillAssetPreloader.PreloadAll()

		local SceneContainer: Instance? = FindSceneContainer()
		if not SceneContainer then
			return
		end

		local SourceCharacter, SourceRoot = ResolveSourceCharacter(SourcePlayer)
		if not SourceCharacter or not SourceRoot then
			return
		end

		local RuntimeVfxModel: Model? = CloneVfxModel(SceneContainer, SourceRoot.Position)
		if not RuntimeVfxModel then
			return
		end

		State.Token += ONE
		local Token: number = State.Token
		State.Active = true
		State.SourcePlayer = SourcePlayer
		State.ShouldNotifyServer = SourcePlayer == LocalPlayer
		State.ServerCompletionSent = false
		State.CameraReleased = false

		SetShiftlockBlocked(true)
		SetLocalCutsceneHudHidden(true)
		SetLocalAwakenCutsceneActive(true)

		CloneLightingAssets(SceneContainer)
		CloneGuiAssets(SceneContainer)
		RefreshHiddenBall(true)
		HideSourceCharacter(SourcePlayer)
		FreezeLocalSourceCharacter(SourcePlayer)
		SetupActor(SceneContainer, RuntimeVfxModel, SourcePlayer, SourceCharacter, Token)
		SetupVictim(SceneContainer, RuntimeVfxModel, SourcePlayer, SourceRoot, Token)
		SetupCamera(SceneContainer, RuntimeVfxModel, Token)
		RefreshGameplayHudArtifactsHidden(true)
		StartMaintenance(Token)

		local MaxFrame: number = StartTimeline(Token)
		local TimelineDuration: number = MaxFrame / (Config.Timeline.FPS or 60)
		local EffectiveDuration: number = math.max(CutsceneDuration or Config.CutsceneDuration, TimelineDuration)
		ScheduleCleanup(Token, EffectiveDuration)
	end

	local Controller = {} :: AwakenController

	function Controller.Cleanup(): ()
		CleanupState(false)
	end

	function Controller.HandleStatus(Status: string, _Duration: number): ()
		if typeof(Status) ~= "string" then
			return
		end

		if Status == "Start" then
			BeginCutscene(LocalPlayer, Config.CutsceneDuration)
			return
		end

		CleanupState(true)
	end

	function Controller.PlayForPlayer(SourcePlayer: Player, CutsceneDuration: number?): ()
		if typeof(SourcePlayer) ~= "Instance" or not SourcePlayer:IsA("Player") then
			return
		end

		BeginCutscene(SourcePlayer, CutsceneDuration)
	end

	task.defer(function()
		SkillAssetPreloader.PreloadAll()
		FindSceneContainer()
		PrepareRuntimeVfxModelAsync()
	end)

	return Controller
end

return SceneBundleAwakenController
