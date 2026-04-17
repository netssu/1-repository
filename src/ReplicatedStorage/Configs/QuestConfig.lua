local quests = {}

quests.QuestConfigs = require(script.Quests)
local QuestConfigs = quests.QuestConfigs  

local function createQuest(id, name, desc, configName, goal, reward, wipe, questType, additional)
	local questFolder = Instance.new("Folder")
	questFolder.Name = id

	local questName = Instance.new("StringValue")
	questName.Name = "QuestName"
	questName.Value = name
	questName.Parent = questFolder

	local questDesc = Instance.new("StringValue")
	questDesc.Name = "Description"
	questDesc.Value = desc
	questDesc.Parent = questFolder

	local qType = Instance.new("StringValue")
	qType.Name = "Config"
	qType.Value = configName
	qType.Parent = questFolder
	
	local wipeVal = Instance.new("BoolValue", questFolder)
	wipeVal.Name = "Wipe"
	wipeVal.Value = wipe

	if questType ~= "Questline" then
		
		local goalVal = Instance.new("NumberValue", questFolder)
		goalVal.Name = "Goal"
		goalVal.Value = goal
		
		local rewardFolder = Instance.new("Folder", questFolder)
		rewardFolder.Name = "Reward"
		for rewardType, rewardData in pairs(reward) do
			local rewardEntry = Instance.new("Folder", rewardFolder)
			rewardEntry.Name = rewardType
			for key, value in rewardData do
				local valInstance
				if typeof(value) == "number" then
					valInstance = Instance.new("NumberValue")
				elseif typeof(value) == "string" then
					valInstance = Instance.new("StringValue")
				elseif typeof(value) == "boolean" then
					valInstance = Instance.new("BoolValue")
				else
					warn("Unsupported reward value type:", rewardType, key)
					continue
				end
				valInstance.Name = key
				valInstance.Value = value
				valInstance.Parent = rewardEntry
			end
		end
		
		Instance.new("NumberValue", questFolder).Name = "Progress"
		Instance.new("BoolValue", questFolder).Name = "Completed"
	end

	if questType == "Questline" then
		local currentPart = Instance.new("IntValue", questFolder)
		currentPart.Name = "Part"
		currentPart.Value = additional.Part or 1

		local partsFolder = Instance.new("Folder", questFolder)
		partsFolder.Name = "Parts"

		for i, part in pairs(additional.Parts or {}) do
			local partFolder = Instance.new("Folder", partsFolder)
			partFolder.Name = "Part" .. i

			local pGoal = Instance.new("NumberValue", partFolder)
			pGoal.Name = "Goal"
			pGoal.Value = part.Goal
			
			local pName = Instance.new("StringValue", partFolder)
			pName.Name = "PartName"
			pName.Value = part.Name

			local pReward = Instance.new("Folder", partFolder)
			pReward.Name = "Reward"

			for rewardType, value in pairs(part.RewardCalc()) do
				local rewardEntry = Instance.new("Folder", pReward)
				rewardEntry.Name = rewardType

				local valInstance
				if typeof(value) == "number" then
					valInstance = Instance.new("NumberValue")
				elseif typeof(value) == "string" then
					valInstance = Instance.new("StringValue")
				elseif typeof(value) == "boolean" then
					valInstance = Instance.new("BoolValue")
				else
					warn("Unsupported reward value type:", rewardType)
					continue
				end
				valInstance.Name = "Amount"
				valInstance.Value = value
				valInstance.Parent = rewardEntry
			end


			Instance.new("NumberValue", partFolder).Name = "Progress"
			Instance.new("BoolValue", partFolder).Name = "Completed"
			Instance.new("BoolValue", partFolder).Name = "Claimed"
		end

	elseif questType == "Infinite" then
		local incremental = Instance.new("NumberValue", questFolder)
		incremental.Value = additional.GoalIncrement
		incremental.Name = "GoalIncrement"
	else
		Instance.new("BoolValue", questFolder).Name = "Claimed"
	end

	return questFolder
end


