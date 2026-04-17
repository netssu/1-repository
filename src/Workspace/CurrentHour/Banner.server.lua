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

			local mythicals = chanceModule.updateBanner()

			for i, v in pairs(mythicals) do
				script.Parent:SetAttribute("Mythical" .. tostring(i), v)
			end
		end
		
	end
end


ErrorCatcher.wrap(main)