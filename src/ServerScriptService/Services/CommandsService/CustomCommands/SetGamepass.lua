return {
    Name = "setGamepass",
    Aliases = {"gamepass", "setgamepass"},
    Description = "Gives gamepass of a specified type to the target player.",
    Args = {

        {
            Type = "player",
            Name = "player",
            Description = "The player to give stats to.",
        },
        {
            Type = "gamepasses",
            Name = "gamepass",
            Description = "The type of gamepass to give",
        },
        {
            Type = "boolean",
            Name = "value",
            Description = "True or False",
        },
    }
}