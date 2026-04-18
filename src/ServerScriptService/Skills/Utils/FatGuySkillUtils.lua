--!strict

local Debris: Debris = game:GetService("Debris")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local Workspace: Workspace = game:GetService("Workspace")

local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local CutsceneRigUtils: any = require(ReplicatedStorage.Modules.Game.Skills.VFX.Client.Init.CutsceneRigUtils)
local PlaySoundAt: any = require(ReplicatedStorage.Modules.Platform.PlaySoundAt)

export type MovementState = {
	RootAnchoredBefore: boolean,
	AutoRotateBefore: boolean,
	WalkSpeedBefore: number,
	JumpPowerBefore: number,
	JumpHeightBefore: number,
	UseJumpPowerBefore: boolean,
	PlatformStandBefore: boolean,
	HumanoidStateBefore: Enum.HumanoidStateType,
	PhysicsStateForced: boolean,
}

export type BeginSkillOptions = {
	AnchorRoot: boolean?,
	CaptureNetworkOwner: boolean?,
	ForcePhysicsState: boolean?,
	StartInvulnerable: boolean?,
}

export type SkillSession = {
	Player: Player,
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Forward: Vector3,
	RootGroundOffset: number,
	MovementState: MovementState,
	OriginalNetworkOwner: Player?,
	NetworkOwnerCaptured: boolean,
	Active: boolean,
	CleanupCallbacks: {() -> ()},
}

type FrameEvent = {
	Frame: number,
	Callback: () -> (),
}

type TweenOptions = {
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	Forward: Vector3?,
}

type TriggerEffectOptions = {
	AnchorPart: BasePart?,
	Offset: Vector3?,
	AttachToAnchor: boolean?,
	PreserveRotation: boolean?,
}

type ReleaseEffectOptions = {
	EnableEffects: boolean?,
}

type SpawnVfxOptions = {
	AttachToRoot: boolean?,
	PreserveRotation: boolean?,
	UseCharacterPivot: boolean?,
	UseWorldSpaceOffset: boolean?,
	UseWeldAttachment: boolean?,
}

local FatGuySkillUtils = {}

local ZERO: number = 0
local ONE: number = 1
local MIN_DIRECTION_MAGNITUDE: number = 1e-4
local DEFAULT_TIMELINE_FPS: number = 60
local DEFAULT_WELD_NAME: string = "FatGuySkillWeld"
local DEFAULT_EMIT_COUNT: number = 10
local DEFAULT_VFX_DESTROY_DELAY: number = 3
local DEFAULT_SOUND_VOLUME: number = 0.5
local DEFAULT_SOUND_ROLLOFF_MAX_DISTANCE: number = 75
local GROUND_RAY_HEIGHT: number = 24
local GROUND_RAY_DISTANCE: number = 80
local GROUND_CLEARANCE: number = 0.8
local UP_VECTOR: Vector3 = Vector3.new(0, 1, 0)
local FALLBACK_FORWARD: Vector3 = Vector3.new(0, 0, -1)
local ATTR_INVULNERABLE: string = "Invulnerable"
local ASSETS_FOLDER_NAME: string = "Assets"
local SKILLS_FOLDER_NAME: string = "Skills"

local FAT_GUY_STYLE_ALIASES: {string} = {
	"Kurita",
	"Kuritas",
	"FatGuys",
	"FatGuy",
}

local WarmedAnimationIdsByCharacter: {[Model]: {[string]: boolean}} =
	setmetatable({}, { __mode = "k" }) :: {[Model]: {[string]: boolean}}

local VFX_MODEL_ALIASES: {string} = {
	"VfxModel",
	"VFXModel",
}

