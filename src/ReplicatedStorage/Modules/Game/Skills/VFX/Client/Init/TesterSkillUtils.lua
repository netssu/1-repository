--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local FOVController: any = require(ReplicatedStorage.Controllers.FOVController)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local SkillAssetPreloader: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillAssetPreloader)
local CutsceneRigUtils: any = require(script.Parent.CutsceneRigUtils)
local SkillVfxUtils: any = require(script.Parent.SkillVfxUtils)

type TimelineEvent = {
	Frame: number,
	Kind: string,
	Path: {string}?,
	MeshPath: {string}?,
	BasePath: {string}?,
	RelativeCFrame: CFrame?,
	FillTransparency: number?,
	OutlineTransparency: number?,
	LocalOnly: boolean?,
}

type RecordedCFrameEventConfig = {
	Frame: number,
	Path: {string},
	ReferenceBaseCFrame: CFrame,
	RecordedCFrame: CFrame,
	BasePath: {string}?,
	LocalOnly: boolean?,
}

type RecordedCFrameKeyframe = {
	Frame: number,
	RecordedCFrame: CFrame,
}

type RecordedCFrameTrackConfig = {
	Path: {string},
	ReferenceBaseCFrame: CFrame,
	Keyframes: {RecordedCFrameKeyframe},
	BasePath: {string}?,
	LocalOnly: boolean?,
}

type RelativeCFrameTrack = {
	Key: string,
	Path: {string},
	BasePath: {string}?,
	LocalOnly: boolean?,
	Keyframes: {TimelineEvent},
}

type SkillConfig = {
	TypeName: string,
	SkillFolderAliases: {string},
	AnimationId: string,
	WorldOffset: Vector3,
	WorldOrientationOffset: Vector3,
	UseWorldSpacePositionOffset: boolean?,
	UseAbsoluteOrientationOffset: boolean?,
	DetachAttachedParticlePartsOnStart: boolean?,
	SendStartPhase: boolean?,
	PlayAnimationOnClient: boolean?,
	AnimationPriority: Enum.AnimationPriority?,
	AnimationSpeed: number?,
	WorldTemplateAliases: {string}?,
	PlayerProxyAliases: {string}?,
	AttachWorldCloneToRoot: boolean?,
	AnchorDetachedWorldClone: boolean?,
	MarkerEvents: {[string]: {TimelineEvent}}?,
	EndFovPriority: number?,
	FovRequestId: string,
	EndFovTarget: number,
	EndFovInTime: number,
	EndFovHoldTime: number,
	Timeline: {TimelineEvent},
}

type PlaybackState = {
	Active: boolean,
	Token: number,
	IsLocal: boolean,
	Track: AnimationTrack?,
	Connections: {RBXScriptConnection},
	Instances: {Instance},
	Lookup: {[string]: Instance},
	Highlight: Highlight?,
	FovSequence: number,
	FovRequestId: string?,
	WorldBaseTarget: Instance?,
	WorldBaseCFrame: CFrame?,
	StartSent: boolean,
	StartHandled: boolean,
	EndSent: boolean,
}

local TesterSkillUtils = {}

local TESTER_STYLE_ALIASES: {string} = {
	"Tester",
}

local PLAYER_PROXY_ALIASES: {string} = {
	"Player",
}

local VFX_MODEL_ALIASES: {string} = {
	"VfxModel",
	"VFXModel",
}

local DEFAULT_ANIMATION_PRIORITY: Enum.AnimationPriority = Enum.AnimationPriority.Action
local START_MARKER_NAME: string = "Start"
local END_MARKER_NAME: string = "End"
local TIMELINE_FPS: number = 60
local EFFECTS_FOLDER_NAME: string = "TesterSkillEffects"
local WORLD_WELD_NAME: string = "TesterWorldVfxWeld"
local PLAYER_EFFECT_WELD_NAME: string = "TesterPlayerEffectWeld"
local DEFAULT_FILL_TRANSPARENCY: number = 1
local DEFAULT_OUTLINE_TRANSPARENCY: number = 1
local PHASE_ACTION_START: string = "Start"
local PHASE_ACTION_END: string = "End"
local TIMELINE_KIND_EMIT: string = "Emit"
local TIMELINE_KIND_HIGHLIGHT: string = "Highlight"
local TIMELINE_KIND_VIGNETTE: string = "Vignette"
local TIMELINE_KIND_SET_RELATIVE_CFRAME: string = "SetRelativeCFrame"
local KEYFRAME_TIME_EPSILON: number = 1 / 240
local START_PART_NAME: string = "Start"
local MESH_EMIT_MODULE_NAME: string = "MeshEmitModule"
local TEMP_FOLDER_NAME: string = "temp"

local LocalPlayer: Player = Players.LocalPlayer
local CachedMeshEmitModule: ((Instance) -> ())? = nil
local CachedMeshEmitResolved: boolean = false

local function ResolveSourcePlayer(SourceUserId: number): Player?
	return Players:GetPlayerByUserId(math.floor(SourceUserId + 0.5))
end

