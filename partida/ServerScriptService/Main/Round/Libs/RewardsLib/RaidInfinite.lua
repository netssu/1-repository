local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Variables = require(ServerScriptService.Main.Round.Variables)
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost)
local RewardProcessing = require(script.Parent.RewardProcessing)

local ReceiveRewardsEvent = ReplicatedStorage.Events.Client.ReceiveRewards
local info = workspace.Info

return function(player)
	print("Player died on Raid infinite")
	local rewards = {}
	rewards['Gems'] = math.round((Variables.gemCounts[player] or Variables.CurrentRound * 4) * GetPlayerBoost(player, "Gems") or 1)
	rewards["Items"] = {}
	rewards["Items"][Variables.ActStats.ItemReward] = math.floor(Variables.CurrentRound/10)
	rewards["OwnedTowers"] = Variables.infinityTowerReward
	rewards['Credits'] = Variables.ticketCounts[player]
	player.Items[Variables.ActStats.ItemReward].Value += rewards["Items"][Variables.ActStats.ItemReward]
	player.Gems.Value += rewards["Gems"]
	player.RaidData.Credits.Value += rewards['Credits'] or 0 
	
	
	local currentRound = Variables.CurrentRound or 0
	local SpinCount = math.floor(currentRound / 100) -- 1 spin per 100 waves
	local Amount = 0

	for i = 1, SpinCount do
		Amount += math.random(2, 5)
	end

	player.TraitPoint.Value += Amount
	rewards["TraitPoint"] = Amount

	
	--Variables.CurrentRound
	
	
	


	ReceiveRewardsEvent:FireClient(player,rewards,true)

	if player.WorldStats[StoryModeStats.Worlds[game.Workspace.Info.World.Value]].InfiniteRecord.Value < Variables.CurrentRound then
		player.WorldStats[StoryModeStats.Worlds[game.Workspace.Info.World.Value]].InfiniteRecord.Value = Variables.CurrentRound
	end
	
	RewardProcessing(player)
end