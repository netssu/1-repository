local ServerStorage = game:GetService("ServerStorage")
local ErrorService = require(ServerStorage.ServerModules.ErrorService)

local function main()
	print('teleportonexitloaded')

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local TeleportService = game:GetService("TeleportService")

	local SafeTeleport = require(ServerScriptService.SafeTeleport)
	local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
	local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)

	local events = ReplicatedStorage:WaitForChild("Events")
	local exitEvent = events:WaitForChild("ExitGame")

	local worldReservePlace = nil

	local locked = false

	local function Teleport(player, decision) --Decisions: Return | Replay | Next
		local placeId = PlaceData.Lobby
		local options = Instance.new("TeleportOptions")
		if decision == "Return" then
			options:SetTeleportData({
				["Money"] = player.Money.Value
			}) 
			events.Client.Teleporting:FireClient(player, "Lobby")
	    elseif decision == "Replay" then
	        if locked then return end
			--if workspace.Info.ChallengeNumber.Value > 0 then return end
			locked = true
			
			print('REPLAYINGG')
			
			
			

			
			placeId = PlaceData.Game
			worldReservePlace = worldReservePlace or TeleportService:ReserveServer(placeId)
			options.ReservedServerAccessCode = worldReservePlace
	        options:SetTeleportData({World = workspace.Info.World.Value,Level = workspace.Info.Level.Value,Mode = workspace.Info.Mode.Value, Raid = workspace.Info.Raid.Value,OwnerId = workspace.Info.OwnerId.Value, Infinite = workspace.Info.Infinity.Value, Event = workspace.Info.Event.Value})
			
			if workspace.Info.ChallengeNumber.Value > 0 then
				options:SetTeleportData({
					World = workspace.Info.World.Value,
					Level = workspace.Info.Level.Value,
					Mode = workspace.Info.Mode.Value,
					Raid = workspace.Info.Raid.Value,
					OwnerId = workspace.Info.OwnerId.Value,
					ChallengeNumber = workspace.Info.ChallengeNumber.Value,
					ChallengeUniqueId = workspace.Info.ChallengeUniqueId.Value,
					ChallengeRewardNumber = workspace.Info.ChallengRewardeNumber.Value,
					Event = workspace.Info.Event.Value
				})
				print("Challenge Restart")
				for i, v in pairs(game.Players:GetChildren()) do
					events.Client.Teleporting:FireClient(
						v, 
						"Game", 
						workspace.Info.World.Value, 
						workspace.Info.Level.Value, 
						workspace.Info.Mode.Value, 
						workspace.Info.ChallengeNumber.Value, 
						workspace.Info.ChallengeUniqueId.Value, 
						workspace.Info.ChallengRewardeNumber.Value,
						workspace.Info.Event.Value
					)
				end
			end
			
	        for i, v in pairs(game.Players:GetChildren()) do
	            events.Client.Teleporting:FireClient(v, "Game", workspace.Info.World.Value, workspace.Info.Level.Value, workspace.Info.Mode.Value)
	        end
			
	    elseif decision == "Next" and workspace.Info.Message.Value == "VICTORY" then
	        if locked then return end
	        locked = true
			local isNextPlaceValid
			local currentWorldName = StoryModeStats.Worlds[workspace.Info.World.Value]
			local currentWorldLevels = currentWorldName and StoryModeStats.LevelName[currentWorldName]

			local nextWorld,nextLevel

			if currentWorldLevels then
				if workspace.Info.Level.Value < #currentWorldLevels then
					nextWorld = workspace.Info.World.Value
					nextLevel = workspace.Info.Level.Value + 1
				elseif #StoryModeStats.Worlds > workspace.Info.World.Value then
					nextWorld = workspace.Info.World.Value + 1
					nextLevel = 1 
				end
			end
			
			if nextWorld and nextLevel then
				placeId = PlaceData.Game
				worldReservePlace = worldReservePlace or TeleportService:ReserveServer(placeId)
				options.ReservedServerAccessCode = worldReservePlace
	            options:SetTeleportData({World = nextWorld,Level = nextLevel,Mode = workspace.Info.Mode.Value, Raid = workspace.Info.Raid.Value, OwnerId = workspace.Info.OwnerId.Value})
			else
				options:SetTeleportData({
					["Money"] = player.Money.Value
				}) 
			end
			events.Client.Teleporting:FireClient(player, "Game", nextWorld, nextLevel, workspace.Info.Mode.Value, workspace.Info.Raid.Value)
		end
		
	    task.wait(3)
	    if locked then
	        SafeTeleport(placeId, game.Players:GetChildren(), options)
	    else
	        SafeTeleport(placeId, {player}, options)
	    end
	    
		
		print("Finished teleport")
		----------------------------
	end

	exitEvent.OnServerEvent:Connect(Teleport)
end

ErrorService.wrap(main)