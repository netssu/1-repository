--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local Workspace: Workspace = game:GetService("Workspace")

local ASSETS_FOLDER_NAME: string = "Assets"
local EFFECTS_FOLDER_NAME: string = "Effects"
local WIND_TEMPLATE_NAME: string = "Wind"
local CAMERA_EFFECT_NAME: string = "FTCameraWindVFX"
local OWNER_ATTRIBUTE: string = "FTCameraWindOwner"
local OWNER_VALUE: string = "WindVFXController"
local DEFAULT_KEY: string = "Default"

local DEFAULT_CAMERA_OFFSET: Vector3 = Vector3.new(0, 0, -4)
local DEFAULT_REFERENCE_VIEWPORT: Vector2 = Vector2.new(1920, 1080)
local DEFAULT_REFERENCE_FIELD_OF_VIEW: number = 70
local DEFAULT_SPEED_REF: number = 24
local DEFAULT_RATE_MULTIPLIER: number = 1
local DEFAULT_MIN_RATE_MULTIPLIER: number = 0
local DEFAULT_BASE_RATE: number = 18
local DEFAULT_MIN_RATE: number = 4
local DEFAULT_INPUT_DEADZONE: number = 0.05
local DEFAULT_STOP_DEADZONE: number = 0.8

type ScreenScaleMode = "Width" | "Height" | "Min" | "Max"

export type WindConfig = {
	Priority: number?,
	ForceEnabled: boolean?,
	RequireGrounded: boolean?,
	CameraOffset: Vector3?,
	ScaleToScreen: boolean?,
	ReferenceViewport: Vector2?,
	ReferenceFieldOfView: number?,
	ScreenScaleMode: ScreenScaleMode?,
	ScreenScaleMultiplier: number?,
	MinScreenScale: number?,
	MaxScreenScale: number?,
	SpeedRef: number?,
	RateMultiplier: number?,
	MinRateMultiplier: number?,
	BaseRate: number?,
	MinRate: number?,
	InputDeadzone: number?,
	StopDeadzone: number?,
	Color: Color3?,
	ColorSequence: ColorSequence?,
	Transparency: NumberSequence?,
	SizeScale: number?,
	SpeedScale: number?,
	DragMultiplier: number?,
	Acceleration: Vector3?,
	LightEmission: number?,
	BrightnessMultiplier: number?,
	LightRangeScale: number?,
}

type WindRequest = {
	Humanoid: Humanoid,
	Config: WindConfig,
	Order: number,
}

type ParticleState = {
	Emitter: ParticleEmitter,
	Rate: number,
	BaseRate: number,
	Color: ColorSequence,
	Transparency: NumberSequence,
	Size: NumberSequence,
	Speed: NumberRange,
	Drag: number,
	Acceleration: Vector3,
	LightEmission: number,
	Brightness: number,
}

type BeamState = {
	Beam: Beam,
	Color: ColorSequence,
	Transparency: NumberSequence,
	Width0: number,
	Width1: number,
}

type TrailState = {
	Trail: Trail,
	Color: ColorSequence,
	Transparency: NumberSequence,
	WidthScale: NumberSequence,
}

type LightState = {
	Light: Light,
	Color: Color3,
	Brightness: number,
	Range: number,
}

type GenericEnabledState = {
	Item: Instance,
}

type BasePartState = {
	Part: BasePart,
	Size: Vector3,
}

type ModelScaleState = {
	Model: Model,
	Scale: number,
}

type AttachmentState = {
	Attachment: Attachment,
	Position: Vector3,
}

type SpecialMeshState = {
	Mesh: SpecialMesh,
	Scale: Vector3,
}

local WindVFXController = {}

WindVFXController.PRESET_RUN = "Run"
WindVFXController.PRESET_SKILL = "Skill"
WindVFXController.PRESET_BURST = "Burst"

local TemplateCache: Instance? = nil
local TemplateWarnedMissing: boolean = false

local ActiveRequests: {[string]: WindRequest} = {}
local RequestCounter: number = 0

