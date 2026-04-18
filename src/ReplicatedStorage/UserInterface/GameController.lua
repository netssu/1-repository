--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ContentProvider = game:GetService("ContentProvider")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local CountdownController = require(ReplicatedStorage.Controllers.CountdownController)
local FOVController = require(ReplicatedStorage.Controllers.FOVController)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local WaveTransition = require(ReplicatedStorage.Modules.WaveTransition)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)
local PlayerCardsData = require(ReplicatedStorage.Modules.Data.PlayerCardsData)
local GameplayGuiVisibility = require(ReplicatedStorage.Modules.Game.GameplayGuiVisibility)
local GoalEffects = require(ReplicatedStorage.Modules.Game.GoalEffects)
local TouchdownWaveTransitionCoordinator = require(ReplicatedStorage.Modules.Game.TouchdownWaveTransitionCoordinator)

local FTGameController = {}
FTGameController.__index = FTGameController

--\\ CONSTANTS \\ -- TR
local SCORE_TWEEN_INFO: TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local COUNTDOWN_TWEEN_INFO: TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOUCHDOWN_SHOWCASE_SOUND_VOLUME: number = 7
local LOST_YARDS_NOTIFY_SOUND_VOLUME: number = 4
local POSITION_SELECTION_ACTIVE_ATTRIBUTE = "FTPositionSelectionActive"
local IN_LOBBY_ATTRIBUTE = "FTIsInLobby"
local ATTR_AWAKEN_ACTIVE = "AwakenActive"
local ATTR_AWAKEN_CUTSCENE_ACTIVE = "FTAwakenCutsceneActive"
local ATTR_PERFECT_PASS_CUTSCENE_LOCKED = "FTPerfectPassCutsceneLocked"
local ATTR_TOUCHDOWN_GAMEPLAY_GUI_OVERRIDE = "FTTouchdownGameplayGuiOverride"
local LOBBY_STATE_PADDING = Vector3.new(6, 8, 6)
local GOAL_EFFECT_NAME: string = "Yellow"
local TOUCHDOWN_TOP_GAMEPLAY_FALLBACK_POSITION = UDim2.new(-0.584, 0, -0.302, 0)
local TOUCHDOWN_BOTTOM_GAMEPLAY_FALLBACK_POSITION = UDim2.new(-0.529, 0, 0.818, 0)
local TOUCHDOWN_TOP_REOPEN_START_POSITION = UDim2.new(-0.611, 0, 0.529, 0)
local TOUCHDOWN_BOTTOM_REOPEN_START_POSITION = UDim2.new(-0.529, 0, 0, 0)
local TOUCHDOWN_TOP_CARD_POSITION = UDim2.new(-0.589, 0, -0.324, 0)
local TOUCHDOWN_BOTTOM_CARD_POSITION = UDim2.new(-0.574, 0, 0.818, 0)
local TOUCHDOWN_TOP_CARD_EXIT_POSITION = UDim2.new(-0.584, 0, -1.5, 0)
local TOUCHDOWN_BOTTOM_CARD_EXIT_POSITION = UDim2.new(-0.529, 0, 1.5, 0)
local TOUCHDOWN_IMAGE_START_POSITION = UDim2.fromScale(0.5, 1.5)
local TOUCHDOWN_IMAGE_END_POSITION = UDim2.fromScale(0.5, 0.257)
local TOUCHDOWN_LABEL_START_POSITION = UDim2.fromScale(0.521, -0.5)
local TOUCHDOWN_LABEL_END_POSITION = UDim2.fromScale(0.521, 0.212)
local TOUCHDOWN_CARD_START_POSITION = UDim2.new(0.209, 0, -0.5, 0)
local TOUCHDOWN_CARD_ENTRY_POSITION = UDim2.new(0.226, 0, 0.575, 0)
local TOUCHDOWN_CARD_IDLE_POSITION = UDim2.new(0.209, 0, 0.527, 0)
local TOUCHDOWN_CARD_ANTICIPATION_POSITION = UDim2.new(0.196, 0, 0.49, 0)
local TOUCHDOWN_CARD_EXIT_POSITION = UDim2.new(0.209, 0, 2, 0)
local TOUCHDOWN_IMAGE_ENTRY_INFO: TweenInfo = TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOUCHDOWN_LABEL_ENTRY_INFO: TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOUCHDOWN_IMAGE_EXIT_INFO: TweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TOUCHDOWN_LABEL_EXIT_INFO: TweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TOUCHDOWN_FRAME_GAMEPLAY_INFO: TweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOUCHDOWN_SEQUENCE_DEFAULT_DURATION: number = 3.15
local TOUCHDOWN_SEQUENCE_FIXED_TIME: number = 0.88
local TOUCHDOWN_SEQUENCE_MIN_HOLD_TIME: number = 1.35
local TOUCHDOWN_CARD_DISPLAY_ORDER: number = 10010
local TOUCHDOWN_OVERLAY_NAME: string = "TouchdownShowcaseOverlay"
local TOUCHDOWN_OVERLAY_GUI_NAME: string = "TouchdownPlayerCardOverlayGui"
local TOUCHDOWN_CARD_ENTRY_INFO: TweenInfo = TweenInfo.new(0.62, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOUCHDOWN_CARD_SETTLE_INFO: TweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TOUCHDOWN_CARD_ANTICIPATION_INFO: TweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TOUCHDOWN_CARD_EXIT_INFO: TweenInfo = TweenInfo.new(0.58, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TOUCHDOWN_PLAYER_CARD_START_DELAY: number = 0.12
local TOUCHDOWN_PLAYER_CARD_FRAME_INFO: TweenInfo = TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TOUCHDOWN_PLAYER_CARD_FRAME_EXIT_INFO: TweenInfo = TweenInfo.new(0.52, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local TOUCHDOWN_PLAYER_CARD_MIN_HOLD: number = 0.95
local TOUCHDOWN_CARD_ENTRY_ROTATION: number = -10
local TOUCHDOWN_CARD_ENTRY_TARGET_ROTATION: number = 6
local TOUCHDOWN_CARD_IDLE_ROTATION: number = 0
local TOUCHDOWN_CARD_ANTICIPATION_ROTATION: number = -5
local TOUCHDOWN_CARD_EXIT_ROTATION: number = 11
local TOUCHDOWN_CARD_ENTRY_SCALE: number = 0.84
local TOUCHDOWN_CARD_ENTRY_TARGET_SCALE: number = 1.05
local TOUCHDOWN_CARD_IDLE_SCALE: number = 1
local TOUCHDOWN_CARD_ANTICIPATION_SCALE: number = 1.03
local TOUCHDOWN_CARD_EXIT_SCALE: number = 0.9
local TOUCHDOWN_CARD_FLOAT_X_SPEED: number = 1.15
local TOUCHDOWN_CARD_FLOAT_X_AMPLITUDE: number = 0.006
local TOUCHDOWN_CARD_FLOAT_Y_SPEED: number = 1.9
local TOUCHDOWN_CARD_FLOAT_Y_AMPLITUDE: number = 0.017
local TOUCHDOWN_CARD_FLOAT_ROTATION_SPEED: number = 1.7
local TOUCHDOWN_CARD_FLOAT_ROTATION_AMPLITUDE: number = 2.2
local TOUCHDOWN_CARD_ZINDEX_BOOST: number = 40
local TOUCHDOWN_FOV_REQUEST_ID: string = "GameController::TouchdownFov"
local TOUCHDOWN_FOV_TARGET: number = 120
local TOUCHDOWN_FOV_TWEEN_INFO: TweenInfo = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TOUCHDOWN_LABEL_FLOAT_SPEED: number = 2.6
local TOUCHDOWN_LABEL_FLOAT_AMPLITUDE: number = 0.008
local TOUCHDOWN_LABEL_FLOAT_ROTATION: number = 1.1
local TOUCHDOWN_GUI_RESTORE_RETRY_COUNT: number = 18
local TOUCHDOWN_GUI_RESTORE_RETRY_STEP: number = 0.12
local TOUCHDOWN_PRELOAD_WAIT_TIMEOUT: number = 4
local TOUCHDOWN_PRELOAD_POST_RENDER_STEPS: number = 4
local TOUCHDOWN_PLAYER_CARD_PAYLOAD_WAIT_TIMEOUT: number = 1.25
local LOBBY_STATE_POLL_INTERVAL: number = 0.2
local LEAVE_MATCH_BUTTON_COOLDOWN: number = 1.2
local LEAVE_MATCH_REQUEST_DELAY: number = 0.12
local TOUCHDOWN_GAMEPLAY_TRANSITION_GUI_NAME: string = "WaveTransitionGui"
local LEAVE_MATCH_TRANSITION_GUI_NAME: string = "WaveTransitionGui"
local WAVE_TRANSITION_DISPLAY_ORDER: number = 20000
local WAVE_TRANSITION_ZINDEX: number = 50
local WAVE_TRANSITION_RENDER_WAIT_STEPS: number = 2
local LEAVE_MATCH_TRANSITION_IN_INFO: TweenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local LEAVE_MATCH_TRANSITION_OUT_INFO: TweenInfo = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local LEAVE_MATCH_TRANSITION_WAVE_WIDTH: number = 14
local LEAVE_MATCH_TRANSITION_DIRECTION: Vector2 = Vector2.new(1, -0.7)

--\\ MODULE STATE \\ -- TR
local LocalPlayer: Player = Players.LocalPlayer

local State = {
	team1ScoreLabel = nil :: TextLabel?,
	team2ScoreLabel = nil :: TextLabel?,
	timerLabel = nil :: TextLabel?,
	intermissionLabel = nil :: TextLabel?,
	stateLabel = nil :: TextLabel?,
	gameGui = nil :: ScreenGui?,
	hudGui = nil :: ScreenGui?,
	matchInfoExitButton = nil :: GuiButton?,
	connections = {} :: {RBXScriptConnection},
	loadingFinished = false :: boolean,
	lastMatchStarted = false :: boolean,
	lastLobbyState = false :: boolean,
	nextLobbyStatePollAt = 0 :: number,
	leaveMatchPending = false :: boolean,
	leaveMatchCooldownUntil = 0 :: number,
	touchdownSequenceActive = false :: boolean,
	touchdownPlayerCardActive = false :: boolean,
	touchdownFramesReady = false :: boolean,
	touchdownFramesVisible = false :: boolean,
}

local FadeState = {
	gui = nil :: ScreenGui?,
	frame = nil :: Frame?,
	token = 0 :: number,
}

local TouchdownShowcaseState = {
	token = 0 :: number,
	labelFloatConnection = nil :: RBXScriptConnection?,
	cardFloatConnection = nil :: RBXScriptConnection?,
	overlay = nil :: Frame?,
	card = nil :: GuiObject?,
	touchdownGui = nil :: ScreenGui?,
	touchdownRoot = nil :: GuiObject?,
	touchdownImage = nil :: GuiObject?,
	touchdownLabel = nil :: GuiObject?,
	goalPlayback = nil :: any,
	main = nil :: GuiObject?,
	matchInfo = nil :: GuiObject?,
	topFrame = nil :: GuiObject?,
	bottomFrame = nil :: GuiObject?,
	topFrameDefaultPosition = nil :: UDim2?,
	bottomFrameDefaultPosition = nil :: UDim2?,
	topFrameDefaultVisible = true :: boolean,
	bottomFrameDefaultVisible = true :: boolean,
	mainWasVisible = true :: boolean,
	matchInfoWasVisible = true :: boolean,
	touchdownGuiDisplayOrder = 0 :: number,
	touchdownRootWasVisible = true :: boolean,
	touchdownImageWasVisible = true :: boolean,
	touchdownLabelWasVisible = true :: boolean,
	pendingPlayerCard = nil :: {
		PlayerId: number,
		CardName: string,
		Touchdowns: number,
		Passing: number,
		Tackles: number,
	}?,
}

type WaveTransitionOverlayState = {
	Overlay: ScreenGui,
	Transition: any,
	AlphaValue: NumberValue,
	ChangedConnection: RBXScriptConnection,
}

local IsLocalPlayerInMatch: () -> boolean
local CleanupTouchdownShowcase: (boolean, boolean?) -> ()
local UpdateUIVisibility: () -> ()
local RestoreTouchdownGameplayGui: () -> ()
local SetTouchdownFramesVisible: (boolean) -> ()
local TouchdownGuiEnforcementConnection: RBXScriptConnection? = nil
local TouchdownUiPreloaded: boolean = false
local TouchdownUiPreloadInProgress: boolean = false

local function AppendUniqueTouchdownPreloadInstance(
	preloadList: {any},
	seenInstances: {[Instance]: boolean},
	instance: Instance?
): ()
	if not instance or seenInstances[instance] then
		return
	end

	seenInstances[instance] = true
	table.insert(preloadList, instance)
end

local function AppendUniqueTouchdownPreloadContent(
	preloadList: {any},
	seenContent: {[string]: boolean},
	contentValue: any
): ()
	if typeof(contentValue) ~= "string" then
		return
	end
	if contentValue == "" or seenContent[contentValue] then
		return
	end

	seenContent[contentValue] = true
	table.insert(preloadList, contentValue)
end

local function AppendTouchdownContentProperty(
	preloadList: {any},
	seenContent: {[string]: boolean},
	instance: Instance,
	propertyName: string
): ()
	local success, value = pcall(function()
		return (instance :: any)[propertyName]
	end)
	if success then
		AppendUniqueTouchdownPreloadContent(preloadList, seenContent, value)
	end
end

local function AppendTouchdownPreloadItemsFromInstance(
	preloadList: {any},
	seenInstances: {[Instance]: boolean},
	seenContent: {[string]: boolean},
	instance: Instance
): ()
	if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		AppendUniqueTouchdownPreloadInstance(preloadList, seenInstances, instance)
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "Image")
	elseif instance:IsA("VideoFrame") then
		AppendUniqueTouchdownPreloadInstance(preloadList, seenInstances, instance)
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "Video")
	elseif instance:IsA("Sound") then
		AppendUniqueTouchdownPreloadInstance(preloadList, seenInstances, instance)
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "SoundId")
	elseif instance:IsA("MeshPart") then
		AppendUniqueTouchdownPreloadInstance(preloadList, seenInstances, instance)
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "MeshId")
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "TextureID")
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "MeshContent")
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "TextureContent")
	elseif instance:IsA("SurfaceAppearance") then
		AppendUniqueTouchdownPreloadInstance(preloadList, seenInstances, instance)
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "ColorMap")
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "MetalnessMap")
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "NormalMap")
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "RoughnessMap")
	elseif instance:IsA("SpecialMesh") then
		AppendUniqueTouchdownPreloadInstance(preloadList, seenInstances, instance)
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "MeshId")
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "TextureId")
	elseif instance:IsA("Texture") or instance:IsA("Decal") then
		AppendUniqueTouchdownPreloadInstance(preloadList, seenInstances, instance)
		AppendTouchdownContentProperty(preloadList, seenContent, instance, "Texture")
	end
