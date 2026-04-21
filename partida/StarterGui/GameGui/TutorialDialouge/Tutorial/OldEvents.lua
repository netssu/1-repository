--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--// Player
local player = Players.LocalPlayer
local gameGui = player:WaitForChild("PlayerGui"):WaitForChild("GameGui")

--// Modules
local upgradesModule = require(ReplicatedStorage:WaitForChild("Upgrades"))

--// Workspace Folders
local info = workspace:WaitForChild("Info")
local wave = info:WaitForChild("Wave")
local towers = workspace:WaitForChild("Towers")

--// Internal State
local towersPlaced = {}
local states = {
	UpgradedEarly = false,
	PlacedTower = false
}

--// Connections
local connections = {}

--// Helper: Clean up connection safely
local function disconnect(conn)
	if conn and conn.Disconnect then
		pcall(function() conn:Disconnect() end)
	end
end

--// Helper: Track new tower
local function childAdded(tower)
	if towersPlaced[tower] then return end
	local config = tower:FindFirstChild("Config")
	if not config then return end
	local owner = config:FindFirstChild("Owner")
	if not owner or owner.Value ~= player.Name then return end

	warn("Tower added: " .. tower.Name)

	local conn = config.Upgrades.Changed:Connect(function()
		local tracked = towersPlaced[tower]
		if not tracked then return end
		tracked.Upgraded = true
		disconnect(tracked.Connection)
		tracked.Connection = nil
		warn("Tower upgraded.")
	end)

	towersPlaced[tower] = {
		Object = tower,
		Owner = player,
		Upgraded = false,
		Checked = false,
		Connection = conn
	}
end

--// Helper: Handle tower removal
local function childRemoved(tower)
	local data = towersPlaced[tower]
	if data then
		warn("Tower removed: " .. tower.Name)
		disconnect(data.Connection)
		towersPlaced[tower] = nil
	end
end

--// Get a valid tower owned by the player
local function getValidTower()
	for tower, data in pairs(towersPlaced) do
		if data.Owner == player and tower:IsDescendantOf(workspace) then
			return tower
		end
	end
	return nil
end

--// Event hooks
towers.ChildAdded:Connect(childAdded)
towers.ChildRemoved:Connect(childRemoved)

--// Module
local EventsModule = {}

function EventsModule.WaveStart(callback)
	for _, tower in towers:GetChildren() do
		local config = tower:FindFirstChild("Config")
		if config and config.Owner.Value == player.Name then
			states.PlacedTower = true
			break
		end
	end

	if not states.PlacedTower then
		local conn
		conn = towers.ChildAdded:Connect(function(tower)
			local config = tower:WaitForChild("Config")
			if config.Owner.Value == player.Name then
				states.PlacedTower = true
				states.UpgradedEarly = false
				config.Upgrades.Changed:Once(function()
					states.UpgradedEarly = true
				end)
				disconnect(conn)
			end
		end)
	end

	if wave.Value >= 1 then
		callback()
	else
		wave:GetPropertyChangedSignal("Value"):Wait()
		callback()
	end
end

function EventsModule.EnoughMoney(callback)
	local playerMoney = player:FindFirstChild("Money")
	if not playerMoney then warn("No 'Money' stat."); return end

	local function checkAndWait(tower)
		local config = tower:FindFirstChild("Config")
		if not config then return end

		local upgrades = upgradesModule[tower.Name]
		if not upgrades then return end

		local index = config.Upgrades.Value + 1
		local upgradeCost = upgrades.Upgrades[index]
		if not upgradeCost then
			callback()
			return
		end

		if states.UpgradedEarly then
			warn("Already upgraded early.")
			callback()
			return
		end

		while playerMoney.Value < upgradeCost.Price do
			if not tower:IsDescendantOf(workspace) or not towersPlaced[tower] then
				warn("Tower sold. Restarting check.")
				return EventsModule.EnoughMoney(callback)
			end
			playerMoney.Changed:Wait()
		end

		warn("Player has enough money.")
		callback()
	end

	local tower = getValidTower()
	if not tower then
		local conn
		conn = towers.ChildAdded:Connect(function(child)
			local config = child:FindFirstChild("Config")
			if config and config:FindFirstChild("Owner") and config.Owner.Value == player.Name then
				disconnect(conn)
				task.wait(0.5)
				EventsModule.EnoughMoney(callback)
			end
		end)
		return
	end

	checkAndWait(tower)
end

function EventsModule.TowerPlaced(callback)
	local conn
	conn = towers.ChildAdded:Connect(function(child)
		local config = child:WaitForChild("Config")
		if config.Owner.Value == player.Name then
			disconnect(conn)
			states.PlacedTower = false
			callback()
		end
	end)
end

function EventsModule.TowerUpgraded(callback)
	local function waitForUpgrade()
		while true do
			for _, data in pairs(towersPlaced) do
				if data.Owner == player and data.Upgraded and not data.Checked then
					data.Checked = true
					return true
				end
			end
			task.wait(0.1)
		end
	end

	local conn
	conn = towers.ChildAdded:Connect(function(child)
		task.defer(function()
			local config = child:WaitForChild("Config", 5)
			if config and config:FindFirstChild("Owner") and config.Owner.Value == player.Name then
				childAdded(child)
			end
		end)
	end)

	waitForUpgrade()
	disconnect(conn)
	callback()
end

function EventsModule.Boss(callback)
	ReplicatedStorage.Events.Client.BossSpawn.OnClientEvent:Wait()
	callback()
end

function EventsModule.Defeated(callback)
	info.Victory.Changed:Wait()
	callback()
end

function EventsModule.Finished(callback)
	task.wait(6)
	callback()
end

return EventsModule
