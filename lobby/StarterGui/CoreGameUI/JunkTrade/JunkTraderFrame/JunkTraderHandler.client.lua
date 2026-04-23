--// Services & Modules
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local legacyJunkTrader = script.Parent
local NewUI = playerGui:WaitForChild("NewUI")
local junktraderPoints = player:WaitForChild("JunkTraderPoints")

repeat task.wait() until player:FindFirstChild("DataLoaded")

local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local Upgrades = ReplicatedStorage:WaitForChild("Upgrades")
local UpgradesModule = require(ReplicatedStorage.Upgrades)
local SacrificePoints = require(ReplicatedStorage.Modules.SacrificePoints)

local Inventory = playerGui:WaitForChild("UnitsGui"):WaitForChild("Inventory"):WaitForChild("Units")
local InventoryCache = ReplicatedStorage:WaitForChild("Cache"):WaitForChild("Inventory")

local BUY_25_PRODUCT_ID = 3282373891
local BUY_50_PRODUCT_ID = 3282373336

--// State
local connectedButtons = {}
local unitConnections = {}
local selectedUnits = {}
local db = false
local dbThread = nil
local adding = false
local isClicked = false
local handleUnitClick
local selectionOrder = 0

--// Helpers
local function findChildPath(root, path)
	local current = root

	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	return current
end

local function findFirstGuiButton(root)
	if not root then
		return nil
	end

	if root:IsA("GuiButton") then
		return root
	end

	local preferredButton = root:FindFirstChild("Btn")
		or root:FindFirstChild("Button")

	if preferredButton and preferredButton:IsA("GuiButton") then
		return preferredButton
	end

	return root:FindFirstChildWhichIsA("GuiButton", true)
end

local function setTextValue(label, value)
	if not label then
		return
	end

	if label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox") then
		label.Text = tostring(value)
	end
end

local function findDescendantByName(root, name)
	if not root then
		return nil
	end

	return root:FindFirstChild(name, true)
end

local function getOrderedGuiChildren(container)
	if not container then
		return {}
	end

	local children = {}

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			table.insert(children, child)
		end
	end

	table.sort(children, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end

		local aNumber = tonumber(a.Name)
		local bNumber = tonumber(b.Name)
		if aNumber and bNumber and aNumber ~= bNumber then
			return aNumber < bNumber
		end

		return a.Name < b.Name
	end)

	return children
end

local function getOrCreateTemplateHost(root)
	if not (root and root:IsA("GuiObject")) then
		return nil
	end

	local host = root:FindFirstChild("JunkTraderTemplates")
	if host and host:IsA("GuiObject") then
		return host
	end

	host = Instance.new("Frame")
	host.Name = "JunkTraderTemplates"
	host.BackgroundTransparency = 1
	host.BorderSizePixel = 0
	host.Size = UDim2.fromOffset(0, 0)
	host.Position = UDim2.new()
	host.Visible = false
	host.ClipsDescendants = true
	host.Parent = root

	return host
end

local function getActiveJunkTraderFrame()
	local newJunkTrader = NewUI and NewUI:FindFirstChild("JunkTrader")
	if newJunkTrader and newJunkTrader:IsA("GuiObject") then
		return newJunkTrader
	end

	return legacyJunkTrader
end

local function hasNewUnitsUi()
	local unitsUi = NewUI and NewUI:FindFirstChild("Units")
	return unitsUi and unitsUi:IsA("GuiObject")
end

local function hasNewJunkTraderUi()
	local junkTrader = NewUI and NewUI:FindFirstChild("JunkTrader")
	return junkTrader and junkTrader:IsA("GuiObject")
end

