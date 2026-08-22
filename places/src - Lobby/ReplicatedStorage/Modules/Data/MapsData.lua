------------------//CONSTANTS
local MATCH_PLACE_ID: number = 128336905370673
local DEFAULT_MAP_NAME: string = "Intergalatic"

type MapDefinition = {
	Name: string,
	Description: string,
	MarkerPosition: UDim2?,
}

local MAPS: { MapDefinition } = {
	{
		Name = "Tempelhof",
		Description = "The Tempelhof Formula E track, located on the former Berlin airport, is known for its concrete surface and technical layout.",
		MarkerPosition = UDim2.fromScale(0.51, 0.245),
	},
	{
		Name = "São Paulo",
		Description = "The São Paulo Street Circuit is a fast temporary urban track around the Anhembi Sambadrome in Brazil.",
		MarkerPosition = UDim2.fromScale(0.314, 0.707),
	},
	{
		Name = "Mexico City",
		Description = "The Mexico City Formula E track combines fast corners, heavy braking zones, and the stadium section at high altitude.",
		MarkerPosition = UDim2.fromScale(0.177, 0.444),
	},
	{
		Name = "Miami",
		Description = "The Miami Formula E circuit combines long straights with technical corners and demanding energy management.",
		MarkerPosition = UDim2.fromScale(0.236, 0.397),
	},
	{
		Name = "Brainrot",
		Description = "The Brainrot Track is a limited-time racing map set in the world of Brainrots.",
		MarkerPosition = UDim2.fromScale(0.236, 0.397),
	},
	{
		Name = "Madrid",
		Description = "The Madrid Formula E track is a temporary urban circuit with fast straights, technical corners, and a stadium section.",
		MarkerPosition = UDim2.fromScale(0.528, 0.418),
	},
	{
		Name = "Intergalatic",
		Description = "The Intergalatic Track is a sci-fi racing map built for high-speed runs through a space-themed circuit.",
		MarkerPosition = nil,
	},
	{
		Name = "Shanghai",
		Description = "The Shanghai Formula E track is a high-speed urban circuit with long straights and demanding braking zones.",
		MarkerPosition = UDim2.fromScale(0.7, 0.45),
	},
	{
		Name = "Tokyo",
		Description = "The Tokyo Formula E track is a fast technical street circuit around the waterfront with tight braking zones.",
		MarkerPosition = UDim2.fromScale(0.826, 0.414),
	},
}

------------------//FUNCTIONS
local function get_map(rawMapName: any): MapDefinition?
	if type(rawMapName) ~= "string" then
		return nil
	end

	for _, map in MAPS do
		if map.Name == rawMapName then
			return map
		end
	end

	return nil
end

------------------//MAIN FUNCTIONS
local mapsData = {
	MATCH_PLACE_ID = MATCH_PLACE_ID,
	DEFAULT_MAP_NAME = DEFAULT_MAP_NAME,
	Maps = MAPS,
	get_map = get_map,
}

------------------//INIT
return mapsData
