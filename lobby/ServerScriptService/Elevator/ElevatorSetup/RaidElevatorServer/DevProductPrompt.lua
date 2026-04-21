local module = {}

local MarketPlaceService = game:GetService('MarketplaceService')

local plrs = {}
local id = 3263599604

function module.prompt(plr)
	if not plrs[plr] then
		plrs[plr] = true
		
		MarketPlaceService:PromptProductPurchase(plr, id)
		
		task.wait(3)
		plrs[plr] = nil
		
	end
end



return module