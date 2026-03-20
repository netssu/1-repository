------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local MAX_BEST_SLOTS = 5
local COLOR_EQUIPPED = Color3.fromRGB(197, 255, 209)
local COLOR_DEFAULT = Color3.fromRGB(255, 255, 255)
local DATA_WAIT_TIMEOUT = 10
local DATA_POLL_INTERVAL = 0.2

local VIEWPORT_RESOLUTION = 800 
local VIEWPORT_OVERFLOW = 2.0   
local CAMERA_DISTANCE_OFFSET = 4.5 

------------------//VARIABLES
local InventoryController = {}
local localPlayer = Players.LocalPlayer

local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local MathUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("MathUtility"))
local DataPets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))
local PogoData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PogoData"))
local PotionsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PotionsData"))
local RaritysData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("RaritysData"))
local HudManager = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("HudManager"))

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local equipRemote = remotesFolder:WaitForChild("ActionRemote")

local createdMainFrames = {}
local createdBestFrames = {}

local currentCategory = "Pogos"
local currentSearchQuery = ""

local ownedPets = {}
local bestPets = {}
local equippedPets = {}
local ownedPogos = {}
local bestPogos = {}
local equippedPogoId = ""
local ownedPotions = {}

local isAddingMode = false
local pendingReplaceItem = nil

local defaultMainContentSize = nil
local defaultMainContentPosition = nil

local cachedMainTemplate = nil
local cachedBestTemplate = nil

local tooltipFrame = nil
local tooltipConn = nil

------------------//FUNCTIONS
local function init_tooltip()
	if tooltipFrame then return end
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	local gui = playerGui and playerGui:WaitForChild("GUI", 10)
	if not gui then return end
	tooltipFrame = Instance.new("Frame")
	tooltipFrame.Name = "HoverTooltip"
	tooltipFrame.Size = UDim2.new(0, 160, 0, 50)
	tooltipFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	tooltipFrame.BackgroundTransparency = 0.1
	tooltipFrame.BorderSizePixel = 0
	tooltipFrame.ZIndex = 100
	tooltipFrame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = tooltipFrame
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = tooltipFrame
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Size = UDim2.new(1, 0, 0.5, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextColor3 = Color3.new(1, 1, 1)
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextSize = 14
	rarityLabel.Parent = tooltipFrame
	local multLabel = Instance.new("TextLabel")
	multLabel.Name = "MultiplierLabel"
	multLabel.Size = UDim2.new(1, 0, 0.5, 0)
	multLabel.Position = UDim2.new(0, 0, 0.5, 0)
	multLabel.BackgroundTransparency = 1
	multLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	multLabel.TextXAlignment = Enum.TextXAlignment.Left
	multLabel.Font = Enum.Font.GothamMedium
	multLabel.TextSize = 13
	multLabel.Parent = tooltipFrame
	tooltipFrame.Parent = gui
end

local function update_tooltip_position()
	if tooltipFrame and tooltipFrame.Visible then
		local mousePos = UserInputService:GetMouseLocation()
		tooltipFrame.Position = UDim2.new(0, mousePos.X + 15, 0, mousePos.Y - 20)
	end
end

local function show_tooltip(itemId, category)
	if not tooltipFrame then return end
	if category == "Pets" then
		local petData = DataPets.GetPetData(itemId)
		if petData then
			local rarityConfig = RaritysData[petData.Raritys]
			local colorHex = rarityConfig and rarityConfig.Color:ToHex() or "FFFFFF"
			tooltipFrame.RarityLabel.RichText = true
			tooltipFrame.RarityLabel.Text = "Rarity: <font color='#" .. colorHex .. "'>" .. tostring(petData.Raritys) .. "</font>"
			tooltipFrame.MultiplierLabel.Text = "Multiplier: " .. tostring(petData.Multiplier) .. "x"
			tooltipFrame.Visible = true
			if tooltipConn then tooltipConn:Disconnect() end
			tooltipConn = RunService.RenderStepped:Connect(update_tooltip_position)
		end
	end
end

local function hide_tooltip()
	if tooltipFrame then tooltipFrame.Visible = false end
	if tooltipConn then tooltipConn:Disconnect() tooltipConn = nil end
end

local function wait_for_data(key)
	local deadline = os.clock() + DATA_WAIT_TIMEOUT
	local value = DataUtility.client.get(key)
	while value == nil and os.clock() < deadline do
		task.wait(DATA_POLL_INTERVAL)
		value = DataUtility.client.get(key)
	end
	return value
end

local function bind_click(uiObject, callback)
	if not uiObject then return {} end
	local conns = {}
	local debounce = false
	local function trigger()
		if debounce then return end
		debounce = true
		callback()
		task.delay(0.3, function() debounce = false end)
	end
	if uiObject:IsA("GuiButton") then
		table.insert(conns, uiObject.Activated:Connect(trigger))
	else
		table.insert(conns, uiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				trigger()
			end
		end))
	end
	return conns
