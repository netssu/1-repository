--[[
    GoatAnalytics SDK - Device Reporter (Client)
    Detects the player's device/platform and reports it to the server.
    
    Usage: Automatically runs when required. Or manually:
        local DeviceReporter = require(path.to.GoatAnalytics.Client.DeviceReporter)
        -- auto-reports on require
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DeviceReporter = {}

local function detectDevice(): string
	-- Check touch first (mobile/tablet)
	if UserInputService.TouchEnabled then
		-- Distinguish phone vs tablet by screen size
		local viewportSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
		if viewportSize then
			local minDim = math.min(viewportSize.X, viewportSize.Y)
			if minDim >= 600 then
				return "tablet"
			end
		end
		return "mobile"
	end

	-- Check for gamepad (console)
	if UserInputService.GamepadEnabled then
		-- Could be console or PC with controller
		-- GuiService:IsTenFootInterface() is true on consoles (Xbox)
		if GuiService:IsTenFootInterface() then
			return "console"
		end
		return "pc_gamepad"
	end

	-- Check for keyboard/mouse (PC)
	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		return "pc"
	end

	-- VR
	if UserInputService.VREnabled then
		return "vr"
	end

	return "unknown"
end

-- Report to server via a dedicated RemoteEvent
local function report()
	local device = detectDevice()

	-- Wait for the analytics remote
	local remote = ReplicatedStorage:WaitForChild("GoatAnalyticsDeviceReport", 10)
	if not remote then
		-- Fallback: use the main analytics remote with a custom event
		remote = ReplicatedStorage:WaitForChild("GoatAnalyticsEvent", 10)
		if remote then
			remote:FireServer({
				eventType = "custom_event",
				properties = {
					eventName = "_sdk_device_report",
					device = device,
				},
				clientTimestamp = tick(),
			})
		end
		return
	end

	remote:FireServer(device)
end

-- Auto-report on require
task.spawn(report)

DeviceReporter.detectDevice = detectDevice

return DeviceReporter