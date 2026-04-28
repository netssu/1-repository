-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- CONSTANTS
local UiHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local ExpModule = require(ReplicatedStorage.Modules.ExpModule)
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local UpgradesModule = require(ReplicatedStorage.Upgrades)
local ItemStatsModule = require(ReplicatedStorage.ItemStats)
local UI_Animation_Module = require(ReplicatedStorage.Modules:WaitForChild('UI_Animations'))
local TypeIcons = require(ReplicatedStorage.Modules.TypeIcons)
local SellAndFuseModule = require(ReplicatedStorage.Modules.SellAndFuse)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local GradientModule = require(ReplicatedStorage.Modules.GradientsModule)
local ButtonAnimation = require(ReplicatedStorage.Modules.ButtonAnimation)
local ButtonCreationModule = require(ReplicatedStorage.Modules.ButtonCreationModule)
local Functions = require(ReplicatedStorage.Modules.Functions)

local layoutorders = {"Exclusive","Unique","Secret","Mythical","Legendary","Epic","Rare"}
local requiredSlotLevel = {0,0,0,10,20,30}

local RARITY_STARS = {
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythical = 5,
	Supreme = 6,
	Exclusive = 6,
	Secret = 6,
	Unique = 5
}

-- VARIABLES
_G.traitTowerSelection = false
_G.traitTowerSelectTower = nil
_G.traitTowerCancelSelection = nil
_G.InventoryButtonsClickable = true
_G.evolveTowerSelection = false
_G.levelupTowerSelection = false
_G.junkTraderTowerSelection = false
_G.junkTraderCanSelectTower = nil
_G.junkTraderIsTowerSelected = nil
_G.junkTraderSelectTower = nil
_G.junkTraderCancelSelection = nil

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
repeat task.wait() until player:FindFirstChild("DataLoaded")

local LockTowerEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("LockTower")
local EquipCosmeticFunction = ReplicatedStorage:WaitForChild("Functions"):WaitForChild("EquipCosmetic")
local UnitsCache = ReplicatedStorage.Cache.Inventory

local NewUI = playerGui:WaitForChild("NewUI")
local UnitsUI = NewUI:WaitForChild("Units")

local MainFrame = UnitsUI:WaitForChild("Main")
local AddFrame = MainFrame:WaitForChild("Add")
local UnitsQuantityText = AddFrame:WaitForChild("Amount")

local CraftFrame = MainFrame:WaitForChild("Craft")
local CraftBar = CraftFrame:WaitForChild("Bar"):WaitForChild("Bar")
local CraftButtons = CraftFrame:WaitForChild("Buttons"):WaitForChild("Buttons")
local EquipBtn = CraftButtons:WaitForChild("Equip").Btn
local EquipBtnText = CraftButtons:WaitForChild("Equip").Text
local FuseBtn = CraftButtons:WaitForChild("Fuse").Btn
local ViewBtn = CraftButtons:WaitForChild("View").Btn
local ViewportPlaceholder = CraftFrame:WaitForChild("Placeholder").ViewportFrame
local CraftValues = CraftFrame:WaitForChild("Values")

local UnitCostText = CraftFrame:WaitForChild("Amount")
local UnitRarityText = CraftFrame:WaitForChild("Rarity")
local UnitNameText = CraftFrame:WaitForChild("UnitName")

local ItemsTab = MainFrame:WaitForChild("ItemsTab")
local ContentGrid = ItemsTab:WaitForChild("Content")

local TopLeft = MainFrame:WaitForChild("TopLeft")
local SearchBox = TopLeft:WaitForChild("Search").TextBox
local SellModeBtn = TopLeft:WaitForChild("Sell").Btn
local UnequipAllBtn = TopLeft:WaitForChild("Unequip").Btn

local SellMenu = UnitsUI:WaitForChild("Sell_Menu")
local FuseOptions = SellMenu:WaitForChild("Fuse_Options")
local ConfirmFuseBtn = FuseOptions:WaitForChild("Fuse")
local CancelFuseBtn = FuseOptions:WaitForChild("Cancel")

local SellMenuOptions = SellMenu:WaitForChild("Sell_Menu_Options")
local ConfirmSellBtn = SellMenuOptions:WaitForChild("Confirm")
local CancelSellBtn = SellMenuOptions:WaitForChild("Cancel")
local SelectRarityFilters = SellMenu:WaitForChild("Select_Rarity")

local CoreGameGui = playerGui:WaitForChild("CoreGameUI", 3)
local GameGui = playerGui:WaitForChild("GameGui", 3)
local LvlUp = GameGui and GameGui:FindFirstChild("LvlUp")
local LvlUpFrame = LvlUp and LvlUp:FindFirstChild("LvlUpFrame")

