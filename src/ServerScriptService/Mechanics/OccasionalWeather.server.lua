------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MultiplierUtility = require(ReplicatedStorage.Modules.Utility.MultiplierUtility)
local WeatherControl = require(script.Parent:WaitForChild("WeatherControl"))

------------------//CONSTANTS
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local weatherRemote = remotesFolder:FindFirstChild("GlobalWeatherEvent")
if not weatherRemote then
	weatherRemote = Instance.new("RemoteEvent")
	weatherRemote.Name = "GlobalWeatherEvent"
	weatherRemote.Parent = remotesFolder
end

local HOUR_SECONDS = 60 * 60
local EVENT_DURATION_SECONDS = 5 * 60 -- primeiros 5 minutos de cada hora cheia

local WEATHER_MULTIPLIER_ACTIVE = 2
local WEATHER_MULTIPLIER_IDLE = 1

local WIND_PUSH_FORCE = 60
local PUSH_INTERVAL = 0.2

local CLOUDS_NAME = "GlobalWeatherClouds"

------------------//STATE
local activeState = {
	active = false,
	direction = Vector3.new(1, 0, 0),
	hourSlot = -1,
	startedAt = 0,
	endsAt = 0,
}

local pushAccumulator = 0

------------------//FUNCTIONS (Random determinístico)
local function hash_int(value: number): number
	local x = math.floor(value)
	x = bit32.band(bit32.bxor(x, bit32.lshift(x, 13)), 0x7fffffff)
	x = bit32.band(bit32.bxor(x, bit32.rshift(x, 17)), 0x7fffffff)
	x = bit32.band(bit32.bxor(x, bit32.lshift(x, 5)), 0x7fffffff)
	return x
end

local function get_hour_state(hourSlot: number, now: number)
	local angleSeed = hash_int(hourSlot * 3571 + 19)
	local angle = (angleSeed % 360) * math.pi / 180
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	if direction.Magnitude < 0.001 then
		direction = Vector3.new(1, 0, 0)
	else
		direction = direction.Unit
	end

	local startedAt = hourSlot * HOUR_SECONDS
	local endsAt = startedAt + EVENT_DURATION_SECONDS
	local isActive = now >= startedAt and now < endsAt

	return {
		active = isActive,
		direction = direction,
		hourSlot = hourSlot,
		startedAt = startedAt,
		endsAt = endsAt,
	}
end

------------------//FUNCTIONS (Visual)
local function get_clouds(): Clouds?
	local clouds = workspace.Terrain:FindFirstChild(CLOUDS_NAME)
	if clouds and clouds:IsA("Clouds") then
		return clouds
	end

	local fallbackClouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if fallbackClouds then
		return fallbackClouds
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
	newClouds.Parent = workspace.Terrain
	return newClouds
end

local function apply_weather_visuals(state)
	if state.active then
		local clouds = ensure_clouds()
		clouds.Cover = 1
		clouds.Density = 1
	else
		local clouds = ensure_clouds()
		clouds.Cover = 0
		clouds.Density = 0
	end
end

------------------//FUNCTIONS (Multiplicador do evento)
local function set_weather_multiplier_for_player(player: Player, isActive: boolean)
	local target = isActive and WEATHER_MULTIPLIER_ACTIVE or WEATHER_MULTIPLIER_IDLE
	MultiplierUtility.set_factor(player, "WeatherEvent", target)
end

local function apply_weather_multiplier_to_all_players(isActive: boolean)
	for _, player in ipairs(Players:GetPlayers()) do
		set_weather_multiplier_for_player(player, isActive)
	end
end

------------------//FUNCTIONS (Gameplay)
local function push_players(dt: number)
	if not activeState.active then return end

	pushAccumulator += dt
	if pushAccumulator < PUSH_INTERVAL then
		return
	end
	pushAccumulator = 0

	local deltaVelocity = activeState.direction * WIND_PUSH_FORCE

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if hrp and hrp:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				hrp.AssemblyLinearVelocity += deltaVelocity
			end
		end
	end
end

local function broadcast_state(targetPlayer: Player?)
	if targetPlayer then
		weatherRemote:FireClient(targetPlayer, activeState)
	else
		weatherRemote:FireAllClients(activeState)
	end
end

local function sync_weather_state(forceBroadcast: boolean?)
	local now = os.time()
	local hourSlot = math.floor(now / HOUR_SECONDS)
	local nextState = get_hour_state(hourSlot, now)
	if WeatherControl.is_forced_active(now) then
		nextState.active = true
	end

	local changed = nextState.hourSlot ~= activeState.hourSlot or nextState.active ~= activeState.active

	if changed or forceBroadcast then
		activeState = nextState
		apply_weather_visuals(activeState)
		apply_weather_multiplier_to_all_players(activeState.active)
		broadcast_state()
	end
end

------------------//INIT
sync_weather_state(true)

Players.PlayerAdded:Connect(function(player)
	MultiplierUtility.init(player)
	set_weather_multiplier_for_player(player, activeState.active)
	task.defer(function()
		broadcast_state(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	MultiplierUtility.clear(player)
end)

RunService.Heartbeat:Connect(function(dt)
	sync_weather_state(false)
	push_players(dt)
end)
