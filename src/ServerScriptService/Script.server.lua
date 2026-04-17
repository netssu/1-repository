local MarketplaceService = game:GetService("MarketplaceService")
local PurchaseHandler = require(game.ServerStorage.ServerModules.Market)


MarketplaceService.ProcessReceipt = PurchaseHandler.ProcessReceipt