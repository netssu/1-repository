local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ClansDatstore = DataStoreService:GetDataStore('Clans')
local ScheduleLib = require(script.Parent.ScheduleLib)
local InstanceLib = require(script.Parent.InstanceLib)
local MessageLib = require(script.Parent.MessagingLib)
local ClanQuestsLib = require(ServerScriptService.ClanService.ClanQuestsLib)
local RewardsService = require(script.Parent.RewardsService)


local module = {}

module.ClanTemplate = require(script.ClanTemplate)


function module.createClan(ID, Description, Emblem, Leader: Player) -- make sure this is santisied	
	local newClanData = module.ClanTemplate
	
	newClanData.Name = ID
	newClanData.Description = Description
	newClanData.Emblem = Emblem
	
	local leaderData = {
		Rank = 'Emperor',
		Contributions = {
			Kills = 0,
			Vault = 0,
			XP = 0,
		},
		Username = Leader.Name,
		DisplayName = Leader.DisplayName
	}
	
	newClanData.Members[Leader.UserId] = leaderData
	
	local transformFunction = function()
		return newClanData
	end
	
	local success = ScheduleLib.ScheduleWriteAsync(ID, transformFunction)
	
	if success.Success then
		local ClanFolder = Instance.new('Folder')
		ClanFolder.Name = ID
		InstanceLib.DeepLoadDataToInstances(newClanData, ClanFolder)
		ClanFolder.Parent = ReplicatedStorage.Clans
		Instance.new('Folder', ClanFolder).Name = 'Loaded'
		Leader.ClanData.CurrentClan.Value = ID
		
		ClanQuestsLib.reconcileQuests(ID)
	else
		return 'An internal server error occurred'
	end
	
	return success.Message
end

function module.deleteClan(clan)
	local transformFunc = function(source)
		source.Deleted = true
		return source
	end
	local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)
	
	if success.Success then
		local message = {
			Clan = clan,
		}
		MessageLib.PublishMessageAsync('DeleteClan', message)
		return 'Success'
	else
		return 'An Internal Error Occured'
	end
end

function module.writeToAuditLogs(data, LogMessage)
	if #data.AuditLogs == 500 then
		table.remove(data.AuditLogs, 1)
	end
	
	local writingData = {
		Message = LogMessage,
		Index = data.AuditIndex,
	}
	
	table.insert(data.AuditLogs, writingData)
	data.AuditIndex += 1
	
	return data
end

function module.KickPlayer(UserId, clan, whoDidIt)
	local transformFunc = function(source)
		source.Members[tostring(UserId)] = nil
		if whoDidIt then
			module.writeToAuditLogs(source, `{whoDidIt} kicked {UserId}`)
		else
			module.writeToAuditLogs(source, `{UserId} left the clan`)
		end
		return source 
	end
	
	local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)
	
	local clanFolder = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if clanFolder then
		task.spawn(function()
			clanFolder.Members[tostring(UserId)]:Destroy()
		end)
	end
	
	if success.Success then
		local message = {
			Clan = clan,
			UserId = UserId
		}
		MessageLib.PublishMessageAsync('KickMember', message)
		
		return 'Success'
	else
		return 'An Internal Error Occured'
	end
end

function module.joinPlayer(plr, clan) -- make sure to check if they were invited(external)
	local currentClan = plr.ClanData.CurrentClan
	
	if currentClan.Value == 'None' then
		local memberData = {
			Rank = 'Initiate',
			Contributions = {
				Kills = 0,
				Vault = 0,
				XP = 0,
			},
			Username = plr.Name,
			DisplayName = plr.DisplayName
		}
		
		local transformFunc = function(source)
			source.Members[plr.UserId] = memberData
			return source
		end
		
		local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)
		
		if success.Success then
			currentClan.Value = clan
			local message = {
				UserId = plr.UserId,
				Clan = clan,
				Username = plr.Name,
				DisplayName = plr.DisplayName
			}

			MessageLib.PublishMessageAsync("PlayerJoined", message)
			return 'Success'
		else
			return "An internal error occurred, please try again"
		end
	else
		return "You are already inside a clan"
	end
end

function module.modifyRank(targetID, clan, targetRank, whoDidIt: string) -- make sure to check if they can promote/demote whatev (external)
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		
		local transformFunc = function(source)
			source.Members[targetID].Rank = targetRank
			module.writeToAuditLogs(source, `{whoDidIt} changed {targetID}'s rank to {targetRank}`)
			
			return source 
		end
		
		local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)
		
		if success.Success then
			local message = {
				Clan = clan,
				UserId = targetID,
				Rank = targetRank
			}
			--[[
			local clan = data.Clan
			local UserId = data.UserId
			local newRank = data.Rank
		
			--]]
			MessageLib.PublishMessageAsync('UpdateRank', message)
			return 'Success'
		else
			return "An internal error occured, Please try again later."
		end
	end
