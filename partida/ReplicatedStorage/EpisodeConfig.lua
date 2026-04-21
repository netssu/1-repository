--!strict

local CurrentEpisode = 2

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
		[1] = { Free = { Title = 'Gems' , Amount = 150 } , Premium = { Title = 'Gems' , Amount = 1000 } },
		[2] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 10 } },
		[3] = { Free = { Title = 'Gems' , Amount = 200 } , Premium = { Title = 'Gems' , Amount = 2000 } },
		[4] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 2 } },
		[5] = { Free = { Title = 'Gems' , Amount = 250 } , Premium = { Title = 'Gems' , Amount = 2500  } },
		[6] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[7] = { Free = { Title = 'Lucky Crystal' , Amount = 1 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[8] = { Free = { Title = 'Gems' , Amount = 300 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[9] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[10] = { Free = { Title = 'LuckySpins' , Amount = 1 } , Premium = { Title = 'LuckySpins' , Amount = 2 } },
		--
		[11] = { Free = { Title = 'Gems' , Amount = 350 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[12] = { Free = { Title = 'Raid Refresh' , Amount = 1 } , Premium = { Title = 'Raid Refresh' , Amount = 2 } },
		[13] = { Free = { Title = 'Fortunate Crystal' , Amount = 1 } , Premium = { Title = 'Fortunate Crystal' , Amount = 2 } },
		[14] = { Free = { Title = 'Gems' , Amount = 400 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[15] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[16] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 3 } },
		[17] = { Free = { Title = 'Gems' , Amount = 450 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[18] = { Free = { Title = 'JunkOfferings' , Amount = 1 } , Premium = { Title = 'JunkOfferings' , Amount = 2 } },
		[19] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[20] = { Free = { Title = 'Gems' , Amount = 500 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		--
		[21] = { Free = { Title = 'Lucky Crystal' , Amount = 2 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[22] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[23] = { Free = { Title = 'Gems' , Amount = 550 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[24] = { Free = { Title = '2x Gems' , Amount = 1 } , Premium = { Title = '2x Gems' , Amount = 2 } },
		[25] = { Free = { Title = 'TraitPoint' , Amount = 10 } , Premium = { Title = 'TraitPoint' , Amount = 50 } },
		[26] = { Free = { Title = 'Gems' , Amount = 600 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[27] = { Free = { Title = 'JunkOfferings' , Amount = 2 } , Premium = { Title = 'JunkOfferings' , Amount = 5 } },
		[28] = { Free = { Title = 'Gems' , Amount = 1250 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[29] = { Free = { Title = 'LuckySpins' , Amount = 10 } , Premium = { Title = 'LuckySpins' , Amount = 10 } },
		[30] = { Free = { Title = 'Django' , Amount = 1 } , Premium = { Title = 'SHINY Django' , Amount = 1 } },
	},
	[2] = {
		[1] = { Free = { Title = 'Gems' , Amount = 150 } , Premium = { Title = 'Gems' , Amount = 1000 } },
		[2] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 10 } },
		[3] = { Free = { Title = 'Gems' , Amount = 200 } , Premium = { Title = 'Gems' , Amount = 2000 } },
		[4] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 2 } },
		[5] = { Free = { Title = 'Gems' , Amount = 250 } , Premium = { Title = 'Gems' , Amount = 2500  } },
		[6] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[7] = { Free = { Title = 'Lucky Crystal' , Amount = 1 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[8] = { Free = { Title = 'Gems' , Amount = 300 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[9] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[10] = { Free = { Title = 'LuckySpins' , Amount = 1 } , Premium = { Title = 'LuckySpins' , Amount = 2 } },
		--
		[11] = { Free = { Title = 'Gems' , Amount = 350 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[12] = { Free = { Title = 'Raid Refresh' , Amount = 1 } , Premium = { Title = 'Raid Refresh' , Amount = 2 } },
		[13] = { Free = { Title = 'Fortunate Crystal' , Amount = 1 } , Premium = { Title = 'Fortunate Crystal' , Amount = 2 } },
		[14] = { Free = { Title = 'Gems' , Amount = 400 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[15] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[16] = { Free = { Title = '2x Coins' , Amount = 1 } , Premium = { Title = '2x Coins' , Amount = 3 } },
		[17] = { Free = { Title = 'Gems' , Amount = 450 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[18] = { Free = { Title = 'JunkOfferings' , Amount = 1 } , Premium = { Title = 'JunkOfferings' , Amount = 2 } },
		[19] = { Free = { Title = '2x XP' , Amount = 1 } , Premium = { Title = '2x XP' , Amount = 2 } },
		[20] = { Free = { Title = 'Gems' , Amount = 500 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		--
		[21] = { Free = { Title = 'Lucky Crystal' , Amount = 2 } , Premium = { Title = 'Lucky Crystal' , Amount = 2 } },
		[22] = { Free = { Title = 'TraitPoint' , Amount = 5 } , Premium = { Title = 'TraitPoint' , Amount = 25 } },
		[23] = { Free = { Title = 'Gems' , Amount = 550 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[24] = { Free = { Title = '2x Gems' , Amount = 1 } , Premium = { Title = '2x Gems' , Amount = 2 } },
		[25] = { Free = { Title = 'TraitPoint' , Amount = 10 } , Premium = { Title = 'TraitPoint' , Amount = 50 } },
		[26] = { Free = { Title = 'Gems' , Amount = 600 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[27] = { Free = { Title = 'JunkOfferings' , Amount = 2 } , Premium = { Title = 'JunkOfferings' , Amount = 5 } },
		[28] = { Free = { Title = 'Gems' , Amount = 1250 } , Premium = { Title = 'Gems' , Amount = 2500 } },
		[29] = { Free = { Title = 'LuckySpins' , Amount = 10 } , Premium = { Title = 'LuckySpins' , Amount = 10 } },
		[30] = { Free = { Title = 'Grand Interrupter' , Amount = 1 } , Premium = { Title = 'SHINY Grand Interrupter' , Amount = 1 } },
	}
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
			['Day'] = 31,
		},
		['XPCurve'] = 500,
		Tasks = {
			{ Type = 'Defeat Enemies' , Amount = 1000 , UniqueId = 'dani1' , XPOverride = 125 },
			{ Type = 'Defeat Story Bosses' , Amount = 5 , UniqueId = 'dani2' , XPOverride = 150 },
			{ Type = 'Clear Acts' , Amount = 5 , UniqueId = 'dani3' , XPOverride = 175 },
			{ Type = 'Complete Raid Act 5' , Amount = 5 , UniqueId = 'dani4' , XPOverride = 350 },
			{ Type = 'Clear 5 Waves' , Amount = 5, UniqueId = 'dani5' , XPOverride = 125 },
			{ Type = 'Complete 25 Waves in Infinite' , Amount = 25, UniqueId = 'dani6' , XPOverride = 250 },

			-- medium
			{ Type = 'Defeat Enemies' , Amount = 2500 , UniqueId = 'medium1' , XPOverride = 350 },
			{ Type = 'Clear Acts' , Amount = 10 , UniqueId = 'medium2' , XPOverride = 450 },
			{ Type = 'Complete Raid Act 5' , Amount = 10 , UniqueId = 'medium3' , XPOverride = 450 },
			{ Type = 'Defeat Story Bosses' , Amount = 10, UniqueId = 'medium4' , XPOverride = 500 },
			{ Type = 'Clear 10 Waves' , Amount = 10, UniqueId = 'medium5' , XPOverride = 250 },
			{ Type = 'Complete 50 Waves in Infinite' , Amount = 50, UniqueId = 'medium6' , XPOverride = 500 },

			-- extreme
			{ Type = 'Defeat Enemies' , Amount = 5000 , UniqueId = 'extreme1' , XPOverride = 750 },
			{ Type = 'Clear Acts' , Amount = 15 , UniqueId = 'extreme2' , XPOverride = 800 },
			{ Type = 'Complete Raid Act 5' , Amount = 15 , UniqueId = 'extreme3' , XPOverride = 750 },
			{ Type = 'Defeat Story Bosses' , Amount = 20, UniqueId = 'extreme4' , XPOverride = 750 },
			{ Type = 'Clear 20 Waves' , Amount = 20, UniqueId = 'extreme5' , XPOverride = 500 },
			{ Type = 'Complete 100 Waves in Infinite' , Amount = 100, UniqueId = 'extreme6' , XPOverride = 850 },
		},
		--Tasks = {
		--	{ Type = 'Defeat Enemies' , Amount = 5 , UniqueId = 'dani1' , XPOverride = 15 },
		--	{ Type = 'Defeat Bosses' , Amount = 2 , UniqueId = 'dani2' , XPOverride = 100 },
		--	{ Type = 'Clear Acts' , Amount = 2 , UniqueId = 'dani3' , XPOverride = 15 },
		--	{ Type = 'Complete Raids' , Amount = 2 , UniqueId = 'dani4' , XPOverride = 75 },
			
		--	-- medium
		--	{ Type = 'Defeat Enemies' , Amount = 5*10 , UniqueId = 'medium1' , XPOverride = 15*3 },
		--	{ Type = 'Clear Acts' , Amount = 2*10 , UniqueId = 'medium2' , XPOverride = 15*2 },
		--	{ Type = 'Complete Raids' , Amount = 2*10 , UniqueId = 'medium3' , XPOverride = 75*3 },
		--	{ Type = 'Defeat Bosses' , Amount = 2 *10, UniqueId = 'medium4' , XPOverride = 100*3 },
			
		--	-- extreme
		--	{ Type = 'Defeat Enemies' , Amount = 1500 , UniqueId = 'extreme1' , XPOverride = 300 },
		--	{ Type = 'Clear Acts' , Amount = 2*25 , UniqueId = 'extreme2' , XPOverride = 15*4 },
		--	{ Type = 'Complete Raids' , Amount = 2*25 , UniqueId = 'extreme3' , XPOverride = 75*5 },
		--	{ Type = 'Defeat Bosses' , Amount = 2 *25, UniqueId = 'extreme4' , XPOverride = 100*4 },
		--},
	},
	[2] = {
		['StartDate'] = {
			['Year'] = 2025,
			['Month'] = 5,
			['Day'] = 31,
		},
		['ExpiryDate'] = {
			['Year'] = 2025,
			['Month'] = 6,
			['Day'] = 30,
		},
		['XPCurve'] = 500,
		Tasks = {
			{ Type = 'Defeat Enemies' , Amount = 50 , UniqueId = 'dani1' , XPOverride = 50 },
			{ Type = 'Defeat Bosses' , Amount = 20 , UniqueId = 'dani2' , XPOverride = 100 },
			{ Type = 'Clear Acts' , Amount = 5 , UniqueId = 'dani3' , XPOverride = 60 },
			{ Type = 'Complete Raids' , Amount = 5 , UniqueId = 'dani4' , XPOverride = 105 },

			-- medium
			{ Type = 'Defeat Enemies' , Amount = 5*10 , UniqueId = 'medium1' , XPOverride = 15 },
			{ Type = 'Clear Acts' , Amount = 2*10 , UniqueId = 'medium2' , XPOverride = 15 },
			{ Type = 'Complete Raids' , Amount = 2*10 , UniqueId = 'medium3' , XPOverride = 75 },
			{ Type = 'Defeat Bosses' , Amount = 2 *10, UniqueId = 'medium4' , XPOverride = 100 },

			-- extreme
			{ Type = 'Defeat Enemies' , Amount = 1500 , UniqueId = 'extreme1' , XPOverride = 300 },
			{ Type = 'Clear Acts' , Amount = 2*25 , UniqueId = 'extreme2' , XPOverride = 15 },
			{ Type = 'Complete Raids' , Amount = 2*25 , UniqueId = 'extreme3' , XPOverride = 75 },
			{ Type = 'Defeat Bosses' , Amount = 2 *25, UniqueId = 'extreme4' , XPOverride = 100 },
		},
	}
}

--
return {
	CurrentEpisode = CurrentEpisode,
	TierData = TierData,
	EpisodeData = EpisodeData,
	EntryToDate = function( Entry : { Year : number , Month : number , Day : number } ) : number
		return os.time( { year = Entry.Year , month = Entry.Month , day = Entry.Day , hour = 0 , min = 0 , sec = 0 } )
	end,
}