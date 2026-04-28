local player = game.Players.LocalPlayer
local Mouse = player:GetMouse()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local PlayerGui = player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI", 5)
local NewWillPower = NewUI and NewUI:WaitForChild("WillPower", 5)
local populateNewWillpowerPanels
local Reroll
local isAutoRerolling = false
local autoThread = nil
local CheckIfExists
local restoreNewWillpowerIndexOnReturn = false
local lastWillpowerSelectionOpenAt = 0

local NormalReroll = player:WaitForChild("TraitPoint")
local LuckyReroll = player:WaitForChild("LuckyWillpower")

local UIHandlerModule = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local ChangeUnit = script.Parent.WillpowerFrame.Frame.Contents.Unit
local TraitReroll = script.Parent.WillpowerFrame.Frame.Bottom_Bar.Bottom_Bar.Reroll
local AutoReroll = script.Parent.WillpowerFrame.Frame.Bottom_Bar.Bottom_Bar.AutoReroll
local RobuxReroll = script.Parent.WillpowerFrame.Frame.Bottom_Bar.Bottom_Bar.LuckyWillpower
local MainFrame = script.Parent.WillpowerFrame.Frame
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local UnitFrame = ChangeUnit.Contents
local Tween = game:GetService("TweenService")
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local RunService = game:GetService("RunService")

local RerollText = script.Parent.WillpowerFrame.Frame.Contents.Willpower_Total
local LuckyText = script.Parent.WillpowerFrame.Frame.Contents.LuckyWillpower
local Luckyicon = script.Parent.WillpowerFrame.Frame.Contents.LuckyWillpowerIcon

local TraitLabel = script.Parent.WillpowerFrame.Frame.Contents.Current_Willpower.Unit_Willpower
local Upgrades = ReplicatedStorage.Upgrades

local UpgradesModule = require(ReplicatedStorage.Upgrades)
local UI_Handler = require(ReplicatedStorage.Modules.Client.UIHandler)
local Traits = require(ReplicatedStorage.Modules.Traits)
local Inventory = player.PlayerGui.UnitsGui.Inventory.Units

local WILLPOWER_INDEX_ORDER = {
	"Strong I",
	"Strong II",
	"Strong III",
	"Range I",
	"Range II",
	"Range III",
	"Nimble I",
	"Nimble II",
	"Nimble III",
	"Experience",
	"Precision Protocol",
	"Arms Dealer",
	"Tyrant's Damage",
	"Lightspeed",
	"Star Killer",
	"Padawan",
	"Apprentice",
	"Lord",
	"Merchant",
	"Mandalorian",
	"Tyrant's Wrath",
	"Cosmic Crusader",
	"Waders Will",
}

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
	if not root then return nil end
	if root:IsA("GuiButton") then
		return root
	end

	local preferredButton = root:FindFirstChild("Btn", true)
		or root:FindFirstChild("Button", true)

	if preferredButton and preferredButton:IsA("GuiButton") then
		return preferredButton
	end

	return root:FindFirstChildWhichIsA("GuiButton", true)
end

local function findTextObject(root, names)
	if not root then return nil end

	for _, name in ipairs(names) do
		local found = root:FindFirstChild(name, true)
		if found and (found:IsA("TextLabel") or found:IsA("TextButton")) then
			return found
		end
	end

	return nil
end

local function findImageObject(root)
	if not root then return nil end

	local preferredImage = root:FindFirstChild("Icon", true)
		or root:FindFirstChild("Ray", true)
		or root:FindFirstChild("Image", true)

	if preferredImage and (preferredImage:IsA("ImageLabel") or preferredImage:IsA("ImageButton")) then
		return preferredImage
	end

	return root:FindFirstChildWhichIsA("ImageLabel", true)
		or root:FindFirstChildWhichIsA("ImageButton", true)
end

local function getDebugInstancePath(instance)
	if not instance then
		return "nil"
	end

	local success, fullName = pcall(function()
		return instance:GetFullName()
	end)

	return success and fullName or instance.Name
end

local function debugWillpower(message)
--	warn("[WillpowerDebug] " .. message)
end

local function isScreenPointInside(gui, screenPoint)
	if not (gui and gui:IsA("GuiObject") and gui.Visible) then
		return false
	end

	local position = gui.AbsolutePosition
	local size = gui.AbsoluteSize

	return screenPoint.X >= position.X
		and screenPoint.Y >= position.Y
		and screenPoint.X <= position.X + size.X
		and screenPoint.Y <= position.Y + size.Y
end

local function isGuiActuallyVisible(gui)
	if not (gui and gui:IsA("GuiObject")) then
		return false
	end

	local current = gui
	while current do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end

		if current:IsA("LayerCollector") and current.Enabled == false then
			return false
		end

		current = current.Parent
	end

	return true
end

local function formatGuiObjects(guiObjects)
	local names = {}

	for index, guiObject in ipairs(guiObjects) do
		if index > 6 then
			break
		end

		table.insert(names, getDebugInstancePath(guiObject))
	end

	return table.concat(names, " | ")
end

local function resolveGuiActionTarget(root)
	if not root then
		return nil, nil
	end

	if root:IsA("GuiButton") then
		return root, "Activated"
	end

	local preferredButton = root:FindFirstChild("Btn", true)
		or root:FindFirstChild("Button", true)

	if preferredButton and preferredButton:IsA("GuiButton") then
		return preferredButton, "Activated"
	end

	local anyButton = root:FindFirstChildWhichIsA("GuiButton", true)
	if anyButton then
		return anyButton, "Activated"
	end

	if root:IsA("GuiObject") then
		return root, "InputBegan"
	end

	return nil, nil
end

