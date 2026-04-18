--!strict

local Debris: Debris = game:GetService("Debris")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local CutsceneRigUtils: any = require(script.Parent.CutsceneRigUtils)

local SkillVfxUtils = {}

local DEFAULT_DESTROY_DELAY: number = 3
local DEFAULT_EMIT_COUNT: number = 1
local DEFAULT_WELD_NAME: string = "SkillVfxWeld"
local ASSETS_FOLDER_NAME: string = "Assets"
local SKILLS_FOLDER_NAME: string = "Skills"
local VFX_MODULE_NAME: string = "vfx"
local ZERO_VECTOR3: Vector3 = Vector3.zero

local CachedVfxModule: any = nil
local CachedVfxResolved: boolean = false

local function ResolveEmitCount(Emitter: ParticleEmitter): number
	local EmitCountValue: any = Emitter:GetAttribute("EmitCount")
	if type(EmitCountValue) == "number" and EmitCountValue > 0 then
		return math.max(1, math.floor(EmitCountValue + 0.5))
	end

	return DEFAULT_EMIT_COUNT
end

local function ToggleEffect(Effect: Instance, Enabled: boolean): ()
	if Effect:IsA("ParticleEmitter")
		or Effect:IsA("Beam")
		or Effect:IsA("Trail")
		or Effect:IsA("Fire")
		or Effect:IsA("Smoke")
		or Effect:IsA("Sparkles")
	then
		(Effect :: any).Enabled = Enabled
		return
	end

	if Effect:IsA("PointLight")
		or Effect:IsA("SpotLight")
		or Effect:IsA("SurfaceLight")
	then
		Effect.Enabled = Enabled
		return
	end

	if Effect:IsA("Highlight") then
		Effect.Enabled = Enabled
		return
	end

	if Effect:IsA("Sound") then
		if Enabled then
			Effect:Play()
		else
			Effect:Stop()
		end
	end
end

local function EmitFallback(Target: Instance): ()
	if Target:IsA("ParticleEmitter") then
		Target:Emit(ResolveEmitCount(Target))
	elseif Target:IsA("Sound") then
		Target:Play()
	end

	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("ParticleEmitter") then
			Descendant:Emit(ResolveEmitCount(Descendant))
		elseif Descendant:IsA("Sound") then
			Descendant:Play()
		end
	end
end

local function PrepareAttachedPart(Part: BasePart): ()
	Part.Anchored = false
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.Massless = true
	Part.AssemblyLinearVelocity = Vector3.zero
	Part.AssemblyAngularVelocity = Vector3.zero
end

function SkillVfxUtils.NormalizeName(Name: string): string
	return CutsceneRigUtils.NormalizeName(Name)
end

function SkillVfxUtils.NormalizePath(PathSegments: {string}): string
	local NormalizedSegments: {string} = {}
	for _, Segment in PathSegments do
		table.insert(NormalizedSegments, SkillVfxUtils.NormalizeName(Segment))
	end
	return table.concat(NormalizedSegments, "/")
end

function SkillVfxUtils.FindChildByAliases(Container: Instance?, Aliases: {string}, Recursive: boolean?): Instance?
	return CutsceneRigUtils.FindChildByAliases(Container, Aliases, Recursive)
end

function SkillVfxUtils.GetSkillsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	if not AssetsFolder then
		return nil
	end

	return AssetsFolder:FindFirstChild(SKILLS_FOLDER_NAME)
end

function SkillVfxUtils.GetVfxModule(): any
	if CachedVfxResolved then
		return CachedVfxModule
	end

	CachedVfxResolved = true

	local SkillsFolder: Instance? = SkillVfxUtils.GetSkillsFolder()
	local VfxModuleInstance: Instance? = SkillsFolder and SkillVfxUtils.FindChildByAliases(SkillsFolder, { VFX_MODULE_NAME }, true)
	if not VfxModuleInstance then
		return nil
	end

	if not VfxModuleInstance:IsA("ModuleScript") then
		local InitModule: Instance? = VfxModuleInstance:FindFirstChild("init") or VfxModuleInstance:FindFirstChild("Init")
		if InitModule and InitModule:IsA("ModuleScript") then
			VfxModuleInstance = InitModule
		end
	end

	if not VfxModuleInstance:IsA("ModuleScript") then
		return nil
	end

	local Success: boolean, Result: any = pcall(require, VfxModuleInstance)
	if not Success then
		warn(string.format("[SkillVfxUtils] failed to require VFX module: %s", tostring(Result)))
		return nil
	end

	CachedVfxModule = Result
	return CachedVfxModule
end

