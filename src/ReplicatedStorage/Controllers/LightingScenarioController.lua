--!strict

local Lighting: Lighting = game:GetService("Lighting")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local Workspace: Workspace = game:GetService("Workspace")

local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)

local LightingScenarioController = {}

local LOCAL_PLAYER: Player = Players.LocalPlayer
local ASSETS_FOLDER_NAME: string = "Assets"
local EFFECTS_FOLDER_NAME: string = "Effects"
local CAMPO_SCENARIO_NAME: string = "Campo"
local LOBBY_SCENARIO_NAME: string = "Lobby"
local LOBBY_NAME: string = "Lobby"
local GAME_FOLDER_NAME: string = "Game"
local CAMPO_ZONE_NAME: string = "CampoZone"
local PLAYER_GUI_NAME: string = "PlayerGui"
local LOADING_GUI_NAME: string = "LoadingGui"
local MANAGED_ATTRIBUTE: string = "FTScenarioLightingManaged"
local SCENARIO_ATTRIBUTE: string = "FTScenarioLightingScenario"
local INTRO_CUTSCENE_ATTRIBUTE: string = "FTMatchCutsceneLocked"
local REFRESH_INTERVAL: number = 0.25
local LIGHTING_TRANSITION_DURATION: number = 1.1

type LightingPreset = {
	Ambient: Color3,
	Brightness: number,
	ColorShift_Bottom: Color3,
	ColorShift_Top: Color3,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	GlobalShadows: boolean,
	LightingStyle: Enum.LightingStyle,
	OutdoorAmbient: Color3,
	PrioritizeLightingQuality: boolean,
	ShadowSoftness: number,
	ClockTime: number,
	GeographicLatitude: number,
	ExposureCompensation: number,
	FogColor: Color3,
	FogEnd: number,
	FogStart: number,
}

local COLOR3_LIGHTING_PROPERTIES: {string} = {
	"Ambient",
	"ColorShift_Bottom",
	"ColorShift_Top",
	"OutdoorAmbient",
	"FogColor",
}

local NUMBER_LIGHTING_PROPERTIES: {string} = {
	"Brightness",
	"EnvironmentDiffuseScale",
	"EnvironmentSpecularScale",
	"ShadowSoftness",
	"ClockTime",
	"GeographicLatitude",
	"ExposureCompensation",
	"FogEnd",
	"FogStart",
}

local LIGHTING_PRESETS: {[string]: LightingPreset} = {
	[CAMPO_SCENARIO_NAME] = {
		Ambient = Color3.fromRGB(0, 0, 0),
		Brightness = 1.59,
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ColorShift_Top = Color3.fromRGB(239, 239, 255),
		EnvironmentDiffuseScale = 0.5,
		EnvironmentSpecularScale = 0.295,
		GlobalShadows = true,
		LightingStyle = Enum.LightingStyle.Realistic,
		OutdoorAmbient = Color3.fromRGB(0, 0, 0),
		PrioritizeLightingQuality = true,
		ShadowSoftness = 0.82,
		ClockTime = 12.352,
		GeographicLatitude = 23.941,
		ExposureCompensation = 0.14,
		FogColor = Color3.fromRGB(192, 192, 192),
		FogEnd = 100000,
		FogStart = 0,
	},
	[LOBBY_SCENARIO_NAME] = {
		Ambient = Color3.fromRGB(86, 73, 55),
		Brightness = 3,
		ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 0.596,
		GlobalShadows = false,
		LightingStyle = Enum.LightingStyle.Realistic,
		OutdoorAmbient = Color3.fromRGB(70, 70, 70),
		PrioritizeLightingQuality = true,
		ShadowSoftness = 0.19,
		ClockTime = 0.457,
		GeographicLatitude = 73.41,
		ExposureCompensation = 0.21,
		FogColor = Color3.fromRGB(192, 192, 192),
		FogEnd = 100000,
		FogStart = 0,
	},
}

local Started: boolean = false
local Connections: {RBXScriptConnection} = {}
local RefreshAccumulator: number = 0
local ActiveScenario: string? = nil
local ActiveScenarioSignature: string = ""
local ActiveScenarioCloneCount: number = 0
local LightingTransitionConnection: RBXScriptConnection? = nil
local CharacterCutsceneConnection: RBXScriptConnection? = nil
local LightingPropertyWriteSupport: {[string]: boolean} = {}
local RefreshLightingScenario: (boolean?) -> ()

local function TrackConnection(Connection: RBXScriptConnection): ()
	table.insert(Connections, Connection)
