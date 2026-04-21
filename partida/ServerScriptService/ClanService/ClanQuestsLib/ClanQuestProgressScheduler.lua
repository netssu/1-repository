local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Players = game:GetService("Players")
local ClanQuestsLib = require(script.Parent)

local module = {}

module.Queue = {}

function module.addToQueue(plr: Player, Type, Amount)
	if plr and Type and Amount then
		local RewardData = {
			Player = plr,
			Type = Type,
			Amount = Amount
		}
		table.insert(module.Queue, RewardData)
	end
end


function module.flushQueue()
	local Values = {}

	for _, RewardTable in ipairs(module.Queue) do
		if RewardTable.Player then
			local plr = RewardTable.Player
			local rewardType = RewardTable.Type
			local amount = RewardTable.Amount

			if not Values[plr] then
				Values[plr] = {}
			end
			if not Values[plr][rewardType] then
				Values[plr][rewardType] = 0
			end

			Values[plr][rewardType] += amount
		end
	end

	-- yeye values works all fine

	for plr, Rewards in pairs(Values) do
		for rewardType, amount in pairs(Rewards) do
			task.spawn(function()
				if plr:FindFirstChild('ClansLoaded') then
					local foundClan = ReplicatedStorage.Clans:FindFirstChild(plr.ClanData.CurrentClan.Value)
					if foundClan then
						ClanQuestsLib.progressQuest(foundClan.Name, rewardType, amount)
					end
				end
			end)
		end
	end

	module.Queue = {} -- wipe full array after processing
end



return module