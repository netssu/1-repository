local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local Variables = require(script.Parent.Parent.Variables)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local mob = require(ServerScriptService.Main.Mob)
local QuestHandler = require(game.ServerStorage.ServerModules.QuestHandler)
local info = workspace.Info
local QuestConfig = require(ReplicatedStorage.Configs.QuestConfig)

local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost)
local ClanLeaderboardQueue = require(ServerScriptService.ClanService.ClanLoader.ClanLeaderboardQueue)
local ClanLib = require(ServerScriptService.ClanService.ClansHandler.ClanLib)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Warning = ReplicatedStorage.ServerWarningEvent

local module = {}

local EnemySpawnChances = Variables.RoundStats.EnemySpawnChances

repeat
	Variables.CurrentRound += 1

	local round = Variables.ActStats.Rounds[Variables.CurrentRound]

	if not round and not Variables.infinity then
		warn(Variables.CurrentRound)
		warn(Variables.ActStats.Rounds)
		warn('Game ended!')

		if info.Versus.Value then
			print('Versus')
			if info.WinningTeam.Value ~= 'RED' and info.WinningTeam.Value ~= 'BLUE' then
				print('End of wave config, infinitely spawning big bosses until enemy dies')
				local cancel = false
				local death = Instance.new('BindableEvent')

				info.WinningTeam.Changed:Connect(function()
					if info.GameOver.Value then
						cancel = true
						death:Fire()
					end
				end)


				-- infinitely spawn enemies
				task.spawn(function()
					local health = 2500
					local cancel = false
					local growthRate = 0.2 -- 5% curve
					local linearBoost = 2

					while not cancel do
						health += linearBoost
						health *= (1 + growthRate)
						health = math.round(health)

						local wsp = 6

						local unitstats = {
							unit = 'Wader Last Breath',
							health = health,
							speed = wsp,
							money_reward = health * 0.1
						}

						-- spawn enemy
						mob.Spawn(
							'Wader Last Breath',
							1,
							Variables.map,
							nil,
							health,
							health*0.25,
							wsp,
							false,
							unitstats,
							nil,
							'Blue'
						)

						mob.Spawn(
							'Wader Last Breath',
							1,
							Variables.map,
							nil,
							health,
							health*0.25,
							wsp,
							false,
							unitstats,
							nil,
							'Red'
						)


						task.wait(3)
					end

				end)

				death.Event:Wait()
				cancel = true
				-- break main loop and give rewards
				break
			end

			break
		else
			Warning:FireAllClients('[ROUND MODULE] xo1, uh oh this shouldnt be happening')
			Variables.win = true
			break
		end
	elseif not round and Variables.infinity then
		Warning:FireAllClients('[ROUND MODULE] Starting Infinite Wave')
		for _, player in game.Players:GetPlayers() do
			QuestHandler.UpdateQuestProgress(player, "reach_wave", {
				World = info.World.Value,
				Wave = Variables.CurrentRound,
				AddAmount = 1
			})
		end


		round = {
			wave = {},
			wave_reward = Variables.infinityWaveReward, 
		}


		local mobGroups = 2
		for minRound, groups in Variables.RoundStats.MobGroupRounds do
			if Variables.CurrentRound > minRound and mobGroups < groups then
				mobGroups = groups
			end
		end

		local newSpawnChances = table.clone(EnemySpawnChances)
		for i=1, mobGroups do
			local total = 0
			for enemyName, enemyPercent in newSpawnChances do
				total += enemyPercent
			end
			local randomNumber = math.random(0,total*100)/100
			local counter = 0
			local selectedMob = "normal"

			for enemy, weight in newSpawnChances do
				counter = counter + weight
				if randomNumber >= counter then
					selectedMob = enemy
				end
			end
			local mobAmount = 1
			local lastHighestRound = 0
			for minRound, selectedAmount in Variables.RoundStats.MobAmounts[selectedMob] do
				if Variables.CurrentRound > minRound and minRound >= lastHighestRound then
					mobAmount = selectedAmount
					lastHighestRound = minRound
				end
			end
			table.insert(round.wave,{unit = selectedMob, amount = mobAmount})
			newSpawnChances[selectedMob] = nil
		end

		if Variables.CurrentRound%10 == 0 then
			if not bosses or #bosses == 0 then
				if workspace.Info.World.Value == 5 then
					bosses = {"boss1","boss2","boss3"}
				else
					bosses = {"boss1","boss2","boss3","boss4","boss5"}
				end
			end
			local randomIndex = math.random(1,#bosses)
			local chosenBoss = bosses[randomIndex]
			table.remove(bosses,randomIndex)
			table.insert(round.wave,{unit = chosenBoss, amount = 1, is_boss = true})
		end

		if Variables.challenge == 8 then
			table.insert(round.wave,{unit = Variables.RoundStats.mega_boss, amount = 1, is_boss = true})
		end

		for enemy, chance in EnemySpawnChances do
			local increaseStats = Variables.RoundStats.EnemySpawnChancesStats[enemy]
			if increaseStats then
				if Variables.CurrentRound >= increaseStats.StartRound and Variables.CurrentRound <= increaseStats.EndRound then
					chance += increaseStats.Increase
				end
			end
		end
	end
	if Variables.infinity then
		Variables.healthMultiplier += (Variables.CurrentRound^1.5)/577.8 
	end

	info.Wave.Value = Variables.CurrentRound
	info.Message.Value = ""

	local waitCount = 1
	if RunService:IsStudio() then waitCount = 0 end

	task.wait((Variables.ActStats.wave_rest_time/workspace.Info.GameSpeed.Value) * waitCount)
	local bossDead = false
	local isBoss = false
	local isBossRush = false
	local lastSpawnedMob = nil
	local lastBlueSpawnedMob = nil
	local lastRedSpawnedMob = nil

	for _, roundinfo in round.wave do
		if Variables.died then break end
		for x=1, roundinfo.amount do
			if Variables.died then break end
			local unitStats = Variables.ActStats.EnemyStats[roundinfo.unit]
			if unitStats then
				local health = math.round(unitStats.health * Variables.healthMultiplier)
				local money = unitStats.money_reward
				local speed = unitStats.speed * script.Parent.Parent:GetAttribute('SpeedMultiplier')
				local unitName = unitStats.unit
				local newMob
				local redMob

				if Variables.infinity then
					newMob = mob.Spawn(unitName, 1, Variables.map, lastSpawnedMob, math.round((health*info.Mode.Value)*#Players:GetPlayers()), money, speed, roundinfo.is_boss,unitStats)
					lastSpawnedMob = newMob or lastSpawnedMob
				else
					if not info.Versus.Value then
						newMob = mob.Spawn(unitName, 1, Variables.map, lastSpawnedMob, math.round((health+(health*round.wave_diff_scale)*info.Mode.Value)*#Players:GetPlayers()), money, speed, roundinfo.is_boss,unitStats,roundinfo.is_bossrush)
						lastSpawnedMob = newMob or lastSpawnedMob
					else
						newMob = mob.Spawn(unitName, 1, Variables.map, lastBlueSpawnedMob, math.round((health+(health*round.wave_diff_scale)*info.Mode.Value)*#Players:GetPlayers()), money, speed, roundinfo.is_boss,unitStats,roundinfo.is_bossrush, 'Blue')
						redMob = mob.Spawn(unitName, 1, Variables.map, lastRedSpawnedMob, math.round((health+(health*round.wave_diff_scale)*info.Mode.Value)*#Players:GetPlayers()), money, speed, roundinfo.is_boss,unitStats,roundinfo.is_bossrush, 'Red')
						lastBlueSpawnedMob = newMob or lastBlueSpawnedMob
						lastRedSpawnedMob = redMob or lastRedSpawnedMob
					end
				end


				local lastBossSpawnTime = 0
				local debounceDelay = 5
				local Counter = 0


				if not info.Versus.Value then
					if roundinfo.is_boss then
						warn(newMob)
						ReplicatedStorage.Events.Client.BossSpawn:FireAllClients(newMob)

						if not Variables.infinity then
							isBoss = true

							task.spawn(function()
								repeat task.wait() until not newMob or not newMob.Parent
								bossDead = true
							end)
							break
						end
					end
				else
					-- versus, dont wait till boss is over

				end
			end

			if not RunService:IsStudio() then
				task.wait(script.Parent.Parent:GetAttribute('MobSpawnDelay'))
			else
				task.wait()
			end
		end
	end

	if isBoss then
		repeat task.wait() until bossDead

		if not workspace.Info.GameOver.Value then
			Variables.win = true
		end

		break
	end

	if Variables.died then break end

	if Variables.CurrentRound < Variables.MaxWave then
		skipvotes = 0
		ReplicatedStorage.Events.SkipGui:FireAllClients(true, { 
			Required = true
		})		
	end

	local roundEnd = false

	local count = 0
	repeat
		task.wait(0.5)
		if Variables.Skip == true and Variables.CurrentRound < Variables.MaxWave then
			Variables.Skip = false
			break
		end
		count += 1
		--print(count)
		if not info.Versus.Value then
			if #game.Workspace.Mobs:GetChildren() == 0 or count == 23 then
				if count == 23 then
					--ReplicatedStorage.Events.Client.Message:FireAllClients("Force Skipped Wave")
				end

				roundEnd = true
			end
		else
			local totalCount = #workspace.RedMobs:GetChildren() + #workspace.BlueMobs:GetChildren()

			if totalCount == 0 or count == 20 then
				roundEnd = true
			end

		end
	until roundEnd
	ReplicatedStorage.Events.SkipGui:FireAllClients(false)


	if Variables.infinity then
		if Variables.CurrentRound == 50 then
			for i,v in pairs(Players:GetChildren()) do
				BadgeService:AwardBadge(v.UserId, 778268411443411)
			end
		end

		Variables.infinityWaveReward = math.min(Variables.infinityWaveReward+300,2000)
		info.Message.Value = "Wave Reward: $" .. Variables.infinityWaveReward
		if Variables.CurrentRound%10==0 or game["Run Service"]:IsStudio() then

			task.spawn(function()

				for i, player in Players:GetPlayers() do
					local s,e = pcall(function()
						local DoubleEXP = if player.OwnGamePasses["2x Player XP"].Value then 2 else 1
						local world = workspace.Info.World.Value
						local worldMultiplier = 1 + math.log(world) * 0.2 
						local XPAmount = math.round(5 * worldMultiplier * GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP)
						player.PlayerExp.Value += XPAmount

						local plrClan = player.ClanData.CurrentClan.Value
						if player:FindFirstChild('ClansLoaded') and plrClan ~= 'None' then
							--v.Kills.Value 
							task.spawn(function()
								ClanLeaderboardQueue.addToQueue(plrClan, "XP", XPAmount)
							end)
							ClanLib.giveStat(plrClan, player.UserId, 'XP', XPAmount)
						end
					end)

					if not s then
						warn('CRITICAL ERROR WITH THE XP THIS IS WHY YU ARE TRIPPING')
						warn(e)

					end
				end
			end)
		end

		if Variables.CurrentRound > 100 then
			if Variables.CurrentRound%25 == 0 then
				Variables.raidLuckIncrease += 3/(5/workspace.Info.Level.Value) 
			end
		end

		if Variables.CurrentRound%100 == 0 and Variables.CurrentRound ~= 0 then
			for i, player in Players:GetChildren() do
				pcall(function()
					player.TraitPoint.Value += 3
				end)
			end
		end

		if Variables.CurrentRound%50 == 0 and Variables.infinity and Variables.raid then
			for i, player in Players:GetChildren() do
				pcall(function()
					-- raid ticket
					if not Variables.ticketCounts[player] then Variables.ticketCounts[player] = 0 end
					Variables.ticketCounts[player] += math.random(2,4)
				end)
			end
		end


		for i, player in Players:GetPlayers() do
			local hasDoubleGem = if player.OwnGamePasses["x2 Gems"].Value then 2 else 1

			local amountToAdd = 1

			amountToAdd += workspace.Info.World.Value

			if workspace.Info.Infinity.Value then
				amountToAdd *= 0.65
				amountToAdd = math.round(amountToAdd)
			end

			local gemToAdd = math.round(amountToAdd * (hasDoubleGem * GetPlayerBoost(player, "Gems")))

			if workspace.Info.Difficulty.Value == 'Hard' and not workspace.Info.Infinity.Value then
				gemToAdd *= 1.3
				gemToAdd = math.round(gemToAdd)
			end



			local unitCount = 0

			unitCount = #workspace.Towers:GetChildren()

			if workspace.Info.Infinity.Value and Variables.CurrentRound < 10 then
				amountToAdd = 0
			end


			if unitCount ~= 0 then
				if not Variables.gemCounts[player] then
					Variables.gemCounts[player] = 0
				end

				Variables.gemCounts[player] += amountToAdd
			end

			player.Money.Value += round.wave_reward or math.min((500 * Variables.CurrentRound), 10000)
			info.Message.Value = "Wave Reward: $" .. (round.wave_reward or math.min((500 * Variables.CurrentRound), 10000))

			if player:FindFirstChild('Quest') then -- x_x: quest dont exist but i dont wanna risk deleting this so added a check instaed
				for _, questInfo in player.Quest.Infinite:GetChildren() do
					if Variables.map.Name == questInfo.Map.Value then
						questInfo.Progress.Value += 1
					end
				end
			end
		end
	else
		for i, player in Players:GetPlayers() do			

			local unitCount = 0

			unitCount = #workspace.Towers:GetChildren()

			local amountToAdd = 0
			amountToAdd += info.World.Value

			if info.Difficulty.Value == 'Hard' then
				amountToAdd *= 1.2
			end

			local actMultiplier = 1 + (0.02 * info.Level.Value)

			amountToAdd = math.round(amountToAdd * actMultiplier)

			if unitCount ~= 0 then
				if not Variables.gemCounts[player] then
					Variables.gemCounts[player] = 0
				end

				Variables.gemCounts[player] += amountToAdd
			end

			player.Money.Value += round.wave_reward or math.min((500 * Variables.CurrentRound), 10000)
			if #Players:GetPlayers() > 1 then
				if player:FindFirstChild('Quest') then
					player.Quest.Daily.Multiplayer.Progress.Value+=1
				end
			end
		end
		info.Message.Value = "Wave Reward: $" .. (round.wave_reward or math.min((500 * Variables.CurrentRound), 10000))
	end


	for _, player in Players:GetPlayers() do

		if #Players:GetPlayers() > 1 then
			QuestConfig.UpdateProgressAll(player, "ClearWavesMultiplayer", 1)

		end

		QuestConfig.UpdateProgressAll(player, "ClearWaves", 1)

		if Variables.infinity then
			QuestConfig.UpdateProgressAll(player, "InfiniteWaves", 1)
			QuestConfig.UpdateProgressAll(player, "ClearInfinite", 1)
		end

	end

	if Variables.CurrentRound < Variables.MaxWave then
		ReplicatedStorage.Events.Client.Timer:FireAllClients(Variables.CurrentRound + 1, Variables.ActStats.wave_rest_time)
	end
until Variables.died


return module
