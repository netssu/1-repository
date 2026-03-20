local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

PhysicsService:RegisterCollisionGroup("Players")
PhysicsService:RegisterCollisionGroup("RockDebris")
PhysicsService:CollisionGroupSetCollidable("Players", "RockDebris", false)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAppearanceLoaded:Connect(function(character)
		for i, v in pairs(character:GetChildren()) do
			if v:IsA("BasePart") or v:IsA("MeshPart") then
				v.CollisionGroup = "Players"
			end
		end
	end)
end)
-- Written by @LxckyDev