local function connectGuiAction(root, attributeName, debugName, callback)
	local actionTarget, actionMode = resolveGuiActionTarget(root)
	debugWillpower(string.format(
		"bind %s | root=%s | rootClass=%s | target=%s | targetClass=%s | mode=%s",
		debugName,
		getDebugInstancePath(root),
		root and root.ClassName or "nil",
		getDebugInstancePath(actionTarget),
		actionTarget and actionTarget.ClassName or "nil",
		tostring(actionMode)
		))

	if not actionTarget then
		return nil
	end

	if actionTarget:GetAttribute(attributeName) then
		return actionTarget
	end

	actionTarget:SetAttribute(attributeName, true)
	local lastTriggerAt = 0
	local function trigger(source)
		lastTriggerAt = os.clock()
		debugWillpower("pressed " .. debugName .. " via " .. source .. " => " .. getDebugInstancePath(actionTarget))
		callback()
	end

	if actionMode == "Activated" then
		actionTarget.Activated:Connect(function()
			trigger("Activated")
		end)
	else
		actionTarget.Active = true
		actionTarget.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				trigger("InputBegan")
			end
		end)
	end

	UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		if not (actionTarget.Parent and isGuiActuallyVisible(actionTarget) and isGuiActuallyVisible(root)) then
			return
		end

		local screenPoint = Vector2.new(input.Position.X, input.Position.Y)
		if not isScreenPointInside(actionTarget, screenPoint) then
			return
		end

		local guiObjects = PlayerGui:GetGuiObjectsAtPosition(screenPoint.X, screenPoint.Y)
		local foundInStack = false
		for _, guiObject in ipairs(guiObjects) do
			if guiObject == actionTarget
				or guiObject:IsDescendantOf(actionTarget)
				or actionTarget:IsDescendantOf(guiObject) then
				foundInStack = true
				break
			end
		end

		debugWillpower(string.format(
			"fallback probe %s | processed=%s | point=%d,%d | stack=%s",
			debugName,
			tostring(gameProcessedEvent),
			screenPoint.X,
			screenPoint.Y,
			formatGuiObjects(guiObjects)
			))

		if not foundInStack then
			return
		end

		if os.clock() - lastTriggerAt < 0.15 then
			return
		end

		trigger("FallbackInputEnded")
	end)

	return actionTarget
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

	local viewport = ViewPortModule.CreateViewPort(unitName, shiny, true)
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

local function getSortedGuiChildren(container)
	local children = {}
	if not container then
		return children
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") then
			table.insert(children, child)
		end
	end

	table.sort(children, function(a, b)
		local aNumber = tonumber(a.Name)
		local bNumber = tonumber(b.Name)

		if aNumber and bNumber and aNumber ~= bNumber then
			return aNumber < bNumber
		elseif aNumber ~= nil then
			return true
		elseif bNumber ~= nil then
			return false
		end

		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end

		return a.Name < b.Name
	end)

	return children
end

local function getNumberedGuiChildren(container)
	local children = {}
	if not container then
		return children
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and tonumber(child.Name) then
			table.insert(children, child)
		end
	end

	table.sort(children, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)

	return children
end

