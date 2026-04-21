local AnalyticsService = game:GetService('AnalyticsService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local GameAnalytics = require(ReplicatedStorage.GameAnalytics)

local UpdateTierBy , RedeemTiers

local PassesList = {
	Products = require(script.Products),
	GamePasses = require(script.Passes),
	Information = require(script.Information)
}

return PassesList