local SelectedTowerValue = Instance.new("ObjectValue")
SelectedTowerValue.Name = "SelectedTower"
SelectedTowerValue.Parent = script

local viewdebounce = false
local inGui = false
local oldEquippedTowers = {}
local latestSelectedButton
local refreshInventoryButtonVisibility

local currentFilter = "None"
local selectState = "None" 
local sellButtonList = {}
local fuseButtonList = {}

local buttonConnections = {
	["DisconnectAll"] = function(self)
		for index,element in pairs(self) do
			if typeof(element) == "RBXScriptConnection" then
				element:Disconnect()
				self[index] = nil
			end
		end
	end
}
local feedConnections = {}

local filteringType = {
	["None"] = function(TowersOwn)
		local newList = {}
		for _,Tower in TowersOwn do
			table.insert(newList,{ TowerButton = Tower.Button, LayoutOrder = table.find(layoutorders,Tower.Stats["Rarity"]) })
		end
		return newList
	end,
	["Cooldown"] = function(TowersOwn)
		local newList = {}
		for _,Tower in TowersOwn do
			table.insert(newList,{ TowerButton = Tower.Button, LayoutOrder = Tower.Stats.Upgrades[1].Cooldown })
		end
		return newList
	end,
	["Range"] = function(TowersOwn)
		local indexNum = 1
		local newList = {}
		while #TowersOwn > 0 do
			local highest,index = nil
			for i,Tower in TowersOwn do
				if highest == nil or Tower.Stats.Upgrades[1].Range > highest then
					highest = Tower.Stats.Upgrades[1].Range
					index = i
				end
			end
			table.insert(newList,{ TowerButton = TowersOwn[index].Button, LayoutOrder = indexNum })
			indexNum += 1
			table.remove(TowersOwn,index)
		end
		return newList
	end,
	["Damage"] = function(TowersOwn)
		local indexNum = 1
		local newList = {}
		while #TowersOwn > 0 do
			local highest,index = nil
			for i,Tower in TowersOwn do
				if highest == nil or Tower.Stats.Upgrades[1].Damage > highest then
					highest = Tower.Stats.Upgrades[1].Damage
					index = i
				end
			end
			table.insert(newList,{ TowerButton = TowersOwn[index].Button, LayoutOrder = indexNum })
			indexNum += 1
			table.remove(TowersOwn,index)
		end
		return newList
	end,
}

-- FUNCTIONS
local function getIngameHudBottom()
	local ingameHud = NewUI:FindFirstChild("IngameHud")
	return ingameHud and ingameHud:FindFirstChild("Bottom")
end

local function getSlotsContainer()
	local bottom = getIngameHudBottom()
	return bottom and bottom:FindFirstChild("Slot")
end

local function getSlotByIndex(index)
	local slotContainer = getSlotsContainer()
	if not slotContainer then return nil end
	return slotContainer:FindFirstChild(tostring(index))
end

local function getTemplateFolder()
	local ingameHud = NewUI:FindFirstChild("IngameHud")
	return ingameHud and ingameHud:FindFirstChild("Template")
end

local function getSlotTemplateForRarity(rarity)
	local templateFolder = getTemplateFolder()
	if not templateFolder then return nil end

	local searchRarity = rarity
	if rarity == "Mythical" then searchRarity = "Mythic" end

	local template = templateFolder:FindFirstChild(searchRarity)
	if template then return template end

	local fallbacks = {Secret = "Mythic", Unique = "Mythic", Supreme = "Mythic", Exclusive = "Exclusive"}
	return templateFolder:FindFirstChild(fallbacks[rarity] or "Rare")
end

local function resolvePlayerLevelObjects()
	local bottom = getIngameHudBottom()
	local levelBar = bottom and bottom:FindFirstChild("LevelBar")
	if levelBar then
		return levelBar:FindFirstChild("Fill"), levelBar:FindFirstChild("Text")
	end
	return nil, nil
end

local function getRarityColor(rarity)
	local borderInfo = ReplicatedStorage.Borders:FindFirstChild(rarity)
	if borderInfo then
		if borderInfo:IsA("ColorSequence") then return borderInfo.Keypoints[1].Value end
		if borderInfo:IsA("UIGradient") then return borderInfo.Color.Keypoints[1].Value end
		if typeof(borderInfo.Value) == "Color3" then return borderInfo.Value end
		if typeof(borderInfo.Color) == "Color3" then return borderInfo.Color end
	end
	return Color3.fromRGB(200, 200, 200)
end

