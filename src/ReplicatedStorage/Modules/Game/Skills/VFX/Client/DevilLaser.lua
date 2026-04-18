--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local CameraController: any = require(ReplicatedStorage.Controllers.CameraController)
local FOVController: any = require(ReplicatedStorage.Controllers.FOVController)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local SkillVfxUtils: any = require(script.Parent.Init.SkillVfxUtils)

local DevilLaser = {}

local ASSETS_FOLDER_NAME: string = "Assets"
local SKILLS_FOLDER_NAME: string = "Skills"
local SENNA_FOLDER_NAME: string = "Senna"
local DEVIL_LASER_FOLDER_NAME: string = "Devil Lazer"

local AURA_NAME: string = "Aura"
local VFX_NAME: string = "VFX"
local VFX_MAIN_NAME: string = "Vfxmain"
local ANIMATION_NAME: string = "Animation"
local TRAIL_PART_NAME: string = "TrailPart"

local MARKER_NAMES: {string} = {
	"point1",
	"point2",
	"point3",
	"point4",
	"point5",
	"point6",
	"point7",
}

local MARKER_FALLBACK_SEQUENCE: {string} = {
	"point2",
	"point4",
	"point6",
	"point7",
}

local MARKER_FALLBACK_DELAY: number = 0.05
local MARKER_STEP_TIME: number = 0.24
local FINAL_MARKER_NAME: string = "point7"
local SKILL_TYPE_NAME: string = "DevilLaser"

local ANIMATION_SPEED: number = 0.9
local CAMERA_FOV_TARGET: number = 100
local CAMERA_FOV_IN_TIME: number = 0.12
local CAMERA_FOV_OUT_TIME: number = 0.25
local FOV_REQUEST_ID: string = "DevilLaser::FOV"
local FINAL_FOV_REQUEST_ID: string = "DevilLaser::FinalFOV"
local FINAL_FOV_TARGET: number = 30
local FINAL_FOV_IN_TIME: number = 0.16
local FINAL_FOV_HOLD_TIME: number = 1.85
local REMOTE_SOURCE_RESOLVE_TIMEOUT: number = 0.75
local REMOTE_SOURCE_RESOLVE_STEP: number = 0.05
local TRAIL_PART_OFFSET: Vector3 = Vector3.new(0.09, 0.074, 0.042)
local TRAIL_PART_YAW: number = math.rad(90)
local TRAIL_RAY_HEIGHT: number = 8
local TRAIL_RAY_DISTANCE: number = 40
local EFFECT_DESTROY_DELAY: number = 3
local FLAT_DIRECTION_FALLBACK: Vector3 = Vector3.new(1, 0, 0)
local UP_VECTOR: Vector3 = Vector3.new(0, 1, 0)

local LocalPlayer: Player = Players.LocalPlayer

type StateType = {
	Active: boolean,
	Token: number,
	EndReceived: boolean,
	Track: AnimationTrack?,
	Connections: {RBXScriptConnection},
	ClonedInstances: {Instance},
	Emitters: {ParticleEmitter},
	EnabledSet: {[Instance]: boolean},
	MarkerFired: {[string]: boolean},
	MarkerSequenceToken: number,
	FinalPresentationSequence: number,
	FinalPresentationActive: boolean,
	ShiftLockWasEnabled: boolean,
	BaseFov: number?,
}

type RemoteState = {
	Token: number,
	ClonedInstances: {Instance},
	Emitters: {ParticleEmitter},
}

local State: StateType = {
	Active = false,
	Token = 0,
	EndReceived = false,
	Track = nil,
	Connections = {},
	ClonedInstances = {},
	Emitters = {},
	EnabledSet = {},
	MarkerFired = {},
	MarkerSequenceToken = 0,
	FinalPresentationSequence = 0,
	FinalPresentationActive = false,
	ShiftLockWasEnabled = false,
	BaseFov = nil,
}

local RemoteStates: {[number]: RemoteState} = {}

local function TrackConnection(Connection: RBXScriptConnection): ()
	table.insert(State.Connections, Connection)
end

local function GetDevilLaserFolder(): Folder?
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
	local DevilFolder: Instance? = SennaFolder:FindFirstChild(DEVIL_LASER_FOLDER_NAME)
	if not DevilFolder or not DevilFolder:IsA("Folder") then
		return nil
	end
	return DevilFolder
