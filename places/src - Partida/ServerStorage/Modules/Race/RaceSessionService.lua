------------------//SERVICES
local HttpService: HttpService = game:GetService("HttpService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MATCH_STATE_FOLDER_NAME: string = "MatchState"
local MAP_LOAD_STATUS_ATTRIBUTE_NAME: string = "MapLoadStatus"
local LOADED_MAP_ATTRIBUTE_NAME: string = "LoadedMap"
local MAP_LOAD_STATUS: string = "Loaded"
local ZONE_ATTRIBUTE_NAME: string = "InStartRaceZone"
local SESSION_ID_ATTRIBUTE_NAME: string = "RaceSessionId"
local RACE_STATE_ATTRIBUTE_NAME: string = "RaceState"
local COUNTDOWN_ATTRIBUTE_NAME: string = "RaceCountdown"
local POSITION_ATTRIBUTE_NAME: string = "RacePosition"
local MINIMUM_PLAYERS: number = 1
local WAITING_COUNTDOWN_SECONDS: number = 10
local GRID_COUNTDOWN_SECONDS: number = 5
local LIGHT_COUNT: number = 5
local LIGHT_DELAY_SECONDS: number = 0.8
local START_DELAY_MIN_SECONDS: number = 0.3
local START_DELAY_MAX_SECONDS: number = 1.5
local POST_RACE_DELAY_SECONDS: number = 5

------------------//DEPENDENCIES
local serverModules: Folder = game:GetService("ServerStorage"):WaitForChild("Modules")
local raceTypes = require(serverModules:WaitForChild("Race"):WaitForChild("RaceTypes"))
local mapRuntime = require(serverModules:WaitForChild("Race"):WaitForChild("MapRuntime"))
local participantRegistry = require(serverModules:WaitForChild("Race"):WaitForChild("ParticipantRegistry"))
local vehicleService = require(serverModules:WaitForChild("Race"):WaitForChild("VehicleService"))
local trackProgressionService = require(serverModules:WaitForChild("Race"):WaitForChild("TrackProgressionService"))
local raceGridService = require(serverModules:WaitForChild("Race"):WaitForChild("RaceGridService"))
local raceRewardService = require(serverModules:WaitForChild("Race"):WaitForChild("RaceRewardService"))
local raceStateService = require(serverModules:WaitForChild("Race"):WaitForChild("RaceStateService"))

------------------//VARIABLES
local matchState: Folder = ReplicatedStorage:WaitForChild(MATCH_STATE_FOLDER_NAME) :: Folder
local currentState: string = "WaitingForMap"
local currentSessionId: string = ""
local currentDefinition: raceTypes.MapDefinition?
local countdownToken = 0
local playerConnections: { [Player]: RBXScriptConnection } = {}
local finishPosition: number = 0
local started: boolean = false
local mapResetScheduled: boolean = false

------------------//FUNCTIONS
local function set_state(state: string): ()
	currentState = state
	raceStateService.set_state(state, participantRegistry.get_all())
end

local function set_countdown(value: number?): ()
	raceStateService.set_countdown(value, participantRegistry.get_all())
end

local function set_light_color(color: Color3): ()
	local raceLight = currentDefinition and currentDefinition.raceLight
	if not raceLight then
		return
	end

	for _, descendant in raceLight:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = color
		end
	end
end

local function prepare_grid(): boolean
	return currentDefinition ~= nil
		and raceGridService.prepare(participantRegistry.get_all(), currentDefinition.gridSpawns)
end

local function finish_session(): ()
	if currentState == "Results" or currentState == "Closed" then
		return
	end

	set_state("Results")
	set_countdown(nil)
	trackProgressionService.stop()

	for _, participant in participantRegistry.get_all() do
		raceRewardService.award(participant)
	end

	task.delay(POST_RACE_DELAY_SECONDS, function()
		if currentSessionId == "" then
			return
		end

		vehicleService.destroy_all()
		for _, participant in participantRegistry.get_all() do
			participant.player:SetAttribute(SESSION_ID_ATTRIBUTE_NAME, nil)
			participant.player:SetAttribute(RACE_STATE_ATTRIBUTE_NAME, nil)
			participant.player:SetAttribute(COUNTDOWN_ATTRIBUTE_NAME, nil)
		end
		participantRegistry.clear()
		currentSessionId = ""
		finishPosition = 0
		set_state("WaitingForPlayers")
	end)
end

local function on_finished(participant: raceTypes.Participant): ()
	if participant.finishPosition then
		return
	end

	finishPosition += 1
	participant.finishPosition = finishPosition
	participant.state = "Finished"
	participant.player:SetAttribute(POSITION_ATTRIBUTE_NAME, finishPosition)
	vehicleService.set_enabled(participant.player, false)

	local finishedCount = 0
	for _, currentParticipant in participantRegistry.get_all() do
		if currentParticipant.finishPosition then
			finishedCount += 1
		end
	end

	if finishedCount >= participantRegistry.count() then
		finish_session()
	end
end

local function on_lap_completed(participant: raceTypes.Participant, lapNumber: number, lapTime: number): ()
	participant.player:SetAttribute("RaceCompletedLap", lapNumber)
	participant.player:SetAttribute("RaceLastLapTime", lapTime)
end

local function on_lap_started(participant: raceTypes.Participant): ()
	participant.player:SetAttribute("RaceLap", participant.currentLap)
end

local function on_checkpoint(participant: raceTypes.Participant, checkpointNumber: number): ()
	participant.player:SetAttribute("RaceCheckpoint", checkpointNumber)
end

local function on_sector(participant: raceTypes.Participant, sectorName: string, sectorTime: number): ()
	participant.player:SetAttribute("Race" .. sectorName .. "Time", sectorTime)
end

local function on_lap_invalid(participant: raceTypes.Participant): ()
	participant.player:SetAttribute("RaceLapValid", false)
end

local begin_race: () -> ()

local function finish_qualifying(): ()
	if currentState ~= "Qualifying" then
		return
	end

	trackProgressionService.stop()
	local participants = participantRegistry.get_all()
	if not currentDefinition or not raceGridService.apply_qualifying_order(participants, currentDefinition.gridSpawns) then
		set_state("WaitingForPlayers")
		return
	end

	set_state("Grid")
	task.delay(GRID_COUNTDOWN_SECONDS, function()
		if currentState == "Grid" then
			set_state("Countdown")
			begin_race()
		end
	end)
end

local function on_qualifying_finished(participant: raceTypes.Participant, lapTime: number): ()
	participant.player:SetAttribute("RaceQualifyingTime", lapTime)
	local finishedCount = 0
	for _, currentParticipant in participantRegistry.get_all() do
		if currentParticipant.qualifyingTime then
			finishedCount += 1
		end
	end

	if finishedCount >= participantRegistry.count() then
		finish_qualifying()
	end
end

local function begin_qualifying(): ()
	if currentState ~= "Countdown" or not currentDefinition then
		return
	end
	if not prepare_grid() then
		set_state("WaitingForPlayers")
		return
	end

	set_countdown(nil)
	set_state("Qualifying")
	for _, participant in participantRegistry.get_all() do
		participant.state = "Qualifying"
		vehicleService.set_enabled(participant.player, true)
	end
	trackProgressionService.start(currentDefinition, participantRegistry, {
		on_lap_started = on_lap_started,
		on_lap_completed = on_lap_completed,
		on_checkpoint = on_checkpoint,
		on_sector = on_sector,
		on_lap_invalid = on_lap_invalid,
		on_finished = on_finished,
		on_qualifying_finished = on_qualifying_finished,
	}, "Qualifying")
end

begin_race = function(): ()
	if currentState ~= "Countdown" or not currentDefinition then
		return
	end
	if participantRegistry.count() < MINIMUM_PLAYERS then
		set_state("WaitingForPlayers")
		return
	end
	if not prepare_grid() then
		set_state("WaitingForPlayers")
		return
	end

	set_state("Grid")
	set_countdown(GRID_COUNTDOWN_SECONDS)
	task.wait(1)
	for remaining = GRID_COUNTDOWN_SECONDS - 1, 0, -1 do
		if currentState ~= "Grid" then
			return
		end
		set_countdown(remaining)
		task.wait(1)
	end

	local startDelay = math.random(
		math.floor(START_DELAY_MIN_SECONDS * 100),
		math.floor(START_DELAY_MAX_SECONDS * 100)
	) / 100
	set_state("RaceLights")
	set_light_color(Color3.fromRGB(255, 0, 0))
	for _ = 1, LIGHT_COUNT do
		task.wait(LIGHT_DELAY_SECONDS)
	end
	task.wait(startDelay)
	set_light_color(Color3.fromRGB(27, 42, 53))
	set_countdown(nil)
	set_state("Racing")
	for _, participant in participantRegistry.get_all() do
		participant.state = "Racing"
		vehicleService.set_enabled(participant.player, true)
	end
	trackProgressionService.start(currentDefinition, participantRegistry, {
		on_lap_started = on_lap_started,
		on_lap_completed = on_lap_completed,
		on_checkpoint = on_checkpoint,
		on_sector = on_sector,
		on_lap_invalid = on_lap_invalid,
		on_finished = on_finished,
		on_qualifying_finished = on_qualifying_finished,
	}, "Racing")
end

local function start_countdown(): ()
	if currentState ~= "WaitingForPlayers" or participantRegistry.count() < MINIMUM_PLAYERS then
		return
	end

	countdownToken += 1
	local token = countdownToken
	set_state("Countdown")

	task.spawn(function()
		for remaining = WAITING_COUNTDOWN_SECONDS, 0, -1 do
			if token ~= countdownToken or currentState ~= "Countdown" then
				return
			end
			set_countdown(remaining)
			task.wait(1)
		end
		if currentDefinition and currentDefinition.isQualifyingEnabled then
			begin_qualifying()
		else
			begin_race()
		end
	end)
end

local function add_player(player: Player): ()
	if not currentDefinition or (currentState ~= "WaitingForPlayers" and currentState ~= "Countdown") then
		return
	end
	if participantRegistry.get_by_player(player) then
		return
	end

	local participant = participantRegistry.create(player, currentSessionId)
	local vehicle, spawn = vehicleService.spawn_vehicle(player, currentSessionId)
	if not vehicle or not spawn then
		participantRegistry.remove(player.UserId)
		return
	end

	participant.vehicle = vehicle
	participant.spawn = spawn
	participant.player:SetAttribute(SESSION_ID_ATTRIBUTE_NAME, currentSessionId)
	participant.player:SetAttribute(RACE_STATE_ATTRIBUTE_NAME, currentState)
	participant.player:SetAttribute("RaceParticipant", true)
	participant.player:SetAttribute(POSITION_ATTRIBUTE_NAME, participantRegistry.count())
	vehicleService.set_enabled(player, false)
	vehicleService.seat_player(player)
	start_countdown()
end

local function remove_player(player: Player): ()
	local participant = participantRegistry.remove(player.UserId)
	vehicleService.destroy_vehicle(player)
	if participant and participantRegistry.count() == 0 and currentState ~= "Results" then
		countdownToken += 1
		trackProgressionService.stop()
		set_countdown(nil)
		set_state("WaitingForPlayers")
	end
end

local function reset_for_map(): ()
	countdownToken += 1
	trackProgressionService.stop()
	vehicleService.destroy_all()
	participantRegistry.clear()
	finishPosition = 0
	currentSessionId = HttpService:GenerateGUID(false)
	currentDefinition = mapRuntime.get_current()
	matchState:SetAttribute(SESSION_ID_ATTRIBUTE_NAME, currentSessionId)
	if currentDefinition then
		set_state("WaitingForPlayers")
	else
		set_state("WaitingForMap")
	end
	set_countdown(nil)
end

local function schedule_map_reset(): ()
	if mapResetScheduled then
		return
	end
	mapResetScheduled = true
	task.defer(function()
		mapResetScheduled = false
		if matchState:GetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME) == MAP_LOAD_STATUS then
			reset_for_map()
		end
	end)