end

local function disable_input_blockers(frame)
	for _, child in ipairs(frame:GetDescendants()) do
		if child:IsA("GuiObject") and not child:IsA("GuiButton") then
			child.Active = false
		end
	end
end

local function get_display_name(itemId, category)
	if category == "Pets" then
		local petData = DataPets.GetPetData(itemId)
		return (petData and petData.DisplayName) or tostring(itemId)
	elseif category == "Pogos" then
		local pogoList = PogoData.GetSortedList()
		for _, p in ipairs(pogoList) do if p.Id == itemId then return p.Name end end
	elseif category == "Potions" then
		local potionData = PotionsData.Get(itemId)
		return (potionData and potionData.DisplayName) or tostring(itemId)
	end
	return tostring(itemId)
end

local function is_equipped(itemId)
	if currentCategory == "Pogos" then return equippedPogoId == itemId
	elseif currentCategory == "Pets" then
		if type(equippedPets) ~= "table" then return false end
		for _, id in pairs(equippedPets) do if id == itemId then return true end end
	end
	return false
end

local function get_ui()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	local GUI = playerGui and playerGui:WaitForChild("GUI", 10)
	if not GUI then return nil end
	local invFrame = GUI:FindFirstChild("InventoryFrame", true)
	local confFrame = GUI:FindFirstChild("ConfirmationFrame", true)
	local selector = invFrame and invFrame:FindFirstChild("Selector")
	return {
		Main = invFrame,
		BG = invFrame and invFrame:FindFirstChild("BG"),
		BestPogos = invFrame and invFrame:FindFirstChild("BestPogos", true),
		BestPogosTextLB = invFrame and invFrame:FindFirstChild("BestPogosTextLB", true),
		MainContent = invFrame and invFrame:FindFirstChild("MainContent", true),
		SearchBar = invFrame and invFrame:FindFirstChild("SearchBar", true),
		Selector = selector and selector:FindFirstChild("Content"),
		Confirmation = confFrame,
	}
end

local function init_templates()
	if cachedMainTemplate and cachedBestTemplate then return end
	local ui = get_ui()
	if not ui then return end
	if not cachedMainTemplate and ui.MainContent then
		local t = ui.MainContent:FindFirstChild("PogoStickHolder")
		if t then
			cachedMainTemplate = t:Clone()
			cachedMainTemplate.Visible = false
			cachedMainTemplate.Parent = ReplicatedStorage
			t:Destroy()
		end
	end
	if not cachedBestTemplate and ui.BestPogos then
		local t = ui.BestPogos:FindFirstChild("PogoStickHolder")
		if t then
			cachedBestTemplate = t:Clone()
			cachedBestTemplate.Visible = false
			cachedBestTemplate.Parent = ReplicatedStorage
			t:Destroy()
		end
	end
end

local confirmationConns = {}
local function show_confirmation(title, desc, onConfirm)
	local ui = get_ui()
	if not ui or not ui.Confirmation then return end
	local conf = ui.Confirmation
	local headText = conf:FindFirstChild("HeadText", true)
	local descText = conf:FindFirstChild("DescriptionText", true)
	if headText then headText.Text = title end
	if descText then descText.Text = desc end
	conf.Visible = true
	for _, c in ipairs(confirmationConns) do c:Disconnect() end
	table.clear(confirmationConns)
	local function cleanup()
		for _, c in ipairs(confirmationConns) do c:Disconnect() end
		table.clear(confirmationConns)
		conf.Visible = false
	end
	local bottomContent = conf:FindFirstChild("BottomContent", true)
	local btnConfirmHolder = bottomContent and bottomContent:FindFirstChild("ConfirmButton")
	if btnConfirmHolder then
		local btn = btnConfirmHolder:FindFirstChild("Btn") or btnConfirmHolder
		local conns = bind_click(btn, function() cleanup() if onConfirm then onConfirm() end end)
		for _, c in ipairs(conns) do table.insert(confirmationConns, c) end
	end
	local btnDenyHolder = bottomContent and bottomContent:FindFirstChild("DenyButton")
	if btnDenyHolder then
		local btn = btnDenyHolder:FindFirstChild("Btn") or btnDenyHolder
		local conns = bind_click(btn, cleanup)
		for _, c in ipairs(conns) do table.insert(confirmationConns, c) end
	end
	local exitBtn = conf:FindFirstChild("ExitButton", true)
	if exitBtn then
		local btn = exitBtn:FindFirstChild("Btn") or exitBtn
		local conns = bind_click(btn, cleanup)
		for _, c in ipairs(conns) do table.insert(confirmationConns, c) end
	end
