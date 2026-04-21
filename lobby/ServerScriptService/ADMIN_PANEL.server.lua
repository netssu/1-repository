local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Compensaiton = DataStoreService:GetDataStore('Compensation')


local fire = ReplicatedStorage.BOOM

local whitelist = {
	794444736,
	2309402771,
	546957599,
	5365172226,
	864876417
}

local funcs = {
	['OwnGamePasses'] = function(plrName, gp)
		Players[plrName].OwnGamePasses[gp].Value = true
	end,
	['Items'] = function(plrName, item)
		Players[plrName].Items[item].Value += 1
	end,
	['Willpower'] = function(plrName, amount)
		Players[plrName].TraitPoint.Value += amount
	end,
	['Gems'] = function(plrName, amount)
		if Players:FindFirstChild(plrName) then
			Players[plrName].Gems.Value += amount
		else
			local UserId = tonumber(plrName)
			local Data = {
				Type = 'Gems',
				Item = amount
			}

			Compensaiton:UpdateAsync(UserId, function(oldData)
				oldData = oldData or {}
				table.insert(oldData, Data)

				return oldData
			end)
		end
	end,
	['LuckySpins'] = function(plrName, amount)
		Players[plrName].LuckySpins.Value += amount
	end,
	['Tower'] = function(plrName, tower, isShiny)
		_G.createTower(Players[plrName].OwnedTowers, tower, nil, {Shiny = isShiny})
	end,
	['Battlepass'] = function(UserId)
		UserId = tonumber(UserId)
		
		local Data = {
			Type = 'Battlepass Bundle'
		}
		
		Compensaiton:UpdateAsync(UserId, function(oldData)
			oldData = oldData or {}
			table.insert(oldData, Data)
			
			return oldData
		end)
	end,
	
	['Battlepass Bundle'] = function(UserId)
		UserId = tonumber(UserId)
		local Data = {
			Type = 'Battlepass Bundle'
		}

		Compensaiton:UpdateAsync(UserId, function(oldData)
			oldData = oldData or {}
			table.insert(oldData, Data)

			return oldData
		end)
		
	end,
	['Clans'] = function(UserId)
		UserId = tonumber(UserId)
		local Data = {
			Type = 'Gems',
			Item = 100000
		}

		Compensaiton:UpdateAsync(UserId, function(oldData)
			oldData = oldData or {}
			table.insert(oldData, Data)

			return oldData
		end)
	end,
}

fire.OnServerEvent:Connect(function(plr, Itemtype, targetPlr, item, secondVal)
	if secondVal == 'true' then secondVal = true end
	
	if table.find(whitelist, plr.UserId) then
		funcs[Itemtype](targetPlr, item, secondVal)
	end
end)