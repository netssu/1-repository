--!strict

local Players: Players = game:GetService("Players")
local UserInputService: UserInputService = game:GetService("UserInputService")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local FTConfig: any = require(ReplicatedStorage.Modules.Game.Config)
local FlowBuffs: any = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local SharedSkills: any = require(ReplicatedStorage.Modules.Game.Skills)
local PlayerDataGuard: any = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)
local SkillInputGate: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillInputGate)
local SkillCooldownTracker: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillCooldownTracker)
local SkillClientGuard: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillClientGuard)
local SkillAssetPreloader: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillAssetPreloader)
local ThrowAimResolver: any = require(ReplicatedStorage.Modules.Game.Skills.Utils.ThrowAimResolver)
local NotificationController: any = require(ReplicatedStorage.Controllers.NotificationController)

type SkillDefinition = {
	Id: string,
	Name: string,
	Cooldown: number,
	Benefit: string,
	VFXPath: string,
	Module: string,
	VFX: any,
	Input: any?,
	RequiresBall: boolean?,
	BlocksWhenHoldingBall: boolean?,
}

type SkillInputBehavior = {
	Mode: string,
}

type HeldSkillState = {
	StartedAt: number,
}

local FTSkillController: {[string]: any} = {}

--// CONSTANTS
local ZERO: number = 0
local ONE: number = 1
local TWO: number = 2
local THREE: number = 3
local FOUR: number = 4

local COOLDOWN_DECIMAL_FACTOR: number = 10
local COOLDOWN_TEXT_FORMAT: string = "%.1fs"
local INPUT_DEBOUNCE_WINDOW: number = 0.08
local AWAKEN_INPUT_DEBOUNCE_WINDOW: number = 0.12

local AWAKEN_HIDE_TIME: number = 0.15

local FULL_SCALE: number = ONE
local EMPTY_SCALE: number = ZERO
local OFFSET_VISIBLE: Vector2 = Vector2.new(ONE, ZERO)
local OFFSET_EMPTY: Vector2 = Vector2.new(ZERO, ZERO)
local OFFSET_EASE_STYLE: Enum.EasingStyle = Enum.EasingStyle.Linear
local OFFSET_EASE_DIR: Enum.EasingDirection = Enum.EasingDirection.Out

local SLOT_PREFIX: string = "Slot"
local INPUT_SLOTS_MIN: number = ONE
local INPUT_SLOTS_MAX: number = THREE
local STYLE_SLOTS_MAX: number = FOUR

local AWAKEN_STATUS_READY: string = "Ready"
local AWAKEN_STATUS_START: string = "Start"
local AWAKEN_STATUS_END: string = "End"
local ATTR_AWAKEN_READY: string = "AwakenReady"
local ATTR_AWAKEN_ACTIVE: string = "AwakenActive"
local ATTR_INVULNERABLE: string = "Invulnerable"
local ATTR_SKILL_LOCKED: string = "FTSkillLocked"
local ATTR_MATCH_CUTSCENE_LOCKED: string = "FTMatchCutsceneLocked"
local ATTR_PERFECT_PASS_CUTSCENE_LOCKED: string = "FTPerfectPassCutsceneLocked"
local ATTR_AWAKEN_CUTSCENE_ACTIVE: string = "FTAwakenCutsceneActive"
local ATTR_CUTSCENE_HUD_HIDDEN: string = "FTCutsceneHudHidden"
local HIRUMA_THROW_MODULE_NAME: string = "HirumaThrow"
local EMPTY_AIM_TARGET: Vector3 = Vector3.zero
local SKILL_HOLD_ACTION_BEGIN: number = 1
local SKILL_HOLD_ACTION_RELEASE: number = 2
local HOLD_INPUT_MODE: string = "Hold"
local BALL_REQUIRED_NOTIFICATION_TITLE: string = "Ball Required"
local BALL_REQUIRED_NOTIFICATION_MESSAGE: string = "You need to have the ball."
local BALL_REQUIRED_NOTIFICATION_DURATION: number = 2
local BALL_REQUIRED_NOTIFICATION_COOLDOWN: number = 1

type LabelLike = TextLabel | TextButton

type ButtonState = {
	Button: GuiButton,
	Label: LabelLike?,
	OriginalText: string,
	OriginalActive: boolean,
	OriginalAutoColor: boolean,
}

