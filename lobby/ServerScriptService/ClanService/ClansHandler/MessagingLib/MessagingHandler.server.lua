local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService('MessagingService')
local InstanceLib = require(script.Parent.Parent.InstanceLib)
local ClanTemplate = require(ServerScriptService.ClanService.ClansHandler.ClanLib.ClanTemplate)

MessagingService:SubscribeAsync('DeleteClan', function(data)
	data = data.Data
	-- there's also data.Sent which is the timestamp
	local clan = data.Clan
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		for i,v in Players:GetChildren() do
			if v:FindFirstChild('DataLoaded') then
				if v.ClanData.CurrentClan.Value == clan then
					v.ClanData.CurrentClan.Value = 'None'
				end
			end
		end
		
		foundClan:Destroy()
	end
end)

MessagingService:SubscribeAsync('UpdateRank', function(data)
	data = data.Data
	-- there's also data.Sent which is the timestamp
	local clan = data.Clan
	local UserId = data.UserId
	local newRank = data.Rank
	
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)

	if foundClan then
		foundClan.Members[UserId].Rank.Value = newRank	
	end
end)

MessagingService:SubscribeAsync('KickMember', function(data)
	data = data.Data
	-- there's also data.Sent which is the timestamp
	
	local clan = data.Clan
	local UserId = data.UserId

	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)

	if foundClan then
		local found = foundClan.Members:FindFirstChild(UserId)
		if found then
			found:Destroy()
		end		
		
		local foundPlr = Players:GetPlayerByUserId(UserId)
		
		if foundPlr then
			repeat task.wait() until not foundPlr.Parent or foundPlr:FindFirstChild('DataLoaded')
			
			if foundPlr.Parent then
				foundPlr.ClanData.CurrentClan.Value = 'None'
			end
		end
	end
end)

MessagingService:SubscribeAsync('PlayerJoined', function(data)
	data = data.Data
	-- there's also data.Sent which is the timestamp
	local clan = data.Clan
	local UserId = data.UserId
	local Username = data.Username
	local DisplayName = data.DisplayName
	
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan and not foundClan.Members:FindFirstChild(UserId) then
		local memberData = {
			Rank = 'Initiate',
			Contributions = {
				Kills = 0,
				Vault = 0,
				XP = 0,
			},
			Username = Username,
			DisplayName = DisplayName
		}
		
		local Folder = Instance.new('Folder')
		Folder.Name = UserId
		
		InstanceLib.DeepLoadDataToInstances(memberData, Folder)
		
		Folder.Parent = foundClan.Members
	end
end)


MessagingService:SubscribeAsync('PostMessage', function(data)
	data = data.Data
	-- there's also data.Sent which is the timestamp
	local clan = data.Clan
	local Message = data.Message
	local index = data.Index

	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)

	if foundClan then
		local messageData = {
			Message = Message,
			Index = index
		}

		local Folder = Instance.new('Folder')
		Folder.Name = index


		InstanceLib.DeepLoadDataToInstances(messageData, Folder)

		Folder.Parent = foundClan.ChatBox
	end
end)

MessagingService:SubscribeAsync('ModifyClan', function(data)
	data = data.Data
	-- there's also data.Sent which is the timestamp
	local clan = data.Clan
	local valueType = data.moditype
	local newValue = data.Value

	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)

	if foundClan then
		foundClan[valueType].Value = newValue
	end
end)

MessagingService:SubscribeAsync('StatUpdated', function(data)
	data = data.Data
	--local dat = {
	--	UserId = plr.UserId,
	--	Amount = filtered,
	--	Total = success.Message.Stats.Vault,
	--	Stat = 'Vault',
	--	Clan = currentClan
	--}
	--['x_x6n'] = {
	--	Rank = 'Emperor',
	--	Contributions = {
	--		Kills = 0,
	--		Vault = 0,
	--		XP = 0,
	--	}
	--}
	----]]
	local Clan = data.Clan
	local Amount = data.Amount
	local Total = data.Total
	local Stat = data.Stat
	local UserId = data.UserId
	
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(Clan)
	
	if foundClan then
		foundClan.Members[tostring(UserId)].Contributions[Stat].Value += Amount
		foundClan.Stats[Stat].Value = Total
	end
end)

type questType = {
	QuestID: NumberValue,
	ConfigID: NumberValue,
	QuestName: StringValue,
	Description: StringValue,
	Progress: NumberValue,
	TotalAmount: NumberValue,
	QuestIcon: StringValue,
}


MessagingService:SubscribeAsync('UpdateQuest', function(data)
	data = data.Data
	
	local Clan = data.Clan
	local Amount = data.Amount
	local QuestID = data.QuestID
	
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(Clan)
	
	if foundClan then	
		for i,v:questType in foundClan.Quests:GetChildren() do
			if v.QuestID == QuestID then
				v.Progress.Value += Amount
				
				if v.Progress.Value >= v.TotalAmount.Value then
					v:Destroy()
				end
			end
		end		
	end
end)

MessagingService:SubscribeAsync('SyncQuestTree', function(data: ClanTemplate.ClanData)
	data = data.Data

	local Clan = data.Clan
	local QuestTree = data.QuestTree
	
	local foundClan: ClanTemplate.ClanData = ReplicatedStorage.Clans:FindFirstChild(Clan)
	
	if foundClan and QuestTree then
		InstanceLib.ReconcileInstancesWithData(QuestTree, foundClan.Quests)
	end
end)