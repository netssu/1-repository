export type PlayerDataType = string

export type InventoryItem = {
	Name: string,
	Quantity: number,
	Rarity: string?,
}

export type CharacterData = {
	Name: string,
	Level: number,
	Exp: number,
	Equipped: boolean?,
}

export type PlayerQuestStatus = {
	ID: number,
	Type: string,
	Progress: number,
	Goal: number,
	Completed: boolean,
	Claimed: boolean,
}

export type PlayerStats = {
	MVP: number,
	Points: number,
	Saves: number,
	Assists: number,
	MatchesPlayed: number,
	Steals: number,
	Passing: number,
	Touchdowns: number,
	Interceptions: number,
	Tackles: number,
	Coins: number,
}

return {}
