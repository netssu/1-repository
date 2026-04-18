--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local FlowBuffs: any = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local FTPlayerService: any = require(script.Parent.PlayerService)

type FlowState = {
	Percent: number,
	Active: boolean,
	PassiveElapsed: number,
	DrainElapsed: number,
	FlowId: string?,
	ActivationTrack: AnimationTrack?,
	ActivationAnimation: Animation?,
}

local FTFlowService = {}

local PlayerStates: {[Player]: FlowState} = {}

local function StopActivationAnimation(State: FlowState): ()
	if State.ActivationTrack then
		pcall(function()
			State.ActivationTrack:Stop(0)
		end)
		pcall(function()
			State.ActivationTrack:Destroy()
		end)
		State.ActivationTrack = nil
	end

	if State.ActivationAnimation then
		pcall(function()
			State.ActivationAnimation:Destroy()
		end)
		State.ActivationAnimation = nil
	end
end

local function PlayActivationAnimation(Player: Player, State: FlowState, FlowId: string?): ()
	StopActivationAnimation(State)

	if typeof(FlowId) ~= "string" or FlowId == "" then
		return
	end

	local Definition = FlowBuffs.GetDefinition(FlowId)
	local AnimationId = Definition and Definition.AnimationId
	if typeof(AnimationId) ~= "string" or AnimationId == "" then
		return
	end

	local Character: Model? = Player.Character
	if not Character then
		return
	end

	local Humanoid: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	local Animator: Animator? = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end

	local AnimationInstance: Animation = Instance.new("Animation")
	AnimationInstance.Name = "FlowActivationAnimation"
	AnimationInstance.AnimationId = AnimationId
	AnimationInstance.Parent = Character

	local Success: boolean, TrackOrError: any = pcall(function()
		return Animator:LoadAnimation(AnimationInstance)
	end)
	if not Success or not TrackOrError then
		AnimationInstance:Destroy()
		warn("[FlowService] Failed to load flow activation animation:", Player.Name, FlowId, AnimationId, TrackOrError)
		return
	end

	local Track: AnimationTrack = TrackOrError
	Track.Looped = false
	Track.Priority = Enum.AnimationPriority.Action
	Track:Play(0.05)

	State.ActivationTrack = Track
	State.ActivationAnimation = AnimationInstance

	Track.Stopped:Connect(function()
		if State.ActivationTrack == Track then
			State.ActivationTrack = nil
		end
		if State.ActivationAnimation == AnimationInstance then
			State.ActivationAnimation = nil
		end
		pcall(function()
			Track:Destroy()
		end)
		pcall(function()
			AnimationInstance:Destroy()
		end)
	end)
end

local function SetCharacterAttributes(Character: Model, State: FlowState): ()
	Character:SetAttribute(FlowBuffs.ATTR_FLOW_PERCENT, State.Percent)
	Character:SetAttribute(FlowBuffs.ATTR_FLOW_ACTIVE, State.Active)
	Character:SetAttribute(FlowBuffs.ATTR_FLOW_READY, (not State.Active) and State.Percent >= FlowBuffs.ACTIVATION_THRESHOLD)
	Character:SetAttribute(FlowBuffs.ATTR_FLOW_TYPE, State.FlowId or "")
end

local function EnsureState(Player: Player): FlowState
	local Existing: FlowState? = PlayerStates[Player]
	if Existing then
		return Existing
	end

	local NewState: FlowState = {
		Percent = 0,
		Active = false,
		PassiveElapsed = 0,
		DrainElapsed = 0,
		FlowId = FlowBuffs.GetEquippedFlowId(Player),
		ActivationTrack = nil,
		ActivationAnimation = nil,
	}
	PlayerStates[Player] = NewState
	return NewState
end

local function RefreshInactiveFlowId(Player: Player, State: FlowState): ()
	if State.Active then
		return
	end
	State.FlowId = FlowBuffs.GetEquippedFlowId(Player)
end

local function SyncAttributes(Player: Player): ()
	local State: FlowState = EnsureState(Player)
	if not State.Active then
		RefreshInactiveFlowId(Player, State)
	end

	Player:SetAttribute(FlowBuffs.ATTR_FLOW_PERCENT, State.Percent)
	Player:SetAttribute(FlowBuffs.ATTR_FLOW_ACTIVE, State.Active)
	Player:SetAttribute(FlowBuffs.ATTR_FLOW_READY, (not State.Active) and State.Percent >= FlowBuffs.ACTIVATION_THRESHOLD)
	Player:SetAttribute(FlowBuffs.ATTR_FLOW_TYPE, State.FlowId or "")

	local Character: Model? = Player.Character
	if Character then
		SetCharacterAttributes(Character, State)
	end
end

local function SetPercent(Player: Player, State: FlowState, Percent: number): ()
	local Clamped: number = math.clamp(math.round(Percent), 0, FlowBuffs.MAX_FLOW_PERCENT)
	if State.Percent == Clamped then
		SyncAttributes(Player)
		return
	end
	State.Percent = Clamped
	SyncAttributes(Player)
end

