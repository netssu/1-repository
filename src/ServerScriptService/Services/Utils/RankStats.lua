--!strict

local RankStats = {}

export type StatName = "Touchdowns" | "Passing" | "Tackles" | "Wins" | "Timer"
export type BoardType = "Touchdowns" | "Wins" | "Pass" | "Timer" | "Tackles"
export type BoardDisplayVariant = "Default" | "Tv"
export type BoardDef = {
	BoardType: BoardType,
	StatName: StatName,
	StoreKey: string,
	Title: string,
	TvTitle: string,
	IsTimer: boolean,
}

local HOUR_SECONDS: number = 60 * 60
local DAY_HOURS: number = 24

local BOARD_TYPES: {BoardType} = {
	"Touchdowns",
	"Wins",
	"Pass",
	"Timer",
	"Tackles",
}

local STAT_NAMES: {StatName} = {
	"Touchdowns",
	"Wins",
	"Passing",
	"Timer",
	"Tackles",
}

local BOARD_DEFS: {[string]: BoardDef} = {
	Touchdowns = {
		BoardType = "Touchdowns",
		StatName = "Touchdowns",
		StoreKey = "Touchdowns",
		Title = "Top Touchdowns",
		TvTitle = "MOST TOUCHDOWNS SCORED",
		IsTimer = false,
	},
	Wins = {
		BoardType = "Wins",
		StatName = "Wins",
		StoreKey = "Wins",
		Title = "Top Wins",
		TvTitle = "MOST WINS",
		IsTimer = false,
	},
	Pass = {
		BoardType = "Pass",
		StatName = "Passing",
		StoreKey = "Passing",
		Title = "Top Passes",
		TvTitle = "MOST PASSES COMPLETED",
		IsTimer = false,
	},
	Timer = {
		BoardType = "Timer",
		StatName = "Timer",
		StoreKey = "Timer",
		Title = "Top Time Played",
		TvTitle = "MOST TIME PLAYED",
		IsTimer = true,
	},
	Tackles = {
		BoardType = "Tackles",
		StatName = "Tackles",
		StoreKey = "Tackles",
		Title = "Top Tackles",
		TvTitle = "MOST TACKLES",
		IsTimer = false,
	},
}

local BOARD_TYPE_ALIASES: {[string]: BoardType} = {
	touchdowns = "Touchdowns",
	wins = "Wins",
	pass = "Pass",
	timer = "Timer",
	tackles = "Tackles",
	taclkes = "Tackles",
}

local STAT_TO_BOARD: {[string]: BoardType} = {
	Touchdowns = "Touchdowns",
	Wins = "Wins",
	Passing = "Pass",
	Timer = "Timer",
	Tackles = "Tackles",
}

local function ClampValue(Value: any): number
	local NumericValue: number = tonumber(Value) or 0
	return math.max(math.floor(NumericValue), 0)
end

local function FormatTimer(Value: number): string
	local TotalHours: number = math.floor(ClampValue(Value) / HOUR_SECONDS)
	local Days: number = math.floor(TotalHours / DAY_HOURS)
	local Hours: number = TotalHours % DAY_HOURS
	return string.format("%03dd : %02dh", Days, Hours)
end

function RankStats.GetBoardTypes(): {BoardType}
	return table.clone(BOARD_TYPES)
end

function RankStats.GetStatNames(): {StatName}
	return table.clone(STAT_NAMES)
end

function RankStats.NormalizeBoardType(TypeValue: any): BoardType?
	if typeof(TypeValue) ~= "string" then
		return nil
	end

	local AliasBoardType: BoardType? = BOARD_TYPE_ALIASES[string.lower(TypeValue)]
	if AliasBoardType then
		return AliasBoardType
	end

	local Definition: BoardDef? = BOARD_DEFS[TypeValue]
	if not Definition then
		return nil
	end

	return Definition.BoardType
end

function RankStats.GetBoardDef(TypeValue: string): BoardDef?
	local BoardType: BoardType? = RankStats.NormalizeBoardType(TypeValue)
	if not BoardType then
		return nil
	end

	return BOARD_DEFS[BoardType]
end

function RankStats.GetBoardTitle(TypeValue: string, Variant: BoardDisplayVariant?): string
	local Definition: BoardDef? = RankStats.GetBoardDef(TypeValue)
	if not Definition then
		if Variant == "Tv" then
			return string.upper("Most " .. tostring(TypeValue))
		end

		return "Top " .. tostring(TypeValue)
	end

	if Variant == "Tv" then
		return Definition.TvTitle
	end

	return Definition.Title
end

function RankStats.GetBoardTypeFromStatName(StatValue: string): BoardType?
	return STAT_TO_BOARD[StatValue]
end

function RankStats.IsTrackedStat(StatValue: string): boolean
	return STAT_TO_BOARD[StatValue] ~= nil
end

function RankStats.ClampValue(Value: any): number
	return ClampValue(Value)
end

function RankStats.FormatScore(TypeValue: string, Value: number): string
	local Definition: BoardDef? = RankStats.GetBoardDef(TypeValue)
	if not Definition then
		return tostring(ClampValue(Value))
	end

	if Definition.IsTimer then
		return FormatTimer(Value)
	end

	return tostring(ClampValue(Value))
end

return RankStats
