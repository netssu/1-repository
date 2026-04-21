local ServerScriptService = game:GetService("ServerScriptService")
local module = {}

local ScheduleLib = require(ServerScriptService.ClanService.ClansHandler.ScheduleLib)
local DataStoreService = game:GetService("DataStoreService")
local RewardsService = require(ServerScriptService.ClanService.ClansHandler.RewardsService)


local function calendarMonthsSinceEpoch()
	local now = os.date("*t", tick())
	return (now.year - 1970) * 12 + (now.month - 1)
end

local GemsLBDS2 = DataStoreService:GetOrderedDataStore('ClanVault' .. calendarMonthsSinceEpoch())
local KillsLBDS2 = DataStoreService:GetOrderedDataStore('ClanKills' .. calendarMonthsSinceEpoch())
local XPLBDS2 = DataStoreService:GetOrderedDataStore('ClanXP' .. calendarMonthsSinceEpoch())

local GemsLBDS = DataStoreService:GetOrderedDataStore('ClanVault') -- temp, delete after 5.0
local KillsLBDS = DataStoreService:GetOrderedDataStore('ClanKills') -- same here
local XPLBDS = DataStoreService:GetOrderedDataStore('ClanXP') -- same here

local Clans = DataStoreService:GetDataStore('Clans')

local smallestFirst = false
local numberToShow = 100
local minValue = 1 
local maxValue = 10e30

local Rewards = {
	[1] = {
		TraitPoint = 250,
		LuckySpins = 50,
		PrestigeTokens = 5,
	},
	[2] = {
		TraitPoint = 250,
		LuckySpins = 50,
		PrestigeTokens = 5,
	},
	[3] = {
		TraitPoint = 250,
		LuckySpins = 50,
		PrestigeTokens = 5
	},
	[4] = {
		TraitPoint = 150,
		LuckySpins = 30,
		PrestigeTokens = 3
	},
	[11] = {
		TraitPoint = 100,
		LuckySpins = 15,
		PrestigeTokens = 1
	},
	[26] = {
		TraitPoint = 60,
		LuckySpins = 5
	}
}

local processingFunctions = {
	['Currency'] = function(currency, amount)
		local transformFunc = function(data)

			for i,v in data.Members do	
				if not data.PendingRewards[i] then
					data.PendingRewards[i] = {}
				end

				local awardData = {
					Name = currency,
					Type = 'Currency',
					Amount = amount
				}

				table.insert(data.PendingRewards[i], awardData)
			end

			return data
		end
		
		return transformFunc
	end,
	['Tower'] = function(unit, isShiny)
		local transformFunc = function(data)

			for i,v in data.Members do	
				if not data.PendingRewards[i] then
					data.PendingRewards[i] = {}
				end

				local awardData = {
					Name = unit,
					Type = 'Tower',
					Shiny = isShiny
				}

				table.insert(data.PendingRewards[i], awardData)
			end

			return data
		end

		return transformFunc
	end,
}

function getClosestLowerValue(number)
	local closestKey = nil
	for k in pairs(Rewards) do
		if k <= number and (closestKey == nil or k > closestKey) then
			closestKey = k
		end
	end
	return closestKey and Rewards[closestKey] or nil
end


local limit = 51

local function grantRewardToLB(DB)
	-- Reward Gems :D
	local pages = DB:GetSortedAsync(smallestFirst, numberToShow, minValue, maxValue)

	--Get data
	local top = pages:GetCurrentPage()--Get the first page

	for pos ,v in ipairs(top) do--Loop through data
		if pos == limit then break end -- no more rewards HAHAHHAHAHAHAH
		if pos ~= 2 then continue end
		task.wait(1.5)
		local clan = v.key--ClanName
		-- pos = number
		-- clan = 
		
		warn(`Giving reward to {clan} in position {pos}`)

		local rewards = getClosestLowerValue(pos)


		local transformFunc = function(source)
			for reward, amount in pairs(rewards) do
				local transform = processingFunctions.Currency(reward, amount)
				source = transform(source)
			end
			
			
			if pos == 1 then
				local transform = processingFunctions.Tower('Hans', true)
				source = transform(source)
			elseif pos == 2 then
				local transform = processingFunctions.Tower('Hans', false)
				source = transform(source)
			end

			return source
		end
		local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)
		
		if success and success.Success then
			warn(`Success for clan: {clan}`)
		else
			warn('ERROR!')
			warn(success)
			warn(success.Message)
		end
		
		break -- REMEMBER THIS
	end
end

local function resetLB(DB: DataStore , target: DataStore, LBType)
	-- Reward Gems :D
	local pages = DB:GetSortedAsync(smallestFirst, numberToShow, minValue, maxValue)

	--Get data
	local top = pages:GetCurrentPage()--Get the first page

	for pos ,v in ipairs(top) do--Loop through data
		if pos == limit then break end -- no more rewards HAHAHHAHAHAHAH
		task.wait(1.5)
		local clan = v.key--ClanName
		-- pos = number
		-- clan = 

		warn(`resetting {clan} in position {pos}`)

		local s,e = pcall(function()
			Clans:UpdateAsync(v.key, function(source)
				source.PreviousStats[LBType] = v.value
			end)
		end)
		
		
		if s then
			warn(`Success for clan: {clan}`)
		else
			warn('ERROR!')
			warn(e)
		end

	end
end

function module.giveLeaderboardRewards()
	warn('Triggered!')
	--grantRewardToLB(GemsLBDS)
	--grantRewardToLB(KillsLBDS)
	----grantRewardToLB(XPLBDS)
	--warn('[CLAN LEADERBOARD REWARDS] WE ARE DONEEEEEEEE!!!')
	
	warn('Fixing Leaderboards')
	--resetLB(GemsLBDS, GemsLBDS2, 'Vault')
	resetLB(KillsLBDS, KillsLBDS2, 'Kills')
	resetLB(XPLBDS, XPLBDS2, 'XP')
	warn('Done!')
end

script.Trigger.Changed:Connect(module.giveLeaderboardRewards)


return module