local UpdateConnection: RBXScriptConnection? = nil
local ActiveClone: Instance? = nil
local ParticleStates: {ParticleState} = {}
local BeamStates: {BeamState} = {}
local TrailStates: {TrailState} = {}
local LightStates: {LightState} = {}
local GenericEnabledStates: {GenericEnabledState} = {}
local ModelScaleStates: {ModelScaleState} = {}
local BasePartStates: {BasePartState} = {}
local AttachmentStates: {AttachmentState} = {}
local SpecialMeshStates: {SpecialMeshState} = {}

local Presets: {[string]: WindConfig} = {
	Run = {
		Priority = 0,
		RequireGrounded = true,
		ForceEnabled = false,
		CameraOffset = DEFAULT_CAMERA_OFFSET,
		ScaleToScreen = true,
		ReferenceViewport = DEFAULT_REFERENCE_VIEWPORT,
		ReferenceFieldOfView = DEFAULT_REFERENCE_FIELD_OF_VIEW,
		ScreenScaleMode = "Max",
		ScreenScaleMultiplier = 1,
		MinScreenScale = 1,
		SpeedRef = DEFAULT_SPEED_REF,
		RateMultiplier = 1.35,
		MinRateMultiplier = 0.2,
		BaseRate = 26,
		MinRate = 8,
		InputDeadzone = DEFAULT_INPUT_DEADZONE,
		StopDeadzone = DEFAULT_STOP_DEADZONE,
		SizeScale = 1,
		SpeedScale = 1,
		DragMultiplier = 1,
		BrightnessMultiplier = 1,
		LightRangeScale = 1,
	},
	Skill = {
		Priority = 10,
		RequireGrounded = false,
		ForceEnabled = true,
		CameraOffset = Vector3.new(0, 0, -5.5),
		ScaleToScreen = true,
		ReferenceViewport = DEFAULT_REFERENCE_VIEWPORT,
		ReferenceFieldOfView = DEFAULT_REFERENCE_FIELD_OF_VIEW,
		ScreenScaleMode = "Max",
		ScreenScaleMultiplier = 1,
		MinScreenScale = 1,
		SpeedRef = 18,
		RateMultiplier = 1.75,
		MinRateMultiplier = 1,
		BaseRate = 24,
		MinRate = 12,
		InputDeadzone = 0,
		StopDeadzone = 0,
		SizeScale = 1.35,
		SpeedScale = 1.15,
		DragMultiplier = 1,
		BrightnessMultiplier = 1.1,
		LightRangeScale = 1.15,
	},
	Burst = {
		Priority = 20,
		RequireGrounded = false,
		ForceEnabled = true,
		CameraOffset = Vector3.new(0, 0, -7),
		ScaleToScreen = true,
		ReferenceViewport = DEFAULT_REFERENCE_VIEWPORT,
		ReferenceFieldOfView = DEFAULT_REFERENCE_FIELD_OF_VIEW,
		ScreenScaleMode = "Max",
		ScreenScaleMultiplier = 1,
		MinScreenScale = 1,
		SpeedRef = 14,
		RateMultiplier = 2.25,
		MinRateMultiplier = 1.25,
		BaseRate = 30,
		MinRate = 16,
		InputDeadzone = 0,
		StopDeadzone = 0,
		SizeScale = 1.7,
		SpeedScale = 1.35,
		DragMultiplier = 1,
		BrightnessMultiplier = 1.2,
		LightRangeScale = 1.25,
	},
}

local function CloneConfig(Config: WindConfig?): WindConfig
	local Result: WindConfig = {}
	if not Config then
		return Result
	end
	for Key, Value in Config do
		(Result :: any)[Key] = Value
	end
	return Result
end

local function MergeConfig(Base: WindConfig?, Override: WindConfig?): WindConfig
	local Result: WindConfig = CloneConfig(Base)
	if not Override then
		return Result
	end
	for Key, Value in Override do
		if Value ~= nil then
			(Result :: any)[Key] = Value
		end
	end
	return Result
end

