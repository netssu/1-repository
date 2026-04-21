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

-- VARIABLES
_G.traitTowerSelection = false
_G.InventoryButtonsClickable = true
_G.evolveTowerSelection = false
_G.levelupTowerSelection = false

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
local TemplateButton = ContentGrid:WaitForChild("1")
TemplateButton.Visible = false 

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
local SlotsContainer = GameGui and GameGui:FindFirstChild("Slots") and GameGui.Slots.Slots.Units_Bar
local LevelFrame = SlotsContainer and SlotsContainer.Parent.Exp_Frame
local LevelBar = LevelFrame and LevelFrame.CanvasGroup.Glow
local LevelNumber = LevelFrame and LevelFrame.Level
local LvlUp = GameGui and GameGui:FindFirstChild("LvlUp")
local LvlUpFrame = LvlUp and LvlUp:FindFirstChild("LvlUpFrame")

local SelectedTowerValue = Instance.new("ObjectValue")
SelectedTowerValue.Name = "SelectedTower"
SelectedTowerValue.Parent = script

local viewdebounce = false
local inGui = false
local oldEquippedTowers = {}
local latestSelectedButton

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

local function compare(arr1, arr2)
	local arr1Length,arr2Length = getDictionaryLength(arr1),getDictionaryLength(arr2)
	local higherIndex = math.max(arr1Length,arr2Length)
	if arr1Length ~= arr2Length then return false end
	for i = 1, higherIndex do
		if arr1[`{i}`] ~= arr2[`{i}`] then return false end
	end
	return true
end

local function removeAllGradients(container)
	if typeof(container) == "table" then
		for _, c in pairs(container) do
			for i, v in pairs(c:GetChildren()) do
				if v:IsA("UIGradient") then v:Destroy() end
			end
		end
	elseif typeof(container) == "Instance" then
		for i, v in pairs(container:GetChildren()) do
			if v:IsA("UIGradient") then v:Destroy() end
		end
	end
end

local function addRarityGradient(container,rarity)
	local g = ReplicatedStorage.Borders:FindFirstChild(rarity) or ReplicatedStorage.Borders.Rare
	removeAllGradients(container)

	if typeof(container) == "table" then
		for _, c in pairs(container) do
			local gc = g:Clone()
			gc.Parent = c
		end
	elseif typeof(container) == "Instance" then
		local gc = g:Clone()
		gc.Parent = container
	end
end

local function getUnitRarity(unit)
	local rarity = nil
	for i,v in pairs(ReplicatedStorage.Towers:GetChildren()) do
		if v:IsA('Folder') and v:FindFirstChild(unit) then
			rarity = v.Name
			break
		end
	end
	return rarity
end

local function GetSellPrice()
	local totalPrice = 0
	for _,button in pairs(sellButtonList) do
		local towerVal = button:FindFirstChild("TowerValue")
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
	if not LevelBar or not LevelNumber then return end
	local playerLevelValue = player.PlayerLevel.Value
	local playerExpValue = player.PlayerExp.Value
	local requireExp = ExpModule.playerExpCalculation(playerLevelValue)

	LevelBar.Size = UDim2.fromScale((playerExpValue/requireExp) * (0.904 - 0.031), 1)
	LevelNumber.Text = `Level {playerLevelValue} [{playerExpValue}/{requireExp}]`
end

