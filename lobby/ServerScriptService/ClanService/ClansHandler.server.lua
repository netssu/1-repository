local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ClanRemotes = ReplicatedStorage.Remotes.Clans
local FilterLib = require(script.FilterLib)
local ScheduleLib = require(script.ScheduleLib)
local StringManipulation = require(ReplicatedStorage.AceLib.StringManipulation)
local ClanLib = require(script.ClanLib)
local ClanPermissions = require(ReplicatedStorage.ClansLib.ClanPermissions)
local ClanTags = require(ReplicatedStorage.ClansLib.ClanTags)
local InviteLib = require(script.InviteLib)
local UpdateNameTag = (ServerScriptService:FindFirstChild('Nametag') and ServerScriptService.Nametag.Apply) or ServerScriptService.GameMechanics.Nametag.Apply


local ClanUpgradeCalculation = require(ReplicatedStorage.ClansLib.ClanUpgradeCalculation)
local MessagingLib = require(script.MessagingLib)
local ClanLeaderboardQueue = require(ServerScriptService.ClanService.ClanLoader.ClanLeaderboardQueue)


local function isDataLoaded(plr)
	return plr.Parent and plr:FindFirstChild('DataLoaded')
end

local ratelimit = {}

local function createClan(plr, clanName, clanDescription, clanEmblem, method)
	if not isDataLoaded(plr) then return 'Please wait for your data to load' end
	if table.find(ratelimit, plr) then return 'You are being ratelimited, please wait' end
	table.insert(ratelimit, plr)

	task.delay(5, function()
		table.remove(ratelimit, table.find(ratelimit, plr))
	end)

	-- Check if clanName and clanDescription is appropriate
	clanDescription = StringManipulation.truncateToCharacterLength(clanDescription, 75)
	clanName = StringManipulation.cleanString(string.upper(StringManipulation.truncateToCharacterLength(clanName, 14)))
	clanEmblem = StringManipulation.stringToNumbers(clanEmblem)

	if method ~= 'Gems' and method ~= 'Token' then return "Unknown Error" end
	if method == 'Gems' then
		if plr.Gems.Value < 100000 then return 'You need 100,000 Gems!' end
	else
		-- Prompt Developer Product Purchase
		-- prompt: 3295256092
		if plr.ClanData.CreationTokens.Value == 0 then MarketplaceService:PromptProductPurchase(plr, 3295256092) return end
	end

	if #clanName < 3 then return "Your clan name is too short!" end
	if plr.ClanData.CurrentClan.Value ~= 'None' then return "You are already in a clan, HOW ARE YOU MAKING A CLAN?" end
	local isBanned = FilterLib.checkIfFilteredAsync(clanName, plr.UserId)
	if isBanned then return "Your clan name was filtered" end
	local isBanned = FilterLib.checkIfFilteredAsync(clanDescription, plr.UserId)
	if isBanned then return "Your clan description was filtered" end
	local result = ScheduleLib.ScheduleReadAsync(clanName)
	if result.ErrorCode then return "An Internal Server Error Occured. Please try again later." end
	if result.Message then return "Clan already exists :(" end
	local success = ClanLib.createClan(clanName, clanDescription, clanEmblem, plr)

	if not success then
		return "Internal Error, Please type /console in chat and send a screenshot to our communication server"
	else
		if method == 'Gems' then
			plr.Gems.Value -= 100000
			UpdateNameTag:Fire(plr)
			return "Success"
		else
			plr.ClanData.CreationTokens.Value -= 1
			return "Success"
		end
	end
end

local function ModifyMember(plr: Player, targetUserId, state: string)
	if not targetUserId or not state then return "Missing Parameters" end
	local CurrentClan = plr.ClanData.CurrentClan
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(CurrentClan.Value)

	if foundClan then
		-- found clan
		local foundMember = foundClan.Members:FindFirstChild(targetUserId)

		if foundMember then
			local plrRank = foundClan.Members[plr.UserId].Rank.Value
			local memberRank = foundMember.Rank.Value

			if state == 'Promote' then
				if ClanPermissions.canPromote(plrRank, memberRank) then
					local getPromotedRank = ClanPermissions.GetPromotedTo(memberRank)
					foundMember.Rank.Value = getPromotedRank
					local success = ClanLib.modifyRank(targetUserId, CurrentClan.Value, getPromotedRank, plr.Name)
					return if success == 'Success' then 'Success' else 'An internal server error occured'
				end
			elseif state == 'Demote' then
				if ClanPermissions.canDemote(plrRank, memberRank) then
					local getDemotedRank = ClanPermissions.GetDemotedTo(memberRank) 
					foundMember.Rank.Value = getDemotedRank
					local success = ClanLib.modifyRank(targetUserId, CurrentClan.Value, getDemotedRank, plr.Name)
					return if success == 'Success' then 'Success' else 'An internal server error occured'
				else
					return 'Insufficient Permissions'
				end
			else
				-- kick
				if ClanPermissions.CanKick(plrRank, memberRank) then
					foundMember:Destroy()
					local success = ClanLib.KickPlayer(targetUserId, CurrentClan.Value, plr.Name)
					if success == 'Success' then
						local foundPlr = Players:GetPlayerByUserId(targetUserId) 
						if foundPlr then
							task.spawn(function()
								repeat task.wait() until not foundPlr.Parent or foundPlr:FindFirstChild('ClansLoaded')
								foundPlr.ClanData.CurrentClan.Value = 'None'
							end)
							InviteLib.deleteInvite(foundPlr.UserId, CurrentClan.Value)
							UpdateNameTag:Fire(foundPlr)
						end
					end
					return if success == 'Success' then 'Success' else 'An internal server error occured' 
				else
					return 'Insufficient Permissions'
				end
			end
		else
			return "Member now found"
		end
	else
		return "Cannot find clan data"
	end
