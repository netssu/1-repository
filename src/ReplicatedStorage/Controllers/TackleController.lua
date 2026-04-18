
--!strict

--[[
    Updated FTTackleController
    --------------------------
    This client‑side controller handles tackle input and animations.  It has
    been updated to use the correct FTBallService module path and to respect
    the new `Invulnerable` attribute set by the server during down and
    touchdown notifications.  When the local player is marked as
    Invulnerable, tackle attempts are ignored so the client UI stays in
    sync with server rules.  See GameService and ScoringService for when
    Invulnerable is applied.

    Original source: src/Shared/Controllers/FTTackleController.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RUN_SERVICE = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Require packets and config from the canonical Modules.Game folder
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local HighlightEffect = require(ReplicatedStorage.Modules.Game.HighlightEffect)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)
local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
local WalkSpeedController = require(ReplicatedStorage.Controllers.WalkSpeedController)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)

--[[
    Although the server uses FTBallService to determine when a tackle ends a
    play, the client does not need to call FTBallService here.  If your
    client requires ball state information, require it from Modules.Game:

        local FTBallService = require(ReplicatedStorage.Modules.Game.FTBallService)

    Do not require FTBallService from ReplicatedStorage.Controllers.
]]

local LocalPlayer = Players.LocalPlayer
local FTTackleController = {}

--\ CONSTANTS \ --
local ATTR_CAN_ACT = "FTCanAct"
local ATTR_CAN_THROW = "FTCanThrow"
local ATTR_CAN_SPIN = "FTCanSpin"
local ATTR_STUNNED = "FTStunned"
local ATTR_SKILL_LOCKED = "FTSkillLocked"
local ATTR_RAGDOLLED = "FTRagdolled"
-- New attribute used by the server to mark players invulnerable during
-- down and touchdown notifications.  When true, the client must prevent
-- tackle input to stay consistent with server rules.
local INVULNERABLE_ATTR = "Invulnerable"
local GAME_STATE_FOLDER_NAME: string = "FTGameState"
local MATCH_ENABLED_NAME: string = "MatchEnabled"
local MATCH_STARTED_NAME: string = "MatchStarted"
local BALL_DATA_NAME: string = "FTBallData"
local BALL_IN_AIR_ATTR: string = "FTBall_InAir"
local BALL_POSSESSION_ATTR: string = "FTBall_Possession"
local BALL_EXTERNAL_HOLDER_ATTR: string = "FTBall_ExternalHolder"

local KEY_TACKLE: Enum.KeyCode = FTConfig.TACKLE_CONFIG.TackleKeyCode or Enum.KeyCode.F
-- Mirror the server cooldown locally so the client does not replay
-- tackle animation and sound while the action is still locked out.
local TACKLE_COOLDOWN: number = FTConfig.TACKLE_CONFIG.Cooldown or 2.5
local HITBOX_SIZE: Vector3 = FTConfig.TACKLE_CONFIG.HitboxSize or Vector3.new(6, 5, 8)
local HITBOX_FORWARD: number = FTConfig.TACKLE_CONFIG.HitboxForwardOffset or 3
local VELOCITY_PROJECTION: number = FTConfig.TACKLE_CONFIG.VelocityProjection or 0.05
local STUN_DURATION: number = FTConfig.TACKLE_CONFIG.StunDuration or 1.2
local HIGHLIGHT_KEY = "TackleStun"
local HIGHLIGHT_FLASH_KEY = "TackleFlash"
local WALK_SPEED_DEFAULT = 16
local TACKLE_IMPULSE_SPEED = 28
local TACKLE_IMPULSE_DURATION = 0.25

--\ STATE \ --
local LastTackleRequestTime: number = -math.huge
local StunToken: number = 0
local BallCarrierValue: ObjectValue? = nil
local BallDataInstance: Instance? = nil
local StunEnforceConn: RBXScriptConnection? = nil
local MatchEnabledValue: BoolValue? = nil
local MatchStartedValue: BoolValue? = nil
local LocalRagdollActive: boolean = false

--\ HELPERS \ --
local function GetBallCarrier(): Player?
    if not BallCarrierValue then
        local gameState = ReplicatedStorage:FindFirstChild("FTGameState")
        if gameState then
            BallCarrierValue = gameState:FindFirstChild("BallCarrier") :: ObjectValue?
        end
    end
    return if BallCarrierValue and BallCarrierValue.Value then BallCarrierValue.Value :: Player else nil
end

