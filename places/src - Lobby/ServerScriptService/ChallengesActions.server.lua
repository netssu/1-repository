------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local serverModules: Folder = ServerStorage:WaitForChild("Modules")
local challengesService = require(serverModules:WaitForChild("ChallengesService"))

------------------//MAIN FUNCTIONS
challengesService.enable()

------------------//INIT
