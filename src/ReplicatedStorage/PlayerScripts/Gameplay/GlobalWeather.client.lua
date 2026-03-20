------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

------------------//CONSTANTS
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local weatherRemote = remotesFolder:WaitForChild("GlobalWeatherEvent")
local NotificationUtility = require(ReplicatedStorage.Modules.Utility.NotificationUtility)

local WEATHER_ATMOSPHERE_NAME = "GlobalWeatherAtmosphere"
local LIGHTING_TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WIND_AIR_ACCELERATION = 200 -- studs/s² horizontais no ar
local WIND_MAX_HORIZONTAL_SPEED = 85
local RAIN_EFFECT_OFFSET = CFrame.new(0, 10, 0)
local RAIN_EFFECT_NAME = "GlobalWeatherRain"

------------------//STATE
local activeAtmosphereTween: Tween? = nil
local activeLightingTweens: {Tween} = {}
local currentWeatherState: {[string]: any} = {
	active = false,
	direction = Vector3.new(0, 0, -1),
}
local lastWeatherActive = false
local lightingDefaults = {
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Ambient = Lighting.Ambient,
	EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	ExposureCompensation = Lighting.ExposureCompensation,
}

------------------//UI
local localPlayer = Players.LocalPlayer

local function direction_to_side(direction: Vector3): string
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude < 0.001 then
		return "X+"
	end
	horizontal = horizontal.Unit
	if math.abs(horizontal.X) >= math.abs(horizontal.Z) then
		return horizontal.X >= 0 and "X+" or "X-"
	end
	return horizontal.Z >= 0 and "Z+" or "Z-"
end

local function show_weather_start_notice(direction: Vector3)
	local side = direction_to_side(direction)
	NotificationUtility:Show({
		type = "action",
		title = "CLIMA GLOBAL",
		message = "Começou a chover! O vento está empurrando você para o lado "
			.. side
			.. ". Confirme que entendeu para fechar este aviso.",
		buttonText = "Entendi",
		callback = function() end,
		duration = 99999,
		priority = 999,
	})
end

------------------//FUNCTIONS
local function get_or_create_atmosphere(): Atmosphere
	local atmosphere = Lighting:FindFirstChild(WEATHER_ATMOSPHERE_NAME)
	if atmosphere and atmosphere:IsA("Atmosphere") then
		return atmosphere
	end

	local newAtmosphere = Instance.new("Atmosphere")
	newAtmosphere.Name = WEATHER_ATMOSPHERE_NAME
	newAtmosphere.Density = 0.25
	newAtmosphere.Haze = 1.2
	newAtmosphere.Glare = 0
	newAtmosphere.Offset = 0
	newAtmosphere.Color = Color3.fromRGB(210, 218, 225)
	newAtmosphere.Decay = Color3.fromRGB(160, 170, 180)
	newAtmosphere.Parent = Lighting
	return newAtmosphere
end

local function apply_cloudy_state(isActive: boolean)
	local atmosphere = get_or_create_atmosphere()

	if activeAtmosphereTween then
		activeAtmosphereTween:Cancel()
		activeAtmosphereTween = nil
	end

	if isActive then
		activeAtmosphereTween = TweenService:Create(atmosphere, LIGHTING_TWEEN, {
			Density = 0.6,
			Haze = 4.3,
			Color = Color3.fromRGB(126, 137, 152),
			Decay = Color3.fromRGB(60, 66, 78),
		})
	else
		activeAtmosphereTween = TweenService:Create(atmosphere, LIGHTING_TWEEN, {
			Density = 0.25,
			Haze = 1.2,
			Color = Color3.fromRGB(210, 218, 225),
			Decay = Color3.fromRGB(160, 170, 180),
		})
	end

	activeAtmosphereTween:Play()

	for _, tween in ipairs(activeLightingTweens) do
		tween:Cancel()
	end
	table.clear(activeLightingTweens)

	if isActive then
		local rainyLightingTween = TweenService:Create(Lighting, LIGHTING_TWEEN, {
			Brightness = 1.1,
			ClockTime = 16.2,
			OutdoorAmbient = Color3.fromRGB(46, 54, 66),
			Ambient = Color3.fromRGB(40, 45, 55),
			EnvironmentDiffuseScale = 0.22,
			EnvironmentSpecularScale = 0.08,
			ExposureCompensation = -0.45,
		})
		table.insert(activeLightingTweens, rainyLightingTween)
		rainyLightingTween:Play()
	else
		local restoreLightingTween = TweenService:Create(Lighting, LIGHTING_TWEEN, {
			Brightness = lightingDefaults.Brightness,
			ClockTime = lightingDefaults.ClockTime,
			OutdoorAmbient = lightingDefaults.OutdoorAmbient,
			Ambient = lightingDefaults.Ambient,
			EnvironmentDiffuseScale = lightingDefaults.EnvironmentDiffuseScale,
			EnvironmentSpecularScale = lightingDefaults.EnvironmentSpecularScale,
			ExposureCompensation = lightingDefaults.ExposureCompensation,
		})
		table.insert(activeLightingTweens, restoreLightingTween)
		restoreLightingTween:Play()
	end
