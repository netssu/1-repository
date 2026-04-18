local ProfileTemplate = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

PlayerDataManager:SetTemplate({
	Yen = 2000,
	Level = 0,
	Exp = 0,
	Rating = 20,
	MVP = 0,
	Touchdowns = 0,
	Passing = 0,
	Tackles = 0,
	Wins = 0,
	Timer = 0,
	Intercepts = 0,
	Assists = 0,
	Possession = 0,

	SpinStyle = 30,
	StyleLuckySpins = 2,
	
	SpinFlow = 35,
	FlowLuckySpins = 2,

	Gamepass = {
		GamePassVip = false,
		SkipSpin = false,
		ToxicEmotes = false,
		AnimeEmotes = false,
	},

	Settings = {
		MusicVolume = 5,
		SFXVolume = 5,
		MusicEnabled = true,
		SFXEnabled = true,
		Shadows = true,
		SpinWarning = true,
		SkipSpinActivated = false,
	},

	RedeemedCodes = {},

	SelectedSlot = 1,
	SelectedFlowSlot = 1,
	StyleSlots = {
		Slot1 = "",
		Slot2 = "",
		Slot3 = "",
		Slot4 = "",
	},
	FlowSlots = {
		Slot1 = "",
		Slot2 = "",
		Slot3 = "",
		Slot4 = "",
		Slot5 = "",
		Slot6 = "",
	},

	UnlockedStyleSlots = { 1 },
	UnlockedFlowSlots = { 1 },

	EquippedCosmetics = {},
	OwnedCosmetics = {},
	OwnedCosmeticsCount = {},

	EquippedCard = "",
	OwnedCards = {},
	OwnedCardsCount = {},

	EquippedEmotes = {},
	OwnedEmotes = {},
	OwnedEmotesCount = {},
})

return ProfileTemplate
