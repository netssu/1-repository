--// Services & Modules
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
repeat task.wait() until player:FindFirstChild("DataLoaded")

local junkTrader = script.Parent
local junktraderPoints = player:WaitForChild("JunkTraderPoints")

local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local Upgrades = ReplicatedStorage:WaitForChild("Upgrades")
local UpgradesModule = require(ReplicatedStorage.Upgrades)
local SacrificePoints = require(ReplicatedStorage.Modules.SacrificePoints)

--// UI References
local closeButton = junkTrader.Frame.X_Close
local summonButton = junkTrader.Frame.Right_Panel.Contents.Options.Bar.Summon
local addButton = junkTrader.Frame.Left_Panel.Contents["Ascendant Prism"].Contents.Requirements.Contents.Add
local Inventory = player.PlayerGui.UnitsGui.Inventory.Units
local PointsLabel = junkTrader.Frame.Left_Panel.Contents["Ascendant Prism"].Contents.Item_Main.Contents.Points
local Points = junkTrader.Points

--// State
local unitConnections = {}
local selectedUnits = {}
local currentPoints = junktraderPoints.Value

--// Functions

local function updatePointsLabel()
	local pts = 0
	
	for unit, template in selectedUnits do
		local tower = unit.TowerValue.Value
		if not tower then continue end

		local upgradeInfo = UpgradesModule[tower.Name]
		if not upgradeInfo then
			_G.Message("Invalid unit!", Color3.fromRGB(255, 0, 0))
			return
		end
		
		local rarity = upgradeInfo.Rarity
		local shiny = tower:GetAttribute("Shiny")
		local pointsToAdd = 0

		local data = SacrificePoints.SacrificeData[rarity]
		if not data then
			_G.Message("Ineligible unit.", Color3.fromRGB(255, 0, 0))
			return
		end

		pointsToAdd = shiny and data.Shiny or data.Points
		pts += pointsToAdd

	end
	
	local text = junktraderPoints.Value + pts
	PointsLabel.Text = "Points: " .. tostring(text)
end

local function disconnectUnitConnections()
	for _, conn in unitConnections do
		if conn.Connected then conn:Disconnect() end
	end
	table.clear(unitConnections)
end

local function resetState()
	for _, conn in ipairs(unitConnections) do
		pcall(function() conn:Disconnect() unitConnections[conn] = nil end)
	end
	unitConnections = {}

	for unit, template in selectedUnits do
		if unit then unit.Visible = true end
		if template then template:Destroy() end
		selectedUnits[unit] = nil	
	end

	selectedUnits = {}
	currentPoints = junktraderPoints.Value
	updatePointsLabel()
end

local isClicked = false
local function handleUnitClick(unit, tower)
	print('CLICK![JUNK TRADER]')
	if tower:GetAttribute("Lock") or tower:GetAttribute("Locked") then return end -- not sure which one
	if currentPoints >= 100 then
		_G.Message("You already have enough points.", Color3.fromRGB(255, 0, 0))
		return
	end
	
	if isClicked then return end
	isClicked = true

	local upgradeInfo = UpgradesModule[tower.Name]
	if not upgradeInfo then
		_G.Message("Invalid unit!", Color3.fromRGB(255, 0, 0))
		return
	end

	local rarity = upgradeInfo.Rarity
	local shiny = tower:GetAttribute("Shiny")
	local pointsToAdd = 0

	local data = SacrificePoints.SacrificeData[rarity]
	if not data then
		_G.Message("Ineligible unit.", Color3.fromRGB(255, 0, 0))
		return
	end

	pointsToAdd = shiny and data.Shiny or data.Points
	currentPoints += pointsToAdd

	local viewport = ViewPortModule.CreateViewPort(tower.Name, shiny)
	local contents = junkTrader.Frame.Left_Panel.Contents["Ascendant Prism"].Contents.Requirements.Contents
	local template = contents.UIListLayout.Template:Clone()
	viewport.Parent = template.Contents
	template.Contents.Text_Container.Cost.Text = pointsToAdd .. " Points"
	template.Name = tower.Name
	template.Parent = contents

	selectedUnits[unit] = template
	unit.Visible = false

	PointsLabel.Text = "Points: " .. currentPoints
	_G.CloseAll("JunkTraderFrame")
	
	task.delay(.5, function()
		isClicked = false
	end)
end

