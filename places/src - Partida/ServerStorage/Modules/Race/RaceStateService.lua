------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local MATCH_STATE_FOLDER_NAME: string = "MatchState"
local RACE_STATE_ATTRIBUTE_NAME: string = "RaceState"
local COUNTDOWN_ATTRIBUTE_NAME: string = "RaceCountdown"
local SESSION_ID_ATTRIBUTE_NAME: string = "RaceSessionId"
local ATTACK_AVAILABLE_ATTRIBUTE_NAME: string = "AttackAvailable"
local ATTACK_ACTIVE_ATTRIBUTE_NAME: string = "AttackActive"

------------------//DEPENDENCIES
local raceTypes = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Race"):WaitForChild("RaceTypes"))

------------------//VARIABLES
local matchState: Folder = ReplicatedStorage:WaitForChild(MATCH_STATE_FOLDER_NAME) :: Folder

------------------//MAIN FUNCTIONS
local raceStateService = {}

function raceStateService.set_state(state: string, participants: { raceTypes.Participant }): ()
	matchState:SetAttribute(RACE_STATE_ATTRIBUTE_NAME, state)
	for _, participant in participants do
		participant.player:SetAttribute(RACE_STATE_ATTRIBUTE_NAME, state)
		participant.player:SetAttribute(ATTACK_AVAILABLE_ATTRIBUTE_NAME, state == "Racing")
		participant.player:SetAttribute(ATTACK_ACTIVE_ATTRIBUTE_NAME, false)
	end
end

function raceStateService.set_countdown(value: number?, participants: { raceTypes.Participant }): ()
	matchState:SetAttribute(COUNTDOWN_ATTRIBUTE_NAME, value)
	for _, participant in participants do
		participant.player:SetAttribute(COUNTDOWN_ATTRIBUTE_NAME, value)
	end
end

function raceStateService.set_session_id(sessionId: string): ()
	matchState:SetAttribute(SESSION_ID_ATTRIBUTE_NAME, sessionId)
end

------------------//INIT
return raceStateService