end

local function update_selector_visuals()
	local ui = get_ui()
	if not ui or not ui.Selector then return end
	for _, tabName in ipairs({"Pogos", "Pets", "Potions"}) do
		local tab = ui.Selector:FindFirstChild(tabName)
		if tab then
			local alpha = (currentCategory == tabName) and 0 or 0.5
			local icon = tab:FindFirstChild("Icon")
			if icon then icon.ImageTransparency = alpha end
			local headText = tab:FindFirstChild("HeadText")
			if headText then headText.TextTransparency = alpha end
		end
	end
end

local function clear_grid(gridTable)
	for _, frame in pairs(gridTable) do frame:Destroy() end
	table.clear(gridTable)
end

local function set_adding_mode(state)
	isAddingMode = state
	local ui = get_ui()
	local addBtn = ui and ui.BestPogos and ui.BestPogos:FindFirstChild("AddButton")
	if addBtn then
		local amountTxt = addBtn:FindFirstChild("Amount")
		if amountTxt then amountTxt.Text = state and "-" or "+" end
	end
	if not state then pendingReplaceItem = nil end
end

local function handle_item_click(itemId, isBestSlot)
	if currentCategory == "Potions" then
		local amount = ownedPotions[itemId] or 0
		if amount <= 0 then return end
		local potionData = PotionsData.Get(itemId)
		if not potionData then return end
		show_confirmation("Use " .. potionData.DisplayName, "Use this potion?", function()
			equipRemote:FireServer("Potions", "Use", itemId)
		end)
		return
	end
	local currentBestList = (currentCategory == "Pogos") and bestPogos or bestPets
	if isAddingMode then
		if not isBestSlot then
			local count = 0
			for _ in pairs(currentBestList) do count += 1 end
			if count >= MAX_BEST_SLOTS then
				pendingReplaceItem = itemId
				show_confirmation("Inventory Full", "Select an item in your Best list to replace.", function() end)
			else
				show_confirmation("Add to Best", "Do you want to add this?", function()
					equipRemote:FireServer(currentCategory, "Add", itemId)
					set_adding_mode(false)
				end)
			end
		else
			if pendingReplaceItem then
				show_confirmation("Replace Item", "Replace this?", function()
					equipRemote:FireServer(currentCategory, "Replace", {Old = itemId, New = pendingReplaceItem})
					set_adding_mode(false)
				end)
			else
				show_confirmation("Remove Item", "Remove from best?", function()
					equipRemote:FireServer(currentCategory, "Remove", itemId)
				end)
			end
		end
	else
		if currentCategory == "Pets" then
			local isAlreadyEquipped = is_equipped(itemId)
			local action = isAlreadyEquipped and "Unequip" or "Equip"
			show_confirmation(action .. " Pet", "Do you want to " .. action:lower() .. " this pet?", function()
				equipRemote:FireServer(currentCategory, "Select", itemId)
			end)
		else
			local action = is_equipped(itemId) and "Unequip" or "Equip"
			show_confirmation(action .. " Item", "Do you want to " .. action:lower() .. " this item?", function()
				equipRemote:FireServer(currentCategory, "Select", itemId)
			end)
		end
	end
end

