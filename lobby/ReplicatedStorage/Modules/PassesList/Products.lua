local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local GameAnalytics = require(ReplicatedStorage.GameAnalytics)

local function giveUltraVIP(Player)
	local character = Player.Character
	local overhead = character and character.Head:FindFirstChild("_overhead") or false
	if overhead and Player.OwnGamePasses["Ultra VIP"] == false then
		overhead.Frame.Tag_Frame.Visible = true
		overhead.Frame.Tag_Frame.Tag_Text.VIP_Gradient.Enabled = true
		overhead.Frame.Tag_Frame.Tag_Text.Text = `[VIP]`
		overhead.Frame.Name_Frame.Name_Text.VIP_Gradient.Enabled = true
	end
	Player.OwnGamePasses["Ultra VIP"].Value = true
end

--[[
player.LuckySpins.Value += 5
Player.Items["Fortunate Crystal"].Value,
Player.Items["Lucky"].Value,
Player.OwnGamePasses["3x Speed"].Value = true
Player.OwnGamePasses["Supreme Bundle"].Value = true
Player.Gems.Value += 50000
Player["TraitPoint"].Value += 250
--]]


local Products = {
	
	----------------------- NEW BUNDLES BY ACE
	
	[3337720767] = function(ReceiptInfo, Player) -- Fawn
		print('non shiny')
		_G.createTower(Player.OwnedTowers, 'Fawn')
		return true
	end,
	
	[3338418451] = function(ReceiptInfo, Player) -- Fawn(SHINY)
		_G.createTower(Player.OwnedTowers, 'Fawn', nil, {Shiny = true})
		return true
	end,
	
	[3307945604] = function(ReceiptInfo, Player) -- Force Fortune Pack
		
		Player.Items["Fortunate Crystal"].Value += 10
		Player.Items["Lucky Crystal"].Value += 10
		Player.Gems.Value += 5000
		Player.LuckySpins.Value += 20
		
		return true
	end,
	
	[3307946638] = function(ReceiptInfo, Player) -- Droid Starter Kit

		Player.Items["Fortunate Crystal"].Value += 2
		Player.Items["Lucky Crystal"].Value += 2
		Player.Gems.Value += 1000
		Player.TraitPoint.Value += 15

		return true
	end,
	
	[3307946165] = function(ReceiptInfo, Player) -- Wisest Jedai's Blessing
		
		Player.TraitPoint.Value += 200
		Player.Gems.Value += 7500
		Player.LuckySpins.Value += 25

		return true
	end,
	
	[3307944846] = function(ReceiptInfo, Player) -- Jedi Master Bundle
		
		Player.Gems.Value += 82000
		Player["TraitPoint"].Value += 700
		Player.OwnGamePasses["3x Speed"].Value = true
		Player.OwnGamePasses['x2 Gems'].Value = true
		
		local character = Player.Character
		local overhead = character and character.Head:FindFirstChild("_overhead") or false
		if overhead and Player.OwnGamePasses["Ultra VIP"].Value == false then
			overhead.Frame.Tag_Frame.Visible = true
			overhead.Frame.Tag_Frame.Tag_Text.VIP_Gradient.Enabled = true
			overhead.Frame.Tag_Frame.Tag_Text.Text = `[VIP]`
			overhead.Frame.Name_Frame.Name_Text.VIP_Gradient.Enabled = true
		end
		Player.OwnGamePasses["Ultra VIP"].Value = true
		
		return true
	end,

	
	
	
	----------------------- END OF NEW BUNDLES
	
	
	
	
	
	[3296909141] = function(RecieptInfo, player) -- battle pass
		player.BattlepassData.Premium.Value = true
		return true
	end,

	----------------------- BP SKIPS

	[3279744329] = function(RecieptInfo, player) -- 1
		player.BattlepassData.Tier.Value += 1
		return true
	end,

	[3286932503] = function(RecieptInfo, player) -- 5
		player.BattlepassData.Tier.Value += 5
		return true
	end,

	[3279744407] = function(RecieptInfo, player) -- 10
		player.BattlepassData.Tier.Value += 10
		return true
	end,

	-----------------------
	[3305696523] = function(ReceiptInfo, player)
		player:FindFirstChild("DailyRewards"):FindFirstChild("LastClaimTime").Value = 0
		return true
	end,

	[3282596429] = function(ReceiptInfo, player) -- Battlepass Bundle
		player.BattlepassData.Premium.Value = true
		player.BattlepassData.Tier.Value += 20
		player.LuckySpins.Value += 5


		return true
	end,
	
	
	


	[3295256092] = function(RecieptInfo, player) -- clan token refill thing
		player.ClanData.CreationTokens.Value += 1

		return true
	end,

	[3221509781] = function(ReceiptInfo, Player)	--Mini Pack
		Player.Gems.Value += 500
		return true
	end,
	[3221510072] = function(ReceiptInfo, Player)	--Small Pack
		Player.Gems.Value += 2000

		return true
	end,
	[3221510368] = function(ReceiptInfo, Player)	--Medium Pack
		Player.Gems.Value += 3000

		return true
	end,
	[3221510579] = function(ReceiptInfo, Player)	--Large Pack
		Player.Gems.Value += 5000

		return true
	end,
	[3221510847] = function(ReceiptInfo, Player)	--Huge Pack
		Player.Gems.Value += 20000

		return true
	end,
	[3221511117] = function(ReceiptInfo, Player)	--Massive Pack
		Player.Gems.Value += 50000
		
		return true
	end,
	[3221511460] = function(ReceiptInfo, Player)	--Colossal Pack
		Player.Gems.Value += 100000
		
		return true
	end,

	[3221514046] = function(ReceiptInfo, Player)    --Fortunate Crystal
		Player.Items["Fortunate Crystal"].Value += 1
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			1,
			Player.Items["Fortunate Crystal"].Value,
			"Fortunate Crystal"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Item"
		local itemId = "Fortunate Crystal"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,


	[3294700047] = function(ReceiptInfo, Player)    --Fortunate Crystal Bundle
		Player.Items["Fortunate Crystal"].Value += 3
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			1,
			Player.Items["Fortunate Crystal"].Value,
			"Fortunate Crystal"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Item"
		local itemId = "Fortunate Crystal"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,


	[3221514284] = function(ReceiptInfo, Player)    --Lucky Crystal
		local DefaultValue = Player.Items["Lucky Crystal"].Value
		Player.Items["Lucky Crystal"].Value += 1



		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			1,
			Player.Items["Lucky Crystal"].Value,
			"Lucky Crystal"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Crystals"
		local itemId = "Lucky Crystal"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,

	[3294700254] = function(ReceiptInfo, Player)    -- Junk Offering Bundle
		Player.Items["Junk Offering"].Value += 3
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			1,
			Player.Items["Junk Offering"].Value,
			"Junk Offering"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Crystals"
		local itemId = "Junk Offering"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,

	[3294700439] = function(ReceiptInfo, Player)    --Lucky Crystal Bundle
		local DefaultValue = Player.Items["Lucky Crystal"].Value
		Player.Items["Lucky Crystal"].Value += 3



		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			1,
			Player.Items["Lucky Crystal"].Value,
			"Lucky Crystal"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Crystals"
		local itemId = "Lucky Crystal"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,


	[3294700715] = function(ReceiptInfo, Player)    -- x2 Raid Luck Bundle
		Player.Items["x2 Raid Luck"].Value += 3
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			1,
			Player.Items["x2 Raid Luck"].Value,
			"x2 Raid Luck"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Crystals"
		local itemId = "x2 Raid Luck"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,


	[3294704373] = function(ReceiptInfo, Player)    -- x3 Raid Luck Crystal
		Player.Items["x3 Raid Luck"].Value += 3
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			1,
			Player.Items["x3 Raid Luck"].Value,
			"x3 Raid Luck"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Crystals"
		local itemId = "x3 Raid Luck"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,



	[3221515245] = function(ReceiptInfo, Player) -- x1 WillPowers
		Player["LuckyWillpower"].Value += 1
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"LuckyWillpower",
			1,
			Player["TraitPoint"].Value,
			"x1 Lucky WillPowers"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "TraitPoint"
		local itemId = "x1 WillPowers"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[3250974753] = function(ReceiptInfo, Player) -- x10 WillPowers
		Player["TraitPoint"].Value += 20

		return true
	end,
	[3250975033] = function(ReceiptInfo, Player) -- x25 WillPowers
		Player["TraitPoint"].Value += 50
		
		return true
	end,
	[3250975313] = function(ReceiptInfo, Player) -- x50 WillPowers
		Player["TraitPoint"].Value += 100

		return true
	end,
	[3250976109] = function(ReceiptInfo, Player) -- x100 WillPowers
		Player["TraitPoint"].Value += 250
		return true
	end,
	[3263599604] = function(ReceiptInfo, Player) -- Refill Raid Attempts
		Player.RaidLimitData.Attempts.Value = 10
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"RaidRefill",
			1,
			5,
			"Raid Refill"
		)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "RaidRefill"
		local itemId = "Raid Refill"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[2659785711] = function(ReceiptInfo, Player) --Starter Pack
		if Player.OwnGamePasses["Starter Pack"].Value == true then
			return false
		end
		Player.OwnGamePasses["Starter Pack"].Value = true
		Player["TraitPoint"].Value += 5
		Player["Gems"].Value += 500
		_G.createTower(Player.OwnedTowers,"Frenk")

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Bundle"
		local itemId = "Starter Pack"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[3250033230] = function(ReceiptInfo, Player)	--2x Coin Boost [1HR]
		local item = Player.Items:FindFirstChild("2x Coins")
		item.Value += 1

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Pass"
		local itemId = "2x Coins"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[3250040699] = function(ReceiptInfo, Player)	--2x Gem Boost [1HR]
		local item = Player.Items:FindFirstChild("2x Gems")
		item.Value += 1

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Pass"
		local itemId = "2x Gems"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[3250657727] = function(ReceiptInfo, Player)	--2x XP Boost [1HR]
		local item = Player.Items:FindFirstChild("2x XP")
		item.Value += 1

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Pass"
		local itemId = "2x XP"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		return true
	end,
	[3257561721] = function(ReceiptInfo,Player)	--Starter Bundle
		Player.OwnGamePasses["VIP"].Value = true
		Player.OwnGamePasses["2x Speed"].Value = true
		Player.OwnGamePasses["Starter Bundle"].Value = true
		Player.Gems.Value += 500
		Player["TraitPoint"].Value += 10

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Bundle"
		local itemId = "Starter Bundle"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		local character = Player.Character
		local overhead = character and character.Head:FindFirstChild("_overhead") or false
		if overhead and Player.OwnGamePasses["Ultra VIP"] == false then
			overhead.Frame.Tag_Frame.Visible = true
			overhead.Frame.Tag_Frame.Tag_Text.VIP_Gradient.Enabled = true
			overhead.Frame.Tag_Frame.Tag_Text.Text = `[VIP]`
			overhead.Frame.Name_Frame.Name_Text.VIP_Gradient.Enabled = true
		end

		return true
	end,
	[3257605348] = function(ReceiptInfo,Player)	--Supreme Bundle
		Player.OwnGamePasses["Ultra VIP"].Value = true
		Player.OwnGamePasses["3x Speed"].Value = true
		Player.OwnGamePasses["Supreme Bundle"].Value = true
		Player.Gems.Value += 50000
		Player["TraitPoint"].Value += 250

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Pass"
		local itemId = "Supreme Bundle"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		local character = Player.Character
		local overhead = character and character.Head:FindFirstChild("_overhead") or false
		if overhead then
			overhead.Frame.Tag_Frame.Visible = true
			overhead.Frame.Tag_Frame.Tag_Text.UltraVIP_Gradient.Enabled = true
			overhead.Frame.Tag_Frame.Tag_Text.Text = `[ULTRA VIP]`
			overhead.Frame.Name_Frame.Name_Text.UltraVIP_Gradient.Enabled = true
		end

		return true
	end,

	[3268063455] = function(ReceiptInfo,Player) -- Luck Bundle
		Player.Gems.Value += 1000
		Player.Items['Lucky Crystal'].Value += 2
		Player.Items['Fortunate Crystal'].Value += 2
		Player.LuckySpins.Value += 5
		--AnalyticsService:LogEconomyEvent(
		--    Player,
		--    Enum.AnalyticsEconomyFlowType.Source,
		--    "Items",
		--    2,
		--    Player.Items["Lucky Crystal"].Value,
		--    "Lucky Crystal"
		--)
		--AnalyticsService:LogEconomyEvent(
		--    Player,
		--    Enum.AnalyticsEconomyFlowType.Source,
		--    "Items",
		--    2,
		--    Player.Items["Fortunate Crystal"].Value,
		--    "Fortuante Crystal"
		--end

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Bundle"
		local itemId = "Luck Bundle"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})


		return true
	end,

	[3268063964] = function(ReceiptInfo, Player) -- 4-Leaf Bundle
		Player.Gems.Value += 2500
		Player.TraitPoint.Value += 100
		-- 5 lucky summons
		Player.LuckySpins.Value += 5

		--Player.Items['Lucky Crystal'].Value += 2
		--Player.Items['Fortunate Crystal'].Value += 2

		--AnalyticsService:LogEconomyEvent(
		--    Player,
		--    Enum.AnalyticsEconomyFlowType.Source,
		--    "Items",
		--    2,
		--    Player.Items["Lucky Crystal"].Value,
		--    "Lucky Crystal"
		--)
		--AnalyticsService:LogEconomyEvent(
		--    Player,
		--    Enum.AnalyticsEconomyFlowType.Source,
		--    "Items",
		--    2,
		--    Player.Items["Fortunate Crystal"].Value,
		--    "Fortuante Crystal"
		--)

		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Bundle"
		local itemId = "Luck Bundle"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})
		return true
	end,

	[3276829944] = function(ReceiptInfo, Player) -- x1 Lucky Summon
		Player.LuckySpins.Value += 1

		return true
	end,

	[3276830049] = function(ReceiptInfo, Player) -- x5 Lucky Summon
		Player.LuckySpins.Value += 5

		return true
	end,

	[3276831656] = function(ReceiptInfo, Player) -- x10 Lucky Summon
		Player.LuckySpins.Value += 10

		return true
	end,

	[3276832248] = function(ReceiptInfo, Player) -- x20 Lucky Summon
		
		Player.LuckySpins.Value += 30

		return true
	end,


	[3282373891] = function(ReceiptInfo, Player) -- 25 Junk Trader Points
		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Currency"
		local itemId = "25 Junk Trader Points"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			25,
			Player.JunkTraderPoints.Value,
			"25 Junk Trader Points"
		)

		Player.JunkTraderPoints.Value += 25
		ReplicatedStorage.Events.Client.Junktrader:Fire(true)

		return true
	end,	

	[3282373336] = function(ReceiptInfo, Player) -- 50 Junk Trader Points
		local userId = Player.UserId
		local amount = ReceiptInfo.CurrencySpent
		local itemType = "Currency"
		local itemId = "50 Junk Trader Points"
		local cartType = "InGame"
		-- local USDSpent = math.floor((amount * 0.7) * 0.35)

		GameAnalytics:addBusinessEvent(userId, {
			amount = amount,
			itemType = itemType,
			itemId = itemId,
			cartType = cartType
		})

		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Items",
			50,
			Player.JunkTraderPoints.Value,
			"50 Junk Trader Points"
		)

		Player.JunkTraderPoints.Value += 50
		ReplicatedStorage.Events.Client.Junktrader:Fire(true)

		return true
	end,

	[3290504878] = function(ReceiptInfo, Player)
			--[[

				OldStreak = 0,
				Streak = 0,
				StreakIncreasesIn = os.clock() + 86400,
				StreakRestoreExpiresIn = os.clock() + 86400 * 3,
				PlayStreakAnimation = false

				--]]

		if Player.StreakRestoreExpiresIn.Value > os.clock() and Player.OldStreak.Value ~= 0 and Player.StreakRestoreExpiresIn.Value ~= 0 then

			Player.Streak.Value = Player.OldStreak.Value
			Player.OldStreak.Value = 0
			Player.StreakRestoreExpiresIn.Value = 0
			Player.StreakIncreaseIn.Value = os.clock() + 86400
			Player.PlayStreakAnimation.Value = true

			return true
		end
	end,

	[3291161002] = function(ReceiptInfo, Player) -- Lucky Willpower
		--warn("Firing", Player)
		--warn(Player)
		--local userId = Player.UserId
		--local amount = 99
		--local itemType = "Crystals"
		--local itemId = "1x Lucky Willpower"
		--local cartType = "InGame"
		---- local USDSpent = math.floor((amount * 0.7) * 0.35)

		--GameAnalytics:addBusinessEvent(userId, {
		--	amount = amount,
		--	itemType = itemType,
		--	itemId = itemId,
		--	cartType = cartType
		--})
		Player.Items["Double Willpower Luck"].Value += 1
		return true	
	end,


	[3294703556] = function(ReceiptInfo, Player) -- Lucky Willpower Bundle
		--warn("Firing", Player)
		--warn(Player)
		--local userId = Player.UserId
		--local amount = 99
		--local itemType = "Crystals"
		--local itemId = "1x Lucky Willpower"
		--local cartType = "InGame"
		---- local USDSpent = math.floor((amount * 0.7) * 0.35)

		--GameAnalytics:addBusinessEvent(userId, {
		--	amount = amount,
		--	itemType = itemType,
		--	itemId = itemId,
		--	cartType = cartType
		--})
		Player.Items["Double Willpower Luck"].Value += 3
		return true	
	end
}

return Products