local function ScaleNumberSequence(Sequence: NumberSequence, Scale: number): NumberSequence
	local Keypoints = table.create(#Sequence.Keypoints)
	for Index, Keypoint in Sequence.Keypoints do
		Keypoints[Index] = NumberSequenceKeypoint.new(
			Keypoint.Time,
			Keypoint.Value * Scale,
			Keypoint.Envelope * Scale
		)
	end
	return NumberSequence.new(Keypoints)
end

local function ScaleNumberRange(Range: NumberRange, Scale: number): NumberRange
	return NumberRange.new(Range.Min * Scale, Range.Max * Scale)
end

local function ResolveColorSequence(Config: WindConfig, Fallback: ColorSequence): ColorSequence
	if Config.ColorSequence then
		return Config.ColorSequence
	end
	if Config.Color then
		return ColorSequence.new(Config.Color)
	end
	return Fallback
end

local function ResolvePrimaryColor(Config: WindConfig, Fallback: Color3): Color3
	if Config.Color then
		return Config.Color
	end
	if Config.ColorSequence then
		local Keypoints = Config.ColorSequence.Keypoints
		if #Keypoints > 0 then
			return Keypoints[1].Value
		end
	end
	return Fallback
end

local function GetTemplate(): Instance?
	if TemplateCache and TemplateCache.Parent then
		return TemplateCache
	end

	local AssetsFolder = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
		or ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME, 5)
	if not AssetsFolder then
		return nil
	end

	local EffectsFolder = AssetsFolder:FindFirstChild(EFFECTS_FOLDER_NAME)
		or AssetsFolder:WaitForChild(EFFECTS_FOLDER_NAME, 5)
	if not EffectsFolder then
		return nil
	end

	local Template = EffectsFolder:FindFirstChild(WIND_TEMPLATE_NAME)
		or EffectsFolder:WaitForChild(WIND_TEMPLATE_NAME, 5)
	if Template then
		TemplateCache = Template
		return Template
	end

	if not TemplateWarnedMissing then
		TemplateWarnedMissing = true
		warn("WindVFXController: asset ReplicatedStorage.Assets.Effects.Wind not found")
	end

	return nil
end

local function SupportsEnabledProperty(Item: Instance): boolean
	local Success, Result = pcall(function()
		return (Item :: any).Enabled
	end)
	return Success and typeof(Result) == "boolean"
end

local function SetInstanceEnabled(Item: Instance, Enabled: boolean): ()
	pcall(function()
		(Item :: any).Enabled = Enabled
	end)
end

local function ResolveEmitterBaseRate(Emitter: ParticleEmitter): number
	for _, AttributeName in { "WindBaseRate", "BaseRate", "RateBase" } do
		local AttributeValue = Emitter:GetAttribute(AttributeName)
		if typeof(AttributeValue) == "number" and AttributeValue > 0 then
			return AttributeValue
		end
	end

	if Emitter.Rate > 0 then
		return Emitter.Rate
	end

	return DEFAULT_BASE_RATE
end

local function FindGeometryTarget(Root: Instance): Instance?
	if Root:IsA("Model") or Root:IsA("BasePart") then
		return Root
	end

	local ModelTarget = Root:FindFirstChildWhichIsA("Model", true)
	if ModelTarget then
		return ModelTarget
	end

	return Root:FindFirstChildWhichIsA("BasePart", true)
end

local function GetModelBaseScale(TargetModel: Model): number
	local Success, Result = pcall(function()
		return TargetModel:GetScale()
	end)
	if Success and typeof(Result) == "number" and Result > 0 then
		return Result
	end
	return 1
end

local function ResolveTanHalfFov(FieldOfView: number): number
	return math.tan(math.rad(math.max(FieldOfView, 1)) * 0.5)
end