local function GetBallData(): Instance?
	if BallDataInstance and BallDataInstance.Parent ~= nil then
		return BallDataInstance
	end

	BallDataInstance = ReplicatedStorage:FindFirstChild(BALL_DATA_NAME)
	return BallDataInstance
end

local function GetMatchEnabled(): boolean
    if not MatchEnabledValue then
        local GameState: Instance? = ReplicatedStorage:FindFirstChild(GAME_STATE_FOLDER_NAME)
        if GameState then
            MatchEnabledValue = GameState:FindFirstChild(MATCH_ENABLED_NAME) :: BoolValue?
        end
    end
    return if MatchEnabledValue then MatchEnabledValue.Value else false
end

local function GetMatchStarted(): boolean
    if not MatchStartedValue then
        local GameState: Instance? = ReplicatedStorage:FindFirstChild(GAME_STATE_FOLDER_NAME)
        if GameState then
            MatchStartedValue = GameState:FindFirstChild(MATCH_STARTED_NAME) :: BoolValue?
        end
    end
    return if MatchStartedValue then MatchStartedValue.Value else false
end

local function IsPlayerInMatch(): boolean
    return MatchPlayerUtils.IsPlayerActive(LocalPlayer)
end

local function IsCarryingBall(): boolean
    local BallData: Instance? = GetBallData()
    if BallData then
        if BallData:GetAttribute(BALL_IN_AIR_ATTR) == true then
            return false
        end

        if BallData:GetAttribute(BALL_EXTERNAL_HOLDER_ATTR) ~= nil then
            return false
        end

        local PossessionValue: any = BallData:GetAttribute(BALL_POSSESSION_ATTR)
        local LocalIdValue: number = PlayerIdentity.GetLocalIdValue()
        if type(PossessionValue) == "number" and LocalIdValue > 0 then
            return PossessionValue == LocalIdValue
        end
    end

    return GetBallCarrier() == LocalPlayer
end

local function GetHumanoidAndRoot(): (Humanoid?, BasePart?)
    local character = LocalPlayer.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    return humanoid, root
end

-- Returns whether the local player is allowed to act (tackle).  In
-- addition to the original checks, we now verify that the player is not
-- invulnerable.
local function CanAct(): boolean
    if not GetMatchEnabled() then
        return false
    end
    if not GetMatchStarted() then
        return false
    end
    if not IsPlayerInMatch() then
        return false
    end
    -- If the server has marked us invulnerable, ignore tackle input.
    if LocalPlayer:GetAttribute(INVULNERABLE_ATTR) == true then
        return false
    end
    if LocalPlayer:GetAttribute(ATTR_SKILL_LOCKED) == true then
        return false
    end
    if LocalPlayer:GetAttribute(ATTR_STUNNED) == true then
        return false
    end
    local Character = LocalPlayer.Character
    if Character and Character:GetAttribute(ATTR_SKILL_LOCKED) == true then
        return false
    end
    if LocalPlayer:GetAttribute(ATTR_CAN_ACT) == false then
        return false
    end
    return true
end

local function PlayTackleAnimation(): ()
    if AnimationController and AnimationController.PlayAnimation then
        AnimationController.PlayAnimation("Tackle", {
            Priority = Enum.AnimationPriority.Action4,
            FadeTime = 0.1,
        })
    end
end

local function BuildHitboxCFrame(root: BasePart): CFrame
    local baseCF = root.CFrame * CFrame.new(0, 0, -HITBOX_FORWARD)
    local projected = baseCF.Position + (root.AssemblyLinearVelocity * VELOCITY_PROJECTION)
    return CFrame.lookAt(projected, projected + root.CFrame.LookVector, root.CFrame.UpVector)
end

-- Send a tackle request to the server.  This does not perform local
-- collision detection; the server will handle verifying hits.
local function SendTackleAttempt(): ()
    local humanoid, root = GetHumanoidAndRoot()
    if not humanoid or not root then return end
    LastTackleRequestTime = os.clock()
    PlayTackleAnimation()
    SoundController:Play("Tackle")
    local boxCFrame = BuildHitboxCFrame(root)
    Packets.TackleAttempt:Fire(boxCFrame, HITBOX_SIZE)
end