local function create_item_frame(itemId, parent, isBest)
	local template = isBest and cachedBestTemplate or cachedMainTemplate
	if not template then return nil end
	local newFrame = template:Clone()
	newFrame.Name = itemId
	newFrame.Visible = true
	local stickViewportContainer = newFrame:FindFirstChild("StickViewport", true)
	local potionImg = newFrame:FindFirstChild("PotionImg", true)
	local nameLabel1 = newFrame:FindFirstChild("Name", true)
	local nameLabel2 = newFrame:FindFirstChild("NamePogo", true)
	local amountLabel = newFrame:FindFirstChild("AmountPotions", true)
	local checkImg = newFrame:FindFirstChild("CheckImg", true)
	local displayName = get_display_name(itemId, currentCategory)
	if nameLabel1 then nameLabel1.Text = displayName end
	if nameLabel2 then nameLabel2.Text = displayName end
	if currentCategory == "Potions" then
		if stickViewportContainer then stickViewportContainer.Visible = false end
		if checkImg then checkImg.Visible = false end
		if potionImg then
			local potionData = PotionsData.Get(itemId)
			potionImg.Image = potionData and potionData.Image or ""
			potionImg.Visible = true
		end
		if amountLabel then
			local qty = tonumber(ownedPotions[itemId]) or 0
			amountLabel.Text = "x" .. qty
			amountLabel.Visible = true
		end
	else
		if potionImg then potionImg.Visible = false end
		if amountLabel then amountLabel.Visible = false end
		local isItemEquipped = is_equipped(itemId)
		newFrame.BackgroundColor3 = isItemEquipped and COLOR_EQUIPPED or COLOR_DEFAULT
		if checkImg then checkImg.Visible = isItemEquipped end
		if stickViewportContainer then
			stickViewportContainer.Visible = true
			stickViewportContainer:ClearAllChildren()
			stickViewportContainer.ClipsDescendants = true 
			local viewportData
			if currentCategory == "Pets" then viewportData = DataPets.GetPetViewport(itemId)
			elseif currentCategory == "Pogos" then viewportData = PogoData.GetPogoViewport(itemId) end
			if viewportData and viewportData:IsA("ViewportFrame") then
				local canvasGroup = Instance.new("CanvasGroup")
				canvasGroup.Size = UDim2.fromOffset(VIEWPORT_RESOLUTION, VIEWPORT_RESOLUTION)
				canvasGroup.AnchorPoint = Vector2.new(0.5, 0.5)
				canvasGroup.Position = UDim2.fromScale(0.5, 0.5)
				canvasGroup.BackgroundTransparency = 1
				canvasGroup.Parent = stickViewportContainer
				local uiScale = Instance.new("UIScale")
				local currentSize = stickViewportContainer.AbsoluteSize.X
				if currentSize <= 0 then currentSize = 100 end 
				uiScale.Scale = currentSize / VIEWPORT_RESOLUTION
				uiScale.Parent = canvasGroup

				local cam = viewportData.CurrentCamera
				if cam then
					cam.CFrame = cam.CFrame * CFrame.new(0, 0, CAMERA_DISTANCE_OFFSET)
				end

				viewportData.Size = UDim2.fromScale(VIEWPORT_OVERFLOW, VIEWPORT_OVERFLOW)
				viewportData.Position = UDim2.fromScale(0.5, 0.5)
				viewportData.AnchorPoint = Vector2.new(0.5, 0.5)
				viewportData.BackgroundTransparency = 1
				viewportData.Parent = canvasGroup
			end
		end
	end
	disable_input_blockers(newFrame)
	local bgDesign = newFrame:FindFirstChild("BackgroundDesign", true)
	if bgDesign then
		local rarity = nil
		if currentCategory == "Pets" then
			local petData = DataPets.GetPetData(itemId)
			rarity = petData and petData.Raritys
		elseif currentCategory == "Pogos" then
			local pogoData = PogoData.Get(itemId)
			rarity = pogoData and pogoData.Rarity
		end
		local rarityConfig = rarity and RaritysData[rarity]
		bgDesign.ImageColor3 = rarityConfig and rarityConfig.Color or COLOR_DEFAULT
	end
	local targetBtn = newFrame:FindFirstChild("Btn", true) or newFrame
	bind_click(targetBtn, function() handle_item_click(itemId, isBest) end)
	newFrame.MouseEnter:Connect(function() show_tooltip(itemId, currentCategory) end)
	newFrame.MouseLeave:Connect(function() hide_tooltip() end)
	newFrame.Destroying:Connect(function() hide_tooltip() end)
	newFrame.Parent = parent
	return newFrame
end

local function update_best_ui()
	local ui = get_ui()
	if not ui or not ui.BestPogos then return end
	clear_grid(createdBestFrames)
	local currentBestList = (currentCategory == "Pogos") and bestPogos or bestPets
	local count = 0
	for _, itemId in pairs(currentBestList) do
		count += 1
		local frame = create_item_frame(itemId, ui.BestPogos, true)
		if frame then createdBestFrames[itemId] = frame end
	end
	if ui.BestPogosTextLB and ui.BestPogosTextLB:FindFirstChild("BestPogosText") then
		local typeName = (currentCategory == "Pogos") and "Best Pogos: " or "Best Pets: "
		ui.BestPogosTextLB.BestPogosText.Text = typeName .. count .. "/" .. MAX_BEST_SLOTS
	end
