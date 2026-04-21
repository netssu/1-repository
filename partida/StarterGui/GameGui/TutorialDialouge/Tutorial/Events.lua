--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local repStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--// Objects & Player
local player = players.LocalPlayer
local gui = player.PlayerGui
local gameGui = gui:WaitForChild("GameGui")

--// Packages
local Signal = require(ReplicatedStorage.Modules.Signal)

--// Folders
local clientEvents = repStorage:WaitForChild("Events"):WaitForChild("Client")
local info = workspace:WaitForChild('Info')
local wave = info:WaitForChild("Wave")
local towers = workspace:WaitForChild("Towers")

--// Ui Elements
local dialogueFrame = script.Parent.Parent.Dialogue
local contents = dialogueFrame.Contents
local bgText = contents.Bg_Text
local viewport = bgText.ViewportFrame
local label = bgText.TextLabel
local eventsLabel = bgText.EventsLabel

--// Tables
local towersPlaced = {}

--// Data
local upgradeCount = 0

clientEvents.TowerUpgrade.Event:Connect(function(tower)
	if not towersPlaced[tower] then
		warn("no tower found in towersPlaced")
		return
	end
	
	if not towersPlaced[tower].upgraded then
		towersPlaced[tower].upgraded = true
	end
	
	towersPlaced[tower].timesUpgraded = math.clamp(towersPlaced[tower].timesUpgraded+1, 0, 3)
	
	local total = 0
	for _, data in pairs(towersPlaced) do
		total += math.clamp(data.timesUpgraded, 0, 5)
	end
	upgradeCount = math.clamp(total, 0, 5)
end)

local events = {}

events.WaveStart = function(callback)
	if wave.Value >= 1 then
		callback()
	else
		while wave.Value < 1 do
			wave:GetPropertyChangedSignal("Value"):Wait()
		end
		
		callback()
	end
end

workspace:WaitForChild('Towers').ChildAdded:Connect(function(tower)
	towersPlaced[tower] = {
		upgraded = false,
		timesUpgraded = 0
	}
end)

events.TowersPlaced = function(callback)
	eventsLabel.Visible = true
	
	local bindable = Instance.new('BindableEvent')
	local count = 0
	
	local conn1 = workspace:WaitForChild('Towers').ChildAdded:Connect(function(tower)
		local foundConfig = tower:WaitForChild('Config', 10)
		if foundConfig and tower:WaitForChild('Config'):WaitForChild('Owner').Value == player.Name then
			count += 1
			eventsLabel.Text = count .. "/3"
			
			if count == 3 then
				bindable:Fire()
			end
		end
	end)
	local conn2 = workspace.Towers.ChildRemoved:Connect(function(tower)
		local foundConfig = tower:WaitForChild('Config', 10)
		if foundConfig and tower:WaitForChild('Config', 10):WaitForChild('Owner').Value == player.Name then
			count -= 1
			
			
			eventsLabel.Text = count .. "/3"
		end
	end)
	
	bindable.Event:Wait()
	conn1:Disconnect()
	conn2:Disconnect()
	conn1 = nil
	conn2 = nil
	
	eventsLabel.Visible = false
	eventsLabel.Text = "0/3"
	
	callback()
end

events.TowerUpgraded = function(callback)
	eventsLabel.Visible = true
	eventsLabel.Text = upgradeCount .. "/1"

	while upgradeCount < 1 do
		eventsLabel.Text = upgradeCount .. "/1"	
		task.wait(.1)	
	end

	eventsLabel.Visible = false
	eventsLabel.Text = "0/1"

	callback()
end

events.Boss = function(callback)
	game.ReplicatedStorage.Events.Client.BossSpawn.OnClientEvent:Wait()
	callback()
end

events.Defeated = function(callback)
	info.Victory.Changed:Wait()
	callback()
end

events.Finished = function(callback)
	task.wait(6)
	callback()
end

return events
