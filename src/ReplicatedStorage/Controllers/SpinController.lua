
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local WalkSpeedController = require(ReplicatedStorage.Controllers.WalkSpeedController)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local FOVController = require(ReplicatedStorage.Controllers.FOVController)
local CountdownController = require(ReplicatedStorage.Controllers.CountdownController)
local WindVFXController = require(ReplicatedStorage.Controllers.WindVFXController)

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local HighlightEffect = require(ReplicatedStorage.Modules.Game.HighlightEffect)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)

local FTSpinController = {}

--\ CONSTANTS \-- TR
local STAMINA_BAR_TWEEN_INFO: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local STAMINA_VISIBILITY_TWEEN_INFO: TweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local STAMINA_HIDE_DELAY: number = 0.9
local STAMINA_ACTIVITY_EPSILON: number = 0.01
local SPIN_COOLDOWN: number = 0.5
local SPIN_THROW_LOCK_EXTRA: number = 0
local ATTR_CAN_SPIN = "FTCanSpin"
local ATTR_CAN_THROW = "FTCanThrow"
local ATTR_STUNNED = "FTStunned"
local ATTR_CAN_ACT = "FTCanAct"
local ATTR_SKILL_LOCKED = "FTSkillLocked"
local ATTR_CUTSCENE_HUD_HIDDEN = "FTCutsceneHudHidden"
local ATTR_RESUME_RUN = "FTResumeRun"
local ATTR_RUN_DEBUG = "FTRunDebug"
local SPIN_HIGHLIGHT_COLOR: Color3 = Color3.fromRGB(0, 150, 255)
local STAMINA_FILL_COLOR: Color3 = Color3.fromRGB(0, 170, 255)
local WALK_SPEED: number = 16
local RUN_SPEED: number = 24
local RUN_KEY_PRIMARY: Enum.KeyCode = Enum.KeyCode.LeftControl
local RUN_KEY_SECONDARY: Enum.KeyCode = Enum.KeyCode.RightControl
local RUN_CHECK_INTERVAL: number = 0
local RUN_TOGGLE_DEBOUNCE: number = 0.08
local MIN_STAMINA_TO_RUN: number = FTConfig.TACKLE_CONFIG.MinStaminaToRun or 5
local RUN_LINES_INTERVAL: number = 0.06
local RUN_FOV_INCREASE: number = 10
local RUN_FOV_MAX: number = 95
local RUN_FOV_TWEEN_INFO: TweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local MOVEMENT_FACTOR_DEADZONE: number = 0.05
local BASE_FOV_FALLBACK: number = 70
local RUN_FOV_REQUEST_ID: string = "SpinController::Run"
local RUN_WIND_REQUEST_ID: string = "SpinController::RunWind"
local RUN_DEBUG_DEFAULT: boolean = RunService:IsStudio()
local Assets = ReplicatedStorage:FindFirstChild("Assets"):FindFirstChild("Gameplay"):FindFirstChild("Modelo")
local LEAVE_ACTION_NAME = "FTLeaveMatch"
local CHARGE_ATTRIBUTE = "FTChargingThrow"

-- Name of the attribute used to mark players invulnerable.  When
-- `Invulnerable` is true, the local player should not be able to spin.
local INVULNERABLE_ATTR = "Invulnerable"

--\ MODULE STATE \-- TR
local LocalPlayer: Player = Players.LocalPlayer

local StaminaBillboard: BillboardGui? = nil
local StaminaFill: Frame? = nil
local StaminaFillGradient: UIGradient? = nil
local StaminaFillTween: Tween? = nil
local StaminaAttachment: Attachment? = nil
local CurrentStamina: number = FTConfig.STAMINA_CONFIG.MaxStamina
local StaminaVisibilityTween: Tween? = nil
local StaminaVisibilityDriver: NumberValue? = nil
local StaminaVisibilityConnection: RBXScriptConnection? = nil
local StaminaShouldBeVisible: boolean = false
local LastStaminaActivityAt: number = 0
local SpinAnimationTrack: AnimationTrack? = nil
local MatchStartedInstance: BoolValue? = nil
local Connections: {RBXScriptConnection} = {}
local IsSpinning: boolean = false
local IsRunning: boolean = false
local MovementLocked: boolean = false
local NextSpinAnimationIndex: number = 1
local SpinHighlight: Highlight? = nil
local SpinHighlightToken: number = 0
local LastAppliedSpeed: number = WALK_SPEED
local LastRunningReported: boolean = false
local LastRunCheck: number = 0
local LastRunLines: number = 0
local LastRunPosition: Vector3? = nil
local LastVFXDebug: number = 0
local RunIntent: boolean = false
local PendingResumeRun: boolean = false
local BaseCameraFOV: number = BASE_FOV_FALLBACK
local LastFOVTarget: number = BASE_FOV_FALLBACK
local RunFOVTween: Tween? = nil
local RunFOVEnabled: boolean = false
local LastRunToggleAt: number = 0
local LastPolledRunKeyDown: boolean = false
local AttemptRunToggleFromKey: (source: string, keyName: string, GameProcessed: boolean?) -> ()
local UpdateRunCameraEffects: (Humanoid?, Model?, BasePart?) -> () = function() end
local GetMatchStarted: () -> boolean
local IsLocalPlayerInMatch: () -> boolean
local LastRunDebugMessage: string = ""
local HudGradient: UIGradient? = nil
local HudGradientColorTween: Tween? = nil
local HudGradientRotationTween: Tween? = nil
local HudGradientColorAnimating: boolean = false
local HudGradientRotationActive: boolean = false
local HudGradientColorDriver: NumberValue? = nil
local HudGradientColorConn: RBXScriptConnection? = nil
local HUD_COLOR_WHITE = Color3.new(1, 1, 1)
local HUD_COLOR_RED = Color3.fromRGB(255, 0, 0)
local HIGHLIGHT_KEY_SPIN = "Spin"