end

local function AppendTouchdownPreloadItemsFromRoot(
	root: Instance?,
	preloadList: {any},
	seenInstances: {[Instance]: boolean},
	seenContent: {[string]: boolean}
): ()
	if not root then
		return
	end

	AppendTouchdownPreloadItemsFromInstance(preloadList, seenInstances, seenContent, root)
	for _, descendant in root:GetDescendants() do
		AppendTouchdownPreloadItemsFromInstance(preloadList, seenInstances, seenContent, descendant)
	end
end

local function BuildTouchdownPreloadList(playerGui: PlayerGui): ({any}, boolean)
	local preloadList: {any} = {}
	local seenInstances: {[Instance]: boolean} = {}
	local seenContent: {[string]: boolean} = {}
	local touchdownGuiResolved: boolean = false

	local touchdownGui = playerGui:FindFirstChild("TouchdownUI")
	if not touchdownGui then
		touchdownGui = playerGui:WaitForChild("TouchdownUI", TOUCHDOWN_PRELOAD_WAIT_TIMEOUT)
	end
	if touchdownGui then
		touchdownGuiResolved = true
	end
	AppendTouchdownPreloadItemsFromRoot(touchdownGui, preloadList, seenInstances, seenContent)

	for _, cardData in PlayerCardsData.Cards do
		local cardTemplate = if type(cardData) == "table" then cardData.Card else nil
		if typeof(cardTemplate) == "Instance" then
			AppendTouchdownPreloadItemsFromRoot(cardTemplate, preloadList, seenInstances, seenContent)
		end
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cardsFolder = assets and assets:FindFirstChild("PlayerCards")
	local fallbackCard = cardsFolder and cardsFolder:FindFirstChild("Blue")
	AppendTouchdownPreloadItemsFromRoot(fallbackCard, preloadList, seenInstances, seenContent)

	return preloadList, touchdownGuiResolved
end

local function StartTouchdownUiPreload(): ()
	if TouchdownUiPreloaded or TouchdownUiPreloadInProgress then
		return
	end

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	TouchdownUiPreloadInProgress = true
	task.spawn(function(): ()
		local preloadCompleted = false
		local touchdownGuiResolved = false

		local success = pcall(function()
			local preloadList: {any}
			preloadList, touchdownGuiResolved = BuildTouchdownPreloadList(playerGui)
			if #preloadList <= 0 then
				return
			end

			ContentProvider:PreloadAsync(preloadList)
			preloadCompleted = true
		end)

		if success and preloadCompleted and touchdownGuiResolved then
			for _ = 1, TOUCHDOWN_PRELOAD_POST_RENDER_STEPS do
				RunService.Heartbeat:Wait()
			end
			TouchdownUiPreloaded = true
		else
			TouchdownUiPreloaded = false
		end

		TouchdownUiPreloadInProgress = false
	end)
end

local function WaitForTouchdownUiPreload(timeout: number?): ()
	if TouchdownUiPreloaded then
		return
	end

	StartTouchdownUiPreload()

	local waitTimeout = if typeof(timeout) == "number" then math.max(timeout, 0) else TOUCHDOWN_PRELOAD_WAIT_TIMEOUT
	local deadline = os.clock() + waitTimeout
	while not TouchdownUiPreloaded and os.clock() < deadline do
		if not TouchdownUiPreloadInProgress then
			StartTouchdownUiPreload()
		end
		RunService.Heartbeat:Wait()
	end
end

local function ResolveRuntimeGuis(): ()
	local GameplayGuis = GameplayGuiVisibility.ResolveGameplayGuis(LocalPlayer)
	State.gameGui = GameplayGuis.GameGui
	State.hudGui = GameplayGuis.HudGui
end

local function StopTouchdownGameplayGuiEnforcement(): ()
	if TouchdownGuiEnforcementConnection then
		TouchdownGuiEnforcementConnection:Disconnect()
		TouchdownGuiEnforcementConnection = nil
	end
end

local function StartTouchdownGameplayGuiEnforcement(): ()
	if TouchdownGuiEnforcementConnection then
		return
	end

	TouchdownGuiEnforcementConnection = RunService.Heartbeat:Connect(function()
		if not State.touchdownPlayerCardActive then
			StopTouchdownGameplayGuiEnforcement()
			return
		end

		if State.gameGui then
			State.gameGui.Enabled = true
		end
		SetTouchdownFramesVisible(State.touchdownFramesVisible)
	end)
end

local function SetTouchdownGameplayGuiOverride(active: boolean): ()
	State.touchdownPlayerCardActive = active
	LocalPlayer:SetAttribute(ATTR_TOUCHDOWN_GAMEPLAY_GUI_OVERRIDE, active)

	local Character = LocalPlayer.Character
	if Character then
		Character:SetAttribute(ATTR_TOUCHDOWN_GAMEPLAY_GUI_OVERRIDE, active)
	end

	if active then
		StartTouchdownGameplayGuiEnforcement()
	else
		StopTouchdownGameplayGuiEnforcement()
	end
end

local function EnsureFadeGui(): (ScreenGui?, Frame?)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil, nil
	end
	if not FadeState.gui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "TeleportFadeGui"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 9999
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = playerGui
		FadeState.gui = gui

		local frame = Instance.new("Frame")
		frame.Name = "Fade"
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = gui
		FadeState.frame = frame
	end
	if FadeState.gui and FadeState.gui.Parent ~= playerGui then
		FadeState.gui.Parent = playerGui
	end
	return FadeState.gui, FadeState.frame
end

local function PlayTeleportFade(duration: number): ()
	local _gui, frame = EnsureFadeGui()
	if not frame then
		return
	end
	FadeState.token += 1
	local token = FadeState.token
	local total = if duration > 0 then duration else 0.35
	local fadeIn = math.clamp(total * 0.35, 0.08, 0.2)
	local fadeOut = math.clamp(total * 0.65, 0.12, 0.35)

	frame.Visible = true
	frame.BackgroundTransparency = 1

	local tweenIn = TweenService:Create(frame, TweenInfo.new(fadeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.12,
	})
	tweenIn.Completed:Once(function()
		if FadeState.token ~= token then
			return
		end
		local tweenOut = TweenService:Create(frame, TweenInfo.new(fadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		})
		tweenOut.Completed:Once(function()
			if FadeState.token ~= token then
				return
			end
			frame.Visible = false
		end)
		tweenOut:Play()
	end)
	tweenIn:Play()
end

local function CreateWaveTransitionOverlay(guiName: string): WaveTransitionOverlayState?
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local existingOverlay = playerGui:FindFirstChild(guiName)
	if existingOverlay then
		existingOverlay:Destroy()
	end

	local overlay = Instance.new("ScreenGui")
	overlay.Name = guiName
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = WAVE_TRANSITION_DISPLAY_ORDER
	overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlay.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "WaveContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.ZIndex = WAVE_TRANSITION_ZINDEX
	container.Parent = overlay

	for _ = 1, WAVE_TRANSITION_RENDER_WAIT_STEPS do
		if container.AbsoluteSize.X > 0 and container.AbsoluteSize.Y > 0 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	local transition = WaveTransition.new(container, {
		color = Color3.new(0, 0, 0),
		width = LEAVE_MATCH_TRANSITION_WAVE_WIDTH,
		waveDirection = LEAVE_MATCH_TRANSITION_DIRECTION,
	})
	for _, square in ipairs(transition.squares) do
		square.ZIndex = WAVE_TRANSITION_ZINDEX
	end

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Value = 0
	transition:Update(alphaValue.Value)

	local changedConnection = alphaValue.Changed:Connect(function()
		transition:Update(alphaValue.Value)
	end)

	return {
		Overlay = overlay,
		Transition = transition,
		AlphaValue = alphaValue,
		ChangedConnection = changedConnection,
	}
