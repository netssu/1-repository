-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local BpConfig = require(game.ReplicatedStorage.Configs.BattlepassConfig)
local XpHandler = require(game.ReplicatedStorage.EpisodeConfig.XPHandler)
local QuestConfig = require(game.ReplicatedStorage.Configs.QuestConfig)

-- Remotes
local ClaimBattlepassReward = ReplicatedStorage.Remotes.Quests.ClaimBattlepassReward

-- Variables
local questCap = 5

local function RefreshQuests(player, data, amount)
	local lastRefresh = data.LastRefresh
	local currentDay = os.date("*t").day
	local quests = data.Quests

	if lastRefresh.Value == currentDay then return end -- print("cant refresh") return end

	quests:ClearAllChildren()

	for i = 1,amount do
		QuestConfig.CreateQuest(player, quests, nil, true, false, "Battlepass")
	end

	lastRefresh.Value = currentDay

	return true
end

game.Players.PlayerAdded:Connect(function(player)
	repeat task.wait() until player:FindFirstChild("DataLoaded")
	
	local bpData = player:WaitForChild("BattlepassData")
	local season = bpData:WaitForChild("Season")
	
	RefreshQuests(player, bpData, 5)

	workspace:GetAttributeChangedSignal("Day"):Connect(function()
		RefreshQuests(player, bpData, 5)
	end)

	local function seasonReset()
		if season.Value ~= BpConfig.GetSeason() then
			-- Reset
			season.Value = BpConfig.GetSeason()
			bpData.Tier.Value = 1
			bpData.Exp.Value = 0
			bpData.Premium.Value = false
			bpData.InfiniteRewards:ClearAllChildren()
			bpData.TiersClaimed:ClearAllChildren()
		end
	end
	
	seasonReset()
	script.Season.Changed:Connect(seasonReset)
	
	bpData.Exp.Changed:Connect(function()
		while bpData.Exp.Value >= BpConfig.ExpReq(bpData.Tier.Value) do
			bpData.Exp.Value -= BpConfig.ExpReq(bpData.Tier.Value)
			bpData.Tier.Value += 1
		end
	end)
	
	BpConfig.generateInfiniteRewards(player)
	bpData.Tier.Changed:Connect(function()
		if bpData.Tier.Value > #BpConfig.Tiers[BpConfig.GetSeason()] then
			BpConfig.generateInfiniteRewards(player)
		end
	end)
end)

task.spawn(function() while task.wait(1) do script.Season.Value = BpConfig.GetSeason() end end)

local function rewardPlayer(player, reward)
	if not reward then return end

	if reward.Special then
		if reward.Special == "Unit" then
			local unitName = reward.Title
			local isShiny = false
			if unitName:sub(1,6) == "SHINY " then
				isShiny = true
				unitName = unitName:sub(7)
			end
			
			_G.createTower(game.Players[player.Name].OwnedTowers, unitName, nil, {Shiny = isShiny})
			print("Rewarded "..player.Name.." "..unitName.." unit")
			return true
		end
	else
		local statName = reward.Title
		local amount = tonumber(reward.Amount) or 0
		local item = player.Items:FindFirstChild(statName)

		if item then
			item.Value += reward.Amount
			print("Rewarded item")
			return true
		else
			if statName and amount > 0 then
				local stat = player:FindFirstChild(statName)
				if stat and typeof(stat.Value) == "number" then
					stat.Value += amount
					print("Rewarded "..player.Name.." "..amount.." "..statName)
					return true
				else
					warn("Player stat '"..tostring(statName).."' missing or not a number for player "..player.Name)
				end
			else
				--warn("Invalid reward data for player "..player.Name)
			end
		end
	end
end

ClaimBattlepassReward.OnServerEvent:Connect(function(player, tier, premiumClaim)
	local bpData = player.BattlepassData
	local currentTier = bpData.Tier.Value
	local isPremium = bpData.Premium.Value
	local tiersClaimed = bpData.TiersClaimed
	local rewards = BpConfig.Tiers[BpConfig.GetSeason()]


	if tier > currentTier then
		warn("Player tried to claim tier they haven't reached:", tier)
		return
	end

	if tier > #BpConfig.Tiers[BpConfig.GetSeason()] then
		local response = BpConfig.ClaimInfiniteReward(player, tier, premiumClaim)
		return response
	else
		local reward = rewards[tier]
		if not reward then
			warn("Invalid reward data for tier:", tier)
			return
		end

		local tierKey = "Tier" .. tier
		local tierFolder = tiersClaimed:FindFirstChild(tierKey)

		if not tierFolder then
			tierFolder = Instance.new("Folder")
			tierFolder.Name = tierKey
			tierFolder.Parent = tiersClaimed

			local freeBool = Instance.new("BoolValue")
			freeBool.Name = "Free"
			freeBool.Value = false
			freeBool.Parent = tierFolder

			local premiumBool = Instance.new("BoolValue")
			premiumBool.Name = "Premium"
			premiumBool.Value = false
			premiumBool.Parent = tierFolder
		end

		local freeClaimed = tierFolder:FindFirstChild("Free")
		local premiumClaimed = tierFolder:FindFirstChild("Premium")

		if not freeClaimed or not premiumClaimed then
			warn("Tier claim values missing for:", tierKey)
			return
		end

		if not premiumClaim then
			if not freeClaimed.Value and reward.Free then

				local result = rewardPlayer(player, reward.Free)
				print(result)
				freeClaimed.Value = result or false
				print("Claimed Free reward for Tier", tier)
			else
				print("Free reward already claimed or missing for Tier", tier)
			end
		else
			if not isPremium then
				print("Player does not own Premium pass")
				return
			end
			if not premiumClaimed.Value and reward.Premium then
				local result = rewardPlayer(player, reward.Premium)
				print(result)
				premiumClaimed.Value = result or false
				print("Claimed Premium reward for Tier", tier)
			else
				print("Premium reward already claimed or missing for Tier", tier)
			end
		end
	end
end)