type ControllerState = {
	AwakenReady: boolean,
	AwakenActive: boolean,
	AwakenDuration: number,
	AwakenCountdownStarted: boolean,
	AwakenCountdownBeginsAt: number,
	AwakenCountdownEndsAt: number,
	AwakenCutsceneObserved: boolean,
	AwakenBarVisible: boolean,
	AwakenOffsetToken: number,
	Buttons: {[number]: ButtonState},
	ButtonsRoot: GuiObject?,
	FillAwaken: Instance?,
	AwakenFillSize: UDim2?,
	AwakenBar: GuiObject?,
	AwakenOffset: Instance?,
	AwakenFillTween: Tween?,
	AwakenOffsetTween: Tween?,
	HeldSkills: {[number]: HeldSkillState},
}

local LocalPlayer: Player = Players.LocalPlayer
local SkillsData: any = SharedSkills

local State: ControllerState = {
	AwakenReady = false,
	AwakenActive = false,
	AwakenDuration = ZERO,
	AwakenCountdownStarted = false,
	AwakenCountdownBeginsAt = ZERO,
	AwakenCountdownEndsAt = ZERO,
	AwakenCutsceneObserved = false,
	AwakenBarVisible = false,
	AwakenOffsetToken = ZERO,
	Buttons = {},
	ButtonsRoot = nil,
	FillAwaken = nil,
	AwakenFillSize = nil,
	AwakenBar = nil,
	AwakenOffset = nil,
	AwakenFillTween = nil,
	AwakenOffsetTween = nil,
	HeldSkills = {},
}

local InputGate: any = SkillInputGate.new()
local CooldownTracker: any = SkillCooldownTracker.new()
local LastBallRequiredNotificationAt: number = -math.huge
local HUD_REFERENCE_NAMES: {[string]: boolean} = {
	GameGui = true,
	Main = true,
	Frame = true,
	Buttons = true,
	FillAwaken = true,
	Fill = true,
	Container = true,
	AdjustThisOffset = true,
	Slot1 = true,
	Slot2 = true,
	Slot3 = true,
}

local function IsInstanceAlive(Target: Instance?): boolean
	return Target ~= nil and Target.Parent ~= nil
end

local function HasValidButtons(): boolean
	return IsInstanceAlive(State.ButtonsRoot)
end

local function HasValidAwakenBar(): boolean
	return IsInstanceAlive(State.AwakenBar) and IsInstanceAlive(State.FillAwaken) and IsInstanceAlive(State.AwakenOffset)
end

local function ClearButtonReferences(): ()
	table.clear(State.Buttons)
	State.ButtonsRoot = nil
end

local function NotifyBallRequired(): ()
	local Now: number = os.clock()
	if Now - LastBallRequiredNotificationAt < BALL_REQUIRED_NOTIFICATION_COOLDOWN then
		return
	end
	LastBallRequiredNotificationAt = Now
	NotificationController.NotifyWarning(
		BALL_REQUIRED_NOTIFICATION_TITLE,
		BALL_REQUIRED_NOTIFICATION_MESSAGE,
		BALL_REQUIRED_NOTIFICATION_DURATION
	)
end

local function GetStyleId(): string
	local SelectedSlot: number = PlayerDataGuard.GetOrDefault(LocalPlayer, {"SelectedSlot"}, ONE)
	local Slots: {[string]: string} = PlayerDataGuard.GetOrDefault(LocalPlayer, {"StyleSlots"}, {})
	return SkillsData.ResolveStyleFromSlots(SelectedSlot, Slots)
end

local function GetSkillList(): {SkillDefinition}?
	local StyleId: string = GetStyleId()
	return SkillsData.GetSkillList(StyleId, State.AwakenActive)
end

local function GetSkillInputBehavior(Skill: SkillDefinition?): SkillInputBehavior
	return SkillsData.GetSkillInputBehavior(Skill)
end

local function GetAwakenCutsceneDuration(): number
	local StyleId: string = GetStyleId()
	return math.max(SkillsData.GetAwakenCutsceneDuration(StyleId), ZERO)
end

local function IsSlotVisible(SlotIndex: number, SkillList: {SkillDefinition}?): boolean
	if SlotIndex == THREE then
		return State.AwakenActive and SkillList ~= nil and #SkillList > TWO
	end
	return SlotIndex >= INPUT_SLOTS_MIN and SlotIndex <= TWO
end

