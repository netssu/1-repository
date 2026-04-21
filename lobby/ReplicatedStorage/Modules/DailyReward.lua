local RewardDays = {	
	[1] = { Type = "Gems", Value = 550},	
	[2] = { Type = "TraitPoint", Value = 45 },	
	[3] = { Type = "Lucky Crystal", Value = 4 }, -- Epic	
	[4] = { Type = "Gems", Value = 700 },	
	[5] = { Type = "TraitPoint", Value = 55 },	
	[6] = { Type = "Fortunate Crystal", Value = 2 },	
	[7] = { Type = "Mythic Unit", Value = 1 }, -- Legendary	
	[8] = { Type = "Gems", Value = 3000 },	
	[9] = { Type = "TraitPoint", Value = 50 },	
	[10] = { Type = "Lucky Crystal", Value = 3 },	
	[11] = { Type = "Gems", Value = 4500 },	
	[12] = { Type = "TraitPoint", Value = 85 },	
	[13] = { Type = "Fortunate Crystal", Value =  6 },	
	[14] = { Type = "Mythic Unit", Value = 1 },	 -- Mythic
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DailyRewards = {}
local Rarity_ = nil
local Functions = {
	["Epic Unit"] = function ()
		local Epic = {}
		local EpicUnits = ReplicatedStorage.Upgrades.Epic
		for i,v in EpicUnits:GetChildren() do
			table.insert(Epic, v.Name)
		end
		local random = math.random(1, #Epic)
		local NewUnit = Epic[random]		
		return NewUnit
	end,
	
	["Legendary Unit"] = function ()
		local Legendary = {}
		local LegendaryUnits = ReplicatedStorage.Upgrades.Legendary
		for i,v in LegendaryUnits:GetChildren() do
			table.insert(Legendary, v.Name)
		end
		local random = math.random(1, #Legendary)
		local NewUnit = Legendary[random]		
		return NewUnit
	end,
	
	["Mythic Unit"] = function ()
		local Mythic = {"Kit Fishto", "Dart Raiven", "Wisest Jedai", "Hired Killer","Commander Codi 222th","Count", "Dart Mol", "Jedai Kenobi", "Lyk Skaivoker", "Mace Vindy", "Plooo", "Wisest Jedai"} 	
		local random = math.random(1, #Mythic)
		local NewUnit = Mythic[random]		
		return NewUnit, "Mythical"
	end,
}
local Debounce = false

function DailyRewards.Claim(player)
	if Debounce then return end
	Debounce = true

	if not player:FindFirstChild("DataLoaded") then
		repeat task.wait() until player:FindFirstChild("DataLoaded")
	end

	if (os.time() - player.DailyRewards.LastClaimTime.Value) < (3600 * 24) then
		Debounce = false
		return false
	else
		print("Not Enough Time")
	end

	local nextClaim = player.DailyRewards.NextClaim.Value or 1
	local dayIndex = ((nextClaim - 1) % 7) + 1
	local dayReward = RewardDays[dayIndex]
	local UnitClaimed = false
	local Unit = nil

	local BasicReward = {"Gems", "Coins", "TraitPoint", "LuckySpins", "Epic Unit", "Legendary Unit", "Mythic Unit"}
	if table.find(BasicReward, dayReward.Type) then
		if string.find(string.lower(dayReward.Type), "unit") then
			local NewUnit, Rarity = Functions[dayReward.Type]()
			warn(NewUnit)
			UnitClaimed = true
			_G.createTower(player.OwnedTowers, NewUnit)
			Unit = NewUnit
			Rarity_ = Rarity
		end
		if dayReward.Type == "Gems" and player.OwnGamePasses["x2 Gems"].Value then
			player[dayReward.Type].Value += (dayReward.Value * 2)
		else
			if not UnitClaimed then
				player[dayReward.Type].Value += dayReward.Value
			end
		end
	else
		if dayReward.Type == "Lucky Crystal" or dayReward.Type == "Fortunate Crystal" then
			player.Items[dayReward.Type].Value += dayReward.Value
		end
	end

	player.DailyRewards.NextClaim.Value = nextClaim + 1
	player.DailyRewards.LastClaimTime.Value = os.time()

	
	
	if UnitClaimed then
		Debounce = false
		return true, Unit, Rarity_
	end
	Debounce = false
	return true, false
end


function DailyRewards.GetTimeUntilClaim(player, day)
	if not player:FindFirstChild("DataLoaded") then repeat task.wait() until player:FindFirstChild("DataLoaded") end

	local nextClaimValue = player.DailyRewards.NextClaim.Value or 1
	day = day or nextClaimValue

	if day < nextClaimValue then
		return 0
	else
		local dayDifference = day - nextClaimValue
		local timeDifferenceFromLastClaim = os.time() - player.DailyRewards.LastClaimTime.Value
		local timeUntil = (timeDifferenceFromLastClaim < (3600 * 24) and ((3600 * 24) - timeDifferenceFromLastClaim)) or 0
		return timeUntil + (3600 * 24 * dayDifference)
	end
end

return DailyRewards
