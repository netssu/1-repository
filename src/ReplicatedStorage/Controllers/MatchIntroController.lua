--!strict

local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)
local GameplayGuiVisibility = require(ReplicatedStorage.Modules.Game.GameplayGuiVisibility)
local MatchIntroConfig = require(ReplicatedStorage.Modules.Game.MatchIntroConfig)
local SkillAssetPreloader = require(ReplicatedStorage.Modules.Game.Skills.Utils.SkillAssetPreloader)
local WaveTransition = require(ReplicatedStorage.Modules.WaveTransition)
local CutsceneRigUtils = require(ReplicatedStorage.Modules.Game.Skills.VFX.Client.Init.CutsceneRigUtils)
local CameraController = require(ReplicatedStorage.Controllers.CameraController)
local FOVController = require(ReplicatedStorage.Controllers.FOVController)

local MatchIntroController = {}

local LocalPlayer: Player = Players.LocalPlayer

local ATTR_CUTSCENE_HUD_HIDDEN: string = "FTCutsceneHudHidden"
local ATTR_MATCH_CUTSCENE_LOCKED: string = "FTMatchCutsceneLocked"
local SHIFTLOCK_BLOCKER_NAME: string = "MatchIntroCutscene"
local CAMERA_BIND_NAME: string = "MatchIntroCamera"
local INTRO_FOV_REQUEST_ID: string = "MatchIntroController::Intro"
local INTRO_FOV_TWEEN: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local INTRO_CAMERA_FOV: number = 70
local REFERENCE_TRACK_START_EPSILON: number = 1 / 120
local REFERENCE_TRACK_END_EPSILON: number = 1 / 30
local REFERENCE_TRACK_STOP_GRACE_TIME: number = 0.15
local TRACK_PLAY_RETRY_ATTEMPTS: number = 6
local TRACK_PLAY_RETRY_DELAY: number = 0.08
local TRACK_START_VERIFY_HEARTBEATS: number = 4
local REFERENCE_TRACK_TRANSITION_MARKER: string = "transition"
local REFERENCE_TRACK_FREEZE_MARKER: string = "freeze"
local TRANSITION_IN_INFO: TweenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TRANSITION_OUT_INFO: TweenInfo = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local TRANSITION_COVER_RENDER_STEPS: number = 2
local TRANSITION_UNLOCK_WAIT_TIMEOUT: number = MatchIntroConfig.ACK_TIMEOUT
local GAMEPLAY_CAMERA_RESTORE_TIMEOUT: number = 2
local PREPARED_SCENE_ACQUIRE_TIMEOUT: number = 0.35
local INTRO_PREPARATION_BATCH_SIZE: number = 3
local TEAM_ONE_NUMBER: number = 1
local TEAM_TWO_NUMBER: number = 2
local TEAM_SLOT_COUNT: number = 7
local ASSETS_FOLDER_NAME: string = "Assets"
local CHARS_FOLDER_NAME: string = "Chars"
local PERSISTENT_SCENE_NAME: string = "MatchIntroScene"
local PERSISTENT_SCENE_HIDDEN_CFRAME: CFrame = CFrame.new(0, -5000, 0)
local CAMERA_RIG_ALIASES: { string } = {
	"CamRigWithLetterBox",
	"CamRig",
	"CameraRigWithLetterBox",
	"CameraRig",
}

local PLAYER_ANIMATION_IDS: { [string]: string } = {
	Player1 = "rbxassetid://94482355725357",
	Player2 = "rbxassetid://71636906903127",
	Player3 = "rbxassetid://90165335480707",
	Player4 = "rbxassetid://93547343580033",
	Player5 = "rbxassetid://107835182811910",
	Player6 = "rbxassetid://92269723470797",
	Player7 = "rbxassetid://108716391711708",
	Player8 = "rbxassetid://135626075656395",
	Player9 = "rbxassetid://121108990641515",
	Player10 = "rbxassetid://85470698837607",
	Player11 = "rbxassetid://79047209393791",
	Player12 = "rbxassetid://118896817118038",
	Player13 = "rbxassetid://86689212805396",
	Player14 = "rbxassetid://108075363375540",
	Referee = "rbxassetid://99062290903472",
	CamRigWithLetterBox = "rbxassetid://116341697644287",
}

type IntroState = {
	Active: boolean,
	Token: number,
	IntroToken: number?,
	Scene: Model?,
	SceneRootPivot: CFrame?,
	RenderConnectionBound: boolean,
	CameraPart: BasePart?,
	HiddenCharacterParts: { [BasePart]: number },
	HiddenBallParts: { [BasePart]: number },
	HiddenBallVisuals: { [Instance]: number },
	PreviousCameraType: Enum.CameraType?,
	PreviousCameraSubject: Instance?,
	PreviousCameraCFrame: CFrame?,
	PreviousCameraFov: number?,
	PreviousHudGuiEnabled: boolean?,
	PreviousGameGuiEnabled: boolean?,
	TransitionOverlay: ScreenGui?,
	TransitionObject: any?,
	TransitionAlphaValue: NumberValue?,
	TransitionValueConnection: RBXScriptConnection?,
	TransitionReleasing: boolean,
	SceneCleaned: boolean,
	TransitionQueued: boolean,
	SceneTracks: { AnimationTrack },
	ReferenceTrackConnection: RBXScriptConnection?,
	ReferenceTrackStoppedConnection: RBXScriptConnection?,
	ReferenceTransitionMarkerConnection: RBXScriptConnection?,
	ReferenceFreezeMarkerConnection: RBXScriptConnection?,
	ReferenceTrackBound: boolean,
	ReferenceTrackCompleted: boolean,
}

type IntroPayload = {
	Team1: { number }?,
	Team2: { number }?,
	Token: number?,
}

type AnalyzedReferenceAnimation = {
	Length: number,
	Markers: { [string]: number },
}

type IntroActorSetup = {
	ActorModel: Model,
	AnimationId: string,
	SourcePlayer: Player?,
	FallbackAppearanceModel: Model?,
	TeamNumber: number,
}

local State: IntroState = {
	Active = false,
	Token = 0,
	IntroToken = nil,
	Scene = nil,
	SceneRootPivot = nil,
	RenderConnectionBound = false,
	CameraPart = nil,
	HiddenCharacterParts = {},
	HiddenBallParts = {},
	HiddenBallVisuals = {},
	PreviousCameraType = nil,
	PreviousCameraSubject = nil,
	PreviousCameraCFrame = nil,
	PreviousCameraFov = nil,
	PreviousHudGuiEnabled = nil,
	PreviousGameGuiEnabled = nil,
	TransitionOverlay = nil,
	TransitionObject = nil,
	TransitionAlphaValue = nil,
	TransitionValueConnection = nil,
	TransitionReleasing = false,
	SceneCleaned = false,
	TransitionQueued = false,
	SceneTracks = {},
	ReferenceTrackConnection = nil,
	ReferenceTrackStoppedConnection = nil,
	ReferenceTransitionMarkerConnection = nil,
	ReferenceFreezeMarkerConnection = nil,
	ReferenceTrackBound = false,
	ReferenceTrackCompleted = false,
}
local GameplayCameraRestoreConnection: RBXScriptConnection? = nil
local AnalyzedReferenceAnimationCache: { [string]: AnalyzedReferenceAnimation } = {}
local MissingAnalyzedReferenceAnimations: { [string]: boolean } = {}
local PersistentTemplateScene: Model? = nil
local PersistentTemplateSceneRootPivot: CFrame? = nil
local PreparedRuntimeScene: Model? = nil
local PreparedRuntimeSceneTemplate: Model? = nil
local PreparingRuntimeScene: boolean = false
local CachedFallbackIntroModels: { Model }? = nil

local function StudioWarn(Message: string): ()
	if RunService:IsStudio() then
		warn("[MatchIntro] " .. Message)
	end
end