end

local function NormalizeName(Name: string): string
	return string.gsub(string.lower(Name), "[^%w]", "")
end

local function FindTemplateFlexible(Root: Instance, Name: string): Instance?
	local Direct: Instance? = Root:FindFirstChild(Name)
	if Direct then
		return Direct
	end
	local NormalizedTarget: string = NormalizeName(Name)
	for _, Descendant in Root:GetDescendants() do
		if NormalizeName(Descendant.Name) == NormalizedTarget then
			return Descendant
		end
	end
	for _, Descendant in Root:GetDescendants() do
		if string.find(NormalizeName(Descendant.Name), NormalizedTarget, 1, true) then
			return Descendant
		end
	end
	return nil
end

local function IsShiftLockEnabled(): boolean
	return _G.CameraShiftlock == true
end

local function DisableShiftLock(): ()
	State.ShiftLockWasEnabled = IsShiftLockEnabled()
	if CameraController.SetShiftlockBlocked then
		CameraController:SetShiftlockBlocked("DevilLaser", true)
	end
end

local function RestoreShiftLock(): ()
	if CameraController.SetShiftlockBlocked then
		CameraController:SetShiftlockBlocked("DevilLaser", false)
	end
	State.ShiftLockWasEnabled = false
end

local function StartFov(): ()
	local Camera: Camera? = workspace.CurrentCamera
	if not Camera then
		return
	end
	State.BaseFov = Camera.FieldOfView
	FOVController.AddRequest(FOV_REQUEST_ID, CAMERA_FOV_TARGET, nil, {
		TweenInfo = TweenInfo.new(CAMERA_FOV_IN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
	})
end

local function RestoreFov(): ()
	local Camera: Camera? = workspace.CurrentCamera
	if not Camera then
		State.BaseFov = nil
		return
	end
	if State.BaseFov == nil then
		return
	end
	State.BaseFov = nil
	FOVController.RemoveRequest(FOV_REQUEST_ID)
	FOVController.RemoveRequest(FINAL_FOV_REQUEST_ID)
end

local function StartFinalPresentation(Token: number): ()
	if State.FinalPresentationActive or not State.Active or State.Token ~= Token then
		return
	end

	State.FinalPresentationActive = true
	State.FinalPresentationSequence += 1
	local PresentationSequence: number = State.FinalPresentationSequence

	FOVController.RemoveRequest(FOV_REQUEST_ID)
	FOVController.AddRequest(FINAL_FOV_REQUEST_ID, FINAL_FOV_TARGET, nil, {
		TweenInfo = TweenInfo.new(FINAL_FOV_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	})

	task.delay(FINAL_FOV_HOLD_TIME, function()
		if not State.Active or State.Token ~= Token then
			return
		end
		if not State.FinalPresentationActive or State.FinalPresentationSequence ~= PresentationSequence then
			return
		end
		DevilLaser.Cleanup()
	end)
end

local function DisableEnabledSet(): ()
	for InstanceItem, _ in State.EnabledSet do
		if InstanceItem:IsA("ParticleEmitter") or InstanceItem:IsA("Beam") or InstanceItem:IsA("Trail") or InstanceItem:IsA("Light") then
			InstanceItem.Enabled = false
		end
	end
	table.clear(State.EnabledSet)
end

local function CleanupClones(): ()
	local PendingClones: {Instance} = State.ClonedInstances
	State.ClonedInstances = {}
	State.Emitters = {}
	SkillVfxUtils.CleanupInstanceList(PendingClones, EFFECT_DESTROY_DELAY)
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
	CleanupInstanceList(Existing.ClonedInstances)
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

local function SendMarker(Token: number, MarkerName: string): ()
	if not State.Active or State.Token ~= Token then
		return
	end
	Packets.SkillMarker:Fire(SKILL_TYPE_NAME, Token, MarkerName)
end

local function EmitAll(): ()
	for _, Emitter in State.Emitters do
		if not Emitter.Parent then
			continue
		end
		local Count: number = 1
		local EmitCount: any = Emitter:GetAttribute("EmitCount")
		if type(EmitCount) == "number" then
			Count = EmitCount
		end
		local WasEnabled: boolean = Emitter.Enabled
		if not WasEnabled then
			Emitter.Enabled = true
			State.EnabledSet[Emitter] = true
		end
		Emitter:Emit(Count)
		if not WasEnabled then
			Emitter.Enabled = false
			State.EnabledSet[Emitter] = nil
		end
	end
end

local function EmitEmitterList(Emitters: {ParticleEmitter}): ()
	for _, Emitter in Emitters do
		if not Emitter.Parent then
			continue
		end
		local Count: number = 1
		local EmitCount: any = Emitter:GetAttribute("EmitCount")
		if type(EmitCount) == "number" then
			Count = EmitCount
		end
		Emitter:Emit(Count)
	end
end

local function CollectEmitters(Root: Instance): ()
	for _, Descendant in Root:GetDescendants() do
		if Descendant:IsA("ParticleEmitter") then
			table.insert(State.Emitters, Descendant)
		end
	end
end

local function CollectEmittersInto(TargetEmitters: {ParticleEmitter}, Root: Instance): ()
	for _, Descendant in Root:GetDescendants() do
		if Descendant:IsA("ParticleEmitter") then
			table.insert(TargetEmitters, Descendant)
		end
	end
end

local function PrepareAttachedPart(Part: BasePart): ()
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.Massless = true
end

local function GetFlatRootCFrame(Root: BasePart): CFrame
	local FlatLook: Vector3 = Vector3.new(Root.CFrame.LookVector.X, 0, Root.CFrame.LookVector.Z)
	if FlatLook.Magnitude <= 0.001 then
		FlatLook = FLAT_DIRECTION_FALLBACK
	else
		FlatLook = FlatLook.Unit
	end
	local RootPosition: Vector3 = Root.Position
	return CFrame.lookAt(RootPosition, RootPosition + FlatLook, UP_VECTOR)
end

local function ResolveTrailCFrame(Character: Model, Root: BasePart, TrailClone: BasePart): CFrame
	local FlatRootCFrame: CFrame = GetFlatRootCFrame(Root)
	local BaseTarget: CFrame = FlatRootCFrame * CFrame.new(TRAIL_PART_OFFSET.X, 0, TRAIL_PART_OFFSET.Z)
	local BasePosition: Vector3 = BaseTarget.Position
	local RayParams: RaycastParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	RayParams.FilterDescendantsInstances = { Character, TrailClone }

	local RayOrigin: Vector3 = BasePosition + Vector3.new(0, TRAIL_RAY_HEIGHT, 0)
	local RayResult: RaycastResult? = workspace:Raycast(RayOrigin, Vector3.new(0, -TRAIL_RAY_DISTANCE, 0), RayParams)

	local TargetY: number = Root.Position.Y + TRAIL_PART_OFFSET.Y
	if RayResult then
		TargetY = RayResult.Position.Y + (TrailClone.Size.Y * 0.5) + TRAIL_PART_OFFSET.Y
	end

	local _, Yaw, _ = FlatRootCFrame:ToOrientation()
	local TargetPosition: Vector3 = Vector3.new(BasePosition.X, TargetY, BasePosition.Z)
	return CFrame.new(TargetPosition) * CFrame.Angles(0, Yaw + TRAIL_PART_YAW, 0)
end

local function CloneAuraToCharacter(Character: Model, AuraTemplate: Model, TargetInstances: {Instance}, TargetEmitters: {ParticleEmitter}): ()
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
			CollectEmittersInto(TargetEmitters, Clone)
		end
	end
end

local function ApplyAura(Character: Model, AuraTemplate: Model): ()
	CloneAuraToCharacter(Character, AuraTemplate, State.ClonedInstances, State.Emitters)
end

local function AttachTrailPart(Character: Model, Root: BasePart, TrailTemplate: BasePart, Token: number): ()
	local TrailClone: BasePart = TrailTemplate:Clone()
	PrepareAttachedPart(TrailClone)
	TrailClone.CFrame = ResolveTrailCFrame(Character, Root, TrailClone)
	TrailClone.Parent = workspace

	table.insert(State.ClonedInstances, TrailClone)
	CollectEmitters(TrailClone)

	TrackConnection(RunService.RenderStepped:Connect(function()
		if not State.Active or State.Token ~= Token then
			return
		end
		if not Root.Parent or not TrailClone.Parent then
			return
		end
		TrailClone.CFrame = ResolveTrailCFrame(Character, Root, TrailClone)
	end))
end

local function CloneTemplateEffectsToCharacterTarget(
	Character: Model,
	Root: BasePart,
	Template: Instance,
	TargetInstances: {Instance},
	TargetEmitters: {ParticleEmitter}
): ()
	for _, VfxPart in Template:GetChildren() do
		if not VfxPart:IsA("BasePart") then
			continue
		end
		local TargetPart: Instance? = Character:FindFirstChild(VfxPart.Name)
		local ParentPart: BasePart = Root
		if TargetPart and TargetPart:IsA("BasePart") then
			ParentPart = TargetPart
		end
		for _, Effect in VfxPart:GetChildren() do
			local Clone: Instance = Effect:Clone()
			Clone.Parent = ParentPart
			table.insert(TargetInstances, Clone)
			CollectEmittersInto(TargetEmitters, Clone)
		end
	end

	for _, Item in Template:GetChildren() do
		if Item:IsA("BasePart") or Item:IsA("Model") or Item:IsA("Folder") then
			continue
		end
		if not (Item:IsA("Attachment") or Item:IsA("ParticleEmitter") or Item:IsA("Beam") or Item:IsA("Trail") or Item:IsA("Light")) then
			continue
		end
		local Clone: Instance = Item:Clone()
		Clone.Parent = Root
		table.insert(TargetInstances, Clone)
		CollectEmittersInto(TargetEmitters, Clone)
	end
end

local function CloneTemplateEffectsToCharacter(Character: Model, Root: BasePart, Template: Instance): ()
	CloneTemplateEffectsToCharacterTarget(Character, Root, Template, State.ClonedInstances, State.Emitters)
end

local function BeginRemote(SourceUserId: number, Token: number): ()
	CleanupRemoteState(SourceUserId)

	local SourcePlayer, Character, Root = ResolveSourceCharacter(SourceUserId)
	if not SourcePlayer or not Character or not Root then
		return
	end

	local Folder: Folder? = GetDevilLaserFolder()
	if not Folder then
		return
	end

	local AuraTemplate: Model? = FindTemplateFlexible(Folder, AURA_NAME) :: Model?
	local VFXTemplate: Instance? = FindTemplateFlexible(Folder, VFX_NAME)
	local VFXMainTemplate: Instance? = FindTemplateFlexible(Folder, VFX_MAIN_NAME)
	if not AuraTemplate or not AuraTemplate:IsA("Model") then
		return
	end

	local RemoteStateData: RemoteState = {
		Token = Token,
		ClonedInstances = {},
		Emitters = {},
	}
	RemoteStates[SourceUserId] = RemoteStateData

	CloneAuraToCharacter(Character, AuraTemplate, RemoteStateData.ClonedInstances, RemoteStateData.Emitters)
	if VFXTemplate then
		CloneTemplateEffectsToCharacterTarget(
			Character,
			Root,
			VFXTemplate,
			RemoteStateData.ClonedInstances,
			RemoteStateData.Emitters
		)
	end
	if VFXMainTemplate then
		CloneTemplateEffectsToCharacterTarget(
			Character,
			Root,
			VFXMainTemplate,
			RemoteStateData.ClonedInstances,
			RemoteStateData.Emitters
		)
	end

	EmitEmitterList(RemoteStateData.Emitters)

	task.delay(FINAL_FOV_HOLD_TIME + 0.5, function()
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

local function HandleMarker(Token: number, MarkerName: string): ()
	if not State.Active or State.Token ~= Token then
		return
	end
	if State.MarkerFired[MarkerName] then
		return
	end
	State.MarkerFired[MarkerName] = true
	SendMarker(Token, MarkerName)
	if MarkerName == "point2" or MarkerName == "point4" or MarkerName == "point6" or MarkerName == "point7" then
		EmitAll()
		if MarkerName == FINAL_MARKER_NAME then
			StartFinalPresentation(Token)
			return
		end
	end
end

local function EndLocal(Token: number): ()
	if not State.Active or State.Token ~= Token then
		return
	end
	State.EndReceived = true
	if State.Track and State.Track.IsPlaying then
		return
	end
	if State.FinalPresentationActive or State.MarkerFired[FINAL_MARKER_NAME] then
		return
	end
	DevilLaser.Cleanup()
end

local function RunMarkerFallback(Token: number): ()
	State.MarkerSequenceToken += 1
	local SequenceToken: number = State.MarkerSequenceToken
	task.spawn(function()
		task.wait(MARKER_FALLBACK_DELAY)
		for _, MarkerName in MARKER_FALLBACK_SEQUENCE do
			if not State.Active or State.Token ~= Token or State.MarkerSequenceToken ~= SequenceToken then
				return
			end
			if not State.MarkerFired[MarkerName] then
				HandleMarker(Token, MarkerName)
			end
			task.wait(MARKER_STEP_TIME)
		end
	end)
end

local function Begin(Token: number): ()
	DevilLaser.Cleanup()

	local Character: Model? = LocalPlayer.Character
	local Root: BasePart? = GlobalFunctions.GetRoot(Character)
	if not Character or not Root then
		return
	end

	local Folder: Folder? = GetDevilLaserFolder()
	if not Folder then
		return
	end

	local AuraTemplate: Model? = FindTemplateFlexible(Folder, AURA_NAME) :: Model?
	local VFXTemplate: Instance? = FindTemplateFlexible(Folder, VFX_NAME)
	local VFXMainTemplate: Instance? = FindTemplateFlexible(Folder, VFX_MAIN_NAME)
	local AnimationTemplate: Animation? = FindTemplateFlexible(Folder, ANIMATION_NAME) :: Animation?
	local TrailPartTemplate: Instance? = FindTemplateFlexible(Folder, TRAIL_PART_NAME)
	if not AuraTemplate or not AuraTemplate:IsA("Model") then
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
	State.MarkerSequenceToken = 0
	State.FinalPresentationSequence += 1
	State.FinalPresentationActive = false
	table.clear(State.MarkerFired)
	for _, Name in MARKER_NAMES do
		State.MarkerFired[Name] = false
	end

	StartFov()
	ApplyAura(Character, AuraTemplate)
	if VFXTemplate then
		CloneTemplateEffectsToCharacter(Character, Root, VFXTemplate)
	end
	if VFXMainTemplate then
		CloneTemplateEffectsToCharacter(Character, Root, VFXMainTemplate)
	end
	if TrailPartTemplate and TrailPartTemplate:IsA("BasePart") then
		AttachTrailPart(Character, Root, TrailPartTemplate, Token)
	end

	local AnimationClone: Animation = AnimationTemplate:Clone()
	local Track: AnimationTrack = AnimatorInstance:LoadAnimation(AnimationClone)
	AnimationClone:Destroy()
	Track.Priority = Enum.AnimationPriority.Action
	Track.Looped = false
	Track:Play()
	Track:AdjustSpeed(ANIMATION_SPEED)
	State.Track = Track

	for _, MarkerName in MARKER_NAMES do
		TrackConnection(Track:GetMarkerReachedSignal(MarkerName):Connect(function()
			HandleMarker(Token, MarkerName)
		end))
	end

	TrackConnection(Track.Stopped:Connect(function()
		EndLocal(Token)
	end))

	RunMarkerFallback(Token)
end

function DevilLaser.Start(Data: {[string]: any}): ()
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
		EndLocal(ParsedToken)
	end
end

function DevilLaser.Cleanup(): ()
	RestoreShiftLock()
	RestoreFov()
	DisableEnabledSet()
	GlobalFunctions.DisconnectAll(State.Connections)
	CleanupClones()
	if State.Track then
		State.Track:Stop()
		State.Track:Destroy()
		State.Track = nil
	end

	State.Active = false
	State.Token = 0
	State.EndReceived = false
	State.MarkerSequenceToken = 0
	State.FinalPresentationSequence += 1
	State.FinalPresentationActive = false
	table.clear(State.MarkerFired)
	State.ShiftLockWasEnabled = false
	State.BaseFov = nil
end

return DevilLaser

