--[[
    GoatAnalytics SDK - Server Analytics
    Main server module. Initializes the SDK, receives client events via RemoteEvent,
    validates, enriches, and batches them for the API.

    Usage (in a server Script):
        local Analytics = require(path.to.GoatAnalytics)

        Analytics:init({
            appId = "your-app-id",
            apiKey = "your-api-key",
        })

        -- Server-side tracking:
        Analytics:track(player, "custom_event", { eventName = "npc_killed", npcType = "boss" })
        Analytics:trackEconomy(player, "source", "gold", 100, "quest_reward")
        Analytics:trackProgression(player, "complete", "level_5", 2500)
        Analytics:trackBusiness(player, "gamepass", "12345678", 299)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Types = require(script.Parent.Parent.Shared.Types)
local EventSchema = require(script.Parent.Parent.Shared.EventSchema)
local Config = require(script.Parent.Parent.Shared.Config)
local BatchQueue = require(script.Parent.BatchQueue)
local PlayerTracker = require(script.Parent.PlayerTracker)
local EconomyTracker = require(script.Parent.EconomyTracker)

local ServerAnalytics = {}
ServerAnalytics.__index = ServerAnalytics

-- State
local initialized = false
local appId: string = ""
local batchQueue: any = nil
local remoteEvent: RemoteEvent? = nil

-- Per-player state
local playerSessions: {[number]: string} = {} -- UserId → sessionId
local playerRateLimits: {[number]: {timestamps: {number}}} = {}

-- Rate limiting: max 30 events/second per player (server-side)
local SERVER_RATE_LIMIT = 30
local RATE_WINDOW = 1

local function checkServerRateLimit(userId: number): boolean
	local now = os.clock()
	local data = playerRateLimits[userId]
	if not data then
		data = { timestamps = {} }
		playerRateLimits[userId] = data
	end

	-- Prune old timestamps
	while #data.timestamps > 0 and data.timestamps[1] < now - RATE_WINDOW do
		table.remove(data.timestamps, 1)
	end

	if #data.timestamps >= SERVER_RATE_LIMIT then
		return false
	end

	table.insert(data.timestamps, now)
	return true
end

-- Get or create a session ID for a player
local function getSessionId(userId: number): string
	if not playerSessions[userId] then
		playerSessions[userId] = HttpService:GenerateGUID(false)
	end
	return playerSessions[userId]
end

-- Enrich and queue a validated event
local function enqueueEvent(userId: number, eventType: string, properties: {[string]: any})
	if not batchQueue then
		return
	end

	local sessionId = getSessionId(userId)

	batchQueue:add({
		eventType = eventType,
		eventId = HttpService:GenerateGUID(false),
		timestamp = os.time() * 1000,
		properties = properties,
		userId = tostring(userId),
		sessionId = sessionId,
	})
end

-- Create RemoteEvent for device reporting
local deviceRemote = Instance.new("RemoteEvent")
deviceRemote.Name = "GoatAnalyticsDeviceReport"
deviceRemote.Parent = ReplicatedStorage

deviceRemote.OnServerEvent:Connect(function(player: Player, device: string)
	if typeof(device) ~= "string" or #device > 32 then
		return
	end
	PlayerTracker:setPlayerDevice(player, device)
end)

-- Handle incoming client events via RemoteEvent
local function onClientEvent(player: Player, payload: any)
	if not initialized then
		return
	end
	
	if Config.CLIENT_EVENTS_DISABLED then
		return
	end

	-- Validate sender is a real player
	if not player or not player:IsA("Player") then
		warn("[GoatAnalytics] Received event from non-player, ignoring")
		return
	end

	-- Validate payload structure
	if typeof(payload) ~= "table" then
		warn(`[GoatAnalytics] Invalid payload from {player.Name}`)
		return
	end

	local eventType = payload.eventType
	local properties = payload.properties

	-- Rate limit per player
	if not checkServerRateLimit(player.UserId) then
		warn(`[GoatAnalytics] Rate limit exceeded for {player.Name} — event dropped`)
		return
	end

	-- Validate event schema
	local valid, err = EventSchema.validate(eventType, properties)
	if not valid then
		warn(`[GoatAnalytics] Invalid event from {player.Name}: {err}`)
		return
	end

	enqueueEvent(player.UserId, eventType, properties or {})
end

--[[
    Initialize the SDK. Must be called once from a server Script.
    @param config — { appId: string, apiKey: string, options?: table }
]]
function ServerAnalytics:init(config: {appId: string, apiKey: string, options: {[string]: any}?})
	if initialized then
		warn("[GoatAnalytics] Already initialized")
		return
	end

	assert(config.appId and #config.appId > 0, "[GoatAnalytics] appId is required")
	assert(config.apiKey and #config.apiKey > 0, "[GoatAnalytics] apiKey is required")

	appId = config.appId
	local options = config.options or {}

	-- Create RemoteEvent for client → server communication
	remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = "GoatAnalyticsEvent"
	remoteEvent.Parent = ReplicatedStorage

	-- Initialize batch queue
	batchQueue = BatchQueue.new({
		appId = appId,
		apiKey = config.apiKey,
		endpoint = options.endpoint,
		batchSize = options.batchSize,
		flushInterval = options.flushInterval,
		maxQueueSize = options.maxQueueSize,
	})
	batchQueue:start()

	-- Listen for client events
	remoteEvent.OnServerEvent:Connect(onClientEvent)

	-- Initialize auto-trackers
	PlayerTracker._init(ServerAnalytics)
	EconomyTracker._init(ServerAnalytics)

	initialized = true
	print(`[GoatAnalytics] SDK initialized (appId: {appId}, v{Config.DEFAULT.SDK_VERSION})`)
end

--[[
    Track a generic event from the server.
    @param player — The player to associate the event with
    @param eventType — One of Types.EventType values
    @param properties — Event properties
]]
function ServerAnalytics:track(player: Player, eventType: string, properties: {[string]: any}?)
	if not initialized then
		warn("[GoatAnalytics] SDK not initialized")
		return
	end

	local props = properties or {}

	local valid, err = EventSchema.validate(eventType, props)
	if not valid then
		warn(`[GoatAnalytics] Invalid event: {err}`)
		return
	end

	if not checkServerRateLimit(player.UserId) then
		warn(`[GoatAnalytics] Rate limit exceeded for {player.Name}`)
		return
	end

	enqueueEvent(player.UserId, eventType, props)
end

--[[
    Track an economy event.
    @param player — The player
    @param flow — "source" (earned) or "sink" (spent)
    @param currency — Currency name (e.g. "gold", "gems")
    @param amount — Amount of currency
    @param itemId — Optional item identifier
]]
function ServerAnalytics:trackEconomy(player: Player, flow: string, currency: string, amount: number, source: string?, itemId: string?)
	self:track(player, Types.EventType.ECONOMY, {
		flow = flow,
		currency = currency,
		amount = amount,
		source = source,
		itemId = itemId,
	})
end

--[[
    Track a progression event.
    @param player — The player
    @param status — "start", "complete", or "fail"
    @param level — Level/stage identifier
    @param score — Optional score
]]
function ServerAnalytics:trackProgression(player: Player, status: string, level: string, score: number?)
	self:track(player, Types.EventType.PROGRESSION, {
		status = status,
		level = level,
		score = score,
	})
end

--[[
    Track a business/purchase event.
    @param player — The player
    @param businessType — "gamepass", "dev_product", or "premium"
    @param productId — The product identifier
    @param amount — Robux amount
]]
function ServerAnalytics:trackBusiness(player: Player, businessType: string, productId: string, amount: number)
	self:track(player, Types.EventType.BUSINESS, {
		businessType = businessType,
		productId = productId,
		amount = amount,
	})
end

-- Get session ID for a player (used by PlayerTracker)
function ServerAnalytics:getSessionId(player: Player): string
	return getSessionId(player.UserId)
end

-- Clean up player state on leave
function ServerAnalytics:_onPlayerLeaving(userId: number)
	task.delay(5, function()
		playerSessions[userId] = nil
		playerRateLimits[userId] = nil
	end)
end

-- Shutdown: flush remaining events
function ServerAnalytics:shutdown()
	if batchQueue then
		batchQueue:stop()
	end
	initialized = false
end

return ServerAnalytics
