------------------//DEPENDENCIES
local serverModules: Folder = game:GetService("ServerStorage"):WaitForChild("Modules")
local raceTypes = require(serverModules:WaitForChild("Race"):WaitForChild("RaceTypes"))
local vehicleService = require(serverModules:WaitForChild("Race"):WaitForChild("VehicleService"))

------------------//CONSTANTS
local POSITION_ATTRIBUTE_NAME: string = "RacePosition"

------------------//FUNCTIONS
local function position_participant(participant: raceTypes.Participant, spawn: BasePart, position: number): boolean
	if not participant.vehicle then
		return false
	end

	if not vehicleService.position_vehicle(participant.vehicle, spawn) then
		return false
	end

	participant.spawn = spawn
	participant.vehicle:SetAttribute("SpawnSlot", spawn.Name)
	participant.vehicle:SetAttribute("GridPosition", position)
	participant.player:SetAttribute(POSITION_ATTRIBUTE_NAME, position)
	participant.player:SetAttribute("RaceCheckpoint", 0)
	participant.player:SetAttribute("RaceLap", 0)
	vehicleService.set_enabled(participant.player, false)
	vehicleService.seat_player(participant.player)
	return true
end

------------------//MAIN FUNCTIONS
local raceGridService = {}

function raceGridService.prepare(participants: { raceTypes.Participant }, gridSpawns: { BasePart }): boolean
	table.sort(participants, function(left, right): boolean
		return left.userId < right.userId
	end)

	for position, participant in participants do
		local spawn = gridSpawns[position]
		if not spawn or not position_participant(participant, spawn, position) then
			return false
		end
	end
	return true
end

function raceGridService.apply_qualifying_order(participants: { raceTypes.Participant }, gridSpawns: { BasePart }): boolean
	table.sort(participants, function(left, right): boolean
		return (left.qualifyingTime or math.huge) < (right.qualifyingTime or math.huge)
	end)

	for position, participant in participants do
		local spawn = gridSpawns[position]
		if not spawn or not position_participant(participant, spawn, position) then
			return false
		end
		participant.state = "Grid"
	end
	return true
end

------------------//INIT
return raceGridService
