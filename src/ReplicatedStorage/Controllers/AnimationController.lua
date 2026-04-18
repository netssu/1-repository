--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationController = {}
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)
local VisualFx = require(ReplicatedStorage.Modules.Game.VisualFx)

--\\ TYPES \\ -- TR
type AnimationData = {
	Name: string,
	Track: AnimationTrack?,
	IsPlaying: boolean,
	LastPlayTime: number,
	Cooldown: number,
	DefaultPriority: Enum.AnimationPriority,
	LoopingAnimations: {string}
}

type ActionState = {
	InProgress: boolean,
	LastActionTime: number,
	Cooldown: number,
}

type ModelAnimationData = {
	Track: AnimationTrack?,
	IsPlaying: boolean,
}

--\\ CONSTANTS \\ -- TR
local ANIMATION_NAMES: {string} = {
	"Catch","Juke","Linebacker","QB","Walk","Run","WalkBall","Walkback","WalkL","WalkR","WalkFront","IdleBall",
	"Request Ball","SpinJuke","SpinJuke M","Stand Up","Tackle","Throw","Kick",
	"Idle","Jump","Fall","Climb","Sit",
}

local DEFAULT_COOLDOWN = 0.5
local REQUEST_BALL_KEY = Enum.KeyCode.E
local REQUEST_BALL_EFFECT_NAME = "Pass"
local REQUEST_BALL_EFFECT_IMAGE = "rbxassetid://88969906712523"
local STAND_UP_ANIMATION_NAME: string = "Stand Up"
local STAND_UP_ANIMATION_FADE_TIME: number = 0.05
local STAND_UP_RETRY_COUNT: number = 4
local STAND_UP_RETRY_DELAY: number = 0.06
local STAND_UP_DEBOUNCE_TIME: number = 0.2
local STAND_UP_GROUND_RAY_HEIGHT: number = 24
local STAND_UP_GROUND_RAY_DISTANCE: number = 80
local STAND_UP_GROUND_CLEARANCE: number = 0.8
local STAND_UP_GROUND_OFFSET_MIN: number = 0.25
local STAND_UP_GROUND_SNAP_EPSILON: number = 0.05
local STAND_UP_GROUND_MAX_RAYCAST_SKIPS: number = 8
local STAND_UP_MAX_SNAP_DISTANCE: number = 32
local REQUEST_BALL_EFFECT_LIFETIME: number = 2
local REQUEST_BALL_EFFECT_OUT_DELAY: number = 1.5
local REQUEST_BALL_EFFECT_TWEEN_IN_INFO: TweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
local REQUEST_BALL_EFFECT_TWEEN_OUT_INFO: TweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
local REQUEST_BALL_EFFECT_EXPANDED_SIZE: UDim2 = UDim2.fromScale(10, 1)
local REQUEST_BALL_EFFECT_COLLAPSED_SIZE: UDim2 = UDim2.new(0, 0, 0, 0)
local MOVEMENT_ANIMS = { Walk = true, Run = true, WalkBall = true, Walkback = true, WalkL = true, WalkR = true, WalkFront = true, IdleBall = true, Idle = true, Jump = true, Fall = true, Climb = true, Sit = true }

local STATE_FADE_TIME = 0.15
local WALK_BASE_SPEED = 16
local RUN_BASE_SPEED = 24
local RUN_STATE_SPEED_THRESHOLD = 18
local MOVE_DIRECTION_THRESHOLD = 0.05
local PLANAR_MOVE_SPEED_THRESHOLD = 1.75
local WALK_STATES = { walk = true, walkball = true, walkback = true, walkl = true, walkr = true, front = true }
local WALKBACK_ENTER_FACING_DOT = -0.2
local WALKBACK_EXIT_FACING_DOT = -0.05
local WALKBACK_CAMERA_ALIGN_DOT = 0.2
local WALKBACK_CAMERA_BACK_DOT = -0.1
local CHARGE_SIDE_ENTER_DOT = 0.55
local CHARGE_SIDE_EXIT_DOT = 0.35
local CHARGE_FRONT_FACING_DOT = 0.05
local GAMEPAD_DIRECTION_THRESHOLD = 0.35
local CHARGING_THROW_ATTRIBUTE = "FTChargingThrow"
local PREWARM_BATCH_SIZE = 4

local STATE_ANIMS = {
	idle = "Idle",
	walk = "Walk",
	run = "Run",
	walkball = "WalkBall",
	walkback = "Walkback",
	walkl = "WalkL",
	walkr = "WalkR",
	front = "WalkFront",
	idleball = "IdleBall",
	jump = "Jump",
	fall = "Fall",
	climb = "Climb",
	sit = "Sit",
}

