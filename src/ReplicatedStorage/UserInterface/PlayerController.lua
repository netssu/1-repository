--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local ZonePlus = require(ReplicatedStorage.Packages.ZonePlus)
local GuiController = require(ReplicatedStorage.Controllers.GuiController)
local WaveTransition = require(ReplicatedStorage.Modules.WaveTransition)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)

local FTPlayerController = {}

local TEAM_COLORS = {
	[1] = Color3.fromRGB(0, 162, 255),
	[2] = Color3.fromRGB(255, 55, 55),
}

local TWEEN_INFO_HOVER = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_CLICK = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_SCALE = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TRANSITION_IN_INFO = TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TRANSITION_OUT_INFO = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
local PLAY_GUI_NAME = "PlayGui"
local PLAY_GUI_SELECTION_ACTIVE_ATTRIBUTE = "FTPositionSelectionActive"
local IN_LOBBY_ATTRIBUTE = "FTIsInLobby"
local MATCH_CUTSCENE_LOCK_ATTRIBUTE = "FTMatchCutsceneLocked"
local CUTSCENE_HUD_HIDDEN_ATTRIBUTE = "FTCutsceneHudHidden"
local SELECTION_TRANSITION_GUI_NAME = "SelectionWaveTransitionGui"
local PLAY_GUI_CAMERA_LOOK_DISTANCE = 12
local PLAY_GUI_CAMERA_FOCUS_SHIFT_X = 1.1
local PLAY_GUI_CAMERA_FOCUS_SHIFT_Y = 0.6
local PLAY_GUI_CAMERA_POSITION_SHIFT_X = 0.12
local PLAY_GUI_CAMERA_POSITION_SHIFT_Y = 0.08
local PLAY_GUI_CAMERA_BLEND_SPEED = 8
local SELECTION_TRANSITION_COVER_HOLD_TIME = 0.12
local SELECTION_TRANSITION_RELEASE_TIMEOUT = 2
local PLAY_GUI_CAMERA_RELEASE_DISTANCE = 10
local PLAY_GUI_CAMERA_RELEASE_HEIGHT = 4
local PLAY_GUI_CAMERA_RELEASE_LOOK_HEIGHT = 2.5
local PLAY_GUI_CAMERA_RELEASE_TIMEOUT = 3
local POSITION_SELECTION_ACK_TIMEOUT = 8
local POSITION_SELECTION_SETTLE_TIMEOUT = 8
local POSITION_SELECTION_MIN_SETTLE_TIME = 0.2
local POSITION_SELECTION_TARGET_RADIUS = 8
local WORLD_UP_VECTOR = Vector3.new(0, 1, 0)

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local PlayGui: ScreenGui? = nil
local PickingFrameContainer: Frame? = nil
local Controls: any = nil
local PositionButtons: { [string]: { Button: ImageButton, Position: string, Team: number, OriginalSize: UDim2, OriginalColor: Color3 } } =
	{}
local IntermissionActive = true
local ActiveTweens: { [Instance]: { [string]: Tween } } = {}
local OccupiedPositions: { [string]: boolean } = {}
local PlayZone: any = nil
local Connections: { RBXScriptConnection } = {}
local IsSelectingPosition = false
local PendingPlayOpen = false
local PlayGuiDismissed = false
local PlayGuiMovementLocked = false
local PlayerGuiRef: PlayerGui? = nil
local LoadingGui: ScreenGui? = nil
local GameState = ReplicatedStorage:WaitForChild("FTGameState")
local MatchEnabled: BooleanValue? = nil
local PlayGuiCameraConnection: RBXScriptConnection? = nil
local GameplayCameraReleaseConnection: RBXScriptConnection? = nil
local PlayGuiCameraAnchor: BasePart? = nil
local PlayGuiCameraLookOffset = Vector2.zero
local SelectionTransitionState = {
	Token = 0 :: number,
	Overlay = nil :: ScreenGui?,
	Container = nil :: Frame?,
	AlphaValue = nil :: NumberValue?,
	Transition = nil :: any,
	Connection = nil :: RBXScriptConnection?,
	TweenIn = nil :: Tween?,
	TweenOut = nil :: Tween?,
	ContainerSize = nil :: Vector2?,
}
local ThumbnailCache: { [number]: string } = {}
local PendingThumbnailRequests: { [number]: boolean } = {}
local BoundThumbnailIcons: { [ImageLabel]: number } = setmetatable({}, { __mode = "k" }) :: { [ImageLabel]: number }
local StoredMovementState: {
	Humanoid: Humanoid,
	WalkSpeed: number,
	JumpPower: number,
	JumpHeight: number,
	UseJumpPower: boolean,
	AutoRotate: boolean,
}? =
	nil
local MovementLockHeartbeat: RBXScriptConnection? = nil
local PlayGuiOpen = false
local PlayZoneAutoOpenArmed = false
local PlayZonePart: BasePart? = nil
local PlayZoneSpawnStateToken = 0
local PendingSelectionRequestId = 0
local PendingSelectionTeam: number? = nil
local PendingSelectionPosition: string? = nil
local PendingSelectionAwaitingServer = false
local PendingSelectionAwaitingSettle = false
local UpdatePickingFrame: () -> ()
local IsSelectionCameraReleaseBlocked: () -> boolean

local function GetLocalHumanoid(): Humanoid?
	local Character = LocalPlayer.Character
	if not Character then
		return nil
	end
	return Character:FindFirstChildOfClass("Humanoid")
end

local function GetLocalRootPart(): BasePart?
	local Character = LocalPlayer.Character
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function IsPositionInsidePart(Part: BasePart, Position: Vector3): boolean
	local LocalPosition = Part.CFrame:PointToObjectSpace(Position)
	local HalfSize = Part.Size * 0.5
	return math.abs(LocalPosition.X) <= HalfSize.X
		and math.abs(LocalPosition.Y) <= HalfSize.Y
		and math.abs(LocalPosition.Z) <= HalfSize.Z
end

local function RefreshPlayZoneAutoOpenState(Character: Model?): ()
	PlayZoneSpawnStateToken += 1
	local Token = PlayZoneSpawnStateToken

	task.spawn(function()
		local CurrentCharacter = Character or LocalPlayer.Character
		if not CurrentCharacter then
			return
		end

		local RootPart = CurrentCharacter:FindFirstChild("HumanoidRootPart")
			or CurrentCharacter:WaitForChild("HumanoidRootPart", 5)
		if Token ~= PlayZoneSpawnStateToken then
			return
		end
		if LocalPlayer.Character ~= CurrentCharacter then
			return
		end

		local CurrentPlayZonePart = PlayZonePart
		if not CurrentPlayZonePart or not CurrentPlayZonePart.Parent then
			return
		end

		local InPlayZone: boolean?
		if RootPart and RootPart:IsA("BasePart") then
			InPlayZone = IsPositionInsidePart(CurrentPlayZonePart, RootPart.Position)
		elseif PlayZone then
			local success, result = pcall(function()
				return PlayZone:findLocalPlayer()
			end)
			if success then
				InPlayZone = result
			end
		end
		if InPlayZone == nil then
			return
		end
		PlayZoneAutoOpenArmed = not InPlayZone
		if InPlayZone then
			PendingPlayOpen = false
		end
	end)