local function clearPhysicalSlot(slot)
	if not slot then return end
	for _, child in pairs(slot:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function clearSlotDisplay(slot, index)
	if not slot then return end

	clearPhysicalSlot(slot)

	local templateFolder = getTemplateFolder()
	local closedTemplate = templateFolder and templateFolder:FindFirstChild("Closed")

	if closedTemplate then
		local clone = closedTemplate:Clone()
		clone.Size = UDim2.fromScale(1, 1)
		clone.Position = UDim2.fromScale(0.5, 0.5)
		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Visible = true
		clone.Parent = slot
	end
end

local function fillSlotDisplay(slot, tower)
	if not slot or not tower then return end

	clearPhysicalSlot(slot)

	local statsTower = UpgradesModule[tower.Name]
	local rarity = statsTower and statsTower.Rarity or "Rare"
	local template = getSlotTemplateForRarity(rarity)

	if template then
		local clone = template:Clone()
		clone.Size = UDim2.fromScale(1, 1)
		clone.Position = UDim2.fromScale(0.5, 0.5)
		clone.AnchorPoint = Vector2.new(0.5, 0.5)
		clone.Visible = true
		clone.Parent = slot

		local profile = clone:FindFirstChild("Profile")
		if profile then
			local vpFrame = profile:FindFirstChild("ViewportFrame")
			if vpFrame then
				for _, v in pairs(vpFrame:GetChildren()) do
					if v:IsA("ViewportFrame") then v:Destroy() end
				end
				local vp = ViewPortModule.CreateViewPort(tower.Name, tower:GetAttribute("Shiny"))
				if vp then
					vp.Size = UDim2.fromScale(1, 1)
					vp.Position = UDim2.fromScale(0.5, 0.5)
					vp.AnchorPoint = Vector2.new(0.5, 0.5)
					vp.BackgroundTransparency = 1
					vp.Name = tower.Name
					vp.Parent = vpFrame
				end
			end

			local profileText = profile:FindFirstChild("Text")
			if profileText then
				local amountLbl = profileText:FindFirstChild("Amount")
				local nameLbl = profileText:FindFirstChild("NamePerson")
				if amountLbl and statsTower then amountLbl.Text = "$" .. math.round(statsTower.Upgrades[1].Price) end
				if nameLbl then nameLbl.Text = tower.Name end
			end

			local starsFrame = profile:FindFirstChild("Stars")
			if starsFrame then
				local numStars = RARITY_STARS[rarity] or 2
				for s = 1, 6 do
					local starNode = starsFrame:FindFirstChild(tostring(s))
					if starNode then
						local empty = starNode:FindFirstChild("Empty")
						local full = starNode:FindFirstChild("Full")
						if empty and full then
							full.Visible = (s <= numStars)
							empty.Visible = (s > numStars)
						end
					end
				end
			end
		end

		local lvlFrame = clone:FindFirstChild("Lvl")
		if lvlFrame then
			local lvlTextFrame = lvlFrame:FindFirstChild("Text")
			if lvlTextFrame then
				local amountLbl = lvlTextFrame:FindFirstChild("Amount")
				if amountLbl then amountLbl.Text = tostring(tower:GetAttribute("Level")) end
			end
		end
	else
		clearSlotDisplay(slot, tonumber(slot.Name))
	end
end

local function findDictionaryIndex(dictionary,element)
	for index,currentElement in pairs(dictionary) do
		if currentElement == element then return index end
	end
	return nil
end

local function getDictionaryLength(dictionary)
	local count = 0
	for _,_ in pairs(dictionary) do count += 1 end
	return count
end

local function getTowerValueObject(guiObject)
	if not guiObject then
		return nil
	end

	local towerValue = nil
	for _, child in guiObject:GetChildren() do
		if child.Name == "TowerValue" and child:IsA("ObjectValue") then
			towerValue = child
		end
	end

	return towerValue
end

local function setTowerValueObject(guiObject, tower)
	if not guiObject then
		return nil
	end

	local towerValue = nil
	for _, child in guiObject:GetChildren() do
		if child.Name == "TowerValue" then
			if child:IsA("ObjectValue") and not towerValue then
				towerValue = child
			else
				child:Destroy()
			end
		end
	end

	if not towerValue then
		towerValue = Instance.new("ObjectValue")
		towerValue.Name = "TowerValue"
		towerValue.Parent = guiObject
	end

	towerValue.Value = tower
	return towerValue
end

local function compare(arr1, arr2)
	local arr1Length,arr2Length = getDictionaryLength(arr1),getDictionaryLength(arr2)
	local higherIndex = math.max(arr1Length,arr2Length)
	if arr1Length ~= arr2Length then return false end
	for i = 1, higherIndex do
		if arr1[`{i}`] ~= arr2[`{i}`] then return false end
	end
	return true
end

local function GetSellPrice()
	local totalPrice = 0
	for _,button in pairs(sellButtonList) do
		local towerVal = getTowerValueObject(button)
		if towerVal and towerVal.Value then
			local rarity = UpgradesModule[towerVal.Value.Name].Rarity
			local towerPriceValue = SellAndFuseModule.RaritySellPrice[rarity]
			towerPriceValue += towerPriceValue * GetPlayerBoost(player, "Coins") 
			totalPrice += towerPriceValue
		end
	end
	return totalPrice
end

local function updatePlayerLevelBar()
	local LevelBar, LevelNumber = resolvePlayerLevelObjects()
	if not LevelBar or not LevelNumber then return end

	local playerLevelValue = player.PlayerLevel.Value
	local playerExpValue = player.PlayerExp.Value
	local requireExp = ExpModule.playerExpCalculation(playerLevelValue)
	local progress = requireExp > 0 and (playerExpValue / requireExp) or 0

	if LevelBar.Name == "Fill" then
		LevelBar.Size = UDim2.fromScale(progress, 1)
	else
		LevelBar.Size = UDim2.fromScale(progress * (0.904 - 0.031), 1)
	end

	LevelNumber.Text = `Level {playerLevelValue} [{playerExpValue}/{requireExp}]`
end

local function changeSelectState(stateChange)
	local function ShowLockedUnits(bool)
		for _, ui in pairs(ContentGrid:GetChildren()) do
			if not ui:IsA("GuiObject") then continue end
			local tVal = getTowerValueObject(ui)
			if not tVal or not tVal.Value then continue end
			local towerValue = tVal.Value

			local lock = ui:FindFirstChild("Shadow") 
			if lock then
				if bool and UpgradesModule[towerValue.Name] and (UpgradesModule[towerValue.Name].NotSaleable or towerValue:GetAttribute("Locked") == true) then
					lock.Visible = true
				else
					lock.Visible = false
				end
			end
		end
	end

	stateChange = stateChange or (selectState == "None" and "Sell") or "None"

	if stateChange == "Sell" then
		SellMenuOptions.Visible = true
		ShowLockedUnits(true)
		local confirmText = ConfirmSellBtn:FindFirstChild("Contents") and ConfirmSellBtn.Contents:FindFirstChild("TextLabel")
		if confirmText then confirmText.Text = string.format("Sell (x%d) <font color=\"#FFBB01\">+ $%d</font>", 0, 0) end
	elseif stateChange == "Fuse" then
		FuseOptions.Visible = true
		ShowLockedUnits(true)
		fuseButtonList = {}
	elseif stateChange == "None" then
		ShowLockedUnits(false)
		FuseOptions.Visible = false
		SellMenuOptions.Visible = false

		if selectState == "Sell" then
			for _, btn in pairs(sellButtonList) do
				if btn and btn:FindFirstChild("Currency Icon") then btn["Currency Icon"].Visible = false end
			end
			sellButtonList = {}
		elseif selectState == "Fuse" then
			for _, btn in pairs(fuseButtonList) do
				if btn and btn:FindFirstChild("Fuse_Icon") then btn.Fuse_Icon.Visible = false end
			end
			fuseButtonList = {}
			if latestSelectedButton then latestSelectedButton.Visible = true end
		end
	end
	selectState = stateChange
end

local function updateInventory()
	for _, v in pairs(ContentGrid:GetChildren()) do
		if v:IsA("GuiObject") and getTowerValueObject(v) and v:GetAttribute("Select") == true then
			v:SetAttribute("Select", false)
			break
		end
	end

	local equippedTowers = {}
	for index,tower in pairs(oldEquippedTowers) do
		local getChildrenTowers = player.OwnedTowers:GetChildren()
		if tower.Name and findDictionaryIndex(getChildrenTowers,tower) and tower:GetAttribute("Equipped") == true then
			equippedTowers[tower:GetAttribute("EquippedSlot")] = tower
		end
	end
	for i, v in pairs(player.OwnedTowers:GetChildren()) do
		if v:GetAttribute("Equipped") == true then
			equippedTowers[v:GetAttribute("EquippedSlot")] = v
		end
	end

	updatePlayerLevelBar()
	oldEquippedTowers = equippedTowers

	local ownTowersButton = {}
	for i, v in pairs(ContentGrid:GetChildren()) do
		if v:IsA("GuiObject") then
			local tValue = getTowerValueObject(v)
			if tValue and tValue.Value then
				local statsTower = UpgradesModule[tValue.Value.Name]
				if statsTower then
					local rarity = statsTower["Rarity"] or "Rare"
					if tValue.Value:GetAttribute("Equipped") == true then
						local val = findDictionaryIndex(equippedTowers,tValue.Value)
						if val then v.LayoutOrder = tonumber(val) end
					else
						table.insert(ownTowersButton,{ Button = v, Stats = statsTower })
					end
				end
			end
		end
	end

	local newLayoutList = filteringType[currentFilter](ownTowersButton)
	for _,info in pairs(newLayoutList) do
		if info.LayoutOrder then
			info.TowerButton.LayoutOrder = info.LayoutOrder + #layoutorders
		end
	end

	UnitsQuantityText.Text = "Units: "..tostring(#player.OwnedTowers:GetChildren()).."/"..player.MaxUnits.Value

	for i = 1, 6 do
		local tower = equippedTowers[`{i}`]
		local slot = getSlotByIndex(i)

		if slot then
			if tower then
				fillSlotDisplay(slot, tower)
			else
				clearSlotDisplay(slot, i)
			end
		end
	end

	refreshInventoryButtonVisibility()
end

local function isJunkTraderSelectionActive()
	return _G.junkTraderTowerSelection == true and typeof(_G.junkTraderSelectTower) == "function"
end

local function selectTowerForWillpower(button, tower)
	if not button or not tower or typeof(_G.traitTowerSelectTower) ~= "function" then
		return false
	end

	return _G.traitTowerSelectTower(button, tower) == true
end

local function isJunkTraderTowerSelected(tower)
	return typeof(_G.junkTraderIsTowerSelected) == "function" and _G.junkTraderIsTowerSelected(tower) == true
end

local function updateJunkTraderSelectionIndicator(button, tower)
	if not button then
		return
	end

	local indicator = button:FindFirstChild("Currency Icon") or button:FindFirstChild("Fuse_Icon")
	if indicator then
		indicator.Visible = isJunkTraderSelectionActive() and isJunkTraderTowerSelected(tower)
	end
end

local function canUseTowerInCurrentSelectionMode(tower)
	if not tower then
		return false
	end

	if _G.evolveTowerSelection == true and not UpgradesModule[tower.Name]["Evolve"] then
		return false
	end

	if isJunkTraderSelectionActive() and typeof(_G.junkTraderCanSelectTower) == "function" then
		return _G.junkTraderCanSelectTower(tower) == true
	end

	return true
end

refreshInventoryButtonVisibility = function()
	local newString = string.lower(SearchBox.Text)
	local unitsFound = 0
	local shouldShowDefaultCount = newString == "" and not _G.evolveTowerSelection and not isJunkTraderSelectionActive()

	for _, towerButton in pairs(ContentGrid:GetChildren()) do
		if not towerButton:IsA("GuiObject") then continue end

		local tVal = getTowerValueObject(towerButton)
		if not (tVal and tVal.Value) then
			continue
		end

		local isVisible = canUseTowerInCurrentSelectionMode(tVal.Value)
		updateJunkTraderSelectionIndicator(towerButton, tVal.Value)
		if isVisible and newString ~= "" then
			local towerName = string.lower(tVal.Value.Name)
			isVisible = string.sub(towerName, 1, #newString) == newString
		end

		towerButton.Visible = isVisible
		if isVisible then
			unitsFound += 1
		end
	end

	UnitsQuantityText.Text = shouldShowDefaultCount
		and ("Units: " .. tostring(#player.OwnedTowers:GetChildren()) .. "/" .. player.MaxUnits.Value)
		or ("Units: " .. tostring(unitsFound) .. "/" .. player.MaxUnits.Value)
end

local function addButton(tower)
	-- Evita duplicatas
	for _, button in pairs(ContentGrid:GetChildren()) do
		if button:IsA("GuiObject") then
			local towerValue = getTowerValueObject(button)
			if towerValue and towerValue.Value == tower then
				return
			end
		end
	end

	-- Pega o status da torre para saber a raridade
	local statsTower = UpgradesModule[tower.Name]
	local rarity = (statsTower and statsTower["Rarity"]) or "Rare"

	-- Procura o template dinamicamente na UI com base na raridade
	local template = ContentGrid:FindFirstChild(rarity) or ContentGrid:FindFirstChild("Rare")
	if not template then return end -- Fallback se não encontrar nenhum template válido

	local button = template:Clone()
	button.Name = "Tower"..tower.Name
	button.Visible = true

	setTowerValueObject(button, tower)

	-- Referências baseadas na nova hierarquia da imagem
	local profile = button:FindFirstChild("Profile")
	local textTemp = profile and profile:FindFirstChild("TextTemp")

	if textTemp then
		if textTemp:FindFirstChild("NamePerson") then textTemp.NamePerson.Text = tower.Name end
		if textTemp:FindFirstChild("Lvl") then textTemp.Lvl.Text = "Lvl " .. tower:GetAttribute("Level") end

		if statsTower then
			local baseStats = statsTower.Upgrades[1]
			if textTemp:FindFirstChild("Amount") then
				textTemp.Amount.Text = "$" .. baseStats.Price
			end
		end
	end

	if button:FindFirstChild("Currency Icon") then button["Currency Icon"].Visible = false end
	if button:FindFirstChild("Fuse_Icon") then button.Fuse_Icon.Visible = false end
	updateJunkTraderSelectionIndicator(button, tower)

	if not canUseTowerInCurrentSelectionMode(tower) then
		button.Visible = false
	end

	task.spawn(function()
		local vp = ViewPortModule.CreateViewPort(tower.Name, tower:GetAttribute("Shiny"))
		if profile and profile:FindFirstChild("ViewportFrame") then
			vp.Parent = profile.ViewportFrame
		else
			vp.Parent = button
		end
	end)

	tower:GetPropertyChangedSignal('Parent'):Connect(function()
		if not tower.Parent then button:Destroy() end
	end)

	if not tower.Parent then 
		button:Destroy()
		return
	end

	tower:GetAttributeChangedSignal("Level"):Connect(function()
		if textTemp and textTemp:FindFirstChild("Lvl") then
			textTemp.Lvl.Text = "Lvl " .. tower:GetAttribute("Level")
		end
	end)

	-- O próprio template é o botão agora, então usamos 'button.Activated'
	button.Activated:Connect(function()
		if isJunkTraderSelectionActive() then
			if canUseTowerInCurrentSelectionMode(tower) then
				_G.junkTraderSelectTower(button, tower)
			end
			return
		end

		if _G.traitTowerSelection == true then
			selectTowerForWillpower(button, tower)
			return
		end

		if _G.traitTowerSelection == false and _G.InventoryButtonsClickable == true and _G.evolveTowerSelection == false and _G.levelupTowerSelection == false then
			local statsTowerRefresh = UpgradesModule[tower.Name]
			local finalRarity = statsTowerRefresh["Rarity"] or "Rare"
			buttonConnections:DisconnectAll()

			if selectState == "Sell" then
				local SellText = ConfirmSellBtn:FindFirstChild("Contents") and ConfirmSellBtn.Contents:FindFirstChild("TextLabel")
				if tower:GetAttribute("Locked") or statsTowerRefresh.NotSaleable then return end

				if table.find(sellButtonList,button) then
					table.remove(sellButtonList, table.find(sellButtonList,button))
					if button:FindFirstChild("Currency Icon") then button["Currency Icon"].Visible = false end
					if SellText then SellText.Text = string.format("Sell (x%d) <font color=\"#FFBB01\">+ $%d</font>", #sellButtonList, GetSellPrice()) end
					return
				end
				table.insert(sellButtonList,button)
				if button:FindFirstChild("Currency Icon") then button["Currency Icon"].Visible = true end
				if SellText then SellText.Text = string.format("Sell (x%d) <font color=\"#FFBB01\">+ $%d</font>", #sellButtonList,GetSellPrice()) end
				return

			elseif selectState == "Fuse" then
				if tower:GetAttribute("Locked") or statsTowerRefresh.NotSaleable then return end
				if SelectedTowerValue.Value == tower then return end
				local inFuseButtonListIndex = table.find(fuseButtonList,button)

				if inFuseButtonListIndex then
					table.remove(fuseButtonList,inFuseButtonListIndex)
					if button:FindFirstChild("Fuse_Icon") then button.Fuse_Icon.Visible = false end
				else
					table.insert(fuseButtonList,button)
					if button:FindFirstChild("Fuse_Icon") then button.Fuse_Icon.Visible = true end
				end

				local fuseExpCount = 0
				local fuseTower = SelectedTowerValue.Value
				local oldLevel, oldExp = fuseTower:GetAttribute("Level"), fuseTower:GetAttribute("Exp")

				for index,fuseBtn in pairs(fuseButtonList) do
					local towerValueObject = getTowerValueObject(fuseBtn)
					local selectedTower = towerValueObject and towerValueObject.Value
					if not selectedTower then continue end
					local towerRarity = UpgradesModule[selectedTower.Name].Rarity
					local towerLevel = selectedTower:GetAttribute("Level")
					local addAmount = SellAndFuseModule.ExpFusing[towerRarity] * (1+ towerLevel * (4/50))
					fuseExpCount += addAmount
				end

				local newLevel, newExp = ExpModule.towerLevelCalculation(player, oldLevel, oldExp + fuseExpCount)
				local requireExp = ExpModule.towerExpCalculation(newLevel)
				local maxLevel, maxExp = ExpModule.getTowerMaxStats()

				CraftBar:FindFirstChild("Text").Text = string.format("Level %d (%d/%d)", newLevel, newExp, requireExp)
				CraftBar:FindFirstChild("Fill").Size = UDim2.new((newLevel >= maxLevel and 1) or newExp/requireExp, 0, 1, 0)

				local fuseText = ConfirmFuseBtn:FindFirstChild("Contents") and ConfirmFuseBtn.Contents:FindFirstChild("TextLabel")
				if fuseText then fuseText.Text = string.format("Fuse (x%d) <font color=\"#FFBB01\">+ %dXP</font>", #fuseButtonList, fuseExpCount) end
				return

			elseif SelectedTowerValue.Value == tower then
				return
			end

			latestSelectedButton = button
			SelectedTowerValue.Value = tower

			if statsTowerRefresh then
				local HasViewPort = ViewportPlaceholder:FindFirstChildOfClass("WorldModel")
				if HasViewPort then HasViewPort:Destroy() end

				local SelectVp = ViewPortModule.CreateViewPort(statsTowerRefresh.Name)
				SelectVp:FindFirstChildOfClass("WorldModel").Parent = ViewportPlaceholder

				local statlabels = {"Damage","Cooldown","Range"}
				local baseStats = statsTowerRefresh.Upgrades[1]
				local levelboost = 1 + tower:GetAttribute("Level")*(1/50)

				for _, stat in pairs(statlabels) do
					local finalStatVal = baseStats[stat]
					if stat == "Damage" then
						finalStatVal = math.round(baseStats[stat] * levelboost) > 100 and math.round(baseStats[stat] * levelboost) or math.round((baseStats[stat] * levelboost) * 10) / 10
					end
					if CraftValues:FindFirstChild(stat) then
						CraftValues[stat].Amount.Text = tostring(finalStatVal)
					end
				end
			end

			local level = tower:GetAttribute("Level")
			local currentExp = tower:GetAttribute("Exp")
			local requiredExp = ExpModule.towerExpCalculation(level)

			UnitNameText.Text = tower.Name
			UnitRarityText.Text = finalRarity == "Exclusive" and "[EXCLUSIVE]" or finalRarity
			UnitCostText.Text = "$" .. math.round(UpgradesModule[tower.Name].Upgrades[1].Price)

			local craftColor = getRarityColor(finalRarity)
			local craftBg = CraftFrame:FindFirstChild("Bg")
			if craftBg then
				craftBg.BackgroundColor3 = craftColor
				if craftBg:FindFirstChild("1") then craftBg["1"].Color = craftColor end
				if craftBg:FindFirstChild("2") then craftBg["2"].Color = craftColor end
				if craftBg:FindFirstChild("3") then craftBg["3"].Color = craftColor end
			end
			UnitRarityText.TextColor3 = craftColor

			if level >= 75 then
				CraftBar:FindFirstChild("Fill").Size = UDim2.new(1,0,1,0)
				CraftBar:FindFirstChild("Text").Text = "MAX"
			else
				CraftBar:FindFirstChild("Fill").Size = UDim2.new(currentExp/requiredExp,0,1,0)
				CraftBar:FindFirstChild("Text").Text = string.format("Level %d (%d/%d)", level, currentExp, requiredExp)
			end

			local function updateEquipButtonVisual()
				local isEquipped = tower:GetAttribute("Equipped")
				EquipBtnText.Text = isEquipped and "Unequip" or "Equip"

				local equipBg = CraftButtons:FindFirstChild("Equip") and CraftButtons.Equip:FindFirstChild("Bg")
				if equipBg then
					local targetColor = isEquipped and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(50, 200, 50) 
					equipBg.BackgroundColor3 = targetColor
					if equipBg:FindFirstChild("1") and equipBg["1"]:IsA("UIStroke") then
						equipBg["1"].Color = targetColor
					end
					if equipBg:FindFirstChild("2") and equipBg["2"]:IsA("UIStroke") then
						equipBg["2"].Color = targetColor
					end

					local uiGradient = equipBg:FindFirstChildOfClass("UIGradient") or equipBg:FindFirstChild("UIGradient")
					if uiGradient and uiGradient:IsA("UIGradient") then
						uiGradient.Color = ColorSequence.new(targetColor)
					end
				end
			end

			updateEquipButtonVisual()

			tower:GetAttributeChangedSignal("Equipped"):Connect(function()
				updateEquipButtonVisual()
			end)

			buttonConnections:DisconnectAll()

			buttonConnections["ViewButton"] = ViewBtn.Activated:Connect(function()
				if SelectedTowerValue.Value == nil then return end
				if viewdebounce == false then
					viewdebounce = true
					task.delay(1,function() viewdebounce = false end)
					local TowerModel = GetUnitModel[tower.Name]
					if TowerModel then
						UiHandler.PlaySound("Redeem")
						_G.CloseAll()
						ViewModule.Hatch({UpgradesModule[tower.Name], tower})
						buttonConnections:DisconnectAll()
					end
				end
			end)
		end
	end)

	button.Parent = ContentGrid
	refreshInventoryButtonVisibility()
end

local function removeButton(tower)
	for _, v in pairs(ContentGrid:GetChildren()) do
		local tVal = getTowerValueObject(v)
		if tVal and tVal.Value == tower then
			v:Destroy()
			return
		end
	end
end

local function updateFilter()
	for _,button in pairs(SelectRarityFilters:GetChildren()) do
		if not button:IsA("ImageButton") then continue end
	end
end

-- INIT
UserInputService.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and not inGui then
		for i, v in pairs(ContentGrid:GetChildren()) do
			if v:IsA("GuiObject") and getTowerValueObject(v) and v:GetAttribute("Select") == true then
				v:SetAttribute("Select", false)
				break
			end
		end
	end
end)

player.OwnedTowers.ChildRemoved:Connect(function(child)
	updateInventory()
end)

EquipBtn.Activated:Connect(function()
	if SelectedTowerValue.Value == nil then return end
	ReplicatedStorage.Events.InteractItem:FireServer(SelectedTowerValue.Value)
end)

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
	refreshInventoryButtonVisibility()
end)

UnequipAllBtn.Activated:Connect(function()
	for _,tower in pairs(player.OwnedTowers:GetChildren()) do
		if tower:GetAttribute("Equipped") then
			ReplicatedStorage.Events.InteractItem:FireServer(tower)
		end
	end
end)

SellModeBtn.Activated:Connect(function() changeSelectState() end)
CancelSellBtn.Activated:Connect(function() changeSelectState("None") end)

FuseBtn.Activated:Connect(function()
	if SelectedTowerValue.Value == nil or selectState == "Fuse" then return end
	if latestSelectedButton then latestSelectedButton.Visible = false end
	changeSelectState("Fuse")
end)

CancelFuseBtn.Activated:Connect(function() changeSelectState("None") end)

ConfirmFuseBtn.Activated:Connect(function()
	local fuseReceiverTower = SelectedTowerValue.Value
	if not fuseReceiverTower then return end
	local fuseTowerList = {}
	for _,fuseButton in pairs(fuseButtonList) do
		local towerValueObject = getTowerValueObject(fuseButton)
		local towerValue = towerValueObject and towerValueObject.Value
		if towerValue then table.insert(fuseTowerList, towerValue) end
	end
	ReplicatedStorage.Events.FuseTower:FireServer(fuseReceiverTower, fuseTowerList)
	changeSelectState("None")
end)

ConfirmSellBtn.Activated:Connect(function()
	if #sellButtonList > 0 then
		local sellTowerList = {}
		for _,button in pairs(sellButtonList) do
			local towerValueObject = getTowerValueObject(button)
			if towerValueObject and towerValueObject.Value then
				table.insert(sellTowerList, towerValueObject.Value)
			end
		end
		ReplicatedStorage.Events.SellItem:FireServer(sellTowerList)
		changeSelectState("None")
	end
end)

for _,button in pairs(SelectRarityFilters:GetChildren()) do
	if button:IsA("ImageButton") then
		button.Activated:Connect(function()
			currentFilter = currentFilter == button.Name and "None" or button.Name
			updateFilter()
			updateInventory()
		end)
	end
end

player.PlayerLevel.Changed:Connect(updateInventory)
player:WaitForChild("MaxUnits").Changed:Connect(function()
	UnitsQuantityText.Text = "Units: "..tostring(#player.OwnedTowers:GetChildren()).."/"..player.MaxUnits.Value
end)
player.PlayerExp.Changed:Connect(updatePlayerLevelBar)

local processedUnits = {}
for i, v in pairs(player.OwnedTowers:GetChildren()) do
	RunService.Stepped:Wait()
	addButton(v)
	processedUnits[v] = true
	v.AttributeChanged:Connect(updateInventory)
end

updateInventory()

player:WaitForChild("OwnedTowers").ChildAdded:Connect(function(child)
	addButton(child)
	child:GetPropertyChangedSignal('Name'):Connect(function(old)
		removeButton(old)
		addButton(child)
	end)
	child.AttributeChanged:Connect(updateInventory)
	child.Changed:Connect(updateInventory)
end)

UnitsUI:GetPropertyChangedSignal('Visible'):Connect(function()
	if UnitsUI.Visible then
		updateInventory()
	elseif _G.traitTowerSelection == true then
		if typeof(_G.traitTowerCancelSelection) == "function" then
			_G.traitTowerCancelSelection()
		else
			_G.traitTowerSelection = false
			_G.traitTowerSelectTower = nil
			_G.traitTowerCancelSelection = nil
		end
	elseif isJunkTraderSelectionActive() and typeof(_G.junkTraderCancelSelection) == "function" then
		_G.junkTraderCancelSelection()
	end
end)
