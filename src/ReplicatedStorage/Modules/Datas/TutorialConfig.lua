local TutorialConfig = {}

function TutorialConfig.getStage(stageNumber: number)
	stageNumber = tonumber(stageNumber)

	if not stageNumber then
		warn("[TutorialConfig] Invalid stage number provided")
		return nil
	end

	local stage = TutorialConfig.Stages[stageNumber]

	if not stage then
		warn("[TutorialConfig] Stage", stageNumber, "not found")
		return nil
	end

	return stage
end

function TutorialConfig.getTotalStages(): number
	local count = 0
	for _ in pairs(TutorialConfig.Stages) do
		count += 1
	end
	return count
end

function TutorialConfig.stageExists(stageNumber: number): boolean
	return TutorialConfig.Stages[stageNumber] ~= nil
end

function TutorialConfig.getAllStages()
	return TutorialConfig.Stages
end

TutorialConfig.Stages = {
	[0] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🎉 Welcome!\nLet's learn fast.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.56, 0.1),
			TextSize = 18,
			TypeSpeed = 0.025
		},
		WaitForCondition = "Wait",
		ConditionValue = 1.8
	},

	[1] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "UI.GameHUD.BottomBarFR.JumpBT",
			Padding = 16,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "👆 Hold Jump or press SPACE.\nGet 200 Coins.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.62, 0.12),
			TextSize = 17
		},
		WaitForCondition = "CoinsReached",
		ConditionValue = 200
	},

	[2] = {
		Enabled = true,
		Spotlight = {
			Enabled = false
		},
		Trail = {
			Enabled = true,
			TargetType = "Position",
			TargetPath = {X = 7.019, Y = 15.953, Z = -561.882},
			Color = Color3.fromRGB(255, 222, 89)
		},
		Text = {
			Text = "➡️ Go to the shop.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.42, 0.08),
			TextSize = 17
		},
		WaitForCondition = "PositionReached",
		ConditionValue = {X = 7.019, Y = 15.953, Z = -561.882},
		ConditionRadius = 4
	},

	[3] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "DYNAMIC_FIRST_POGO",
			Padding = 10,
			Ratio = 0.9
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🛒 Buy a better pogo.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.48, 0.09),
			TextSize = 17
		},
		WaitForCondition = "PogoPurchase"
	},

	[4] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "GUI.VendorFrame.ExitButton",
			Padding = 8,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "✅ Close the shop.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.4, 0.08),
			TextSize = 17
		},
		WaitForCondition = "ShopClosed",
		ConditionValue = true
	},

	[5] = {
		Enabled = true,
		Spotlight = {
			Enabled = false
		},
		Trail = {
			Enabled = true,
			TargetType = "Position",
			TargetPath = {X = -92.349, Y = 19.409, Z = -575.141},
			Color = Color3.fromRGB(255, 255, 255)
		},
		Text = {
			Text = "🥚 Go to the Common Egg.\nBuy your first pet.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.6, 0.12),
			TextSize = 17
		},
		WaitForCondition = "EggPurchase",
		ConditionValue = "CommonEgg"
	},

	[6] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "UI.GameHUD.LeftBTFR.InventoryFrame",
			Padding = 14,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🎒 Open Inventory.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.46, 0.08),
			TextSize = 17
		},
		WaitForCondition = "ButtonClick",
		ConditionValue = "InventoryFrame"
	},

	[7] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "GUI.InventoryFrame.Selector.Content.Pets",
			Padding = 6,
			Ratio = 1,
			IsCircle = true
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🐾 Tap Pets.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.34, 0.08),
			TextSize = 17
		},
		WaitForCondition = "ButtonClick",
		ConditionValue = "Pets"
	},

	[8] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "DYNAMIC_FIRST_PET",
			Padding = 12,
			Ratio = 1,
			IsCircle = true
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🐾 Tap your pet.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.42, 0.08),
			TextSize = 17
		},
		WaitForCondition = "ConfirmationOpened",
		ConditionValue = true
	},

	[9] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "GUI.ConfirmationFrame.BottomContent.ConfirmButton.Btn",
			Padding = 8,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "✅ Confirm to equip.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.48, 0.08),
			TextSize = 17
		},
		WaitForCondition = "PetEquipped",
		ConditionValue = true
	},

	[10] = {
		Enabled = true,
		Spotlight = {
			Enabled = true,
			GuiPath = "GUI.InventoryFrame.ExitButton",
			Padding = 8,
			Ratio = 1,
			IsCircle = true
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "❌ Close Inventory.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.46, 0.08),
			TextSize = 17
		},
		WaitForCondition = "InventoryClosed",
		ConditionValue = true
	},

	[11] = {
		Enabled = true,
		Spotlight = {
			Enabled = false
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "⏱️ Jump Using Space Bar or Pogo button\n to get a perfect landing",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.62, 0.12),
			TextSize = 17
		},
		WaitForCondition = "PerfectLanding",
		ConditionValue = true
	},

	[12] = {
		Enabled = true,
		Spotlight = {
			Enabled = false
		},
		Trail = {
			Enabled = true,
			TargetType = "Position",
			TargetPath = {X = -399.627, Y = 181.8, Z = -275.599},
			Color = Color3.fromRGB(100, 255, 255)
		},
		Text = {
			Text = "☁️ Reach the first island.",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.5, 0.08),
			TextSize = 17
		},
		WaitForCondition = "PositionReached",
		ConditionValue = {X = -399.627, Y = 181.8, Z = -275.599},
		ConditionRadius = 20
	},

	[13] = {
		Enabled = true,
		Spotlight = {
			Enabled = false,
			Padding = 0,
			Ratio = 1
		},
		Trail = {
			Enabled = false
		},
		Text = {
			Text = "🎊 Tutorial done! Reach the final island for a prize!",
			Position = UDim2.fromScale(0.5, 0.25),
			Size = UDim2.fromScale(0.46, 0.1),
			TextSize = 18
		},
		WaitForCondition = "Wait",
		ConditionValue = 3
	},

	[14] = {
		Enabled = false
	}
}

return TutorialConfig