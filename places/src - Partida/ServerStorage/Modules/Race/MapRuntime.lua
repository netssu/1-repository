------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//DEPENDENCIES
local raceTypes = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Race"):WaitForChild("RaceTypes"))

------------------//CONSTANTS
local MATCH_STATE_FOLDER_NAME: string = "MatchState"
local MAP_LOAD_STATUS_ATTRIBUTE_NAME: string = "MapLoadStatus"
local MAP_LOAD_STATUS: string = "Loaded"
local LOADED_MAP_ATTRIBUTE_NAME: string = "LoadedMap"
local FESYSTEM_FOLDER_NAME: string = "FESystem"
local START_PART_NAME: string = "Start"
local SECTOR_TWO_PART_NAME: string = "S2"
local SECTOR_THREE_PART_NAME: string = "S3"
local END_PART_NAME: string = "End"
local CHECKPOINTS_FOLDER_NAME: string = "Checkpoints"
local GRID_SPAWNS_FOLDER_NAME: string = "GridSpawns"
local RACE_LIGHT_FOLDER_NAME: string = "RaceLight"
local CORNER_CUTS_FOLDER_NAME: string = "CornerCuts"
local PIT_STOP_FOLDER_NAME: string = "PitStop"
local ATTACK_ZONE_FOLDER_NAME: string = "AttackZone"
local INFO_FOLDER_NAME: string = "Info"

------------------//VARIABLES
local matchState: Folder = ReplicatedStorage:WaitForChild(MATCH_STATE_FOLDER_NAME) :: Folder

------------------//FUNCTIONS
local function get_base_part(parent: Instance?, name: string): BasePart?
	local child = parent and parent:FindFirstChild(name)
	return if child and child:IsA("BasePart") then child else nil
end

local function get_base_parts(parent: Instance?): { BasePart }
	local parts: { BasePart } = {}
	if not parent then
		return parts
	end

	for _, child in parent:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end

	return parts
end

local function get_sorted_parts(parent: Instance?): { BasePart }
	local parts = get_base_parts(parent)
	table.sort(parts, function(left: BasePart, right: BasePart): boolean
		return (tonumber(left.Name) or math.huge) < (tonumber(right.Name) or math.huge)
	end)
	return parts
end

local function get_sorted_checkpoints(parent: Instance?): { BasePart }
	local parts: { BasePart } = {}
	if not parent then
		return parts
	end

	for _, child in parent:GetChildren() do
		if child:IsA("BasePart") and tonumber(child.Name) then
			table.insert(parts, child)
		end
	end

	table.sort(parts, function(left: BasePart, right: BasePart): boolean
		return (tonumber(left.Name) or math.huge) < (tonumber(right.Name) or math.huge)
	end)
	return parts
end

local function get_fesystem(): Instance?
	local fesystem = workspace:FindFirstChild(FESYSTEM_FOLDER_NAME)
	return if fesystem then fesystem else nil
end

local function get_number_value(parent: Instance?, name: string, fallback: number): number
	local value = parent and parent:FindFirstChild(name)
	if value and value:IsA("NumberValue") then
		return value.Value
	end

	return fallback
end

local function get_boolean_value(parent: Instance?, name: string, fallback: boolean): boolean
	local value = parent and parent:FindFirstChild(name)
	if value and value:IsA("BoolValue") then
		return value.Value
	end

	return fallback
end

local function build_definition(): raceTypes.MapDefinition?
	if matchState:GetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME) ~= MAP_LOAD_STATUS then
		return nil
	end

	local fesystem = get_fesystem()
	if not fesystem then
		return nil
	end

	local info = fesystem:FindFirstChild(INFO_FOLDER_NAME)
	local checkpointsFolder = fesystem:FindFirstChild(CHECKPOINTS_FOLDER_NAME)
	local checkpoints = get_sorted_checkpoints(checkpointsFolder)
	local definition = {
		mapName = matchState:GetAttribute(LOADED_MAP_ATTRIBUTE_NAME),
		fesystem = fesystem,
		info = info,
		start = get_base_part(fesystem, START_PART_NAME),
		sectorTwo = get_base_part(fesystem, SECTOR_TWO_PART_NAME),
		sectorThree = get_base_part(fesystem, SECTOR_THREE_PART_NAME),
		finish = get_base_part(checkpointsFolder, END_PART_NAME),
		checkpoints = checkpoints,
		gridSpawns = get_sorted_parts(fesystem:FindFirstChild(GRID_SPAWNS_FOLDER_NAME)),
		raceLight = fesystem:FindFirstChild(RACE_LIGHT_FOLDER_NAME),
		cornerCuts = get_base_parts(fesystem:FindFirstChild(CORNER_CUTS_FOLDER_NAME)),
		pitStop = fesystem:FindFirstChild(PIT_STOP_FOLDER_NAME),
		attackZone = fesystem:FindFirstChild(ATTACK_ZONE_FOLDER_NAME),
		maxLaps = math.max(1, math.floor(get_number_value(info, "Laps", 1))),
		isQualifyingEnabled = get_boolean_value(info, "Quali", false),
	}

	if #definition.checkpoints == 0 then
		return nil
	end

	if #definition.gridSpawns == 0 then
		return nil
	end

	return definition
end

------------------//MAIN FUNCTIONS
local mapRuntime = {}

function mapRuntime.get_current(): raceTypes.MapDefinition?
	return build_definition()
end

function mapRuntime.wait_for_current(timeoutSeconds: number): raceTypes.MapDefinition?
	local deadline = os.clock() + timeoutSeconds
	local definition = build_definition()
	while not definition and os.clock() < deadline do
		task.wait()
		definition = build_definition()
	end

	return definition
end

------------------//INIT
return mapRuntime
