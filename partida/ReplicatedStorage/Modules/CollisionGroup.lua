local PhysicsService = game:GetService("PhysicsService")

local module = {}
module.__index = module

function module.new()
	local self = setmetatable({},module)

	if game["Run Service"]:IsServer() then
		PhysicsService:RegisterCollisionGroup("Tower")
		PhysicsService:CollisionGroupSetCollidable("Tower","Tower",false)	--Cuase tower to not be able to collide to anything
		
		PhysicsService:RegisterCollisionGroup("Player")
		PhysicsService:CollisionGroupSetCollidable("Player","Player",false)

		
	end

	return self
end

function module:SetModel(model,GroupName)
	for _,object in model:GetDescendants() do
		if not object:IsA("BasePart") then continue end
		object.CollisionGroup = GroupName
	end
end

return module.new()