end

local function GetGameplayCameraReleaseCFrame(): CFrame?
	local RootPart = GetLocalRootPart()
	if not RootPart then
		return nil
	end

	local FocusPosition = RootPart.Position + Vector3.new(0, PLAY_GUI_CAMERA_RELEASE_LOOK_HEIGHT, 0)
	local CameraPosition = FocusPosition
		- (RootPart.CFrame.LookVector * PLAY_GUI_CAMERA_RELEASE_DISTANCE)
		+ Vector3.new(0, PLAY_GUI_CAMERA_RELEASE_HEIGHT, 0)

	return CFrame.lookAt(CameraPosition, FocusPosition, WORLD_UP_VECTOR)
end

local function StopGameplayCameraReleaseWatchdog(): ()
	if GameplayCameraReleaseConnection then
		GameplayCameraReleaseConnection:Disconnect()
		GameplayCameraReleaseConnection = nil
	end
end

local function RestoreGameplayCamera(ForceRelease: boolean?): ()
	Camera.CameraType = Enum.CameraType.Custom
	local Humanoid = GetLocalHumanoid()
	if Humanoid then
		Camera.CameraSubject = Humanoid
	end
	if ForceRelease == true then
		local ReleaseCFrame = GetGameplayCameraReleaseCFrame()
		if ReleaseCFrame then
			Camera.CFrame = ReleaseCFrame
		end
	end
end

local function IsCameraReleasedFromMiddlePosition(): boolean
	local GameFolder = Workspace:FindFirstChild("Game")
	local Middle = GameFolder and GameFolder:FindFirstChild("MiddlePosition")
	if not Middle or not Middle:IsA("BasePart") then
		return true
	end
	return (Camera.CFrame.Position - Middle.Position).Magnitude > POSITION_SELECTION_TARGET_RADIUS
end

local function StartGameplayCameraReleaseWatchdog(Duration: number): ()
	StopGameplayCameraReleaseWatchdog()
	local Deadline = os.clock() + math.max(Duration, POSITION_SELECTION_MIN_SETTLE_TIME)
	GameplayCameraReleaseConnection = RunService.Heartbeat:Connect(function()
		if PlayGui and PlayGui.Enabled then
			return
		end
		if IsSelectionCameraReleaseBlocked() then
			StopGameplayCameraReleaseWatchdog()
			return
		end
		RestoreGameplayCamera(true)
		if IsCameraReleasedFromMiddlePosition() or os.clock() >= Deadline then
			StopGameplayCameraReleaseWatchdog()
		end
	end)
end

IsSelectionCameraReleaseBlocked = function(): boolean
	local Character = LocalPlayer.Character
	if LocalPlayer:GetAttribute(MATCH_CUTSCENE_LOCK_ATTRIBUTE) == true then
		return true
	end
	if LocalPlayer:GetAttribute(CUTSCENE_HUD_HIDDEN_ATTRIBUTE) == true then
		return true
	end
	if Character then
		if Character:GetAttribute(MATCH_CUTSCENE_LOCK_ATTRIBUTE) == true then
			return true
		end
		if Character:GetAttribute(CUTSCENE_HUD_HIDDEN_ATTRIBUTE) == true then
			return true
		end
	end
	return false
end

local function CleanupSelectionTransitionOverlay(DestroyOverlay: boolean?): ()
	local TweenIn = SelectionTransitionState.TweenIn
	if TweenIn then
		TweenIn:Cancel()
		SelectionTransitionState.TweenIn = nil
	end

	local TweenOut = SelectionTransitionState.TweenOut
	if TweenOut then
		TweenOut:Cancel()
		SelectionTransitionState.TweenOut = nil
	end

	if DestroyOverlay ~= true then
		local Overlay = SelectionTransitionState.Overlay
		local AlphaValue = SelectionTransitionState.AlphaValue
		local Transition = SelectionTransitionState.Transition
		if Overlay and AlphaValue and Transition then
			Overlay.Enabled = false
			AlphaValue.Value = 0
			pcall(function()
				Transition:Update(0)
			end)
		end
		return
	end

	local Connection = SelectionTransitionState.Connection
	if Connection then
		Connection:Disconnect()
		SelectionTransitionState.Connection = nil
	end

	local AlphaValue = SelectionTransitionState.AlphaValue
	if AlphaValue then
		AlphaValue:Destroy()
		SelectionTransitionState.AlphaValue = nil
	end

	local Transition = SelectionTransitionState.Transition
	if Transition then
		Transition:Destroy()
		SelectionTransitionState.Transition = nil
	end

	local Container = SelectionTransitionState.Container
	if Container and DestroyOverlay == true then
		SelectionTransitionState.Container = nil
	end
	SelectionTransitionState.ContainerSize = nil

	local Overlay = SelectionTransitionState.Overlay
	if Overlay then
		if DestroyOverlay ~= true then
			Overlay.Enabled = false
			return
		end
		Overlay:Destroy()
		SelectionTransitionState.Overlay = nil
	end
end

local function EnsureSelectionTransitionOverlay(): boolean
	local Overlay = SelectionTransitionState.Overlay
	local Container = SelectionTransitionState.Container
	local AlphaValue = SelectionTransitionState.AlphaValue
	local Transition = SelectionTransitionState.Transition
	local Connection = SelectionTransitionState.Connection
	if
		Overlay
		and Overlay.Parent ~= nil
		and Container
		and Container.Parent == Overlay
		and AlphaValue
		and AlphaValue.Parent ~= nil
		and Transition
		and Connection
	then
		local CurrentSize = Container.AbsoluteSize
		local PreviousSize = SelectionTransitionState.ContainerSize
		if
			PreviousSize
			and (
				(CurrentSize.X <= 0 or CurrentSize.Y <= 0)
				or (math.abs(CurrentSize.X - PreviousSize.X) <= 1 and math.abs(CurrentSize.Y - PreviousSize.Y) <= 1)
			)
		then
			return true
		end
	end

	CleanupSelectionTransitionOverlay(true)

	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end

	local overlay = Instance.new("ScreenGui")
	overlay.Name = SELECTION_TRANSITION_GUI_NAME
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = 9999
	overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlay.Enabled = false
	overlay.Parent = playerGui
	SelectionTransitionState.Overlay = overlay

	local container = Instance.new("Frame")
	container.Name = "WaveContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Parent = overlay
	SelectionTransitionState.Container = container

	for _ = 1, 2 do
		if container.AbsoluteSize.X > 0 and container.AbsoluteSize.Y > 0 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	local transition = WaveTransition.new(container, {
		color = Color3.new(0, 0, 0),
		width = 14,
		waveDirection = Vector2.new(1, -0.7),
	})
	SelectionTransitionState.Transition = transition
	SelectionTransitionState.ContainerSize = container.AbsoluteSize

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Value = 0
	transition:Update(alphaValue.Value)
	alphaValue.Parent = overlay
	SelectionTransitionState.AlphaValue = alphaValue

	local connection = alphaValue.Changed:Connect(function()
		transition:Update(alphaValue.Value)
	end)
	SelectionTransitionState.Connection = connection

	return true
