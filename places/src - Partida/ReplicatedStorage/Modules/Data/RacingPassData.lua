------------------//CONSTANTS
local MIN_LEVEL: number = 1
local MAX_LEVEL: number = 30
local CURRENT_SEASON: number = 5

local LEVEL_REQUIREMENTS: { [number]: number } = {
	[1] = 300,
	[2] = 350,
	[3] = 400,
	[4] = 450,
	[5] = 500,
	[6] = 550,
	[7] = 600,
	[8] = 650,
	[9] = 700,
	[10] = 750,
	[11] = 800,
	[12] = 850,
	[13] = 900,
	[14] = 950,
	[15] = 1000,
	[16] = 1050,
	[17] = 1100,
	[18] = 1150,
	[19] = 1200,
	[20] = 1250,
	[21] = 1300,
	[22] = 1350,
	[23] = 1400,
	[24] = 1450,
	[25] = 1500,
	[26] = 1550,
	[27] = 1600,
	[28] = 1650,
	[29] = 1700,
	[30] = 1750,
}

export type Reward = {
	Type: "Cash" | "Suit" | "Helmets" | "Livery",
	Item: string?,
	Amount: number?,
}

local REWARDS: { [string]: { [number]: Reward } } = {
	Premium = {
		[1] = { Type = "Helmets", Item = "Livery Winner" },
		[5] = { Type = "Cash", Amount = 5000 },
		[10] = { Type = "Suit", Item = "Livery Winner" },
		[12] = { Type = "Livery", Item = "Livery Winner" },
		[14] = { Type = "Cash", Amount = 5000 },
		[16] = { Type = "Suit", Item = "Mecha Pilot" },
		[18] = { Type = "Livery", Item = "Mecha Pilot" },
		[20] = { Type = "Helmets", Item = "Mecha Pilot" },
		[21] = { Type = "Cash", Amount = 10000 },
		[22] = { Type = "Cash", Amount = 10000 },
		[24] = { Type = "Livery", Item = "Kyubiko" },
		[25] = { Type = "Suit", Item = "Kyubiko" },
		[26] = { Type = "Cash", Amount = 10000 },
		[28] = { Type = "Cash", Amount = 20000 },
		[29] = { Type = "Helmets", Item = "Kyubiko" },
		[30] = { Type = "Cash", Amount = 25000 },
	},
	Normal = {
		[1] = { Type = "Cash", Amount = 1000 },
		[5] = { Type = "Cash", Amount = 5000 },
		[10] = { Type = "Suit", Item = "Kurobushi" },
		[12] = { Type = "Helmets", Item = "Kurobushi" },
		[15] = { Type = "Livery", Item = "Kurobushi" },
		[18] = { Type = "Livery", Item = "Sakura" },
		[19] = { Type = "Suit", Item = "Sakura" },
		[20] = { Type = "Helmets", Item = "Sakura" },
		[22] = { Type = "Helmets", Item = "Jay" },
		[24] = { Type = "Cash", Amount = 10000 },
		[25] = { Type = "Cash", Amount = 15000 },
		[26] = { Type = "Livery", Item = "CoolPixel" },
		[27] = { Type = "Cash", Amount = 20000 },
		[28] = { Type = "Cash", Amount = 25000 },
		[29] = { Type = "Suit", Item = "CoolPixel" },
		[30] = { Type = "Cash", Amount = 30000 },
	},
}

local PRODUCTS: { [string]: number } = {
	RacingPass = 3482774850,
	SkipOne = 3482774183,
	SkipFive = 3482774636,
	CompleteSkip = 3482774481,
}

------------------//INIT
return {
	MIN_LEVEL = MIN_LEVEL,
	MAX_LEVEL = MAX_LEVEL,
	CURRENT_SEASON = CURRENT_SEASON,
	LEVEL_REQUIREMENTS = LEVEL_REQUIREMENTS,
	REWARDS = REWARDS,
	PRODUCTS = PRODUCTS,
}