local function CreateState(IsLocal: boolean, Token: number): PlaybackState
	return {
		Active = true,
		Token = Token,
		IsLocal = IsLocal,
		Track = nil,
		Connections = {},
		Instances = {},
		Lookup = {},
		Highlight = nil,
		FovSequence = 0,
		FovRequestId = nil,
		WorldBaseTarget = nil,
		WorldBaseCFrame = nil,
		StartSent = false,
		StartHandled = false,
		EndSent = false,
	}
end

local function RegisterConnection(State: PlaybackState, Connection: RBXScriptConnection): ()
	table.insert(State.Connections, Connection)
end

local function RegisterInstance(State: PlaybackState, InstanceItem: Instance): ()
	table.insert(State.Instances, InstanceItem)
end

local function RegisterLookup(State: PlaybackState, PathSegments: {string}, InstanceItem: Instance): ()
	State.Lookup[SkillVfxUtils.NormalizePath(PathSegments)] = InstanceItem
end

local function RegisterTree(State: PlaybackState, Root: Instance, PrefixSegments: {string}?): ()
	local BaseSegments: {string} = PrefixSegments or { Root.Name }
	if #BaseSegments > 0 then
		RegisterLookup(State, BaseSegments, Root)
	end

	for _, Descendant in Root:GetDescendants() do
		local Segments: {string} = {}
		for _, Segment in BaseSegments do
			table.insert(Segments, Segment)
		end

		local Current: Instance? = Descendant
		local Relative: {string} = {}
		while Current and Current ~= Root do
			table.insert(Relative, 1, Current.Name)
			Current = Current.Parent
		end

		for _, Segment in Relative do
			table.insert(Segments, Segment)
		end

		RegisterLookup(State, Segments, Descendant)
	end
end

local function FindTarget(State: PlaybackState, PathSegments: {string}?): Instance?
	if not PathSegments or #PathSegments <= 0 then
		return nil
	end

	return State.Lookup[SkillVfxUtils.NormalizePath(PathSegments)]
end

local function EnsureWorkspaceTempContainer(): Instance
	local Existing: Instance? = workspace:FindFirstChild(TEMP_FOLDER_NAME)
	if Existing then
		return Existing
	end

	-- Asset-side mesh emit code stages temporary clones under `workspace.temp`.
	local FolderInstance: Folder = Instance.new("Folder")
	FolderInstance.Name = TEMP_FOLDER_NAME
	FolderInstance.Parent = workspace
	return FolderInstance
end

local function ResolveMeshEmitModule(): ((Instance) -> ())?
	if CachedMeshEmitResolved then
		return CachedMeshEmitModule
	end

	CachedMeshEmitResolved = true

	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	local SkillsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild("Skills")
	if not SkillsFolder then
		return nil
	end

	local ModuleInstance: Instance? = SkillVfxUtils.FindChildByAliases(SkillsFolder, { MESH_EMIT_MODULE_NAME }, true)
	if not ModuleInstance or not ModuleInstance:IsA("ModuleScript") then
		return nil
	end

	local Success: boolean, Result: any = pcall(require, ModuleInstance)
	if not Success then
		return nil
	end

	if type(Result) == "function" then
		local EmitFunction: (Instance) -> () = Result :: (Instance) -> ()
		CachedMeshEmitModule = function(Target: Instance): ()
			EnsureWorkspaceTempContainer()
			EmitFunction(Target)
		end
		return CachedMeshEmitModule
	end

	if type(Result) == "table" and type((Result :: any).emit) == "function" then
		local EmitFunction: any = (Result :: any).emit
		CachedMeshEmitModule = function(Target: Instance): ()
			EnsureWorkspaceTempContainer()
			local MethodSuccess: boolean = pcall(function()
				EmitFunction(Result, Target)
			end)
			if MethodSuccess then
				return
			end

			EmitFunction(Target)
		end
		return CachedMeshEmitModule
	end

	return nil
end

local function EnsureEffectsFolder(Character: Model): Folder
	local Existing: Instance? = Character:FindFirstChild(EFFECTS_FOLDER_NAME)
	if Existing and Existing:IsA("Folder") then
		return Existing
	end

	local FolderInstance: Folder = Instance.new("Folder")
	FolderInstance.Name = EFFECTS_FOLDER_NAME
	FolderInstance.Parent = Character
	return FolderInstance
end

local function BuildClonePath(PathPrefix: {string}, Name: string): {string}
	local ClonePath: {string} = {}
	for _, Segment in PathPrefix do
		table.insert(ClonePath, Segment)
	end
	table.insert(ClonePath, Name)
	return ClonePath
end

local function AlignAttachedClone(
	SourceContainer: Instance,
	SourceChild: Instance,
	Clone: Instance,
	TargetPart: BasePart
): ()
	local SourceContainerCFrame: CFrame? = SkillVfxUtils.GetInstanceCFrame(SourceContainer)
	local SourceChildCFrame: CFrame? = SkillVfxUtils.GetInstanceCFrame(SourceChild)
	if not SourceContainerCFrame or not SourceChildCFrame then
		return
	end

	local RelativeCFrame: CFrame = SourceContainerCFrame:ToObjectSpace(SourceChildCFrame)
	SkillVfxUtils.SetInstanceCFrame(Clone, TargetPart.CFrame * RelativeCFrame)
	SkillVfxUtils.AttachToRootPreservingOffset(TargetPart, Clone, PLAYER_EFFECT_WELD_NAME)
