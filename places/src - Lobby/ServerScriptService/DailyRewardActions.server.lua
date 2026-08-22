------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//DEPENDENCIES
local dailyRewardService = require(ServerStorage:WaitForChild("Modules"):WaitForChild("DailyRewardService"))

------------------//INIT
dailyRewardService.enable()
