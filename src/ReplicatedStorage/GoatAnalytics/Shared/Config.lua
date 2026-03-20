--[[
    GoatAnalytics SDK - Shared Configuration
    Default settings for the SDK. Override via ServerAnalytics.init() options.
]]

local Config = {}

Config.DEFAULT = {
	API_ENDPOINT = "https://ingest.kuzugaming.com/v1/ingest",
	BATCH_SIZE = 50,                  -- events per batch before auto-flush
	FLUSH_INTERVAL = 10,              -- seconds between periodic flushes
	MAX_QUEUE_SIZE = 1000,            -- max queued events before dropping oldest
	SESSION_HEARTBEAT = 60,           -- seconds between client heartbeats
	SDK_VERSION = "1.0.1",
	MAX_PROPERTIES = 50,              -- max custom properties per event
	MAX_PROPERTY_KEY_LENGTH = 64,
	MAX_PROPERTY_VALUE_LENGTH = 256,
	CLIENT_EVENTS_DISABLED = true,
}

return Config
