------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService: SoundService = game:GetService("SoundService")

------------------//CONSTANTS
local PLAYLIST_FOLDER_NAME: string = "MusicPlaylist"
local PLAYLIST_ORDER_ATTRIBUTE: string = "PlaylistOrder"
local ENABLED_ATTRIBUTE: string = "Enabled"
local SETTINGS_MUSIC_PATH: string = "Profile.Settings.MusicEnabled"
local DEFAULT_TRACK_ORDER: number = math.huge
local FADE_OUT_ON_STOP: boolean = true

type DataConnection = {
	disconnect: (self: DataConnection) -> (),
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local soundUtility = require(modules:WaitForChild("Utility"):WaitForChild("SoundUtility"))

------------------//VARIABLES
local playlistFolder: Folder?
local currentTrack: Sound?
local currentTrackSourceName: string?
local currentTrackIndex: number = 0
local playbackToken: number = 0
local isMusicEnabled: boolean = true
local isEnabled: boolean = false
local trackEndedConnection: RBXScriptConnection?
local playlistConnections: { RBXScriptConnection } = {}
local dataConnection: DataConnection?

------------------//FUNCTIONS
local function ensure_playlist_folder(): Folder
	local existingFolder = SoundService:FindFirstChild(PLAYLIST_FOLDER_NAME)
	if existingFolder and existingFolder:IsA("Folder") then
		return existingFolder
	end

	if existingFolder then
		existingFolder:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = PLAYLIST_FOLDER_NAME
	folder.Parent = SoundService
	return folder
end

local function disconnect_track_ended(): ()
	if trackEndedConnection then
		trackEndedConnection:Disconnect()
		trackEndedConnection = nil
	end
end

local function get_track_order(track: Sound): number
	local order = track:GetAttribute(PLAYLIST_ORDER_ATTRIBUTE)
	if type(order) == "number" then
		return order
	end

	return DEFAULT_TRACK_ORDER
end

local function get_playlist_tracks(): { Sound }
	local tracks: { Sound } = {}
	if not playlistFolder then
		return tracks
	end

	for _, instance in playlistFolder:GetChildren() do
		if instance:IsA("Sound") and instance.SoundId ~= "" and instance:GetAttribute(ENABLED_ATTRIBUTE) ~= false then
			table.insert(tracks, instance)
		end
	end

	table.sort(tracks, function(firstTrack: Sound, secondTrack: Sound): boolean
		local firstOrder = get_track_order(firstTrack)
		local secondOrder = get_track_order(secondTrack)
		if firstOrder ~= secondOrder then
			return firstOrder < secondOrder
		end

		return string.lower(firstTrack.Name) < string.lower(secondTrack.Name)
	end)

	return tracks
end

local function has_track_source(trackName: string?, tracks: { Sound }): boolean
	if not trackName then
		return false
	end

	for _, track in tracks do
		if track.Name == trackName then
			return true
		end
	end

	return false
end

local function stop_current_music(fadeOut: boolean, resetIndex: boolean): ()
	playbackToken += 1
	disconnect_track_ended()
	currentTrack = nil
	currentTrackSourceName = nil
	if resetIndex then
		currentTrackIndex = 0
	end
	soundUtility.stop_music(fadeOut)
end

local play_track: (number) -> ()

play_track = function(requestedIndex: number): ()
	if not isEnabled or not isMusicEnabled then
		return
	end

	local tracks = get_playlist_tracks()
	local trackCount = #tracks
	if trackCount == 0 then
		stop_current_music(FADE_OUT_ON_STOP, true)
		return
	end

	local normalizedIndex = ((requestedIndex - 1) % trackCount) + 1
	local sourceTrack = tracks[normalizedIndex]
	if not sourceTrack then
		return
	end

	playbackToken += 1
	local token = playbackToken
	disconnect_track_ended()
	currentTrackIndex = normalizedIndex
	currentTrackSourceName = sourceTrack.Name
	local sound = soundUtility.play_music(sourceTrack.SoundId, true, false)
	currentTrack = sound
	if not sound then
		return
	end

	trackEndedConnection = sound.Ended:Connect(function()
		if token ~= playbackToken or sound ~= currentTrack then
			return
		end

		play_track(currentTrackIndex + 1)
	end)
end

local function reconcile_playlist(): ()
	if not isEnabled then
		return
	end

	local tracks = get_playlist_tracks()
	if #tracks == 0 then
		stop_current_music(FADE_OUT_ON_STOP, true)
		return
	end

	if not isMusicEnabled then
		return
	end

	if currentTrack and currentTrack.Parent and currentTrack.Playing and has_track_source(currentTrackSourceName, tracks) then
		return
	end

	local requestedIndex = currentTrackIndex
	if requestedIndex < 1 then
		requestedIndex = 1
	end

	play_track(requestedIndex)
end

local function on_playlist_changed(): ()
	task.defer(reconcile_playlist)
end

local function disconnect_playlist_connections(): ()
	for _, connection in playlistConnections do
		connection:Disconnect()
	end
	playlistConnections = {}
end

local function disconnect_data_connection(): ()
	if dataConnection then
		dataConnection:disconnect()
		dataConnection = nil
	end
end

local function set_music_enabled(enabled: boolean): ()
	isMusicEnabled = enabled
	if not enabled then
		stop_current_music(FADE_OUT_ON_STOP, false)
		return
	end

	reconcile_playlist()
end

local function bind_playlist(): ()
	if not playlistFolder then
		return
	end

	table.insert(playlistConnections, playlistFolder.ChildAdded:Connect(on_playlist_changed))
	table.insert(playlistConnections, playlistFolder.ChildRemoved:Connect(on_playlist_changed))
end

------------------//MAIN FUNCTIONS
local function music_playlist_enable(): ()
	if isEnabled then
		return
	end

	playlistFolder = ensure_playlist_folder()
	bind_playlist()
	dataUtility.client.ensure_remotes()
	isMusicEnabled = dataUtility.client.get(SETTINGS_MUSIC_PATH) ~= false
	dataConnection = dataUtility.client.bind(SETTINGS_MUSIC_PATH, function(value: any)
		set_music_enabled(value == true)
	end)
	isEnabled = true
	reconcile_playlist()
end

local function music_playlist_disable(): ()
	if not isEnabled then
		return
	end

	isEnabled = false
	disconnect_playlist_connections()
	disconnect_data_connection()
	stop_current_music(FADE_OUT_ON_STOP, true)
	playlistFolder = nil
end

------------------//INIT
music_playlist_enable()
