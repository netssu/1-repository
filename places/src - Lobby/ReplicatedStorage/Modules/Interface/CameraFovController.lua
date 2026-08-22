------------------//SERVICES
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local DEFAULT_FOV: number = 70
local MAX_SPRINT_FOV: number = 90
local SPRINT_FOV_INCREMENT: number = 8
local FOV_TWEEN_DURATION: number = 0.25

------------------//VARIABLES
local baseFOV: number = DEFAULT_FOV
local uiFOV: number?
local sprintActive: boolean = false
local fovTween: Tween?

------------------//FUNCTIONS
local function get_camera(): Camera?
	return workspace.CurrentCamera
end

local function get_target_fov(): number
	if uiFOV then
		return uiFOV
	end

	if sprintActive then
		return math.min(baseFOV + SPRINT_FOV_INCREMENT, MAX_SPRINT_FOV)
	end

	return baseFOV
end

local function apply_fov(duration: number): ()
	local camera = get_camera()
	if not camera then
		return
	end

	if fovTween then
		fovTween:Cancel()
	end

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	fovTween = TweenService:Create(camera, tweenInfo, { FieldOfView = get_target_fov() })
	fovTween:Play()
end

------------------//MAIN FUNCTIONS
local cameraFovController = {}

function cameraFovController.set_ui_fov(fov: number?, duration: number): ()
	uiFOV = fov
	apply_fov(duration)
end

function cameraFovController.set_sprint_active(isActive: boolean, fov: number?): ()
	if fov then
		baseFOV = fov
	end
	sprintActive = isActive
	apply_fov(FOV_TWEEN_DURATION)
end

------------------//INIT
return cameraFovController
