local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ClanQuestsLib = require(ServerScriptService.ClanService.ClanQuestsLib)

local Tracked = {}

local module = {}

function secondsToMinutes(seconds)
	return math.round(seconds / 60)
end

Players.PlayerAdded:Connect(function(plr)
	Tracked[plr] = os.time()
end)

Players.PlayerRemoving:Connect(function(plr)
	if Tracked[plr] and plr:FindFirstChild('ClansLoaded') then
		local foundClan = ReplicatedStorage.Clans:FindFirstChild(plr.ClanData.CurrentClan.Value)
		local TimePlayed = os.time() - Tracked[plr]
		
		if foundClan then
			ClanQuestsLib.progressQuest(foundClan.Name, 'Playtime', secondsToMinutes(TimePlayed))
		end
	end
end)


return module