--!strict

local MatchPlayerUtils = require(script.Parent.MatchPlayerUtils)

local LOBBY_TRACK_ID: number = 122946357438094
local FIELD_TRACK_ID: number = 91008630235421

local MusicIds = {
	Lobby = LOBBY_TRACK_ID,
	Game = FIELD_TRACK_ID,
	Field = FIELD_TRACK_ID,
}

function MusicIds.GetLobbyTrackId(): number
	return LOBBY_TRACK_ID
end

function MusicIds.GetFieldTrackId(): number
	return FIELD_TRACK_ID
end

function MusicIds.GetTargetTrackId(Player: Player?): number
	if MatchPlayerUtils.IsPlayerActive(Player) then
		return FIELD_TRACK_ID
	end

	return LOBBY_TRACK_ID
end

return MusicIds
