local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClanTags = require(ReplicatedStorage.ClansLib.ClanTags)
local module = {}

module.Shop = {
	Tags = {
		Content = {}, -- This gets automatically filled
		Index = 1
	},
	-- Auras = {
	-- 	Content = {},
	-- 	Index = 2
	-- },
	Towers = {
		Content = {
			[1] = {
				Name = 'Ninth Sister',
				Description = "An exclusive unit that gets distributed to all members!",
				Price = 5000000
			},
			[2] = {
				Name = '[SHINY] Ninth Sister',
				Description = "An exclusive shiny unit that gets distributed to all members!",
				Price = 15000000
			}
		},
		Index = 2
	},
	Currencies = {
		Content = {
			[1] = {
				Name = '5 Willpower',
				BackendName = 'TraitPoint',
				Amount = 5,
				Description = 'Purchase willpower for all your clan members!',
				Image = 'rbxassetid://122847918518753',
				Price = 25000
			},
			[2] = {
				Name = '5 Lucky Summons',
				BackendName = 'LuckySpins',
				Amount = 5,
				Description = 'Purchase lucky summons for all your clan members!',
				Image = 'rbxassetid://98492072936946',
				Price = 50000,
			},
			
		},
		Index = 3
	},
	Items = {
		Content = {
			[1] = {
				Name = '2x Coins(1 hour)',
				BackendName = '2x Coins',
				Description = 'Purchase this boost for all your clan members!',
				Image = 'rbxassetid://111778592400235',
				Price = 25000
			},
			[2] = {
				Name = '2x Gems(1 hour)',
				BackendName = '2x Gems',
				Description = 'Purchase this boost for all your clan members!',
				Image = 'rbxassetid://111778592400235',
				Price = 25000
			}
		},
		
		Index = 4
	},
	Misc = {
		Content = {
			[1] = {
				Name = '+1 Clan Slot Upgrade',
				Description = 'Increases the cap for the maximum amount of members this clan can hold!',
				Image = 'rbxassetid://111778592400235',
				DynamicPrice = true
			}
		},
		Index = 5
	},
}

local function getKeyByIndex(tbl, index)
	for key, val in tbl do
		if val.Index == index then
			return key, val
		end
	end
end

-- Fill Tags.Shop.Content in order
local totalCount = 0
for _, _ in ClanTags.Tags do
	totalCount += 1
end

for i = 1, totalCount do
	local key, tagData = getKeyByIndex(ClanTags.Tags, i)
	if key and tagData then
		module.Shop.Tags.Content[i] = {
			Name = key,
			Description = `Unlocks the '{key}' tag for your clan.`,
			Type = "Tag",
			Price = tagData.Price
		}
	end
end

return module
