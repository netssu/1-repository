local ServerStorage = game:GetService('ServerStorage')

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local AnalyticsService = game:GetService("AnalyticsService")
local BadgeService = game:GetService('BadgeService')

local AuraHandling = require(script.AuraHandling)
local ABTesting = require(script.ABTesting)
local InventoryDataStore = DataStoreService:GetDataStore("Inventory") 

local RaidDataSync = require(script.RaidDataSync)

local SacrificePoints = require(ReplicatedStorage.Modules.SacrificePoints)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local QuestStore = require(ReplicatedStorage.Modules.QuestStore)
local ExpModule = require(ReplicatedStorage.Modules.ExpModule)
local ItemStatsModule = require(ReplicatedStorage.ItemStats)
local CollisionGroupModule = require(ReplicatedStorage.Modules.CollisionGroup)
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local CosmeticModule = require(ReplicatedStorage.Modules.Cosmetic)
local GlobalFunctions = require(ReplicatedStorage.Modules.GlobalFunctions)
local Market = require(game.ServerStorage.ServerModules.Market)
local DailyReward = require(ReplicatedStorage.Modules.DailyReward)
local SafeTeleport = require(game.ServerScriptService.SafeTeleport)
local DeleteTakedownsAttribute = ReplicatedStorage.Events.DeleteTakedownsAttribute
local UpgradesModule = require(ReplicatedStorage.Upgrades)
local SellAndFuseModule = require(ReplicatedStorage.Modules.SellAndFuse)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local GetItemModel = require(ReplicatedStorage.Modules.GetItemModel)
local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)
local defaultData = require(script.DefaultData)
local DiscordHook = require(game.ServerStorage.ServerModules.DiscordWebhook)
local GetPlayerBoost = require(game.ReplicatedStorage.Modules.GetPlayerBoost)
local QuestHandler = require(game.ServerStorage.ServerModules.QuestHandler)
local HistoryLoggingService = require(script.HistoryLoggingService)
local SummonHook = DiscordHook.new("Summon")
local SummonMessenger = SummonHook:NewMessage()

local Compensation = DataStoreService:GetDataStore('Compensation')

local GroupRewards = ReplicatedStorage.Events:WaitForChild("GroupRewards")

local arrays = {"OwnedTowers","Buffs","RewardsClaimed","Codes","ItemsBought","Team"}

local function interact(player, item, willEquip)

	local function ReorganizeEquippedTowers()
		local currentCount = 0
	end

	local status = "Owned" 
	if item:GetAttribute("Equipped") == true then
		status = "Equipped"
	end

	local MAX_SELECTED_TOWERS = 3
	if player.PlayerLevel.Value >= 30 then
		MAX_SELECTED_TOWERS = 6
	elseif player.PlayerLevel.Value >= 20 then
		MAX_SELECTED_TOWERS = 5
	elseif player.PlayerLevel.Value >= 10 then
		MAX_SELECTED_TOWERS = 4
	end

	local equippedTowers = {}
	local totalEquipped = 0
	for i, v in player.OwnedTowers:GetChildren() do
		if v:GetAttribute("Equipped") == true then
			totalEquipped += 1
			equippedTowers[v:GetAttribute("EquippedSlot")] = v
			--table.insert(equippedTowers,v)
		end
	end

	if status == "Owned" then
		for _,towerValue in equippedTowers do
			if towerValue.Name == item.Name then
				ReplicatedStorage.Events.Client.Message:FireClient(player,"2 of the same type of unit cannot be equipped",Color3.fromRGB(166, 0, 0))
				return 
			end
		end
		local count = 1
		local equipToSlot = ""
		for i = 1, MAX_SELECTED_TOWERS do
			print(equippedTowers[`{count}`])
			if equippedTowers[`{count}`] == nil then
				equipToSlot = `{count}`
				print(count)
				break
			elseif count == MAX_SELECTED_TOWERS then
				equipToSlot = `{count}`
			end
			count += 1
		end

		if count > MAX_SELECTED_TOWERS then
			print(count, MAX_SELECTED_TOWERS)
			equippedTowers[equipToSlot]:SetAttribute("EquippedSlot","")
			equippedTowers[equipToSlot]:SetAttribute("Equipped",false)

			item:SetAttribute("EquippedSlot", equipToSlot)
			item:SetAttribute("Equipped",true)
		else
			item:SetAttribute("EquippedSlot", equipToSlot)
			item:SetAttribute("Equipped",true)
		end
	elseif status == "Equipped" then
		local wasEquipToSlot = item:GetAttribute("EquippedSlot")
		local subtractBy = 1
		print(equippedTowers, wasEquipToSlot)
		equippedTowers[wasEquipToSlot] = nil
		item:SetAttribute("Equipped",false)
		item:SetAttribute("EquippedSlot", "")

		for i = tonumber(wasEquipToSlot) + 1, totalEquipped do
			local tower = equippedTowers[`{i}`]
			if tower == nil then
				subtractBy += 1
			else
				equippedTowers[`{i}`]:SetAttribute("EquippedSlot", tostring(i - subtractBy) )
			end
		end
	end
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


_G.createTower = function(location,tower,trait,info,FirstUnit)
	local towerval = Instance.new("StringValue")
	towerval.Name = tower

	if not UpgradesModule[tower] then return end

	towerval:SetAttribute("Level",1)  
	towerval:SetAttribute("Exp",0)
	towerval:SetAttribute("Trait",trait or "")
	towerval:SetAttribute("Equipped",false)
	towerval:SetAttribute("Locked",false)
	towerval:SetAttribute("UniqueID", GlobalFunctions.GenerateID())
	towerval:SetAttribute("EquippedSlot", "")

	if FirstUnit then
		towerval:SetAttribute("Equipped",true)
		towerval:SetAttribute("EquippedSlot", "1")
	end

	task.spawn(function()
		local index = location:FindFirstAncestorOfClass("Player"):WaitForChild("Index"):WaitForChild("Units Index")
		if UpgradesModule[tower] then
			if not index:FindFirstChild(tower) then
				print("No index")
				local Value = Instance.new("BoolValue",index)
				Value.Name = tower
			end
		end
	end)


	if UpgradesModule[tower] and UpgradesModule[tower].Takedowns then
		towerval:SetAttribute("Takedowns",0)
	end

	--print( info )
	local shinyLimited = false
	if info then
		if info["Shiny"] then
			--print('yep shiny')
			towerval:SetAttribute("Shiny",true)
		end
	end

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
	else
		warn('Unit not found!')
	end


	towerval.Parent = location
	return towerval
end

local debounces = {}


for i, v in StoryModeStats.Worlds do
	defaultData["WorldStats"][v] = {
		LevelStats = {},
		InfiniteRecord = -1
	}
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

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local MPS = game:GetService("MarketplaceService")
local Raycast = require(ReplicatedStorage.Modules.Raycast)

local currentPass = ReplicatedStorage.CurrentPassName.Value

--local admins = require(ReplicatedStorage.Admins)
local ChanceModule = require(ReplicatedStorage.Chances)

local ProfileService = require(game.ServerStorage.ServerModules.ProfileService)
local SecondOldProfileStore = ProfileService.GetProfileStore(
	"InventoryV2",
	defaultData
)
local GameProfileStore = ProfileService.GetProfileStore(
	"UserDataV2",
	defaultData
)

local OldDataStore = DataStoreService:GetDataStore("Inventory")

local Events = ReplicatedStorage:WaitForChild("Events")
local Functions = ReplicatedStorage:WaitForChild("Functions")

local summonBannerEvent = Functions:WaitForChild("SummonBannerEvent")

local red = Color3.new(1, 0, 0)
local orange = Color3.new(1, 0.333333, 0)
local yellow = Color3.new(1, 1, 0)
local green = Color3.new(0, 1, 0)
local blue = Color3.new(0, 0.666667, 1)
local indigo = Color3.new(0, 0.333333, 1)
local violet = Color3.new(0.333333, 0, 1)