end

function module.modifyClan(clan, moditype, value)
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		local transformFunc = function(data)
			data[moditype] = value
			return data
		end
		
		local success, transformedData = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)
		
		if success.Success then
			local message = {
				Clan = clan,
				moditype = moditype,
				Value = value
			}
			
			MessageLib.PublishMessageAsync('ModifyClan', message)
			return 'Success'
		else
			return 'An internal server error occurred'
		end
	end
end


local function makeTransformFunction(statType, amount, userId)
	return function(source)
		print(`[TRANSFORM SERVICE] Applying {statType} += {amount} to {userId}`)
		source.Stats[statType] += amount
		source.Members[tostring(userId)].Contributions[statType] += amount
		return source
	end
end




function module.giveStat(clan, UserId, StatType, Amount)
	local foundPlr = Players:GetPlayerByUserId(UserId)
	
	if foundPlr and foundPlr:FindFirstChild('ClansLoaded') then
		--print('type of stat:')
		--print(StatType)
		--print(UserId)
		--print(Amount)
		
		--local transformFunction = function(source)
		--	source.Stats[StatType] += Amount
		--	source.Members[tostring(UserId)].Contributions[StatType] += Amount
		--	return source
		--end
		local transformFunction = makeTransformFunction(StatType, Amount, UserId)
		local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunction)
		
		if success and success.Success then
			local transformedData = success.Message
			--local Clan = data.Clan
			--local Amount = data.Amount
			--local Total = data.Total
			--local Stat = data.Stat
			--local UserId = data.UserId
			local message = {
				Clan = clan,
				Amount = Amount,
				Stat = StatType,
				UserId = UserId,
				Total = transformedData.Stats[StatType]
			}
			
			MessageLib.PublishMessageAsync('StatUpdated', message)
		end
		
		return success
	end
end

--[[
You can buy:
Boosts
Towers
Clan Tags
Auras
--]]

local ClanUpgradeCalculation = require(ReplicatedStorage.ClansLib.ClanUpgradeCalculation)

module.validTypes = {
	Tags = function(clan, item, price) -- "ClanColors"
		local transformFunc = function(data)
			if data.Stats.Vault >= price then
				data.Stats.Vault -= price
				table.insert(data['ClanColors'], item)
				local message = {
					Clan = clan,
					Type = 'Tag',
					Value = item
				}
				MessageLib.PublishMessageAsync("ClanUpgrade", message)
			end

			return data
		end
		return transformFunc
	end,
	['+1 Clan Slot Upgrade'] = function(clan: string, item: string, price) -- price is calculated dynamically + ignore item

		local transformFunc = function(data)
			if data.Stats.Vault >= price then
				data.Stats.Vault = data.Stats.Vault - price
				data.Upgrades.UpgradeSlotLevel += 1
			end
			
			return data
		end
		
		return transformFunc
	end,
	Towers = function(clan, tower, price)
		local transformFunc = function(data)
			if data.Stats.Vault >= price then
				data.Stats.Vault = data.Stats.Vault - price
				for i,v in data.Members do	
					if not data.PendingRewards[i] then
						data.PendingRewards[i] = {}
					end
					
					local filteredName = tower:gsub("%[SHINY%] ", "")
					local isShiny = filteredName ~= tower
					
					local awardData = {
						Name = filteredName,
						Type = 'Tower',
						Shiny = isShiny
					}
					
					table.insert(data.PendingRewards[i], awardData)
				end
			end
			
			return data
		end
		
		return transformFunc
	end,

	Auras = function(clan, aura, price)
		local transformFunc = function(data)
			
			return data
		end
		
		return transformFunc
	end,
	
	Currencies = function(clan, currency, price, amount, itemData)
		
		local blacklist = {}
		
		for i,v in Players:GetChildren() do
			if v:FindFirstChild('ClansLoaded') then
				if v.ClanData.CurrentClan.Value == clan then
					local rewardData = {
						Name = currency,
						Type = 'Currencies',
						Amount = amount
					}

					RewardsService.processDirectReward(v, rewardData)

					table.insert(blacklist, v.UserId)
				end
			end
		end
		
		local transformFunc = function(data)
			if data.Stats.Vault >= price then
				data.Stats.Vault = data.Stats.Vault - price
				for i,v in data.Members do	
					if table.find(blacklist, tonumber(i)) then 
						continue
					end
					
					if not data.PendingRewards[i] then
						data.PendingRewards[i] = {}
					end

					local awardData = {
						Name = currency,
						Type = 'Currency',
						Amount = amount
					}

					table.insert(data.PendingRewards[i], awardData)
				end
			end
			
			return data
		end
		
		return transformFunc
	end,
	
	Items = function(clan, currency, price, amount, itemData)

		local blacklist = {}

		for i,v in Players:GetChildren() do
			if v:FindFirstChild('ClansLoaded') then
				if v.ClanData.CurrentClan.Value == clan then
					local rewardData = {
						Name = currency,
						Type = 'Items',
						Amount = amount
					}

					RewardsService.processDirectReward(v, rewardData)

					table.insert(blacklist, v.UserId)
				end
			end
		end

		local transformFunc = function(data)
			if data.Stats.Vault >= price then
				data.Stats.Vault = data.Stats.Vault - price
				for i,v in data.Members do	
					if table.find(blacklist, tonumber(i)) then 
						print(`Already granted reward to {i}, continue`)
						continue
					end

					if not data.PendingRewards[i] then
						data.PendingRewards[i] = {}
					end

					local awardData = {
						Name = currency,
						Type = 'Currency',
						Amount = amount
					}

					table.insert(data.PendingRewards[i], awardData)
				end
			end

			return data
		end

		return transformFunc
	end,
}