local DEFAULT_PRIORITIES = {
	["Walk"] = Enum.AnimationPriority.Movement,
	["Run"] = Enum.AnimationPriority.Movement,
	["WalkBall"] = Enum.AnimationPriority.Movement,
	["Walkback"] = Enum.AnimationPriority.Movement,
	["WalkL"] = Enum.AnimationPriority.Movement,
	["WalkR"] = Enum.AnimationPriority.Movement,
	["WalkFront"] = Enum.AnimationPriority.Movement,
	["IdleBall"] = Enum.AnimationPriority.Idle,
	["Idle"] = Enum.AnimationPriority.Idle,
	["Jump"] = Enum.AnimationPriority.Movement,
	["Fall"] = Enum.AnimationPriority.Movement,
	["Climb"] = Enum.AnimationPriority.Movement,
	["Sit"] = Enum.AnimationPriority.Idle,

	["Request Ball"] = Enum.AnimationPriority.Action,
	["Stand Up"] = Enum.AnimationPriority.Action4,
	["Catch"] = Enum.AnimationPriority.Action,
	["Throw"] = Enum.AnimationPriority.Action,
	["Kick"] = Enum.AnimationPriority.Action,

	["Tackle"] = Enum.AnimationPriority.Action,
	["Juke"] = Enum.AnimationPriority.Action,
	["SpinJuke"] = Enum.AnimationPriority.Action,
	["SpinJuke M"] = Enum.AnimationPriority.Action,

	["Linebacker"] = Enum.AnimationPriority.Action,
	["QB"] = Enum.AnimationPriority.Action,
}

local LOOPING_ANIMATIONS = {
	["Walk"] = true,
	["Run"] = true,
	["WalkBall"] = true,
	["Walkback"] = true,
	["WalkL"] = true,
	["WalkR"] = true,
	["WalkFront"] = true,
	["IdleBall"] = true,
	["Idle"] = true,
	["Climb"] = true,
	["Sit"] = true,
}

local ANIMATION_PREWARM_ORDER: {string} = {
	"Idle",
	"Walk",
	"Run",
	"WalkBall",
	"Walkback",
	"WalkL",
	"WalkR",
	"WalkFront",
	"IdleBall",
	"Jump",
	"Fall",
	"Climb",
	"Sit",
	"Request Ball",
	"Catch",
	"Throw",
	"Kick",
	"Tackle",
	"Juke",
	"SpinJuke",
	"SpinJuke M",
	"Linebacker",
	"QB",
	"Stand Up",
}

--\\ MODULE STATE \\ -- TR
local LocalPlayer = Players.LocalPlayer
local LoadedAnimations: {[string]: AnimationData} = {}
local ActionStates: {[string]: ActionState} = {}
local CurrentAnimator: Animator? = nil
local ModelAnimations: {[Model]: {[string]: ModelAnimationData}} = {}

local BallCarrierValue: ObjectValue? = nil
local StateTracks: {[string]: AnimationTrack?} = {}
local CurrentState = "idle"
local ActiveHumanoid: Humanoid? = nil
local StateUpdateConn: RBXScriptConnection? = nil
local MissingAnimationWarned: {[string]: boolean} = {}
local LastStandUpAt: number = -math.huge
local CachedAnimationFolder: Folder? = nil
local CachedAnimationByNormalizedName: {[string]: Animation} = {}
local TrackPrewarmToken: number = 0
local GetAnimationsFolder: () -> Folder?

local function NormalizeAnimationName(name: string): string
	return string.lower((string.gsub(name, "[%s_%-%./]", "")))
end

local function FindAnimationAsset(animationsFolder: Folder, animationName: string): Animation?
	local direct = animationsFolder:FindFirstChild(animationName, true)
	if direct and direct:IsA("Animation") then
		return direct
	end

	if CachedAnimationFolder ~= animationsFolder then
		CachedAnimationFolder = animationsFolder
		CachedAnimationByNormalizedName = {}
		for _, descendant in ipairs(animationsFolder:GetDescendants()) do
			if descendant:IsA("Animation") then
				local normalizedName = NormalizeAnimationName(descendant.Name)
				if CachedAnimationByNormalizedName[normalizedName] == nil then
					CachedAnimationByNormalizedName[normalizedName] = descendant
				end
			end
		end
	end

	local normalizedTarget = NormalizeAnimationName(animationName)
	return CachedAnimationByNormalizedName[normalizedTarget]
end

local function GetAnimationAssetFromSource(AnimationSource: string | Animation): Animation?
	if typeof(AnimationSource) == "Instance" then
		if AnimationSource:IsA("Animation") then
			return AnimationSource
		end

		return nil
	end

	local AnimationsFolder = GetAnimationsFolder()
	if not AnimationsFolder then
		return nil
	end

	return FindAnimationAsset(AnimationsFolder, AnimationSource)
end

local function GetAnimationCacheKey(AnimationSource: string | Animation): string
	if typeof(AnimationSource) == "Instance" and AnimationSource:IsA("Animation") then
		local AnimationId: string = AnimationSource.AnimationId
		if AnimationId ~= "" then
			return "Id:" .. AnimationId
		end

		return "Obj:" .. AnimationSource:GetFullName()
	end

	return "Name:" .. NormalizeAnimationName(AnimationSource)
end

local function ResolveAnimationPriority(AnimationSource: string | Animation): Enum.AnimationPriority
	if typeof(AnimationSource) == "Instance" then
		return Enum.AnimationPriority.Action
	end

	return DEFAULT_PRIORITIES[AnimationSource] or Enum.AnimationPriority.Action
end

local function ResolveAnimationLooped(AnimationSource: string | Animation): boolean
	if typeof(AnimationSource) == "Instance" then
		return false
	end

	return LOOPING_ANIMATIONS[AnimationSource] or false
end

