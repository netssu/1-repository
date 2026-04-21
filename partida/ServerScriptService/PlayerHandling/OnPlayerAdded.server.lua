local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
--local GameSpeed = workspace.Info.GameSpeed

local topVal = 1

Players.PlayerAdded:Connect(function(player)
	
	local Money = Instance.new("IntValue")
	Money.Name = "Money"
	Money.Value = 0
	Money.Parent = player

	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Parent = player

	local Damage = Instance.new("IntValue")
	Damage.Name = "Damage"
	Damage.Parent = player
	
	local placedTowers = Instance.new("IntValue")
	placedTowers.Name = "PlacedTowers"
	placedTowers.Value = 0
	placedTowers.Parent = player
	
	player.CharacterAppearanceLoaded:Connect(function(character)
		for i, object in character:GetDescendants() do
			if object:IsA("BasePart") then
				PhysicsService:SetPartCollisionGroup(object, "Player")
			end
		end
	end)
	
	repeat task.wait() until not player.Parent or player:FindFirstChild('DataLoaded')
    
    local speedMultiplier = player.Speed.Value
    
	if speedMultiplier > topVal then
        topVal = speedMultiplier
	end
	
	local isMapLoaded = #workspace.Map:GetChildren()
	
	if isMapLoaded == 0 then
		workspace.Map.ChildAdded:Wait()
	end
	
	local mapFolder = workspace.Map:GetChildren()[1]
	
		
	local spawnLocation = mapFolder:FindFirstChildOfClass('SpawnLocation')
	print('found spawnlocation')
	
	if not spawnLocation then 
		warn('i no found')
		repeat 
			spawnLocation = mapFolder:FindFirstChildOfClass('SpawnLocation')
			task.wait()
		until spawnLocation
		
		warn('FOUND SPAWN LOCATION!!')
	end
	
	
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	
	player.Character:PivotTo(spawnLocation.CFrame * CFrame.new(Vector3.new(0,5,0)))
end)

Players.PlayerAdded:Wait()
repeat task.wait() until workspace.Info.GameRunning.Value


if workspace:FindFirstChild('Mobs') then

	local mobs = workspace:WaitForChild("Mobs")
	local info = workspace:WaitForChild("Info")
	local gameSpeed = info:WaitForChild("GameSpeed")

	local function updateMobSpeed(mob)
		local humanoid = mob:FindFirstChild("Humanoid")
		local originalSpeed = mob:FindFirstChild("OriginalSpeed")
		if humanoid and originalSpeed then
			humanoid.WalkSpeed = originalSpeed.Value * gameSpeed.Value
		end
	end

	for _, mob in mobs:GetChildren() do
		updateMobSpeed(mob)
	end

	gameSpeed:GetPropertyChangedSignal("Value"):Connect(function()
		for _, mob in mobs:GetChildren() do
			updateMobSpeed(mob)
		end
	end)

	mobs.ChildAdded:Connect(function(child)
		child:WaitForChild("Humanoid")
		child:WaitForChild("OriginalSpeed")
		updateMobSpeed(child)
	end)
else
	-- we are running comp or versus so 3x/2x speed wont affect it :)
end