------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local ASSETS_FOLDER_NAME: string = "Assets"
local MAPS_FOLDER_NAME: string = "Maps"
local MATCH_STATE_FOLDER_NAME: string = "MatchState"
local MAP_ATTRIBUTE_NAME: string = "Map"
local LOADED_MAP_ATTRIBUTE_NAME: string = "LoadedMap"
local MAP_LOAD_STATUS_ATTRIBUTE_NAME: string = "MapLoadStatus"
local MAP_ASSET_PATH_ATTRIBUTE_NAME: string = "MapAssetPath"
local MAP_CLONE_ATTRIBUTE_NAME: string = "RemakeMapClone"
local DEFAULT_MAP_NAME: string = "Mexico City"
local DEFAULT_MAP_DELAY_SECONDS: number = 2

local MAP_ASSET_PATHS: { [string]: { string } } = {
	["Tempelhof"] = { "Tempelhof" },
	["São Paulo"] = { "SãoPaulo" },
	["Mexico City"] = { "Mexico" },
	["Miami"] = { "Miami", "USA_HardRockStadium" },
	["Brainrot"] = { "Brainrot" },
	["Intergalatic"] = { "Intergalatic" },
	["Shanghai"] = { "Shangai" },
	["Tokyo"] = { "Tokyo" },
}

------------------//VARIABLES
local assets: Folder = ReplicatedStorage:WaitForChild(ASSETS_FOLDER_NAME) :: Folder
local maps: Folder = assets:WaitForChild(MAPS_FOLDER_NAME) :: Folder
local matchState: Folder = ReplicatedStorage:WaitForChild(MATCH_STATE_FOLDER_NAME) :: Folder
local loadedMapName: string?
local isLoading: boolean = false

------------------//FUNCTIONS
local function get_map_asset_path(mapName: string): { string }?
	return MAP_ASSET_PATHS[mapName]
end

local function get_map_source(mapName: string): Folder?
	local assetPath = get_map_asset_path(mapName)
	if not assetPath then
		return nil
	end

	local currentInstance: Instance = maps
	for _, pathSegment in assetPath do
		local nextInstance = currentInstance:FindFirstChild(pathSegment)
		if not nextInstance then
			return nil
		end
		currentInstance = nextInstance
	end

	if currentInstance:IsA("Folder") then
		return currentInstance
	end

	return nil
end

local function clear_loaded_map(): ()
	for _, instance in workspace:GetChildren() do
		if instance:GetAttribute(MAP_CLONE_ATTRIBUTE_NAME) == true then
			instance:Destroy()
		end
	end

	loadedMapName = nil
	matchState:SetAttribute(LOADED_MAP_ATTRIBUTE_NAME, nil)
	matchState:SetAttribute(MAP_ASSET_PATH_ATTRIBUTE_NAME, nil)
end

local function clone_map_source(mapSource: Folder, mapName: string): number
	local cloneCount: number = 0
	local assetPath = get_map_asset_path(mapName)
	if not assetPath then
		return cloneCount
	end

	for _, sourceChild in mapSource:GetChildren() do
		local clone = sourceChild:Clone()
		clone:SetAttribute(MAP_CLONE_ATTRIBUTE_NAME, true)
		clone.Parent = workspace
		cloneCount += 1
	end

	matchState:SetAttribute(LOADED_MAP_ATTRIBUTE_NAME, mapName)
	matchState:SetAttribute(MAP_ASSET_PATH_ATTRIBUTE_NAME, MAPS_FOLDER_NAME .. "." .. table.concat(assetPath, "."))
	return cloneCount
end

local function load_map(requestedMapName: string): ()
	if isLoading or loadedMapName == requestedMapName then
		return
	end

	isLoading = true
	matchState:SetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME, "Loading")
	clear_loaded_map()

	local effectiveMapName: string = requestedMapName
	local mapSource = get_map_source(effectiveMapName)
	if not mapSource then
		warn(("[MapLoader] Asset do mapa %s não foi encontrado; usando %s"):format(requestedMapName, DEFAULT_MAP_NAME))
		effectiveMapName = DEFAULT_MAP_NAME
		mapSource = get_map_source(effectiveMapName)
	end

	if not mapSource then
		matchState:SetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME, "MissingAsset")
		isLoading = false
		return
	end

	local cloneCount = clone_map_source(mapSource, effectiveMapName)
	loadedMapName = effectiveMapName
	matchState:SetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME, if cloneCount > 0 then "Loaded" else "Empty")
	isLoading = false
end

local function get_requested_map_name(): string
	local mapName = matchState:GetAttribute(MAP_ATTRIBUTE_NAME)
	if type(mapName) == "string" and mapName ~= "" then
		return mapName
	end

	return DEFAULT_MAP_NAME
end

local function on_map_changed(): ()
	load_map(get_requested_map_name())
end

------------------//MAIN FUNCTIONS
matchState:GetAttributeChangedSignal(MAP_ATTRIBUTE_NAME):Connect(on_map_changed)
task.delay(DEFAULT_MAP_DELAY_SECONDS, on_map_changed)

------------------//INIT
on_map_changed()
