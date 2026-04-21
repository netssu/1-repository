local module = {
	Worlds = { -- THIS IS SOOO UNNECESSARY BRO.(ace)
		"Naboo Planet",
		"Geonosis Planet",
		"Kashyyyk Planet",
		"Death Star",
		"Tatooine",
        'Mustafar',
		'Destroyed Kamino',
		'Temple',
		'Hoff',
		'Bespin',
		'Endor',
	},
	LevelName = {
		["Naboo Planet"] = {"Commander", "Loner", "GalacticShip", "Mandalorian", "Chancelar"},
		["Geonosis Planet"] = {"General", "Senior Commander", "Kaller", "Anikan Skaivoker", "Grand Vazien"},
		["Kashyyyk Planet"] = {"Pilot", "Senior Pilot", "Shock Trooper", "CosmoShip", "Imiperial Destroyer"},
		["Death Star"] = {"Dart Mayl", "Anikan Skaivoker", "Mayl Phantom Rage", "Dark Overlord", "Wader Last Breath"},
		['Tatooine'] = {"Pilot", "Hyena Bomber", "General", "Kit Fishto", "Kit Fishto (Supreme)"},
        ["Mustafar"] = {"Pilot", "Hyena Bomber", "General", "Kit Fishto", "Kit Fishto (Supreme)"}, -- {"Molten Knight","Duel of Fates","Sith Flamebringer","Obi the Red Blade","Ashes of Vader"} -- 6
		['Destroyed Kamino'] = {'B1', 'B2', 'BX', 'Dark Overlord', 'Wader Last Breath'},
		['Temple'] = {'Tact', 'Tact', 'Dart Raiven', 'Plooo', 'Anikin Armor'},
		['Hoff'] = {
			"Frozen Divide",
			"Glacier's Grasp",
			"Blizzard Requiem",
			"Echoes of Frost",
			"Final Thaw"
		},
		['Bespin'] = {'Gasworks Ambush',
			'Cloudport Skirmish',
			'Tibanna Turmoil',
			'Carbon Freeze Protocol',
			'Duel at Dawn' -- Final Boss
		},
		['Endor'] = {
			"Whispers Beneath the Leaves",
			"Echoes of the Hollow Moon",
			"The Shattered Grove",
			"Veil of the Forest Warden",
			"Throne of Thorns"
		}
	},
	Images = {
		["Naboo Planet"] = "rbxassetid://102100691476495",
		["Geonosis Planet"] = "rbxassetid://102100691476495",
		["Kashyyyk Planet"] = "rbxassetid://102100691476495",
		["Death Star"] = "rbxassetid://102100691476495",
		['Tatooine'] = 'rbxassetid://80270847920009',
        ['Mustafar'] = 'rbxassetid://80270847920009', -- big
		['Destroyed Kamino'] = 'rbxassetid://134785018786874',
		['Temple'] = 'rbxassetid://113741794143567',
		['Hoff'] = 'rbxassetid://79920000701742',
		['Bespin'] = 'rbxassetid://88974324482612',
		['Endor'] = 'rbxassetid://99657084528550',
	},

	Maps = { -- this is handled terribly be ivancho, hes assigning numbers to each planet which is unnecessary asf - makes it hard to scale(Ace)
		["Naboo Planet"] = "Naboo Planet",
		["Geonosis Planet"] = "Geonosis Planet",
		["Kashyyyk Planet"] = "Kashyyyk Planet",
		["Death Star"] = "Death Star",
		['Tatooine'] = 'Tatooine', -- 5
        ['Mustafar'] = 'Mustafar', -- 6
		['Destroyed Kamino'] = 'Destroyed Kamino', -- 7
		['Temple'] = 'Temple', -- 8 
		['Hoff'] = 'Hoff', -- 9
		['Bespin'] = 'Bespin',
		['Endor'] = 'Endor',
	},

	LoadScreenImages = { -- same here?? why dont we just index module.Images instead(Ace)
		["Lobby"] = "rbxassetid://102100691476495",
		["AFKChamber"] = "rbxassetid://102100691476495",
		["Naboo Planet"] = "rbxassetid://102100691476495",
		["Geonosis Planet"] = "rbxassetid://102100691476495",
		["Kashyyyk Planet"] = "rbxassetid://102100691476495",
		["Death Star"] = "rbxassetid://102100691476495",
		['Tatooine'] = 'rbxassetid://83876239668688', -- kamino image
        ['Mustafar'] = 'rbxassetid://119722477427441',
		['Destroyed Kamino'] = 'rbxassetid://134785018786874',
		['Temple'] = 'rbxassetid://113741794143567',
		['Hoff'] = 'rbxassetid://79920000701742',
		['Bespin'] = 'rbxassetid://88974324482612',
		['Endor'] = 'rbxassetid://88364420964916'
	},
}

return module