end

local function StopLightingTransition(): ()
	if LightingTransitionConnection then
		LightingTransitionConnection:Disconnect()
		LightingTransitionConnection = nil
	end
end

local function BindCharacterCutsceneSignal(Character: Model?): ()
	if CharacterCutsceneConnection then
		CharacterCutsceneConnection:Disconnect()
		CharacterCutsceneConnection = nil
	end

	if not Character then
		return
	end

	CharacterCutsceneConnection = Character:GetAttributeChangedSignal(INTRO_CUTSCENE_ATTRIBUTE):Connect(function()
		RefreshLightingScenario(true)
	end)
end

local function ResolveCharacterRoot(): BasePart?
	local Character: Model? = LOCAL_PLAYER.Character
	if not Character then
		return nil
	end

	local RootPart: Instance? = Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		return RootPart
	end

	return Character.PrimaryPart
end

local function IsPointInsidePart(Part: BasePart, Position: Vector3): boolean
	local LocalPosition: Vector3 = Part.CFrame:PointToObjectSpace(Position)
	local HalfSize: Vector3 = Part.Size * 0.5

	return math.abs(LocalPosition.X) <= HalfSize.X
		and math.abs(LocalPosition.Y) <= HalfSize.Y
		and math.abs(LocalPosition.Z) <= HalfSize.Z
end

local function ResolveEffectsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	if not AssetsFolder then
		return nil
	end

	return AssetsFolder:FindFirstChild(EFFECTS_FOLDER_NAME)
end

local function ResolveScenarioFolder(ScenarioName: string): Instance?
	local EffectsFolder: Instance? = ResolveEffectsFolder()
	if not EffectsFolder then
		return nil
	end

	return EffectsFolder:FindFirstChild(ScenarioName)
end

local function IsIntroCutsceneActive(): boolean
	if LOCAL_PLAYER:GetAttribute(INTRO_CUTSCENE_ATTRIBUTE) == true then
		return true
	end

	local Character: Model? = LOCAL_PLAYER.Character
	return Character ~= nil and Character:GetAttribute(INTRO_CUTSCENE_ATTRIBUTE) == true
end

local function IsLoadingActive(): boolean
	local PlayerGui: Instance? = LOCAL_PLAYER:FindFirstChild(PLAYER_GUI_NAME)
	if not PlayerGui then
		return false
	end

	local LoadingGui: Instance? = (PlayerGui :: PlayerGui):FindFirstChild(LOADING_GUI_NAME)
	if not LoadingGui or not LoadingGui:IsA("ScreenGui") then
		return false
	end

	return LoadingGui.Enabled
end

local function IsLightingTemplate(InstanceItem: Instance): boolean
	return InstanceItem:IsA("PostEffect")
		or InstanceItem:IsA("Atmosphere")
		or InstanceItem:IsA("Sky")
		or InstanceItem:IsA("Clouds")
end

local function CollectScenarioTemplates(ScenarioFolder: Instance?): ({Instance}, string)
	if not ScenarioFolder then
		return {}, "missing"
	end

	local Templates: {Instance} = {}
	local SignatureParts: {string} = {}

	for _, Descendant in ScenarioFolder:GetDescendants() do
		if not IsLightingTemplate(Descendant) then
			continue
		end

		table.insert(Templates, Descendant)
		table.insert(SignatureParts, Descendant.ClassName .. ":" .. Descendant.Name)
	end

	table.sort(SignatureParts)

	return Templates, table.concat(SignatureParts, "|")
end

local function CountManagedScenarioClones(ScenarioName: string): number
	local Count: number = 0

	for _, Child in Lighting:GetChildren() do
		if Child:GetAttribute(MANAGED_ATTRIBUTE) ~= true then
			continue
		end
		if Child:GetAttribute(SCENARIO_ATTRIBUTE) ~= ScenarioName then
			continue
		end

		Count += 1
	end

	return Count
end

local function ClearManagedLighting(): ()
	for _, Child in Lighting:GetChildren() do
		if Child:GetAttribute(MANAGED_ATTRIBUTE) == true then
			Child:Destroy()
		end
	end
end

local function LerpClockTime(FromValue: number, ToValue: number, Alpha: number): number
	local Delta: number = ((ToValue - FromValue + 12) % 24) - 12
	local Result: number = (FromValue + (Delta * Alpha)) % 24
	if Result < 0 then
		Result += 24
	end
	return Result
end

