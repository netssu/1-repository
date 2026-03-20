--[[
    GoatAnalytics SDK - Client Session Manager
    Tracks session lifecycle on the client: heartbeats, AFK detection.
    The server is the authority on sessions — this provides client-side signals.

    Usage (from a LocalScript, after requiring the main module):
        local SessionManager = require(path.to.GoatAnalytics.Client.SessionManager)
        SessionManager:start()
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Shared.Types)
local Config = require(script.Parent.Parent.Shared.Config)

local SessionManager = {}
SessionManager.__index = SessionManager

local AFK_TIMEOUT = 300 -- 5 minutes with no input → AFK
local isAFK = false
local lastInputTime = tick()
local started = false
local heartbeatConnection: RBXScriptConnection? = nil
local inputConnection: RBXScriptConnection? = nil

local remoteEvent: RemoteEvent? = nil

local function getRemoteEvent(): RemoteEvent?
	if remoteEvent then
		return remoteEvent
	end
	remoteEvent = ReplicatedStorage:WaitForChild("GoatAnalyticsEvent", 10) :: RemoteEvent?
	return remoteEvent
end

local function sendToServer(eventType: string, properties: {[string]: any}?)
	local remote = getRemoteEvent()
	if not remote then
		return
	end
	remote:FireServer({
		eventType = eventType,
		properties = properties or {},
		clientTimestamp = tick(),
	})
end

-- Track user input to detect AFK
local function onUserInput(_input: InputObject, _gameProcessed: boolean)
	lastInputTime = tick()
	if isAFK then
		isAFK = false
		sendToServer(Types.EventType.CUSTOM, {
			eventName = "_sdk_afk_return",
		})
	end
end

--[[
    Start the session manager.
    Call once from a LocalScript after the SDK is loaded.
]]
function SessionManager:start()
	if started then
		return
	end
	started = true

	task.delayh(2, function()
		-- Send initial session start signal to server
		sendToServer(Types.EventType.SESSION_START, {})
	end)

	-- Listen for user input (AFK detection)
	inputConnection = UserInputService.InputBegan:Connect(onUserInput)

	-- Periodic heartbeat + AFK check
	local lastHeartbeat = tick()
	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local now = tick()

		-- AFK detection
		if not isAFK and (now - lastInputTime) >= AFK_TIMEOUT then
			isAFK = true
			sendToServer(Types.EventType.CUSTOM, {
				eventName = "_sdk_afk_start",
			})
		end

		-- Periodic heartbeat
		if (now - lastHeartbeat) >= Config.DEFAULT.SESSION_HEARTBEAT then
			lastHeartbeat = now
			sendToServer(Types.EventType.CUSTOM, {
				eventName = "_sdk_heartbeat",
				isAFK = isAFK,
			})
		end
	end)
end

--[[
    Stop the session manager. Called automatically on player leaving.
]]
function SessionManager:stop()
	if not started then
		return
	end
	started = false

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

--[[
    Returns whether the player is currently AFK.
]]
function SessionManager:isPlayerAFK(): boolean
	return isAFK
end

return SessionManager
