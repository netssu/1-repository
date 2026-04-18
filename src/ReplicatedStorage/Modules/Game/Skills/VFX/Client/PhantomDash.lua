--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local CameraController: any = require(ReplicatedStorage.Controllers.CameraController)
local FOVController: any = require(ReplicatedStorage.Controllers.FOVController)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local SkillVfxUtils: any = require(script.Parent.Init.SkillVfxUtils)

local PhantomDash = {}

local ASSETS_FOLDER_NAME: string = "Assets"
local SKILLS_FOLDER_NAME: string = "Skills"
local SENNA_FOLDER_NAME: string = "Senna"
local PHANTOM_DASH_FOLDER_NAME: string = "Phantom Dash"
local AURA_NAME: string = "Aura"
local VFX_NAME: string = "Phantom Step VFX"
local ANIMATION_NAME: string = "Animation"

local MARKER_POINT1: string = "point1"
local MARKER_POINT2: string = "point2"
local SKILL_TYPE_NAME: string = "PhantomDash"

local DIRECTION_SEND_INTERVAL: number = 0.05
local MIN_DIRECTION_MAGNITUDE: number = 0.01

local PRE_POINT1_ANIMATION_SPEED: number = 1.6
local POST_POINT1_ANIMATION_SPEED: number = 1.2
local END_ANIMATION_SPEED: number = 0.2

local CAMERA_SHAKE_INTENSITY: number = 0.26
local CAMERA_SHAKE_DURATION: number = 4
local CAMERA_SHAKE_NOISE_SPEED: number = 8
local CAMERA_FOV_PRE_TARGET: number = 100
local CAMERA_FOV_PRE_TIME: number = 0.16
local CAMERA_FOV_PEAK_TARGET: number = 120
local CAMERA_FOV_PEAK_TIME: number = 0.12
local CAMERA_FOV_RETURN_TIME: number = 1.1
local FOV_REQUEST_ID: string = "PhantomDash::Camera"

local SERVER_END_FALLBACK_TIME: number = 0.6
local CLEANUP_DELAY: number = 0.3
local EFFECT_DESTROY_DELAY: number = 3
local REMOTE_SOURCE_RESOLVE_TIMEOUT: number = 0.75
local REMOTE_SOURCE_RESOLVE_STEP: number = 0.05

local EMIT_COUNT_ATTRIBUTE: string = "EmitCount"
local DEFAULT_EMIT_COUNT: number = 1

local ENABLE_NAMES: {string} = {
	"embers3",
	"embers2",
	"embers",
	"Stars1",
	"Dark Background",
	"Dust2",
	"Dust",
	"Flashstep5",
	"Flashstep4",
	"Flashstep3",
	"Flashstep2",
	"Flashstep1",
	"Shine1",
}

local EMIT_NAMES: {string} = {
	"Dust",
	"Dust II",
	"Impact",
	"dust3",
	"dust2",
	"dust1",
	"Um",
	"Sw2",
	"Sw1",
	"Smoke 4",
	"Smoke 3",
	"Smoke 2",
	"Smoke",
	"ParticleEmitter4",
	"ParticleEmitter3",
	"ParticleEmitter2",
	"ParticleEmitter1",
	"Burst2",
	"Burst1",
	"Alpha2",
	"Alpha3",
	"Alpha1",
	"Air2",
	"Air1",
}

local LocalPlayer: Player = Players.LocalPlayer

type NameMap = {[string]: {Instance}}

type StateType = {
	Active: boolean,
	Token: number,
	EndReceived: boolean,
	Point1Fired: boolean,
	Point2Fired: boolean,
	Track: AnimationTrack?,
	Connections: {RBXScriptConnection},
	AuraInstances: {Instance},
	VFXInstances: {Instance},
	EnabledSet: {[Instance]: boolean},
	NameMap: NameMap,
	DirectionLastSend: number,
	ShiftLockWasEnabled: boolean,
	BaseFov: number?,
	FovTweenToken: number,
	ShakeStopper: (() -> ())?,
}

type RemoteState = {
	Token: number,
	AuraInstances: {Instance},
	VFXInstances: {Instance},
}