end

local function CloneChildEffectsIntoState(
	State: PlaybackState,
	SourceContainer: Instance,
	TargetParent: Instance,
	EffectsFolder: Folder,
	PathPrefix: {string}
): ()
	for _, Child in SourceContainer:GetChildren() do
		local Clone: Instance = Child:Clone()
		if (Clone:IsA("BasePart") or Clone:IsA("Model")) and TargetParent:IsA("BasePart") then
			Clone.Parent = EffectsFolder
			AlignAttachedClone(SourceContainer, Child, Clone, TargetParent)
		else
			Clone.Parent = TargetParent
		end

		RegisterInstance(State, Clone)
		local ClonePath: {string} = BuildClonePath(PathPrefix, Clone.Name)
		RegisterTree(State, Clone, ClonePath)
	end
end

local function ClonePlayerProxy(State: PlaybackState, Character: Model, PlayerProxy: Instance): ()
	local HighlightTemplate: Instance? = SkillVfxUtils.FindChildByAliases(PlayerProxy, { "Highlight" }, true)
	if HighlightTemplate and HighlightTemplate:IsA("Highlight") then
		local HighlightClone: Highlight = HighlightTemplate:Clone()
		HighlightClone.FillTransparency = DEFAULT_FILL_TRANSPARENCY
		HighlightClone.OutlineTransparency = DEFAULT_OUTLINE_TRANSPARENCY
		HighlightClone.Enabled = true
		HighlightClone.Parent = Character
		State.Highlight = HighlightClone
		RegisterInstance(State, HighlightClone)
		RegisterLookup(State, { "Highlight" }, HighlightClone)
	end

	local EffectsFolder: Folder = EnsureEffectsFolder(Character)
	for _, Child in PlayerProxy:GetChildren() do
		if Child:IsA("ModuleScript") then
			local Clone: ModuleScript = Child:Clone()
			Clone.Parent = EffectsFolder
			RegisterInstance(State, Clone)
			RegisterLookup(State, { Clone.Name }, Clone)
			continue
		end

		if not (Child:IsA("BasePart") or Child:IsA("Folder") or Child:IsA("Model")) then
			continue
		end

		local TargetPart: Instance? = Character:FindFirstChild(Child.Name, true)
		if not TargetPart then
			continue
		end

		CloneChildEffectsIntoState(State, Child, TargetPart, EffectsFolder, { Child.Name })
	end
end

local PrepareAnchoredParticlePart: (Part: BasePart) -> ()
local AnchorDetachedClone: (Target: Instance) -> ()

local function ResolveSkillFolder(Config: SkillConfig): Instance?
	local SkillsFolder: Instance? = SkillVfxUtils.GetSkillsFolder()
	if not SkillsFolder then
		return nil
	end

	local TesterFolder: Instance? = SkillVfxUtils.FindChildByAliases(SkillsFolder, TESTER_STYLE_ALIASES, false)
	if not TesterFolder then
		return nil
	end

	return SkillVfxUtils.FindChildByAliases(TesterFolder, Config.SkillFolderAliases, true)
end

local function ResolveWorldTemplateAliases(Config: SkillConfig): {string}
	return Config.WorldTemplateAliases or VFX_MODEL_ALIASES
end

local function ResolvePlayerProxyAliases(Config: SkillConfig): {string}
	return Config.PlayerProxyAliases or PLAYER_PROXY_ALIASES
end

local function MatchesAlias(Name: string, Aliases: {string}): boolean
	local NormalizedName: string = SkillVfxUtils.NormalizeName(Name)
	for _, Alias in Aliases do
		if NormalizedName == SkillVfxUtils.NormalizeName(Alias) then
			return true
		end
	end

	return false
end

local function ShouldAttachWorldCloneToRoot(Config: SkillConfig): boolean
	return Config.AttachWorldCloneToRoot ~= false
end

local function ShouldPlayAnimationOnClient(Config: SkillConfig): boolean
	return Config.PlayAnimationOnClient ~= false
end

local function ResolveWorldTemplate(SkillFolder: Instance?, Config: SkillConfig): Instance?
	return SkillVfxUtils.FindChildByAliases(SkillFolder, ResolveWorldTemplateAliases(Config), true)
end

local function ResolvePlayerProxyTemplate(SkillFolder: Instance?, WorldTemplate: Instance?, Config: SkillConfig): Instance?
	local PlayerProxyAliases: {string} = ResolvePlayerProxyAliases(Config)
	if SkillFolder then
		for _, Child in SkillFolder:GetChildren() do
			if Child ~= WorldTemplate and MatchesAlias(Child.Name, PlayerProxyAliases) then
				return Child
			end
		end
	end

	return SkillVfxUtils.FindChildByAliases(WorldTemplate, PlayerProxyAliases, true)
end

local function ResolveRelativeInstancePath(Ancestor: Instance, Descendant: Instance): {string}?
	local Segments: {string} = {}
	local Current: Instance? = Descendant

	while Current ~= nil and Current ~= Ancestor do
		table.insert(Segments, 1, Current.Name)
		Current = Current.Parent
	end

	if Current ~= Ancestor then
		return nil
	end

	return Segments
