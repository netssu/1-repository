--!strict

--\\ MODULE CONSTANTS \\ -- TR
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local PlayersService = game:GetService("Players")
local WORKSPACE = workspace

local RunService = game:GetService("RunService")
local USER_INPUT_SERVICE = game:GetService("UserInputService")

local ANIM_NAMES = {
	Charge = { "Charged" },
	ChargeShot = { "ChargedShot" },
	Throw = { "Throw" },
	Shot = { "Shot" },
	Catch = { "Catch" },
}
local CHARGE_MOVEMENT_OVERRIDE_STATES = {
	walkback = true,
	walkl = true,
	walkr = true,
	front = true,
}
local HIGHLIGHT_PULSE_MIN: number = 0.2
local HIGHLIGHT_PULSE_MAX: number = 0.8
local POWER_BAR_TWEEN_INFO: TweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ATTR = {
	CAN_ACT = "FTCanAct",
	IS_CHARGING = "FTChargingThrow",
	CAN_SPIN = "FTCanSpin",
	CAN_THROW = "FTCanThrow",
	IS_RUNNING = "FTRunning",
	STUNNED = "FTStunned",
	EXTRA_POINT_FROZEN = "FTExtraPointFrozen",
	FACING_GOAL = "FTFacingGoalTeam",
}
local ATTR_PERFECT_PASS_CUTSCENE_LOCKED: string = "FTPerfectPassCutsceneLocked"

local ANIMATION_FADE_TIME: number = 0.1 
local CIRCLE_CONSTS = {
	AIM_COLOR = Color3.fromRGB(255, 255, 255),
	TEAM_ONE_COLOR = Color3.fromRGB(0, 38, 120),
	TEAM_TWO_COLOR = Color3.fromRGB(83, 0, 0),
	PLAYER_COLOR = Color3.fromRGB(0, 38, 120),
	OUTLINE_TRANSPARENCY = 0.55,
	OUTLINE_COLOR = Color3.fromRGB(0, 0, 0),
}
local CIRCLE_ROTATION_SPEED: number = 2
local CIRCLE_GROUND_EPSILON: number = 0.01
local PLAYER_MARKER_FIXED_Y: number = 711.072
local CIRCLE_GROUND_RAY_DISTANCE: number = 200
local CIRCLE_MAX_VISIBLE_AIR_HEIGHT: number = 30
local BALL_ASSET_PRELOAD_TIMEOUT: number = 8
local BALL_ASSET_POST_PRELOAD_FRAMES: number = 2
local BALL_STATE_FOV_REQUEST_ID: string = "BallController::BallStatePulse"
local EXTRA_POINT_KICK_FOV_REQUEST_ID: string = "BallController::ExtraPointKick"
local BALL_STATE_FOV_TWEEN: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

--\\ MODULE STATE \\ -- TR
local LocalPlayer = game:GetService("Players").LocalPlayer
local Camera = WORKSPACE.CurrentCamera

local BallInstance: Model? = nil
local BallPart: BasePart? = nil
local CircleState = {
	PlayerInstance = nil :: BasePart?,
	BallInstance = nil :: BasePart?,
	PlayerGroundOffset = CIRCLE_GROUND_EPSILON :: number,
	BallGroundOffset = CIRCLE_GROUND_EPSILON :: number,
}
local AimCircleInstance: BasePart? = nil
local AimCircleGroundOffset: number = CIRCLE_GROUND_EPSILON
local BallInAir: boolean = false
local BallMarkerReady: boolean = false
local BallCameraEnabled: boolean = false
local BallCameraForceUntil: number = 0
local LastBallCameraDirection: Vector3 = Vector3.new(0, 0, -1)
local PreExtraPointCamState = {
	active = false,
	untilTime = 0,
	duration = 0,
	targetId = nil,
	mode = "front",
	prevType = nil,
	prevSubject = nil,
	prevShiftlockEnabled = nil,
	prevMouseBehavior = nil,
	prevMouseIconEnabled = nil,
	mouseOverrideBound = false,
	connection = nil,
	focusPos = nil,
	forward = nil,
	lastUpdateAt = 0,
}
local MatchStartedInstance: BoolValue? = nil
local BallCarrierInstance: ObjectValue? = nil
local IsChargingThrow: boolean = false
local CountdownActive: boolean = false
local LocalPlayerTeam: number? = nil
local PlayerTeamValueConnection: RBXScriptConnection? = nil
local GameStateConnections: {RBXScriptConnection} = {}
local FacingGoalAttributeConnection: RBXScriptConnection? = nil
local ExtraPointCountdownActive: boolean = false
local ExtraPointCountdownStartTime: number? = nil
local controllers = ReplicatedStorage:WaitForChild("Controllers")
local CameraController = require(controllers:WaitForChild("CameraController"))
local FOVController = require(controllers:WaitForChild("FOVController"))
local TouchdownWaveTransitionCoordinator = require(ReplicatedStorage.Modules.Game.TouchdownWaveTransitionCoordinator)

local InvulFrame: Frame? = nil
local InvulFrameTween: Tween? = nil
local BallVisualUtils = {}
local FTBallController: {[string]: any} = {}
local _ResetPowerBar: (() -> ())? = nil
local _ReleaseCharacterFacing: (() -> ())? = nil
local _UpdateCharacterFacing: ((Vector3) -> ())? = nil
local _ApplyFacingGoalTarget: ((number) -> ())? = nil
local _StopShotHoldAnimation: (() -> ())? = nil
local PreloadedBallSignatures: {[string]: boolean} = {}
local LastBallStateSignature: string? = nil

function BallVisualUtils.IsLocalPlayerInMatch(): boolean
    return require(REPLICATED_STORAGE.Modules.Game.MatchPlayerUtils).IsPlayerActive(LocalPlayer)
end

local function _EnsureInvulFrame(): Frame?
    if InvulFrame and InvulFrame.Parent then
        return InvulFrame
    end
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local gameGui = pg:FindFirstChild("GameGui")
    if not gameGui then return nil end
    local main = gameGui:FindFirstChild("Main")
    if not main then return nil end
    local frame = main:FindFirstChild("Frame")
    if frame and frame:IsA("Frame") then
        InvulFrame = frame
        return frame
    end
    return nil
end

local function _PlayInvulnerabilityAnimation(invul: boolean): ()
    local frame = _EnsureInvulFrame()
    if not frame then
        return
    end
    local tweenToken = ((frame:GetAttribute("FTInvulFrameTweenToken") :: number?) or 0) + 1
    frame:SetAttribute("FTInvulFrameTweenToken", tweenToken)
    if InvulFrameTween then
        InvulFrameTween:Cancel()
        InvulFrameTween = nil
    end
    if invul then
        frame.Visible = true
        frame.Position = UDim2.new(0.503, 0, 0.99, 0)
        local tween = TweenService:Create(frame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Position = UDim2.new(0.503, 0, 1.99, 0)
        })
        InvulFrameTween = tween
        tween.Completed:Once(function(playbackState)
            if frame:GetAttribute("FTInvulFrameTweenToken") ~= tweenToken then
                return
            end
            if playbackState ~= Enum.PlaybackState.Completed then
                return
            end
            if InvulFrameTween == tween then
                InvulFrameTween = nil
            end
            frame.Visible = false
        end)
        tween:Play()
    else
        frame.Position = UDim2.new(0.503, 0, 1.99, 0)
        frame.Visible = true
        local tween = TweenService:Create(frame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.503, 0, 0.99, 0)
        })
        InvulFrameTween = tween
        tween.Completed:Once(function(playbackState)
            if frame:GetAttribute("FTInvulFrameTweenToken") ~= tweenToken then
                return
            end
            if playbackState ~= Enum.PlaybackState.Completed then
                return
            end
            if InvulFrameTween == tween then
                InvulFrameTween = nil
            end
        end)
        tween:Play()
    end
end

local function AppendUniquePreloadInstance(preloadList: {any}, seenInstances: {[Instance]: boolean}, instance: Instance?): ()
	if not instance or seenInstances[instance] then
		return
	end
	seenInstances[instance] = true
	table.insert(preloadList, instance)
end

local function AppendUniquePreloadContent(preloadList: {any}, seenContent: {[string]: boolean}, contentValue: any): ()
	if typeof(contentValue) ~= "string" then
		return
	end
	if contentValue == "" or seenContent[contentValue] then
		return
	end
	seenContent[contentValue] = true
	table.insert(preloadList, contentValue)
end

local function AppendContentProperty(preloadList: {any}, seenContent: {[string]: boolean}, instance: Instance, propertyName: string): ()
	local success, value = pcall(function()
		return (instance :: any)[propertyName]
	end)
	if success then
		AppendUniquePreloadContent(preloadList, seenContent, value)
	end
end

local function CollectBallPreloadItems(root: Instance): ({any}, {string})
	local preloadList: {any} = {}
	local seenInstances: {[Instance]: boolean} = {}
	local seenContent: {[string]: boolean} = {}

	local function collectInstance(instance: Instance): ()
		if instance:IsA("MeshPart") then
			AppendUniquePreloadInstance(preloadList, seenInstances, instance)
			AppendContentProperty(preloadList, seenContent, instance, "MeshId")
			AppendContentProperty(preloadList, seenContent, instance, "TextureID")
			AppendContentProperty(preloadList, seenContent, instance, "MeshContent")
			AppendContentProperty(preloadList, seenContent, instance, "TextureContent")
		elseif instance:IsA("SurfaceAppearance") then
			AppendUniquePreloadInstance(preloadList, seenInstances, instance)
			AppendContentProperty(preloadList, seenContent, instance, "ColorMap")
			AppendContentProperty(preloadList, seenContent, instance, "MetalnessMap")
			AppendContentProperty(preloadList, seenContent, instance, "NormalMap")
			AppendContentProperty(preloadList, seenContent, instance, "RoughnessMap")
		elseif instance:IsA("SpecialMesh") then
			AppendUniquePreloadInstance(preloadList, seenInstances, instance)
			AppendContentProperty(preloadList, seenContent, instance, "MeshId")
			AppendContentProperty(preloadList, seenContent, instance, "TextureId")
		elseif instance:IsA("Texture") or instance:IsA("Decal") then
			AppendUniquePreloadInstance(preloadList, seenInstances, instance)
			AppendContentProperty(preloadList, seenContent, instance, "Texture")
		end
	end

	collectInstance(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		collectInstance(descendant)
	end

	local signatureParts: {string} = {}
	for contentId in seenContent do
		table.insert(signatureParts, contentId)
	end
	table.sort(signatureParts)

	return preloadList, signatureParts
end

local function PreloadBallRenderAssets(root: Instance?): ()
	if not root then
		return
	end

	local preloadList, signatureParts = CollectBallPreloadItems(root)
	if #preloadList <= 0 then
		return
	end

	local signature = table.concat(signatureParts, "|")
	if signature ~= "" and PreloadedBallSignatures[signature] then
		return
	end

	local completed = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(preloadList)
		end)
		completed = true
	end)

	local startTime = os.clock()
	while not completed and os.clock() - startTime < BALL_ASSET_PRELOAD_TIMEOUT do
		RunService.Heartbeat:Wait()
	end

	for _ = 1, BALL_ASSET_POST_PRELOAD_FRAMES do
		RunService.Heartbeat:Wait()
	end

	if signature ~= "" then
		PreloadedBallSignatures[signature] = true
	end
end


local lastInvulnerabilityState: boolean? = nil
LocalPlayer:GetAttributeChangedSignal("FTSkillLocked"):Connect(function()
    local invulFlag = false
    if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
        invulFlag = true
    elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
        invulFlag = true
    elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
        invulFlag = true
    else
        local ch = LocalPlayer.Character
        if ch and (ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true) then
            invulFlag = true
        end
    end
    if invulFlag ~= lastInvulnerabilityState then
        lastInvulnerabilityState = invulFlag
        _PlayInvulnerabilityAnimation(invulFlag)
    end
end)

LocalPlayer:GetAttributeChangedSignal("FTCutsceneHudHidden"):Connect(function()
    local invulFlag = false
    if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
        invulFlag = true
    elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
        invulFlag = true
    elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
        invulFlag = true
    else
        local ch = LocalPlayer.Character
        if ch and (ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true) then
            invulFlag = true
        end
    end
    if invulFlag ~= lastInvulnerabilityState then
        lastInvulnerabilityState = invulFlag
        _PlayInvulnerabilityAnimation(invulFlag)
    end
    if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
        if FTBallController._HideTrajectoryVisuals then
            FTBallController._HideTrajectoryVisuals()
        end
        if _ResetPowerBar then
            _ResetPowerBar()
        end
        if _ReleaseCharacterFacing then
            _ReleaseCharacterFacing()
        end
    end
end)

LocalPlayer:GetAttributeChangedSignal("FTMatchCutsceneLocked"):Connect(function()
    local invulFlag = false
    if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
        invulFlag = true
    elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
        invulFlag = true
    elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
        invulFlag = true
    else
        local ch = LocalPlayer.Character
        if ch and (ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true) then
            invulFlag = true
        end
    end
    if invulFlag ~= lastInvulnerabilityState then
        lastInvulnerabilityState = invulFlag
        _PlayInvulnerabilityAnimation(invulFlag)
    end
end)

if LocalPlayer.Character then
    local ch = LocalPlayer.Character
    ch:GetAttributeChangedSignal("FTSkillLocked"):Connect(function()
        local invulFlag = false
        if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
            invulFlag = true
        else
            if ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true then
                invulFlag = true
            end
        end
        if invulFlag ~= lastInvulnerabilityState then
            lastInvulnerabilityState = invulFlag
            _PlayInvulnerabilityAnimation(invulFlag)
        end
    end)
    ch:GetAttributeChangedSignal("FTCutsceneHudHidden"):Connect(function()
        local invulFlag = false
        if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
            invulFlag = true
        else
            if ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true then
                invulFlag = true
            end
        end
        if invulFlag ~= lastInvulnerabilityState then
            lastInvulnerabilityState = invulFlag
            _PlayInvulnerabilityAnimation(invulFlag)
        end
    end)
    ch:GetAttributeChangedSignal("FTMatchCutsceneLocked"):Connect(function()
        local invulFlag = false
        if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
            invulFlag = true
        else
            if ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true then
                invulFlag = true
            end
        end
        if invulFlag ~= lastInvulnerabilityState then
            lastInvulnerabilityState = invulFlag
            _PlayInvulnerabilityAnimation(invulFlag)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(ch)
    ch:GetAttributeChangedSignal("FTSkillLocked"):Connect(function()
        local invulFlag = false
        if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
            invulFlag = true
        else
            if ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true then
                invulFlag = true
            end
        end
        if invulFlag ~= lastInvulnerabilityState then
            lastInvulnerabilityState = invulFlag
            _PlayInvulnerabilityAnimation(invulFlag)
        end
    end)
    ch:GetAttributeChangedSignal("FTCutsceneHudHidden"):Connect(function()
        local invulFlag = false
        if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
            invulFlag = true
        else
            if ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true then
                invulFlag = true
            end
        end
        if invulFlag ~= lastInvulnerabilityState then
            lastInvulnerabilityState = invulFlag
            _PlayInvulnerabilityAnimation(invulFlag)
        end
    end)
    ch:GetAttributeChangedSignal("FTMatchCutsceneLocked"):Connect(function()
        local invulFlag = false
        if LocalPlayer:GetAttribute("FTCutsceneHudHidden") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTMatchCutsceneLocked") == true then
            invulFlag = true
        elseif LocalPlayer:GetAttribute("FTSkillLocked") == true then
            invulFlag = true
        else
            if ch:GetAttribute("FTCutsceneHudHidden") == true or ch:GetAttribute("FTMatchCutsceneLocked") == true or ch:GetAttribute("FTSkillLocked") == true then
                invulFlag = true
            end
        end
        if invulFlag ~= lastInvulnerabilityState then
            lastInvulnerabilityState = invulFlag
            _PlayInvulnerabilityAnimation(invulFlag)
        end
    end)
end)

--\\ BEAM STATE \\ -- TR
local DirectionBeam: Beam? = nil
local Attachment0: Attachment? = nil
local Attachment1: Attachment? = nil
local LastAimTarget: Vector3? = nil
local LastAimDistance: number = 0
local TrailInstance: Trail? = nil
local BallHighlight: Highlight? = nil
local PowerBillboard: BillboardGui? = nil
local PowerFill: Frame? = nil
local PowerFillGradient: UIGradient? = nil
local PowerFillTween: Tween? = nil
local PowerAttachment: Attachment? = nil
local ThrowTrack: AnimationTrack? = nil
local ChargeTrack: AnimationTrack? = nil
local ChargeShotTrack: AnimationTrack? = nil
local CatchTrack: AnimationTrack? = nil
local ShotTrack: AnimationTrack? = nil
local ExtraPointStage: number = 0
local ExtraPointTeam: number = 0
local ExtraPointActive: boolean = false
local ExtraPointTarget: Vector3? = nil
local ExtraPointOscillationOffset: number = 0
local ExtraPointOscillationLocked: boolean = false
local IsFacingLocked: boolean = false
local FacingHoldUntil: number = 0
local LastCountdownFacingWarn: number = 0
local LastThrowTarget: Vector3? = nil
local LastCarrier: Player? = nil
local ChargeStartTime: number = 0
local LastChargeAlpha: number = 0
local LastChargeMaxDistance: number = 0
local LockedAimDirection: Vector3? = nil
local LockedReleaseTarget: Vector3? = nil
local PlayerPickupHighlight: Highlight? = nil
local ExtraPointKickState = {
	pending = false,
	kickerId = nil,
	cinematicActive = false,
	shiftlockRestorePending = false,
	postGoalActive = false,
	postGoalReleaseAt = 0,
	startTime = 0,
	duration = 0,
	kickLookUntil = 0,
	anchorPos = nil,
	launchOrigin = nil,
	launchAxis = nil,
	travelProgress = 0,
	forward = nil,
	goalPart = nil,
	prevType = nil,
	prevSubject = nil,
	prevFov = nil,
	fovTween = nil,
	localPrimeAt = 0,
	inputFrozen = false,
	trajectoryBeamSuppressed = false,
	lastBallPos = nil,
	preKickCFrame = nil,
	preKickBlendStartAt = 0,
	preKickBlendUntil = 0,
}
type LocalPredictedLaunchState = {
	requestId: number,
	releaseAt: number,
	source: string,
	spinType: number,
	expiresAt: number,
	solution: {
		spawnPos: Vector3,
		target: Vector3,
		power: number,
		curve: number,
		distance: number,
		flightTime: number,
	},
}
local ExtraPointFadeState = {
	gui = nil :: ScreenGui?,
	frame = nil :: Frame?,
	token = 0 :: number,
	lastAt = 0 :: number,
}

local ExtraPointGoalVisualState = {
	part = nil,
	team = 0,
	originalColor = nil,
	originalTransparency = nil,
	result = 0,
}
local ExtraPointUi = {}
local _GetAnimationTrackByName: (({string}) -> AnimationTrack?)? = nil
local LastCircleGroundCFrame: CFrame? = nil

local Packets = require(REPLICATED_STORAGE.Modules.Game.Packets)
local FTConfig = require(REPLICATED_STORAGE.Modules.Game.Config)
local FlowBuffs = require(REPLICATED_STORAGE.Modules.Game.FlowBuffs)
local ThrowPrediction = require(REPLICATED_STORAGE.Modules.Game.ThrowPrediction)
local HighlightEffect = require(REPLICATED_STORAGE.Modules.Game.HighlightEffect)
local MatchPlayerUtils = require(REPLICATED_STORAGE.Modules.Game.MatchPlayerUtils)
local PlayerIdentity = require(REPLICATED_STORAGE.Modules.Game.PlayerIdentity)
local WalkSpeedController = require(REPLICATED_STORAGE.Controllers.WalkSpeedController)
local CountdownController = require(REPLICATED_STORAGE.Controllers.CountdownController)
local SoundController = require(REPLICATED_STORAGE.Controllers.SoundController)
local BallImpactFx = require(REPLICATED_STORAGE.Modules.Game.BallImpactFx)


local ChargeConfig = {
	minAimDistance = FTConfig.THROW_CONFIG.MinAimDistance,
	maxAimDistance = FTConfig.THROW_CONFIG.MaxAimDistance,
	duration = FTConfig.THROW_CONFIG.ChargeDuration,
	barMin = 0,
	barMax = 1,
}
local PredictionRuntime = {
	spawnVelocityLead = FTConfig.THROW_CONFIG.SpawnVelocityLeadTime,
	blendTime = FTConfig.THROW_CONFIG.PredictionBlendTime,
	lagCompWindow = FTConfig.THROW_CONFIG.PredictionLagCompWindow,
	expiryBuffer = FTConfig.THROW_CONFIG.PredictionExpiryBuffer,
	releaseDelay = 0.3,
}
local HighlightKeys = {
	ball = "Ball",
	pickup = "BallPickup",
}
local ExtraPointConfig = {
	countdown = 5,
	aimDuration = 20,
	kickWarningCountdown = 3,
	targetDistance = 35,
	oscillationSpeed = 2,
	oscillationRadius = 150,
	ballOffset = 1.5,
	ballHeight = 0.1,
	kickReleaseDelay = 0.12,
	kickPowerScale = 0.72,
	kickMinPower = 20,
	kickBallLockLeadTime = 1.35,
	kickSequenceDuration = 2.9,
	kickMissCameraHoldTime = 2.6,
	kickPostGoalHoldTime = 1.45,
	kickBallCamDistance = 9,
	kickBallCamHeight = 3.15,
	kickBallCamLookHeight = 0.9,
	kickBallCamLerp = 0.09,
	kickBallPosLerp = 0.18,
	kickBallDirLerp = 0.08,
	kickBallMinPlanarSpeed = 6,
	kickPreCamBackDistance = 11.5,
	kickPreCamSideDistance = 4.75,
	kickPreCamHeight = 4.1,
	kickPreCamLookHeight = 1.15,
	kickPreCamBlendDuration = 0.42,
	kickCinematicCamDistance = 7,
	kickCinematicCamHeight = 4.25,
	kickCinematicCamLookHeight = 0.75,
	kickCinematicCamLerp = 0.06,
	kickCinematicPosLerp = 0.12,
	kickCinematicDirLerp = 0.06,
	kickCamDistance = 18,
	kickCamHeight = 5,
	kickCamLookHeight = 2.75,
	kickFovTarget = 100,
	kickFovInTime = 0.28,
	kickFovOutTime = 0.65,
	curveScale = 1,
	curveMax = 0.7,
	stageNone = 0,
	stageCountdown = 1,
	stageAim = 2,
	chargeId = "ExtraPointCharge",
}
local ExtraPointKickTimeoutState = {
	deadline = 0,
	token = 0,
	warningStarted = false,
	autoTriggered = false,
}

