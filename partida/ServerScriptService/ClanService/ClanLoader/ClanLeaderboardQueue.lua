local DataStoreService = game:GetService("DataStoreService")
local ClansDataStore = DataStoreService:GetDataStore("Clans")

local function calendarMonthsSinceEpoch()
	local now = os.date("*t", tick())
	return (now.year - 1970) * 12 + (now.month - 1)
end

local Leaderboards = {
	ClanXP = DataStoreService:GetOrderedDataStore("ClanXP" .. calendarMonthsSinceEpoch()),
	ClanVault = DataStoreService:GetOrderedDataStore("ClanVault" .. calendarMonthsSinceEpoch()),
	ClanKills = DataStoreService:GetOrderedDataStore("ClanKills" .. calendarMonthsSinceEpoch())
}

local converted = {
	ClanVault = 'ClanVault',
	Vault = 'ClanVault',
	Kills = 'ClanKills',
	Level = 'ClanXP',
	XP = 'ClanXP' -- exists because im stupid
}

local module = {}

local queue = {}
module.flushInterval = 10 -- seconds
module.lastFlushTime = os.clock()

-- Add to queue
function module.addToQueue(CLAN_ID, Type, increment)
	if converted[Type] then
		Type = converted[Type]

		if not Type then
			warn('Incorrect Type passed!')
		end
	else
		warn(`Incorrect type passed! {Type}`)
	end

	if not queue[CLAN_ID] then
		queue[CLAN_ID] = {}
	end

	if not queue[CLAN_ID][Type] then
		queue[CLAN_ID][Type] = 0
	end

	queue[CLAN_ID][Type] = increment -- TOTAL
end

-- Flush function
function module.flushQueue()
	for clanId, types in pairs(queue) do
		for statType, value in pairs(types) do
			local leaderboard = Leaderboards[statType]
			if leaderboard then
				local s,e = pcall(function()
					leaderboard:UpdateAsync(clanId, function(old)
						local base = old or 0
						--if statType == 'ClanVault' then
							--base = value
						--else
							base = value
						--end
						return base
					end)
				end)

				if not s then
					task.spawn(function()
						error(e)
					end)
				end

			end
		end
	end
	table.clear(queue)
	module.lastFlushTime = os.clock()
end

return module
