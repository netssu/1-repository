local module = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local GameAnalytics = require(ReplicatedStorage.GameAnalytics)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

GameAnalytics:isRemoteConfigsReady()

module.GameAnalyticsABService = {}

module.GameAnalyticsABService.__index = module.GameAnalyticsABService

function module.GameAnalyticsABService.new(onLoaded)
	local self = setmetatable({}, module.GameAnalyticsABService)

	self.GameAnayltics = GameAnalytics

	return self:constructor(onLoaded) or self
end

function module.GameAnalyticsABService:constructor(onLoaded)
	self.onLoaded = onLoaded
	self.maid = {}
	self.connections = {}
	for _, player in Players:GetPlayers() do
		task.defer(function()
			return self:onPlayerAdded(player)
		end)
	end

	local _maid = self.maid
	local _arg0 = Players.PlayerAdded:Connect(function(player)
		return self:onPlayerAdded(player)
	end)
	table.insert(_maid, _arg0)

	local _maid_1 = self.maid
	local _arg0_1 = Players.PlayerRemoving:Connect(function(player)
		return self:onPlayerRemoving(player)
	end)
	table.insert(_maid_1, _arg0_1)
end

function module.GameAnalyticsABService:onRemoteConfigReady(player)
	self.Loaded(player)
end

function module.GameAnalyticsABService:onPlayerAdded(player)
	if player.Parent == nil then
		return nil
	end
	local disconnected = false
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if disconnected then
			return nil
		end
		if GameAnalytics:isPlayerReady(player.UserId) then
			if GameAnalytics:isRemoteConfigsReady(player.UserId) then
				disconnected = true
				connection:Disconnect()
				self:onRemoteConfigReady(player)
			end
		end
	end)
	self.connections[player] = connection
end

function module.GameAnalyticsABService:onPlayerRemoving(player)
	self.connections[player]:Disconnect()
	self.connections[player] = nil
end

function module.GameAnalyticsABService:get(player, key)
	local result
	local success, error = pcall(function()
		result = GameAnalytics:getRemoteConfigsValueAsString(player.UserId, { key = key })
	end)
	if not success then
		warn("Failed to get remote config value for key '" .. key .. "': " .. tostring(error))
		result = nil
	end
	return result
end

function module.GameAnalyticsABService:cleanup()
	for _, connection in self.maid do
		connection:Disconnect()
	end
end

local vals = {
	["control"] = 1,
	["small"] = 1.15,
	['medium'] = 1.35,
	['large'] = 1.5
}

function module.selectTreatment(plr)
	local treatment = nil
	local group = module.GameAnalyticsABService:get(plr, "price_slashing")
	if group then
		treatment = vals[group]
	else
		print("Group not found or error fetching remote config")
	end
	return treatment
end

return module