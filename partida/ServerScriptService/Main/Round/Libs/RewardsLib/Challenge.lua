local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Variables = require(ServerScriptService.Main.Round.Variables)
local info = workspace.Info
local ChallengeModule = require(ReplicatedStorage.Modules.ChallengeModule)
local ReceiveRewardsEvent = ReplicatedStorage.Events.Client.ReceiveRewards

return function(player)
	local challengeData = ChallengeModule.Data[Variables.challenge]
	local receiveRewards = ChallengeModule.Rewards[challengeData.Difficulty].Give(player)
	player.LastChallengeCompletedUniqueId.Value = info.ChallengeUniqueId.Value
	ReceiveRewardsEvent:FireClient(player,receiveRewards)
end