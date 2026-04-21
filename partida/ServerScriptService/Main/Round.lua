local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local MapLoader = require(script.Libs.MapLoader)


local ServerStorage = game:GetService("ServerStorage")
local ErrorService = require(ServerStorage.ServerModules.ErrorService)
local ScheduleLib = require(ServerScriptService.ClanService.ClansHandler.ScheduleLib)
local ClanLib = require(ServerScriptService.ClanService.ClansHandler.ClanLib)

local round = {}

local raidLuckIncrease = 0


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrentRaidEventMap = ReplicatedStorage.CurrentRaidEventMap.Value
local ServerScriptService = game:GetService('ServerScriptService')
local ClanLeaderboardQueue = require(ServerScriptService.ClanService.ClanLoader.ClanLeaderboardQueue)

local TweenService = game:GetService("TweenService")
local AnalyticsService = game:GetService("AnalyticsService")
local BadgeService = game:GetService('BadgeService')

local forceUnit = false

local Events = ReplicatedStorage.Events
local mob = require(script.Parent.Mob)
local ChallengeModule = require(ReplicatedStorage.Modules.ChallengeModule)
local info = workspace.Info
local Variables = require(script.Variables)
local Event = workspace.Info.Event
local Parties = require(script.Parent.Parties)


local StreaksDatastore = DataStoreService:GetOrderedDataStore('Streak')
local XPHandler
task.spawn(function()
	XPHandler = require( ReplicatedStorage:WaitForChild('EpisodeConfig').XPHandler )
end)
local wait = task.wait


local votes = {}

local win = false
local died = false

--local ramping = 1
local healthMultiplier = 1
local skipvotes = 0
local BASIC_MOB_SPAWN_DELAY = 1
local MIN_MOB_SPAWN_DELAY = 1


Variables.mobLimit = game.Workspace.Info.MobLimit.Value

for i,v in script.RoundFunctions:GetChildren() do
	task.spawn(function()
		require(v)
	end)
end

local function repeatSubtract(number, sub)
	local r = number
	local r1 = 0
	for _ = 0, math.huge do
		if r <= sub then break end
		r -= sub
	end
	return r
end

local function forceTeleportPlayer(v)
	local s,e = nil,nil
	repeat
		if not v.Parent then break end
		local teamName = nil
		local success, err = pcall(function()
			teamName = v.Team.Name
		end)
		if teamName ~= 'Red' and teamName ~= 'Blue' then task.wait(0.1) continue end -- havent been assigned a team yet

		local spawnCFrame = workspace[v.Team.Name .. 'SpawnLocation']

		s,e = pcall(function()
			local targetCFrame = spawnCFrame.CFrame * CFrame.new(Vector3.new(0,5,0))
			v.Character:PivotTo(targetCFrame)
		end)

		task.wait(0.1)
	until s
end