local function ResolveScreenScale(Camera: Camera, Config: WindConfig): number
	local ScaleMultiplier = Config.ScreenScaleMultiplier or 1
	if Config.ScaleToScreen == false then
		return ScaleMultiplier
	end

	local ViewportSize = Camera.ViewportSize
	local ReferenceViewport = Config.ReferenceViewport or DEFAULT_REFERENCE_VIEWPORT
	local ViewportHeight = math.max(ViewportSize.Y, 1)
	local ReferenceHeight = math.max(ReferenceViewport.Y, 1)
	local ViewportAspect = ViewportSize.X / ViewportHeight
	local ReferenceAspect = ReferenceViewport.X / ReferenceHeight

	local FieldOfViewScale = ResolveTanHalfFov(Camera.FieldOfView)
		/ math.max(ResolveTanHalfFov(Config.ReferenceFieldOfView or DEFAULT_REFERENCE_FIELD_OF_VIEW), 0.001)
	local WidthScale = ViewportAspect / math.max(ReferenceAspect, 0.001)
	local HeightScale = 1
	local ScaleMode: ScreenScaleMode = (Config.ScreenScaleMode or "Max") :: ScreenScaleMode

	local ScreenScale = FieldOfViewScale
	if ScaleMode == "Width" then
		ScreenScale *= WidthScale
	elseif ScaleMode == "Min" then
		ScreenScale *= math.min(WidthScale, HeightScale)
	elseif ScaleMode == "Height" then
		ScreenScale *= HeightScale
	else
		ScreenScale *= math.max(WidthScale, HeightScale)
	end

	ScreenScale *= ScaleMultiplier

	local MinScreenScale = Config.MinScreenScale
	local MaxScreenScale = Config.MaxScreenScale
	if MinScreenScale ~= nil and MaxScreenScale ~= nil then
		return math.clamp(ScreenScale, MinScreenScale, MaxScreenScale)
	end
	if MinScreenScale ~= nil then
		return math.max(ScreenScale, MinScreenScale)
	end
	if MaxScreenScale ~= nil then
		return math.min(ScreenScale, MaxScreenScale)
	end

	return ScreenScale
end

local function SetCloneEnabled(Enabled: boolean): ()
	for _, State in ParticleStates do
		State.Emitter.Enabled = Enabled
		if not Enabled then
			State.Emitter.Rate = 0
		end
	end

	for _, State in BeamStates do
		State.Beam.Enabled = Enabled
	end

	for _, State in TrailStates do
		State.Trail.Enabled = Enabled
	end

	for _, State in LightStates do
		State.Light.Enabled = Enabled
	end

	for _, State in GenericEnabledStates do
		SetInstanceEnabled(State.Item, Enabled)
	end
end

local function CollectCloneState(Root: Instance): ()
	table.clear(ParticleStates)
	table.clear(BeamStates)
	table.clear(TrailStates)
	table.clear(LightStates)
	table.clear(GenericEnabledStates)
	table.clear(ModelScaleStates)
	table.clear(BasePartStates)
	table.clear(AttachmentStates)
	table.clear(SpecialMeshStates)

	local GeometryTarget = FindGeometryTarget(Root)
	local ScaledModel = if GeometryTarget and GeometryTarget:IsA("Model") then GeometryTarget else nil
	if ScaledModel then
		table.insert(ModelScaleStates, {
			Model = ScaledModel,
			Scale = GetModelBaseScale(ScaledModel),
		})
	end

	local function Collect(Item: Instance): ()
		if Item:IsA("ParticleEmitter") then
			table.insert(ParticleStates, {
				Emitter = Item,
				Rate = Item.Rate,
				BaseRate = ResolveEmitterBaseRate(Item),
				Color = Item.Color,
				Transparency = Item.Transparency,
				Size = Item.Size,
				Speed = Item.Speed,
				Drag = Item.Drag,
				Acceleration = Item.Acceleration,
				LightEmission = Item.LightEmission,
				Brightness = Item.Brightness,
			})
			return
		end

		if Item:IsA("Beam") then
			table.insert(BeamStates, {
				Beam = Item,
				Color = Item.Color,
				Transparency = Item.Transparency,
				Width0 = Item.Width0,
				Width1 = Item.Width1,
			})
			return
		end

		if Item:IsA("Trail") then
			table.insert(TrailStates, {
				Trail = Item,
				Color = Item.Color,
				Transparency = Item.Transparency,
				WidthScale = Item.WidthScale,
			})
			return
		end

		if Item:IsA("Light") then
			table.insert(LightStates, {
				Light = Item,
				Color = Item.Color,
				Brightness = Item.Brightness,
				Range = Item.Range,
			})
			return
		end

		if Item:IsA("BasePart") then
			if ScaledModel and Item:IsDescendantOf(ScaledModel) then
				return
			end
			table.insert(BasePartStates, {
				Part = Item,
				Size = Item.Size,
			})
		end

		if Item:IsA("Attachment") then
			if ScaledModel and Item:IsDescendantOf(ScaledModel) then
				return
			end
			table.insert(AttachmentStates, {
				Attachment = Item,
				Position = Item.Position,
			})
			return
		end

		if Item:IsA("SpecialMesh") then
			if ScaledModel and Item:IsDescendantOf(ScaledModel) then
				return
			end
			table.insert(SpecialMeshStates, {
				Mesh = Item,
				Scale = Item.Scale,
			})
			return
		end

		if SupportsEnabledProperty(Item) then
			table.insert(GenericEnabledStates, {
				Item = Item,
			})
		end
	end

	Collect(Root)
	for _, Descendant in Root:GetDescendants() do
		Collect(Descendant)
	end

	SetCloneEnabled(false)
