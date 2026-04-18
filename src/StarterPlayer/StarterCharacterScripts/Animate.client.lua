--// LocalScript: AnimationController.client.luau (COMPLETO + SPEEDLINES NO RUN)
--!strict

local REPLICATED_STORAGE: ReplicatedStorage = game:GetService("ReplicatedStorage")
local PLAYERS: Players = game:GetService("Players")
local RUN_SERVICE: RunService = game:GetService("RunService")
local COLLECTION_SERVICE: CollectionService = game:GetService("CollectionService")

local BALL_STATE_FOLDER_NAME: string = "FTGameState"
local BALL_CARRIER_VALUE_NAME: string = "BallCarrier"
local WALK_SPEED_PROPERTY_NAME: string = "WalkSpeed"
local VALUE_PROPERTY_NAME: string = "Value"

local TRACK_IDLE: string = "idle"
local TRACK_WALK: string = "walk"
local TRACK_RUN: string = "run"
local TRACK_WALK_BALL: string = "walkBall"
local TRACK_RUN_BALL: string = "runBall"
local TRACK_JUMP: string = "jump"
local TRACK_FALL: string = "fall"
local TRACK_SIT: string = "sit"
local TRACK_CLIMB: string = "climb"

local FADE_IN_MOVE: number = 0.12
local FADE_OUT_MOVE: number = 0.14
local FADE_IN_IDLE: number = 0.15
local FADE_OUT_IDLE: number = 0.14

local FADE_IN_AIR: number = 0.06
local FADE_OUT_JUMP_TO_FALL: number = 0.10
local FADE_IN_FALL: number = 0.10
local FADE_OUT_FALL_LAND: number = 0.28

local STOP_DEADZONE: number = 0.8
local INPUT_DEADZONE: number = 0.05
local RUN_THRESHOLD_WALKSPEED: number = 24

local HEARTBEAT_FIX_ENABLED: boolean = true
local HEARTBEAT_RATE: number = 0.10

local BALL_CARRIER_DEFER_1: number = 0.05
local BALL_CARRIER_DEFER_2: number = 0.10

local AIR_ANIM_SPEED_MULT: number = 0.25
local JUMP_MIN_TIME: number = 0.16
local AIR_SEQUENCE_MIN_TIME: number = 0.22
local LANDED_STABILITY_DELAY: number = 0.06

local HARD_BLOCK_FOREIGN_FALL_ID: string = "rbxassetid://135853112500287"
local DEFAULT_WALKSPEED_FALLBACK: number = 16

type SpeedLinesModule = {
	Play: (Humanoid, any?) -> (),
	Stop: () -> (),
}

local Assets: Folder = REPLICATED_STORAGE:WaitForChild("Assets") :: Folder
local Gameplay: Folder = Assets:WaitForChild("Gameplay") :: Folder
local Animations: Folder = Gameplay:WaitForChild("Animations") :: Folder

local Controllers: Instance? = REPLICATED_STORAGE:FindFirstChild("Controllers")
local SpeedLinesController: SpeedLinesModule? = require(Controllers:FindFirstChild("SpeedLinesController"))
local LocalPlayer: Player = PLAYERS.LocalPlayer
local AnimationClone: Animation = Instance.new("Animation")

local _Anims: {[string]: AnimationTrack} = {}
local _OwnedTracks: {[AnimationTrack]: boolean} = {}

local _BallCarrierInstance: ObjectValue? = nil

local _Character: Model? = nil
local _Humanoid: Humanoid? = nil
local _Animator: Animator? = nil

local _InAir: boolean = false
local _InClimb: boolean = false
local _InSeat: boolean = false
local _CurrentMove: string? = nil

local _AirSequenceActive: boolean = false
local _AirPhase: string? = nil
local _AirStartedAt: number = 0
local _JumpStartedAt: number = 0
local _AirStopNonce: number = 0

local _HeartbeatAccumulator: number = 0
local _CachedWalkSpeed: number = DEFAULT_WALKSPEED_FALLBACK

local _SpeedLinesActive: boolean = false
local _SpeedLinesHumanoid: Humanoid? = nil