type TransparencyBinding = {
	Instance: Instance,
	Property: string,
	VisibleValue: number,
}

local StaminaTransparencyBindings: {TransparencyBinding} = {}

--\ PRIVATE FUNCTIONS \-- TR
local function SetPlayerAttribute(attr: string, value: any): ()
    if LocalPlayer then
        LocalPlayer:SetAttribute(attr, value)
    end
    local Character = LocalPlayer.Character
    if Character then
        Character:SetAttribute(attr, value)
    end
end

local function IsMovementLocked(): boolean
    if WalkSpeedController and WalkSpeedController.HasActiveRequests then
        return WalkSpeedController.HasActiveRequests()
    end
    return false
end

local function IsRunDebugEnabled(): boolean
    local attr = LocalPlayer:GetAttribute(ATTR_RUN_DEBUG)
    if attr ~= nil then
        return attr == true
    end
    return RUN_DEBUG_DEFAULT
end

local function EmitRunDebug(reason: string, allowRepeat: boolean?): ()
    return
end

local function ApplyRunSpeed(targetSpeed: number)
    local Humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end
    local resolvedSpeed = FlowBuffs.ApplySpeedBuff(LocalPlayer, targetSpeed)
    local HasWalkSpeedRequest: boolean = false
    if WalkSpeedController and WalkSpeedController.SetDefaultWalkSpeed then
        WalkSpeedController.SetDefaultWalkSpeed(resolvedSpeed)
    end
    if WalkSpeedController and WalkSpeedController.HasActiveRequests then
        HasWalkSpeedRequest = WalkSpeedController.HasActiveRequests()
    end
    if LastAppliedSpeed ~= resolvedSpeed then
        LastAppliedSpeed = resolvedSpeed
    end
    if LocalPlayer and LocalPlayer:GetAttribute(CHARGE_ATTRIBUTE) == true then
        EmitRunDebug("ApplyRunSpeedBlocked:Charging")
        return
    end
    if HasWalkSpeedRequest then
        EmitRunDebug("ApplyRunSpeedBlocked:WalkSpeedRequest")
        return
    end
    Humanoid.WalkSpeed = resolvedSpeed
end

local function ResolveHudGradient(): ()
    if HudGradient and HudGradient.Parent then
        return
	end
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local hudGui = playerGui:FindFirstChild("HudGui")
	if not hudGui then return end
	local gradientFrame = hudGui:FindFirstChild("Gradient") :: GuiObject?
    if not gradientFrame then return end
    HudGradient = gradientFrame:FindFirstChildOfClass("UIGradient")
end

local function SetHudGradientColor(color: Color3): ()
    if not HudGradient then return end
    HudGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, color),
        ColorSequenceKeypoint.new(1, color),
    })
end

local function StopHudGradientColorAnimation(setFinalRed: boolean): ()
    HudGradientColorAnimating = false
    if HudGradientColorTween then
        HudGradientColorTween:Cancel()
        HudGradientColorTween = nil
    end
    if HudGradientColorConn then
        HudGradientColorConn:Disconnect()
        HudGradientColorConn = nil
    end
    if HudGradientColorDriver then
        HudGradientColorDriver:Destroy()
        HudGradientColorDriver = nil
    end
    if setFinalRed then
        SetHudGradientColor(HUD_COLOR_RED)
    end
end

local function StartHudGradientColorAnimation(): ()
    if not HudGradient or HudGradientColorAnimating then return end
    HudGradientColorAnimating = true
    StopHudGradientColorAnimation(false)
    HudGradientColorAnimating = true
    HudGradientColorDriver = Instance.new("NumberValue")
    HudGradientColorDriver.Value = 0
    HudGradientColorConn = HudGradientColorDriver.Changed:Connect(function(alpha)
        local clamped = math.clamp(alpha, 0, 1)
        local targetColor = HUD_COLOR_WHITE:Lerp(HUD_COLOR_RED, clamped)
        SetHudGradientColor(targetColor)
    end)
    local toRed = true
    local function step()
        if not HudGradient or not HudGradientColorAnimating then return end
        if not HudGradientColorDriver then return end
        local tween = TweenService:Create(HudGradientColorDriver, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Value = toRed and 1 or 0,
        })
        HudGradientColorTween = tween
        tween.Completed:Once(function()
            if not HudGradientColorAnimating then return end
            toRed = not toRed
            step()
        end)
        tween:Play()
    end
    step()
end

local function StopHudGradientRotation(): ()
    HudGradientRotationActive = false
    if HudGradientRotationTween then
        HudGradientRotationTween:Cancel()
        HudGradientRotationTween = nil
    end
end

local function StartHudGradientRotation(): ()
    if not HudGradient or HudGradientRotationActive then return end
    HudGradientRotationActive = true
    local directionUp = true
    local function step()
        if not HudGradient or not HudGradientRotationActive then return end
        local target = directionUp and 90 or 80
        local tween = TweenService:Create(HudGradient, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Rotation = target,
        })
        HudGradientRotationTween = tween
        tween.Completed:Once(function()
            if not HudGradientRotationActive then return end
            directionUp = not directionUp
            step()
        end)
        tween:Play()
    end
    step()
end

local function HandleCountdownVisuals(active: boolean): ()
    if not HudGradient or not HudGradient.Parent then
        ResolveHudGradient()
    end
    if not HudGradient then return end
    if active then
        StartHudGradientColorAnimation()
    else
        StopHudGradientColorAnimation(true)
    end
    StartHudGradientRotation()