local function prepareEligibleUnits()
	local unitChildren = Inventory.Frame.Left_Panel.Contents.Act.UnitsScroll:GetChildren()

	for i,v in ReplicatedStorage.Cache.Inventory:GetChildren() do
		table.insert(unitChildren, v)
	end
	
	
	for _, unit in ipairs(unitChildren) do
		if not (unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue")) then continue end

		local tower = unit.TowerValue.Value
		if not tower then continue end

		local isEligible = (not selectedUnits[unit]) and (
			Upgrades.Legendary:FindFirstChild(tower.Name) or
				Upgrades.Mythical:FindFirstChild(tower.Name) or
				Upgrades.Secret:FindFirstChild(tower.Name)
				or Upgrades.Exclusive:FindFirstChild(tower.Name)
		)

		unit.Visible = isEligible
		
		print('PREPARING ELIGIBLE UNIT...')
		
		if isEligible then

			local conn = unit.Activated:Once(function()
				handleUnitClick(unit, tower)
			end)
			table.insert(unitConnections, conn)
		end
	end

	-- Reset visibility if inventory closes
	Inventory:GetPropertyChangedSignal("Visible"):Once(function()
		for _, unit in ipairs(unitChildren) do
			if unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue") then
				unit.Visible = true
			end
		end
	end)
end

--// Gamepass Logic
local function canBuyMissingPoints()
	return currentPoints >= 50 and currentPoints < 100
end

Points["25 Points"].Activated:Connect(function()

	if not canBuyMissingPoints() then
		if currentPoints >= 100 then
			_G.Message("You already have enough points!")
		elseif currentPoints < 50 then
			_G.Message("To buy 50 points, you need 50 at start.", Color3.fromRGB(255, 0, 0))
		end
		return
	end
	
	if currentPoints < 75 then 
		_G.Message("To buy 25 points, you need 75 at start.")
		return
	end
	
	local serializedUnits = {}
	for unit, template in pairs(selectedUnits) do
		local tower = unit:FindFirstChild("TowerValue") and unit.TowerValue.Value
		if tower then
			table.insert(serializedUnits, tower)
		end
	end
	
	local result = ReplicatedStorage.Functions.Sacrifice:InvokeServer(serializedUnits, 3282373891)
	if result then
		_G.CloseAll()

		print(result)

		local openFrame = false -- this just waits until the player clicks to open the junktraderframe (if he's still inside the zone)

		UIHandler.PlaySound("Redeem")
		ViewModule.EvolveHatch({
			UpgradesModule[result.Name],
			result,
			function()
				openFrame = true
			end,
		})

		repeat task.wait(.1) until openFrame

		resetState()

		if player:FindFirstChild("IsInside") then
			_G.CloseAll("JunkTraderFrame")
		end
	end
end)

Points["50 Points"].Activated:Connect(function()
	if not canBuyMissingPoints() then
		if currentPoints >= 100 then
			_G.Message("You already have enough points!")
		elseif currentPoints < 50 then
			_G.Message("You must have at least 50 points to buy the rest.", Color3.fromRGB(255, 0, 0))
		end
		return
	end
	
	local serializedUnits = {}
	for unit, template in pairs(selectedUnits) do
		local tower = unit:FindFirstChild("TowerValue") and unit.TowerValue.Value
		if tower then
			table.insert(serializedUnits, tower)
		end
	end
	
	local result = ReplicatedStorage.Functions.Sacrifice:InvokeServer(serializedUnits, 3282373336)
	if result then
		_G.CloseAll()

		local openFrame = false -- this just waits until the player clicks to open the junktraderframe (if he's still inside the zone)

		UIHandler.PlaySound("Redeem")
		ViewModule.EvolveHatch({
			UpgradesModule[result.Name],
			result,
			function()
				openFrame = true
			end,
		})

		repeat task.wait(.1) until openFrame

		resetState()
		if player:FindFirstChild("IsInside") then
			_G.CloseAll("JunkTraderFrame")
		end
	end
end)

local dbThread = nil
local db = false
summonButton.Activated:Connect(function()
	if db then return end
	db = true
	
	local serializedUnits = {}
	for unit, template in pairs(selectedUnits) do
		local tower = unit:FindFirstChild("TowerValue") and unit.TowerValue.Value
		if tower then
			table.insert(serializedUnits, tower)
		end
	end
	
	local result, points = ReplicatedStorage.Functions.Sacrifice:InvokeServer(serializedUnits)
	if result then
		if dbThread then
			task.cancel(dbThread)
			dbThread = nil
		end
		
		db = true
		
		_G.CloseAll()

		local openFrame = false

		PointsLabel.Text = points

		print(result)

		UIHandler.PlaySound("Redeem")
		ViewModule.EvolveHatch({
			UpgradesModule[result.Name],
			result,
			function()
				openFrame = true
			end,
		})

		repeat task.wait(.1) until openFrame

		resetState()

		db = false

		if player:FindFirstChild("IsInside") then
			_G.CloseAll("JunkTraderFrame")
		end
	else
		if dbThread then
			task.cancel(dbThread)
			dbThread = nil
		end
		
		dbThread = task.delay(.5, function()
			db = false
		end)
	end
end)

--// Trigger events
local adding = false
addButton.Activated:Connect(function()
	if adding then return end
	adding = true
	
	_G.CloseAll("Units")
	disconnectUnitConnections()
	prepareEligibleUnits()
	
	task.delay(.5, function()
		adding = false
	end)
end)

closeButton.Activated:Connect(function()
	resetState()
end)

player.ChildRemoved:Connect(function(child)
	if child.Name == "IsInside" then
		resetState()
	end
end)

junktraderPoints:GetPropertyChangedSignal("Value"):Connect(updatePointsLabel)

updatePointsLabel()
--warn("Loaded JunkTrader.")



--closeButton.Activated:Connect(function()
--	for i, v in script.Parent:GetChildren() do
--		if v:IsA("Frame") then
--			v.Visible = false
--		end
--	end
--end)