end

local function DestroyWaveTransitionOverlay(transitionState: WaveTransitionOverlayState?): ()
	if not transitionState then
		return
	end

	transitionState.ChangedConnection:Disconnect()
	transitionState.AlphaValue:Destroy()
	transitionState.Transition:Destroy()
	transitionState.Overlay:Destroy()
end

local function PlayTouchdownGameGuiTransitionIn(): WaveTransitionOverlayState?
	local transitionState = CreateWaveTransitionOverlay(TOUCHDOWN_GAMEPLAY_TRANSITION_GUI_NAME)
	if not transitionState then
		return nil
	end

	local tweenIn = TweenService:Create(transitionState.AlphaValue, LEAVE_MATCH_TRANSITION_IN_INFO, { Value = 1 })
	tweenIn:Play()
	tweenIn.Completed:Wait()
	return transitionState
end

local function ReleaseTouchdownGameGuiTransition(transitionState: WaveTransitionOverlayState?): ()
	if not transitionState then
		return
	end

	task.spawn(function()
		task.wait()
		DestroyWaveTransitionOverlay(transitionState)
	end)
end

local function EnableTouchdownGameGuiWithTransition(
	gameGui: ScreenGui?,
	token: number?,
	forceTransition: boolean?,
	existingTransitionState: WaveTransitionOverlayState?
): boolean
	if not gameGui then
		return false
	end

	local transitionState: WaveTransitionOverlayState? = existingTransitionState
	if not transitionState and (forceTransition == true or not gameGui.Enabled) then
		transitionState = PlayTouchdownGameGuiTransitionIn()
		if token ~= nil and TouchdownShowcaseState.token ~= token then
			DestroyWaveTransitionOverlay(transitionState)
			return false
		end
	end

	gameGui.Enabled = true
	if transitionState then
		ReleaseTouchdownGameGuiTransition(transitionState)
	end
	return true
end

local function PlayLeaveMatchTransition(): ()
	local transitionState = CreateWaveTransitionOverlay(LEAVE_MATCH_TRANSITION_GUI_NAME)
	if not transitionState then
		return
	end

	local tweenIn = TweenService:Create(transitionState.AlphaValue, LEAVE_MATCH_TRANSITION_IN_INFO, { Value = 1 })
	tweenIn.Completed:Once(function()
		local tweenOut = TweenService:Create(transitionState.AlphaValue, LEAVE_MATCH_TRANSITION_OUT_INFO, { Value = 0 })
		tweenOut.Completed:Once(function()
			DestroyWaveTransitionOverlay(transitionState)
		end)
		tweenOut:Play()
	end)

	tweenIn:Play()
end

local function PlayPlayerHighlightFade(duration: number): ()
	local total = if duration > 0 then duration else 0.35
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local existing = character:FindFirstChild("TeleportFadeHighlight")
			if existing then
				existing:Destroy()
			end
			local highlight = Instance.new("Highlight")
			highlight.Name = "TeleportFadeHighlight"
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

local function SetGuiObjectVisible(target: GuiObject?, visible: boolean): ()
	if target then
		target.Visible = visible
	end
end

local function FindGuiObject(root: Instance?, name: string): GuiObject?
	if not root then
		return nil
	end
	local direct = root:FindFirstChild(name)
	if direct and direct:IsA("GuiObject") then
		return direct
	end
	local found = root:FindFirstChild(name, true)
	if found and found:IsA("GuiObject") then
		return found
	end
	return nil
end

local function ResolveScoringTeam(playerId: number): number?
	local GameState: Instance? = ReplicatedStorage:FindFirstChild("FTGameState")
	local MatchFolder: Instance? = GameState and GameState:FindFirstChild("Match")
	if not MatchFolder then
		return nil
	end

	for TeamIndex = 1, 2 do
		local TeamFolder: Instance? = MatchFolder:FindFirstChild("Team" .. TeamIndex)
		if not TeamFolder then
			continue
		end

		for _, ValueObject in TeamFolder:GetChildren() do
			if ValueObject:IsA("IntValue") and ValueObject.Value == playerId then
				return TeamIndex
			end
		end
	end

	return nil
end

local function EnsureTouchdownOverlay(playerGui: PlayerGui): Frame?
	local overlayGui = playerGui:FindFirstChild(TOUCHDOWN_OVERLAY_GUI_NAME)
	if overlayGui and not overlayGui:IsA("ScreenGui") then
		overlayGui:Destroy()
		overlayGui = nil
	end

	local resolvedOverlayGui = overlayGui :: ScreenGui?
	if not resolvedOverlayGui then
		resolvedOverlayGui = Instance.new("ScreenGui")
		resolvedOverlayGui.Name = TOUCHDOWN_OVERLAY_GUI_NAME
		resolvedOverlayGui.IgnoreGuiInset = true
		resolvedOverlayGui.ResetOnSpawn = false
		resolvedOverlayGui.DisplayOrder = TOUCHDOWN_CARD_DISPLAY_ORDER + 1
		resolvedOverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		resolvedOverlayGui.Parent = playerGui
	end

	local existing = resolvedOverlayGui:FindFirstChild(TOUCHDOWN_OVERLAY_NAME)
	if existing and existing:IsA("Frame") then
		return existing
	end

	local overlay = Instance.new("Frame")
	overlay.Name = TOUCHDOWN_OVERLAY_NAME
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = TOUCHDOWN_CARD_ZINDEX_BOOST
	overlay.Parent = resolvedOverlayGui
	return overlay
end

local function BoostGuiZIndex(root: GuiObject, amount: number): ()
	root.ZIndex += amount
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex += amount
		end
	end
end

local function ResolveTouchdownCardTemplate(cardName: string): GuiObject?
	local cardData = PlayerCardsData.Cards[cardName]
	local template = if type(cardData) == "table" then cardData.Card else nil
	if template and template:IsA("GuiObject") then
		return template
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local cardsFolder = assets and assets:FindFirstChild("PlayerCards")
	local fallback = cardsFolder and cardsFolder:FindFirstChild("Blue")
	if fallback and fallback:IsA("GuiObject") then
		return fallback
	end

	return nil
end

local function SetCardFieldValue(target: Instance?, textValue: string, numericValue: number): ()
	if not target then
		return
	end

	if target:IsA("TextLabel") or target:IsA("TextButton") then
		target.Text = textValue
	elseif target:IsA("StringValue") then
		target.Value = textValue
	elseif target:IsA("IntValue") then
		target.Value = math.floor(numericValue + 0.5)
	elseif target:IsA("NumberValue") then
		target.Value = numericValue
	end
end

local function NormalizeCardFieldName(name: string): string
	return string.lower((string.gsub(name, "[%s_%-]", "")))
end

local function CollectCardFieldsByNames(root: Instance?, candidateNames: {string}): {Instance}
	if not root then
		return {}
	end

	local normalizedCandidates = table.create(#candidateNames)
	local foundFields = {}
	local seenFields = {}

	for _, candidateName in ipairs(candidateNames) do
		table.insert(normalizedCandidates, NormalizeCardFieldName(candidateName))

		local directMatch = root:FindFirstChild(candidateName, true)
		if directMatch and not seenFields[directMatch] then
			seenFields[directMatch] = true
			table.insert(foundFields, directMatch)
		end
	end

	for _, descendant in root:GetDescendants() do
		local normalizedDescendantName = NormalizeCardFieldName(descendant.Name)
		for _, normalizedCandidate in ipairs(normalizedCandidates) do
			if normalizedDescendantName == normalizedCandidate
				or string.find(normalizedDescendantName, normalizedCandidate, 1, true) then
				if not seenFields[descendant] then
					seenFields[descendant] = true
					table.insert(foundFields, descendant)
				end
				break
			end
		end
	end

	return foundFields
end

local function ApplyTouchdownCardData(
	card: GuiObject,
	playerId: number,
	touchdowns: number,
	passing: number,
	tackles: number
): ()
	local scorer = PlayerIdentity.ResolvePlayer(playerId)
	local scorerName = if scorer then scorer.DisplayName else "PLAYER"

	SetCardFieldValue(card:FindFirstChild("Plr", true), scorerName, 0)
	SetCardFieldValue(card:FindFirstChild("Touchdownsnumber", true), tostring(math.floor(touchdowns + 0.5)), touchdowns)
	SetCardFieldValue(card:FindFirstChild("Passnumber", true), tostring(math.floor(passing + 0.5)), passing)
	SetCardFieldValue(card:FindFirstChild("Taclkenumber", true), tostring(math.floor(tackles + 0.5)), tackles)

	local overallRating = PlayerCardsData.GetOverallRating(touchdowns, passing, tackles)
	local overallTargets = CollectCardFieldsByNames(card, {
		"OVR",
		"Overall",
		"OverallRating",
		"Rating",
		"OVRNumber",
	})

	if #overallTargets == 0 then
		warn(`[GameController] OVR field not found in touchdown card "{card.Name}"`)
	else
		for _, overallTarget in ipairs(overallTargets) do
			SetCardFieldValue(overallTarget, tostring(overallRating), overallRating)
		end
	end

	local profileImage = card:FindFirstChild("PlayerProfile", true)
	if scorer and profileImage and (profileImage:IsA("ImageLabel") or profileImage:IsA("ImageButton")) then
		local profileTarget = profileImage
		task.spawn(function(target: ImageLabel | ImageButton, userId: number): ()
			local ok, image = pcall(function(): string
				return Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size420x420
				)
			end)
			if ok and typeof(image) == "string" and target.Parent then
				target.Image = image
			end
		end, profileTarget, scorer.UserId)
	end
end

local function StopTouchdownLabelFloat(): ()
	if TouchdownShowcaseState.labelFloatConnection then
		TouchdownShowcaseState.labelFloatConnection:Disconnect()
		TouchdownShowcaseState.labelFloatConnection = nil
	end
end

local function StopTouchdownPlayerCardFloat(): ()
	if TouchdownShowcaseState.cardFloatConnection then
		TouchdownShowcaseState.cardFloatConnection:Disconnect()
		TouchdownShowcaseState.cardFloatConnection = nil
	end
end

local function CaptureTouchdownFrameDefaults(topFrame: GuiObject?, bottomFrame: GuiObject?): ()
	if topFrame then
		TouchdownShowcaseState.topFrameDefaultPosition = topFrame.Position
		TouchdownShowcaseState.topFrameDefaultVisible = topFrame.Visible
	end

	if bottomFrame then
		TouchdownShowcaseState.bottomFrameDefaultPosition = bottomFrame.Position
		TouchdownShowcaseState.bottomFrameDefaultVisible = bottomFrame.Visible
	end
end

local function GetTouchdownGameplayFrameTargets(): (UDim2, UDim2)
	return TOUCHDOWN_TOP_GAMEPLAY_FALLBACK_POSITION, TOUCHDOWN_BOTTOM_GAMEPLAY_FALLBACK_POSITION
end

SetTouchdownFramesVisible = function(Visible: boolean): ()
	State.touchdownFramesVisible = Visible

	local topFrame = TouchdownShowcaseState.topFrame
	if topFrame then
		topFrame.Visible = Visible
	end

	local bottomFrame = TouchdownShowcaseState.bottomFrame
	if bottomFrame then
		bottomFrame.Visible = Visible
	end
