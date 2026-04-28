local ServerStorage = game:GetService('ServerStorage')
local ErrorCatcher = require(ServerStorage.ServerModules.ErrorService)
local chanceModule = require(game.ReplicatedStorage.Chances)

local function main()
	while task.wait(1) do
		local currentTime = workspace:GetServerTimeNow()
		local lastUpdateTime = script.Parent.Value or 0
		local mythics = {}

		if currentTime >= lastUpdateTime then
			local hourInterval = 3600/2 
			script.Parent.Value = currentTime + hourInterval

			local banners = chanceModule.updateBanner()

			for bannerIndex, mythicals in ipairs(banners) do
				for mythicalIndex, mythicalName in ipairs(mythicals) do
					script.Parent:SetAttribute(
						string.format("Banner%dMythical%d", bannerIndex, mythicalIndex),
						mythicalName
					)

					if bannerIndex == 1 then
						script.Parent:SetAttribute("Mythical" .. tostring(mythicalIndex), mythicalName)
					end
				end
			end
		end

	end
end


ErrorCatcher.wrap(main)