local function GetButtonLabel(Button: GuiButton): LabelLike?
	if Button:IsA("TextButton") then
		return Button :: TextButton
	end
	local DirectText: Instance? = Button:FindFirstChild("TextLabel")
	if DirectText and DirectText:IsA("TextLabel") then
		return DirectText
	end
	local DirectLabel: Instance? = Button:FindFirstChild("Label")
	if DirectLabel and DirectLabel:IsA("TextLabel") then
		return DirectLabel
	end
	local NameLabel: Instance? = Button:FindFirstChild("Name")
	if NameLabel and NameLabel:IsA("TextLabel") then
		return NameLabel
	end
	local AnyLabel: TextLabel? = Button:FindFirstChildWhichIsA("TextLabel")
	return AnyLabel
end

local function TrackButton(SlotIndex: number, Button: GuiButton): ()
	local Label: LabelLike? = GetButtonLabel(Button)
	local Text: string = Label and Label.Text or ""
	State.Buttons[SlotIndex] = {
		Button = Button,
		Label = Label,
		OriginalText = Text,
		OriginalActive = Button.Active,
		OriginalAutoColor = Button.AutoButtonColor,
	}
end

local function ResolveButtons(): ()
	if HasValidButtons() and next(State.Buttons) ~= nil then
		return
	end
	ClearButtonReferences()

	local PlayerGuiInstance: PlayerGui? = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not PlayerGuiInstance then
		return
	end
	local GameGui: ScreenGui? = PlayerGuiInstance:FindFirstChild("GameGui") :: ScreenGui?
	if not GameGui then
		return
	end
	local Main: Instance? = GameGui:FindFirstChild("Main")
	if not Main then
		return
	end
	local Frame: Instance? = Main:FindFirstChild("Frame")
	if not Frame then
		return
	end
	local Buttons: Instance? = Frame:FindFirstChild("Buttons")
	if not Buttons then
		return
	end
	if Buttons:IsA("GuiObject") then
		State.ButtonsRoot = Buttons
	end
	for Index = INPUT_SLOTS_MIN, INPUT_SLOTS_MAX do
		local Name: string = "Slot" .. tostring(Index)
		local Found: Instance? = Buttons:FindFirstChild(Name)
		if Found and Found:IsA("GuiButton") then
			TrackButton(Index, Found)
		end
	end
end

local function ResolveAwakenBar(): ()
	if HasValidAwakenBar() then
		return
	end
	State.FillAwaken = nil
	State.AwakenFillSize = nil
	State.AwakenBar = nil
	State.AwakenOffset = nil

	local PlayerGuiInstance: PlayerGui? = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not PlayerGuiInstance then
		return
	end
	local GameGui: ScreenGui? = PlayerGuiInstance:FindFirstChild("GameGui") :: ScreenGui?
	if not GameGui then
		return
	end
	local Main: Instance? = GameGui:FindFirstChild("Main")
	if not Main then
		return
	end
	local Frame: Instance? = Main:FindFirstChild("Frame")
	if not Frame then
		return
	end
	
	local FillAwakenRoot: Instance? = Frame:FindFirstChild("FillAwaken")
	
	if not FillAwakenRoot then
		return
	end
	
	local FillFrame: Instance? = FillAwakenRoot:FindFirstChild("Fill") or FillAwakenRoot:FindFirstChild("Container")
	if not FillFrame then
		FillFrame = FillAwakenRoot:FindFirstChild("Fill", true)
	end

	local Adjust: Instance? = FillFrame and FillFrame:FindFirstChild("AdjustThisOffset", true) or nil
	if not Adjust then
		Adjust = FillAwakenRoot:FindFirstChild("AdjustThisOffset", true)
	end

	if FillFrame and FillFrame:IsA("GuiObject") and Adjust then
		State.FillAwaken = FillFrame
		State.AwakenFillSize = FillFrame.Size
		State.AwakenBar = FillAwakenRoot
		State.AwakenOffset = Adjust
	end
end

local function StopAwakenFillTween(): ()
	if State.AwakenFillTween then
		State.AwakenFillTween:Cancel()
		State.AwakenFillTween = nil
	end
end

local function StopAwakenOffsetTween(): ()
	if State.AwakenOffsetTween then
		State.AwakenOffsetTween:Cancel()
		State.AwakenOffsetTween = nil
	end
end

local function GetAwakenFillSize(Scale: number): UDim2
	local BaseSize: UDim2 = State.AwakenFillSize or UDim2.new(ONE, ZERO, ONE, ZERO)
	return UDim2.new(
		BaseSize.X.Scale * Scale,
		math.round(BaseSize.X.Offset * Scale),
		BaseSize.Y.Scale,
		BaseSize.Y.Offset
	)
end