end

local function RefreshTouchdownGameplayObjects(): ()
	local gameGui = State.gameGui
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not gameGui then
		local foundGui = if playerGui then playerGui:FindFirstChild("GameGui") else nil
		if foundGui and foundGui:IsA("ScreenGui") then
			gameGui = foundGui
			State.gameGui = foundGui
		end
	end
	if not gameGui then
		return
	end

	if not TouchdownShowcaseState.main then
		local main = gameGui:FindFirstChild("Main") or gameGui:WaitForChild("Main", 2)
		if main and main:IsA("GuiObject") then
			TouchdownShowcaseState.main = main
		end
	end
	if not TouchdownShowcaseState.matchInfo then
		local matchInfo = gameGui:FindFirstChild("MatchInfo") or gameGui:WaitForChild("MatchInfo", 2)
		if matchInfo and matchInfo:IsA("GuiObject") then
			TouchdownShowcaseState.matchInfo = matchInfo
		end
	end
	if not TouchdownShowcaseState.topFrame then
		local topFrame = gameGui:FindFirstChild("Framecima") or gameGui:WaitForChild("Framecima", 2)
		if topFrame and topFrame:IsA("GuiObject") then
			TouchdownShowcaseState.topFrame = topFrame
		end
	end
	if not TouchdownShowcaseState.bottomFrame then
		local bottomFrame = gameGui:FindFirstChild("Framebaixo") or gameGui:WaitForChild("Framebaixo", 2)
		if bottomFrame and bottomFrame:IsA("GuiObject") then
			TouchdownShowcaseState.bottomFrame = bottomFrame
		end
	end
end

local function IsGuiObjectAtPosition(target: GuiObject?, position: UDim2): boolean
	if not target or not target.Visible then
		return false
	end

	return math.abs(target.Position.X.Scale - position.X.Scale) <= 0.001
		and math.abs(target.Position.Y.Scale - position.Y.Scale) <= 0.001
		and math.abs(target.Position.X.Offset - position.X.Offset) <= 1
		and math.abs(target.Position.Y.Offset - position.Y.Offset) <= 1
end

local function IsGuiObjectNearPosition(target: GuiObject?, position: UDim2): boolean
	if not target then
		return false
	end

	return math.abs(target.Position.X.Scale - position.X.Scale) <= 0.001
		and math.abs(target.Position.Y.Scale - position.Y.Scale) <= 0.001
		and math.abs(target.Position.X.Offset - position.X.Offset) <= 1
		and math.abs(target.Position.Y.Offset - position.Y.Offset) <= 1
end

local function WaitForTouchdownFrameTweens(topTween: Tween?, bottomTween: Tween?): ()
	if topTween then
		topTween.Completed:Wait()
	end
	if bottomTween then
		bottomTween.Completed:Wait()
	end
end

local function EnsureTouchdownGameplayGuiVisible(): boolean
	RefreshTouchdownGameplayObjects()
	SetTouchdownGameplayGuiOverride(true)
	if State.gameGui then
		State.gameGui.Enabled = true
	end
	RestoreTouchdownGameplayGui()
	UpdateUIVisibility()
	if State.gameGui then
		State.gameGui.Enabled = true
	end
	TouchdownWaveTransitionCoordinator.ReleaseAfterDelay()
	return true
end

local function PlayTouchdownGameplayReveal(token: number): boolean
	RefreshTouchdownGameplayObjects()
	local topFrame = TouchdownShowcaseState.topFrame
	local bottomFrame = TouchdownShowcaseState.bottomFrame
	local topGameplayTarget, bottomGameplayTarget = GetTouchdownGameplayFrameTargets()

	if not EnsureTouchdownGameplayGuiVisible() then
		return false
	end

	if IsGuiObjectAtPosition(topFrame, topGameplayTarget) and IsGuiObjectAtPosition(bottomFrame, bottomGameplayTarget) then
		SetTouchdownFramesVisible(true)
		State.touchdownFramesReady = true
		return TouchdownShowcaseState.token == token
	end

	State.touchdownFramesReady = false
	if topFrame then
		topFrame.Position = TOUCHDOWN_TOP_REOPEN_START_POSITION
	end
	if bottomFrame then
		bottomFrame.Position = TOUCHDOWN_BOTTOM_REOPEN_START_POSITION
	end
	SetTouchdownFramesVisible(false)
	RunService.RenderStepped:Wait()
	if TouchdownShowcaseState.token ~= token then
		return false
	end

	local frameTopGameplayTween = if topFrame
		then TweenService:Create(topFrame, TOUCHDOWN_FRAME_GAMEPLAY_INFO, { Position = topGameplayTarget })
		else nil
	local frameBottomGameplayTween = if bottomFrame
		then TweenService:Create(bottomFrame, TOUCHDOWN_FRAME_GAMEPLAY_INFO, { Position = bottomGameplayTarget })
		else nil
	SetTouchdownFramesVisible(true)
	if frameTopGameplayTween then
		frameTopGameplayTween:Play()
	end
	if frameBottomGameplayTween then
		frameBottomGameplayTween:Play()
	end
	WaitForTouchdownFrameTweens(frameTopGameplayTween, frameBottomGameplayTween)
	if TouchdownShowcaseState.token ~= token then
		return false
	end

	if topFrame then
		topFrame.Position = topGameplayTarget
	end
	if bottomFrame then
		bottomFrame.Position = bottomGameplayTarget
	end
	SetTouchdownFramesVisible(true)
	State.touchdownFramesReady = true
	return true
end

local function RestoreTouchdownFrames(): ()
	local topFrame = TouchdownShowcaseState.topFrame
	local bottomFrame = TouchdownShowcaseState.bottomFrame
	if topFrame then
		topFrame.Position = TouchdownShowcaseState.topFrameDefaultPosition or TOUCHDOWN_TOP_GAMEPLAY_FALLBACK_POSITION
		topFrame.Visible = TouchdownShowcaseState.topFrameDefaultVisible
	end
	if bottomFrame then
		bottomFrame.Position = TouchdownShowcaseState.bottomFrameDefaultPosition or TOUCHDOWN_BOTTOM_GAMEPLAY_FALLBACK_POSITION
		bottomFrame.Visible = TouchdownShowcaseState.bottomFrameDefaultVisible
	end
	State.touchdownFramesVisible = (if topFrame then topFrame.Visible else false)
		or (if bottomFrame then bottomFrame.Visible else false)
end

local function ResetTouchdownFrames(): ()
	local topFrame = TouchdownShowcaseState.topFrame
	local bottomFrame = TouchdownShowcaseState.bottomFrame
	if topFrame then
		topFrame.Position = TOUCHDOWN_TOP_REOPEN_START_POSITION
	end
	if bottomFrame then
		bottomFrame.Position = TOUCHDOWN_BOTTOM_REOPEN_START_POSITION
	end
	SetTouchdownFramesVisible(false)
end

local function PrimeTouchdownGameplayFrames(): ()
	local topFrame = TouchdownShowcaseState.topFrame
	local bottomFrame = TouchdownShowcaseState.bottomFrame
	if topFrame then
		topFrame.Position = TOUCHDOWN_TOP_REOPEN_START_POSITION
	end
	if bottomFrame then
		bottomFrame.Position = TOUCHDOWN_BOTTOM_REOPEN_START_POSITION
	end
	SetTouchdownFramesVisible(false)
end

local function PresetTouchdownGameplayFrames(): ()
	local topFrame = TouchdownShowcaseState.topFrame
	local bottomFrame = TouchdownShowcaseState.bottomFrame
	if topFrame then
		topFrame.Position = TOUCHDOWN_TOP_REOPEN_START_POSITION
	end
	if bottomFrame then
		bottomFrame.Position = TOUCHDOWN_BOTTOM_REOPEN_START_POSITION
	end
	SetTouchdownFramesVisible(false)
end

local function SetTouchdownFramesToCardExitPositions(): ()
	local topFrame = TouchdownShowcaseState.topFrame
	local bottomFrame = TouchdownShowcaseState.bottomFrame
	if topFrame then
		topFrame.Position = TOUCHDOWN_TOP_CARD_EXIT_POSITION
	end
	if bottomFrame then
		bottomFrame.Position = TOUCHDOWN_BOTTOM_CARD_EXIT_POSITION
	end
	SetTouchdownFramesVisible(true)
end

local function AreTouchdownFramesAtCardExitPositions(): boolean
	return IsGuiObjectNearPosition(TouchdownShowcaseState.topFrame, TOUCHDOWN_TOP_CARD_EXIT_POSITION)
		or IsGuiObjectNearPosition(TouchdownShowcaseState.bottomFrame, TOUCHDOWN_BOTTOM_CARD_EXIT_POSITION)
end

local function ResetTouchdownUi(): ()
	local touchdownGui = TouchdownShowcaseState.touchdownGui
	if touchdownGui then
		touchdownGui.Enabled = false
		touchdownGui.DisplayOrder = TouchdownShowcaseState.touchdownGuiDisplayOrder
	end
	if TouchdownShowcaseState.overlay then
		TouchdownShowcaseState.overlay.Visible = false
	end

	SetGuiObjectVisible(TouchdownShowcaseState.touchdownRoot, TouchdownShowcaseState.touchdownRootWasVisible)
	SetGuiObjectVisible(TouchdownShowcaseState.touchdownImage, TouchdownShowcaseState.touchdownImageWasVisible)
	SetGuiObjectVisible(TouchdownShowcaseState.touchdownLabel, TouchdownShowcaseState.touchdownLabelWasVisible)

	local touchdownImage = TouchdownShowcaseState.touchdownImage
	if touchdownImage then
		touchdownImage.Position = TOUCHDOWN_IMAGE_START_POSITION
		touchdownImage.Rotation = 0
	end

	local touchdownLabel = TouchdownShowcaseState.touchdownLabel
	if touchdownLabel then
		touchdownLabel.Position = TOUCHDOWN_LABEL_START_POSITION
		touchdownLabel.Rotation = 0
	end
end

RestoreTouchdownGameplayGui = function(): ()
	if IsLocalPlayerInMatch() then
		if State.gameGui then
			State.gameGui.Enabled = true
		end

		SetGuiObjectVisible(TouchdownShowcaseState.main, true)
		SetGuiObjectVisible(TouchdownShowcaseState.matchInfo, true)
		return
	end

	SetGuiObjectVisible(TouchdownShowcaseState.main, TouchdownShowcaseState.mainWasVisible)
	SetGuiObjectVisible(TouchdownShowcaseState.matchInfo, TouchdownShowcaseState.matchInfoWasVisible)
end

local function ScheduleTouchdownGameplayGuiRestore(token: number): ()
	for RetryIndex = 1, TOUCHDOWN_GUI_RESTORE_RETRY_COUNT do
		task.delay(RetryIndex * TOUCHDOWN_GUI_RESTORE_RETRY_STEP, function(): ()
			if TouchdownShowcaseState.token ~= token or State.touchdownSequenceActive then
				return
			end

			UpdateUIVisibility()
			if GameplayGuiVisibility.IsGameplayGuiBlocked(LocalPlayer) then
				return
			end

			if State.gameGui then
				State.gameGui.Enabled = true
			end
		end)
	end
