------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local CASH_PER_LAP: number = 100
local XP_PER_LAP: number = 40
local FIRST_PLACE_CASH: number = 400
local FIRST_PLACE_XP: number = 400
local SECOND_PLACE_CASH: number = 200
local SECOND_PLACE_XP: number = 200
local THIRD_PLACE_CASH: number = 150
local THIRD_PLACE_XP: number = 150

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local raceTypes = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Race"):WaitForChild("RaceTypes"))
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//FUNCTIONS
local function calculate_rewards(participant: raceTypes.Participant): (number, number)
	local completedLaps = math.max(0, participant.currentLap - 1)
	local cash = CASH_PER_LAP * completedLaps
	local xp = XP_PER_LAP * completedLaps
	if participant.finishPosition == 1 then
		cash += FIRST_PLACE_CASH
		xp += FIRST_PLACE_XP
	elseif participant.finishPosition == 2 then
		cash += SECOND_PLACE_CASH
		xp += SECOND_PLACE_XP
	elseif participant.finishPosition == 3 then
		cash += THIRD_PLACE_CASH
		xp += THIRD_PLACE_XP
	end
	return cash, xp
end

------------------//MAIN FUNCTIONS
local raceRewardService = {}

function raceRewardService.award(participant: raceTypes.Participant): ()
	if participant.rewarded or not participant.player.Parent then
		return
	end

	local cash, xp = calculate_rewards(participant)
	local currentCash = tonumber(dataUtility.server.get(participant.player, "Currency.Cash")) or 0
	local currentXp = tonumber(dataUtility.server.get(participant.player, "Currency.XP")) or 0
	local currentMatches = tonumber(dataUtility.server.get(participant.player, "Profile.Statistics.Matches")) or 0
	local currentWins = tonumber(dataUtility.server.get(participant.player, "Profile.Statistics.Wins")) or 0

	dataUtility.server.set(participant.player, "Currency.Cash", currentCash + cash)
	dataUtility.server.set(participant.player, "Currency.XP", currentXp + xp)
	dataUtility.server.set(participant.player, "Profile.Statistics.Matches", currentMatches + 1)
	if participant.finishPosition == 1 then
		dataUtility.server.set(participant.player, "Profile.Statistics.Wins", currentWins + 1)
	end

	participant.rewarded = true
	participant.player:SetAttribute("RaceRewardCash", cash)
	participant.player:SetAttribute("RaceRewardXP", xp)
end

------------------//INIT
return raceRewardService
