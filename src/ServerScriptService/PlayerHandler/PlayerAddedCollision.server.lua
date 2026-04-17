--!strict

local Players : Players = game:GetService('Players')
local CollisionName = 'Player'

--

local SetCollision = function( Character : Model )
	for __ , BasePart : BasePart in Character:GetChildren() do
		if not BasePart:IsA('BasePart') then
			continue
		end
		BasePart.CollisionGroup = CollisionName
	end
end

local OnAdded = function( Player : Player )
	Player.CharacterAdded:Connect( SetCollision )
	SetCollision( Player.Character or Player.CharacterAdded:Wait() )
end

Players.PlayerAdded:Connect( OnAdded )
for __ , Player : Player in Players:GetPlayers() do
	OnAdded( Player )
end