local _RunningConn: RBXScriptConnection? = nil
local _StateConn: RBXScriptConnection? = nil
local _HumanoidChangedConn: RBXScriptConnection? = nil
local _BallCarrierConn: RBXScriptConnection? = nil
local _HeartbeatConn: RBXScriptConnection? = nil
local _AnimPlayedConn: RBXScriptConnection? = nil

local MOVEMENT_TRACKS: {[string]: boolean} = {
	[TRACK_IDLE] = true,
	[TRACK_WALK] = true,
	[TRACK_RUN] = true,
	[TRACK_WALK_BALL] = true,
	[TRACK_RUN_BALL] = true,
}

local function _StopSpeedLines()
	if not _SpeedLinesActive then
		return
	end
	if SpeedLinesController ~= nil then
		SpeedLinesController.Stop()
	end
	_SpeedLinesActive = false
	_SpeedLinesHumanoid = nil
end

local function _UpdateSpeedLinesForMove(MoveName: string)
	if SpeedLinesController == nil then
		return
	end

	local Humanoid: Humanoid? = _Humanoid
	local shouldRunFx: boolean = (MoveName == TRACK_RUN) or (MoveName == TRACK_RUN_BALL)

	if not shouldRunFx then
		_StopSpeedLines()
		return
	end

	if Humanoid == nil then
		_StopSpeedLines()
		return
	end

	if (not _SpeedLinesActive) or (_SpeedLinesHumanoid ~= Humanoid) then
		SpeedLinesController.Stop()
		SpeedLinesController.Play(Humanoid)
		_SpeedLinesActive = true
		_SpeedLinesHumanoid = Humanoid
	end
end

local function _GetReferenceWalkSpeed(): number
	local Humanoid: Humanoid? = _Humanoid
	if Humanoid == nil then
		return _CachedWalkSpeed
	end

	local ws: number = Humanoid.WalkSpeed
	if ws > 0 then
		_CachedWalkSpeed = ws
		return ws
	end

	return _CachedWalkSpeed
end

local function _IsOnGround(): boolean
	local Humanoid: Humanoid? = _Humanoid
	if Humanoid == nil then
		return true
	end

	if Humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	local state: Enum.HumanoidStateType = Humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.FallingDown then
		return false
	end

	return true
end

local function _RefreshAirFlag()
	local Humanoid: Humanoid? = _Humanoid
	if Humanoid == nil then
		_InAir = false
		return
	end
	_InAir = not _IsOnGround()
end

local function _GetRealSpeed(): number
	local Humanoid: Humanoid? = _Humanoid
	if Humanoid == nil then
		return 0
	end
	local vel: Vector3 = Humanoid:GetMoveVelocity()
	return Vector3.new(vel.X, 0, vel.Z).Magnitude
end

local function _IsMovingInput(): boolean
	local Humanoid: Humanoid? = _Humanoid
	if Humanoid == nil then
		return false
	end
	return Humanoid.MoveDirection.Magnitude > INPUT_DEADZONE
end

local function _IsRunningMode(): boolean
	return _GetReferenceWalkSpeed() >= RUN_THRESHOLD_WALKSPEED
end

local function _GetBallCarrierObject(): ObjectValue?
	if _BallCarrierInstance ~= nil and _BallCarrierInstance.Parent ~= nil then
		return _BallCarrierInstance
	end

	local StateFolder: Instance? = REPLICATED_STORAGE:FindFirstChild(BALL_STATE_FOLDER_NAME)
	if StateFolder == nil then
		return nil
	end

	local CarrierValue: Instance? = StateFolder:FindFirstChild(BALL_CARRIER_VALUE_NAME)
	if CarrierValue == nil then
		return nil
	end

	if not CarrierValue:IsA("ObjectValue") then
		return nil
	end

	_BallCarrierInstance = CarrierValue
	return CarrierValue
end

local function _IsCarryingBallFromState(Character: Model): boolean
	local CarrierObject: ObjectValue? = _GetBallCarrierObject()
	if CarrierObject == nil then
		return false
	end

	local Value: any = CarrierObject.Value
	if Value == nil or typeof(Value) ~= "Instance" then
		return false
	end

	if Value:IsA("Player") then
		return Value == LocalPlayer
	end

	if Value:IsA("Model") then
		return Value == Character
	end

	if Value:IsA("Humanoid") then
		return Value.Parent == Character
	end

	if Value:IsA("BasePart") then
		return Value:IsDescendantOf(Character)
	end

	return false
