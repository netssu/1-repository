--[[
    GoatAnalytics SDK - Economy Tracker
    Helper methods for tracking currency flow, gamepasses, and dev product purchases.
    Initialized by ServerAnalytics — use via the ServerAnalytics API or directly.

    Usage (server-side):
        local EconomyTracker = require(path.to.GoatAnalytics.Server.EconomyTracker)
        EconomyTracker:currencyEarned(player, "gold", 100, "quest_reward")
        EconomyTracker:currencySpent(player, "gold", 50, "sword_purchase")
        EconomyTracker:gamepassPurchased(player, "12345678", 299)
]]

local Types = require(script.Parent.Parent.Shared.Types)

local EconomyTracker = {}

local serverAnalytics: any = nil

-- Initialize (called by ServerAnalytics)
function EconomyTracker._init(analytics: any)
	serverAnalytics = analytics
end

--[[
    Track currency earned by a player.
    @param player — The player who earned currency
    @param currency — Currency name (e.g. "gold", "gems")
    @param amount — Amount earned
    @param source — Where it came from (e.g. "quest_reward", "enemy_drop")
]]
function EconomyTracker:currencyEarned(player: Player, currency: string, amount: number, source: string?, itemId: string)
	serverAnalytics:trackEconomy(player, Types.EconomyFlow.SOURCE, currency, amount, source, itemId)
end

--[[
    Track currency spent by a player.
    @param player — The player who spent currency
    @param currency — Currency name
    @param amount — Amount spent
    @param itemId — What they bought (optional)
]]
function EconomyTracker:currencySpent(player: Player, currency: string, amount: number, source: string?, itemId: string)
	serverAnalytics:trackEconomy(player, Types.EconomyFlow.SINK, currency, amount, source, itemId)
end

--[[
    Track a gamepass purchase.
    @param player — The player who bought the gamepass
    @param gamepassId — The gamepass ID (as string)
    @param robuxAmount — Price in Robux
]]
function EconomyTracker:gamepassPurchased(player: Player, gamepassId: string, robuxAmount: number)
	serverAnalytics:trackBusiness(player, Types.BusinessType.GAMEPASS, gamepassId, robuxAmount)
end

--[[
    Track a developer product purchase.
    @param player — The player who bought the product
    @param productId — The developer product ID (as string)
    @param robuxAmount — Price in Robux
]]
function EconomyTracker:devProductPurchased(player: Player, productId: string, robuxAmount: number)
	serverAnalytics:trackBusiness(player, Types.BusinessType.DEV_PRODUCT, productId, robuxAmount)
end

return EconomyTracker