end

local function FindInstanceByPath(Root: Instance, PathSegments: {string}): Instance?
	local Current: Instance? = Root

	for _, Segment in PathSegments do
		if Current == nil then
			return nil
		end

		Current = Current:FindFirstChild(Segment)
	end

	return Current
end

local function RemovePlayerProxyFromWorldClone(
	WorldTemplate: Instance,
	WorldClone: Instance,
	PlayerProxyTemplate: Instance?
): ()
	if PlayerProxyTemplate == nil or PlayerProxyTemplate == WorldTemplate then
		return
	end
	if not PlayerProxyTemplate:IsDescendantOf(WorldTemplate) then
		return
	end

	local RelativePath: {string}? = ResolveRelativeInstancePath(WorldTemplate, PlayerProxyTemplate)
	if RelativePath == nil then
		return
	end

	local ProxyClone: Instance? = FindInstanceByPath(WorldClone, RelativePath)
	if ProxyClone ~= nil then
		ProxyClone:Destroy()
	end
end

local function CloneTopLevelSkillModule(State: PlaybackState, Character: Model, SourceModule: ModuleScript): ()
	local EffectsFolder: Folder = EnsureEffectsFolder(Character)
	local Clone: ModuleScript = SourceModule:Clone()
	Clone.Parent = EffectsFolder
	RegisterInstance(State, Clone)
	RegisterLookup(State, { Clone.Name }, Clone)
end

local function CloneAuxiliarySkillRoot(
	State: PlaybackState,
	Character: Model,
	Root: BasePart,
	WorldTemplate: Instance,
	SpawnCFrame: CFrame,
	SourceRoot: Instance,
	Config: SkillConfig
): ()
	if SourceRoot:IsA("Animation") then
		return
	end

	if SourceRoot:IsA("ModuleScript") then
		CloneTopLevelSkillModule(State, Character, SourceRoot)
		return
	end

	if not (SourceRoot:IsA("Model") or SourceRoot:IsA("BasePart")) then
		return
	end

	local Clone: Instance = SourceRoot:Clone()
	Clone.Parent = workspace

	local TemplateCFrame: CFrame? = SkillVfxUtils.GetInstanceCFrame(WorldTemplate)
	local SourceCFrame: CFrame? = SkillVfxUtils.GetInstanceCFrame(SourceRoot)
	if TemplateCFrame and SourceCFrame then
		local RelativeCFrame: CFrame = TemplateCFrame:ToObjectSpace(SourceCFrame)
		SkillVfxUtils.SetInstanceCFrame(Clone, SpawnCFrame * RelativeCFrame)
	end

	if ShouldAttachWorldCloneToRoot(Config) then
		SkillVfxUtils.AttachToRootPreservingOffset(Root, Clone, WORLD_WELD_NAME)
	elseif Config.AnchorDetachedWorldClone == true then
		AnchorDetachedClone(Clone)
	end
	RegisterInstance(State, Clone)
	RegisterTree(State, Clone, { Clone.Name })
end

local function BuildWorldClone(State: PlaybackState, Root: BasePart, Config: SkillConfig, SkillFolder: Instance?): ()
	local WorldTemplate: Instance? = ResolveWorldTemplate(SkillFolder, Config)
	if not WorldTemplate then
		return
	end

	local Character: Model? = Root.Parent
	if not Character or not Character:IsA("Model") then
		return
	end

	local SpawnCFrame: CFrame = SkillVfxUtils.ResolveOffsetTransformCFrame(
		Root.CFrame,
		Config.WorldOffset,
		Config.WorldOrientationOffset,
		Config.UseWorldSpacePositionOffset,
		Config.UseAbsoluteOrientationOffset
	)

	local PlayerProxyTemplate: Instance? = ResolvePlayerProxyTemplate(SkillFolder, WorldTemplate, Config)
	if PlayerProxyTemplate then
		ClonePlayerProxy(State, Character, PlayerProxyTemplate)
	end

	local WorldClone: Instance = WorldTemplate:Clone()
	RemovePlayerProxyFromWorldClone(WorldTemplate, WorldClone, PlayerProxyTemplate)

	WorldClone.Parent = workspace
	SkillVfxUtils.SetInstanceCFrame(WorldClone, SpawnCFrame)
	if ShouldAttachWorldCloneToRoot(Config) then
		SkillVfxUtils.AttachToRootPreservingOffset(Root, WorldClone, WORLD_WELD_NAME)
	elseif Config.AnchorDetachedWorldClone == true then
		AnchorDetachedClone(WorldClone)
	end
	State.WorldBaseTarget = WorldClone
	State.WorldBaseCFrame = SpawnCFrame
	RegisterInstance(State, WorldClone)
	RegisterTree(State, WorldClone, {})

	if not SkillFolder then
		return
	end

	for _, Child in SkillFolder:GetChildren() do
		if Child == WorldTemplate or Child == PlayerProxyTemplate then
			continue
		end
		if MatchesAlias(Child.Name, ResolvePlayerProxyAliases(Config)) then
			continue
		end

		CloneAuxiliarySkillRoot(State, Character, Root, WorldTemplate, SpawnCFrame, Child, Config)
	end