local function NormalizeAnimationId(AnimationId: string): string
	if string.sub(AnimationId, 1, #"rbxassetid://") == "rbxassetid://" then
		return AnimationId
	end
	return "rbxassetid://" .. AnimationId
end

local function AnalyzeReferenceAnimation(AnimationId: string): AnalyzedReferenceAnimation?
	if AnimationId == "" then
		return nil
	end

	local NormalizedAnimationId: string = NormalizeAnimationId(AnimationId)
	local CachedAnalysis: AnalyzedReferenceAnimation? = AnalyzedReferenceAnimationCache[NormalizedAnimationId]
	if CachedAnalysis then
		return CachedAnalysis
	end
	if MissingAnalyzedReferenceAnimations[NormalizedAnimationId] then
		return nil
	end

	local Success, Result = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(NormalizedAnimationId)
	end)
	local Sequence: KeyframeSequence? = nil
	if Success and typeof(Result) == "Instance" and Result:IsA("KeyframeSequence") then
		Sequence = Result
	end
	if not Success or not Sequence then
		MissingAnalyzedReferenceAnimations[NormalizedAnimationId] = true
		StudioWarn(
			"Failed to analyze intro animation markers for " .. NormalizedAnimationId .. ": " .. tostring(Result)
		)
		return nil
	end

	local MarkerTimes: { [string]: number } = {}
	local Length: number = 0
	for _, Keyframe: Keyframe in Sequence:GetKeyframes() do
		local TimePosition: number = Keyframe.Time
		if TimePosition > Length then
			Length = TimePosition
		end

		for _, Marker: KeyframeMarker in Keyframe:GetMarkers() do
			local MarkerName: string = string.lower(Marker.Name)
			local ExistingMarkerTime: number? = MarkerTimes[MarkerName]
			if ExistingMarkerTime == nil or TimePosition < ExistingMarkerTime then
				MarkerTimes[MarkerName] = TimePosition
			end
		end
	end

	pcall(function()
		Sequence:Destroy()
	end)

	local Analysis: AnalyzedReferenceAnimation = {
		Length = Length,
		Markers = MarkerTimes,
	}
	AnalyzedReferenceAnimationCache[NormalizedAnimationId] = Analysis
	return Analysis
end

local function WarmupIntroAnimationAnalysis(): ()
	AnalyzeReferenceAnimation(PLAYER_ANIMATION_IDS.Referee)
	AnalyzeReferenceAnimation(PLAYER_ANIMATION_IDS.CamRigWithLetterBox)
end

local function WarmupIntroAnimationAnalysisAsync(): ()
	task.spawn(function()
		WarmupIntroAnimationAnalysis()
	end)
end

local function GetCurrentCamera(): Camera?
	return Workspace.CurrentCamera
end

local function GetLocalHumanoid(): Humanoid?
	local Character: Model? = LocalPlayer.Character
	if not Character then
		return nil
	end
	return Character:FindFirstChildOfClass("Humanoid")
end

local function GetPlayerGui(): PlayerGui?
	return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function GetHudGui(): ScreenGui?
	local PlayerGui = GetPlayerGui()
	if not PlayerGui then
		return nil
	end
	return PlayerGui:FindFirstChild("HudGui") :: ScreenGui?
end

local function GetGameGui(): ScreenGui?
	local PlayerGui = GetPlayerGui()
	if not PlayerGui then
		return nil
	end
	return PlayerGui:FindFirstChild("GameGui") :: ScreenGui?
end

local function IsIntroCutsceneLocked(): boolean
	return LocalPlayer:GetAttribute(ATTR_MATCH_CUTSCENE_LOCKED) == true
end

local function WaitForIntroCutsceneUnlock(): ()
	local Deadline: number = os.clock() + TRANSITION_UNLOCK_WAIT_TIMEOUT
	while IsIntroCutsceneLocked() and os.clock() < Deadline do
		RunService.Heartbeat:Wait()
	end
end

local function StopGameplayCameraRestoreWatchdog(): ()
	if GameplayCameraRestoreConnection then
		GameplayCameraRestoreConnection:Disconnect()
		GameplayCameraRestoreConnection = nil
	end
end

local function RestoreGameplayCameraNow(): ()
	local CurrentCamera: Camera? = GetCurrentCamera()
	if not CurrentCamera then
		return
	end

	local Humanoid: Humanoid? = GetLocalHumanoid()
	if Humanoid then
		CurrentCamera.CameraSubject = Humanoid
	end
	CurrentCamera.CameraType = Enum.CameraType.Custom
end

local function StartGameplayCameraRestoreWatchdog(Duration: number): ()
	StopGameplayCameraRestoreWatchdog()
	local Deadline: number = os.clock() + math.max(Duration, 0.1)
	GameplayCameraRestoreConnection = RunService.Heartbeat:Connect(function()
		if State.Active or IsIntroCutsceneLocked() then
			return
		end

		RestoreGameplayCameraNow()

		local CurrentCamera: Camera? = GetCurrentCamera()
		local Humanoid: Humanoid? = GetLocalHumanoid()
		local SubjectReady: boolean = Humanoid == nil or CurrentCamera == nil or CurrentCamera.CameraSubject == Humanoid
		local CameraReleased: boolean = CurrentCamera ~= nil and CurrentCamera.CameraType == Enum.CameraType.Custom
		if (CameraReleased and SubjectReady) or os.clock() >= Deadline then
			StopGameplayCameraRestoreWatchdog()
			RestoreGameplayCameraNow()
		end
	end)
end

local function CleanupTransitionOverlay(force: boolean?): ()
	if State.TransitionReleasing and force ~= true then
		return
	end

	State.TransitionReleasing = false

	if State.TransitionValueConnection then
		State.TransitionValueConnection:Disconnect()
		State.TransitionValueConnection = nil
	end

	if State.TransitionAlphaValue then
		State.TransitionAlphaValue:Destroy()
		State.TransitionAlphaValue = nil
	end

	if State.TransitionObject then
		pcall(function()
			State.TransitionObject:Destroy()
		end)
		State.TransitionObject = nil
	end

	if State.TransitionOverlay then
		State.TransitionOverlay:Destroy()
		State.TransitionOverlay = nil
	end

	State.TransitionQueued = false
end

local function IsIntroSceneActive(Token: number, Scene: Model): boolean
	return State.Token == Token and State.Active and State.Scene == Scene
end

local function YieldIntroPreparationFrame(Token: number, Scene: Model): boolean
	if not IsIntroSceneActive(Token, Scene) then
		return false
	end

	RunService.Heartbeat:Wait()
	return IsIntroSceneActive(Token, Scene)
end

local PlaySelectionTransition: (teamNumber: number, waiting_time: number) -> ()
local ResolveCameraPart: (CameraRigModel: Model?, Scene: Model) -> BasePart?

local function DisconnectReferenceTrackMonitor(): ()
	if State.ReferenceTrackConnection then
		State.ReferenceTrackConnection:Disconnect()
		State.ReferenceTrackConnection = nil
	end
	if State.ReferenceTrackStoppedConnection then
		State.ReferenceTrackStoppedConnection:Disconnect()
		State.ReferenceTrackStoppedConnection = nil
	end
	if State.ReferenceTransitionMarkerConnection then
		State.ReferenceTransitionMarkerConnection:Disconnect()
		State.ReferenceTransitionMarkerConnection = nil
	end
	if State.ReferenceFreezeMarkerConnection then
		State.ReferenceFreezeMarkerConnection:Disconnect()
		State.ReferenceFreezeMarkerConnection = nil
	end
end

local function CleanupSceneTracks(): ()
	for Index = #State.SceneTracks, 1, -1 do
		local Track: AnimationTrack = State.SceneTracks[Index]
		pcall(function()
			Track:Stop(0)
			Track:Destroy()
		end)
	end
	table.clear(State.SceneTracks)
end

local function GetScenePivot(Scene: Model): CFrame?
	local Success: boolean, PivotOrError: any = pcall(function(): CFrame
		return Scene:GetPivot()
	end)
	if not Success then
		return nil
	end
	return PivotOrError :: CFrame
end

local function MoveSceneTo(Scene: Model, Pivot: CFrame): ()
	pcall(function()
		Scene:PivotTo(Pivot)
	end)
end

