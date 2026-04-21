local ReplicatedStorage = game:GetService("ReplicatedStorage")
local bpConfig = {}

local function parseDate(dateString)
	local day, month, year = dateString:match("(%d+)/(%d+)/(%d+)")
	return tonumber(year), tonumber(month), tonumber(day)
end

function bpConfig.GetSeason()
	local now = os.time(os.date("!*t"))
	local seasons = {}
	for seasonNum, dateStr in pairs(bpConfig.Dates) do
		local y, m, d = parseDate(dateStr)
		local timestamp = os.time{year = y, month = m, day = d, hour = 0, min = 0, sec = 0}
		table.insert(seasons, {season = seasonNum, timestamp = timestamp})
	end
	table.sort(seasons, function(a,b) return a.timestamp < b.timestamp end)
	if now < seasons[1].timestamp then
		return 1
	end
	for i = 1, #seasons do
		local current = seasons[i]
		local nextSeason = seasons[i + 1]
		if not nextSeason then
			return current.season
		end
		if now >= current.timestamp and now < nextSeason.timestamp then
			return current.season
		end
	end
	return 1
end

function bpConfig.SeasonDuration()
	local now = os.time(os.date("!*t"))
	local seasons = {}
	for seasonNum, dateStr in pairs(bpConfig.Dates) do
		local y, m, d = parseDate(dateStr)
		local timestamp = os.time{year = y, month = m, day = d, hour = 0, min = 0, sec = 0}
		table.insert(seasons, {season = seasonNum, timestamp = timestamp})
	end
	table.sort(seasons, function(a,b) return a.timestamp < b.timestamp end)

	local currentSeason = bpConfig.GetSeason()

	local nextSeasonTimestamp

	if currentSeason == 1 then
		nextSeasonTimestamp = seasons[1].timestamp
	else
		for i = 1, #seasons do
			if seasons[i].season == currentSeason then
				nextSeasonTimestamp = seasons[i + 1] and seasons[i + 1].timestamp
				break
			end
		end
	end

	if not nextSeasonTimestamp then
		return "No upcoming season"
	end

	local diff = nextSeasonTimestamp - now
	if diff <= 0 then
		return "0 Days 0 Hours 0 Minutes 0 Seconds"
	end

	local days = math.floor(diff / 86400)
	diff = diff % 86400
	local hours = math.floor(diff / 3600)
	diff = diff % 3600
	local minutes = math.floor(diff / 60)
	local seconds = diff % 60

	return string.format("%d Days %d Hours %d Minutes %d Seconds", days, hours, minutes, seconds)
	
end

bpConfig.Dates = {
	[2] = "31/05/2025",
	[3] = "01/07/2025",
}

