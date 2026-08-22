------------------//SERVICES
local GuiService: GuiService = game:GetService("GuiService")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local ENTRY_DURATION: number = 0.9
local MOUSE_SMOOTHING: number = 12
local MOUSE_OFFSET: number = 0.22
local MOUSE_PITCH: number = math.rad(1.1)
local MOUSE_YAW: number = math.rad(1.5)

------------------//VARIABLES
local currentCamera: Camera?
local previousCameraType
local previousCameraCFrame: CFrame?
local previousCameraFocus: CFrame?
local previousFieldOfView: number?
local previousCameraSubject: Instance?
local previousMinZoomDistance: number?
local previousMaxZoomDistance: number?
local localPlayer: Player? = nil
local targetCFrame: CFrame?
local isActive: boolean = false
local isTweening: boolean = false
local activeMode: string?
local entryCount: number = 0
local sessionToken: number = 0
local activeTween: Tween?
local renderConnection: RBXScriptConnection?
local smoothedMouse: Vector2 = Vector2.zero

------------------//FUNCTIONS
local function get_camera(): Camera?
	local camera = workspace.CurrentCamera
	if camera then
		currentCamera = camera
	end
	return currentCamera
end

local function get_focus_cframe(cameraCFrame: CFrame): CFrame
	return CFrame.new(cameraCFrame.Position + cameraCFrame.LookVector * 100)
end

local function get_mouse_offset(): (number, number)
	local camera = get_camera()
	if not camera then
		return 0, 0
	end

	local viewportSize = camera.ViewportSize
	if viewportSize.X <= 0 or viewportSize.Y <= 0 then
		return 0, 0
	end

	local inset = GuiService:GetGuiInset()
	local mouseLocation = UserInputService:GetMouseLocation()
	local normalizedX = (mouseLocation.X - inset.X) / viewportSize.X - 0.5
	local normalizedY = (mouseLocation.Y - inset.Y) / viewportSize.Y - 0.5
	return math.clamp(normalizedX * 2, -1, 1), math.clamp(normalizedY * 2, -1, 1)
end

local function apply_debug_attributes(): ()
	local camera = get_camera()
	if not camera then
		return
	end

	camera:SetAttribute("RemakeGarageSession", isActive)
	camera:SetAttribute("RemakeGarageMode", activeMode or "")
	camera:SetAttribute("RemakeGarageEntryCount", entryCount)
	camera:SetAttribute("RemakeGarageMouseSway", isActive and not isTweening)
end

local function apply_sway(deltaTime: number): ()
	local camera = get_camera()
	local baseCFrame = targetCFrame
	if not camera or not baseCFrame or not isActive or isTweening then
		return
	end

	local targetX, targetY = get_mouse_offset()
	local alpha = math.clamp(MOUSE_SMOOTHING * deltaTime, 0, 1)
	smoothedMouse = smoothedMouse:Lerp(Vector2.new(targetX, targetY), alpha)

	local offset = CFrame.new(smoothedMouse.X * MOUSE_OFFSET, -smoothedMouse.Y * MOUSE_OFFSET, 0)
	local rotation = CFrame.Angles(-smoothedMouse.Y * MOUSE_PITCH, -smoothedMouse.X * MOUSE_YAW, 0)
	camera.CFrame = baseCFrame * offset * rotation
	camera.Focus = get_focus_cframe(baseCFrame)
end

local function disconnect_render(): ()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

local function connect_render(): ()
	if renderConnection then
		return
	end

	renderConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		apply_sway(deltaTime)
	end)
end

local function stop_tween(): ()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	isTweening = false
	apply_debug_attributes()
end

local function play_entry(target: CFrame, token: number): ()
	local camera = get_camera()
	if not camera then
		return
	end

	stop_tween()
	disconnect_render()
	isTweening = true
	apply_debug_attributes()

	local tweenInfo = TweenInfo.new(ENTRY_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tween = TweenService:Create(camera, tweenInfo, {
		CFrame = target,
		Focus = get_focus_cframe(target),
	})
	activeTween = tween
	tween.Completed:Connect(function()
		if token ~= sessionToken or not isActive then
			return
		end

		activeTween = nil
		isTweening = false
		targetCFrame = target
		smoothedMouse = Vector2.zero
		connect_render()
		apply_debug_attributes()
	end)
	tween:Play()
end

local function capture_camera_state(camera: Camera, player: Player?): ()
	previousCameraType = camera.CameraType
	previousCameraCFrame = camera.CFrame
	previousCameraFocus = camera.Focus
	previousFieldOfView = camera.FieldOfView
	previousCameraSubject = camera.CameraSubject
	if player then
		previousMinZoomDistance = player.CameraMinZoomDistance
		previousMaxZoomDistance = player.CameraMaxZoomDistance
	end
end

local function restore_camera_state(): ()
	local camera = get_camera()
	if not camera or not previousCameraCFrame then
		return
	end

	camera.CFrame = previousCameraCFrame
	if previousCameraFocus then
		camera.Focus = previousCameraFocus
	end
	if previousFieldOfView then
		camera.FieldOfView = previousFieldOfView
	end
	if previousCameraSubject then
		camera.CameraSubject = previousCameraSubject
	end
	if previousCameraType then
		camera.CameraType = previousCameraType
	end
	if localPlayer and previousMinZoomDistance and previousMaxZoomDistance then
		localPlayer.CameraMinZoomDistance = previousMinZoomDistance
		localPlayer.CameraMaxZoomDistance = previousMaxZoomDistance
	end
end

------------------//MAIN FUNCTIONS
local function camera_controller_open(mode: string, target: CFrame, player: Player?): boolean
	local camera = get_camera()
	if not camera then
		return false
	end

	if isActive then
		if isTweening then
			sessionToken += 1
			stop_tween()
			connect_render()
		end
		activeMode = mode
		targetCFrame = target
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = target
		camera.Focus = get_focus_cframe(target)
		apply_debug_attributes()
		return true
	end

	localPlayer = player
	capture_camera_state(camera, player)
	sessionToken += 1
	isActive = true
	isTweening = true
	activeMode = mode
	targetCFrame = target
	entryCount += 1
	camera.CameraType = Enum.CameraType.Scriptable
	if player then
		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
	end
	apply_debug_attributes()
	play_entry(target, sessionToken)
	return true
end

local function camera_controller_set_mode(mode: string, target: CFrame): boolean
	local camera = get_camera()
	if not camera or not isActive then
		return false
	end

	if isTweening then
		sessionToken += 1
		stop_tween()
		connect_render()
	end

	activeMode = mode
	targetCFrame = target
	camera.CameraType = Enum.CameraType.Scriptable
	if not isTweening then
		camera.CFrame = target
		camera.Focus = get_focus_cframe(target)
	end
	apply_debug_attributes()
	return true
end

local function camera_controller_close(): ()
	if not isActive then
		return
	end

	sessionToken += 1
	isActive = false
	activeMode = nil
	targetCFrame = nil
	disconnect_render()
	stop_tween()
	restore_camera_state()
	previousCameraType = nil
	previousCameraCFrame = nil
	previousCameraFocus = nil
	previousFieldOfView = nil
	previousCameraSubject = nil
	previousMinZoomDistance = nil
	previousMaxZoomDistance = nil
	apply_debug_attributes()
end

local function camera_controller_is_active(): boolean
	return isActive
end

------------------//INIT
return {
	open = camera_controller_open,
	set_mode = camera_controller_set_mode,
	close = camera_controller_close,
	is_active = camera_controller_is_active,
}
