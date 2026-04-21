--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local repStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--// Objects & Player
local player = players.LocalPlayer
local gui = player.PlayerGui
local gameGui = gui:WaitForChild("GameGui")

--// Packages
local upgradesModule = require(repStorage.Upgrades)
local Signal = require(ReplicatedStorage.Modules.Signal)

--// Folders
local clientEvents = repStorage:WaitForChild("Events"):WaitForChild("Client")
local info = workspace:WaitForChild('Info')
local wave = info:WaitForChild("Wave")
local towers = workspace:WaitForChild("Towers")

--// Tables
local towersPlaced = {
	ChildAdded = Signal.new()
}
local states = {
	UpgradedEarly = false,
	PlacedTower = false
}



--// Helper functions
local function childAdded(child: Instance)
	local config = child:FindFirstChild("Config")
	if not config then
		_G.Message("Error with tower, place another one.", Color3.new(255,0,0))
		return
	end	
	
	if towersPlaced[child] then return end -- Prevent duplicates

	local owner = config:FindFirstChild("Owner")
	if not owner then
		_G.Message("Error with tower, place another one.", Color3.new(255,0,0))
		return 
	end

	if owner.Value ~= player.Name then return end

	local upgradeInfo = upgradesModule[child.Name]
	if not upgradeInfo then
		warn("[ChildAdded]: No upgrade data for tower, retrying...")
		return
	end
	
	local upgradeCost = upgradeInfo.Upgrades[config.Upgrades.Value + 1]

	warn("Tower added: " .. child.Name)

	local connection = config.Upgrades.Changed:Connect(function()
		local trackedTower = towersPlaced[child]
		if not trackedTower then return end

		trackedTower.Upgraded = true
		if trackedTower.Connection then
			trackedTower.Connection:Disconnect()
			trackedTower.Connection = nil
		end
		warn("Tower Upgraded.")
	end)

	towersPlaced[child] = {
		Object = child,
		Config = config,
		Owner = player,
		UpgradeCost = upgradeCost and upgradeCost.Price or 0,
		PlacedEvent = Signal.new(),
		Upgradedevent = Signal.new(),
		Upgraded = false,
		Placed = true,
		CheckedPlace = false,
		Checked = false, -- if the tower was checked in previous tutorial step.
		Connection = connection
	}

	towersPlaced.ChildAdded:Fire(child)	
end

local function childRemoved(child: Instance)
	local tower = towersPlaced[child]
	if tower then
		warn("Tower removed: " .. child.Name)
		if tower.Connection then
			tower.Connection:Disconnect()
		end
		towersPlaced[child] = nil
	end
end

local function checkUpgrade()
	local upgradedDetected = false
	for tower, data in towersPlaced do
		if typeof(tower) == "string" then continue end
		if data.Upgraded then
			upgradedDetected = true
			break
		end

		if not data.Connection then
			data.Connection = tower.Config.Upgrades.Changed:Connect(function()
				if upgradedDetected then return end -- Prevent duplicate callback
				data.Upgraded = true
				upgradedDetected = true

				if data.Connection then
					data.Connection:Disconnect()
					data.Connection = nil
				end
				
				upgradedDetected = false
			end)
		end
	end
	
	return true
end

local function checkIfTowerExists()
	for _, tower in towers:GetChildren() do
		local config = tower:FindFirstChild("Config")
		if config and config.Owner.Value == player.Name then
			return true
		end
	end
	return false
end

clientEvents.TowerPlace.Event:Connect(function(action, tower)
	if action == "TowerPlaced" then
		childAdded(tower)
	elseif action == "RemoveTower" then
		childRemoved(tower)
	end
end)

clientEvents.TowerUpgrade.Event:Connect(function(tower)
	local towerData = towersPlaced[tower]
	if towerData and not towerData.Upgraded then
		warn("Tower Upgraded.")
		towerData.Upgraded = true
	end
end)


local childaddedCon

--// Module
local EventsModule = {}

function EventsModule.WaveStart(callback)
	if wave.Value >= 1 then
		callback()
		return	
	end

	if wave.Value <= 1 then
		wave:GetPropertyChangedSignal("Value"):Wait()
		callback()
	end 
end

function EventsModule.EnoughMoney(callback)
	local checking = false
	local hasMoney = false
	local costs = {}
	
	local playerMoney = player:FindFirstChild("Money")
	if not playerMoney then
		warn("[EnoughMoney]: No money stat found.")
		return
	end
	
	if not next(towersPlaced) then
		_G.Message("No tower's placed, please place one", Color3.new())
		return EventsModule.EnoughMoney(callback)
	end
	
	for tower, data in towersPlaced do
		if typeof(tower) == "string" then continue end
		if data.Owner == player and tower:IsDescendantOf(workspace) then
			 if not table.find(costs, data.UpgradeCost) then
				table.insert(costs, data.UpgradeCost)
			 end
		end
	end
	
	if states.UpgradedEarly then
		warn("[EnoughMoney]: Already upgraded during early window.")
		callback()
		return
	end
	
	repeat task.wait(.1)
		for _, cost in costs do
			if playerMoney.Value >= cost then
				hasMoney = true
			end
		end
	until hasMoney

	warn("[EnoughMoney]: Player has enough money.")
	callback()
end


function EventsModule.TowerPlaced(callback)
	local towerPlaced = false
	local conn = nil

	local function waitForPlace()
		while true do
			for tower, data in pairs(towersPlaced) do
				if typeof(tower) == "string" then return end
				
				if data.Owner == player and data.Placed then
					if data.CheckedPlace then continue end
					return true
				end
			end
			task.wait(0.1)
		end
	end

	if not states.PlacedTower then
		towersPlaced.ChildAdded:Wait()
	end

	states.PlacedTower = false
	
	if conn then
		conn:Disconnect()
	end

	callback()
end

function EventsModule.TowerUpgraded(callback)
	local function waitForUpgrade()
		while true do
			for tower, data in pairs(towersPlaced) do
				if typeof(tower) == "string" then continue end
				
				local upgraded = false
				data.Upgradedevent:Connect(function()
					if data.Checked then return end
					upgraded = true
				end)
				
				if upgraded then
					return true
				end
			end
			task.wait(0.1)
		end
	end

	local towerAddedConn
	towerAddedConn = towersPlaced.ChildAdded:Connect(function(child)
		task.spawn(function()
			local config = child:WaitForChild("Config", 5)
			if not config then return end
			local owner = config:FindFirstChild("Owner")
			if not owner or owner.Value ~= player.Name then return end
			
			states.PlacedTower = true
		end)
	end)

	
	waitForUpgrade()

	if towerAddedConn then towerAddedConn:Disconnect() end
	callback()
end


function EventsModule.Boss(callback)
	game.ReplicatedStorage.Events.Client.BossSpawn.OnClientEvent:Wait()
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