local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Variables = require(ServerScriptService.Main.Round.Variables)
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost)
local RewardProcessing = require(script.Parent.RewardProcessing)

local ReceiveRewardsEvent = ReplicatedStorage.Events.Client.ReceiveRewards
local info = workspace.Info

local givenGems = nil

return function(player)
	local rewards = {}
	
	
	if Variables.gemCounts[player] and not givenGems then
		givenGems = math.round(Variables.gemCounts[player])
	end

	--rewards['Gems'] = (givenGems * (GetPlayerBoost(player, "Gems") or 1)) + 10
	
	rewards['Gems'] = math.round((givenGems or 1) * GetPlayerBoost(player, "Gems") or 1)
	
	
	rewards["Items"] = {}
	rewards["Items"][Variables.ActStats.ItemReward] = math.floor(Variables.CurrentRound/10)
	rewards["OwnedTowers"] = Variables.infinityTowerReward
	player.Items[Variables.ActStats.ItemReward].Value += rewards["Items"][Variables.ActStats.ItemReward]
	player.Gems.Value += rewards["Gems"]

	local wavesTable = nil

	if workspace.Info.SpecialEvent.Value then
		player.EventData['YS9000'].Attempts.Value += 1
		player.EventPity.Value += 1
		if player.EventData['YS9000'].HighestWave.Value < Variables.CurrentRound then
			player.EventData['YS9000'].HighestWave.Value = Variables.CurrentRound
		end
	end

	if player.WorldStats[StoryModeStats.Worlds[game.Workspace.Info.World.Value]].InfiniteRecord.Value < Variables.CurrentRound then
		player.WorldStats[StoryModeStats.Worlds[game.Workspace.Info.World.Value]].InfiniteRecord.Value = Variables.CurrentRound
	end

	ReceiveRewardsEvent:FireClient(player,rewards,true)
	
	RewardProcessing(player)
end