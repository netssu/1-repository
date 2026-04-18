--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager: any = require(ReplicatedStorage.Packages.PlayerDataManager)
local RankStats = require(ServerScriptService.Services.Utils.RankStats)

local PlayerStatsTracker = {}

local STAT_TOUCHDOWNS: string = "Touchdowns"
local STAT_PASSING: string = "Passing"
local STAT_TACKLES: string = "Tackles"
local STAT_WINS: string = "Wins"
local STAT_TIMER: string = "Timer"
local DEFAULT_INCREMENT: number = 1

local function IsValidPlayer(PlayerInstance: Player?): boolean
	return PlayerInstance ~= nil and PlayerInstance.Parent ~= nil
end

local function IncrementStat(PlayerInstance: Player?, StatName: string, Amount: number?): boolean
	if not IsValidPlayer(PlayerInstance) then
		return false
	end
	if not RankStats.IsTrackedStat(StatName) then
		return false
	end

	local IncrementAmount: number = math.max(math.floor(Amount or DEFAULT_INCREMENT), 0)
	if IncrementAmount <= 0 then
		return false
	end

	local Success: boolean, ErrorMessage: any = pcall(function()
		PlayerDataManager:Increment(PlayerInstance, { StatName }, IncrementAmount)
	end)
	if not Success then
		warn(string.format("PlayerStatsTracker failed for %s (%s): %s", PlayerInstance.Name, StatName, tostring(ErrorMessage)))
		return false
	end

	return true
end

function PlayerStatsTracker.AwardTouchdown(PlayerInstance: Player?): boolean
	return IncrementStat(PlayerInstance, STAT_TOUCHDOWNS, DEFAULT_INCREMENT)
end

function PlayerStatsTracker.AwardPass(PlayerInstance: Player?): boolean
	return IncrementStat(PlayerInstance, STAT_PASSING, DEFAULT_INCREMENT)
end

function PlayerStatsTracker.AwardTackle(PlayerInstance: Player?): boolean
	return IncrementStat(PlayerInstance, STAT_TACKLES, DEFAULT_INCREMENT)
end

function PlayerStatsTracker.AwardWin(PlayerInstance: Player?): boolean
	return IncrementStat(PlayerInstance, STAT_WINS, DEFAULT_INCREMENT)
end

function PlayerStatsTracker.AddTimer(PlayerInstance: Player?, Seconds: number): boolean
	return IncrementStat(PlayerInstance, STAT_TIMER, Seconds)
end

function PlayerStatsTracker.Add(PlayerInstance: Player?, StatName: string, Amount: number?): boolean
	return IncrementStat(PlayerInstance, StatName, Amount)
end

return PlayerStatsTracker
