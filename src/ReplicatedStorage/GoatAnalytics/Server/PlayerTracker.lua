--[[
    GoatAnalytics SDK - Player Tracker
    Automatically tracks player join/leave events and session duration.
    Now enriched with: region (country), device (platform), game version.
    Initialized by ServerAnalytics — do not use directly.
]]

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local UserInputService = game:GetService("UserInputService")

local Types = require(script.Parent.Parent.Shared.Types)

local PlayerTracker = {}

local serverAnalytics: any = nil
local joinTimestamps: {[number]: number} = {} -- UserId → join time (os.time)
local playerMeta: {[number]: {region: string, device: string}} = {} -- cached metadata
local activePlayerCount = 0

-- Game version: set this in your init script or use a constant
-- e.g. Analytics.gameVersion = "1.2.3"
local GAME_VERSION = "1.0.0"

-- Detect player's device/platform
local function getDeviceType(player: Player): string
	-- Use player's platform from their membership info
	-- More reliable: check via PolicyService or initial client report
	-- Fallback: use GetPlatform from client or guess from screen size

	-- Server-side detection via UserInputService won't work (it's local)
	-- Best approach: have the client send this info
	-- For now, we track what we can server-side
	return "unknown" -- Will be overridden by client enrichment below
end

-- Get player's country/region
local function getPlayerRegion(player: Player): string
	local success, countryCode = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	if success and countryCode and #countryCode > 0 then
		return countryCode
	end
	return "unknown"
end

local function onPlayerAdded(player: Player)
	activePlayerCount += 1
	joinTimestamps[player.UserId] = os.time()

	-- Gather metadata (region is async, so we do it in a task)
	task.spawn(function()
		local region = getPlayerRegion(player)

		playerMeta[player.UserId] = {
			region = region,
			device = "unknown", -- will be set by client
		}

		-- Fire session_start with enriched properties
		serverAnalytics:track(player, Types.EventType.SESSION_START, {
			region = region,
			device = "pending_client", -- placeholder until client reports
			gameVersion = GAME_VERSION,
			locale = player.LocaleId or "unknown",
		})
	end)
end

local function onPlayerRemoving(player: Player)
	activePlayerCount = math.max(0, activePlayerCount - 1)

	local joinTime = joinTimestamps[player.UserId]
	local duration = if joinTime then os.time() - joinTime else 0
	local meta = playerMeta[player.UserId]

	serverAnalytics:track(player, Types.EventType.SESSION_END, {
		sessionDuration = duration,
		region = if meta then meta.region else "unknown",
		device = if meta then meta.device else "unknown",
		gameVersion = GAME_VERSION,
	})

	joinTimestamps[player.UserId] = nil
	playerMeta[player.UserId] = nil
	serverAnalytics:_onPlayerLeaving(player.UserId)
end

-- Called by client to report their device type
function PlayerTracker:setPlayerDevice(player: Player, device: string)
	local meta = playerMeta[player.UserId]
	if meta then
		meta.device = device
	end

	-- Fire a device_reported event so we have the data
	serverAnalytics:track(player, Types.EventType.CUSTOM, {
		eventName = "_sdk_device_reported",
		device = device,
		region = if meta then meta.region else "unknown",
		gameVersion = GAME_VERSION,
	})
end

-- Set game version (call from your init script)
function PlayerTracker:setGameVersion(version: string)
	GAME_VERSION = version
end

-- Initialize the player tracker (called by ServerAnalytics)
function PlayerTracker._init(analytics: any)
	serverAnalytics = analytics

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in the game (in case SDK inits late)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			onPlayerAdded(player)
		end)
	end
end

function PlayerTracker:getActivePlayerCount(): number
	return activePlayerCount
end

function PlayerTracker:getJoinTime(player: Player): number?
	return joinTimestamps[player.UserId]
end

function PlayerTracker:getPlayerMeta(player: Player): {region: string, device: string}?
	return playerMeta[player.UserId]
end

return PlayerTracker