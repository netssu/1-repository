------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

------------------//CONSTANTS
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local weatherRemote = remotesFolder:WaitForChild("GlobalWeatherEvent")

local WEATHER_ATMOSPHERE_NAME = "GlobalWeatherAtmosphere"
local LIGHTING_TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local INDICATOR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WIND_AIR_ACCELERATION = 22 -- studs/s² horizontais no ar
local WIND_MAX_HORIZONTAL_SPEED = 85

------------------//STATE
local activeAtmosphereTween: Tween? = nil
local indicatorTween: Tween? = nil
local currentWeatherState: {[string]: any} = {
	active = false,
	direction = Vector3.new(0, 0, -1),
}

------------------//UI
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local uiRoot = playerGui:WaitForChild("UI")

local function get_or_create_wind_indicator(): TextLabel
	local existing = uiRoot:FindFirstChild("WindDirectionIndicator")
	if existing and existing:IsA("TextLabel") then
		return existing
	end

	local label = Instance.new("TextLabel")
	label.Name = "WindDirectionIndicator"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.12)
	label.Size = UDim2.fromOffset(180, 40)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 25, 34)
	label.TextColor3 = Color3.fromRGB(235, 245, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = "Vento  ↑"
	label.TextTransparency = 1
	label.Visible = true
	label.Parent = uiRoot

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.45
	stroke.Color = Color3.fromRGB(160, 195, 240)
	stroke.Parent = label

	return label
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

local function direction_to_arrow(direction: Vector3): string
	if direction.Magnitude < 0.001 then
		return "↑"
	end

	local angle = math.atan2(direction.X, -direction.Z)
	local octant = math.floor(((angle / (2 * math.pi)) * 8) + 0.5) % 8
	local arrows = {"↑", "↗", "→", "↘", "↓", "↙", "←", "↖"}
	return arrows[octant + 1]
end

local function apply_wind_indicator(state: {[string]: any})
	local indicator = get_or_create_wind_indicator()
	local active = state.active == true
	local direction = state.direction

	if typeof(direction) ~= "Vector3" then
		direction = Vector3.new(0, 0, -1)
	end

	indicator.Text = string.format("Vento  %s", direction_to_arrow(direction))

	if indicatorTween then
		indicatorTween:Cancel()
		indicatorTween = nil
	end

	indicatorTween = TweenService:Create(indicator, INDICATOR_TWEEN, {
		TextTransparency = active and 0 or 1,
		BackgroundTransparency = active and 0.35 or 1,
	})
	indicatorTween:Play()
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
	apply_wind_indicator(state)
end)

RunService.RenderStepped:Connect(apply_air_wind)