end

local function enforce_weather_lighting()
	if currentWeatherState.active ~= true then
		return
	end

	Lighting.Brightness = 1.1
	Lighting.ClockTime = 16.2
	Lighting.OutdoorAmbient = Color3.fromRGB(46, 54, 66)
	Lighting.Ambient = Color3.fromRGB(40, 45, 55)
	Lighting.EnvironmentDiffuseScale = 0.22
	Lighting.EnvironmentSpecularScale = 0.08
	Lighting.ExposureCompensation = -0.45
end

local function get_or_create_rain_effect(character: Model): BasePart?
	local existing = character:FindFirstChild(RAIN_EFFECT_NAME)
	if existing and existing:IsA("BasePart") then
		return existing
	end

	local effectsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not effectsFolder then
		return nil
	end

	local effects = effectsFolder:FindFirstChild("Effects")
	if not effects then
		return nil
	end

	local rainTemplate = effects:FindFirstChild("Rain")
	if not rainTemplate or not rainTemplate:IsA("BasePart") then
		return nil
	end

	local rainPart = rainTemplate:Clone()
	rainPart.Name = RAIN_EFFECT_NAME
	rainPart.Anchored = true
	rainPart.CanCollide = false
	rainPart.CanQuery = false
	rainPart.CanTouch = false
	rainPart.Massless = true
	local currentCamera = Workspace.CurrentCamera
	if currentCamera then
		rainPart.CFrame = currentCamera.CFrame * RAIN_EFFECT_OFFSET
	end
	rainPart.Parent = character

	return rainPart
end

local function set_rain_active(isActive: boolean)
	local character = localPlayer.Character
	if not character then
		return
	end

	local rainPart = get_or_create_rain_effect(character)
	if not rainPart then
		return
	end

	for _, descendant in ipairs(rainPart:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = isActive
		elseif descendant:IsA("Sound") then
			if isActive then
				if not descendant.IsPlaying then
					descendant:Play()
				end
			else
				descendant:Stop()
			end
		end
	end
end

local function update_rain_follow_camera()
	local character = localPlayer.Character
	if not character then
		return
	end

	local rainPart = character:FindFirstChild(RAIN_EFFECT_NAME)
	if not rainPart or not rainPart:IsA("BasePart") then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local direction = currentWeatherState.direction
	if typeof(direction) ~= "Vector3" then
		direction = Vector3.new(0, 0, -1)
	end

	local horizontalWind = Vector3.new(direction.X, 0, direction.Z)
	if horizontalWind.Magnitude < 0.001 then
		horizontalWind = Vector3.new(0, 0, -1)
	else
		horizontalWind = horizontalWind.Unit
	end

	local rainPosition = (camera.CFrame * RAIN_EFFECT_OFFSET).Position
	rainPart.CFrame = CFrame.lookAt(rainPosition, rainPosition + horizontalWind, Vector3.yAxis)
end

local function apply_air_wind(dt: number)
	if currentWeatherState.active ~= true then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart or not rootPart:IsA("BasePart") or humanoid.Health <= 0 then
		return
	end

	local state = humanoid:GetState()
	local isAirborne = state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Freefall
		or state == Enum.HumanoidStateType.FallingDown
	if not isAirborne then
		return
	end

	local direction = currentWeatherState.direction
	if typeof(direction) ~= "Vector3" then
		direction = Vector3.new(0, 0, -1)
	end

	local horizontalWind = Vector3.new(direction.X, 0, direction.Z)
	if horizontalWind.Magnitude < 0.001 then
		horizontalWind = Vector3.new(0, 0, -1)
	else
		horizontalWind = horizontalWind.Unit
	end

	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local boostedHorizontal = horizontalVelocity + (horizontalWind * WIND_AIR_ACCELERATION * dt)

	if boostedHorizontal.Magnitude > WIND_MAX_HORIZONTAL_SPEED then
		boostedHorizontal = boostedHorizontal.Unit * WIND_MAX_HORIZONTAL_SPEED
	end

	rootPart.AssemblyLinearVelocity = Vector3.new(boostedHorizontal.X, velocity.Y, boostedHorizontal.Z)
end

------------------//INIT
weatherRemote.OnClientEvent:Connect(function(state)
	if typeof(state) ~= "table" then return end
	if type(state.active) ~= "boolean" then return end

	currentWeatherState = state
	apply_cloudy_state(state.active)
	set_rain_active(state.active)
	if state.active and not lastWeatherActive then
		show_weather_start_notice(state.direction)
	end
	lastWeatherActive = state.active
end)

RunService.RenderStepped:Connect(apply_air_wind)
RunService.RenderStepped:Connect(update_rain_follow_camera)
RunService.RenderStepped:Connect(enforce_weather_lighting)

localPlayer.CharacterAdded:Connect(function()
	task.wait(0.2)
	if currentWeatherState.active == true then
		apply_cloudy_state(true)
		set_rain_active(true)
	else
		apply_cloudy_state(false)
	end
end)