end

local function DestroyClone(): ()
	if ActiveClone then
		ActiveClone:Destroy()
		ActiveClone = nil
	end
	table.clear(ParticleStates)
	table.clear(BeamStates)
	table.clear(TrailStates)
	table.clear(LightStates)
	table.clear(GenericEnabledStates)
	table.clear(ModelScaleStates)
	table.clear(BasePartStates)
	table.clear(AttachmentStates)
	table.clear(SpecialMeshStates)
end

local function EnsureClone(): boolean
	local Camera = Workspace.CurrentCamera
	if not Camera then
		return false
	end

	if ActiveClone and ActiveClone.Parent == Camera then
		return true
	end

	if ActiveClone and ActiveClone.Parent ~= nil and ActiveClone:GetAttribute(OWNER_ATTRIBUTE) == OWNER_VALUE then
		ActiveClone.Parent = Camera
		return true
	end

	DestroyClone()

	local Template = GetTemplate()
	if not Template then
		return false
	end

	local Clone = Template:Clone()
	Clone.Name = CAMERA_EFFECT_NAME
	Clone:SetAttribute(OWNER_ATTRIBUTE, OWNER_VALUE)
	Clone.Parent = Camera
	ActiveClone = Clone
	CollectCloneState(Clone)
	return true
end

local function ResolveActiveRequest(): WindRequest?
	local BestRequest: WindRequest? = nil
	local BestPriority: number = -math.huge
	local BestOrder: number = -math.huge

	for _, Request in ActiveRequests do
		local Priority = Request.Config.Priority or 0
		if not BestRequest or Priority > BestPriority or (Priority == BestPriority and Request.Order > BestOrder) then
			BestRequest = Request
			BestPriority = Priority
			BestOrder = Request.Order
		end
	end

	return BestRequest
end

local function GetRootPart(Humanoid: Humanoid): BasePart?
	local Character = Humanoid.Parent
	if not Character or not Character:IsA("Model") then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function IsHumanoidGrounded(Humanoid: Humanoid): boolean
	if Humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	local State = Humanoid:GetState()
	return State ~= Enum.HumanoidStateType.Jumping
		and State ~= Enum.HumanoidStateType.Freefall
		and State ~= Enum.HumanoidStateType.FallingDown
end

local function GetPlanarSpeed(Root: BasePart): number
	return Vector2.new(Root.AssemblyLinearVelocity.X, Root.AssemblyLinearVelocity.Z).Magnitude
end

local function ShouldShow(Humanoid: Humanoid, Root: BasePart, Config: WindConfig): boolean
	if Config.ForceEnabled == true then
		return true
	end

	if Config.RequireGrounded ~= false and not IsHumanoidGrounded(Humanoid) then
		return false
	end

	local InputDeadzone = Config.InputDeadzone or DEFAULT_INPUT_DEADZONE
	local StopDeadzone = Config.StopDeadzone or DEFAULT_STOP_DEADZONE
	return Humanoid.MoveDirection.Magnitude > InputDeadzone and GetPlanarSpeed(Root) > StopDeadzone
