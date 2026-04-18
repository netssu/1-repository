--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerIdentity = {}

local SESSION_ATTR = "FTSessionId"
local nextSessionId = 0
local assigned: {[Player]: number} = {}

local function assignSessionId(player: Player): number
	local existing = player:GetAttribute(SESSION_ATTR)
	if typeof(existing) == "number" and existing > 0 then
		assigned[player] = existing
		return existing
	end

	nextSessionId += 1
	local id = nextSessionId
	assigned[player] = id
	player:SetAttribute(SESSION_ATTR, id)

	local character = player.Character
	if character then
		character:SetAttribute(SESSION_ATTR, id)
	end

	player.CharacterAdded:Connect(function(newCharacter)
		newCharacter:SetAttribute(SESSION_ATTR, id)
	end)

	return id
end

function PlayerIdentity.AssignSessionId(player: Player): number?
	if not RunService:IsServer() then
		return nil
	end
	return assignSessionId(player)
end

function PlayerIdentity.GetSessionId(player: Player?): number?
	if not player then
		return nil
	end
	local value = player:GetAttribute(SESSION_ATTR)
	if typeof(value) == "number" and value > 0 then
		return value
	end
	return nil
end

function PlayerIdentity.GetIdValue(player: Player?): number
	if not player then
		return 0
	end
	local sessionId = PlayerIdentity.GetSessionId(player)
	if sessionId then
		return sessionId
	end
	if RunService:IsServer() then
		local assignedId = assignSessionId(player)
		if assignedId then
			return assignedId
		end
	end
	return player.UserId
end

function PlayerIdentity.ResolvePlayer(id: number?): Player?
	if typeof(id) ~= "number" then
		return nil
	end
	for _, player in Players:GetPlayers() do
		if PlayerIdentity.GetSessionId(player) == id then
			return player
		end
	end
	return Players:GetPlayerByUserId(id)
end

function PlayerIdentity.GetLocalIdValue(): number
	local player = Players.LocalPlayer
	if not player then
		return 0
	end
	return PlayerIdentity.GetIdValue(player)
end

return PlayerIdentity