local function changeSelectState(stateChange)
	local function ShowLockedUnits(bool)
		for _, ui in pairs(ContentGrid:GetChildren()) do
			if ui.Name == "1" or not ui:IsA("Frame") then continue end
			local towerValue = ui:FindFirstChild("TowerValue") and ui.TowerValue.Value
			if not towerValue then continue end

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
		if v.Name ~= "1" and v:IsA("Frame") and v:GetAttribute("Select") == true then
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
		if v:IsA("Frame") and v.Name ~= "1" then
			local tValue = v:FindFirstChild("TowerValue")
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

	if SlotsContainer then
		for i=1, 6 do
			local tower = equippedTowers[`{i}`]
			local slot = SlotsContainer:FindFirstChild("Unit"..`{i}`)
			if slot then
				local HasViewPort = slot.Internal:FindFirstChildOfClass("ViewportFrame")
				if HasViewPort then HasViewPort:Destroy() end

				if tower then
					slot.Internal.Glow.Visible = tower:GetAttribute("Shiny")
					local vp = ViewPortModule.CreateViewPort(tower.Name,tower:GetAttribute("Shiny"))
					vp.Parent = slot.Internal

					slot.Internal.Text_Container.Unit_Level.Text = 'Lvl ' .. tower:GetAttribute("Level")
					slot.Internal['Text_Container'].Unit_Name.Text = tower.Name

					local statsTower = UpgradesModule[tower.Name]
					if statsTower then
						slot.Internal.Unit_Value.Text = math.round(statsTower["Upgrades"][1].Price).."$"
						local rarity = statsTower["Rarity"]
						if rarity then
							local gradientRarity = ReplicatedStorage.Borders:FindFirstChild(rarity)
							if gradientRarity then
								slot.Internal.Glow.UIGradient.Color = gradientRarity.Color
								slot.Internal['Main_Unit_ Frame'].UIGradient.Color = gradientRarity.Color
							end
						end
					end
				else
					local gray = Color3.fromRGB(100,100,100)
					if slot.Internal:FindFirstChild('Main_Unit_ Frame') then
						slot.Internal['Main_Unit_ Frame'].UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, gray),ColorSequenceKeypoint.new(1, gray)}
					end
					slot.Internal.TraitIcon.Visible = false
					slot.Internal.Glow.Visible = false
					slot.Internal.Text_Container.Unit_Level.Text = ""
					slot.Internal.Unit_Value.Text = ""
					slot.Internal['Text_Container'].Unit_Name.Text = ""

					if player.PlayerLevel.Value < requiredSlotLevel[i] and slot:FindFirstChild("Locked") then
						slot.Locked.Visible = true
					end
				end
			end
		end
	end
end