end

local function ResolveRateMultiplier(Humanoid: Humanoid, Root: BasePart, Config: WindConfig): number
	local SpeedRef = math.max(Config.SpeedRef or DEFAULT_SPEED_REF, 0.001)
	local SpeedFactor = GetPlanarSpeed(Root) / SpeedRef
	local Multiplier = SpeedFactor * (Config.RateMultiplier or DEFAULT_RATE_MULTIPLIER)
	local Minimum = Config.MinRateMultiplier or DEFAULT_MIN_RATE_MULTIPLIER
	return math.max(Multiplier, Minimum)
end

local function PositionClone(Camera: Camera, Config: WindConfig): ()
	local Clone = ActiveClone
	if not Clone then
		return
	end

	local TargetCFrame = Camera.CFrame * CFrame.new(Config.CameraOffset or DEFAULT_CAMERA_OFFSET)
	if Clone:IsA("Model") then
		Clone:PivotTo(TargetCFrame)
		return
	end

	if Clone:IsA("BasePart") then
		Clone.CFrame = TargetCFrame
		return
	end

	local ModelTarget = Clone:FindFirstChildWhichIsA("Model", true)
	if ModelTarget then
		ModelTarget:PivotTo(TargetCFrame)
		return
	end

	local PartTarget = Clone:FindFirstChildWhichIsA("BasePart", true)
	if PartTarget then
		PartTarget.CFrame = TargetCFrame
	end
end

local function ApplyAppearance(Camera: Camera, Config: WindConfig, RateMultiplier: number): ()
	local ColorSequenceValue: ColorSequence? = nil
	if Config.ColorSequence or Config.Color then
		ColorSequenceValue = ResolveColorSequence(Config, ColorSequence.new(Color3.new(1, 1, 1)))
	end

	local TransparencyValue: NumberSequence? = Config.Transparency
	local ScreenScale = ResolveScreenScale(Camera, Config)
	local SizeScale = (Config.SizeScale or 1) * ScreenScale
	local SpeedScale = Config.SpeedScale or 1
	local DragMultiplier = Config.DragMultiplier or 1
	local BrightnessMultiplier = Config.BrightnessMultiplier or 1
	local LightRangeScale = (Config.LightRangeScale or 1) * ScreenScale
	local MinimumRate = Config.MinRate or DEFAULT_MIN_RATE

	for _, State in ModelScaleStates do
		pcall(function()
			State.Model:ScaleTo(State.Scale * ScreenScale)
		end)
	end

	for _, State in BasePartStates do
		State.Part.Size = State.Size * ScreenScale
	end

	for _, State in AttachmentStates do
		State.Attachment.Position = State.Position * ScreenScale
	end

	for _, State in SpecialMeshStates do
		State.Mesh.Scale = State.Scale * ScreenScale
	end

	for _, State in ParticleStates do
		local Emitter = State.Emitter
		Emitter.Color = if ColorSequenceValue then ColorSequenceValue else State.Color
		Emitter.Transparency = TransparencyValue or State.Transparency
		Emitter.Size = if SizeScale ~= 1 then ScaleNumberSequence(State.Size, SizeScale) else State.Size
		Emitter.Speed = if SpeedScale ~= 1 then ScaleNumberRange(State.Speed, SpeedScale) else State.Speed
		Emitter.Drag = State.Drag * DragMultiplier
		Emitter.Acceleration = if Config.Acceleration then Config.Acceleration else State.Acceleration
		Emitter.LightEmission = if Config.LightEmission ~= nil then Config.LightEmission else State.LightEmission
		Emitter.Brightness = State.Brightness * BrightnessMultiplier
		Emitter.Rate = math.max(State.BaseRate * RateMultiplier, MinimumRate)
	end

	for _, State in BeamStates do
		local Beam = State.Beam
		Beam.Color = if ColorSequenceValue then ColorSequenceValue else State.Color
		Beam.Transparency = TransparencyValue or State.Transparency
		Beam.Width0 = State.Width0 * SizeScale
		Beam.Width1 = State.Width1 * SizeScale
	end

	for _, State in TrailStates do
		local Trail = State.Trail
		Trail.Color = if ColorSequenceValue then ColorSequenceValue else State.Color
		Trail.Transparency = TransparencyValue or State.Transparency
		Trail.WidthScale = if SizeScale ~= 1 then ScaleNumberSequence(State.WidthScale, SizeScale) else State.WidthScale
	end

	for _, State in LightStates do
		local Light = State.Light
		Light.Color = ResolvePrimaryColor(Config, State.Color)
		Light.Brightness = State.Brightness * BrightnessMultiplier
		Light.Range = State.Range * LightRangeScale
	end
