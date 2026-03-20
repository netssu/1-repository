------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local PETS_FOLDER = ASSETS_FOLDER:WaitForChild("Pets")

------------------//VARIABLES
export type PetData = {
	MeshPart: MeshPart?,
	DisplayName: string,
	Raritys: string,
	Weight: number,
	Multiplier: number,
	IsFlying: boolean,
	World: number
}

local PetsConfig: {[string]: PetData} = {

	-- ==========================================
	-- WORLD 1: COMMON EGG (Multipliers: 1.0 a 1.5)
	-- ==========================================
	["Doggy"] = { MeshPart = PETS_FOLDER:FindFirstChild("Doggy"), DisplayName = "Doggy", Weight = 38, World = 1, IsFlying = false, Raritys = "Common", Multiplier = 1.00 },
	["Kitty"] = { MeshPart = PETS_FOLDER:FindFirstChild("Kitty"), DisplayName = "Kitty", Weight = 38, World = 1, IsFlying = false, Raritys = "Common", Multiplier = 1.02 },
	["Bunny"] = { MeshPart = PETS_FOLDER:FindFirstChild("Bunny"), DisplayName = "Bunny", Weight = 20, World = 1, IsFlying = false, Raritys = "Rare", Multiplier = 1.08 },
	["Dragon"] = { MeshPart = PETS_FOLDER:FindFirstChild("Dragon"), DisplayName = "Dragon", Weight = 4, World = 1, IsFlying = false, Raritys = "Legendary", Multiplier = 1.20 },

	["Golden Doggy"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Doggy"), DisplayName = "Golden Doggy", Weight = 38, World = 1, IsFlying = false, Raritys = "Common", Multiplier = 1.25 },
	["Golden Kitty"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Kitty"), DisplayName = "Golden Kitty", Weight = 38, World = 1, IsFlying = false, Raritys = "Common", Multiplier = 1.28 },
	["Golden Bunny"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Bunny"), DisplayName = "Golden Bunny", Weight = 20, World = 1, IsFlying = false, Raritys = "Rare", Multiplier = 1.35 },
	["Golden Dragon"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Dragon"), DisplayName = "Golden Dragon", Weight = 4, World = 1, IsFlying = true, Raritys = "Legendary", Multiplier = 1.50 },

	-- ==========================================
	-- WORLD 1: AQUA EGG (Multipliers: 1.1 a 1.85)
	-- ==========================================
	["Fish"] = { MeshPart = PETS_FOLDER:FindFirstChild("Orange Fish"), DisplayName = "Fish", Weight = 40, World = 1, IsFlying = true, Raritys = "Common", Multiplier = 1.10 },
	["Shark"] = { MeshPart = PETS_FOLDER:FindFirstChild("Shark"), DisplayName = "Shark", Weight = 36, World = 1, IsFlying = true, Raritys = "Uncommon", Multiplier = 1.15 },
	["Turtle"] = { MeshPart = PETS_FOLDER:FindFirstChild("Turtle"), DisplayName = "Turtle", Weight = 14, World = 1, IsFlying = false, Raritys = "Rare", Multiplier = 1.25 },
	["Axolotl"] = { MeshPart = PETS_FOLDER:FindFirstChild("Axolotl"), DisplayName = "Axolotl", Weight = 10, World = 1, IsFlying = false, Raritys = "Epic", Multiplier = 1.45 },

	["Golden Fish"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Orange Fish"), DisplayName = "Golden Fish", Weight = 40, World = 1, IsFlying = true, Raritys = "Common", Multiplier = 1.38 },
	["Golden Shark"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Shark"), DisplayName = "Golden Shark", Weight = 36, World = 1, IsFlying = true, Raritys = "Uncommon", Multiplier = 1.44 },
	["Golden Turtle"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Turtle"), DisplayName = "Golden Turtle", Weight = 14, World = 1, IsFlying = false, Raritys = "Rare", Multiplier = 1.58 },
	["Golden Axolotl"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Axolotl"), DisplayName = "Golden Axolotl", Weight = 10, World = 1, IsFlying = false, Raritys = "Epic", Multiplier = 1.85 },

	-- ==========================================
	-- WORLD 2: FROST EGG (Multipliers: 1.35 a 2.75)
	-- ==========================================
	["Penguin"] = { MeshPart = PETS_FOLDER:FindFirstChild("Penguin"), DisplayName = "Penguin", Weight = 50, World = 2, IsFlying = false, Raritys = "Common", Multiplier = 1.35 },
	["Walrus"] = { MeshPart = PETS_FOLDER:FindFirstChild("Walrus"), DisplayName = "Walrus", Weight = 25, World = 2, IsFlying = false, Raritys = "Uncommon", Multiplier = 1.50 },
	["Snow Ram"] = { MeshPart = PETS_FOLDER:FindFirstChild("Snow Ram"), DisplayName = "Snow Ram", Weight = 18, World = 2, IsFlying = false, Raritys = "Rare", Multiplier = 1.70 },
	["Yeti"] = { MeshPart = PETS_FOLDER:FindFirstChild("Yeti"), DisplayName = "Yeti", Weight = 7, World = 2, IsFlying = false, Raritys = "Legendary", Multiplier = 2.15 },

	["Golden Penguin"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Penguin"), DisplayName = "Golden Penguin", Weight = 50, World = 2, IsFlying = false, Raritys = "Common", Multiplier = 1.70 },
	["Golden Walrus"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Walrus"), DisplayName = "Golden Walrus", Weight = 25, World = 2, IsFlying = false, Raritys = "Uncommon", Multiplier = 1.90 },
	["Golden Snow Ram"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Snow Ram"), DisplayName = "Golden Snow Ram", Weight = 18, World = 2, IsFlying = false, Raritys = "Rare", Multiplier = 2.15 },
	["Golden Yeti"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Yeti"), DisplayName = "Golden Yeti", Weight = 7, World = 2, IsFlying = false, Raritys = "Legendary", Multiplier = 2.75 },

	-- ==========================================
	-- WORLD 3: CHRISTMAS EGG (Multipliers: 1.90 a 4.10)
	-- ==========================================
	["Santa Hat Seal"] = { MeshPart = PETS_FOLDER:FindFirstChild("Santa Hat Seal"), DisplayName = "Santa Hat Seal", Weight = 35, World = 3, IsFlying = false, Raritys = "Uncommon", Multiplier = 1.90 },
	["Santa Hat Polar Bear"] = { MeshPart = PETS_FOLDER:FindFirstChild("Santa Hat Polar Bear"), DisplayName = "Santa Hat Polar Bear", Weight = 30, World = 3, IsFlying = false, Raritys = "Rare", Multiplier = 2.15 },
	["Rudolph"] = { MeshPart = PETS_FOLDER:FindFirstChild("Rudolph"), DisplayName = "Rudolph", Weight = 20, World = 3, IsFlying = false, Raritys = "Epic", Multiplier = 2.50 },
	["Santa Paws"] = { MeshPart = PETS_FOLDER:FindFirstChild("Santa Paws"), DisplayName = "Santa Paws", Weight = 15, World = 3, IsFlying = false, Raritys = "Legendary", Multiplier = 3.20 },

	["Golden Santa Hat Seal"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Santa Hat Seal"), DisplayName = "Golden Santa Hat Seal", Weight = 35, World = 3, IsFlying = false, Raritys = "Uncommon", Multiplier = 2.40 },
	["Golden Santa Hat Polar Bear"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Santa Hat Polar Bear"), DisplayName = "Golden Santa Hat Polar Bear", Weight = 30, World = 3, IsFlying = false, Raritys = "Rare", Multiplier = 2.70 },
	["Golden Rudolph"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Rudolph"), DisplayName = "Golden Rudolph", Weight = 20, World = 3, IsFlying = false, Raritys = "Epic", Multiplier = 3.15 },
	["Golden Santa Paws"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Santa Paws"), DisplayName = "Golden Santa Paws", Weight = 15, World = 3, IsFlying = false, Raritys = "Legendary", Multiplier = 4.10 },

	-- ==========================================
	-- WORLD 4: JUNGLE EGG (Multipliers: 2.80 a 6.20)
	-- ==========================================
	["Parrot"] = { MeshPart = PETS_FOLDER:FindFirstChild("Parrot"), DisplayName = "Parrot", Weight = 50, World = 4, IsFlying = false, Raritys = "Common", Multiplier = 2.80 },
	["Monkey"] = { MeshPart = PETS_FOLDER:FindFirstChild("Monkey"), DisplayName = "Monkey", Weight = 25, World = 4, IsFlying = false, Raritys = "Uncommon", Multiplier = 3.20 },
	["Tiger"] = { MeshPart = PETS_FOLDER:FindFirstChild("Tiger"), DisplayName = "Tiger", Weight = 19, World = 4, IsFlying = false, Raritys = "Rare", Multiplier = 3.80 },
	["Crocodile"] = { MeshPart = PETS_FOLDER:FindFirstChild("Crocodile"), DisplayName = "Crocodile", Weight = 6, World = 4, IsFlying = false, Raritys = "Legendary", Multiplier = 4.80 },

	["Golden Parrot"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Parrot"), DisplayName = "Golden Parrot", Weight = 50, World = 4, IsFlying = true, Raritys = "Common", Multiplier = 3.50 },
	["Golden Monkey"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Monkey"), DisplayName = "Golden Monkey", Weight = 25, World = 4, IsFlying = false, Raritys = "Uncommon", Multiplier = 4.00 },
	["Golden Tiger"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Tiger"), DisplayName = "Golden Tiger", Weight = 19, World = 4, IsFlying = false, Raritys = "Rare", Multiplier = 4.80 },
	["Golden Crocodile"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Crocodile"), DisplayName = "Golden Crocodile", Weight = 6, World = 4, IsFlying = false, Raritys = "Legendary", Multiplier = 6.20 },

	-- ==========================================
	-- WORLD 5: CUPCAKE EGG (Multipliers: 4.40 a 8.50)
	-- ==========================================
	["Cotton Candy Cow"] = { MeshPart = PETS_FOLDER:FindFirstChild("Cotton Candy Cow"), DisplayName = "Cotton Candy Cow", Weight = 40, World = 5, IsFlying = false, Raritys = "Uncommon", Multiplier = 4.40 },
	["Pony"] = { MeshPart = PETS_FOLDER:FindFirstChild("Pony"), DisplayName = "Pony", Weight = 35, World = 5, IsFlying = false, Raritys = "Rare", Multiplier = 5.00 },
	["Cupcake"] = { MeshPart = PETS_FOLDER:FindFirstChild("Cupcake"), DisplayName = "Cupcake", Weight = 22, World = 5, IsFlying = false, Raritys = "Epic", Multiplier = 5.80 },
	["Unicorn"] = { MeshPart = PETS_FOLDER:FindFirstChild("Unicorn"), DisplayName = "Unicorn", Weight = 3, World = 5, IsFlying = false, Raritys = "Legendary", Multiplier = 6.80 },

	["Golden Cotton Candy Cow"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Cotton Candy Cow"), DisplayName = "Golden Cotton Candy Cow", Weight = 40, World = 5, IsFlying = false, Raritys = "Uncommon", Multiplier = 5.50 },
	["Golden Pony"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Pony"), DisplayName = "Golden Pony", Weight = 35, World = 5, IsFlying = false, Raritys = "Rare", Multiplier = 6.30 },
	["Golden Cupcake"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Cupcake"), DisplayName = "Golden Cupcake", Weight = 21, World = 5, IsFlying = false, Raritys = "Epic", Multiplier = 7.30 },
	["Golden Unicorn"] = { MeshPart = PETS_FOLDER:FindFirstChild("Golden Unicorn"), DisplayName = "Golden Unicorn", Weight = 3, World = 5, IsFlying = false, Raritys = "Legendary", Multiplier = 8.50 },
}

local DataPets = {}

------------------//FUNCTIONS
function DataPets.GetPetData(petName: string): PetData?
	return PetsConfig[petName]
end

function DataPets.GetAllPets()
	return PetsConfig
end

function DataPets.GetPetsByWorld(world: number)
	local result = {}
	for name, pet in pairs(PetsConfig) do
		if pet.World == world then
			result[name] = pet
		end
	end
	return result
end

function DataPets.GetPetViewport(petName)
	local petData = PetsConfig[petName]
	if not petData or not petData.MeshPart then
		return nil
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.BackgroundTransparency = 1
	viewport.Name = "PetView_" .. petName

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local partClone = petData.MeshPart:Clone()
	partClone.CFrame = CFrame.new()
	partClone.Anchored = true
	partClone.Parent = viewport

	local cf = partClone.CFrame
	local size = partClone.Size

	local radius = size.Magnitude / 2
	local fov = camera.FieldOfView

	local fitDistance = radius / math.sin(math.rad(fov / 2))

	local distanceMultiplier = 0.97
	local finalDistance = fitDistance * distanceMultiplier

	local viewAngle = math.rad(90)
	local rotatedDirection = (cf * CFrame.Angles(0, viewAngle, 0)).LookVector
	local cameraPosition = cf.Position + (rotatedDirection * finalDistance)

	cameraPosition += Vector3.new(size.X * 0.15, size.Y * 0.1, 0)

	camera.CFrame = CFrame.lookAt(cameraPosition, cf.Position)

	return viewport
end

------------------//INIT
return DataPets