local function addButton(tower)
	for _, button in pairs(ContentGrid:GetChildren()) do
		if button:IsA("Frame") and button:FindFirstChild("TowerValue") and button.TowerValue.Value == tower then return end
	end

	local button = TemplateButton:Clone()
	button.Name = "Tower"..tower.Name
	button.NameChar.Text = tower.Name
	button.Lvl.Text = "Lvl " .. tower:GetAttribute("Level")
	button.Visible = true

	local towerValueInstance = Instance.new("ObjectValue")
	towerValueInstance.Name = "TowerValue"
	towerValueInstance.Value = tower
	towerValueInstance.Parent = button

	if button:FindFirstChild("Currency Icon") then button["Currency Icon"].Visible = false end
	if button:FindFirstChild("Fuse_Icon") then button.Fuse_Icon.Visible = false end

	if _G.evolveTowerSelection == true and not UpgradesModule[tower.Name]["Evolve"] then
		button.Visible = false
	end

	task.spawn(function()
		local vp = ViewPortModule.CreateViewPort(tower.Name,tower:GetAttribute("Shiny"))
		vp.Parent = button:FindFirstChild("Placeholder") or button
	end)

	tower:GetPropertyChangedSignal('Parent'):Connect(function()
		if not tower.Parent then button:Destroy() end
	end)

	if not tower.Parent then 
		button:Destroy()
		return
	end

	tower:GetAttributeChangedSignal("Level"):Connect(function()
		button.Lvl.Text = "Lvl " .. tower:GetAttribute("Level")
	end)

	local statsTower = UpgradesModule[tower.Name]
	if statsTower then
		local baseStats = statsTower.Upgrades[1]
		local rarity = statsTower["Rarity"] or "Rare"
		button.Amount.Text = "$" .. baseStats.Price

		local cardColor = getRarityColor(rarity)
		if button:FindFirstChild("Bg") then
			button.Bg.BackgroundColor3 = cardColor
			if button.Bg:FindFirstChild("1") then button.Bg["1"].Color = cardColor end
			if button.Bg:FindFirstChild("2") then button.Bg["2"].Color = cardColor end
			if button.Bg:FindFirstChild("3") then button.Bg["3"].Color = cardColor end
		end
	end

	button.Btn.Activated:Connect(function() 
		if _G.traitTowerSelection == false and _G.InventoryButtonsClickable == true and _G.evolveTowerSelection == false and _G.levelupTowerSelection == false then
			local rarity = statsTower["Rarity"] or "Rare"
			buttonConnections:DisconnectAll()

			if selectState == "Sell" then
				local SellText = ConfirmSellBtn:FindFirstChild("Contents") and ConfirmSellBtn.Contents:FindFirstChild("TextLabel")
				if tower:GetAttribute("Locked") or statsTower.NotSaleable then return end

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
				if tower:GetAttribute("Locked") or statsTower.NotSaleable then return end
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
					local tValue = fuseBtn:FindFirstChild("TowerValue") and fuseBtn.TowerValue.Value
					if not tValue then continue end
					local towerRarity = UpgradesModule[tValue.Name].Rarity
					local towerLevel = tValue:GetAttribute("Level")
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
			statsTower = UpgradesModule[tower.Name] 

			if statsTower then
				local HasViewPort = ViewportPlaceholder:FindFirstChildOfClass("WorldModel")
				if HasViewPort then HasViewPort:Destroy() end

				local SelectVp = ViewPortModule.CreateViewPort(statsTower.Name)
				SelectVp:FindFirstChildOfClass("WorldModel").Parent = ViewportPlaceholder

				local statlabels = {"Damage","Cooldown","Range"}
				local baseStats = statsTower.Upgrades[1]
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
			UnitRarityText.Text = rarity == "Exclusive" and "[EXCLUSIVE]" or rarity
			UnitCostText.Text = "$" .. math.round(UpgradesModule[tower.Name].Upgrades[1].Price)

			local craftColor = getRarityColor(rarity)
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
end

local function removeButton(tower)
	for _, v in pairs(ContentGrid:GetChildren()) do
		local tVal = v:FindFirstChild("TowerValue")
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
			if v:IsA("Frame") and v:GetAttribute("Select") == true then
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
	local newString = string.lower(SearchBox.Text)
	local UnitsFound = 0

	for _,towerButton in pairs(ContentGrid:GetChildren()) do
		if towerButton.Name == "1" or not towerButton:IsA("Frame") then continue end
		local tVal = towerButton:FindFirstChild("TowerValue")
		if tVal and tVal.Value then
			local towerName = string.lower(tVal.Value.Name)
			local isMatch = (string.sub(towerName,1,#newString) == newString)

			towerButton.Visible = isMatch
			if isMatch then UnitsFound += 1 end
		end
	end
	UnitsQuantityText.Text = newString == "" and "Units: "..tostring(#player.OwnedTowers:GetChildren()).."/"..player.MaxUnits.Value or "Units: "..tostring(UnitsFound).."/"..player.MaxUnits.Value
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
		local towerValue = fuseButton:FindFirstChild("TowerValue") and fuseButton.TowerValue.Value
		if towerValue then table.insert(fuseTowerList, towerValue) end
	end
	ReplicatedStorage.Events.FuseTower:FireServer(fuseReceiverTower, fuseTowerList)
	changeSelectState("None")
end)

ConfirmSellBtn.Activated:Connect(function()
	if #sellButtonList > 0 then
		local sellTowerList = {}
		for _,button in pairs(sellButtonList) do
			table.insert(sellTowerList, button.TowerValue.Value)
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
	end
end)