return {
    Name = "giveSpins",
    Aliases = {"spins", "givespins"},
    Description = "Gives spins of a specified type to the target player.",
    Args = {

        {
            Type = "player",
            Name = "player",
            Description = "The player to give stats to.",
        },
        {
            Type = "spins",
            Name = "spinsType",
            Description = "The type of spins to give(SpinsFlow or SpinsStyle)",
        },
        {
            Type = "number",
            Name = "amount",
            Description = "The amount of spins to give",
            Default = 1,
        },

    }
}