local function ResolveMovementFadeTime(AnimationSource: string | Animation, fadeTime: number?): number?
	if fadeTime ~= nil then
		return fadeTime
	end
	if typeof(AnimationSource) == "string" and MOVEMENT_ANIMS[AnimationSource] then
		return STATE_FADE_TIME
	end
	return nil
end

local function ResolveStopFadeTime(AnimationSource: string | Animation, fadeTime: number?): number
	local ResolvedFadeTime = ResolveMovementFadeTime(AnimationSource, fadeTime)
	if ResolvedFadeTime ~= nil then
		return ResolvedFadeTime
	end
	return 0
end

--\\ PRIVATE FUNCTIONS \\ -- TR
GetAnimationsFolder = function(): Folder?
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets then return nil end
	local Gameplay = Assets:FindFirstChild("Gameplay")
	if not Gameplay then return nil end
	return Gameplay:FindFirstChild("Animations") :: Folder?
end

local function GetAnimator(): Animator?
	if CurrentAnimator then return CurrentAnimator end
	local Character = LocalPlayer.Character
	if not Character then return nil end
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then return nil end
	CurrentAnimator = Humanoid:FindFirstChildOfClass("Animator")
	if not CurrentAnimator then
		CurrentAnimator = Instance.new("Animator")
		CurrentAnimator.Parent = Humanoid
	end
	return CurrentAnimator
end

local function LoadAnimation(AnimationName: string, SuppressMissingWarning: boolean?): AnimationTrack?
	local Animator = GetAnimator()
	if not Animator then return nil end
	local Animation = GetAnimationAssetFromSource(AnimationName)
	if not Animation then
		if not SuppressMissingWarning and not MissingAnimationWarned[AnimationName] then
			MissingAnimationWarned[AnimationName] = true
			warn(("[AnimationController] Animation '%s' not found in ReplicatedStorage.Assets.Gameplay.Animations"):format(AnimationName))
		end
		return nil
	end
	return Animator:LoadAnimation(Animation)
end

local function GetAnimatorForModel(model: Model): Animator?
	local Humanoid = model:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		local DescendantHumanoid = model:FindFirstChildWhichIsA("Humanoid", true)
		if DescendantHumanoid and DescendantHumanoid:IsA("Humanoid") then
			Humanoid = DescendantHumanoid
		end
	end
	if not Humanoid then return nil end
	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		Animator = Instance.new("Animator")
		Animator.Parent = Humanoid
	end
	return Animator
end

local function LoadAnimationForModel(model: Model, AnimationSource: string | Animation): AnimationTrack?
	local Animator = GetAnimatorForModel(model)
	if not Animator then return nil end
	local Animation = GetAnimationAssetFromSource(AnimationSource)
	if not Animation then
		if typeof(AnimationSource) == "Instance" then
			return nil
		end
		if not MissingAnimationWarned[AnimationSource] then
			MissingAnimationWarned[AnimationSource] = true
			warn(("[AnimationController] Animation '%s' not found in ReplicatedStorage.Assets.Gameplay.Animations"):format(AnimationSource))
		end
		return nil
	end
	return Animator:LoadAnimation(Animation)
end

local function GetModelTrack(model: Model, AnimationSource: string | Animation): AnimationTrack?
	local cache: {[string]: ModelAnimationData}? = ModelAnimations[model]
	if not cache then
		cache = {}
		ModelAnimations[model] = cache
	end
	local CacheKey: string = GetAnimationCacheKey(AnimationSource)
	local data = cache[CacheKey]
	if data and data.Track then
		return data.Track
	end
	local track = LoadAnimationForModel(model, AnimationSource)
	if track then
		cache[CacheKey] = { Track = track, IsPlaying = false }
	end
	return track
end

local function InitializeAnimations(): ()
	for _, AnimationName in ANIMATION_NAMES do
		local isMovement = MOVEMENT_ANIMS[AnimationName] == true
		local defaultPriority = DEFAULT_PRIORITIES[AnimationName] or Enum.AnimationPriority.Action

		LoadedAnimations[AnimationName] = {
			Name = AnimationName,
			Track = nil,
			IsPlaying = false,
			LastPlayTime = 0,
			Cooldown = isMovement and 0 or DEFAULT_COOLDOWN,
			DefaultPriority = defaultPriority,
			LoopingAnimations = LOOPING_ANIMATIONS[AnimationName] or false
		}

		ActionStates[AnimationName] = {
			InProgress = false,
			LastActionTime = 0,
			Cooldown = isMovement and 0 or DEFAULT_COOLDOWN,
		}
	end
end

local function IsLocalPlayerInMatch(): boolean
	return MatchPlayerUtils.IsPlayerActive(Players.LocalPlayer)
end

local function IsMatchActive(): boolean
	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if not GameStateFolder then return false end
	local MatchStarted = GameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
	return MatchStarted and MatchStarted.Value or false
end

local function GetBallCarrier(): Player?
	if not BallCarrierValue then
		local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
		if GameStateFolder then
			BallCarrierValue = GameStateFolder:FindFirstChild("BallCarrier") :: ObjectValue?
		end
	end
	return if BallCarrierValue and BallCarrierValue.Value then BallCarrierValue.Value :: Player else nil
end

local function IsCarryingBall(): boolean
	return GetBallCarrier() == LocalPlayer
end

