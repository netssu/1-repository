--[[
    GoatAnalytics SDK - Shared Types
    Event type constants and type definitions used by both client and server.
]]

local Types = {}

-- Core event types supported by the SDK
Types.EventType = {
	SESSION_START = "session_start",
	SESSION_END = "session_end",
	CUSTOM = "custom_event",
	PROGRESSION = "progression_event",
	ECONOMY = "economy_event",
	INTERACTION = "interaction_event",
	BUSINESS = "business_event",
}

-- Progression status values
Types.ProgressionStatus = {
	START = "start",
	COMPLETE = "complete",
	FAIL = "fail",
}

-- Economy flow direction
Types.EconomyFlow = {
	SOURCE = "source", -- currency earned
	SINK = "sink",     -- currency spent
}

-- Business transaction types
Types.BusinessType = {
	GAMEPASS = "gamepass",
	DEV_PRODUCT = "dev_product",
	PREMIUM = "premium",
}

-- Reverse lookup tables for validation
Types._validEventTypes = {}
for _, v in Types.EventType do
	Types._validEventTypes[v] = true
end

Types._validProgressionStatuses = {}
for _, v in Types.ProgressionStatus do
	Types._validProgressionStatuses[v] = true
end

Types._validEconomyFlows = {}
for _, v in Types.EconomyFlow do
	Types._validEconomyFlows[v] = true
end

Types._validBusinessTypes = {}
for _, v in Types.BusinessType do
	Types._validBusinessTypes[v] = true
end

return Types