local rainbowSequence = ColorSequence.new{
	ColorSequenceKeypoint.new(0, red),
	ColorSequenceKeypoint.new(0.166, orange),
	ColorSequenceKeypoint.new(0.333, yellow),
	ColorSequenceKeypoint.new(0.498, green),
	ColorSequenceKeypoint.new(0.665, blue),
	ColorSequenceKeypoint.new(0.831, indigo),
	ColorSequenceKeypoint.new(1, violet)
}

local specialSequence = ColorSequence.new{
	ColorSequenceKeypoint.new(0, red),
	ColorSequenceKeypoint.new(0.831, indigo),
	ColorSequenceKeypoint.new(1, violet)
}

local timeUntilNextReward = 24 -- this is in hours

local rewards = {
	25,  -- 1 day
	35,  -- 2 day
	50,  -- 3 day
	70,  -- 4 day 
	90,  -- 5 day
	120, -- 6 day
	150, -- 7 day
}

local Profiles = {}

local function addBuff(Player,buff)
	local buff_found = false
	for i, v in Player.Buffs:GetChildren() do
		if v.Name == buff.BuffType and v.Multiplier.Value == buff.Multiplier then
			buff_found = true
			v.Duration.Value += buff.Duration
		end
	end
	print('has buff been found: btw thi sis the buff type; ')
	warn(buff)
	print(buff_found)
	if not buff_found then
		local folder = Instance.new("Folder")
		folder.Name = buff.BuffType
		local buffval = Instance.new("StringValue")
		buffval.Name = "Buff"
		buffval.Value = buff.Buff
		buffval.Parent = folder
		local starttime = Instance.new("NumberValue")
		starttime.Name = "StartTime"
		starttime.Value = buff.StartTime
		starttime.Parent = folder
		local duration = Instance.new("NumberValue")
		duration.Name = "Duration"
		duration.Value = buff.Duration
		duration.Parent = folder
		local multiplier = Instance.new("NumberValue")
		multiplier.Name = "Multiplier"
		multiplier.Value = buff.Multiplier
		multiplier.Parent = folder
		folder.Parent = Player.Buffs
		warn((folder.StartTime.Value + folder.Duration.Value) - os.time())
	end
end

--local MarketModule = require(ReplicatedStorage.Modules.MarketModule)

local MarketPlaceService =  game:GetService('MarketplaceService')

local function onPromptPurchaseFinished(player, assetId, isPurchased)
	if isPurchased then
		print(player.Name, "bought an item with AssetID:", assetId)
	else
		print(player.Name, "didn't buy an item with AssetID:", assetId)
	end
end

MPS.PromptPurchaseFinished:Connect(onPromptPurchaseFinished)
MarketPlaceService.ProcessReceipt = Market.ProcessReceipt

Functions.GetMarketInfoById.OnServerInvoke = function(player, Id)
	return Market.GetInfoById(Id)
end
Functions.GetMarketInfoByName.OnServerInvoke = function(player, name)
	return Market.GetInfoByName(name)
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
				local attributes = {"Level","Exp","Trait","Equipped","Locked","UniqueID","EquippedSlot","TimeObtained","Shiny","Takedowns"}
				for _, towerData in element do
					local newTower = _G.createTower(folder,towerData["TowerName"],nil,{Shiny=towerData["Shiny"],TimeObtained=towerData["TimeObtained"],LoadingData = true})
					if newTower then
						for j, attribute in attributes do
							if towerData[attribute] then
								if attribute == "Equipped" and towerData.EquippedSlot == "" then
									if towerData[attribute] == 'CC' then
										towerData[attribute] = 'Cosmic Crusader'
									end
									if towerData[attribute] == 'Mando' then
										towerData[attribute] = 'Mandalorian'
									end
									newTower:SetAttribute(attribute,false)
								else
									if attribute == 'Trait' then
										if towerData[attribute] == 'CC' then
											towerData[attribute] = 'Cosmic Crusader'
										end
										if towerData[attribute] == 'Mando' then
											towerData[attribute] = 'Mandalorian'
										end
									end

									newTower:SetAttribute(attribute,towerData[attribute])
								end
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
						local attributes = {"Level","Exp","Trait","Equipped","Locked","UniqueID","EquippedSlot","TimeObtained","Shiny","Takedowns"}
						print(towerData, index)
						local newTower = _G.createTower(folder,towerData["TowerName"],nil,{Shiny=towerData["Shiny"],TimeObtained=towerData["TimeObtained"],LoadingData = true})
						for j, attribute in attributes do
							if towerData[attribute] then
								if attribute == 'Trait' then
									if towerData[attribute] == 'CC' then
										towerData[attribute] = 'Cosmic Crusader'
									end
									if towerData[attribute] == 'Mando' then
										towerData[attribute] = 'Mandalorian'
									end
								end

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
					buff.StartTime.Value = buffData["StartTime"] --os.time() --
					buff.Parent = folder
				end
			else
				DeepLoadDataToInstances(element, folder)
			end
		end
	end

	-- reconcile
end

local function DeepSaveInstancesToData(instancesChildren, currentLayer, playerLeaving)
	currentLayer += 1
	local newData = {}
	for index, element in instancesChildren do
		if currentLayer == 1 and defaultData[element.Name] == nil then continue end
		if element:IsA("ValueBase") then

			if currentLayer == 1 and defaultData[element.Name] then	--double check to make sure that it doesnt copy instances that are not part of the data
				newData[element.Name] = element.Value
			else
				--print(playerLeaving, print(element.Name), element.Parent:FindFirstAncestor("Buffs"))
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
					towerstats["Takedowns"] = tower:GetAttribute("Takedowns")

					table.insert(newData[element.Name],towerstats)
				end
			elseif element.Name == "TeamPresets" then
				for _, teamFolder in element:GetChildren() do
					newData[element.Name][teamFolder.Name] = {}

					for _, tower in teamFolder:GetChildren() do
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
						towerstats["Takedowns"] = tower:GetAttribute("Takedowns")
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

local groupID = 35339513

function Get(id)
	return 	GameProfileStore:LoadProfileAsync(
		id.."PlayerData",
		"ForceLoad"
	)
end

function LoadDataVersion(player, profile, dataVersionString)
	local placeId = 135405300632248
	local function TeleportPlayers()

		print("Teleport")
		SafeTeleport(placeId, {player})
	end


	local useDataStore 
	local validDataStoreVersion = false
	local selectVersionString = dataVersionString or profile.Data.SelectedVersion
	if selectVersionString == nil then return false end --fail to load version

	if selectVersionString == "Inventory" then
		validDataStoreVersion = true
		useDataStore = OldDataStore

	elseif selectVersionString == "InventoryV2" then
		validDataStoreVersion = true
		useDataStore = SecondOldProfileStore

	end
	print(validDataStoreVersion, selectVersionString)
	print(profile.Data)
	if not validDataStoreVersion then return false end --fail to load version due to invalid versionString

	if profile.Data.DataTransferFromOldData == false then	--current profile havent grab either older version
		local loadcount = 0
		local dataLoadedSuccessully
		local oldData = nil
		print("LoadAttempt", useDataStore)
		repeat
			dataLoadedSuccessully, errorMessage = pcall(function()

				if selectVersionString == "Inventory" then
					oldData = useDataStore:GetAsync(player.UserId.."PlayerData")
				else
					oldData = useDataStore:LoadProfileAsync(
						player.UserId.."PlayerData"
					)
				end

			end)
			loadcount = loadcount + 1
		until loadcount >= 3 or dataLoadedSuccessully
		print(dataLoadedSuccessully, oldData)
		if dataLoadedSuccessully then
			print(oldData)
			if oldData ~= nil then
				if selectVersionString == "Inventory" then
					--old data with profile service
					MergeData(oldData, profile.Data)
					profile.Data = oldData
				else
					--data without profile service
					MergeData(oldData.Data, profile.Data)
					profile.Data = oldData.Data
				end
			end


			profile.Data.DataTransferFromOldData = true
			profile:Release()
			game:GetService("TeleportService"):TeleportAsync(placeId, {player})
			--player:Kick("Plz rejoin to update your data")
		else
			profile:Release()
		end  

	else
		if profile.MetaData.SessionLoadCount == 1 then
			--_G.createTower(player.OwnedTowers, "Saske Kid")
		end

	end

	return true
