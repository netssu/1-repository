local module = {
	Worlds = {
        "Death Star",
        "Kashyyyk Planet",
        "Mustafar",
		"Destroyed Kamino",
		'Temple'
	},
	LevelName = {
        ["Death Star"] = {"Commander", "Loner", "GalacticShip", "Mandalorian", "Chancelar"},
        ['Kashyyyk Planet'] = {'Saberstorm', 'The Twin Suns', 'Force and Fury', 'Womp Rat Rebels', 'Echo Squadron'},
        ["Mustafar"] = {"Molten Knight","Duel of Fates","Sith Flamebringer","Obi the Red Blade","Ashes of Vader"},
		["Destroyed Kamino"] = {"Clones in the Rain","The Flooded Legacy","Genetic Ghosts","Echoes of Order 66","The Drip of War"},
		["Temple"] = {"Vault of the Ancients","Shadow of the Jedi","Cracked Holocron","Order’s End","Echoes in the Marble"}
	},
	Images = {
        ["Death Star"] = "rbxassetid://75044000150604",
		['Kashyyyk Planet'] = 'rbxassetid://101689445539382',
        ['Mustafar'] = 'rbxassetid://119722477427441',
		['Destroyed Kamino'] = 'rbxassetid://111167314992858',
		['Temple'] = 'rbxassetid://113741794143567'
	},

	Maps = {
        ["Death Star"] = "Death Star",
        ['Kashyyyk Planet'] = "Kashyyyyk Planet",
		['Mustafar'] = "Mustafar",
		['Temple'] = 'Temple'
	},
	LoadScreenImages = {
		["Lobby"] = "rbxassetid://102100691476495",
		["AFKChamber"] = "rbxassetid://102100691476495",
        ["Death Star"] = "rbxassetid://75044000150604",
        ['Kashyyyk Planet'] = 'rbxassetid://101689445539382',
        ['Mustafar'] = 'rbxassetid://119722477427441',
		['Destroyed Kamino'] = 'rbxassetid://101726974550373',
		['Temple'] = 'rbxassetid://113741794143567'
	},
	
	
	
}

return module