local function StopTackleImpulse(root: BasePart?): ()
    if not root then
        return
    end
    local lv = root:FindFirstChild("TackleImpulseLV") :: LinearVelocity?
    if lv then
        lv.Enabled = false
        lv.VectorVelocity = Vector3.zero
    end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function ApplyTackleImpulse(root: BasePart)
    local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
    if not attachment then
        attachment = root:FindFirstChildWhichIsA("Attachment")
    end
    if not attachment then
        attachment = Instance.new("Attachment")
        attachment.Name = "TackleImpulseAttachment"
        attachment.Parent = root
    end
    local lv = root:FindFirstChild("TackleImpulseLV") :: LinearVelocity?
    if not lv then
        lv = Instance.new("LinearVelocity")
        lv.Name = "TackleImpulseLV"
        lv.RelativeTo = Enum.ActuatorRelativeTo.World
        lv.MaxForce = math.huge
        lv.Attachment0 = attachment
        lv.Parent = root
    end
    local forwardVel = root.CFrame.LookVector * TACKLE_IMPULSE_SPEED
    lv.VectorVelocity = Vector3.new(forwardVel.X, 0, forwardVel.Z)
    lv.Enabled = true
    task.delay(TACKLE_IMPULSE_DURATION, function()
        if lv then
            lv.Enabled = false
        end
    end)
end

-- Visual flash on tackle; unchanged.
local function PlayTackleFlash()
    local character = LocalPlayer.Character
    if not character then return end
    local highlight = HighlightEffect.EnsureHighlight(HIGHLIGHT_FLASH_KEY, {
        Parent = character,
        Name = "TackleFlashHighlight",
        FillColor = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineTransparency = 0.5,
    })
    if not highlight then return end
    HighlightEffect.SetHighlightMode(HIGHLIGHT_FLASH_KEY, "off")
    highlight.Enabled = true
    local tween = TweenService:Create(highlight, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        FillTransparency = 1,
        OutlineTransparency = 1,
    })
    tween:Play()
    tween.Completed:Once(function()
        HighlightEffect.ClearHighlight(HIGHLIGHT_FLASH_KEY)
    end)
end

-- Clear tackle highlight; unchanged.
local function ClearHighlight()
    HighlightEffect.ClearHighlight(HIGHLIGHT_KEY)
end

-- Show a stun highlight for the given duration; unchanged.
local function ShowStunHighlight(duration: number): ()
    local character = LocalPlayer.Character
    if not character then return end
    local highlight = HighlightEffect.EnsureHighlight(HIGHLIGHT_KEY, {
        Parent = character,
        Name = "TackleStunHighlight",
        FillColor = Color3.fromRGB(255, 60, 60),
        OutlineColor = Color3.fromRGB(255, 60, 60),
        FillTransparency = 0.2,
        OutlineTransparency = 0.2,
    })
    if not highlight then return end
    HighlightEffect.SetHighlightMode(HIGHLIGHT_KEY, "off")
    highlight.Enabled = true
    local tween = TweenService:Create(highlight, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        FillTransparency = 1,
        OutlineTransparency = 1,
    })
    tween:Play()
    tween.Completed:Once(function()
        ClearHighlight()
    end)
end

local function ShowStunHighlightForTarget(target: Player, duration: number): ()
    local character = target.Character
    if not character then return end
    local idValue = PlayerIdentity.GetIdValue(target)
    local key = "TackleStun_" .. tostring(idValue)
    local highlight = HighlightEffect.EnsureHighlight(key, {
        Parent = character,
        Name = "TackleStunHighlight",
        FillColor = Color3.fromRGB(255, 60, 60),
        OutlineColor = Color3.fromRGB(255, 60, 60),
        FillTransparency = 0.2,
        OutlineTransparency = 0.2,
    })
    if not highlight then return end
    HighlightEffect.SetHighlightMode(key, "off")
    highlight.Enabled = true
    local tween = TweenService:Create(highlight, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        FillTransparency = 1,
        OutlineTransparency = 1,
    })
    tween:Play()
    tween.Completed:Once(function()
        HighlightEffect.ClearHighlight(key)
    end)
end

-- Set or clear attributes on the local player when stunned; unchanged.
local function SetAttributesForStun(stunned: boolean): ()
    LocalPlayer:SetAttribute(ATTR_STUNNED, stunned)
    LocalPlayer:SetAttribute(ATTR_CAN_ACT, not stunned)
    LocalPlayer:SetAttribute(ATTR_CAN_THROW, not stunned)
    LocalPlayer:SetAttribute(ATTR_CAN_SPIN, not stunned)
    local character = LocalPlayer.Character
    if character then
        character:SetAttribute(ATTR_STUNNED, stunned)
        character:SetAttribute(ATTR_CAN_ACT, not stunned)
        character:SetAttribute(ATTR_CAN_THROW, not stunned)
        character:SetAttribute(ATTR_CAN_SPIN, not stunned)
    end
    if Packets and Packets.RunningStateUpdate and Packets.RunningStateUpdate.Fire then
        Packets.RunningStateUpdate:Fire(false)
    end
