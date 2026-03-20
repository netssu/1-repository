------------------//SERVICES
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local APP_ID: string = "d89f81b1-14f9-451a-a4a5-15d9e3892ab8"
local API_KEY: string = "goat_9a3930ef6ac21e8b847385ca544ec6c54867ca01e45f9c91"

------------------//VARIABLES
local AnalyticsService = require(ServerStorage.Modules.Utility:WaitForChild("AnalyticsService"))

------------------//INIT
AnalyticsService.init(APP_ID, API_KEY)