end

local function _IsCarryingBallLocalFallback(Character: Model): boolean
	if Character:GetAttribute("CarryingBall") == true then
		return true
	end

	for _, child: Instance in ipairs(Character:GetChildren()) do
		local lower: string = string.lower(child.Name)
		if string.find(lower, "ball") ~= nil then
			if child:IsA("Tool") or child:IsA("BasePart") or child:IsA("Model") then
				return true
			end
		end
	end

	for _, d: Instance in ipairs(Character:GetDescendants()) do
		if COLLECTION_SERVICE:HasTag(d, "Ball") then
			return true
		end
	end

	return false
end

local function _IsCarryingBall(): boolean
	local Character: Model? = _Character
	if Character == nil then
		return false
	end

	if _IsCarryingBallFromState(Character) then
		return true
	end

	return _IsCarryingBallLocalFallback(Character)
end

local function _GetExpectedMove(HasBall: boolean): string
	if _IsRunningMode() then
		return HasBall and TRACK_RUN_BALL or TRACK_RUN
	end
	return HasBall and TRACK_WALK_BALL or TRACK_WALK
end

local function _StopTrack(Name: string, Fade: number)
	local Track: AnimationTrack? = _Anims[Name]
	if Track == nil then
		return
	end
	if not Track.IsPlaying then
		return
	end
	Track:Stop(Fade)
end

local function _PlayTrack(Name: string, FadeIn: number, Weight: number, Speed: number)
	local Track: AnimationTrack? = _Anims[Name]
	if Track == nil then
		return
	end

	if not Track.IsPlaying then
		Track:Play(FadeIn, Weight, Speed)
	else
		Track:AdjustSpeed(Speed)
	end
end

local function _StopAllMovementInstant()
	for n: string, _ in pairs(MOVEMENT_TRACKS) do
		_StopTrack(n, 0)
	end
end

local function _SetMove(Name: string, SpeedScale: number)
	if _CurrentMove == Name then
		_PlayTrack(Name, 0, 1, SpeedScale)
		_UpdateSpeedLinesForMove(Name)
		return
	end

	for Other: string, _ in pairs(MOVEMENT_TRACKS) do
		if Other ~= Name then
			_StopTrack(Other, Other == TRACK_IDLE and FADE_OUT_IDLE or FADE_OUT_MOVE)
		end
	end

	_PlayTrack(Name, Name == TRACK_IDLE and FADE_IN_IDLE or FADE_IN_MOVE, 1, SpeedScale)
	_CurrentMove = Name
	_UpdateSpeedLinesForMove(Name)
end

local function _BindAnimatorInterceptors()
	local Animator: Animator? = _Animator
	if Animator == nil then
		return
	end

	if _AnimPlayedConn ~= nil then
		_AnimPlayedConn:Disconnect()
		_AnimPlayedConn = nil
	end

	_AnimPlayedConn = Animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		if _OwnedTracks[track] == true then
			return
		end

		local nameLower: string = string.lower(track.Name)
		local animId: string = ""

		pcall(function()
			if track.Animation then
				animId = track.Animation.AnimationId
			end
		end)

		local isAirName: boolean =
			(string.find(nameLower, "fall") ~= nil)
			or (string.find(nameLower, "jump") ~= nil)
			or (string.find(nameLower, "freefall") ~= nil)

		local isHardBlocked: boolean = (animId == HARD_BLOCK_FOREIGN_FALL_ID)

		if isAirName or isHardBlocked then
			pcall(function()
				track:Stop(0)
			end)
		end
	end)
end

local function _AddAnimation(Name: string, AnimationObject: Animation, Priority: Enum.AnimationPriority, Looped: boolean)
	local Humanoid: Humanoid? = _Humanoid
	if Humanoid == nil then
		return
	end

	local Animator: Animator? = _Animator
	if Animator == nil then
		local Created: Animator = Instance.new("Animator")
		Created.Parent = Humanoid
		_Animator = Created
		Animator = Created
	end

	local Anim: Animation = AnimationClone:Clone()
	Anim.AnimationId = AnimationObject.AnimationId

	local Track: AnimationTrack = Animator:LoadAnimation(Anim)
	Track.Name = Name
	Track.Priority = Priority
	Track.Looped = Looped

	_Anims[Name] = Track
	_OwnedTracks[Track] = true