end

local function SetLocalRagdollState(enabled: boolean): ()
    LocalRagdollActive = enabled
    LocalPlayer:SetAttribute(ATTR_RAGDOLLED, enabled)
    local character = LocalPlayer.Character
    if character then
        character:SetAttribute(ATTR_RAGDOLLED, enabled)
    end
end

local function OnRagdollState(enabled: boolean, _duration: number): ()
    local wasRagdolled = LocalRagdollActive
    local _, root = GetHumanoidAndRoot()
    if enabled then
        StopTackleImpulse(root)
    end
    SetLocalRagdollState(enabled == true)
    if not enabled and wasRagdolled then
        task.defer(function(): ()
            AnimationController.PlayStandUpAnimation()
        end)
    end
end

-- Apply a stun locally; unchanged from original implementation.
local function ApplyStun(duration: number): ()
    StunToken += 1
    local token = StunToken
    if StunEnforceConn then
        StunEnforceConn:Disconnect()
        StunEnforceConn = nil
    end
    local humanoid, root = GetHumanoidAndRoot()
    SetAttributesForStun(true)
    StopTackleImpulse(root)
    if WalkSpeedController and WalkSpeedController.SetDefaultWalkSpeed then
        WalkSpeedController.SetDefaultWalkSpeed(0)
    end
    if humanoid then
        humanoid.WalkSpeed = 0
    end
    StunEnforceConn = RUN_SERVICE.Heartbeat:Connect(function()
        if LocalPlayer:GetAttribute(ATTR_STUNNED) ~= true then
            return
        end
        local h, _root = GetHumanoidAndRoot()
        if h then
            h.WalkSpeed = 0
        end
        if WalkSpeedController and WalkSpeedController.SetDefaultWalkSpeed then
            WalkSpeedController.SetDefaultWalkSpeed(0)
        end
    end)
    ShowStunHighlight(duration)
    task.delay(duration, function()
        if token ~= StunToken then
            return
        end
        if StunEnforceConn then
            StunEnforceConn:Disconnect()
            StunEnforceConn = nil
        end
        SetAttributesForStun(false)
        if WalkSpeedController and WalkSpeedController.SetDefaultWalkSpeed then
            WalkSpeedController.SetDefaultWalkSpeed(FlowBuffs.ApplySpeedBuff(LocalPlayer, WALK_SPEED_DEFAULT))
        end
        if humanoid then
            humanoid.WalkSpeed = FlowBuffs.ApplySpeedBuff(LocalPlayer, WALK_SPEED_DEFAULT)
        end
        ClearHighlight()
    end)
end

-- Handle stun packets from the server; unchanged.
local function OnTackleStun(duration: number): ()
    SoundController:Play("StunTackle")
    ApplyStun(duration)
end

local function OnTackleImpact(targetId: number, duration: number): ()
    local target = PlayerIdentity.ResolvePlayer(targetId)
    if not target then
        return
    end
    if target == LocalPlayer then
        return
    end
    local dur = if typeof(duration) == "number" and duration > 0 then duration else STUN_DURATION
    ShowStunHighlightForTarget(target, dur)
end

-- Handle user input for tackles.  Added a check for invulnerability so the
-- client does not attempt a tackle when the server forbids it.
local function HandleInputBegan(input: InputObject, gameProcessed: boolean): ()
    if gameProcessed then return end
    if input.KeyCode ~= KEY_TACKLE then return end
    if IsCarryingBall() then return end
    if os.clock() - LastTackleRequestTime < TACKLE_COOLDOWN then return end
    -- Do not allow tackle input while invulnerable
    if LocalPlayer:GetAttribute(INVULNERABLE_ATTR) == true then
        return
    end
    if not CanAct() then return end
    local _, root = GetHumanoidAndRoot()
    if root then
        ApplyTackleImpulse(root)
    end
    PlayTackleFlash()
    SendTackleAttempt()
end

--\ PUBLIC API \ --
function FTTackleController.Init(): ()
    Packets.TackleStun.OnClientEvent:Connect(OnTackleStun)
    if Packets.TackleImpact then
        Packets.TackleImpact.OnClientEvent:Connect(OnTackleImpact)
    end
    if Packets.RagdollState then
        Packets.RagdollState.OnClientEvent:Connect(OnRagdollState)
    end
end

function FTTackleController.Start(): ()
    SetLocalRagdollState(false)
    UserInputService.InputBegan:Connect(HandleInputBegan)
end

return FTTackleController