local function ensureNumberedGuiChildren(container, amount)
	local children = getNumberedGuiChildren(container)
	local template = children[#children]

	if not template then
		return children
	end

	for index = #children + 1, amount do
		local clone = template:Clone()
		clone.Name = tostring(index)
		clone.LayoutOrder = index
		clone.Visible = true
		clone:SetAttribute("WillpowerIndexClone", true)
		clone.Parent = container
	end

	return getNumberedGuiChildren(container)
end

local function setTextIfExists(target, text)
	if target and (target:IsA("TextLabel") or target:IsA("TextButton")) then
		target.Text = tostring(text or "")
	end
end

local function collectTextObjects(root)
	local objects = {}
	if not root then
		return objects
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			table.insert(objects, descendant)
		end
	end

	table.sort(objects, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end

		return a:GetFullName() < b:GetFullName()
	end)

	return objects
end

local function copyTextByName(source, target, sourceNames, targetNames)
	local sourceText = findTextObject(source, sourceNames)
	local targetText = findTextObject(target, targetNames)

	if sourceText and targetText then
		targetText.Text = sourceText.Text
		return true
	end

	return false
end

local function copyOrderedTexts(source, target)
	local sourceTexts = collectTextObjects(source)
	local targetTexts = collectTextObjects(target)

	for index, targetText in ipairs(targetTexts) do
		local sourceText = sourceTexts[index]
		if sourceText then
			targetText.Text = sourceText.Text
		end
	end
end

local function copyIcon(source, target)
	local sourceImage = findImageObject(source)
	local targetImage = findImageObject(target)

	if sourceImage and targetImage then
		targetImage.Image = sourceImage.Image
		return true
	end

	return false
end

local function findShopPriceLabel(card)
	local button = card and card:FindFirstChild("Button")
	return findTextObject(button, {"Text", "Price"})
		or findTextObject(card, {"Price"})
end

local productPriceCache = {}

local function getProductPriceText(productId)
	if not productId then
		return nil
	end

	if productPriceCache[productId] then
		return productPriceCache[productId]
	end

	local success, productInfo = pcall(function()
		return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
	end)

	if not success or not productInfo or not productInfo.PriceInRobux then
		return nil
	end

	local priceText = tostring(productInfo.PriceInRobux) .. "R$"
	productPriceCache[productId] = priceText

	return priceText
end

local function generateTraitDescription(traitData)
	local descriptions = {}

	if traitData.Damage and traitData.Damage > 0 then
		table.insert(descriptions, "Increases damage by " .. traitData.Damage .. "%")
	end

	if traitData.Range and traitData.Range > 0 then
		table.insert(descriptions, "Increases range by " .. traitData.Range .. "%")
	end

	if traitData.Cooldown and traitData.Cooldown > 0 then
		table.insert(descriptions, "Decreases cooldown by " .. traitData.Cooldown .. "%")
	end

	if traitData.BossDamage and traitData.BossDamage > 0 then
		table.insert(descriptions, "Increases boss damage by " .. traitData.BossDamage .. "%")
	end

	if traitData.Money and traitData.Money > 0 then
		table.insert(descriptions, "Increases money by " .. traitData.Money .. "%")
	end

	if traitData.Exp and traitData.Exp > 0 then
		table.insert(descriptions, "Increases experience by " .. traitData.Exp .. "%")
	end

	if traitData.TowerBuffs then
		local towerBuffs = {}

		if traitData.TowerBuffs.Damage and traitData.TowerBuffs.Damage ~= 1 then
			table.insert(towerBuffs, "damage by " .. math.floor((traitData.TowerBuffs.Damage - 1) * 100) .. "%")
		end

		if traitData.TowerBuffs.Range and traitData.TowerBuffs.Range ~= 1 then
			table.insert(towerBuffs, "range by " .. math.floor((traitData.TowerBuffs.Range - 1) * 100) .. "%")
		end

		if traitData.TowerBuffs.Cooldown and traitData.TowerBuffs.Cooldown ~= 1 then
			table.insert(towerBuffs, "cooldown by " .. math.floor((1 - traitData.TowerBuffs.Cooldown) * 100) .. "%")
		end

		if #towerBuffs > 0 then
			table.insert(descriptions, "Global Buffs: increases " .. table.concat(towerBuffs, ", increases "))
		end
	end

	if #descriptions == 0 then
		return "No stat bonuses"
	end

	return table.concat(descriptions, ", ")
end

local function getNewWillPowerFrame()
	if NewWillPower and NewWillPower.Parent then
		return NewWillPower
	end

	NewUI = PlayerGui:FindFirstChild("NewUI")
	NewWillPower = NewUI and NewUI:FindFirstChild("WillPower")
	return NewWillPower
end

local function getWillpowerMenuTarget()
	return getNewWillPowerFrame() and "WillPower" or "WillpowerFrame"
end

local function getCloseAllFunction(timeoutSeconds)
	local closeAll = _G.CloseAll
	local timeoutAt = os.clock() + (timeoutSeconds or 1)

	while typeof(closeAll) ~= "function" and os.clock() < timeoutAt do
		task.wait()
		closeAll = _G.CloseAll
	end

	if typeof(closeAll) == "function" then
		return closeAll
	end

	return nil
end

local function safeCloseAll(targetName)
	local newFrame = getNewWillPowerFrame()
	local unitsFrame = NewUI and NewUI:FindFirstChild("Units")
	local indexFrame = newFrame and newFrame:FindFirstChild("Index")
	debugWillpower(string.format(
		"safeCloseAll:start target=%s | newVisible=%s | unitsVisible=%s | indexVisible=%s | restoreIndex=%s",
		tostring(targetName),
		tostring(newFrame and newFrame.Visible),
		tostring(unitsFrame and unitsFrame.Visible),
		tostring(indexFrame and indexFrame.Visible),
		tostring(restoreNewWillpowerIndexOnReturn)
		))

	if targetName == "Units" and unitsFrame and unitsFrame:IsA("GuiObject") then
		if newFrame and newFrame:IsA("GuiObject") then
			newFrame.Visible = false
		end
		if indexFrame and indexFrame:IsA("GuiObject") then
			restoreNewWillpowerIndexOnReturn = indexFrame.Visible == true
			indexFrame.Visible = false
		else
			restoreNewWillpowerIndexOnReturn = false
		end
		unitsFrame.Visible = true
		debugWillpower(string.format(
			"safeCloseAll:units newVisible=%s | unitsVisible=%s | indexVisible=%s | restoreIndex=%s",
			tostring(newFrame and newFrame.Visible),
			tostring(unitsFrame and unitsFrame.Visible),
			tostring(indexFrame and indexFrame.Visible),
			tostring(restoreNewWillpowerIndexOnReturn)
			))
		return true
	end

	if targetName == getWillpowerMenuTarget() and newFrame and newFrame:IsA("GuiObject") then
		newFrame.Visible = true
		if indexFrame and indexFrame:IsA("GuiObject") then
			indexFrame.Visible = restoreNewWillpowerIndexOnReturn
		end
		restoreNewWillpowerIndexOnReturn = false
		local currentUnits = NewUI and NewUI:FindFirstChild("Units")
		if currentUnits and currentUnits:IsA("GuiObject") then
			currentUnits.Visible = false
		end
		debugWillpower(string.format(
			"safeCloseAll:returnToWillpower newVisible=%s | unitsVisible=%s | indexVisible=%s | restoreIndex=%s",
			tostring(newFrame and newFrame.Visible),
			tostring(currentUnits and currentUnits.Visible),
			tostring(indexFrame and indexFrame.Visible),
			tostring(restoreNewWillpowerIndexOnReturn)
			))
		return true
	end

	if targetName == nil and newFrame and newFrame:IsA("GuiObject") then
		newFrame.Visible = false
		if unitsFrame and unitsFrame:IsA("GuiObject") then
			unitsFrame.Visible = false
		end
		if indexFrame and indexFrame:IsA("GuiObject") then
			indexFrame.Visible = false
		end
		restoreNewWillpowerIndexOnReturn = false
		debugWillpower(string.format(
			"safeCloseAll:closeAll newVisible=%s | unitsVisible=%s | indexVisible=%s | restoreIndex=%s",
			tostring(newFrame and newFrame.Visible),
			tostring(unitsFrame and unitsFrame.Visible),
			tostring(indexFrame and indexFrame.Visible),
			tostring(restoreNewWillpowerIndexOnReturn)
			))
		return true
	end

	local closeAll = getCloseAllFunction(1)
	if closeAll then
		debugWillpower("safeCloseAll:fallback CloseAll for target=" .. tostring(targetName))
		closeAll(targetName)
		return true
	end

	debugWillpower("safeCloseAll:failed target=" .. tostring(targetName))
	return false
end

local function getNewWillpowerContents()
	local newFrame = getNewWillPowerFrame()
	return findChildPath(newFrame, {"Body", "Main", "Contents"})
end

local selectedTowerTraitChangedConnection
local getSelectedWillpowerTraitText

local function updateNewWillpowerProfile()
	local contents = getNewWillpowerContents()
	local profile = contents and findChildPath(contents, {"Profile"})
	local willpowerSection = contents and findChildPath(contents, {"Willpower"})
	local selectedTower = script.Parent.SelectedTower.Value
	local currentTrait = getSelectedWillpowerTraitText()
	local traitData = selectedTower and Traits.Traits[selectedTower:GetAttribute("Trait")] or nil
	local descriptionText = "Select a unit to begin!"

	if selectedTower then
		descriptionText = traitData and generateTraitDescription(traitData) or "This unit has no Willpower yet."
	end

	if profile then
		local addButtonRoot = profile:FindFirstChild("+")
		local placeholderContainer = findChildPath(profile, {"Placeholder"})
		local shadow = profile:FindFirstChild("Shadow")
		local hasTower = selectedTower ~= nil

		if addButtonRoot and addButtonRoot:IsA("GuiObject") then
			addButtonRoot.Visible = not hasTower
		end

		if shadow and shadow:IsA("GuiObject") then
			shadow.Visible = hasTower
		end

		attachViewport(
			placeholderContainer,
			hasTower and selectedTower.Name or nil,
			hasTower and selectedTower:GetAttribute("Shiny") or nil
		)
	end

	setTextIfExists(
		findTextObject(findChildPath(willpowerSection, {"Current"}) or willpowerSection, {"Text"}),
		currentTrait
	)
	setTextIfExists(
		findTextObject(findChildPath(willpowerSection, {"Description"}) or willpowerSection, {"Text", "Description"}),
		descriptionText
	)
end

getSelectedWillpowerTraitText = function()
	local selectedTower = script.Parent.SelectedTower.Value
	if not selectedTower then
		return "No Willpower"
	end

	local trait = selectedTower:GetAttribute("Trait")
	if trait and trait ~= "" then
		return trait
	end

	return "No Willpower"
end

local function updateNewWillpowerStatusEffects()
	local contents = getNewWillpowerContents()
	local statusEffects = contents and findChildPath(contents, {"Willpower", "Statuseffects"})
	local current = contents and findChildPath(contents, {"Willpower", "Current"})

	setTextIfExists(findChildPath(statusEffects, {"1", "Text"}), NormalReroll.Value .. "/1")
	setTextIfExists(findChildPath(statusEffects, {"2", "Text"}), LuckyReroll.Value .. "/1")
	setTextIfExists(current and current:FindFirstChild("Text"), getSelectedWillpowerTraitText())
end

local function clearWillpowerSelectionMode()
	_G.traitTowerSelection = false
	_G.traitTowerSelectTower = nil
	_G.traitTowerCancelSelection = nil
end

local function openWillpowerUnitSelection()
	debugWillpower("openWillpowerUnitSelection")
	_G.traitTowerSelection = true
	_G.traitTowerSelectTower = function(_, tower)
		if not tower then
			debugWillpower("traitTowerSelectTower received nil tower")
			return false
		end

		debugWillpower("traitTowerSelectTower selected=" .. tower.Name)
		script.Parent.SelectedTower.Value = tower
		clearWillpowerSelectionMode()
		safeCloseAll(getWillpowerMenuTarget())
		return true
	end
	_G.traitTowerCancelSelection = clearWillpowerSelectionMode
	safeCloseAll("Units")
end

local function requestWillpowerUnitSelection()
	if os.clock() - lastWillpowerSelectionOpenAt < 0.15 then
		return
	end

	lastWillpowerSelectionOpenAt = os.clock()
	openWillpowerUnitSelection()
end

local function wireNewWillpowerAddButton()
	local contents = getNewWillpowerContents()
	local profile = contents and findChildPath(contents, {"Profile"})
	local addButtonRoot = contents and findChildPath(contents, {"Profile", "+"})
	local placeholderContainer = contents and findChildPath(contents, {"Profile", "Placeholder"})
	local shadow = profile and profile:FindFirstChild("Shadow")

	connectGuiAction(addButtonRoot, "WillpowerAddConnected", "AddButton", requestWillpowerUnitSelection)
	connectGuiAction(placeholderContainer, "WillpowerProfileConnected", "ProfilePlaceholder", requestWillpowerUnitSelection)
	connectGuiAction(shadow, "WillpowerProfileShadowConnected", "ProfileShadow", requestWillpowerUnitSelection)
end

local function populateNewWillpowerIndex()
	local newFrame = getNewWillPowerFrame()
	local targetContents = findChildPath(newFrame, {"Index", "Contents"})
	if not targetContents then
		return
	end

	local oldContents = findChildPath(script.Parent.WillpowerFrame, {"Index", "Index", "Contents"})
	local targetCards = ensureNumberedGuiChildren(targetContents, #WILLPOWER_INDEX_ORDER)

	for index, targetCard in ipairs(targetCards) do
		local traitName = WILLPOWER_INDEX_ORDER[index]
		local traitData = traitName and Traits.Traits[traitName]
		local sourceCard = oldContents and traitName and oldContents:FindFirstChild(traitName)

		targetCard.Visible = traitData ~= nil

		if traitData then
			local copiedIcon = sourceCard and copyIcon(sourceCard, targetCard)

			if not (sourceCard and copyTextByName(sourceCard, targetCard, {"Title", "Name"}, {"Title", "Name"})) then
				setTextIfExists(findTextObject(targetCard, {"Title", "Name"}), traitName)
			end

			if not (sourceCard and copyTextByName(sourceCard, targetCard, {"Subtext", "Description", "Text"}, {"Text", "Description"})) then
				setTextIfExists(findTextObject(targetCard, {"Text", "Description"}), traitData and generateTraitDescription(traitData) or "")
			end

			local targetIcon = findImageObject(targetCard)
			if not copiedIcon and targetIcon and traitData and traitData.ImageID then
				targetIcon.Image = traitData.ImageID
			end
		end
	end
end

--// Colors
local baseColorBottom = Color3.fromRGB(27, 102, 0)
local baseColorTop = Color3.fromRGB(19, 163, 0)
local toggledColorBottom = Color3.fromRGB(102,0,0)
local toggledColorTop = Color3.fromRGB(255,0,0)

function updatePrice(SelectedTower)
	local statsTower = UpgradesModule[SelectedTower.Name]
	local priceMultiplier = 1
	local trait = SelectedTower:GetAttribute("Trait")

	if TraitsModule.Traits[trait] then
		if TraitsModule.Traits[trait]["Money"] then
			priceMultiplier = (1 - (TraitsModule.Traits[trait]["Money"] / 100))
		end
	end

	local priceVal = math.round(statsTower["Upgrades"][1].Price * priceMultiplier)
	MainFrame.Contents.Unit.Contents.UnitPrice.Text = priceVal .. " $"
end


--function FilterSupport()
--	local isNotEligible = {}

--	for i,v in Upgrades:GetDescendants() do
--		if v:IsA("ModuleScript") then
--			local Info  = require(v)
--			if Info[v.Name]["Support"] then
--				table.insert(isNotEligible, v.Name)
--			end

--		end
--	end

--	local unitChildren = Inventory.Frame.Left_Panel.Contents.Act.UnitsScroll:GetChildren()
--	for _, unit in unitChildren do
--		if not (unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue")) then continue end
--		for i,v in isNotEligible do
--			if unit.TowerValue.Value == v then
--				unit.Visible = false
--				break
--			end	
--		end	

--		Inventory:GetPropertyChangedSignal("Visible"):Once(function()
--			for _, unit in ipairs(unitChildren) do
--				if unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue") then
--					unit.Visible = true
--				end
--			end
--		end)
--	end
--end


--RunService.RenderStepped:Connect(function(dt)
--	local rotationSpeed = 100 * dt
--	UnitFrame.GlowEffect.UIGradient.Rotation = (UnitFrame.GlowEffect.UIGradient.Rotation + rotationSpeed) % 360
--	UnitFrame.Image.UIGradient.Rotation = UnitFrame.GlowEffect.UIGradient.Rotation
--end)

RerollText.Text = NormalReroll.Value.."/1"
LuckyText.Text = LuckyReroll.Value.."/1"

if NormalReroll.Value >= 1 then
	RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(164, 30, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 24, 255))}
else
	RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
end

if LuckyReroll.Value >= 1 then
	LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(164, 30, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 24, 255))}