local function IsRunningActive(humanoid: Humanoid): boolean
	if humanoid.WalkSpeed < RUN_STATE_SPEED_THRESHOLD then
		return false
	end
	if LocalPlayer:GetAttribute("FTRunning") == true then
		return true
	end
	local character = LocalPlayer.Character
	if character and character:GetAttribute("FTRunning") == true then
		return true
	end
	return humanoid.WalkSpeed >= (RUN_BASE_SPEED - 0.5)
end

local function IsChargingThrowActive(): boolean
	if LocalPlayer:GetAttribute(CHARGING_THROW_ATTRIBUTE) == true then
		return true
	end
	local character = LocalPlayer.Character
	return character ~= nil and character:GetAttribute(CHARGING_THROW_ATTRIBUTE) == true
end

local function IsBackwardInputActive(): boolean
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		return true
	end
	local gamepadState = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, inputObject in ipairs(gamepadState) do
		if inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then
			local thumb = inputObject.Position
			if thumb.Y > GAMEPAD_DIRECTION_THRESHOLD and math.abs(thumb.Y) >= math.abs(thumb.X) then
				return true
			end
		end
	end
	return false
end

local function GetLateralInputDirection(): number
	local direction = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		direction -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		direction += 1
	end
	if direction ~= 0 then
		return direction
	end

	local gamepadState = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, inputObject in ipairs(gamepadState) do
		if inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then
			local thumb = inputObject.Position
			if math.abs(thumb.X) > GAMEPAD_DIRECTION_THRESHOLD and math.abs(thumb.X) >= math.abs(thumb.Y) then
				return if thumb.X < 0 then -1 else 1
			end
		end
	end

	return 0
end

local function IsForwardInputActive(): boolean
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		return true
	end

	local gamepadState = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, inputObject in ipairs(gamepadState) do
		if inputObject.KeyCode == Enum.KeyCode.Thumbstick1 then
			local thumb = inputObject.Position
			if thumb.Y < -GAMEPAD_DIRECTION_THRESHOLD and math.abs(thumb.Y) >= math.abs(thumb.X) then
				return true
			end
		end
	end

	return false
end

local function ResolveChargedCarryState(humanoid: Humanoid): string
	local backwardInput = IsBackwardInputActive()
	local lateralInputDirection = GetLateralInputDirection()
	local forwardInput = IsForwardInputActive()
	local character = humanoid.Parent
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local moveDirection = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
	local holdingWalkback = CurrentState == "walkback"
	local holdingWalkLeft = CurrentState == "walkl"
	local holdingWalkRight = CurrentState == "walkr"

	if moveDirection.Magnitude > 1e-4 then
		moveDirection = moveDirection.Unit
	end

	if root and moveDirection.Magnitude > 1e-4 then
		local lookVector = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		local rightVector = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
		if lookVector.Magnitude > 1e-4 and rightVector.Magnitude > 1e-4 then
			lookVector = lookVector.Unit
			rightVector = rightVector.Unit

			local facingDot = moveDirection:Dot(lookVector)
			local facingThreshold = if holdingWalkback then WALKBACK_EXIT_FACING_DOT else WALKBACK_ENTER_FACING_DOT
			local movingBackByTorso = facingDot <= facingThreshold
			local cameraAllowsWalkback = true
			local camera = workspace.CurrentCamera
			if camera then
				local cameraLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
				if cameraLook.Magnitude > 1e-4 then
					local cameraLookUnit = cameraLook.Unit
					local cameraAlignDot = lookVector:Dot(cameraLookUnit)
					local moveCameraDot = moveDirection:Dot(cameraLookUnit)
					local cameraBackThreshold = if holdingWalkback then 0 else WALKBACK_CAMERA_BACK_DOT
					cameraAllowsWalkback = cameraAlignDot >= WALKBACK_CAMERA_ALIGN_DOT and moveCameraDot <= cameraBackThreshold
				end
			end

			if movingBackByTorso and cameraAllowsWalkback then
				return "walkback"
			end

			local lateralDot = moveDirection:Dot(rightVector)
			local lateralThreshold = if holdingWalkLeft or holdingWalkRight then CHARGE_SIDE_EXIT_DOT else CHARGE_SIDE_ENTER_DOT
			if math.abs(lateralDot) >= lateralThreshold and math.abs(lateralDot) > math.abs(facingDot) then
				return if lateralDot < 0 then "walkl" else "walkr"
			end

			if facingDot >= CHARGE_FRONT_FACING_DOT then
				return "front"
			end
		end
	end

	if backwardInput then
		return "walkback"
	end
	if lateralInputDirection < 0 then
		return "walkl"
	end
	if lateralInputDirection > 0 then
		return "walkr"
	end
	if forwardInput then
		return "front"
	end

	return "walkball"
end

local function CanPerformAction(ActionName: string): boolean
	if MOVEMENT_ANIMS[ActionName] then
		return true
	end
	local State = ActionStates[ActionName]
	if not State then return false end
	if State.InProgress then return false end
	local CurrentTime = os.clock()
	if CurrentTime - State.LastActionTime < State.Cooldown then return false end
	return true
end

local function SetActionInProgress(ActionName: string, InProgress: boolean): ()
	local State = ActionStates[ActionName]
	if not State then return end
	State.InProgress = InProgress
	if not InProgress then
		State.LastActionTime = os.clock()
	end
end

