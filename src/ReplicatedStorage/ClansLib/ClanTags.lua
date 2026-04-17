local module = {}

module.Tags = {
	Default = {
		Color = Color3.fromRGB(255, 255, 255),
		Price = 0,
		Index = 1,
	},

	-- 💸 Cheap Tier
	["Mist Gray"] = {
		Color = Color3.fromRGB(200, 200, 200),
		Price = 7500,
		Index = 2,
	},
	["Soft Sky"] = {
		Color = Color3.fromRGB(173, 216, 230),
		Price = 8500,
		Index = 3,
	},
	["Pale Rose"] = {
		Color = Color3.fromRGB(255, 192, 203),
		Price = 9500,
		Index = 4,
	},
	["Faint Mint"] = {
		Color = Color3.fromRGB(180, 255, 210),
		Price = 10500,
		Index = 5,
	},
	["Dust Lavender"] = {
		Color = Color3.fromRGB(200, 180, 255),
		Price = 12000,
		Index = 6,
	},
	["Snowdrift"] = {
		Color = Color3.fromRGB(240, 248, 255),
		Price = 13000,
		Index = 7,
	},
	["Washed Coral"] = {
		Color = Color3.fromRGB(255, 160, 160),
		Price = 14500,
		Index = 8,
	},

	-- 💎 Mid Tier
	["Crimson Blade"] = {
		Color = Color3.fromRGB(220, 20, 60),
		Price = 16000,
		Index = 9,
	},
	["Celestial Blue"] = {
		Color = Color3.fromRGB(100, 149, 237),
		Price = 17000,
		Index = 10,
	},
	["Arcane Green"] = {
		Color = Color3.fromRGB(34, 139, 34),
		Price = 18500,
		Index = 11,
	},
	["Sunset Flame"] = {
		Color = Color3.fromRGB(255, 99, 71),
		Price = 20000,
		Index = 12,
	},
	["Violet Storm"] = {
		Color = Color3.fromRGB(148, 0, 211),
		Price = 21500,
		Index = 13,
	},
	["Ocean Depths"] = {
		Color = Color3.fromRGB(0, 105, 148),
		Price = 22500,
		Index = 14,
	},
	["Radiant Lime"] = {
		Color = Color3.fromRGB(191, 255, 0),
		Price = 24000,
		Index = 15,
	},

	-- 🔥 High Tier (soft gradients)
	["Flare Ember"] = {
		Color = {
			Color3.fromRGB(255, 120, 120),
			Color3.fromRGB(255, 180, 140),
			Color3.fromRGB(255, 120, 120),
		},
		Price = 26000,
		Index = 16,
	},
	["Toxic Pulse"] = {
		Color = {
			Color3.fromRGB(100, 255, 100),
			Color3.fromRGB(200, 255, 100),
			Color3.fromRGB(100, 255, 100),
		},
		Price = 28000,
		Index = 17,
	},
	["Royal Veil"] = {
		Color = {
			Color3.fromRGB(180, 140, 255),
			Color3.fromRGB(230, 190, 255),
			Color3.fromRGB(180, 140, 255),
		},
		Price = 32000,
		Index = 18,
	},
	["Draconite Core"] = {
		Color = {
			Color3.fromRGB(80, 255, 255),
			Color3.fromRGB(130, 200, 255),
			Color3.fromRGB(80, 255, 255),
		},
		Price = 40000,
		Index = 19,
	},
	["Searing Void"] = {
		Color = {
			Color3.fromRGB(255, 90, 90),
			Color3.fromRGB(180, 0, 120),
			Color3.fromRGB(255, 90, 90),
		},
		Price = 50000,
		Index = 20,
	},

	-- 🌈 Ultra Tier (100k+ full gradients)
	["Blood Red"] = {
		Color = {
			Color3.fromRGB(246, 26, 28),
			Color3.fromRGB(146, 37, 32),
			Color3.fromRGB(246, 3, 0),
		},
		Price = 100000,
		Index = 21,
	},
	["Sovereign Gold"] = {
		Color = {
			Color3.fromRGB(255, 173, 21),
			Color3.fromRGB(246, 225, 61),
			Color3.fromRGB(255, 173, 21),
		},
		Price = 200000,
		Index = 22,
	},
	["Shadow Monarch"] = {
		Color = {
			Color3.fromRGB(80, 0, 120),
			Color3.fromRGB(140, 0, 255),
			Color3.fromRGB(60, 0, 90),
		},
		Price = 300000,
		Index = 23,
	},
	["Celestial Radiance"] = {
		Color = {
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(255, 255, 160),
			Color3.fromRGB(255, 255, 255),
		},
		Price = 350000,
		Index = 24,
	},
	["Infinite Night"] = {
		Color = {
			Color3.fromRGB(89, 27, 179),
			Color3.fromRGB(229, 8, 228),
			Color3.fromRGB(89, 27, 179),
		},
		Price = 500000,
		Index = 25,
	},
	['Stormbreaker'] = {
		Color = {
			Color3.fromRGB(254, 255, 12),
			Color3.fromRGB(255, 185, 0),
			Color3.fromRGB(254, 255, 12)
		},
		Price = 750000,
		Index = 26
	},
	Dusk = {
		Color = {
			Color3.fromRGB(79, 73, 255),
			Color3.fromRGB(114, 0, 255),
			Color3.fromRGB(79, 73, 255),
		},
		Price = 750000,
		Index = 27,
	},
	Imperial = {
		Color = {
			Color3.fromRGB(145, 27, 18),
			Color3.fromRGB(74, 0, 2),
			Color3.fromRGB(145, 27, 18),
		},
		Price = 800000,
		Index = 28
	},
	['Cherry Blossom'] = {
		Color = {
			Color3.fromRGB(247, 177, 255),
			Color3.fromRGB(255,255,255),
			Color3.fromRGB(247, 177, 255)
		},
		Price = 900000,
		Index = 29
	},
	Aurora = {
		Color = {
			Color3.fromRGB(194, 150, 255),
			Color3.fromRGB(247, 167, 250),
			Color3.fromRGB(194, 150, 255),
		},
		Price = 1000000,
		Index = 30
	},
}

function module.Color3Tohex(color3)
	local r = math.floor(color3.R * 255)
	local g = math.floor(color3.G * 255)
	local b = math.floor(color3.B * 255)
	return string.format("#%02X%02X%02X", r, g, b)
end

function module.ApplyTag(TextLabel: TextLabel, color, BG)
	if not TextLabel:FindFirstChild('UIGradient') then
		local UIGradient = script.UIGradient:Clone()
		UIGradient.Parent = TextLabel
	end

	local UIGradient = TextLabel.UIGradient

	local tagColor = module.Tags[color].Color
	if typeof(tagColor) ~= 'table' then
		if not BG then
			TextLabel.TextColor3 = tagColor
		else
			TextLabel.BackgroundColor3 = tagColor
		end
		UIGradient.Color = script.UIGradient.Color
	else
		local gradient = module.generateColorSequence(tagColor)
		if not BG then
			TextLabel.TextColor3 = Color3.fromRGB(255,255,255)
		else
			TextLabel.BackgroundColor3 = Color3.fromRGB(255,255,255)
		end
		UIGradient.Color = gradient
	end
end

function module.generateColorSequence(tagColor)
	local keypoints = {}
	local count = #tagColor
	for i, color in ipairs(tagColor) do
		local position = (i - 1) / (count - 1)
		table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
	end
	return ColorSequence.new(keypoints)
end

return module