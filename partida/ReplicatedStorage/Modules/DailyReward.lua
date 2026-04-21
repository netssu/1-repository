
local RewardDays = {
	[1] = {
		Type = "Gems",
		Value = 50
	},
	[2] = {
		Type = "Gems",
		Value = 60
	},
	[3] = {
		Type = "Gems",
		Value = 70
	},
	[4] = {
		Type = "Gems",
		Value = 85
	},
	[5] = {
		Type = "Gems",
		Value = 100
	},
	[6] = {
		Type = "Lucky Crystal",
		Value = 1
	},
	[7] = {
		Type = "TraitPoint",
		Value = 5
	},
}


local DailyRewards = {}
function DailyRewards.Claim(player)	--remote function invoke connect from DatastoreHandler
	if not player:FindFirstChild("DataLoaded") then repeat task.wait() until player:FindFirstChild("DataLoaded") end


	if (os.time() - player.DailyRewards.LastClaimTime.Value) < (3600 * 24) then return false end
	
	local nextClaim = player.DailyRewards.NextClaim.Value
	local dayReward = RewardDays[nextClaim]

	local BasicReward = {"Gems", "Coins", "TraitPoint"}
	if table.find(BasicReward, dayReward.Type) then
		if dayReward.Type == "Gems" and player.OwnGamePasses["x2 Gems"].Value then
			player[dayReward.Type].Value += (dayReward.Value*2)
		else
			player[dayReward.Type].Value += dayReward.Value
		end
	else

		if dayReward.Type == "Lucky Crystal" then
			player.Items[dayReward.Type].Value += dayReward.Value
		end

	end

	player.DailyRewards.NextClaim.Value = (nextClaim < 7 and nextClaim + 1) or 1
	player.DailyRewards.LastClaimTime.Value = os.time()

	return true

end

function DailyRewards.GetTimeUntilClaim(player, day)	--return how many seconds left until claimable
	-- if no day is specify, it will return the next claimable day
	if not player:FindFirstChild("DataLoaded") then repeat task.wait() until player:FindFirstChild("DataLoaded") end
	local nextClaimValue = player.DailyRewards.NextClaim.Value
	day = day or nextClaimValue

	if day < nextClaimValue then
		return 0
	else
		local dayDifference = (day - nextClaimValue)
		local timeDifferenceFromLastClaim = os.time() - player.DailyRewards.LastClaimTime.Value
		local timeUntil = (timeDifferenceFromLastClaim < (3600 * 24) and ( (3600 * 24) - timeDifferenceFromLastClaim) ) or 0
		return timeUntil + ( 3600 * (24 * dayDifference) )
	end


end

return DailyRewards