end

local function update_main_content()
	local ui = get_ui()
	if not ui or not ui.MainContent then return end
	clear_grid(createdMainFrames)
	local listToIterate = {}
	if currentCategory == "Pets" then listToIterate = type(ownedPets) == "table" and ownedPets or {}
	elseif currentCategory == "Pogos" then listToIterate = type(ownedPogos) == "table" and ownedPogos or {}
	elseif currentCategory == "Potions" then listToIterate = ownedPotions or {} end
	local query = currentSearchQuery:lower()
	for itemId, value in pairs(listToIterate) do
		if currentCategory == "Potions" then if (tonumber(value) or 0) <= 0 then continue end end
		local displayName = get_display_name(itemId, currentCategory)
		if query == "" or displayName:lower():find(query) or tostring(itemId):lower():find(query) then
			local frame = create_item_frame(itemId, ui.MainContent, false)
			if frame then createdMainFrames[itemId] = frame end
		end
	end
end

local function full_refresh()
	ownedPets = DataUtility.client.get("OwnedPets") or {}
	bestPets = DataUtility.client.get("BestPets") or {}
	equippedPets = DataUtility.client.get("EquippedPets") or {}
	ownedPogos = DataUtility.client.get("OwnedPogos") or {}
	bestPogos = DataUtility.client.get("BestPogos") or {}
	equippedPogoId = DataUtility.client.get("EquippedPogoId") or ""
	ownedPotions = DataUtility.client.get("Potions") or {}
	set_adding_mode(false)
	update_best_ui()
	update_main_content()
end

local function switch_category(newCategory)
	currentCategory = newCategory
	currentSearchQuery = ""
	local ui = get_ui()
	if not ui then return end
	if ui.SearchBar and ui.SearchBar:FindFirstChild("TextBox") then ui.SearchBar.TextBox.Text = "" end
	update_selector_visuals()
	set_adding_mode(false)
	if ui.MainContent then
		if not defaultMainContentSize then
			defaultMainContentSize = ui.MainContent.Size
			defaultMainContentPosition = ui.MainContent.Position
		end
		if currentCategory == "Potions" then
			if ui.BestPogos then ui.BestPogos.Visible = false end
			if ui.BestPogosTextLB then ui.BestPogosTextLB.Visible = false end
			local bestHeight = 0.17
			ui.MainContent.Size = UDim2.new(defaultMainContentSize.X.Scale, 0, defaultMainContentSize.Y.Scale + bestHeight, 0)
			ui.MainContent.Position = UDim2.new(defaultMainContentPosition.X.Scale, 0, defaultMainContentPosition.Y.Scale - bestHeight, 0)
		else
			if ui.BestPogos then ui.BestPogos.Visible = true end
			if ui.BestPogosTextLB then ui.BestPogosTextLB.Visible = true end
			ui.MainContent.Size = defaultMainContentSize
			ui.MainContent.Position = defaultMainContentPosition
			update_best_ui()
		end
	end
	update_main_content()
end

local function setup_ui_events()
	local ui = get_ui()
	if not ui then return end
	if ui.Confirmation then ui.Confirmation.Visible = false end
	init_templates()
	init_tooltip()
	if ui.Selector then
		for _, tabName in ipairs({"Pogos", "Pets", "Potions"}) do
			local tab = ui.Selector:FindFirstChild(tabName)
			if tab then
				local btn = tab:FindFirstChild("Btn", true) or tab
				bind_click(btn, function() switch_category(tabName) end)
			end
		end
	end
	if ui.BestPogos and ui.BestPogos:FindFirstChild("AddButton") then
		local btn = ui.BestPogos.AddButton:FindFirstChild("Btn", true) or ui.BestPogos.AddButton
		bind_click(btn, function() set_adding_mode(not isAddingMode) end)
	end
	if ui.SearchBar and ui.SearchBar:FindFirstChild("TextBox") then
		ui.SearchBar.TextBox:GetPropertyChangedSignal("Text"):Connect(function()
			currentSearchQuery = ui.SearchBar.TextBox.Text
			update_main_content()
		end)
	end
end

------------------//INIT
DataUtility.client.ensure_remotes()
local dataKeys = {"OwnedPets", "BestPets", "EquippedPets", "OwnedPogos", "BestPogos", "EquippedPogoId", "Potions"}
for _, key in ipairs(dataKeys) do
	DataUtility.client.bind(key, function() full_refresh() end)
end
task.spawn(function()
	setup_ui_events()
	switch_category("Pogos")
	full_refresh()
end)

return InventoryController