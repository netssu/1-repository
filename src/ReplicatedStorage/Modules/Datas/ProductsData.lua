------------------//SERVICES

------------------//CONSTANTS
local PRODUCT_TYPES = {
	DEVELOPER_PRODUCT = "DeveloperProduct",
	GAMEPASS = "Gamepass",
}

------------------//VARIABLES
local ProductsData = {}

ProductsData.DeveloperProducts = {
	["Coins_1000"] = {
		ProductId = 3526740464,
		Name = "$1000 Coins",
		Price = 1,
		Category = "Gold",
		Icon = "rbxassetid://0",
		Rewards = {
			Coins = 1000,
		},
	},
	["Coins_3000"] = {
		ProductId = 3526740864,
		Name = "$3000 Coins",
		Price = 1,
		Category = "Gold",
		Icon = "rbxassetid://0",
		Rewards = {
			Coins = 3000,
		},
	},
	["Coins_6000"] = {
		ProductId = 3526741624,
		Name = "$6000 Coins",
		Price = 1,
		Category = "Gold",
		Icon = "rbxassetid://0",
		Rewards = {
			Coins = 6000,
		},
	},
	["Coins_10000"] = {
		ProductId = 3526741851,
		Name = "$10.000 Coins",
		Price = 1,
		Category = "Gold",
		Icon = "rbxassetid://0",
		Rewards = {
			Coins = 10000,
		},
	},
	["Coins2x"] = {
		ProductId = 3526744299,
		Name = "2xCoins",
		Price = 1,
		Category = "Boosts",
		Icon = "rbxassetid://0",
		Rewards = {
			BoostType = "Coins2x",
			PotionId = "CoinsPotion",
		},
	},
	["Lucky2x"] = {
		ProductId = 3526745060,
		Name = "2xLucky",
		Price = 1,
		Category = "Boosts",
		Icon = "rbxassetid://0",
		Rewards = {
			BoostType = "Lucky2x",
			PotionId = "LuckyPotion",
		},
	},
	["Coins4x"] = {
		ProductId = 3526744558,
		Name = "4xCoins",
		Price = 1,
		Category = "Boosts",
		Icon = "rbxassetid://0",
		Rewards = {
			BoostType = "Coins4x",
		},
	},
	["Lucky4x"] = {
		ProductId = 3526745229,
		Name = "4xLucky",
		Price = 1,
		Category = "Boosts",
		Icon = "rbxassetid://0",
		Rewards = {
			BoostType = "Lucky4x",
		},
	},
	["MegaCupcakeEgg_1x"] = {
		ProductId = 3546145760,
		Name = "1x Mega Cupcake Egg",
		Price = 1,
		Category = "Eggs",
		Icon = "rbxassetid://0",
		Rewards = {
			Egg = "MegaCupcake",
			Amount = 1,
		},
	},
	["MegaCupcakeEgg_3x"] = {
		ProductId = 3546146655,
		Name = "3X Mega Cupcake Egg",
		Price = 1,
		Category = "Eggs",
		Icon = "rbxassetid://0",
		Rewards = {
			Egg = "MegaCupcake",
			Amount = 3,
		},
	},
	["MegaCupcakeEgg_5x"] = {
		ProductId = 3546146807,
		Name = "5X Mega Cupcake Egg",
		Price = 1,
		Category = "Eggs",
		Icon = "rbxassetid://0",
		Rewards = {
			Egg = "MegaCupcake",
			Amount = 5,
		},
	},
	["MassivePack"] = {
		ProductId = 3546148697,
		Name = "MASSIVE PACK",
		Price = 1,
		Category = "Packs",
		Icon = "rbxassetid://0",
		Rewards = {
			Coins = 50500,
		},
	},
}

ProductsData.Gamepasses = {
	["StarterPack"] = {
		GamepassId = 1700273220,
		Name = "Starter Pack",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "Automatically jump when landing",
		DataPath = "Gamepasses.StarterPack",
	},
	["AutoJump"] = {
		GamepassId = 1699595369,
		Name = "Auto Jump",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "Automatically jump when landing",
		DataPath = "Gamepasses.AutoJump",
	},
	["ExtraSlotPet"] = {
		GamepassId = 1700692919,
		Name = "Extra Pet Slots",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "Unlock extra pet slots",
		DataPath = "Gamepasses.ExtraPetSlots",
	},
	["Easier Perfect Landings"] = {
		GamepassId = 1701310636,
		Name = "Easier Perfect Landings",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "Easier Perfect Landings",
		DataPath = "Gamepasses.EasierPerfectLandings",
	},
	["Faster Hatch"] = {
		GamepassId = 1702677369,
		Name = "Faster Hatch",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "Faster Hatch",
		DataPath = "Gamepasses.FasterHatch",
	},
	["GuidingStar"] = {
		GamepassId = 1728612056,
		Name = "GuidingStar",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "GuildingStar",
		DataPath = "Gamepasses.GuidingStar",
	},
	["NeonArc"] = {
		GamepassId = 1728246158,
		Name = "NeonArc",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "NeonArc",
		DataPath = "Gamepasses.NeonArc",
	},
	["PoisonVine"] = {
		GamepassId = 1729925043,
		Name = "PoisonVine",
		Price = 1,
		Icon = "rbxassetid://0",
		Description = "PoisonVine",
		DataPath = "Gamepasses.PoisonVine",
	},
}

------------------//FUNCTIONS
function ProductsData.GetProductById(productId: number)
	for key, product in pairs(ProductsData.DeveloperProducts) do
		if product.ProductId == productId then
			return product, key, PRODUCT_TYPES.DEVELOPER_PRODUCT
		end
	end
	return nil
end

function ProductsData.GetGamepassById(gamepassId: number)
	for key, gamepass in pairs(ProductsData.Gamepasses) do
		if gamepass.GamepassId == gamepassId then
			return gamepass, key, PRODUCT_TYPES.GAMEPASS
		end
	end
	return nil
end

function ProductsData.GetProductsByCategory(category: string)
	local products = {}
	for key, product in pairs(ProductsData.DeveloperProducts) do
		if product.Category == category then
			products[key] = product
		end
	end
	return products
end

------------------//INIT
return ProductsData