end

PrepareAnchoredParticlePart = function(Part: BasePart): ()
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.Massless = true
	Part.AssemblyLinearVelocity = Vector3.zero
	Part.AssemblyAngularVelocity = Vector3.zero
end

AnchorDetachedClone = function(Target: Instance): ()
	for _, Part in SkillVfxUtils.CollectBaseParts(Target) do
		PrepareAnchoredParticlePart(Part)
	end
end

local function RemoveTesterWelds(Target: Instance): ()
	local function RemoveFrom(Container: Instance): ()
		for _, Child in Container:GetChildren() do
			if (Child:IsA("Weld") or Child:IsA("WeldConstraint") or Child:IsA("ManualWeld"))
				and (Child.Name == WORLD_WELD_NAME or Child.Name == PLAYER_EFFECT_WELD_NAME)
			then
				Child:Destroy()
			end
		end
	end

	RemoveFrom(Target)
	for _, Descendant in Target:GetDescendants() do
		RemoveFrom(Descendant)
	end
end

local function DetachAttachedParticleParts(State: PlaybackState, Config: SkillConfig): ()
	if Config.DetachAttachedParticlePartsOnStart ~= true then
		return
	end

	local ProcessedParts: {[BasePart]: boolean} = {}
	for _, InstanceItem in State.Instances do
		if InstanceItem.Parent == nil then
			continue
		end

		RemoveTesterWelds(InstanceItem)

		for _, Part in SkillVfxUtils.CollectBaseParts(InstanceItem) do
			if ProcessedParts[Part] then
				continue
			end
			PrepareAnchoredParticlePart(Part)
			ProcessedParts[Part] = true
		end
	end
end

local function ResolvePlaybackBaseCFrame(State: PlaybackState, BasePath: {string}?): CFrame?
	local BaseTarget: Instance? = FindTarget(State, BasePath)
	local BaseTargetCFrame: CFrame? = SkillVfxUtils.GetInstanceCFrame(BaseTarget)
	if BaseTargetCFrame then
		return BaseTargetCFrame
	end

	local WorldBaseTarget: Instance? = State.WorldBaseTarget
	if WorldBaseTarget and WorldBaseTarget.Parent ~= nil then
		local WorldBaseTargetCFrame: CFrame? = SkillVfxUtils.GetInstanceCFrame(WorldBaseTarget)
		if WorldBaseTargetCFrame then
			return WorldBaseTargetCFrame
		end
	end

	return State.WorldBaseCFrame
end

local function SetHighlight(State: PlaybackState, FillTransparency: number, OutlineTransparency: number): ()
	local HighlightInstance: Highlight? = State.Highlight
	if not HighlightInstance or HighlightInstance.Parent == nil then
		return
	end

	HighlightInstance.FillTransparency = FillTransparency
	HighlightInstance.OutlineTransparency = OutlineTransparency
	HighlightInstance.Enabled = true
end

local function EmitPath(State: PlaybackState, PathSegments: {string}?): ()
	local Target: Instance? = FindTarget(State, PathSegments)
	if not Target then
		return
	end

	SkillVfxUtils.Emit(Target)
end

local function CollectMeshStartParts(Target: Instance): {BasePart}
	local StartParts: {BasePart} = {}
	local SeenParts: {[BasePart]: boolean} = {}
	local NormalizedStartName: string = SkillVfxUtils.NormalizeName(START_PART_NAME)

	local function IsValidMeshStartPart(Item: BasePart): boolean
		if SkillVfxUtils.NormalizeName(Item.Name) ~= NormalizedStartName then
			return false
		end

		local Parent: Instance? = Item.Parent
		if not Parent then
			return false
		end

		return Parent:FindFirstChild("End") ~= nil
	end

	local function TryAdd(Item: Instance): ()
		if not Item:IsA("BasePart") then
			return
		end

		if not IsValidMeshStartPart(Item) then
			return
		end

		if SeenParts[Item] then
			return
		end

		SeenParts[Item] = true
		table.insert(StartParts, Item)
	end

	TryAdd(Target)
	for _, Descendant in Target:GetDescendants() do
		TryAdd(Descendant)
	end

	return StartParts
end

local function EmitMeshPath(State: PlaybackState, PathSegments: {string}?): ()
	local Target: Instance? = FindTarget(State, PathSegments)
	if not Target then
		return
	end

	local StartParts: {BasePart} = CollectMeshStartParts(Target)
	if #StartParts <= 0 then
		SkillVfxUtils.Emit(Target)
		return
	end

	local MeshEmitModule: ((Instance) -> ())? = ResolveMeshEmitModule()
	if not MeshEmitModule then
		SkillVfxUtils.Emit(Target)
		return
	end

	local AnySucceeded: boolean = false
	for _, StartPart in StartParts do
		local StartSuccess: boolean = pcall(MeshEmitModule, StartPart)
		if StartSuccess then
			AnySucceeded = true
		end
	end

	if AnySucceeded then
		return
	end

	SkillVfxUtils.Emit(Target)
