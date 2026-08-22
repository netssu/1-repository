------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService: TeleportService = game:GetService("TeleportService")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local mapsData = require(modules:WaitForChild("Data"):WaitForChild("MapsData"))

------------------//CONSTANTS
local MATCH_REMOTES_FOLDER_NAME: string = "MatchRemotes"
local JOIN_MATCH_REMOTE_NAME: string = "JoinMatch"
local TELEPORT_STATUS_REMOTE_NAME: string = "TeleportStatus"
local TELEPORT_DATA_VERSION: number = 1
local MATCH_TYPE: string = "FreeRoam"

------------------//VARIABLES
local matchRemotes: Folder
local joinMatch: RemoteEvent
local teleportStatus: RemoteEvent
local activeTeleports: { [Player]: boolean } = {}

------------------//FUNCTIONS
local function get_or_create_folder(): Folder
	local existingFolder = ReplicatedStorage:FindFirstChild(MATCH_REMOTES_FOLDER_NAME)
	if existingFolder and existingFolder:IsA("Folder") then
		return existingFolder
	end

	if existingFolder then
		existingFolder:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = MATCH_REMOTES_FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function get_or_create_remote(folder: Folder, remoteName: string): RemoteEvent
	local existingRemote = folder:FindFirstChild(remoteName)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		return existingRemote
	end

	if existingRemote then
		existingRemote:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = folder
	return remote
end

local function create_teleport_options(player: Player, mapName: string): TeleportOptions
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	options:SetTeleportData({
		Version = TELEPORT_DATA_VERSION,
		MatchType = MATCH_TYPE,
		Map = mapName,
		SourcePlaceId = game.PlaceId,
		SourceJobId = game.JobId,
		RequestedAt = os.time(),
		RequestedByUserId = player.UserId,
	})
	return options
end

local function teleport_player_to_match(player: Player, rawMapName: any): ()
	if activeTeleports[player] then
		return
	end

	local map = mapsData.get_map(rawMapName)
	if not map then
		teleportStatus:FireClient(player, false, "INVALID_MAP")
		return
	end

	activeTeleports[player] = true
	local options = create_teleport_options(player, map.Name)
	local success, errorMessage = pcall(function()
		TeleportService:TeleportAsync(mapsData.MATCH_PLACE_ID, { player }, options)
	end)
	if not success then
		activeTeleports[player] = nil
		warn(("[MatchTeleport] Failed to teleport %s to %s: %s"):format(player.Name, map.Name, tostring(errorMessage)))
		teleportStatus:FireClient(player, false, "TELEPORT_FAILED")
		return
	end

	teleportStatus:FireClient(player, true, "TELEPORT_STARTED")
end

------------------//MAIN FUNCTIONS
matchRemotes = get_or_create_folder()
joinMatch = get_or_create_remote(matchRemotes, JOIN_MATCH_REMOTE_NAME)
teleportStatus = get_or_create_remote(matchRemotes, TELEPORT_STATUS_REMOTE_NAME)

joinMatch.OnServerEvent:Connect(teleport_player_to_match)

Players.PlayerRemoving:Connect(function(player: Player)
	activeTeleports[player] = nil
end)

------------------//INIT
