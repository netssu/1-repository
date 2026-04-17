local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Codes = require(ReplicatedStorage.Modules.Codes)
local MessageEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Client"):WaitForChild("Message")

local RequestRedeemCodes = ReplicatedStorage:WaitForChild("Functions").RequestRedeemCode

local DataRestoreCode = {"Inventory", "InventoryV2"}

local function InRedeem(player, code: string)
    if not player:FindFirstChild('DataLoaded') then return end
    
    
	local foundKey = nil
	
	for i,v in pairs(Codes) do
		if string.upper(code) == string.upper(i) then
			foundKey = i
			code = i
		end
    end
	
    if foundKey then
        --if player.Prestige.Value == 0 and player.PlayerLevel.Value < 3 then
        --    ReplicatedStorage.Events.Client.Message:FireClient(player, "You must reach level 3 first to redeem this code!", Color3.fromRGB(255,0,0))
        --    return
        --end
        
        local auxRedeemed = player.Codes:FindFirstChild('One') or player.Codes:FindFirstChild('Chosen')
        local redeemed = player.Codes:FindFirstChild(code)
        
        if not player.Codes:FindFirstChild('One') or not player.Codes:FindFirstChild('Chosen') then
            local codeVal = Instance.new("StringValue")
            codeVal.Name = 'RedeemedCompensation'
            codeVal.Parent = player.Codes
        end
        
        
        if code == 'Compensation' and auxRedeemed and not player.Codes:FindFirstChild('RedeemedCompensation') then
            local codeVal = Instance.new("StringValue")
            codeVal.Name = 'RedeemedCompensation'
            codeVal.Parent = player.Codes


            player.Gems.Value += 1000
            MessageEvent:FireClient(player,`Compensated with 1000 gems, sorry :(`,Color3.fromRGB(47, 255, 15),true)
            return true
        elseif code == 'Compensation' and player.Codes:FindFirstChild('RedeemedCompensation') then
            return "Already Redeemed or Unavailable"
        end


		if Codes[code] then
			if Codes[code].ExpireDate ~= nil then
				local expireDate = Codes[code].ExpireDate
				local currentDate = os.date("!*t")
				if currentDate.year >= expireDate.Year and currentDate.month >= expireDate.Month and currentDate.day >= expireDate.Day and currentDate.hour >= expireDate.Hour and currentDate.min >= expireDate.Minute and currentDate.sec >= expireDate.Second then
					return "Expired"
				end
			end
			
			if redeemed then
				return "Already Redeemed"
			end
			
			if Codes[code]['Required Rank'] then
				local PlayerRoleInGroup = player:GetRoleInGroup(35339513)
				
				if PlayerRoleInGroup == Codes[code]['Required Rank'] then
					for _,codeInfo in Codes[code].Rewards do

						if codeInfo.Type == "Tower" then
							_G.createTower(player.OwnedTowers,codeInfo.Value)
							MessageEvent:FireClient(player,`You Got {codeInfo.Value}`)
						elseif codeInfo.Type == "RaidAttempt" then
							player.RaidLimitData.Attempts.Value += codeInfo.Value
							MessageEvent:FireClient(player,`You Got +{codeInfo.Value} Raid Attempt`,Color3.fromRGB(47, 255, 15),true)
						elseif codeInfo.Type == 'Junk Offering' then
							player.Items['Junk Offering'].Value += codeInfo.Value
							MessageEvent:FireClient(player,`You Got +{codeInfo.Value} Junk Offering`,Color3.fromRGB(47, 255, 15),true)
						else
							player[codeInfo.Type].Value += codeInfo.Value
							MessageEvent:FireClient(player,`You Got +{codeInfo.Value} {codeInfo.Type}`,Color3.fromRGB(47, 255, 15),true)
						end
					end

					local codeVal = Instance.new("StringValue")
					codeVal.Name = code
					codeVal.Parent = player.Codes
					return true
				else
					return "Insufficient Rank to redeem this"
				end
			end
			

			if redeemed then
				return "Already Redeemed"
			else

				for _,codeInfo in Codes[code].Rewards do

					if codeInfo.Type == "Tower" then
						_G.createTower(player.OwnedTowers,codeInfo.Value)
						MessageEvent:FireClient(player,`You Got {codeInfo.Value}`)
					elseif codeInfo.Type == "RaidAttempt" then
						player.RaidLimitData.Attempts.Value += codeInfo.Value
						MessageEvent:FireClient(player,`You Got +{codeInfo.Value} Raid Attempt`,Color3.fromRGB(47, 255, 15),true)
					elseif codeInfo.Type == 'Junk Offering' then
						player.Items['Junk Offering'].Value += codeInfo.Value
						MessageEvent:FireClient(player,`You Got +{codeInfo.Value} Junk Offering`,Color3.fromRGB(47, 255, 15),true)
					else
						player[codeInfo.Type].Value += codeInfo.Value
						MessageEvent:FireClient(player,`You Got +{codeInfo.Value} {codeInfo.Type}`,Color3.fromRGB(47, 255, 15),true)
					end
				end

				local codeVal = Instance.new("StringValue")
				codeVal.Name = code
				codeVal.Parent = player.Codes

				return true
			end
		else
			return "Invalid Code!"
		end
	else
		return "Invalid Code!"
	end
end

RequestRedeemCodes.OnServerInvoke = InRedeem