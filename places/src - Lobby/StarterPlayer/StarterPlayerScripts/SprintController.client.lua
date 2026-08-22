------------------//SERVICES
local Players: Players = game:GetService("Players")
local UserInputService: UserInputService = game:GetService("UserInputService")
local RunService: RunService = game:GetService("RunService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local SPRINT_ANIMATION_ID: string = "rbxassetid://79709494725639"
local DEFAULT_WALK_SPEED: number = 16
local SPRINT_SPEED_MULTIPLIER: number = 2
local DEFAULT_FOV: number = 70
local MIN_MOVEMENT_MAGNITUDE: number = 0.1
local ANIMATION_FADE_TIME: number = 0.15
local SPRINT_ANIMATION_SPEED: number = 1.1

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local cameraFovController = require(modules:WaitForChild("Interface"):WaitForChild("CameraFovController"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local sprintHeld: boolean = false
local humanoid: Humanoid?
local runTrack: AnimationTrack?
local baseWalkSpeed: number = DEFAULT_WALK_SPEED
local defaultFOV: number = DEFAULT_FOV
local isSprinting: boolean = false
local sprintAnimation: Animation = Instance.new("Animation")

sprintAnimation.AnimationId = SPRINT_ANIMATION_ID

------------------//FUNCTIONS
local function get_camera(): Camera?
	return workspace.CurrentCamera
end

local function stop_run_animation(): ()
	if runTrack and runTrack.IsPlaying then
		runTrack:Stop(ANIMATION_FADE_TIME)
	end
end

local function start_run_animation(): ()
	if not runTrack or runTrack.IsPlaying then
		return
	end

	runTrack:Play(ANIMATION_FADE_TIME, 1, SPRINT_ANIMATION_SPEED)
end

local function set_sprinting(status: boolean): ()
	if isSprinting == status then
		return
	end

	isSprinting = status

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if status then
		humanoid.WalkSpeed = baseWalkSpeed * SPRINT_SPEED_MULTIPLIER
		cameraFovController.set_sprint_active(true, defaultFOV)
		start_run_animation()
	else
		humanoid.WalkSpeed = baseWalkSpeed
		cameraFovController.set_sprint_active(false, defaultFOV)
		stop_run_animation()
	end
end

local function is_moving_on_ground(): boolean
	if not humanoid or humanoid.Health <= 0 or humanoid.Sit then
		return false
	end

	return humanoid.MoveDirection.Magnitude > MIN_MOVEMENT_MAGNITUDE
		and humanoid.FloorMaterial ~= Enum.Material.Air
end

local function clear_character(): ()
	stop_run_animation()
	if runTrack then
		runTrack:Destroy()
		runTrack = nil
	end

	if humanoid then
		humanoid.WalkSpeed = baseWalkSpeed
	end

	cameraFovController.set_sprint_active(false, defaultFOV)
	humanoid = nil
	isSprinting = false
	sprintHeld = false
end

local function bind_character(character: Model): ()
	clear_character()

	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	baseWalkSpeed = humanoid.WalkSpeed
	isSprinting = false

	local camera = get_camera()
	if camera then
		defaultFOV = camera.FieldOfView
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local success, track = pcall(function(): AnimationTrack
		return animator:LoadAnimation(sprintAnimation)
	end)
	if not success then
		return
	end

	runTrack = track
	runTrack.Priority = Enum.AnimationPriority.Action
	runTrack.Looped = true
end

local function is_sprint_key(keyCode: Enum.KeyCode): boolean
	return keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift
end

local function handle_input(input: InputObject, gameProcessed: boolean): ()
	if gameProcessed or UserInputService:GetFocusedTextBox() then
		return
	end

	if is_sprint_key(input.KeyCode) then
		sprintHeld = true
	end
end

local function handle_input_ended(input: InputObject): ()
	if is_sprint_key(input.KeyCode) then
		sprintHeld = false
	end
end

local function update_sprint(): ()
	if not humanoid then
		return
	end

	set_sprinting(sprintHeld and is_moving_on_ground())
end

------------------//MAIN FUNCTIONS
------------------//INIT
localPlayer.CharacterAdded:Connect(bind_character)
localPlayer.CharacterRemoving:Connect(clear_character)
UserInputService.InputBegan:Connect(handle_input)
UserInputService.InputEnded:Connect(handle_input_ended)
RunService.RenderStepped:Connect(update_sprint)

if localPlayer.Character then
	task.spawn(bind_character, localPlayer.Character)
end
