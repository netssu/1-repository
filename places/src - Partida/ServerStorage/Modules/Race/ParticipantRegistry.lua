------------------//VARIABLES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//DEPENDENCIES
local raceTypes = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Race"):WaitForChild("RaceTypes"))

------------------//VARIABLES
local participantsByUserId: { [number]: raceTypes.Participant } = {}

------------------//MAIN FUNCTIONS
local participantRegistry = {}

function participantRegistry.create(player: Player, sessionId: string): raceTypes.Participant
	local participant: raceTypes.Participant = {
		player = player,
		userId = player.UserId,
		sessionId = sessionId,
		vehicle = nil,
		spawn = nil,
		state = "Registered",
		currentCheckpoint = 0,
		currentLap = 0,
		lapStartedAt = nil,
		sectorStartedAt = nil,
		sectorTwoReached = false,
		sectorThreeReached = false,
		lapValid = true,
		lastLapTime = nil,
		qualifyingTime = nil,
		finishedAt = nil,
		finishPosition = nil,
		rewarded = false,
	}
	participantsByUserId[player.UserId] = participant
	return participant
end

function participantRegistry.get(userId: number): raceTypes.Participant?
	return participantsByUserId[userId]
end

function participantRegistry.get_by_player(player: Player): raceTypes.Participant?
	return participantsByUserId[player.UserId]
end

function participantRegistry.get_by_vehicle(vehicle: Model): raceTypes.Participant?
	local ownerUserId = vehicle:GetAttribute("OwnerUserId")
	if type(ownerUserId) ~= "number" then
		return nil
	end

	return participantsByUserId[ownerUserId]
end

function participantRegistry.get_all(): { raceTypes.Participant }
	local participants: { raceTypes.Participant } = {}
	for _, participant in participantsByUserId do
		table.insert(participants, participant)
	end

	table.sort(participants, function(left, right): boolean
		return left.userId < right.userId
	end)
	return participants
end

function participantRegistry.remove(userId: number): raceTypes.Participant?
	local participant = participantsByUserId[userId]
	participantsByUserId[userId] = nil
	return participant
end

function participantRegistry.clear(): { raceTypes.Participant }
	local participants = participantRegistry.get_all()
	table.clear(participantsByUserId)
	return participants
end

function participantRegistry.count(): number
	local count = 0
	for _ in participantsByUserId do
		count += 1
	end
	return count
end

------------------//INIT
return participantRegistry
