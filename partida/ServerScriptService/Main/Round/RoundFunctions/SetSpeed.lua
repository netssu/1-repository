local Info = workspace.Info
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Round = script.Parent.Parent
local Basic_mob_spawn_delay = 1
local Min_mob_spawn_delay = 0.1

local speedMultiplier = 1

local module = {}

local function getCurrentSpeedMultiplier()
	local currentGameSpeed = workspace.Info.GameSpeed.Value
	if currentGameSpeed > 0 then
		return currentGameSpeed
	end

	return speedMultiplier
end

local function getAvailableSpeeds(player)
	return {1, 1.5, 2, 3, 5}
end

local function getNextSpeedMultiplier(player, currentSpeedMultiplier)
	local availableSpeeds = getAvailableSpeeds(player)
	local currentIndex = table.find(availableSpeeds, currentSpeedMultiplier)

	if not currentIndex then
		return availableSpeeds[1]
	end

	local nextIndex = currentIndex + 1

	if nextIndex > #availableSpeeds then
		nextIndex = 1
	end

	return availableSpeeds[nextIndex]
end

ReplicatedStorage.Functions.SpeedRemote.OnServerInvoke = function(player,speed)
	if not Info.GameRunning.Value then return false, "Wait until the match has started!" end
	if Info.Versus.Value then return false, "Changing this setting is disabled in Versus" end

	if workspace.Info.OwnerId.Value ~= 0 and player.UserId ~= workspace.Info.OwnerId.Value then
		return false, `only host can change speed`
	end

	if workspace.Info.SpeedCD.Value then
		return false, "Please Wait Before Changing Speed!"
	end

	workspace.Info.SpeedCD.Value = true
	task.spawn(function()
		task.wait(3.2)
		workspace.Info.SpeedCD.Value = false
	end)

	speedMultiplier = getNextSpeedMultiplier(player, getCurrentSpeedMultiplier())

	ReplicatedStorage.Events.ChangeSpeed:FireAllClients(`{speedMultiplier}x`, player)

	Round:SetAttribute('MobSpawnDelay', math.max(Min_mob_spawn_delay, Basic_mob_spawn_delay / speedMultiplier))

	workspace.Info.GameSpeed.Value = speedMultiplier

	if player:FindFirstChild('Speed') then
		player.Speed.Value = speedMultiplier
	end

	for _, v in workspace.Mobs:GetChildren() do
		local humanoid = v:FindFirstChild("Humanoid")
		local originalSpeed = v:FindFirstChild("OriginalSpeed")

		if humanoid and originalSpeed then
			humanoid.WalkSpeed = originalSpeed.Value * speedMultiplier
		end
	end

	for _, v in workspace.Spawnables:GetChildren() do
		local humanoid = v:FindFirstChild("Humanoid") :: Humanoid

		if humanoid then
			local originalSpeed = v:FindFirstChild("OriginalSpeed")
			if not originalSpeed then
				originalSpeed = Instance.new('NumberValue', v)
				originalSpeed.Name = 'OriginalSpeed'
				originalSpeed.Value = humanoid.WalkSpeed
			end

			if originalSpeed then
				humanoid.WalkSpeed = originalSpeed.Value * speedMultiplier
			end
		end
	end

	return true
end

return module