local function PrimeAnimationTrack(AnimationName: string): ()
	local Data = LoadedAnimations[AnimationName]
	if not Data or Data.Track then
		return
	end

	local Track = LoadAnimation(AnimationName, true)
	if not Track then
		return
	end

	Track.Looped = Data.LoopingAnimations
	Track.Priority = Data.DefaultPriority
	Data.Track = Track
	Data.IsPlaying = false
end

local function PrewarmCharacterAnimationTracks(Character: Model): ()
	TrackPrewarmToken += 1
	local Token = TrackPrewarmToken

	task.spawn(function()
		task.wait()

		for Index, AnimationName in ANIMATION_PREWARM_ORDER do
			if TrackPrewarmToken ~= Token or LocalPlayer.Character ~= Character or Character.Parent == nil then
				return
			end

			PrimeAnimationTrack(AnimationName)

			if Index % PREWARM_BATCH_SIZE == 0 then
				RunService.Heartbeat:Wait()
			end
		end
	end)
end

local function HasBlockingActionAnimation(): boolean
	for animName, data in LoadedAnimations do
		if MOVEMENT_ANIMS[animName] then
			continue
		end
		if data.Track and data.Track.IsPlaying then
			return true
		end
	end
	return false
end

local function StopAllStateTracks(fadeTime: number?, exceptStateName: string?)
	for stateName, track in StateTracks do
		if exceptStateName and stateName == exceptStateName then
			continue
		end
		if track and track.IsPlaying then
			track:Stop(fadeTime or STATE_FADE_TIME)
		end
		local animName = STATE_ANIMS[stateName]
		local data = if animName then LoadedAnimations[animName] else nil
		if data then
			data.IsPlaying = false
		end
	end
end

local function ApplyStateSpeed(stateName: string)
	local humanoid = ActiveHumanoid
	if not humanoid then return end
	local track = StateTracks[stateName]
	if not track or not track.IsPlaying then return end
	if WALK_STATES[stateName] then
		track:AdjustSpeed(math.max(0.05, humanoid.WalkSpeed / WALK_BASE_SPEED))
	elseif stateName == "run" then
		track:AdjustSpeed(math.max(0.05, humanoid.WalkSpeed / RUN_BASE_SPEED))
	else
		track:AdjustSpeed(1)
	end
end

local function GetStateTrack(stateName: string): AnimationTrack?
	return StateTracks[stateName]
end

local function GetPlanarSpeed(root: BasePart?): number
	if not root then
		return 0
	end

	return Vector2.new(root.AssemblyLinearVelocity.X, root.AssemblyLinearVelocity.Z).Magnitude
end

local function SwitchTo(stateName: string, fadeTime: number?)
	if stateName == "" or not STATE_ANIMS[stateName] then
		return
	end
	if stateName == CurrentState then
		local ExistingTrack = GetStateTrack(stateName)
		if ExistingTrack and ExistingTrack.IsPlaying then
			ApplyStateSpeed(stateName)
			return
		end
	end

	local animName = STATE_ANIMS[stateName]
	local Data = LoadedAnimations[animName]
	if not Data then
		Data = { 
			Name = animName, 
			Track = nil, 
			IsPlaying = false, 
			LastPlayTime = 0, 
			Cooldown = 0,
			DefaultPriority = DEFAULT_PRIORITIES[animName] or Enum.AnimationPriority.Movement,
			LoopingAnimations = LOOPING_ANIMATIONS[animName] or false
		}
		LoadedAnimations[animName] = Data
	end
	if not Data.Track then
		Data.Track = LoadAnimation(animName)
	end
	local track = Data.Track
	if not track then
		return
	end

	track.Looped = Data.LoopingAnimations
	track.Priority = Data.DefaultPriority
	StateTracks[stateName] = track

	StopAllStateTracks(fadeTime, stateName)
	if not track.IsPlaying then
		track:Play(fadeTime or STATE_FADE_TIME)
	end
	Data.IsPlaying = track.IsPlaying
	CurrentState = stateName
	ApplyStateSpeed(stateName)
end

local function IsHumanoidMoving(humanoid: Humanoid): boolean
	if humanoid.MoveDirection.Magnitude > MOVE_DIRECTION_THRESHOLD then
		return true
	end

	local character = humanoid.Parent
	if not character or not character:IsA("Model") then
		return false
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return GetPlanarSpeed(root) >= PLANAR_MOVE_SPEED_THRESHOLD
	end

	return false
end

local function ResolveDesiredState(humanoid: Humanoid): string
	if humanoid.PlatformStand then
		return "idle"
	end
	local humanoidState = humanoid:GetState()
	if humanoidState == Enum.HumanoidStateType.Seated then
		return "sit"
	end
	if humanoidState == Enum.HumanoidStateType.Climbing then
		return "climb"
	end
	if humanoidState == Enum.HumanoidStateType.Jumping then
		return "jump"
	end
	if humanoidState == Enum.HumanoidStateType.Freefall or humanoidState == Enum.HumanoidStateType.FallingDown then
		return "fall"
	end

	local chargingThrow = IsChargingThrowActive()
	local runningActive = IsRunningActive(humanoid)
	local carryingBall = IsCarryingBall()
	local moving = IsHumanoidMoving(humanoid)

	if not moving then
		if carryingBall and chargingThrow then
			return "idleball"
		end

		return "idle"
	end

	if carryingBall then
		if chargingThrow then
			return ResolveChargedCarryState(humanoid)
		end

		local nextState = if runningActive then "run" else "walkball"
		return nextState
	end

	if chargingThrow then
		return "walk"
	end

	if runningActive then
		return "run"
	end
	return "walk"