end

CleanupTouchdownShowcase = function(restoreHud: boolean, cleanupGoalEffects: boolean?): ()
	local wasPlayerCardActive = State.touchdownPlayerCardActive
	StopTouchdownLabelFloat()
	StopTouchdownPlayerCardFloat()
	State.touchdownSequenceActive = false
	State.touchdownFramesReady = false
	TouchdownWaveTransitionCoordinator.Cancel()
	SetTouchdownGameplayGuiOverride(false)
	FOVController.RemoveRequest(TOUCHDOWN_FOV_REQUEST_ID)
	TouchdownShowcaseState.pendingPlayerCard = nil

	if cleanupGoalEffects ~= false and TouchdownShowcaseState.goalPlayback then
		GoalEffects.Cleanup(TouchdownShowcaseState.goalPlayback)
		TouchdownShowcaseState.goalPlayback = nil
	end
	if TouchdownShowcaseState.card then
		TouchdownShowcaseState.card:Destroy()
		TouchdownShowcaseState.card = nil
	end

	ResetTouchdownUi()
	if wasPlayerCardActive or AreTouchdownFramesAtCardExitPositions() then
		SetTouchdownFramesToCardExitPositions()
	elseif restoreHud then
		RestoreTouchdownFrames()
	else
		ResetTouchdownFrames()
	end

	if restoreHud then
		RestoreTouchdownGameplayGui()
	end
end

local function ForceStopTouchdownPresentation(cleanupGoalEffects: boolean?): ()
	TouchdownShowcaseState.token += 1
	CleanupTouchdownShowcase(true, cleanupGoalEffects)
	UpdateUIVisibility()
end

local function StartTouchdownLabelFloat(card: GuiObject, token: number): ()
	StopTouchdownLabelFloat()
	local startedAt = os.clock()
	TouchdownShowcaseState.labelFloatConnection = RunService.RenderStepped:Connect(function()
		if TouchdownShowcaseState.token ~= token or not card.Parent then
			StopTouchdownLabelFloat()
			return
		end

		local elapsed = os.clock() - startedAt
		local yOffset = math.sin(elapsed * TOUCHDOWN_LABEL_FLOAT_SPEED) * TOUCHDOWN_LABEL_FLOAT_AMPLITUDE
		local sway = math.sin(elapsed * TOUCHDOWN_LABEL_FLOAT_SPEED) * TOUCHDOWN_LABEL_FLOAT_ROTATION
		card.Position = UDim2.new(
			TOUCHDOWN_LABEL_END_POSITION.X.Scale,
			TOUCHDOWN_LABEL_END_POSITION.X.Offset,
			TOUCHDOWN_LABEL_END_POSITION.Y.Scale + yOffset,
			TOUCHDOWN_LABEL_END_POSITION.Y.Offset
		)
		card.Rotation = sway
	end)
end

local function StartTouchdownPlayerCardFloat(card: GuiObject, token: number): ()
	StopTouchdownPlayerCardFloat()
	local startedAt = os.clock()
	TouchdownShowcaseState.cardFloatConnection = RunService.RenderStepped:Connect(function()
		if TouchdownShowcaseState.token ~= token or not card.Parent then
			StopTouchdownPlayerCardFloat()
			return
		end

		local elapsed = os.clock() - startedAt
		local xOffset = math.cos(elapsed * TOUCHDOWN_CARD_FLOAT_X_SPEED) * TOUCHDOWN_CARD_FLOAT_X_AMPLITUDE
		local yOffset = math.sin(elapsed * TOUCHDOWN_CARD_FLOAT_Y_SPEED) * TOUCHDOWN_CARD_FLOAT_Y_AMPLITUDE
		local sway = math.sin(elapsed * TOUCHDOWN_CARD_FLOAT_ROTATION_SPEED) * TOUCHDOWN_CARD_FLOAT_ROTATION_AMPLITUDE
		card.Position = UDim2.new(
			TOUCHDOWN_CARD_IDLE_POSITION.X.Scale + xOffset,
			TOUCHDOWN_CARD_IDLE_POSITION.X.Offset,
			TOUCHDOWN_CARD_IDLE_POSITION.Y.Scale + yOffset,
			TOUCHDOWN_CARD_IDLE_POSITION.Y.Offset
		)
		card.Rotation = sway
	end)
end

local function PlayAndWaitTween(tween: Tween): Enum.PlaybackState
	tween:Play()
	return tween.Completed:Wait()
end

local function GetTouchdownPlayerCardHoldDuration(totalDuration: number): number
	local fixedDuration = TOUCHDOWN_PLAYER_CARD_START_DELAY
		+ TOUCHDOWN_CARD_ENTRY_INFO.Time
		+ TOUCHDOWN_CARD_SETTLE_INFO.Time
		+ TOUCHDOWN_CARD_ANTICIPATION_INFO.Time
		+ TOUCHDOWN_CARD_EXIT_INFO.Time
		+ TOUCHDOWN_PLAYER_CARD_FRAME_EXIT_INFO.Time
	return math.max(totalDuration - fixedDuration, TOUCHDOWN_PLAYER_CARD_MIN_HOLD)
end