else
	LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
end


local cooldowntick = 0
local mythicalpluscooldown = false

local traitcolors = Traits.TraitColors

local SelectedTower = script.Parent.SelectedTower

script.Parent.SelectedTower.Changed:Connect(function()
	local SelectedTower = script.Parent.SelectedTower

	if selectedTowerTraitChangedConnection then
		selectedTowerTraitChangedConnection:Disconnect()
		selectedTowerTraitChangedConnection = nil
	end

	if not SelectedTower.Value then
		updateNewWillpowerProfile()
		updateNewWillpowerStatusEffects()
		return
	end

	if MainFrame.Contents.Unit.Contents:FindFirstChildOfClass("ViewportFrame") then MainFrame.Contents.Unit.Contents:FindFirstChildOfClass("ViewportFrame"):Destroy() end

	local trait = SelectedTower.Value:GetAttribute("Trait")
	if trait and trait ~= "" then
		TraitLabel.Text = trait
		--TraitLabel.Parent.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
		MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[trait].ImageID
		MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
		TraitLabel.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
		--TraitLabel.Parent.GlowEffect.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
	else
		TraitLabel.Text = "No WillPower"
		TraitLabel.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}
		--TraitLabel.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}
		--TraitLabel.Parent.GlowEffect.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}
		MainFrame.Contents.Unit.Contents.TraitIcon.Image = ""
	end

	local statsTower = UpgradesModule[SelectedTower.Value.Name]
	local rarity = statsTower["Rarity"] or "Rare"
	--script.Parent.MainFrame.Unit.UIStroke.UIGradient.Color = game.ReplicatedStorage.Borders[rarity].Color
	MainFrame.Contents.Unit.Contents.Border.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color
	MainFrame.Contents.Unit.Contents.Glow.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color

	--script.Parent.MainFrame.Unit.Image.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color

	MainFrame.Contents.Unit.Contents.Text_Container.Unit_Level.Text = SelectedTower.Value:GetAttribute("Level")
	--script.Parent.MainFrame.Unit.UnitLvl.Text = SelectedTower.Value:GetAttribute("Level")

	local CharModel = GetUnitModel[SelectedTower.Value.Name]
	local priceMultiplier = 1
	if TraitsModule.Traits[SelectedTower.Value:GetAttribute("Trait")] then
		if TraitsModule.Traits[SelectedTower.Value:GetAttribute("Trait")]["Money"] then
			priceMultiplier = (1-(TraitsModule.Traits[SelectedTower.Value:GetAttribute("Trait")]["Money"]/100))
		end
	end

	updatePrice(SelectedTower.Value)

	if SelectedTower.Value then
		selectedTowerTraitChangedConnection = SelectedTower.Value:GetAttributeChangedSignal("Trait"):Connect(function()
			if script.Parent.SelectedTower.Value ~= SelectedTower.Value then
				return
			end

			updatePrice(SelectedTower.Value)
			updateNewWillpowerProfile()
			updateNewWillpowerStatusEffects()
		end)
	end

	if CharModel then
		local vp = ViewPortModule.CreateViewPort(SelectedTower.Value.Name,SelectedTower.Value:GetAttribute("Shiny"),true)
		vp.ZIndex = 5
		vp.Active = false
		vp.AnchorPoint = Vector2.new(.5,.5)
		vp.Position = UDim2.new(.5,0,.5,0)
		vp.Size = UDim2.new(1.1,0,1,0)
		vp.Parent = MainFrame.Contents.Unit.Contents
		if SelectedTower.Value:GetAttribute("Shiny") then
			MainFrame.Contents.Unit.Contents.Icon_Container.Shiny_Icon.Visible = true
		else
			MainFrame.Contents.Unit.Contents.Icon_Container.Shiny_Icon.Visible = false
		end

		UnitFrame.Text_Container.Unit_Level.Text = SelectedTower.Value:GetAttribute("Level")
		UnitFrame.Plus.Transparency = 1
		UnitFrame.Plus.UIStroke.Transparency = 1

		if player:FindFirstChild("OwnGamePasses"):FindFirstChild("2x Willpower Luck").Value == true or player:FindFirstChild("Buffs"):FindFirstChild("WillpowerLuckyCrystal") then
			UnitFrame.Indicator.ImageLabel.Visible = true
		end
		--UnitFrame.UName.Text = SelectedTower.Value.Name
	else
		print(SelectedTower.Value)
		warn("Selected tower was not found as a model. Selected tower name: "..SelectedTower.Value.Name)
	end

	updateNewWillpowerProfile()
	updateNewWillpowerStatusEffects()