local function getLegacyUiRefs()
	local junkTrader = legacyJunkTrader
	local frame = junkTrader:FindFirstChild("Frame")
	local leftPanel = frame and frame:FindFirstChild("Left_Panel")
	local rightPanel = frame and frame:FindFirstChild("Right_Panel")
	local ascendantPrism = leftPanel and leftPanel:FindFirstChild("Contents") and leftPanel.Contents:FindFirstChild("Ascendant Prism")
	local prismContents = ascendantPrism and ascendantPrism:FindFirstChild("Contents")
	local requirements = prismContents and prismContents:FindFirstChild("Requirements")
	local requirementContents = requirements and requirements:FindFirstChild("Contents")
	local requirementTemplate = findChildPath(requirementContents, { "UIListLayout", "Template" })

	if requirementTemplate and requirementTemplate:IsA("GuiObject") then
		requirementTemplate.Visible = false
	end

	return {
		mode = "legacy",
		root = junkTrader,
		closeButton = frame and frame:FindFirstChild("X_Close"),
		summonButton = findChildPath(rightPanel, { "Contents", "Options", "Bar", "Summon" }),
		addButton = requirementContents and requirementContents:FindFirstChild("Add"),
		pointsLabel = findChildPath(prismContents, { "Item_Main", "Contents", "Points" }),
		requirementContents = requirementContents,
		requirementTemplate = requirementTemplate,
		pointButtons = {
			[25] = findChildPath(junkTrader, { "Points", "25 Points" }),
			[50] = findChildPath(junkTrader, { "Points", "50 Points" }),
		},
	}
end

local function getNewUiRefs()
	local junkTrader = NewUI and NewUI:FindFirstChild("JunkTrader")
	if not (junkTrader and junkTrader:IsA("GuiObject")) then
		return nil
	end

	local left = junkTrader:FindFirstChild("Left")
	local main = junkTrader:FindFirstChild("Main")
	local itemsTab = main and main:FindFirstChild("ItemsTab")
	local itemsChildren = getOrderedGuiChildren(itemsTab)
	local previewPanel = itemsTab and (itemsTab:FindFirstChild("2") or itemsChildren[2])
	local selectionPanel = itemsTab and (itemsTab:FindFirstChild("3") or itemsChildren[3])
	local templateHost = getOrCreateTemplateHost(junkTrader)
	local profile = (templateHost and templateHost:FindFirstChild("Profile"))
		or (selectionPanel and (selectionPanel:FindFirstChild("Profile") or findDescendantByName(selectionPanel, "Profile")))
	local pointEntries = getOrderedGuiChildren(left and left:FindFirstChild("Points"))
	local rewardSlots = getOrderedGuiChildren(previewPanel and previewPanel:FindFirstChild("Slots"))

	local pointButtons = {}
	for index, entry in ipairs(pointEntries) do
		local action = index == 1 and 25 or index == 2 and 50 or index == 3 and 100 or nil
		local textLabel = entry:FindFirstChild("Text")
		local text = textLabel and string.lower(textLabel.Text) or ""

		if string.find(text, "25") then
			action = 25
		elseif string.find(text, "50") then
			action = 50
		elseif string.find(text, "100") then
			action = 100
		end

		if action then
			pointButtons[action] = findFirstGuiButton(entry)
		end
	end

	return {
		mode = "new",
		root = junkTrader,
		closeButton = findFirstGuiButton(junkTrader:FindFirstChild("Closebtn")),
		summonButton = findFirstGuiButton(findChildPath(main, { "Craft", "Button" })),
		addButton = findFirstGuiButton(selectionPanel and (selectionPanel:FindFirstChild("Add") or findDescendantByName(selectionPanel, "Add"))),
		selectionPanel = selectionPanel,
		templateHost = templateHost,
		profileTemplate = profile,
		craftViewport = findChildPath(main, { "Craft", "Placeholder" }),
		craftTitle = findChildPath(main, { "Craft", "Title" }),
		rewardSlots = rewardSlots,
		pointButtons = pointButtons,
	}
end

local function connectButtonOnce(button, callback)
	local actualButton = findFirstGuiButton(button)
	if not actualButton or connectedButtons[actualButton] then
		return
	end

	connectedButtons[actualButton] = true
	actualButton.Activated:Connect(callback)
end

local function copyViewportProperty(targetViewport, sourceViewport, propertyName)
	local readSuccess, value = pcall(function()
		return sourceViewport[propertyName]
	end)

	if not readSuccess then
		return
	end

	pcall(function()
		targetViewport[propertyName] = value
	end)
end

local function clearViewportTarget(viewport)
	if not viewport then
		return
	end

	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