end

local function TriggerSpinHighlight(Duration: number): ()
    local Character = LocalPlayer.Character
    if not Character then return end
    SpinHighlight = HighlightEffect.EnsureHighlight(HIGHLIGHT_KEY_SPIN, {
        Parent = Character,
        Name = "SpinHighlight",
        FillColor = SPIN_HIGHLIGHT_COLOR,
        OutlineColor = SPIN_HIGHLIGHT_COLOR,
        FillTransparency = 0.5,
        OutlineTransparency = 0.5,
    })
    if not SpinHighlight then return end
    SpinHighlightToken += 1
    local token = SpinHighlightToken
    HighlightEffect.SetHighlightMode(HIGHLIGHT_KEY_SPIN, "off")
    SpinHighlight.FillColor = SPIN_HIGHLIGHT_COLOR
    SpinHighlight.OutlineColor = SPIN_HIGHLIGHT_COLOR
    SpinHighlight.FillTransparency = 0.5
    SpinHighlight.OutlineTransparency = 0.5
    SpinHighlight.Enabled = true
    local tween = TweenService:Create(SpinHighlight, TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        FillTransparency = 1,
        OutlineTransparency = 1,
    })
    tween:Play()
    tween.Completed:Once(function()
        if SpinHighlight and SpinHighlightToken == token then
            HighlightEffect.ClearHighlight(HIGHLIGHT_KEY_SPIN)
            SpinHighlight = nil
        end
    end)
end

GetMatchStarted = function(): boolean
    if not MatchStartedInstance then
        local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
        if GameStateFolder then
            MatchStartedInstance = GameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
        end
    end
    return if MatchStartedInstance then MatchStartedInstance.Value else false
end

IsLocalPlayerInMatch = function(): boolean
    return MatchPlayerUtils.IsPlayerActive(LocalPlayer)
end

-- Determine if the local player is allowed to act (e.g. spin).  We
-- prohibit actions if the match isn't running, the player isn't in
-- the match, or the player has been marked invulnerable by the
-- server.  This check is used to gate client‑side spin input.
local function CanPlayerAct(): boolean
    if not GetMatchStarted() then return false end
    if not IsLocalPlayerInMatch() then return false end
    -- If the server has marked us invulnerable, we cannot act
    if LocalPlayer:GetAttribute(INVULNERABLE_ATTR) == true then return false end
    if LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true then return false end
    local character = LocalPlayer.Character
    if character and character:GetAttribute(INVULNERABLE_ATTR) == true then return false end
    if character and character:GetAttribute(ATTR_SKILL_LOCKED) == true then return false end
    return true
end

local function CanSpinNow(): boolean
    local Character = LocalPlayer.Character
    if Character then
        local value = Character:GetAttribute(ATTR_CAN_SPIN)
        if value ~= nil then
            return value == true
        end
    end
    local value = LocalPlayer:GetAttribute(ATTR_CAN_SPIN)
    if value ~= nil then
        return value == true
    end
    return true
end

local function HasEnoughStamina(): boolean
    local SpinCost: number = FlowBuffs.ApplyStaminaCostReduction(LocalPlayer, FTConfig.STAMINA_CONFIG.SpinStaminaCost)
    return CurrentStamina >= SpinCost
end

local function GetSpinDuration(): number
    return FTConfig.SPIN_CONFIG.SpinDuration + (FlowBuffs.GetDribbleBonus(LocalPlayer) * 0.01)
end

local function IsStunnedOrLocked(): boolean
    local Character = LocalPlayer.Character
    if Character and Character:GetAttribute(ATTR_STUNNED) == true then
        return true
    end
    if LocalPlayer:GetAttribute(ATTR_STUNNED) == true then
        return true
    end
	if Character and Character:GetAttribute(ATTR_CAN_ACT) == false then
		return true
	end
	if Character and Character:GetAttribute(ATTR_SKILL_LOCKED) == true then
		return true
	end
	if LocalPlayer:GetAttribute(ATTR_CAN_ACT) == false then
		return true
	end
	return LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true
end

local function ApplyStaminaFillMask(alpha: number): ()
    if not StaminaFillGradient then return end
    local clamped = math.clamp(alpha, 0, 1)
    if clamped <= 0 then
        StaminaFillGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
        return
    end
    local fadeStart = clamped
    local fadeEnd = math.clamp(clamped + 0.001, fadeStart, 1)
    StaminaFillGradient.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(fadeStart, 0),
        NumberSequenceKeypoint.new(fadeEnd, 1),
        NumberSequenceKeypoint.new(1, 1),
    })
end

local function ClearStaminaTransparencyState(): ()
	if StaminaVisibilityTween then
		StaminaVisibilityTween:Cancel()
		StaminaVisibilityTween = nil
	end
	if StaminaVisibilityConnection then
		StaminaVisibilityConnection:Disconnect()
		StaminaVisibilityConnection = nil
	end
	if StaminaVisibilityDriver then
		StaminaVisibilityDriver:Destroy()
		StaminaVisibilityDriver = nil
	end
	table.clear(StaminaTransparencyBindings)
	StaminaShouldBeVisible = false
end

local function TrackStaminaTransparency(Target: Instance, Property: string): ()
	local Success, Value = pcall(function()
		return (Target :: any)[Property]
	end)
	if not Success or type(Value) ~= "number" then
		return
	end
	table.insert(StaminaTransparencyBindings, {
		Instance = Target,
		Property = Property,
		VisibleValue = Value,
	})
end

