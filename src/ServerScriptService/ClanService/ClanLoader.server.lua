local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService('Players')
local ScheduleLib = require(script.Parent.ClansHandler.ScheduleLib)
local InstanceLib = require(ServerScriptService.ClanService.ClansHandler.InstanceLib)
local ClanLib = require(ServerScriptService.ClanService.ClansHandler.ClanLib)
local RewardsService = require(script.Parent.ClansHandler.RewardsService)
local ClanQuestsLib = require(ServerScriptService.ClanService.ClanQuestsLib)
local UpdateNameTag = (ServerScriptService:FindFirstChild('Nametag') and ServerScriptService.Nametag.Apply) or ServerScriptService.GameMechanics.Nametag.Apply
local clansBeingLoaded = {}
local rewardProcessing = {}

local function calendarMonthsSinceEpoch()
	local now = os.date("*t", tick())
	return (now.year - 1970) * 12 + (now.month - 1)
end


Players.PlayerAdded:Connect(function(plr)
	repeat task.wait() until not plr.Parent or plr:FindFirstChild('DataLoaded')
	
	
	if plr.Parent then
		-- their data has loaded, proceed to load clan data(if any)
		repeat task.wait() until not plr.Parent or plr:FindFirstChild('ClansLoaded')
		
		local TargetClan = plr.ClanData.CurrentClan.Value
		if not ReplicatedStorage.Clans:FindFirstChild(plr.ClanData.CurrentClan.Value) and TargetClan ~= 'None' and not table.find(clansBeingLoaded, TargetClan) then
			table.insert(clansBeingLoaded, TargetClan)
			--print(`We cannot find the the clan: {TargetClan} in cache, loading it`)
			local Response = ScheduleLib.ScheduleReadAsync(TargetClan)
			--[[
			response example:
			{
				Message = response
				ErrorCode = true
			}
			--]]

			if not Response.ErrorCode then
				local newClanData = Response.Message
				local ClanFolder = Instance.new('Folder')
				ClanFolder.Name = TargetClan
				
				-- Reconcile
				local templateModified = false -- change to false
				local processedTable = nil
				for i,v in ClanLib.ClanTemplate do
					if newClanData[i] == nil then -- KEEP IT AS == NIL BECAUSE OF DELETED = FALSE
						if i == 'PreviousStats' then
							newClanData[i] = v
							
							for oldVal,val in newClanData.Stats do
								newClanData[i][oldVal] = val
							end
						end
						
						newClanData[i] = v
						templateModified = true
					end
				end
				
				if newClanData.LastClanNumber ~= calendarMonthsSinceEpoch() then
					for i,v in newClanData['PreviousStats'] do
						if v == 0 then
							newClanData['PreviousStats'][i] = newClanData['Stats'][i]
						end
					end
				end
				
				processedTable = RewardsService.processRewards(newClanData)

				if not processedTable.Members[tostring(plr.UserId)] then -- just so that ace can force himself into clans
					processedTable.Members[tostring(plr.UserId)] = {
						Rank = 'Initiate',
						Contributions = {
							Kills = 0,
							Vault = 0,
							XP = 0,
						},
						Username = plr.Name,
						DisplayName = plr.DisplayName
					}
					templateModified = true
				end
				
				if not processedTable.Members[tostring(plr.UserId)].Username then
					processedTable.Members[tostring(plr.UserId)].Username = plr.Name
					processedTable.Members[tostring(plr.UserId)].DisplayName = plr.DisplayName
					templateModified = true
				end
				
				newClanData = processedTable
				
				if templateModified then
					print('Template has been modified, updating!')
					local success =	ScheduleLib.ScheduleWriteAsync(TargetClan, function()
						return newClanData
					end)
					
					-- now sure how we're supposed to do error handling
					if not success.Success then
						error(`There was a HUGE error whilst trying to load {TargetClan}`)
					end
				end
				
				InstanceLib.DeepLoadDataToInstances(newClanData, ClanFolder)
				ClanFolder.Parent = ReplicatedStorage.Clans
				
				-- check if player was kicked
				task.spawn(function()
					if not ClanFolder.Members:FindFirstChild(tostring(plr.UserId)) then
						-- player was kicked :c
						plr.ClanData.CurrentClan.Value = 'None'
					end
				end)
				
				ClanQuestsLib.reconcileQuests(ClanFolder.Name) -- load quetss if we dont have it already
				
				Instance.new('Folder', ClanFolder).Name = 'Loaded'
				table.remove(clansBeingLoaded, table.find(clansBeingLoaded, TargetClan))
			end
			
			for i,v in Players:GetChildren() do
				if v:FindFirstChild('ClansLoaded') then
					UpdateNameTag:Fire(v)
				end
			end
			
		elseif not table.find(rewardProcessing, TargetClan) and ReplicatedStorage.Clans:FindFirstChild(TargetClan) then
			table.insert(rewardProcessing, TargetClan)
			task.delay(15, function()
				table.remove(rewardProcessing, table.find(rewardProcessing, TargetClan))
			end)
			
			local Response = ScheduleLib.ScheduleReadAsync(TargetClan)
			
			if not Response.ErrorCode then
				local newClanData = Response.Message
				local processedTable = RewardsService.processRewards(newClanData)
				InstanceLib.ReconcileInstancesWithData(newClanData, ReplicatedStorage.Clans[TargetClan])
			end
		end
	end
end)

require(script.ClanLeaderboardRewards)