end

local function setPlaceholderGraphicsVisible(container, visible)
	if not (container and container:IsA("GuiObject")) then
		return
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant ~= container
			and descendant.Name == "Placeholder"
			and descendant:IsA("GuiObject")
			and not descendant:IsA("ViewportFrame") then
			descendant.Visible = visible
		end
	end
end

local function ensureSelectionPanelPadding(panel)
	if not (panel and panel:IsA("GuiObject")) then
		return
	end

	local padding = panel:FindFirstChild("JunkTraderPadding")
	if not padding then
		padding = Instance.new("UIPadding")
		padding.Name = "JunkTraderPadding"
		padding.Parent = panel
	end

	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)

	local listLayout = panel:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout.Padding = UDim.new(0, 8)
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end
end

local function clearSelectionProfileClones(panel)
	if not panel then
		return
	end

	for _, child in ipairs(panel:GetChildren()) do
		if child:IsA("GuiObject") and child:GetAttribute("JunkTraderProfileClone") == true then
			child:Destroy()
		end
	end
end

local function getSortedSelectedInfos()
	local infos = {}

	for _, info in pairs(selectedUnits) do
		table.insert(infos, info)
	end

	table.sort(infos, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)

	return infos
end

local function getViewportTarget(container)
	if not container then
		return nil
	end

	if container:IsA("ViewportFrame") then
		return container
	end

	local directViewport = container:FindFirstChild("ViewportFrame")
	if directViewport and directViewport:IsA("ViewportFrame") then
		return directViewport
	end

	return container:FindFirstChildWhichIsA("ViewportFrame", true)
end

local function attachViewport(container, unitName, shiny)
	local targetViewport = getViewportTarget(container)
	if not targetViewport then
		return
	end

	clearViewportTarget(targetViewport)
	setPlaceholderGraphicsVisible(container, unitName == nil)

	local placeholderGraphic = container:IsA("GuiObject") and container:FindFirstChild("Placeholder")
	if placeholderGraphic and placeholderGraphic ~= targetViewport and placeholderGraphic:IsA("GuiObject") then
		placeholderGraphic.Visible = unitName == nil
	end

	if not unitName then
		return
	end

	local viewport = ViewPortModule.CreateViewPort(unitName, shiny)
	if not viewport then
		return
	end

	copyViewportProperty(targetViewport, viewport, "BackgroundTransparency")
	copyViewportProperty(targetViewport, viewport, "ImageTransparency")
	copyViewportProperty(targetViewport, viewport, "ImageColor3")
	copyViewportProperty(targetViewport, viewport, "Ambient")
	copyViewportProperty(targetViewport, viewport, "LightColor")
	copyViewportProperty(targetViewport, viewport, "LightDirection")
	copyViewportProperty(targetViewport, viewport, "CurrentCamera")

	local worldModel = viewport:FindFirstChildOfClass("WorldModel")
	if worldModel then
		worldModel.Parent = targetViewport
	end

	if ViewPortModule.DestroyViewport then
		ViewPortModule.DestroyViewport(viewport)
	else
		viewport:Destroy()
	end
end

local function getPointsForTower(tower)
	local upgradeInfo = tower and UpgradesModule[tower.Name]
	if not upgradeInfo then
		return nil, "Invalid unit!"
	end

	local data = SacrificePoints.SacrificeData[upgradeInfo.Rarity]
	if not data then
		return nil, "Ineligible unit."
	end

	if tower:GetAttribute("Shiny") then
		return data.Shiny
	end

	return data.Points
end

local function getSelectedPointsTotal()
	local total = 0

	for _, info in pairs(selectedUnits) do
		total += info.points or 0
	end

	return total
end

local function getCurrentTotalPoints()
	return junktraderPoints.Value + getSelectedPointsTotal()
end

local function buildSerializedUnits()
	local serializedUnits = {}

	for _, info in pairs(selectedUnits) do
		if info.tower then
			table.insert(serializedUnits, info.tower)
		end
	end

	return serializedUnits
end

local function isTowerSelected(tower)
	return tower and selectedUnits[tower] ~= nil
end