end

local function _ShouldUseAirSequence(): boolean
	if not _IsRunningMode() then
		return true
	end
	if not _IsMovingInput() then
		return true
	end
	if _GetRealSpeed() <= STOP_DEADZONE then
		return true
	end
	return false
end

local function _StartAirSequence()
	_AirSequenceActive = true
	_AirPhase = "Jump"
	_AirStartedAt = os.clock()
	_JumpStartedAt = os.clock()
	_AirStopNonce += 1

	_CurrentMove = nil
	_StopAllMovementInstant()
	_StopTrack(TRACK_FALL, 0)
	_StopSpeedLines()

	local jumpTrack: AnimationTrack? = _Anims[TRACK_JUMP]
	if jumpTrack then
		jumpTrack.Looped = false
	end

	_PlayTrack(TRACK_JUMP, FADE_IN_AIR, 1, 1)
end

local function _TryTransitionJumpToFall()
	if not _AirSequenceActive or _AirPhase ~= "Jump" then
		return
	end

	local nonce: number = _AirStopNonce
	local elapsedJump: number = os.clock() - _JumpStartedAt
	local waitMin: number = math.max(0, JUMP_MIN_TIME - elapsedJump)

	task.delay(waitMin, function()
		if nonce ~= _AirStopNonce then
			return
		end
		if not _AirSequenceActive or _AirPhase ~= "Jump" then
			return
		end

		_AirPhase = "Fall"
		_StopTrack(TRACK_JUMP, FADE_OUT_JUMP_TO_FALL)

		local fallTrack: AnimationTrack? = _Anims[TRACK_FALL]
		if fallTrack then
			fallTrack.Looped = true
		end

		_PlayTrack(TRACK_FALL, FADE_IN_FALL, 1, 1)
	end)
end

local _UpdateMovement: (() -> ())? = nil

local function _StopAirSequenceSmoothOnLand()
	_AirStopNonce += 1
	local nonce: number = _AirStopNonce

	local elapsedTotal: number = os.clock() - _AirStartedAt
	local waitMin: number = math.max(0, AIR_SEQUENCE_MIN_TIME - elapsedTotal)

	task.delay(waitMin, function()
		if nonce ~= _AirStopNonce then
			return
		end
		if not _AirSequenceActive then
			return
		end

		task.delay(LANDED_STABILITY_DELAY, function()
			if nonce ~= _AirStopNonce then
				return
			end
			if not _AirSequenceActive then
				return
			end

			local Humanoid: Humanoid? = _Humanoid
			if Humanoid == nil then
				return
			end

			local state: Enum.HumanoidStateType = Humanoid:GetState()
			local onGround: boolean = (Humanoid.FloorMaterial ~= Enum.Material.Air)

			if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall or not onGround then
				return
			end

			_AirSequenceActive = false
			_AirPhase = nil

			_StopTrack(TRACK_JUMP, 0)
			_StopTrack(TRACK_FALL, FADE_OUT_FALL_LAND)

			_CurrentMove = nil
			if _UpdateMovement then
				task.defer(_UpdateMovement)
			end
		end)
	end)
end

local function _UpdateMovementImpl()
	if _InClimb or _InSeat then
		return
	end

	local Humanoid: Humanoid? = _Humanoid
	if Humanoid == nil then
		return
	end

	if _AirSequenceActive then
		return
	end

	_RefreshAirFlag()

	local movingInput: boolean = _IsMovingInput()
	local speed: number = _GetRealSpeed()

	if (not movingInput) or speed <= STOP_DEADZONE then
		_SetMove(TRACK_IDLE, 1)
		return
	end

	local hasBall: boolean = _IsCarryingBall()
	local refWalkSpeed: number = _GetReferenceWalkSpeed()

	local speedScale: number = 1
	if refWalkSpeed > 0 then
		speedScale = math.clamp(speed / refWalkSpeed, 0.75, 1.35)
	end

	if _InAir then
		speedScale *= AIR_ANIM_SPEED_MULT
	end

	local expected: string = _GetExpectedMove(hasBall)
	_SetMove(expected, speedScale)