local State: StateType = {
	Active = false,
	Token = 0,
	EndReceived = false,
	Point1Fired = false,
	Point2Fired = false,
	Track = nil,
	Connections = {},
	AuraInstances = {},
	VFXInstances = {},
	EnabledSet = {},
	NameMap = {},
	DirectionLastSend = 0,
	ShiftLockWasEnabled = false,
	BaseFov = nil,
	FovTweenToken = 0,
	ShakeStopper = nil,
}

local RemoteStates: {[number]: RemoteState} = {}

local function TrackConnection(Connection: RBXScriptConnection): ()
	table.insert(State.Connections, Connection)
end

local function GetPhantomDashFolder(): Folder?
	local Assets: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	if not Assets then
		return nil
	end
	local SkillsFolder: Instance? = Assets:FindFirstChild(SKILLS_FOLDER_NAME)
	if not SkillsFolder then
		return nil
	end
	local SennaFolder: Instance? = SkillsFolder:FindFirstChild(SENNA_FOLDER_NAME)
	if not SennaFolder then
		return nil
	end
	local PhantomFolder: Instance? = SennaFolder:FindFirstChild(PHANTOM_DASH_FOLDER_NAME)
	if not PhantomFolder or not PhantomFolder:IsA("Folder") then
		return nil
	end
	return PhantomFolder
end

local function AddToNamedMap(Map: NameMap, Item: Instance): ()
	local Bucket: {Instance}? = Map[Item.Name]
	if not Bucket then
		Bucket = {}
		Map[Item.Name] = Bucket
	end
	table.insert(Bucket, Item)
end

local function RegisterCloneForState(Clone: Instance, Instances: {Instance}, Map: NameMap): ()
	table.insert(Instances, Clone)
	AddToNamedMap(Map, Clone)
	for _, Descendant in Clone:GetDescendants() do
		AddToNamedMap(Map, Descendant)
	end
end

local function EmitFromList(Map: NameMap, Names: {string}): ()
	for _, Name in Names do
		local Bucket: {Instance}? = Map[Name]
		if not Bucket then
			continue
		end
		for _, Item in Bucket do
			if Item:IsA("ParticleEmitter") then
				local EmitCount: number = DEFAULT_EMIT_COUNT
				local EmitValue: any = Item:GetAttribute(EMIT_COUNT_ATTRIBUTE)
				if type(EmitValue) == "number" then
					EmitCount = EmitValue
				end
				Item:Emit(EmitCount)
			end
		end
	end
end

local function SetEnabledFromList(Map: NameMap, Names: {string}, Enabled: boolean): ()
	for _, Name in Names do
		local Bucket: {Instance}? = Map[Name]
		if not Bucket then
			continue
		end
		for _, Item in Bucket do
			if not (Item:IsA("ParticleEmitter") or Item:IsA("Beam") or Item:IsA("Trail") or Item:IsA("Light")) then
				continue
			end
			if Enabled then
				if not Item.Enabled then
					Item.Enabled = true
					State.EnabledSet[Item] = true
				end
			else
				if State.EnabledSet[Item] then
					Item.Enabled = false
					State.EnabledSet[Item] = nil
				end
			end
		end
	end
end

local function SetEnabledImmediate(Map: NameMap, Names: {string}, Enabled: boolean): ()
	for _, Name in Names do
		local Bucket: {Instance}? = Map[Name]
		if not Bucket then
			continue
		end
		for _, Item in Bucket do
			if Item:IsA("ParticleEmitter") or Item:IsA("Beam") or Item:IsA("Trail") or Item:IsA("Light") then
				Item.Enabled = Enabled
			end
		end
	end
end

local function DisableEnabledSet(): ()
	for InstanceItem, _ in State.EnabledSet do
		if InstanceItem:IsA("ParticleEmitter") or InstanceItem:IsA("Beam") or InstanceItem:IsA("Trail") or InstanceItem:IsA("Light") then
			InstanceItem.Enabled = false
		end
	end
	table.clear(State.EnabledSet)
end