local function StopFlow(Player: Player, State: FlowState): ()
	State.Active = false
	State.DrainElapsed = 0
	State.PassiveElapsed = 0
	State.FlowId = FlowBuffs.GetEquippedFlowId(Player)
	StopActivationAnimation(State)
	SyncAttributes(Player)
end

local function ResetFlow(Player: Player, State: FlowState): ()
	State.Percent = 0
	State.Active = false
	State.PassiveElapsed = 0
	State.DrainElapsed = 0
	State.FlowId = FlowBuffs.GetEquippedFlowId(Player)
	StopActivationAnimation(State)
	SyncAttributes(Player)
end

local function CanChargeOrDrain(Player: Player): boolean
	if Player.Parent == nil then
		return false
	end
	return FTPlayerService:IsPlayerInMatch(Player)
end

local function TryActivateFlow(Player: Player): ()
	local State: FlowState = EnsureState(Player)
	if State.Active then
		return
	end
	if State.Percent < FlowBuffs.ACTIVATION_THRESHOLD then
		return
	end
	if not CanChargeOrDrain(Player) then
		return
	end

	State.Active = true
	State.PassiveElapsed = 0
	State.DrainElapsed = 0
	State.FlowId = FlowBuffs.GetEquippedFlowId(Player)
	SyncAttributes(Player)
	PlayActivationAnimation(Player, State, State.FlowId)
end

local function HandleActivateRequest(Player: Player): ()
	TryActivateFlow(Player)
end

local function HandleCharacterAdded(Player: Player, Character: Model): ()
	local State: FlowState = EnsureState(Player)
	SetCharacterAttributes(Character, State)
end

local function HandlePlayerAdded(Player: Player): ()
	local _State: FlowState = EnsureState(Player)
	SyncAttributes(Player)

	Player.CharacterAdded:Connect(function(Character: Model)
		HandleCharacterAdded(Player, Character)
	end)

	if Player.Character then
		HandleCharacterAdded(Player, Player.Character)
	end
end

local function HandlePlayerRemoving(Player: Player): ()
	local State: FlowState? = PlayerStates[Player]
	if State then
		StopActivationAnimation(State)
	end
	PlayerStates[Player] = nil
end

local function UpdatePassiveFlow(Player: Player, State: FlowState, DeltaTime: number): ()
	State.PassiveElapsed += DeltaTime
	while State.PassiveElapsed >= FlowBuffs.PASSIVE_GAIN_INTERVAL do
		State.PassiveElapsed -= FlowBuffs.PASSIVE_GAIN_INTERVAL
		SetPercent(Player, State, State.Percent + FlowBuffs.PASSIVE_GAIN_AMOUNT)
	end
end

local function UpdateActiveFlow(Player: Player, State: FlowState, DeltaTime: number): ()
	State.DrainElapsed += DeltaTime
	while State.DrainElapsed >= FlowBuffs.DRAIN_INTERVAL do
		State.DrainElapsed -= FlowBuffs.DRAIN_INTERVAL
		local NewPercent: number = State.Percent - FlowBuffs.DRAIN_STEP
		if NewPercent <= 0 then
			State.Percent = 0
			StopFlow(Player, State)
			return
		end
		SetPercent(Player, State, NewPercent)
	end
end

local function UpdatePlayerFlow(Player: Player, DeltaTime: number): ()
	local State: FlowState = EnsureState(Player)

	if not CanChargeOrDrain(Player) then
		if State.Active or State.Percent > 0 or State.PassiveElapsed > 0 or State.DrainElapsed > 0 then
			ResetFlow(Player, State)
			return
		end
		local PreviousFlowId: string? = State.FlowId
		RefreshInactiveFlowId(Player, State)
		if PreviousFlowId ~= State.FlowId then
			SyncAttributes(Player)
		end
		return
	end

	if State.Active then
		UpdateActiveFlow(Player, State, DeltaTime)
	else
		UpdatePassiveFlow(Player, State, DeltaTime)
	end
end

function FTFlowService.Init(_self: typeof(FTFlowService)): ()
	Packets.FlowActivateRequest.OnServerEvent:Connect(HandleActivateRequest)
	Players.PlayerAdded:Connect(HandlePlayerAdded)
	Players.PlayerRemoving:Connect(HandlePlayerRemoving)

	for _, Player in Players:GetPlayers() do
		HandlePlayerAdded(Player)
	end
end

function FTFlowService.Start(_self: typeof(FTFlowService)): ()
	RunService.Heartbeat:Connect(function(DeltaTime: number)
		for _, Player in Players:GetPlayers() do
			UpdatePlayerFlow(Player, DeltaTime)
		end
	end)
end

function FTFlowService.GetPlayerPercent(_self: typeof(FTFlowService), Player: Player): number
	return EnsureState(Player).Percent
end

function FTFlowService.IsActive(_self: typeof(FTFlowService), Player: Player): boolean
	return EnsureState(Player).Active
end

function FTFlowService.ResetPlayer(_self: typeof(FTFlowService), Player: Player): ()
	if typeof(Player) ~= "Instance" or not Player:IsA("Player") then
		return
	end

	local State: FlowState = EnsureState(Player)
	ResetFlow(Player, State)
end

return FTFlowService
