local DataStoreService = game:GetService("DataStoreService")
local ELODatastore = DataStoreService:GetOrderedDataStore('ELO')

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Variables = require(ServerScriptService.Main.Round.Variables)
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost)
local RewardProcessing = require(script.Parent.RewardProcessing)


local ReceiveRewardsEvent = ReplicatedStorage.Events.Client.ReceiveRewards
local info = workspace.Info

return function(player: Player)
	print("game ended in versus or comp")
	
	local rewards = {}
	if not Variables.gemCounts[player] then
		local amount = info.Wave.Value * 5 * 5
		Variables.gemCounts[player] = amount
	end
	
	rewards['Gems'] = math.round(Variables.gemCounts[player] * GetPlayerBoost(player, "Gems") or 1)
	rewards["Items"] = {}
	task.spawn(function()
		rewards["Items"][Variables.ActStats.ItemReward] = math.floor(Variables.CurrentRound/10)
	end)
	rewards["OwnedTowers"] = {}
	task.spawn(function()
		player.Items[Variables.ActStats.ItemReward].Value += rewards["Items"][Variables.ActStats.ItemReward]
	end)
	
	player.Gems.Value += rewards["Gems"]
	
	local RankedPoints = info.Wave.Value
	
	if info.Competitive.Value and player.Team then
		local ELOCalculated = 0
		
		if info.Wave.Value > 25 then
			ELOCalculated += 5 -- performance bonus
		end
		
		if player.Team.Name == info.WinningTeam.Value then
			ELOCalculated += 20
			rewards['Gems'] *= 1.2
			rewards['Gems'] = math.round(rewards['Gems'])
		else
			ELOCalculated -= 20
		end
		
		-- player.ELO.Value == elo
		local oldELO = player.ELO.Value
		player.ELO.Value = math.max(0, player.ELO.Value + ELOCalculated)
		
		pcall(function()
			ELODatastore:SetAsync(player.UserId, player.ELO.Value)
		end)
		
		rewards['CompReward'] = {
			OldELO = oldELO,
			ELO = ELOCalculated	
		}
		rewards['RankedPoints'] = math.round(RankedPoints)
	else
		rewards['RankedPoints'] = math.round(RankedPoints/2)
	end
	
	player['RankedPoints'].Value += rewards['RankedPoints']

	ReceiveRewardsEvent:FireClient(player,rewards,true)
	
	RewardProcessing(player)
end