end

local function ApplyCachedThumbnail(Icon: ImageLabel, UserId: number): ()
	BoundThumbnailIcons[Icon] = UserId

	local CachedImage: string? = ThumbnailCache[UserId]
	if CachedImage then
		Icon.Image = CachedImage
		return
	end

	if PendingThumbnailRequests[UserId] then
		return
	end

	PendingThumbnailRequests[UserId] = true
	task.spawn(function()
		local Success: boolean, Image: any = pcall(function()
			return Players:GetUserThumbnailAsync(UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)

		PendingThumbnailRequests[UserId] = nil
		if not Success or type(Image) ~= "string" or Image == "" then
			return
		end

		ThumbnailCache[UserId] = Image
		for BoundIcon, BoundUserId in BoundThumbnailIcons do
			if BoundUserId == UserId and BoundIcon.Parent ~= nil then
				BoundIcon.Image = Image
			end
		end
	end)
end

local function IsSelectionTransitionReadyToReveal(): boolean
	if LocalPlayer:GetAttribute(MATCH_CUTSCENE_LOCK_ATTRIBUTE) == true then
		return true
	end
	if not PlayGui or not PlayGui.Enabled then
		return true
	end
	if not IsSelectingPosition and not PendingSelectionAwaitingServer and not PendingSelectionAwaitingSettle then
		return true
	end
	return false
end

local function SetPositionButtonsInteractable(Enabled: boolean): ()
	for _, ButtonData in PositionButtons do
		local Button = ButtonData.Button
		Button.Active = Enabled
		Button.AutoButtonColor = Enabled
	end
end

local function IsLoading(): boolean
	local playerGui = PlayerGuiRef or LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return true
	end
	if LoadingGui and LoadingGui.Parent == playerGui then
		return true
	end
	local loading = playerGui:FindFirstChild("LoadingGui")
	if loading and loading:IsA("ScreenGui") then
		LoadingGui = loading
		return true
	end
	return false
end

local function CanEnterMatch(): boolean
	if IsLoading() then
		return false
	end
	local intermission = GameState:FindFirstChild("IntermissionActive") :: BoolValue?
	local intermissionTime = GameState:FindFirstChild("IntermissionTime") :: IntValue?
	if not intermission or not intermissionTime then
		return false
	end
	if intermission.Value then
		return false
	end
	if intermissionTime.Value > 0 then
		return false
	end
	return true
end

local function IsLocalPlayerInMatch(): boolean
	return MatchPlayerUtils.IsPlayerActive(LocalPlayer)
end

local function GetAssignedSelection(): (number?, string?)
	local MatchFolder = GameState and GameState:FindFirstChild("Match")
	if not MatchFolder then
		return nil, nil
	end

	local localId = PlayerIdentity.GetLocalIdValue()
	if localId <= 0 then
		return nil, nil
	end

	for TeamIndex = 1, 2 do
		local TeamFolder = MatchFolder:FindFirstChild("Team" .. TeamIndex)
		if not TeamFolder then
			continue
		end
		for _, PositionValue in TeamFolder:GetChildren() do
			if PositionValue:IsA("IntValue") and PositionValue.Value == localId then
				return TeamIndex, PositionValue.Name
			end
		end
	end

	return nil, nil
end

local function FindTeamPositionTarget(TeamFolder: Instance, Position: string): Instance?
	local DirectTarget = TeamFolder:FindFirstChild(Position)
	if DirectTarget then
		return DirectTarget
	end
	return TeamFolder:FindFirstChild(Position, true)
end

local function GetPositionTargetCFrame(PositionTarget: Instance?): CFrame?
	if not PositionTarget then
		return nil
	end
	if PositionTarget:IsA("BasePart") then
		return PositionTarget.CFrame
	end
	if PositionTarget:IsA("Model") then
		if PositionTarget.PrimaryPart then
			return PositionTarget.PrimaryPart.CFrame
		end
		local DescendantPart = PositionTarget:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
		if DescendantPart then
			return DescendantPart.CFrame
		end
	end
	return nil
end

local function GetSpawnTargetCFrame(TeamNumber: number?, PositionName: string?): CFrame?
	if type(TeamNumber) ~= "number" or type(PositionName) ~= "string" or PositionName == "" then
		return nil
	end

	local GameFolder = Workspace:FindFirstChild("Game")
	local Positions = GameFolder and GameFolder:FindFirstChild("Positions")
	local TeamFolder = Positions and Positions:FindFirstChild("Team" .. TeamNumber)
	if not TeamFolder then
		return nil
	end

	return GetPositionTargetCFrame(FindTeamPositionTarget(TeamFolder, PositionName))
end

local function UpdatePositionSelectionAttribute(): ()
	local Active = PlayGuiOpen or IsSelectingPosition
	LocalPlayer:SetAttribute(PLAY_GUI_SELECTION_ACTIVE_ATTRIBUTE, Active)
	local Character = LocalPlayer.Character
	if Character then
		Character:SetAttribute(PLAY_GUI_SELECTION_ACTIVE_ATTRIBUTE, Active)
	end
end

local function RestoreLobbyHud(): ()
	local playerGui = PlayerGuiRef or LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local hudGui = playerGui:FindFirstChild("HudGui")
	if not hudGui or not hudGui:IsA("ScreenGui") then
		return
	end

	local function shouldEnableHud(): boolean
		if GuiController._currentGuiName ~= nil then
			return false
		end

		local Character = LocalPlayer.Character
		local selectionActive = LocalPlayer:GetAttribute(PLAY_GUI_SELECTION_ACTIVE_ATTRIBUTE) == true
			or (Character ~= nil and Character:GetAttribute(PLAY_GUI_SELECTION_ACTIVE_ATTRIBUTE) == true)
		if selectionActive then
			return false
		end

		local cutsceneBlocked = LocalPlayer:GetAttribute(MATCH_CUTSCENE_LOCK_ATTRIBUTE) == true
			or LocalPlayer:GetAttribute(CUTSCENE_HUD_HIDDEN_ATTRIBUTE) == true
			or (Character ~= nil and Character:GetAttribute(MATCH_CUTSCENE_LOCK_ATTRIBUTE) == true)
			or (Character ~= nil and Character:GetAttribute(CUTSCENE_HUD_HIDDEN_ATTRIBUTE) == true)
		if cutsceneBlocked then
			return false
		end

		local playerInLobby = LocalPlayer:GetAttribute(IN_LOBBY_ATTRIBUTE)
		local characterInLobby = if Character ~= nil then Character:GetAttribute(IN_LOBBY_ATTRIBUTE) else nil
		return playerInLobby ~= false or characterInLobby ~= false
	end

	if shouldEnableHud() then
		hudGui.Enabled = true
		task.defer(function()
			if hudGui.Parent and shouldEnableHud() then
				hudGui.Enabled = true
			end
		end)
	end
end

local function ApplyMovementLockToCharacter(): ()
	local Character = LocalPlayer.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Humanoid and (not StoredMovementState or StoredMovementState.Humanoid ~= Humanoid) then
		StoredMovementState = {
			Humanoid = Humanoid,
			WalkSpeed = Humanoid.WalkSpeed,
			JumpPower = Humanoid.JumpPower,
			JumpHeight = Humanoid.JumpHeight,
			UseJumpPower = Humanoid.UseJumpPower,
			AutoRotate = Humanoid.AutoRotate,
		}
	end

	if Humanoid then
		Humanoid.WalkSpeed = 0
		Humanoid.JumpPower = 0
		Humanoid.JumpHeight = 0
		Humanoid.AutoRotate = false
		Humanoid:Move(Vector3.zero, false)
	end
	if RootPart then
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

local function StopMovementLockHeartbeat(): ()
	if MovementLockHeartbeat then
		MovementLockHeartbeat:Disconnect()
		MovementLockHeartbeat = nil
	end
end

local function StartMovementLockHeartbeat(): ()
	if MovementLockHeartbeat then
		return
	end

	MovementLockHeartbeat = RunService.Heartbeat:Connect(function()
		if not PlayGuiMovementLocked then
			return
		end
		ApplyMovementLockToCharacter()
	end)
end

local function SetPlayGuiMovementLocked(Locked: boolean): ()
	PlayGuiMovementLocked = Locked
	if Controls then
		if Locked then
			Controls:Disable()
		else
			Controls:Enable()
		end
	end

	if Locked then
		StartMovementLockHeartbeat()
		ApplyMovementLockToCharacter()
		return
	end

	StopMovementLockHeartbeat()

	local Character = LocalPlayer.Character
	if not Character then
		StoredMovementState = nil
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid and StoredMovementState and StoredMovementState.Humanoid == Humanoid then
		Humanoid.WalkSpeed = StoredMovementState.WalkSpeed
		Humanoid.JumpPower = StoredMovementState.JumpPower
		Humanoid.JumpHeight = StoredMovementState.JumpHeight
		Humanoid.UseJumpPower = StoredMovementState.UseJumpPower
		Humanoid.AutoRotate = StoredMovementState.AutoRotate
	end
	StoredMovementState = nil
end

local function StopPlayGuiCameraFollow(): ()
	if PlayGuiCameraConnection then
		PlayGuiCameraConnection:Disconnect()
		PlayGuiCameraConnection = nil
	end
	PlayGuiCameraAnchor = nil
	PlayGuiCameraLookOffset = Vector2.zero
end

local function EnsureSelectionGuiClosedAndCameraReleased(): ()
	local Deadline = os.clock() + POSITION_SELECTION_SETTLE_TIMEOUT
	SetPlayGuiMovementLocked(false)
	if not IsSelectionCameraReleaseBlocked() then
		StartGameplayCameraReleaseWatchdog(PLAY_GUI_CAMERA_RELEASE_TIMEOUT)
	end

	repeat
		StopPlayGuiCameraFollow()
		if not IsSelectionCameraReleaseBlocked() then
			RestoreGameplayCamera(true)
		end
		if PlayGui and PlayGui.Enabled then
			GuiController:Close(PLAY_GUI_NAME)
		end
		RunService.Heartbeat:Wait()
	until (
			(not PlayGui or not PlayGui.Enabled)
			and (IsSelectionCameraReleaseBlocked() or IsCameraReleasedFromMiddlePosition())
		) or os.clock() >= Deadline

	StopGameplayCameraReleaseWatchdog()
	if not IsSelectionCameraReleaseBlocked() then
		RestoreGameplayCamera(true)
	end
end

local function IsPlayGuiCutsceneBlocked(): boolean
	local Character = LocalPlayer.Character
	return LocalPlayer:GetAttribute(MATCH_CUTSCENE_LOCK_ATTRIBUTE) == true
		or LocalPlayer:GetAttribute(CUTSCENE_HUD_HIDDEN_ATTRIBUTE) == true
		or (Character ~= nil and Character:GetAttribute(MATCH_CUTSCENE_LOCK_ATTRIBUTE) == true)
		or (Character ~= nil and Character:GetAttribute(CUTSCENE_HUD_HIDDEN_ATTRIBUTE) == true)
end

local function ForceReleasePlayGuiForCutscene(): ()
	if not IsPlayGuiCutsceneBlocked() then
		return
	end

	PendingPlayOpen = false
	StopGameplayCameraReleaseWatchdog()
	StopPlayGuiCameraFollow()
	SetPlayGuiMovementLocked(false)

	if PlayGui and PlayGui.Enabled then
		PlayGui.Enabled = false
	end

	GuiController:Close(PLAY_GUI_NAME)
end

local function StartPlayGuiCameraFollow(anchor: BasePart): ()
	StopGameplayCameraReleaseWatchdog()
	StopPlayGuiCameraFollow()
	PlayGuiCameraAnchor = anchor
	PlayGuiCameraConnection = RunService.RenderStepped:Connect(function(dt: number)
		if not PlayGuiMovementLocked or not PlayGui or not PlayGui.Enabled then
			return
		end
		if IsPlayGuiCutsceneBlocked() then
			ForceReleasePlayGuiForCutscene()
			return
		end
		local currentAnchor = PlayGuiCameraAnchor
		if not currentAnchor or not currentAnchor.Parent then
			return
		end
		local viewportSize = Camera.ViewportSize
		if viewportSize.X <= 0 or viewportSize.Y <= 0 then
			Camera.CFrame = currentAnchor.CFrame
			return
		end
		local mouseLocation = UserInputService:GetMouseLocation()
		local normalizedX = math.clamp(((mouseLocation.X / viewportSize.X) - 0.5) * 2, -1, 1)
		local normalizedY = math.clamp(((mouseLocation.Y / viewportSize.Y) - 0.5) * 2, -1, 1)
		local targetOffset =
			Vector2.new(normalizedX * PLAY_GUI_CAMERA_FOCUS_SHIFT_X, -normalizedY * PLAY_GUI_CAMERA_FOCUS_SHIFT_Y)
		local blendAlpha = 1 - math.exp(-PLAY_GUI_CAMERA_BLEND_SPEED * math.clamp(dt, 0, 0.1))
		PlayGuiCameraLookOffset = PlayGuiCameraLookOffset:Lerp(targetOffset, blendAlpha)

		local anchorCFrame = currentAnchor.CFrame
		local camPosition = anchorCFrame.Position
			- anchorCFrame.RightVector * (PlayGuiCameraLookOffset.X * PLAY_GUI_CAMERA_POSITION_SHIFT_X)
			- anchorCFrame.UpVector * (PlayGuiCameraLookOffset.Y * PLAY_GUI_CAMERA_POSITION_SHIFT_Y)
		local focusPosition = anchorCFrame.Position
			+ anchorCFrame.LookVector * PLAY_GUI_CAMERA_LOOK_DISTANCE
			+ anchorCFrame.RightVector * PlayGuiCameraLookOffset.X
			+ anchorCFrame.UpVector * PlayGuiCameraLookOffset.Y
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = CFrame.lookAt(camPosition, focusPosition, anchorCFrame.UpVector)
	end)
end

local function ApplyPlayGuiGate(): ()
	if not PlayGui then
		return
	end
	local matchEnabled = MatchEnabled and MatchEnabled.Value or false
	local canEnter = CanEnterMatch() and matchEnabled
	if not canEnter then
		PlayGui.Enabled = false
		PendingPlayOpen = false
		GuiController:Close(PLAY_GUI_NAME)
	end
end

local function IsPlayReady(): boolean
	if not PlayGui or not PickingFrameContainer then
		return false
	end
	if next(PositionButtons) == nil then
		return false
	end
	local MatchFolder = GameState and GameState:FindFirstChild("Match")
	if not MatchFolder then
		return false
	end
	if not MatchEnabled or not MatchEnabled.Value then
		return false
	end
	return true
end

local function TryOpenPlayGui(): ()
	if not PlayZone then
		return
	end
	if not PlayZoneAutoOpenArmed then
		return
	end
	if IsSelectingPosition then
		return
	end
	if PendingSelectionAwaitingServer or PendingSelectionAwaitingSettle then
		return
	end
	if IsLocalPlayerInMatch() then
		return
	end
	local AssignedTeam: number?, AssignedPosition: string? = GetAssignedSelection()
	if AssignedTeam ~= nil and AssignedPosition ~= nil then
		return
	end
	if PlayGuiDismissed then
		return
	end
	if IntermissionActive then
		return
	end
	if not CanEnterMatch() then
		return
	end
	if not MatchEnabled or not MatchEnabled.Value then
		return
	end
	local inZone = false
	pcall(function()
		inZone = PlayZone:findLocalPlayer()
	end)
	if not inZone then
		return
	end
	if not IsPlayReady() then
		PendingPlayOpen = true
		return
	end
	PendingPlayOpen = false
	UpdatePickingFrame()
	GuiController:Open(PLAY_GUI_NAME)
end

local function Cleanup(): ()
	SetPlayGuiMovementLocked(false)
	StopPlayGuiCameraFollow()
	StopGameplayCameraReleaseWatchdog()
	CleanupSelectionTransitionOverlay(true)
	PlayGuiOpen = false
	IsSelectingPosition = false
	PendingSelectionTeam = nil
	PendingSelectionPosition = nil
	PendingSelectionAwaitingServer = false
	PendingSelectionAwaitingSettle = false
	UpdatePositionSelectionAttribute()
	SetPositionButtonsInteractable(true)
	for _, Connection in Connections do
		if Connection then
			Connection:Disconnect()
		end
	end
	Connections = {}
	PositionButtons = {}
	OccupiedPositions = {}
	ActiveTweens = {}
	PlayGuiDismissed = false
	PlayZoneAutoOpenArmed = false
	PlayZonePart = nil
	PlayZoneSpawnStateToken += 1
	if PlayZone then
		PlayZone:destroy()
		PlayZone = nil
	end
end

local function HandleTween(Object: GuiObject, Info: TweenInfo, Goals: { [string]: any }, Name: string): Tween
	if ActiveTweens[Object] and ActiveTweens[Object][Name] then
		ActiveTweens[Object][Name]:Cancel()
	end
	local NewTween = TweenService:Create(Object, Info, Goals)
	ActiveTweens[Object] = ActiveTweens[Object] or {}
	ActiveTweens[Object][Name] = NewTween
	NewTween:Play()
	return NewTween
end

local function PlaySelectionTransition(teamNumber: number): ()
	local _ = teamNumber
	if not EnsureSelectionTransitionOverlay() then
		return
	end

	SelectionTransitionState.Token += 1
	local Token = SelectionTransitionState.Token
	CleanupSelectionTransitionOverlay()

	local overlay = SelectionTransitionState.Overlay
	local alphaValue = SelectionTransitionState.AlphaValue
	if not overlay or not alphaValue then
		return
	end
	overlay.Enabled = true

	local function CleanupTransitionState(): ()
		if SelectionTransitionState.Token ~= Token then
			return
		end
		CleanupSelectionTransitionOverlay()
	end

	local tweenIn = TweenService:Create(alphaValue, TRANSITION_IN_INFO, { Value = 1 })
	SelectionTransitionState.TweenIn = tweenIn
	tweenIn.Completed:Once(function()
		if SelectionTransitionState.TweenIn == tweenIn then
			SelectionTransitionState.TweenIn = nil
		end
		if SelectionTransitionState.Token ~= Token or SelectionTransitionState.Overlay ~= overlay then
			return
		end

		local HoldUntil = os.clock() + SELECTION_TRANSITION_COVER_HOLD_TIME
		while SelectionTransitionState.Token == Token and os.clock() < HoldUntil do
			RunService.Heartbeat:Wait()
		end

		local ReleaseDeadline = os.clock() + SELECTION_TRANSITION_RELEASE_TIMEOUT
		while SelectionTransitionState.Token == Token and os.clock() < ReleaseDeadline do
			if IsSelectionTransitionReadyToReveal() then
				break
			end
			RunService.Heartbeat:Wait()
		end

		if SelectionTransitionState.Token ~= Token or SelectionTransitionState.Overlay ~= overlay then
			return
		end

		local tweenOut = TweenService:Create(alphaValue, TRANSITION_OUT_INFO, { Value = 0 })
		SelectionTransitionState.TweenOut = tweenOut
		tweenOut.Completed:Once(function()
			if SelectionTransitionState.TweenOut == tweenOut then
				SelectionTransitionState.TweenOut = nil
			end
			CleanupTransitionState()
		end)
		tweenOut:Play()
	end)

	tweenIn:Play()
end

UpdatePickingFrame = function(): ()
	if not PickingFrameContainer then
		return
	end

	local MatchFolder = GameState and GameState:FindFirstChild("Match")

	for TeamIndex = 1, 2 do
		local TeamFrame = PickingFrameContainer:FindFirstChild("Team" .. TeamIndex)
		if not TeamFrame then
			continue
		end

		local TeamColor = TEAM_COLORS[TeamIndex]

		for _, Position in FTConfig.PLAYER_POSITIONS do
			local Element = TeamFrame:FindFirstChild(Position.Name)
			if not Element then
				continue
			end

			local Button = Element:IsA("ImageButton") and Element or Element:FindFirstChild("Button")
			if not Button or not Button:IsA("ImageButton") then
				continue
			end

			local PositionKey = TeamIndex .. "_" .. Position.Name
			local OccupantId = 0

			if MatchFolder then
				local TeamFolder = MatchFolder:FindFirstChild("Team" .. TeamIndex)
				if TeamFolder then
					local PositionValue = TeamFolder:FindFirstChild(Position.Name) :: IntValue?
					if PositionValue then
						OccupantId = PositionValue.Value
					end
				end
			end

			local Icon = Button:FindFirstChild("PlayerIcon", true)
			local NameLabel = Button:FindFirstChild("PlayerName", true)

			if OccupantId ~= 0 then
				OccupiedPositions[PositionKey] = true
				local FoundPlayer = PlayerIdentity.ResolvePlayer(OccupantId)

				if Icon and Icon:IsA("ImageLabel") then
					if FoundPlayer then
						ApplyCachedThumbnail(Icon, FoundPlayer.UserId)
						Icon.Visible = true
					else
						BoundThumbnailIcons[Icon] = nil
						Icon.Visible = false
					end
				end

				if NameLabel and NameLabel:IsA("TextLabel") then
					if FoundPlayer then
						NameLabel.Text = FoundPlayer.DisplayName
					else
						NameLabel.Text = "Occupied"
					end
					NameLabel.Visible = true
				end

				Button.ImageColor3 = TeamColor
			else
				OccupiedPositions[PositionKey] = nil

				if Icon then
					if Icon:IsA("ImageLabel") then
						BoundThumbnailIcons[Icon] = nil
					end
					Icon.Visible = false
				end
				if NameLabel then
					NameLabel.Visible = false
				end

				local ButtonData = PositionButtons[PositionKey]
				if ButtonData then
					Button.ImageColor3 = ButtonData.OriginalColor
				else
					Button.ImageColor3 = Color3.fromRGB(255, 255, 255)
				end
			end

			TeamFrame.Visible = true
		end
	end
end

local function FinishPendingSelection(Succeeded: boolean): ()
	PendingSelectionAwaitingServer = false
	PendingSelectionAwaitingSettle = false
	PendingSelectionTeam = nil
	PendingSelectionPosition = nil
	IsSelectingPosition = false
	UpdatePositionSelectionAttribute()
	SetPositionButtonsInteractable(true)

	if not PlayGuiOpen then
		SetPlayGuiMovementLocked(false)
	end

	if not Succeeded then
		task.defer(function()
			if IsSelectingPosition or IsLocalPlayerInMatch() then
				return
			end
			UpdatePickingFrame()
			TryOpenPlayGui()
		end)
	end
end

local function WaitForSelectionSettlement(RequestId: number, TeamNumber: number, PositionName: string): ()
	local Deadline = os.clock() + POSITION_SELECTION_SETTLE_TIMEOUT
	local UnlockAfter = os.clock() + POSITION_SELECTION_MIN_SETTLE_TIME

	while PendingSelectionRequestId == RequestId and PendingSelectionAwaitingSettle do
		local AssignedTeam: number?, AssignedPosition: string? = GetAssignedSelection()
		local Assigned = AssignedTeam == TeamNumber and AssignedPosition == PositionName

		if Assigned and os.clock() >= UnlockAfter then
			break
		end
		if os.clock() >= Deadline then
			break
		end

		RunService.Heartbeat:Wait()
	end

	if PendingSelectionRequestId ~= RequestId or not PendingSelectionAwaitingSettle then
		return
	end

	EnsureSelectionGuiClosedAndCameraReleased()
	FinishPendingSelection(true)
end

local function WatchSelectionServerTimeout(RequestId: number): ()
	task.delay(POSITION_SELECTION_ACK_TIMEOUT, function()
		if PendingSelectionRequestId ~= RequestId or not PendingSelectionAwaitingServer then
			return
		end
		FinishPendingSelection(false)
	end)
end

local function OnPositionButtonClick(PositionName: string, TeamNumber: number): ()
	if IsSelectingPosition or PendingSelectionAwaitingServer or PendingSelectionAwaitingSettle then
		return
	end
	local AssignedTeam: number?, AssignedPosition: string? = GetAssignedSelection()
	if AssignedTeam ~= nil and AssignedPosition ~= nil then
		return
	end

	local PositionKey = TeamNumber .. "_" .. PositionName
	if OccupiedPositions[PositionKey] then
		return
	end

	IsSelectingPosition = true
	PendingSelectionRequestId += 1
	local RequestId = PendingSelectionRequestId
	PendingSelectionTeam = TeamNumber
	PendingSelectionPosition = PositionName
	PendingSelectionAwaitingServer = true
	PendingSelectionAwaitingSettle = false
	UpdatePositionSelectionAttribute()
	SetPositionButtonsInteractable(false)
	SetPlayGuiMovementLocked(true)
	WatchSelectionServerTimeout(RequestId)

	local TeamAsNumber: number = TeamNumber

	Packets.PositionSelect:Fire(PositionName, TeamAsNumber)
	SoundController:Play("Select")

	PlaySelectionTransition(TeamNumber)

	task.delay(0.5, function()
		if PendingSelectionRequestId ~= RequestId then
			return
		end
		if not (PendingSelectionAwaitingServer or PendingSelectionAwaitingSettle or IsLocalPlayerInMatch()) then
			return
		end
		PlayGuiDismissed = false
		GuiController:Close(PLAY_GUI_NAME)
	end)
end

local function SetupButtonEvents(
	Button: ImageButton,
	Position: string,
	TeamNumber: number,
	OriginalSize: UDim2,
	OriginalColor: Color3,
	TeamColor: Color3
): ()
	local PositionKey = TeamNumber .. "_" .. Position

	local MouseEnterConnection = Button.MouseEnter:Connect(function()
		if OccupiedPositions[PositionKey] then
			return
		end
		if IsSelectingPosition then
			return
		end

		SoundController:PlayUiHover()
		HandleTween(Button, TWEEN_INFO_SCALE, {
			Size = UDim2.new(
				OriginalSize.X.Scale * 1.1,
				OriginalSize.X.Offset,
				OriginalSize.Y.Scale * 1.1,
				OriginalSize.Y.Offset
			),
		}, "Scale")
		HandleTween(Button, TWEEN_INFO_HOVER, { ImageColor3 = TeamColor }, "Color")
	end)
	table.insert(Connections, MouseEnterConnection)

	local MouseLeaveConnection = Button.MouseLeave:Connect(function()
		if OccupiedPositions[PositionKey] then
			return
		end

		HandleTween(Button, TWEEN_INFO_SCALE, { Size = OriginalSize }, "Scale")
		HandleTween(Button, TWEEN_INFO_HOVER, { ImageColor3 = OriginalColor }, "Color")
	end)
	table.insert(Connections, MouseLeaveConnection)

	local ActivatedConnection = Button.Activated:Connect(function()
		if OccupiedPositions[PositionKey] then
			return
		end
		if IsSelectingPosition or PendingSelectionAwaitingServer or PendingSelectionAwaitingSettle then
			return
		end

		local ClickTween = HandleTween(Button, TWEEN_INFO_CLICK, {
			Size = UDim2.new(
				OriginalSize.X.Scale * 0.95,
				OriginalSize.X.Offset,
				OriginalSize.Y.Scale * 0.95,
				OriginalSize.Y.Offset
			),
		}, "Click")

		ClickTween.Completed:Once(function()
			HandleTween(Button, TWEEN_INFO_CLICK, { Size = OriginalSize }, "Scale")
		end)

		OnPositionButtonClick(Position, TeamNumber)
	end)
	table.insert(Connections, ActivatedConnection)
end

local function ConfigureButton(Element: GuiObject, Position: string, TeamNumber: number, TeamColor: Color3): ()
	local Button = Element:IsA("ImageButton") and Element or Element:FindFirstChild("Button")
	if not Button or not Button:IsA("ImageButton") then
		return
	end

	local Key = TeamNumber .. "_" .. Position
	if PositionButtons[Key] then
		return
	end

	local OriginalSize = Button.Size
	local OriginalColor = Button.ImageColor3

	PositionButtons[Key] = {
		Button = Button,
		Position = Position,
		Team = TeamNumber,
		OriginalSize = OriginalSize,
		OriginalColor = OriginalColor,
	}

	Button.Active = true
	Button.Visible = true

	if Element:IsA("Frame") then
		Element.BackgroundTransparency = 1
	end

	SetupButtonEvents(Button, Position, TeamNumber, OriginalSize, OriginalColor, TeamColor)
end

local function SetupPlayZone(): ()
	local Lobby = Workspace:FindFirstChild("Lobby")
	local UI = Lobby and Lobby:FindFirstChild("Zones") and Lobby.Zones:FindFirstChild("UI")
	local PlayPart = UI and UI:FindFirstChild("Play")

	if not PlayPart then
		return
	end

	PlayZonePart = PlayPart
	PlayZone = ZonePlus.new(PlayPart)
	PlayZoneAutoOpenArmed = false
	RefreshPlayZoneAutoOpenState(LocalPlayer.Character)

	local PlayerEnteredConnection = PlayZone.playerEntered:Connect(function(Player)
		if Player == LocalPlayer and PlayZoneAutoOpenArmed and not IntermissionActive and CanEnterMatch() then
			PlayGuiDismissed = false
			TryOpenPlayGui()
		end
	end)
	table.insert(Connections, PlayerEnteredConnection)

	local PlayerExitedConnection = PlayZone.playerExited:Connect(function(Player)
		if Player == LocalPlayer then
			PlayZoneAutoOpenArmed = true
			PendingPlayOpen = false
			PlayGuiDismissed = false
		end
	end)
	table.insert(Connections, PlayerExitedConnection)
end

local function SetupGuiControllerEvents(): ()
	local GuiOpenedConnection = GuiController.GuiOpened:Connect(function(GuiName: string)
		if GuiName == PLAY_GUI_NAME then
			if not CanEnterMatch() then
				GuiController:Close(PLAY_GUI_NAME)
				return
			end
			local AssignedTeam: number?, AssignedPosition: string? = GetAssignedSelection()
			if AssignedTeam ~= nil and AssignedPosition ~= nil then
				GuiController:Close(PLAY_GUI_NAME)
				return
			end
			PlayGuiOpen = true
			UpdatePositionSelectionAttribute()
			local GameFolder = Workspace:FindFirstChild("Game")
			local Middle = GameFolder and GameFolder:FindFirstChild("MiddlePosition")

			if Middle and Middle:IsA("BasePart") then
				Camera.CameraType = Enum.CameraType.Scriptable
				Camera.CFrame = Middle.CFrame
				StartPlayGuiCameraFollow(Middle)
			else
				StopPlayGuiCameraFollow()
			end
			SetPlayGuiMovementLocked(true)
		end
	end)
	table.insert(Connections, GuiOpenedConnection)

	local GuiClosedConnection = GuiController.GuiClosed:Connect(function(GuiName: string)
		if GuiName == PLAY_GUI_NAME then
			PlayGuiOpen = false
			StopPlayGuiCameraFollow()
			if not IsSelectionCameraReleaseBlocked() then
				RestoreGameplayCamera(true)
			end
			if not IsSelectionCameraReleaseBlocked() and not IsCameraReleasedFromMiddlePosition() then
				StartGameplayCameraReleaseWatchdog(PLAY_GUI_CAMERA_RELEASE_TIMEOUT)
			end
			UpdatePositionSelectionAttribute()
			if not IsSelectingPosition then
				SetPlayGuiMovementLocked(false)
				RestoreLobbyHud()
			end
		end
	end)
	table.insert(Connections, GuiClosedConnection)
end

local function BindMatchFolder(Folder: Folder): ()
	local function RefreshMatchFolderView(): ()
		UpdatePickingFrame()
		if MatchEnabled and MatchEnabled.Value then
			task.defer(TryOpenPlayGui)
		elseif PendingPlayOpen then
			TryOpenPlayGui()
		end
	end

	local DescendantAddedConnection = Folder.DescendantAdded:Connect(function(Descendant)
		if Descendant:IsA("IntValue") then
			local ChangedConnection = Descendant.Changed:Connect(function()
				RefreshMatchFolderView()
			end)
			table.insert(Connections, ChangedConnection)
			RefreshMatchFolderView()
			return
		end

		if Descendant:IsA("Folder") and (Descendant.Name == "Team1" or Descendant.Name == "Team2") then
			RefreshMatchFolderView()
		end
	end)
	table.insert(Connections, DescendantAddedConnection)

	local DescendantRemovingConnection = Folder.DescendantRemoving:Connect(function(Descendant)
		if Descendant:IsA("IntValue") then
			RefreshMatchFolderView()
			return
		end

		if Descendant:IsA("Folder") and (Descendant.Name == "Team1" or Descendant.Name == "Team2") then
			RefreshMatchFolderView()
		end
	end)
	table.insert(Connections, DescendantRemovingConnection)

	for _, Team in Folder:GetChildren() do
		for _, PositionValue in Team:GetChildren() do
			if PositionValue:IsA("IntValue") then
				local ChangedConnection = PositionValue.Changed:Connect(function()
					RefreshMatchFolderView()
				end)
				table.insert(Connections, ChangedConnection)
			end
		end
	end
	RefreshMatchFolderView()
end

function FTPlayerController.Init(): () end

function FTPlayerController.Start(): ()
	Cleanup()
	SetupGuiControllerEvents()
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	PlayerGuiRef = PlayerGui
	LoadingGui = PlayerGui:FindFirstChild("LoadingGui") :: ScreenGui?
	local PlayerModule = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	Controls = PlayerModule:GetControls()
	PlayGui = PlayerGui:WaitForChild(PLAY_GUI_NAME) :: ScreenGui
	PlayGui.Enabled = false
	PickingFrameContainer = PlayGui:WaitForChild("PickingFrame", 5) or PlayGui:WaitForChild("Main", 5)
	task.defer(EnsureSelectionTransitionOverlay)

	local MainFrame = PlayGui:WaitForChild("Main", 5)
	local ExitButton = MainFrame and MainFrame:WaitForChild("Exit", 5)
	if ExitButton and ExitButton:IsA("GuiButton") then
		local ExitConnection = ExitButton.Activated:Connect(function()
			PlayGuiDismissed = true
			PendingPlayOpen = false
		end)
		table.insert(Connections, ExitConnection)
	end

	MatchEnabled = GameState:WaitForChild("MatchEnabled") :: BooleanValue

	local LoadingAddedConnection = PlayerGui.DescendantAdded:Connect(function(child)
		if child.Name == "LoadingGui" and child:IsA("ScreenGui") then
			LoadingGui = child
			ApplyPlayGuiGate()
			GuiController:Close(PLAY_GUI_NAME)
		end
	end)
	table.insert(Connections, LoadingAddedConnection)

	local LoadingRemovedConnection = PlayerGui.DescendantRemoving:Connect(function(child)
		if LoadingGui and child == LoadingGui then
			LoadingGui = nil
			ApplyPlayGuiGate()
			if MatchEnabled and MatchEnabled.Value then
				TryOpenPlayGui()
			end
		end
	end)
	table.insert(Connections, LoadingRemovedConnection)

	local function HandleCutsceneBlockChanged(): ()
		ForceReleasePlayGuiForCutscene()
	end

	local LocalPlayerCutsceneLockConnection = LocalPlayer:GetAttributeChangedSignal(MATCH_CUTSCENE_LOCK_ATTRIBUTE)
		:Connect(HandleCutsceneBlockChanged)
	table.insert(Connections, LocalPlayerCutsceneLockConnection)

	local LocalPlayerHudHiddenConnection = LocalPlayer:GetAttributeChangedSignal(CUTSCENE_HUD_HIDDEN_ATTRIBUTE)
		:Connect(HandleCutsceneBlockChanged)
	table.insert(Connections, LocalPlayerHudHiddenConnection)

	local function BindCharacterCutsceneSignals(Character: Model): ()
		local CharacterCutsceneLockConnection = Character:GetAttributeChangedSignal(MATCH_CUTSCENE_LOCK_ATTRIBUTE)
			:Connect(HandleCutsceneBlockChanged)
		table.insert(Connections, CharacterCutsceneLockConnection)

		local CharacterHudHiddenConnection = Character:GetAttributeChangedSignal(CUTSCENE_HUD_HIDDEN_ATTRIBUTE)
			:Connect(HandleCutsceneBlockChanged)
		table.insert(Connections, CharacterHudHiddenConnection)

		HandleCutsceneBlockChanged()
	end

	if LocalPlayer.Character then
		BindCharacterCutsceneSignals(LocalPlayer.Character)
	end
	HandleCutsceneBlockChanged()

	local CharacterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(Character)
		BindCharacterCutsceneSignals(Character)
		RefreshPlayZoneAutoOpenState(Character)
		UpdatePositionSelectionAttribute()
		if PlayGuiMovementLocked then
			task.defer(function()
				Character:WaitForChild("Humanoid", 5)
				Character:WaitForChild("HumanoidRootPart", 5)
				SetPlayGuiMovementLocked(true)
			end)
			return
		end
		task.defer(function()
			Character:WaitForChild("Humanoid", 5)
			Character:WaitForChild("HumanoidRootPart", 5)
			if IsSelectionCameraReleaseBlocked() then
				return
			end
			RestoreGameplayCamera(true)
			if not IsCameraReleasedFromMiddlePosition() then
				StartGameplayCameraReleaseWatchdog(PLAY_GUI_CAMERA_RELEASE_TIMEOUT)
			end
		end)
	end)
	table.insert(Connections, CharacterAddedConnection)

	local MatchEnabledConnection = MatchEnabled.Changed:Connect(function(Value)
		ApplyPlayGuiGate()
		if Value then
			TryOpenPlayGui()
		end
	end)
	table.insert(Connections, MatchEnabledConnection)

	local Intermission = GameState:WaitForChild("IntermissionActive") :: BoolValue

	IntermissionActive = Intermission.Value

	local IntermissionConnection = Intermission.Changed:Connect(function(Value)
		IntermissionActive = Value
		ApplyPlayGuiGate()
		if MatchEnabled.Value then
			TryOpenPlayGui()
		end
	end)
	table.insert(Connections, IntermissionConnection)

	local IntermissionTime = GameState:WaitForChild("IntermissionTime") :: IntValue
	local IntermissionTimeConnection = IntermissionTime.Changed:Connect(function()
		ApplyPlayGuiGate()
		if MatchEnabled.Value then
			TryOpenPlayGui()
		end
	end)
	table.insert(Connections, IntermissionTimeConnection)

	local SessionConnection = LocalPlayer:GetAttributeChangedSignal("FTSessionId"):Connect(function()
		UpdatePickingFrame()
		ApplyPlayGuiGate()
		if MatchEnabled.Value then
			TryOpenPlayGui()
		end
	end)
	table.insert(Connections, SessionConnection)

	local MatchActiveConnection = LocalPlayer:GetAttributeChangedSignal(MatchPlayerUtils.GetMatchActiveAttributeName())
		:Connect(function()
			UpdatePickingFrame()
			ApplyPlayGuiGate()
			if MatchEnabled.Value then
				TryOpenPlayGui()
			end
		end)
	table.insert(Connections, MatchActiveConnection)

	local PositionSelectResultConnection = Packets.PositionSelectResult.OnClientEvent:Connect(
		function(Succeeded: boolean, TeamNumber: number, PositionName: string)
			if not IsSelectingPosition then
				return
			end
			if not PendingSelectionAwaitingServer then
				return
			end

			PendingSelectionAwaitingServer = false
			if not Succeeded then
				FinishPendingSelection(false)
				return
			end

			local ResolvedTeam = if TeamNumber > 0 then TeamNumber else PendingSelectionTeam
			local ResolvedPosition = if PositionName ~= "" then PositionName else PendingSelectionPosition
			if type(ResolvedTeam) ~= "number" or type(ResolvedPosition) ~= "string" or ResolvedPosition == "" then
				FinishPendingSelection(false)
				return
			end

			PendingSelectionTeam = ResolvedTeam
			PendingSelectionPosition = ResolvedPosition
			PendingSelectionAwaitingSettle = true
			SetPositionButtonsInteractable(false)
			task.spawn(WaitForSelectionSettlement, PendingSelectionRequestId, ResolvedTeam, ResolvedPosition)
		end
	)
	table.insert(Connections, PositionSelectResultConnection)

	if PickingFrameContainer then
		for TeamIndex = 1, 2 do
			local TeamFrame = PickingFrameContainer:FindFirstChild("Team" .. TeamIndex)
			if not TeamFrame then
				continue
			end

			local TeamColor = TEAM_COLORS[TeamIndex]

			for _, Position in FTConfig.PLAYER_POSITIONS do
				local Element = TeamFrame:FindFirstChild(Position.Name)
				if Element then
					ConfigureButton(Element, Position.Name, TeamIndex, TeamColor)
				end
			end
		end
	end

	local MatchFolder = GameState:FindFirstChild("Match")
	if MatchFolder then
		BindMatchFolder(MatchFolder)
		if PendingPlayOpen then
			TryOpenPlayGui()
		end
	end

	local ChildAddedConnection = GameState.ChildAdded:Connect(function(Child)
		if Child.Name == "Match" then
			BindMatchFolder(Child)
			if PendingPlayOpen then
				TryOpenPlayGui()
			end
		end
	end)
	table.insert(Connections, ChildAddedConnection)

	SetupPlayZone()
	UpdatePickingFrame()
	ApplyPlayGuiGate()
	UpdatePositionSelectionAttribute()
	SetPlayGuiMovementLocked(false)
	if not CanEnterMatch() then
		GuiController:Close(PLAY_GUI_NAME)
	end
end

return FTPlayerController