local function FreezeSceneTracks(): ()
	for _, Track in State.SceneTracks do
		pcall(function()
			Track:AdjustSpeed(0)
		end)
	end
end

local function RegisterSceneTrack(Track: AnimationTrack?): AnimationTrack?
	if not Track then
		return nil
	end

	table.insert(State.SceneTracks, Track)
	return Track
end

local function EnsureTrackPlaying(Track: AnimationTrack?, Token: number): ()
	if not Track then
		return
	end

	local function TryPlay(AttemptsLeft: number): ()
		if AttemptsLeft <= 0 or State.Token ~= Token or not State.Active or Track.Parent == nil then
			return
		end

		local BaselineTimePosition: number = Track.TimePosition
		if BaselineTimePosition > REFERENCE_TRACK_START_EPSILON then
			return
		end

		pcall(function()
			if Track.IsPlaying then
				Track:AdjustSpeed(1)
			else
				Track:Play(0, 1, 1)
			end
		end)

		task.spawn(function()
			for _ = 1, TRACK_START_VERIFY_HEARTBEATS do
				if State.Token ~= Token or not State.Active or Track.Parent == nil then
					return
				end

				RunService.Heartbeat:Wait()
				if Track.TimePosition > math.max(BaselineTimePosition, REFERENCE_TRACK_START_EPSILON) then
					return
				end
			end

			if State.Token ~= Token or not State.Active or Track.Parent == nil then
				return
			end
			if Track.TimePosition > math.max(BaselineTimePosition, REFERENCE_TRACK_START_EPSILON) then
				return
			end

			pcall(function()
				Track:Stop(0)
			end)

			task.delay(TRACK_PLAY_RETRY_DELAY, function()
				TryPlay(AttemptsLeft - 1)
			end)
		end)
	end

	TryPlay(TRACK_PLAY_RETRY_ATTEMPTS)
end

local function PlaySceneTracks(): ()
	for _, Track in State.SceneTracks do
		pcall(function()
			Track:Play(0)
		end)
	end
end

local function PlaySceneTracksStartingWith(LeadTrack: AnimationTrack?): ()
	if LeadTrack then
		pcall(function()
			LeadTrack:Play(0)
		end)
	end

	for _, Track in State.SceneTracks do
		if Track == LeadTrack then
			continue
		end

		pcall(function()
			Track:Play(0)
		end)
	end
end

local function TryFinishIntroFromTrack(Token: number): ()
	if State.Token ~= Token or not State.Active or State.TransitionQueued then
		return
	end

	if State.ReferenceTrackBound and not State.ReferenceTrackCompleted then
		return
	end

	PlaySelectionTransition(0, 0.5)
end

local function CompleteReferenceTrack(Token: number): ()
	if State.Token ~= Token or not State.Active then
		return
	end
	if State.ReferenceTrackCompleted then
		return
	end

	State.ReferenceTrackCompleted = true
	DisconnectReferenceTrackMonitor()
	TryFinishIntroFromTrack(Token)
end

local function SetHudHidden(active: boolean): ()
	LocalPlayer:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, active)
	local Character = LocalPlayer.Character
	if Character then
		Character:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, active)
	end
end

local function HideGameplayGui(): ()
	local GameplayGuis = GameplayGuiVisibility.ResolveGameplayGuis(LocalPlayer)
	local HudGui = GameplayGuis.HudGui
	local GameGui = GameplayGuis.GameGui

	if State.PreviousHudGuiEnabled == nil and HudGui then
		State.PreviousHudGuiEnabled = HudGui.Enabled
	end
	if State.PreviousGameGuiEnabled == nil and GameGui then
		State.PreviousGameGuiEnabled = GameGui.Enabled
	end

	GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
end

local function RestoreGameplayGui(): ()
	if GameplayGuiVisibility.IsGameplayGuiBlocked(LocalPlayer) then
		GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
		State.PreviousHudGuiEnabled = nil
		State.PreviousGameGuiEnabled = nil
		return
	end

	local HudGui = GetHudGui()
	local GameGui = GetGameGui()

	if HudGui and State.PreviousHudGuiEnabled ~= nil then
		HudGui.Enabled = State.PreviousHudGuiEnabled
	end
	if GameGui and State.PreviousGameGuiEnabled ~= nil then
		GameGui.Enabled = State.PreviousGameGuiEnabled
	end

	State.PreviousHudGuiEnabled = nil
	State.PreviousGameGuiEnabled = nil
end

local function HideCharacter(Character: Model?): ()
	if not Character then
		return
	end

	for _, Descendant in Character:GetDescendants() do
		if Descendant:IsA("BasePart") and State.HiddenCharacterParts[Descendant] == nil then
			State.HiddenCharacterParts[Descendant] = Descendant.LocalTransparencyModifier
			Descendant.LocalTransparencyModifier = 1
		end
	end
end

local function RestoreHiddenCharacters(): ()
	for Part, PreviousValue in State.HiddenCharacterParts do
		if Part.Parent ~= nil then
			Part.LocalTransparencyModifier = PreviousValue
		end
	end
	table.clear(State.HiddenCharacterParts)
end

local function HideBallVisualTree(Target: Instance?): ()
	if not Target then
		return
	end

	if Target:IsA("BasePart") then
		if State.HiddenBallParts[Target] == nil then
			State.HiddenBallParts[Target] = Target.LocalTransparencyModifier
		end
		Target.LocalTransparencyModifier = 1
	end
	if Target:IsA("Decal") or Target:IsA("Texture") then
		if State.HiddenBallVisuals[Target] == nil then
			State.HiddenBallVisuals[Target] = Target.Transparency
		end
		Target.Transparency = 1
	end

	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("BasePart") then
			if State.HiddenBallParts[Descendant] == nil then
				State.HiddenBallParts[Descendant] = Descendant.LocalTransparencyModifier
			end
			Descendant.LocalTransparencyModifier = 1
		elseif Descendant:IsA("Decal") or Descendant:IsA("Texture") then
			if State.HiddenBallVisuals[Descendant] == nil then
				State.HiddenBallVisuals[Descendant] = Descendant.Transparency
			end
			Descendant.Transparency = 1
		end
	end
end

local function HideBallVisuals(): ()
	HideBallVisualTree(Workspace:FindFirstChild("Football", true))
	HideBallVisualTree(Workspace:FindFirstChild("FootballVisual", true))
end

local function RestoreBallVisuals(): ()
	for Part, PreviousValue in State.HiddenBallParts do
		if Part.Parent ~= nil then
			Part.LocalTransparencyModifier = PreviousValue
		end
	end
	table.clear(State.HiddenBallParts)

	for Visual, PreviousValue in State.HiddenBallVisuals do
		if Visual.Parent == nil then
			continue
		end
		if Visual:IsA("Decal") or Visual:IsA("Texture") then
			Visual.Transparency = PreviousValue
		end
	end
	table.clear(State.HiddenBallVisuals)
end

local function StoreCameraState(): ()
	StopGameplayCameraRestoreWatchdog()
	local CurrentCamera: Camera? = GetCurrentCamera()
	if not CurrentCamera then
		State.PreviousCameraType = nil
		State.PreviousCameraSubject = nil
		State.PreviousCameraCFrame = nil
		State.PreviousCameraFov = nil
		return
	end

	State.PreviousCameraType = CurrentCamera.CameraType
	State.PreviousCameraSubject = CurrentCamera.CameraSubject
	State.PreviousCameraCFrame = CurrentCamera.CFrame
	State.PreviousCameraFov = CurrentCamera.FieldOfView
	CurrentCamera.CameraType = Enum.CameraType.Scriptable
end