local function DisableEffectsInList(Instances: {Instance}): ()
	for _, InstanceItem in Instances do
		if InstanceItem.Parent then
			SkillVfxUtils.DisableEffectsRecursive(InstanceItem)
		end
	end
end

local function StopCameraEffects(): ()
	if State.ShakeStopper then
		State.ShakeStopper()
		State.ShakeStopper = nil
	end

	local Camera: Camera? = workspace.CurrentCamera
	if not Camera then
		State.BaseFov = nil
		return
	end
	if State.BaseFov == nil then
		return
	end

	State.FovTweenToken += 1
	local BaseFov: number = State.BaseFov
	State.BaseFov = nil
	FOVController.RemoveRequest(FOV_REQUEST_ID)
end

local function StartFovPrep(): ()
	local Camera: Camera? = workspace.CurrentCamera
	if not Camera then
		return
	end
	State.FovTweenToken += 1
	State.BaseFov = Camera.FieldOfView
	FOVController.AddRequest(FOV_REQUEST_ID, CAMERA_FOV_PRE_TARGET, nil, {
		TweenInfo = TweenInfo.new(CAMERA_FOV_PRE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})
end

local function StartFovHold(): ()
	local Camera: Camera? = workspace.CurrentCamera
	if not Camera then
		return
	end
	State.FovTweenToken += 1
	if State.BaseFov == nil then
		State.BaseFov = Camera.FieldOfView
	end
	FOVController.AddRequest(FOV_REQUEST_ID, CAMERA_FOV_PEAK_TARGET, nil, {
		TweenInfo = TweenInfo.new(CAMERA_FOV_PEAK_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})
end

local function PlayCameraEffects(): ()
	local Camera: Camera? = workspace.CurrentCamera
	State.ShakeStopper = GlobalFunctions.StartCameraShake(Camera, CAMERA_SHAKE_INTENSITY, CAMERA_SHAKE_DURATION, CAMERA_SHAKE_NOISE_SPEED)
	StartFovHold()
end

local function CleanupAura(): ()
	local PendingAuraInstances: {Instance} = State.AuraInstances
	State.AuraInstances = {}
	SkillVfxUtils.CleanupInstanceList(PendingAuraInstances, EFFECT_DESTROY_DELAY)
end

local function CleanupVFX(): ()
	local PendingVFXInstances: {Instance} = State.VFXInstances
	State.VFXInstances = {}
	SkillVfxUtils.CleanupInstanceList(PendingVFXInstances, EFFECT_DESTROY_DELAY)
end

local function CleanupInstanceList(Instances: {Instance}): ()
	SkillVfxUtils.CleanupInstanceList(Instances, EFFECT_DESTROY_DELAY)
end

local function CleanupRemoteState(SourceUserId: number): ()
	local Existing: RemoteState? = RemoteStates[SourceUserId]
	if not Existing then
		return
	end
	RemoteStates[SourceUserId] = nil
	CleanupInstanceList(Existing.AuraInstances)
	CleanupInstanceList(Existing.VFXInstances)
end

local function ResolveSourcePlayer(SourceUserId: number): Player?
	return Players:GetPlayerByUserId(math.floor(SourceUserId + 0.5))
end

local function ResolveSourceCharacter(SourceUserId: number): (Player?, Model?, BasePart?)
	local Deadline: number = os.clock() + REMOTE_SOURCE_RESOLVE_TIMEOUT
	repeat
		local SourcePlayer: Player? = ResolveSourcePlayer(SourceUserId)
		local Character: Model? = SourcePlayer and SourcePlayer.Character
		local Root: BasePart? = GlobalFunctions.GetRoot(Character)
		if SourcePlayer and Character and Root then
			return SourcePlayer, Character, Root
		end
		task.wait(REMOTE_SOURCE_RESOLVE_STEP)
	until os.clock() >= Deadline

	local SourcePlayer: Player? = ResolveSourcePlayer(SourceUserId)
	local Character: Model? = SourcePlayer and SourcePlayer.Character
	local Root: BasePart? = GlobalFunctions.GetRoot(Character)
	return SourcePlayer, Character, Root
end

local function IsShiftLockEnabled(): boolean
	return _G.CameraShiftlock == true
end

local function DisableShiftLock(): ()
	State.ShiftLockWasEnabled = IsShiftLockEnabled()
	if CameraController.SetShiftlockBlocked then
		CameraController:SetShiftlockBlocked("PhantomDash", true)
	end
end

local function RestoreShiftLock(): ()
	if CameraController.SetShiftlockBlocked then
		CameraController:SetShiftlockBlocked("PhantomDash", false)
	end
	State.ShiftLockWasEnabled = false
end

local function SendMarker(Token: number, MarkerName: string): ()
	if not State.Active or State.Token ~= Token then
		return
	end
	Packets.SkillMarker:Fire(SKILL_TYPE_NAME, Token, MarkerName)
end

local function GetDirection(): Vector3?
	local Character: Model? = LocalPlayer.Character
	if not Character then
		return nil
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance then
		local MoveDirection: Vector3 = Vector3.new(HumanoidInstance.MoveDirection.X, 0, HumanoidInstance.MoveDirection.Z)
		if MoveDirection.Magnitude >= MIN_DIRECTION_MAGNITUDE then
			return MoveDirection.Unit
		end
	end

	local Camera: Camera? = workspace.CurrentCamera
	if Camera then
		local LookDirection: Vector3 = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
		if LookDirection.Magnitude >= MIN_DIRECTION_MAGNITUDE then
			return LookDirection.Unit
		end
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		return nil
	end
	local RootLook: Vector3 = Vector3.new(Root.CFrame.LookVector.X, 0, Root.CFrame.LookVector.Z)
	if RootLook.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return nil
	end
	return RootLook.Unit
end

local function SendDirection(Token: number): ()
	if not State.Active or State.Token ~= Token then
		return
	end
	local Direction: Vector3? = GetDirection()
	if not Direction then
		return
	end
	Packets.SkillDirection:Fire(SKILL_TYPE_NAME, Token, Direction)
end

local function QueueCleanup(Token: number): ()
	task.delay(CLEANUP_DELAY, function()
		if not State.Active or State.Token ~= Token then
			return
		end
		PhantomDash.Cleanup()
	end)
end

local function StartEndFallback(Token: number): ()
	task.delay(SERVER_END_FALLBACK_TIME, function()
		if not State.Active or State.Token ~= Token then
			return
		end
		if State.EndReceived then
			return
		end
		if State.Track then
			State.Track:AdjustSpeed(POST_POINT1_ANIMATION_SPEED)
		end
		StopCameraEffects()
		DisableEnabledSet()
		DisableEffectsInList(State.AuraInstances)
		DisableEffectsInList(State.VFXInstances)
		QueueCleanup(Token)
	end)
end

local function CloneAuraToCharacter(Character: Model, AuraTemplate: Model, TargetInstances: {Instance}): ()
	for _, AuraPart in AuraTemplate:GetChildren() do
		if not AuraPart:IsA("BasePart") then
			continue
		end
		local TargetPart: Instance? = Character:FindFirstChild(AuraPart.Name)
		if not TargetPart or not TargetPart:IsA("BasePart") then
			continue
		end
		for _, Effect in AuraPart:GetChildren() do
			local Clone: Instance = Effect:Clone()
			Clone.Parent = TargetPart
			table.insert(TargetInstances, Clone)
		end
	end
end

local function ApplyAura(Character: Model, AuraTemplate: Model): ()
	CloneAuraToCharacter(Character, AuraTemplate, State.AuraInstances)
end

local function CloneVFXToCharacter(
	Character: Model,
	Root: BasePart,
	VFXTemplate: Instance,
	TargetInstances: {Instance},
	Map: NameMap
): ()
	for _, VfxPart in VFXTemplate:GetChildren() do
		if not VfxPart:IsA("BasePart") then
			continue
		end
		local TargetPart: Instance? = Character:FindFirstChild(VfxPart.Name)
		if not TargetPart or not TargetPart:IsA("BasePart") then
			continue
		end
		for _, Effect in VfxPart:GetChildren() do
			local Clone: Instance = Effect:Clone()
			Clone.Parent = TargetPart
			RegisterCloneForState(Clone, TargetInstances, Map)
		end
	end

	for _, Item in VFXTemplate:GetChildren() do
		if Item:IsA("BasePart") or Item:IsA("Model") or Item:IsA("Folder") then
			continue
		end
		if not (Item:IsA("Attachment") or Item:IsA("ParticleEmitter") or Item:IsA("Beam") or Item:IsA("Trail") or Item:IsA("Light")) then
			continue
		end
		local Clone: Instance = Item:Clone()
		Clone.Parent = Root
		RegisterCloneForState(Clone, TargetInstances, Map)
	end
end

local function ApplyVFXToCharacter(Character: Model, Root: BasePart, VFXTemplate: Instance): ()
	CloneVFXToCharacter(Character, Root, VFXTemplate, State.VFXInstances, State.NameMap)
end

local function BeginRemote(SourceUserId: number, Token: number): ()
	CleanupRemoteState(SourceUserId)

	local SourcePlayer, Character, Root = ResolveSourceCharacter(SourceUserId)
	if not SourcePlayer or not Character or not Root then
		return
	end

	local Folder: Folder? = GetPhantomDashFolder()
	if not Folder then
		return
	end

	local AuraTemplate: Model? = Folder:FindFirstChild(AURA_NAME) :: Model?
	local VFXTemplate: Instance? = Folder:FindFirstChild(VFX_NAME)
	if not AuraTemplate or not AuraTemplate:IsA("Model") or not VFXTemplate then
		return
	end

	local RemoteNameMap: NameMap = {}
	local RemoteStateData: RemoteState = {
		Token = Token,
		AuraInstances = {},
		VFXInstances = {},
	}
	RemoteStates[SourceUserId] = RemoteStateData

	CloneAuraToCharacter(Character, AuraTemplate, RemoteStateData.AuraInstances)
	CloneVFXToCharacter(Character, Root, VFXTemplate, RemoteStateData.VFXInstances, RemoteNameMap)
	SetEnabledImmediate(RemoteNameMap, ENABLE_NAMES, true)
	EmitFromList(RemoteNameMap, EMIT_NAMES)

	task.delay(SERVER_END_FALLBACK_TIME + 0.85, function()
		local CurrentState: RemoteState? = RemoteStates[SourceUserId]
		if not CurrentState or CurrentState.Token ~= Token then
			return
		end
		CleanupRemoteState(SourceUserId)
	end)
end

local function EndRemote(SourceUserId: number, Token: number): ()
	local Existing: RemoteState? = RemoteStates[SourceUserId]
	if not Existing or Existing.Token ~= Token then
		return
	end
	CleanupRemoteState(SourceUserId)
end

local function Begin(Token: number): ()
	PhantomDash.Cleanup()

	local Character: Model? = LocalPlayer.Character
	local Root: BasePart? = GlobalFunctions.GetRoot(Character)
	if not Character or not Root then
		return
	end

	local Folder: Folder? = GetPhantomDashFolder()
	if not Folder then
		return
	end

	local AuraTemplate: Model? = Folder:FindFirstChild(AURA_NAME) :: Model?
	local VFXTemplate: Instance? = Folder:FindFirstChild(VFX_NAME)
	local AnimationTemplate: Animation? = Folder:FindFirstChild(ANIMATION_NAME) :: Animation?
	if not AuraTemplate or not AuraTemplate:IsA("Model") then
		return
	end
	if not VFXTemplate then
		return
	end
	if not AnimationTemplate or not AnimationTemplate:IsA("Animation") then
		return
	end

	local AnimatorInstance: Animator? = GlobalFunctions.GetAnimator(Character)
	if not AnimatorInstance then
		return
	end

	DisableShiftLock()

	State.Active = true
	State.Token = Token
	State.EndReceived = false
	State.Point1Fired = false
	State.Point2Fired = false
	State.DirectionLastSend = 0
	State.NameMap = {}
	table.clear(State.VFXInstances)

	StartFovPrep()
	ApplyAura(Character, AuraTemplate)
	ApplyVFXToCharacter(Character, Root, VFXTemplate)

	local AnimationClone: Animation = AnimationTemplate:Clone()
	local Track: AnimationTrack = AnimatorInstance:LoadAnimation(AnimationClone)
	AnimationClone:Destroy()
	Track.Priority = Enum.AnimationPriority.Action
	Track.Looped = false
	Track:Play()
	Track:AdjustSpeed(PRE_POINT1_ANIMATION_SPEED)
	State.Track = Track

	TrackConnection(RunService.RenderStepped:Connect(function()
		if not State.Active or State.Token ~= Token or State.Point2Fired then
			return
		end
		local Now: number = os.clock()
		if Now - State.DirectionLastSend < DIRECTION_SEND_INTERVAL then
			return
		end
		State.DirectionLastSend = Now
		SendDirection(Token)
	end))

	TrackConnection(Track:GetMarkerReachedSignal(MARKER_POINT1):Connect(function()
		if not State.Active or State.Token ~= Token or State.Point1Fired then
			return
		end
		State.Point1Fired = true
		Track:AdjustSpeed(POST_POINT1_ANIMATION_SPEED)
		SetEnabledFromList(State.NameMap, ENABLE_NAMES, true)
		EmitFromList(State.NameMap, EMIT_NAMES)
		SendDirection(Token)
		SendMarker(Token, MARKER_POINT1)
		PlayCameraEffects()
	end))

	TrackConnection(Track:GetMarkerReachedSignal(MARKER_POINT2):Connect(function()
		if not State.Active or State.Token ~= Token or State.Point2Fired then
			return
		end
		State.Point2Fired = true
		Track:AdjustSpeed(END_ANIMATION_SPEED)
		SendMarker(Token, MARKER_POINT2)
		StartEndFallback(Token)
	end))

	TrackConnection(Track.Stopped:Connect(function()
		if not State.Active or State.Token ~= Token then
			return
		end
		if not State.Point2Fired then
			State.Point2Fired = true
			SendMarker(Token, MARKER_POINT2)
			StartEndFallback(Token)
		end
	end))
end

local function End(Token: number): ()
	if not State.Active or State.Token ~= Token then
		return
	end
	State.EndReceived = true
	if State.Track then
		State.Track:AdjustSpeed(POST_POINT1_ANIMATION_SPEED)
	end
	StopCameraEffects()
	DisableEnabledSet()
	DisableEffectsInList(State.AuraInstances)
	DisableEffectsInList(State.VFXInstances)
	QueueCleanup(Token)
end

function PhantomDash.Start(Data: {[string]: any}): ()
	local Action: string = Data.Action or ""
	local Token: any = Data.Token
	if type(Token) ~= "number" then
		return
	end
	local ParsedToken: number = math.floor(Token)
	local SourceUserId: any = Data.SourceUserId
	if type(SourceUserId) == "number" and math.floor(SourceUserId + 0.5) ~= LocalPlayer.UserId then
		local ParsedSourceUserId: number = math.floor(SourceUserId + 0.5)
		if Action == "Start" then
			BeginRemote(ParsedSourceUserId, ParsedToken)
			return
		end
		if Action == "End" then
			EndRemote(ParsedSourceUserId, ParsedToken)
			return
		end
	end
	if Action == "Start" then
		Begin(ParsedToken)
		return
	end
	if Action == "End" then
		End(ParsedToken)
	end
end

function PhantomDash.Cleanup(): ()
	if State.Active and State.Point1Fired and not State.Point2Fired then
		State.Point2Fired = true
		SendMarker(State.Token, MARKER_POINT2)
	end

	RestoreShiftLock()
	StopCameraEffects()
	DisableEnabledSet()
	GlobalFunctions.DisconnectAll(State.Connections)
	CleanupAura()
	CleanupVFX()

	if State.Track then
		State.Track:Stop()
		State.Track:Destroy()
		State.Track = nil
	end

	State.Active = false
	State.Token = 0
	State.EndReceived = false
	State.Point1Fired = false
	State.Point2Fired = false
	State.NameMap = {}
	State.DirectionLastSend = 0
	State.ShiftLockWasEnabled = false
	State.BaseFov = nil
	State.FovTweenToken = 0
	State.ShakeStopper = nil
end

return PhantomDash

