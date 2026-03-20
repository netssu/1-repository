------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//TYPES
export type EggData = {
	Price: number,
	Currency: string,
	Model: Model,
	Weights: {[string]: number}
}

local eggsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Egg")

------------------//DATA
local DataEggs: {[string]: EggData} = {

	-- WORLD 1 ----------------------------------------------------
	-- Economia inicial. Fácil de comprar os primeiros.
	["Common Egg"] = {
		Price = 250,
		Currency = "Coins",
		Model = eggsFolder:WaitForChild("Common Egg"),
		Weights = {
			["Kitty"] = 38,
			["Doggy"] = 38,
			["Bunny"] = 20,
			["Dragon"] = 4
		}
	},

	["Golden Common Egg"] = {
		Price = 2,
		Currency = "RebirthTokens",
		Model = eggsFolder:WaitForChild("Golden Common Egg"),
		Weights = {
			["Golden Kitty"] = 38,
			["Golden Doggy"] = 38,
			["Golden Bunny"] = 20,
			["Golden Dragon"] = 4
		}
	},

	["Aqua Egg"] = {
		Price = 1000,
		Currency = "Coins",
		Model = eggsFolder:WaitForChild("Aqua Egg"),
		Weights = {
			["Fish"] = 40,
			["Turtle"] = 36,
			["Shark"] = 14,
			["Axolotl"] = 10
		}
	},

	["Golden Aqua Egg"] = {
		Price = 3,
		Currency = "RebirthTokens",
		Model = eggsFolder:WaitForChild("Golden Aqua Egg"),
		Weights = {
			["Golden Fish"] = 40,
			["Golden Shark"] = 36,
			["Golden Turtle"] = 14,
			["Golden Axolotl"] = 10
		}
	},

	-- WORLD 2 ----------------------------------------------------
	-- Multiplicadores chegam na casa dos 25x. Preços saltam para milhares.
	["Frost Egg"] = {
		Price = 20000,
		Currency = "Coins",
		Model = eggsFolder:WaitForChild("Frost Egg"),
		Weights = {
			["Penguin"] = 50,
			["Walrus"] = 25,
			["Snow Ram"] = 18,
			["Yeti"] = 7
		}
	},

	["Golden Frost Egg"] = {
		Price = 10,
		Currency = "RebirthTokens",
		Model = eggsFolder:WaitForChild("Golden Frost Egg"),
		Weights = {
			["Golden Penguin"] = 50,
			["Golden Walrus"] = 25,
			["Golden Snow Ram"] = 18,
			["Golden Yeti"] = 7
		}
	},

	-- WORLD 3 ----------------------------------------------------
	-- Multiplicadores passam de 400x. Entramos na casa dos Milhões.
	["Christmas Egg"] = {
		Price = 1000000, -- 1.5 Milhões
		Currency = "Coins",
		Model = eggsFolder:WaitForChild("Christmas Egg"),
		Weights = {
			["Santa Hat Seal"] = 35,
			["Santa Hat Polar Bear"] = 30,
			["Rudolph"] = 20,
			["Santa Paws"] = 15
		}
	},

	["Golden Christmas Egg"] = {
		Price = 20,
		Currency = "RebirthTokens",
		Model = eggsFolder:WaitForChild("Christmas Egg"),
		Weights = {
			["Golden Santa Hat Seal"] = 35,
			["Golden Santa Hat Polar Bear"] = 30,
			["Golden Rudolph"] = 20,
			["Golden Santa Paws"] = 15
		}
	},


	-- WORLD 4 ----------------------------------------------------
	-- Multiplicadores passam de 4000x. Entramos nas dezenas/centenas de Milhões.
	["Jungle Egg"] = {
		Price = 125000000, -- 125 Milhões
		Currency = "Coins",
		Model = eggsFolder:WaitForChild("Jungle Egg"),
		Weights = {
			["Parrot"] = 50,
			["Monkey"] = 25,
			["Tiger"] = 19,
			["Crocodile"] = 6
		}
	},

	["Golden Jungle Egg"] = {
		Price = 1000,
		Currency = "RebirthTokens",
		Model = eggsFolder:WaitForChild("Golden Jungle Egg"),
		Weights = {
			["Golden Parrot"] = 50,
			["Golden Monkey"] = 25,
			["Golden Tiger"] = 19,
			["Golden Crocodile"] = 6
		}
	},


	-- WORLD 5 ----------------------------------------------------
	-- Multiplicadores passam de 30.000x. Entramos na casa dos Bilhões.
	["Cupcake Egg"] = {
		Price = 8500000000, 
		Currency = "Coins",
		Model = eggsFolder:WaitForChild("Cupcake Egg"),
		Weights = {
			["Cotton Candy Cow"] = 40,
			["Pony"] = 35,
			["Cupcake"] = 22,
			["Unicorn"] = 3
		}
	},

	["Golden Cupcake Egg"] = {
		Price = 5000,
		Currency = "RebirthTokens",
		Model = eggsFolder:WaitForChild("Cupcake Egg"),
		Weights = {
			["Golden Cotton Candy Cow"] = 40,
			["Golden Pony"] = 35,
			["Golden Cupcake"] = 21,
			["Golden Unicorn"] = 3
		}
	},

	["Mega Cupcake Egg"] = {
		Price = 0,
		Currency = "Robux",
		Model = eggsFolder:WaitForChild("Cupcake Egg"),
		Weights = {
			["Cotton Candy Cow"] = 60,
			["Cupcake"] = 29,
			["Unicorn"] = 9,
			["Golden Unicorn"] = 2
		}
	}
}

------------------//INIT
return DataEggs