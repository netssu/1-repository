------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MultiplierUtility = require(ReplicatedStorage.Modules.Utility.MultiplierUtility)
local WeatherControl = require(script.Parent:WaitForChild("WeatherControl"))
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local WorldConfig = require(ReplicatedStorage.Modules.Datas.WorldConfig)

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

local CLOUDS_NAME = "GlobalWeatherClouds"
local DEFAULT_WIND_DIRECTION = Vector3.new(1, 0, 0)
local portalsFolder = workspace:WaitForChild("Portals")

------------------//STATE
local activeState = {
	active = false,
	direction = DEFAULT_WIND_DIRECTION,
	hourSlot = -1,
	startedAt = 0,
	endsAt = 0,
}

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
		direction = DEFAULT_WIND_DIRECTION
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

local function snap_to_nearest_right_angle(direction: Vector3): Vector3
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude < 0.001 then
		return DEFAULT_WIND_DIRECTION
	end

	if math.abs(horizontal.X) >= math.abs(horizontal.Z) then
		return Vector3.new(horizontal.X >= 0 and 1 or -1, 0, 0)
	end

	return Vector3.new(0, 0, horizontal.Z >= 0 and 1 or -1)
end

local function get_player_wind_direction(player: Player): Vector3
	local currentWorldId = DataUtility.server.get(player, "CurrentWorld") or 1
	local currentWorldData = WorldConfig.GetWorld(currentWorldId)
	local nextPortal = portalsFolder:FindFirstChild(tostring(currentWorldId + 1))

	if not currentWorldData or not currentWorldData.entryCFrame or not nextPortal or not nextPortal:IsA("BasePart") then
		return activeState.direction
	end

	local spawnPosition = currentWorldData.entryCFrame.Position
	local directionToPortal = nextPortal.Position - spawnPosition
	if directionToPortal.Magnitude < 0.001 then
		return activeState.direction
	end

	local snapped = snap_to_nearest_right_angle(directionToPortal.Unit)
	return -snapped
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

local function broadcast_state(targetPlayer: Player?)
	if targetPlayer then
		local personalizedState = table.clone(activeState)
		personalizedState.direction = get_player_wind_direction(targetPlayer)
		weatherRemote:FireClient(targetPlayer, personalizedState)
	else
		for _, player in ipairs(Players:GetPlayers()) do
			local personalizedState = table.clone(activeState)
			personalizedState.direction = get_player_wind_direction(player)
			weatherRemote:FireClient(player, personalizedState)
		end
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

task.spawn(function()
	while true do
		task.wait(1)
		sync_weather_state(false)
	end
end)