end

function LoadOwnedTowersVersionFolders(player)

	local function LoadUnitsFolder(folderName, ownedTowersTable)
		local folder = Instance.new("Folder")
		folder.Name = folderName

		local attributes = {"Level","Exp","Trait","Equipped","Locked","UniqueID","EquippedSlot","TimeObtained","Shiny"}
		for _, towerData in ownedTowersTable do
			local newTower = _G.createTower(folder,towerData["TowerName"],nil,{Shiny=towerData["Shiny"],TimeObtained=towerData["TimeObtained"]})
			for j, attribute in attributes do
				if towerData[attribute] then
					if attribute == "Equipped" and towerData.EquippedSlot == "" then
						newTower:SetAttribute(attribute,false)
					else
						newTower:SetAttribute(attribute,towerData[attribute])
					end

				end
			end
		end

		folder.Parent = player

	end


	local firstData

	local success1, result1
	local loadcount = 0
	repeat
		success1 = pcall(function()
			result1 = OldDataStore:GetAsync(player.UserId.."PlayerData")
		end)
		loadcount = loadcount + 1
	until loadcount >= 3 or success1

	local result2
	local success2 = pcall(function()
		result2 = SecondOldProfileStore:ViewProfileAsync(
			player.UserId.."PlayerData"
		)
	end)
	print(success1, success2)
	if not success1 or not success2 then return false end
	print(result1, result2)
	local loadBothFolderSuccessfully, errorResult = pcall(function()
		if result1 ~= nil then
			MergeData(result1, defaultData)
			LoadUnitsFolder("OlderData", result1.OwnedTowers)
		end
		if result2 ~= nil then
			MergeData(result2, defaultData)
			LoadUnitsFolder("NewerData", result2.Data.OwnedTowers)
		end

	end)
	print(errorResult)
	if not loadBothFolderSuccessfully then return false end

	return true

end


