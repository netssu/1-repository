return {
    Name = "giveStats",
    Aliases = {"stats", "givestats"},
    Description = "Gives stats of a specified type to the target player.",
    Args = {

        {
            Type = "player",
            Name = "player",
            Description = "The player to give stats to.",
        },
        {
            Type = "stats",
            Name = "statsType",
            Description = "The type of stat to give(Yen, assist etc)",
        },
        {
            Type = "number",
            Name = "amount",
            Description = "The amount to increment/set",
        },

    }
}