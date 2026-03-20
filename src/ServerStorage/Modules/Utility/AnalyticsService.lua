------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//VARIABLES
local GoatAnalytics = require(ReplicatedStorage:WaitForChild("GoatAnalytics"))
local EconomyTracker = require(ReplicatedStorage.GoatAnalytics.Server:WaitForChild("EconomyTracker"))
local SharedConfig = require(ReplicatedStorage.GoatAnalytics.Shared:WaitForChild("Config"))

local initialized: boolean = false

------------------//FUNCTIONS
local function ensure_config_bridge(): ()
	SharedConfig.CLIENT_EVENTS_DISABLED = SharedConfig.DEFAULT.CLIENT_EVENTS_DISABLED
end

local function safe_call(fn: () -> ()): ()
	local ok, err = pcall(fn)
	if not ok then
		warn(err)
	end
end

------------------//MAIN FUNCTIONS
local AnalyticsService = {}

function AnalyticsService.init(appId: string, apiKey: string): ()
	if initialized then
		return
	end

	ensure_config_bridge()

	GoatAnalytics:init({
		appId = appId,
		apiKey = apiKey,
		options = {
			batchSize = 50,
			flushInterval = 10,
		},
	})

	initialized = true
end

function AnalyticsService.coins_earned(player: Player, amount: number, source: string, props: {[string]: any}?): ()
	if not initialized then
		return
	end

	safe_call(function()
		EconomyTracker:currencyEarned(player, "coins", amount, source, nil)
	end)

	if props then
		props.eventName = "coins_earned"
		props.amount = amount
		props.source = source

		safe_call(function()
			GoatAnalytics:track(player, "custom_event", props)
		end)
	end
end

function AnalyticsService.pogo_jump(player: Player, worldId: number, floorMult: number, impactForce: number): ()
	if not initialized then
		return
	end

	safe_call(function()
		GoatAnalytics:track(player, "custom_event", {
			eventName = "pogo_jump",
			worldId = worldId,
			floorMult = floorMult,
			impactForce = impactForce,
		})
	end)
end

function AnalyticsService.pogo_rebound(player: Player, worldId: number, combo: number, isCritical: boolean, floorMult: number, impactForce: number): ()
	if not initialized then
		return
	end

	safe_call(function()
		GoatAnalytics:track(player, "custom_event", {
			eventName = "pogo_rebound",
			worldId = worldId,
			combo = combo,
			isCritical = isCritical,
			floorMult = floorMult,
			impactForce = impactForce,
		})
	end)
end

function AnalyticsService.pogo_land(player: Player, worldId: number, status: string): ()
	if not initialized then
		return
	end

	safe_call(function()
		GoatAnalytics:track(player, "custom_event", {
			eventName = "pogo_land",
			worldId = worldId,
			status = status,
		})
	end)
end

return AnalyticsService