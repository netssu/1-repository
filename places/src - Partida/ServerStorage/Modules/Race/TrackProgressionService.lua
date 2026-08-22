------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//DEPENDENCIES
local raceTypes = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Race"):WaitForChild("RaceTypes"))

------------------//CONSTANTS
local OWNER_ATTRIBUTE_NAME: string = "OwnerUserId"
local VEHICLES_FOLDER_NAME: string = "Vehicles"
local TRIGGER_COOLDOWN_SECONDS: number = 0.75

------------------//VARIABLES
local connections: { RBXScriptConnection } = {}
local triggerTimes: { [string]: number } = {}
local active = false
local registry: raceTypes.ParticipantRegistry?
local definition: raceTypes.MapDefinition?
local callbacks: raceTypes.TrackCallbacks?
local mode: string = "Racing"

------------------//FUNCTIONS
local function disconnect_connections(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(triggerTimes)
end

local function get_vehicle_from_hit(hit: BasePart): Model?
	local current: Instance? = hit
	local vehiclesFolder = definition and definition.fesystem:FindFirstChild(VEHICLES_FOLDER_NAME)
	while current and current ~= workspace do
		if current:IsA("Model") and vehiclesFolder and current:IsDescendantOf(vehiclesFolder) then
			local ownerUserId = current:GetAttribute(OWNER_ATTRIBUTE_NAME)
			if type(ownerUserId) == "number" then
				return current
			end
		end
		current = current.Parent
	end

	return nil
end

local function can_process(participant: raceTypes.Participant, triggerName: string): boolean
	local key = tostring(participant.userId) .. ":" .. triggerName
	local now = os.clock()
	local lastTime = triggerTimes[key]
	if lastTime and now - lastTime < TRIGGER_COOLDOWN_SECONDS then
		return false
	end

	triggerTimes[key] = now
	return true
end

local function get_participant(hit: BasePart, triggerName: string): raceTypes.Participant?
	local vehicle = get_vehicle_from_hit(hit)
	if not vehicle then
		return nil
	end

	local participant = registry.get_by_vehicle(vehicle)
	if not participant or participant.state ~= mode then
		return nil
	end

	if not can_process(participant, triggerName) then
		return nil
	end

	return participant
end

local function update_attributes(participant: raceTypes.Participant): ()
	local player = participant.player
	player:SetAttribute("RaceLap", participant.currentLap)
	player:SetAttribute("RaceCheckpoint", participant.currentCheckpoint)
	player:SetAttribute("RaceLapValid", participant.lapValid)
end

local function begin_lap(participant: raceTypes.Participant): ()
	participant.currentLap = 1
	participant.currentCheckpoint = 0
	participant.lapStartedAt = os.clock()
	participant.sectorStartedAt = participant.lapStartedAt
	participant.sectorTwoReached = false
	participant.sectorThreeReached = false
	participant.lapValid = true
	update_attributes(participant)
	callbacks.on_lap_started(participant)
end

local function complete_lap(participant: raceTypes.Participant): ()
	if not participant.lapStartedAt then
		return
	end

	local completedLap = participant.currentLap
	local lapTime = os.clock() - participant.lapStartedAt
	participant.lastLapTime = lapTime

	if mode == "Qualifying" then
		participant.qualifyingTime = lapTime
		participant.state = "QualifyingFinished"
		participant.finishedAt = os.clock()
		update_attributes(participant)
		callbacks.on_lap_completed(participant, completedLap, lapTime)
		callbacks.on_qualifying_finished(participant, lapTime)
		return
	end

	if participant.currentLap >= definition.maxLaps then
		participant.state = "Finished"
		participant.finishedAt = os.clock()
		update_attributes(participant)
		callbacks.on_lap_completed(participant, completedLap, lapTime)
		callbacks.on_finished(participant)
		return
	end

	participant.currentLap += 1
	participant.currentCheckpoint = 0
	participant.lapStartedAt = os.clock()
	participant.sectorStartedAt = participant.lapStartedAt
	participant.sectorTwoReached = false
	participant.sectorThreeReached = false
	participant.lapValid = true
	update_attributes(participant)
	callbacks.on_lap_completed(participant, completedLap, lapTime)
	callbacks.on_lap_started(participant)
end

local function on_start_line(hit: BasePart): ()
	local participant = get_participant(hit, "Start")
	if not participant then
		return
	end

	if participant.currentLap == 0 then
		begin_lap(participant)
	elseif participant.currentCheckpoint >= #definition.checkpoints then
		complete_lap(participant)
	end
end

local function on_finish_line(hit: BasePart): ()
	local participant = get_participant(hit, "End")
	if participant and participant.currentCheckpoint >= #definition.checkpoints then
		complete_lap(participant)
	end
end

local function on_checkpoint(hit: BasePart, checkpoint: BasePart): ()
	local participant = get_participant(hit, checkpoint.Name)
	if not participant then
		return
	end

	local checkpointNumber = tonumber(checkpoint.Name)
	if checkpointNumber and checkpointNumber == participant.currentCheckpoint + 1 then
		participant.currentCheckpoint = checkpointNumber
		update_attributes(participant)
		callbacks.on_checkpoint(participant, checkpointNumber)
	end
end

local function on_sector(hit: BasePart, sectorPart: BasePart): ()
	local sectorName = sectorPart.Name
	local participant = get_participant(hit, sectorName)
	if not participant or not participant.sectorStartedAt then
		return
	end

	local elapsed = os.clock() - participant.sectorStartedAt
	if sectorName == "S2" and not participant.sectorTwoReached then
		participant.sectorTwoReached = true
		participant.sectorStartedAt = os.clock()
		callbacks.on_sector(participant, "S1", elapsed)
	elseif sectorName == "S3" and participant.sectorTwoReached and not participant.sectorThreeReached then
		participant.sectorThreeReached = true
		participant.sectorStartedAt = os.clock()
		callbacks.on_sector(participant, "S2", elapsed)
	end
end

local function on_corner_cut(hit: BasePart, cornerCut: BasePart): ()
	local participant = get_participant(hit, cornerCut.Name)
	if participant and participant.lapValid then
		participant.lapValid = false
		update_attributes(participant)
		callbacks.on_lap_invalid(participant)
	end
end

local function connect_trigger(part: BasePart, callback: (BasePart, BasePart?) -> (), secondary: BasePart?): ()
	table.insert(connections, part.Touched:Connect(function(hit: BasePart)
		callback(hit, secondary)
	end))
end

------------------//MAIN FUNCTIONS
local trackProgressionService = {}

function trackProgressionService.start(
	mapDefinition: raceTypes.MapDefinition,
	participantRegistry: raceTypes.ParticipantRegistry,
	eventCallbacks: raceTypes.TrackCallbacks,
	progressionMode: string
): boolean
	trackProgressionService.stop()
	definition = mapDefinition
	registry = participantRegistry
	callbacks = eventCallbacks
	mode = progressionMode or "Racing"
	active = true

	if definition.start then
		connect_trigger(definition.start, on_start_line)
	end
	if definition.finish then
		connect_trigger(definition.finish, on_finish_line)
	end
	if definition.sectorTwo then
		connect_trigger(definition.sectorTwo, on_sector, definition.sectorTwo)
	end
	if definition.sectorThree then
		connect_trigger(definition.sectorThree, on_sector, definition.sectorThree)
	end
	for _, checkpoint in definition.checkpoints do
		connect_trigger(checkpoint, on_checkpoint, checkpoint)
	end
	for _, cornerCut in definition.cornerCuts do
		connect_trigger(cornerCut, on_corner_cut, cornerCut)
	end

	return active
end

function trackProgressionService.stop(): ()
	active = false
	disconnect_connections()
	definition = nil
	registry = nil
	callbacks = nil
	mode = "Racing"
end

------------------//INIT
return trackProgressionService