end

local function leaveClan(plr: Player)
	local CurrentClan = plr.ClanData.CurrentClan
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(CurrentClan.Value)

	if foundClan then
		local foundMember = foundClan.Members:FindFirstChild(plr.UserId)

		if foundMember then		
			local isLeader = foundMember.Rank.Value == 'Emperor'
			local leaderCount = 0
			
			if isLeader then
				for i,v in foundClan.Members:GetChildren() do
					if v.Rank.Value == 'Emperor' then
						leaderCount += 1
					end
				end

				if leaderCount == 1 then -- only 1 emperor left D:
					local success = ClanLib.deleteClan(CurrentClan.Value)
					if success ~= 'Success' then
						return 'An internal server error occured'
					else
						plr.ClanData.CurrentClan.Value = 'None'
						UpdateNameTag:Fire(plr)
						return 'Success'
					end
				end
			end

			local success = ClanLib.KickPlayer(plr.UserId, CurrentClan.Value)
			if success == 'Success' then
				plr.ClanData.CurrentClan.Value = 'None'
				foundMember:Destroy()
				UpdateNameTag:Fire(plr)
				return success
			end
			return 'An internal server error occured' 
		end
	end
end

local maillimit = {}
local function SendMail(plr, msg)
	if plr:FindFirstChild('ClansLoaded') and not table.find(maillimit, plr) then
		local CurrentClan = plr.ClanData.CurrentClan.Value
		local clanData = ReplicatedStorage.Clans:FindFirstChild(CurrentClan)
		local foundMember = clanData.Members:FindFirstChild(plr.UserId)
		if clanData and foundMember then
			local rank = foundMember.Rank.Value

			if ClanPermissions.canPost(rank) then
				table.insert(maillimit, plr)
				local newMsg = StringManipulation.truncateToCharacterLength(StringManipulation.cleanString(msg, true),100)
				local isModerated = FilterLib.checkIfFilteredAsync(newMsg, plr.UserId)

				if not isModerated then
					-- use clan lib to post message
					print('Posting mail')
					-- <font color="#FF0000"><b>[Leader] Bobbie:</b></font> Hello world!
					local convertedColor = ClanTags.Color3Tohex(ClanPermissions.Permissions[rank].Color)
					local constructedMessage = `<font color="{convertedColor}"><b>[{rank}]</b></font> {plr.Name}: ` .. newMsg
					ClanLib.postMail(CurrentClan, plr.Name, rank, constructedMessage)

					task.delay(6, function()
						table.remove(maillimit, table.find(maillimit, plr))
					end)
					return true
				else
					ReplicatedStorage.Events.Client.Message:FireClient(plr, "Your message was moderated", Color3.fromRGB(255,0,0))
					table.remove(maillimit, table.find(maillimit, plr))
					return true
				end		
			end
		end
	end

	return "Jeez slow down"
end

local editlimit = {}
local function EditClan(plr, moditype, result)
	if plr:FindFirstChild('ClansLoaded') and not table.find(editlimit, plr) then
		table.insert(editlimit, plr)
		task.delay(4, function()
			table.remove(editlimit, table.find(editlimit, plr))
		end)

		local CurrentClan = plr.ClanData.CurrentClan.Value
		local clanData = ReplicatedStorage.Clans:FindFirstChild(CurrentClan)
		local foundMember = clanData.Members:FindFirstChild(plr.UserId)
		if clanData and foundMember then
			local rank = foundMember.Rank.Value

			if moditype == 'Emblem' then
				if ClanPermissions.CanChangeEmblem(rank) then
					local filtered = StringManipulation.truncateToCharacterLength(StringManipulation.stringToNumbers(result), 75)
					local result = ClanLib.modifyClan(CurrentClan, moditype, filtered)
					return result
				else
					return 'Insufficient Permissions'
				end
			elseif moditype == 'Description' then
				if ClanPermissions.CanChangeDescription(rank) then
					local filtered = StringManipulation.truncateToCharacterLength(StringManipulation.cleanString(result, true), 75)
					local isModerated = FilterLib.checkIfFilteredAsync(filtered, plr.UserId)

					if not isModerated then
						local result = ClanLib.modifyClan(CurrentClan, moditype, filtered)
						return result
					else
						return "Your description was moderated"
					end
				else
					return 'Insufficient Permissions'
				end
			end
		end
	end
	return 'You are being ratelimited'