local function reward(rewardFolder: Folder, player: Player)
	for _, reward in pairs(rewardFolder:GetChildren()) do
		if reward:IsA("Folder") then
			local rewardType = reward.Name				

			if rewardType == "Unit" then
				local unitName = reward:FindFirstChild("UnitName")
				local shiny = reward:FindFirstChild("Shiny")
				local amount = reward:FindFirstChild("Amount")

				if unitName and shiny and amount then
					for i = 1, amount.Value do
						_G.createTower(player.OwnedTowers, unitName.Value, nil, shiny.Value)
					end
				end

			elseif rewardType == "Item" then
				local itemName = reward:FindFirstChild("ItemName")
				local amount = reward:FindFirstChild("Amount")

				if itemName and amount then
					local item = player.Items:FindFirstChild(itemName.Value)
					if item then
						item.Value += amount.Value
					else
						warn("Item:",itemName.Value,"not found.")
						return false
					end
				end
			else
				local amount = reward:FindFirstChild("Amount")
				if amount then
					local data = nil

					if rewardType == "Exp" then
						data = player:FindFirstChild("BattlepassData").Exp				
					else
						data = player:FindFirstChild(rewardType)
					end
					
					local multi = 1
					if rewardType == 'Gems' and player.OwnGamePasses['x2 Gems'].Value then
						multi = 2
					end

					if data then
						data.Value += (amount.Value * multi)
					else
						warn("Unknown reward type:", rewardType)
						return false
					end
				else
					warn("Unknown reward type:", rewardType)
					return false
				end
			end
		end
	end
	
	return true
end

local function generateUniqueId(baseId, questPath)
	local count = 1
	local id = baseId .. "_" .. count
	while questPath:FindFirstChild(id) do
		count += 1
		id = baseId .. "_" .. count
	end
	return id
end

local function genQuestData(configId, questPath, wipe, group, questType, additional)
	local config = QuestConfigs[configId]
	if not config then return end
	print(config, questType)

	local goal = nil
	local rewardData = nil
	
	if questType == "Questline" then
		local part = config.Part or 1
		local partData = config.Parts and config.Parts[part]

		if partData then
			goal = partData.Goal
			rewardData = partData.RewardCalc()
		else
			warn("Missing part data for story quest:", configId, "part:", part)
			return
		end
		
		print(config.Parts)
		additional = {Part = 1, Parts = config.Parts}
	elseif questType == "Infinite" then
		goal = config.Goal
		rewardData = config.RewardCalc(goal)
		
		additional = {GoalIncrement = config.GoalIncrement}
	else
		goal = math.random(config.GoalRange[group].min, config.GoalRange[group].max)
		rewardData = config.RewardCalc(goal, config.RewardMultiplier[group], group)
	end

	
	if not goal or not rewardData then print("no goal or reward data found") return end
	
	
	local rewardFolderData = {}
	for key, val in rewardData do
		rewardFolderData[key] = { Amount = val }
	end

	local uniqueId = generateUniqueId(configId, questPath)
	return createQuest(uniqueId, config.Name, config.Desc, configId, goal, rewardFolderData, wipe, questType, additional)
end