local function isEligibleTower(tower, unitKey)
	if not tower then
		return false
	end

	if unitKey and selectedUnits[unitKey] then
		return false
	end

	if isTowerSelected(tower) then
		return false
	end

	return not not (
		Upgrades:FindFirstChild("Legendary") and Upgrades.Legendary:FindFirstChild(tower.Name)
		or Upgrades:FindFirstChild("Mythical") and Upgrades.Mythical:FindFirstChild(tower.Name)
		or Upgrades:FindFirstChild("Secret") and Upgrades.Secret:FindFirstChild(tower.Name)
		or Upgrades:FindFirstChild("Exclusive") and Upgrades.Exclusive:FindFirstChild(tower.Name)
	)
end

local function clearJunkTraderSelectionMode()
	_G.junkTraderTowerSelection = false
	_G.junkTraderCanSelectTower = nil
	_G.junkTraderIsTowerSelected = nil
	_G.junkTraderSelectTower = nil
	_G.junkTraderCancelSelection = nil
end

local function enableJunkTraderSelectionMode()
	_G.junkTraderTowerSelection = true
	_G.junkTraderCanSelectTower = function(tower)
		return isTowerSelected(tower) or isEligibleTower(tower, nil)
	end
	_G.junkTraderIsTowerSelected = isTowerSelected
	_G.junkTraderSelectTower = function(unitButton, tower)
		handleUnitClick(unitButton, tower)
	end
	_G.junkTraderCancelSelection = clearJunkTraderSelectionMode
end

local function getEligibleRewardUnits(rarity)
	local rarityFolder = Upgrades:FindFirstChild(rarity)
	if not rarityFolder then
		return {}
	end

	local evolvedUnits = {}
	local noBannerUnits = {}

	for _, unitData in pairs(UpgradesModule) do
		if unitData.Evolve and unitData.Evolve.EvolvedUnit then
			evolvedUnits[unitData.Evolve.EvolvedUnit] = true
		end

		if unitData.NotInBanner then
			noBannerUnits[unitData.Name] = true
		end
	end

	local blacklist = {
		["Sith Trooper"] = true,
		["Asaka Tano"] = true,
		["Cad Bunny"] = true,
		["Egg Bane"] = true,
		["Anikin Armor"] = true,
		["Grand Inquisitor"] = true,
		["Grand Interrupter (The Traitor)"] = true,
		["Ninth Sister"] = true,
		["Ninth Sister (Brute)"] = true,
		["Fifth Brother (Dangerous Rebel)"] = true,
		["Tenth Brother"] = true,
		["Quinion (Survivor)"] = true,
		["Tenth Brother (The Wise)"] = true,
		["Dart Wader Maskless"] = true,
		["Dart Wader Maskless (Reformed)"] = true,
	}

	local units = {}
	for _, unit in ipairs(rarityFolder:GetChildren()) do
		if not evolvedUnits[unit.Name] and not noBannerUnits[unit.Name] and not blacklist[unit.Name] then
			table.insert(units, unit)
		end
	end

	table.sort(units, function(a, b)
		return a.Name < b.Name
	end)

	return units
end

local function buildRewardPoolEntries()
	local entries = {}
	local totalWeight = 0
	local weights = {}

	for rarity, data in pairs(SacrificePoints.SacrificeData) do
		local chance = data.SummonChance
		if chance and chance > 0 then
			if rarity == "Secret" then
				local buffs = player:FindFirstChild("Buffs")
				if buffs and buffs:FindFirstChild("Junk Offering") then
					chance *= 2
				end
			end

			weights[rarity] = chance
			totalWeight += chance
		end
	end

	if totalWeight <= 0 then
		return entries
	end

	for rarity, weight in pairs(weights) do
		local units = getEligibleRewardUnits(rarity)
		if #units > 0 then
			local unitChance = (weight / totalWeight) * 100 / #units

			for _, unit in ipairs(units) do
				table.insert(entries, {
					Name = unit.Name,
					Rarity = rarity,
					Chance = unitChance,
				})
			end
		end
	end

	table.sort(entries, function(a, b)
		if a.Chance ~= b.Chance then
			return a.Chance > b.Chance
		end

		if a.Rarity ~= b.Rarity then
			return a.Rarity < b.Rarity
		end

		return a.Name < b.Name
	end)

	return entries
