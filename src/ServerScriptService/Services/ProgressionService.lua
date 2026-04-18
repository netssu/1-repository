--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local ProgressionUtil = require(ReplicatedStorage.Modules.Game.ProgressionUtil)

local FTGameService = require(script.Parent.GameService)
local FTPlayerService = require(script.Parent.PlayerService)

local ProgressionService = {}

local BASE_MATCH_EXP = 100
local WIN_BONUS_EXP = 75
local EXP_PER_PASS = 12
local EXP_PER_TOUCHDOWN = 250
local EXP_PER_TACKLE = 18
local EXP_PER_INTERCEPT = 80
local EXP_PER_ASSIST = 45
local PARTICIPATION_EXP_PER_MINUTE = 10
local SECONDS_PER_PARTICIPATION_POINT = 60

type MatchResult = {
	WinnerTeam: number?,
	Team1Score: number,
	Team2Score: number,
}

type StatSnapshot = {
	Passing: number,
	Touchdowns: number,
	Tackles: number,
	Intercepts: number,
	Assists: number,
	Timer: number,
}

local matchStartedConnection: RBXScriptConnection? = nil
local matchBaselineByPlayer: {[Player]: StatSnapshot} = {}

local function readNumericStat(player: Player, statName: string): number
	local value = PlayerDataManager:Get(player, { statName })
	return math.max(0, math.floor(tonumber(value) or 0))
end

local function capturePlayerSnapshot(player: Player): StatSnapshot
	return {
		Passing = readNumericStat(player, "Passing"),
		Touchdowns = readNumericStat(player, "Touchdowns"),
		Tackles = readNumericStat(player, "Tackles"),
		Intercepts = readNumericStat(player, "Intercepts"),
		Assists = readNumericStat(player, "Assists"),
		Timer = readNumericStat(player, "Timer"),
	}
end

local function clearBaselines(): ()
	table.clear(matchBaselineByPlayer)
end

local function captureMatchBaselines(): ()
	clearBaselines()

	for _, player in FTPlayerService:GetSelectedPlayers() do
		if player.Parent == nil then
			continue
		end

		matchBaselineByPlayer[player] = capturePlayerSnapshot(player)
	end
end

local function getParticipants(): {Player}
	local participants = {}

	for player in matchBaselineByPlayer do
		if player.Parent ~= nil then
			table.insert(participants, player)
		end
	end

	if #participants > 0 then
		return participants
	end

	for _, player in FTPlayerService:GetSelectedPlayers() do
		if player.Parent ~= nil then
			table.insert(participants, player)
		end
	end

	return participants
end

local function getBaselineForPlayer(player: Player): StatSnapshot
	return matchBaselineByPlayer[player] or capturePlayerSnapshot(player)
end

local function getStatDelta(currentValue: number, baselineValue: number): number
	return math.max(0, currentValue - baselineValue)
end

local function getParticipationExp(timerDelta: number): number
	if timerDelta <= 0 then
		return 0
	end

	return math.floor(timerDelta / SECONDS_PER_PARTICIPATION_POINT) * PARTICIPATION_EXP_PER_MINUTE
end

local function getMatchExpAward(player: Player, result: MatchResult): number
	local currentSnapshot = capturePlayerSnapshot(player)
	local baselineSnapshot = getBaselineForPlayer(player)

	local passingDelta = getStatDelta(currentSnapshot.Passing, baselineSnapshot.Passing)
	local touchdownsDelta = getStatDelta(currentSnapshot.Touchdowns, baselineSnapshot.Touchdowns)
	local tacklesDelta = getStatDelta(currentSnapshot.Tackles, baselineSnapshot.Tackles)
	local interceptsDelta = getStatDelta(currentSnapshot.Intercepts, baselineSnapshot.Intercepts)
	local assistsDelta = getStatDelta(currentSnapshot.Assists, baselineSnapshot.Assists)
	local timerDelta = getStatDelta(currentSnapshot.Timer, baselineSnapshot.Timer)

	local expAward = BASE_MATCH_EXP
		+ (passingDelta * EXP_PER_PASS)
		+ (touchdownsDelta * EXP_PER_TOUCHDOWN)
		+ (tacklesDelta * EXP_PER_TACKLE)
		+ (interceptsDelta * EXP_PER_INTERCEPT)
		+ (assistsDelta * EXP_PER_ASSIST)
		+ getParticipationExp(timerDelta)

	local winnerTeam = result.WinnerTeam
	local playerTeam = FTPlayerService:GetPlayerTeam(player)
	if winnerTeam ~= nil and playerTeam == winnerTeam then
		expAward += WIN_BONUS_EXP
	end

	return math.max(BASE_MATCH_EXP, expAward)
end

local function awardPlayerExp(player: Player, expAward: number): ()
	local currentLevel = PlayerDataManager:Get(player, { "Level" })
	local currentExp = PlayerDataManager:Get(player, { "Exp" })
	local progressionResult = ProgressionUtil.AddExp(currentLevel, currentExp, expAward)

	PlayerDataManager:Set(player, { "Level" }, progressionResult.Level)
	PlayerDataManager:Set(player, { "Exp" }, progressionResult.Exp)
end

local function handleMatchEnded(result: MatchResult): ()
	for _, player in getParticipants() do
		if player.Parent == nil then
			continue
		end

		local expAward = getMatchExpAward(player, result)
		awardPlayerExp(player, expAward)
	end

	clearBaselines()
end

local function bindMatchStarted(): ()
	local gameStateFolder = ReplicatedStorage:WaitForChild("FTGameState", 30)
	if not gameStateFolder then
		return
	end

	local matchStartedValue = gameStateFolder:WaitForChild("MatchStarted", 30)
	if not matchStartedValue or not matchStartedValue:IsA("BoolValue") then
		return
	end

	if matchStartedConnection then
		matchStartedConnection:Disconnect()
	end

	matchStartedConnection = matchStartedValue.Changed:Connect(function(isStarted: boolean)
		if isStarted then
			captureMatchBaselines()
			return
		end

		clearBaselines()
	end)

	if matchStartedValue.Value then
		captureMatchBaselines()
	end
end

function ProgressionService:Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		matchBaselineByPlayer[player] = nil
	end)
end

function ProgressionService:Start()
	task.spawn(bindMatchStarted)

	local matchEndedSignal = FTGameService:GetMatchEndedSignal()
	if matchEndedSignal and matchEndedSignal.Connect then
		matchEndedSignal:Connect(handleMatchEnded)
	end
end

return ProgressionService
