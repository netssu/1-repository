------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MATCH_STATE_FOLDER_NAME: string = "MatchState"
local MAP_ATTRIBUTE_NAME: string = "Map"
local MATCH_TYPE_ATTRIBUTE_NAME: string = "MatchType"
local VERSION_ATTRIBUTE_NAME: string = "Version"
local SOURCE_PLACE_ID_ATTRIBUTE_NAME: string = "SourcePlaceId"
local SOURCE_JOB_ID_ATTRIBUTE_NAME: string = "SourceJobId"

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local matchTeleportData = require(modules:WaitForChild("Data"):WaitForChild("MatchTeleportData"))

------------------//VARIABLES
local matchState: Folder

------------------//FUNCTIONS
local function get_or_create_match_state(): Folder
	local existingState = ReplicatedStorage:FindFirstChild(MATCH_STATE_FOLDER_NAME)
	if existingState and existingState:IsA("Folder") then
		return existingState
	end

	if existingState then
		existingState:Destroy()
	end

	local state = Instance.new("Folder")
	state.Name = MATCH_STATE_FOLDER_NAME
	state.Parent = ReplicatedStorage
	return state
end

local function get_player_match_data(player: Player): any
	local joinData = player:GetJoinData()
	return matchTeleportData.normalize(joinData.TeleportData)
end

local function apply_player_state(player: Player, data: any): ()
	player:SetAttribute(MAP_ATTRIBUTE_NAME, data.Map)
	player:SetAttribute(MATCH_TYPE_ATTRIBUTE_NAME, data.MatchType)
	player:SetAttribute(VERSION_ATTRIBUTE_NAME, data.Version)
end

local function publish_match_state(data: any): ()
	matchState:SetAttribute(MAP_ATTRIBUTE_NAME, data.Map)
	matchState:SetAttribute(MATCH_TYPE_ATTRIBUTE_NAME, data.MatchType)
	matchState:SetAttribute(VERSION_ATTRIBUTE_NAME, data.Version)
	if data.SourcePlaceId then
		matchState:SetAttribute(SOURCE_PLACE_ID_ATTRIBUTE_NAME, data.SourcePlaceId)
	end
	if data.SourceJobId then
		matchState:SetAttribute(SOURCE_JOB_ID_ATTRIBUTE_NAME, data.SourceJobId)
	end
end

local function on_player_added(player: Player): ()
	local currentMap = matchState:GetAttribute(MAP_ATTRIBUTE_NAME)
	if type(currentMap) == "string" then
		apply_player_state(player, {
			Map = currentMap,
			MatchType = matchState:GetAttribute(MATCH_TYPE_ATTRIBUTE_NAME) or "FreeRoam",
			Version = matchState:GetAttribute(VERSION_ATTRIBUTE_NAME) or 1,
		})
		return
	end

	local data = get_player_match_data(player)
	if not data then
		warn(("[MatchSession] No valid TeleportData for %s"):format(player.Name))
		return
	end

	publish_match_state(data)
	apply_player_state(player, data)
end

------------------//MAIN FUNCTIONS
matchState = get_or_create_match_state()

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)

------------------//INIT