local function RestoreCameraState(): ()
	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	State.RenderConnectionBound = false
	State.CameraPart = nil
	FOVController.RemoveRequest(INTRO_FOV_REQUEST_ID)
	local ActiveFovRequest = FOVController.GetActiveRequest()

	local PreviousCameraType: Enum.CameraType? = State.PreviousCameraType
	local PreviousCameraSubject: Instance? = State.PreviousCameraSubject
	local PreviousCameraCFrame: CFrame? = State.PreviousCameraCFrame
	local PreviousCameraFov: number? = State.PreviousCameraFov
	local CurrentCamera: Camera? = GetCurrentCamera()

	if CurrentCamera then
		if PreviousCameraFov and ActiveFovRequest == nil then
			CurrentCamera.FieldOfView = PreviousCameraFov
		end

		if PreviousCameraCFrame and PreviousCameraType ~= Enum.CameraType.Custom then
			CurrentCamera.CFrame = PreviousCameraCFrame
		end

		if
			PreviousCameraType == Enum.CameraType.Custom
			and PreviousCameraSubject
			and PreviousCameraSubject.Parent ~= nil
		then
			CurrentCamera.CameraSubject = PreviousCameraSubject
			CurrentCamera.CameraType = Enum.CameraType.Custom
		else
			RestoreGameplayCameraNow()
		end
	end

	State.PreviousCameraType = nil
	State.PreviousCameraSubject = nil
	State.PreviousCameraCFrame = nil
	State.PreviousCameraFov = nil
	State.SceneRootPivot = nil

	StartGameplayCameraRestoreWatchdog(GAMEPLAY_CAMERA_RESTORE_TIMEOUT)
end

local function SetShiftlockBlocked(blocked: boolean): ()
	if CameraController.SetShiftlockBlocked then
		CameraController:SetShiftlockBlocked(SHIFTLOCK_BLOCKER_NAME, blocked)
	end
	if CameraController.RefreshShiftlockState then
		CameraController:RefreshShiftlockState()
	end
end

local function CleanupSceneOnly(): ()
	if State.SceneCleaned then
		return
	end

	DisconnectReferenceTrackMonitor()
	State.ReferenceTrackBound = false
	State.ReferenceTrackCompleted = false
	CleanupSceneTracks()
	RestoreCameraState()
	SetShiftlockBlocked(false)
	RestoreHiddenCharacters()
	RestoreBallVisuals()

	if State.Scene then
		if PersistentTemplateScene and State.Scene == PersistentTemplateScene then
			MoveSceneTo(State.Scene, PERSISTENT_SCENE_HIDDEN_CFRAME)
		else
			State.Scene:Destroy()
		end
		State.Scene = nil
	end

	State.SceneCleaned = true
end

local function FullCleanup(restoreHud: boolean): ()
	CleanupTransitionOverlay(true)
	CleanupSceneOnly()

	if restoreHud then
		RestoreGameplayGui()
		SetHudHidden(false)
	end

	State.Active = false
	State.IntroToken = nil
end

local function FinishIntroWhileTransitionCovered(): ()
	local IntroToken: number? = State.IntroToken
	if IntroToken then
		Packets.MatchIntroFinished:Fire(IntroToken)
		State.IntroToken = nil
	end

	WaitForIntroCutsceneUnlock()

	CleanupSceneOnly()
	RestoreGameplayGui()
	SetHudHidden(false)
	State.Active = false
end

local function WaitForTransitionCoverPresentation(): ()
	for _ = 1, TRANSITION_COVER_RENDER_STEPS do
		RunService.RenderStepped:Wait()
	end
end

-- Cria o overlay de wave e faz o tween de entrada (0 → 1), bloqueando até a tela
-- estar completamente preta. Deve ser chamado antes de qualquer preparação de cena.
local function PlayEntranceCover(): ()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	CleanupTransitionOverlay(true)
	State.TransitionReleasing = false

	local overlay = Instance.new("ScreenGui")
	overlay.Name = "WaveTransitionGui"
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = 9999
	overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlay.Parent = playerGui
	State.TransitionOverlay = overlay

	local container = Instance.new("Frame")
	container.Name = "WaveContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Parent = overlay

	local transition = WaveTransition.new(container, {
		color = Color3.new(0, 0, 0),
		width = 14,
		waveDirection = Vector2.new(1, -0.7),
	})

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Value = 0
	transition:Update(alphaValue.Value)

	local connection = alphaValue.Changed:Connect(function()
		transition:Update(alphaValue.Value)
	end)

	State.TransitionObject = transition
	State.TransitionAlphaValue = alphaValue
	State.TransitionValueConnection = connection

	-- Tween de entrada: 0 → 1 (tela vai ficando preta). Bloqueante.
	local tweenIn = TweenService:Create(alphaValue, TRANSITION_IN_INFO, { Value = 1 })
	tweenIn:Play()
	tweenIn.Completed:Wait()
end

-- Revela a intro fazendo o tween de saída (1 → 0) no overlay existente.
-- Deve ser chamado após toda a preparação de cena estar concluída.
local function RevealIntroFromCover(waiting_time: number): ()
	local alphaValue = State.TransitionAlphaValue
	local overlay = State.TransitionOverlay
	if not alphaValue or not overlay then
		return
	end

	-- Garante alguns frames para o Roblox renderizar a cena antes de revelar
	WaitForTransitionCoverPresentation()

	State.TransitionReleasing = true

	local tweenOut = TweenService:Create(alphaValue, TRANSITION_OUT_INFO, { Value = 0 })
	tweenOut.Completed:Once(function()
		if State.TransitionOverlay ~= overlay then
			return
		end
		task.wait(waiting_time)
		CleanupTransitionOverlay(true)
	end)
	tweenOut:Play()
end

-- PlaySelectionTransition: transição de SAÍDA da intro (fim da cutscene → jogo).
-- Se o overlay de entrada ainda estiver ativo (alpha já em 1), reutiliza-o
-- para fazer a saída sem criar um novo overlay do zero.
PlaySelectionTransition = function(teamNumber: number, waiting_time: number): ()
	local _ = teamNumber
	if State.TransitionQueued then
		return
	end

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		FullCleanup(true)
		return
	end

	-- Reutiliza o overlay existente (caso ainda esteja ativo do cover de entrada)
	if State.TransitionOverlay and State.TransitionAlphaValue then
		State.TransitionQueued = true
		local overlay = State.TransitionOverlay
		local alphaValue = State.TransitionAlphaValue

		-- Garante alpha=1 antes de prosseguir
		alphaValue.Value = 1

		WaitForTransitionCoverPresentation()
		FinishIntroWhileTransitionCovered()

		RunService.RenderStepped:Wait()
		if State.TransitionOverlay ~= overlay then
			return
		end

		State.TransitionReleasing = true
		local tweenOut = TweenService:Create(alphaValue, TRANSITION_OUT_INFO, { Value = 0 })
		tweenOut.Completed:Once(function()
			if State.TransitionOverlay ~= overlay then
				return
			end
			task.wait(waiting_time)
			CleanupTransitionOverlay(true)
		end)
		tweenOut:Play()
		return
	end

	-- Nenhum overlay ativo: cria um novo do zero para a transição de saída
	CleanupTransitionOverlay(true)
	State.TransitionQueued = true
	State.TransitionReleasing = false

	local overlay = Instance.new("ScreenGui")
	overlay.Name = "WaveTransitionGui"
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = 9999
	overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlay.Parent = playerGui
	State.TransitionOverlay = overlay

	local container = Instance.new("Frame")
	container.Name = "WaveContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Parent = overlay

	local transition = WaveTransition.new(container, {
		color = Color3.new(0, 0, 0),
		width = 14,
		waveDirection = Vector2.new(1, -0.7),
	})

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Value = 0
	transition:Update(alphaValue.Value)

	local connection = alphaValue.Changed:Connect(function()
		transition:Update(alphaValue.Value)
	end)
	State.TransitionObject = transition
	State.TransitionAlphaValue = alphaValue
	State.TransitionValueConnection = connection

	local tweenIn = TweenService:Create(alphaValue, TRANSITION_IN_INFO, { Value = 1 })
	tweenIn.Completed:Once(function()
		if State.TransitionOverlay ~= overlay then
			return
		end

		WaitForTransitionCoverPresentation()
		FinishIntroWhileTransitionCovered()
		if State.TransitionOverlay ~= overlay then
			return
		end

		RunService.RenderStepped:Wait()
		if State.TransitionOverlay ~= overlay then
			return
		end

		State.TransitionReleasing = true

		local tweenOut = TweenService:Create(alphaValue, TRANSITION_OUT_INFO, { Value = 0 })
		tweenOut.Completed:Once(function()
			if State.TransitionOverlay ~= overlay then
				return
			end

			task.wait(waiting_time)

			CleanupTransitionOverlay(true)
		end)
		tweenOut:Play()
	end)

	tweenIn:Play()
