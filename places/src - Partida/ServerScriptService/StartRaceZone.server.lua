------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedFirst: ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MATCH_STATE_FOLDER_NAME: string = "MatchState"
local LOADED_MAP_ATTRIBUTE_NAME: string = "LoadedMap"
local MAP_LOAD_STATUS_ATTRIBUTE_NAME: string = "MapLoadStatus"
local MAP_LOAD_STATUS: string = "Loaded"
local FESYSTEM_FOLDER_NAME: string = "FESystem"
local PLAY_FOLDER_NAME: string = "Play"
local HIT_PART_NAME: string = "Hit"
local PLAYER_ZONE_ATTRIBUTE_NAME: string = "InStartRaceZone"
local ZONE_READY_ATTRIBUTE_NAME: string = "StartRaceZoneReady"
local ZONE_MAP_ATTRIBUTE_NAME: string = "StartRaceZoneMap"

------------------//DEPENDENCIES
local packages: Folder = ReplicatedFirst:WaitForChild("Packages")
local zoneModule = require(packages:WaitForChild("Zone"))

------------------//VARIABLES
local matchState: Folder = ReplicatedStorage:WaitForChild(MATCH_STATE_FOLDER_NAME) :: Folder
local startRaceZone: any

------------------//FUNCTIONS
local function set_players_outside_zone(): ()
	for _, player in Players:GetPlayers() do
		player:SetAttribute(PLAYER_ZONE_ATTRIBUTE_NAME, false)
	end
end

local function destroy_start_race_zone(): ()
	if startRaceZone then
		startRaceZone:destroy()
		startRaceZone = nil
	end
	set_players_outside_zone()
	matchState:SetAttribute(ZONE_READY_ATTRIBUTE_NAME, false)
	matchState:SetAttribute(ZONE_MAP_ATTRIBUTE_NAME, nil)
end

local function get_start_race_hit_part(): BasePart?
	local fesystem = workspace:FindFirstChild(FESYSTEM_FOLDER_NAME)
	local playFolder = fesystem and fesystem:FindFirstChild(PLAY_FOLDER_NAME)
	local hitPart = playFolder and playFolder:FindFirstChild(HIT_PART_NAME)
	if hitPart and hitPart:IsA("BasePart") then
		return hitPart
	end

	return nil
end

local function create_start_race_zone(): ()
	destroy_start_race_zone()

	if matchState:GetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME) ~= MAP_LOAD_STATUS then
		return
	end

	local hitPart = get_start_race_hit_part()
	if not hitPart then
		warn("[StartRaceZone] FESystem.Play.Hit não foi encontrado no mapa carregado")
		return
	end

	local zone = zoneModule.new(hitPart)
	zone:setAccuracy("High")
	startRaceZone = zone

	zone.playerEntered:Connect(function(player: Player)
		player:SetAttribute(PLAYER_ZONE_ATTRIBUTE_NAME, true)
	end)

	zone.playerExited:Connect(function(player: Player)
		player:SetAttribute(PLAYER_ZONE_ATTRIBUTE_NAME, false)
	end)

	matchState:SetAttribute(ZONE_READY_ATTRIBUTE_NAME, true)
	matchState:SetAttribute(ZONE_MAP_ATTRIBUTE_NAME, matchState:GetAttribute(LOADED_MAP_ATTRIBUTE_NAME))
end

local function on_map_loaded(): ()
	task.defer(create_start_race_zone)
end

local function on_player_added(player: Player): ()
	player:SetAttribute(PLAYER_ZONE_ATTRIBUTE_NAME, false)
end

------------------//MAIN FUNCTIONS
matchState:GetAttributeChangedSignal(LOADED_MAP_ATTRIBUTE_NAME):Connect(on_map_loaded)
matchState:GetAttributeChangedSignal(MAP_LOAD_STATUS_ATTRIBUTE_NAME):Connect(function()
	if matchState:GetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME) == MAP_LOAD_STATUS then
		on_map_loaded()
	end
end)

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)

------------------//INIT
on_map_loaded()