end

local function UpdateStateMachine(): ()
	local humanoid = ActiveHumanoid
	if not humanoid then
		local character = LocalPlayer.Character
		if character then
			humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				ActiveHumanoid = humanoid
			end
		end
	end
	if not humanoid then
		StopAllStateTracks(STATE_FADE_TIME)
		CurrentState = "idle"
		return
	end
	if HasBlockingActionAnimation() then
		ApplyStateSpeed(CurrentState)
		return
	end
	local nextState = ResolveDesiredState(humanoid)
	SwitchTo(nextState, STATE_FADE_TIME)
end

local function SafeUpdateStateMachine(): ()
	local ok, err = pcall(UpdateStateMachine)
	if not ok then
		warn("[AnimationController] UpdateStateMachine error: " .. tostring(err))
	end
end

local function RefreshStateMachineBurst(): ()
	SafeUpdateStateMachine()
	for Attempt = 1, 4 do
		task.delay(0.05 * Attempt, function()
			SafeUpdateStateMachine()
		end)
	end
end

local function OnCharacterAdded(Character: Model): ()
	local animateScript = Character:FindFirstChild("Animate")
	if animateScript and animateScript:IsA("LocalScript") and animateScript.Enabled then
		animateScript.Enabled = false
	end
	CurrentAnimator = nil
	ActiveHumanoid = Character:FindFirstChildOfClass("Humanoid")
	if not ActiveHumanoid then
		local waited = Character:WaitForChild("Humanoid", 5)
		if waited and waited:IsA("Humanoid") then
			ActiveHumanoid = waited
		end
	end

	for _, Data in LoadedAnimations do
		Data.Track = nil
		Data.IsPlaying = false
	end
	for _, State in ActionStates do
		State.InProgress = false
	end

	StopAllStateTracks(0)
	CurrentState = "idle"

	if StateUpdateConn then
		StateUpdateConn:Disconnect()
		StateUpdateConn = nil
	end
	StateUpdateConn = RunService.RenderStepped:Connect(SafeUpdateStateMachine)
	PrewarmCharacterAnimationTracks(Character)
	task.defer(RefreshStateMachineBurst)
end

local function ResolveRequestBallAdornee(Character: Model?): BasePart?
	if not Character then
		return nil
	end

	local PrimaryPart = Character.PrimaryPart
	if PrimaryPart and PrimaryPart:IsA("BasePart") then
		return PrimaryPart
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and HumanoidRootPart:IsA("BasePart") then
		return HumanoidRootPart
	end

	return Character:FindFirstChildWhichIsA("BasePart")
end

local function PlayRequestBallEffect(): ()
	local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local Character = LocalPlayer.Character
	local Adornee = ResolveRequestBallAdornee(Character)
	if not PlayerGui or not Character or not Adornee then
		return
	end

	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	local EffectsFolder = Assets and Assets:FindFirstChild("Effects")
	local EffectTemplate = EffectsFolder and EffectsFolder:FindFirstChild(REQUEST_BALL_EFFECT_NAME)
	if not EffectTemplate then
		return
	end

	local EffectClone = EffectTemplate:Clone()
	EffectClone.Parent = PlayerGui
	VisualFx.SetBillboardAdornee(EffectClone, Adornee)
	VisualFx.SetBillboardsEnabled(EffectClone, true)

	if EffectClone:IsA("BillboardGui") then
		EffectClone.Adornee = Adornee
		EffectClone.Enabled = true
	end

	local Bar = EffectClone:FindFirstChild("Bar", true)
	if Bar and Bar:IsA("GuiObject") then
		Bar.Size = REQUEST_BALL_EFFECT_COLLAPSED_SIZE
		if Bar:IsA("ImageLabel") or Bar:IsA("ImageButton") then
			Bar.Image = REQUEST_BALL_EFFECT_IMAGE
		end

		TweenService:Create(Bar, REQUEST_BALL_EFFECT_TWEEN_IN_INFO, {
			Size = REQUEST_BALL_EFFECT_EXPANDED_SIZE,
		}):Play()

		task.delay(REQUEST_BALL_EFFECT_OUT_DELAY, function(): ()
			if Bar.Parent == nil then
				return
			end

			TweenService:Create(Bar, REQUEST_BALL_EFFECT_TWEEN_OUT_INFO, {
				Size = REQUEST_BALL_EFFECT_COLLAPSED_SIZE,
			}):Play()
		end)
	end

	task.delay(REQUEST_BALL_EFFECT_LIFETIME, function(): ()
		if EffectClone.Parent then
			EffectClone:Destroy()
		end
	end)
end