end

local function ApplyRelativeCFrameValue(
	State: PlaybackState,
	PathSegments: {string}?,
	BasePath: {string}?,
	RelativeCFrame: CFrame?
): ()
	local Target: Instance? = FindTarget(State, PathSegments)
	if not Target or not RelativeCFrame then
		return
	end

	local BaseCFrame: CFrame? = ResolvePlaybackBaseCFrame(State, BasePath)
	if not BaseCFrame then
		return
	end

	local WorldCFrame: CFrame = SkillVfxUtils.ResolveWorldCFrame(BaseCFrame, RelativeCFrame)
	SkillVfxUtils.SetInstanceCFrame(Target, WorldCFrame)
end

local function ApplyRelativeCFrame(State: PlaybackState, Event: TimelineEvent): ()
	ApplyRelativeCFrameValue(State, Event.Path, Event.BasePath, Event.RelativeCFrame)
end

local function ResolveTimelineFrameTime(Frame: number): number
	return math.max(Frame, 0) / TIMELINE_FPS
end

local function BuildRelativeCFrameTrackKey(Event: TimelineEvent): string
	local PathKey: string = SkillVfxUtils.NormalizePath(Event.Path or {})
	local BasePathKey: string = SkillVfxUtils.NormalizePath(Event.BasePath or {})
	local LocalOnlyKey: string = if Event.LocalOnly == true then "local" else "shared"
	return string.format("%s|%s|%s", PathKey, BasePathKey, LocalOnlyKey)
end

local function SampleRelativeCFrameTrack(Keyframes: {TimelineEvent}, ElapsedTime: number): CFrame?
	local CurrentEvent: TimelineEvent = Keyframes[1]
	local CurrentRelativeCFrame: CFrame? = CurrentEvent.RelativeCFrame
	if not CurrentRelativeCFrame then
		return nil
	end

	local CurrentTime: number = ResolveTimelineFrameTime(CurrentEvent.Frame)
	if ElapsedTime <= CurrentTime + KEYFRAME_TIME_EPSILON then
		return CurrentRelativeCFrame
	end

	for Index = 2, #Keyframes do
		local NextEvent: TimelineEvent = Keyframes[Index]
		local NextRelativeCFrame: CFrame? = NextEvent.RelativeCFrame
		if not NextRelativeCFrame then
			continue
		end

		local NextTime: number = ResolveTimelineFrameTime(NextEvent.Frame)
		if ElapsedTime <= NextTime + KEYFRAME_TIME_EPSILON then
			local SegmentDuration: number = math.max(NextTime - CurrentTime, KEYFRAME_TIME_EPSILON)
			local Alpha: number = math.clamp((ElapsedTime - CurrentTime) / SegmentDuration, 0, 1)
			return CurrentRelativeCFrame:Lerp(NextRelativeCFrame, Alpha)
		end

		CurrentEvent = NextEvent
		CurrentRelativeCFrame = NextRelativeCFrame
		CurrentTime = NextTime
	end

	return CurrentRelativeCFrame
end