local function BuildStaminaTransparencyBindings(Root: BillboardGui): ()
	ClearStaminaTransparencyState()
	TrackStaminaTransparency(Root, "BackgroundTransparency")
	for _, Descendant in Root:GetDescendants() do
		if Descendant:IsA("ImageLabel") or Descendant:IsA("ImageButton") then
			TrackStaminaTransparency(Descendant, "ImageTransparency")
			TrackStaminaTransparency(Descendant, "BackgroundTransparency")
		elseif Descendant:IsA("TextLabel") or Descendant:IsA("TextButton") then
			TrackStaminaTransparency(Descendant, "TextTransparency")
			TrackStaminaTransparency(Descendant, "BackgroundTransparency")
		elseif Descendant:IsA("Frame") then
			TrackStaminaTransparency(Descendant, "BackgroundTransparency")
		elseif Descendant:IsA("UIStroke") then
			TrackStaminaTransparency(Descendant, "Transparency")
		end
	end
	StaminaVisibilityDriver = Instance.new("NumberValue")
	StaminaVisibilityDriver.Name = "StaminaVisibilityDriver"
	StaminaVisibilityDriver.Value = 0
	StaminaVisibilityConnection = StaminaVisibilityDriver.Changed:Connect(function(Value: number)
		local Alpha: number = math.clamp(Value, 0, 1)
		for _, Binding in StaminaTransparencyBindings do
			if Binding.Instance.Parent == nil then
				continue
			end
			local HiddenValue: number = 1
			local TargetValue: number = HiddenValue + ((Binding.VisibleValue - HiddenValue) * Alpha)
			pcall(function()
				(Binding.Instance :: any)[Binding.Property] = TargetValue
			end)
		end
	end)
end

local function ShouldUseStaminaBillboard(): boolean
	if not StaminaBillboard then
		return false
	end
	local InMatch = IsLocalPlayerInMatch()
	local Character = LocalPlayer.Character
	local HudHidden = LocalPlayer:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true
		or (Character ~= nil and Character:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true)
	local CutsceneLocked = LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true
		or (Character ~= nil and Character:GetAttribute(ATTR_SKILL_LOCKED) == true)
	return InMatch and not CutsceneLocked and not HudHidden
end

local function ApplyStaminaBillboardVisibility(Visible: boolean, Immediate: boolean?): ()
	if not StaminaBillboard or not StaminaVisibilityDriver then
		return
	end
	local TargetValue: number = if Visible then 1 else 0
	if StaminaVisibilityTween then
		StaminaVisibilityTween:Cancel()
		StaminaVisibilityTween = nil
	end
	StaminaBillboard.Enabled = true
	if Immediate then
		StaminaVisibilityDriver.Value = TargetValue
		if not Visible then
			StaminaBillboard.Enabled = false
		end
		return
	end
	local TweenInstance: Tween = TweenService:Create(
		StaminaVisibilityDriver,
		STAMINA_VISIBILITY_TWEEN_INFO,
		{ Value = TargetValue }
	)
	StaminaVisibilityTween = TweenInstance
	TweenInstance.Completed:Connect(function()
		if StaminaVisibilityTween ~= TweenInstance then
			return
		end
		if not Visible and StaminaBillboard then
			StaminaBillboard.Enabled = false
		end
		StaminaVisibilityTween = nil
	end)
	TweenInstance:Play()
end

local function CreateStaminaBillboard(Character: Model): ()
    if StaminaBillboard then
        StaminaBillboard:Destroy()
        StaminaBillboard = nil
    end
    if StaminaAttachment then
        StaminaAttachment:Destroy()
        StaminaAttachment = nil
    end
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not HumanoidRootPart then return end
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    local UIFolder = if Assets then Assets:FindFirstChild("UI") else nil
    local BarFolder = if UIFolder then UIFolder:FindFirstChild("Bar2") else nil
    local BarAttachment = if BarFolder then BarFolder:FindFirstChild("Bar") else nil
    if not BarAttachment then return end
    local attachmentClone = BarAttachment:Clone()
    attachmentClone.Name = "StaminaBarAttachment"
    attachmentClone.Parent = HumanoidRootPart
    StaminaAttachment = attachmentClone
    local billboard = attachmentClone:FindFirstChildWhichIsA("BillboardGui", true)
    if not billboard then return end
    billboard.Adornee = HumanoidRootPart
    billboard.Enabled = false
    StaminaBillboard = billboard
    local barFrame = billboard:FindFirstChild("Bar", true) :: Frame?
    if not barFrame then return end
    local fill = barFrame:FindFirstChild("Fill") :: Frame?
    if not fill then return end
    fill.BackgroundColor3 = STAMINA_FILL_COLOR
    StaminaFill = fill
    local gradient = fill:FindFirstChildWhichIsA("UIGradient")
    gradient.Offset = Vector2.new(-1, 0)
    StaminaFillGradient = gradient
    BuildStaminaTransparencyBindings(billboard)
    ApplyStaminaFillMask(CurrentStamina / FTConfig.STAMINA_CONFIG.MaxStamina)
    ApplyStaminaBillboardVisibility(false, true)
end

local function UpdateStaminaBillboardVisibility(): ()
    if not StaminaBillboard then return end
    local CanDisplay: boolean = ShouldUseStaminaBillboard()
    local IsActive: boolean = CanDisplay and ((os.clock() - LastStaminaActivityAt) <= STAMINA_HIDE_DELAY)
    local NeedsCorrection: boolean =
        (IsActive and not StaminaBillboard.Enabled)
        or (not CanDisplay and StaminaBillboard.Enabled)
    if IsActive == StaminaShouldBeVisible and not NeedsCorrection then
        return
    end
    StaminaShouldBeVisible = IsActive
    ApplyStaminaBillboardVisibility(IsActive, not CanDisplay)
