local ReplicatedStorage = game:GetService("ReplicatedStorage")
script.ClanQuestsConfig:Clone().Parent = ReplicatedStorage.Configs -- making it package-compatible
local ServerScriptService = game:GetService("ServerScriptService")
local InstanceLib = require(ServerScriptService.ClanService.ClansHandler.InstanceLib)
local QuestConfig = require(script.ClanQuestsConfig)
local ScheduleLib = require(ServerScriptService.ClanService.ClansHandler.ScheduleLib)
local TimeConverter = require(ReplicatedStorage.AceLib.TimeConverter)
local MessagingLib = require(ServerScriptService.ClanService.ClansHandler.MessagingLib)
local RewardsService = require(ServerScriptService.ClanService.ClansHandler.RewardsService)
local ClanTemplate = require(ServerScriptService.ClanService.ClansHandler.ClanLib.ClanTemplate)

local module = {}

type questType = {
	QuestID: NumberValue,
	ConfigID: NumberValue,
	QuestName: StringValue,
	Description: StringValue,
	Progress: NumberValue,
	TotalAmount: NumberValue,
	QuestIcon: StringValue,
}

local questTemplate = {
	QuestID = 1,
	ConfigID = nil,
	QuestName = '',
	Description = '',
	Progress = 0,
	TotalAmount = 0,
	QuestIcon = '',
}

function module.writeToQuestLog(data, questInfo)
	if #data.QuestLogs == 500 then
		table.remove(data.QuestLogs, 1)
	end

	local writingData = {
		Message = questInfo,
		Index = data.QuestIndex,
	}

	table.insert(data.QuestLogs, writingData)
	data.QuestIndex += 1

	return data
end

local QuestRewards = {
	ClanXP = function(data: ClanTemplate.ClanData, amount)
		data.Stats.Vault += amount
		return data
	end,
	Gems = function(data: ClanTemplate.ClanData, amount)
		for i,v in data.Members do	
			if not data.PendingRewards[i] then
				data.PendingRewards[i] = {}
			end
			
			data = RewardsService.grantReward(data, i, 'Gems', "Currency", amount)
		end
		
		return data
	end,
	TraitPoint = function(data: ClanTemplate.ClanData, amount)
		for i,v in data.Members do	
			if not data.PendingRewards[i] then
				data.PendingRewards[i] = {}
			end

			data = RewardsService.grantReward(data, i, 'TraitPoint', "Currency", amount)
		end
		
		return data
	end,
}

function module.progressQuest(clan: string, Type, amount: number)
	local foundClan : Folder = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		for i,v: questType in foundClan.Quests:GetChildren() do	
			local qType = QuestConfig[v.ConfigID.Value].Type
			local QuestID = v.QuestID.Value
			
			if qType == Type then
				v.Progress.Value += amount

				local transformFunction = function(data)
					for i,qData in data.Quests do
						local transformType = QuestConfig[v.ConfigID.Value].Type
						if qData.QuestID == QuestID and transformType == Type then
							qData.Progress += amount
							
							if qData.Progress >= qData.TotalAmount then
								-- we can delete the quest because they completed it!!
								-- make sure to give them rewards first!
								for _, reward in QuestConfig[v.ConfigID.Value].Rewards do
									data = QuestRewards[reward.Type](data, reward.Amount)										
								end
								
								data.Quests[i] = nil
							end
							
							break
						end
					end
					
					return data
				end
				
				local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunction)
				
				if success and success.Success then
					local transformedData: ClanTemplate.ClanData = success.Message
					if v.Progress.Value >= v.TotalAmount.Value then
						v:Destroy()
					end
					
					local Data = {
						Clan = clan,
						Type = Type,
						Amount = amount,
						QuestID = v.QuestID.Value
					}

					MessagingLib.PublishMessageAsync("UpdateQuest", Data)
					
					module.reconcileQuests(clan)
				end
			end
		end
	end
end

function MinutesToHours(minutes: number): number
	return minutes / 60
end

local DescriptionConfig = {
	['Kills'] = function(amount)
		return `As a clan, defeat {amount} enemies collectively`
	end,
	['Kills:Bosses'] = function(amount)
		return `As a clan, defeat {amount} bosses collectively`
	end,
	['Playtime'] = function(amount)
		--local processedAmount = TimeConverter.secondsToTime(amount)
		return `Collectively get {MinutesToHours(amount)} hours worth of playtime as a clan`
	end,
}


local function generateQuest(exclude: {number}): table
	local generatedQuest = {}

	-- filter out excluded indices
	local validIndices = {}
	for i = 1, #QuestConfig do
		if not exclude then
			table.insert(validIndices, i)
		else
			if not table.find(exclude, i) then
				table.insert(validIndices, i)
			end
		end
	end

	if #validIndices == 0 then
		warn("No valid quest configs available.")
		return nil
	end

	local randomIndex = validIndices[math.random(1, #validIndices)]
	local pickedQuest = QuestConfig[randomIndex]

	generatedQuest.QuestID = nil -- will be specified in the transform function
	generatedQuest.ConfigID = randomIndex
	generatedQuest.QuestName = pickedQuest.QuestName
	generatedQuest.Description = DescriptionConfig[pickedQuest.Type](pickedQuest.Amount)
	generatedQuest.TotalAmount = pickedQuest.Amount
	generatedQuest.QuestIcon = pickedQuest.Icon
	generatedQuest.Progress = 0

	return generatedQuest
end


function module.reconcileQuests(clan) -- this is strictly a backend function
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		if #foundClan.Quests:GetChildren() < 3 then
			-- we got some missing quests that have been completed
			local sufficientAmount = false

			local transformedData = nil
			task.spawn(function()
				for i = 1, 3 do
					local transformFunction = function(source)
						local exclusion = {}
						
						for i,v: questType in source.Quests do
							table.insert(exclusion, v.ConfigID)
						end
						
						local questCount = 0
						for _ in pairs(source.Quests) do
							questCount += 1
						end
						
						if questCount < 3 then
							local generatedQuest = generateQuest(exclusion)							
							generatedQuest.QuestID = source.QuestIndex

							-- Replace numeric index with string ID key
							local questKey = "Quest_" .. tostring(source.QuestIndex)
							source.Quests[questKey] = generatedQuest

							source.QuestIndex += 1
						end

						return source
					end

					local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunction)

					if success and success.Success and success.Message then
						transformedData = success.Message

						InstanceLib.ReconcileInstancesWithData(transformedData, foundClan)

						if #foundClan.Quests:GetChildren() >= 3 then
							sufficientAmount = true
						end
					end

					if sufficientAmount then break end
				end
				
				if transformedData then -- we successfully got some data written(needed some new quests!)
					local Data = {
						Clan = clan,
						QuestTree = transformedData.Quests,
					}

					MessagingLib.PublishMessageAsync("SyncQuestTree", Data)
				end
			end)
		end
	end
end





return module