game.Players.PlayerAdded:Connect(function(player)

	local profile = GameProfileStore:LoadProfileAsync(
		player.UserId.."PlayerData",
		"ForceLoad"
	)
	--print(profile)
	local dataIsNew = false
	debounces[player.Name] = {
		Trait = false,
	}


	if profile ~= nil then

		--print(profile)
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate (optional)
		profile:ListenToRelease(function()
			if player:FindFirstChild("DataLoaded") then
				player.DataLoaded:Destroy()
			end
			Profiles[player] = nil
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			profile = HistoryLoggingService.log(profile, true)

			AnalyticsService:LogOnboardingFunnelStepEvent(
				player, 
				1,
				"player joined"
			)

			--if profile.Data.DataTransferFromOldData == false then
			--	if profile.Data.SelectedVersion ~= "" then
			--		LoadDataVersion(player, profile, profile.Data.SelectedVersion)
			--	else
			--		local versionFoldersLoaded = LoadOwnedTowersVersionFolders(player)
			--		print(versionFoldersLoaded)
			--		if not versionFoldersLoaded then
			--			profile:Release()
			--			return
			--		end
			--	end

			--end

			--local wiping = {
			--	['High General'] = true,
			--	['Colonel'] = true,
			--	['Storm Scout'] = true,
			--	['Storm Commander'] = true,
			--	['Captain'] = true,
			--	['Death Trooper'] = true,
			--	['Quinion Vas'] = true,
			--	['Tenth Brother'] = true,
			--}

			--if player.Name ~= "Wh1teosnako" then
			--	for i = #profile.Data.OwnedTowers, 1, -1 do
			--		local unitName = profile.Data.OwnedTowers[i].TowerName
			--		--warn('ASJFIOASDJHFIOASDJIOFIJASDOFPODSJFOI:')
			--		--print(unitName)
			--		if wiping[unitName] then
			--			table.remove(profile.Data.OwnedTowers, i)
			--			table.remove(profile.Data.Index["Units Index"], i)
			--		end
			--	end
			--end

			--print(profile.Data.DataTransferFromOldData)

			local statsData = profile.Data


			--Temporary Fix to give storage
			if statsData.OwnGamePasses["Extra Storage"] == true and statsData.MaxUnits <= 100 then
				statsData.MaxUnits = 200
			end

			DeepLoadDataToInstances(statsData, player)

			--warn('DEEP LOADING!')

			if not player.receivedScout.Value and #player.OwnedTowers:GetChildren() == 0 then
				--warn('its the players first time!')

				--player.Gems.Value += 50

				-- tell them to summon
				--ReplicatedStorage.Remotes.ForceSummon:FireClient(player)
				_G.createTower(player.OwnedTowers, "Scout")
				local unit = player.OwnedTowers:FindFirstChild('Scout')

				interact(player, unit, true)
				print('GIEV')
				player.receivedScout.Value = true
			end
			
			if player.MaxUnits.Value == 100 then
				player.MaxUnits.Value = defaultData.MaxUnits
			elseif player.MaxUnits.Value == 200 then
				player.MaxUnits.Value = 250
			end

			-- reconcile items
			for i,v in ItemStatsModule do
				if not player.Items:FindFirstChild(i) then
					Instance.new("IntValue", player.Items).Name = i
				end
			end

			--1304495868535931

			if player.Stats.Kills.Value >= 1138 then
				BadgeService:AwardBadge(player.UserId, 1304495868535931)
			end

			--for i,v in player.Items:GetChildren() do

			--end

			--task.spawn(function()
			--	--task.wait( 5 )
			--	--task.wait(9e9) -- cuz broken atm
			--	while task.wait( 1 ) do
			--		if ABTesting.GameAnalytics:isPlayerReady(player.UserId) and ABTesting.GameAnalytics:isRemoteConfigsReady(player.UserId) then
			--			local treatment = ABTesting.selectTreatment(player)
			--			if treatment then
			--				player.ABTesting.Treatment.Value = treatment
			--				player.ABTesting.TreatmentSet.Value = true
			--				print("setting treatment")
			--			end

			--			break
			--		end
			--	end
			--end)

			if player.RaidReset.Value ~= '-4' then
				player.RaidLimitData.OldReset.Value = tick()-1
				player.RaidLimitData.NextReset.Value = tick()-1 -- force the server to reset them
				player.RaidLimitData.Attempts.Value = 10
				player.OwnGamePasses['Premium Season Pass'].Value = false
				player.RaidReset.Value = '-4'
			end


			--warn("PLAYER LOADING")

			for _, v in player:WaitForChild("Items"):GetChildren() do
				if v.Name == "Super Lucky" or v.Name == "Ultra Lucky" then
					v:Destroy()
				end
			end


			--for _, tower in game.ReplicatedStorage.Towers:GetChildren() do
			--	if tower:IsA("Model") then
			--		_G.createTower(player.OwnedTowers,tower.Name)
			--	end
			--end




			local function updatePlayerExp()
				local newLevel,newExp = ExpModule.playerLevelCalculation(player, player.PlayerLevel.Value,player.PlayerExp.Value) --math.round(50 + (10 * player.PlayerLevel.Value))

				player.PlayerExp.Value = newExp
				player.PlayerLevel.Value = newLevel
			end
			updatePlayerExp()
			player.PlayerExp.Changed:Connect(updatePlayerExp)
			Profiles[player] = profile

			RaidDataSync.init(player)

			local DataLoaded = Instance.new("Folder")
			DataLoaded.Name = "DataLoaded"
			DataLoaded.Parent = player



			local ServerJoined = Instance.new("NumberValue")
			ServerJoined.Name = "ServerJoined"
			ServerJoined.Value = os.time()
			ServerJoined.Parent = player

			task.spawn(function()
				--print(Profiles, Profiles[player])
				while player and player:IsDescendantOf(Players) do
					if Profiles[player] ~= nil and player:FindFirstChild("DataLoaded") then
						local dat = DeepSaveInstancesToData(player:GetChildren(), 0)

						--warn('SAVING DATA:')
						--print(dat)

						Profiles[player].Data = dat
					else
						break
					end
					task.wait(1)
				end
			end)


			-- Load Clan Data
			local CurrentClan = player.ClanData.CurrentClan
			if CurrentClan.Value ~= 'None' then
				task.spawn(function()
					repeat task.wait() until ReplicatedStorage.Clans:FindFirstChild(CurrentClan.Value)
					Instance.new('Folder', player).Name = 'CurrentClanLoaded'
				end)
			else
				Instance.new('Folder', player).Name = 'CurrentClanLoaded'
			end

			local DataLoaded = Instance.new("Folder")
			DataLoaded.Name = "ClansLoaded"
			DataLoaded.Parent = player
			
			AuraHandling.equipAura(player, player.EquippedAura.Value)

			local compensationRewards = {
				['Battlepass'] = function(plr, item)
					player.BattlepassData.Premium.Value = true
				end,
				['Battlepass Bundle'] = function(plr, item)
					local bpData = plr.BattlepassData

					--plr.OwnGamePasses['Episode 2 Pass'].Value = true
					plr.LuckySpins.Value += 5
					bpData.Premium.Value = true
					bpData.Tier.Value += 20

				end,
				['Clans'] = function(plr, amount)
					plr.Gems.Value += amount
				end,
				['Gems'] = function(plr, amount)
					plr.Gems.Value += amount
				end,
			}

			local data = Compensation:GetAsync(player.UserId)

			if data then
				for i,v in data do
						--[[
						Type = "thing",
						Item = 'Item'
						
						--]]

					if compensationRewards[v.Type] then
						compensationRewards[v.Type](player, v.Item)
					end
				end
			end
			Compensation:RemoveAsync(player.UserId)

		else
			profile:Release() -- Player left before the profile loaded
		end

	else
		-- The profile couldn't be loaded possibly due to other
		--   Roblox servers trying to load this profile at the same time:
		player:Kick() 
	end
	--print(defaultData)

end)





local debounce = false
local dictionaryFolders = {}

Players.PlayerRemoving:Connect(function(player)
	local profile = Profiles[player]
	if profile ~= nil then
		local ServerJoined = player:FindFirstChild("ServerJoined")
		if ServerJoined then
			player.TimeSpent.Value += ( os.time() - ServerJoined.Value )
		end

		player.FirstTime.Value = false
		local dat = DeepSaveInstancesToData(player:GetChildren(), 0, true)
		if #dat ~= 0 then
			warn('LOGGING OUT')
			dat = HistoryLoggingService.log(dat, false)
			profile.Data = dat
		end

		--print(Profiles, profile)
		profile:Release()

	end
end)



ReplicatedStorage.Events.EquipEvent.OnServerEvent:Connect(function(Player, ...)
	local Data = (...)
	if not Data then return end

	local TowerName = Data.Name



	-- check if has tower
	-- check if its equipped/unequipped
	-- equip/unequip unit
end)

ReplicatedStorage.Events.UpdateSetting.OnServerEvent:Connect(function(player, changeSetting, newValue)
	player.Settings[changeSetting].Value = newValue
end)

GroupRewards.OnServerEvent:Connect(function(player)
	if not player.ClaimedGroupReward.Value then
		player.ClaimedGroupReward.Value = true
		player.Gems.Value += 500
	end
end)

ReplicatedStorage.Events.InteractItem.OnServerEvent:Connect(interact)

ReplicatedStorage.Events.LockTower.OnServerEvent:Connect(function(player,towerValue)
	local ownedTowersList = player.OwnedTowers:GetChildren()
	local validTower = ownedTowersList[table.find(ownedTowersList, towerValue)]
	if validTower then
		validTower:SetAttribute("Locked",not validTower:GetAttribute("Locked"))
	end
end)

--Only for selling tower at the moment
function SellItem(player, sellTowerList)
	local soldEquippedTower = false
	local totalSoldFor = 0
	for _,tower in sellTowerList do
		local ownedList = player.OwnedTowers:GetChildren()
		local towerStats = UpgradesModule[tower.Name]
		local validTower =  ownedList[ table.find(ownedList,tower) ]
		if not validTower or tower:GetAttribute("Locked") == true or towerStats.Rarity == "Exclusive" then continue end
		if validTower:GetAttribute("Equipped") then
			soldEquippedTower = true
		end

		local refundCoin = SellAndFuseModule.RaritySellPrice[UpgradesModule[tower.Name].Rarity]
		refundCoin += refundCoin * GetPlayerBoost(player, "Coins")

		tower:Destroy()
		player.Coins.Value += refundCoin
		totalSoldFor += refundCoin
	end



end
ReplicatedStorage.Events.SellItem.OnServerEvent:Connect(SellItem)

ReplicatedStorage.Functions.GetTime.OnServerInvoke = function()
	return os.date("*t")
end

local function locate(table, value)
	if table ~= nil then  
		for i,v in table do
			if i == value then
				return table[i]
			end
		end
	end
	return nil
end

ReplicatedStorage.Events.UpdateTowerLevelEvent.OnServerEvent:Connect(function(player,towerValue,itemsUseList)

	local maxLevel, maxExp = ExpModule.getTowerMaxStats()
	warn(itemsUseList)
	for itemName, quantity in pairs(itemsUseList) do
		if quantity <= 0 then
			warn("Skipped item with non-positive quantity:", itemName, quantity)
			continue
		end

		local itemValue = player.Items:FindFirstChild(itemName)
		if not itemValue then
			warn("Item not found in inventory:", itemName)
			continue
		end

		if itemValue.Value < quantity then
			warn("Not enough quantity for:", itemName, "Required:", quantity, "Available:", itemValue.Value)
			continue
		end

		local itemStats = ItemStatsModule[itemName]
		if not itemStats or itemStats.Itemtype ~= "XP_feed" then
			warn("Item not valid for XP feed:", itemName)
			continue
		end
		itemValue.Value -= quantity
		local baseExp = itemStats.XP_amount * quantity
		warn(itemStats.XP_amount)
		local newTotalExp = baseExp + towerValue:GetAttribute("Exp")
		warn(newTotalExp)
		local towerTrait = towerValue:GetAttribute("Trait")
		if towerTrait ~= "" then
			local traitData = TraitsModule.Traits[towerTrait]
			print(traitData)
			if traitData and traitData.Exp then
				print("Bous")
				local bonusExp = newTotalExp * (traitData.Exp / 100)
				newTotalExp += bonusExp
			end
		end
		warn(newTotalExp)

		local newLevel, newExp = ExpModule.towerLevelCalculation(
			player,
			towerValue:GetAttribute("Level"),
			newTotalExp
		)



		towerValue:SetAttribute("Level", math.clamp(newLevel, 1, maxLevel))
		towerValue:SetAttribute("Exp", math.clamp(newExp, 0, maxExp))

		warn(string.format("Fed %d of %s. New Level: %d, New Exp: %d", quantity, itemName, newLevel, newExp))
	end



end)

local summonCooldown = {}
-- summonBannerEvent:InvokeServer
summonBannerEvent.OnServerInvoke = function(player,quantity,HolocronSummon, isLucky, selectedBannerIndex)
	if isLucky and player.LuckySpins.Value == 0 then return "You do not have enough spins" end   

	if #player.OwnedTowers:GetChildren()+quantity > player.MaxUnits.Value then
		return "Unit inventory full!"
	end
	if summonCooldown[player] then return "Summon on cooldown" end
	task.spawn(function()
		summonCooldown[player] = true
		task.wait(1)
		summonCooldown[player] = false
	end)
	local holocron = nil
	selectedBannerIndex = math.clamp(tonumber(selectedBannerIndex) or 1, 1, 3)
	if HolocronSummon then
		if player.Items["Holocron Summon Cube"].Value > 0 then
			holocron = true
		end
	end

	quantity = math.clamp(quantity,1,10)
	local cost = 50

	if player.OwnGamePasses.VIP.Value then
		cost = 40 * quantity -- - (math.floor(quantity/10)*40)
	else
		cost = 50 * quantity -- - (math.floor(quantity/10)*50)
	end
	if player.OwnGamePasses["Ultra VIP"].Value then
		cost = 35 * quantity -- - (math.floor(quantity/10)*40)
	end
	if player.Gems.Value >= cost or holocron or isLucky then
		if holocron then
			player.Items["Holocron Summon Cube"].Value -= quantity
			quantity = 10
		elseif not isLucky then
			player.Gems.Value -= cost
		end

		local newUnits = {}
		local sellList = {}
		for i=1, quantity do
			if isLucky and player.LuckySpins.Value == 0 then break end
			if isLucky then
				player.LuckySpins.Value -= 1
			end

			local unit = ChanceModule.chooseRandomUnit(player, isLucky, selectedBannerIndex)
			--player.Quest.Daily.Summon.Progress.Value+=1
			--unit = ReplicatedStorage.Upgrades.Mythical.Plooo

			if unit.Name == "TraitPoint" then
				table.insert(newUnits,{
					Item = unit,
					AutoSell = false
				})
			else

				local unitName = unit.Name -- unit.Name
				local unitStats = UpgradesModule[unitName]
				local isAutoSell = (player.AutoSell:FindFirstChild(unitStats.Rarity) and player.AutoSell[unitStats.Rarity].Value) or nil
				local isShiney = unit:GetAttribute("Shiny")

				local raritiesGrade = {
					Rare = 1,
					Epic = 2,
					Legendary = 3,
					Mythical = 4,
					Unique = 5
				}

				local hasTrait = unit:GetAttribute("Trait") ~= "" and unit:GetAttribute("Trait") or false
				local traitRarity = hasTrait and TraitsModule.Traits[hasTrait] and TraitsModule.Traits[hasTrait].Rarity

				local isTraitMythical = (hasTrait and raritiesGrade[traitRarity] ~= nil and raritiesGrade[traitRarity] >= raritiesGrade.Mythical) or false

				if isAutoSell and not isShiney and not isTraitMythical then
					table.insert(sellList, unit)
				end

				--game.gameid
				if unitStats.Rarity == 'Legendary' then
					BadgeService:AwardBadge(player.UserId, 1600961271455049)
				end


				if unitStats.Rarity == "Secret" then

					--local SummonMessenger = SummonHook:NewMessage()
					--local msg = SummonMessenger:NewEmbed()
					--msg:SetColor3(Color3.fromRGB(255, 0, 0))
					--msg:SetTitle(`PlayerName: {player.Name} | PlayerId: {player.UserId}`)
					--msg:AppendLine(`Character: {unit.Name} | Rarity: {unitStats.Rarity}`)
					--msg:AppendLine(`Trait: {unit:GetAttribute("Trait") == "" and "None" or unit:GetAttribute("Trait")}`)
					--msg:AppendLine(`TimeStamp: {DateTime.now():ToIsoDate()}`)
					--SummonMessenger:Send()

					MessagingService:PublishAsync("GlobalSummon", `<font color="rgb({66},{135},{245})">[GLOBAL]</font> <i>{player.Name}</i> summoned a <font color="#ff0000"><font face="FredokaOne">{unitStats.Name}.</font></font>`)
				elseif unitStats.Rarity == "Mythical"  then
					local stringToConvert = unitStats.Name
					local stringToColor = ""
					local hueIncrement = 1/(#stringToConvert)
					for i = 1, #stringToConvert do
						local colorInHSV = Color3.fromHSV(hueIncrement * i,1,1)
						local R,G,B = math.round(colorInHSV.R * 255), math.round(colorInHSV.G * 255), math.round(colorInHSV.B * 255)
						stringToColor = `{stringToColor}<font color="rgb({R},{G},{B})">{string.sub(stringToConvert,i,i)}</font>`
					end

					--local SummonMessenger = SummonHook:NewMessage()
					--local msg = SummonMessenger:NewEmbed()
					--msg:SetColor3(Color3.fromRGB(0, 255, 234))
					--msg:SetTitle(`PlayerName: {player.Name} | PlayerId: {player.UserId}`)
					--msg:AppendLine(`Character: {unit.Name} | Rarity: {unitStats.Rarity}`)
					--msg:AppendLine(`Trait: {unit:GetAttribute("Trait") == "" and "None" or unit:GetAttribute("Trait")}`)
					--msg:AppendLine(`TimeStamp: {DateTime.now():ToIsoDate()}`)
					--SummonMessenger:Send()
					if unit:GetAttribute("Shiny") then
						MessagingService:PublishAsync("GlobalSummon", `<font color="rgb({255},{215},{0})">[GLOBAL]</font> <i>{player.Name}</i> summoned a <font color="rgb({52},{21},{57})">SHINY</font> <font face="FredokaOne">{stringToColor}.</font>`)
					else
						Events.Client.ChatMessage:FireAllClients(`[Server] <i>{player.Name}</i> summoned a <font face="FredokaOne">{stringToColor}.</font>`)
					end


				end
				table.insert(newUnits,{
					Tower = unit,
					AutoSell = isAutoSell
				})
			end


		end

		if #sellList > 0 then
			--task.delay(1,function()
			SellItem(player, sellList)
			--end)
		end
		QuestHandler.UpdateQuestProgress(player, "summon_unit", {AddAmount = #newUnits})
		for _, unit in newUnits do
			if unit.Item and unit.Item == "TraitPoint" or not unit.Tower then continue end
			--warn(unit)
			local unitStats = UpgradesModule[unit.Tower.Name]
			--print(unit.Tower, unit.Tower.Name, unitStats)
			QuestHandler.UpdateQuestProgress(player, "summon_rarity_unit", {AddAmount = 1, Rarity = unitStats.Rarity})
		end

		AnalyticsService:LogOnboardingFunnelStepEvent(
			player,
			2,
			"summon unit"
		)
		return newUnits
	else
		return "You need "..cost - player.Gems.Value.." more gems!"
	end
end

--local BrawlPassModule = require(ReplicatedStorage.BrawlPass)
--Functions.ClaimPass.OnServerInvoke = function(player)
--	return BrawlPassModule.Functions.ClaimAll(player)
--end

Events.UseItem.OnServerEvent:Connect(function(player,item)
	if not player.Items:FindFirstChild(item) or player.Items[item].Value <= 0 then return end
	if ItemStatsModule[item].Itemtype ~= "Boost" then return end

	player.Items:FindFirstChild(item).Value -= 1
	local buff = ItemStatsModule[item].Buff
	buff["StartTime"] = os.time()
	if buff then
		addBuff(player,buff)
		ReplicatedStorage.Events.Client.Message:FireClient(player,"Successfully applied!",Color3.new(0.168627, 1, 0.168627))
	else
		ReplicatedStorage.Events.Client.Message:FireClient(player,"Error!",Color3.new(0.827451, 0, 0))
	end
end)


script.ApplyBuff.Event:Connect(function(plr, buff)
	addBuff(plr, buff)
end)


Events.Gift.OnServerEvent:Connect(Market.Gift)
Events.Buy.OnServerEvent:Connect(Market.Buy)

Events.TeleportToChamber.OnServerEvent:Connect(function(player)
	local function TeleportPlayers()
		local placeId = PlaceData.AFKChamber
		if placeId ~= nil then
			local server = TeleportService:ReserveServer(placeId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = server
			--options:SetTeleportData({
			--	World = world,
			--	Level = level,
			--	Mode = 2, 
			--	ChallengeNumber = self.ChallengeData.ChallengeNumber, 
			--	ChallengeUniqueId = DataFolder.RefreshingAt.Value,
			--	ChallengeRewardNumber = self.ChallengeData.ChallengeRewardNumber
			--})
			SafeTeleport(placeId, {player}, options)
		end
	end
	print("Teleporting")
	TeleportPlayers()
end)

--Functions.QuestComplete.OnServerInvoke = function(player,questType,questInfo)
--	if questType == "Story" then
--		local storyLevelsBeat = ((player.StoryProgress.World.Value-1) * 6) + player.StoryProgress.Level.Value - 1
--		local questLevelsBeat = ((questInfo.World-1) * 6) + questInfo.Level
--		print(storyLevelsBeat)
--		print(player.Quest.StoryClaimed.Value)
--		print(questLevelsBeat)
--		if player.Quest.StoryClaimed.Value + 1 <= storyLevelsBeat and player.Quest.StoryClaimed.Value + 1 == questLevelsBeat then
--			player.Quest.StoryClaimed.Value = questLevelsBeat
--			if questInfo.Level == 6 then
--				player.Gems.Value += 100
--				player.TraitPoint.Value += 1
--			else
--				player.Gems.Value += 50
--			end
--			return true
--		end
--	elseif questType == "Infinite" then
--		local QuestFolder = player:WaitForChild("Quest"):WaitForChild("Infinite"):FindFirstChild(questInfo)
--		if QuestFolder then
--			local worldNumber = table.find(StoryModeStats.Worlds,QuestFolder.Map.Value)
--			if QuestFolder.Claimed.Value == false and QuestFolder.Progress.Value >= QuestStore.InfiniteWaves[QuestFolder.Difficulty.Value].Progress then
--				QuestFolder.Claimed.Value = true
--				player.Gems.Value += QuestStore.InfiniteWaves[worldNumber].Reward.Gems
--				return true
--			end
--		end
--	elseif questType == "Daily" then
--		local QuestFolder = player:WaitForChild("Quest"):WaitForChild("Daily"):FindFirstChild(questInfo)
--		if QuestFolder then
--			if QuestFolder.Claimed.Value == false and QuestFolder.Progress.Value >= QuestStore.Daily[questInfo][QuestFolder.Difficulty.Value].Progress then
--				QuestFolder.Claimed.Value = true
--				player.Gems.Value += QuestStore.Daily[questInfo][QuestFolder.Difficulty.Value].Reward.Gems
--				return true
--			end
--		end
--	end
--	--if table.find(QuestStore.DailyQuestTypes,questType) then
--	--	if player.DailyStats[questType].Value >= QuestStore[questType][player.Quest.Daily[questType].Value]["Progress"] then
--	--		if player.Quest.Daily[questType].Value <= #QuestStore[questType] then
--	--			player.Coins.Value += QuestStore[questType][player.Quest.Daily[questType].Value]["Reward"].Value
--	--			player.Quest.Daily[questType].Value += 1
--	--			return player
--	--		end
--	--	end
--	--elseif table.find(QuestStore.WeeklyQuestTypes,questType) then
--	--	if QuestStore[questType][player.Quest.Weekly[questType]] then
--	--		if player.WeeklyStats[questType].Value >= QuestStore[questType][player.Quest.Weekly[questType].Value]["Progress"] then
--	--			if player.Quest.Weekly[questType].Value <= #QuestStore[questType] then
--	--				player.Coins.Value += QuestStore[questType][player.Quest.Weekly[questType]]["Reward"]
--	--				player.Quest.Weekly[questType].Value += 1
--	--				return player
--	--			end
--	--		end
--	--	else
--	--		print(questType)
--	--		print(player.Quest.Weekly[questType])
--	--		print(QuestStore[questType])
--	--	end
--	--end
--end


Functions.ClaimReward.OnServerInvoke = DailyReward.Claim

Functions.EvolveUnit.OnServerInvoke = function(plr, tower)
	if tower == nil or plr == nil then return false end
	if tower.Parent == plr:WaitForChild("OwnedTowers") then
		if UpgradesModule[tower.Name] then
			if UpgradesModule[tower.Name]["Evolve"] then
				local requirements = UpgradesModule[tower.Name]["Evolve"]["EvolutionRequirement"]
				local playerhas = {}

				for i, v in UpgradesModule[tower.Name]["Evolve"]["EvolutionRequirement"] do
					playerhas[i] = v
				end

				for i, v in playerhas do
					playerhas[i] = 0
				end
				for i, v in plr.OwnedTowers:GetChildren() do
					for towername, quantity in playerhas do
						if v.Name == towername and v:GetAttribute("Equipped") == false and v:GetAttribute("Locked") ~= true and v ~= tower then
							playerhas[towername] = playerhas[towername] + 1
						end
					end
				end
				for i, v in plr.Items:GetChildren() do
					for towername, quantity in playerhas do
						if v.Name == towername then
							playerhas[towername] = v.Value
						end
					end
				end
				local cannotcraft = false
				for i, v in requirements do
					if v > playerhas[i] then
						cannotcraft = true
					end
				end
				local Takedowns = tower:GetAttribute("Takedowns")
				local TakedownsEnought = nil
				if Takedowns then
					TakedownsEnought = Takedowns >= UpgradesModule[tower.Name].Takedowns
				end


				if cannotcraft then
					Events.Client.Message:FireClient(plr,"Not Enough Materials!",Color3.new(0.764706, 0, 0.0117647),nil,"Error")
					return
				end
				if Takedowns then
					if not TakedownsEnought then
						Events.Client.Message:FireClient(plr,"Not Enough Takedowns!",Color3.new(0.764706, 0, 0.0117647),nil,"Error")
						return
					end
				end

				if not cannotcraft and (TakedownsEnought == nil or TakedownsEnought) then
					for towername, quantity in requirements do
						for i=1, quantity do
							if plr.OwnedTowers:FindFirstChild(towername) then
								if plr.OwnedTowers[towername]:GetAttribute("Equipped") == false then
									plr.OwnedTowers:FindFirstChild(towername):Destroy()
								end
							end
						end
					end
					for itemname, quantity in requirements do
						if plr.Items:FindFirstChild(itemname) then
							plr.Items:FindFirstChild(itemname).Value -= quantity
						elseif plr.OwnedTowers:FindFirstChild(itemname) then
							for i=1, quantity do
								plr.OwnedTowers:FindFirstChild(itemname):Destroy()
							end
						end
					end
					tower.Name = UpgradesModule[tower.Name]["Evolve"]["EvolvedUnit"]
					return tower
				end
			else
				warn("Tower evolution requirements not found")
			end
		else
			warn("Tower not in module")
		end
	else
		warn("Could not find tower in inventory")
	end
end

Functions.Sacrifice.OnServerInvoke = function(plr, selectedUnits: {any}, gamepassId)
	local JunkTraderPoints = plr:FindFirstChild("JunkTraderPoints")

	local scheduleDestroyingUnits = {}

	local function calculateTotalPoints(units)
		local total = 0

		for _, tower in selectedUnits do
			local upgrade = UpgradesModule[tower.Name]
			if not upgrade then continue end

			local rarity = upgrade.Rarity
			local rarityData = SacrificePoints.SacrificeData[rarity]
			if not rarityData then
				Events.Client.Message:FireClient(plr, "No Junk offering data for rarity: " .. rarity, Color3.fromRGB(195, 0, 3), nil, "Error")
				continue
			end

			local isShiny = tower:GetAttribute("Shiny")
			local points = isShiny and rarityData.Shiny or rarityData.Points
			total += points

			table.insert(scheduleDestroyingUnits, tower)
		end

		total += JunkTraderPoints.Value

		return total
	end

	local function canReceiveShiny()
		if plr.OwnGamePasses["Shiny Hunter"].Value then
			return math.random(1, 100) <= 50
		elseif plr.Buffs:FindFirstChild('Junk Offering') then
			return math.random(1,100) <= 40
		elseif plr.PlayerLevel.Value >= 10 then
			return math.random(1, 100) <= 20
		end
		return false
	end

	local function pickRandomUnitFromRarity(rarity)
		local rarityFolder = ReplicatedStorage.Upgrades:FindFirstChild(rarity)
		if not rarityFolder then return nil end


		local options = rarityFolder:GetChildren()
		local EvoUnits = {}
		local noBannerUnits = {}

		local upgrades = require(ReplicatedStorage.Upgrades)
		for _, unit in pairs(upgrades) do
			if unit.Evolve and unit.Evolve.EvolvedUnit then
				EvoUnits[unit.Evolve.EvolvedUnit] = true
			end
		end

		for _, unit in pairs(upgrades) do
			if unit.NotInBanner then
				noBannerUnits[unit.Name] = true
			end
		end

		for i = #options, 1, -1 do
			local v = options[i]
			if EvoUnits[v.Name] then
				table.remove(options, i)
			end
		end

		for i = #options, 1, -1 do
			local v = options[i]
			if noBannerUnits[v.Name] then
				table.remove(options, i)
			end
		end


		local unit = options[math.random(1, #options)]

		local blacklist = {
			"Sith Trooper", "Asaka Tano", "Cad Bunny", "Egg Bane", "Anikin Armor", "Grand Inquisitor", "Grand Interrupter (The Traitor)", "Ninth Sister", "Ninth Sister (Brute)", "Fifth Brother (Dangerous Rebel)", 'Tenth Brother', 'Quinion (Survivor)', 'Tenth Brother (The Wise)', 'Dart Wader Maskless','Dart Wader Maskless (Reformed)' 
		}

		if table.find(blacklist, unit.Name) then
			warn("Unit from blacklist: " .. unit.Name)
			return pickRandomUnitFromRarity(rarity)
		end
		return unit
	end

	local function sacrificeUnits(player, selectedUnits)
		local totalPoints = calculateTotalPoints(selectedUnits)
		if totalPoints < 100 then
			Events.Client.Message:FireClient(player, "Not Enough Points!", Color3.fromRGB(195, 0, 3), nil, "Error")
			return
		end

		if not JunkTraderPoints then
			Events.Client.Message:FireClient(player, "Unexpected Error! Please reload.", Color3.fromRGB(195, 0, 3), nil, "Error")
			return
		end

		JunkTraderPoints.Value = 0


		for _, tower in scheduleDestroyingUnits do
			if tower then
				print("tower destroyed: " .. tower.Name)
				tower:Destroy()
			end
		end

		local selectedRarity = SacrificePoints.GetRandomRarity(player)
		local trait = SacrificePoints.GetRandomTrait(player)
		local unitTemplate = pickRandomUnitFromRarity(selectedRarity)
		if not unitTemplate then
			warn("No units found for rarity:", selectedRarity)
			return
		end

		local shiny = canReceiveShiny(player)
		local newUnit = _G.createTower(player.OwnedTowers, unitTemplate.Name, trait, { Shiny = shiny })

		return newUnit, JunkTraderPoints.Value
	end

	if gamepassId then
		MarketPlaceService:PromptProductPurchase(plr, gamepassId)

		local startTime = os.clock()
		local purchased = false
		Events.Client.Junktrader.Event:Connect(function(purchasedPass)
			purchased = purchasedPass
		end)

		repeat
			task.wait(.1)
		until purchased

		if not purchased then return end	
	end

	return sacrificeUnits(plr, selectedUnits)
end

local ChanceModule = require(ReplicatedStorage.Chances)
local PityTraits = {
	["Mythical"] = {
		"Cosmic Crusader",
		"Mandalorian",
		"Merchant",
		"Lord",
		"Padawan",
		"Star Killer",
		"Apprentice",
		"Tyrant's Wrath"
	},
	["Legendary"] = {"Lightspeed", "Experience"}
}
local NewMythicRates = {
	["Cosmic Crusader"] = 5,
	["Mandalorian"] = 10,
	["Merchant"] = 20,
	["Lord"] = 25,
	["Padawan"] = 30,
	["Star Killer"] = 10
}
local NewLegendaryRates = {
	["Lightspeed"] = 40,
	["Experience"] = 60
}
local Generated = false
local PityTrait = nil


local function getTraitCategory(value)
	for category, traits in PityTraits do
		for _, trait in traits do
			if trait == value then
				warn(trait == value)
				return category
			end
		end
	end
	return nil
end


local function GetRandomMythic()
	local totalWeight = 0
	local weightedTraits = {}


	for trait, weight in pairs(NewMythicRates) do
		warn(NewMythicRates)
		totalWeight += weight
		table.insert(weightedTraits, {trait = trait, weight = weight})
	end


	local rand = math.random() * totalWeight
	local runningWeight = 0

	for _, item in ipairs(weightedTraits) do
		runningWeight += item.weight
		if rand <= runningWeight then
			return item.trait
		end
	end

	return weightedTraits[#weightedTraits].trait 
end

local function GetRandomLegendary()
	local totalWeight = 0
	local weightedTraits = {}

	for trait, weight in pairs(NewLegendaryRates) do
		totalWeight += weight
		table.insert(weightedTraits, {trait = trait, weight = weight})
	end


	local rand = math.random() * totalWeight
	local runningWeight = 0

	for _, item in ipairs(weightedTraits) do
		runningWeight += item.weight
		if rand <= runningWeight then
			return item.trait
		end
	end

	return weightedTraits[#weightedTraits].trait 
end


Functions.BuyTrait.OnServerInvoke = function(player, tower, isluckyRoll)
	warn(isluckyRoll)
	if debounces[player.Name] then
		if debounces[player.Name]["Trait"] == false then
			debounces[player.Name]["Trait"] = true
			task.delay(0.1, function()
				debounces[player.Name]["Trait"] = false
			end)
			
			
			local LuckyTrait = nil
			
			if isluckyRoll then
				if player:FindFirstChild("LuckyWillpower").Value >= 1 then
					player:FindFirstChild("LuckyWillpower").Value -= 1
					LuckyTrait = ChanceModule.chooseRandomTrait(player, isluckyRoll)
					tower:SetAttribute("Trait", LuckyTrait)
					warn("Pick LuckyRoll")
					return LuckyTrait
				end
			end
			
			
			if player.TraitPoint.Value >= 1 then
				local Legendary = player:FindFirstChild("LegendaryPityWP")
				local Mythical = player:FindFirstChild("MythicalPityWP")


				if Mythical.Value == 500 then
					Mythical.Value = 0
					PityTrait = GetRandomMythic()
					Generated = true
				end
				
				
				
				

				if Generated then
					Generated = false
					if PityTrait then
						tower:SetAttribute("Trait", PityTrait)
						player.TraitPoint.Value -= 1
						ReplicatedStorage.Events.UpdateInventory:FireClient(player)
						--TraitsModule.UpdateVisualAura(tower, newTrait)
					end
					return PityTrait
				else
					local newTrait = ChanceModule.chooseRandomTrait(player)
					local Category = getTraitCategory(newTrait)
					local tablefunction = {
						["Legendary"] = function()
							if Legendary then
								Legendary.Value = 0
								return "Legendary"
							end
						end,
						["Mythical"] = function()
							if Mythical then
								Mythical.Value = 0
								return "Mythical"
							end
						end,
					}
					local Returning = nil
					if Category == "Mythical" then
						Returning = tablefunction[Category]()
					end
					warn(Returning)

					if Returning == nil then
						Mythical.Value += 1
					end




					if newTrait then
						tower:SetAttribute("Trait", newTrait)
						player.TraitPoint.Value -= 1
						ReplicatedStorage.Events.UpdateInventory:FireClient(player)
						--TraitsModule.UpdateVisualAura(tower, newTrait)
						return newTrait
					end
				end
			else
				return "Not enough Trait Points!"
			end
		end
	end
end

Functions.Craft.OnServerInvoke = function(player, itemName)
	warn(player.Name, itemName)
	local itemStats = ItemStatsModule[itemName]
	local playerItems = player.Items
	if not itemStats then return false end
	
	warn("Item Stats XO2")
	
	
	local hasAllRequireItems = true
	for requireItemName, amount in itemStats.CraftingRequirement do
		if requireItemName == "Coins" then 
			if player.Coins.Value < amount then
				warn("Not Enough Coins")
				hasAllRequireItems = false 
				break

			end
		elseif playerItems[requireItemName].Value < amount then 
			hasAllRequireItems = false 
			break 
		end

	end

	if not hasAllRequireItems then return false end
	for requireItemName, amount in itemStats.CraftingRequirement do
		if requireItemName == "Coins" then
			player.Coins.Value -= amount
		else
			playerItems[requireItemName].Value -= amount
		end
	end
	playerItems[itemName].Value += 1

	return true


end

Events.SetAutoSell.OnServerEvent:Connect(function(player, rarity, setTo)
	local AutoSellFolder = player:FindFirstChild("AutoSell")
	local rarityObject = (AutoSellFolder and AutoSellFolder:FindFirstChild(rarity)) or nil
	if rarityObject then
		rarityObject.Value = setTo
	end
end)

--Events.AdminEvent.OnServerEvent:Connect(function(player,command,arg,arg2)
--	if table.find(admins.Admins,player.UserId) then
--		if command == "Coins" then
--			player.Coins.Value += arg
--		elseif command == "Tower" then
--			if UpgradesModule[arg] then
--				local quantity = arg2
--				--if type(arg2) == "number" then
--				--	quantity = arg2
--				--end
--				for i=1, quantity do
--					_G.createTower(player.OwnedTowers,arg)
--				end
--			end
--		elseif command == "PassExp" then
--			--player.BrawlPass[currentPass].Exp.Value += arg
--		end
--	end
--end)

local function CheckIfPlayerExist(Player)
	if Players:FindFirstChild(Player) then
		return true
	else
		return false
	end
end

Functions.EquipCosmetic.OnServerInvoke = function(Player, Tower)
	local towerName, towerUniqueID = Tower.Name, Tower:GetAttribute("UniqueID")
	local TowerName = nil
	if Tower:GetAttribute("Shiny") then
		TowerName = Tower.Name..":shiny"
	else
		TowerName = Tower.Name
	end
	if Player.CosmeticEquipped.Value == TowerName and Player.CosmeticUniqueID.Value == towerUniqueID then
		warn(towerName)
		CosmeticModule.Apply(false ,Player, towerName)
		Player.CosmeticEquipped.Value = ""
		Player.CosmeticUniqueID.Value = ""
		return false
	else
		local Shiny = Tower:GetAttribute("Shiny")
		local equippable = CosmeticModule.Apply(true ,Player, if Shiny then towerName..":shiny" else towerName, Tower:GetAttribute("UniqueID"), Shiny)
		if equippable then 
			if Shiny then
				Player.CosmeticEquipped.Value = towerName..":shiny"
			else
				Player.CosmeticEquipped.Value = towerName 
			end

			Player.CosmeticUniqueID.Value = Tower:GetAttribute("UniqueID")
			return true 
		end
		return false
	end

end

Functions.SaveTeam.OnServerInvoke = function(player, inTeamFolder)
	if inTeamFolder.Parent ~= player.TeamPresets then return false end
	print("InvokeSave")
	local equipTowers = {}
	print(player.OwnedTowers:GetChildren())
	for _, tower in player.OwnedTowers:GetChildren() do
		if not tower:GetAttribute("Equipped") then continue end
		table.insert(equipTowers, tower)
	end
	print(equipTowers)
	inTeamFolder:ClearAllChildren()
	for slotNumber, tower in equipTowers do
		local clone = tower:Clone()
		clone.Parent = inTeamFolder
	end
	print("Clones")
	return true

end

Functions.LoadTeam.OnServerInvoke = function(player, toTeamFolder)
	if toTeamFolder.Parent ~= player.TeamPresets then return false end
	print("InvokeSave")
	local equipTowers = {}
	print(player.OwnedTowers:GetChildren())

	for _, tower in player.OwnedTowers:GetChildren() do
		tower:SetAttribute("EquippedSlot", "")
		tower:SetAttribute("Equipped", false)
	end

	for _, teamTower in toTeamFolder:GetChildren() do

		for _, inventoryTower in player.OwnedTowers:GetChildren() do
			if inventoryTower:GetAttribute("UniqueID") == teamTower:GetAttribute("UniqueID") then
				inventoryTower:SetAttribute("EquippedSlot", teamTower:GetAttribute("EquippedSlot"))
				inventoryTower:SetAttribute("Equipped", true)
			end
		end

	end

	return true

end

DeleteTakedownsAttribute.OnServerEvent:Connect(function(plr,tower,attribute)
	if plr and tower and attribute then
		tower:SetAttribute(attribute,nil)
	end
end)

Events.Admin.OnServerEvent:Connect(function(Player,SelectedPlayer,Command,Value)
	local AdminsList = require(ReplicatedStorage.AdminsList)

	if SelectedPlayer == nil or Command == nil or Value == nil or not table.find(AdminsList,Player.Name) then warn(".......fr") return end

	local PlayerExist = CheckIfPlayerExist(SelectedPlayer)
	local Selected = Players[SelectedPlayer]

	if Command == "Gems" then
		if PlayerExist  then
			Selected.Gems.Value += Value
		end
	elseif Command == "Tokens" then
		if PlayerExist  then
			Selected.TraitPoint.Value += Value
		end
	elseif Command == "Coins" then
		if PlayerExist  then
			Selected.Coins.Value += Value
		end
	elseif Command == "Level" then
		if PlayerExist then
			Selected.PlayerLevel.Value += Value
		end
	elseif Command == "Tower" then
		if PlayerExist then
			Events.Client.Message:FireClient(Selected,"You Recived "..Value.Name.."!",Color3.new(0, 1, 0))
			local TowerData = Value
		end
	end
end)

Events.FuseTower.OnServerEvent:Connect(function(player,receiveFuseTower, fuseList)
	local ownedList = player.OwnedTowers:GetChildren()
	local validReceiveFuseTower =  ownedList[ table.find(ownedList,receiveFuseTower) ]

	if not receiveFuseTower or #fuseList <=0 then return end
	if not validReceiveFuseTower then return end

	local oldLevel, oldExp = receiveFuseTower:GetAttribute("Level"), receiveFuseTower:GetAttribute("Exp")

	local addingExpCount = 0
	for _,tower in fuseList do
		local ownedList = player.OwnedTowers:GetChildren()
		local validFuseTower =  ownedList[ table.find(ownedList,tower) ]

		if not validFuseTower or tower:GetAttribute("Locked") == true then continue end
		local towerRarity = UpgradesModule[tower.Name] and UpgradesModule[tower.Name].Rarity
		local towerLevel = tower:GetAttribute("Level")
		addingExpCount += SellAndFuseModule.ExpFusing[towerRarity] * (1+ towerLevel * (4/50))

		tower:Destroy()
	end

	local receiveTowerTrait = receiveFuseTower:GetAttribute("Trait")
	if receiveTowerTrait ~= "" then
		addingExpCount += addingExpCount * (TraitsModule.Traits[receiveTowerTrait].Exp/100)
	end

	local newLevel, newExp = ExpModule.towerLevelCalculation(player, oldLevel, oldExp + addingExpCount)
	print(`OldLevel:{oldLevel} : OldExp:{oldExp} | NewLevel:{newLevel} : NewExp:{newExp} | AddingExp:{addingExpCount}`)
	receiveFuseTower:SetAttribute("Level",newLevel)
	receiveFuseTower:SetAttribute("Exp", newExp)
end)

MessagingService:SubscribeAsync("GlobalSummon", function(message)
	Events.Client.ChatMessage:FireAllClients(message.Data)
end)
--MessagingService:PublishAsync("GlobalSummon","Hashira has summon Hisoka/")

while task.wait(0.25) do
	for _, plr in game.Players:GetPlayers() do
		if plr:FindFirstChild('Buffs') then
			for i, v in plr['Buffs']:GetChildren() do
				if (v.StartTime.Value + v.Duration.Value) - os.time() <= 0 then
					print(v.Duration.Value)
					v:Destroy()
				end
			end
		end
	end 
end