end

local function UpdateStaminaBarVisual(): ()
    if not StaminaFill then return end
    if not StaminaBillboard then return end
    local StaminaPercent = CurrentStamina / FTConfig.STAMINA_CONFIG.MaxStamina
    local clampedPercent = math.clamp(StaminaPercent, 0, 1)
    local targetOffset = Vector2.new(clampedPercent - 1, 0)
    ApplyStaminaFillMask(clampedPercent)
    if StaminaFillGradient then
        if StaminaFillTween then
            StaminaFillTween:Cancel()
            StaminaFillTween = nil
        end
        if clampedPercent <= 0 then
            StaminaFillGradient.Offset = targetOffset
            return
        end
        StaminaFillTween = TweenService:Create(StaminaFillGradient, STAMINA_BAR_TWEEN_INFO, { Offset = targetOffset })
        StaminaFillTween:Play()
    end
end

local function ReportRunningState(isRunning: boolean): ()
    if isRunning == LastRunningReported then
        return
    end
    LastRunningReported = isRunning
    if Packets and Packets.RunningStateUpdate and Packets.RunningStateUpdate.Fire then
        Packets.RunningStateUpdate:Fire(isRunning)
    end
end

local function ApplyRunState(isRunning: boolean): ()
    local PreviousRunning: boolean = IsRunning
    IsRunning = isRunning
    if not isRunning then
        LastRunPosition = nil
    end
    local targetSpeed = if isRunning then RUN_SPEED else WALK_SPEED
    ApplyRunSpeed(targetSpeed)
    ReportRunningState(isRunning and (CurrentStamina >= MIN_STAMINA_TO_RUN))
    if PreviousRunning ~= isRunning then
        EmitRunDebug(if isRunning then "ApplyRunState:Running" else "ApplyRunState:Walking")
    end
end

local function ForceStopRunning(clearIntent: boolean?, reason: string?): ()
    if clearIntent ~= false then
        RunIntent = false
        PendingResumeRun = false
    end
    ApplyRunState(false)
    WindVFXController:Release(RUN_WIND_REQUEST_ID)
    UpdateRunCameraEffects(nil, nil, nil)
    if reason then
        local IntentMode: string = if clearIntent ~= false then "clear-intent" else "preserve-intent"
        EmitRunDebug(string.format("ForceStop:%s:%s", reason, IntentMode))
    end
end

local function QueueResumeRun(): ()
    PendingResumeRun = true
    EmitRunDebug("QueueResumeRun")
end

local function UpdateStamina(Stamina: number): ()
    local PreviousStamina: number = CurrentStamina
    CurrentStamina = math.clamp(Stamina, 0, FTConfig.STAMINA_CONFIG.MaxStamina)
    if math.abs(CurrentStamina - PreviousStamina) > STAMINA_ACTIVITY_EPSILON then
        LastStaminaActivityAt = os.clock()
    end
    if CurrentStamina < MIN_STAMINA_TO_RUN then
        ForceStopRunning(true, "LowStamina")
    end
    UpdateStaminaBarVisual()
    UpdateStaminaBillboardVisibility()
end

local function UpdateRunningState(skipThrottle: boolean?): ()
    local now = os.clock()
    if not skipThrottle and now - LastRunCheck < RUN_CHECK_INTERVAL then
        return
    end
    LastRunCheck = now
    local Character = LocalPlayer.Character
    if not Character then
        ForceStopRunning(true, "NoCharacter")
        return
    end
    local inMatch = IsLocalPlayerInMatch()
    if inMatch and not GetMatchStarted() then
        ForceStopRunning(true, "MatchNotStarted")
        return
    end
    if IsStunnedOrLocked() then
        ForceStopRunning(false, "StunnedOrLocked")
        return
    end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not Humanoid or not root then
        ForceStopRunning(true, "MissingHumanoidOrRoot")
        return
    end
    MovementLocked = IsMovementLocked()
    if MovementLocked then
        ForceStopRunning(false, "MovementLocked")
        return
    end
    if IsRunning and (CurrentStamina <= 0 or CurrentStamina < MIN_STAMINA_TO_RUN) then
        ForceStopRunning(true, "RunningOutOfStamina")
        return
    end
    if PendingResumeRun then
        PendingResumeRun = false
        if CurrentStamina >= MIN_STAMINA_TO_RUN then
            RunIntent = true
        end
    end
    local shouldRun = RunIntent and not MovementLocked and (CurrentStamina >= MIN_STAMINA_TO_RUN)
    ApplyRunState(shouldRun)
end

local function GetFXFolder(): Instance
    return Workspace:FindFirstChild("FX") or Workspace
end

local function SetRunIntent(enabled: boolean): ()
    if RunIntent == enabled then
        EmitRunDebug(if enabled then "SetRunIntentIgnored:AlreadyEnabled" else "SetRunIntentIgnored:AlreadyDisabled", true)
        return
    end
    PendingResumeRun = false
    RunIntent = enabled
    EmitRunDebug(if enabled then "SetRunIntent:Enable" else "SetRunIntent:Disable")
    UpdateRunningState(true)
end

local function ToggleRunIntent(): ()
    SetRunIntent(not RunIntent)
end

local function IsRunToggleKey(Input: InputObject?): boolean
    if not Input or Input.UserInputType ~= Enum.UserInputType.Keyboard then
        return false
    end
    return Input.KeyCode == RUN_KEY_PRIMARY or Input.KeyCode == RUN_KEY_SECONDARY
end

local function IsRunToggleKeyDown(): boolean
    return UserInputService:IsKeyDown(RUN_KEY_PRIMARY) or UserInputService:IsKeyDown(RUN_KEY_SECONDARY)