local function SetAwakenFillScale(Scale: number): ()
	local FillFrame: Instance? = State.FillAwaken
	if not FillFrame or not FillFrame:IsA("GuiObject") then
		return
	end
	StopAwakenFillTween()
	FillFrame.Size = GetAwakenFillSize(Scale)
end

local function SetAwakenOffset(Value: Vector2): ()
	local Target: Instance? = State.AwakenOffset
	if not Target then
		return
	end
	StopAwakenOffsetTween()
	pcall(function()
		(Target :: any).Offset = Value
	end)
end

local function TweenAwakenOffset(Value: Vector2, Duration: number): ()
	local Target: Instance? = State.AwakenOffset
	if not Target then
		return
	end
	if Duration <= ZERO then
		SetAwakenOffset(Value)
		return
	end
	StopAwakenOffsetTween()
	local Success: boolean, TweenInstance: Tween? = pcall(function()
		local TweenInfoInstance: TweenInfo = TweenInfo.new(Duration, OFFSET_EASE_STYLE, OFFSET_EASE_DIR)
		return TweenService:Create(Target, TweenInfoInstance, {Offset = Value})
	end)
	if not Success or not TweenInstance then
		SetAwakenOffset(Value)
		return
	end
	State.AwakenOffsetTween = TweenInstance
	TweenInstance:Play()
	TweenInstance.Completed:Connect(function()
		if State.AwakenOffsetTween == TweenInstance then
			State.AwakenOffsetTween = nil
		end
	end)
end

local function SetBarVisible(Visible: boolean): ()
	local Bar: GuiObject? = State.AwakenBar
	if Bar then
		Bar.Visible = Visible
	end
	State.AwakenBarVisible = Visible
end

local function HasAwakenAttributes(): boolean
	if State.AwakenReady or State.AwakenActive then
		return true
	end
	if LocalPlayer:GetAttribute(ATTR_AWAKEN_READY) == true then
		return true
	end
	if LocalPlayer:GetAttribute(ATTR_AWAKEN_ACTIVE) == true then
		return true
	end
	local Character: Model? = LocalPlayer.Character
	if Character then
		if Character:GetAttribute(ATTR_AWAKEN_READY) == true then
			return true
		end
		if Character:GetAttribute(ATTR_AWAKEN_ACTIVE) == true then
			return true
		end
	end
	return false
end

local function IsAwakenCutsceneActive(): boolean
	if LocalPlayer:GetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE) == true then
		return true
	end
	local Character: Model? = LocalPlayer.Character
	return Character ~= nil and Character:GetAttribute(ATTR_AWAKEN_CUTSCENE_ACTIVE) == true
end

local function IsCutsceneHudHidden(): boolean
	if LocalPlayer:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true then
		return true
	end
	local Character: Model? = LocalPlayer.Character
	return Character ~= nil and Character:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true
end

local function SyncAwakenBarVisibility(): ()
	ResolveAwakenBar()
	local Visible: boolean = HasAwakenAttributes() and not IsCutsceneHudHidden()

	if HasValidAwakenBar() then
		if HasAwakenAttributes() then
			SetAwakenFillScale(FULL_SCALE)
		end
		if State.AwakenActive and State.AwakenCountdownEndsAt > State.AwakenCountdownBeginsAt then
			local Now: number = os.clock()
			if Now <= State.AwakenCountdownBeginsAt then
				SetAwakenOffset(OFFSET_VISIBLE)
			elseif Now >= State.AwakenCountdownEndsAt then
				SetAwakenOffset(OFFSET_EMPTY)
			else
				local CountdownDuration: number = State.AwakenCountdownEndsAt - State.AwakenCountdownBeginsAt
				local RemainingDuration: number = math.max(State.AwakenCountdownEndsAt - Now, ZERO)
				local RemainingAlpha: number = math.clamp(RemainingDuration / CountdownDuration, ZERO, ONE)
				SetAwakenOffset(Vector2.new(RemainingAlpha, ZERO))
				TweenAwakenOffset(OFFSET_EMPTY, RemainingDuration)
			end
		elseif HasAwakenAttributes() then
			SetAwakenOffset(OFFSET_VISIBLE)
		else
			SetAwakenOffset(OFFSET_EMPTY)
		end
	end

	SetBarVisible(Visible)
end

local function HasBlockedSkillHudAttributes(): boolean
	if IsCutsceneHudHidden() then
		return true
	end
	if LocalPlayer:GetAttribute(ATTR_MATCH_CUTSCENE_LOCKED) == true then
		return true
	end
	if LocalPlayer:GetAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED) == true then
		return true
	end
	local Character: Model? = LocalPlayer.Character
	if Character and Character:GetAttribute(ATTR_MATCH_CUTSCENE_LOCKED) == true then
		return true
	end
	if Character and Character:GetAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED) == true then
		return true
	end
	return false
