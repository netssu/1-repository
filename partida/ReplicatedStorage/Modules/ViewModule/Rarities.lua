local DARKEN_MULTIPLIER = 0.7

local function rarityColor(r, g, b)
	return Color3.new(r * DARKEN_MULTIPLIER, g * DARKEN_MULTIPLIER, b * DARKEN_MULTIPLIER)
end

return {
	Common = {
		Value = 25;
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor(0.258824, 0.258824, 0.258824));
			ColorSequenceKeypoint.new(0.161, rarityColor(0.705882, 0.705882, 0.705882));
			ColorSequenceKeypoint.new(1, rarityColor(1, 1, 1));
		});
		Image = "rbxassetid://14594028951";
	},
	Rare = {
		Value = 25;
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor(0, 0.34902, 1));
			ColorSequenceKeypoint.new(1, rarityColor(0.0823529, 0.678431, 1));
		});
		Image = "rbxassetid://14594028951";
	},
	Epic = {
		Value = 19;
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor(0.333333, 0, 1));
			ColorSequenceKeypoint.new(0.42, rarityColor(0.364706, 0.00392157, 0.992157));
			ColorSequenceKeypoint.new(1, rarityColor(0.560784, 0.0235294, 0.933333));
		});
		Image = "rbxassetid://14594028727";
	},
	Legendary = {
		Value = 5.5;
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor(1, 0.666667, 0));
			ColorSequenceKeypoint.new(.5, rarityColor(1, 0.682353, 0));
			ColorSequenceKeypoint.new(1, rarityColor(1, 0.94902, 0.227451));
		});
		Image = "rbxassetid://14594028523";
	},
	Exclusive = {
		Value = .5;
		Rotation = 45,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor(0.541176, 0.313725, 1));
			ColorSequenceKeypoint.new(1, rarityColor(0.266667, 1, 0.913725));
		});
		Image = "rbxassetid://14594028268";
	},
	Secret = {
		Value = .5;
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor(1, 0, 0));
			ColorSequenceKeypoint.new(1, rarityColor(1, 0.168627, 0.168627));
		});
		Image = "rbxassetid://14594028268";
	},
	Mythical = {
		Value = .5;
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarityColor(1, 0.2, 0.823529));
			ColorSequenceKeypoint.new(0.1, rarityColor(1, 0.2, 0.533333));
			ColorSequenceKeypoint.new(0.2, rarityColor(1, 0.2, 0.247059));
			ColorSequenceKeypoint.new(0.3, rarityColor(1, 0.443137, 0.2));
			ColorSequenceKeypoint.new(0.4, rarityColor(1, 0.729412, 0.2));
			ColorSequenceKeypoint.new(0.5, rarityColor(0.980392, 1, 0.2));
			ColorSequenceKeypoint.new(0.6, rarityColor(0.694118, 1, 0.2));
			ColorSequenceKeypoint.new(0.7, rarityColor(0.407843, 1, 0.2));
			ColorSequenceKeypoint.new(0.8, rarityColor(0.2, 1, 0.282353));
			ColorSequenceKeypoint.new(0.9, rarityColor(0.2, 1, 0.568627));
			ColorSequenceKeypoint.new(1, rarityColor(0.2, 1, 0.858824));
		});
		Image = "rbxassetid://14594028268";
	}
}