end

local function TryToggleRun(source: string): ()
    EmitRunDebug(string.format("RunToggleAttempt:%s:target=%s", source, tostring(not RunIntent)), true)
    ToggleRunIntent()
end

AttemptRunToggleFromKey = function(source: string, keyName: string, GameProcessed: boolean?): ()
    EmitRunDebug(
        string.format(
            "RunKeyPressed:%s:gpe=%s:key=%s",
            source,
            tostring(GameProcessed == true),
            keyName
        ),
        true
    )
    if UserInputService:GetFocusedTextBox() then
        EmitRunDebug(string.format("RunKeyIgnored:%s:FocusedTextBox", source), true)
        return
    end
    local now = os.clock()
    if now - LastRunToggleAt < RUN_TOGGLE_DEBOUNCE then
        EmitRunDebug(string.format("RunKeyIgnored:%s:Debounce", source), true)
        return
    end
    LastRunToggleAt = now
    TryToggleRun(source)
end

local function ProcessRunToggleInput(
    source: string,
    Input: InputObject?,
    GameProcessed: boolean?,
    InputState: Enum.UserInputState?
): ()
    if InputState ~= nil and InputState ~= Enum.UserInputState.Begin then
        if IsRunToggleKey(Input) then
            EmitRunDebug(
                string.format("RunKeyIgnored:%s:InputState=%s", source, tostring(InputState)),
                true
            )
        end
        return
    end
    if not IsRunToggleKey(Input) then
        return
    end
    AttemptRunToggleFromKey(source, Input and Input.KeyCode.Name or "Unknown", GameProcessed)
end

local function HandleRunToggleInput(Input: InputObject, GameProcessed: boolean): ()
    ProcessRunToggleInput("InputBegan", Input, GameProcessed, Enum.UserInputState.Begin)
end

local function PollRunToggleInput(): ()
    local isDown: boolean = IsRunToggleKeyDown()
    if isDown == LastPolledRunKeyDown then
        return
    end
    LastPolledRunKeyDown = isDown
    EmitRunDebug(string.format("RunKeyStateChanged:Poll:down=%s", tostring(isDown)), true)
    if not isDown then
        return
    end
    if UserInputService:GetFocusedTextBox() then
        EmitRunDebug("RunKeyIgnored:Poll:FocusedTextBox", true)
        return
    end
    local now = os.clock()
    if now - LastRunToggleAt < RUN_TOGGLE_DEBOUNCE then
        EmitRunDebug("RunKeyIgnored:Poll:Debounce", true)
        return
    end
    LastRunToggleAt = now
    TryToggleRun("Poll")
end

