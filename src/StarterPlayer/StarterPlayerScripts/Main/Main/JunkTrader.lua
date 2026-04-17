local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replicatedStorage = game:GetService("ReplicatedStorage")

local zone = require(replicatedStorage.Modules.Zone)
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)


local localPlayer = game.Players.LocalPlayer

local HitboxPart = workspace:WaitForChild("JunkTrader"):WaitForChild('Hitbox')

local zoneHitbox = zone.fromRegion(HitboxPart.CFrame, HitboxPart.Size)

zoneHitbox.playerEntered:Connect(function(player: Player)
	if player == localPlayer then
		UIHandler.DisableAllButtons({'Exp_Frame','Units_Bar',"Currency","Level","SummonFrame"})
		_G.CloseAll("JunkTraderFrame")

		local isInside = Instance.new("Accessory")
		isInside.Name = "IsInside"
		isInside.Parent = player --[[
			Prob better way to do this, 
			but the framework is so fucked I don't wanna find it, this is good enough (all on client anyway.)
		--]]
	end
end)

zoneHitbox.playerExited:Connect(function(player: Player)
	if player == localPlayer then
		UIHandler.EnableAllButtons()
		_G.CloseAll()

		local isInside = player:FindFirstChild("IsInside")
		if isInside then isInside:Destroy() end
	end
end)


return {}