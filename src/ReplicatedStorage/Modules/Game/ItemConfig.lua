local ItemInfo = {
	Navy = {Description = "none", Rarity = "Epic", Model = "Navy"},
	Emote1 = {Description = "none", Rarity = "Epic", AnimationId = "rbxassetid://104313875695792"},
	Red = {Description = "none", Rarity = "Epic", ImageId = "Red"}
}

local GachaPools = {
	Cosmetics = {
		Cost = 100,
		Items = {
			{Name = "Navy", Weight = 10},
		}
	},
	Emotes = {
		Cost = 500,
		Items = {
			{Name = "Emote1", Weight = 10},
		}
	},
	Player = {
		Cost = 250,
		Items = {
			{Name = "Red", Weight = 10},
		}
	}
}

return {
	ItemInfo = ItemInfo,
	GachaPools = GachaPools
}