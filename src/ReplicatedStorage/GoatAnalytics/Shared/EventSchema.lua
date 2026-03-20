--[[
    GoatAnalytics SDK - Event Schema Validation
    Validates event payloads by type. Returns (true, nil) or (false, errorMessage).
]]

local Types = require(script.Parent.Types)
local Config = require(script.Parent.Config)

local EventSchema = {}

-- Validate custom properties table
local function validateProperties(properties: {[string]: any}): (boolean, string?)
	if properties == nil then
		return true, nil
	end

	if typeof(properties) ~= "table" then
		return false, "properties must be a table"
	end

	local count = 0
	for key, value in properties do
		count += 1
		if count > Config.DEFAULT.MAX_PROPERTIES then
			return false, `too many properties (max {Config.DEFAULT.MAX_PROPERTIES})`
		end

		if typeof(key) ~= "string" then
			return false, "property keys must be strings"
		end

		if #key > Config.DEFAULT.MAX_PROPERTY_KEY_LENGTH then
			return false, `property key too long: "{key}" (max {Config.DEFAULT.MAX_PROPERTY_KEY_LENGTH})`
		end

		if typeof(value) == "string" and #value > Config.DEFAULT.MAX_PROPERTY_VALUE_LENGTH then
			return false, `property value too long for key "{key}" (max {Config.DEFAULT.MAX_PROPERTY_VALUE_LENGTH})`
		end
	end

	return true, nil
end

-- Type-specific validators
local validators: {[string]: (properties: {[string]: any}) -> (boolean, string?)} = {
	[Types.EventType.SESSION_START] = function(props)
		return true, nil
	end,

	[Types.EventType.SESSION_END] = function(props)
		if typeof(props.sessionDuration) ~= "number" then
			return false, "session_end requires sessionDuration (number)"
		end
		if props.sessionDuration < 0 then
			return false, "sessionDuration must be non-negative"
		end
		return true, nil
	end,

	[Types.EventType.CUSTOM] = function(props)
		if typeof(props.eventName) ~= "string" or #props.eventName == 0 then
			return false, "custom_event requires eventName (non-empty string)"
		end
		return true, nil
	end,

	[Types.EventType.PROGRESSION] = function(props)
		if not Types._validProgressionStatuses[props.status] then
			return false, "progression_event requires status (start/complete/fail)"
		end
		if typeof(props.level) ~= "string" or #props.level == 0 then
			return false, "progression_event requires level (non-empty string)"
		end
		if props.score ~= nil and typeof(props.score) ~= "number" then
			return false, "progression_event score must be a number"
		end
		return true, nil
	end,

	[Types.EventType.ECONOMY] = function(props)
		if not Types._validEconomyFlows[props.flow] then
			return false, "economy_event requires flow (source/sink)"
		end
		if typeof(props.currency) ~= "string" or #props.currency == 0 then
			return false, "economy_event requires currency (non-empty string)"
		end
		if typeof(props.amount) ~= "number" then
			return false, "economy_event requires amount (number)"
		end
		if props.itemId ~= nil and typeof(props.itemId) ~= "string" then
			return false, "economy_event itemId must be a string"
		end
		return true, nil
	end,

	[Types.EventType.INTERACTION] = function(props)
		if typeof(props.action) ~= "string" or #props.action == 0 then
			return false, "interaction_event requires action (non-empty string)"
		end
		if props.target ~= nil and typeof(props.target) ~= "string" then
			return false, "interaction_event target must be a string"
		end
		if props.value ~= nil and typeof(props.value) ~= "number" then
			return false, "interaction_event value must be a number"
		end
		return true, nil
	end,

	[Types.EventType.BUSINESS] = function(props)
		if not Types._validBusinessTypes[props.businessType] then
			return false, "business_event requires businessType (gamepass/dev_product/premium)"
		end
		if typeof(props.productId) ~= "string" or #props.productId == 0 then
			return false, "business_event requires productId (non-empty string)"
		end
		if typeof(props.amount) ~= "number" then
			return false, "business_event requires amount (number, Robux)"
		end
		return true, nil
	end,
}

-- Validate an event payload
-- @param eventType: The event type string
-- @param properties: The event properties table
-- @return success (boolean), errorMessage (string?)
function EventSchema.validate(eventType: string, properties: {[string]: any}): (boolean, string?)
	if typeof(eventType) ~= "string" or not Types._validEventTypes[eventType] then
		return false, `invalid eventType: "{tostring(eventType)}"`
	end

	if properties ~= nil and typeof(properties) ~= "table" then
		return false, "properties must be a table or nil"
	end

	local props = properties or {}

	-- Validate custom properties
	local propsOk, propsErr = validateProperties(props)
	if not propsOk then
		return false, propsErr
	end

	-- Run type-specific validation
	local validator = validators[eventType]
	if validator then
		return validator(props)
	end

	return true, nil
end

return EventSchema
