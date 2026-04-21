--!strict

local CurrentEpisode = 1

export type DateExpectancyType = {
	Year : number,
	Month : number,
	Day : number,
}

export type TierType = {
	Title : string,
	Amount : number,
}

local TierData : { [number] : { [number] : { Free : TierType , Premium : TierType } } } = {
	[1] = {
		-- [#] = { Free = { Title = '' , Amount = 0 } , Premium = { Title = '' , Amount = 0 } },
		[1] = { Free = { Title = 'Gems' , Amount = 150 } , Premium = { Title = 'Gems' , Amount = 300 } },
		[2] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 10 } },
		[3] = { Free = { Title = 'Gems' , Amount = 200 } , Premium = { Title = 'Gems' , Amount = 400 } },
		[4] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 2 } },
		[5] = { Free = { Title = 'Gems' , Amount = 250 } , Premium = { Title = 'Gems' , Amount = 500 } },
		[6] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[7] = { Free = { Title = 'Lucky Crystal' , Amount = 1 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[8] = { Free = { Title = 'Gems' , Amount = 300 } , Premium = { Title = 'Gems' , Amount = 600 } },
		[9] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 10 } },
		[10] = { Free = { Title = 'LuckySpins' , Amount = 1 } , Premium = { Title = 'LuckySpins' , Amount = 2 } },
		--
		[11] = { Free = { Title = 'Gems' , Amount = 350 } , Premium = { Title = 'Gems' , Amount = 700 } },
		[12] = { Free = { Title = 'Raid Refresh' , Amount = 1 } , Premium = { Title = 'Raid Refresh' , Amount = 2 } },
		[13] = { Free = { Title = 'Fortunate Crystal' , Amount = 1 } , Premium = { Title = 'Fortunate Crystal' , Amount = 2 } },
		[14] = { Free = { Title = 'Gems' , Amount = 400 } , Premium = { Title = 'Gems' , Amount = 800 } },
		[15] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 3 } },
		[16] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 3 } },
		[17] = { Free = { Title = 'Gems' , Amount = 450 } , Premium = { Title = 'Gems' , Amount = 900 } },
		[18] = { Free = { Title = 'JunkOfferings' , Amount = 1 } , Premium = { Title = 'JunkOfferings' , Amount = 2 } },
		[19] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[20] = { Free = { Title = 'Gems' , Amount = 500 } , Premium = { Title = 'Gems' , Amount = 1000 } },
		--
		[21] = { Free = { Title = 'Lucky Crystal' , Amount = 2 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[22] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 10 } },
		[23] = { Free = { Title = 'Gems' , Amount = 550 } , Premium = { Title = 'Gems' , Amount = 1100 } },
		[24] = { Free = { Title = '2x Gems' , Amount = 1 } , Premium = { Title = '2x Gems' , Amount = 2 } },
		[25] = { Free = { Title = 'TraitPoint' , Amount = 10 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[26] = { Free = { Title = 'Gems' , Amount = 600 } , Premium = { Title = 'Gems' , Amount = 1200 } },
		[27] = { Free = { Title = 'JunkOfferings' , Amount = 2 } , Premium = { Title = 'JunkOfferings' , Amount = 5 } },
		[28] = { Free = { Title = 'Gems' , Amount = 1250 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[29] = { Free = { Title = 'LuckySpins' , Amount = 10 } , Premium = { Title = 'LuckySpins' , Amount = 25 } },
		[30] = { Free = { Title = 'Django' , Amount = 1 } , Premium = { Title = 'SHINY Django' , Amount = 1 } },
	},
}

--

--local NonPlural = {
--	['Defeat Enemies'] = 'Defeat An Enemy',
--	['Defeat Bosses'] = 'Defeat A Boss',
--	['Clear Acts'] = 'Clear An Act',
--	['Complete Raids'] = 'Complete A Raid'
--}

export type TaskType = {
	Type : 'Defeat Enemies' | 'Defeat Bosses' | 'Clear Acts' | 'Complete Raids',
	Amount : number,
	StartDate : DateExpectancyType? | number?,
	ExpiryDate : DateExpectancyType? | number?,
	UniqueId : string,
	IntValue : IntValue?,
}

local EpisodeData : { [number] : { StartDate : DateExpectancyType , ExpiryDate : DateExpectancyType , XPCurve : number , Tasks : { any } } } = {
	[1] = {
		['StartDate'] = {
			['Year'] = 2025,
			['Month'] = 5,
			['Day'] = 4,
		},
		['ExpiryDate'] = {
			['Year'] = 2025,
			['Month'] = 5,
			['Day'] = 5,
		},
		['XPCurve'] = 500,
		Tasks = {
			{ Type = 'Defeat Enemies' , Amount = 5 , UniqueId = 'dani1' , XPOverride = 15 },
			{ Type = 'Defeat Bosses' , Amount = 2 , UniqueId = 'dani2' , XPOverride = 100 },
			{ Type = 'Clear Acts' , Amount = 2 , UniqueId = 'dani3' , XPOverride = 15 },
			{ Type = 'Complete Raids' , Amount = 2 , UniqueId = 'dani4' , XPOverride = 75 },
		},
	},
}

--

return {
	CurrentEpisode = 1,
	TierData = TierData,
	EpisodeData = EpisodeData,
	EntryToDate = function( Entry : { Year : number , Month : number , Day : number } ) : number
		return os.time( { year = Entry.Year , month = Entry.Month , day = Entry.Day , hour = 0 , min = 0 , sec = 0 } )
	end,
}