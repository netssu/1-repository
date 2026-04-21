local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UpgradesModule = require(ReplicatedStorage:WaitForChild("Upgrades"))
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")
local TowerCutsceneConfig = require(ReplicatedStorage:WaitForChild("TowerCutsceneConfig"))

local eventsFolder = ReplicatedStorage:WaitForChild("Events")
local clientFolder = eventsFolder:FindFirstChild("Client")
if not clientFolder then
	clientFolder = Instance.new("Folder")
	clientFolder.Name = "Client"
	clientFolder.Parent = eventsFolder
end

local cutsceneEvent = clientFolder:FindFirstChild(TowerCutsceneConfig.RemoteEventName)
if not cutsceneEvent then
	cutsceneEvent = Instance.new("RemoteEvent")
	cutsceneEvent.Name = TowerCutsceneConfig.RemoteEventName
	cutsceneEvent.Parent = clientFolder
end

local towerConnections: {[Instance]: {RBXScriptConnection}} = {}
local triggeredTowers: {[Instance]: boolean} = {}

local function getTowerOwner(tower: Model): Player?
	local config = tower:FindFirstChild("Config")
	if not config then
		return nil
	end

	local ownerValue = config:FindFirstChild("Owner")
	if not ownerValue or not ownerValue:IsA("StringValue") then
		return nil
	end

	return Players:FindFirstChild(ownerValue.Value)
end

local function hasCutsceneConfig(towerName: string): boolean
	return TowerCutsceneConfig.Towers[towerName] ~= nil
end

local function isTowerAtMaxUpgrade(tower: Model): boolean
	if not hasCutsceneConfig(tower.Name) then
		return false
	end

	local unitStats = UpgradesModule[tower.Name]
	if not unitStats then
		return false
	end

	local config = tower:FindFirstChild("Config")
	local upgradesValue = config and config:FindFirstChild("Upgrades")
	if not upgradesValue or not upgradesValue:IsA("IntValue") then
		return false
	end

	local maxUpgrades = unitStats.MaxUpgrades or #unitStats.Upgrades
	return upgradesValue.Value >= maxUpgrades
end

local function clearTowerConnections(tower: Instance)
	local connections = towerConnections[tower]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end

	towerConnections[tower] = nil
	triggeredTowers[tower] = nil
end

local function tryStartCutscene(tower: Model)
	if triggeredTowers[tower] then
		return
	end

	if not isTowerAtMaxUpgrade(tower) then
		return
	end

	local ownerPlayer = getTowerOwner(tower)
	if not ownerPlayer then
		return
	end

	triggeredTowers[tower] = true
	cutsceneEvent:FireClient(ownerPlayer, tower.Name)
end

local function hookTower(tower: Instance)
	if not tower:IsA("Model") then
		return
	end

	if towerConnections[tower] then
		return
	end

	if not hasCutsceneConfig(tower.Name) then
		return
	end

	towerConnections[tower] = {}

	local config = tower:FindFirstChild("Config")
	local upgradesValue = config and config:FindFirstChild("Upgrades")

	if upgradesValue and upgradesValue:IsA("IntValue") then
		table.insert(towerConnections[tower], upgradesValue.Changed:Connect(function()
			tryStartCutscene(tower)
		end))
	end

	table.insert(towerConnections[tower], tower.AncestryChanged:Connect(function(_, parent)
		if not parent then
			clearTowerConnections(tower)
		end
	end))

	tryStartCutscene(tower)
end

local towersFolder = workspace:WaitForChild("Towers")

for _, tower in towersFolder:GetChildren() do
	hookTower(tower)
end

towersFolder.ChildAdded:Connect(hookTower)
towersFolder.ChildRemoved:Connect(clearTowerConnections)