local PogoData = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local POGOS_FOLDER = ASSETS_FOLDER:WaitForChild("Pogos")

PogoData.POGOS = {
	------------------//WORLD 1 (Order 1-5)
	["Rustbucket"] = {
		Name = "Rustbucket",
		Power = 180,
		AirMobility = 30, 
		Price = 0,
		RequiredRebirths = 0,
		Order = 1,
		Rarity = "Common",
		CoinMultiplier = 1.0,
		Description = "Rusty, loud, and barely holding together."
	},
	["BasicPogo"] = {
		Name = "Basic Pogo",
		Power = 280,
		AirMobility = 35,
		Price = 200,
		RequiredRebirths = 0,
		Order = 2,
		Rarity = "Common",
		CoinMultiplier = 1.5,
		Description = "The reliable wooden pogo to start your journey."
	},
	["MeltingPopsicle"] = {
		Name = "Melting Popsicle",
		Power = 330, 
		AirMobility = 40,
		Price = 800,
		RequiredRebirths = 0,
		Order = 3,
		Rarity = "Uncommon",
		CoinMultiplier = 2.5,
		Description = "Cold look, messy landing. Drips with every jump."
	},
	["Bloodsucker"] = {
		Name = "Bloodsucker",
		Power = 420,
		AirMobility = 45,
		Price = 2500,
		RequiredRebirths = 1,
		Order = 4,
		Rarity = "Uncommon",
		CoinMultiplier = 4.0,
		Description = "A red menace that feeds off momentum."
	},
	["GrayGhost"] = {
		Name = "Gray Ghost",
		Power = 550, 
		AirMobility = 50,
		Price = 8000,
		RequiredRebirths = 2,
		Order = 5,
		Rarity = "Rare",
		CoinMultiplier = 6.5,
		Description = "Silent springs. You barely hear it coming."
	},

	------------------//WORLD 2 (Order 6-10)
	["AbyssBreather"] = {
		Name = "Abyss Breather",
		Power = 720, 
		AirMobility = 55,
		Price = 25000,
		RequiredRebirths = 3,
		Order = 6,
		Rarity = "Rare",
		CoinMultiplier = 10.0,
		Description = "Built for deep drops and darker skies."
	},
	["YellowPiercer"] = {
		Name = "Yellow Piercer",
		Power = 950, 
		AirMobility = 60,
		Price = 80000,
		RequiredRebirths = 4,
		Order = 7,
		Rarity = "Rare",
		CoinMultiplier = 15.0,
		Description = "Punches through air like a spear."
	},
	["Hellheart"] = {
		Name = "Hellheart",
		Power = 1250, 
		AirMobility = 65,
		Price = 250000,
		RequiredRebirths = 6,
		Order = 8,
		Rarity = "Epic",
		CoinMultiplier = 22.0,
		Description = "A burning core that refuses to cool down."
	},
	["TropicPop"] = {
		Name = "Tropic Pop",
		Power = 1650,
		AirMobility = 70,
		Price = 800000,
		RequiredRebirths = 8,
		Order = 9,
		Rarity = "Epic",
		CoinMultiplier = 32.0,
		Description = "Bright vibes, sharp bounce."
	},
	["TheEnforcer"] = {
		Name = "The Enforcer",
		Power = 2200, 
		AirMobility = 75,
		Price = 2500000,
		RequiredRebirths = 10,
		Order = 10,
		Rarity = "Epic",
		CoinMultiplier = 48.0,
		Description = "Heavy duty. No excuses."
	},

	------------------//WORLD 3 (Order 11-15)
	["SodaBomb"] = {
		Name = "Soda Bomb",
		Power = 2900,
		AirMobility = 80,
		Price = 8000000,
		RequiredRebirths = 12,
		Order = 11,
		Rarity = "Epic",
		CoinMultiplier = 70.0,
		Description = "Carbonated power that pops on impact."
	},
	["PressureTank"] = {
		Name = "Pressure Tank",
		Power = 3800, 
		AirMobility = 85,
		Price = 25000000,
		RequiredRebirths = 15,
		Order = 12,
		Rarity = "Epic",
		CoinMultiplier = 100.0,
		Description = "Overpressurized. Handle with care."
	},
	["SkyRipper"] = {
		Name = "Sky Ripper",
		Power = 5000, 
		AirMobility = 90,
		Price = 80000000,
		RequiredRebirths = 18,
		Order = 13,
		Rarity = "Legendary",
		CoinMultiplier = 150.0,
		Description = "Cuts open the sky with every launch."
	},
	["WoodTotem"] = {
		Name = "Wood Totem",
		Power = 6500, 
		AirMobility = 95,
		Price = 250000000,
		RequiredRebirths = 22,
		Order = 14,
		Rarity = "Legendary",
		CoinMultiplier = 220.0,
		Description = "Ancient wood, modern bounce."
	},
	["NeonArc"] = {
		Name = "Neon Arc",
		Power = 8500, 
		AirMobility = 100,
		Price = 800000000,
		RequiredRebirths = 26,
		Order = 15,
		Rarity = "Legendary",
		CoinMultiplier = 320.0,
		Description = "Neon lines trace every jump path."
	},

	------------------//WORLD 4 (Order 16-20)
	["StreetScrap"] = {
		Name = "Street Scrap",
		Power = 11000, 
		AirMobility = 105,
		Price = 2500000000,
		RequiredRebirths = 30,
		Order = 16,
		Rarity = "Legendary",
		CoinMultiplier = 500.0,
		Description = "Built from the street. Hits like a truck."
	},
	["PurpleMechling"] = {
		Name = "Purple Mechling",
		Power = 14500, 
		AirMobility = 110,
		Price = 8000000000,
		RequiredRebirths = 35,
		Order = 17,
		Rarity = "Legendary",
		CoinMultiplier = 800.0,
		Description = "A compact mech core with purple glow."
	},
	["GuidingStar"] = {
		Name = "Guiding Star",
		Power = 19000, 
		AirMobility = 115,
		Price = 25000000000,
		RequiredRebirths = 40,
		Order = 18,
		Rarity = "Legendary",
		CoinMultiplier = 1200.0,
		Description = "Follow the star, stick the landing."
	},
	["TurboAngel"] = {
		Name = "Turbo Angel",
		Power = 25000, 
		AirMobility = 120,
		Price = 80000000000,
		RequiredRebirths = 45,
		Order = 19,
		Rarity = "Legendary",
		CoinMultiplier = 1800.0,
		Description = "Wings out. Throttle up."
	},
	["BubbleRing"] = {
		Name = "Bubble Ring",
		Power = 33000, 
		AirMobility = 125,
		Price = 250000000000,
		RequiredRebirths = 50,
		Order = 20,
		Rarity = "Legendary",
		CoinMultiplier = 2800.0,
		Description = "A smooth ring that keeps you floating."
	},

	------------------//WORLD 5 (Order 21-25)
	["FutureBeetle"] = {
		Name = "Future Beetle",
		Power = 43000, 
		AirMobility = 130,
		Price = 800000000000,
		RequiredRebirths = 55,
		Order = 21,
		Rarity = "Legendary",
		CoinMultiplier = 4200.0,
		Description = "A futuristic shell with relentless rebound."
	},
	["PurpleCyclops"] = {
		Name = "Purple Cyclops",
		Power = 56000,
		AirMobility = 135,
		Price = 2500000000000,
		RequiredRebirths = 60,
		Order = 22,
		Rarity = "Legendary",
		CoinMultiplier = 6500.0,
		Description = "One eye. One mission. Perfect jumps."
	},
	["FloatingPlanet"] = {
		Name = "Floating Planet",
		Power = 73000, 
		AirMobility = 140,
		Price = 8000000000000,
		RequiredRebirths = 65,
		Order = 23,
		Rarity = "Legendary",
		CoinMultiplier = 10000.0,
		Description = "A planet-sized bounce packed into one pogo."
	},
	["PoisonVine"] = {
		Name = "Poison Vine",
		Power = 95000, 
		AirMobility = 145,
		Price = 25000000000000,
		RequiredRebirths = 70,
		Order = 24,
		Rarity = "Legendary",
		CoinMultiplier = 16000.0,
		Description = "Toxic growth, unstoppable spring."
	},
	["GoldenGleam"] = {
		Name = "Golden Gleam",
		Power = 125000, 
		AirMobility = 150,
		Price = 75000000000000,
		RequiredRebirths = 75,
		Order = 25,
		Rarity = "Legendary", -- Se desejar, você pode mudar esta para "Secret" ou "Mythic"
		CoinMultiplier = 25000.0,
		Description = "Pure gold brilliance with god-tier bounce."
	},
}