local function CanWriteLightingProperty(PropertyName: string): boolean
	local CachedResult: boolean? = LightingPropertyWriteSupport[PropertyName]
	if CachedResult ~= nil then
		return CachedResult
	end

	local LightingAny: any = Lighting
	local Success: boolean = pcall(function()
		local CurrentValue: any = LightingAny[PropertyName]
		LightingAny[PropertyName] = CurrentValue
	end)

	LightingPropertyWriteSupport[PropertyName] = Success
	return Success
end

local function GetWritableLightingProperties(PropertyNames: {string}): {string}
	local WritablePropertyNames: {string} = {}

	for _, PropertyName in PropertyNames do
		if CanWriteLightingProperty(PropertyName) then
			table.insert(WritablePropertyNames, PropertyName)
		end
	end

	return WritablePropertyNames
end

local function SetLightingProperty(PropertyName: string, Value: any): boolean
	if not CanWriteLightingProperty(PropertyName) then
		return false
	end

	local LightingAny: any = Lighting
	local Success: boolean = pcall(function()
		LightingAny[PropertyName] = Value
	end)

	if not Success then
		LightingPropertyWriteSupport[PropertyName] = false
	end

	return Success
end

local function CaptureLightingTweenState(ColorProperties: {string}, NumberProperties: {string}): {[string]: any}
	local State: {[string]: any} = {}
	local LightingAny: any = Lighting

	for _, PropertyName in ColorProperties do
		State[PropertyName] = LightingAny[PropertyName]
	end
	for _, PropertyName in NumberProperties do
		State[PropertyName] = LightingAny[PropertyName]
	end

	return State
end

local function ApplyLightingStaticProperties(Preset: LightingPreset): ()
	SetLightingProperty("GlobalShadows", Preset.GlobalShadows)
	SetLightingProperty("LightingStyle", Preset.LightingStyle)
	SetLightingProperty("PrioritizeLightingQuality", Preset.PrioritizeLightingQuality)
end

local function ApplyLightingTweenStep(
	FromState: {[string]: any},
	Preset: LightingPreset,
	Alpha: number,
	ColorProperties: {string},
	NumberProperties: {string}
): ()
	local LightingAny: any = Lighting
	local PresetAny: any = Preset

	for _, PropertyName in ColorProperties do
		local FromValue: Color3 = FromState[PropertyName] :: Color3
		local ToValue: Color3 = PresetAny[PropertyName] :: Color3
		LightingAny[PropertyName] = FromValue:Lerp(ToValue, Alpha)
	end

	for _, PropertyName in NumberProperties do
		local FromValue: number = FromState[PropertyName] :: number
		local ToValue: number = PresetAny[PropertyName] :: number
		if PropertyName == "ClockTime" then
			Lighting.ClockTime = LerpClockTime(FromValue, ToValue, Alpha)
		else
			LightingAny[PropertyName] = FromValue + ((ToValue - FromValue) * Alpha)
		end
	end
end

local function StartLightingPresetTransition(Preset: LightingPreset): ()
	StopLightingTransition()
	ApplyLightingStaticProperties(Preset)

	local WritableColorProperties: {string} = GetWritableLightingProperties(COLOR3_LIGHTING_PROPERTIES)
	local WritableNumberProperties: {string} = GetWritableLightingProperties(NUMBER_LIGHTING_PROPERTIES)
	local FromState: {[string]: any} = CaptureLightingTweenState(WritableColorProperties, WritableNumberProperties)
	if LIGHTING_TRANSITION_DURATION <= 0 then
		ApplyLightingTweenStep(FromState, Preset, 1, WritableColorProperties, WritableNumberProperties)
		ApplyLightingStaticProperties(Preset)
		return
	end

	local Elapsed: number = 0
	LightingTransitionConnection = RunService.RenderStepped:Connect(function(DeltaTime: number)
		Elapsed += DeltaTime
		local Alpha: number = math.clamp(Elapsed / LIGHTING_TRANSITION_DURATION, 0, 1)
		ApplyLightingTweenStep(FromState, Preset, Alpha, WritableColorProperties, WritableNumberProperties)

		if Alpha >= 1 then
			ApplyLightingStaticProperties(Preset)
			StopLightingTransition()
		end
	end)
end

