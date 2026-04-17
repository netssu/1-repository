local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}

local ClanUpgradeCalculation = require(ReplicatedStorage.ClansLib.ClanUpgradeCalculation)

module.PriceFuncs = {
	Misc = {
		['+1 Clan Slot Upgrade'] = function(clan) -- scales based on slot level
			local clanData = ReplicatedStorage.Clans:WaitForChild(clan)
			return ClanUpgradeCalculation.getCalculatedUpgradeCost(clanData.Upgrades.UpgradeSlotLevel.Value)
		end,
	}
}

module.PriceEvents = {
	Misc = {
		['+1 Clan Slot Upgrade'] = function(label: TextLabel, clan, category, name)
			local clanData = ReplicatedStorage.Clans[clan]
			local connection = clanData.Upgrades.UpgradeSlotLevel.Changed:Connect(function()
				label.Text = module.PriceFuncs[category][name](clan)
			end)
			return connection
		end,
	}
}

return module