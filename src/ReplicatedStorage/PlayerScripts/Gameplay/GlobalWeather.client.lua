------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local weatherRemote = remotesFolder:WaitForChild("GlobalWeatherEvent")

local WEATHER_ATMOSPHERE_NAME = "GlobalWeatherAtmosphere"
local LIGHTING_TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

------------------//STATE
local activeAtmosphereTween: Tween? = nil

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
			Density = 0.44,
			Haze = 2.8,
			Color = Color3.fromRGB(190, 198, 205),
			Decay = Color3.fromRGB(120, 130, 145),
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
end

------------------//INIT
weatherRemote.OnClientEvent:Connect(function(state)
	if typeof(state) ~= "table" then return end
	if type(state.active) ~= "boolean" then return end

	apply_cloudy_state(state.active)
end)
