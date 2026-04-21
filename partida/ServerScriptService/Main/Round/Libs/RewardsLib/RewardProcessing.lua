local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost)
local Variables = require(ServerScriptService.Main.Round.Variables)
local info = workspace.Info


return function(player : Player)
	local DoubleEXP = if player.OwnGamePasses["2x Player XP"].Value then 2 else 1
	
	print(Variables.ActStats)
	warn(Variables.ActStats.Rewards)
	
	for reward, amount in Variables.ActStats.Rewards or {} do
		if reward == 'Gems' then continue end
		
		local Rewards = {
			PlayerExp = function()
				local PrestigeValue = player:FindFirstChild("Prestige").Value
				player[reward].Value += math.round(amount * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10)/100) ))
				player:SetAttribute("PlayerXP", math.round(amount * (GetPlayerBoost(player, "XP") * GetVipsBoost(player) * DoubleEXP * (1 + (PrestigeValue * 10)/100) )))
			end,

			Credits = function()
				player.RaidData.Credits.Value += amount
			end,

			Eggs = function()
				player.EventData.Easter.Eggs += amount
			end,
		}

		if reward == "Gems" or reward == "Coins" or reward == "PlayerExp" or reward == 'Eggs' then -- or reward == 'Credits'
			if Rewards[reward] then
				Rewards[reward]()
			else
				print('[REWARD PROCESSING] - giving gems')
				local total = amount * GetPlayerBoost(player, reward)
				local nonBoostTotal = amount
				
				print('Total:')
				print(total)
				print('Non boost:')
				print(nonBoostTotal)
				
				player[reward].Value += total
			end
		elseif reward == "Items" then
			for item, quantity in amount do
				if player.Items:FindFirstChild(item) then
					player.Items[item].Value += quantity
				else
					warn(item.." not found in "..player.Name)
				end
			end
		elseif reward == "Tower" then
			if info.Raid.Value and info.Infinity.Value then
				require(script.RaidInfiniteTower)(player, amount)
				continue
			end
			
			--warn('--------- TOWER ------- -UNIT -----')
			local unitName = amount['unit']
			local chance = amount['chance']

			local roll = math.random() * 100 
			local luckBoost = 1

			if player.ActiveBoosts:FindFirstChild('RaidLuck3x') then
				luckBoost = 3
			elseif player.ActiveBoosts:FindFirstChild('RaidLuck2x') then
				luckBoost = 2
			end

			if player.OwnGamePasses['x2 Raid Luck'].Value then
				luckBoost += 1
			end

			luckBoost += Variables.raidLuckIncrease/100

			if roll < (chance * luckBoost) or game.PlaceId == 77187363960578 then -- or game.PlaceId == 77187363960578 or forceUnit then
				_G.createTower(player.OwnedTowers, unitName)
			else
				Variables.ActStats.Rewards['Tower'] = nil
			end
		end
	end
end