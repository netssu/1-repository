local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local numberFormat = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NumberFormat"))

local newUI = playerGui:WaitForChild("NewUI")
local quickAccess = newUI:WaitForChild("QuickAcess")
local title = quickAccess:WaitForChild("Title")
local info = Workspace:WaitForChild("Info")

local fieldRate = quickAccess:WaitForChild("Buttons"):WaitForChild("Field"):WaitForChild("Rate")
local takedownsRate = quickAccess.Buttons:WaitForChild("Takedowns"):WaitForChild("Rate")
local unitsOnFieldRate = quickAccess.Buttons:WaitForChild("UnitsOnField"):WaitForChild("Rate")

local function readValue(name, fallback)
	local valueObject = info:FindFirstChild(name)
	if valueObject and valueObject:IsA("ValueBase") then
		return valueObject.Value
	end

	return fallback
end

local function updateTitle()
	local stage = readValue("World", 1)
	local act = readValue("Level", 1)

	title.Text = `Stage {stage} - Act {act}`
end

local function shorten(value)
	return numberFormat.ShortenNum(tostring(math.floor(tonumber(value) or 0)))
end

local function countEnemiesOnField()
	local total = 0

	for _, folderName in {"Mobs", "RedMobs", "BlueMobs"} do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			total += #folder:GetChildren()
		end
	end

	return total
end

local function countUnitsOnField()
	local placedTowers = player:FindFirstChild("PlacedTowers")
	if placedTowers and placedTowers:IsA("ValueBase") then
		return placedTowers.Value
	end

	local total = 0
	local towersFolder = Workspace:FindFirstChild("Towers")
	if not towersFolder then
		return total
	end

	for _, tower in towersFolder:GetChildren() do
		local config = tower:FindFirstChild("Config")
		local owner = config and config:FindFirstChild("Owner")

		if owner and owner:IsA("ValueBase") and owner.Value == player.Name then
			total += 1
		end
	end

	return total
end

local function readPlayerStat(names)
	for _, parent in {player, player:FindFirstChild("Stats"), player:FindFirstChild("leaderstats")} do
		if parent then
			for _, name in names do
				local valueObject = parent:FindFirstChild(name)
				if valueObject and valueObject:IsA("ValueBase") then
					return valueObject.Value
				end
			end
		end
	end

	return 0
end

local function updateRates()
	fieldRate.Text = `x{shorten(countEnemiesOnField())}`
	takedownsRate.Text = `x{shorten(readPlayerStat({"Takedowns", "TakeDowns", "Kills", "Eliminations"}))}`
	unitsOnFieldRate.Text = `x{shorten(countUnitsOnField())}`
end

local function updateQuickAccess()
	updateTitle()
	updateRates()
end

updateQuickAccess()

for _, valueName in {"World", "Level"} do
	local valueObject = info:FindFirstChild(valueName)
	if valueObject and valueObject:IsA("ValueBase") then
		valueObject:GetPropertyChangedSignal("Value"):Connect(updateTitle)
	end
end

task.spawn(function()
	while quickAccess.Parent do
		updateRates()
		task.wait(1)
	end
end)