end

local function SyncSkillBarVisibility(): ()
	ResolveButtons()
	local ButtonsRoot: GuiObject? = State.ButtonsRoot
	if not ButtonsRoot then
		return
	end
	ButtonsRoot.Visible = not HasBlockedSkillHudAttributes()
end

local function AnimateFill(Scale: number, Duration: number): ()
	local FillFrame: Instance? = State.FillAwaken
	if not FillFrame or not FillFrame:IsA("GuiObject") then
		return
	end
	StopAwakenFillTween()
	local TweenInfoInstance: TweenInfo = TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local TweenInstance: Tween = TweenService:Create(FillFrame, TweenInfoInstance, {
		Size = GetAwakenFillSize(Scale),
	})
	State.AwakenFillTween = TweenInstance
	TweenInstance.Completed:Connect(function()
		if State.AwakenFillTween == TweenInstance then
			State.AwakenFillTween = nil
		end
	end)
	TweenInstance:Play()
end

local function ResetAwakenOffset(): ()
	State.AwakenOffsetToken += ONE
	StopAwakenOffsetTween()
end

local function ResetAwakenCountdownWindow(): ()
	State.AwakenCountdownBeginsAt = ZERO
	State.AwakenCountdownEndsAt = ZERO
end

local function StartAwakenOffsetCountdown(Duration: number, CutsceneDuration: number): ()
	State.AwakenOffsetToken += ONE
	local Token: number = State.AwakenOffsetToken
	SetAwakenOffset(OFFSET_VISIBLE)
	local ActiveDuration: number = math.max(Duration, ZERO)
	local CountdownDelay: number = math.max(CutsceneDuration, ZERO)
	local CountdownStartAt: number = os.clock() + CountdownDelay
	State.AwakenCountdownBeginsAt = CountdownStartAt
	State.AwakenCountdownEndsAt = CountdownStartAt + ActiveDuration
	task.delay(CountdownDelay, function()
		if State.AwakenOffsetToken ~= Token then
			return
		end
		if not State.AwakenActive then
			return
		end
		local RemainingDuration: number = math.max(State.AwakenCountdownEndsAt - os.clock(), ZERO)
		if RemainingDuration <= ZERO then
			SetAwakenOffset(OFFSET_EMPTY)
			return
		end
		TweenAwakenOffset(OFFSET_EMPTY, RemainingDuration)
	end)
end

local UpdateSkillButtons: () -> ()

local function HandleAwakenCutsceneActiveChanged(): ()
	State.AwakenCutsceneObserved = IsAwakenCutsceneActive()
	UpdateSkillButtons()
end

local function ClearCooldownVisual(SlotIndex: number): ()
	local ButtonStateData: ButtonState? = State.Buttons[SlotIndex]
	if not ButtonStateData then
		return
	end
	ButtonStateData.Button.Active = ButtonStateData.OriginalActive
	ButtonStateData.Button.AutoButtonColor = ButtonStateData.OriginalAutoColor
	if ButtonStateData.Label then
		ButtonStateData.Label.Text = ButtonStateData.OriginalText
	end
end

local function ClearAllCooldowns(): ()
	CooldownTracker:ClearAll(INPUT_SLOTS_MIN, INPUT_SLOTS_MAX)
	for Index = INPUT_SLOTS_MIN, INPUT_SLOTS_MAX do
		ClearCooldownVisual(Index)
	end
end

function UpdateSkillButtons(): ()
	SyncAwakenBarVisibility()
	SyncSkillBarVisibility()
	local SkillList: {SkillDefinition}? = GetSkillList()
	local SkillHudBlocked: boolean = HasBlockedSkillHudAttributes()
	for Index = INPUT_SLOTS_MIN, INPUT_SLOTS_MAX do
		local ButtonStateData: ButtonState? = State.Buttons[Index]
		if ButtonStateData then
			local Visible: boolean = IsSlotVisible(Index, SkillList) and not SkillHudBlocked
			ButtonStateData.Button.Visible = Visible
			local Label: LabelLike? = ButtonStateData.Label
			if Label and Visible then
				if SkillList and SkillList[Index] then
					Label.Text = SkillList[Index].Name
				else
					Label.Text = "Empty"
				end
				ButtonStateData.OriginalText = Label.Text
			end
		end
	end
end