end

local function formatChance(chance)
	if chance >= 10 then
		return string.format("%.0f%%", chance)
	end

	if chance >= 1 then
		return string.format("%.1f%%", chance)
	end

	return string.format("%.2f%%", chance)
end

local function updateRewardPreview()
	local refs = getNewUiRefs()
	if not refs then
		return
	end

	local entries = buildRewardPoolEntries()

	for index, slot in ipairs(refs.rewardSlots or {}) do
		local entry = entries[index]
		local nameLabel = slot:FindFirstChild("Name")
		local amountLabel = slot:FindFirstChild("Amount")
		local viewportContainer = slot:FindFirstChild("Placeholder")

		if entry then
			setTextValue(nameLabel, entry.Name)
			setTextValue(amountLabel, formatChance(entry.Chance))
			attachViewport(viewportContainer, entry.Name, false)
		else
			setTextValue(nameLabel, "Empty")
			setTextValue(amountLabel, "--")
			attachViewport(viewportContainer, nil)
		end
	end

	local featuredEntry = entries[1]
	attachViewport(refs.craftViewport, featuredEntry and featuredEntry.Name or nil)

	if refs.craftTitle and refs.craftTitle.Text == "" and featuredEntry then
		setTextValue(refs.craftTitle, "Trade-in")
	end
end

local function updateSelectedProfiles()
	local refs = getNewUiRefs()
	if not refs then
		return
	end

	ensureSelectionPanelPadding(refs.selectionPanel)
	clearSelectionProfileClones(refs.selectionPanel)

	local profileTemplate = refs.profileTemplate
	if not profileTemplate then
		return
	end

	local templateHost = refs.templateHost or getOrCreateTemplateHost(refs.root)
	if templateHost and profileTemplate.Parent ~= templateHost then
		profileTemplate.Parent = templateHost
	end

	local addRoot = refs.selectionPanel and findDescendantByName(refs.selectionPanel, "Add")

	profileTemplate.Visible = false

	if addRoot and addRoot:IsA("GuiObject") then
		addRoot.LayoutOrder = 10000
	end

	for index, info in ipairs(getSortedSelectedInfos()) do
		local clone = profileTemplate:Clone()
		clone.Name = string.format("Selected_%s_%d", info.tower.Name, index)
		clone.Visible = true
		clone.LayoutOrder = index
		clone:SetAttribute("JunkTraderProfileClone", true)

		local nameLabel = clone:FindFirstChild("Name") or findDescendantByName(clone, "Name")
		local pointsLabel = clone:FindFirstChild("Points") or findDescendantByName(clone, "Points")
		local viewportContainer = clone:FindFirstChild("Placeholder") or findDescendantByName(clone, "Placeholder")

		setTextValue(nameLabel, info.tower.Name)
		setTextValue(pointsLabel, "Points:" .. tostring(info.points or 0))
		attachViewport(viewportContainer, info.tower.Name, info.shiny)

		clone.Parent = refs.selectionPanel
	end
end

local function updatePointsDisplay()
	local totalPoints = getCurrentTotalPoints()

	local legacyRefs = getLegacyUiRefs()
	setTextValue(legacyRefs.pointsLabel, "Points: " .. tostring(totalPoints))
	updateSelectedProfiles()
end