local function GetStandUpGroundY(character: Model, position: Vector3): number?
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.IgnoreWater = true

	local ExcludedInstances: {Instance} = { character }
	local Origin = position + Vector3.new(0, STAND_UP_GROUND_RAY_HEIGHT, 0)
	local Direction = Vector3.new(0, -STAND_UP_GROUND_RAY_DISTANCE, 0)

	for _ = 1, STAND_UP_GROUND_MAX_RAYCAST_SKIPS do
		Params.FilterDescendantsInstances = ExcludedInstances
		local Result = Workspace:Raycast(Origin, Direction, Params)
		if not Result then
			return nil
		end

		local Hit = Result.Instance
		if Hit:IsA("Terrain") then
			return Result.Position.Y
		end
		if Hit:IsA("BasePart") and Hit.CanCollide then
			return Result.Position.Y
		end

		table.insert(ExcludedInstances, Hit)
	end

	return nil
end

local function ResolveStandUpRootGroundOffset(root: BasePart, humanoid: Humanoid, groundY: number?): number
	local BaseOffset = (root.Size.Y * 0.5) + math.max(humanoid.HipHeight, 0)
	if groundY ~= nil then
		local MeasuredOffset = root.Position.Y - groundY
		if MeasuredOffset > STAND_UP_GROUND_OFFSET_MIN then
			return math.max(MeasuredOffset, BaseOffset)
		end
	end

	return BaseOffset
end

local function LiftCharacterAboveGroundIfNeeded(character: Model, root: BasePart, humanoid: Humanoid): ()
	local GroundY = GetStandUpGroundY(character, root.Position)
	if GroundY == nil then
		return
	end

	local TargetRootY = GroundY + ResolveStandUpRootGroundOffset(root, humanoid, GroundY) + STAND_UP_GROUND_CLEARANCE
	local LiftAmount = TargetRootY - root.Position.Y
	if LiftAmount <= STAND_UP_GROUND_SNAP_EPSILON then
		return
	end
	if LiftAmount > STAND_UP_MAX_SNAP_DISTANCE then
		return
	end

	character:PivotTo(character:GetPivot() + Vector3.new(0, LiftAmount, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function PrepareCharacterForStandUp(character: Model, humanoid: Humanoid): ()
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid:Move(Vector3.zero, false)
	LiftCharacterAboveGroundIfNeeded(character, root, humanoid)
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end)
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Landed)
	end)
end

local function HandleRequestBall(): ()
	if not IsLocalPlayerInMatch() then return end
	if not IsMatchActive() then return end
	if IsCarryingBall() then return end
	if not CanPerformAction("Request Ball") then return end
	AnimationController.PlayAnimation("Request Ball")
	PlayRequestBallEffect()
end

local function SetupInputHandling(): ()
	UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
		if GameProcessed then return end
		if Input.KeyCode == REQUEST_BALL_KEY then
			HandleRequestBall()
		end
	end)
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function AnimationController.Init(): ()
	InitializeAnimations()
end

function AnimationController.Start(): ()
	LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
	if LocalPlayer.Character then
		OnCharacterAdded(LocalPlayer.Character)
	end
	if not StateUpdateConn then
		StateUpdateConn = RunService.RenderStepped:Connect(SafeUpdateStateMachine)
	end
	SetupInputHandling()
end

function AnimationController.SwitchTo(stateName: string, fadeTime: number?): ()
	SwitchTo(stateName, fadeTime)
end

function AnimationController.PlayAnimation(AnimationName: string, Options: {Looped: boolean?, Priority: Enum.AnimationPriority?, FadeTime: number?}?): AnimationTrack?
	local Data = LoadedAnimations[AnimationName]
	if not Data then return nil end
	local isMovement = MOVEMENT_ANIMS[AnimationName] == true
	if not isMovement and not CanPerformAction(AnimationName) then return nil end
	if not Data.Track then
		Data.Track = LoadAnimation(AnimationName)
	end
	if not Data.Track then return nil end

	if not isMovement then
		SetActionInProgress(AnimationName, true)
	end

	local ActualOptions = Options or {}
	Data.Track.Looped = ActualOptions.Looped or Data.LoopingAnimations
	Data.Track.Priority = ActualOptions.Priority or Data.DefaultPriority
	if Data.Track.IsPlaying then
		Data.IsPlaying = true
		return Data.Track
	end
	local fadeTime = ResolveMovementFadeTime(AnimationName, ActualOptions.FadeTime)
	if fadeTime then
		Data.Track:Play(fadeTime)
	else
		Data.Track:Play()
	end
	Data.IsPlaying = true
	Data.LastPlayTime = os.clock()

	Data.Track.Stopped:Once(function()
		Data.IsPlaying = false
		if not isMovement then
			SetActionInProgress(AnimationName, false)
		end
	end)

	return Data.Track
end

function AnimationController.StopAnimation(AnimationName: string, fadeTime: number?): ()
	local Data = LoadedAnimations[AnimationName]
	if not Data then return end
	if Data.Track and Data.IsPlaying then
		Data.Track:Stop(ResolveStopFadeTime(AnimationName, fadeTime))
		Data.IsPlaying = false
		SetActionInProgress(AnimationName, false)
	end
end

function AnimationController.StopAllAnimations(fadeTime: number?): ()
	StopAllStateTracks(ResolveStopFadeTime(CurrentState, fadeTime))
	for _, Data in LoadedAnimations do
		if Data.Track and Data.IsPlaying then
			Data.Track:Stop(ResolveStopFadeTime(Data.Name, fadeTime))
			Data.IsPlaying = false
			SetActionInProgress(Data.Name, false)
		end
	end
end