end)

NormalReroll.Changed:Connect(function()
	RerollText.Text = NormalReroll.Value.."/1"
	if NormalReroll.Value >= 1 then
		RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(177, 23, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(240, 28, 255))}
	else
		RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
	end

	updateNewWillpowerStatusEffects()
end)

LuckyReroll.Changed:Connect(function()
	LuckyText.Text = LuckyReroll.Value.."/1"
	if LuckyReroll.Value >= 1 then
		LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(177, 23, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(240, 28, 255))}
	else
		LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
	end

	updateNewWillpowerStatusEffects()
end)



MainFrame.Bottom_Bar.Bottom_Bar.Index.Activated:Connect(function()
	UIHandlerModule.PlaySound(MainFrame.Parent.Index.Visible and "Close" or "Open")

	MainFrame.Parent.Index.Visible = not MainFrame.Parent.Index.Visible
end)

--[[
local function Reroll()
	local tower = script.Parent.SelectedTower.Value
	if tower then
		if not mythicalpluscooldown then
			mythicalpluscooldown = true
			local trait = game.ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower)
			if Traits.Traits[trait] then
				if Traits.Traits[trait].Rarity == "Unique" or Traits.Traits[trait].Rarity == "Mythical" then
					_G.Message("You got a "..Traits.Traits[trait].Rarity.." trait!",Color3.new(1, 0.666667, 0))
					UI_Handler.PlaySound("LuckActive")
					UI_Handler.CreateConfetti()
					task.delay(3, function()
						mythicalpluscooldown = false
					end)
				else
					task.delay(0.02, function()
						mythicalpluscooldown = false
					end)
				end


				TraitLabel.Size = UDim2.new(0,0,0,0)
				Tween:Create(TraitLabel,TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{Size = UDim2.new(1, 0,0.67, 0)}):Play()
				TraitLabel.Text = trait
				MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[tower:GetAttribute("Trait")].ImageID
				MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
			--	TraitLabel.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
				TraitLabel.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
				--TraitLabel.Parent.GlowEffect.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
			else

				mythicalpluscooldown = false
				UIHandlerModule.PlaySound("Error")
				--_G.Message(trait,Color3.new(0.776471, 0.239216, 0.239216))
			end
		else
			--UIHandlerModule.PlaySound("Error")
			_G.Message("Please wait before rerolling again!",Color3.new(0.776471, 0.239216, 0.239216))
		end
	end
end
--]]