local function StartRelativeCFrameTracks(State: PlaybackState, Tracks: {RelativeCFrameTrack}): ()
	for _, TrackData in Tracks do
		if TrackData.LocalOnly == true and not State.IsLocal then
			continue
		end

		table.sort(TrackData.Keyframes, function(Left: TimelineEvent, Right: TimelineEvent): boolean
			return Left.Frame < Right.Frame
		end)

		local LastKeyframe: TimelineEvent = TrackData.Keyframes[#TrackData.Keyframes]
		local LastKeyframeTime: number = ResolveTimelineFrameTime(LastKeyframe.Frame)
		local StartAt: number = os.clock()
		local Connection: RBXScriptConnection? = nil

		local function Step(): ()
			if not State.Active then
				if Connection then
					Connection:Disconnect()
				end
				return
			end

			local ElapsedTime: number = os.clock() - StartAt
			local RelativeCFrame: CFrame? = SampleRelativeCFrameTrack(TrackData.Keyframes, ElapsedTime)
			ApplyRelativeCFrameValue(State, TrackData.Path, TrackData.BasePath, RelativeCFrame)

			if ElapsedTime >= LastKeyframeTime + KEYFRAME_TIME_EPSILON and Connection then
				Connection:Disconnect()
			end
		end

		Step()
		Connection = RunService.Heartbeat:Connect(Step)
		RegisterConnection(State, Connection)
	end
end

local function BuildFovRequestId(Config: SkillConfig, State: PlaybackState): string
	return string.format("%s::%d", Config.FovRequestId, State.Token)
end

local function StartEndFov(State: PlaybackState, Config: SkillConfig): ()
	if not State.IsLocal then
		return
	end

	State.FovSequence += 1
	local Sequence: number = State.FovSequence
	local RequestId: string = BuildFovRequestId(Config, State)
	State.FovRequestId = RequestId

	FOVController.AddRequest(RequestId, Config.EndFovTarget, Config.EndFovPriority, {
		TweenInfo = TweenInfo.new(Config.EndFovInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})

	task.delay(Config.EndFovHoldTime, function()
		if State.FovSequence ~= Sequence then
			return
		end

		if State.FovRequestId == RequestId then
			State.FovRequestId = nil
		end

		FOVController.RemoveRequest(RequestId)
	end)
end

local function HandleTimelineEvent(State: PlaybackState, Event: TimelineEvent): ()
	if not State.Active then
		return
	end

	if Event.LocalOnly == true and not State.IsLocal then
		return
	end

	if Event.Kind == TIMELINE_KIND_EMIT then
		EmitPath(State, Event.Path)
		EmitMeshPath(State, Event.MeshPath)
		return
	end

	if Event.Kind == TIMELINE_KIND_HIGHLIGHT then
		SetHighlight(
			State,
			if Event.FillTransparency ~= nil then Event.FillTransparency else DEFAULT_FILL_TRANSPARENCY,
			if Event.OutlineTransparency ~= nil then Event.OutlineTransparency else DEFAULT_OUTLINE_TRANSPARENCY
		)
		return
	end

	if Event.Kind == TIMELINE_KIND_VIGNETTE then
		EmitPath(State, { "Vignette" })
		return
	end

	if Event.Kind == TIMELINE_KIND_SET_RELATIVE_CFRAME then
		ApplyRelativeCFrame(State, Event)
	end
end

local function HandleMarkerEvents(State: PlaybackState, Config: SkillConfig, MarkerName: string): ()
	local MarkerEvents: {[string]: {TimelineEvent}}? = Config.MarkerEvents
	if not MarkerEvents then
		return
	end

	local Events: {TimelineEvent}? = MarkerEvents[MarkerName]
	if not Events then
		return
	end

	for _, Event in Events do
		HandleTimelineEvent(State, Event)
	end
end

local function ScheduleTimeline(State: PlaybackState, Config: SkillConfig): ()
	local EventsByFrame: {[number]: {TimelineEvent}} = {}
	local OrderedFrames: {number} = {}
	local RelativeCFrameTracksByKey: {[string]: RelativeCFrameTrack} = {}
	local RelativeCFrameTracks: {RelativeCFrameTrack} = {}

	for _, Event in Config.Timeline do
		if Event.Kind == TIMELINE_KIND_SET_RELATIVE_CFRAME and Event.Path and Event.RelativeCFrame then
			local TrackKey: string = BuildRelativeCFrameTrackKey(Event)
			local TrackData: RelativeCFrameTrack? = RelativeCFrameTracksByKey[TrackKey]
			if not TrackData then
				TrackData = {
					Key = TrackKey,
					Path = Event.Path,
					BasePath = Event.BasePath,
					LocalOnly = Event.LocalOnly,
					Keyframes = {},
				}
				RelativeCFrameTracksByKey[TrackKey] = TrackData
				table.insert(RelativeCFrameTracks, TrackData)
			end

			table.insert(TrackData.Keyframes, Event)
			continue
		end

		local Frame: number = math.max(Event.Frame, 0)
		local FrameEvents: {TimelineEvent}? = EventsByFrame[Frame]
		if not FrameEvents then
			FrameEvents = {}
			EventsByFrame[Frame] = FrameEvents
			table.insert(OrderedFrames, Frame)
		end

		table.insert(FrameEvents, Event)
	end

	table.sort(OrderedFrames)
	StartRelativeCFrameTracks(State, RelativeCFrameTracks)

	for _, Frame in OrderedFrames do
		local DelayTime: number = Frame / TIMELINE_FPS
		local FrameEvents: {TimelineEvent} = EventsByFrame[Frame]
		task.delay(DelayTime, function()
			if not State.Active then
				return
			end

			for _, Event in FrameEvents do
				HandleTimelineEvent(State, Event)
			end
		end)
	end
end

local function DisconnectState(State: PlaybackState): ()
	GlobalFunctions.DisconnectAll(State.Connections)
	State.Connections = {}
end

function TesterSkillUtils.Create(Config: SkillConfig): {[string]: any}
	local ActiveStates: {[number]: PlaybackState} = {}

	local function CleanupState(SourceUserId: number, RemoveFov: boolean?): ()
		local State: PlaybackState? = ActiveStates[SourceUserId]
		if not State then
			return
		end

		ActiveStates[SourceUserId] = nil
		State.Active = false
		DisconnectState(State)

		if State.Track then
			State.Track:Stop()
			State.Track:Destroy()
			State.Track = nil
		end

		if State.Highlight then
			State.Highlight.FillTransparency = DEFAULT_FILL_TRANSPARENCY
			State.Highlight.OutlineTransparency = DEFAULT_OUTLINE_TRANSPARENCY
		end

		if RemoveFov == true and State.IsLocal then
			State.FovSequence += 1
			if State.FovRequestId then
				FOVController.RemoveRequest(State.FovRequestId)
				State.FovRequestId = nil
			end
		end

		SkillVfxUtils.CleanupInstanceList(State.Instances)
	end

	local function SendStart(State: PlaybackState): ()
		if not State.IsLocal or State.StartSent then
			return
		end
		if Config.SendStartPhase == false then
			State.StartSent = true
			return
		end

		State.StartSent = true
		Packets.SkillPhase:Fire(Config.TypeName, State.Token, PHASE_ACTION_START)
	end

	local function HandleStart(State: PlaybackState): ()
		if State.StartHandled then
			return
		end

		State.StartHandled = true
		DetachAttachedParticleParts(State, Config)
		SendStart(State)
	end

	local function SendEnd(State: PlaybackState): ()
		if not State.IsLocal or State.EndSent then
			return
		end

		State.EndSent = true
		StartEndFov(State, Config)
		Packets.SkillPhase:Fire(Config.TypeName, State.Token, PHASE_ACTION_END)
	end

	local function Begin(SourceUserId: number, Token: number): ()
		CleanupState(SourceUserId, true)

		local SourcePlayer: Player? = ResolveSourcePlayer(SourceUserId)
		local Character: Model? = SourcePlayer and SourcePlayer.Character
		local Root: BasePart? = GlobalFunctions.GetRoot(Character)
		if not SourcePlayer or not Character or not Root then
			return
		end

		local SkillFolder: Instance? = ResolveSkillFolder(Config)
		if not SkillFolder then
			return
		end

		local State: PlaybackState = CreateState(SourceUserId == LocalPlayer.UserId, Token)
		ActiveStates[SourceUserId] = State

		BuildWorldClone(State, Root, Config, SkillFolder)
		ScheduleTimeline(State, Config)
		SkillAssetPreloader.WarmupAnimationIdsForModel(Character, { Config.AnimationId })

		if not ShouldPlayAnimationOnClient(Config) then
			HandleStart(State)
			return
		end

		local Track: AnimationTrack? =
			CutsceneRigUtils.LoadAnimationTrack(
				Character,
				Config.AnimationId,
				Config.AnimationPriority or DEFAULT_ANIMATION_PRIORITY
			)
		if not Track then
			CleanupState(SourceUserId, true)
			return
		end

		Track.Looped = false
		Track:Play()
		if type(Config.AnimationSpeed) == "number" and Config.AnimationSpeed > 0 then
			Track:AdjustSpeed(Config.AnimationSpeed)
		end
		State.Track = Track

		RegisterConnection(State, Track:GetMarkerReachedSignal(START_MARKER_NAME):Connect(function()
			HandleStart(State)
		end))

		RegisterConnection(State, Track:GetMarkerReachedSignal(END_MARKER_NAME):Connect(function()
			SendEnd(State)
		end))

		RegisterConnection(State, Track.Stopped:Connect(function()
			SendEnd(State)
		end))
	end

	local function End(SourceUserId: number, Token: number): ()
		local State: PlaybackState? = ActiveStates[SourceUserId]
		if not State or State.Token ~= Token then
			return
		end

		CleanupState(SourceUserId, false)
	end

	local function Marker(SourceUserId: number, Token: number, MarkerName: string): ()
		local State: PlaybackState? = ActiveStates[SourceUserId]
		if not State or State.Token ~= Token or MarkerName == "" then
			return
		end

		HandleMarkerEvents(State, Config, MarkerName)
	end

	local Module = {}

	function Module.Start(Data: {[string]: any}): ()
		local Action: string = tostring(Data.Action or "")
		local TokenValue: any = Data.Token
		local SourceUserIdValue: any = Data.SourceUserId

		if type(TokenValue) ~= "number" then
			return
		end
		if type(SourceUserIdValue) ~= "number" then
			return
		end

		local Token: number = math.floor(TokenValue + 0.5)
		local SourceUserId: number = math.floor(SourceUserIdValue + 0.5)

		if Action == "Start" then
			Begin(SourceUserId, Token)
			return
		end

		if Action == "End" then
			End(SourceUserId, Token)
			return
		end

		if Action == "Marker" then
			local MarkerName: string = tostring(Data.MarkerName or Data.Marker or "")
			Marker(SourceUserId, Token, MarkerName)
		end
	end

	function Module.Cleanup(): ()
		for SourceUserId in ActiveStates do
			CleanupState(SourceUserId, true)
		end
	end

	return Module
end

function TesterSkillUtils.CreateRecordedCFrameEvent(Config: RecordedCFrameEventConfig): TimelineEvent
	return {
		Frame = Config.Frame,
		Kind = TIMELINE_KIND_SET_RELATIVE_CFRAME,
		Path = Config.Path,
		BasePath = Config.BasePath,
		RelativeCFrame = SkillVfxUtils.ResolveRelativeCFrame(Config.ReferenceBaseCFrame, Config.RecordedCFrame),
		LocalOnly = Config.LocalOnly,
	}
end

function TesterSkillUtils.CreateRecordedCFrameTrackEvents(Config: RecordedCFrameTrackConfig): {TimelineEvent}
	local Events: {TimelineEvent} = {}
	for _, Keyframe in Config.Keyframes do
		table.insert(Events, TesterSkillUtils.CreateRecordedCFrameEvent({
			Frame = Keyframe.Frame,
			Path = Config.Path,
			ReferenceBaseCFrame = Config.ReferenceBaseCFrame,
			RecordedCFrame = Keyframe.RecordedCFrame,
			BasePath = Config.BasePath,
			LocalOnly = Config.LocalOnly,
		}))
	end

	return Events
end

return TesterSkillUtils