local function IsSlotOnCooldown(SlotIndex: number): boolean
	return CooldownTracker:IsOnCooldown(SlotIndex)
end

local function FireSkillRequest(SlotIndex: number, AimTarget: Vector3): ()
	Packets.SkillRequest:Fire(SlotIndex, AimTarget)
end

local function FireSkillHoldRequest(SlotIndex: number, ActionId: number, HoldDuration: number, AimTarget: Vector3): ()
	Packets.SkillHoldRequest:Fire(SlotIndex, ActionId, HoldDuration, AimTarget)
end

local function ResolveSkillAimTarget(SkillDefinition: SkillDefinition?): Vector3
	if SkillDefinition and SkillDefinition.Module == HIRUMA_THROW_MODULE_NAME then
		local MaxAimDistance: number = FlowBuffs.ApplyThrowDistanceBuff(LocalPlayer, FTConfig.THROW_CONFIG.MaxAimDistance)
		local ResolvedAimTarget: Vector3? = ThrowAimResolver.ResolveCurrentTarget(LocalPlayer, MaxAimDistance)
		if typeof(ResolvedAimTarget) == "Vector3" then
			return ResolvedAimTarget
		end
	end
	return EMPTY_AIM_TARGET
end

local function StartCooldownVisual(SlotIndex: number, Duration: number): ()
	local ButtonStateData: ButtonState? = State.Buttons[SlotIndex]
	if not ButtonStateData then
		return
	end
	ButtonStateData.Button.Active = false
	ButtonStateData.Button.AutoButtonColor = false
	CooldownTracker:Begin(
		SlotIndex,
		Duration,
		function(Remaining: number)
			if ButtonStateData.Label then
				local RemainingClamped: number = math.max(Remaining, ZERO)
				local Rounded: number = math.floor(RemainingClamped * COOLDOWN_DECIMAL_FACTOR) / COOLDOWN_DECIMAL_FACTOR
				ButtonStateData.Label.Text = string.format(COOLDOWN_TEXT_FORMAT, Rounded)
			end
		end,
		function()
			ClearCooldownVisual(SlotIndex)
		end
	)
end

local function HandleAwakenStatus(Status: string, Duration: number): ()
	if not State.AwakenBar or not State.FillAwaken then
		ResolveAwakenBar()
	end
	InputGate:Reset("awaken")
	if Status == AWAKEN_STATUS_READY then
		State.AwakenReady = true
		State.AwakenActive = false
		State.AwakenDuration = ZERO
		State.AwakenCountdownStarted = false
		ResetAwakenCountdownWindow()
		State.AwakenCutsceneObserved = false
		ResetAwakenOffset()
		SetAwakenFillScale(FULL_SCALE)
		SetAwakenOffset(OFFSET_VISIBLE)
		SetBarVisible(not IsCutsceneHudHidden())
		ClearAllCooldowns()
	elseif Status == AWAKEN_STATUS_START then
		State.AwakenReady = false
		State.AwakenActive = true
		State.AwakenDuration = Duration
		State.AwakenCountdownStarted = true
		State.AwakenCutsceneObserved = IsAwakenCutsceneActive()
		SetAwakenFillScale(FULL_SCALE)
		SetBarVisible(not IsCutsceneHudHidden())
		StartAwakenOffsetCountdown(Duration, GetAwakenCutsceneDuration())
		ClearAllCooldowns()
	elseif Status == AWAKEN_STATUS_END then
		State.AwakenReady = false
		State.AwakenActive = false
		State.AwakenDuration = ZERO
		State.AwakenCountdownStarted = false
		ResetAwakenCountdownWindow()
		State.AwakenCutsceneObserved = false
		ResetAwakenOffset()
		SetAwakenOffset(OFFSET_EMPTY)
		AnimateFill(EMPTY_SCALE, AWAKEN_HIDE_TIME)
		task.delay(AWAKEN_HIDE_TIME, function()
			if not State.AwakenActive and not State.AwakenReady then
				SetBarVisible(false)
			end
		end)
		ClearAllCooldowns()
	end
	UpdateSkillButtons()
end

