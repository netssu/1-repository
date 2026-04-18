return {
    Name = "changeStyle",
    Aliases = { "style", "changestyle", "setstyle" },
    Description = "Changes the target player's current style.",
    Args = {
        {
            Type = "player",
            Name = "player",
            Description = "The player to change the style for.",
        },
        {
            Type = "styles",
            Name = "style",
            Description = "The style to equip.",
        },
    },
}
