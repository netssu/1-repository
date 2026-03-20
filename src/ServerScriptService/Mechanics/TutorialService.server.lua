------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//CONSTANTS

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))

------------------//FUNCTIONS

------------------//INIT
local assets = ReplicatedStorage:WaitForChild("Assets")
local remotes = assets:WaitForChild("Remotes")
local finishTutorialEvent = remotes:WaitForChild("FinishTutorial")

finishTutorialEvent.OnServerEvent:Connect(function(player)
	DataUtility.server.set(player, "TutorialCompleted", true)
end)