local function ApplyScenarioLighting(
	ScenarioName: string,
	Templates: {Instance},
	Signature: string,
	Preset: LightingPreset?
): ()
	ClearManagedLighting()

	local CloneCount: number = 0
	for _, Template in Templates do
		local Clone: Instance = Template:Clone()
		Clone.Name = Template.Name
		Clone:SetAttribute(MANAGED_ATTRIBUTE, true)
		Clone:SetAttribute(SCENARIO_ATTRIBUTE, ScenarioName)
		Clone.Parent = Lighting
		CloneCount += 1
	end

	if Preset then
		StartLightingPresetTransition(Preset)
	end

	ActiveScenario = ScenarioName
	ActiveScenarioSignature = Signature
	ActiveScenarioCloneCount = CloneCount
end

local function ResolveTargetScenario(): string
	if IsLoadingActive() then
		return CAMPO_SCENARIO_NAME
	end

	if IsIntroCutsceneActive() then
		return CAMPO_SCENARIO_NAME
	end

	local RootPart: BasePart? = ResolveCharacterRoot()
	local GameFolder: Instance? = Workspace:FindFirstChild(GAME_FOLDER_NAME)
	local CampoZone: Instance? = GameFolder and GameFolder:FindFirstChild(CAMPO_ZONE_NAME)

	if RootPart and CampoZone and CampoZone:IsA("BasePart") then
		if IsPointInsidePart(CampoZone, RootPart.Position) then
			return CAMPO_SCENARIO_NAME
		end

		return LOBBY_SCENARIO_NAME
	end

	if MatchPlayerUtils.IsPlayerActive(LOCAL_PLAYER) then
		return CAMPO_SCENARIO_NAME
	end

	return LOBBY_SCENARIO_NAME
end

RefreshLightingScenario = function(Force: boolean?): ()
	local TargetScenario: string = ResolveTargetScenario()
	local ScenarioFolder: Instance? = ResolveScenarioFolder(TargetScenario)
	local Templates: {Instance}, Signature: string = CollectScenarioTemplates(ScenarioFolder)
	local Preset: LightingPreset? = LIGHTING_PRESETS[TargetScenario]
	local CurrentManagedCloneCount: number = CountManagedScenarioClones(TargetScenario)

	if Force ~= true
		and ActiveScenario == TargetScenario
		and ActiveScenarioSignature == Signature
		and ActiveScenarioCloneCount == CurrentManagedCloneCount
	then
		return
	end

	ApplyScenarioLighting(TargetScenario, Templates, Signature, Preset)
end

function LightingScenarioController.Start(): ()
	if Started then
		return
	end
	Started = true

	BindCharacterCutsceneSignal(LOCAL_PLAYER.Character)

	TrackConnection(LOCAL_PLAYER.CharacterAdded:Connect(function(Character: Model)
		BindCharacterCutsceneSignal(Character)
		task.defer(function()
			RefreshLightingScenario(true)
		end)
	end))

	TrackConnection(LOCAL_PLAYER:GetAttributeChangedSignal(MatchPlayerUtils.GetMatchActiveAttributeName()):Connect(function()
		RefreshLightingScenario(true)
	end))
	TrackConnection(LOCAL_PLAYER:GetAttributeChangedSignal(INTRO_CUTSCENE_ATTRIBUTE):Connect(function()
		RefreshLightingScenario(true)
	end))

	local PlayerGui: Instance? = LOCAL_PLAYER:FindFirstChild(PLAYER_GUI_NAME)
	if PlayerGui and PlayerGui:IsA("PlayerGui") then
		TrackConnection(PlayerGui.DescendantAdded:Connect(function(Child: Instance)
			if Child.Name == LOADING_GUI_NAME then
				RefreshLightingScenario(true)
			end
		end))

		TrackConnection(PlayerGui.DescendantRemoving:Connect(function(Child: Instance)
			if Child.Name == LOADING_GUI_NAME then
				RefreshLightingScenario(true)
			end
		end))
	end

	TrackConnection(Workspace.ChildAdded:Connect(function(Child: Instance)
		if Child.Name == GAME_FOLDER_NAME or Child.Name == LOBBY_NAME then
			RefreshLightingScenario(true)
		end
	end))

	TrackConnection(Workspace.ChildRemoved:Connect(function(Child: Instance)
		if Child.Name == GAME_FOLDER_NAME or Child.Name == LOBBY_NAME then
			RefreshLightingScenario(true)
		end
	end))

	TrackConnection(RunService.Heartbeat:Connect(function(DeltaTime: number)
		RefreshAccumulator += DeltaTime
		if RefreshAccumulator < REFRESH_INTERVAL then
			return
		end

		RefreshAccumulator = 0
		RefreshLightingScenario(false)
	end))

	task.defer(function()
		RefreshLightingScenario(true)
	end)
end

return LightingScenarioController