local function NormalizeAnimationId(AnimationId: string | number): string
	local RawId: string = tostring(AnimationId)
	if string.sub(RawId, 1, #"rbxassetid://") == "rbxassetid://" then
		return RawId
	end
	return "rbxassetid://" .. RawId
end

local function NormalizeSoundId(SoundId: string | number): string
	local RawId: string = tostring(SoundId)
	if string.sub(RawId, 1, #"rbxassetid://") == "rbxassetid://" then
		return RawId
	end
	return "rbxassetid://" .. RawId
end

local function ResolveNumericSoundId(SoundId: string | number): number?
	if type(SoundId) == "number" then
		return SoundId
	end

	local Digits: string? = string.match(SoundId, "%d+")
	return if Digits then tonumber(Digits) else nil
end

local function ResolveForward(Direction: Vector3): Vector3
	local Flattened: Vector3 = GlobalFunctions.FlattenDirection(Direction)
	if Flattened.Magnitude > MIN_DIRECTION_MAGNITUDE then
		return Flattened.Unit
	end
	return FALLBACK_FORWARD
end

local function GetSkillsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	if not AssetsFolder then
		return nil
	end
	return AssetsFolder:FindFirstChild(SKILLS_FOLDER_NAME)
end

local function GetCampo(): Instance?
	local GameFolder: Instance? = Workspace:FindFirstChild("Game")
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
	local Result: RaycastResult? = Workspace:Raycast(Origin, Vector3.new(0, -GROUND_RAY_DISTANCE, 0), Params)
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
		local Pivot: CFrame, Size: Vector3 = Campo:GetBoundingBox()
		return Pivot.Position.Y + (Size.Y * 0.5)
	end
	return nil
end

local function FreezeCharacterMovement(
	Root: BasePart,
	HumanoidInstance: Humanoid,
	Options: BeginSkillOptions?
): MovementState
	local State: MovementState = {
		RootAnchoredBefore = Root.Anchored,
		AutoRotateBefore = HumanoidInstance.AutoRotate,
		WalkSpeedBefore = HumanoidInstance.WalkSpeed,
		JumpPowerBefore = HumanoidInstance.JumpPower,
		JumpHeightBefore = HumanoidInstance.JumpHeight,
		UseJumpPowerBefore = HumanoidInstance.UseJumpPower,
		PlatformStandBefore = HumanoidInstance.PlatformStand,
		HumanoidStateBefore = HumanoidInstance:GetState(),
		PhysicsStateForced = Options and Options.ForcePhysicsState == true,
	}

	Root.Anchored = Options and Options.AnchorRoot == true
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	HumanoidInstance.AutoRotate = false
	HumanoidInstance.WalkSpeed = ZERO
	if HumanoidInstance.UseJumpPower then
		HumanoidInstance.JumpPower = ZERO
	else
		HumanoidInstance.JumpHeight = ZERO
	end
	HumanoidInstance.PlatformStand = false
	HumanoidInstance.Sit = false
	if State.PhysicsStateForced then
		pcall(function()
			HumanoidInstance:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	return State
end

local function CaptureNetworkOwner(Root: BasePart): Player?
	local OriginalOwner: Player? = nil
	pcall(function()
		OriginalOwner = Root:GetNetworkOwner()
	end)
	pcall(function()
		Root:SetNetworkOwnershipAuto(false)
		Root:SetNetworkOwner(nil)
	end)
	return OriginalOwner
end

local function RestoreNetworkOwner(Root: BasePart, OriginalOwner: Player?): ()
	if Root.Parent == nil then
		return
	end
	if OriginalOwner then
		pcall(function()
			Root:SetNetworkOwner(OriginalOwner)
		end)
		return
	end
	pcall(function()
		Root:SetNetworkOwnershipAuto(true)
	end)
end

local function RestoreCharacterMovement(Root: BasePart, HumanoidInstance: Humanoid, State: MovementState): ()
	Root.Anchored = State.RootAnchoredBefore
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero

	HumanoidInstance.AutoRotate = State.AutoRotateBefore
	HumanoidInstance.WalkSpeed = State.WalkSpeedBefore
	HumanoidInstance.UseJumpPower = State.UseJumpPowerBefore
	if State.UseJumpPowerBefore then
		HumanoidInstance.JumpPower = State.JumpPowerBefore
	else
		HumanoidInstance.JumpHeight = State.JumpHeightBefore
	end
	HumanoidInstance.PlatformStand = State.PlatformStandBefore
	HumanoidInstance.Sit = false
	if State.PhysicsStateForced then
		pcall(function()
			HumanoidInstance:ChangeState(State.HumanoidStateBefore)
		end)
	end
end

local function SetInvulnerable(Player: Player, Character: Model, Enabled: boolean): ()
	Player:SetAttribute(ATTR_INVULNERABLE, Enabled)
	Character:SetAttribute(ATTR_INVULNERABLE, Enabled)
end

local function ClearSkillLock(Player: Player, Character: Model): ()
	local CurrentCharacter: Model? = Player.Character or Character
	GlobalFunctions.SetSkillLock(Player, CurrentCharacter, false)
	if CurrentCharacter ~= Character then
		GlobalFunctions.SetSkillLock(nil, Character, false)
	end
end

local function ClearInvulnerable(Player: Player, Character: Model): ()
	Player:SetAttribute(ATTR_INVULNERABLE, false)
	Character:SetAttribute(ATTR_INVULNERABLE, false)
	local CurrentCharacter: Model? = Player.Character
	if CurrentCharacter and CurrentCharacter ~= Character then
		CurrentCharacter:SetAttribute(ATTR_INVULNERABLE, false)
	end
end

local function PrepareAttachedPart(Part: BasePart): ()
	Part.Anchored = false
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.CastShadow = false
	Part.Massless = true
	Part.AssemblyLinearVelocity = Vector3.zero
	Part.AssemblyAngularVelocity = Vector3.zero
end

local function CollectBaseParts(Target: Instance): {BasePart}
	local Parts: {BasePart} = {}
	if Target:IsA("BasePart") then
		table.insert(Parts, Target)
	end
	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("BasePart") then
			table.insert(Parts, Descendant)
		end
	end
	return Parts
end

local function SetPartsAnchored(Target: Instance, Anchored: boolean): ()
	for _, Part in CollectBaseParts(Target) do
		Part.Anchored = Anchored
		Part.AssemblyLinearVelocity = Vector3.zero
		Part.AssemblyAngularVelocity = Vector3.zero
	end
end

local function AttachPartsToAnchor(AnchorPart: BasePart, Parts: {BasePart}): ()
	for _, Part in Parts do
		PrepareAttachedPart(Part)
		for _, Child in Part:GetChildren() do
			if Child:IsA("WeldConstraint") and Child.Name == DEFAULT_WELD_NAME then
				Child:Destroy()
			end
		end

		local Weld: WeldConstraint = Instance.new("WeldConstraint")
		Weld.Name = DEFAULT_WELD_NAME
		Weld.Part0 = AnchorPart
		Weld.Part1 = Part
		Weld.Parent = Part
	end
end

local function AttachPartsToAnchorWithWeld(AnchorPart: BasePart, Parts: {BasePart}): ()
	for _, Part in Parts do
		PrepareAttachedPart(Part)
		for _, Child in Part:GetChildren() do
			if (Child:IsA("WeldConstraint") or Child:IsA("Weld")) and Child.Name == DEFAULT_WELD_NAME then
				Child:Destroy()
			end
		end

		local Weld: Weld = Instance.new("Weld")
		Weld.Name = DEFAULT_WELD_NAME
		Weld.Part0 = Part
		Weld.Part1 = AnchorPart
		Weld.C0 = CFrame.identity
		Weld.C1 = AnchorPart.CFrame:Inverse() * Part.CFrame
		Weld.Parent = Part
	end
end

local function RefreshWeldOffsetsFromCurrentPose(AnchorPart: BasePart, Parts: {BasePart}): ()
	for _, Part in Parts do
		for _, Child in Part:GetChildren() do
			if Child:IsA("Weld") and Child.Name == DEFAULT_WELD_NAME then
				Child.Part0 = Part
				Child.Part1 = AnchorPart
				Child.C0 = CFrame.identity
				Child.C1 = AnchorPart.CFrame:Inverse() * Part.CFrame
			end
		end
	end
end

local function RemoveDefaultWeldConstraints(Target: Instance): ()
	local function RemoveFromInstance(InstanceToClean: Instance): ()
		for _, Child in InstanceToClean:GetChildren() do
			if (Child:IsA("WeldConstraint") or Child:IsA("Weld")) and Child.Name == DEFAULT_WELD_NAME then
				Child:Destroy()
			end
		end
	end

	RemoveFromInstance(Target)
	for _, Descendant in Target:GetDescendants() do
		RemoveFromInstance(Descendant)
	end
end

local function SanitizeVfxClone(Clone: Instance): ()
	for _, Descendant in Clone:GetDescendants() do
		if Descendant:IsA("Constraint")
			or Descendant:IsA("BodyMover")
			or Descendant:IsA("Motor6D")
			or Descendant:IsA("Weld")
			or Descendant:IsA("WeldConstraint")
			or Descendant:IsA("ManualWeld")
			or Descendant:IsA("Snap")
		then
			Descendant:Destroy()
			continue
		end

		if Descendant:IsA("BasePart") then
			PrepareAttachedPart(Descendant)
		end
	end

	if Clone:IsA("BasePart") then
		PrepareAttachedPart(Clone)
	end
end

local function ResolveWorldCFrameFromCFrame(SourceCFrame: CFrame, Offset: Vector3): CFrame
	local Forward: Vector3 = ResolveForward(SourceCFrame.LookVector)
	local StableSourceCFrame: CFrame = CFrame.lookAt(SourceCFrame.Position, SourceCFrame.Position + Forward, UP_VECTOR)
	local WorldPosition: Vector3 = StableSourceCFrame:PointToWorldSpace(Offset)
	return CFrame.lookAt(WorldPosition, WorldPosition + Forward, UP_VECTOR)
end

local function ResolveWorldPositionFromCFrame(SourceCFrame: CFrame, Offset: Vector3): Vector3
	return ResolveWorldCFrameFromCFrame(SourceCFrame, Offset).Position
end

local function ResolvePlacementPosition(SourceCFrame: CFrame, Offset: Vector3, UseWorldSpaceOffset: boolean): Vector3
	if UseWorldSpaceOffset then
		return SourceCFrame.Position + Offset
	end

	return ResolveWorldPositionFromCFrame(SourceCFrame, Offset)
end

local function ResolvePlacementCFrame(SourceCFrame: CFrame, Offset: Vector3, UseWorldSpaceOffset: boolean): CFrame
	if UseWorldSpaceOffset then
		local Forward: Vector3 = ResolveForward(SourceCFrame.LookVector)
		local WorldPosition: Vector3 = SourceCFrame.Position + Offset
		return CFrame.lookAt(WorldPosition, WorldPosition + Forward, UP_VECTOR)
	end

	return ResolveWorldCFrameFromCFrame(SourceCFrame, Offset)
end

local function MoveInstanceToWorldPosition(Target: Instance, Position: Vector3): ()
	if Target:IsA("Model") then
		local Pivot: CFrame = Target:GetPivot()
		Target:PivotTo(Pivot + (Position - Pivot.Position))
	elseif Target:IsA("BasePart") then
		Target.CFrame = Target.CFrame + (Position - Target.Position)
	end
end

local function ResolveEmitCount(Emitter: ParticleEmitter): number
	local EmitCountValue: any = Emitter:GetAttribute("EmitCount")
	if type(EmitCountValue) == "number" and EmitCountValue > ZERO then
		return math.max(ONE, math.floor(EmitCountValue))
	end

	if Emitter.Rate > ZERO then
		return math.max(ONE, math.min(60, math.floor(Emitter.Rate * 0.15)))
	end

	return DEFAULT_EMIT_COUNT
end

local function ResolveCharacterSoundParent(Character: Model): Instance
	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if Root then Root else Character
end

local function FindCharacterSound(Character: Model?, SoundName: string): Sound?
	if not Character then
		return nil
	end

	local ExistingSound: Instance? = ResolveCharacterSoundParent(Character):FindFirstChild(SoundName)
	return if ExistingSound and ExistingSound:IsA("Sound") then ExistingSound else nil
end

local function GetOrCreateCharacterSound(Character: Model?, SoundName: string): Sound?
	if not Character then
		return nil
	end

	local SoundParent: Instance = ResolveCharacterSoundParent(Character)
	local ExistingSound: Instance? = SoundParent:FindFirstChild(SoundName)
	if ExistingSound and not ExistingSound:IsA("Sound") then
		ExistingSound:Destroy()
		ExistingSound = nil
	end

	if ExistingSound and ExistingSound:IsA("Sound") then
		return ExistingSound
	end

	local SoundInstance: Sound = Instance.new("Sound")
	SoundInstance.Name = SoundName
	SoundInstance.Parent = SoundParent
	return SoundInstance
end

local function ToggleEffectsRecursive(Target: Instance, Enabled: boolean): ()
	local function ToggleEffect(Effect: Instance): ()
		if Effect:IsA("ParticleEmitter")
			or Effect:IsA("Beam")
			or Effect:IsA("Trail")
			or Effect:IsA("Light")
			or Effect:IsA("Fire")
			or Effect:IsA("Smoke")
			or Effect:IsA("Sparkles")
		then
			(Effect :: any).Enabled = Enabled
		elseif Effect:IsA("Sound") and Enabled then
			Effect:Play()
		end
	end

	ToggleEffect(Target)
	for _, Descendant in Target:GetDescendants() do
		ToggleEffect(Descendant)
	end
end

local function DisableEffectsRecursive(Target: Instance): ()
	ToggleEffectsRecursive(Target, false)
	if Target:IsA("Sound") then
		Target:Stop()
	end
	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("Sound") then
			Descendant:Stop()
		end
	end
end

local function EmitRecursive(Target: Instance): ()
	local function Emit(Effect: Instance): ()
		if Effect:IsA("ParticleEmitter") then
			Effect:Emit(ResolveEmitCount(Effect))
			return
		end
		if Effect:IsA("Sound") then
			Effect:Play()
		end
	end

	Emit(Target)
	for _, Descendant in Target:GetDescendants() do
		Emit(Descendant)
	end
end

local function HideVisualsRecursive(Target: Instance): ()
	local function HideVisual(Visual: Instance): ()
		if Visual:IsA("BasePart") then
			Visual.Transparency = 1
			Visual.CanCollide = false
			Visual.CanTouch = false
			Visual.CanQuery = false
			return
		end
		if Visual:IsA("Decal") or Visual:IsA("Texture") then
			Visual.Transparency = 1
			return
		end
		if Visual:IsA("Highlight") then
			Visual.Enabled = false
		end
	end

	HideVisual(Target)
	for _, Descendant in Target:GetDescendants() do
		HideVisual(Descendant)
	end
end

function FatGuySkillUtils.BeginSkill(Character: Model, Options: BeginSkillOptions?): SkillSession?
	local Player: Player? = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return nil
	end

	local Root: BasePart? = GlobalFunctions.GetRoot(Character)
	local HumanoidInstance: Humanoid? = GlobalFunctions.GetHumanoid(Character)
	if not Root or not HumanoidInstance then
		return nil
	end

	local ShouldCaptureNetworkOwner: boolean = Options == nil or Options.CaptureNetworkOwner ~= false
	local ShouldStartInvulnerable: boolean = Options == nil or Options.StartInvulnerable ~= false
	local Session: SkillSession = {
		Player = Player,
		Character = Character,
		Root = Root,
		Humanoid = HumanoidInstance,
		Forward = ResolveForward(Root.CFrame.LookVector),
		RootGroundOffset = FatGuySkillUtils.ResolveRootGroundOffset(Root, HumanoidInstance),
		MovementState = FreezeCharacterMovement(Root, HumanoidInstance, Options),
		OriginalNetworkOwner = if ShouldCaptureNetworkOwner then CaptureNetworkOwner(Root) else nil,
		NetworkOwnerCaptured = ShouldCaptureNetworkOwner,
		Active = true,
		CleanupCallbacks = {},
	}

	if ShouldStartInvulnerable then
		SetInvulnerable(Player, Character, true)
	end
	GlobalFunctions.SetSkillLock(Player, Character, true)

	return Session
end

function FatGuySkillUtils.SetSessionInvulnerable(Session: SkillSession, Enabled: boolean): ()
	SetInvulnerable(Session.Player, Session.Character, Enabled)
end

function FatGuySkillUtils.RegisterCleanup(Session: SkillSession, Callback: () -> ()): ()
	table.insert(Session.CleanupCallbacks, Callback)
end

function FatGuySkillUtils.IsSessionActive(Session: SkillSession): boolean
	if not Session.Active then
		return false
	end
	if Session.Character.Parent == nil or Session.Root.Parent == nil or Session.Humanoid.Parent == nil then
		return false
	end
	return true
end

function FatGuySkillUtils.EndSkill(Session: SkillSession): ()
	if not Session.Active then
		return
	end

	Session.Active = false

	for Index = #Session.CleanupCallbacks, ONE, -ONE do
		local Callback: () -> () = Session.CleanupCallbacks[Index]
		local Success: boolean, ErrorMessage: any = pcall(Callback)
		if not Success then
			warn(string.format("FatGuySkillUtils cleanup failed for %s: %s", Session.Player.Name, tostring(ErrorMessage)))
		end
	end

	if Session.NetworkOwnerCaptured and Session.Root.Parent ~= nil then
		RestoreNetworkOwner(Session.Root, Session.OriginalNetworkOwner)
	end

	if Session.Root.Parent ~= nil and Session.Humanoid.Parent ~= nil then
		RestoreCharacterMovement(Session.Root, Session.Humanoid, Session.MovementState)
	end

	ClearSkillLock(Session.Player, Session.Character)
	ClearInvulnerable(Session.Player, Session.Character)
end

function FatGuySkillUtils.ResolveSkillFolder(SkillAliases: {string}): Instance?
	local SkillsFolder: Instance? = GetSkillsFolder()
	if not SkillsFolder then
		return nil
	end

	local StyleFolder: Instance? = CutsceneRigUtils.FindChildByAliases(SkillsFolder, FAT_GUY_STYLE_ALIASES, true)
	if not StyleFolder then
		return nil
	end

	return CutsceneRigUtils.FindChildByAliases(StyleFolder, SkillAliases, true)
end

function FatGuySkillUtils.ResolveVfxModelTemplate(SkillAliases: {string}): Instance?
	local SkillFolder: Instance? = FatGuySkillUtils.ResolveSkillFolder(SkillAliases)
	if not SkillFolder then
		return nil
	end

	return CutsceneRigUtils.FindChildByAliases(SkillFolder, VFX_MODEL_ALIASES, true)
end

function FatGuySkillUtils.SpawnAttachedVfx(
	Session: SkillSession,
	SkillAliases: {string},
	Offset: Vector3,
	Options: SpawnVfxOptions?
): Instance?
	local Template: Instance? = FatGuySkillUtils.ResolveVfxModelTemplate(SkillAliases)
	if not Template then
		return nil
	end

	local Clone: Instance = Template:Clone()
	SanitizeVfxClone(Clone)
	DisableEffectsRecursive(Clone)
	Clone.Parent = Workspace
	local CloneParts: {BasePart} = CollectBaseParts(Clone)

	local PlacementCFrame: CFrame =
		if Options ~= nil and Options.UseCharacterPivot == true
		then Session.Character:GetPivot()
		else Session.Root.CFrame
	local UseWorldSpaceOffset: boolean = Options ~= nil and Options.UseWorldSpaceOffset == true
	local ShouldPreserveRotation: boolean = Options ~= nil and Options.PreserveRotation == true
	if ShouldPreserveRotation then
		MoveInstanceToWorldPosition(Clone, ResolvePlacementPosition(PlacementCFrame, Offset, UseWorldSpaceOffset))
	else
		local TargetCFrame: CFrame = ResolvePlacementCFrame(PlacementCFrame, Offset, UseWorldSpaceOffset)
		if Clone:IsA("Model") then
			Clone:PivotTo(TargetCFrame)
		elseif Clone:IsA("BasePart") then
			Clone.CFrame = TargetCFrame
		end
	end

	local ShouldAttachToRoot: boolean = Options == nil or Options.AttachToRoot ~= false
	if ShouldAttachToRoot then
		if Options ~= nil and Options.UseWeldAttachment == true then
			AttachPartsToAnchorWithWeld(Session.Root, CloneParts)
			if ShouldPreserveRotation then
				MoveInstanceToWorldPosition(Clone, ResolvePlacementPosition(PlacementCFrame, Offset, UseWorldSpaceOffset))
			else
				local TargetCFrame: CFrame = ResolvePlacementCFrame(PlacementCFrame, Offset, UseWorldSpaceOffset)
				if Clone:IsA("Model") then
					Clone:PivotTo(TargetCFrame)
				elseif Clone:IsA("BasePart") then
					Clone.CFrame = TargetCFrame
				end
			end
			RefreshWeldOffsetsFromCurrentPose(Session.Root, CloneParts)
		else
			AttachPartsToAnchor(Session.Root, CloneParts)
		end
	else
		SetPartsAnchored(Clone, true)
	end

	return Clone
end

function FatGuySkillUtils.TriggerNamedEffects(Container: Instance?, EffectNames: {string}, TriggerOptions: TriggerEffectOptions?): ()
	if not Container then
		return
	end

	local SeenTargets: {[Instance]: boolean} = {}
	local NameLookup: {[string]: boolean} = {}
	for _, EffectName in EffectNames do
		NameLookup[CutsceneRigUtils.NormalizeName(EffectName)] = true
	end

	local function TryTrigger(Target: Instance): ()
		if not NameLookup[CutsceneRigUtils.NormalizeName(Target.Name)] then
			return
		end
		if SeenTargets[Target] then
			return
		end
		SeenTargets[Target] = true
		SetPartsAnchored(Target, false)
		if TriggerOptions and TriggerOptions.AnchorPart then
			local AnchorOffset: Vector3 = TriggerOptions.Offset or Vector3.zero
			local MoveTarget: Instance? = Target
			if not MoveTarget:IsA("Model") and not MoveTarget:IsA("BasePart") then
				MoveTarget = Target:FindFirstAncestorWhichIsA("BasePart") or Target:FindFirstAncestorWhichIsA("Model")
			end
			if MoveTarget then
				RemoveDefaultWeldConstraints(MoveTarget)
				SetPartsAnchored(MoveTarget, false)
				if TriggerOptions.PreserveRotation == true then
					MoveInstanceToWorldPosition(MoveTarget, ResolveWorldPositionFromCFrame(TriggerOptions.AnchorPart.CFrame, AnchorOffset))
				else
					local TargetCFrame: CFrame = ResolveWorldCFrameFromCFrame(TriggerOptions.AnchorPart.CFrame, AnchorOffset)
					if MoveTarget:IsA("Model") then
						MoveTarget:PivotTo(TargetCFrame)
					elseif MoveTarget:IsA("BasePart") then
						MoveTarget.CFrame = TargetCFrame
					end
				end
			end
			if TriggerOptions.AttachToAnchor ~= false then
				AttachPartsToAnchor(TriggerOptions.AnchorPart, CollectBaseParts(MoveTarget or Target))
			else
				SetPartsAnchored(MoveTarget or Target, false)
			end
		end
		ToggleEffectsRecursive(Target, true)
		EmitRecursive(Target)
	end

	TryTrigger(Container)
	for _, Descendant in Container:GetDescendants() do
		TryTrigger(Descendant)
	end
end

function FatGuySkillUtils.ReleaseNamedEffects(
	Container: Instance?,
	EffectNames: {string},
	ReleaseOptions: ReleaseEffectOptions?
): ()
	if not Container then
		return
	end

	local SeenTargets: {[Instance]: boolean} = {}
	local NameLookup: {[string]: boolean} = {}
	for _, EffectName in EffectNames do
		NameLookup[CutsceneRigUtils.NormalizeName(EffectName)] = true
	end

	local function TryRelease(Target: Instance): ()
		if not NameLookup[CutsceneRigUtils.NormalizeName(Target.Name)] then
			return
		end
		if SeenTargets[Target] then
			return
		end
		SeenTargets[Target] = true

		local MoveTarget: Instance? = Target
		if not MoveTarget:IsA("Model") and not MoveTarget:IsA("BasePart") then
			MoveTarget = Target:FindFirstAncestorWhichIsA("BasePart") or Target:FindFirstAncestorWhichIsA("Model")
		end

		local ResolvedTarget: Instance = MoveTarget or Target
		RemoveDefaultWeldConstraints(ResolvedTarget)
		SetPartsAnchored(ResolvedTarget, true)
		if ReleaseOptions == nil or ReleaseOptions.EnableEffects ~= false then
			ToggleEffectsRecursive(Target, true)
		end
		EmitRecursive(Target)
	end

	TryRelease(Container)
	for _, Descendant in Container:GetDescendants() do
		TryRelease(Descendant)
	end
end

function FatGuySkillUtils.DetachNamedEffects(Container: Instance?, EffectNames: {string}): ()
	if not Container then
		return
	end

	local SeenTargets: {[Instance]: boolean} = {}
	local NameLookup: {[string]: boolean} = {}
	for _, EffectName in EffectNames do
		NameLookup[CutsceneRigUtils.NormalizeName(EffectName)] = true
	end

	local function TryDetach(Target: Instance): ()
		if not NameLookup[CutsceneRigUtils.NormalizeName(Target.Name)] then
			return
		end
		if SeenTargets[Target] then
			return
		end
		SeenTargets[Target] = true

		local MoveTarget: Instance? = Target
		if not MoveTarget:IsA("Model") and not MoveTarget:IsA("BasePart") then
			MoveTarget = Target:FindFirstAncestorWhichIsA("BasePart") or Target:FindFirstAncestorWhichIsA("Model")
		end

		local ResolvedTarget: Instance = MoveTarget or Target
		RemoveDefaultWeldConstraints(ResolvedTarget)
		SetPartsAnchored(ResolvedTarget, true)
	end

	TryDetach(Container)
	for _, Descendant in Container:GetDescendants() do
		TryDetach(Descendant)
	end
end

function FatGuySkillUtils.ReleaseAttachedVfx(Container: Instance?): ()
	if not Container then
		return
	end

	RemoveDefaultWeldConstraints(Container)
	SetPartsAnchored(Container, true)
end

function FatGuySkillUtils.EnableNamedEffects(Container: Instance?, EffectNames: {string}): ()
	if not Container then
		return
	end

	local SeenTargets: {[Instance]: boolean} = {}
	local NameLookup: {[string]: boolean} = {}
	for _, EffectName in EffectNames do
		NameLookup[CutsceneRigUtils.NormalizeName(EffectName)] = true
	end

	local function TryEnable(Target: Instance): ()
		if not NameLookup[CutsceneRigUtils.NormalizeName(Target.Name)] then
			return
		end
		if SeenTargets[Target] then
			return
		end
		SeenTargets[Target] = true
		ToggleEffectsRecursive(Target, true)
	end

	TryEnable(Container)
	for _, Descendant in Container:GetDescendants() do
		TryEnable(Descendant)
	end
end

function FatGuySkillUtils.DisableNamedEffects(Container: Instance?, EffectNames: {string}): ()
	if not Container then
		return
	end

	local SeenTargets: {[Instance]: boolean} = {}
	local NameLookup: {[string]: boolean} = {}
	for _, EffectName in EffectNames do
		NameLookup[CutsceneRigUtils.NormalizeName(EffectName)] = true
	end

	local function TryDisable(Target: Instance): ()
		if not NameLookup[CutsceneRigUtils.NormalizeName(Target.Name)] then
			return
		end
		if SeenTargets[Target] then
			return
		end
		SeenTargets[Target] = true
		DisableEffectsRecursive(Target)
	end

	TryDisable(Container)
	for _, Descendant in Container:GetDescendants() do
		TryDisable(Descendant)
	end
end

function FatGuySkillUtils.CleanupVfxInstance(Container: Instance?, DestroyDelay: number?): ()
	if not Container then
		return
	end

	DisableEffectsRecursive(Container)
	HideVisualsRecursive(Container)
	Debris:AddItem(Container, math.max(DestroyDelay or DEFAULT_VFX_DESTROY_DELAY, 0))
end

function FatGuySkillUtils.DisableVfxEffects(Container: Instance?): ()
	if not Container then
		return
	end

	DisableEffectsRecursive(Container)
end

function FatGuySkillUtils.PlayCharacterSound(Character: Model?, SoundId: string | number, Volume: number?): ()
	if not Character then
		return
	end

	local NumericSoundId: number? = ResolveNumericSoundId(SoundId)
	if not NumericSoundId then
		return
	end

	PlaySoundAt(ResolveCharacterSoundParent(Character), NumericSoundId, Volume or DEFAULT_SOUND_VOLUME)
end

function FatGuySkillUtils.PlayManagedCharacterSound(
	Character: Model?,
	SoundName: string,
	SoundId: string | number,
	Volume: number?,
	Looped: boolean?
): Sound?
	local SoundInstance: Sound? = GetOrCreateCharacterSound(Character, SoundName)
	if not SoundInstance then
		return nil
	end

	SoundInstance.SoundId = NormalizeSoundId(SoundId)
	SoundInstance.Volume = Volume or DEFAULT_SOUND_VOLUME
	SoundInstance.RollOffMaxDistance = DEFAULT_SOUND_ROLLOFF_MAX_DISTANCE
	SoundInstance.Looped = Looped == true
	if SoundInstance.IsPlaying then
		SoundInstance:Stop()
	end
	SoundInstance.TimePosition = ZERO
	SoundInstance:Play()
	return SoundInstance
end

function FatGuySkillUtils.PlayLoopingCharacterSound(
	Character: Model?,
	SoundName: string,
	SoundId: string | number,
	Volume: number?
): Sound?
	return FatGuySkillUtils.PlayManagedCharacterSound(Character, SoundName, SoundId, Volume, true)
end

function FatGuySkillUtils.PlayReusableCharacterSound(
	Character: Model?,
	SoundName: string,
	SoundId: string | number,
	Volume: number?
): Sound?
	return FatGuySkillUtils.PlayManagedCharacterSound(Character, SoundName, SoundId, Volume, false)
end

function FatGuySkillUtils.StopCharacterSound(Character: Model?, SoundName: string, DestroySound: boolean?): ()
	local SoundInstance: Sound? = FindCharacterSound(Character, SoundName)
	if not SoundInstance then
		return
	end

	if SoundInstance.IsPlaying then
		SoundInstance:Stop()
	end
	if DestroySound ~= false then
		SoundInstance:Destroy()
	end
end

function FatGuySkillUtils.LoadAnimationTrack(Character: Model, AnimationId: string | number): AnimationTrack?
	return CutsceneRigUtils.LoadAnimationTrack(Character, NormalizeAnimationId(AnimationId), Enum.AnimationPriority.Action)
end

function FatGuySkillUtils.WarmAnimations(Character: Model, AnimationIds: {string | number}): ()
	local AnimatorInstance: Animator? = CutsceneRigUtils.GetAnimatorFromModel(Character)
	if not AnimatorInstance then
		return
	end

	local WarmedIds: {[string]: boolean}? = WarmedAnimationIdsByCharacter[Character]
	if not WarmedIds then
		WarmedIds = {}
		WarmedAnimationIdsByCharacter[Character] = WarmedIds
	end

	for _, AnimationId in AnimationIds do
		local NormalizedAnimationId: string = NormalizeAnimationId(AnimationId)
		if WarmedIds[NormalizedAnimationId] then
			continue
		end

		local AnimationInstance: Animation = Instance.new("Animation")
		AnimationInstance.AnimationId = NormalizedAnimationId

		local Success: boolean, TrackOrError: any = pcall(function()
			return AnimatorInstance:LoadAnimation(AnimationInstance)
		end)

		AnimationInstance:Destroy()

		if Success and TrackOrError then
			local Track: AnimationTrack = TrackOrError :: AnimationTrack
			pcall(function()
				Track:Play(0, 0, 0)
				Track:Stop(0)
			end)
			Track:Destroy()
			WarmedIds[NormalizedAnimationId] = true
		end
	end
end

function FatGuySkillUtils.GetTrackDuration(Track: AnimationTrack?, FallbackFrames: number?, Fps: number?): number
	if Track and Track.Length > ZERO then
		return Track.Length
	end

	local EffectiveFrames: number = math.max(FallbackFrames or ZERO, ZERO)
	local EffectiveFps: number = math.max(Fps or DEFAULT_TIMELINE_FPS, ONE)
	return EffectiveFrames / EffectiveFps
end

function FatGuySkillUtils.ResolveRootGroundOffset(Root: BasePart, HumanoidInstance: Humanoid): number
	local BaseOffset: number = (Root.Size.Y * 0.5) + math.max(HumanoidInstance.HipHeight, ZERO)
	local GroundY: number? = GetGroundY(Root.Position)
	if GroundY ~= nil then
		local MeasuredOffset: number = Root.Position.Y - GroundY
		if MeasuredOffset > 0.25 then
			return math.max(MeasuredOffset, BaseOffset)
		end
	end
	return BaseOffset
end

function FatGuySkillUtils.AlignRootToGround(Position: Vector3, RootOffset: number): Vector3
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

function FatGuySkillUtils.SetCharacterTransform(Session: SkillSession, Position: Vector3, Forward: Vector3?): ()
	local Facing: Vector3 = ResolveForward(Forward or Session.Forward)
	Session.Forward = Facing
	local TargetCFrame: CFrame = CFrame.lookAt(Position, Position + Facing, UP_VECTOR)
	Session.Root.CFrame = TargetCFrame
	Session.Root.AssemblyLinearVelocity = Vector3.zero
	Session.Root.AssemblyAngularVelocity = Vector3.zero
end

function FatGuySkillUtils.RunHeartbeatLoop(
	Duration: number?,
	IsActive: () -> boolean,
	StepCallback: (Elapsed: number, DeltaTime: number) -> boolean?
): boolean
	local MaxDuration: number? = nil
	if Duration ~= nil then
		MaxDuration = math.max(Duration, ZERO)
	end

	local StartAt: number = os.clock()
	local LastAt: number = StartAt

	while IsActive() do
		local Now: number = os.clock()
		local Elapsed: number = Now - StartAt
		local DeltaTime: number = math.clamp(Now - LastAt, 1 / 240, 1 / 20)
		LastAt = Now

		local Continue: boolean? = StepCallback(Elapsed, DeltaTime)
		if Continue == false then
			return true
		end
		if MaxDuration ~= nil and Elapsed >= MaxDuration then
			return true
		end

		RunService.Heartbeat:Wait()
	end

	return false
end

function FatGuySkillUtils.TweenCharacterPosition(
	Session: SkillSession,
	FromPosition: Vector3,
	ToPosition: Vector3,
	Duration: number,
	IsActive: () -> boolean,
	Options: TweenOptions?
): boolean
	local MoveDuration: number = math.max(Duration, ZERO)
	local EasingStyle: Enum.EasingStyle = if Options and Options.EasingStyle then Options.EasingStyle else Enum.EasingStyle.Quad
	local EasingDirection: Enum.EasingDirection =
		if Options and Options.EasingDirection then Options.EasingDirection else Enum.EasingDirection.Out
	local Facing: Vector3 = ResolveForward(if Options and Options.Forward then Options.Forward else Session.Forward)
	if MoveDuration <= ZERO then
		FatGuySkillUtils.SetCharacterTransform(Session, ToPosition, Facing)
		return true
	end

	FatGuySkillUtils.SetCharacterTransform(Session, FromPosition, Facing)

	local MoveTween: Tween = TweenService:Create(
		Session.Root,
		TweenInfo.new(MoveDuration, EasingStyle, EasingDirection),
		{
			CFrame = CFrame.lookAt(ToPosition, ToPosition + Facing, UP_VECTOR),
		}
	)
	local PlaybackState: Enum.PlaybackState? = nil
	local CompletedConnection: RBXScriptConnection = MoveTween.Completed:Connect(function(State: Enum.PlaybackState)
		PlaybackState = State
	end)

	MoveTween:Play()

	local LoopCompleted: boolean = FatGuySkillUtils.RunHeartbeatLoop(MoveDuration + (1 / 30), IsActive, function()
		Session.Root.AssemblyLinearVelocity = Vector3.zero
		Session.Root.AssemblyAngularVelocity = Vector3.zero
		if PlaybackState ~= nil then
			return false
		end
		return true
	end)

	if PlaybackState == nil then
		MoveTween:Cancel()
	end
	CompletedConnection:Disconnect()

	if not IsActive() then
		return false
	end

	FatGuySkillUtils.SetCharacterTransform(Session, ToPosition, Facing)
	return LoopCompleted and PlaybackState == Enum.PlaybackState.Completed
end

function FatGuySkillUtils.TweenCharacterArc(
	Session: SkillSession,
	FromPosition: Vector3,
	ToPosition: Vector3,
	ApexHeight: number,
	Duration: number,
	IsActive: () -> boolean,
	Options: TweenOptions?
): boolean
	local MoveDuration: number = math.max(Duration, ZERO)
	if MoveDuration <= ZERO then
		FatGuySkillUtils.SetCharacterTransform(Session, ToPosition)
		return true
	end

	local EasingStyle: Enum.EasingStyle = if Options and Options.EasingStyle then Options.EasingStyle else Enum.EasingStyle.Quad
	local EasingDirection: Enum.EasingDirection =
		if Options and Options.EasingDirection then Options.EasingDirection else Enum.EasingDirection.Out
	local VerticalArcHeight: number = math.max(ApexHeight, ZERO)

	return FatGuySkillUtils.RunHeartbeatLoop(MoveDuration, IsActive, function(Elapsed: number)
		local Alpha: number = math.clamp(Elapsed / MoveDuration, ZERO, ONE)
		local EasedAlpha: number = TweenService:GetValue(Alpha, EasingStyle, EasingDirection)
		local HorizontalPosition: Vector3 = FromPosition:Lerp(ToPosition, EasedAlpha)
		local VerticalArc: number = math.sin(EasedAlpha * math.pi) * VerticalArcHeight
		local Position: Vector3 = Vector3.new(
			HorizontalPosition.X,
			HorizontalPosition.Y + VerticalArc,
			HorizontalPosition.Z
		)
		FatGuySkillUtils.SetCharacterTransform(Session, Position)
		return Alpha < ONE
	end)
end

function FatGuySkillUtils.ScheduleFrameEvents(Events: {FrameEvent}, IsActive: () -> boolean, Fps: number?): ()
	local EffectiveFps: number = math.max(Fps or DEFAULT_TIMELINE_FPS, ONE)

	for _, Event in Events do
		local DelayTime: number = math.max(Event.Frame, ZERO) / EffectiveFps
		task.delay(DelayTime, function()
			if not IsActive() then
				return
			end
			Event.Callback()
		end)
	end
end

return FatGuySkillUtils
