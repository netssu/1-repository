--!strict

local MatchPlayerUtils = {}

local ATTR_MATCH_ACTIVE: string = "FTInMatchActive"
local MINIMUM_PLAYERS_TO_START: number = 1

function MatchPlayerUtils.GetMatchActiveAttributeName(): string
	return ATTR_MATCH_ACTIVE
end

function MatchPlayerUtils.IsPlayerActive(Player: Player?): boolean
	if not Player then
		return false
	end

	local PlayerValue: any = Player:GetAttribute(ATTR_MATCH_ACTIVE)
	if typeof(PlayerValue) == "boolean" then
		return PlayerValue
	end

	local Character: Model? = Player.Character
	if not Character then
		return false
	end

	return Character:GetAttribute(ATTR_MATCH_ACTIVE) == true
end

function MatchPlayerUtils.SetPlayerActive(Player: Player?, Active: boolean): ()
	if not Player then
		return
	end

	Player:SetAttribute(ATTR_MATCH_ACTIVE, Active)

	local Character: Model? = Player.Character
	if Character then
		Character:SetAttribute(ATTR_MATCH_ACTIVE, Active)
	end
end

function MatchPlayerUtils.GetMinimumPlayersToStart(): number
	return MINIMUM_PLAYERS_TO_START
end

return MatchPlayerUtils