local function HandleInput(Input: InputObject, GameProcessed: boolean): ()
	if GameProcessed then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if Input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local Mapping: {[Enum.KeyCode]: number} = SkillsData.GetInputMapping()
	local SlotIndex: number? = Mapping[Input.KeyCode]
	if SlotIndex then
		local SkillList: {SkillDefinition}? = GetSkillList()
		if not IsSlotVisible(SlotIndex, SkillList) then
			return
		end
		if not SkillClientGuard.CanUseSkill(LocalPlayer) then
			return
		end
		if IsSlotOnCooldown(SlotIndex) then
			return
		end
		local SkillDefinition: SkillDefinition? = SkillList and SkillList[SlotIndex] or nil
		if SkillDefinition == nil then
			return
		end
		if SkillsData.BlocksWhenHoldingBall(SkillDefinition) and SkillClientGuard.IsHoldingBall(LocalPlayer) then
			return
		end
		if SkillsData.RequiresBall(SkillDefinition) and not SkillClientGuard.IsHoldingBall(LocalPlayer) then
			NotifyBallRequired()
			return
		end
		local GateKey: string = "skill_" .. tostring(SlotIndex)
		if not InputGate:TryAcquire(GateKey, INPUT_DEBOUNCE_WINDOW) then
			return
		end
		local InputBehavior: SkillInputBehavior = GetSkillInputBehavior(SkillDefinition)
		local AimTarget: Vector3 = ResolveSkillAimTarget(SkillDefinition)
		if InputBehavior.Mode == HOLD_INPUT_MODE then
			if State.HeldSkills[SlotIndex] then
				return
			end
			State.HeldSkills[SlotIndex] = {
				StartedAt = os.clock(),
			}
			FireSkillHoldRequest(SlotIndex, SKILL_HOLD_ACTION_BEGIN, ZERO, AimTarget)
			return
		end
		FireSkillRequest(SlotIndex, AimTarget)
		return
	end
	if Input.KeyCode == SkillsData.GetAwakenKey() then
		if not SkillClientGuard.CanUseSkill(LocalPlayer) then
			return
		end
		if not SkillClientGuard.IsHoldingBall(LocalPlayer) then
			NotifyBallRequired()
			return
		end
		if not SkillClientGuard.CanUseAwaken(LocalPlayer) then
			return
		end
		if not InputGate:TryAcquire("awaken", AWAKEN_INPUT_DEBOUNCE_WINDOW) then
			return
		end
		Packets.AwakenRequest:Fire()
	end
end

local function HandleInputEnded(Input: InputObject, _GameProcessed: boolean): ()
	if Input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local Mapping: {[Enum.KeyCode]: number} = SkillsData.GetInputMapping()
	local SlotIndex: number? = Mapping[Input.KeyCode]
	if not SlotIndex then
		return
	end
	local HeldSkill: HeldSkillState? = State.HeldSkills[SlotIndex]
	if not HeldSkill then
		return
	end

	State.HeldSkills[SlotIndex] = nil
	local HoldDuration: number = math.max(os.clock() - HeldSkill.StartedAt, ZERO)
	FireSkillHoldRequest(SlotIndex, SKILL_HOLD_ACTION_RELEASE, HoldDuration, EMPTY_AIM_TARGET)
end

local function BindPlayerDataSignals(): ()
	PlayerDataGuard.ConnectValueChanged(LocalPlayer, {"SelectedSlot"}, function()
		UpdateSkillButtons()
	end, {
		RetryDelay = ONE,
		OnConnected = UpdateSkillButtons,
	})
	for Index = INPUT_SLOTS_MIN, STYLE_SLOTS_MAX do
		local SlotKey: string = SLOT_PREFIX .. tostring(Index)
		PlayerDataGuard.ConnectValueChanged(LocalPlayer, {"StyleSlots", SlotKey}, function()
			UpdateSkillButtons()
		end, {
			RetryDelay = ONE,
			OnConnected = UpdateSkillButtons,
		})
	end
end

function FTSkillController.Init(_self: typeof(FTSkillController)): ()
	ResolveButtons()
	ResolveAwakenBar()
	task.spawn(function()
		SkillAssetPreloader.PreloadAll()
	end)
end

