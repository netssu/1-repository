--!strict

local CollectionService: CollectionService = game:GetService("CollectionService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local Workspace: Workspace = game:GetService("Workspace")

local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local CutsceneRigUtils: any = require(ReplicatedStorage.Modules.Game.Skills.VFX.Client.Init.CutsceneRigUtils)

local LobbyNpcController = {}

local LOBBY_NAME: string = "Lobby"
local DEV_FOLDER_NAME: string = "Dev"
local PLAYER_ATTRIBUTE: string = "Player"
local FLOATING_SPINNING_MODEL_TAG: string = "FloatingSpinningModel"
local PLAYER_CARD_TAG: string = "PLAYER CARD"
local PLAYER_CARD_TAG_ALIASES: {string} = { PLAYER_CARD_TAG, "PLAYER_CARD", "PLAYERCARD" }
local FLOATING_BOB_AMPLITUDE: number = 0.35
local FLOATING_BOB_SPEED: number = 1.8
local FLOATING_SPIN_SPEED: number = math.rad(18)
local PLAYER_CARD_BOB_AMPLITUDE: number = 0.18
local PLAYER_CARD_BOB_SPEED: number = 1.45
local PLAYER_CARD_TILT_AMPLITUDE: number = math.rad(2.5)
local FLOATING_PHASE_MOD: number = 10000
local TWO_PI: number = math.pi * 2

type RigState = {
	Model: Model,
	Humanoid: Humanoid,
	OriginalAppearanceSource: Model?,
	Applied: boolean,
	AttributeConnection: RBXScriptConnection?,
	AncestryConnection: RBXScriptConnection?,
	HumanoidConnection: RBXScriptConnection?,
}

type FloatingState = {
	Model: Model,
	BasePivot: CFrame,
	BasePosition: Vector3,
	BaseRotation: CFrame,
	Phase: number,
	BobAmplitude: number,
	BobSpeed: number,
	SpinSpeed: number,
}

type FloatingPlayerCardState = {
	Part: BasePart,
	BaseCFrame: CFrame,
	Phase: number,
	BobAmplitude: number,
	BobSpeed: number,
	TiltAmplitude: number,
}

local LocalPlayer: Player = Players.LocalPlayer
local ActiveLobby: Instance? = nil
local Started: boolean = false
local LobbyConnections: {RBXScriptConnection} = {}
local _WorkspaceConnections: {RBXScriptConnection} = {}
local _PlayerConnections: {RBXScriptConnection} = {}
local RigStates: {[Model]: RigState} = {}
local FloatingStates: {[Model]: FloatingState} = {}
local FloatingPlayerCardStates: {[BasePart]: FloatingPlayerCardState} = {}
local FloatingConnection: RBXScriptConnection? = nil
local FloatingPlayerCardConnection: RBXScriptConnection? = nil

local RefreshRig: (Model) -> ()
local CleanupRig: (Model) -> ()
local RegisterFloatingModel: (Model) -> ()
local CleanupFloatingModel: (Model) -> ()
local RegisterFloatingPlayerCard: (BasePart) -> ()
local CleanupFloatingPlayerCard: (BasePart) -> ()

local function HashString(Text: string): number
	local Hash: number = 0
	for Index = 1, #Text do
		Hash = ((Hash * 33) + string.byte(Text, Index)) % 1000003
	end
	return Hash
end

local function ResolveRotationOnly(Pivot: CFrame): CFrame
	return CFrame.fromMatrix(Vector3.zero, Pivot.XVector, Pivot.YVector, Pivot.ZVector)
end

local function ResolveModelPivot(ModelInstance: Model): CFrame?
	local RootPart: BasePart? = ModelInstance:FindFirstChildWhichIsA("BasePart", true)
	if not RootPart then
		return nil
	end

	local Success: boolean, PivotOrError: any = pcall(function(): CFrame
		return ModelInstance:GetPivot()
	end)
	if not Success then
		return nil
	end

	return PivotOrError :: CFrame
end

local function ResolveRigModelFromHumanoid(HumanoidInstance: Humanoid): Model?
	local ParentInstance: Instance? = HumanoidInstance.Parent
	if ParentInstance and ParentInstance:IsA("Model") then
		return ParentInstance
	end

	return nil
end

local function ResolveRigHumanoid(ModelInstance: Model): Humanoid?
	local DirectHumanoid: Humanoid? = ModelInstance:FindFirstChildOfClass("Humanoid")
	if DirectHumanoid then
		return DirectHumanoid
	end

	local DescendantHumanoid: Instance? = ModelInstance:FindFirstChildWhichIsA("Humanoid", true)
	if DescendantHumanoid and DescendantHumanoid:IsA("Humanoid") then
		return DescendantHumanoid
	end

	return nil
end

local function IsInsideActiveLobby(InstanceItem: Instance): boolean
	local LobbyInstance: Instance? = ActiveLobby
	if not LobbyInstance then
		return false
	end

	return InstanceItem == LobbyInstance or InstanceItem:IsDescendantOf(LobbyInstance)
end

local function IsInsideActiveLobbyDev(InstanceItem: Instance): boolean
	local LobbyInstance: Instance? = ActiveLobby
	if not LobbyInstance then
		return false
	end

	local DevInstance: Instance? = LobbyInstance:FindFirstChild(DEV_FOLDER_NAME)
	if not DevInstance then
		return false
	end

	return InstanceItem == DevInstance or InstanceItem:IsDescendantOf(DevInstance)
end

local function IsPlayerRig(ModelInstance: Model): boolean
	return ModelInstance:GetAttribute(PLAYER_ATTRIBUTE) == true
end

local function HasPlayerCardTag(InstanceItem: Instance): boolean
	for _, TagName in PLAYER_CARD_TAG_ALIASES do
		if CollectionService:HasTag(InstanceItem, TagName) then
			return true
		end
	end

	return false
end

local function EnsureFloatingConnection(): ()
	if FloatingConnection or next(FloatingStates) == nil then
		return
	end

	-- Single render loop for all tagged lobby models to keep the effect smooth and cheap.
	FloatingConnection = RunService.RenderStepped:Connect(function()
		local Now: number = os.clock()
		local ModelsToCleanup: {Model} = {}

		for ModelInstance, State in FloatingStates do
			if not ModelInstance.Parent then
				table.insert(ModelsToCleanup, ModelInstance)
				continue
			end
			if not IsInsideActiveLobby(ModelInstance) then
				table.insert(ModelsToCleanup, ModelInstance)
				continue
			end
			if not CollectionService:HasTag(ModelInstance, FLOATING_SPINNING_MODEL_TAG) then
				table.insert(ModelsToCleanup, ModelInstance)
				continue
			end

			local BobOffset: number = math.sin((Now * State.BobSpeed) + State.Phase) * State.BobAmplitude
			local SpinAngle: number = (Now * State.SpinSpeed) + State.Phase
			local TargetPivot: CFrame =
				CFrame.new(State.BasePosition + Vector3.new(0, BobOffset, 0))
				* State.BaseRotation
				* CFrame.Angles(0, SpinAngle, 0)

			local Success: boolean = pcall(function()
				ModelInstance:PivotTo(TargetPivot)
			end)
			if not Success then
				table.insert(ModelsToCleanup, ModelInstance)
			end
		end

		for _, ModelInstance in ModelsToCleanup do
			CleanupFloatingModel(ModelInstance)
		end

		if next(FloatingStates) == nil and FloatingConnection then
			FloatingConnection:Disconnect()
			FloatingConnection = nil
		end
	end)
end

CleanupFloatingModel = function(ModelInstance: Model): ()
	local State: FloatingState? = FloatingStates[ModelInstance]
	if not State then
		return
	end

	FloatingStates[ModelInstance] = nil
	if ModelInstance.Parent then
		pcall(function()
			ModelInstance:PivotTo(State.BasePivot)
		end)
	end

	if next(FloatingStates) == nil and FloatingConnection then
		FloatingConnection:Disconnect()
		FloatingConnection = nil
	end
end

RegisterFloatingModel = function(ModelInstance: Model): ()
	if FloatingStates[ModelInstance] ~= nil then
		return
	end
	if not IsInsideActiveLobby(ModelInstance) then
		return
	end
	if not CollectionService:HasTag(ModelInstance, FLOATING_SPINNING_MODEL_TAG) then
		return
	end

	local BasePivot: CFrame? = ResolveModelPivot(ModelInstance)
	if not BasePivot then
		return
	end

	local Hash: number = HashString(ModelInstance:GetFullName())
	local Phase: number = ((Hash % FLOATING_PHASE_MOD) / FLOATING_PHASE_MOD) * TWO_PI

	FloatingStates[ModelInstance] = {
		Model = ModelInstance,
		BasePivot = BasePivot,
		BasePosition = BasePivot.Position,
		BaseRotation = ResolveRotationOnly(BasePivot),
		Phase = Phase,
		BobAmplitude = FLOATING_BOB_AMPLITUDE,
		BobSpeed = FLOATING_BOB_SPEED,
		SpinSpeed = FLOATING_SPIN_SPEED,
	}

	EnsureFloatingConnection()
end

local function EnsureFloatingPlayerCardConnection(): ()
	if FloatingPlayerCardConnection or next(FloatingPlayerCardStates) == nil then
		return
	end

	FloatingPlayerCardConnection = RunService.RenderStepped:Connect(function()
		local Now: number = os.clock()
		local CardsToCleanup: {BasePart} = {}

		for PartInstance, State in FloatingPlayerCardStates do
			if not PartInstance.Parent then
				table.insert(CardsToCleanup, PartInstance)
				continue
			end
			if not IsInsideActiveLobbyDev(PartInstance) then
				table.insert(CardsToCleanup, PartInstance)
				continue
			end
			if not HasPlayerCardTag(PartInstance) then
				table.insert(CardsToCleanup, PartInstance)
				continue
			end

			local BobOffset: number = math.sin((Now * State.BobSpeed) + State.Phase) * State.BobAmplitude
			local TiltAngle: number = math.sin((Now * State.BobSpeed * 0.7) + State.Phase) * State.TiltAmplitude
			PartInstance.CFrame = (State.BaseCFrame + Vector3.new(0, BobOffset, 0)) * CFrame.Angles(0, 0, TiltAngle)
		end

		for _, PartInstance in CardsToCleanup do
			CleanupFloatingPlayerCard(PartInstance)
		end

		if next(FloatingPlayerCardStates) == nil and FloatingPlayerCardConnection then
			FloatingPlayerCardConnection:Disconnect()
			FloatingPlayerCardConnection = nil
		end
	end)
end

CleanupFloatingPlayerCard = function(PartInstance: BasePart): ()
	local State: FloatingPlayerCardState? = FloatingPlayerCardStates[PartInstance]
	if not State then
		return
	end

	FloatingPlayerCardStates[PartInstance] = nil
	if PartInstance.Parent then
		PartInstance.CFrame = State.BaseCFrame
	end

	if next(FloatingPlayerCardStates) == nil and FloatingPlayerCardConnection then
		FloatingPlayerCardConnection:Disconnect()
		FloatingPlayerCardConnection = nil
	end
end

RegisterFloatingPlayerCard = function(PartInstance: BasePart): ()
	if FloatingPlayerCardStates[PartInstance] ~= nil then
		return
	end
	if not IsInsideActiveLobbyDev(PartInstance) then
		return
	end
	if not HasPlayerCardTag(PartInstance) then
		return
	end

	local Hash: number = HashString(PartInstance:GetFullName())
	local Phase: number = ((Hash % FLOATING_PHASE_MOD) / FLOATING_PHASE_MOD) * TWO_PI

	FloatingPlayerCardStates[PartInstance] = {
		Part = PartInstance,
		BaseCFrame = PartInstance.CFrame,
		Phase = Phase,
		BobAmplitude = PLAYER_CARD_BOB_AMPLITUDE,
		BobSpeed = PLAYER_CARD_BOB_SPEED,
		TiltAmplitude = PLAYER_CARD_TILT_AMPLITUDE,
	}

	EnsureFloatingPlayerCardConnection()
end

local function CaptureOriginalAppearance(State: RigState): ()
	if State.OriginalAppearanceSource ~= nil then
		return
	end

	local Success: boolean, Result: any = pcall(function(): Model
		return State.Model:Clone()
	end)
	if not Success or not Result or not Result:IsA("Model") then
		return
	end

	State.OriginalAppearanceSource = Result
end

local function RestoreOriginalAppearance(State: RigState): ()
	if not State.Applied then
		return
	end
	if not State.OriginalAppearanceSource then
		State.Applied = false
		return
	end
	if State.Model.Parent == nil then
		State.Applied = false
		return
	end

	local Success: boolean, ErrorMessage: any = pcall(function()
		CutsceneRigUtils.ApplyModelAppearance(State.OriginalAppearanceSource :: Model, State.Model)
	end)
	if not Success then
		warn(string.format("LobbyNpcController: failed to restore rig appearance on %s: %s", State.Model:GetFullName(), tostring(ErrorMessage)))
	end

	State.Applied = false
end

local function ApplyLocalPlayerAppearance(State: RigState): ()
	if State.Applied then
		return
	end

	local LocalCharacter: Model? = LocalPlayer.Character
	if not LocalCharacter then
		return
	end
	if LocalCharacter.Parent == nil then
		return
	end

	CaptureOriginalAppearance(State)
	local Success: boolean, ErrorMessage: any = pcall(function()
		CutsceneRigUtils.ApplyPlayerAppearance(LocalPlayer, State.Model, {
			AccessoryMode = "All",
		})
	end)
	if not Success then
		warn(string.format("LobbyNpcController: failed to apply local player appearance on %s: %s", State.Model:GetFullName(), tostring(ErrorMessage)))
		return
	end

	State.Applied = true
end

CleanupRig = function(ModelInstance: Model): ()
	local State: RigState? = RigStates[ModelInstance]
	if not State then
		return
	end

	RigStates[ModelInstance] = nil
	RestoreOriginalAppearance(State)
	if State.AttributeConnection then
		State.AttributeConnection:Disconnect()
	end
	if State.AncestryConnection then
		State.AncestryConnection:Disconnect()
	end
	if State.HumanoidConnection then
		State.HumanoidConnection:Disconnect()
	end
end

RefreshRig = function(ModelInstance: Model): ()
	if not IsInsideActiveLobby(ModelInstance) then
		CleanupRig(ModelInstance)
		return
	end

	local HumanoidInstance: Humanoid? = ResolveRigHumanoid(ModelInstance)
	if not HumanoidInstance then
		CleanupRig(ModelInstance)
		return
	end

	local State: RigState? = RigStates[ModelInstance]
	if not State then
		State = {
			Model = ModelInstance,
			Humanoid = HumanoidInstance,
			OriginalAppearanceSource = nil,
			Applied = false,
			AttributeConnection = nil,
			AncestryConnection = nil,
			HumanoidConnection = nil,
		}
		RigStates[ModelInstance] = State
	end

	local HumanoidChanged: boolean = State.Humanoid ~= HumanoidInstance
	if HumanoidChanged then
		RestoreOriginalAppearance(State)
		if State.HumanoidConnection then
			State.HumanoidConnection:Disconnect()
			State.HumanoidConnection = nil
		end
		State.Humanoid = HumanoidInstance
		State.OriginalAppearanceSource = nil
		State.Applied = false
	end

	if not State.AttributeConnection then
		State.AttributeConnection = ModelInstance:GetAttributeChangedSignal(PLAYER_ATTRIBUTE):Connect(function()
			RefreshRig(ModelInstance)
		end)
	end

	if not State.AncestryConnection then
		State.AncestryConnection = ModelInstance.AncestryChanged:Connect(function()
			if not IsInsideActiveLobby(ModelInstance) then
				CleanupRig(ModelInstance)
				return
			end
			RefreshRig(ModelInstance)
		end)
	end

	if not State.HumanoidConnection then
		State.HumanoidConnection = HumanoidInstance.AncestryChanged:Connect(function()
			if not HumanoidInstance.Parent then
				RefreshRig(ModelInstance)
			end
		end)
	end

	if IsPlayerRig(ModelInstance) then
		ApplyLocalPlayerAppearance(State)
		return
	end

	RestoreOriginalAppearance(State)
end

local function CleanupAllRigs(): ()
	for ModelInstance, _ in RigStates do
		CleanupRig(ModelInstance)
	end
end

local function CleanupAllFloatingModels(): ()
	for ModelInstance, _ in FloatingStates do
		CleanupFloatingModel(ModelInstance)
	end
end

local function CleanupAllFloatingPlayerCards(): ()
	for PartInstance, _ in FloatingPlayerCardStates do
		CleanupFloatingPlayerCard(PartInstance)
	end
end

local function RegisterRigFromHumanoid(HumanoidInstance: Humanoid): ()
	local ModelInstance: Model? = ResolveRigModelFromHumanoid(HumanoidInstance)
	if not ModelInstance then
		return
	end
	if not IsInsideActiveLobby(ModelInstance) then
		return
	end

	RefreshRig(ModelInstance)
end

local function ScanLobby(LobbyInstance: Instance): ()
	if LobbyInstance:IsA("Model") then
		local LobbyHumanoid: Humanoid? = ResolveRigHumanoid(LobbyInstance)
		if LobbyHumanoid then
			RegisterRigFromHumanoid(LobbyHumanoid)
		end
		if CollectionService:HasTag(LobbyInstance, FLOATING_SPINNING_MODEL_TAG) then
			RegisterFloatingModel(LobbyInstance)
		end
	end
	if LobbyInstance:IsA("BasePart") and HasPlayerCardTag(LobbyInstance) then
		RegisterFloatingPlayerCard(LobbyInstance)
	end

	for _, Descendant in LobbyInstance:GetDescendants() do
		if Descendant:IsA("Humanoid") then
			RegisterRigFromHumanoid(Descendant)
			continue
		end
		if Descendant:IsA("Model") and CollectionService:HasTag(Descendant, FLOATING_SPINNING_MODEL_TAG) then
			RegisterFloatingModel(Descendant)
			continue
		end
		if Descendant:IsA("BasePart") and HasPlayerCardTag(Descendant) then
			RegisterFloatingPlayerCard(Descendant)
		end
	end
end

local function DetachLobby(): ()
	GlobalFunctions.DisconnectAll(LobbyConnections)
	CleanupAllRigs()
	CleanupAllFloatingModels()
	CleanupAllFloatingPlayerCards()
	ActiveLobby = nil
end

local function AttachLobby(LobbyInstance: Instance): ()
	if ActiveLobby == LobbyInstance then
		return
	end

	DetachLobby()
	ActiveLobby = LobbyInstance

	table.insert(LobbyConnections, LobbyInstance.DescendantAdded:Connect(function(Descendant: Instance)
		if Descendant:IsA("Humanoid") then
			RegisterRigFromHumanoid(Descendant)
			return
		end
		if Descendant:IsA("Model") and CollectionService:HasTag(Descendant, FLOATING_SPINNING_MODEL_TAG) then
			RegisterFloatingModel(Descendant)
			return
		end
		if Descendant:IsA("BasePart") and HasPlayerCardTag(Descendant) then
			RegisterFloatingPlayerCard(Descendant)
		end
	end))

	table.insert(LobbyConnections, LobbyInstance.DescendantRemoving:Connect(function(Descendant: Instance)
		if Descendant:IsA("Humanoid") then
			local ModelInstance: Model? = ResolveRigModelFromHumanoid(Descendant)
			if ModelInstance then
				task.defer(function()
					RefreshRig(ModelInstance)
				end)
			end
			return
		end

		if Descendant:IsA("Model") and RigStates[Descendant] then
			CleanupRig(Descendant)
		end
		if Descendant:IsA("Model") and FloatingStates[Descendant] then
			CleanupFloatingModel(Descendant)
		end
		if Descendant:IsA("BasePart") and FloatingPlayerCardStates[Descendant] then
			CleanupFloatingPlayerCard(Descendant)
		end
	end))

	ScanLobby(LobbyInstance)
end

local function RefreshAllPlayerRigs(): ()
	for _, State in RigStates do
		State.Applied = false
	end

	for ModelInstance, _ in RigStates do
		RefreshRig(ModelInstance)
	end
end

local function HandleWorkspaceChildAdded(Child: Instance): ()
	if Child.Name ~= LOBBY_NAME then
		return
	end

	AttachLobby(Child)
end

local function HandleWorkspaceChildRemoved(Child: Instance): ()
	if Child ~= ActiveLobby then
		return
	end

	DetachLobby()
end

local function HandleFloatingTaggedAdded(InstanceItem: Instance): ()
	if not InstanceItem:IsA("Model") then
		return
	end

	RegisterFloatingModel(InstanceItem)
end

local function HandleFloatingTaggedRemoved(InstanceItem: Instance): ()
	if not InstanceItem:IsA("Model") then
		return
	end

	CleanupFloatingModel(InstanceItem)
end

local function HandlePlayerCardTaggedAdded(InstanceItem: Instance): ()
	if not InstanceItem:IsA("BasePart") then
		return
	end

	RegisterFloatingPlayerCard(InstanceItem)
end

local function HandlePlayerCardTaggedRemoved(InstanceItem: Instance): ()
	if not InstanceItem:IsA("BasePart") then
		return
	end

	CleanupFloatingPlayerCard(InstanceItem)
end

function LobbyNpcController.Init(): ()
	return
end

function LobbyNpcController.Start(): ()
	if Started then
		return
	end
	Started = true

	local LobbyInstance: Instance? = Workspace:FindFirstChild(LOBBY_NAME)
	if LobbyInstance then
		AttachLobby(LobbyInstance)
	end

	table.insert(_WorkspaceConnections, Workspace.ChildAdded:Connect(HandleWorkspaceChildAdded))
	table.insert(_WorkspaceConnections, Workspace.ChildRemoved:Connect(HandleWorkspaceChildRemoved))
	table.insert(
		_WorkspaceConnections,
		CollectionService:GetInstanceAddedSignal(FLOATING_SPINNING_MODEL_TAG):Connect(HandleFloatingTaggedAdded)
	)
	table.insert(
		_WorkspaceConnections,
		CollectionService:GetInstanceRemovedSignal(FLOATING_SPINNING_MODEL_TAG):Connect(HandleFloatingTaggedRemoved)
	)
	for _, TagName in PLAYER_CARD_TAG_ALIASES do
		table.insert(
			_WorkspaceConnections,
			CollectionService:GetInstanceAddedSignal(TagName):Connect(HandlePlayerCardTaggedAdded)
		)
		table.insert(
			_WorkspaceConnections,
			CollectionService:GetInstanceRemovedSignal(TagName):Connect(HandlePlayerCardTaggedRemoved)
		)
	end
	table.insert(_PlayerConnections, LocalPlayer.CharacterAdded:Connect(function()
		task.defer(RefreshAllPlayerRigs)
	end))
	table.insert(_PlayerConnections, LocalPlayer.CharacterAppearanceLoaded:Connect(function()
		task.defer(RefreshAllPlayerRigs)
	end))
end

return LobbyNpcController