end

local function connect_player(player: Player): ()
	if playerConnections[player] then
		return
	end

	playerConnections[player] = player:GetAttributeChangedSignal(ZONE_ATTRIBUTE_NAME):Connect(function()
		if player:GetAttribute(ZONE_ATTRIBUTE_NAME) == true then
			add_player(player)
		end
	end)
	if player:GetAttribute(ZONE_ATTRIBUTE_NAME) == true then
		add_player(player)
	end
end

------------------//MAIN FUNCTIONS
local raceSessionService = {}

function raceSessionService.start(): ()
	if started then
		return
	end
	started = true
	vehicleService.start()
	matchState:GetAttributeChangedSignal(MAP_LOAD_STATUS_ATTRIBUTE_NAME):Connect(function()
		if matchState:GetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME) == MAP_LOAD_STATUS then
			schedule_map_reset()
		end
	end)
	matchState:GetAttributeChangedSignal(LOADED_MAP_ATTRIBUTE_NAME):Connect(function()
		if matchState:GetAttribute(MAP_LOAD_STATUS_ATTRIBUTE_NAME) == MAP_LOAD_STATUS then
			schedule_map_reset()
		end
	end)
	for _, player in Players:GetPlayers() do
		connect_player(player)
	end
	Players.PlayerAdded:Connect(connect_player)
	Players.PlayerRemoving:Connect(function(player: Player)
		remove_player(player)
		playerConnections[player] = nil
	end)
	reset_for_map()
	for _, player in Players:GetPlayers() do
		if player:GetAttribute(ZONE_ATTRIBUTE_NAME) == true then
			add_player(player)
		end
	end
end

------------------//INIT
return raceSessionService
