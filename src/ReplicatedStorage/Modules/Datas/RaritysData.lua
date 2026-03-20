------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local RaritysConfig = {
	["Common"] = {
		Color = Color3.fromRGB(255, 255, 255),
		Tier = 1,
		DisplayName = "Common",
	},
	["Uncommon"] = {
		Color = Color3.fromRGB(85, 255, 127),
		Tier = 2,
		DisplayName = "Uncommon",
	},
	["Rare"] = {
		Color = Color3.fromRGB(85, 170, 255),
		Tier = 3,
		DisplayName = "Rare",
	},
	["Epic"] = {
		Color = Color3.fromRGB(170, 85, 255),
		Tier = 4,
		DisplayName = "Epic",
	},
	["Legendary"] = {
		Color = Color3.fromRGB(255, 170, 0),
		Tier = 5,
		DisplayName = "Legendary",
	},
	["Mythical"] = {
		Color = Color3.fromRGB(255, 85, 255),
		Tier = 6,
		DisplayName = "Mythical",
	},
}

------------------//INIT
return RaritysConfig