function SkillVfxUtils.Emit(Target: Instance?): ()
	if not Target then
		return
	end

	-- The external asset VFX module can throw asynchronously inside its own emit pipeline.
	-- Use the local deterministic fallback here so cutscenes/VFX don't depend on that unstable asset code path.
	EmitFallback(Target)
end

function SkillVfxUtils.SetEffectsEnabled(Target: Instance?, Enabled: boolean): ()
	if not Target then
		return
	end

	ToggleEffect(Target, Enabled)
	for _, Descendant in Target:GetDescendants() do
		ToggleEffect(Descendant, Enabled)
	end
end

function SkillVfxUtils.DisableEffectsRecursive(Target: Instance?): ()
	SkillVfxUtils.SetEffectsEnabled(Target, false)
end

function SkillVfxUtils.HideVisualsRecursive(Target: Instance?): ()
	if not Target then
		return
	end

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

function SkillVfxUtils.CleanupInstance(Target: Instance?, DestroyDelay: number?): ()
	if not Target then
		return
	end

	SkillVfxUtils.DisableEffectsRecursive(Target)
	SkillVfxUtils.HideVisualsRecursive(Target)
	Debris:AddItem(Target, math.max(DestroyDelay or DEFAULT_DESTROY_DELAY, 0))
end

function SkillVfxUtils.CleanupInstanceList(Targets: {Instance}, DestroyDelay: number?): ()
	for _, Target in Targets do
		SkillVfxUtils.CleanupInstance(Target, DestroyDelay)
	end
end

function SkillVfxUtils.CollectBaseParts(Target: Instance): {BasePart}
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

function SkillVfxUtils.GetInstanceCFrame(Target: Instance?): CFrame?
	if not Target then
		return nil
	end

	if Target:IsA("Model") then
		return Target:GetPivot()
	end

	if Target:IsA("BasePart") then
		return Target.CFrame
	end

	if Target:IsA("Attachment") then
		return Target.WorldCFrame
	end

	return nil
end

function SkillVfxUtils.SetInstanceCFrame(Target: Instance, TargetCFrame: CFrame): ()
	if Target:IsA("Model") then
		Target:PivotTo(TargetCFrame)
		return
	end

	if Target:IsA("BasePart") then
		Target.CFrame = TargetCFrame
	end
end

function SkillVfxUtils.ResolveRelativeCFrame(ReferenceBaseCFrame: CFrame, RecordedWorldCFrame: CFrame): CFrame
	return ReferenceBaseCFrame:ToObjectSpace(RecordedWorldCFrame)
end

function SkillVfxUtils.ResolveWorldCFrame(CurrentBaseCFrame: CFrame, RelativeCFrame: CFrame): CFrame
	return CurrentBaseCFrame:ToWorldSpace(RelativeCFrame)
end

function SkillVfxUtils.MoveInstanceToPosition(Target: Instance, Position: Vector3): ()
	if Target:IsA("Model") then
		local Pivot: CFrame = Target:GetPivot()
		Target:PivotTo(Pivot + (Position - Pivot.Position))
		return
	end

	if Target:IsA("BasePart") then
		Target.CFrame += Position - Target.Position
	end
end

function SkillVfxUtils.ResolveOffsetCFrame(SourceCFrame: CFrame, Offset: Vector3): CFrame
	return SourceCFrame * CFrame.new(Offset)
end

function SkillVfxUtils.ResolveOffsetTransformCFrame(
	SourceCFrame: CFrame,
	PositionOffset: Vector3,
	OrientationOffset: Vector3?,
	UseWorldSpacePositionOffset: boolean?,
	UseAbsoluteOrientationOffset: boolean?
): CFrame
	local RotationOffset: Vector3 = OrientationOffset or ZERO_VECTOR3
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

function SkillVfxUtils.AttachToRootPreservingOffset(Root: BasePart, Target: Instance, WeldName: string?): ()
	local ResolvedWeldName: string = WeldName or DEFAULT_WELD_NAME

	for _, Part in SkillVfxUtils.CollectBaseParts(Target) do
		PrepareAttachedPart(Part)

		for _, Child in Part:GetChildren() do
			if Child:IsA("Weld") and Child.Name == ResolvedWeldName then
				Child:Destroy()
			end
		end

		local Weld: Weld = Instance.new("Weld")
		Weld.Name = ResolvedWeldName
		Weld.Part0 = Part
		Weld.Part1 = Root
		Weld.C0 = CFrame.identity
		Weld.C1 = Root.CFrame:Inverse() * Part.CFrame
		Weld.Parent = Part
	end
end

return SkillVfxUtils