local function GetEffectiveMaxAimDistance(): number
	return FlowBuffs.ApplyThrowDistanceBuff(LocalPlayer, ChargeConfig.maxAimDistance)
end

local function GetEffectiveMaxThrowDistance(): number
	return FlowBuffs.ApplyThrowDistanceBuff(LocalPlayer, FTConfig.THROW_CONFIG.MaxThrowDistance)
end

local LocalPredictionState = {
	activeLaunch = nil :: LocalPredictedLaunchState?,
	ballInFlight = false,
	visualDetached = false,
	nextRequestId = 0,
}
local ReleaseTrailState = {
	pending = false,
}
local LocalPrediction = {}

local _GetBallCarrier: () -> Player?
local _CanPlayerAct: () -> boolean
local _EnsureBallEffects: (() -> ())? = nil
local _GetCampoPlaneY: ((Instance) -> number?)? = nil
local _ClearExtraPointStage: (skipCameraRestore: boolean?) -> ()

local function _SetPendingReleaseTrailEnabled(enabled: boolean): ()
	ReleaseTrailState.pending = enabled
	if not TrailInstance then
		return
	end
	if enabled then
		TrailInstance.Enabled = true
	else
		TrailInstance.Enabled = false
	end
end

--\\ PRIVATE FUNCTIONS \\ -- TR
local function _SetPlayerAttribute(attr: string, value: any): ()
	if LocalPlayer then
		LocalPlayer:SetAttribute(attr, value)
	end
	local Character = LocalPlayer.Character
	if Character then
		Character:SetAttribute(attr, value)
	end
end

local function _ApplyCircleVisual(circle: BasePart?, color: Color3): ()
	if not circle then return end
	circle.Color = color
	for _, descendant in ipairs(circle:GetDescendants()) do
		local nameLower = descendant.Name:lower()
		if descendant:IsA("BasePart") then
			if string.find(nameLower, "outline") then
                    descendant.Color = CIRCLE_CONSTS.OUTLINE_COLOR
                    descendant.Transparency = CIRCLE_CONSTS.OUTLINE_TRANSPARENCY
			else
				descendant.Color = color
			end
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			if string.find(nameLower, "outline") then
                    descendant.Color3 = CIRCLE_CONSTS.OUTLINE_COLOR
                    descendant.Transparency = CIRCLE_CONSTS.OUTLINE_TRANSPARENCY
			else
				descendant.Color3 = color
			end
		elseif descendant:IsA("Highlight") then
                descendant.FillColor = color
                descendant.OutlineColor = CIRCLE_CONSTS.OUTLINE_COLOR
                descendant.OutlineTransparency = CIRCLE_CONSTS.OUTLINE_TRANSPARENCY
		elseif descendant:IsA("SelectionBox") then
                descendant.Color3 = CIRCLE_CONSTS.OUTLINE_COLOR
                descendant.SurfaceTransparency = CIRCLE_CONSTS.OUTLINE_TRANSPARENCY
		end
	end
end

local function _GetPartGroundOffsetByPivot(part: BasePart?): number
	if not part then
		return CIRCLE_GROUND_EPSILON
	end

	local half: Vector3 = part.Size * 0.5
	local corners: {Vector3} = {
		Vector3.new(-half.X, -half.Y, -half.Z),
		Vector3.new(half.X, -half.Y, -half.Z),
		Vector3.new(-half.X, -half.Y, half.Z),
		Vector3.new(half.X, -half.Y, half.Z),
		Vector3.new(-half.X, half.Y, -half.Z),
		Vector3.new(half.X, half.Y, -half.Z),
		Vector3.new(-half.X, half.Y, half.Z),
		Vector3.new(half.X, half.Y, half.Z),
	}
	local pivotInverse: CFrame = part.PivotOffset:Inverse()
	local minY: number = math.huge

	for _, corner in ipairs(corners) do
		local cornerInPivotSpace: Vector3 = (pivotInverse * CFrame.new(corner)).Position
		if cornerInPivotSpace.Y < minY then
			minY = cornerInPivotSpace.Y
		end
	end

	if minY == math.huge then
		return CIRCLE_GROUND_EPSILON
	end

	return math.max(-minY + CIRCLE_GROUND_EPSILON, CIRCLE_GROUND_EPSILON)
end

local function _GroundCFrameFromHit(hitPosition: Vector3, groundOffset: number): CFrame
	return CFrame.new(hitPosition + Vector3.new(0, groundOffset, 0))
end

local function _ResolveVisibleCircleGroundCFrame(
	origin: Vector3,
	groundOffset: number,
	filterInstances: {Instance}
): CFrame?
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = filterInstances

	local ray = WORKSPACE:Raycast(origin, Vector3.new(0, -CIRCLE_GROUND_RAY_DISTANCE, 0), params)
	if not ray then
		return nil
	end

	if (origin.Y - ray.Position.Y) > CIRCLE_MAX_VISIBLE_AIR_HEIGHT then
		return nil
	end

	return _GroundCFrameFromHit(ray.Position, groundOffset)
end

local function _CreatePickupHighlight(): Highlight?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	PlayerPickupHighlight = HighlightEffect.EnsureHighlight(HighlightKeys.pickup, {
		Parent = Character,
		Name = "BallPickupHighlight",
		FillColor = Color3.fromRGB(255, 255, 255),
		OutlineColor = Color3.fromRGB(255, 255, 255),
		FillTransparency = 0.5,
		OutlineTransparency = 0.5,
	})
	return PlayerPickupHighlight
end

local function _PlayHighlightFade(key: string, highlight: Highlight?, color: Color3, duration: number): ()
	if not highlight then return end
	HighlightEffect.SetHighlightMode(key, "off")
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.5
	highlight.Enabled = true

	local tween = TweenService:Create(highlight, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		HighlightEffect.ClearHighlight(key)
		if key == HighlightKeys.pickup then
			PlayerPickupHighlight = nil
		end
	end)
end

function FTBallController._TriggerPickupHighlight(): ()
	local highlight = _CreatePickupHighlight()
	if not highlight then return end
	_PlayHighlightFade(HighlightKeys.pickup, highlight, Color3.fromRGB(255, 255, 255), 0.6)
end

function ExtraPointUi.EnsureFadeGui(): (ScreenGui?, Frame?)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil, nil
	end
	if not ExtraPointFadeState.gui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "ExtraPointFadeGui"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 9999
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
		ExtraPointFadeState.gui = gui

		local frame = Instance.new("Frame")
		frame.Name = "Fade"
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = gui
		ExtraPointFadeState.frame = frame
	end
	if ExtraPointFadeState.gui and ExtraPointFadeState.gui.Parent ~= playerGui then
		ExtraPointFadeState.gui.Parent = playerGui
	end
	return ExtraPointFadeState.gui, ExtraPointFadeState.frame
end

function ExtraPointUi.PlayFade(duration: number, onCovered: (() -> ())?): boolean
	local _gui, frame = ExtraPointUi.EnsureFadeGui()
	if not frame then
		return false
	end
	local now = os.clock()
	if now - (ExtraPointFadeState.lastAt or 0) < 0.35 then
		return false
	end
	ExtraPointFadeState.lastAt = now
	ExtraPointFadeState.token += 1
	local token = ExtraPointFadeState.token
	local total = if duration > 0 then duration else 1.0
	local fadeIn = math.clamp(total * 0.45, 0.1, 0.35)
	local fadeOut = math.clamp(total * 0.55, 0.12, 0.45)

	frame.Visible = true
	frame.BackgroundTransparency = 1

	local tweenIn = TweenService:Create(frame, TweenInfo.new(fadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.12,
	})
	tweenIn.Completed:Once(function()
		if ExtraPointFadeState.token ~= token then
			return
		end
		if onCovered then
			onCovered()
		end
		local tweenOut = TweenService:Create(frame, TweenInfo.new(fadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		tweenOut.Completed:Once(function()
			if ExtraPointFadeState.token ~= token then
				return
			end
			frame.Visible = false
		end)
		tweenOut:Play()
	end)
	tweenIn:Play()
	return true
end

function ExtraPointUi.PlayHighlightFade(duration: number): ()
	local total = if duration > 0 then duration else 0.8
	for _, player in PlayersService:GetPlayers() do
		local character = player.Character
		if character then
			local existing = character:FindFirstChild("ExtraPointFadeHighlight")
			if existing then
				existing:Destroy()
			end
			local highlight = Instance.new("Highlight")
			highlight.Name = "ExtraPointFadeHighlight"
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.FillColor = Color3.new(1, 1, 1)
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.FillTransparency = 0.3
			highlight.OutlineTransparency = 0.5
			highlight.Parent = character

			local tween = TweenService:Create(highlight, TweenInfo.new(total, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				FillTransparency = 1,
				OutlineTransparency = 1,
			})
			tween.Completed:Once(function()
				if highlight then
					highlight:Destroy()
				end
			end)
			tween:Play()
		end
	end
end

function FTBallController._GetHumanoid(): Humanoid?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	return Character:FindFirstChildOfClass("Humanoid")
end

function FTBallController._ApplyCatchSpinLock(track: AnimationTrack?)
	local duration = if track and track.Length and track.Length > 0 then track.Length else 0.35
	_SetPlayerAttribute(ATTR.CAN_SPIN, false)
	task.delay(duration, function()
		_SetPlayerAttribute(ATTR.CAN_SPIN, true)
	end)
end

local function _CreatePowerBillboard(Character: Model): ()
	if PowerBillboard then
		PowerBillboard:Destroy()
		PowerBillboard = nil
	end
	if PowerAttachment then
		PowerAttachment:Destroy()
		PowerAttachment = nil
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HumanoidRootPart then return end

	local Assets = REPLICATED_STORAGE:FindFirstChild("Assets")
	local UIFolder = if Assets then Assets:FindFirstChild("UI") else nil
	local BarFolder = if UIFolder then UIFolder:FindFirstChild("Bar1") else nil
	local BarAttachment = if BarFolder then BarFolder:FindFirstChild("Bar") else nil
	if not BarAttachment then return end

	local attachmentClone = BarAttachment:Clone()
	attachmentClone.Name = "PowerBarAttachment"
	attachmentClone.Parent = HumanoidRootPart
	PowerAttachment = attachmentClone

	local billboard = attachmentClone:FindFirstChildWhichIsA("BillboardGui", true)
	if not billboard then return end
	billboard.Adornee = HumanoidRootPart
	billboard.Enabled = false
	PowerBillboard = billboard

	local barFrame = billboard:FindFirstChild("Bar", true) :: Frame?
	if not barFrame then return end
	local fill = barFrame:FindFirstChild("Fill") :: Frame?
	if not fill then return end
	fill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	PowerFill = fill

	local gradient = fill:FindFirstChildWhichIsA("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = fill
	end
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 140, 0)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 0)),
	})
	gradient.Offset = Vector2.new(-1, 0)
	PowerFillGradient = gradient

	if PowerFillGradient then
		PowerFillGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
end

local function _ApplyPowerFillMask(alpha: number): ()
	if not PowerFillGradient then return end
	local clamped = math.clamp(alpha, ChargeConfig.barMin, ChargeConfig.barMax)
	if clamped <= 0 then
		PowerFillGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		return
	end

	local fadeStart = clamped
	local fadeEnd = math.clamp(clamped + 0.001, fadeStart, ChargeConfig.barMax)
	PowerFillGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(fadeStart, 0),
		NumberSequenceKeypoint.new(fadeEnd, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function _UpdatePowerBar(alpha: number): ()
	if not PowerBillboard or not PowerFill then return end

	local clampedAlpha = math.clamp(alpha, ChargeConfig.barMin, ChargeConfig.barMax)
	local targetOffset = Vector2.new(clampedAlpha - 1, 0)

	_ApplyPowerFillMask(clampedAlpha)

	if PowerFillTween then
		PowerFillTween:Cancel()
		PowerFillTween = nil
	end

	if PowerFillGradient then
		if clampedAlpha <= 0 then
			PowerFillGradient.Offset = targetOffset
		else
			PowerFillTween = TweenService:Create(PowerFillGradient, POWER_BAR_TWEEN_INFO, { Offset = targetOffset })
		end
	else
		local newSize = UDim2.new(clampedAlpha, -2, 1, -2)
		if clampedAlpha <= 0 then
			PowerFill.Size = newSize
		else
			PowerFillTween = TweenService:Create(PowerFill, POWER_BAR_TWEEN_INFO, { Size = newSize })
		end
	end
	if PowerFillTween then
		PowerFillTween:Play()
	end

	PowerBillboard.Enabled = true
end

function _ResetPowerBar(): ()
	if not PowerBillboard or not PowerFill then return end

	if PowerFillTween then
		PowerFillTween:Cancel()
		PowerFillTween = nil
	end
	if PowerFillGradient then
		_ApplyPowerFillMask(0)
		PowerFillGradient.Offset = Vector2.new(-1, 0)
	else
		PowerFill.Size = UDim2.new(0, 0, 1, -2)
	end
	PowerBillboard.Enabled = false
end

local function _GetPlayerAttribute(attr: string, fallback: any): any
	local Character = LocalPlayer.Character
	if Character then
		local value = Character:GetAttribute(attr)
		if value ~= nil then
			return value
		end
	end
	local value = LocalPlayer:GetAttribute(attr)
	if value ~= nil then
		return value
	end
	return fallback
end

function FTBallController._GetGoalPartForTeam(team: number): BasePart?
	local gameFolder = WORKSPACE:FindFirstChild("Game")
	if not gameFolder then
		return nil
	end
	local goalFolder = gameFolder:FindFirstChild("Goal")
	if not goalFolder then
		return nil
	end
	local teamPart = goalFolder:FindFirstChild("Team" .. team)
	if not teamPart then
		return nil
	end
	if teamPart:IsA("BasePart") then
		return teamPart
	end
	if teamPart:IsA("Model") and teamPart.PrimaryPart then
		return teamPart.PrimaryPart
	end
	for _, descendant in teamPart:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

function FTBallController._GetOpponentGoalFacingTarget(): Vector3?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HRP then return nil end
	local team = LocalPlayerTeam
	if not team then return nil end
	local goalTeam = if team == 1 then 2 else 1
	local goalPart = FTBallController._GetGoalPartForTeam(goalTeam)
	if not goalPart then return nil end
	return Vector3.new(goalPart.Position.X, HRP.Position.Y, goalPart.Position.Z)
end

function FTBallController._MaintainStunFacing(): boolean
	if _GetPlayerAttribute(ATTR.STUNNED, false) ~= true then
		return false
	end
	local target = FTBallController._GetOpponentGoalFacingTarget()
	if target then
		_UpdateCharacterFacing(target)
		return true
	end
	return false
end

function FTBallController._GetMatchStarted(): boolean
	if not MatchStartedInstance then
		local GameStateFolder = REPLICATED_STORAGE:FindFirstChild("FTGameState")
		if GameStateFolder then
			MatchStartedInstance = GameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
		end
	end
	return if MatchStartedInstance then MatchStartedInstance.Value else false
end

function FTBallController._GetCampo(): Instance?
	local Game = WORKSPACE:FindFirstChild("Game")
	if not Game then return nil end
	return Game:FindFirstChild("Campo")
end

local function _IsGameplayHudSuppressed(): boolean
	return _GetPlayerAttribute("FTCutsceneHudHidden", false) == true
		or _GetPlayerAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED, false) == true
end

local function _IsPlayerActionLocked(): boolean
	return _GetPlayerAttribute("FTSkillLocked", false) == true
		or _GetPlayerAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED, false) == true
end

_CanPlayerAct = function(): boolean
	if not BallVisualUtils.IsLocalPlayerInMatch() then return false end
    if _GetPlayerAttribute("Invulnerable", false) == true then
        return false
    end
	if _IsPlayerActionLocked() then return false end
	if _GetPlayerAttribute(ATTR.CAN_ACT, true) == false then return false end
	if _GetPlayerAttribute(ATTR.CAN_THROW, true) == false then return false end
	return true
end

local function _CanPlayerThrow(): boolean
	if not FTBallController._GetMatchStarted() then return false end
	if not BallVisualUtils.IsLocalPlayerInMatch() then return false end
    if _GetPlayerAttribute("Invulnerable", false) == true then
        return false
    end
	if _IsPlayerActionLocked() then return false end
	if _GetPlayerAttribute(ATTR.CAN_ACT, true) == false then return false end
	if _GetPlayerAttribute(ATTR.CAN_THROW, true) == false then return false end
	return true
end

_GetBallCarrier = function(): Player?
	if not BallCarrierInstance then
		local GameStateFolder = REPLICATED_STORAGE:FindFirstChild("FTGameState")
		if GameStateFolder then
			BallCarrierInstance = GameStateFolder:FindFirstChild("BallCarrier") :: ObjectValue?
		end
	end
	if BallCarrierInstance and BallCarrierInstance.Value then
		return BallCarrierInstance.Value :: Player
	end
	return nil
end

function FTBallController._GetBallDataInstance(): Instance?
	local data = _G.FT_BALL_DATA
	if data and data.Parent then
		return data
	end

	data = REPLICATED_STORAGE:FindFirstChild("FTBallData")
	_G.FT_BALL_DATA = data
	return data
end

function FTBallController._ResolveMarkerGroundCFrame(position: Vector3, groundOffset: number): CFrame
	local gameFolder = WORKSPACE:FindFirstChild("Game")
	local campo = gameFolder and gameFolder:FindFirstChild("Campo")
	if campo then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { campo }
		local ray = WORKSPACE:Raycast(position + Vector3.new(0, 25, 0), Vector3.new(0, -80, 0), params)
		if ray then
			return CFrame.new(ray.Position + Vector3.new(0, groundOffset, 0))
		end
	end

	return CFrame.new(position + Vector3.new(0, groundOffset, 0))
end

local function _GetThrowLandingTarget(): Vector3?
	local prediction = LocalPrediction.GetActiveLaunch(WORKSPACE:GetServerTimeNow())
	if prediction and prediction.solution and typeof(prediction.solution.target) == "Vector3" then
		return prediction.solution.target
	end

	local data = FTBallController._GetBallDataInstance()
	if not data or data:GetAttribute("FTBall_InAir") ~= true then
		return nil
	end

	local target = data:GetAttribute("FTBall_Target")
	if typeof(target) == "Vector3" then
		return target
	end

	return nil
end

function FTBallController._GetStableExtraPointBallPosition(serverNow: number): Vector3?
	local function GetReplicatedBallPosition(): Vector3?
		local realBall = _G.FT_REAL_BALL
		if not realBall or not realBall.Parent then
			local gameFolder = WORKSPACE:FindFirstChild("Game")
			realBall = gameFolder and gameFolder:FindFirstChild("Football")
			_G.FT_REAL_BALL = realBall
		end
		if realBall and realBall:IsA("BasePart") then
			return realBall.Position
		end
		if realBall and realBall:IsA("Model") then
			local part = realBall.PrimaryPart or realBall:FindFirstChildWhichIsA("BasePart")
			if part then
				return part.Position
			end
		end
		return nil
	end

	local function HasExceededNominalFlight(launchTime: number, spawnPos: Vector3, target: Vector3, power: number): boolean
		local distance = (target - spawnPos).Magnitude
		if power <= 0 or distance <= 1e-4 then
			return false
		end
		local flightTime = distance / power
		return (serverNow - launchTime) >= flightTime
	end

	local prediction = LocalPrediction.GetActiveLaunch(serverNow)
	if prediction and prediction.solution then
		local solution = prediction.solution
		if HasExceededNominalFlight(prediction.releaseAt, solution.spawnPos, solution.target, solution.power) then
			local replicatedPosition = GetReplicatedBallPosition()
			if replicatedPosition then
				return replicatedPosition
			end
		end
		return ThrowPrediction.GetPositionAtServerTime(prediction.releaseAt, serverNow, prediction.solution)
	end

	local data = FTBallController._GetBallDataInstance()
	if data and data:GetAttribute("FTBall_InAir") == true then
		local launchTime = data:GetAttribute("FTBall_LaunchTime")
		local spawnPos = data:GetAttribute("FTBall_SpawnPos")
		local target = data:GetAttribute("FTBall_Target")
		local power = data:GetAttribute("FTBall_Power")
		local curve = data:GetAttribute("FTBall_Curve")
		if typeof(launchTime) == "number"
			and typeof(spawnPos) == "Vector3"
			and typeof(target) == "Vector3"
			and typeof(power) == "number" then
			if HasExceededNominalFlight(launchTime, spawnPos, target, power) then
				local replicatedPosition = GetReplicatedBallPosition()
				if replicatedPosition then
					return replicatedPosition
				end
			end
			local elapsed = math.max(0, serverNow - launchTime)
			local util = _G.FT_BALL_UTIL
			if not util then
				util = require(REPLICATED_STORAGE.Modules.Game.Utility)
				_G.FT_BALL_UTIL = util
			end
			return util.GetPositionAtTime(elapsed, spawnPos, target, power, typeof(curve) == "number" and curve or 0.2)
		end
	end

	return BallPart and BallPart.Position or nil
end

function FTBallController._GetRightArmPosition(): Vector3?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	if not RightArm then return nil end
	return (RightArm :: BasePart).Position
end

function FTBallController._GetRightFootPart(): BasePart?
	local Character = LocalPlayer.Character
	if not Character then return nil end
	return Character:FindFirstChild("RightFoot") or Character:FindFirstChild("Right Leg") or Character:FindFirstChild("RightLowerLeg") or Character:FindFirstChild("RightLowerLeg")
end

function FTBallController._GetExtraPointFixedPart(): BasePart?
	if ExtraPointTeam <= 0 then
		return nil
	end
	local gameFolder = WORKSPACE:FindFirstChild("Game")
	if not gameFolder then
		return nil
	end
	local fixedName = if ExtraPointTeam == 1 then "2TeamFixed" else "1TeamFixed"
	local fixedPart = gameFolder:FindFirstChild(fixedName) :: BasePart?
	return fixedPart
end