end

_UpdateMovement = _UpdateMovementImpl

local function _EnterClimb()
	_InClimb = true
	_InSeat = false
	_InAir = false

	_AirSequenceActive = false
	_AirPhase = nil

	_CurrentMove = nil
	_StopAllMovementInstant()
	_StopTrack(TRACK_JUMP, 0)
	_StopTrack(TRACK_FALL, 0)
	_StopSpeedLines()
	_PlayTrack(TRACK_CLIMB, FADE_IN_MOVE, 1, 1)
end

local function _EnterSeat()
	_InSeat = true
	_InClimb = false
	_InAir = false

	_AirSequenceActive = false
	_AirPhase = nil

	_CurrentMove = nil
	_StopAllMovementInstant()
	_StopTrack(TRACK_JUMP, 0)
	_StopTrack(TRACK_FALL, 0)
	_StopSpeedLines()
	_PlayTrack(TRACK_SIT, FADE_IN_IDLE, 1, 1)
end

local function _OnStateChanged(NewState: Enum.HumanoidStateType)
	if NewState == Enum.HumanoidStateType.Climbing then
		_EnterClimb()
		return
	end

	if NewState == Enum.HumanoidStateType.Seated then
		_EnterSeat()
		return
	end

	if _InClimb and NewState ~= Enum.HumanoidStateType.Climbing then
		_InClimb = false
		_StopTrack(TRACK_CLIMB, FADE_OUT_MOVE)
	end

	if _InSeat and NewState ~= Enum.HumanoidStateType.Seated then
		_InSeat = false
		_StopTrack(TRACK_SIT, FADE_OUT_IDLE)
	end

	if NewState == Enum.HumanoidStateType.Jumping then
		_InAir = true

		if _ShouldUseAirSequence() then
			_StartAirSequence()
			return
		end

		_AirSequenceActive = false
		_AirPhase = nil
		_StopTrack(TRACK_JUMP, 0)
		_StopTrack(TRACK_FALL, 0)
		_StopSpeedLines()
		_UpdateMovementImpl()
		return
	end

	if NewState == Enum.HumanoidStateType.Freefall or NewState == Enum.HumanoidStateType.FallingDown then
		_InAir = true

		if _AirSequenceActive and _AirPhase == "Jump" then
			_TryTransitionJumpToFall()
			return
		end

		_UpdateMovementImpl()
		return
	end

	if NewState == Enum.HumanoidStateType.Landed then
		_InAir = false

		if _AirSequenceActive then
			_StopAirSequenceSmoothOnLand()
			return
		end

		_CurrentMove = nil
		_UpdateMovementImpl()
		return
	end

	_RefreshAirFlag()
end

local function _OnRunning()
	_UpdateMovementImpl()
end

local function _OnHumanoidChanged(PropertyName: string)
	if PropertyName ~= WALK_SPEED_PROPERTY_NAME then
		return
	end

	local Humanoid: Humanoid? = _Humanoid
	if Humanoid ~= nil then
		local ws: number = Humanoid.WalkSpeed
		if ws > 0 then
			_CachedWalkSpeed = ws
		end
	end

	_UpdateMovementImpl()
end

local function _OnBallCarrierChanged(PropertyName: string)
	if PropertyName ~= VALUE_PROPERTY_NAME then
		return
	end

	_CurrentMove = nil
	_UpdateMovementImpl()

	task.defer(_UpdateMovementImpl)
	task.delay(BALL_CARRIER_DEFER_1, _UpdateMovementImpl)
	task.delay(BALL_CARRIER_DEFER_2, _UpdateMovementImpl)
end

local function _OnHeartbeat(dt: number)
	if not HEARTBEAT_FIX_ENABLED then
		return
	end

	_HeartbeatAccumulator += dt
	if _HeartbeatAccumulator < HEARTBEAT_RATE then
		return
	end
	_HeartbeatAccumulator = 0

	_UpdateMovementImpl()
end