end

local function StopController(): ()
	if UpdateConnection then
		UpdateConnection:Disconnect()
		UpdateConnection = nil
	end
	DestroyClone()
end

local function EnsureUpdateLoop(): ()
	if UpdateConnection then
		return
	end

	UpdateConnection = RunService.RenderStepped:Connect(function()
		local ActiveRequest = ResolveActiveRequest()
		local Camera = Workspace.CurrentCamera

		if not ActiveRequest or not Camera then
			SetCloneEnabled(false)
			return
		end

		if not EnsureClone() then
			return
		end

		if ActiveClone and ActiveClone.Parent ~= Camera then
			ActiveClone.Parent = Camera
		end

		local Humanoid = ActiveRequest.Humanoid
		if not Humanoid.Parent then
			SetCloneEnabled(false)
			return
		end

		local Root = GetRootPart(Humanoid)
		if not Root then
			SetCloneEnabled(false)
			return
		end

		PositionClone(Camera, ActiveRequest.Config)

		if not ShouldShow(Humanoid, Root, ActiveRequest.Config) then
			SetCloneEnabled(false)
			return
		end

		ApplyAppearance(Camera, ActiveRequest.Config, ResolveRateMultiplier(Humanoid, Root, ActiveRequest.Config))
		SetCloneEnabled(true)
	end)
end

function WindVFXController.RegisterPreset(_self: typeof(WindVFXController), Name: string, Config: WindConfig): ()
	Presets[Name] = CloneConfig(Config)
end

function WindVFXController.GetPreset(_self: typeof(WindVFXController), Name: string): WindConfig
	return CloneConfig(Presets[Name])
end

function WindVFXController.Acquire(_self: typeof(WindVFXController), Key: string, Humanoid: Humanoid, Config: WindConfig?): ()
	local ExistingRequest = ActiveRequests[Key]
	if not ExistingRequest then
		RequestCounter += 1
	end
	ActiveRequests[Key] = {
		Humanoid = Humanoid,
		Config = MergeConfig(Presets.Run, Config),
		Order = if ExistingRequest then ExistingRequest.Order else RequestCounter,
	}
	EnsureUpdateLoop()
end

function WindVFXController.AcquirePreset(
	self: typeof(WindVFXController),
	Key: string,
	Humanoid: Humanoid,
	PresetName: string,
	Overrides: WindConfig?
): ()
	self:Acquire(Key, Humanoid, MergeConfig(Presets[PresetName], Overrides))
end

function WindVFXController.Release(_self: typeof(WindVFXController), Key: string): ()
	if ActiveRequests[Key] == nil then
		return
	end

	ActiveRequests[Key] = nil
	if next(ActiveRequests) ~= nil then
		return
	end

	StopController()
end

function WindVFXController.Play(_self: typeof(WindVFXController), Humanoid: Humanoid, Config: WindConfig?): ()
	WindVFXController:Acquire(DEFAULT_KEY, Humanoid, Config)
end

function WindVFXController.PlayPreset(
	self: typeof(WindVFXController),
	Humanoid: Humanoid,
	PresetName: string,
	Overrides: WindConfig?
): ()
	self:AcquirePreset(DEFAULT_KEY, Humanoid, PresetName, Overrides)
end

function WindVFXController.Stop(_self: typeof(WindVFXController)): ()
	self:Release(DEFAULT_KEY)
end

return WindVFXController