local function _PlaceBallNearFoot(): ()
	local Character = LocalPlayer.Character
	if not Character or not BallInstance then
		return
	end

	if _EnsureBallEffects then
		_EnsureBallEffects()
	end
	if not BallPart then
		BallPart = BallInstance.PrimaryPart or BallInstance:FindFirstChildWhichIsA("BasePart")
	end
	if not BallPart then
		return
	end

	local hrp = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local foot = FTBallController._GetRightFootPart()
	local forward = (hrp and hrp.CFrame.LookVector) or (foot and foot.CFrame.LookVector) or Vector3.new(0, 0, -1)
	if forward.Magnitude < 1e-4 then
		forward = Vector3.new(0, 0, -1)
	end
	local planarForward = Vector3.new(forward.X, 0, forward.Z)
	if planarForward.Magnitude < 1e-4 then
		planarForward = Vector3.new(0, 0, -1)
	end
	planarForward = planarForward.Unit

	local basePos = (foot and foot.Position) or (hrp and hrp.Position) or Vector3.zero
	local desiredPos = Vector3.new(basePos.X, basePos.Y, basePos.Z) + planarForward * ExtraPointConfig.ballOffset
	local campo = FTBallController._GetCampo()
	local groundY: number? = nil
	if campo then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { campo }
		local hit = WORKSPACE:Raycast(desiredPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
		if hit then
			groundY = hit.Position.Y
		elseif _GetCampoPlaneY then
			groundY = _GetCampoPlaneY(campo)
		end
	end
	local baseHeight = BallPart.Size.Y * 0.5
	local finalY = (groundY or desiredPos.Y) + baseHeight + ExtraPointConfig.ballHeight
	local placement = Vector3.new(desiredPos.X, finalY, desiredPos.Z)
	local orientation = CFrame.lookAt(placement, placement + planarForward) * CFrame.Angles(0, math.rad(-180), 0)

	if BallInstance.PrimaryPart then
		BallInstance:SetPrimaryPartCFrame(orientation)
	else
		BallPart.CFrame = orientation
	end
	BallPart.AssemblyLinearVelocity = Vector3.zero
	BallPart.AssemblyAngularVelocity = Vector3.zero
	if ExtraPointStage ~= ExtraPointConfig.stageNone and _GetBallCarrier() == LocalPlayer then
		_SetPendingReleaseTrailEnabled(true)
	end
end

local function _GetCircleColorForTeam(teamNumber: number?): Color3
	if teamNumber == 2 then
		return CIRCLE_CONSTS.TEAM_TWO_COLOR
	end

	return CIRCLE_CONSTS.TEAM_ONE_COLOR
end

local function _InitializeBallAssets(): ()
	local Assets = REPLICATED_STORAGE:WaitForChild("Assets", 5)
	if not Assets then return end
	local Gameplay = Assets:FindFirstChild("Gameplay")
	if not Gameplay then return end
	local Modelo = Gameplay:FindFirstChild("Modelo")
	if not Modelo then return end
	local BallTemplate = Modelo:FindFirstChild("Bola")
	if BallTemplate then
		PreloadBallRenderAssets(BallTemplate)
	end
	
	local realBall = WORKSPACE.Game:FindFirstChild("Football")
	if realBall then
		_G.FT_REAL_BALL = realBall
		BallVisualUtils.UpdateBallVisualState(realBall)
	else
		BallInstance = nil
		BallPart = nil
	end

	if CircleState.PlayerInstance then
		CircleState.PlayerInstance:Destroy()
		CircleState.PlayerInstance = nil
	end
	if CircleState.BallInstance then
		CircleState.BallInstance:Destroy()
		CircleState.BallInstance = nil
	end
	if AimCircleInstance then
		AimCircleInstance:Destroy()
		AimCircleInstance = nil
	end
	CircleState.PlayerGroundOffset = CIRCLE_GROUND_EPSILON
	CircleState.BallGroundOffset = CIRCLE_GROUND_EPSILON
	AimCircleGroundOffset = CIRCLE_GROUND_EPSILON

	local playerCircleTemplate: BasePart? = nil
	do
		local markerTemplate = Modelo:FindFirstChild("Circle") or Modelo:FindFirstChild("Star") or Modelo:FindFirstChild("Estrela")
		if markerTemplate and not markerTemplate:IsA("BasePart") then
			markerTemplate = markerTemplate:FindFirstChildWhichIsA("BasePart", true)
		end
		if markerTemplate and markerTemplate:IsA("BasePart") then
			playerCircleTemplate = markerTemplate
		end
	end

	local ballCircleTemplate: BasePart? = nil
	do
		local markerTemplate = Modelo:FindFirstChild("Circle2")
			or Modelo:FindFirstChild("Circle")
			or Modelo:FindFirstChild("Star")
			or Modelo:FindFirstChild("Estrela")
		if markerTemplate and not markerTemplate:IsA("BasePart") then
			markerTemplate = markerTemplate:FindFirstChildWhichIsA("BasePart", true)
		end
		if markerTemplate and markerTemplate:IsA("BasePart") then
			ballCircleTemplate = markerTemplate
		end
	end

	if playerCircleTemplate then
		local playerCircle = playerCircleTemplate:Clone() :: BasePart
		playerCircle.Name = "PlayerMarker"
		playerCircle.Anchored = true
		playerCircle.CanCollide = false
		playerCircle.CanTouch = false
		playerCircle.CanQuery = false
		playerCircle.Transparency = 1
		_ApplyCircleVisual(playerCircle, CIRCLE_CONSTS.PLAYER_COLOR)
		for _, descendant in ipairs(playerCircle:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
		CircleState.PlayerGroundOffset = _GetPartGroundOffsetByPivot(playerCircle)
		playerCircle.Parent = WORKSPACE
		CircleState.PlayerInstance = playerCircle
	end

	if ballCircleTemplate then
		local ballCircle = ballCircleTemplate:Clone() :: BasePart
		ballCircle.Name = "BallMarker"
		ballCircle.Anchored = true
		ballCircle.CanCollide = false
		ballCircle.CanTouch = false
		ballCircle.CanQuery = false
		ballCircle.Transparency = 1
		_ApplyCircleVisual(ballCircle, CIRCLE_CONSTS.AIM_COLOR)
		for _, descendant in ipairs(ballCircle:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
		CircleState.BallGroundOffset = _GetPartGroundOffsetByPivot(ballCircle)
		ballCircle.Parent = WORKSPACE
		CircleState.BallInstance = ballCircle
	end

	local aimTemplate = ballCircleTemplate or playerCircleTemplate
	if aimTemplate then
		local aimCircle = aimTemplate:Clone() :: BasePart
		aimCircle.Name = "AimMarker"
		aimCircle.Anchored = true
		aimCircle.CanCollide = false
		aimCircle.CanTouch = false
		aimCircle.CanQuery = false
		aimCircle.Transparency = 1
		_ApplyCircleVisual(aimCircle, CIRCLE_CONSTS.AIM_COLOR)
		for _, descendant in ipairs(aimCircle:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanTouch = false
				descendant.CanQuery = false
			end
		end
		AimCircleGroundOffset = _GetPartGroundOffsetByPivot(aimCircle)
		aimCircle.Parent = WORKSPACE
		AimCircleInstance = aimCircle
	end

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "BeamStart"
	Attachment0 = attachment0

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "BeamEnd"
	Attachment1 = attachment1
	
	local beam = Instance.new("Beam")
	beam.Name = "TrajectoryBeam"
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.Segments = 50
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Transparency = NumberSequence.new(0.2)
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	beam.Parent = WORKSPACE
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	DirectionBeam = beam
end

local function _DestroyBallAssets(): ()
	if CircleState.PlayerInstance then
		CircleState.PlayerInstance:Destroy()
		CircleState.PlayerInstance = nil
	end
	if CircleState.BallInstance then
		CircleState.BallInstance:Destroy()
		CircleState.BallInstance = nil
	end
	if AimCircleInstance then
		AimCircleInstance:Destroy()
		AimCircleInstance = nil
	end
	CircleState.PlayerGroundOffset = CIRCLE_GROUND_EPSILON
	CircleState.BallGroundOffset = CIRCLE_GROUND_EPSILON
	AimCircleGroundOffset = CIRCLE_GROUND_EPSILON
	BallMarkerReady = false
	BallImpactFx.Clear()
end

local function _BuildBallStateSignature(realBall: Instance?): string?
	if not realBall then
		return nil
	end

	local possession = tostring(realBall:GetAttribute("FTBall_Possession") or 0)
	local inAir = tostring(realBall:GetAttribute("FTBall_InAir") == true)
	local onGround = tostring(realBall:GetAttribute("FTBall_OnGround") == true)
	local sequence = tostring(realBall:GetAttribute("FTBall_Seq") or 0)
	return table.concat({possession, inAir, onGround, sequence}, "|")
end

local function _PulseBallStateFov(realBall: Instance?): ()
	local signature = _BuildBallStateSignature(realBall)
	if signature == nil or signature == LastBallStateSignature then
		return
	end

	LastBallStateSignature = signature
	FOVController.AddRequest(BALL_STATE_FOV_REQUEST_ID, 80, nil, {
		TweenInfo = BALL_STATE_FOV_TWEEN,
		Duration = 0.35,
	})
end

_EnsureBallEffects = function(): ()
	if not BallInstance then
		BallPart = nil
		return
	end

	local Part = if BallInstance:IsA("BasePart") then BallInstance else (BallInstance.PrimaryPart or BallInstance:FindFirstChildWhichIsA("BasePart"))
	if not Part or Part == BallPart then
		return
	end

	BallPart = Part
	BallPart.CanCollide = false

	if TrailInstance then
		TrailInstance:Destroy()
		TrailInstance = nil
	end
	if BallHighlight then
		HighlightEffect.ClearHighlight(HighlightKeys.ball)
	end

	local att0 = Instance.new("Attachment")
	att0.Name = "TrailTop"
	att0.Position = Vector3.new(0, Part.Size.Y * 0.5, 0)
	att0.Parent = Part

	local att1 = Instance.new("Attachment")
	att1.Name = "TrailBottom"
	att1.Position = Vector3.new(0, -Part.Size.Y * 0.5, 0)
	att1.Parent = Part

	local trail = REPLICATED_STORAGE.Assets.Gameplay.Modelo.TrailEffect:Clone()
	trail.Name = "BallTrail"
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Enabled = false
	trail.Parent = Part

	TrailInstance = trail

	BallHighlight = HighlightEffect.EnsureHighlight(HighlightKeys.ball, {
		Parent = BallInstance,
		Name = "BallHighlight",
		FillColor = Color3.fromRGB(255, 255, 255),
		OutlineColor = Color3.fromRGB(255, 255, 255),
		FillTransparency = 0.6,
		OutlineTransparency = 0.4,
	})
end

local function _IsBallInAir(): boolean
	if LocalPredictionState.ballInFlight then
		return true
	end
	if _GetBallCarrier() ~= nil then
		return false
	end
	if not BallPart then return false end
	local Campo = FTBallController._GetCampo()
	if not Campo then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Campo }
	local ray = WORKSPACE:Raycast(BallPart.Position, Vector3.new(0, -10, 0), params)
	if not ray then return false end
	return (BallPart.Position.Y - ray.Position.Y) > 1
end

local function _IsBallOverField(): boolean
	if not BallPart then return false end
	local gameFolder = WORKSPACE:FindFirstChild("Game")
	if not gameFolder then return false end
	local filter: {Instance} = {}
	local campo = gameFolder:FindFirstChild("Campo")
	if campo then
		table.insert(filter, campo)
	end
	local campoZone = gameFolder:FindFirstChild("CampoZone")
	if campoZone then
		table.insert(filter, campoZone)
	end
	local endzones = gameFolder:FindFirstChild("Endzones")
	if endzones then
		table.insert(filter, endzones)
	end
	if #filter == 0 then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = filter
	local ray = WORKSPACE:Raycast(BallPart.Position, Vector3.new(0, -2000, 0), params)
	return ray ~= nil
end

local function _UpdateBallCircle(): ()
	local PlayerCircle = CircleState.PlayerInstance
	local BallCircle = CircleState.BallInstance
	local AimCircle = AimCircleInstance
	if not PlayerCircle and not BallCircle and not AimCircle then return end
	if _IsGameplayHudSuppressed() then
		if PlayerCircle then
			PlayerCircle.Transparency = 1
		end
		if BallCircle then
			BallCircle.Transparency = 1
		end
		if AimCircle then
			AimCircle.Transparency = 1
		end
		return
	end

	local Carrier = if LocalPredictionState.visualDetached then nil else _GetBallCarrier()
	local BallData = FTBallController._GetBallDataInstance()
	local ExternalHolder: Model? = nil
	if BallData then
		local ExternalHolderName = BallData:GetAttribute("FTBall_ExternalHolder")
		if typeof(ExternalHolderName) == "string" and ExternalHolderName ~= "" then
			local Candidate = WORKSPACE:FindFirstChild(ExternalHolderName)
			if Candidate and Candidate:IsA("Model") then
				ExternalHolder = Candidate
			end
		end
	end
	local FlightTarget = if ExtraPointActive or ExtraPointKickState.pending or ExtraPointKickState.startTime > 0
		then nil
		else _GetThrowLandingTarget()
	local TargetCFrame: CFrame? = nil
	local ShouldShow = false
	local desiredColor = _GetCircleColorForTeam(LocalPlayerTeam)
	local ActiveCircle: BasePart? = nil
	local ActiveGroundOffset: number = CIRCLE_GROUND_EPSILON

	if not Carrier and FlightTarget then
		local circleForTarget = BallCircle or PlayerCircle or AimCircleInstance
		if not circleForTarget then
			if PlayerCircle then PlayerCircle.Transparency = 1 end
			if BallCircle then BallCircle.Transparency = 1 end
			return
		end
		ActiveCircle = circleForTarget
		if circleForTarget == BallCircle then
			ActiveGroundOffset = CircleState.BallGroundOffset
		elseif circleForTarget == AimCircleInstance then
			ActiveGroundOffset = AimCircleGroundOffset
		else
			ActiveGroundOffset = CircleState.PlayerGroundOffset
		end
		desiredColor = CIRCLE_CONSTS.AIM_COLOR
		TargetCFrame = FTBallController._ResolveMarkerGroundCFrame(FlightTarget, ActiveGroundOffset)
		ShouldShow = true
	elseif not Carrier and ExternalHolder then
		local circleForHolder = PlayerCircle or BallCircle
		if not circleForHolder then
			if PlayerCircle then PlayerCircle.Transparency = 1 end
			if BallCircle then BallCircle.Transparency = 1 end
			return
		end
		ActiveCircle = circleForHolder
		ActiveGroundOffset = if circleForHolder == PlayerCircle then CircleState.PlayerGroundOffset else CircleState.BallGroundOffset
		desiredColor = CIRCLE_CONSTS.AIM_COLOR
		local HolderRoot = (ExternalHolder.PrimaryPart or ExternalHolder:FindFirstChild("HumanoidRootPart") or ExternalHolder:FindFirstChildWhichIsA("BasePart", true)) :: BasePart?
		if HolderRoot then
			local filterInstances = { ExternalHolder, circleForHolder }
			if PlayerCircle and PlayerCircle ~= circleForHolder then
				table.insert(filterInstances, PlayerCircle)
			end
			if BallCircle and BallCircle ~= circleForHolder then
				table.insert(filterInstances, BallCircle)
			end
			TargetCFrame = _ResolveVisibleCircleGroundCFrame(HolderRoot.Position, ActiveGroundOffset, filterInstances)
			if TargetCFrame then
				LastCircleGroundCFrame = TargetCFrame
				ShouldShow = true
			else
				LastCircleGroundCFrame = nil
			end
		end
	elseif Carrier then
		local carrierTeam: number? = nil
		local gameState = REPLICATED_STORAGE:FindFirstChild("FTGameState")
		if gameState then
			local teamValue = gameState:FindFirstChild("PlayerTeam_" .. PlayerIdentity.GetIdValue(Carrier))
			if teamValue and teamValue:IsA("IntValue") then
				carrierTeam = teamValue.Value
			end
		end
		if carrierTeam == nil and Carrier == LocalPlayer then
			carrierTeam = LocalPlayerTeam
		end
		desiredColor = _GetCircleColorForTeam(carrierTeam)
		local CarrierCharacter = Carrier.Character
		local CarrierCutsceneLocked = Carrier:GetAttribute("FTSkillLocked") == true
			or (CarrierCharacter ~= nil and CarrierCharacter:GetAttribute("FTSkillLocked") == true)
		if CarrierCutsceneLocked then
			if PlayerCircle then PlayerCircle.Transparency = 1 end
			if BallCircle then BallCircle.Transparency = 1 end
			return
		end
		local circleForCarrier = PlayerCircle or BallCircle
		if not circleForCarrier then
			if PlayerCircle then PlayerCircle.Transparency = 1 end
			if BallCircle then BallCircle.Transparency = 1 end
			return
		end
		ActiveCircle = circleForCarrier
		ActiveGroundOffset = if circleForCarrier == PlayerCircle then CircleState.PlayerGroundOffset else CircleState.BallGroundOffset
		local Character = Carrier.Character
		if Character then
			local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if Root then
				local filterInstances = { Character, circleForCarrier }
				if PlayerCircle and PlayerCircle ~= circleForCarrier then
					table.insert(filterInstances, PlayerCircle)
				end
				if BallCircle and BallCircle ~= circleForCarrier then
					table.insert(filterInstances, BallCircle)
				end
				TargetCFrame = _ResolveVisibleCircleGroundCFrame(Root.Position, ActiveGroundOffset, filterInstances)
				if TargetCFrame then
					LastCircleGroundCFrame = TargetCFrame
					ShouldShow = true
				else
					LastCircleGroundCFrame = nil
				end
			end
		end
	elseif not Carrier and BallInstance and BallPart and BallMarkerReady then
		local circleForBall = BallCircle or PlayerCircle
		if not circleForBall then
			if PlayerCircle then PlayerCircle.Transparency = 1 end
			if BallCircle then BallCircle.Transparency = 1 end
			return
		end
		ActiveCircle = circleForBall
		ActiveGroundOffset = if circleForBall == BallCircle then CircleState.BallGroundOffset else CircleState.PlayerGroundOffset
		desiredColor = CIRCLE_CONSTS.AIM_COLOR
		local Campo = WORKSPACE.Game:FindFirstChild("Campo")
		if Campo then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { Campo }
			local ray = WORKSPACE:Raycast(BallPart.Position + Vector3.new(0, 5, 0), Vector3.new(0, -10, 0), params)
			if ray then
				TargetCFrame = _GroundCFrameFromHit(ray.Position, ActiveGroundOffset)
				ShouldShow = true
			end
		end
	end

	if PlayerCircle and PlayerCircle ~= ActiveCircle then
		PlayerCircle.Transparency = 1
	end
	if BallCircle and BallCircle ~= ActiveCircle then
		BallCircle.Transparency = 1
	end
	if AimCircleInstance and AimCircleInstance ~= ActiveCircle and not IsChargingThrow then
		AimCircleInstance.Transparency = 1
	end

	if ShouldShow and TargetCFrame and ActiveCircle then
		if ActiveCircle == PlayerCircle then
			local position = TargetCFrame.Position
			TargetCFrame = CFrame.new(position.X, PLAYER_MARKER_FIXED_Y, position.Z)
		end
		local Time = os.clock()
		local Rotation = CFrame.Angles(0, (Time * CIRCLE_ROTATION_SPEED) % (math.pi * 2), 0)
		_ApplyCircleVisual(ActiveCircle, desiredColor)
		ActiveCircle:PivotTo(TargetCFrame * Rotation)
		ActiveCircle.Transparency = 0
	elseif ActiveCircle then
		ActiveCircle.Transparency = 1
	end
end



local function _UpdateBallEffects(): ()
	if not BallPart then return end
	if not BallVisualUtils.IsLocalPlayerInMatch() then return end
	if BallVisualUtils.IsBallCutsceneHidden(_G.FT_REAL_BALL) then
		if TrailInstance then
			TrailInstance.Enabled = false
		end
		HighlightEffect.SetHighlightMode(HighlightKeys.ball, "off")
		return
	end

	if ReleaseTrailState.pending and _GetBallCarrier() ~= LocalPlayer and not BallInAir then
		_SetPendingReleaseTrailEnabled(false)
	end

	if ReleaseTrailState.pending then
		if TrailInstance then
			TrailInstance.Enabled = true
		end
		HighlightEffect.SetHighlightMode(HighlightKeys.ball, "pulse", {
			FillTransparency = HIGHLIGHT_PULSE_MIN,
			OutlineTransparency = HIGHLIGHT_PULSE_MIN,
			PulseMaxTransparency = HIGHLIGHT_PULSE_MAX,
			PulseDuration = 0.8,
		})
		return
	end

	if BallInAir then
		if TrailInstance then
			TrailInstance.Enabled = true
		end
		HighlightEffect.SetHighlightMode(HighlightKeys.ball, "pulse", {
			FillTransparency = HIGHLIGHT_PULSE_MIN,
			OutlineTransparency = HIGHLIGHT_PULSE_MIN,
			PulseMaxTransparency = HIGHLIGHT_PULSE_MAX,
			PulseDuration = 0.8,
		})
	elseif _GetBallCarrier() == nil then
		HighlightEffect.SetHighlightMode(HighlightKeys.ball, "pulse", {
			FillTransparency = HIGHLIGHT_PULSE_MIN,
			OutlineTransparency = HIGHLIGHT_PULSE_MIN,
			PulseMaxTransparency = HIGHLIGHT_PULSE_MAX,
			PulseDuration = 0.8,
		})
	else
		if TrailInstance then
			TrailInstance.Enabled = false
		end
		HighlightEffect.SetHighlightMode(HighlightKeys.ball, "off")
	end
end

local _StopExtraPointKickCinematic: (skipCameraRestore: boolean?) -> () = function()
	return
end
local _StopPreExtraPointCamera: (expectedMode: string?, preserveState: boolean?, skipCameraRestore: boolean?) -> () = function()
	return
end

function FTBallController._RestoreCameraToLocalPlayer(): ()
	if not Camera or PreExtraPointCamState.active then
		return
	end
	_G.CameraScoredGoal = false
	Camera.CameraType = Enum.CameraType.Custom
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Camera.CameraSubject = humanoid
	end
end

local _IsPointInsidePart: (BasePart, Vector3) -> boolean = function(_part: BasePart, _point: Vector3): boolean
	return false
end

function FTBallController._ResolvePreExtraPointLookBasis(character: Model, hrp: BasePart): (Vector3, Vector3)
	local head = character:FindFirstChild("Head") :: BasePart?
	local headPos = (head and head.Position) or (hrp.Position + Vector3.new(0, 2, 0))
	local forward = nil :: Vector3?
	if head then
		local decal = head:FindFirstChildWhichIsA("Decal")
		if decal then
			local localDir = Vector3.new(0, 0, -1)
			if decal.Face == Enum.NormalId.Back then
				localDir = Vector3.new(0, 0, 1)
			elseif decal.Face == Enum.NormalId.Left then
				localDir = Vector3.new(-1, 0, 0)
			elseif decal.Face == Enum.NormalId.Right then
				localDir = Vector3.new(1, 0, 0)
			elseif decal.Face == Enum.NormalId.Top then
				localDir = Vector3.new(0, 1, 0)
			elseif decal.Face == Enum.NormalId.Bottom then
				localDir = Vector3.new(0, -1, 0)
			end
			forward = head.CFrame:VectorToWorldSpace(localDir)
		end
	end
	forward = forward or hrp.CFrame.LookVector
	local flatForward = Vector3.new(forward.X, 0, forward.Z)
	if flatForward.Magnitude < 1e-4 then
		local previousForward = PreExtraPointCamState.forward
		if typeof(previousForward) == "Vector3" and previousForward.Magnitude >= 1e-4 then
			flatForward = previousForward
		else
			flatForward = Vector3.new(0, 0, -1)
		end
	else
		flatForward = flatForward.Unit
	end
	return headPos, flatForward
end

function FTBallController._UpdatePreExtraPointSmoothedState(
	now: number,
	rawFocusPos: Vector3,
	rawForward: Vector3
): (Vector3, Vector3)
	local previousUpdateAt = PreExtraPointCamState.lastUpdateAt or 0
	local deltaTime = math.clamp(now - previousUpdateAt, 1 / 240, 1 / 20)
	if previousUpdateAt <= 0 then
		deltaTime = 1 / 60
	end
	PreExtraPointCamState.lastUpdateAt = now

	local positionAlpha = 1 - math.exp(-10 * deltaTime)
	local directionAlpha = 1 - math.exp(-12 * deltaTime)

	local smoothedFocus = PreExtraPointCamState.focusPos
	if typeof(smoothedFocus) == "Vector3" then
		smoothedFocus = smoothedFocus:Lerp(rawFocusPos, positionAlpha)
	else
		smoothedFocus = rawFocusPos
	end
	PreExtraPointCamState.focusPos = smoothedFocus

	local smoothedForward = PreExtraPointCamState.forward
	if typeof(smoothedForward) == "Vector3" and smoothedForward.Magnitude >= 1e-4 then
		local blendedForward = smoothedForward:Lerp(rawForward, directionAlpha)
		if blendedForward.Magnitude >= 1e-4 then
			smoothedForward = blendedForward.Unit
		else
			smoothedForward = rawForward
		end
	else
		smoothedForward = rawForward
	end
	PreExtraPointCamState.forward = smoothedForward

	return smoothedFocus, smoothedForward
end

local function _UpdatePreExtraPointCamera(now: number): boolean
	if not PreExtraPointCamState.active then
		return false
	end
	if now >= PreExtraPointCamState.untilTime then
		_StopPreExtraPointCamera()
		return true
	end

	local target = PlayerIdentity.ResolvePlayer(PreExtraPointCamState.targetId or 0)
	local character = target and target.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return true
	end

	if Camera.CameraType ~= Enum.CameraType.Scriptable then
		Camera.CameraType = Enum.CameraType.Scriptable
	end

	local duration = math.max(PreExtraPointCamState.duration, 0.1)
	local elapsed = math.max(0, now - (PreExtraPointCamState.untilTime - duration))
	local headPos, flatForward = FTBallController._ResolvePreExtraPointLookBasis(character, hrp)
	if PreExtraPointCamState.mode == "orbit" then
		local lookBase, _ = FTBallController._UpdatePreExtraPointSmoothedState(
			now,
			hrp.Position + Vector3.new(0, 2, 0),
			flatForward
		)
		local t = math.clamp(elapsed / math.max(duration, 0.1), 0, 1)
		local angle = t * math.pi * 2
		local radius = 7
		local height = 2.5
		local offset = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local camPos = lookBase + offset
		Camera.CFrame = CFrame.lookAt(camPos, lookBase, Vector3.yAxis)
	elseif PreExtraPointCamState.mode == "front" then
		local lookAt, smoothedForward = FTBallController._UpdatePreExtraPointSmoothedState(
			now,
			headPos + Vector3.new(0, 0.8, 0),
			flatForward
		)
		local camPos = lookAt + smoothedForward * 6
		Camera.CFrame = CFrame.lookAt(camPos, lookAt, Vector3.yAxis)
	else
		local hrpSizeX = hrp.Size.X
		local offsetDist = hrpSizeX * 3.5
		local lookAt, smoothedForward = FTBallController._UpdatePreExtraPointSmoothedState(
			now,
			hrp.Position + Vector3.new(0, 1.8, 0),
			flatForward
		)
		local camPos = lookAt + smoothedForward * offsetDist
		Camera.CFrame = CFrame.lookAt(camPos, lookAt, Vector3.yAxis)
	end

	return true
end

function FTBallController._IsExtraPointKickFlightActive(): boolean
	local data = FTBallController._GetBallDataInstance()
	if data and data:GetAttribute("FTBall_InAir") == true then
		return true
	end
	if LocalPrediction.GetActiveLaunch(WORKSPACE:GetServerTimeNow()) ~= nil then
		return true
	end
	return LocalPredictionState.ballInFlight
end

local function _UpdateBallCamera(): ()
	local now = os.clock()
	if _UpdatePreExtraPointCamera(now) then
		return
	end
	local forced = now < BallCameraForceUntil
	local kickFlightActive = FTBallController._IsExtraPointKickFlightActive()
	local waitingForExtraPointResolution = ExtraPointStage ~= ExtraPointConfig.stageNone
		and (kickFlightActive or ExtraPointGoalVisualState.result ~= 0)
	local extraPointSequenceActive = (ExtraPointKickState.startTime > 0
		and now < (ExtraPointKickState.startTime + math.max(ExtraPointKickState.duration, 0))
	) or waitingForExtraPointResolution
	if ExtraPointKickState.startTime > 0 and not extraPointSequenceActive then
		_StopExtraPointKickCinematic()
		forced = now < BallCameraForceUntil
	end
	if extraPointSequenceActive then
		if not BallPart then
			if ExtraPointGoalVisualState.result == -1 then
				BallCameraForceUntil = 0
				LocalPrediction.ClearLaunch()
			end
			_StopExtraPointKickCinematic()
			return
		end
		if ExtraPointGoalVisualState.result == -1 and not kickFlightActive then
			BallCameraForceUntil = 0
			LocalPrediction.ClearLaunch()
			_StopExtraPointKickCinematic()
			return
		end
		local serverNow = WORKSPACE:GetServerTimeNow()
		if now >= ExtraPointKickState.kickLookUntil and not ExtraPointKickState.cinematicActive then
			ExtraPointKickState.cinematicActive = true
			FOVController.AddRequest(EXTRA_POINT_KICK_FOV_REQUEST_ID, ExtraPointConfig.kickFovTarget, nil, {
				TweenInfo = TweenInfo.new(ExtraPointConfig.kickFovInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			})
		end
		if Camera.CameraType ~= Enum.CameraType.Scriptable then
			Camera.CameraType = Enum.CameraType.Scriptable
		end
		local ballPos = FTBallController._GetStableExtraPointBallPosition(serverNow) or BallPart.Position
		local launchAxis = ExtraPointKickState.launchAxis
		if typeof(launchAxis) ~= "Vector3" then
			launchAxis = ExtraPointKickState.forward or LastBallCameraDirection
		end
		launchAxis = Vector3.new(launchAxis.X, 0, launchAxis.Z)
		if launchAxis.Magnitude < 1e-4 then
			launchAxis = Vector3.new(0, 0, -1)
		else
			launchAxis = launchAxis.Unit
		end
		ExtraPointKickState.launchAxis = launchAxis

		local launchOrigin = ExtraPointKickState.launchOrigin
		if typeof(launchOrigin) ~= "Vector3" then
			launchOrigin = ExtraPointKickState.anchorPos or ballPos
			ExtraPointKickState.launchOrigin = launchOrigin
		end

		local planarDelta = Vector3.new(ballPos.X - launchOrigin.X, 0, ballPos.Z - launchOrigin.Z)
		local rawTravel = planarDelta:Dot(launchAxis)
		local lateralPlanar = planarDelta - (launchAxis * rawTravel)
		local forwardTravel = math.max(rawTravel, 0)
		ExtraPointKickState.travelProgress = math.max(ExtraPointKickState.travelProgress or 0, forwardTravel)

		local monotonicPlanar = launchOrigin + (launchAxis * ExtraPointKickState.travelProgress) + lateralPlanar
		local anchorTarget = Vector3.new(monotonicPlanar.X, ballPos.Y, monotonicPlanar.Z)
		local targetDir = ExtraPointKickState.forward or launchAxis
		local lastBallPos = ExtraPointKickState.lastBallPos
		local planarMotion = Vector3.zero
		if lastBallPos then
			planarMotion = Vector3.new(anchorTarget.X - lastBallPos.X, 0, anchorTarget.Z - lastBallPos.Z)
		end
		ExtraPointKickState.lastBallPos = anchorTarget
		if planarMotion.Magnitude > 0.05 then
			local motionDir = planarMotion.Unit
			if targetDir.Magnitude < 1e-4 or motionDir:Dot(launchAxis) >= 0.25 then
				targetDir = motionDir
			end
		else
			local velocity = BallPart.AssemblyLinearVelocity
			local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
			if planarVelocity.Magnitude > ExtraPointConfig.kickBallMinPlanarSpeed then
				local velocityDir = planarVelocity.Unit
				if velocityDir:Dot(launchAxis) >= 0.25 then
					targetDir = velocityDir
				end
			end
		end
		if targetDir.Magnitude < 1e-4 then
			targetDir = launchAxis
		end
		local dirLerp = ExtraPointKickState.cinematicActive and ExtraPointConfig.kickCinematicDirLerp
			or ExtraPointConfig.kickBallDirLerp
		local posLerp = ExtraPointKickState.cinematicActive and ExtraPointConfig.kickCinematicPosLerp
			or ExtraPointConfig.kickBallPosLerp
		local camLerp = ExtraPointKickState.cinematicActive and ExtraPointConfig.kickCinematicCamLerp
			or ExtraPointConfig.kickBallCamLerp
		local camDistance = ExtraPointKickState.cinematicActive and ExtraPointConfig.kickCinematicCamDistance
			or ExtraPointConfig.kickBallCamDistance
		local camHeight = ExtraPointKickState.cinematicActive and ExtraPointConfig.kickCinematicCamHeight
			or ExtraPointConfig.kickBallCamHeight
		local lookHeight = ExtraPointKickState.cinematicActive and ExtraPointConfig.kickCinematicCamLookHeight
			or ExtraPointConfig.kickBallCamLookHeight
		local currentDir = ExtraPointKickState.forward
		if currentDir and currentDir.Magnitude > 1e-4 then
			targetDir = currentDir:Lerp(targetDir, dirLerp)
		end
		if targetDir.Magnitude < 1e-4 then
			targetDir = launchAxis
		end
		if targetDir:Dot(launchAxis) < 0.1 then
			targetDir = launchAxis
		end
		ExtraPointKickState.forward = targetDir.Unit
		LastBallCameraDirection = ExtraPointKickState.forward
		local anchorPos = anchorTarget
		if ExtraPointKickState.anchorPos then
			anchorPos = ExtraPointKickState.anchorPos:Lerp(anchorTarget, posLerp)
		end
		ExtraPointKickState.anchorPos = anchorPos
		local camPos = anchorPos - (ExtraPointKickState.forward * camDistance) + Vector3.new(0, camHeight, 0)
		local lookAt = anchorPos + Vector3.new(0, lookHeight, 0)
		local camCF = CFrame.lookAt(camPos, lookAt, Vector3.yAxis)
		local preKickBlendStartAt = ExtraPointKickState.preKickBlendStartAt or 0
		local preKickBlendUntil = ExtraPointKickState.preKickBlendUntil or 0
		local preKickCFrame = ExtraPointKickState.preKickCFrame
		if typeof(preKickCFrame) == "CFrame" and preKickBlendUntil > preKickBlendStartAt and now < preKickBlendUntil then
			local alpha = math.clamp((now - preKickBlendStartAt) / math.max(preKickBlendUntil - preKickBlendStartAt, 1 / 240), 0, 1)
			alpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			camCF = preKickCFrame:Lerp(camCF, alpha)
		elseif now >= preKickBlendUntil then
			ExtraPointKickState.preKickCFrame = nil
			ExtraPointKickState.preKickBlendStartAt = 0
			ExtraPointKickState.preKickBlendUntil = 0
		end
		local transitionElapsed = now - ExtraPointKickState.startTime
		local shouldSnapKickCamera = transitionElapsed <= math.max(ExtraPointConfig.kickReleaseDelay, 0.15)
		if shouldSnapKickCamera and not ExtraPointKickState.cinematicActive then
			Camera.CFrame = camCF
		else
			Camera.CFrame = Camera.CFrame:Lerp(camCF, camLerp)
		end
		return
	end
	if not (BallCameraEnabled or forced) then return end
	if not BallPart then return end
	if not forced and not _CanPlayerAct() then return end
	if not forced and _GetBallCarrier() == LocalPlayer then
		BallCameraEnabled = false
		return
	end

	local ballPos = BallPart.Position
	local velocity = BallPart.AssemblyLinearVelocity
	local targetDir = LastBallCameraDirection
	local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if planarVelocity.Magnitude > 3 then
		targetDir = planarVelocity.Unit
	end
	LastBallCameraDirection = LastBallCameraDirection:Lerp(targetDir, 0.15)
	if LastBallCameraDirection.Magnitude < 1e-4 then
		LastBallCameraDirection = Vector3.new(0, 0, -1)
	end
	local direction = LastBallCameraDirection.Unit

	local camPos = ballPos - direction * 6 + Vector3.new(0, 2, 0)
	local lookAt = ballPos + Vector3.new(0, 1.2, 0) + direction * 10
	local camCF = CFrame.lookAt(camPos, lookAt, Vector3.yAxis)
	Camera.CFrame = Camera.CFrame:Lerp(camCF, 0.12)
end

_StopPreExtraPointCamera = function(expectedMode: string?, preserveState: boolean?, skipCameraRestore: boolean?): ()
	if not PreExtraPointCamState.active then
		return
	end
	if expectedMode and PreExtraPointCamState.mode ~= expectedMode then
		return
	end
	PreExtraPointCamState.active = false
	if PreExtraPointCamState.connection then
		PreExtraPointCamState.connection:Disconnect()
		PreExtraPointCamState.connection = nil
	end
	local prevType = PreExtraPointCamState.prevType
	local prevSubject = PreExtraPointCamState.prevSubject
	local prevShiftlockEnabled = PreExtraPointCamState.prevShiftlockEnabled
	local prevMouseBehavior = PreExtraPointCamState.prevMouseBehavior
	local prevMouseIconEnabled = PreExtraPointCamState.prevMouseIconEnabled
	if preserveState then
		PreExtraPointCamState.targetId = nil
		PreExtraPointCamState.duration = 0
		PreExtraPointCamState.mode = "front"
		return
	end
	PreExtraPointCamState.prevType = nil
	PreExtraPointCamState.prevSubject = nil
	PreExtraPointCamState.prevShiftlockEnabled = nil
	PreExtraPointCamState.prevMouseBehavior = nil
	PreExtraPointCamState.prevMouseIconEnabled = nil
	PreExtraPointCamState.targetId = nil
	PreExtraPointCamState.duration = 0
	PreExtraPointCamState.mode = "front"
	PreExtraPointCamState.focusPos = nil
	PreExtraPointCamState.forward = nil
	PreExtraPointCamState.lastUpdateAt = 0
	if Camera and not skipCameraRestore then
		_G.CameraScoredGoal = false
		Camera.CameraType = prevType or Enum.CameraType.Custom
		if prevSubject and prevSubject.Parent then
			Camera.CameraSubject = prevSubject
		else
			local character = LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				Camera.CameraSubject = humanoid
			end
		end
	end
	if prevMouseBehavior ~= nil then
		USER_INPUT_SERVICE.MouseBehavior = prevMouseBehavior
	end
	if prevMouseIconEnabled ~= nil then
		USER_INPUT_SERVICE.MouseIconEnabled = prevMouseIconEnabled
	end
	if prevShiftlockEnabled ~= nil then
		CameraController:SetShiftlock(prevShiftlockEnabled == true)
	end
end

local function _StartPreExtraPointCamera(targetId: number, duration: number, mode: string?): ()
	if not BallVisualUtils.IsLocalPlayerInMatch() then
		return
	end
	local targetPlayer = PlayerIdentity.ResolvePlayer(targetId)
	if not targetPlayer then
		return
	end
	if PreExtraPointCamState.active then
		_StopPreExtraPointCamera(nil, true)
	end
	PreExtraPointCamState.active = true
	PreExtraPointCamState.untilTime = os.clock() + math.max(duration, 0.1)
	PreExtraPointCamState.duration = math.max(duration, 0.1)
	PreExtraPointCamState.targetId = targetId
	PreExtraPointCamState.mode = mode or "behind"
	PreExtraPointCamState.focusPos = nil
	PreExtraPointCamState.forward = nil
	PreExtraPointCamState.lastUpdateAt = 0
	if PreExtraPointCamState.prevType == nil then
		PreExtraPointCamState.prevType = Camera.CameraType
	end
	if PreExtraPointCamState.prevSubject == nil then
		PreExtraPointCamState.prevSubject = Camera.CameraSubject
	end
	if PreExtraPointCamState.prevShiftlockEnabled == nil then
		PreExtraPointCamState.prevShiftlockEnabled = (_G.CameraShiftlock == true)
	end
	if PreExtraPointCamState.prevMouseBehavior == nil then
		PreExtraPointCamState.prevMouseBehavior = USER_INPUT_SERVICE.MouseBehavior
	end
	if PreExtraPointCamState.prevMouseIconEnabled == nil then
		PreExtraPointCamState.prevMouseIconEnabled = USER_INPUT_SERVICE.MouseIconEnabled
	end
	BallCameraEnabled = false
	BallCameraForceUntil = 0
	if Camera then
		Camera.CameraType = Enum.CameraType.Scriptable
	end
	local targetCharacter = targetPlayer.Character
	local targetHrp = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if targetHrp then
		local headPos, flatForward = FTBallController._ResolvePreExtraPointLookBasis(targetCharacter, targetHrp)
		PreExtraPointCamState.forward = flatForward
		if PreExtraPointCamState.mode == "front" then
			PreExtraPointCamState.focusPos = headPos + Vector3.new(0, 0.8, 0)
		elseif PreExtraPointCamState.mode == "orbit" then
			PreExtraPointCamState.focusPos = targetHrp.Position + Vector3.new(0, 2, 0)
		else
			PreExtraPointCamState.focusPos = targetHrp.Position + Vector3.new(0, 1.8, 0)
		end
		PreExtraPointCamState.lastUpdateAt = os.clock()
	end
	_G.CameraScoredGoal = true
	if _G.CameraShiftlock == true then
		CameraController:SetShiftlock(false)
	end
end

_GetAnimationTrackByName = function(names: {string}): AnimationTrack?
	local Character = LocalPlayer.Character
	if not Character then return nil end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then return nil end

	local Assets = REPLICATED_STORAGE:FindFirstChild("Assets")
	local Gameplay = Assets and Assets:FindFirstChild("Gameplay")
	local Animations = Gameplay and Gameplay:FindFirstChild("Animations")
	if not Animations then return nil end

	for _, name in names do
		local Anim = Animations:FindFirstChild(name)
		if Anim and Anim:IsA("Animation") then
			return Animator:LoadAnimation(Anim)
		end
	end
	return nil
end

local function _GetThrowTrack(): AnimationTrack?
	if ThrowTrack and ThrowTrack.IsPlaying ~= nil then
		return ThrowTrack
	end
	ThrowTrack = _GetAnimationTrackByName(ANIM_NAMES.Throw)
	return ThrowTrack
end

local function _GetShotTrack(): AnimationTrack?
	if ShotTrack and ShotTrack.IsPlaying ~= nil then
		return ShotTrack
	end
	ShotTrack = _GetAnimationTrackByName(ANIM_NAMES.Shot)
	if not ShotTrack then
		return _GetThrowTrack()
	end
	return ShotTrack
end

local function _GetChargeTrack(): AnimationTrack?
	if ChargeTrack and ChargeTrack.IsPlaying ~= nil then
		return ChargeTrack
	end
	ChargeTrack = _GetAnimationTrackByName(ANIM_NAMES.Charge)
	return ChargeTrack
end

local function _GetCatchTrack(animationName: string?): AnimationTrack?
	if typeof(animationName) == "string" and animationName ~= "" then
		CatchTrack = _GetAnimationTrackByName({ animationName })
		if CatchTrack then
			return CatchTrack
		end
	end
	CatchTrack = _GetAnimationTrackByName(ANIM_NAMES.Catch)
	return CatchTrack
end

local function _PlayChargeAnimation(): ()
	local Track = _GetChargeTrack()
	if not Track then return end
	local shouldSuppress = false
	if IsChargingThrow and _GetBallCarrier() == LocalPlayer then
		local controller = require(REPLICATED_STORAGE.Controllers.AnimationController)
		local currentState = if controller.GetCurrentState then controller.GetCurrentState() else ""
		if CHARGE_MOVEMENT_OVERRIDE_STATES[currentState] then
			shouldSuppress = true
		end
	end
	if shouldSuppress then
		Track:AdjustSpeed(1)
		Track.TimePosition = 0
		if Track.IsPlaying then
			Track:Stop(0.1)
		end
		return
	end
	Track.Looped = true
	if not Track.IsPlaying then
		Track:Play(0.1)
		Track.TimePosition = 0
	end
	Track:AdjustSpeed(1)
end

local function _StopChargeAnimation(): ()
	local Track = _GetChargeTrack()
	if not Track then return end
	Track:AdjustSpeed(1)
	Track.TimePosition = 0
	if Track.IsPlaying then
		Track:Stop(0.1)
	end
end

local function _GetChargeShotTrack(): AnimationTrack?
	if ChargeShotTrack and ChargeShotTrack.IsPlaying ~= nil then
		return ChargeShotTrack
	end
	ChargeShotTrack = _GetAnimationTrackByName(ANIM_NAMES.ChargeShot)
	return ChargeShotTrack
end

local function _PlayChargeShotAnimation(): ()
	local Track = _GetChargeShotTrack()
	if not Track then return end
	Track.Looped = true
	if not Track.IsPlaying then
		Track:Play(0.1)
	end
	Track.TimePosition = 0.3
	Track:AdjustSpeed(0)
end

local function _StopChargeShotAnimation(): ()
	local Track = _GetChargeShotTrack()
	if not Track then return end
	Track:AdjustSpeed(1)
	Track.TimePosition = 0
	Track.Looped = false
	if Track.IsPlaying then
		Track:Stop(0.1)
	end
end

local function _PlayThrowAnimation(): AnimationTrack?
	local Track = if ExtraPointActive and ExtraPointStage == ExtraPointConfig.stageAim then _GetShotTrack() else _GetThrowTrack()
	if not Track then return nil end
	Track.Looped = false
	if ExtraPointActive and ExtraPointStage == ExtraPointConfig.stageAim then
		Track.TimePosition = 0
		Track:AdjustSpeed(1)
	else
		local maxOffset = math.max(0, Track.Length - 0.05)
		Track.TimePosition = math.min(0.1, maxOffset)
		Track:AdjustSpeed(1.2)
	end
	Track:Play(0)
	return Track
end

local function _StopAllThrowTracks(stopThrow: boolean): ()
	local tracks = {
		{ track = ThrowTrack, isThrow = true },
		{ track = ShotTrack, isThrow = true },
		{ track = ChargeTrack, isThrow = false },
		{ track = ChargeShotTrack, isThrow = false },
	}
	for _, entry in ipairs(tracks) do
		local track = entry.track
		if track and track.IsPlaying then
			if entry.isThrow and not stopThrow then
				continue
			end
			track:Stop(ANIMATION_FADE_TIME)
		end
	end
end

local function _SetAimCircleHighlightEnabled(enabled: boolean): ()
	if not AimCircleInstance then return end
	for _, descendant in ipairs(AimCircleInstance:GetDescendants()) do
		if descendant:IsA("Highlight") then
			descendant.Enabled = enabled
		elseif descendant:IsA("SelectionBox") then
			descendant.Visible = enabled
		end
	end
end

local function _StopRoleAnimations(): ()
	local Character = LocalPlayer.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then return end
	for _, track in ipairs(Animator:GetPlayingAnimationTracks()) do
		local anim = track.Animation
		local name = (anim and anim.Name) or track.Name or ""
		local lower = string.lower(name)
		if string.find(lower, "qb") or string.find(lower, "lineback") then
			print(("[ANIM STOP] role=%s time=%.2f playing=%s"):format(name, track.TimePosition, tostring(track.IsPlaying)))
			track:Stop(ANIMATION_FADE_TIME)
		end
	end
end

local function _GetExtraPointWalkDuration(): number
	return ExtraPointConfig.countdown + ExtraPointConfig.aimDuration + 2
end

local function _ApplyExtraPointWalkSpeedZero(): ()
	if WalkSpeedController and WalkSpeedController.AddRequest then
		WalkSpeedController.AddRequest("ExtraPointFreeze", 0, _GetExtraPointWalkDuration(), 100)
	elseif WalkSpeedController and WalkSpeedController.SetDefaultWalkSpeed then
		WalkSpeedController.SetDefaultWalkSpeed(0)
	end
end

function FTBallController._UpdateExtraPointMovementFreeze(): ()
	local ContextActionService = game:GetService("ContextActionService")
	local ShouldFreeze: boolean = BallVisualUtils.IsLocalPlayerInMatch()
		and (
			_GetPlayerAttribute(ATTR.EXTRA_POINT_FROZEN, false) == true
			or ExtraPointKickState.pending
			or ExtraPointKickState.startTime > 0
		)

	if not ShouldFreeze then
		if ExtraPointKickState.inputFrozen then
			ContextActionService:UnbindAction("FTBallControllerExtraPointFreeze")
			ExtraPointKickState.inputFrozen = false
		end
		return
	end

	if not ExtraPointKickState.inputFrozen then
		ContextActionService:UnbindAction("FTBallControllerExtraPointFreeze")
		ContextActionService:BindAction("FTBallControllerExtraPointFreeze", function(): Enum.ContextActionResult
			return Enum.ContextActionResult.Sink
		end, false, unpack(Enum.PlayerActions:GetEnumItems()))
		ExtraPointKickState.inputFrozen = true
	end

	local Character = LocalPlayer.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	Humanoid:Move(Vector3.zero, false)
	Humanoid.WalkSpeed = 0
	Humanoid.AutoRotate = false
	if Humanoid.UseJumpPower then
		Humanoid.JumpPower = 0
	else
		Humanoid.JumpHeight = 0
	end
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function _StartExtraPointCountdownVisuals(): ()
	if not CountdownController or not CountdownController.StartCountdown or not CountdownController.UpdateCountdownNumber then
		return
	end
	if ExtraPointCountdownActive then
		return
	end
	ExtraPointCountdownActive = true
	ExtraPointCountdownStartTime = os.clock()
	CountdownController.StartCountdown()
	CountdownController.UpdateCountdownNumber(ExtraPointConfig.countdown)
	task.spawn(function()
		while ExtraPointCountdownActive do
			local elapsed = os.clock() - (ExtraPointCountdownStartTime or os.clock())
			local remaining = math.max(0, math.ceil(ExtraPointConfig.countdown - elapsed))
			CountdownController.UpdateCountdownNumber(remaining)
			if remaining <= 0 then
				break
			end
			task.wait(1)
		end
	end)
end

local function _StopExtraPointCountdownVisuals(): ()
	if not ExtraPointCountdownActive then
		return
	end
	ExtraPointCountdownActive = false
	ExtraPointCountdownStartTime = nil
	if CountdownController and CountdownController.StopCountdown then
		CountdownController.StopCountdown()
	end
end

local function _ResetExtraPointKickTimeoutState(): ()
	ExtraPointKickTimeoutState.token += 1
	ExtraPointKickTimeoutState.deadline = 0
	ExtraPointKickTimeoutState.warningStarted = false
	ExtraPointKickTimeoutState.autoTriggered = false
	if CountdownController and CountdownController.CancelManualCountdown then
		CountdownController.CancelManualCountdown()
	end
end

local function _ForceExtraPointTimeoutKick(): ()
	if not ExtraPointActive or ExtraPointStage ~= ExtraPointConfig.stageAim then
		return
	end
	if not BallVisualUtils.IsLocalPlayerInMatch() then
		return
	end
	if _GetBallCarrier() ~= LocalPlayer or ExtraPointKickState.pending then
		return
	end

	if IsChargingThrow then
		LastChargeAlpha = FTBallController._GetChargeAlpha()
		LastChargeMaxDistance = FTBallController._GetChargeMaxDistance(LastChargeAlpha)
		IsChargingThrow = false
		LockedAimDirection = nil
		_SetPlayerAttribute(ATTR.IS_CHARGING, false)
		_SetPlayerAttribute(ATTR.CAN_SPIN, true)
		_ResetPowerBar()
		_G.CameraBallController = false
		ExtraPointOscillationLocked = false
		if WalkSpeedController and WalkSpeedController.RemoveRequest then
			WalkSpeedController.RemoveRequest(ExtraPointConfig.chargeId)
		end
		if ExtraPointKickState.shiftlockRestorePending then
			ExtraPointKickState.shiftlockRestorePending = false
			if not PreExtraPointCamState.active and _G.CameraScoredGoal ~= true then
				CameraController:SetShiftlock(true)
			end
		end
	end

	local wasPending = ExtraPointKickState.pending
	FTBallController._RequestExtraPointKick()
	if not wasPending
		and not ExtraPointKickState.pending
		and ExtraPointActive
		and ExtraPointStage == ExtraPointConfig.stageAim
		and _GetBallCarrier() == LocalPlayer
	then
		ExtraPointKickTimeoutState.autoTriggered = false
		ExtraPointKickTimeoutState.deadline = os.clock() + 0.25
	end
end

local function _UpdateExtraPointKickTimeout(): ()
	local shouldTrack = BallVisualUtils.IsLocalPlayerInMatch()
		and ExtraPointActive
		and ExtraPointStage == ExtraPointConfig.stageAim
		and _GetBallCarrier() == LocalPlayer
		and not ExtraPointKickState.pending
		and ExtraPointKickState.startTime <= 0

	if not shouldTrack then
		if ExtraPointKickTimeoutState.deadline > 0
			or ExtraPointKickTimeoutState.warningStarted
			or ExtraPointKickTimeoutState.autoTriggered
		then
			_ResetExtraPointKickTimeoutState()
		end
		return
	end

	if ExtraPointKickTimeoutState.deadline <= 0 then
		ExtraPointKickTimeoutState.token += 1
		ExtraPointKickTimeoutState.deadline = os.clock() + ExtraPointConfig.aimDuration
		ExtraPointKickTimeoutState.warningStarted = false
		ExtraPointKickTimeoutState.autoTriggered = false
	end

	local remaining = ExtraPointKickTimeoutState.deadline - os.clock()
	if not ExtraPointKickTimeoutState.warningStarted and remaining <= ExtraPointConfig.kickWarningCountdown then
		ExtraPointKickTimeoutState.warningStarted = true
		local token = ExtraPointKickTimeoutState.token
		task.spawn(function()
			if token ~= ExtraPointKickTimeoutState.token then
				return
			end
			if CountdownController and CountdownController.PlayManualCountdown then
				CountdownController.PlayManualCountdown(ExtraPointConfig.kickWarningCountdown, {
					UseBlur = false,
					ShowGo = false,
					Interval = 1,
				})
			end
		end)
	end

	if remaining <= 0 and not ExtraPointKickTimeoutState.autoTriggered then
		ExtraPointKickTimeoutState.autoTriggered = true
		task.defer(_ForceExtraPointTimeoutKick)
	end
end

local function _ForceCleanupExtraPointLocalState(skipCameraRestore: boolean?): ()
	LocalPrediction.ClearLaunch()
	FOVController.RemoveRequest(EXTRA_POINT_KICK_FOV_REQUEST_ID)
	_StopPreExtraPointCamera(nil, false, skipCameraRestore)
	_ClearExtraPointStage(skipCameraRestore)
	if skipCameraRestore ~= true then
		FTBallController._RestoreCameraToLocalPlayer()
	end
end

_StopExtraPointKickCinematic = function(skipCameraRestore: boolean?): ()
	ExtraPointKickState.cinematicActive = false
	ExtraPointKickState.postGoalActive = false
	ExtraPointKickState.postGoalReleaseAt = 0
	ExtraPointKickState.startTime = 0
	ExtraPointKickState.duration = 0
	ExtraPointKickState.kickLookUntil = 0
	ExtraPointKickState.localPrimeAt = 0
	ExtraPointKickState.anchorPos = nil
	ExtraPointKickState.launchOrigin = nil
	ExtraPointKickState.launchAxis = nil
	ExtraPointKickState.travelProgress = 0
	ExtraPointKickState.forward = nil
	ExtraPointKickState.lastBallPos = nil
	ExtraPointKickState.preKickCFrame = nil
	ExtraPointKickState.preKickBlendStartAt = 0
	ExtraPointKickState.preKickBlendUntil = 0
	ExtraPointKickState.goalPart = nil
	FOVController.RemoveRequest(EXTRA_POINT_KICK_FOV_REQUEST_ID)
	if Camera and not PreExtraPointCamState.active and not skipCameraRestore then
		FTBallController._RestoreCameraToLocalPlayer()
	end
	ExtraPointKickState.prevType = nil
	ExtraPointKickState.prevSubject = nil
	ExtraPointKickState.prevFov = nil
	ExtraPointKickState.fovTween = nil
end

local function _StartExtraPointKickCinematic(kicker: Player?, duration: number): ()
	if not kicker then
		return
	end
	local character = kicker.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local restoreCameraType = Camera and Camera.CameraType or Enum.CameraType.Custom
	local restoreCameraSubject = Camera and Camera.CameraSubject or nil
	if PreExtraPointCamState.active then
		restoreCameraType = PreExtraPointCamState.prevType or restoreCameraType
		restoreCameraSubject = PreExtraPointCamState.prevSubject or restoreCameraSubject
		_StopPreExtraPointCamera(nil, false, true)
	end
	_StopExtraPointKickCinematic(true)
	BallCameraEnabled = false
	_G.CameraBallController = false
	local now = os.clock()
	local releaseLead = math.max(duration, 0.05)
	local sequenceDuration = releaseLead + ExtraPointConfig.kickBallLockLeadTime + ExtraPointConfig.kickSequenceDuration
	BallCameraForceUntil = now + sequenceDuration
	if Camera then
		ExtraPointKickState.prevType = restoreCameraType
		ExtraPointKickState.prevSubject = restoreCameraSubject
		ExtraPointKickState.prevFov = Camera.FieldOfView
		_G.CameraScoredGoal = true
		Camera.CameraType = Enum.CameraType.Scriptable
		if hrp then
			local flatForward = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
			if flatForward.Magnitude < 1e-4 then
				flatForward = Vector3.new(0, 0, -1)
			end
			flatForward = flatForward.Unit
			ExtraPointKickState.forward = flatForward
			ExtraPointKickState.launchAxis = flatForward
			local focusPos = if BallPart then BallPart.Position else hrp.Position
			ExtraPointKickState.anchorPos = focusPos
			ExtraPointKickState.launchOrigin = focusPos
			ExtraPointKickState.travelProgress = 0
			ExtraPointKickState.lastBallPos = focusPos
			local lookAt = focusPos + Vector3.new(0, ExtraPointConfig.kickPreCamLookHeight, 0)
			local right = flatForward:Cross(Vector3.yAxis)
			if right.Magnitude < 1e-4 then
				right = Vector3.new(1, 0, 0)
			else
				right = right.Unit
			end
			local camPos = lookAt
				- flatForward * ExtraPointConfig.kickPreCamBackDistance
				+ right * ExtraPointConfig.kickPreCamSideDistance
				+ Vector3.new(0, ExtraPointConfig.kickPreCamHeight, 0)
			local preKickCFrame = CFrame.lookAt(camPos, lookAt, Vector3.yAxis)
			ExtraPointKickState.preKickCFrame = preKickCFrame
			ExtraPointKickState.preKickBlendStartAt = now
			ExtraPointKickState.preKickBlendUntil = now + math.min(
				ExtraPointConfig.kickPreCamBlendDuration,
				math.max(releaseLead + 0.12, 0.2)
			)
			Camera.CFrame = preKickCFrame
		end
	end
	ExtraPointKickState.cinematicActive = false
	ExtraPointKickState.postGoalActive = false
	ExtraPointKickState.postGoalReleaseAt = 0
	ExtraPointKickState.kickerId = PlayerIdentity.GetIdValue(kicker)
	ExtraPointKickState.startTime = now
	ExtraPointKickState.duration = sequenceDuration
	ExtraPointKickState.kickLookUntil = now + releaseLead + ExtraPointConfig.kickBallLockLeadTime
	local goalTeam = if ExtraPointTeam == 1 then 2 elseif ExtraPointTeam == 2 then 1 else 0
	ExtraPointKickState.goalPart = if goalTeam > 0 then FTBallController._GetGoalPartForTeam(goalTeam) else nil
	if not ExtraPointKickState.anchorPos and BallPart then
		ExtraPointKickState.anchorPos = BallPart.Position
	end
	if not ExtraPointKickState.launchOrigin and ExtraPointKickState.anchorPos then
		ExtraPointKickState.launchOrigin = ExtraPointKickState.anchorPos
	end
	if not ExtraPointKickState.forward then
		ExtraPointKickState.forward = LastBallCameraDirection
	end
	if not ExtraPointKickState.launchAxis then
		ExtraPointKickState.launchAxis = ExtraPointKickState.forward
	end
end

function ExtraPointUi.GetGoalVisualPart(goalTeam: number): BasePart?
	local gameFolder = WORKSPACE:FindFirstChild("Game")
	local goalFolder = gameFolder and gameFolder:FindFirstChild("Goal")
	local teamFolder = goalFolder and goalFolder:FindFirstChild("Team" .. goalTeam)
	if not teamFolder then
		return nil
	end
	local visual = teamFolder:FindFirstChild("Visual")
	if visual and visual:IsA("BasePart") then
		return visual
	end
	if visual and visual:IsA("Model") then
		local primary = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart")
		if primary then
			return primary
		end
	end
	if teamFolder:IsA("BasePart") then
		return teamFolder
	end
	if teamFolder:IsA("Model") then
		local primary = teamFolder.PrimaryPart or teamFolder:FindFirstChildWhichIsA("BasePart")
		if primary then
			return primary
		end
	end
	return nil
end

function ExtraPointUi.ResetGoalVisual(): ()
	local part = ExtraPointGoalVisualState.part
	if part and part.Parent then
		local originalColor = ExtraPointGoalVisualState.originalColor
		local originalTransparency = ExtraPointGoalVisualState.originalTransparency
		if originalColor then
			part.Color = originalColor
		end
		if originalTransparency ~= nil then
			part.Transparency = originalTransparency
		end
	end
	ExtraPointGoalVisualState.part = nil
	ExtraPointGoalVisualState.team = 0
	ExtraPointGoalVisualState.originalColor = nil
	ExtraPointGoalVisualState.originalTransparency = nil
	ExtraPointGoalVisualState.result = 0

    -- Reset the UI contour effects.  If the GameGui.Contorno folder exists,
    -- restore all ImageLabel and Frame descendants to full transparency so
    -- the default UI style applies when no field goal is active.
	local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		local gameGui = playerGui:FindFirstChild("GameGui")
		if gameGui then
			local contorno = gameGui:FindFirstChild("Contorno")
			if contorno then
				for _, inst in contorno:GetDescendants() do
					if inst:IsA("ImageLabel") then
						inst.ImageTransparency = 1
					elseif inst:IsA("Frame") then
						inst.BackgroundTransparency = 1
					end
				end
			end
		end
	end
end

function ExtraPointUi.UpdateGoalVisual(): ()
	if ExtraPointTeam == 0 or ExtraPointStage == ExtraPointConfig.stageNone then
		ExtraPointUi.ResetGoalVisual()
		return
	end
	local goalTeam = if ExtraPointTeam == 1 then 2 else 1
	if ExtraPointGoalVisualState.team ~= goalTeam or not ExtraPointGoalVisualState.part then
		ExtraPointUi.ResetGoalVisual()
		local part = ExtraPointUi.GetGoalVisualPart(goalTeam)
		if not part then
			return
		end
		ExtraPointGoalVisualState.part = part
		ExtraPointGoalVisualState.team = goalTeam
		ExtraPointGoalVisualState.originalColor = part.Color
		ExtraPointGoalVisualState.originalTransparency = part.Transparency
	end
	local part = ExtraPointGoalVisualState.part
	if not part or not part.Parent then
		return
	end
	local color = Color3.fromRGB(255, 230, 0)
	if ExtraPointGoalVisualState.result == 1 then
		color = Color3.fromRGB(30, 255, 0)
	elseif ExtraPointGoalVisualState.result == -1 then
		color = Color3.fromRGB(255, 60, 60)
	end
	part.Color = color
	local pulse = 0.75 + 0.25 * math.sin(os.clock() * 2.5)
	local minTransparency = 0.5
	if ExtraPointGoalVisualState.result == 0 then
		minTransparency = 0.75
	end
	local transparency = math.clamp(pulse, minTransparency, 1)
	part.Transparency = transparency

	local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		local gameGui = playerGui:FindFirstChild("GameGui")
		if gameGui then
			local contorno = gameGui:FindFirstChild("Contorno")
			if contorno then
				for _, inst in contorno:GetDescendants() do
					if inst:IsA("ImageLabel") then
						inst.ImageColor3 = color
						inst.ImageTransparency = transparency
					elseif inst:IsA("Frame") then
						inst.BackgroundColor3 = color
						inst.BackgroundTransparency = transparency
					end
				end
			end
		end
	end
end

_ClearExtraPointStage = function(skipCameraRestore: boolean?): ()
	ExtraPointStage = ExtraPointConfig.stageNone
	ExtraPointTeam = 0
	ExtraPointActive = false
	ExtraPointTarget = nil
	ExtraPointOscillationOffset = 0
	ExtraPointOscillationLocked = false
	ExtraPointGoalVisualState.result = 0
	LockedAimDirection = nil
	LockedReleaseTarget = nil
	FacingHoldUntil = 0
	IsChargingThrow = false
	if ExtraPointKickState.shiftlockRestorePending then
		ExtraPointKickState.shiftlockRestorePending = false
		if not PreExtraPointCamState.active and _G.CameraScoredGoal ~= true then
			CameraController:SetShiftlock(true)
		end
	end
	_SetPlayerAttribute(ATTR.IS_CHARGING, false)
	_SetPlayerAttribute(ATTR.CAN_SPIN, true)
	ChargeStartTime = 0
	LastChargeAlpha = 0
	LastChargeMaxDistance = 0
	ExtraPointCountdownActive = false
	ExtraPointCountdownStartTime = nil
	_ResetExtraPointKickTimeoutState()
	BallCameraForceUntil = 0
	ExtraPointKickState.pending = false
	ExtraPointKickState.trajectoryBeamSuppressed = false
	_SetPendingReleaseTrailEnabled(false)
	ExtraPointKickState.kickerId = nil
	_StopExtraPointKickCinematic(skipCameraRestore)
	ExtraPointUi.ResetGoalVisual()
	if WalkSpeedController and WalkSpeedController.RemoveRequest then
		WalkSpeedController.RemoveRequest("ExtraPointFreeze")
		WalkSpeedController.RemoveRequest(ExtraPointConfig.chargeId)
	end
	if DirectionBeam then
		DirectionBeam.Enabled = false
	end
	if _StopChargeShotAnimation then
		_StopChargeShotAnimation()
	end
	if _StopShotHoldAnimation then
		_StopShotHoldAnimation()
	end
	if _StopChargeAnimation then
		_StopChargeAnimation()
	end
	if _ResetPowerBar then
		_ResetPowerBar()
	end
	if _StopExtraPointCountdownVisuals then
		_StopExtraPointCountdownVisuals()
	end
	_StopAllThrowTracks(false)
	if _ReleaseCharacterFacing then
		_ReleaseCharacterFacing()
	end
	if _ApplyFacingGoalTarget then
		_ApplyFacingGoalTarget(nil)
	end
	if AimCircleInstance then
		AimCircleInstance.Transparency = 1
	end
	_SetAimCircleHighlightEnabled(true)
end

local function _SetExtraPointStage(stage: number, team: number): ()
	_StopPreExtraPointCamera("front")
	_ResetExtraPointKickTimeoutState()
	local prevStage = ExtraPointStage
	if stage == 0 then
		ExtraPointStage = ExtraPointConfig.stageCountdown
	elseif stage == 1 then
		ExtraPointStage = ExtraPointConfig.stageAim
	else
		ExtraPointStage = ExtraPointConfig.stageNone
	end
	ExtraPointTeam = team
	ExtraPointActive = ExtraPointStage == ExtraPointConfig.stageAim
	ExtraPointTarget = nil
	ExtraPointOscillationOffset = 0
	ExtraPointOscillationLocked = false
	ExtraPointKickState.trajectoryBeamSuppressed = false
	if WalkSpeedController and WalkSpeedController.RemoveRequest then
		WalkSpeedController.RemoveRequest("ExtraPointFreeze")
		WalkSpeedController.RemoveRequest(ExtraPointConfig.chargeId)
	end
	_ApplyExtraPointWalkSpeedZero()
	if ExtraPointStage == ExtraPointConfig.stageCountdown then
		if prevStage ~= ExtraPointConfig.stageCountdown then
			if ExtraPointUi.PlayFade(1.1) then
				ExtraPointUi.PlayHighlightFade(0.9)
			end
		end
	end
	if ExtraPointStage == ExtraPointConfig.stageCountdown then
		_StartExtraPointCountdownVisuals()
	else
		_StopExtraPointCountdownVisuals()
	end
	if ExtraPointStage ~= ExtraPointConfig.stageNone then
		_PlaceBallNearFoot()
	end
	if not ExtraPointActive and DirectionBeam then
		DirectionBeam.Enabled = false
	end
end

function FTBallController._ComputeExtraPointTarget(): Vector3?
	if ExtraPointTeam == 0 then
		return nil
	end
	local fixedPart = FTBallController._GetExtraPointFixedPart()
	if fixedPart then
		local heightOffset = BallPart and BallPart.Size.Y * 0.5 or 0
		local basePos = Vector3.new(fixedPart.Position.X, fixedPart.Position.Y + heightOffset + ExtraPointConfig.ballHeight, fixedPart.Position.Z)
		if not ExtraPointOscillationLocked then
			ExtraPointOscillationOffset = math.sin(os.clock() * ExtraPointConfig.oscillationSpeed) * ExtraPointConfig.oscillationRadius
		end
		return basePos + Vector3.new(0, 0, ExtraPointOscillationOffset)
	end
	local goalTeam = if ExtraPointTeam == 1 then 2 else 1
	local gameFolder = WORKSPACE:FindFirstChild("Game")
	local goalFolder = gameFolder and gameFolder:FindFirstChild("Goal")
	local targetFolder = goalFolder and goalFolder:FindFirstChild("Team" .. goalTeam)
	local goalPart = targetFolder and targetFolder:IsA("BasePart") and targetFolder or targetFolder and targetFolder.PrimaryPart
	if not goalPart then
		return nil
	end
	local character = LocalPlayer.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	local direction = Vector3.new(goalPart.Position.X - hrp.Position.X, 0, goalPart.Position.Z - hrp.Position.Z)
	if direction.Magnitude < 1e-4 then
		direction = Vector3.new(0, 0, -1)
	end
	local forward = direction.Unit
	local target = hrp.Position + forward * ExtraPointConfig.targetDistance
	if not ExtraPointOscillationLocked then
		ExtraPointOscillationOffset = math.sin(os.clock() * ExtraPointConfig.oscillationSpeed) * ExtraPointConfig.oscillationRadius
	end
	target = target + Vector3.new(0, 0, ExtraPointOscillationOffset)
	return target
end

function FTBallController._PlayCatchAnimation(animationName: string?): AnimationTrack?
	local Track = _GetCatchTrack(animationName)
	if not Track then return end
	Track.Looped = false
	Track:Play(0.05)
	return Track
end

function _UpdateCharacterFacing(targetPos: Vector3): ()
	local Character = LocalPlayer.Character
	if not Character then return end

	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not HRP or not Humanoid then return end

	local flatTarget = Vector3.new(targetPos.X, HRP.Position.Y, targetPos.Z)
	local targetCF = CFrame.lookAt(HRP.Position, flatTarget)

	Humanoid.AutoRotate = false
	IsFacingLocked = true
	HRP.CFrame = HRP.CFrame:Lerp(targetCF, 0.18)
end

function FTBallController._SnapCharacterFacing(targetPos: Vector3): ()
	local Character = LocalPlayer.Character
	if not Character then return end

	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not HRP or not Humanoid then return end

	local flatTarget = Vector3.new(targetPos.X, HRP.Position.Y, targetPos.Z)
	local targetCF = CFrame.lookAt(HRP.Position, flatTarget, Vector3.yAxis)

	Humanoid.AutoRotate = false
	IsFacingLocked = true
	HRP.CFrame = targetCF
end

function _ReleaseCharacterFacing(): ()
	if not IsFacingLocked then return end
	local Character = LocalPlayer.Character
	if not Character then return end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		Humanoid.AutoRotate = true
	end
	IsFacingLocked = false
end

_IsPointInsidePart = function(part: BasePart, point: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

function _ApplyFacingGoalTarget(team: number): ()
	if typeof(team) ~= "number" then return end
	if team <= 0 then return end
	local goalPart = FTBallController._GetGoalPartForTeam(team)
	if not goalPart then return end
	local Character = LocalPlayer.Character
	if not Character then return end
	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HRP then return end
	local targetPos = Vector3.new(goalPart.Position.X, HRP.Position.Y, goalPart.Position.Z)
	LastThrowTarget = targetPos
	FacingHoldUntil = os.clock() + 2
	_UpdateCharacterFacing(targetPos)
end

function FTBallController._UpdateFacingHold(): ()
	if IsChargingThrow then
		return
	end
	if _G.CameraShiftlock == true then
		_ReleaseCharacterFacing()
		return
	end
	if LastThrowTarget and os.clock() < FacingHoldUntil then
		_UpdateCharacterFacing(LastThrowTarget)
	else
		_ReleaseCharacterFacing()
	end
end

function FTBallController._HandleFacingGoalAttributeChanged(): ()
	local attrValue = _GetPlayerAttribute(ATTR.FACING_GOAL, 0)
	_ApplyFacingGoalTarget(attrValue)
end

function FTBallController._BindFacingGoalAttributeWatcher(): ()
	FTBallController._HandleFacingGoalAttributeChanged()
	if FacingGoalAttributeConnection then
		FacingGoalAttributeConnection:Disconnect()
	end
	FacingGoalAttributeConnection = LocalPlayer:GetAttributeChangedSignal(ATTR.FACING_GOAL):Connect(FTBallController._HandleFacingGoalAttributeChanged)
	LocalPlayer.CharacterAdded:Connect(function()
		task.defer(FTBallController._HandleFacingGoalAttributeChanged)
	end)
end

_GetCampoPlaneY = function(campo: Instance): number?
	if campo:IsA("BasePart") then
		return campo.Position.Y + (campo.Size.Y * 0.5)
	end
	if campo:IsA("Model") then
		local cf, size = campo:GetBoundingBox()
		return cf.Position.Y + (size.Y * 0.5)
	end
	return nil
end

function FTBallController._GetMouseRay(originFallback: Vector3): (Vector3, Vector3)
	local Mouse = LocalPlayer:GetMouse()
	if Camera then
		local ray = Camera:ViewportPointToRay(Mouse.X, Mouse.Y)
		return ray.Origin, ray.Direction
	end
	return originFallback, Vector3.new(0, 0, -1)
end

function FTBallController._GetChargeAlphaFromElapsed(elapsed: number): number
	if ChargeConfig.duration <= 0 then
		return 1
	end
	return math.clamp(elapsed / ChargeConfig.duration, 0, 1)
end

function FTBallController._GetChargeAlpha(): number
	if ChargeStartTime <= 0 then
		return 0
	end
	return FTBallController._GetChargeAlphaFromElapsed(os.clock() - ChargeStartTime)
end

function FTBallController._GetChargeMaxDistance(chargeAlpha: number): number
	local EffectiveMaxAimDistance: number = GetEffectiveMaxAimDistance()
	return ChargeConfig.minAimDistance + (EffectiveMaxAimDistance - ChargeConfig.minAimDistance) * chargeAlpha
end

function LocalPrediction.GetBallOffsetR6(): CFrame
	local offset = _G.FT_BALL_OFFSET_R6
	if not offset then
		offset = CFrame.new(-0.1, -1.3, -0.5) * CFrame.Angles(0, math.rad(90), 0)
		_G.FT_BALL_OFFSET_R6 = offset
	end
	return offset
end

function LocalPrediction.NextThrowRequestId(): number
	LocalPredictionState.nextRequestId = (LocalPredictionState.nextRequestId % 65535) + 1
	return LocalPredictionState.nextRequestId
end

function LocalPrediction.ClearLaunch(): ()
	LocalPredictionState.activeLaunch = nil
	LocalPredictionState.ballInFlight = false
	LocalPredictionState.visualDetached = false
	_SetPendingReleaseTrailEnabled(false)
end

function LocalPrediction.PrimeLaunch(
	solution: {
		spawnPos: Vector3,
		target: Vector3,
		power: number,
		curve: number,
		distance: number,
		flightTime: number,
	},
	releaseAt: number,
	requestId: number,
	source: string
): ()
	_SetPendingReleaseTrailEnabled(false)
	local spinType = ThrowPrediction.ResolveSpinType(requestId)
	LocalPredictionState.activeLaunch = {
		requestId = requestId,
		releaseAt = releaseAt,
		source = source,
		spinType = spinType,
		expiresAt = releaseAt + math.max(solution.flightTime, 0.1) + PredictionRuntime.expiryBuffer,
		solution = solution,
	}
	LocalPredictionState.ballInFlight = true
	LocalPredictionState.visualDetached = true
	if BallPart then
		local cf = CFrame.new(solution.spawnPos)
		local spinFn = FTConfig.BALL_SPIN_TYPES[spinType]
		if spinFn then
			cf = cf * spinFn()
		end
		if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
			BallInstance:SetPrimaryPartCFrame(cf)
		else
			BallPart.CFrame = cf
		end
	end
end

function LocalPrediction.GetActiveLaunch(serverNow: number): LocalPredictedLaunchState?
	local prediction = LocalPredictionState.activeLaunch
	if not prediction then
		return nil
	end
	if serverNow > prediction.expiresAt then
		LocalPrediction.ClearLaunch()
		return nil
	end
	if serverNow + (1 / 240) < prediction.releaseAt then
		return nil
	end
	return prediction
end

function LocalPrediction.GetPredictedBallCFrame(serverNow: number): CFrame?
	local prediction = LocalPrediction.GetActiveLaunch(serverNow)
	if not prediction then
		return nil
	end
	local position = ThrowPrediction.GetPositionAtServerTime(prediction.releaseAt, serverNow, prediction.solution)
	local cf = CFrame.new(position)
	local spinFn = FTConfig.BALL_SPIN_TYPES[prediction.spinType]
	if spinFn then
		cf = cf * spinFn()
	end
	return cf
end

function LocalPrediction.ResolveThrowSolutionFromCharacter(
	character: Model,
	target: Vector3,
	curveFactor: number
)
	local releaseState = ThrowPrediction.GetCharacterReleaseState(
		character,
		BallPart and BallPart.Position or nil,
		LocalPrediction.GetBallOffsetR6()
	)
	if not releaseState then
		return nil
	end
	return ThrowPrediction.ResolveLaunchFromReleaseState(
		releaseState,
		target,
		curveFactor,
		PredictionRuntime.spawnVelocityLead,
		{
			MaxDistance = GetEffectiveMaxThrowDistance(),
		}
	)
end

function LocalPrediction.ResolveThrowSolutionFromBasePos(basePos: Vector3, target: Vector3, curveFactor: number)
	return ThrowPrediction.ResolveLaunchFromReleaseState({
		basePos = basePos,
		planarVelocity = Vector3.zero,
	}, target, curveFactor, 0, {
		MaxDistance = GetEffectiveMaxThrowDistance(),
	})
end

function LocalPrediction.ConfirmLaunch(requestOwnerId: any, requestId: any): boolean
	local prediction = LocalPredictionState.activeLaunch
	if not prediction then
		return false
	end
	if typeof(requestOwnerId) ~= "number" or typeof(requestId) ~= "number" then
		return false
	end
	if requestOwnerId ~= PlayerIdentity.GetLocalIdValue() then
		return false
	end
	if requestId ~= prediction.requestId then
		return false
	end
	LocalPredictionState.activeLaunch = nil
	return true
end

function FTBallController._GetCurveFactor(aimDirection: Vector3, distance: number, chargeAlpha: number, maxDistance: number): number
	local heightFactor = math.clamp(aimDirection.Y, 0, 1)
	local baseCurve = 0.18
	local extraCurve = 0.32
	local curveFactor = baseCurve + heightFactor * extraCurve
	local distanceFactor = if maxDistance > 0 then math.clamp(distance / maxDistance, 0, 1) else 0

	local longThrowBoost = 1 + (chargeAlpha * distanceFactor * 0.35)
	local shortThrowReduction = 1 - (chargeAlpha * (1 - distanceFactor) * 0.45)
	local chargeBoost = 1 + (chargeAlpha * 0.35)

	local result = curveFactor * longThrowBoost * shortThrowReduction * chargeBoost
	if ExtraPointActive then
		result = math.min(result * ExtraPointConfig.curveScale, ExtraPointConfig.curveMax)
	end
	return result
end

function FTBallController._RaycastCampo(rayOrigin: Vector3, direction: Vector3, maxDistance: number, campo: Instance): Vector3?
	if direction.Magnitude < 1e-4 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { campo }
	local ray = WORKSPACE:Raycast(rayOrigin, direction.Unit * maxDistance, params)
	return if ray then ray.Position else nil
end

function FTBallController._GetFallbackTarget(origin: Vector3, direction: Vector3, campo: Instance, distance: number, lastTarget: Vector3?): Vector3?
	if distance <= 0 then
		return nil
	end
	local planeY = if _GetCampoPlaneY then _GetCampoPlaneY(campo) else nil
	if not planeY then
		return lastTarget
	end
	local planarDir = Vector3.new(direction.X, 0, direction.Z)
	if planarDir.Magnitude < 1e-4 then
		if not lastTarget then
			return nil
		end
		planarDir = Vector3.new(lastTarget.X - origin.X, 0, lastTarget.Z - origin.Z)
	end
	if planarDir.Magnitude < 1e-4 then
		return nil
	end
	planarDir = planarDir.Unit
	local target = origin + planarDir * distance
	return Vector3.new(target.X, planeY, target.Z)
end

function FTBallController._GetAimTarget(origin: Vector3, maxDistance: number, campo: Instance, rayOrigin: Vector3, direction: Vector3): (Vector3?, number?, boolean)
	local hitPos = FTBallController._RaycastCampo(rayOrigin, direction, maxDistance, campo)
	if not hitPos then
		return nil, nil, false
	end
	local clampedDistance = (hitPos - origin).Magnitude
	if clampedDistance < ChargeConfig.minAimDistance then
		local safeDirection = if direction.Magnitude > 1e-4 then direction.Unit else Vector3.new(0, 0, -1)
		hitPos = origin + safeDirection * ChargeConfig.minAimDistance
		clampedDistance = ChargeConfig.minAimDistance
	end
	return hitPos, clampedDistance, true
end

function FTBallController._SetAimMarkerTarget(target: Vector3): ()
	if not AimCircleInstance then
		return
	end
	local rotation = CFrame.Angles(0, (os.clock() * CIRCLE_ROTATION_SPEED) % (math.pi * 2), 0)
	local markerTarget = target + Vector3.new(0, AimCircleGroundOffset, 0)
	AimCircleInstance:PivotTo(CFrame.new(markerTarget) * rotation)
	AimCircleInstance.Transparency = 0
end

function FTBallController._HideTrajectoryVisuals(): ()
	if DirectionBeam then
		DirectionBeam.Enabled = false
	end
	if Attachment0 then
		Attachment0.Parent = nil
	end
	if Attachment1 then
		Attachment1.Parent = nil
	end
	if AimCircleInstance then
		AimCircleInstance.Transparency = 1
	end
end

function FTBallController._SetTrajectoryBeamSuppressed(enabled: boolean): ()
	ExtraPointKickState.trajectoryBeamSuppressed = enabled
	if enabled then
		FTBallController._HideTrajectoryVisuals()
		_SetAimCircleHighlightEnabled(false)
	end
end

function FTBallController._ShowExtraPointPendingBeam(target: Vector3, curveFactor: number): boolean
	if not DirectionBeam or not Attachment0 or not Attachment1 then
		return false
	end
	if ExtraPointKickState.trajectoryBeamSuppressed then
		FTBallController._HideTrajectoryVisuals()
		return false
	end
	local character = LocalPlayer.Character
	if not character then
		FTBallController._HideTrajectoryVisuals()
		return false
	end
	local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	local startPart = BallPart or rightArm
	if not startPart then
		FTBallController._HideTrajectoryVisuals()
		return false
	end

	local startPos = startPart.Position
	local curveDistance = (target - startPos).Magnitude
	if curveDistance < 1e-4 then
		curveDistance = ExtraPointConfig.targetDistance
	end

	Attachment0.Parent = startPart
	Attachment0.Position = if startPart == BallPart then Vector3.zero else Vector3.new(0, -1, 0)
	Attachment1.Parent = WORKSPACE.Terrain
	Attachment1.WorldPosition = target
	DirectionBeam.Enabled = true
	DirectionBeam.CurveSize0 = curveDistance * curveFactor
	DirectionBeam.CurveSize1 = 0
	Attachment0.WorldAxis = Vector3.new(0, 1, 0)
	if AimCircleInstance then
		AimCircleInstance.Transparency = 1
	end
	return true
end

function FTBallController._UpdateTrajectoryBeamExtraPoint(Character: Model): boolean
	if not ExtraPointActive or _GetBallCarrier() ~= LocalPlayer then
		return false
	end

	if ExtraPointKickState.trajectoryBeamSuppressed then
		_PlaceBallNearFoot()
		FTBallController._HideTrajectoryVisuals()
		_SetAimCircleHighlightEnabled(false)
		return true
	end

	if ExtraPointKickState.pending then
		_PlaceBallNearFoot()
		FTBallController._HideTrajectoryVisuals()
		_SetAimCircleHighlightEnabled(false)
		return true
	end

	_PlaceBallNearFoot()
	local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	if not RightArm then
		FTBallController._HideTrajectoryVisuals()
		return true
	end

	local target = FTBallController._ComputeExtraPointTarget()
	if not target then
		FTBallController._HideTrajectoryVisuals()
		return true
	end

	ExtraPointTarget = target
	LockedReleaseTarget = target
	local startPart = BallPart or RightArm
	local startPos = startPart and startPart.Position or RightArm.Position
	local throwDirection = target - startPos
	local aimDirection = throwDirection.Magnitude > 1e-4 and throwDirection.Unit or Vector3.new(0, 0, -1)
	LockedAimDirection = aimDirection
	Attachment0.Parent = startPart
	Attachment0.Position = if startPart == BallPart then Vector3.zero else Vector3.new(0, -1, 0)
	Attachment1.Parent = WORKSPACE.Terrain
	Attachment1.WorldPosition = target
	FTBallController._SetAimMarkerTarget(target)
	_SetAimCircleHighlightEnabled(false)
	_UpdateCharacterFacing(target)
	DirectionBeam.Enabled = true

	local curveDistance = (target - startPos).Magnitude
	if curveDistance < 1e-4 then
		curveDistance = ExtraPointConfig.targetDistance
	end
	local chargeAlpha = if IsChargingThrow then FTBallController._GetChargeAlpha() else 0
	local chargeMaxDistance = FTBallController._GetChargeMaxDistance(chargeAlpha)
	LastChargeAlpha = chargeAlpha
	LastChargeMaxDistance = chargeMaxDistance
	if IsChargingThrow then
		_UpdatePowerBar(chargeAlpha)
	else
		_ResetPowerBar()
	end
	local curveFactor = FTBallController._GetCurveFactor(aimDirection, curveDistance, chargeAlpha, chargeMaxDistance)
	DirectionBeam.CurveSize0 = curveDistance * curveFactor
	DirectionBeam.CurveSize1 = 0
	Attachment0.WorldAxis = Vector3.new(0, 1, 0)
	return true
end

function FTBallController._UpdateTrajectoryBeamStandard(Character: Model): ()
	if ExtraPointKickState.trajectoryBeamSuppressed then
		FTBallController._HideTrajectoryVisuals()
		_ResetPowerBar()
		_ReleaseCharacterFacing()
		return
	end
	if not IsChargingThrow or _GetBallCarrier() ~= LocalPlayer then
		FTBallController._HideTrajectoryVisuals()
		_ResetPowerBar()
		_ReleaseCharacterFacing()
		return
	end

	local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	if not RightArm then
		return
	end

	local campo = WORKSPACE.Game:FindFirstChild("Campo")
	if not campo then
		return
	end

	local rayOrigin, rayDirection = FTBallController._GetMouseRay(RightArm.Position)
	local aimDirection = rayDirection.Magnitude > 1e-4 and rayDirection.Unit or Vector3.new(0, 0, -1)
	if IsChargingThrow and LockedAimDirection then
		aimDirection = LockedAimDirection:Lerp(aimDirection, 1)
	end
	local chargeAlpha = FTBallController._GetChargeAlpha()
	local chargeMaxDistance = FTBallController._GetChargeMaxDistance(chargeAlpha)
	local aimTarget, distance, isValid = FTBallController._GetAimTarget(
		RightArm.Position,
		GetEffectiveMaxAimDistance(),
		campo,
		rayOrigin,
		aimDirection
	)
	if isValid and aimTarget and distance then
		LastAimTarget = aimTarget
		LastAimDistance = distance
	end
	LastChargeAlpha = chargeAlpha
	LastChargeMaxDistance = chargeMaxDistance
	_PlayChargeAnimation()
	_UpdatePowerBar(chargeAlpha)

	local maxReachDistance = math.clamp(chargeMaxDistance, ChargeConfig.minAimDistance, GetEffectiveMaxAimDistance())
	local targetDistance = if isValid and distance then math.min(distance, maxReachDistance) else maxReachDistance
	local targetToUse = if isValid and aimTarget then aimTarget else FTBallController._GetFallbackTarget(RightArm.Position, aimDirection, campo, targetDistance, LastAimTarget)
	if isValid and aimTarget and distance and distance > maxReachDistance then
		targetToUse = FTBallController._GetFallbackTarget(RightArm.Position, aimDirection, campo, maxReachDistance, LastAimTarget)
	end
	if not targetToUse then
		FTBallController._HideTrajectoryVisuals()
		_ReleaseCharacterFacing()
		return
	end

	LockedReleaseTarget = targetToUse
	Attachment0.Parent = RightArm
	Attachment0.Position = Vector3.new(0, -1, 0)
	Attachment1.Parent = WORKSPACE.Terrain
	Attachment1.WorldPosition = targetToUse

	FTBallController._SetAimMarkerTarget(targetToUse)
	_UpdateCharacterFacing(targetToUse)
	DirectionBeam.Enabled = true

	local curveDistance = if isValid and distance then math.min(distance, maxReachDistance) else maxReachDistance
	local curveFactor = FTBallController._GetCurveFactor(aimDirection, curveDistance, chargeAlpha, chargeMaxDistance)
	DirectionBeam.CurveSize0 = curveDistance * curveFactor
	DirectionBeam.CurveSize1 = 0
	Attachment0.WorldAxis = Vector3.new(0, 1, 0)
end

function FTBallController._UpdateTrajectoryBeam(): ()
	if not DirectionBeam or not Attachment0 or not Attachment1 then return end
	if ExtraPointKickState.trajectoryBeamSuppressed
		and not ExtraPointActive
		and not ExtraPointKickState.pending
		and ExtraPointKickState.startTime <= 0 then
		ExtraPointKickState.trajectoryBeamSuppressed = false
	end
	if ExtraPointKickState.trajectoryBeamSuppressed then
		FTBallController._HideTrajectoryVisuals()
		_ResetPowerBar()
		_ReleaseCharacterFacing()
		return
	end
	if _IsGameplayHudSuppressed() then
		FTBallController._HideTrajectoryVisuals()
		_ResetPowerBar()
		_ReleaseCharacterFacing()
		return
	end
	local Character = LocalPlayer.Character
	if not Character then
		FTBallController._HideTrajectoryVisuals()
		return
	end
	if not ExtraPointActive then
		_SetAimCircleHighlightEnabled(true)
	end
	if FTBallController._UpdateTrajectoryBeamExtraPoint(Character) then
		return
	end
	FTBallController._UpdateTrajectoryBeamStandard(Character)
end

function FTBallController._GetFieldCenterPosition(): Vector3?
	local gameFolder = WORKSPACE:FindFirstChild("Game")
	if not gameFolder then
		return nil
	end
	local yardFolder = gameFolder:FindFirstChild("Jardas")
	if not yardFolder then
		return nil
	end
	local g1 = yardFolder:FindFirstChild("GTeam1") :: BasePart?
	local g2 = yardFolder:FindFirstChild("GTeam2") :: BasePart?
	if not g1 or not g2 then
		return nil
	end
	local centerX = (g1.Position.X + g2.Position.X) * 0.5
	local centerZ = (g1.Position.Z + g2.Position.Z) * 0.5
	local centerY = (g1.Position.Y + g2.Position.Y) * 0.5
	return Vector3.new(centerX, centerY, centerZ)
end

function FTBallController._GetCountdownFacingTarget(): Vector3?
	local center = FTBallController._GetFieldCenterPosition()
	local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local matchStarted = FTBallController._GetMatchStarted()
	local facingGoal = _GetPlayerAttribute(ATTR.FACING_GOAL, 0)
	if facingGoal and facingGoal > 0 then
		if not hrp then
			local now = os.clock()
			if now - LastCountdownFacingWarn > 2 then
				LastCountdownFacingWarn = now
				print("[COUNTDOWN FACING] HRP not found to orient the character.")
			end
		else
			local goalPart = FTBallController._GetGoalPartForTeam(facingGoal)
			if goalPart then
				return Vector3.new(goalPart.Position.X, hrp.Position.Y, goalPart.Position.Z)
			else
				local now = os.clock()
				if now - LastCountdownFacingWarn > 2 then
					LastCountdownFacingWarn = now
					print(("[COUNTDOWN FACING] Goal Team %s not found."):format(tostring(facingGoal)))
				end
			end
		end
	end
	if center and hrp then
		if not matchStarted then
			return Vector3.new(center.X, hrp.Position.Y, center.Z)
		end
		local dir = Vector3.new(center.X - hrp.Position.X, 0, center.Z - hrp.Position.Z)
		if dir.Magnitude < 1e-4 then
			return Vector3.new(center.X, hrp.Position.Y, center.Z)
		end
		local opposite = hrp.Position - dir
		return Vector3.new(opposite.X, hrp.Position.Y, opposite.Z)
	end
	local team = LocalPlayerTeam
	if not team then
		return nil
	end
	local goalTeam = if matchStarted then team else (team == 1 and 2 or 1)
	local goalPart = FTBallController._GetGoalPartForTeam(goalTeam)
	if not goalPart or not hrp then
		return goalPart and goalPart.Position or nil
	end
	return Vector3.new(goalPart.Position.X, hrp.Position.Y, goalPart.Position.Z)
end

function FTBallController._MaintainCountdownFacing(): ()
	if not CountdownActive then
		return
	end
	if not BallVisualUtils.IsLocalPlayerInMatch() then
		_ReleaseCharacterFacing()
		return
	end
	local target = FTBallController._GetCountdownFacingTarget()
	if not target then
		local now = os.clock()
		if now - LastCountdownFacingWarn > 2 then
			LastCountdownFacingWarn = now
			print("[COUNTDOWN FACING] Target not found to orient the character.")
		end
		return
	end
	FTBallController._SnapCharacterFacing(target)
end

function FTBallController._BindPlayerTeamValue(value: IntValue): ()
	if PlayerTeamValueConnection then
		PlayerTeamValueConnection:Disconnect()
		PlayerTeamValueConnection = nil
	end
	LocalPlayerTeam = value.Value
	PlayerTeamValueConnection = value.Changed:Connect(function(Value)
		LocalPlayerTeam = Value
	end)
end

function FTBallController._WatchPlayerTeamValue(gameState: Folder?): ()
	if not gameState then
		return
	end
	local activeName: string? = nil
	local childConnection: RBXScriptConnection? = nil

	local function bindForId(id: number): ()
		local targetName = "PlayerTeam_" .. id
		activeName = targetName
		if childConnection then
			childConnection:Disconnect()
			childConnection = nil
		end
		local existing = gameState:FindFirstChild(targetName) :: IntValue?
		if existing then
			FTBallController._BindPlayerTeamValue(existing)
		end
		childConnection = gameState.ChildAdded:Connect(function(child)
			if child.Name == targetName and child:IsA("IntValue") then
				FTBallController._BindPlayerTeamValue(child)
			end
		end)
		if childConnection then
			table.insert(GameStateConnections, childConnection)
		end
	end

	bindForId(PlayerIdentity.GetLocalIdValue())

	local attrConnection = LocalPlayer:GetAttributeChangedSignal("FTSessionId"):Connect(function()
		local currentId = PlayerIdentity.GetLocalIdValue()
		local expectedName = "PlayerTeam_" .. currentId
		if activeName ~= expectedName then
			bindForId(currentId)
		end
	end)
	table.insert(GameStateConnections, attrConnection)
end

function FTBallController._HandleThrowRelease(): ()
	IsChargingThrow = false
	LockedAimDirection = nil
	_SetPlayerAttribute(ATTR.IS_CHARGING, false)
	_SetPlayerAttribute(ATTR.CAN_SPIN, true)
	_StopChargeAnimation()
	if not _CanPlayerThrow() then 
		return 
	end

	if _GetBallCarrier() ~= LocalPlayer then 
		return 
	end

	local Character = LocalPlayer.Character
	if not Character then return end

	local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	if not RightArm then return end

	local campo = WORKSPACE.Game:FindFirstChild("Campo")
	if not campo then return end

	local maxDistance = if LastChargeMaxDistance > 0 then LastChargeMaxDistance else GetEffectiveMaxAimDistance()
	local throwTarget = LockedReleaseTarget
	local isValid = throwTarget ~= nil
	local aimTarget: Vector3? = nil
	if ExtraPointActive and ExtraPointTarget then
		throwTarget = ExtraPointTarget
		isValid = true
	elseif not throwTarget then
		local rayOrigin, rayDirection = FTBallController._GetMouseRay(RightArm.Position)
		local _unusedDistance: number? = nil
		aimTarget, _unusedDistance, isValid = FTBallController._GetAimTarget(
			RightArm.Position,
			maxDistance,
			campo,
			rayOrigin,
			rayDirection
		)
		throwTarget = if isValid and aimTarget then aimTarget else FTBallController._GetFallbackTarget(RightArm.Position, rayDirection, campo, LastAimDistance, LastAimTarget)
	end
	if not throwTarget then 
		return 
	end

	local throwDirection = throwTarget - ((BallPart and BallPart.Position) or RightArm.Position)
	local aimDirection = throwDirection.Magnitude > 1e-4 and throwDirection.Unit or Vector3.new(0, 0, -1)
	local throwDistance = throwDirection.Magnitude
	local capturedChargeAlpha = LastChargeAlpha
	local requestId = LocalPrediction.NextThrowRequestId()
	LastThrowTarget = throwTarget
	_SetPendingReleaseTrailEnabled(true)
	local throwTrack = _PlayThrowAnimation()
	local facingHoldDuration = 1
	if throwTrack and throwTrack.Length > 0 then
		local trackSpeed = throwTrack.Speed
		if trackSpeed <= 0 then
			trackSpeed = 1
		end
		facingHoldDuration = math.max(0.2, (throwTrack.Length - throwTrack.TimePosition) / trackSpeed)
	end
	FacingHoldUntil = os.clock() + facingHoldDuration
	task.spawn(function()
		task.wait(PredictionRuntime.releaseDelay)
		if _GetBallCarrier() ~= LocalPlayer then
			_SetPendingReleaseTrailEnabled(false)
			return
		end
		if not _CanPlayerThrow() then
			_SetPendingReleaseTrailEnabled(false)
			return
		end
		local releaseStartPos = (BallPart and BallPart.Position) or (FTBallController._GetRightArmPosition())
		if not releaseStartPos then
			_SetPendingReleaseTrailEnabled(false)
			return
		end
		local releaseDirection = throwTarget - releaseStartPos
		local releaseAimDirection = releaseDirection.Magnitude > 1e-4 and releaseDirection.Unit or Vector3.new(0, 0, -1)
		local releaseCurve = FTBallController._GetCurveFactor(releaseAimDirection, releaseDirection.Magnitude, capturedChargeAlpha, maxDistance)
		local solution = LocalPrediction.ResolveThrowSolutionFromBasePos(releaseStartPos, throwTarget, releaseCurve)
		if not solution then
			return
		end
		local serverReleaseTime = WORKSPACE:GetServerTimeNow()
		LastThrowTarget = solution.target
		LocalPrediction.PrimeLaunch(solution, serverReleaseTime, requestId, "throw")
		Packets.BallThrow:Fire(solution.target, solution.power, solution.curve, serverReleaseTime, requestId, solution.spawnPos)
		SoundController:Play("Throw")
	end)
	LockedReleaseTarget = nil
end

function FTBallController._RequestExtraPointKick(): ()
	if ExtraPointKickState.pending then
		return
	end
	if not _CanPlayerThrow() then
		return
	end
	if _GetBallCarrier() ~= LocalPlayer then
		return
	end
	local Character = LocalPlayer.Character
	if not Character then return end
	local RightArm = Character:FindFirstChild("Right Arm") or Character:FindFirstChild("RightHand")
	if not RightArm then return end
	local campo = WORKSPACE.Game:FindFirstChild("Campo")
	if not campo then return end

	local maxDistance = if LastChargeMaxDistance > 0 then LastChargeMaxDistance else GetEffectiveMaxAimDistance()
	local throwTarget = LockedReleaseTarget
	local isValid = throwTarget ~= nil
	local aimTarget: Vector3? = nil
	if ExtraPointActive and ExtraPointTarget then
		throwTarget = ExtraPointTarget
		isValid = true
	elseif not throwTarget then
		local rayOrigin, rayDirection = FTBallController._GetMouseRay(RightArm.Position)
		local _unusedDistance: number? = nil
		aimTarget, _unusedDistance, isValid = FTBallController._GetAimTarget(
			RightArm.Position,
			maxDistance,
			campo,
			rayOrigin,
			rayDirection
		)
		throwTarget = if isValid and aimTarget then aimTarget else FTBallController._GetFallbackTarget(RightArm.Position, rayDirection, campo, LastAimDistance, LastAimTarget)
	end
	if not throwTarget then
		return
	end

	local throwDirection = throwTarget - ((BallPart and BallPart.Position) or RightArm.Position)
	local aimDirection = throwDirection.Magnitude > 1e-4 and throwDirection.Unit or Vector3.new(0, 0, -1)
	local throwDistance = throwDirection.Magnitude
	local capturedChargeAlpha = LastChargeAlpha
	local capturedCurve = FTBallController._GetCurveFactor(aimDirection, throwDistance, capturedChargeAlpha, maxDistance)

	local requestId = LocalPrediction.NextThrowRequestId()
	local releaseStartPos = (BallPart and BallPart.Position) or (FTBallController._GetRightArmPosition())
	if not releaseStartPos then
		return
	end
	local releaseDirection = throwTarget - releaseStartPos
	local releaseAimDirection = releaseDirection.Magnitude > 1e-4 and releaseDirection.Unit or Vector3.new(0, 0, -1)
	local releaseCurve = FTBallController._GetCurveFactor(releaseAimDirection, releaseDirection.Magnitude, capturedChargeAlpha, maxDistance)
	local solution = LocalPrediction.ResolveThrowSolutionFromBasePos(releaseStartPos, throwTarget, releaseCurve)
	if not solution then
		return
	end
	if not ExtraPointActive or ExtraPointStage ~= ExtraPointConfig.stageAim then
		return
	end
	if _GetBallCarrier() ~= LocalPlayer then
		return
	end
	if not _CanPlayerThrow() then
		return
	end
	solution.power = math.max(ExtraPointConfig.kickMinPower, solution.power * ExtraPointConfig.kickPowerScale)
	solution.flightTime = solution.distance / math.max(solution.power, 0.05)
	FTBallController._SetTrajectoryBeamSuppressed(true)
	ExtraPointKickState.pending = true
	ExtraPointKickState.kickerId = PlayerIdentity.GetLocalIdValue()
	ExtraPointKickState.localPrimeAt = os.clock()
	_StartExtraPointKickCinematic(LocalPlayer, ExtraPointConfig.kickReleaseDelay)
	task.wait()
	if not ExtraPointActive or ExtraPointStage ~= ExtraPointConfig.stageAim then
		FTBallController._SetTrajectoryBeamSuppressed(false)
		ExtraPointKickState.pending = false
		_StopExtraPointKickCinematic()
		return
	end
	if _GetBallCarrier() ~= LocalPlayer then
		FTBallController._SetTrajectoryBeamSuppressed(false)
		ExtraPointKickState.pending = false
		_StopExtraPointKickCinematic()
		return
	end
	if not _CanPlayerThrow() then
		FTBallController._SetTrajectoryBeamSuppressed(false)
		ExtraPointKickState.pending = false
		_StopExtraPointKickCinematic()
		return
	end
	_StopChargeShotAnimation()
	LastThrowTarget = throwTarget
	_SetPendingReleaseTrailEnabled(true)
	local throwTrack = _PlayThrowAnimation()
	local facingHoldDuration = 1
	if throwTrack and throwTrack.Length > 0 then
		local trackSpeed = throwTrack.Speed
		if trackSpeed <= 0 then
			trackSpeed = 1
		end
		facingHoldDuration = math.max(0.2, (throwTrack.Length - throwTrack.TimePosition) / trackSpeed)
	end
	FacingHoldUntil = os.clock() + facingHoldDuration

	local serverReleaseTime = WORKSPACE:GetServerTimeNow() + ExtraPointConfig.kickReleaseDelay
	LastThrowTarget = solution.target
	FTBallController._HideTrajectoryVisuals()
	Packets.ExtraPointKickRequest:Fire(solution.target, solution.power, solution.curve, serverReleaseTime, requestId, solution.spawnPos)
	task.delay(ExtraPointConfig.kickReleaseDelay, function()
		if ExtraPointKickState.pending then
			LocalPrediction.PrimeLaunch(solution, serverReleaseTime, requestId, "extraPoint")
		end
		if ExtraPointKickState.pending or LocalPredictionState.activeLaunch ~= nil then
			SoundController:Play("Throw")
		end
	end)
end

function BallVisualUtils.DisableTrailAndHighlight(instance: Instance): ()
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("Trail") or descendant:IsA("Highlight") then
			descendant.Enabled = false
		end
	end
end

function BallVisualUtils.ConfigureVisualBall(visual: Instance): ()
	if visual:IsA("BasePart") then
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
		visual.Massless = true
		visual.LocalTransparencyModifier = 0
		BallVisualUtils.DisableTrailAndHighlight(visual)
		return
	end
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.LocalTransparencyModifier = 0
		elseif descendant:IsA("Trail") or descendant:IsA("Highlight") then
			descendant.Enabled = false
		end
	end
end

function BallVisualUtils.ConfigureRealBall(realBall: Instance): ()
	if realBall:IsA("BasePart") then
		realBall.LocalTransparencyModifier = 1
		BallVisualUtils.DisableTrailAndHighlight(realBall)
		return
	end
	for _, descendant in ipairs(realBall:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("Trail") or descendant:IsA("Highlight") then
			descendant.Enabled = false
		end
	end
end

function BallVisualUtils.IsBallCutsceneHidden(realBall: Instance?): boolean
	if realBall and realBall:GetAttribute("FTBall_CutsceneHidden") == true then
		return true
	end
	local data = _G.FT_BALL_DATA
	if not data or not data.Parent then
		data = REPLICATED_STORAGE:FindFirstChild("FTBallData")
		_G.FT_BALL_DATA = data
	end
	return data ~= nil and data:GetAttribute("FTBall_CutsceneHidden") == true
end

function BallVisualUtils.SetVisualBallHidden(visual: Instance?, hidden: boolean): ()
	if not visual then
		return
	end

	local transparency: number = if hidden then 1 else 0
	if visual:IsA("BasePart") then
		visual.LocalTransparencyModifier = transparency
	else
		for _, descendant in ipairs(visual:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = transparency
			end
		end
	end

	if TrailInstance then
		TrailInstance.Enabled = false
	end
	HighlightEffect.SetHighlightMode(HighlightKeys.ball, "off")
end

function BallVisualUtils.GetVisualBall(realBall: Instance): Instance
	PreloadBallRenderAssets(realBall)
	local visual = _G.FT_VISUAL_BALL
	if not visual or not visual.Parent then
		visual = realBall:Clone()
		visual.Name = "FootballVisual"
		visual.Parent = WORKSPACE
		_G.FT_VISUAL_BALL = visual
	end
	PreloadBallRenderAssets(visual)
	return visual
end

function BallVisualUtils.UpdateBallVisualState(realBall: Instance): ()
	local visual = BallVisualUtils.GetVisualBall(realBall)
	BallInstance = visual :: Model?
	BallPart = nil
	if visual and visual.Parent then
		BallVisualUtils.ConfigureVisualBall(visual)
	end
	BallVisualUtils.SetVisualBallHidden(visual, BallVisualUtils.IsBallCutsceneHidden(realBall))
	BallVisualUtils.ConfigureRealBall(realBall)
end

function FTBallController._HandleBallStateUpdate(): ()
	local realBall = WORKSPACE.Game:FindFirstChild("Football")
	if realBall then
		_G.FT_REAL_BALL = realBall
		if not CircleState.PlayerInstance or not CircleState.BallInstance or not AimCircleInstance then
			_InitializeBallAssets()
		end
		BallVisualUtils.UpdateBallVisualState(realBall)
		_PulseBallStateFov(realBall)
	else
		BallInstance = nil
		BallPart = nil
		LastBallStateSignature = nil
		BallMarkerReady = false
		_DestroyBallAssets()
	end
	if _EnsureBallEffects then
		_EnsureBallEffects()
	end
	local carrier = _GetBallCarrier()
	if carrier ~= LastCarrier then
		if carrier ~= LocalPlayer then
			_StopAllThrowTracks(false)
		end
		if carrier == LocalPlayer then
			FTBallController._TriggerPickupHighlight()
		end
		LastCarrier = carrier
	end
end

--\\ PUBLIC FUNCTIONS \\ -- TR

function FTBallController.Start(_self: typeof(FTBallController)): ()
	CountdownController.Start()
	_InitializeBallAssets()
	local Character = LocalPlayer.Character
	if Character then
		_CreatePowerBillboard(Character)
	end
	LocalPlayer.CharacterAdded:Connect(function(newCharacter)
		_CreatePowerBillboard(newCharacter)
	end)
	FTBallController._BindFacingGoalAttributeWatcher()
	_SetPlayerAttribute(ATTR.CAN_ACT, true)
	_SetPlayerAttribute(ATTR.CAN_THROW, true)
	_SetPlayerAttribute(ATTR.CAN_SPIN, true)
	Packets.BallStateUpdate.OnClientEvent:Connect(FTBallController._HandleBallStateUpdate)
	Packets.ThrowPassCatch.OnClientEvent:Connect(function(animationName: string)
		local track = FTBallController._PlayCatchAnimation(animationName)
		FTBallController._ApplyCatchSpinLock(track)
	end)
	Packets.DebugResetReport.OnClientEvent:Connect(function(report: {[string]: any})
		if type(report) ~= "table" then return end

		local lines = { "[DEBUG RESET]" }
		if report.success == false then
			table.insert(lines, "Failed to run debug reset.")
			if report.message then
				table.insert(lines, tostring(report.message))
			end
		else
			table.insert(lines, ("Current yard: %.2f | LOS: %.2f"):format(tonumber(report.currentYard) or 0, tonumber(report.lineYard) or 0))
			if report.playGain then
				table.insert(lines, ("Gain on this play: %.2f yards"):format(tonumber(report.playGain) or 0))
			end
			if report.seriesGain then
				table.insert(lines, ("Drive gain: %.2f yards | Remaining: %.2f"):format(tonumber(report.seriesGain) or 0, tonumber(report.yardsRemaining) or 0))
			end
			if report.currentDown and report.maxDowns then
				table.insert(lines, ("Down: %s / %s"):format(tostring(report.currentDown), tostring(report.maxDowns)))
			end
			if report.targetYard then
				table.insert(lines, ("First down at: yard %.2f"):format(tonumber(report.targetYard) or 0))
			end
			if report.possessionTeam then
				table.insert(lines, ("Possession: Team %s"):format(tostring(report.possessionTeam)))
			end
		end
	end)
	Packets.ExtraPointStart.OnClientEvent:Connect(function(stage: number, team: number)
		if not BallVisualUtils.IsLocalPlayerInMatch() then
			_ForceCleanupExtraPointLocalState()
			return
		end
		_SetExtraPointStage(stage, team)
	end)
	Packets.ExtraPointEnd.OnClientEvent:Connect(function()
		if not BallVisualUtils.IsLocalPlayerInMatch() then
			_ForceCleanupExtraPointLocalState()
			return
		end
		FOVController.RemoveRequest(EXTRA_POINT_KICK_FOV_REQUEST_ID)
		local wasActive = ExtraPointStage ~= ExtraPointConfig.stageNone
		local restoredCamera = false
		local function RestoreCameraAfterTransitionCover(): ()
			if restoredCamera then
				return
			end
			restoredCamera = true
			FTBallController._RestoreCameraToLocalPlayer()
		end
		LocalPrediction.ClearLaunch()
		_ClearExtraPointStage(true)
		if wasActive then
			if ExtraPointUi.PlayFade(1.1, RestoreCameraAfterTransitionCover) then
				ExtraPointUi.PlayHighlightFade(0.9)
			else
				RestoreCameraAfterTransitionCover()
			end
		else
			RestoreCameraAfterTransitionCover()
		end
	end)
	Packets.ExtraPointResult.OnClientEvent:Connect(function(success: boolean)
		if not BallVisualUtils.IsLocalPlayerInMatch() then
			return
		end
		ExtraPointGoalVisualState.result = success and 1 or -1
		if success then
			FOVController.RemoveRequest(EXTRA_POINT_KICK_FOV_REQUEST_ID)
		end
		if not success then
			local missHoldUntil = os.clock() + ExtraPointConfig.kickMissCameraHoldTime
			BallCameraForceUntil = math.max(BallCameraForceUntil, missHoldUntil)
			if ExtraPointKickState.startTime > 0 then
				local sequenceEndAt = ExtraPointKickState.startTime + math.max(ExtraPointKickState.duration, 0)
				if missHoldUntil > sequenceEndAt then
					ExtraPointKickState.duration = missHoldUntil - ExtraPointKickState.startTime
				end
			end
		end
	end)
	Packets.ExtraPointPreCam.OnClientEvent:Connect(function(playerId: number, duration: number, mode: string?)
		if not BallVisualUtils.IsLocalPlayerInMatch() then
			return
		end
		if typeof(playerId) ~= "number" then
			return
		end
		local camDuration = if typeof(duration) == "number" and duration > 0 then duration else 5
		local camMode = mode or "front"
		TouchdownWaveTransitionCoordinator.WaitForCovered(1.5, 0.2)
		_StartPreExtraPointCamera(playerId, camDuration, camMode)
	end)
	Packets.ExtraPointKickCinematic.OnClientEvent:Connect(function(kickerId: number, duration: number)
		if not BallVisualUtils.IsLocalPlayerInMatch() then
			return
		end
		local kicker = PlayerIdentity.ResolvePlayer(kickerId)
		if kicker == LocalPlayer
			and ExtraPointKickState.localPrimeAt > 0
			and (os.clock() - ExtraPointKickState.localPrimeAt) <= 0.35
		then
			return
		end
		local releaseLead = if typeof(duration) == "number" and duration > 0 then duration else ExtraPointConfig.kickReleaseDelay
		_StartExtraPointKickCinematic(kicker, releaseLead)
	end)
	local GameState = REPLICATED_STORAGE:FindFirstChild("FTGameState")
	if GameState then
        FTBallController._WatchPlayerTeamValue(GameState)
		local CountdownActiveValue = GameState:FindFirstChild("CountdownActive") :: BoolValue?
		if CountdownActiveValue then
			CountdownActive = CountdownActiveValue.Value
			table.insert(GameStateConnections, CountdownActiveValue.Changed:Connect(function(Value)
				CountdownActive = Value
				if CountdownActive then
					FTBallController._MaintainCountdownFacing()
				else
					IsChargingThrow = false
					_SetPendingReleaseTrailEnabled(false)
					if ExtraPointKickState.shiftlockRestorePending then
						ExtraPointKickState.shiftlockRestorePending = false
						if not PreExtraPointCamState.active and _G.CameraScoredGoal ~= true then
							CameraController:SetShiftlock(true)
						end
					end
					LockedAimDirection = nil
					_SetPlayerAttribute(ATTR.IS_CHARGING, false)
					_SetPlayerAttribute(ATTR.CAN_SPIN, true)
					_StopChargeShotAnimation()
					_StopChargeAnimation()
					_StopAllThrowTracks(true)
					_StopRoleAnimations()
					_ResetPowerBar()
					_ReleaseCharacterFacing()
				end
			end))
		end
	end

	LocalPlayer:GetAttributeChangedSignal("FTSessionId"):Connect(function()
		if not MatchPlayerUtils.IsPlayerActive(LocalPlayer) then
			_ForceCleanupExtraPointLocalState()
		end
	end)
	LocalPlayer:GetAttributeChangedSignal(MatchPlayerUtils.GetMatchActiveAttributeName()):Connect(function()
		if not MatchPlayerUtils.IsPlayerActive(LocalPlayer) then
			_ForceCleanupExtraPointLocalState()
		end
	end)

	USER_INPUT_SERVICE.InputBegan:Connect(function(Input, _GameProcessed)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			
			local Carrier = _GetBallCarrier()
			if Carrier == LocalPlayer and FTBallController._GetMatchStarted() then


				if not _CanPlayerAct() then 
					return 
				end
				if ExtraPointKickState.pending then
					return
				end

				if ExtraPointStage == ExtraPointConfig.stageCountdown then
					return
				end

				IsChargingThrow = true
				local aimOrigin = FTBallController._GetRightArmPosition() or Vector3.new()
				local _rayOrigin, rayDirection = FTBallController._GetMouseRay(aimOrigin)
				LockedAimDirection = rayDirection.Magnitude > 1e-4 and rayDirection.Unit or Vector3.new(0, 0, -1)
				ChargeStartTime = os.clock()
				LastChargeAlpha = 0
				LastChargeMaxDistance = FTBallController._GetChargeMaxDistance(0)
				_UpdatePowerBar(0)
				_StopRoleAnimations()
				_SetPlayerAttribute(ATTR.IS_CHARGING, true)
				_SetPlayerAttribute(ATTR.CAN_SPIN, false)
				if ExtraPointActive and ExtraPointStage == ExtraPointConfig.stageAim then
					_PlayChargeShotAnimation()
				else
					_PlayChargeAnimation()
				end
				_G.CameraBallController = true
				ExtraPointKickState.shiftlockRestorePending = (_G.CameraShiftlock == true)
				if ExtraPointKickState.shiftlockRestorePending then
					CameraController:SetShiftlock(false)
				end
				if ExtraPointActive and ExtraPointStage == ExtraPointConfig.stageAim then
					ExtraPointOscillationLocked = true
					if WalkSpeedController and WalkSpeedController.AddRequest then
						WalkSpeedController.AddRequest(ExtraPointConfig.chargeId, 0.1, ExtraPointConfig.aimDuration, 30)
					end
				end
			end
		elseif Input.KeyCode == Enum.KeyCode.B then
			if _GetBallCarrier() == LocalPlayer then
				BallCameraEnabled = false
			else
				BallCameraEnabled = not BallCameraEnabled
			end
		elseif Input.KeyCode == Enum.KeyCode.K then
			Packets.DebugResetRequest:Fire()
		end
	end)
	
	USER_INPUT_SERVICE.InputEnded:Connect(function(Input, _)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			if IsChargingThrow then
				LastChargeAlpha = FTBallController._GetChargeAlpha()
				LastChargeMaxDistance = FTBallController._GetChargeMaxDistance(LastChargeAlpha)
				IsChargingThrow = false
				LockedAimDirection = nil
				_SetPlayerAttribute(ATTR.IS_CHARGING, false)
				_SetPlayerAttribute(ATTR.CAN_SPIN, true)
				if ExtraPointActive and ExtraPointStage == ExtraPointConfig.stageAim then
					_ResetPowerBar()
					_G.CameraBallController = false
					ExtraPointOscillationLocked = false
					if WalkSpeedController and WalkSpeedController.RemoveRequest then
						WalkSpeedController.RemoveRequest(ExtraPointConfig.chargeId)
					end
					FTBallController._RequestExtraPointKick()
				else
					_StopChargeAnimation()
					_ResetPowerBar()
					_G.CameraBallController = false
					if DirectionBeam then
						DirectionBeam.Enabled = false
					end
					FTBallController._HandleThrowRelease()
				end
				if ExtraPointKickState.shiftlockRestorePending then
					ExtraPointKickState.shiftlockRestorePending = false
					if not PreExtraPointCamState.active and _G.CameraScoredGoal ~= true then
						CameraController:SetShiftlock(true)
					end
				end
			end
		end
	end)
	
RunService.RenderStepped:Connect(function()
	if _EnsureBallEffects then
		_EnsureBallEffects()
	end
	FTBallController._UpdateExtraPointMovementFreeze()
	local realBall = _G.FT_REAL_BALL
	if not realBall or not realBall.Parent then
		local gameFolder = WORKSPACE:FindFirstChild("Game")
		if gameFolder then
			realBall = gameFolder:FindFirstChild("Football")
			_G.FT_REAL_BALL = realBall
		end
	end
	if realBall and (not BallInstance or not BallInstance.Parent) then
		FTBallController._HandleBallStateUpdate()
	end
	local data = _G.FT_BALL_DATA
	if not data or not data.Parent then
		data = REPLICATED_STORAGE:FindFirstChild("FTBallData")
		_G.FT_BALL_DATA = data
	end
	local serverNow = WORKSPACE:GetServerTimeNow()
	local predictedCFrame: CFrame? = nil
	LocalPredictionState.ballInFlight = false
	LocalPredictionState.visualDetached = false
	if BallPart then
		predictedCFrame = LocalPrediction.GetPredictedBallCFrame(serverNow)
		LocalPredictionState.ballInFlight = predictedCFrame ~= nil
	end
	if data and BallPart then
		BallVisualUtils.SetVisualBallHidden(BallInstance, BallVisualUtils.IsBallCutsceneHidden(realBall))
		local dataInAir = data:GetAttribute("FTBall_InAir") == true
		local possession = data:GetAttribute("FTBall_Possession")
		local externalHolder = data:GetAttribute("FTBall_ExternalHolder")
		if not dataInAir and (typeof(possession) ~= "number" or possession <= 0) then
			local carrier = _GetBallCarrier()
			if carrier then
				possession = PlayerIdentity.GetIdValue(carrier)
			end
		end
		local dataOnGround = data:GetAttribute("FTBall_OnGround") == true
		local function ApplyFromRealBall(): ()
			local fallback = realBall
			if not fallback then
				return
			end
			local part = if fallback:IsA("BasePart") then fallback else (fallback.PrimaryPart or fallback:FindFirstChildWhichIsA("BasePart"))
			if not part then
				return
			end
			local cf = part.CFrame
			if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
				BallInstance:SetPrimaryPartCFrame(cf)
			else
				BallPart.CFrame = cf
			end
		end
		if dataInAir then
			local launchTime = data:GetAttribute("FTBall_LaunchTime")
			local spawnPos = data:GetAttribute("FTBall_SpawnPos")
			local target = data:GetAttribute("FTBall_Target")
			local power = data:GetAttribute("FTBall_Power")
			local curve = data:GetAttribute("FTBall_Curve")
			if typeof(launchTime) == "number" and typeof(spawnPos) == "Vector3" and typeof(target) == "Vector3" and typeof(power) == "number" then
				local elapsed = serverNow - launchTime
				if elapsed < 0 then
					elapsed = 0
				end
				local distance = (target - spawnPos).Magnitude
				local nominalFlightTime = if power > 0 and distance > 1e-4 then (distance / power) else math.huge
				local shouldUseReplicatedBall = elapsed >= nominalFlightTime
				if shouldUseReplicatedBall then
					ApplyFromRealBall()
				else
					local vis = _G.FT_BALL_VIS_STATE
					if not vis then
						vis = {}
						_G.FT_BALL_VIS_STATE = vis
					end
					local seq = data:GetAttribute("FTBall_Seq")
					local requestOwnerId = data:GetAttribute("FTBall_RequestOwner")
					local requestId = data:GetAttribute("FTBall_RequestId")
					local now = os.clock()
					if typeof(seq) == "number" and seq ~= vis.lastSeq then
						local matchedLocalPrediction = LocalPrediction.ConfirmLaunch(requestOwnerId, requestId)
						if matchedLocalPrediction then
							predictedCFrame = nil
							LocalPredictionState.ballInFlight = false
						end
						vis.lastSeq = seq
						if matchedLocalPrediction then
							vis.lagComp = 0
							vis.lagCompDur = 0
							vis.lagCompEnd = nil
							vis.blendFrom = nil
							vis.blendDur = 0
							vis.blendEnd = nil
						else
							local lag = math.clamp(elapsed, 0, PredictionRuntime.lagCompWindow)
							vis.lagComp = lag
							vis.lagCompDur = PredictionRuntime.lagCompWindow
							vis.lagCompEnd = now + PredictionRuntime.lagCompWindow
							vis.blendFrom = BallPart.Position
							vis.blendDur = PredictionRuntime.blendTime
							vis.blendEnd = now + PredictionRuntime.blendTime
						end
					end
					local lagComp = 0
					if typeof(vis.lagCompEnd) == "number" and now < vis.lagCompEnd then
						local dur = typeof(vis.lagCompDur) == "number" and vis.lagCompDur or PredictionRuntime.lagCompWindow
						local t = (vis.lagCompEnd - now) / math.max(dur, 0.001)
						local base = typeof(vis.lagComp) == "number" and vis.lagComp or 0
						lagComp = base * math.clamp(t, 0, 1)
					end
					local effectiveElapsed = elapsed - lagComp
					if effectiveElapsed < 0 then
						effectiveElapsed = 0
					end
					local util = _G.FT_BALL_UTIL
					if not util then
						util = require(REPLICATED_STORAGE.Modules.Game.Utility)
						_G.FT_BALL_UTIL = util
					end
					local pos = util.GetPositionAtTime(effectiveElapsed, spawnPos, target, power, typeof(curve) == "number" and curve or 0.2)
					if typeof(vis.blendEnd) == "number" and now < vis.blendEnd and typeof(vis.blendFrom) == "Vector3" then
						local dur = typeof(vis.blendDur) == "number" and vis.blendDur or PredictionRuntime.blendTime
						local t = 1 - ((vis.blendEnd - now) / math.max(dur, 0.001))
						pos = vis.blendFrom:Lerp(pos, math.clamp(t, 0, 1))
					end
					local spinType = data:GetAttribute("FTBall_Spin")
					local spinFn = typeof(spinType) == "number" and FTConfig.BALL_SPIN_TYPES[spinType] or nil
					local cf = CFrame.new(pos)
					if spinFn then
						cf = cf * spinFn()
					end
					if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
						BallInstance:SetPrimaryPartCFrame(cf)
					else
						BallPart.CFrame = cf
					end
				end
			end
		elseif typeof(externalHolder) == "string" and externalHolder ~= "" then
			ApplyFromRealBall()
		elseif predictedCFrame then
			if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
				BallInstance:SetPrimaryPartCFrame(predictedCFrame)
			else
				BallPart.CFrame = predictedCFrame
			end
		elseif typeof(possession) == "number" and possession > 0 then
			local player = PlayerIdentity.ResolvePlayer(possession)
			local character = player and player.Character
			if not character then
				ApplyFromRealBall()
			elseif ExtraPointActive and character then
				local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local foot = character:FindFirstChild("RightFoot") or character:FindFirstChild("Right Leg") or character:FindFirstChild("RightLowerLeg")
				if hrp and foot then
					local forward = hrp.CFrame.LookVector
					if forward.Magnitude < 1e-4 then
						forward = foot.CFrame.LookVector
					end
					local planarForward = Vector3.new(forward.X, 0, forward.Z)
					if planarForward.Magnitude < 1e-4 then
						planarForward = Vector3.new(0, 0, -1)
					end
					planarForward = planarForward.Unit
					local basePos = foot.Position
					local desiredPos = Vector3.new(basePos.X, basePos.Y, basePos.Z) + planarForward * ExtraPointConfig.ballOffset
					local campo = FTBallController._GetCampo()
					local groundY: number? = nil
					if campo then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Include
						params.FilterDescendantsInstances = { campo }
						local hit = WORKSPACE:Raycast(desiredPos + Vector3.new(0, 5, 0), Vector3.new(0, -20, 0), params)
						if hit then
							groundY = hit.Position.Y
						elseif _GetCampoPlaneY then
							groundY = _GetCampoPlaneY(campo)
						end
					end
					local baseHeight = BallPart.Size.Y * 0.5
					local finalY = (groundY or desiredPos.Y) + baseHeight + ExtraPointConfig.ballHeight
					local placement = Vector3.new(desiredPos.X, finalY, desiredPos.Z)
					local cf = CFrame.lookAt(placement, placement + planarForward) * CFrame.Angles(0, math.rad(-180), 0)
					if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
						BallInstance:SetPrimaryPartCFrame(cf)
					else
						BallPart.CFrame = cf
					end
				else
					ApplyFromRealBall()
				end
			else
				local arm = character and (character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand") or character:FindFirstChild("RightLowerArm") or character:FindFirstChild("RightUpperArm")) :: BasePart?
				if arm then
					local offset = _G.FT_BALL_OFFSET_R6
					if not offset then
						offset = CFrame.new(-0.1, -1.3, -0.5) * CFrame.Angles(0, math.rad(90), 0)
						_G.FT_BALL_OFFSET_R6 = offset
					end
					local cf = arm.CFrame * offset
					if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
						BallInstance:SetPrimaryPartCFrame(cf)
					else
						BallPart.CFrame = cf
					end
				else
					local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp then
						local cf = hrp.CFrame * CFrame.new(0, 0.5, -1)
						if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
							BallInstance:SetPrimaryPartCFrame(cf)
						else
							BallPart.CFrame = cf
						end
					else
						ApplyFromRealBall()
					end
				end
			end
		elseif dataOnGround then
			local groundPos = data:GetAttribute("FTBall_GroundPos")
			if typeof(groundPos) == "Vector3" then
				local cf = CFrame.new(groundPos)
				if BallInstance and BallInstance:IsA("Model") and BallInstance.PrimaryPart then
					BallInstance:SetPrimaryPartCFrame(cf)
				else
					BallPart.CFrame = cf
				end
			end
		end
		if ExtraPointStage ~= ExtraPointConfig.stageNone
			or ExtraPointKickState.pending
			or ExtraPointKickState.startTime > 0
			or ExtraPointKickState.postGoalActive
		then
			BallImpactFx.Clear()
		else
			BallImpactFx.Update(BallPart, data, dataInAir, dataOnGround, possession)
		end
		local activeLaunch = LocalPredictionState.activeLaunch
		if not dataInAir and not predictedCFrame and activeLaunch and serverNow >= activeLaunch.releaseAt then
			if dataOnGround or (typeof(possession) == "number" and possession > 0) then
				LocalPrediction.ClearLaunch()
			end
		end
	else
		BallImpactFx.Clear()
	end
	if data then
		local inAirAttr = data:GetAttribute("FTBall_InAir")
		if typeof(inAirAttr) == "boolean" then
			BallInAir = inAirAttr or LocalPredictionState.ballInFlight
		else
			BallInAir = LocalPredictionState.ballInFlight or _IsBallInAir()
		end
		LocalPredictionState.visualDetached = BallInAir
		local onGroundAttr = data:GetAttribute("FTBall_OnGround")
		if typeof(onGroundAttr) == "boolean" then
			BallMarkerReady = onGroundAttr and not LocalPredictionState.ballInFlight
		else
			BallMarkerReady = not BallInAir
		end
	else
		BallInAir = LocalPredictionState.ballInFlight or _IsBallInAir()
		LocalPredictionState.visualDetached = BallInAir
		BallMarkerReady = not BallInAir
	end
	ExtraPointUi.UpdateGoalVisual()
	if ExtraPointKickState.pending and BallInAir and (LocalPredictionState.visualDetached or _GetBallCarrier() == nil) then
		ExtraPointKickState.pending = false
		if ExtraPointKickState.kickerId == PlayerIdentity.GetLocalIdValue() then
			_StopChargeShotAnimation()
		end
	end
	if ExtraPointActive or ExtraPointKickState.cinematicActive then
		BallCameraEnabled = false
		BallCameraForceUntil = 0
	end
	_UpdateBallCircle()
	_UpdateBallCamera()
	FTBallController._UpdateTrajectoryBeam()
	_UpdateBallEffects()
	if CountdownActive then
		FTBallController._MaintainCountdownFacing()
	elseif not FTBallController._MaintainStunFacing() then
		FTBallController._UpdateFacingHold()
	end
	if not CountdownActive then
		_StopRoleAnimations()
	end
	_UpdateExtraPointKickTimeout()
end)
end

return FTBallController

