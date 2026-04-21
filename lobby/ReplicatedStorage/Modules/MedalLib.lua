local module = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Remotes = ReplicatedStorage:WaitForChild('Remotes') -- wait for other script to insert remotes folder :P
local RunService = game:GetService('RunService')

local HTTPService = game:GetService('HttpService')
local URL = ''
local Endpoint = '/api/v1/event/invoke'

local base64 = require(script.base64)

function module.triggerClip(eventId: string, eventName: string, players: table, triggerActions: table, clipOptions: table, contextTags: table)
	local newPlayers = {}
	
	for i,v in pairs(players) do
		if v:IsA('Player') then
			local data = {}

			data.playerId = v.UserId
			data.playerName = v.Name

			table.insert(newPlayers, data)
		end
	end
	
	local payload = {
		universeId = game.GameId,

		gameEvent = {
			eventId = eventId,
			eventName = eventName,
			otherPlayers = newPlayers,
			triggerActions = triggerActions,
			clipOptions = clipOptions,
			contextTags = contextTags,
		}
	}

    if not RunService:IsStudio() then
        print('[_MAPIEvent][v1/event/invoke] ' .. base64.Encode(HTTPService:JSONEncode(payload)))
    end
end

return module