function quests.PickQuest(questPath, unique, wipe, group, questType)
	local keys = {}

	for key, config in pairs(QuestConfigs) do
		local inGroup = not group or table.find(config.Group, group)

		if inGroup then
			if unique then
				local hasQuest = false
				for _, q in ipairs(questPath:GetChildren()) do
					if string.match(q.Name, "^" .. key) then
						hasQuest = true
						break
					end
				end
				if not hasQuest then
					table.insert(keys, key)
				end
			else
				table.insert(keys, key)
			end
		end
	end

	if unique and #keys == 0 then
		return nil
	end

	if not unique and #keys == 0 then
		for key, config in pairs(QuestConfigs) do
			if not group or table.find(config.Group, group) then
				table.insert(keys, key)
			end
		end
	end

	if #keys == 0 then return end

	local randomKey = keys[math.random(1, #keys)]
	return genQuestData(randomKey, questPath, wipe, group, questType)
end


function quests.CreateQuest(player: Player, questPath, configId, unique, wipe, group, questType)
	local quest = configId and genQuestData(configId, questPath, wipe, group, questType) 
		or quests.PickQuest(questPath, unique, wipe, group, questType)

	if quest then
		print("created quest")
		quest.Parent = questPath
	else
		warn("Failed to generate quest for", player.Name)
	end
end


function quests.UpdateProgress(questPath: Folder, configId: string, amount: number, partNumber: number?)
	local matchedQuest = nil
	for _, child in ipairs(questPath:GetChildren()) do
		if string.match(child.Name, "^" .. configId) then
			matchedQuest = child
			break
		end
	end

	if not matchedQuest then
		--warn("No quest folder starting with:", configId, "found in", questPath.Name)
		return
	end
	questPath = matchedQuest

	local configValue = questPath:FindFirstChild("Config")
	if not configValue then
		--warn("Missing Config value in quest folder:", questPath.Name)
		return
	end

	if configValue.Value ~= configId then
		--warn("Config mismatch: expected", configId, "but found", configValue.Value)
		return
	end

	local config = QuestConfigs[configId]
	if not config then
		--warn("Invalid quest config ID:", configId)
		return
	end

	local questType = (config.Group and #config.Group > 0) and config.Group[1] or "Normal"

	local quest = questPath
	if partNumber then
		local partsFolder = questPath:FindFirstChild("Parts")
		if not partsFolder then
			--warn("Missing 'Parts' folder for story quest:", questPath.Name)
			return
		end

		local currentPart = partsFolder:FindFirstChild("Part" .. partNumber)
		if not currentPart then
			--warn("Invalid part number:", partNumber, "in", questPath.Name)
			return
		end

		if partNumber > 1 then
			local prevPart = partsFolder:FindFirstChild("Part" .. (partNumber - 1))
			if not prevPart or not prevPart:FindFirstChild("Completed") or not prevPart.Completed.Value or not prevPart.Claimed.Value then
				--warn("Must complete previous part before progressing to Part" .. partNumber)
				return
			end
		end

		quest = currentPart
	end

	local progress = quest:FindFirstChild("Progress")
	local goal = quest:FindFirstChild("Goal")
	local completed = quest:FindFirstChild("Completed")

	if not progress or not goal or not completed then
		--warn("Missing required quest values in:", quest.Name)
		return
	end

	if completed.Value and questType ~= "Infinite" then return end

	if questType == "Story" and partNumber and config.Parts then
		local partConfig = config.Parts[partNumber]
		if not partConfig then
			--warn("Missing part config for part number", partNumber, "in", configId)
			return
		end

		progress.Value = math.min(progress.Value + amount, partConfig.Goal)
		if progress.Value >= partConfig.Goal then
			progress.Value = partConfig.Goal
			completed.Value = true
		end

	elseif questType == "Infinite" and config.GoalIncrement then
		progress.Value += amount
		if progress.Value >= goal.Value then
			completed.Value = true
		end

	else
		progress.Value = math.min(progress.Value + amount, goal.Value)
		if progress.Value >= goal.Value then
			progress.Value = goal.Value
			completed.Value = true
		end
	end
end

function quests.UpdateProgressAll(player: Player, configId: string, amount: number, partNumber: number?)
	local config = QuestConfigs[configId]
	if not config then
		--warn("Invalid quest config ID:", configId)
		return
	end

	if not config.Group or #config.Group == 0 then
		--warn("No groups defined for quest:", configId)
		return
	end

	local groupToPath = {
		Daily = player.Quests:FindFirstChild("DailyQuests") and player.Quests.DailyQuests.Quests,
		Weekly = player.Quests:FindFirstChild("WeeklyQuests") and player.Quests.WeeklyQuests.Quests,
		Story = player.Quests:FindFirstChild("StoryQuests") and player.Quests.StoryQuests.Quests,
		Infinite = player.Quests:FindFirstChild("InfiniteQuests") and player.Quests.InfiniteQuests.Quests,
		Event = player.Quests:FindFirstChild("EventQuests") and player.Quests.EventQuests.Quests,
		Battlepass = player:FindFirstChild("BattlepassData") and player.BattlepassData.Quests,
	}

	for _, group in ipairs(config.Group) do
		local questPath = groupToPath[group]
		if questPath then
			quests.UpdateProgress(questPath, configId, amount, partNumber)
		else
			--warn("Quest path not found for group:", group)
		end
	end
end


function quests.ClaimReward(player: Player, quest: Folder)
	local configValue = quest:FindFirstChild("Config")
	if not configValue then
		--warn("Missing Config value in quest:", quest.Name)
		return
	end

	local configId = configValue.Value
	local config = QuestConfigs[configId]
	if not config then
		--warn("Invalid quest config ID:", configId)
		return
	end

	local questType = (config.Group and #config.Group > 0) and config.Group[1] or "Normal"

	if questType == "Story" and config.Parts then
		local partsFolder = quest:FindFirstChild("Parts")
		if not partsFolder then
			--warn("Story quest missing Parts folder:", quest.Name)
			return
		end

		local partToClaim = nil
		for i = 1, #config.Parts do
			local part = partsFolder:FindFirstChild("Part" .. i)
			if part then
				local completed = part:FindFirstChild("Completed")
				local claimed = part:FindFirstChild("Claimed")
				local rewardFol = part:FindFirstChild("Reward")

				if completed and claimed and rewardFol then
					if completed.Value and not claimed.Value then
						partToClaim = part
						break
					end
				end
			end
		end

		if not partToClaim then
			--warn("No eligible completed & unclaimed part found in story quest:", quest.Name)
			return
		end

		local result = partToClaim and reward(partToClaim.Reward, player)
		if result then
			partToClaim.Claimed.Value = true
			return true
		else
			--warn("Failed to apply story part reward")
			return
		end

	elseif questType == "Infinite" then
		local rewardFol = quest:FindFirstChild("Reward")
		if not rewardFol then
			--warn("Infinite quest missing reward folder:", quest.Name)
			return
		end

		local completed = quest:FindFirstChild("Completed")
		if not completed then
			--warn("Missing quest values in:", quest.Name)
			return
		end

		if not completed.Value then
			warn("Infinite quest is incomplete")
			return
		end

		local result = reward(rewardFol, player)
		if result then
			completed.Value = false
			quest.Goal.Value += quest.GoalIncrement.Value
			if quest.Progress.Value >= quest.Goal.Value then
				completed.Value = true
			end
			return true
		else
			warn("Failed to claim infinite quest reward")
			return
		end

	else 
		local rewardFol = quest:FindFirstChild("Reward")
		local claimed = quest:FindFirstChild("Claimed")
		local completed = quest:FindFirstChild("Completed")

		if not rewardFol or not claimed or not completed then
			warn("Missing values in normal quest:", quest.Name)
			return
		end

		if not completed.Value and (quest.Progress.Value < quest.Goal.Value) then
			warn("Normal quest is incomplete")
			return
		end

		if claimed.Value then
			warn("Normal quest already claimed")
			return
		end

		local result = reward(rewardFol, player)
		if result then
			claimed.Value = true
			if quest:FindFirstChild("Wipe") and quest.Wipe.Value then
				quest:Destroy()
			end
			return true
		else
			warn("Failed to claim normal quest reward")
			return
		end
	end
end


function quests.UpdateQuests(player, questDirectory, questType)
	repeat task.wait() until player:FindFirstChild("DataLoaded")

	local function removeQuest(questInstance)
		print("Removing quest:", questInstance.Name)
		game.ReplicatedStorage.Remotes.Quests.RefreshClientQuests:FireClient(player, questType)
		questInstance:Destroy()
	end

	for _, questInstance in ipairs(questDirectory:GetChildren()) do
		local fullName = questInstance.Name
		local configId = fullName:match("^(.-)_")
		if configId then
			local questConfig = quests.QuestConfigs[configId]
			if questConfig then
				local groups = questConfig.Group
				local found = false

				if typeof(groups) == "table" then
					for _, group in ipairs(groups) do
						if group == questType then
							found = true
							break
						end
					end
				elseif groups == questType then
					found = true
				end

				if not found then
					removeQuest(questInstance)
				end
			else
				removeQuest(questInstance)
			end
		else
			removeQuest(questInstance)

		end
	end
end


return quests