local function PlayTouchdownPlayerCard(focusPlayerId: number, focusDuration: number): ()
	local pending = TouchdownShowcaseState.pendingPlayerCard
	if not pending then
		local payloadDeadline = os.clock() + TOUCHDOWN_PLAYER_CARD_PAYLOAD_WAIT_TIMEOUT
		while not pending and os.clock() < payloadDeadline do
			task.wait()
			pending = TouchdownShowcaseState.pendingPlayerCard
		end
	end
	if not pending then
		return
	end
	if pending.PlayerId ~= focusPlayerId then
		return
	end
	if not IsLocalPlayerInMatch() then
		return
	end
	TouchdownShowcaseState.pendingPlayerCard = nil

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local gameGui = State.gameGui
	if not gameGui then
		local foundGui = if playerGui then playerGui:FindFirstChild("GameGui") else nil
		if foundGui and foundGui:IsA("ScreenGui") then
			gameGui = foundGui
			State.gameGui = foundGui
		end
	end
	if not gameGui then
		return
	end

	StartTouchdownUiPreload()

	local token = TouchdownShowcaseState.token
	local waitStartedAt = os.clock()
	while TouchdownShowcaseState.token == token and (State.touchdownSequenceActive or not State.touchdownFramesReady) do
		if os.clock() - waitStartedAt >= 1.25 then
			break
		end
		task.wait()
	end
	if TouchdownShowcaseState.token ~= token then
		return
	end

	TouchdownWaveTransitionCoordinator.WaitForCovered(1.5, 0)
	if TouchdownShowcaseState.token ~= token then
		return
	end

	RefreshTouchdownGameplayObjects()
	SetTouchdownGameplayGuiOverride(true)
	if gameGui then
		gameGui.Enabled = true
	end
	RestoreTouchdownGameplayGui()
	UpdateUIVisibility()
	if gameGui then
		gameGui.Enabled = true
	end
	TouchdownWaveTransitionCoordinator.ReleaseAfterDelay()

	if TouchdownShowcaseState.touchdownGui then
		TouchdownShowcaseState.touchdownGui.Enabled = false
	end
	if not playerGui then
		return
	end
	local overlay = EnsureTouchdownOverlay(playerGui)
	if not overlay then
		return
	end
	TouchdownShowcaseState.overlay = overlay
	for _, child in ipairs(overlay:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local overlayGui = overlay:FindFirstAncestorOfClass("ScreenGui")
	if overlayGui then
		overlayGui.Enabled = true
	end

	SetGuiObjectVisible(TouchdownShowcaseState.main, false)
	SetGuiObjectVisible(TouchdownShowcaseState.matchInfo, false)

	local topFrame = TouchdownShowcaseState.topFrame
	local bottomFrame = TouchdownShowcaseState.bottomFrame
	local topGameplayTarget, bottomGameplayTarget = GetTouchdownGameplayFrameTargets()
	local topTarget = TOUCHDOWN_TOP_CARD_POSITION
	local bottomTarget = TOUCHDOWN_BOTTOM_CARD_POSITION
	local frameTopTween = if topFrame
		then TweenService:Create(topFrame, TOUCHDOWN_PLAYER_CARD_FRAME_INFO, { Position = topTarget })
		else nil
	local frameBottomTween = if bottomFrame
		then TweenService:Create(bottomFrame, TOUCHDOWN_PLAYER_CARD_FRAME_INFO, { Position = bottomTarget })
		else nil

	if topFrame then
		if not IsGuiObjectAtPosition(topFrame, topGameplayTarget) then
			topFrame.Position = topGameplayTarget
		end
	end
	if bottomFrame then
		if not IsGuiObjectAtPosition(bottomFrame, bottomGameplayTarget) then
			bottomFrame.Position = bottomGameplayTarget
		end
	end
	SetTouchdownFramesVisible(true)
	RunService.RenderStepped:Wait()
	if TouchdownShowcaseState.token ~= token then
		return
	end
	if frameTopTween then
		frameTopTween:Play()
	end
	if frameBottomTween then
		frameBottomTween:Play()
	end

	overlay.Visible = true
	task.wait(TOUCHDOWN_PLAYER_CARD_START_DELAY)
	if TouchdownShowcaseState.token ~= token then
		return
	end

	WaitForTouchdownUiPreload(TOUCHDOWN_PRELOAD_WAIT_TIMEOUT)
	if TouchdownShowcaseState.token ~= token then
		return
	end

	local cardTemplate = ResolveTouchdownCardTemplate(pending.CardName)
	if not cardTemplate then
		overlay.Visible = false
		RestoreTouchdownGameplayGui()
		UpdateUIVisibility()
		return
	end

	local cardClone = cardTemplate:Clone() :: GuiObject
	cardClone.AnchorPoint = Vector2.new(0.5, 0.5)
	cardClone.Position = TOUCHDOWN_CARD_START_POSITION
	cardClone.Rotation = TOUCHDOWN_CARD_ENTRY_ROTATION
	cardClone.Visible = true
	cardClone.Parent = overlay
	BoostGuiZIndex(cardClone, TOUCHDOWN_CARD_ZINDEX_BOOST)
	ApplyTouchdownCardData(cardClone, pending.PlayerId, pending.Touchdowns, pending.Passing, pending.Tackles)
	TouchdownShowcaseState.card = cardClone

	local cardScale = cardClone:FindFirstChildOfClass("UIScale")
	if not cardScale then
		cardScale = Instance.new("UIScale")
		cardScale.Parent = cardClone
	end
	cardScale.Scale = TOUCHDOWN_CARD_ENTRY_SCALE

	local entryTween = TweenService:Create(cardClone, TOUCHDOWN_CARD_ENTRY_INFO, {
		Position = TOUCHDOWN_CARD_ENTRY_POSITION,
		Rotation = TOUCHDOWN_CARD_ENTRY_TARGET_ROTATION,
	})
	local entryScaleTween = TweenService:Create(cardScale, TOUCHDOWN_CARD_ENTRY_INFO, {
		Scale = TOUCHDOWN_CARD_ENTRY_TARGET_SCALE,
	})
	entryScaleTween:Play()
	PlayAndWaitTween(entryTween)
	if TouchdownShowcaseState.token ~= token or not cardClone.Parent then
		return
	end

	local settleTween = TweenService:Create(cardClone, TOUCHDOWN_CARD_SETTLE_INFO, {
		Position = TOUCHDOWN_CARD_IDLE_POSITION,
		Rotation = TOUCHDOWN_CARD_IDLE_ROTATION,
	})
	local settleScaleTween = TweenService:Create(cardScale, TOUCHDOWN_CARD_SETTLE_INFO, {
		Scale = TOUCHDOWN_CARD_IDLE_SCALE,
	})
	settleScaleTween:Play()
	PlayAndWaitTween(settleTween)
	if TouchdownShowcaseState.token ~= token or not cardClone.Parent then
		return
	end

	StartTouchdownPlayerCardFloat(cardClone, token)

	local totalDuration = if focusDuration > 0 then focusDuration else TOUCHDOWN_SEQUENCE_DEFAULT_DURATION
	local holdDuration = GetTouchdownPlayerCardHoldDuration(totalDuration)
	task.wait(holdDuration)
	if TouchdownShowcaseState.token ~= token or not cardClone.Parent then
		return
	end

	StopTouchdownPlayerCardFloat()

	local anticipationTween = TweenService:Create(cardClone, TOUCHDOWN_CARD_ANTICIPATION_INFO, {
		Position = TOUCHDOWN_CARD_ANTICIPATION_POSITION,
		Rotation = TOUCHDOWN_CARD_ANTICIPATION_ROTATION,
	})
	local anticipationScaleTween = TweenService:Create(cardScale, TOUCHDOWN_CARD_ANTICIPATION_INFO, {
		Scale = TOUCHDOWN_CARD_ANTICIPATION_SCALE,
	})
	anticipationScaleTween:Play()
	PlayAndWaitTween(anticipationTween)
	if TouchdownShowcaseState.token ~= token or not cardClone.Parent then
		return
	end

	local exitTween = TweenService:Create(cardClone, TOUCHDOWN_CARD_EXIT_INFO, {
		Position = TOUCHDOWN_CARD_EXIT_POSITION,
		Rotation = TOUCHDOWN_CARD_EXIT_ROTATION,
	})
	local exitScaleTween = TweenService:Create(cardScale, TOUCHDOWN_CARD_EXIT_INFO, {
		Scale = TOUCHDOWN_CARD_EXIT_SCALE,
	})
	exitScaleTween:Play()
	PlayAndWaitTween(exitTween)
	if TouchdownShowcaseState.token ~= token then
		return
	end

	if TouchdownShowcaseState.card == cardClone then
		TouchdownShowcaseState.card = nil
	end
	cardClone:Destroy()
	local frameTopExitTween = if topFrame
		then TweenService:Create(
			topFrame,
			TOUCHDOWN_PLAYER_CARD_FRAME_EXIT_INFO,
			{ Position = TOUCHDOWN_TOP_CARD_EXIT_POSITION }
		)
		else nil
	local frameBottomExitTween = if bottomFrame
		then TweenService:Create(
			bottomFrame,
			TOUCHDOWN_PLAYER_CARD_FRAME_EXIT_INFO,
			{ Position = TOUCHDOWN_BOTTOM_CARD_EXIT_POSITION }
		)
		else nil
	if frameTopExitTween then
		frameTopExitTween:Play()
	end
	if frameBottomExitTween then
		frameBottomExitTween:Play()
	end
	WaitForTouchdownFrameTweens(frameTopExitTween, frameBottomExitTween)
	overlay.Visible = false
	if TouchdownShowcaseState.token ~= token then
		return
	end
	gameGui.Enabled = true
	UpdateUIVisibility()
end

local function PlayTouchdownShowcase(
	playerId: number,
	cardName: string,
	touchdowns: number,
	passing: number,
	tackles: number,
	duration: number
): ()
	if not IsLocalPlayerInMatch() then
		return
	end

	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	StartTouchdownUiPreload()

	local gameGui = State.gameGui
	if not gameGui then
		local foundGui = playerGui:FindFirstChild("GameGui")
		if foundGui and foundGui:IsA("ScreenGui") then
			gameGui = foundGui
			State.gameGui = foundGui
		end
	end
	if not gameGui then
		return
	end

	CleanupTouchdownShowcase(false, true)
	TouchdownShowcaseState.token += 1
	local token = TouchdownShowcaseState.token
	local main = gameGui:FindFirstChild("Main")
	local matchInfo = gameGui:FindFirstChild("MatchInfo")
	local topFrameInstance = gameGui:FindFirstChild("Framecima")
	local bottomFrameInstance = gameGui:FindFirstChild("Framebaixo")
	local topFrame = if topFrameInstance and topFrameInstance:IsA("GuiObject") then topFrameInstance else nil
	local bottomFrame = if bottomFrameInstance and bottomFrameInstance:IsA("GuiObject") then bottomFrameInstance else nil
	local touchdownGuiInstance = playerGui:FindFirstChild("TouchdownUI")
	if not touchdownGuiInstance then
		touchdownGuiInstance = playerGui:WaitForChild("TouchdownUI", TOUCHDOWN_PRELOAD_WAIT_TIMEOUT)
	end
	local touchdownGui = if touchdownGuiInstance and touchdownGuiInstance:IsA("ScreenGui") then touchdownGuiInstance else nil
	local touchdownRoot = FindGuiObject(touchdownGui, "Touchdown")
	local touchdownImage = FindGuiObject(touchdownRoot, "ImageLabel")
	local touchdownLabel = FindGuiObject(touchdownRoot, "TouchdownLabel")
	local scoringTeam = ResolveScoringTeam(playerId)

	TouchdownShowcaseState.overlay = nil
	TouchdownShowcaseState.card = nil
	TouchdownShowcaseState.touchdownGui = touchdownGui
	TouchdownShowcaseState.touchdownRoot = touchdownRoot
	TouchdownShowcaseState.touchdownImage = touchdownImage
	TouchdownShowcaseState.touchdownLabel = touchdownLabel
	TouchdownShowcaseState.main = if main and main:IsA("GuiObject") then main else nil
	TouchdownShowcaseState.matchInfo = if matchInfo and matchInfo:IsA("GuiObject") then matchInfo else nil
	TouchdownShowcaseState.topFrame = topFrame
	TouchdownShowcaseState.bottomFrame = bottomFrame
	TouchdownShowcaseState.mainWasVisible = if TouchdownShowcaseState.main then TouchdownShowcaseState.main.Visible else true
	TouchdownShowcaseState.matchInfoWasVisible = if TouchdownShowcaseState.matchInfo then TouchdownShowcaseState.matchInfo.Visible else true
	TouchdownShowcaseState.touchdownGuiDisplayOrder = if touchdownGui then touchdownGui.DisplayOrder else 0
	TouchdownShowcaseState.touchdownRootWasVisible = if touchdownRoot then touchdownRoot.Visible else true
	TouchdownShowcaseState.touchdownImageWasVisible = if touchdownImage then touchdownImage.Visible else true
	TouchdownShowcaseState.touchdownLabelWasVisible = if touchdownLabel then touchdownLabel.Visible else true
	TouchdownShowcaseState.pendingPlayerCard = {
		PlayerId = playerId,
		CardName = cardName,
		Touchdowns = touchdowns,
		Passing = passing,
		Tackles = tackles,
	}
	CaptureTouchdownFrameDefaults(topFrame, bottomFrame)
	TouchdownShowcaseState.goalPlayback = GoalEffects.Play(playerGui, scoringTeam or 0, GOAL_EFFECT_NAME)

	WaitForTouchdownUiPreload(TOUCHDOWN_PRELOAD_WAIT_TIMEOUT)

	State.touchdownSequenceActive = true
	State.touchdownFramesReady = false
	FOVController.AddRequest(TOUCHDOWN_FOV_REQUEST_ID, TOUCHDOWN_FOV_TARGET, nil, {
		TweenInfo = TOUCHDOWN_FOV_TWEEN_INFO,
	})
	SetGuiObjectVisible(TouchdownShowcaseState.main, false)
	SetGuiObjectVisible(TouchdownShowcaseState.matchInfo, false)
	gameGui.Enabled = false
	ResetTouchdownFrames()
	ResetTouchdownUi()
	SoundController:Play("Touchdown", { Volume = TOUCHDOWN_SHOWCASE_SOUND_VOLUME })

	if not touchdownGui or not touchdownImage or not touchdownLabel then
		task.delay(if duration > 0 then duration else TOUCHDOWN_SEQUENCE_DEFAULT_DURATION, function(): ()
			if TouchdownShowcaseState.token ~= token then
				return
			end

			CleanupTouchdownShowcase(true, false)
			UpdateUIVisibility()
		end)
		return
	end

	touchdownGui.DisplayOrder = math.max(TouchdownShowcaseState.touchdownGuiDisplayOrder, TOUCHDOWN_CARD_DISPLAY_ORDER)
	touchdownGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	touchdownGui.Enabled = true
	SetGuiObjectVisible(touchdownRoot, true)
	SetGuiObjectVisible(touchdownImage, true)
	SetGuiObjectVisible(touchdownLabel, true)
	touchdownImage.Position = TOUCHDOWN_IMAGE_START_POSITION
	touchdownImage.Rotation = 0
	touchdownLabel.Position = TOUCHDOWN_LABEL_START_POSITION
	touchdownLabel.Rotation = 0

	local totalDuration = if duration > 0 then duration else TOUCHDOWN_SEQUENCE_DEFAULT_DURATION
	local holdDuration = math.max(totalDuration - TOUCHDOWN_SEQUENCE_FIXED_TIME, TOUCHDOWN_SEQUENCE_MIN_HOLD_TIME)

	PlayAndWaitTween(TweenService:Create(touchdownImage, TOUCHDOWN_IMAGE_ENTRY_INFO, {
		Position = TOUCHDOWN_IMAGE_END_POSITION,
	}))
	if TouchdownShowcaseState.token ~= token then
		return
	end

	PlayAndWaitTween(TweenService:Create(touchdownLabel, TOUCHDOWN_LABEL_ENTRY_INFO, {
		Position = TOUCHDOWN_LABEL_END_POSITION,
	}))
	if TouchdownShowcaseState.token ~= token then
		return
	end

	StartTouchdownLabelFloat(touchdownLabel, token)
	task.wait(holdDuration)
	if TouchdownShowcaseState.token ~= token then
		return
	end

	StopTouchdownLabelFloat()

	local imageExitTween = TweenService:Create(touchdownImage, TOUCHDOWN_IMAGE_EXIT_INFO, {
		Position = TOUCHDOWN_IMAGE_START_POSITION,
	})
	local labelExitTween = TweenService:Create(touchdownLabel, TOUCHDOWN_LABEL_EXIT_INFO, {
		Position = TOUCHDOWN_LABEL_START_POSITION,
	})
	imageExitTween:Play()
	labelExitTween:Play()

	imageExitTween.Completed:Wait()
	labelExitTween.Completed:Wait()
	if TouchdownShowcaseState.token ~= token then
		return
	end

	ResetTouchdownUi()
	PresetTouchdownGameplayFrames()
	gameGui.Enabled = true
	State.touchdownSequenceActive = false
	PrimeTouchdownGameplayFrames()
	if not PlayTouchdownGameplayReveal(token) then
		return
	end

	UpdateUIVisibility()
	ScheduleTouchdownGameplayGuiRestore(token)
end

--\\ PRIVATE FUNCTIONS \\ -- TR
IsLocalPlayerInMatch = function(): boolean
	return MatchPlayerUtils.IsPlayerActive(LocalPlayer)
end

local function UpdateLeaveMatchButtonState(): ()
	local ExitButton = State.matchInfoExitButton
	if not ExitButton then
		return
	end

	local Enabled = IsLocalPlayerInMatch()
		and not State.leaveMatchPending
		and os.clock() >= State.leaveMatchCooldownUntil
	ExitButton.Visible = true
	ExitButton.Active = Enabled
	ExitButton.AutoButtonColor = Enabled
end

local function RequestLeaveMatch(): ()
	if not IsLocalPlayerInMatch() then
		return
	end
	if State.leaveMatchPending then
		return
	end
	if os.clock() < State.leaveMatchCooldownUntil then
		return
	end

	State.leaveMatchPending = true
	State.leaveMatchCooldownUntil = os.clock() + LEAVE_MATCH_BUTTON_COOLDOWN
	UpdateLeaveMatchButtonState()
	if CountdownController and CountdownController.ForceCleanupVisuals then
		CountdownController.ForceCleanupVisuals()
	end
	PlayLeaveMatchTransition()

	task.delay(LEAVE_MATCH_REQUEST_DELAY, function()
		if Packets and Packets.LeaveMatch and Packets.LeaveMatch.Fire then
			Packets.LeaveMatch:Fire()
		end
	end)

	task.delay(LEAVE_MATCH_BUTTON_COOLDOWN, function()
		State.leaveMatchPending = false
		UpdateLeaveMatchButtonState()
	end)
end

local function GetInstanceBounds(target: Instance): (CFrame?, Vector3?)
	if target:IsA("BasePart") then
		return target.CFrame, target.Size
	end

	if target:IsA("Model") then
		return target:GetBoundingBox()
	end

	local minBound: Vector3? = nil
	local maxBound: Vector3? = nil
	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			local cf = descendant.CFrame
			local size = descendant.Size
			local half = size * 0.5
			local corners = {
				cf:PointToWorldSpace(Vector3.new(half.X, half.Y, half.Z)),
				cf:PointToWorldSpace(Vector3.new(half.X, half.Y, -half.Z)),
				cf:PointToWorldSpace(Vector3.new(half.X, -half.Y, half.Z)),
				cf:PointToWorldSpace(Vector3.new(half.X, -half.Y, -half.Z)),
				cf:PointToWorldSpace(Vector3.new(-half.X, half.Y, half.Z)),
				cf:PointToWorldSpace(Vector3.new(-half.X, half.Y, -half.Z)),
				cf:PointToWorldSpace(Vector3.new(-half.X, -half.Y, half.Z)),
				cf:PointToWorldSpace(Vector3.new(-half.X, -half.Y, -half.Z)),
			}
			for _, corner in corners do
				if not minBound then
					minBound = corner
					maxBound = corner
				else
					minBound = Vector3.new(
						math.min(minBound.X, corner.X),
						math.min(minBound.Y, corner.Y),
						math.min(minBound.Z, corner.Z)
					)
					maxBound = Vector3.new(
						math.max(maxBound.X, corner.X),
						math.max(maxBound.Y, corner.Y),
						math.max(maxBound.Z, corner.Z)
					)
				end
			end
		end
	end

	if not minBound or not maxBound then
		return nil, nil
	end

	local center = (minBound + maxBound) * 0.5
	local size = maxBound - minBound
	return CFrame.new(center), size
end

local function IsPointInsideBounds(point: Vector3, boundsCFrame: CFrame, boundsSize: Vector3, padding: Vector3?): boolean
	local extra = padding or Vector3.zero
	local localPoint = boundsCFrame:PointToObjectSpace(point)
	local half = (boundsSize * 0.5) + extra
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local function IsLocalPlayerInLobby(): boolean
	local Character = LocalPlayer.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		return false
	end

	local Lobby = Workspace:FindFirstChild("Lobby")
	if not Lobby then
		return false
	end

	local boundsCFrame, boundsSize = GetInstanceBounds(Lobby)
	if not boundsCFrame or not boundsSize then
		return false
	end

	return IsPointInsideBounds(Root.Position, boundsCFrame, boundsSize, LOBBY_STATE_PADDING)
end

local function UpdateLobbyState(): ()
	local InLobby = IsLocalPlayerInLobby()
	local Character = LocalPlayer.Character
	if LocalPlayer:GetAttribute(IN_LOBBY_ATTRIBUTE) ~= InLobby then
		LocalPlayer:SetAttribute(IN_LOBBY_ATTRIBUTE, InLobby)
	end
	if Character and Character:GetAttribute(IN_LOBBY_ATTRIBUTE) ~= InLobby then
		Character:SetAttribute(IN_LOBBY_ATTRIBUTE, InLobby)
	end
	if State.lastLobbyState == InLobby then
		return
	end

	State.lastLobbyState = InLobby
end

local function ResolveScoreLabel(ScoreboardRoot: Instance, TeamName: string): TextLabel?
	local TeamNode: Instance = ScoreboardRoot:WaitForChild(TeamName)
	if TeamNode:IsA("TextLabel") then
		return TeamNode
	end

	local DirectScore: Instance? = TeamNode:FindFirstChild("Score")
	if DirectScore and DirectScore:IsA("TextLabel") then
		return DirectScore
	end

	local AnyTextLabel: TextLabel? = TeamNode:FindFirstChildWhichIsA("TextLabel", true)
	return AnyTextLabel
end

local function InitializeScoreboard(): ()
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	State.gameGui = PlayerGui:WaitForChild("GameGui") :: ScreenGui
	State.hudGui = PlayerGui:WaitForChild("HudGui") :: ScreenGui
	
	local MatchInfo = State.gameGui:WaitForChild("MatchInfo")
	local Content = MatchInfo:WaitForChild("Content")
	local ScoreHolder = Content:WaitForChild("ScoreHolder")
	local ScoreboardRoot = ScoreHolder:FindFirstChild("Scoreboard") or ScoreHolder
	local ExitButton = State.gameGui:FindFirstChild("Exit") or MatchInfo:FindFirstChild("Exit", true)

	State.team1ScoreLabel = ResolveScoreLabel(ScoreboardRoot, "1Team")
	State.team2ScoreLabel = ResolveScoreLabel(ScoreboardRoot, "2Team")
	
	local TimerHolder = ScoreHolder:FindFirstChild("TimerHolder")
		or ScoreHolder:FindFirstChild("TimerHolder", true)
		or Content:FindFirstChild("TimerHolder")
	if TimerHolder then
		State.timerLabel = TimerHolder:WaitForChild("Timer") :: TextLabel
	end
	
	State.intermissionLabel = State.hudGui:WaitForChild("TimeLabel") :: TextLabel
	State.stateLabel = State.gameGui:FindFirstChild("StateLabel", true) :: TextLabel?
	State.matchInfoExitButton = if ExitButton and ExitButton:IsA("GuiButton") then ExitButton else nil
	if State.matchInfoExitButton then
		State.matchInfoExitButton.Visible = true
		table.insert(State.connections, State.matchInfoExitButton.Activated:Connect(function()
			RequestLeaveMatch()
		end))
	end

	State.gameGui.Enabled = false
	State.hudGui.Enabled = false
	UpdateLeaveMatchButtonState()
end

local HandleCountdownChange: (boolean, number) -> ()

UpdateUIVisibility = function(): ()
	ResolveRuntimeGuis()
	--\\ STRICT VISIBILITY CONTROL \\ -- TR
	if not State.loadingFinished then
		if State.hudGui then
			State.hudGui.Enabled = false
		end
		if State.gameGui then
			State.gameGui.Enabled = false
		end
		UpdateLeaveMatchButtonState()
		return
	end

	local PositionSelectionActive = LocalPlayer:GetAttribute(POSITION_SELECTION_ACTIVE_ATTRIBUTE) == true
	local InLobby = LocalPlayer:GetAttribute(IN_LOBBY_ATTRIBUTE) == true
	if PositionSelectionActive then
		if State.hudGui then
			State.hudGui.Enabled = false
		end
		if State.gameGui then
			State.gameGui.Enabled = false
		end
		UpdateLeaveMatchButtonState()
		return
	end

	if State.touchdownSequenceActive then
		if State.hudGui then
			State.hudGui.Enabled = false
		end
		if State.gameGui then
			State.gameGui.Enabled = false
		end
		UpdateLeaveMatchButtonState()
		return
	end

	if State.touchdownPlayerCardActive then
		if State.hudGui then
			State.hudGui.Enabled = false
		end
		if State.gameGui then
			State.gameGui.Enabled = true
		end
		SetTouchdownFramesVisible(State.touchdownFramesVisible)
		UpdateLeaveMatchButtonState()
		return
	end

	if GameplayGuiVisibility.IsGameplayGuiBlocked(LocalPlayer) then
		GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
		UpdateLeaveMatchButtonState()
		return
	end

	local InMatch = IsLocalPlayerInMatch()
	
	if InMatch then
		if State.hudGui then
			State.hudGui.Enabled = false
		end
		if State.gameGui then
			State.gameGui.Enabled = true
		end
		local GameState = ReplicatedStorage:FindFirstChild("FTGameState")
		local CountdownActive = GameState and GameState:FindFirstChild("CountdownActive") :: BoolValue?
		local CountdownTime = GameState and GameState:FindFirstChild("CountdownTime") :: IntValue?
		if CountdownActive and CountdownTime and CountdownActive.Value then
			HandleCountdownChange(true, CountdownTime.Value)
		end
	else
		CleanupTouchdownShowcase(true)
		if State.gameGui then
			State.gameGui.Enabled = false
		end
		if State.hudGui then
			State.hudGui.Enabled = InLobby
		end
	end
	UpdateLeaveMatchButtonState()
end

local function AnimateScore(Label: TextLabel?, Score: number): ()
	if not Label then return end
	
	local OldText = Label.Text
	Label.Text = tostring(Score)
	
	if OldText ~= Label.Text then
		local OriginalSize = Label.Size
		local ScaleUpTween = TweenService:Create(Label, SCORE_TWEEN_INFO, {
			Size = UDim2.new(OriginalSize.X.Scale * 1.2, OriginalSize.X.Offset, OriginalSize.Y.Scale * 1.2, OriginalSize.Y.Offset)
		})
		ScaleUpTween:Play()
		ScaleUpTween.Completed:Once(function()
			TweenService:Create(Label, SCORE_TWEEN_INFO, { Size = OriginalSize }):Play()
		end)
	end
end

local function UpdateScore(Team1Score: number, Team2Score: number): ()
	AnimateScore(State.team1ScoreLabel, Team1Score)
	AnimateScore(State.team2ScoreLabel, Team2Score)
end

local function FormatTime(Seconds: number): string
	return string.format("%d:%02d", math.floor(Seconds / 60), Seconds % 60)
end

local function AnimateCountdownText(Text: string): ()
	if not State.stateLabel then return end
	
	State.stateLabel.Text = Text
	State.stateLabel.Visible = true
	
	local OriginalSize = State.stateLabel.Size
	State.stateLabel.Size = UDim2.new(OriginalSize.X.Scale * 0.5, OriginalSize.X.Offset, OriginalSize.Y.Scale * 0.5, OriginalSize.Y.Offset)
	
	local ScaleTween = TweenService:Create(State.stateLabel, COUNTDOWN_TWEEN_INFO, { Size = OriginalSize })
	ScaleTween:Play()
end

local function PlayNotifySound(message: string, description: string?): ()
	local upperMessage = string.upper(message)
	local upperDescription = string.upper(description or "")
	if string.find(upperMessage, "FIELD GOAL", 1, true) then
		SoundController:Play("FieldGoal")
	elseif string.find(upperMessage, "SAFETY", 1, true) then
		SoundController:Play("Safety")
	elseif string.find(upperDescription, "LOST ", 1, true) then
		SoundController:Play("Down", { Volume = LOST_YARDS_NOTIFY_SOUND_VOLUME })
	elseif string.find(upperMessage, "INCOMPLETE PASS", 1, true)
		or string.find(upperMessage, "DOWN", 1, true)
	then
		SoundController:Play("Down")
	end
end

local function HandleIntermissionChange(Active: boolean, IntermissionTime: IntValue, GameTime: IntValue): ()
	if Active then
		if State.intermissionLabel then 
			--State.intermissionLabel.Text = tostring(IntermissionTime.Value) 
		--	State.intermissionLabel.Visible = true
		end
		UpdateUIVisibility()
	else
		if State.intermissionLabel then 
			--\\ SET TEXT TO ENTER MATCH WHEN INTERMISSION ENDS \\ -- TR
			--State.intermissionLabel.Text = "ENTER THE MATCH"
			--State.intermissionLabel.Visible = true
		end
		
		if State.timerLabel then 
			State.timerLabel.Text = FormatTime(GameTime.Value) 
		end
		
		UpdateUIVisibility()
	end
end

HandleCountdownChange = function(Active: boolean, CountdownTime: number): ()
	local InMatch = IsLocalPlayerInMatch()
	if Active and InMatch then
		if State.stateLabel then
			AnimateCountdownText("STARTING IN " .. CountdownTime .. "s")
		end
	end
end

local function HandleMatchStarted(Started: boolean): ()
	local InMatch = IsLocalPlayerInMatch()
	if Started and InMatch then
		if State.stateLabel then
			AnimateCountdownText("MATCH STARTED")
			task.delay(2, function()
				if State.stateLabel then
					State.stateLabel.Visible = false
				end
			end)
		end
	end
end

local function BindMatchPositionChanges(): ()
	local GameState = ReplicatedStorage:FindFirstChild("FTGameState")
	if not GameState then return end
	
	local MatchFolder = GameState:FindFirstChild("Match")
	if not MatchFolder then return end
	
	for _, TeamFolder in MatchFolder:GetChildren() do
		for _, PositionValue in TeamFolder:GetChildren() do
			if PositionValue:IsA("IntValue") then
				table.insert(State.connections, PositionValue.Changed:Connect(function()
					UpdateUIVisibility()
				end))
			end
		end
	end
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function FTGameController:Start(): ()
	InitializeScoreboard()
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	task.spawn(StartTouchdownUiPreload)
	table.insert(State.connections, PlayerGui.DescendantAdded:Connect(function(child: Instance)
		if child.Name == "TouchdownUI" then
			task.spawn(StartTouchdownUiPreload)
		end
	end))
	local loadingGui = PlayerGui:FindFirstChild("LoadingGui")
	if loadingGui then
		table.insert(State.connections, loadingGui.AncestryChanged:Connect(function(_child, parent)
			if parent == nil then
				self:FinishLoading()
			end
		end))
	else
		self:FinishLoading()
	end
	
	local GameState = ReplicatedStorage:WaitForChild("FTGameState")
	local GameTime = GameState:WaitForChild("GameTime") :: IntValue
	local IntermissionTime = GameState:WaitForChild("IntermissionTime") :: IntValue
	local Team1Score = GameState:WaitForChild("Team1Score") :: IntValue
	local Team2Score = GameState:WaitForChild("Team2Score") :: IntValue
	local IntermissionActive = GameState:WaitForChild("IntermissionActive") :: BoolValue
	local CountdownTime = GameState:WaitForChild("CountdownTime") :: IntValue
	local CountdownActive = GameState:WaitForChild("CountdownActive") :: BoolValue
	local MatchStarted = GameState:WaitForChild("MatchStarted") :: BoolValue
	State.lastMatchStarted = MatchStarted.Value
	
	table.insert(State.connections, GameTime.Changed:Connect(function(Value)
		local InMatch = IsLocalPlayerInMatch()
		if not IntermissionActive.Value and MatchStarted.Value and State.timerLabel and InMatch then
			State.timerLabel.Text = FormatTime(Value)
		end
	end))
	
	table.insert(State.connections, IntermissionTime.Changed:Connect(function(Value)
		if IntermissionActive.Value and State.intermissionLabel then
		--	State.intermissionLabel.Text = tostring(Value)
		end
	end))
	
	table.insert(State.connections, Team1Score.Changed:Connect(function()
		UpdateScore(Team1Score.Value, Team2Score.Value)
	end))
	
	table.insert(State.connections, Team2Score.Changed:Connect(function()
		UpdateScore(Team1Score.Value, Team2Score.Value)
	end))
	
	table.insert(State.connections, IntermissionActive.Changed:Connect(function(Active)
		HandleIntermissionChange(Active, IntermissionTime, GameTime)
	end))
	
	table.insert(State.connections, CountdownTime.Changed:Connect(function(Value)
		if CountdownActive.Value then
			HandleCountdownChange(true, Value)
		end
	end))
	
	table.insert(State.connections, CountdownActive.Changed:Connect(function(Active)
		if not Active and not MatchStarted.Value and State.stateLabel then
			State.stateLabel.Visible = false
		end
	end))
	
	table.insert(State.connections, MatchStarted.Changed:Connect(function(Started)
		HandleMatchStarted(Started)
		local inMatch = IsLocalPlayerInMatch()
		if Started and not State.lastMatchStarted and inMatch then
			SoundController:Play("GameStart")
		elseif not Started and State.lastMatchStarted and inMatch then
			SoundController:Play("GameEnd")
		end
		State.lastMatchStarted = Started
	end))

	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal("FTSessionId"):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal(MatchPlayerUtils.GetMatchActiveAttributeName()):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal("FTCutsceneHudHidden"):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal("FTMatchCutsceneLocked"):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal(ATTR_PERFECT_PASS_CUTSCENE_LOCKED):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal(ATTR_AWAKEN_ACTIVE):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal(ATTR_AWAKEN_CUTSCENE_ACTIVE):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal(POSITION_SELECTION_ACTIVE_ATTRIBUTE):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, LocalPlayer:GetAttributeChangedSignal(IN_LOBBY_ATTRIBUTE):Connect(function()
		UpdateUIVisibility()
	end))
	table.insert(State.connections, RunService.Heartbeat:Connect(function()
		local Now: number = os.clock()
		if Now < State.nextLobbyStatePollAt then
			return
		end
		State.nextLobbyStatePollAt = Now + LOBBY_STATE_POLL_INTERVAL
		UpdateLobbyState()
	end))
	table.insert(State.connections, LocalPlayer.CharacterAdded:Connect(function(Character)
		UpdateLobbyState()
		table.insert(State.connections, Character:GetAttributeChangedSignal(ATTR_AWAKEN_ACTIVE):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, Character:GetAttributeChangedSignal(ATTR_AWAKEN_CUTSCENE_ACTIVE):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, Character:GetAttributeChangedSignal("FTCutsceneHudHidden"):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, Character:GetAttributeChangedSignal("FTMatchCutsceneLocked"):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, Character:GetAttributeChangedSignal(ATTR_PERFECT_PASS_CUTSCENE_LOCKED):Connect(function()
			UpdateUIVisibility()
		end))
		UpdateUIVisibility()
	end))
	if LocalPlayer.Character then
		table.insert(State.connections, LocalPlayer.Character:GetAttributeChangedSignal(ATTR_AWAKEN_ACTIVE):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, LocalPlayer.Character:GetAttributeChangedSignal(ATTR_AWAKEN_CUTSCENE_ACTIVE):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, LocalPlayer.Character:GetAttributeChangedSignal("FTCutsceneHudHidden"):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, LocalPlayer.Character:GetAttributeChangedSignal("FTMatchCutsceneLocked"):Connect(function()
			UpdateUIVisibility()
		end))
		table.insert(State.connections, LocalPlayer.Character:GetAttributeChangedSignal(ATTR_PERFECT_PASS_CUTSCENE_LOCKED):Connect(function()
			UpdateUIVisibility()
		end))
	end

	table.insert(State.connections, Packets.TeleportFade.OnClientEvent:Connect(function(duration: number)
		if not IsLocalPlayerInMatch() then
			return
		end
		PlayTeleportFade(duration)
		PlayPlayerHighlightFade(duration)
	end))
	table.insert(State.connections, Packets.ScoreNotify.OnClientEvent:Connect(function(message: string, description: string, duration: number)
		CountdownController.Notify(message, description, duration)
		PlayNotifySound(message, description)
	end))
	table.insert(State.connections, Packets.TouchdownShowcase.OnClientEvent:Connect(function(
		playerId: number,
		cardName: string,
		touchdowns: number,
		passing: number,
		tackles: number,
		duration: number
	)
		task.spawn(PlayTouchdownShowcase, playerId, cardName, touchdowns, passing, tackles, duration)
	end))
	table.insert(State.connections, Packets.ExtraPointPreCam.OnClientEvent:Connect(function(
		playerId: number,
		duration: number,
		mode: string?
	)
		local camMode = if typeof(mode) == "string" then string.lower(mode) else ""
		if camMode == "front" then
			TouchdownShowcaseState.pendingPlayerCard = nil
			return
		end

		local pending = TouchdownShowcaseState.pendingPlayerCard
		if not pending or pending.PlayerId ~= playerId then
			return
		end

		ResolveRuntimeGuis()
		RefreshTouchdownGameplayObjects()
		if State.gameGui then
			State.gameGui.Enabled = false
		end
		TouchdownWaveTransitionCoordinator.BeginInAsync()
		task.spawn(PlayTouchdownPlayerCard, playerId, duration)
	end))
	table.insert(State.connections, Packets.ExtraPointStart.OnClientEvent:Connect(function()
		ForceStopTouchdownPresentation(false)
	end))
	table.insert(State.connections, Packets.ExtraPointEnd.OnClientEvent:Connect(function()
		ForceStopTouchdownPresentation(false)
	end))
	
	table.insert(State.connections, GameState.ChildAdded:Connect(function(Child)
		if Child.Name == "Match" then
			BindMatchPositionChanges()
		end
	end))
	
	local MatchFolder = GameState:FindFirstChild("Match")
	if MatchFolder then
		BindMatchPositionChanges()
	end
	
	UpdateScore(Team1Score.Value, Team2Score.Value)
	UpdateLobbyState()
	HandleIntermissionChange(IntermissionActive.Value, IntermissionTime, GameTime)
end

function FTGameController:FinishLoading(): ()
	State.loadingFinished = true
	UpdateLobbyState()
	UpdateUIVisibility()
end

return FTGameController