Reroll = function(LuckyRoll)
	warn(LuckyRoll)
	local tower = script.Parent.SelectedTower.Value
	if tower then
		if not mythicalpluscooldown then
			mythicalpluscooldown = true

			local trait = nil

			if LuckyRoll then
				trait = game.ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower, LuckyRoll)
			else
				trait = game.ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower)
			end
			local MythicalWillpowerPity = player:FindFirstChild("MythicalPityWP").Value
			local LegendaryWillpowerPity = player:FindFirstChild("LegendaryPityWP").Value

			local pityBars = player.PlayerGui.CoreGameUI.Willpower.WillpowerFrame.Frame:WaitForChild("Pity_Bars")
			local mythicalFrame = pityBars:WaitForChild("Mythical_Pity")
			local legendaryFrame = pityBars:WaitForChild("Legendar yPity")

			mythicalFrame.Contents.Bar.Size = UDim2.fromScale(MythicalWillpowerPity/500, 1)
			mythicalFrame.Contents.Pity.Text = MythicalWillpowerPity .. "/" .. 500

			legendaryFrame.Contents.Bar.Size = UDim2.fromScale(LegendaryWillpowerPity / 250, 1)
			legendaryFrame.Contents.Pity.Text = LegendaryWillpowerPity .. "/" .. 250

			if Traits.Traits[trait] then
				local rarity = Traits.Traits[trait].Rarity
				local color = traitcolors[rarity].Gradient

				if rarity == "Unique" or rarity == "Mythical" then
					_G.Message("You got a " .. rarity .. " trait!", Color3.new(1, 0.666667, 0))
					UI_Handler.PlaySound("LuckActive")
					UI_Handler.CreateConfetti()
					task.delay(3, function()
						mythicalpluscooldown = false
					end)
				else
					task.delay(0.02, function()
						mythicalpluscooldown = false
					end)
				end

				TraitLabel.Size = UDim2.new(0, 0, 0, 0)
				Tween:Create(TraitLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0.67, 0)}):Play()
				TraitLabel.Text = trait
				warn(Traits.Traits[tower:GetAttribute("Trait")])
				MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[tower:GetAttribute("Trait")].ImageID
				MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = color
				TraitLabel.UIGradient.Color = color

				return rarity, trait
			else
				mythicalpluscooldown = false
				UIHandlerModule.PlaySound("Error")
				return nil
			end
		else
			_G.Message("Please wait before rerolling again!", Color3.new(0.776471, 0.239216, 0.239216))
			return nil
		end
	else
		_G.Message("Select a unit to start rolling!", Color3.new(255,0,0)) 
	end
