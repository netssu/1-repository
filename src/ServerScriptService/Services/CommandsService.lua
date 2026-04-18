local module = {}

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--//Depencies
local Commands = require(ReplicatedStorage.Packages.Cmdr)

--//Folders
local CustomCommands = script.CustomCommands
local Hooks = script.Hooks
local Types = script.Types

Commands:RegisterDefaultCommands()
Commands:RegisterCommandsIn(CustomCommands)
Commands:RegisterHooksIn(Hooks)
Commands:RegisterTypesIn(Types)

return module