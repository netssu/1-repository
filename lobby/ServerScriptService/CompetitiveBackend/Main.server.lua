local MessagingService = game:GetService('MessagingService')
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TakeMeToComp = ReplicatedStorage.Remotes.TeleportMeToComp
local RankCalculator = require(ReplicatedStorage.CompetitiveData.RankCalculator)
local MemoryStoreService = game:GetService("MemoryStoreService")
local RankedServersStore = MemoryStoreService:GetHashMap('CompServers')
local Blackout = ReplicatedStorage.Remotes.UI.Blackout

local requests = {}

local id -- id for comp lobby

if game.PlaceId == 117137931466956 then
	id = 126417999074475 -- testing
else
	id = 123588521975767 -- mainops
end

TakeMeToComp.OnServerEvent:Connect(function(plr)
	-- check if player is banned from comp
	local plrData = if plr:FindFirstChild('DataLoaded') then plr else nil

	if plrData then
		--if not plrData.CompetitiveData.isCompBanned.Value then
			-- player isnt banned
			local compRank = RankCalculator.getRankAndDivision(plrData.ELO.Value)

			-- check if there is a server available??
			local serverAvailable = nil

			local message = {
				['Rank'] = compRank
			}

			local connection
			local timeOut = Instance.new('BindableEvent')

			connection = MessagingService:SubscribeAsync('ServerIsAvailable', function(message)
				if connection then	
					if message.Data.Rank == compRank then -- it is the rank we are looking for!
						-- code is message.ReserveCode
						serverAvailable = message.Data.ReserveCode
						timeOut:Fire()
						connection:Disconnect()
					end		
				end
			end)

			MessagingService:PublishAsync('IsServerAvailable?', message)

			task.delay(3, function()
				timeOut:Fire()
			end)
			
			timeOut.Event:Wait()

			if serverAvailable then
				Blackout:FireClient(plr)				
				TeleportService:TeleportToPrivateServer(id, serverAvailable, {plr})
				return
			end

			-- there isnt a server available, lets create one
			local code = TeleportService:ReserveServer(id)

			local Data = {
				['Rank'] = compRank,
				['ReserveCode'] = code
			}

			local s,e = pcall(function()
				RankedServersStore:SetAsync(plr.UserId, Data, 360)
			end)

			if not s then
				print(e)
				pcall(function()
					RankedServersStore:SetAsync(plr.UserId, Data, 360)
				end) -- hope it works D:
			end

			TeleportService:TeleportToPrivateServer(id, code, {plr})
		--end
	end
end)