local function HandleRunAction(_actionName: string, inputState: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
    ProcessRunToggleInput("ContextAction", input, false, inputState)
    return Enum.ContextActionResult.Pass
end

local function HandleLeaveMatchAction(_actionName: string, inputState: Enum.UserInputState, _input: InputObject): ()
    if inputState ~= Enum.UserInputState.Begin then
        return
    end
    if UserInputService:GetFocusedTextBox() then
        return
    end
    if not IsLocalPlayerInMatch() then
        return
    end
    if CountdownController and CountdownController.ForceCleanupVisuals then
        CountdownController.ForceCleanupVisuals()
    end
    if Packets and Packets.LeaveMatch and Packets.LeaveMatch.Fire then
        Packets.LeaveMatch:Fire()
    end
end

local function IsRunningOnGround(Humanoid: Humanoid?, Character: Model?, Root: BasePart?): boolean
    if not Humanoid or not Character or not Root then return false end
    if not IsRunning then return false end
    if Humanoid.FloorMaterial == Enum.Material.Air then return false end
    local planarSpeed = Vector2.new(Root.AssemblyLinearVelocity.X, Root.AssemblyLinearVelocity.Z).Magnitude
    local moveDirMag = Humanoid.MoveDirection.Magnitude
    if moveDirMag < 0.05 and planarSpeed < 2 then
        return false
    end
    return true
end

local function GetCamera(): Camera?
    return Workspace.CurrentCamera
end

local function CaptureBaseCameraFOV(): number
    local camera = GetCamera()
    if not camera then
        return BaseCameraFOV
    end
    BaseCameraFOV = camera.FieldOfView
    return BaseCameraFOV
end

local function StopRunFOVTween(): ()
    if RunFOVTween then
        RunFOVTween:Cancel()
        RunFOVTween = nil
    end
    FOVController.RemoveRequest(RUN_FOV_REQUEST_ID)
end

local function TweenCameraFOV(targetFov: number): ()
	local camera = GetCamera()
	if not camera then return end
	if math.abs(targetFov - LastFOVTarget) < 0.05 then
		return
	end
	StopRunFOVTween()
	LastFOVTarget = targetFov
	FOVController.AddRequest(RUN_FOV_REQUEST_ID, targetFov, nil, {
		TweenInfo = RUN_FOV_TWEEN_INFO,
	})
end

local function GetMovementFactor(Humanoid: Humanoid, Root: BasePart): number
    local planarSpeed = Vector2.new(Root.AssemblyLinearVelocity.X, Root.AssemblyLinearVelocity.Z).Magnitude
    local speedFactor = if Humanoid.WalkSpeed > 0 then planarSpeed / Humanoid.WalkSpeed else 0
    local dirFactor = Humanoid.MoveDirection.Magnitude
    local factor = math.max(speedFactor, dirFactor)
    if factor < MOVEMENT_FACTOR_DEADZONE then
        return 0
    end
    return math.clamp(factor, 0, 1)
end

UpdateRunCameraEffects = function(_Humanoid: Humanoid?, _Character: Model?, _Root: BasePart?): ()
    -- FOV disabled for run
    return
end

local function UpdateRunVFX(): ()
    local Character = LocalPlayer.Character
    local Humanoid = if Character then Character:FindFirstChildOfClass("Humanoid") else nil
    local Root = if Character then Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
    UpdateRunCameraEffects(Humanoid, Character, Root)
    if not Character or not Humanoid or not Root then
        WindVFXController:Release(RUN_WIND_REQUEST_ID)
        LastRunPosition = nil
        return
    end
    if not IsRunningOnGround(Humanoid, Character, Root) then
        WindVFXController:Release(RUN_WIND_REQUEST_ID)
        LastRunPosition = nil
        return
    end

    WindVFXController:AcquirePreset(RUN_WIND_REQUEST_ID, Humanoid, WindVFXController.PRESET_RUN, {
        Priority = -10,
    })
end

local function GetSpinAnimationNames(): {string}
    local ConfigNames = FTConfig.SPIN_CONFIG.SpinAnimationNames
    if ConfigNames and #ConfigNames > 0 then
        return ConfigNames
    end
    return { "SpinJuke" }
end

local function GetNextSpinAnimationName(Animations: Instance): string?
    local names = GetSpinAnimationNames()
    local count = #names
    if count == 0 then
        return nil
    end
    local index = math.clamp(NextSpinAnimationIndex, 1, count)
    local name = names[index]
    local candidate = Animations:FindFirstChild(name)
    if candidate and candidate:IsA("Animation") then
        NextSpinAnimationIndex = if index == count then 1 else index + 1
        return name
    end
    if count > 1 then
        local fallbackIndex = if index == count then 1 else index + 1
        local fallbackName = names[fallbackIndex]
        local fallbackCandidate = Animations:FindFirstChild(fallbackName)
        if fallbackCandidate and fallbackCandidate:IsA("Animation") then
            NextSpinAnimationIndex = if fallbackIndex == count then 1 else fallbackIndex + 1
            return fallbackName
        end
    end
    return nil
end

local function PlaySpinAnimation(): AnimationTrack?
    local Character = LocalPlayer.Character
    if not Character then return nil end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return nil end
    local Animator = Humanoid:FindFirstChildOfClass("Animator")
    if not Animator then
        local createdAnimator = Instance.new("Animator")
        createdAnimator.Parent = Humanoid
        Animator = createdAnimator
    end
    local AnimatorRef = Animator :: Animator
    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    if not Assets then return nil end
    local Gameplay = Assets:FindFirstChild("Gameplay")
    if not Gameplay then return nil end
    local Animations = Gameplay:FindFirstChild("Animations")
    if not Animations then return nil end
    local SpinAnimationName = GetNextSpinAnimationName(Animations)
    if not SpinAnimationName then return nil end
    local SpinAnimation = Animations:FindFirstChild(SpinAnimationName)
    if SpinAnimation and SpinAnimation:IsA("Animation") then
        local Track = AnimatorRef:LoadAnimation(SpinAnimation)
        SpinAnimationTrack = Track
        Track:Play()
        return Track
    end
    return nil
end

local function GetBallCarrier(): Player?
    local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
    if not GameStateFolder then return nil end
    local BallCarrierValue = GameStateFolder:FindFirstChild("BallCarrier") :: ObjectValue?
    return if BallCarrierValue then BallCarrierValue.Value :: Player? else nil
end

-- Handle spin input from the local player.  This function now
-- respects the invulnerability attribute: if the local player or
-- their character is marked invulnerable, the spin will not be
-- performed even if all other conditions (stamina, cooldown, etc.) are
-- satisfied.
local function HandleSpinInput(Input: InputObject, GameProcessed: boolean): ()
    if GameProcessed then return end
    if Input.KeyCode ~= FTConfig.SPIN_CONFIG.SpinKeyCode then return end
    if GetBallCarrier() ~= LocalPlayer then return end
    if IsSpinning then return end
    -- Do not allow spin if the local player cannot act (this check
    -- includes invulnerability)
    if not CanPlayerAct() then return end
    if not CanSpinNow() then return end
    if not HasEnoughStamina() then return end
    -- Additional guard: abort if invulnerable
    if LocalPlayer:GetAttribute(INVULNERABLE_ATTR) == true then return end
    local character = LocalPlayer.Character
    if character and character:GetAttribute(INVULNERABLE_ATTR) == true then return end
    -- Deduct spin cost locally so running drain doesn't leave the move "free"
    local SpinCost: number = FlowBuffs.ApplyStaminaCostReduction(LocalPlayer, FTConfig.STAMINA_CONFIG.SpinStaminaCost)
    local postCostStamina = math.max(CurrentStamina - SpinCost, 0)
    UpdateStamina(postCostStamina)
    IsSpinning = true
    SoundController:Play("Spin")
    SetPlayerAttribute(ATTR_CAN_THROW, false)
    TriggerSpinHighlight(GetSpinDuration())
    Packets.SpinActivate:Fire()
    local track = PlaySpinAnimation()
    local function finishSpin(): ()
        task.delay(SPIN_THROW_LOCK_EXTRA, function()
            SetPlayerAttribute(ATTR_CAN_THROW, true)
        end)
        task.delay(SPIN_COOLDOWN, function()
            IsSpinning = false
        end)
    end
    if track then
        track.Stopped:Once(finishSpin)
    else
        finishSpin()
    end
end

local function HandleCharacterAdded(Character: Model): ()
    CreateStaminaBillboard(Character)
    UpdateStaminaBillboardVisibility()
    UpdateStaminaBarVisual()
    ForceStopRunning(true, "CharacterAddedReset")
    table.insert(Connections, Character:GetAttributeChangedSignal(ATTR_SKILL_LOCKED):Connect(function()
        UpdateRunningState(true)
        UpdateStaminaBillboardVisibility()
    end))
    table.insert(Connections, Character:GetAttributeChangedSignal(ATTR_STUNNED):Connect(function()
        UpdateRunningState(true)
    end))
    table.insert(Connections, Character:GetAttributeChangedSignal(ATTR_CAN_ACT):Connect(function()
        UpdateRunningState(true)
    end))
    table.insert(Connections, Character:GetAttributeChangedSignal(ATTR_CUTSCENE_HUD_HIDDEN):Connect(function()
        UpdateStaminaBillboardVisibility()
    end))
end

local function BindMatchPositionChanges(): ()
    local GameState = ReplicatedStorage:FindFirstChild("FTGameState")
    if not GameState then return end
    local MatchFolder = GameState:FindFirstChild("Match")
    if not MatchFolder then return end
    for _, TeamFolder in MatchFolder:GetChildren() do
        for _, PositionValue in TeamFolder:GetChildren() do
            if PositionValue:IsA("IntValue") then
                table.insert(Connections, PositionValue.Changed:Connect(function()
                    UpdateStaminaBillboardVisibility()
                end))
            end
        end
    end
end

--\ PUBLIC FUNCTIONS \-- TR
function FTSpinController.Start(_self: typeof(FTSpinController)): ()
    local Character = LocalPlayer.Character
    if Character then
        CreateStaminaBillboard(Character)
    end
    local camera = Workspace.CurrentCamera
    if camera then
        BaseCameraFOV = camera.FieldOfView
        LastFOVTarget = BaseCameraFOV
    end
    table.insert(Connections, LocalPlayer.CharacterAdded:Connect(HandleCharacterAdded))
    table.insert(Connections, LocalPlayer:GetAttributeChangedSignal(ATTR_SKILL_LOCKED):Connect(function()
        UpdateRunningState(true)
        UpdateStaminaBillboardVisibility()
    end))
    table.insert(Connections, LocalPlayer:GetAttributeChangedSignal(ATTR_STUNNED):Connect(function()
        UpdateRunningState(true)
    end))
    table.insert(Connections, LocalPlayer:GetAttributeChangedSignal(ATTR_CAN_ACT):Connect(function()
        UpdateRunningState(true)
    end))
    table.insert(Connections, LocalPlayer:GetAttributeChangedSignal(CHARGE_ATTRIBUTE):Connect(function()
        UpdateRunningState(true)
    end))
    table.insert(Connections, LocalPlayer:GetAttributeChangedSignal(ATTR_CUTSCENE_HUD_HIDDEN):Connect(function()
        UpdateStaminaBillboardVisibility()
    end))
    table.insert(Connections, LocalPlayer:GetAttributeChangedSignal(ATTR_RESUME_RUN):Connect(function()
        if LocalPlayer:GetAttribute(ATTR_RESUME_RUN) == true then
            QueueResumeRun()
            UpdateRunningState(true)
        end
    end))
    Packets.PlayerStaminaUpdate.OnClientEvent:Connect(function(Stamina: number)
        UpdateStamina(Stamina)
    end)
    EmitRunDebug("RunInputBridgeReady:SingleSourceV3", true)
    ContextActionService:UnbindAction(LEAVE_ACTION_NAME)
    ContextActionService:BindAction(LEAVE_ACTION_NAME, HandleLeaveMatchAction, false, Enum.KeyCode.L)
    UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
        HandleSpinInput(Input, GameProcessed)
    end)
    local GameState = ReplicatedStorage:WaitForChild("FTGameState")
    ResolveHudGradient()
    StartHudGradientRotation()
    local CountdownActiveValue = GameState:FindFirstChild("CountdownActive") :: BoolValue?
    if CountdownActiveValue then
        HandleCountdownVisuals(CountdownActiveValue.Value)
        table.insert(Connections, CountdownActiveValue.Changed:Connect(function(value: boolean)
            HandleCountdownVisuals(value)
        end))
    end
    local MatchStartedValue = GameState:FindFirstChild("MatchStarted") :: BoolValue?
    if MatchStartedValue then
        table.insert(Connections, MatchStartedValue.Changed:Connect(function()
            UpdateRunningState(true)
        end))
    end
    local MatchFolder = GameState:FindFirstChild("Match")
    if MatchFolder then
        BindMatchPositionChanges()
    end
    table.insert(Connections, GameState.ChildAdded:Connect(function(Child)
        if Child.Name == "Match" then
            BindMatchPositionChanges()
        end
    end))
    table.insert(Connections, LocalPlayer:GetAttributeChangedSignal(MatchPlayerUtils.GetMatchActiveAttributeName()):Connect(function()
        UpdateRunningState(true)
        UpdateStaminaBillboardVisibility()
    end))
    RunService.RenderStepped:Connect(function()
        UpdateRunningState()
        UpdateRunVFX()
        UpdateStaminaBillboardVisibility()
    end)
    UpdateStamina(FTConfig.STAMINA_CONFIG.MaxStamina)
    UpdateStaminaBillboardVisibility()
    if LocalPlayer:GetAttribute(ATTR_RESUME_RUN) == true then
        QueueResumeRun()
    end
    LastPolledRunKeyDown = IsRunToggleKeyDown()
    ForceStopRunning(true, "ControllerStartReset")
end

function FTSpinController.HandleExternalRunToggle(source: string, keyCode: Enum.KeyCode?, GameProcessed: boolean?): ()
    AttemptRunToggleFromKey(source, if keyCode then keyCode.Name else "Unknown", GameProcessed)
end

return FTSpinController