local function _DisconnectConnections()
	if _RunningConn then _RunningConn:Disconnect(); _RunningConn = nil end
	if _StateConn then _StateConn:Disconnect(); _StateConn = nil end
	if _HumanoidChangedConn then _HumanoidChangedConn:Disconnect(); _HumanoidChangedConn = nil end
	if _BallCarrierConn then _BallCarrierConn:Disconnect(); _BallCarrierConn = nil end
	if _HeartbeatConn then _HeartbeatConn:Disconnect(); _HeartbeatConn = nil end
	if _AnimPlayedConn then _AnimPlayedConn:Disconnect(); _AnimPlayedConn = nil end
end

local function _ClearOwnedTracks()
	for n: string, tr: AnimationTrack in pairs(_Anims) do
		pcall(function() tr:Stop(0) end)
		pcall(function() tr:Destroy() end)
		_Anims[n] = nil
	end
	table.clear(_OwnedTracks)
end

local function SetupCharacter(Character: Model)
	_Character = Character
	_Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	_Animator = _Humanoid:FindFirstChildOfClass("Animator")

	_CachedWalkSpeed = math.max((_Humanoid :: Humanoid).WalkSpeed, DEFAULT_WALKSPEED_FALLBACK)

	local AnimateScript: Instance? = Character:FindFirstChild("Animate")
	if AnimateScript ~= nil and AnimateScript ~= script then
		if AnimateScript:IsA("LocalScript") or AnimateScript:IsA("Script") then
			AnimateScript.Disabled = true
		end
	end

	_DisconnectConnections()
	_ClearOwnedTracks()
	_StopSpeedLines()

	_InAir = false
	_InClimb = false
	_InSeat = false
	_CurrentMove = nil

	_AirSequenceActive = false
	_AirPhase = nil
	_AirStartedAt = 0
	_JumpStartedAt = 0
	_AirStopNonce = 0

	_HeartbeatAccumulator = 0

	_AddAnimation(TRACK_IDLE, Animations:WaitForChild("Idle") :: Animation, Enum.AnimationPriority.Idle, true)
	_AddAnimation(TRACK_WALK, Animations:WaitForChild("Walk") :: Animation, Enum.AnimationPriority.Movement, true)
	_AddAnimation(TRACK_RUN, Animations:WaitForChild("Run") :: Animation, Enum.AnimationPriority.Movement, true)
	_AddAnimation(TRACK_WALK_BALL, Animations:WaitForChild("WalkBall") :: Animation, Enum.AnimationPriority.Movement, true)
	_AddAnimation(TRACK_RUN_BALL, Animations:WaitForChild("RunBall") :: Animation, Enum.AnimationPriority.Movement, true)

	_AddAnimation(TRACK_JUMP, Animations:WaitForChild("Jump") :: Animation, Enum.AnimationPriority.Action, false)
	_AddAnimation(TRACK_FALL, Animations:WaitForChild("Fall") :: Animation, Enum.AnimationPriority.Action, true)

	_AddAnimation(TRACK_SIT, Animations:WaitForChild("Sit") :: Animation, Enum.AnimationPriority.Idle, true)
	_AddAnimation(TRACK_CLIMB, Animations:WaitForChild("Climb") :: Animation, Enum.AnimationPriority.Movement, true)

	_BindAnimatorInterceptors()

	local Humanoid: Humanoid = _Humanoid :: Humanoid

	_RunningConn = Humanoid.Running:Connect(function()
		_OnRunning()
	end)

	_StateConn = Humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
		_OnStateChanged(newState)
	end)

	_HumanoidChangedConn = Humanoid.Changed:Connect(function(prop: string)
		_OnHumanoidChanged(prop)
	end)

	local carrier: ObjectValue? = _GetBallCarrierObject()
	if carrier then
		_BallCarrierConn = carrier.Changed:Connect(function(prop: string)
			_OnBallCarrierChanged(prop)
		end)
	end

	_HeartbeatConn = RUN_SERVICE.Heartbeat:Connect(function(dt: number)
		_OnHeartbeat(dt)
	end)

	task.defer(_UpdateMovementImpl)
end

local ExistingCharacter: Model? = LocalPlayer.Character
if ExistingCharacter ~= nil then
	SetupCharacter(ExistingCharacter)
end

LocalPlayer.CharacterAdded:Connect(function(Character: Model)
	SetupCharacter(Character)
end)
