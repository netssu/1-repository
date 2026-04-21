local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")


local Info = workspace.Info
local BASIC_MOB_SPAWN_DELAY = 1
local MIN_MOB_SPAWN_DELAY = 1
--local GameStarted = Info.GameRunning

--if not GameStarted.Value then
--GameStarted:GetPropertyChangedSignal('Value'):Wait()
--end

--if not Info.Versus.Value then return {} end
repeat task.wait(1) until Info.Versus.Value 

local Wave = Info.Wave

-- ramp up speed based on wave
local speed = 1
local function adjustSpeed(speedMultiplier)
	local randomPlayer = Players:GetChildren()[1]

	workspace.Info.GameSpeed.Value = speedMultiplier
	ReplicatedStorage.Events.ChangeSpeed:FireAllClients(`{speedMultiplier}x`, randomPlayer)
	script:SetAttribute('MobSpawnDelay', math.max(MIN_MOB_SPAWN_DELAY, BASIC_MOB_SPAWN_DELAY / speedMultiplier))
	for _, player in ipairs(Players:GetPlayers()) do
		if player:FindFirstChild('Speed') then
			player.Speed.Value = speedMultiplier
		end
	end
end
function round2(n)
	return math.floor(n * 100 + 0.5) / 100
end

warn('CONNECTED!')

Wave.Changed:Connect(function()
	speed = round2(1 + ((Wave.Value / 50) * 3))

	adjustSpeed(speed)
end)

return {}
