local WorldConfig = {}

local BASE_GRAVITY = 196.2

WorldConfig.WORLDS = {
	{
		id = 1,
		name = "Earth",
		theme = "Plains",
		gravityMult = 1.5,
		imageId = "rbxassetid://94833519222236",
		entryCFrame = CFrame.new(-28.017, 20.406, -499.372),
		requiredPogoPower = 0,
		requiredRebirths = 0,
		layers = {
			{ name = "Normal Floor", imageId = "rbxassetid://79746642157428", coinMultiplier = 1.0, minBreakForce = 0, color = Color3.fromRGB(106, 189, 94), maxHeight = 415, minHeight = 0, entryCFrame = CFrame.new(-28.017, 20.406, -499.372) },
			{ name = "Hill", imageId = "rbxassetid://134574577761617", coinMultiplier = 1.5, minBreakForce = 200, color = Color3.fromRGB(129, 98, 62), maxHeight = 928, minHeight = 415, entryCFrame = CFrame.new(-28.017, 168, -499.37-2) },
			{ name = "Rocky Part", imageId = "rbxassetid://136787290990200", coinMultiplier = 2.5, minBreakForce = 350, color = Color3.fromRGB(163, 162, 165), maxHeight = 1587, minHeight = 928, entryCFrame = CFrame.new(-28.017, 336, -499.372) },
			{ name = "Peak of Mountain", imageId = "rbxassetid://94833519222236", coinMultiplier = 4.0, minBreakForce = 500, color = Color3.fromRGB(27, 42, 53), maxHeight = 99999, minHeight = 1587, entryCFrame = CFrame.new(-28.017, 660, -499.372) },
			{ name = "Peak of Mountain", imageId = "rbxassetid://79746642157428", coinMultiplier = 4.0, minBreakForce = 500, color = Color3.fromRGB(27, 42, 53), maxHeight = 99999, minHeight = 1587, entryCFrame = CFrame.new(-28.017, 1320, -499.372) },
		}
	},
	{
		id = 2,
		name = "Clouds",
		theme = "Sky",
		gravityMult = 3.0,
		imageId = "rbxassetid://122436689987233",
		entryCFrame = CFrame.new(98095.406, 60, -212.693),
		requiredPogoPower = 700, 
		requiredRebirths = 3,
		layers = {
			{ name = "Cloud", imageId = "rbxassetid://122436689987233", coinMultiplier = 10.0, minBreakForce = 700, color = Color3.fromRGB(255, 255, 255), maxHeight = 1000, minHeight = 20, entryCFrame = CFrame.new(98095.406, 60, -212.693)},
			{ name = "Pale Clouds", imageId = "rbxassetid://83871679218486", coinMultiplier = 18.0, minBreakForce = 1000, color = Color3.fromRGB(205, 240, 255), maxHeight = 20, minHeight = -30, entryCFrame = CFrame.new(98095.406, 470, -212.693) },
			{ name = "Storm Clouds", imageId = "rbxassetid://72823771404502", coinMultiplier = 28.0, minBreakForce = 1500, color = Color3.fromRGB(159, 218, 255), maxHeight = -30, minHeight = -100, entryCFrame = CFrame.new(98095.406, 1460, -212.693) },
			{ name = "Gem Clouds", imageId = "rbxassetid://105982978053020", coinMultiplier = 40.0, minBreakForce = 2000, color = Color3.fromRGB(46, 204, 255), maxHeight = -100, minHeight = -99999, entryCFrame = CFrame.new(98095.406, 2100, -212.693) },
		}
	},
	{
		id = 3,
		name = "Near Space",
		theme = "Space",
		gravityMult = 6.0,
		imageId = "rbxassetid://79746642157428",
		entryCFrame = CFrame.new(350280.125, 62.421, 1545.258),
		requiredPogoPower = 2800,
		requiredRebirths = 12,
		layers = {
			{ name = "Space Station", imageId = "rbxassetid://93020804573131", coinMultiplier = 65.0, minBreakForce = 2800, color = Color3.fromRGB(230, 230, 230), maxHeight = 1000, minHeight = 40, entryCFrame = CFrame.new(350280.125, 78.421, 1545.258) },
			{ name = "Moon Asteroid", imageId = "rbxassetid://136444958670930", coinMultiplier = 110.0, minBreakForce = 4000, color = Color3.fromRGB(159, 218, 255), maxHeight = 40, minHeight = 0, entryCFrame = CFrame.new(350280.125, 240, 1545.258) },
			{ name = "Red Stone", imageId = "rbxassetid://93020804573131", coinMultiplier = 180.0, minBreakForce = 5500, color = Color3.fromRGB(60, 60, 60), maxHeight = 0, minHeight = -99999, entryCFrame = CFrame.new(350280.125, 915, 1545.258) },
			{ name = "Red Stone", imageId = "rbxassetid://79746642157428", coinMultiplier = 260.0, minBreakForce = 7500, color = Color3.fromRGB(60, 60, 60), maxHeight = 0, minHeight = -99999, entryCFrame = CFrame.new(350280.125, 1830, 1545.258) },
		}
	},
	{
		id = 4,
		name = "Alien Planet",
		theme = "Alien",
		gravityMult = 12.0,
		imageId = "rbxassetid://91975920440524",
		entryCFrame = CFrame.new(-119376.766, 7.532, -51.993),
		requiredPogoPower = 10000,
		requiredRebirths = 30,
		layers = {
			{ name = "Biocrust Clouds", imageId = "rbxassetid://91975920440524", coinMultiplier = 400.0, minBreakForce = 10000, color = Color3.fromRGB(106, 189, 94), maxHeight = 1000, minHeight = 0, entryCFrame = CFrame.new(-119376.766, 17.532, -51.993) },
			{ name = "Crystal Stone", imageId = "rbxassetid://91421068423926", coinMultiplier = 800.0, minBreakForce = 15000, color = Color3.fromRGB(86, 66, 54), maxHeight = 0, minHeight = -50, entryCFrame = CFrame.new(-119376.766, 360, -51.993) },
			{ name = "Volcanic Rock", imageId = "rbxassetid://131560876384490", coinMultiplier = 1400.0, minBreakForce = 22000, color = Color3.fromRGB(105, 64, 40), maxHeight = -50, minHeight = -120, entryCFrame = CFrame.new(-119376.766, 917, -51.993) },
			{ name = "Ancient Ruins", imageId = "rbxassetid://98991031183673", coinMultiplier = 2500.0, minBreakForce = 30000, color = Color3.fromRGB(239, 184, 56), maxHeight = -120, minHeight = -99999, entryCFrame = CFrame.new(-119376.766, 1300, -51.993) },
		}
	},
	{
		id = 5,
		name = "Starforge",
		theme = "Space",
		gravityMult = 24.0,
		imageId = "rbxassetid://70682584492943",
		entryCFrame = CFrame.new(-224830.047, 37.364, 78.576),
		requiredPogoPower = 40000,
		requiredRebirths = 55,
		layers = {
			{ name = "Stars", imageId = "rbxassetid://70682584492943", coinMultiplier = 4000.0, minBreakForce = 40000, color = Color3.fromRGB(30, 30, 35), maxHeight = 1000, minHeight = 20, entryCFrame = CFrame.new(-224830.047, 37.364, 78.576) },
			{ name = "Digital Grid Floor", imageId = "rbxassetid://90349159597337", coinMultiplier = 8000.0, minBreakForce = 60000, color = Color3.fromRGB(255, 100, 0), maxHeight = 20, minHeight = -40, entryCFrame = CFrame.new(-224830.047, 367, 78.576) },
			{ name = "Void Crystal", imageId = "rbxassetid://91421068423926", coinMultiplier = 14000.0, minBreakForce = 85000, color = Color3.fromRGB(255, 50, 0), maxHeight = -40, minHeight = -100, entryCFrame = CFrame.new(-224830.047, 750, 78.576) },
			{ name = "Galaxy", imageId = "rbxassetid://116577259979356", coinMultiplier = 22000.0, minBreakForce = 110000, color = Color3.fromRGB(10, 10, 10), maxHeight = -100, minHeight = -99999, entryCFrame = CFrame.new(-224830.047, 1500, 78.576) },
		}
	},
}

function WorldConfig.GetWorld(id: number)
	for _, w in WorldConfig.WORLDS do
		if w.id == id then return w end
	end
	return WorldConfig.WORLDS[1]
end

function WorldConfig.GetNextWorld(currentId: number)
	return WorldConfig.GetWorld(currentId + 1)
end

return WorldConfig
