------------------//CONSTANTS
local TELEPORT_DATA_VERSION: number = 1
local DEFAULT_MATCH_TYPE: string = "FreeRoam"

local VALID_MAPS: { string } = {
	"Tempelhof",
	"São Paulo",
	"Mexico City",
	"Miami",
	"Brainrot",
	"Madrid",
	"Intergalatic",
	"Shanghai",
	"Tokyo",
}

type MatchData = {
	Version: number,
	MatchType: string,
	Map: string,
	SourcePlaceId: number?,
	SourceJobId: string?,
	RequestedAt: number?,
	RequestedByUserId: number?,
}

------------------//FUNCTIONS
local function is_valid_map(mapName: any): boolean
	if type(mapName) ~= "string" then
		return false
	end

	return table.find(VALID_MAPS, mapName) ~= nil
end

local function normalize(rawData: any): MatchData?
	if type(rawData) ~= "table" or not is_valid_map(rawData.Map) then
		return nil
	end

	return {
		Version = TELEPORT_DATA_VERSION,
		MatchType = if type(rawData.MatchType) == "string" then rawData.MatchType else DEFAULT_MATCH_TYPE,
		Map = rawData.Map,
		SourcePlaceId = if type(rawData.SourcePlaceId) == "number" then rawData.SourcePlaceId else nil,
		SourceJobId = if type(rawData.SourceJobId) == "string" then rawData.SourceJobId else nil,
		RequestedAt = if type(rawData.RequestedAt) == "number" then rawData.RequestedAt else nil,
		RequestedByUserId = if type(rawData.RequestedByUserId) == "number" then rawData.RequestedByUserId else nil,
	}
end

------------------//MAIN FUNCTIONS
local matchTeleportData = {
	VALID_MAPS = VALID_MAPS,
	is_valid_map = is_valid_map,
	normalize = normalize,
}

------------------//INIT
return matchTeleportData
