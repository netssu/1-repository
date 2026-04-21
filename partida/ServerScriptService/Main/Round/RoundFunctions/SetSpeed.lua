local Info = workspace.Info
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Round = script.Parent.Parent
local Basic_mob_spawn_delay = 1
local Min_mob_spawn_delay = 1

local speedMultiplier = 1

local module = {}

ReplicatedStorage.Functions.SpeedRemote.OnServerInvoke = function(player,speed)
	if not Info.GameRunning.Value then return false, "Wait until the match has started!" end
	if Info.Versus.Value then return false, "Changing this setting is disabled in Versus" end

	if workspace.Info.OwnerId.Value ~= 0 and player.UserId ~= workspace.Info.OwnerId.Value then
		return false, `only host can change speed`
	end

	if workspace.Info.SpeedCD.Value == false then 
		workspace.Info.SpeedCD.Value = true 
		task.spawn(function()
			task.wait(3.2)
			workspace.Info.SpeedCD.Value = false
		end)
		if speedMultiplier == 1 then
			speedMultiplier = 1.5
		else
			if speedMultiplier == 1.5 and player.OwnGamePasses["2x Speed"].Value then
				speedMultiplier = 2 -- 2
			elseif (speedMultiplier == 1.5 or speedMultiplier == 2) and player.OwnGamePasses["3x Speed"].Value then
				speedMultiplier = 3
			else
				speedMultiplier = 1
			end
		end

		ReplicatedStorage.Events.ChangeSpeed:FireAllClients(`{speedMultiplier}x`, player)

		Round:SetAttribute('MobSpawnDelay', math.max(Min_mob_spawn_delay, Basic_mob_spawn_delay / speedMultiplier))

		if game["Run Service"]:IsStudio() then
			speedMultiplier = 30
		end

		workspace.Info.GameSpeed.Value = speedMultiplier

		if player:FindFirstChild('Speed') then
			player.Speed.Value = speedMultiplier
		end

		for _, v in workspace.Mobs:GetChildren() do 
			local humanoid = v:FindFirstChild("Humanoid")
			local originalSpeed = v:FindFirstChild("OriginalSpeed")

			if humanoid and originalSpeed then
				humanoid.WalkSpeed = originalSpeed.Value * workspace.Info.GameSpeed.Value
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
					humanoid.WalkSpeed = originalSpeed.Value * workspace.Info.GameSpeed.Value
				end
			end
		end


		return true
	end
end

return module
