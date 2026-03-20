--[[
    GoatAnalytics SDK - Remote Config + A/B Test Assignment
    
    Fetches config from the dashboard API, with deterministic A/B test enrollment.
    Config is cached and refreshed periodically.
    
    Usage:
        local RemoteConfig = require(path.to.RemoteConfig)
        RemoteConfig:init(analytics) -- pass initialized ServerAnalytics
        
        -- Get a config value (returns cached value, never yields)
        local spawnRate = RemoteConfig:get("enemySpawnRate", 10)
        
        -- Get player-specific config (includes A/B test overlays)
        local config = RemoteConfig:getForPlayer(player)
        
        -- Get A/B test assignment for a player
        local group = RemoteConfig:getABGroup(player, "new_shop_layout")
        -- Returns: { group = "variant_a", enrolled = true } or { group = "control", enrolled = false }
        
        -- Force refresh (e.g., after deploy)
        RemoteConfig:refresh()
]]

local HttpService = game:GetService("HttpService")
local Config = require(script.Parent.Parent.Shared.Config)

local RemoteConfig = {}
RemoteConfig.__index = RemoteConfig

-- State
local initialized = false
local analytics = nil  -- Reference to ServerAnalytics
local apiEndpoint = ""
local gameId = ""
local apiKey = ""

-- Cache
local baseConfig: {[string]: any} = {}
local configVersion: number = 0
local playerConfigs: {[number]: {config: {[string]: any}, abAssignments: {[string]: any}, fetchedAt: number}} = {}
local lastFetchTime: number = 0

-- Settings
local CACHE_TTL = 60  -- seconds before fetching fresh config
local PLAYER_CACHE_TTL = 300  -- per-player cache (5 min)
local RETRY_DELAY = 5
local MAX_RETRIES = 3

local function makeRequest(url: string, retries: number?): (boolean, any)
	local attempts = retries or MAX_RETRIES

	for attempt = 1, attempts do
		local success, result = pcall(function()
			return HttpService:RequestAsync({
				Url = url,
				Method = "GET",
				Headers = {
					["Authorization"] = "Bearer " .. apiKey,
					["Content-Type"] = "application/json",
				},
			})
		end)

		if success and result.Success then
			local data = HttpService:JSONDecode(result.Body)
			return true, data
		end

		if attempt < attempts then
			warn(`[GoatAnalytics:Config] Fetch failed (attempt {attempt}/{attempts}), retrying in {RETRY_DELAY}s`)
			task.wait(RETRY_DELAY)
		else
			warn(`[GoatAnalytics:Config] Fetch failed after {attempts} attempts`)
			if success then
				warn(`[GoatAnalytics:Config] HTTP {result.StatusCode}: {result.Body}`)
			else
				warn(`[GoatAnalytics:Config] Error: {tostring(result)}`)
			end
		end
	end

	return false, nil
end

--[[
    Initialize remote config.
    @param analyticsRef — Initialized ServerAnalytics instance
    @param options — { gameId: string, apiKey: string, endpoint?: string, refreshInterval?: number }
]]
function RemoteConfig:init(options: {gameId: string, apiKey: string, endpoint: string?, refreshInterval: number?})
	if initialized then
		warn("[GoatAnalytics:Config] Already initialized")
		return
	end

	assert(options.gameId and #options.gameId > 0, "[GoatAnalytics:Config] gameId required")
	assert(options.apiKey and #options.apiKey > 0, "[GoatAnalytics:Config] apiKey required")

	gameId = options.gameId
	apiKey = options.apiKey

	-- Build API endpoint: base URL + /api/games/:gameId/configs/serve
	local baseUrl = options.endpoint or Config.DEFAULT.API_ENDPOINT
	-- Strip /v1/ingest from ingestion URL to get base, or use dashboard API URL
	apiEndpoint = baseUrl:gsub("/v1/ingest$", "") .. "/api/games/" .. gameId .. "/configs/serve"

	CACHE_TTL = options.refreshInterval or 60

	-- Initial fetch
	self:refresh()

	-- Background refresh loop
	task.spawn(function()
		while true do
			task.wait(CACHE_TTL)
			self:refresh()
		end
	end)

	initialized = true
	print(`[GoatAnalytics:Config] Remote config initialized (gameId: {gameId}, refresh: {CACHE_TTL}s)`)
end

--[[
    Fetch latest config from server. Non-blocking after first call.
]]
function RemoteConfig:refresh()
	local url = apiEndpoint .. "?env=prod"
	local success, data = makeRequest(url)

	if success and data then
		baseConfig = data.config or {}
		configVersion = data.version or 0
		lastFetchTime = os.time()
	end
end

--[[
    Get a config value. Returns cached value, never yields.
    @param key — Config key
    @param default — Default value if key not found
    @return The config value
]]
function RemoteConfig:get(key: string, default: any?): any
	if baseConfig[key] ~= nil then
		return baseConfig[key]
	end
	return default
end

--[[
    Get the full config object.
    @return Config table
]]
function RemoteConfig:getAll(): {[string]: any}
	return baseConfig
end

--[[
    Get config version.
    @return Current version number
]]
function RemoteConfig:getVersion(): number
	return configVersion
end

--[[
    Get player-specific config with A/B test overlays applied.
    Fetches from server with userId for deterministic assignment.
    Results are cached per player.
    
    @param player — The player
    @return { config: table, abAssignments: table, version: number }
]]
function RemoteConfig:getForPlayer(player: Player): {config: {[string]: any}, abAssignments: {[string]: any}, version: number}
	local userId = player.UserId
	local cached = playerConfigs[userId]

	-- Return cache if fresh
	if cached and (os.time() - cached.fetchedAt) < PLAYER_CACHE_TTL then
		return {
			config = cached.config,
			abAssignments = cached.abAssignments,
			version = configVersion,
		}
	end

	-- Fetch player-specific config
	local url = apiEndpoint .. "?env=prod&userId=" .. tostring(userId)
	local success, data = makeRequest(url, 2)  -- fewer retries for per-player

	if success and data then
		local entry = {
			config = data.config or baseConfig,
			abAssignments = data.abAssignments or {},
			fetchedAt = os.time(),
		}
		playerConfigs[userId] = entry

		return {
			config = entry.config,
			abAssignments = entry.abAssignments,
			version = data.version or configVersion,
		}
	end

	-- Fallback to base config
	return {
		config = baseConfig,
		abAssignments = {},
		version = configVersion,
	}
end

--[[
    Get A/B test group assignment for a player.
    @param player — The player
    @param testName — Name of the A/B test
    @return { group: string, enrolled: boolean }
]]
function RemoteConfig:getABGroup(player: Player, testName: string): {group: string, enrolled: boolean}
	local playerData = self:getForPlayer(player)
	local assignment = playerData.abAssignments[testName]

	if assignment then
		return assignment
	end

	-- Not in any test
	return { group = "control", enrolled = false }
end

-- Clean up player cache on leave
function RemoteConfig:_onPlayerLeaving(userId: number)
	task.delay(10, function()
		playerConfigs[userId] = nil
	end)
end

return RemoteConfig
