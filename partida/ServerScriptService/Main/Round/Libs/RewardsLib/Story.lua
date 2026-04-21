local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local BadgeService = game:GetService("BadgeService")

local info = workspace.Info
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost)
local AchievementHandler = require(ServerStorage.ServerModules.AchievementHandler)
local QuestConfig = require(ReplicatedStorage.Configs.QuestConfig)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local RaidDataSync = require(ServerScriptService.ProfileServiceMain.Main.RaidDataSync)
local Variables = require(ServerScriptService.Main.Round.Variables)
local CurrentRaidEventMap = ReplicatedStorage.CurrentRaidEventMap.Value
local ReceiveRewardsEvent = ReplicatedStorage.Events.Client.ReceiveRewards
local RewardProcessing = require(script.Parent.RewardProcessing)

local givenGems = nil

return function(player)
	local clearTime = os.time() - Variables.startTime
	local firstTime = false
	if game.Workspace.Info.World.Value >= player.StoryProgress.World.Value and game.Workspace.Info.Level.Value >= player.StoryProgress.Level.Value then
		firstTime = true
	end

	local nextStep = 4 + ( (info.World.Value - 1) * 5 ) + info.Level.Value
	AnalyticsService:LogOnboardingFunnelStepEvent(
		player, 
		nextStep,
		`Beaten: World {info.World.Value} - Level {info.Level.Value}`
	)
	QuestConfig.UpdateProgressAll(player, "ClearActs", 1)

	if workspace.Info.Difficulty.Value == "Easy" and workspace.Info.Level.Value == 5 then
		QuestConfig.UpdateProgressAll(player, "ClearWorldsEasyQuestline", tonumber(workspace.Info.World.Value))

		-- 3rd param is the world number in ts instance, so convert the worlds to numbers and pass that instead of "1"
		-- Make sure to check for difficulty AND that its the final act
	end


	AchievementHandler.UpdateAchievementProgress(player, "finish_level", {
		AddAmount = 1,
		World = game.Workspace.Info.World.Value, 
		Level = game.Workspace.Info.Level.Value,
		Mode = game.Workspace.Info.Mode.Value
	})
	
	if info.World.Value == 2 and info.Level.Value == 5 then
		warn("Giving Badge")
		BadgeService:AwardBadge(player.UserId, 4403924743658221)
	end

	if StoryModeStats.Worlds[info.World.Value] then
		if player.WorldStats:FindFirstChild(StoryModeStats.Worlds[info.World.Value]) then
			player.WorldStats[StoryModeStats.Worlds[info.World.Value]].LevelStats["Act"..math.min(info.Level.Value,6)].Clears.Value += 1
			local oldClearTime = player.WorldStats[StoryModeStats.Worlds[info.World.Value]].LevelStats["Act"..math.min(info.Level.Value,6)].FastestTime
			if oldClearTime.Value > clearTime or oldClearTime.Value == -1 then
				oldClearTime.Value = clearTime
			end
		end
	end

	task.spawn(function()
		if info.Raid.Value then
			player.RaidPity.Value += 1
		end
	end)

	if workspace.Info.Raid.Value then
		RaidDataSync.init(player)
		local act = player.RaidActData[CurrentRaidEventMap]["Act"..math.min(info.Level.Value,6)]
		act.Completed.Value = true
		act.TotalClears.Value += 1
		local oldClearTime = act.ClearTime

		if oldClearTime.Value > clearTime or oldClearTime.Value == -1 then
			oldClearTime.Value = clearTime
		end
	end

	local rewards = {}

	if Variables.gemCounts[player] and not givenGems then
		givenGems = math.round(Variables.gemCounts[player]) + 50
	end
	
	rewards['Gems'] = givenGems * GetPlayerBoost(player, "Gems")
	
	
	
	
	
	rewards["Items"] = {}
	if Variables.ActStats.ItemReward and rewards.Items[Variables.ActStats.ItemReward] then
		rewards["Items"][Variables.ActStats.ItemReward] = math.floor(Variables.CurrentRound/10)
		player.Items[Variables.ActStats.ItemReward].Value += rewards["Items"][Variables.ActStats.ItemReward]
	end

	--warn('SERVER SIDE, BONIFIED REWARDS')
	--warn(Variables.ticketCounts)

	if Variables.raid then
		rewards['Credits'] = math.random(4,8)
		player.RaidData.Credits.Value += rewards['Credits'] or 0 
	end


	warn(rewards)

	player.Gems.Value += rewards["Gems"] 

	--Variables.CurrentRound
	ReceiveRewardsEvent:FireClient(player,rewards,nil)


	--ReceiveRewardsEvent:FireClient(player,Variables.ActStats.Rewards,nil, firstTime)

	if info.Infinity.Value == false then
		player.DailyStats.StoryQuest.Value += 1
	end

	if game.Workspace.Info.World.Value == player.StoryProgress.World.Value and game.Workspace.Info.Level.Value == player.StoryProgress.Level.Value then
		if #StoryModeStats.LevelName[StoryModeStats.Worlds[game.Workspace.Info.World.Value]] == game.Workspace.Info.Level.Value then
			player.StoryProgress.World.Value += 1
			player.StoryProgress.Level.Value = 1
		else
			player.StoryProgress.Level.Value += 1
		end
	end

	RewardProcessing(player)
end