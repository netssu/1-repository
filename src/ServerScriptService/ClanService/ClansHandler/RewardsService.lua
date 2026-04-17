local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ScheduleLib = require(ServerScriptService.ClanService.ClansHandler.ScheduleLib)
local Players = game:GetService("Players")
local ClanShop = require(ReplicatedStorage.ClansLib.ClanShop)
local ClanTemplate = require(ServerScriptService.ClanService.ClansHandler.ClanLib.ClanTemplate)
local ScheduleLib = require(ServerScriptService.ClanService.ClansHandler.ScheduleLib)
local module = {}
type rewardData = {
	Name: string,
	Type: string,
	Shiny: boolean,
	Amount: number
}
type RewardTypes = {
	Tower: string,
	Currency: string
}
local rewardFuncs = {
	['Tower'] = function(plr, rewardData: rewardData)
		local unit = rewardData.Name
		local isShiny = rewardData.Shiny
		_G.createTower(plr.OwnedTowers, unit, nil, {Shiny = isShiny})
	end,
	['Currency'] = function(plr, rewardData: rewardData)
		print(rewardData)
		plr[rewardData.Name].Value += rewardData.Amount
	end,
	['Item'] = function(plr, rewardData: rewardData)
		plr.Items[rewardData.Name].Value += rewardData.Amount
	end,

	Towers = function(plr, rewardData: rewardData)
		local unit = rewardData.Name
		local isShiny = rewardData.Shiny
		_G.createTower(plr.OwnedTowers, unit, nil, {Shiny = isShiny})
	end,
	Currencies = function(plr, rewardData: rewardData)
		print(rewardData)
		plr[rewardData.Name].Value += rewardData.Amount
	end,
	Items = function(plr, rewardData: rewardData)
		plr.Items[rewardData.Name].Value += rewardData.Amount or 1
	end,
}
function module.processRewards(clanData)
	local rewardCache = {}
	local processedUserIds = {}
	for userId, rewards in pairs(clanData.PendingRewards) do
		local foundPlr = Players:GetPlayerByUserId(userId)
		if foundPlr then
			rewardCache[userId] = {
				player = foundPlr,
				rewards = {}
			}
			for key, reward in ipairs(rewards) do
				if rewardFuncs[reward.Type] then
					table.insert(rewardCache[userId].rewards, {
						originalKey = key,
						reward = reward
					})
				end
			end
			processedUserIds[userId] = true
		end
	end

	local transformFunction = function()
		return clanData
	end
	local success = ScheduleLib.ScheduleWriteAsync(clanData.Name, transformFunction)

	if success.Success then
		local successfullyProcessed = {}

		for userId, cachedData in pairs(rewardCache) do
			local foundPlr = cachedData.player
			if foundPlr.Parent and foundPlr:FindFirstChild('ClansLoaded') then
				for _, rewardData in ipairs(cachedData.rewards) do
					rewardFuncs[rewardData.reward.Type](foundPlr, rewardData.reward)
				end
				successfullyProcessed[userId] = true
			end
		end

		for userId in pairs(successfullyProcessed) do
			clanData.PendingRewards[userId] = nil
		end

		if next(successfullyProcessed) then
			ScheduleLib.ScheduleWriteAsync(clanData.Name, function() return clanData end)
		end
	else
		warn("Failed to save clan data for: " .. clanData.Name .. ". Rewards not given.")
	end
	return clanData
end
function module.grantReward(clanData: ClanTemplate.ClanData, UserID: string, Reward, RewardType: RewardTypes, Amount, Shiny)
	UserID = tostring(UserID)
	local rewardData = {
		Name = Reward,
		Type = RewardType,
		Amount = Amount,
		Shiny = Shiny
	}

	if not clanData.PendingRewards[UserID] then
		clanData.PendingRewards[UserID] = {}
	end

	table.insert(clanData.PendingRewards[UserID], rewardData)

	return clanData
end
function module.processDirectReward(plr, rewardData: rewardData)
	rewardFuncs[rewardData.Type](plr, rewardData)
end
return module