------------------//FUNCTIONS
function PogoData.GetSortedList()
	local list = {}
	for id, data in pairs(PogoData.POGOS) do
		local entry = table.clone(data)
		entry.Id = id
		table.insert(list, entry)
	end

	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)

	return list
end

function PogoData.GetPogoViewport(pogoName)
	local pogoData = PogoData.POGOS[pogoName]
	local model = POGOS_FOLDER:FindFirstChild(pogoName)

	if not pogoData or not model then
		warn("Pogo ou Modelo não encontrado para: " .. tostring(pogoName))
		return nil
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Name = "PogoView_" .. pogoName

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local modelClone = model:Clone()
	modelClone.Parent = worldModel

	local cf, size = modelClone:GetBoundingBox()

	local maxDimension = math.max(size.X, size.Y, size.Z)
	local safetyMargin = 1
	local viewAngle = math.rad(70)

	local fov = camera.FieldOfView
	local fitDistance = (maxDimension / 2) / math.tan(math.rad(fov / 2))
	local finalDistance = (size.Z / 2) + (fitDistance * safetyMargin)

	local rotatedDirection = (cf * CFrame.Angles(0, viewAngle, 0)).LookVector
	local cameraPosition = cf.Position + (rotatedDirection * finalDistance)

	cameraPosition += Vector3.new(0, size.Y * 0.1, 0)

	camera.CFrame = CFrame.lookAt(cameraPosition, cf.Position)

	return viewport
end

function PogoData.Get(id: string)
	return PogoData.POGOS[id] or PogoData.POGOS["Rustbucket"]
end

return PogoData