end

local function ResolveTemplateFromContainer(Container: Instance?): Model?
	if not Container then
		return nil
	end
	if Container:IsA("Model") and CutsceneRigUtils.NormalizeName(Container.Name) == "enter" then
		return Container
	end

	local DirectTemplate = Container:FindFirstChild("Enter")
	if DirectTemplate and DirectTemplate:IsA("Model") then
		return DirectTemplate
	end

	local RecursiveTemplate = CutsceneRigUtils.FindChildByAliases(Container, { "Enter" }, true)
	if RecursiveTemplate then
		if RecursiveTemplate:IsA("Model") then
			return RecursiveTemplate
		end
		if RecursiveTemplate:IsA("Folder") then
			local NestedModel = RecursiveTemplate:FindFirstChildWhichIsA("Model", true)
			if NestedModel then
				return NestedModel
			end
		end
	end

	return nil
end

local function ResolveEnterTemplate(): Model?
	if PersistentTemplateScene and PersistentTemplateScene.Parent ~= nil then
		return PersistentTemplateScene
	end

	local ExistingScene: Instance? = Workspace:FindFirstChild(PERSISTENT_SCENE_NAME)
	if ExistingScene and ExistingScene:IsA("Model") then
		PersistentTemplateScene = ExistingScene
		PersistentTemplateSceneRootPivot = PersistentTemplateSceneRootPivot or GetScenePivot(ExistingScene)
		return ExistingScene
	end

	local Assets = ReplicatedStorage:FindFirstChild("Assets") or ReplicatedStorage:WaitForChild("Assets", 10)
	if not Assets then
		StudioWarn("Assets folder not found in ReplicatedStorage")
		return nil
	end

	local SkillsContainer = Assets:FindFirstChild("Skills") or Assets:WaitForChild("Skills", 10)
	if not SkillsContainer then
		SkillsContainer = CutsceneRigUtils.FindChildByAliases(Assets, { "Skills" }, true)
	end
	if not SkillsContainer then
		StudioWarn("Skills folder not found under ReplicatedStorage.Assets")
		return nil
	end

	local DirectEnterContainer = workspace:FindFirstChild('Enter') or workspace:WaitForChild("Enter", 10)
	local Template: Model? = if DirectEnterContainer and DirectEnterContainer:IsA("Model")
		then DirectEnterContainer
		else nil
	if not Template then
		Template = ResolveTemplateFromContainer(DirectEnterContainer)
			or ResolveTemplateFromContainer(SkillsContainer)
			or ResolveTemplateFromContainer(Assets)
	end

	if not Template then
		StudioWarn("Enter template not found under workspace.Enter")
		return nil
	end

	if Template.Parent ~= Workspace then
		Template.Parent = Workspace
	end
	Template.Name = PERSISTENT_SCENE_NAME
	PersistentTemplateScene = Template
	PersistentTemplateSceneRootPivot = GetScenePivot(Template)
	if PersistentTemplateSceneRootPivot then
		MoveSceneTo(Template, PERSISTENT_SCENE_HIDDEN_CFRAME)
	end
	return Template
end

local function DestroyPreparedRuntimeScene(): ()
	if PreparedRuntimeScene then
		PreparedRuntimeScene:Destroy()
		PreparedRuntimeScene = nil
	end
	PreparedRuntimeSceneTemplate = nil
	PreparingRuntimeScene = false
end

local function PrepareRuntimeSceneAsync(): ()
	if PreparingRuntimeScene then
		return
	end
	if PreparedRuntimeScene and PreparedRuntimeScene.Parent == nil then
		return
	end

	local Template: Model? = ResolveEnterTemplate()
	if not Template then
		return
	end

	PreparingRuntimeScene = true
	task.spawn(function()
		local SceneClone: Model = Template:Clone()
		if not PreparingRuntimeScene then
			SceneClone:Destroy()
			return
		end

		DestroyPreparedRuntimeScene()
		PreparedRuntimeScene = SceneClone
		PreparedRuntimeSceneTemplate = Template
		PreparingRuntimeScene = false
	end)
end

local function AcquireRuntimeScene(): Model?
	local Template: Model? = ResolveEnterTemplate()
	if not Template then
		return nil
	end

	if
		not (PreparedRuntimeScene and PreparedRuntimeScene.Parent == nil and PreparedRuntimeSceneTemplate == Template)
	then
		PrepareRuntimeSceneAsync()
		if PreparingRuntimeScene then
			local Deadline: number = os.clock() + PREPARED_SCENE_ACQUIRE_TIMEOUT
			while PreparingRuntimeScene and os.clock() < Deadline do
				if
					PreparedRuntimeScene
					and PreparedRuntimeScene.Parent == nil
					and PreparedRuntimeSceneTemplate == Template
				then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end
	end

	local Scene: Model
	if PreparedRuntimeScene and PreparedRuntimeScene.Parent == nil and PreparedRuntimeSceneTemplate == Template then
		Scene = PreparedRuntimeScene
		PreparedRuntimeScene = nil
		PreparedRuntimeSceneTemplate = nil
	else
		Scene = Template:Clone()
	end

	Scene.Name = PERSISTENT_SCENE_NAME
	Scene.Parent = Workspace
	if PersistentTemplateSceneRootPivot then
		MoveSceneTo(Scene, PERSISTENT_SCENE_HIDDEN_CFRAME)
	end

	task.defer(PrepareRuntimeSceneAsync)
	return Scene
end

local function GetMatchFolder(): Folder?
	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if not GameStateFolder then
		return nil
	end

	local MatchFolder = GameStateFolder:FindFirstChild("Match")
	if MatchFolder and MatchFolder:IsA("Folder") then
		return MatchFolder
	end

	return nil
end

local function BuildPayloadFromGameState(): IntroPayload
	local Team1: { number } = {}
	local Team2: { number } = {}
	local MatchFolder = GetMatchFolder()

	if MatchFolder then
		for TeamNumber = 1, 2 do
			local TeamFolder = MatchFolder:FindFirstChild("Team" .. tostring(TeamNumber))
			if not TeamFolder then
				continue
			end

			local TargetList = if TeamNumber == 1 then Team1 else Team2
			for _, Position in FTConfig.PLAYER_POSITIONS do
				local PositionValue = TeamFolder:FindFirstChild(Position.Name)
				if PositionValue and PositionValue:IsA("IntValue") and PositionValue.Value ~= 0 then
					table.insert(TargetList, PositionValue.Value)
				end
			end
		end
	end

	return {
		Team1 = Team1,
		Team2 = Team2,
	}
end

local function ResolveActorModel(Scene: Model, Name: string): Model?
	local InstanceItem = CutsceneRigUtils.FindChildByAliases(Scene, { Name }, true)
	if InstanceItem and InstanceItem:IsA("Model") then
		return InstanceItem
	end
	if InstanceItem and InstanceItem:IsA("Folder") then
		return InstanceItem:FindFirstChildWhichIsA("Model", true)
	end
	return nil
end

local function ResolveCameraRigModel(Scene: Model): Model?
	for _, Alias in CAMERA_RIG_ALIASES do
		local CameraRigModel: Model? = ResolveActorModel(Scene, Alias)
		if CameraRigModel then
			return CameraRigModel
		end
	end

	for _, Descendant in Scene:GetDescendants() do
		if not Descendant:IsA("Model") then
			continue
		end
		local HasCameraPart: boolean = CutsceneRigUtils.FindChildByAliases(
			Descendant,
			{ "Camo", "CamPart", "CameraPart", "Camera", "camera" },
			true
		) ~= nil
		if not HasCameraPart then
			continue
		end
		if CutsceneRigUtils.GetAnimatorFromModel(Descendant, true) ~= nil then
			return Descendant
		end
	end

	return nil
end

