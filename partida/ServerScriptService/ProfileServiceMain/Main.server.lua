local ServerStorage = game:GetService('ServerStorage')
local ErrorService = require(ServerStorage.ServerModules.ErrorService)

local function main()
    local DataStoreService = game:GetService("DataStoreService")

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local MarketPlace = game:GetService("MarketplaceService")

    local functions = ReplicatedStorage:WaitForChild("Functions")
    local events = ReplicatedStorage:WaitForChild("Events")
    local getDataFunc = functions:WaitForChild("GetData")
    local exitEvent = events:WaitForChild("ExitGame")
    local ExpModule = require(ReplicatedStorage.Modules.ExpModule)
    local ItemStatsModule = require(ReplicatedStorage.ItemStats)
    local CosmeticModule = require(game.ReplicatedStorage.Modules.Cosmetic)
    local CollisionGroupModule = require(ReplicatedStorage.Modules.CollisionGroup)
    local GlobalFunctions = require(game.ReplicatedStorage.Modules.GlobalFunctions)
    local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
    local ProfileService = require(game.ServerStorage.ServerModules.ProfileService)
    local GetItemModel = require(ReplicatedStorage.Modules.GetItemModel)
    local defaultData = require(script.DefaultData)
    local HistoryLoggingService = require(script.HistoryLoggingService)
	local UpgradesModule = require(ReplicatedStorage.Upgrades)
	local AuraHandling = require(script.AuraHandling)
	

    local GameProfileStore = ProfileService.GetProfileStore(
    	"UserDataV2",
    	defaultData
    )

    local OldDataStore = DataStoreService:GetDataStore("Inventory")

    local MAX_SELECTED_TOWERS = 4

    local arrays = {"OwnedTowers","Buffs","RewardsClaimed","Codes","Team"}

    local Profiles = {}

    _G.createTower = function(location,tower,trait,info)
    	local towerval = Instance.new("StringValue")
    	towerval.Name = tower
		
		
		if not UpgradesModule[tower] then
			--print(UpgradesModule)
			error("No tower in upgrades module..")	
		end

    	towerval:SetAttribute("Level",1)  
    	towerval:SetAttribute("Exp",0)
    	towerval:SetAttribute("Trait",trait or "")
    	towerval:SetAttribute("Equipped",false)
    	towerval:SetAttribute("Locked",false)
    	towerval:SetAttribute("UniqueID", GlobalFunctions.GenerateID())
    	towerval:SetAttribute("EquippedSlot", "")
		towerval:SetAttribute('Shiny', (info and info['Shiny']) or false)

    	task.spawn(function()
    		local index = location:FindFirstAncestorOfClass("Player"):WaitForChild("Index"):WaitForChild("Units Index")
    		if not index:FindFirstChild(tower) then
    			local Value = Instance.new("BoolValue",index)
    			Value.Name = tower
    		end
    	end)

    	if UpgradesModule[tower] and UpgradesModule[tower].Takedowns then
    		towerval:SetAttribute("Takedowns",0)
    	end

    	local shinyLimited = false

    	local player = location:FindFirstAncestorOfClass("Player")
    	if UpgradesModule[tower] then
    		if UpgradesModule[tower].Limited then
    			if info then
    				if player and not info["TimeObtained"] then
    					if info["LoadingData"] then
    						towerval:SetAttribute("TimeObtained", "???")
    					else
    						local currenttime = ReplicatedStorage.Functions.GetTime:InvokeClient(player)
    						towerval:SetAttribute("TimeObtained", currenttime)
    					end
    				elseif info["TimeObtained"] then
    					towerval:SetAttribute("TimeObtained", info["TimeObtained"])
    				end
    			else
    				local currenttime = ReplicatedStorage.Functions.GetTime:InvokeClient(player)
    				towerval:SetAttribute("TimeObtained", currenttime)
    			end
    		end
		end

    	towerval.Parent = location
    	return towerval
    end

    local function GetTableType(t)
    	assert(type(t) == "table", "Supplied argument is not a table")
    	for i,_ in t do
    		if type(i) ~= "number" then
    			return "dictionary"
    		end
    	end
    	return "array"
    end

    for i, v in StoryModeStats.Worlds do
    	defaultData["WorldStats"][v] = {
    		LevelStats = {},
    		InfiniteRecord = -1
        }
        
        if not StoryModeStats.LevelName[v] then continue end        
        
    	for x=1, #StoryModeStats.LevelName[v] do
    		defaultData["WorldStats"][v]["LevelStats"][`Act{x}`] = {
    			FastestTime = -1,
    			Clears = 0,
    		}
    	end
    end

    for i, v in GetItemModel do
    	if ItemStatsModule[v.Name] then
    		defaultData.Items[v.Name] = 0
    	end
    end


    local function DeepLoadDataToInstances(data, parentTo)

    	local BasicValues = {
    		["number"] = "NumberValue",
    		["boolean"] = "BoolValue",
    		["string"] = "StringValue"
    	}
    	for index, element in data do
    		if BasicValues[typeof(element)] ~= nil then
    			local numberVal = Instance.new(BasicValues[typeof(element)])
    			numberVal.Name = index
    			numberVal.Value = element
    			numberVal.Parent = parentTo
    		elseif typeof(element) == "table" then
    			local folder = Instance.new("Folder")
    			folder.Name = index
    			folder.Parent = parentTo
    			if element["R"] and element["G"] and element["B"] then
    				local colorVal = Instance.new("Color3Value")
    				colorVal.Name = index
    				colorVal.Value = Color3.new(element["R"],element["G"],element["B"])
    				colorVal.Parent = folder
    				return
    			elseif index == "OwnedTowers" then
    				local attributes = {"Level","Exp","Trait","Equipped","Locked","UniqueID","EquippedSlot"}
					for _, towerData in element do
    					local newTower = _G.createTower(folder,towerData["TowerName"],nil,{Shiny=towerData["Shiny"],TimeObtained=towerData["TimeObtained"],LoadingData = true})
    					for j, attribute in attributes do
    						if towerData[attribute] then
    							if attribute == "Equipped" and towerData.EquippedSlot == "" then
    								newTower:SetAttribute(attribute,false)
								else
									--print(towerData["TowerName"]) -- print the actual name that it's trying to find the t oqwer with, newTower is the object that gets returned, and it'll just return nil
    								--print(newTower)
    								newTower:SetAttribute(attribute,towerData[attribute])
    							end

    						end
    					end
    				end
    			elseif index == "TeamPresets" then
    				for team, teamData in element do

    					local teamFolder = Instance.new("Folder")
    					teamFolder.Name = team
    					teamFolder.Parent = folder
    					if typeof(teamData) ~= "table" then continue end
    					for _, towerData in teamData do
    						local attributes = {"Level","Exp","Trait","Equipped","Locked","UniqueID","EquippedSlot"}
    						print(towerData, index)
    						local newTower = _G.createTower(teamFolder,towerData["TowerName"],nil,{Shiny=towerData["Shiny"],TimeObtained=towerData["TimeObtained"],LoadingData = true})
    						for j, attribute in attributes do
    							if towerData[attribute] then
    								newTower:SetAttribute(attribute,towerData[attribute])
    							end
    						end
    					end
    				end
    			elseif index == "Buffs" then
    				for bufftype, buffData in element do
    					local buff = script.BuffType:Clone()
    					buff.Name = bufftype
    					buff.Buff.Value = buffData["Buff"]
    					buff.Duration.Value = buffData["Duration"]
    					buff.Multiplier.Value = buffData["Multiplier"]
						buff.StartTime.Value =  buffData["StartTime"] --os.time()
    					buff.Parent = folder
    				end
    			else
    				DeepLoadDataToInstances(element, folder)
    			end
    		end
    	end
    end

    local function DeepSaveInstancesToData(instancesChildren, currentLayer, playerLeaving)
    	currentLayer += 1
    	local newData = {}
    	for index, element in instancesChildren do
    		if currentLayer == 1 and defaultData[element.Name] == nil then continue end
    		if element:IsA("ValueBase") then
    			if currentLayer == 1 and defaultData[element.Name] then	--double check to make sure that id doesnt copy instances that are part of the data
    				newData[element.Name] = element.Value
    			else
    				
    				if playerLeaving and element.Name == "Duration" and element.Parent:FindFirstAncestor("Buffs") then
    					local startTime = element.Parent.StartTime
    					element.Value = (startTime.Value + element.Value) -  os.time()
    				end
    				
    				newData[element.Name] = element.Value
    			end

    			--elseif element:IsA("Color3Value") then
    			--	newData[element.Name] = {
    			--		R = folderContent.Value.R,
    			--		G = folderContent.Value.G,
    			--		B = folderContent.Value.B
    			--	}
    		elseif element:IsA("Folder") then	--defaultData[element.Name]: verify that it is indeed part of data
    			newData[element.Name] = {}

    			if element.Name == "OwnedTowers" then
    				for _, tower in element:GetChildren() do
    					local towerstats = {}
    					towerstats["TowerName"] = tower.Name
    					towerstats["Level"] = tower:GetAttribute("Level")
    					towerstats["Exp"] = tower:GetAttribute("Exp")
    					towerstats["Trait"] = tower:GetAttribute("Trait")
    					towerstats["Locked"] = tower:GetAttribute("Locked")
    					towerstats["UniqueID"] = tower:GetAttribute("UniqueID")
    					towerstats["TimeObtained"] = tower:GetAttribute("TimeObtained")
    					towerstats["Shiny"] = tower:GetAttribute("Shiny")
    					towerstats["EquippedSlot"] = tower:GetAttribute("EquippedSlot")
    					towerstats["Equipped"] = tower:GetAttribute("Equipped")

    					table.insert(newData[element.Name],towerstats)
    				end
    			elseif element.Name == "TeamPresets" then
    				for _, teamFolder in element:GetChildren() do
    					newData[element.Name][teamFolder.Name] = {}

    					for _, tower in teamFolder:GetChildren() do
    						print(teamFolder, teamFolder:GetChildren(),tower)
    						local equippedSlot = tower:GetAttribute("EquippedSlot")

    						local towerstats = {}
    						towerstats["TowerName"] = tower.Name
    						towerstats["Level"] = tower:GetAttribute("Level")
    						towerstats["Exp"] = tower:GetAttribute("Exp")
    						towerstats["Trait"] = tower:GetAttribute("Trait")
    						towerstats["Locked"] = tower:GetAttribute("Locked")
    						towerstats["UniqueID"] = tower:GetAttribute("UniqueID")
    						towerstats["TimeObtained"] = tower:GetAttribute("TimeObtained")
    						towerstats["Shiny"] = tower:GetAttribute("Shiny")
    						towerstats["EquippedSlot"] = tower:GetAttribute("EquippedSlot")
    						towerstats["Equipped"] = tower:GetAttribute("Equipped")
    						newData[element.Name][teamFolder.Name][equippedSlot] = towerstats
    					end

    				end

    			else
    				newData[element.Name] = DeepSaveInstancesToData(element:GetChildren(), currentLayer, playerLeaving)
    			end
    		end
    	end
    	return newData
    end

    local function MergeData(currentData, defaultData)
    	local BasicValues = {
    		["number"] = "NumberValue",
    		["boolean"] = "BoolValue",
    		["string"] = "StringValue"
    	}

    	for index, element in defaultData do

    		if typeof(element) == "table" then
    			if currentData[index] then
    				MergeData(currentData[index], element)
    			else
    				currentData[index] = GlobalFunctions.CopyDictionary(element)
    			end
    		else
    			if currentData[index] then
    				currentData[index] = currentData[index]
    			else
    				currentData[index] = element
    			end
    		end

    	end
    end


	local function getTableDescendants(tbl, results, path)
		results = results or {}
		path = path or ""

		for key, value in pairs(tbl) do
			local currentPath = path ~= "" and (path .. "." .. tostring(key)) or tostring(key)

			if type(value) == "table" then
				getTableDescendants(value, results, currentPath)
			else
				table.insert(results, {
					path = currentPath,
					key = key,
					value = value
				})
			end
		end

		return results
	end

    -- Load the players data
	game.Players.PlayerAdded:Connect(function(player)
		print('Player added')
		
    	local profile = GameProfileStore:LoadProfileAsync(
    		player.UserId.."PlayerData",
    		"ForceLoad"
    	)

    	if profile ~= nil then

    		--print(profile)
    		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
    		profile:ListenToRelease(function()
    			if player:FindFirstChild("DataLoaded") then
    				player.DataLoaded:Destroy()
    			end
    			Profiles[player] = nil
    			player:Kick() -- The profile could've been loaded on another Roblox server
    		end)

    		if player:IsDescendantOf(Players) == true then
                profile = HistoryLoggingService.log(profile, true)
                
    			print(profile)
    			--if profile.Data.DataTransferFromOldData == false then
    			--	profile:Release()
    			--end

				profile.Data.Gems = math.round(profile.Data.Gems)

    			local statsData = profile.Data

    			task.spawn(function()
    				local character = player.Character or player.CharacterAdded:Wait()
    				repeat task.wait() until player.Character ~= nil
    				CollisionGroupModule:SetModel(character,"Player")
    			end)

				warn('xo1')

    			--if not statsData["CurrentDay"] then
    			--	statsData["CurrentDay"] = os.date("*t")["yday"]
    			--elseif statsData["CurrentDay"] ~= os.date("*t")["yday"] then
    			--	statsData["CurrentDay"] = os.date("*t")["yday"]
    			--	statsData["DailyStats"] = defaultData["DailyStats"]
    			--	local maps = table.clone(StoryModeStats.Worlds)
    			--	local randomMapNum = math.random(1,#maps)
    			--	local chosenMap1 = maps[randomMapNum]
    			--	table.remove(maps,randomMapNum)
    			--	statsData["Quest"]["Infinite"] = {
    			--		Quest1 = {Map = chosenMap1, Difficulty = math.random(1,3), Progress = 0, Claimed = false},
    			--		--Quest2 = {Map = maps[math.random(1,#maps)], Difficulty = math.random(1,3), Progress = 0, Claimed = false},
    			--	}
    			--	statsData["Quest"]["Daily"] = defaultData["Quest"]["Daily"]
    			--	for i, v in statsData["Quest"]["Daily"] do
    			--		v.Difficulty = math.random(1,3)
    			--	end
    			--end

    			for i, v in statsData["Buffs"] do
    				warn(os.time() >= v.StartTime + v.Duration)
    				if os.time() >= v.StartTime + v.Duration then
    					table.remove(statsData["Buffs"],table.find(statsData["Buffs"],v))
    				end
    			end

    			DeepLoadDataToInstances(statsData, player)
    			--if not player.OwnedTowers:FindFirstChild("Demon Lord") and player:GetRankInGroup(15762744) > 1 then
    			--	_G.createTower(player.OwnedTowers, "Demon Lord")
    			--	statsData.ReceiveExclusiveRimuru = true
    			--end

    			for i, v in player.Buffs:GetChildren() do
    				if v.StartTime.Value + v.Duration.Value > os.time() then
    					task.delay((v.StartTime.Value + v.Duration.Value) - os.time(),function()
    						print("Destroying buff...")
    						if v and v.Parent ~= nil and player.Parent then
    							v:Destroy()
    						else
    							error("Failed to destroy!", v, v.Parent, player.Parent)
    						end
    					end)
    				else
    					print("Destroying buff...")
    					v:Destroy()
    				end
    			end

				

				local function updatePlayerExp()
    				local newLevel,newExp = ExpModule.playerLevelCalculation(player, player.PlayerLevel.Value,player.PlayerExp.Value) --math.round(50 + (10 * player.PlayerLevel.Value))

    				player.PlayerExp.Value = newExp
    				player.PlayerLevel.Value = newLevel
    			end
    			updatePlayerExp()
    			player.PlayerExp.Changed:Connect(updatePlayerExp)

    			pcall(CosmeticModule.Apply,true, player.Character, player.CosmeticEquipped.Value, player.CosmeticUniqueID.Value)

    			task.spawn(function()
    				--print(Profiles, Profiles[player])
    				while player.Parent ~= nil do
    					if  Profiles[player] ~= nil and player:FindFirstChild("DataLoaded") then
    						Profiles[player].Data = DeepSaveInstancesToData(player:GetChildren(), 0)
    					end
    					task.wait(1)
    				end
    			end)

    			Profiles[player] = profile
    			local DataLoaded = Instance.new("Folder")
    			DataLoaded.Name = "DataLoaded"
    			DataLoaded.Parent = player

    			local ServerJoined = Instance.new("NumberValue")
    			ServerJoined.Name = "ServerJoined"
    			ServerJoined.Value = os.time()
				ServerJoined.Parent = player
				
				local DataLoaded = Instance.new("Folder")
				DataLoaded.Name = "ClansLoaded"
				DataLoaded.Parent = player

				AuraHandling.equipAura(player, player.EquippedAura.Value)

				--local profileData = profile.Data.WorldStats
				--local allDescendants = getTableDescendants(profileData)
				

				--local Tasks = player.BattlepassData:WaitForChild("Tasks")
				--game.Workspace.Info.GameOver.Changed:Connect(function()
				--	if game.Workspace.Info.GameOver.Value == true and game.Workspace.Info.Victory.Value == true then
				--		if not profile.Data.CompletedAct[workspace.Info.Level.Value] then
				--			for _, Task in pairs(Tasks:GetChildren()) do
				--				if Task.Name == "dani3" or Task.Name == "medium2" or Task.Name == "extreme2" then 
				--					Task.Value += 1
				--					table.insert(profile.Data.CompletedAct, workspace.Info.Level.Value)
				--				end
				--			end
				--		end
				--	end
				--end)
				
                print(profile)
    		else
    			profile:Release() -- Player left before the profile loaded
    		end

    	else
    		-- The profile couldn't be loaded possibly due to other
    		--   Roblox servers trying to load this profile at the same time:
    		player:Kick() 
    	end
    end)


    -- Save the players data
    Players.PlayerRemoving:Connect(function(player)
    	local profile = Profiles[player]
    	if profile ~= nil then
			
			pcall(function()
				for i,v in workspace.Towers:GetChildren() do
					if v.Config.Owner.Value == player.Name then
						v:Destroy()
					end
				end
			end)
			
    		local ServerJoined = player:FindFirstChild("ServerJoined")
    		if ServerJoined then
    			player.TimeSpent.Value += ( os.time() - ServerJoined.Value )
    		end
            local dat = DeepSaveInstancesToData(player:GetChildren(), 0, true)
            
            if #dat ~= 0 then
                dat = HistoryLoggingService.log(dat, false)
                profile.Data = dat
            end

    		profile:Release()
    	end
    end)

    script.RaidWin.Event:Connect(function()
    	print("RAIDWIN EVENT")
    	if StoryModeStats.RaidDrops[StoryModeStats.Worlds[game.Workspace.Info.World.Value]] then
    		local RaidDrops = StoryModeStats.RaidDrops[StoryModeStats.Worlds[game.Workspace.Info.World.Value]]
    		for i, v in game.Players:GetPlayers() do
    			print(v.Name)
    			local rewards = {}
    			for _, drop in RaidDrops do
    				if math.random(1,drop.Percent) == 1 then
    					_G.createTower(Players.OwnedTowers,drop.Tower)
    					table.insert(rewards,drop.Tower)
    					print(drop.Tower)
    				end
    			end
    			game.ReplicatedStorage.Events.RaidDrop:FireClient(v,rewards)
    			print("Fired Client")
    		end
    	end
    end)

    ReplicatedStorage.Events.UpdateSetting.OnServerEvent:Connect(function(player, changeSetting, newValue)
    	player.Settings[changeSetting].Value = newValue
    end)

    ------------------------------------------------------------------------------------------------------
    local LimitedItachiEarnInServer = workspace.Info.LimitedItachiEarnInServer
    local subtractFromData = 0
    local totalLimitedItachiEarnInServer = 0

    local limitedItachiDataStore = DataStoreService:GetDataStore("Limited")
    local success, currentLimitedAmount
    repeat
    	success, currentLimitedAmount = pcall(function()
    		return limitedItachiDataStore:UpdateAsync("Itachi", function(currentAmount)
    			if currentAmount == nil then
    				return 7000
    			else
    				return currentAmount
    			end
    		end)
    	end)
    	task.wait()
    until success

    workspace.Info.LimitedItachiRemaining.Value = currentLimitedAmount


    LimitedItachiEarnInServer:GetPropertyChangedSignal("Value"):Connect(function()
    	totalLimitedItachiEarnInServer = LimitedItachiEarnInServer.Value
    	
    	if subtractFromData == totalLimitedItachiEarnInServer then return end
    	
    	local success, currentLimitedAmount
    	local subtracted
    	print("Processing")
    	local count = 0
    	repeat
    		success, currentLimitedAmount = pcall(function()
    			return limitedItachiDataStore:UpdateAsync("Itachi", function(currentAmount)
    				if currentAmount == nil then
    					return 7000
    				else
    					subtracted = (totalLimitedItachiEarnInServer - subtractFromData)
    					return currentAmount - subtracted
    				end
    			end)
    		end)
    		count += 1
    	until success or count >= 3
    	
    	if not success then return end
    	
    	subtractFromData += subtracted
    	workspace.Info.LimitedItachiRemaining.Value = currentLimitedAmount
    	
    	print(currentLimitedAmount)
    	
    end)
end

ErrorService.wrap(main)