function round.StartGame(host)
	if info.GameRunning.Value == true then return end



	Variables.map = MapLoader.LoadMap()

	if info.Versus.Value or info.Competitive.Value then
		Parties.generateTeams()

		Players.PlayerAdded:Connect(function(v)
			Parties.putIntoTeam(v)
			forceTeleportPlayer(v)
		end)

		if not Variables.map then error('UH OH, map not loaded into variable') return end

		local redSpawnCFrame = Variables.map:FindFirstChild('RedSpawnLocation')
		local blueSpawnCFrame = Variables.map:FindFirstChild('BlueSpawnLocation')

		if redSpawnCFrame and blueSpawnCFrame then		
			for i,v:Player in pairs(Players:GetChildren()) do
				task.spawn(forceTeleportPlayer, v)
			end
		else
			task.spawn(function()
				error('There was an issue with loading the map!')
			end)
		end

	else
		local spawnCFrame = Variables.map and Variables.map:FindFirstChildOfClass('SpawnLocation')

		if spawnCFrame then		
			for i,v in pairs(Players:GetChildren()) do
				task.spawn(forceTeleportPlayer, v)
			end
		else
			task.spawn(function()
				error('There was an issue with loading the map!')
			end)
		end
	end





	info.GameRunning.Value = true

	task.spawn(function()
		repeat task.wait() until host:FindFirstChild("DataLoaded")
		local Settings = host:FindFirstChild("Settings")
		if Settings then
			local auto3x = Settings:FindFirstChild("Auto3x")
			if auto3x and auto3x.Value == true then
				print("speed")
				local speedMultiplier= 3
				workspace.Info.GameSpeed.Value = speedMultiplier
				ReplicatedStorage.Events.ChangeSpeed:FireAllClients(`{speedMultiplier}x`, host)
				script:SetAttribute('MobSpawnDelay', math.max(MIN_MOB_SPAWN_DELAY, BASIC_MOB_SPAWN_DELAY / speedMultiplier))
				for _, player in ipairs(Players:GetPlayers()) do
					if player:FindFirstChild('Speed') then
						player.Speed.Value = speedMultiplier
					end
				end

			end
		else
			print("no settings")
		end
	end)

	task.wait(4)

	Events.Client.StartGUI:FireAllClients(true)

	task.wait(6.5)

	Variables.infinity = info.Infinity.Value
	Variables.raid = info.Raid.Value
	Variables.challenge = info.ChallengeNumber.Value
	local challengeRewardNumber = info.ChallengRewardeNumber.Value


	local ChallengeModeTable = {
		[7] = function(ActStats)
			if not ActStats then
				Variables.RoundStats = require(script.Gamemodes.BossRush)
			else
				return Variables.RoundStats[Variables.map.Name]["BossRush"]
			end
		end,
		[8] = function(ActStats)
			if not ActStats then
				Variables.RoundStats = require(script.Gamemodes.DemonBoss)
			else
				return Variables.RoundStats[Variables.map.Name]["DemonBoss"]
			end
		end,
		[9] = function(ActStats)
			if not ActStats then
				Variables.RoundStats = require(script.Gamemodes["1HP"])
			else
				return Variables.RoundStats[Variables.map.Name]["1HP"]
			end
		end,
		[10] = function(ActStats)
			if not ActStats then
				Variables.RoundStats = require(script.Gamemodes["EXTREME_BOSS"])
			else
				return Variables.RoundStats[Variables.map.Name]["EXTREME_BOSS"]
			end
		end,
	}


	if info.Versus.Value then
		Variables.RoundStats = require(script.Gamemodes.Versus)
	else
		if Variables.raid and Variables.infinity then
			Variables.RoundStats = require(script.Gamemodes.RaidInfinity)
		elseif Variables.infinity then
			Variables.RoundStats = require(script.Gamemodes.Infinity)
		elseif Variables.raid then
			Variables.RoundStats = require(script.Gamemodes.Raid)
		elseif Variables.challenge >= 7 then
			ChallengeModeTable[Variables.challenge](false)
		elseif Event.Value then
			Variables.RoundStats = require(script.Gamemodes.Event)
		else
			Variables.RoundStats = require(script.Gamemodes.Story)
		end
	end


	if Variables.map ~= nil then
		if info.Versus.Value then
			Variables.ActStats = Variables.RoundStats[info.WorldString.Value]['MainAct']
		else
			if not Variables.infinity then -- and not info.Raid.Value then
				Variables.ActStats = Variables.RoundStats[Variables.map.Name]["Act"..info.Level.Value]
			else
				Variables.ActStats = Variables.RoundStats[Variables.map.Name]
			end
		end
	end

	if not info.Versus.Value then
		if Event.Value then
			Variables.ActStats = Variables.RoundStats[Variables.map.Name]["EXTREME_BOSS"]
		end

		if Variables.challenge >= 7 then
			Variables.ActStats = ChallengeModeTable[Variables.challenge](true)
		end	
	end

	if Variables.ActStats then
		local bosses = nil

		if Variables.challenge == 7 then
			bosses = {
				"boss1",  -- miniboss
				"boss2",  -- miniboss
				"boss3",  -- miniboss
				"boss4",  -- miniboss
				"boss5",  -- miniboss
				"boss6",  -- miniboss
				"boss7",  -- miniboss
				"boss8",  -- miniboss
				"boss9",  -- miniboss
				"boss10", -- miniboss
				"boss11", -- miniboss
				"boss12", -- miniboss
				"boss13", -- boss (Tact)
				"boss14", -- boss
				"boss15", -- boss
				"boss16", -- boss
				"boss17", -- boss
				"boss18", -- boss
				"boss19"  -- mega boss (Brevious)
			}
			warn(bosses)
		end

		Events.Client.VoteStartGame:FireAllClients(nil, nil, nil, true)
		task.wait(0.1)
		local startTimer = 0
		repeat
			startTimer += 1
			Events.Client.VoteStartGame:FireAllClients(40-startTimer, Variables.PlayersVotedForStart)
			task.wait(1)

		until startTimer >= 40 or Variables.voteStart
		Events.Client.VoteStartGame:FireAllClients(40-startTimer,Variables.PlayersVotedForStart,true)

		Variables.startTime = os.time()

		Variables.CurrentRound = 0

		for i, player in Players:GetPlayers() do
			player:WaitForChild("Money").Value = Variables.ActStats.initial_money

			if game["Run Service"]:IsStudio() then -- or game.PlaceId == 77187363960578 then
				player:WaitForChild("Money").Value = 236478592374865
			end
		end

		Variables.MaxWave = if Variables.infinity then math.huge else #Variables.ActStats.Rounds


		info.MaxWaves.Value = Variables.MaxWave
		ReplicatedStorage.Events.Client.Timer:FireAllClients(Variables.CurrentRound + 1, Variables.ActStats.wave_rest_time)

		if Variables.challenge ~= -1 then
			--modify mobs stats based on challenge
			local challengeData = ChallengeModule.Data[Variables.challenge]
			if challengeData and challengeData.MobStats ~= nil then
				script:SetAttribute('SpeedMultiplier', script:GetAttribute('SpeedMultiplier') + (challengeData.MobStats.Speed / 100))

				healthMultiplier += (challengeData.MobStats.Health / 100)
			end

			if Variables.challenge == 9 then
				warn("1HP")

			end

		end




		require(script.Libs.MainGameLoopLib)
		-- Game Ended, Load Rewards
		require(script.Libs.RewardsLib)

		local function handleRewards()
			for _, player in Players:GetPlayers() do
				local tutorialWin = player:FindFirstChild("TutorialWin")
				if tutorialWin and  not tutorialWin.Value then
					tutorialWin.Value = true
				end

				info.Victory.Changed:Connect(function()
					if info.Victory.Value and Event.Value and player:FindFirstChild("EventAttempts").Value >= 500 then
						player.EventAttempts.Value = 0
						_G.createTower(player.OwnedTowers, "Sith Trooper")
					else
						warn("EVENTTTTTTTT")
					end
				end)



				pcall(function()
					if XPHandler then
						XPHandler.UpdateQuests( player , 'Clear Acts' )
						if info.Raid.Value then
							XPHandler.UpdateQuests( player , 'Complete Raids' )	
						end
					end
				end)
			end
		end

		if not died or info.Event.Value then
			info.Victory.Value = true
			info.GameOver.Value = true
			info.Message.Value = "VICTORY"



			local s,e = pcall(function()

				for i,v in Players:GetChildren() do
					if v.StreakIncreasesIn.Value < os.time() then
						print('Incrementing Streak')
						v.StreakIncreasesIn.Value = os.time() + 86400
						v.Streak.Value += 1
						v.PlayStreakAnimation.Value = true
						v.StreakLastUpdated.Value = os.time()

						task.spawn(function()
							StreaksDatastore:SetAsync(v.UserId, v.Streak.Value)
						end)
					end
				end
			end)

			handleRewards()
		else
			print('We lost :(')

			for i,v in Players:GetChildren() do
				v.TutorialWin.Value = true
			end

		end
	else
		assert("MAP VARIABLE IS NIL")
	end
end

return round
