--[[
    GoatAnalytics SDK for Roblox
    Server-authoritative analytics — API key never leaves the server.

    Server usage:
        local Analytics = require(path.to.GoatAnalytics)
        Analytics:init({ appId = "your-app-id", apiKey = "your-api-key" })

    Client usage:
        local Analytics = require(path.to.GoatAnalytics)
        Analytics:trackInteraction("button_click", "shop_button")
]]

local RunService = game:GetService("RunService")

if RunService:IsServer() then
	return require(script.Server.ServerAnalytics)
else
	return require(script.Client.ClientAnalytics)
end