function FTSkillController.Start(_self: typeof(FTSkillController)): ()
	local PlayerGuiInstance: PlayerGui =
		(LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")) :: PlayerGui
	table.clear(State.HeldSkills)
	ResolveButtons()
	ResolveAwakenBar()
	State.AwakenCutsceneObserved = IsAwakenCutsceneActive()
	UpdateSkillButtons()
	SyncAwakenBarVisibility()
	task.spawn(function()
		SkillAssetPreloader.PreloadForCharacter(LocalPlayer.Character)
	end)
	local function RefreshHudReferencesIfNeeded(InstanceItem: Instance): ()
		if not HUD_REFERENCE_NAMES[InstanceItem.Name] then
			return
		end
		task.defer(function()
			ResolveButtons()
			ResolveAwakenBar()
			UpdateSkillButtons()
		end)
	end
	PlayerGuiInstance.ChildAdded:Connect(RefreshHudReferencesIfNeeded)
	PlayerGuiInstance.DescendantAdded:Connect(RefreshHudReferencesIfNeeded)
	UserInputService.InputBegan:Connect(HandleInput)
	UserInputService.InputEnded:Connect(HandleInputEnded)
	Packets.AwakenStatus.OnClientEvent:Connect(HandleAwakenStatus)
	Packets.SkillCooldown.OnClientEvent:Connect(function(SlotIndex: number, Duration: number)
		if SlotIndex < INPUT_SLOTS_MIN or SlotIndex > INPUT_SLOTS_MAX then
			return
		end
		StartCooldownVisual(SlotIndex, Duration)
	end)
	BindPlayerDataSignals()
	LocalPlayer:GetAttributeChangedSignal(ATTR_AWAKEN_READY):Connect(SyncAwakenBarVisibility)
	LocalPlayer:GetAttributeChangedSignal(ATTR_AWAKEN_ACTIVE):Connect(SyncAwakenBarVisibility)
	LocalPlayer:GetAttributeChangedSignal(ATTR_INVULNERABLE):Connect(UpdateSkillButtons)
	LocalPlayer:GetAttributeChangedSignal(ATTR_SKILL_LOCKED):Connect(UpdateSkillButtons)
	LocalPlayer:GetAttributeChangedSignal(ATTR_MATCH_CUTSCENE_LOCKED):Connect(UpdateSkillButtons)
	LocalPlayer:GetAttributeChangedSignal(ATTR_PERFECT_PASS_CUTSCENE_LOCKED):Connect(UpdateSkillButtons)
	LocalPlayer:GetAttributeChangedSignal(ATTR_AWAKEN_CUTSCENE_ACTIVE):Connect(HandleAwakenCutsceneActiveChanged)
	LocalPlayer:GetAttributeChangedSignal(ATTR_CUTSCENE_HUD_HIDDEN):Connect(HandleAwakenCutsceneActiveChanged)
	LocalPlayer.CharacterAdded:Connect(function(Character: Model)
		table.clear(State.HeldSkills)
		task.spawn(function()
			SkillAssetPreloader.PreloadForCharacter(Character)
		end)
		Character:GetAttributeChangedSignal(ATTR_AWAKEN_READY):Connect(SyncAwakenBarVisibility)
		Character:GetAttributeChangedSignal(ATTR_AWAKEN_ACTIVE):Connect(SyncAwakenBarVisibility)
		Character:GetAttributeChangedSignal(ATTR_INVULNERABLE):Connect(UpdateSkillButtons)
		Character:GetAttributeChangedSignal(ATTR_SKILL_LOCKED):Connect(UpdateSkillButtons)
		Character:GetAttributeChangedSignal(ATTR_MATCH_CUTSCENE_LOCKED):Connect(UpdateSkillButtons)
		Character:GetAttributeChangedSignal(ATTR_PERFECT_PASS_CUTSCENE_LOCKED):Connect(UpdateSkillButtons)
		Character:GetAttributeChangedSignal(ATTR_AWAKEN_CUTSCENE_ACTIVE):Connect(HandleAwakenCutsceneActiveChanged)
		Character:GetAttributeChangedSignal(ATTR_CUTSCENE_HUD_HIDDEN):Connect(HandleAwakenCutsceneActiveChanged)
		State.AwakenCutsceneObserved = IsAwakenCutsceneActive()
		SyncAwakenBarVisibility()
		UpdateSkillButtons()
	end)
	if LocalPlayer.Character then
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_AWAKEN_READY):Connect(SyncAwakenBarVisibility)
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_AWAKEN_ACTIVE):Connect(SyncAwakenBarVisibility)
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_INVULNERABLE):Connect(UpdateSkillButtons)
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_SKILL_LOCKED):Connect(UpdateSkillButtons)
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_MATCH_CUTSCENE_LOCKED):Connect(UpdateSkillButtons)
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_PERFECT_PASS_CUTSCENE_LOCKED):Connect(UpdateSkillButtons)
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_AWAKEN_CUTSCENE_ACTIVE):Connect(HandleAwakenCutsceneActiveChanged)
		LocalPlayer.Character:GetAttributeChangedSignal(ATTR_CUTSCENE_HUD_HIDDEN):Connect(HandleAwakenCutsceneActiveChanged)
		State.AwakenCutsceneObserved = IsAwakenCutsceneActive()
	end
end

return FTSkillController