end


TraitReroll.Activated:Connect(function()
	if isAutoRerolling then _G.Message("Stop autorolling to roll manually!", Color3.new(255,0,0)) return end
	Reroll()
end)

local open = false
local function updateOpenState()
	local newFrame = getNewWillPowerFrame()
	open = script.Parent.WillpowerFrame.Visible or (newFrame and newFrame.Visible) or false
end

script.Parent.WillpowerFrame:GetPropertyChangedSignal('Visible'):Connect(updateOpenState)

if NewWillPower then
	NewWillPower:GetPropertyChangedSignal("Visible"):Connect(function()
		updateOpenState()

		if NewWillPower.Visible and populateNewWillpowerPanels then
			populateNewWillpowerPanels()
		end
	end)
end

updateOpenState()

AutoReroll.Activated:Connect(function()
	local tower = script.Parent.SelectedTower.Value
	if not tower then _G.Message("Select a unit to start rolling!", Color3.new(255,0,0)) return end

	isAutoRerolling = not isAutoRerolling

	if isAutoRerolling then
		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(toggledColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(toggledColorTop)
	else
		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(baseColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(baseColorTop)
	end

	warn('autoroll time')

	task.spawn(function()
		while isAutoRerolling do
			local result, trait = Reroll()

			if not open then
				warn("Frame Not Open")
				isAutoRerolling = false
				break
			end

			print(trait, result)

			if result == "Mythical" or trait == 'Cosmic Crusader' or trait == "Waders Will" then
				warn("Mythic Trait")
				isAutoRerolling = false

				break
			end

			if player.TraitPoint.Value <= 0 then
				warn("No More Traits")
				isAutoRerolling = false
				break
			end

			task.wait(0.25) -- Wait a bit to prevent spamming
		end

		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(baseColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(baseColorTop)
	end)
end)

local ClickButtonUnit =  MainFrame.Contents.Unit

connectGuiAction(ChangeUnit, "WillpowerLegacyChangeUnitConnected", "LegacyChangeUnit", requestWillpowerUnitSelection)

CheckIfExists = ReplicatedStorage.Functions.BuyNowWP



RobuxReroll.MouseButton1Down:Connect(function()
	local Check = CheckIfExists:InvokeServer("LuckyWillpower")

	warn(Check)
	if not Check then
		MarketplaceService:PromptProductPurchase(player,3221515245)
	else
		Reroll(true)
	end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userID,productID,isPurchase)
	--print(productID,isPurchase)
	if userID ~= player.UserId then return end
	--print(not isPurchase,productID ~= 3221515245)
	if not isPurchase or productID ~= 3221515245 then return end
	--print("Reroll")
	Reroll()
end)

MainFrame.X_Close.Activated:Connect(function()
	safeCloseAll()
end)

local function wireNewWillpowerBottomButtons()
	local newFrame = getNewWillPowerFrame()
	local indexFrame = newFrame and newFrame:FindFirstChild("Index")
	local closeButtonRoot = findChildPath(newFrame, {"Body", "Closebtn"})
	local indexButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Index"})
	local rerollButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Reroll"})
	local robuxRerollButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Robux_Reroll"})
	local selectUnitButtonRoot = findChildPath(newFrame, {"Body", "Main", "Contents", "Bottom_Bar", "Select_Unit"})

	connectGuiAction(closeButtonRoot, "WillpowerCloseConnected", "CloseButton", function()
		safeCloseAll()
	end)

	connectGuiAction(indexButtonRoot, "WillpowerIndexConnected", "IndexButton", function()
		local targetIndex = indexFrame and indexFrame:IsA("GuiObject") and indexFrame or MainFrame.Parent:FindFirstChild("Index")
		if not (targetIndex and targetIndex:IsA("GuiObject")) then
			debugWillpower("IndexButton missing target Index frame")
			return
		end

		UIHandlerModule.PlaySound(targetIndex.Visible and "Close" or "Open")
		targetIndex.Visible = not targetIndex.Visible
		restoreNewWillpowerIndexOnReturn = targetIndex.Visible == true
		debugWillpower("IndexButton toggled targetIndex=" .. tostring(targetIndex.Visible))
	end)

	connectGuiAction(rerollButtonRoot, "WillpowerRerollConnected", "RerollButton", function()
		if isAutoRerolling then
			_G.Message("Stop autorolling to roll manually!", Color3.new(255, 0, 0))
			return
		end

		Reroll()
	end)

	connectGuiAction(robuxRerollButtonRoot, "WillpowerLuckyConnected", "RobuxRerollButton", function()
		local Check = CheckIfExists:InvokeServer("LuckyWillpower")

		if not Check then
			MarketplaceService:PromptProductPurchase(player, 3221515245)
		else
			Reroll(true)
		end
	end)

	connectGuiAction(selectUnitButtonRoot, "WillpowerSelectUnitConnected", "SelectUnitButton", function()
		openWillpowerUnitSelection()
	end)
end

local Functions = game.ReplicatedStorage:WaitForChild("Functions")
local GetMarketInfoByName = Functions:WaitForChild("GetMarketInfoByName")
local BuyEvent = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("Buy")
local GiftFolder = script.Parent.Parent.Parent:WaitForChild('CoreGameUI').Gift
local GiftFrame = GiftFolder.GiftFrame
local SelectedGiftId = GiftFolder.SelectedGiftId

local function getOldWillpowerShopCards()
	local sideShopContents = MainFrame.Parent:FindFirstChild("Side_Shop")
		and MainFrame.Parent.Side_Shop:FindFirstChild("Contents")
	local cards = {}

	if not sideShopContents then
		return cards
	end

	for _, child in ipairs(sideShopContents:GetChildren()) do
		if child:IsA("GuiObject") and child:FindFirstChild("Contents") then
			table.insert(cards, child)
		end
	end

	table.sort(cards, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then
			return a.LayoutOrder < b.LayoutOrder
		end

		return a.Name < b.Name
	end)

	return cards
end

local function wireNewWillpowerShopCard(card, productName)
	if not (card and productName) then
		return nil
	end

	local success, info = pcall(function()
		return GetMarketInfoByName:InvokeServer(productName)
	end)

	if not success or not info then
		return nil
	end

	local buyButton = findChildPath(card, {"Button", "Btn"})
		or findFirstGuiButton(card:FindFirstChild("Button"))
	local giftButton = findFirstGuiButton(card:FindFirstChild("Buttom"))
		or findFirstGuiButton(card:FindFirstChild("Gift"))

	if buyButton and buyButton:GetAttribute("WillpowerProductName") ~= productName then
		buyButton:SetAttribute("WillpowerProductName", productName)
		buyButton.Activated:Connect(function()
			BuyEvent:FireServer(info.Id)
		end)
	end

	if giftButton and info.GiftId and giftButton:GetAttribute("WillpowerGiftName") ~= productName then
		giftButton:SetAttribute("WillpowerGiftName", productName)
		giftButton.Activated:Connect(function()
			SelectedGiftId.Value = info.GiftId
			GiftFrame.Visible = true
		end)
	end

	return info
end

local function populateNewWillpowerGems()
	local newFrame = getNewWillPowerFrame()
	local targetContents = findChildPath(newFrame, {"Gems", "Contents"})
	if not targetContents then
		return
	end

	local sourceCards = getOldWillpowerShopCards()
	local targetCards = getNumberedGuiChildren(targetContents)

	for index, targetCard in ipairs(targetCards) do
		local sourceCard = sourceCards[index]
		targetCard.Visible = sourceCard ~= nil

		if sourceCard then
			copyIcon(sourceCard, targetCard)

			local copiedTitle = copyTextByName(sourceCard, targetCard, {"Title", "Name"}, {"Title", "Name"})
			local copiedText = copyTextByName(sourceCard, targetCard, {"Text", "Price", "Subtext"}, {"Text", "Price"})

			if not copiedTitle and not copiedText then
				copyOrderedTexts(sourceCard, targetCard)
			elseif not copiedTitle then
				setTextIfExists(findTextObject(targetCard, {"Title", "Name"}), sourceCard.Name)
			end

			local productInfo = wireNewWillpowerShopCard(targetCard, sourceCard.Name)
			local priceText = productInfo and getProductPriceText(productInfo.Id)
			if priceText then
				setTextIfExists(findShopPriceLabel(targetCard), priceText)
			end
		end
	end
end

populateNewWillpowerPanels = function()
	debugWillpower("populateNewWillpowerPanels")
	populateNewWillpowerIndex()
	populateNewWillpowerGems()
	wireNewWillpowerAddButton()
	wireNewWillpowerBottomButtons()
	updateNewWillpowerProfile()
	updateNewWillpowerStatusEffects()
end

local function NewTokenUI(ui)
	local BuyButton = ui.Contents:WaitForChild("Buy")
	local GiftButton = ui.Contents:WaitForChild("Gift")

	local Info = GetMarketInfoByName:InvokeServer(ui.Name) --Market.GetInfoOfName(ui.Name)

	BuyButton.MouseButton1Down:Connect(function()
		BuyEvent:FireServer(Info.Id)
	end)

	GiftButton.MouseButton1Down:Connect(function()
		SelectedGiftId.Value = Info.GiftId
		GiftFrame.Visible = true
	end)
end

for _, ui in MainFrame.Parent.Side_Shop.Contents:GetChildren() do
	if not ui:FindFirstChild("Contents") then continue end
	NewTokenUI(ui)
end

populateNewWillpowerPanels()

local Zone = require(ReplicatedStorage.Modules.Zone)
local Container = workspace:WaitForChild('Willpower'):WaitForChild('Willpower'):WaitForChild("Hitbox")
local zone = Zone.new(Container)

zone.playerEntered:Connect(function(plr)
	if plr == player then
		UIHandlerModule.DisableAllButtons()
		populateNewWillpowerPanels()
		safeCloseAll(getWillpowerMenuTarget())
		_G.CanSummon = false
		open = true

		local MythicalWillpowerPity = player:FindFirstChild("MythicalPityWP").Value
		player.PlayerGui.CoreGameUI.Willpower.WillpowerFrame.Frame.Pity_Bars.Mythical_Pity.Contents.Bar.Size = UDim2.fromScale(MythicalWillpowerPity/500,1)
		player.PlayerGui.CoreGameUI.Willpower.WillpowerFrame.Frame.Pity_Bars.Mythical_Pity.Contents.Pity.Text = MythicalWillpowerPity.."/"..500
	end
end)

zone.playerExited:Connect(function(plr)
	if plr == player then
		_G.CanSummon = true
		clearWillpowerSelectionMode()
		safeCloseAll()
		UIHandlerModule.EnableAllButtons()
	end
end)


