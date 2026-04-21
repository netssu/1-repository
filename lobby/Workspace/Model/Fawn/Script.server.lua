local ServerStorage = game:GetService("ServerStorage")
local Humanoid = script.Parent.Humanoid
local Animation = script.Parent.Animations.Idle

local track = Humanoid:LoadAnimation(Animation)
track.Looped = true
track:Play()

local Market = require(ServerStorage.ServerModules.Market)


script.Parent.HumanoidRootPart.ProximityPrompt.Triggered:Connect(function(plr)
	Market.Buy(plr, 3337720767)	
end)