local function disconnectUnitConnections()
	for _, connection in ipairs(unitConnections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end

	table.clear(unitConnections)
end

local function resetState()
	clearJunkTraderSelectionMode()
	disconnectUnitConnections()

	for _, info in pairs(selectedUnits) do
		if info.button and info.button.Parent then
			info.button.Visible = true
		end

		if info.template and info.template.Parent then
			info.template:Destroy()
		end
	end

	table.clear(selectedUnits)
	updatePointsDisplay()
	updateRewardPreview()
end

local function removeSelectedTower(tower)
	local info = selectedUnits[tower]
	if not info then
		return
	end

	if info.button and info.button.Parent then
		info.button.Visible = true
	end

	if info.template and info.template.Parent then
		info.template:Destroy()
	end

	selectedUnits[tower] = nil
	updatePointsDisplay()
end

handleUnitClick = function(unit, tower)
	if tower:GetAttribute("Lock") or tower:GetAttribute("Locked") then
		return
	end

	if isTowerSelected(tower) then
		clearJunkTraderSelectionMode()
		removeSelectedTower(tower)
		_G.CloseAll("JunkTraderFrame")
		return
	end

	if getCurrentTotalPoints() >= 100 then
		_G.Message("You already have enough points.", Color3.fromRGB(255, 0, 0))
		return
	end

	if isClicked then
		return
	end

	isClicked = true

	local pointsToAdd, errorMessage = getPointsForTower(tower)
	if not pointsToAdd then
		_G.Message(errorMessage or "Invalid unit!", Color3.fromRGB(255, 0, 0))
		isClicked = false
		return
	end

	local legacyRefs = getLegacyUiRefs()
	local template = nil

	if not hasNewJunkTraderUi() and legacyRefs.requirementTemplate and legacyRefs.requirementContents then
		template = legacyRefs.requirementTemplate:Clone()
		local viewport = ViewPortModule.CreateViewPort(tower.Name, tower:GetAttribute("Shiny"))
		if viewport and template:FindFirstChild("Contents") then
			viewport.Parent = template.Contents
		end

		local costLabel = template:FindFirstChild("Cost", true)
		setTextValue(costLabel, pointsToAdd .. " Points")

		template.Name = tower.Name
		template.Parent = legacyRefs.requirementContents
	end

	selectionOrder += 1
	selectedUnits[tower] = {
		tower = tower,
		points = pointsToAdd,
		template = template,
		button = unit,
		shiny = tower:GetAttribute("Shiny"),
		order = selectionOrder,
	}
	clearJunkTraderSelectionMode()

	if unit and unit:IsA("GuiObject") and not hasNewUnitsUi() then
		unit.Visible = false
	end

	updatePointsDisplay()
	_G.CloseAll("JunkTraderFrame")

	task.delay(0.5, function()
		isClicked = false
	end)
end

local function prepareEligibleUnits()
	local unitChildren = Inventory.Frame.Left_Panel.Contents.Act.UnitsScroll:GetChildren()

	for _, cachedUnit in ipairs(InventoryCache:GetChildren()) do
		table.insert(unitChildren, cachedUnit)
	end

	for _, unit in ipairs(unitChildren) do
		if not (unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue")) then
			continue
		end

		local tower = unit.TowerValue.Value
		if not tower then
			continue
		end

		local isEligible = not selectedUnits[tower] and (
			Upgrades:FindFirstChild("Legendary") and Upgrades.Legendary:FindFirstChild(tower.Name)
			or Upgrades:FindFirstChild("Mythical") and Upgrades.Mythical:FindFirstChild(tower.Name)
			or Upgrades:FindFirstChild("Secret") and Upgrades.Secret:FindFirstChild(tower.Name)
			or Upgrades:FindFirstChild("Exclusive") and Upgrades.Exclusive:FindFirstChild(tower.Name)
		)

		unit.Visible = not not isEligible

		if isEligible then
			local connection = unit.Activated:Once(function()
				handleUnitClick(unit, tower)
			end)

			table.insert(unitConnections, connection)
		end
	end

	Inventory:GetPropertyChangedSignal("Visible"):Once(function()
		for _, unit in ipairs(unitChildren) do
			if unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue") and unit.Parent then
				unit.Visible = true
			end
		end
	end)
end

local function canBuyMissingPoints()
	local currentPoints = getCurrentTotalPoints()
	return currentPoints >= 50 and currentPoints < 100
end

local function processSacrificeResult(result)
	if not result then
		return false
	end

	if dbThread then
		task.cancel(dbThread)
		dbThread = nil
	end

	_G.CloseAll()

	local openFrame = false

	UIHandler.PlaySound("Redeem")
	ViewModule.EvolveHatch({
		UpgradesModule[result.Name],
		result,
		function()
			openFrame = true
		end,
	})

	repeat
		task.wait(0.1)
	until openFrame

	resetState()

	if player:FindFirstChild("IsInside") then
		_G.CloseAll("JunkTraderFrame")
	end

	return true
end

local function attemptPurchase(productId)
	local serializedUnits = buildSerializedUnits()
	local result = ReplicatedStorage.Functions.Sacrifice:InvokeServer(serializedUnits, productId)

	if result then
		processSacrificeResult(result)
	end
end

local function buy25Points()
	local currentPoints = getCurrentTotalPoints()

	if not canBuyMissingPoints() then
		if currentPoints >= 100 then
			_G.Message("You already have enough points!")
		else
			_G.Message("To buy 25 points, you need 75 at start.", Color3.fromRGB(255, 0, 0))
		end
		return
	end

	if currentPoints < 75 then
		_G.Message("To buy 25 points, you need 75 at start.", Color3.fromRGB(255, 0, 0))
		return
	end

	attemptPurchase(BUY_25_PRODUCT_ID)
end

local function buy50Points()
	local currentPoints = getCurrentTotalPoints()

	if not canBuyMissingPoints() then
		if currentPoints >= 100 then
			_G.Message("You already have enough points!")
		else
			_G.Message("You must have at least 50 points to buy the rest.", Color3.fromRGB(255, 0, 0))
		end
		return
	end

	attemptPurchase(BUY_50_PRODUCT_ID)
end

local function summonSelectedUnits()
	if db then
		return
	end

	if getCurrentTotalPoints() < 100 then
		_G.Message("You need 100 points for a free summon.", Color3.fromRGB(255, 0, 0))
		return
	end

	db = true

	local serializedUnits = buildSerializedUnits()
	local result = ReplicatedStorage.Functions.Sacrifice:InvokeServer(serializedUnits)

	if result then
		processSacrificeResult(result)
		db = false
		return
	end

	if dbThread then
		task.cancel(dbThread)
	end

	dbThread = task.delay(0.5, function()
		db = false
	end)
end

local function openUnitSelection()
	if adding then
		return
	end

	adding = true

	if hasNewUnitsUi() then
		enableJunkTraderSelectionMode()
		_G.CloseAll("Units")
	else
		_G.CloseAll("Units")
		disconnectUnitConnections()
		prepareEligibleUnits()
	end

	task.delay(0.5, function()
		adding = false
	end)
end

local function bindUiButtons()
	local refsToBind = { getLegacyUiRefs(), getNewUiRefs() }

	for _, refs in ipairs(refsToBind) do
		if refs then
			connectButtonOnce(refs.closeButton, resetState)
			connectButtonOnce(refs.addButton, openUnitSelection)
			connectButtonOnce(refs.summonButton, summonSelectedUnits)
			connectButtonOnce(refs.pointButtons[25], buy25Points)
			connectButtonOnce(refs.pointButtons[50], buy50Points)
			connectButtonOnce(refs.pointButtons[100], summonSelectedUnits)
		end
	end
end

--// Bindings
bindUiButtons()

player.ChildRemoved:Connect(function(child)
	if child.Name == "IsInside" then
		resetState()
	end
end)

junktraderPoints:GetPropertyChangedSignal("Value"):Connect(function()
	updatePointsDisplay()
	updateRewardPreview()
end)

local activeJunkTrader = getActiveJunkTraderFrame()
activeJunkTrader:GetPropertyChangedSignal("Visible"):Connect(function()
	if activeJunkTrader.Visible then
		bindUiButtons()
		updatePointsDisplay()
		updateRewardPreview()
	end
end)

local newJunkTrader = NewUI and NewUI:FindFirstChild("JunkTrader")
if newJunkTrader and newJunkTrader ~= activeJunkTrader then
	newJunkTrader:GetPropertyChangedSignal("Visible"):Connect(function()
		if newJunkTrader.Visible then
			bindUiButtons()
			updatePointsDisplay()
			updateRewardPreview()
		end
	end)
end

local buffs = player:FindFirstChild("Buffs")
if buffs then
	buffs.ChildAdded:Connect(updateRewardPreview)
	buffs.ChildRemoved:Connect(updateRewardPreview)
end

updatePointsDisplay()
updateRewardPreview()
