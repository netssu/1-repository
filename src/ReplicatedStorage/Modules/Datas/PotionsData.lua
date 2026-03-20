------------------//CONSTANTS
local PotionsData = {}

PotionsData.POTIONS = {
	["CoinsPotion"] = {
		Name = "CoinsPotion",
		DisplayName = "2xCoinsPotion",
		BoostName = "Coins2x",
		Duration = 120,
		Image = "rbxassetid://81187465021797",
	},
	["LuckyPotion"] = {
		Name = "LuckyPotion",
		DisplayName = "2xLuckyPotion",
		BoostName = "Lucky2x",
		Duration = 120,
		Image = "rbxassetid://124014027649385",
	},
}

function PotionsData.Get(potionId)
	return PotionsData.POTIONS[potionId]
end

return PotionsData