function module.handleClanPurchase(clan, item, itemtype, byUserId, price, amount)
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	local executionFunc = module.validTypes[item] or module.validTypes[itemtype]
	

	if foundClan and item and executionFunc then -- check if item is a valid thing lol
		--[[
		You can buy:
		Boosts
		Towers
		Clan Tags
		Auras
		--]]
	
		local transformFunc = executionFunc(clan, item, price, amount)

		-- check if we have enough
		if foundClan.Stats.Vault.Value < price then
			return "Your clan vault does not have enough to afford this"
		end

		local success = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)
		
		if success.Success then
			-- reconcile everything, fr
			InstanceLib.ReconcileInstancesWithData(success.Message, foundClan)
			
			local message = {
				Clan = clan,
				Type = 'SlotUpgrade',
				Value = success.Message.Upgrades.UpgradeSlotLevel
			}
			MessageLib.PublishMessageAsync("ClanUpgrade", message)
		end
		return success
	else
		warn('Nope')
		return "An internal server error occured"
	end
end

local EquipFuncs = {
	['Tags'] = function(clan, item, byID)
		local transformFunc = function(source)
			if table.find(source.ClanColors, item) then
				source.ActiveColor = item
				
				source = module.writeToAuditLogs(source, `{byID} .. has equipped tag {item}`)
				local message = {
					Clan = clan,
					Type = 'Tags',
					Value = item
				}
				MessageLib.PublishMessageAsync("ClanEquip", message)
			end
			return source
		end

		return transformFunc
	end,
}

function module.ClanEquip(clan, item, category, byUserId)
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		local executionFunc = EquipFuncs[category](clan, item, byUserId)
		
		local success = ScheduleLib.ScheduleWriteAsync(clan, executionFunc)
		
		if success.Success then
			local transformedData = success.Message
			local foundClan = ReplicatedStorage.Clans[clan]

			InstanceLib.ReconcileInstancesWithData(transformedData, foundClan)			
			
			return {Success = 'Success'}
		else
			return {ErrorCode = "An internal error occurred"}
		end
	else
		return {ErrorCode = 'Clan not found'}
	end
end


function module.postMail(clan, username, rank, message) -- assuming everything is checked + filtered already
	-- msgservice; PostMessage
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		local transformFunc = function(data)
			if #data.ChatBox == 500 then
				table.remove(data.ChatBox, 1)
			end

			local writingData = {
				Message = message,
				Index = data.ChatIndex,
			}

			table.insert(data.ChatBox, writingData)
			data.ChatIndex += 1
			
			return data 
		end
		
		local success, transformedData = ScheduleLib.ScheduleWriteAsync(clan, transformFunc)

		if success.Success then
			local message = {
				Clan = clan,
				Message = message,
				Index = success.Message.ChatIndex - 1
			}
			--[[
			local clan = data.Clan
			local UserId = data.UserId
			local newRank = data.Rank
		
			--]]
			MessageLib.PublishMessageAsync('PostMessage', message)
			return 'Success'
		else
			return "An internal error occured, Please try again later."
		end
		
	end
end

return module