end

local JoinLimit = {}
local function JoinClan(plr, clan)
	if not table.find(JoinLimit, plr) then
		local CurrentClan = plr.ClanData.CurrentClan.Value
		local PlayerLimit = ClanUpgradeCalculation.getMemberCapFromLevel(ReplicatedStorage.Clans[clan].Upgrades.UpgradeSlotLevel.Value)

		if not (#ReplicatedStorage.Clans[clan].Members:GetChildren() < PlayerLimit) then
			return "The clan is full"
		end

		if CurrentClan == 'None' then
			local success = ClanLib.joinPlayer(plr, clan)
			if success.Success then
				ReplicatedStorage.ClanInvites[plr.UserId][clan]:Destroy()
				ServerScriptService.GameMechanics.Nametag.Apply:Fire(plr)

				return 'Success'
			else
				return 'An internal server error occurred'
			end
		else
			return "You are already in a clan"
		end
	else
		return "You are being ratelimited"
	end
end

local processing = {}

local function donateGems(plr, amount)
	local filtered = StringManipulation.stringToNumbers(amount)
	local currentClan = plr.ClanData.CurrentClan.Value
	if filtered ~= '' and currentClan ~= 'None' and not table.find(processing, plr) then
		table.insert(processing, plr)
		filtered = tonumber(filtered)
		if filtered <= plr.Gems.Value then
			local ID = plr.UserId
			local function transformFunc(source)
				
				if not source then
					error("Source is nil for clan " .. currentClan)
				end
				if not source.Members then
					error("Members table missing for clan " .. currentClan)
				end
				if not source.Members[tostring(ID)] then
					error("Player " .. ID .. " not found in clan " .. currentClan .. " members")
				end
				if not source.Members[tostring(ID)].Contributions then
					error("Contributions missing for player " .. ID .. " in clan " .. currentClan)
				end
				if source.Members[tostring(ID)].Contributions.Vault == nil then
					error("Vault contribution is nil for player " .. ID .. " in clan " .. currentClan)
				end
				
				source = ClanLib.writeToAuditLogs(source, `{plr.UserId} donated {filtered}`)
				source.Stats.Vault += filtered
				if not source.Stats.StaticVault then source.Stats.StaticVault = 0 end
				if not source.PreviousStats.StaticVault then source.PreviousStats.StaticVault = source.Stats.StaticVault end 
				source.Stats.StaticVault += filtered
				source.Members[tostring(ID)].Contributions.Vault += filtered
				return source
			end

			local success = ScheduleLib.ScheduleWriteAsync(currentClan, transformFunc)

			-- Always remove from processing, regardless of success/failure
			local processingIndex = table.find(processing, plr)
			if processingIndex then
				table.remove(processing, processingIndex)
			end

			if success.Success and success.Message then
				print('Successfully donated gems!')
				plr.Gems.Value -= filtered -- Only deduct gems on successful write

				print(success)
				print('pushing to leaderboards...')
				task.spawn(function()
					ClanLeaderboardQueue.addToQueue(currentClan, 'ClanVault', success.Message.Stats.StaticVault - success.Message.PreviousStats.StaticVault)
				end)

				local foundClan = ReplicatedStorage.Clans[currentClan]
				foundClan.Members[tostring(plr.UserId)].Contributions['Vault'].Value += filtered
				foundClan.Stats['Vault'].Value = success.Message.Stats.Vault
				
				if foundClan.Stats:FindFirstChild('StaticVault') then
					foundClan.Stats['StaticVault'].Value = success.Message.Stats.StaticVault
				end

				task.spawn(function()
					local dat = {
						UserId = plr.UserId,
						Amount = filtered,
						Total = success.Message.Stats.Vault,
						Stat = 'Vault',
						Clan = currentClan
					}
					MessagingLib.PublishMessageAsync("DonatedGems", dat)
				end)

				return "Successfully donated to clan vault!"
			else
				return "An internal server error occurred"
			end
		else
			-- Remove from processing if they don't have enough gems
			local processingIndex = table.find(processing, plr)
			if processingIndex then
				table.remove(processing, processingIndex)
			end
			return "Insufficient gems"
		end
	end
end

local ClanShop = require(ReplicatedStorage.ClansLib.ClanShop)
local DynamicPricing = require(ReplicatedStorage.ClansLib.ClanShop.DynamicPricing)


local function findKeyBasedOnName(tbl, name)
	for i,v in tbl do
		if v.Name == name then
			return i
		end
	end
end
local function clanPurchase(plr, item, category)
	if plr:FindFirstChild('ClansLoaded') and ClanShop.Shop[category] and ClanShop.Shop[category].Content[findKeyBasedOnName(ClanShop.Shop[category].Content, item)] then
		local CurrentClan = plr.ClanData.CurrentClan.Value
		local ClanData = ReplicatedStorage.Clans:FindFirstChild(CurrentClan)

		if ClanData then
			local Rank = ClanData.Members[plr.UserId].Rank.Value

			if ClanPermissions.canSpendVault(Rank) then
				-- purchase handling
				local price = nil

				-- account for dynamic pricing
				-- check if clan has enough gems inside the transform function
				local ItemData = ClanShop.Shop[category].Content[findKeyBasedOnName(ClanShop.Shop[category].Content, item)] 
				if ItemData.DynamicPrice then
					price = DynamicPricing.PriceFuncs[category][item](CurrentClan)
				else
					price = ItemData.Price
				end

				local success = ClanLib.handleClanPurchase(CurrentClan, ItemData.BackendName or item, category, plr.UserId, price, ItemData.Amount)

				if success.Success then	
					return 'Success, Some stuff such as units require rejoining in a VIP server or may take time to receive'
				else					
					return success 
				end				
			else
				return "Insufficient Permissions"
			end
		else
			return "Clan data was not found"
		end
	else
		return "You are still loading, please wait"
	end
end


local function Equip(plr, item, category)
	if plr:FindFirstChild('ClansLoaded') and ClanShop.Shop[category] and ClanShop.Shop[category].Content[findKeyBasedOnName(ClanShop.Shop[category].Content, item)] then
		local CurrentClan = plr.ClanData.CurrentClan.Value
		local ClanData = ReplicatedStorage.Clans:FindFirstChild(CurrentClan)

		if ClanData then
			local Rank = ClanData.Members[plr.UserId].Rank.Value

			if ClanPermissions.canSpendVault(Rank) then
				local success = ClanLib.ClanEquip(CurrentClan, item, category, plr.UserId)

				if success.Success then
					for i,v:Player in Players:GetChildren() do
						if v:FindFirstChild('ClansLoaded') then
							if v.ClanData.CurrentClan.Value == CurrentClan then
								UpdateNameTag:Fire(v)
							end
						end
					end

					return 'Success'
				else
					return success.ErrorCode
				end
			else
				return "Insufficient Permissions"
			end
		else
			return "Clan data was not found"
		end
	else
		return "You are still loading, please wait"
	end
end

local function invitePlayer(plr, plrName)
	if plr:FindFirstChild('ClansLoaded') then
		local currentClan = plr.ClanData.CurrentClan.Value
		local foundClan = ReplicatedStorage.Clans:FindFirstChild(currentClan)
		if foundClan then
			local rank = foundClan.Members[plr.UserId].Rank.Value
			if ClanPermissions.canInvite(rank) then
				local foundPlr = Players:FindFirstChild(plrName)
				if foundPlr then
					if foundPlr:FindFirstChild('ClansLoaded') then
						local success = InviteLib.createInvite(foundPlr, currentClan)
						return success
					else
						return "Player is still loading"
					end
				else
					return 'Player has left the server'
				end
			else
				return "You do not have permission to do this"
			end
		else
			return `Couldnt find existing clan with {currentClan}`
		end
	else
		return `Your data is still loading, please wait`
	end
end

ClanRemotes.ModifyMember.OnServerInvoke = ModifyMember
ClanRemotes.CreateClan.OnServerInvoke = createClan
ClanRemotes.LeaveClan.OnServerInvoke = leaveClan
ClanRemotes.SendMailbox.OnServerInvoke = SendMail
ClanRemotes.EditClan.OnServerInvoke = EditClan
ClanRemotes.JoinClan.OnServerInvoke = JoinClan
ClanRemotes.DonateVault.OnServerInvoke = donateGems
ClanRemotes.PurchaseClanShop.OnServerInvoke = clanPurchase
ClanRemotes.Equip.OnServerInvoke = Equip
ClanRemotes.InvitePlayer.OnServerInvoke = invitePlayer

-- Remote Events
ClanRemotes.UpdateVariable.OnServerEvent:Connect(function(plr, state)
	plr.Variables[state].Value = true -- SeenClanSplash
end)


for i,v in script.RuntimeScripts:GetChildren() do
	task.spawn(function()
		require(v)
	end)
end