local function ResolveIntroPlayer(IdValue: number): Player?
	return PlayerIdentity.ResolvePlayer(IdValue)
end

local function ResolveCharsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
		or ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME, 10)
	if not AssetsFolder then
		return nil
	end

	local CharsFolder: Instance? = AssetsFolder:FindFirstChild(CHARS_FOLDER_NAME)
	if CharsFolder then
		return CharsFolder
	end

	return AssetsFolder:FindFirstChild(CHARS_FOLDER_NAME, true)
end

local function ResolveRandomIntroFallbackModel(): Model?
	if CachedFallbackIntroModels and #CachedFallbackIntroModels > 0 then
		return CachedFallbackIntroModels[math.random(1, #CachedFallbackIntroModels)]
	end

	local CharsFolder: Instance? = ResolveCharsFolder()
	if not CharsFolder then
		return nil
	end

	local CandidateModels: { Model } = {}
	for _, Child in CharsFolder:GetChildren() do
		if Child:IsA("Model") then
			table.insert(CandidateModels, Child)
		end
	end

	if #CandidateModels <= 0 then
		for _, Descendant in CharsFolder:GetDescendants() do
			if Descendant:IsA("Model") and Descendant:FindFirstChildWhichIsA("Humanoid", true) then
				table.insert(CandidateModels, Descendant)
			end
		end
	end

	if #CandidateModels <= 0 then
		return nil
	end

	CachedFallbackIntroModels = CandidateModels
	return CandidateModels[math.random(1, #CandidateModels)]
end

local function GetCachedReferenceAnimation(AnimationId: string?): AnalyzedReferenceAnimation?
	if type(AnimationId) ~= "string" or AnimationId == "" then
		return nil
	end

	return AnalyzedReferenceAnimationCache[NormalizeAnimationId(AnimationId)]
end

local function BindReferenceTrack(Track: AnimationTrack?, AnimationId: string?): ()
	DisconnectReferenceTrackMonitor()
	State.ReferenceTrackBound = Track ~= nil
	State.ReferenceTrackCompleted = false
	if not Track then
		return
	end

	local IntroToken: number = State.Token
	local TrackStarted: boolean = false
	local LastObservedPlaybackAt: number = os.clock()
	local LastObservedTimePosition: number = 0
	local FreezeTriggered: boolean = false
	local TransitionTriggered: boolean = false
	local AnalyzedAnimation: AnalyzedReferenceAnimation? = GetCachedReferenceAnimation(AnimationId)
	if not AnalyzedAnimation and type(AnimationId) == "string" and AnimationId ~= "" then
		task.spawn(function()
			AnalyzeReferenceAnimation(AnimationId)
		end)
	end

	local function TriggerFreeze(): ()
		if
			FreezeTriggered
			or State.Token ~= IntroToken
			or not State.Active
			or State.ReferenceTrackCompleted
			or State.TransitionQueued
		then
			return
		end

		FreezeTriggered = true
		FreezeSceneTracks()
	end

	local function TriggerTransition(): ()
		if TransitionTriggered or State.Token ~= IntroToken or not State.Active then
			return
		end

		TransitionTriggered = true
		CompleteReferenceTrack(IntroToken)
	end

	if AnalyzedAnimation then
		local FreezeAt: number? = AnalyzedAnimation.Markers[REFERENCE_TRACK_FREEZE_MARKER]
		if FreezeAt ~= nil then
			task.delay(math.max(FreezeAt, 0), function()
				TriggerFreeze()
			end)
		end

		local TransitionAt: number? = AnalyzedAnimation.Markers[REFERENCE_TRACK_TRANSITION_MARKER]
		if TransitionAt ~= nil then
			task.delay(math.max(TransitionAt, 0), function()
				TriggerTransition()
			end)
		elseif AnalyzedAnimation.Length > 0 then
			task.delay(AnalyzedAnimation.Length + REFERENCE_TRACK_STOP_GRACE_TIME, function()
				TriggerTransition()
			end)
		end
	end

	State.ReferenceTransitionMarkerConnection = Track:GetMarkerReachedSignal(REFERENCE_TRACK_TRANSITION_MARKER)
		:Connect(function()
			TriggerTransition()
		end)
	State.ReferenceFreezeMarkerConnection = Track:GetMarkerReachedSignal(REFERENCE_TRACK_FREEZE_MARKER)
		:Connect(function()
			TriggerFreeze()
		end)
	State.ReferenceTrackStoppedConnection = Track.Stopped:Connect(function()
		if State.Token ~= IntroToken or not State.Active or not TrackStarted then
			return
		end

		LastObservedTimePosition = math.max(LastObservedTimePosition, Track.TimePosition)
		local TrackLength: number = Track.Length
		local ReachedTrackEnd: boolean = TrackLength > 0
			and LastObservedTimePosition >= math.max(0, TrackLength - REFERENCE_TRACK_END_EPSILON)
		if ReachedTrackEnd or (TrackLength <= 0 and LastObservedTimePosition > REFERENCE_TRACK_START_EPSILON) then
			task.defer(function()
				TriggerTransition()
			end)
		end
	end)

	State.ReferenceTrackConnection = RunService.Heartbeat:Connect(function()
		if State.Token ~= IntroToken or not State.Active then
			DisconnectReferenceTrackMonitor()
			return
		end

		if Track.Parent == nil then
			DisconnectReferenceTrackMonitor()
			return
		end

		local TimePosition: number = Track.TimePosition
		local IsPlaying: boolean = Track.IsPlaying
		if not TrackStarted then
			if IsPlaying or TimePosition > REFERENCE_TRACK_START_EPSILON then
				TrackStarted = true
				LastObservedPlaybackAt = os.clock()
			else
				return
			end
		elseif IsPlaying then
			LastObservedPlaybackAt = os.clock()
		end

		LastObservedTimePosition = math.max(LastObservedTimePosition, TimePosition)

		local TrackLength: number = Track.Length
		local ReachedTrackEnd: boolean = TrackLength > 0
			and LastObservedTimePosition >= math.max(0, TrackLength - REFERENCE_TRACK_END_EPSILON)
		local TrackStopped: boolean = TrackStarted
			and not IsPlaying
			and (os.clock() - LastObservedPlaybackAt) >= REFERENCE_TRACK_STOP_GRACE_TIME
		if ReachedTrackEnd and TrackStopped then
			TriggerTransition()
			return
		end
		if TrackStopped and TrackLength <= 0 and LastObservedTimePosition > REFERENCE_TRACK_START_EPSILON then
			TriggerTransition()
		end
	end)
end

local function LoadTrackForModel(
	TargetModel: Model,
	AnimationId: string,
	PreferAnimationController: boolean?
): AnimationTrack?
	SkillAssetPreloader.WarmupAnimationIdsForModel(TargetModel, { AnimationId }, PreferAnimationController)
	return RegisterSceneTrack(
		CutsceneRigUtils.LoadAnimationTrack(
			TargetModel,
			AnimationId,
			Enum.AnimationPriority.Action,
			PreferAnimationController
		)
	)
end

local function LoadTrackForTarget(
	Target: Instance,
	AnimationId: string,
	PreferAnimationController: boolean?
): AnimationTrack?
	SkillAssetPreloader.WarmupAnimationIdsForModel(Target, { AnimationId }, PreferAnimationController)
	return RegisterSceneTrack(
		CutsceneRigUtils.LoadAnimationTrack(
			Target,
			AnimationId,
			Enum.AnimationPriority.Action,
			PreferAnimationController
		)
	)
end

local function WaitForAnimationRigReady(FrameCount: number): ()
	for _ = 1, math.max(FrameCount, 0) do
		RunService.Heartbeat:Wait()
	end
end

local function TryApplyPlayerActorAppearance(ActorModel: Model, SourcePlayer: Player): ()
	local Success: boolean, ErrorMessage: any = pcall(function()
		CutsceneRigUtils.ApplyPlayerAppearance(SourcePlayer, ActorModel, {
			AccessoryMode = "HairOnly",
		})
	end)
	if Success then
		return
	end

	StudioWarn(
		string.format("Failed to apply intro player appearance for %s: %s", SourcePlayer.Name, tostring(ErrorMessage))
	)

	local TeamNumber: number? = CutsceneRigUtils.GetPlayerTeamNumber(SourcePlayer)
	if TeamNumber then
		CutsceneRigUtils.ApplyTeamAppearanceByNumber(TeamNumber, ActorModel)
	end
end

local function TryApplyModelActorAppearance(ActorModel: Model, SourceModel: Model, TeamNumber: number?): ()
	local Success: boolean, ErrorMessage: any = pcall(function()
		CutsceneRigUtils.ApplyModelAppearance(SourceModel, ActorModel, {
			AccessoryMode = "HairOnly",
		})
	end)
	if Success then
		return
	end

	StudioWarn(
		string.format(
			"Failed to apply intro fallback appearance from %s: %s",
			SourceModel:GetFullName(),
			tostring(ErrorMessage)
		)
	)

	if TeamNumber then
		CutsceneRigUtils.ApplyTeamAppearanceByNumber(TeamNumber, ActorModel)
	end
end

local function BindCameraToPart(CameraPart: BasePart, Scene: Model, CameraRigModel: Model?): ()
	StoreCameraState()
	State.CameraPart = CameraPart
	FOVController.AddRequest(INTRO_FOV_REQUEST_ID, INTRO_CAMERA_FOV, nil, {
		TweenInfo = INTRO_FOV_TWEEN,
	})

	local function ApplyBoundCamera(): ()
		local CurrentCamera: Camera? = GetCurrentCamera()
		if not CurrentCamera then
			return
		end

		local ActiveCameraPart: BasePart? = State.CameraPart
		if not ActiveCameraPart or ActiveCameraPart.Parent == nil then
			if CameraRigModel == nil or CameraRigModel.Parent == nil then
				CameraRigModel = ResolveCameraRigModel(Scene)
			end
			ActiveCameraPart = ResolveCameraPart(CameraRigModel, Scene)
			State.CameraPart = ActiveCameraPart
		end
		if not ActiveCameraPart then
			return
		end

		if CurrentCamera.CameraType ~= Enum.CameraType.Scriptable then
			CurrentCamera.CameraType = Enum.CameraType.Scriptable
		end
		if CurrentCamera.CameraSubject ~= nil then
			CurrentCamera.CameraSubject = nil
		end
		CurrentCamera.CFrame = ActiveCameraPart.CFrame
	end

	ApplyBoundCamera()
	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, ApplyBoundCamera)
	State.RenderConnectionBound = true
end

ResolveCameraPart = function(CameraRigModel: Model?, Scene: Model): BasePart?
	local function ResolveFromInstance(Target: Instance?): BasePart?
		if not Target then
			return nil
		end

		if Target:IsA("Model") then
			local AnimatedRigModel: Model = CutsceneRigUtils.ResolveAnimatedRigModel(Target)
			if AnimatedRigModel ~= Target then
				local AnimatedRigPart: BasePart? = ResolveFromInstance(AnimatedRigModel)
				if AnimatedRigPart then
					return AnimatedRigPart
				end
			end
		end

		local CameraPartInstance = CutsceneRigUtils.FindChildByAliases(
			Target,
			{ "Camo", "CamPart", "CameraPart", "RootPart", "HumanoidRootPart" },
			true
		)
		if CameraPartInstance and CameraPartInstance:IsA("BasePart") then
			return CameraPartInstance
		end

		local LegacyCameraPartInstance = CutsceneRigUtils.FindChildByAliases(Target, { "Camera", "camera" }, true)
		if LegacyCameraPartInstance and LegacyCameraPartInstance:IsA("BasePart") then
			return LegacyCameraPartInstance
		end

		if Target:IsA("Model") then
			local ModelRootPart: BasePart? = CutsceneRigUtils.FindModelRootPart(Target)
			if ModelRootPart then
				return ModelRootPart
			end
			return Target.PrimaryPart or Target:FindFirstChildWhichIsA("BasePart", true)
		end

		return Target:FindFirstChildWhichIsA("BasePart", true)
	end

	return ResolveFromInstance(CameraRigModel)
		or ResolveFromInstance(Scene:FindFirstChild("CamRigWithLetterBox", true))
		or ResolveFromInstance(Scene)
end

local function ResolveIntroCameraPart(CameraRigModel: Model?, Scene: Model): BasePart?
	if CameraRigModel then
		local ExactCameraInstance: Instance? =
			CutsceneRigUtils.FindChildByAliases(CameraRigModel, { "camera", "Camera" }, true)
		if ExactCameraInstance and ExactCameraInstance:IsA("BasePart") then
			return ExactCameraInstance
		end
	end

	local IntroCameraRig: Instance? = Scene:FindFirstChild("CamRigWithLetterBox", true)
	if IntroCameraRig then
		local ExactCameraInstance: Instance? =
			CutsceneRigUtils.FindChildByAliases(IntroCameraRig, { "camera", "Camera" }, true)
		if ExactCameraInstance and ExactCameraInstance:IsA("BasePart") then
			return ExactCameraInstance
		end
	end

	return ResolveCameraPart(CameraRigModel, Scene)
end

local function CollectTeamSlotSetups(
	Scene: Model,
	TeamIds: { number },
	StartIndex: number,
	TeamNumber: number
): { IntroActorSetup }
	local ActorSetups: { IntroActorSetup } = {}
	for SlotOffset = 0, TEAM_SLOT_COUNT - 1 do
		local SlotIndex = StartIndex + SlotOffset
		local SlotName = "Player" .. tostring(SlotIndex)
		local ActorModel = ResolveActorModel(Scene, SlotName)
		if not ActorModel then
			continue
		end

		local PlayerId = TeamIds[SlotOffset + 1]
		local SourcePlayer = if typeof(PlayerId) == "number" then ResolveIntroPlayer(PlayerId) else nil
		local AnimationId = PLAYER_ANIMATION_IDS[SlotName]
		if type(AnimationId) ~= "string" or AnimationId == "" then
			continue
		end

		table.insert(ActorSetups, {
			ActorModel = ActorModel,
			AnimationId = AnimationId,
			SourcePlayer = SourcePlayer,
			FallbackAppearanceModel = if SourcePlayer then nil else ResolveRandomIntroFallbackModel(),
			TeamNumber = TeamNumber,
		})
	end

	return ActorSetups
end

local function ApplyActorSetupAppearance(ActorSetup: IntroActorSetup): ()
	if ActorSetup.SourcePlayer then
		TryApplyPlayerActorAppearance(ActorSetup.ActorModel, ActorSetup.SourcePlayer)
		HideCharacter(ActorSetup.SourcePlayer.Character)
		return
	end

	if ActorSetup.FallbackAppearanceModel then
		TryApplyModelActorAppearance(ActorSetup.ActorModel, ActorSetup.FallbackAppearanceModel, ActorSetup.TeamNumber)
	end

	CutsceneRigUtils.ApplyTeamAppearanceByNumber(ActorSetup.TeamNumber, ActorSetup.ActorModel)
end

local function LoadActorSetupTrack(ActorSetup: IntroActorSetup): ()
	CutsceneRigUtils.PrepareAnimatedModel(ActorSetup.ActorModel)
	LoadTrackForModel(ActorSetup.ActorModel, ActorSetup.AnimationId)
end

local function StartIntro(Payload: IntroPayload): ()
	FullCleanup(true)

	State.Active = true
	State.Token += 1
	local Token: number = State.Token
	State.SceneCleaned = false
	State.ReferenceTrackBound = false
	State.ReferenceTrackCompleted = false
	State.IntroToken = if typeof(Payload.Token) == "number" then Payload.Token else nil

	-- PASSO 1: Esconde a UI e faz a tela ficar preta ANTES de qualquer preparação.
	-- PlayEntranceCover é bloqueante: só retorna quando alpha == 1 (tela completamente preta).
	SetHudHidden(true)
	HideGameplayGui()
	PlayEntranceCover()

	-- Verifica se o intro ainda é válido após o tween de entrada
	if State.Token ~= Token or not State.Active then
		return
	end

	-- PASSO 2: Com a tela preta, prepara toda a cena sem o player ver nada.
	local Scene = AcquireRuntimeScene()
	if not Scene then
		FullCleanup(true)
		return
	end
	State.Scene = Scene
	State.SceneRootPivot = PersistentTemplateSceneRootPivot or GetScenePivot(Scene)

	SetShiftlockBlocked(true)
	HideBallVisuals()

	if not YieldIntroPreparationFrame(Token, Scene) then
		return
	end

	local Team1Ids: { number } = if typeof(Payload.Team1) == "table" then Payload.Team1 else {}
	local Team2Ids: { number } = if typeof(Payload.Team2) == "table" then Payload.Team2 else {}
	local Team1ActorSetups: { IntroActorSetup } = CollectTeamSlotSetups(Scene, Team1Ids, 1, TEAM_ONE_NUMBER)
	local Team2ActorSetups: { IntroActorSetup } = CollectTeamSlotSetups(Scene, Team2Ids, 8, TEAM_TWO_NUMBER)
	local AllActorSetups: { IntroActorSetup } = table.create(#Team1ActorSetups + #Team2ActorSetups)
	for _, ActorSetup in Team1ActorSetups do
		table.insert(AllActorSetups, ActorSetup)
	end
	for _, ActorSetup in Team2ActorSetups do
		table.insert(AllActorSetups, ActorSetup)
	end

	local CameraRigModel = ResolveCameraRigModel(Scene)

	-- Preload antecipado: warm-up de TODAS as animações de intro nos seus modelos
	-- alvo ainda com a tela preta, garantindo que o motor tenha os dados em cache
	-- antes de LoadTrackForModel/LoadTrackForTarget serem chamados.
	do
		-- Câmera
		if CameraRigModel then
			local CameraAnimTarget: Instance = CameraRigModel:FindFirstChildWhichIsA("AnimationController", true)
				or CameraRigModel
			SkillAssetPreloader.WarmupAnimationIdsForModel(
				CameraAnimTarget,
				{ PLAYER_ANIMATION_IDS.CamRigWithLetterBox },
				true
			)
		end

		-- Árbitro
		local RefereeModel = ResolveActorModel(Scene, "Referee")
		if RefereeModel then
			SkillAssetPreloader.WarmupAnimationIdsForModel(
				RefereeModel,
				{ PLAYER_ANIMATION_IDS.Referee },
				false
			)
		end

		-- Jogadores (todas as slots já resolvidas em AllActorSetups)
		for _, ActorSetup in AllActorSetups do
			SkillAssetPreloader.WarmupAnimationIdsForModel(
				ActorSetup.ActorModel,
				{ ActorSetup.AnimationId },
				false
			)
		end
	end

	SkillAssetPreloader.PreloadAll()
	if not YieldIntroPreparationFrame(Token, Scene) then
		return
	end

	for Index, ActorSetup in AllActorSetups do
		ApplyActorSetupAppearance(ActorSetup)
		if Index % INTRO_PREPARATION_BATCH_SIZE == 0 and not YieldIntroPreparationFrame(Token, Scene) then
			return
		end
	end

	if not IsIntroSceneActive(Token, Scene) then
		return
	end

	local RefereeTrack: AnimationTrack? = nil
	local CameraTrack: AnimationTrack? = nil
	if CameraRigModel then
		CutsceneRigUtils.PrepareAnimatedModel(CameraRigModel)
		WaitForAnimationRigReady(2)
		local CameraAnimationTarget: Instance = CameraRigModel:FindFirstChildWhichIsA("AnimationController", true)
			or CameraRigModel
		CameraTrack = LoadTrackForTarget(CameraAnimationTarget, PLAYER_ANIMATION_IDS.CamRigWithLetterBox, true)
	end

	for Index, ActorSetup in AllActorSetups do
		LoadActorSetupTrack(ActorSetup)
		if Index % INTRO_PREPARATION_BATCH_SIZE == 0 and not YieldIntroPreparationFrame(Token, Scene) then
			return
		end
	end

	local RefereeModel = ResolveActorModel(Scene, "Referee")
	if RefereeModel then
		CutsceneRigUtils.PrepareAnimatedModel(RefereeModel)
		RefereeTrack = LoadTrackForModel(RefereeModel, PLAYER_ANIMATION_IDS.Referee)
	end

	if not IsIntroSceneActive(Token, Scene) then
		return
	end
	if State.SceneRootPivot then
		MoveSceneTo(Scene, State.SceneRootPivot)
	end

	local CameraPart: BasePart? = ResolveIntroCameraPart(CameraRigModel, Scene)
	if CameraPart then
		BindCameraToPart(CameraPart, Scene, CameraRigModel)
	else
		StudioWarn("Camera part not found for intro cutscene")
	end

	PlaySceneTracksStartingWith(CameraTrack)
	EnsureTrackPlaying(CameraTrack, Token)
	EnsureTrackPlaying(RefereeTrack, Token)

	RevealIntroFromCover(0)

	-- Só começa a monitorar depois das tracks estarem tocando e a tela revelando
	BindReferenceTrack(
		CameraTrack or RefereeTrack,
		if CameraTrack then PLAYER_ANIMATION_IDS.CamRigWithLetterBox else PLAYER_ANIMATION_IDS.Referee
	)
end

local function EnsureIntroAssetsReady(): ()
	SkillAssetPreloader.PreloadAll()
	WarmupIntroAnimationAnalysisAsync()
	PrepareRuntimeSceneAsync()
end

local function TryStartIntro(Payload: IntroPayload?): ()
	if Payload and typeof(Payload.Token) == "number" then
		State.IntroToken = Payload.Token
	end

	if State.Active and State.Scene and State.Scene.Parent ~= nil then
		return
	end

	EnsureIntroAssetsReady()

	if State.Active and State.Scene and State.Scene.Parent ~= nil then
		return
	end

	StartIntro(Payload or BuildPayloadFromGameState())
end

function MatchIntroController.Start(): ()
	task.spawn(function()
		SkillAssetPreloader.PreloadAll()
		WarmupIntroAnimationAnalysisAsync()
		local Scene: Model? = ResolveEnterTemplate()
		if Scene and PersistentTemplateSceneRootPivot then
			MoveSceneTo(Scene, PERSISTENT_SCENE_HIDDEN_CFRAME)
		end
		PrepareRuntimeSceneAsync()
	end)

	Packets.MatchIntroCutscene.OnClientEvent:Connect(function(Payload: IntroPayload)
		local IncomingToken: number? = if typeof(Payload.Token) == "number" then Payload.Token else nil
		if State.Active and State.Scene and State.Scene.Parent ~= nil then
			if IncomingToken ~= nil and State.IntroToken == IncomingToken then
				return
			end
			FullCleanup(true)
		end

		TryStartIntro(Payload)
	end)

	local function HandleCutsceneLockChanged(): ()
		local Locked = IsIntroCutsceneLocked()
		if Locked then
			return
		end

		if State.Active and State.Scene and State.Scene.Parent ~= nil and not State.TransitionQueued then
			task.defer(function()
				if State.Active and State.Scene and State.Scene.Parent ~= nil and not State.TransitionQueued then
					if State.ReferenceTrackBound and not State.ReferenceTrackCompleted then
						return
					end
					PlaySelectionTransition(0, 0.5)
				end
			end)
		end
	end

	LocalPlayer:GetAttributeChangedSignal(ATTR_MATCH_CUTSCENE_LOCKED):Connect(HandleCutsceneLockChanged)

	LocalPlayer.CharacterAdded:Connect(function(Character: Model)
		if LocalPlayer:GetAttribute(ATTR_CUTSCENE_HUD_HIDDEN) == true then
			Character:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, true)
		end
		if State.Active then
			HideCharacter(Character)
			return
		end

		task.defer(function()
			if State.Active or IsIntroCutsceneLocked() then
				return
			end

			Character:WaitForChild("Humanoid", 5)
			RestoreGameplayCameraNow()
			StartGameplayCameraRestoreWatchdog(GAMEPLAY_CAMERA_RESTORE_TIMEOUT)
		end)
	end)
end

return MatchIntroController