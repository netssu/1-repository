local Products = {
	[1683767419] = {
		Name = "Vip Game Pass",
		Category = "GamePass",
		RewardPath = { "Gamepass", "GamePassVip" },
		Amount = 0,
	},
	[1683659463] = {
		Name = "Toxic Emotes",
		Category = "GamePass",
		RewardPath = { "Gamepass", "ToxicEmotes" },
		Amount = 0,
	},
	[1683525515] = {
		Name = "Anime Emotes",
		Category = "GamePass",
		RewardPath = { "Gamepass", "AnimeEmotes" },
		Amount = 0,
	},
	[1686011331] = {
		Name = "Skip Spin",
		Category = "GamePass",
		RewardPath = { "Gamepass", "SkipSpin" },
		Amount = 0,
	},

	[3519502791] = {
		Name = "Yen Stack",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "Yen" },
		Amount = 5000,
	},
	[3519503178] = {
		Name = "Yen Bag",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "Yen" },
		Amount = 10000,
	},
	[3519503824] = {
		Name = "Yen Briefcase",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "Yen" },
		Amount = 25000,
	},
	[3519504193] = {
		Name = "Yen Vault",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "Yen" },
		Amount = 50000,
	},
	[3519504525] = {
		Name = "Yen Treasury",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "Yen" },
		Amount = 75000,
	},
	[3519504697] = {
		Name = "Yen Fortune",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "Yen" },
		Amount = 100000,
	},
	[3519507827] = {
		Name = "Cosmetic Pack",
		Category = "DevProduct",
		Action = "OpenCard",
		CardType = "Cosmetics",
		Amount = 2500,
	},
	[3519508067] = {
		Name = "Emote Pack",
		Category = "DevProduct",
		Action = "OpenCard",
		CardType = "Emotes",
		Amount = 3000,
	},
	[3519508867] = {
		Name = "Player Card Pack",
		Category = "DevProduct",
		Action = "OpenCard",
		CardType = "Player",
		Amount = 4000,
	},
	[3571623754] = {
		Name = "Anime Emotes",
		Category = "DevProduct",
		Action = "InventoryPack",
		Items = {
			{
				ItemType = "Emote",
				ItemName = "JOJO POSE",
			},
		},
		Amount = 1,
	},
	[3571623981] = {
		Name = "Toxic Emotes",
		Category = "DevProduct",
		Action = "InventoryPack",
		Items = {
			{
				ItemType = "Emote",
				ItemName = "TAKE THE L",
			},
		},
		Amount = 1,
	},
	[3571624100] = {
		Name = "TikTok Emotes",
		Category = "DevProduct",
		Action = "InventoryPack",
		Items = {
			{
				ItemType = "Emote",
				ItemName = "SHUFFLE",
			},
		},
		Amount = 1,
	},
	[3571625715] = {
		Name = "VIP",
		Category = "DevProduct",
		Action = "InventoryItem",
		ItemType = "Card",
		ItemName = "VIP",
		Amount = 1,
	},
	[3571625783] = {
		Name = "DIAMOND",
		Category = "DevProduct",
		Action = "InventoryItem",
		ItemType = "Card",
		ItemName = "DIAMOND",
		Amount = 1,
	},
	[3547220420] = { -- 10 spins
		Name = "10 Flow Spins",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "SpinFlow" },
		Amount = 10,
	},

	[3547220649] = { -- 30 spins
		Name = "30 Flow Spins",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "SpinFlow" },
		Amount = 30,
	},

	[3547220837] = { -- 50 spins
		Name = "50 Flow Spins",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "SpinFlow" },
		Amount = 50,
	},

	[3547265441] = {
		Name = "10 Style Spins",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "SpinStyle" },
		Amount = 10,
	}, -- 10 style
	[3547265566] = {
		Name = "30 Style Spins",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "SpinStyle" },
		Amount = 30,
	}, -- 30 style
	[3547265643] = {
		Name = "50 Style Spins",
		Category = "DevProduct",
		Action = "Currency",
		RewardPath = { "SpinStyle" },
		Amount = 50,
	},
	[3572465065] = {
		Name = "Flow Slot Unlock",
		Category = "DevProduct",
		Action = "UnlockSlot",
		SlotType = "Flow",
		Amount = 1,
	},
	[3572465977] = {
		Name = "Style Slot Unlock",
		Category = "DevProduct",
		Action = "UnlockSlot",
		SlotType = "Style",
		Amount = 1,
	},
}

local SlotProducts = {
	Flow = 3572465065,
	Style = 3572465977,
}

local ProductsData = {}

function ProductsData.GetProductInfo(id)
	return Products[id]
end

function ProductsData.GetSlotProductId(slotType)
	return SlotProducts[slotType]
end

return ProductsData
