export type CommandParameter = "Player" | "Gamepass" | "True/False" | "Boolean" | "Stat" | "Amount" | "Style"

export type Command = {
	Name: string,
    PrivateName: string,
	Parameters: { CommandParameter },
}

export type Commands = {
	[string]: Command,
}

local commands: Commands = {
	SetGamepass = {
		Name = "Set Gamepass",
        PrivateName = "SetGamepass",
		Parameters = { "Player", "Gamepass", "Boolean" },
	},

	GiveStat = {
		Name = "Give Stats",
		PrivateName = "GiveStat",
		Parameters = { "Player", "Stat", "Amount"}
	},

	ChangeStyle = {
		Name = "Change Style",
		PrivateName = "ChangeStyle",
		Parameters = { "Player", "Style" }
	},
}

return commands
