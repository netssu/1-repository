------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

------------------//CONSTANTS
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local weatherRemote = remotesFolder:WaitForChild("GlobalWeatherEvent")

local CLOUDS_NAME = "GlobalWeatherClouds"
local WEATHER_ATMOSPHERE_NAME = "GlobalWeatherAtmosphere"
local LIGHTING_TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LOCAL_WIND_PART_NAME = "LocalWindParticles"

------------------//STATE
local activeAtmosphereTween: Tween? = nil
local localWindPart: Part? = nil
local localWindEmitter: ParticleEmitter? = nil
local activeWindDirection = Vector3.new(1, 0, 0)

------------------//FUNCTIONS
local function get_clouds(): Clouds?
	local clouds = Lighting:FindFirstChild(CLOUDS_NAME)
	if clouds and clouds:IsA("Clouds") then
		return clouds
	end
	return nil
end

local function ensure_clouds(): Clouds
	local clouds = get_clouds()
	if clouds then
		return clouds
	end

	local newClouds = Instance.new("Clouds")
	newClouds.Name = CLOUDS_NAME
	newClouds.Color = Color3.fromRGB(220, 226, 230)
	newClouds.Parent = Lighting
	return newClouds
end

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

local function get_or_create_local_wind_emitter(): ParticleEmitter
	if localWindEmitter and localWindEmitter.Parent then
		return localWindEmitter
	end

	local windPart = workspace:FindFirstChild(LOCAL_WIND_PART_NAME)
	if not windPart then
		windPart = Instance.new("Part")
		windPart.Name = LOCAL_WIND_PART_NAME
		windPart.Anchored = true
		windPart.CanCollide = false
		windPart.CanQuery = false
		windPart.CanTouch = false
		windPart.Transparency = 1
		windPart.Size = Vector3.new(5, 5, 5)
		windPart.Parent = workspace
	end
	localWindPart = windPart

	local attachment = windPart:FindFirstChild("WindAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "WindAttachment"
		attachment.Parent = windPart
	end

	local emitter = attachment:FindFirstChild("WindEmitter")
	if not (emitter and emitter:IsA("ParticleEmitter")) then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "WindEmitter"
		emitter.Texture = "rbxassetid://7712212240"
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(1.3, 2)
		emitter.Speed = NumberRange.new(25, 36)
		emitter.SpreadAngle = Vector2.new(12, 12)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-120, 120)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.7, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent = attachment
	end

	localWindEmitter = emitter
	return emitter
end

local function apply_cloudy_state(isActive: boolean, windDirection: Vector3?)
	local atmosphere = get_or_create_atmosphere()
	local emitter = get_or_create_local_wind_emitter()

	if activeAtmosphereTween then
		activeAtmosphereTween:Cancel()
		activeAtmosphereTween = nil
	end

	if isActive then
		if windDirection and windDirection.Magnitude > 0 then
			local flatDirection = Vector3.new(windDirection.X, 0, windDirection.Z)
			if flatDirection.Magnitude > 0.001 then
				activeWindDirection = flatDirection.Unit
			end
		end
		local clouds = ensure_clouds()
		clouds.Cover = 1
		clouds.Density = 1
		emitter.Rate = 140
		emitter.Acceleration = activeWindDirection * 32

		activeAtmosphereTween = TweenService:Create(atmosphere, LIGHTING_TWEEN, {
			Density = 0.44,
			Haze = 2.8,
			Color = Color3.fromRGB(190, 198, 205),
			Decay = Color3.fromRGB(120, 130, 145),
		})
	else
		local clouds = get_clouds()
		if clouds then
			clouds:Destroy()
		end
		emitter.Rate = 0
		emitter.Acceleration = Vector3.zero

		activeAtmosphereTween = TweenService:Create(atmosphere, LIGHTING_TWEEN, {
			Density = 0.25,
			Haze = 1.2,
			Color = Color3.fromRGB(210, 218, 225),
			Decay = Color3.fromRGB(160, 170, 180),
		})
	end

	activeAtmosphereTween:Play()
end

------------------//INIT
weatherRemote.OnClientEvent:Connect(function(state)
	if typeof(state) ~= "table" then return end
	if type(state.active) ~= "boolean" then return end

	local direction = state.direction
	if typeof(direction) ~= "Vector3" then
		direction = nil
	end

	apply_cloudy_state(state.active, direction)
end)

RunService.RenderStepped:Connect(function()
	if not localWindPart then return end

	local camera = workspace.CurrentCamera
	if camera then
		localWindPart.CFrame = camera.CFrame * CFrame.new(0, 0, -8)
		return
	end

	local player = Players.LocalPlayer
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		localWindPart.CFrame = hrp.CFrame
	end
end)
