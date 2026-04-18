--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local UserInputService: UserInputService = game:GetService("UserInputService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local FlowBuffs: any = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local FlowsData: any = require(ReplicatedStorage.Modules.Data.FlowsData)

local MatchFlowController = {}

local LocalPlayer: Player = Players.LocalPlayer
local PlayerGui: PlayerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

local FLOW_KEY: Enum.KeyCode = Enum.KeyCode.T
local UI_TWEEN_INFO: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local AURA_REFRESH_INTERVAL: number = 0.1
local FLOW_OFFSET_TWEEN_MIN_INTERVAL: number = 1 / 20
local FLOW_OFFSET_EPSILON: number = 0.0015
local FLOW_AURA_NAME: string = "FTFlowAura"
local FLOW_AURA_OWNER_ATTRIBUTE: string = "FTFlowAuraOwner"
local FLOW_AURA_ID_ATTRIBUTE: string = "FTFlowAuraId"
local FLOW_PROTECTED_ATTRIBUTE: string = "FTFlowProtectedAura"
local FLOW_PENDING_DESTROY_ATTRIBUTE: string = "FTFlowAuraPendingDestroy"
local FLOW_AURA_DESTROY_DELAY: number = 3
local FLOW_READY_TEXT: string = "PRESS T TO ACTIVATE FLOW"

type AuraState = {
	Character: Model?,
	FlowId: string?,
	AuraInstance: Instance?,
}

type ControllerState = {
	FillRoot: GuiObject?,
	OffsetTarget: Instance?,
	PercentLabel: TextLabel?,
	ChangeMode: GuiObject?,
	ChangeButton: GuiButton?,
	HintTextButton: TextButton?,
	OffsetTween: Tween?,
}

local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild("Assets")
local EffectsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild("Effects") or nil
local AurasFolder: Instance? = EffectsFolder and EffectsFolder:FindFirstChild("Auras") or nil
local AuraStates: {[Player]: AuraState} = {}
local State: ControllerState = {
	FillRoot = nil,
	OffsetTarget = nil,
	PercentLabel = nil,
	ChangeMode = nil,
	ChangeButton = nil,
	HintTextButton = nil,
	OffsetTween = nil,
}
local AuraRefreshElapsed: number = 0
local ChangeButtonConnection: RBXScriptConnection? = nil
local LastFlowOffset: Vector2 = Vector2.new(math.huge, math.huge)
local LastFlowOffsetTweenAt: number = 0
local RequestFlowActivation: () -> ()

local function IsInstanceAlive(Target: Instance?): boolean
	return Target ~= nil and Target.Parent ~= nil
end

local function FindBarOffsetTarget(Root: Instance?): Instance?
	if not Root then
		return nil
	end
	for _, ChildName: string in { "Fill", "Container" } do
		local Parent: Instance? = Root:FindFirstChild(ChildName)
		local Adjust: Instance? = Parent and Parent:FindFirstChild("AdjustThisOffset", true) or nil
		if Adjust then
			return Adjust
		end
	end
	return Root:FindFirstChild("AdjustThisOffset", true)
end

local function FindPercentLabel(Root: Instance?): TextLabel?
	if not Root then
		return nil
	end
	local Label: Instance? = Root:FindFirstChild("TextLabel") or Root:FindFirstChild("TextLabel", true)
	if Label and Label:IsA("TextLabel") then
		return Label
	end
	return nil
end

local function HasValidUi(): boolean
	return IsInstanceAlive(State.FillRoot)
		and IsInstanceAlive(State.OffsetTarget)
		and IsInstanceAlive(State.ChangeMode)
		and IsInstanceAlive(State.HintTextButton)
end

local function BindChangeButton(): ()
	if ChangeButtonConnection then
		ChangeButtonConnection:Disconnect()
		ChangeButtonConnection = nil
	end
	if not State.ChangeButton then
		return
	end
	ChangeButtonConnection = State.ChangeButton.Activated:Connect(RequestFlowActivation)
end

local function StopOffsetTween(): ()
	if State.OffsetTween then
		State.OffsetTween:Cancel()
		State.OffsetTween = nil
	end
end

local function TweenFlowOffset(Value: Vector2): ()
	local Target: Instance? = State.OffsetTarget
	if not Target then
		return
	end

	if math.abs(LastFlowOffset.X - Value.X) <= FLOW_OFFSET_EPSILON
		and math.abs(LastFlowOffset.Y - Value.Y) <= FLOW_OFFSET_EPSILON
	then
		return
	end

	local Now: number = os.clock()
	local ShouldTween: boolean = (Now - LastFlowOffsetTweenAt) >= FLOW_OFFSET_TWEEN_MIN_INTERVAL
	LastFlowOffset = Value

	StopOffsetTween()
	if not ShouldTween then
		pcall(function()
			(Target :: any).Offset = Value
		end)
		return
	end

	local Success: boolean, TweenInstance: Tween? = pcall(function()
		return TweenService:Create(Target, UI_TWEEN_INFO, { Offset = Value })
	end)
	if not Success or not TweenInstance then
		pcall(function()
			(Target :: any).Offset = Value
		end)
		return
	end
	LastFlowOffsetTweenAt = Now
	State.OffsetTween = TweenInstance
	TweenInstance:Play()
	TweenInstance.Completed:Connect(function()
		if State.OffsetTween == TweenInstance then
			State.OffsetTween = nil
		end
	end)
end

local function ResolveActivationButton(ChangeMode: Instance?): GuiButton?
	if not ChangeMode then
		return nil
	end
	if ChangeMode:IsA("GuiButton") then
		return ChangeMode
	end
	return ChangeMode:FindFirstChildWhichIsA("GuiButton", true)
end

local function ResolveUi(): ()
	State.FillRoot = nil
	State.OffsetTarget = nil
	State.PercentLabel = nil
	State.ChangeMode = nil
	State.ChangeButton = nil
	State.HintTextButton = nil
	LastFlowOffset = Vector2.new(math.huge, math.huge)
	LastFlowOffsetTweenAt = 0
	BindChangeButton()

	local GameGui: ScreenGui? = PlayerGui:FindFirstChild("GameGui") :: ScreenGui?
	if not GameGui then
		return
	end

	local Main: Instance? = GameGui:FindFirstChild("Main")
	local Frame: Instance? = Main and Main:FindFirstChild("Frame")
	if not Frame then
		return
	end

	local FillRoot: Instance? = Frame:FindFirstChild("Fill")
	if FillRoot and FillRoot:IsA("GuiObject") then
		State.FillRoot = FillRoot
		State.OffsetTarget = FindBarOffsetTarget(FillRoot)
		State.PercentLabel = FindPercentLabel(FillRoot)
	end

	local ChangeMode: Instance? = Frame:FindFirstChild("ChangeMode")
	if ChangeMode and ChangeMode:IsA("GuiObject") then
		State.ChangeMode = ChangeMode
		State.ChangeButton = ResolveActivationButton(ChangeMode)
		BindChangeButton()
	end

	local HintTextButton: Instance? = Frame:FindFirstChild("TextButton")
	if HintTextButton and HintTextButton:IsA("TextButton") then
		State.HintTextButton = HintTextButton
	end
end

RequestFlowActivation = function(): ()
	Packets.FlowActivateRequest:Fire()
end

local function UpdateLocalUi(): ()
	if not HasValidUi() then
		ResolveUi()
	end

	local Percent: number = FlowBuffs.GetFlowPercent(LocalPlayer)
	local Active: boolean = FlowBuffs.IsFlowActive(LocalPlayer)
	local Ready: boolean = (not Active) and Percent >= FlowBuffs.ACTIVATION_THRESHOLD
	local Normalized: number = math.clamp(Percent / FlowBuffs.MAX_FLOW_PERCENT, 0, 1)

	if State.FillRoot then
		State.FillRoot.Visible = true
	end
	if State.PercentLabel then
		State.PercentLabel.Visible = true
		if Ready then
			State.PercentLabel.Text = FLOW_READY_TEXT
		else
			State.PercentLabel.Text = string.format("%d%%", Percent)
		end
	end
	if State.OffsetTarget then
		TweenFlowOffset(Vector2.new(Normalized, 0))
	end
	if State.ChangeMode then
		State.ChangeMode.Visible = Ready
	end
	if State.HintTextButton then
		State.HintTextButton.Visible = (not Active) and (not Ready)
	end
end

local function SetAuraEffectsEnabled(Target: Instance, Enabled: boolean, EmitOnEnable: boolean?): ()
	local function ApplyToInstance(Item: Instance): ()
		if Item:IsA("ParticleEmitter") then
			Item.Enabled = Enabled
			if Enabled and EmitOnEnable then
				local EmitCount: any = Item:GetAttribute("EmitCount")
				if typeof(EmitCount) == "number" and EmitCount > 0 then
					Item:Emit(math.max(1, math.round(EmitCount)))
				end
			end
		elseif
			Item:IsA("Beam")
			or Item:IsA("Trail")
			or Item:IsA("Light")
			or Item:IsA("Fire")
			or Item:IsA("Smoke")
			or Item:IsA("Sparkles")
		then
			pcall(function()
				(Item :: any).Enabled = Enabled
			end)
		end
	end

	ApplyToInstance(Target)
	for _, Descendant in Target:GetDescendants() do
		ApplyToInstance(Descendant)
	end
end

local function ResolveAurasFolder(): Instance?
	if AurasFolder and AurasFolder.Parent ~= nil then
		return AurasFolder
	end

	if not EffectsFolder or EffectsFolder.Parent == nil then
		AssetsFolder = ReplicatedStorage:FindFirstChild("Assets")
		EffectsFolder = AssetsFolder and AssetsFolder:FindFirstChild("Effects") or nil
	end
	if not EffectsFolder then
		return nil
	end

	AurasFolder = EffectsFolder:FindFirstChild("Auras")
	return AurasFolder
end

local function GetAuraTemplate(FlowId: string?): Instance?
	if typeof(FlowId) ~= "string" then
		return nil
	end
	local ResolvedAurasFolder: Instance? = ResolveAurasFolder()
	if not ResolvedAurasFolder then
		return nil
	end
	local FlowData: any = FlowsData[FlowId]
	local AuraModelName: string? =
		if FlowData and typeof(FlowData.AuraModelName) == "string" and FlowData.AuraModelName ~= ""
			then FlowData.AuraModelName
			else FlowId
	return ResolvedAurasFolder:FindFirstChild(AuraModelName)
end

local function DestroyAuraInstance(AuraInstance: Instance?): ()
	if not AuraInstance then
		return
	end
	if AuraInstance:GetAttribute(FLOW_PENDING_DESTROY_ATTRIBUTE) == true then
		return
	end

	AuraInstance:SetAttribute(FLOW_PENDING_DESTROY_ATTRIBUTE, true)
	SetAuraEffectsEnabled(AuraInstance, false)
	task.delay(FLOW_AURA_DESTROY_DELAY, function()
		if AuraInstance.Parent ~= nil then
			AuraInstance:Destroy()
		end
	end)
end

local function ClearAuraState(Player: Player): ()
	local Existing: AuraState? = AuraStates[Player]
	if not Existing then
		return
	end
	DestroyAuraInstance(Existing.AuraInstance)
	Existing.AuraInstance = nil
	Existing.Character = nil
	Existing.FlowId = nil
end

local function EnsureAuraState(Player: Player): AuraState
	local Existing: AuraState? = AuraStates[Player]
	if Existing then
		return Existing
	end
	local NewState: AuraState = {
		Character = nil,
		FlowId = nil,
		AuraInstance = nil,
	}
	AuraStates[Player] = NewState
	return NewState
end

local function AttachAuraToCharacter(Player: Player, Character: Model, AuraTemplate: Instance, FlowId: string): Instance
	local AuraClone: Instance = AuraTemplate:Clone()
	AuraClone.Name = FLOW_AURA_NAME
	AuraClone:SetAttribute("IsAura", true)
	AuraClone:SetAttribute(FLOW_PROTECTED_ATTRIBUTE, true)
	AuraClone:SetAttribute(FLOW_PENDING_DESTROY_ATTRIBUTE, false)
	AuraClone:SetAttribute(FLOW_AURA_OWNER_ATTRIBUTE, Player.UserId)
	AuraClone:SetAttribute(FLOW_AURA_ID_ATTRIBUTE, FlowId)
	SetAuraEffectsEnabled(AuraClone, false)
	AuraClone.Parent = Character

	local RootPart: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if AuraClone:IsA("BasePart") and RootPart then
		AuraClone.Anchored = false
		AuraClone.CanCollide = false
		AuraClone.Massless = true
		AuraClone.Transparency = 1
		AuraClone.CFrame = RootPart.CFrame

		local RootWeld: WeldConstraint = Instance.new("WeldConstraint")
		RootWeld.Name = "FTFlowAuraWeld"
		RootWeld.Part0 = AuraClone
		RootWeld.Part1 = RootPart
		RootWeld.Parent = AuraClone
	end
	for _, Descendant in AuraClone:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		local TargetPart: Instance? = Character:FindFirstChild(Descendant.Name, true)
		if not TargetPart or not TargetPart:IsA("BasePart") then
			TargetPart = RootPart
		end
		if not TargetPart or not TargetPart:IsA("BasePart") then
			continue
		end

		Descendant.Anchored = false
		Descendant.CanCollide = false
		Descendant.Massless = true
		Descendant.Transparency = 1
		Descendant.CFrame = TargetPart.CFrame

		local Weld: WeldConstraint = Instance.new("WeldConstraint")
		Weld.Name = "FTFlowAuraWeld"
		Weld.Part0 = Descendant
		Weld.Part1 = TargetPart
		Weld.Parent = Descendant
	end

	SetAuraEffectsEnabled(AuraClone, true, true)
	return AuraClone
end

local function MaintainAuraForPlayer(Player: Player): ()
	local Active: boolean = FlowBuffs.IsFlowActive(Player)
	local FlowId: string? = FlowBuffs.GetActiveFlowId(Player)
	local Character: Model? = Player.Character
	local AuraStateData: AuraState = EnsureAuraState(Player)

	if not Active or not Character or not FlowId then
		ClearAuraState(Player)
		return
	end

	local AuraTemplate: Instance? = GetAuraTemplate(FlowId)
	if not AuraTemplate then
		ClearAuraState(Player)
		AuraStateData.Character = Character
		AuraStateData.FlowId = FlowId
		return
	end

	local NeedsRebuild: boolean =
		AuraStateData.AuraInstance == nil
		or AuraStateData.AuraInstance.Parent == nil
		or AuraStateData.Character ~= Character
		or AuraStateData.FlowId ~= FlowId

	if NeedsRebuild then
		DestroyAuraInstance(AuraStateData.AuraInstance)
		AuraStateData.Character = Character
		AuraStateData.FlowId = FlowId
		AuraStateData.AuraInstance = AttachAuraToCharacter(Player, Character, AuraTemplate, FlowId)
		return
	end

	if AuraStateData.AuraInstance then
		SetAuraEffectsEnabled(AuraStateData.AuraInstance, true, false)
	end
end

local function RefreshAllAuras(): ()
	for _, Player in Players:GetPlayers() do
		MaintainAuraForPlayer(Player)
	end
end

function MatchFlowController.Init(): ()
	Players.PlayerRemoving:Connect(function(Player: Player)
		ClearAuraState(Player)
		AuraStates[Player] = nil
	end)

	PlayerGui.DescendantAdded:Connect(function(Child: Instance)
		if Child.Name == "GameGui" then
			task.defer(UpdateLocalUi)
		end
	end)
end

function MatchFlowController.Start(): ()
	ResolveUi()
	UpdateLocalUi()
	RefreshAllAuras()

	LocalPlayer:GetAttributeChangedSignal(FlowBuffs.ATTR_FLOW_PERCENT):Connect(UpdateLocalUi)
	LocalPlayer:GetAttributeChangedSignal(FlowBuffs.ATTR_FLOW_ACTIVE):Connect(UpdateLocalUi)
	LocalPlayer:GetAttributeChangedSignal(FlowBuffs.ATTR_FLOW_READY):Connect(UpdateLocalUi)

	LocalPlayer.CharacterAdded:Connect(function()
		task.defer(UpdateLocalUi)
	end)

	UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
		if GameProcessed then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if Input.KeyCode ~= FLOW_KEY then
			return
		end
		RequestFlowActivation()
	end)

	RunService.Heartbeat:Connect(function(DeltaTime: number)
		AuraRefreshElapsed += DeltaTime
		if AuraRefreshElapsed >= AURA_REFRESH_INTERVAL then
			AuraRefreshElapsed = 0
			RefreshAllAuras()
		end
	end)
end

return MatchFlowController