function AnimationController.PlayStandUpAnimation(): AnimationTrack?
	local Character = LocalPlayer.Character
	if not Character then
		return nil
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return nil
	end

	PrepareCharacterForStandUp(Character, Humanoid)

	local Now = os.clock()
	if Now - LastStandUpAt < STAND_UP_DEBOUNCE_TIME then
		local ExistingData = LoadedAnimations[STAND_UP_ANIMATION_NAME]
		return if ExistingData then ExistingData.Track else nil
	end
	LastStandUpAt = Now

	local Track: AnimationTrack? = nil
	for Attempt = 1, STAND_UP_RETRY_COUNT do
		AnimationController.StopAllAnimations()
		Track = AnimationController.PlayAnimation(STAND_UP_ANIMATION_NAME, {
			Priority = Enum.AnimationPriority.Action4,
			FadeTime = STAND_UP_ANIMATION_FADE_TIME,
		})
		if Track then
			Track.Stopped:Once(function()
				RefreshStateMachineBurst()
			end)
			return Track
		end
		if Attempt < STAND_UP_RETRY_COUNT then
			task.wait(STAND_UP_RETRY_DELAY)
		end
	end

	return nil
end

function AnimationController.IsAnimationPlaying(AnimationName: string): boolean
	local Data = LoadedAnimations[AnimationName]
	if not Data then return false end
	return Data.IsPlaying
end

function AnimationController.CanPerformAction(ActionName: string): boolean
	return CanPerformAction(ActionName)
end

function AnimationController.SetActionCooldown(ActionName: string, Cooldown: number): ()
	local State = ActionStates[ActionName]
	if State then
		State.Cooldown = Cooldown
	end
	local Data = LoadedAnimations[ActionName]
	if Data then
		Data.Cooldown = Cooldown
	end
end

function AnimationController.GetAnimationTrack(AnimationName: string): AnimationTrack?
	local Data = LoadedAnimations[AnimationName]
	if not Data then return nil end
	if not Data.Track then
		Data.Track = LoadAnimation(AnimationName)
	end
	return Data.Track
end

function AnimationController.SetAnimationPriority(AnimationName: string, Priority: Enum.AnimationPriority): ()
	local Data = LoadedAnimations[AnimationName]
	if not Data then return end
	Data.DefaultPriority = Priority
	if Data.Track then
		Data.Track.Priority = Priority
	end
end

function AnimationController.SetAnimationLooped(AnimationName: string, Looped: boolean): ()
	local Data = LoadedAnimations[AnimationName]
	if not Data then return end
	Data.LoopingAnimations = Looped
	if Data.Track then
		Data.Track.Looped = Looped
	end
end

function AnimationController.GetAnimationPriority(AnimationName: string): Enum.AnimationPriority?
	local Data = LoadedAnimations[AnimationName]
	if not Data then return nil end
	return Data.DefaultPriority
end

function AnimationController.GetCurrentState(): string
	return CurrentState
end

function AnimationController.PlayAnimationForModel(model: Model, AnimationSource: string | Animation, Options: {Looped: boolean?, Priority: Enum.AnimationPriority?, FadeTime: number?}?): AnimationTrack?
	if not model then return nil end
	local track = GetModelTrack(model, AnimationSource)
	if not track then return nil end

	local CacheKey: string = GetAnimationCacheKey(AnimationSource)
	local cache = ModelAnimations[model]
	if cache and cache[CacheKey] then
		cache[CacheKey].IsPlaying = true
	end

	local ActualOptions = Options or {}
	track.Looped = if ActualOptions.Looped ~= nil then ActualOptions.Looped else ResolveAnimationLooped(AnimationSource)
	track.Priority = ActualOptions.Priority or ResolveAnimationPriority(AnimationSource)
	if track.IsPlaying then
		return track
	end
	local fadeTime = ResolveMovementFadeTime(AnimationSource, ActualOptions.FadeTime)
	if fadeTime then
		track:Play(fadeTime)
	else
		track:Play()
	end

	track.Stopped:Once(function()
		if cache and cache[CacheKey] then
			cache[CacheKey].IsPlaying = false
		end
	end)

	return track
end

function AnimationController.StopAnimationForModel(model: Model, AnimationSource: string | Animation, fadeTime: number?): ()
	local cache = ModelAnimations[model]
	if not cache then return end
	local CacheKey: string = GetAnimationCacheKey(AnimationSource)
	local data = cache[CacheKey]
	if not data or not data.Track then return end
	if data.Track.IsPlaying then
		data.Track:Stop(ResolveStopFadeTime(AnimationSource, fadeTime))
		data.IsPlaying = false
	end
end

function AnimationController.IsAnimationPlayingForModel(model: Model, AnimationSource: string | Animation): boolean
	local cache = ModelAnimations[model]
	if not cache then return false end
	local CacheKey: string = GetAnimationCacheKey(AnimationSource)
	local data = cache[CacheKey]
	return data ~= nil and data.IsPlaying == true
end

function AnimationController.CleanupModelAnimations(model: Model): ()
	if not model then return end
	local cache = ModelAnimations[model]
	if not cache then return end

	for _, data in cache do
		if data.Track then
			data.Track:Stop(0)
			data.Track:Destroy()
		end
	end

	ModelAnimations[model] = nil
end

return AnimationController