bpConfig.Tiers = {
	[2] = {
		[1] = { Free = { Title = 'Gems' , Amount = 150 } , Premium = { Title = 'Gems' , Amount = 1000 } },
		[2] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 10 } },
		[3] = { Free = { Title = 'Gems' , Amount = 200 } , Premium = { Title = 'Gems' , Amount = 2000 } },
		[4] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 2 } },
		[5] = { Free = { Title = 'Gems' , Amount = 250 } , Premium = { Title = 'Gems' , Amount = 2500  } },
		[6] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[7] = { Free = { Title = 'Lucky Crystal' , Amount = 1 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[8] = { Free = { Title = 'Gems' , Amount = 300 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[9] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[10] = { Free = { Title = 'LuckySpins' , Amount = 1 } , Premium = { Title = 'LuckySpins' , Amount = 2 } },
		--
		[11] = { Free = { Title = 'Gems' , Amount = 350 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[12] = { Free = { Title = 'RaidsRefresh' , Amount = 1 } , Premium = { Title = 'RaidsRefresh' , Amount = 2 } },
		[13] = { Free = { Title = 'Fortunate Crystal' , Amount = 1 } , Premium = { Title = 'Fortunate Crystal' , Amount = 2 } },
		[14] = { Free = { Title = 'Gems' , Amount = 400 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[15] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[16] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 3 } },
		[17] = { Free = { Title = 'Gems' , Amount = 450 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[18] = { Free = { Title = 'Junk Offering' , Amount = 1 } , Premium = { Title = 'Junk Offering' , Amount = 2 } },
		[19] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[20] = { Free = { Title = 'Gems' , Amount = 500 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		--
		[21] = { Free = { Title = 'Lucky Crystal' , Amount = 2 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[22] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[23] = { Free = { Title = 'Gems' , Amount = 550 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[24] = { Free = { Title = '2x Gems' , Amount = 1 } , Premium = { Title = '2x Gems' , Amount = 2 } },
		[25] = { Free = { Title = 'TraitPoint' , Amount = 10 } , Premium = { Title = 'TraitPoint' , Amount = 50 } },
		[26] = { Free = { Title = 'Gems' , Amount = 600 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[27] = { Free = { Title = 'Junk Offering' , Amount = 2 } , Premium = { Title = 'Junk Offering' , Amount = 5 } },
		[28] = { Free = { Title = 'Gems' , Amount = 1250 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[29] = { Free = { Title = 'LuckySpins' , Amount = 10 } , Premium = { Title = 'LuckySpins' , Amount = 10 } },
		[30] = { Free = { Title = 'Grand Interrupter' , Amount = 1, Special = "Unit" } , Premium = { Title = 'SHINY Grand Interrupter' , Amount = 1, Special = "Unit" } },
	},
	
	[3] = {
		[1] = { Free = { Title = 'Gems', Amount = 150 }, Premium = { Title = 'Gems', Amount = 1000 } },
		[2] = { Free = { Title = 'TraitPoint', Amount = 5 }, Premium = { Title = 'TraitPoint', Amount = 25 } },
		[3] = { Free = { Title = 'Gems', Amount = 200 }, Premium = { Title = 'Gems', Amount = 1000 } },
		[4] = { Free = { Title = '2x Coins', Amount = 1 }, Premium = { Title = '2x Coins', Amount = 5 } },
		[5] = { Free = { Title = 'Gems', Amount = 250 }, Premium = { Title = 'Gems', Amount = 2500 } },
		[6] = { Free = { Title = '2x XP', Amount = 1 }, Premium = { Title = '2x XP', Amount = 5 } },
		[7] = { Free = { Title = 'Lucky Crystal', Amount = 1 }, Premium = { Title = 'Lucky Crystal', Amount = 5 } },
		[8] = { Free = { Title = 'Gems', Amount = 300 }, Premium = { Title = 'Gems', Amount = 2500 } },
		[9] = { Free = { Title = 'TraitPoint', Amount = 5 }, Premium = { Title = 'TraitPoint', Amount = 50 } },
		[10] = { Free = { Title = 'LuckySpins', Amount = 1 }, Premium = { Title = 'LuckySpins', Amount = 5 } },
		[11] = { Free = { Title = 'Gems', Amount = 350 }, Premium = { Title = 'Gems', Amount = 700 } },
		[12] = { Free = { Title = 'RaidsRefresh', Amount = 1 }, Premium = { Title = 'RaidsRefresh', Amount = 5 } },
		[13] = { Free = { Title = 'Fortunate Crystal', Amount = 1 }, Premium = { Title = 'Fortunate Crystal', Amount = 5 } },
		[14] = { Free = { Title = 'Gems', Amount = 400 }, Premium = { Title = 'Gems', Amount = 5000 } },
		[15] = { Free = { Title = 'TraitPoint', Amount = 5 }, Premium = { Title = 'TraitPoint', Amount = 100 } },
		[16] = { Free = { Title = '2x Coins', Amount = 1 }, Premium = { Title = '2x Coins', Amount = 5 } },
		[17] = { Free = { Title = 'Gems', Amount = 450 }, Premium = { Title = 'Gems', Amount = 5000 } },
		[18] = { Free = { Title = 'Junk Offering', Amount = 1 }, Premium = { Title = 'Junk Offering', Amount = 5 } },
		[19] = { Free = { Title = '2x XP', Amount = 1 }, Premium = { Title = '2x XP', Amount = 2 } },
		[20] = { Free = { Title = 'Gems', Amount = 500 }, Premium = { Title = 'Gems', Amount = 10000 } },
		[21] = { Free = { Title = 'Lucky Crystal', Amount = 2 }, Premium = { Title = 'Lucky Crystal', Amount = 5 } },
		[22] = { Free = { Title = 'TraitPoint', Amount = 5 }, Premium = { Title = 'TraitPoint', Amount = 100 } },
		[23] = { Free = { Title = 'Gems', Amount = 550 }, Premium = { Title = 'Gems', Amount = 10000 } },
		[24] = { Free = { Title = '2x Gems', Amount = 1 }, Premium = { Title = '2x Gems', Amount = 5 } },
		[25] = { Free = { Title = 'TraitPoint', Amount = 10 }, Premium = { Title = 'TraitPoint', Amount = 100 } },
		[26] = { Free = { Title = 'Gems', Amount = 600 }, Premium = { Title = 'Gems', Amount = 5000 } },
		[27] = { Free = { Title = 'Junk Offering', Amount = 2 }, Premium = { Title = 'Junk Offering', Amount = 5 } },
		[28] = { Free = { Title = 'Gems', Amount = 1250 }, Premium = { Title = 'Gems', Amount = 5000 } },
		[29] = { Free = { Title = 'LuckySpins', Amount = 10 }, Premium = { Title = 'LuckySpins', Amount = 25 } },
		[30] = { Free = { Title = 'Bo Kotan', Amount = 1, Special = "Unit" }, Premium = { Title = 'SHINY Bo Kotan', Amount = 1, Special = "Unit" } },
	},

}


function bpConfig.ExpReq(tier)
	return math.round((tier * 30) ^ 1.05)
end

function bpConfig.generateInfiniteRewards(player)
	local function getRandomRewardAmounts()
		return {
			["Gems"] = {Free = math.random(250, 750), Premium = math.random(1000, 3000)},
			["TraitPoint"] = {Free = math.random(1, 10), Premium = math.random(5, 30)},
			["Junk Offering"] = {Free = math.random(1, 3), Premium = math.random(1, 5)},
			["LuckySpins"] = {Free = math.random(1, 5), Premium = math.random(3, 8)},
			["Coins"] = {Free = math.random(500, 1000), Premium = math.random(2000, 5000)},
			["Lucky Crystal"] = {Free = math.random(1, 2), Premium = math.random(1, 4)},
			["Fortunate Crystal"] = {Free = math.random(1, 1), Premium = math.random(1, 2)},
			["2x Gems"] = {Free = 1, Premium = math.random(1, 2)},
			["2x XP"] = {Free = 1, Premium = math.random(1, 2)},
			["2x Coins"] = {Free = 1, Premium = math.random(1, 2)},
			["RaidsRefresh"] = {Free = 1, Premium = math.random(1, 1)},
		}
	end


	local bpData = player.BattlepassData
	local infTiers = bpData.InfiniteRewards
	local tier = bpData.Tier
	local finalTier = #bpConfig.Tiers[bpConfig.GetSeason()]

	if tier.Value <= finalTier then
		warn("Player not over max tier")
		return
	end

	local highestInfTier = finalTier
	for _, child in pairs(infTiers:GetChildren()) do
		if child.Name:match("^Tier(%d+)$") then
			local num = tonumber(child.Name:sub(5))
			if num and num > highestInfTier then
				highestInfTier = num
			end
		end
	end

	for i = highestInfTier + 1, tier.Value do
		if not infTiers:FindFirstChild("Tier"..i) then
			local newTier = Instance.new("Folder")
			newTier.Name = "Tier"..i
			newTier.Parent = infTiers

			local rewardsTable = getRandomRewardAmounts()

			local rewardNames = {}
			for name in pairs(rewardsTable) do
				table.insert(rewardNames, name)
			end
			local chosenRewardName = rewardNames[math.random(#rewardNames)]

			local rewardValue = Instance.new("StringValue")
			rewardValue.Name = "Reward"
			rewardValue.Value = chosenRewardName
			rewardValue.Parent = newTier

			local freeFolder = Instance.new("Folder")
			freeFolder.Name = "Free"
			freeFolder.Parent = newTier

			local freeAmount = Instance.new("IntValue")
			freeAmount.Name = "Amount"
			freeAmount.Value = rewardsTable[chosenRewardName].Free
			freeAmount.Parent = freeFolder

			local freeClaimed = Instance.new("BoolValue")
			freeClaimed.Name = "Claimed"
			freeClaimed.Value = false
			freeClaimed.Parent = freeFolder

			local premiumFolder = Instance.new("Folder")
			premiumFolder.Name = "Premium"
			premiumFolder.Parent = newTier

			local premiumAmount = Instance.new("IntValue")
			premiumAmount.Name = "Amount"
			premiumAmount.Value = rewardsTable[chosenRewardName].Premium
			premiumAmount.Parent = premiumFolder

			local premiumClaimed = Instance.new("BoolValue")
			premiumClaimed.Name = "Claimed"
			premiumClaimed.Value = false
			premiumClaimed.Parent = premiumFolder
		end
	end

end


function bpConfig.ClaimInfiniteReward(player, tier, isPremium)
	local bpData = player.BattlepassData
	local infTiers = bpData.InfiniteRewards
	local currentTier = bpData.Tier
	local finalTier = #bpConfig.Tiers[bpConfig.GetSeason()]
	
	if currentTier.Value <= finalTier then warn("Player not over max tier") return end
	
	local tierFolder = infTiers:FindFirstChild("Tier"..tier)
	if not tierFolder then warn("tier fol nf") return end
	
	local stat = player:FindFirstChild(tierFolder.Reward.Value) or player.Items:FindFirstChild(tierFolder.Reward.Value)
	if not stat then
		warn("stat: "..tierFolder.Reward.Value.." nf")
		return
	end
	
	if isPremium then
		if tierFolder.Premium.Claimed.Value then return end
		
		stat.Value += tierFolder.Premium.Amount.Value
		tierFolder.Premium.Claimed.Value = true
	else
		if tierFolder.Free.Claimed.Value then return end
		
		stat.Value += tierFolder.Free.Amount.Value
		tierFolder.Free.Claimed.Value = true
	end
end


local EpisodeConfig = require(ReplicatedStorage.EpisodeConfig)

-- usage: bpConfig.generateNewQuests("Tosuoii")
-- if it returns a table then it has refreshed quests
-- if it doesnt, then it doesnt need refreshing
-- You guys need to have some main while task.wait(1) loop that will automatically call this function
function bpConfig.generateNewQuests(plr, forceRefresh) -- forceRefresh for dev product i guess
	-- 84600 seconds in a day
	if plr.BattlepassData.NextRefresh2.Value <= os.time() or forceRefresh then
		local tasks = {}
		local usedIDs = {}
		local cachedQuests = table.clone(EpisodeConfig.EpisodeData[1].Tasks)

		while #tasks < 6 and #cachedQuests > 0 do
			local num = math.random(#cachedQuests)
			local selected = cachedQuests[num]

			if not usedIDs[selected.UniqueID] then
				table.insert(tasks, selected)
				table.insert(usedIDs, selected)
			end

			table.remove(cachedQuests, num) 
		end

		plr.BattlepassData.NextRefresh2.Value = os.time() + 86400
		return tasks
	end
end



return bpConfig
