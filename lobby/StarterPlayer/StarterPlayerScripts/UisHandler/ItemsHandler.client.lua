-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- CONSTANTS
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ViewModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ViewModule"))
local itemStatsModule = require(ReplicatedStorage:WaitForChild("ItemStats"))
local UIHandler = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local ViewPortModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ViewPortModule"))

local ItemsUI = PlayerGui:WaitForChild("NewUI"):WaitForChild("ItemsFrame")
local MainFrame = ItemsUI:WaitForChild("Main")
local ItemsTab = MainFrame:WaitForChild("ItemsTab")

local ContentGrid = ItemsTab:WaitForChild("Content")
local TopLeftArea = MainFrame:WaitForChild("TopLeft")

local closeButton = ItemsUI:WaitForChild("Closebtn")
local titleText = MainFrame:WaitForChild("Title") 

-- Referência da barra de pesquisa
local searchBox = TopLeftArea:WaitForChild("Search"):WaitForChild("TextBox")

local itemsSelectionFrame = MainFrame:WaitForChild("ItemsSelection")
local itemTemplateButton = ContentGrid:WaitForChild("1")

itemTemplateButton.Visible = false
itemsSelectionFrame.Visible = false

-- VARIABLES
local selectedButton = nil
local totalQuantity = 0

-- FUNCTIONS

local function filterItems(searchText)
	local lowerSearch = string.lower(searchText)

	for _, child in pairs(ContentGrid:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "1" then
			if lowerSearch == "" or string.find(string.lower(child.Name), lowerSearch) then
				child.Visible = true
			else
				child.Visible = false
			end
		end
	end
end

local SelectionLibrary; SelectionLibrary = {
	["Update"] = function(visible, item, itemButton)
		if not visible then
			itemsSelectionFrame.Visible = false
			return
		end

		local itemStats = itemStatsModule[item.Name]
		if itemStats then
			local useButtonVisibleForType = { "XP_feed", "Boost" }

			itemsSelectionFrame.SelectionScrollingButtons.UseButton.Visible = (table.find(useButtonVisibleForType, itemStats.Itemtype)) and true or false
			itemsSelectionFrame.ItemRarity.Text = itemStats.Rarity
			itemsSelectionFrame.ItemDescription.Text = itemStats.Description
		end

		itemsSelectionFrame.ItemName.Text = item.Name
		itemsSelectionFrame.Visible = true
	end,

	["View"] = function()
		if not selectedButton then return end
		itemsSelectionFrame.Visible = false
		local itemName = selectedButton.ItemValue.Value.Name
		local itemStats = itemStatsModule[itemName]

		if not itemStats then return end

		ViewModule.Item({
			itemStats,
			selectedButton.ItemValue.Value,
			LocalPlayer.Items[itemName].Value
		})

		UIHandler.PlaySound("Redeem")
		selectedButton = nil
	end,

	["Use"] = function()
		if not selectedButton then return end
		local itemName = selectedButton.ItemValue.Value.Name
		local itemStats = itemStatsModule[itemName]

		if itemStats and itemStats.Itemtype == "XP_feed" then
			if _G.CloseAll then
				_G.CloseAll("LvlUpFrame")
			end
		end

		SelectionLibrary.Update(false)
		ReplicatedStorage.Events.UseItem:FireServer(itemName)
	end,
}

local function NewItem(item)
	totalQuantity += item.Value
	titleText.Text = `Items: {totalQuantity}/∞` 

	if item.Value <= 0 then return end

	local button = itemTemplateButton:Clone()
	button.Name = item.Name
	button.Visible = true

	button:WaitForChild("Name").Text = item.Name
	button:WaitForChild("Amount").Text = "x" .. tostring(item.Value)

	local placeholderContainer = button:WaitForChild("Placeholder")

	local viewport = ViewPortModule.CreateViewPort(item.Name, false, false, false)

	if viewport then
		local defaultVP = placeholderContainer:FindFirstChild("ViewportFrame")
		if defaultVP then
			defaultVP:Destroy()
		end

		local imagePlaceholder = placeholderContainer:FindFirstChild("Placeholder")
		if imagePlaceholder and imagePlaceholder:IsA("ImageLabel") then
			imagePlaceholder.Visible = false
		end

		viewport.Parent = placeholderContainer
		viewport.Size = UDim2.new(1, 0, 1, 0)
		viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	end

	local itemValueObj = Instance.new('ObjectValue', button)
	itemValueObj.Name = 'ItemValue'
	itemValueObj.Value = item

	button.Parent = ContentGrid

	local function ButtonClick()
		if selectedButton and selectedButton == button then
			SelectionLibrary.Update(false)
			selectedButton = nil
			return
		end

		selectedButton = button
		SelectionLibrary.Update(true, item, button)
	end

	if button:IsA("GuiButton") then
		button.MouseButton1Down:Connect(ButtonClick)
	else
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				ButtonClick()
			end
		end)
	end

	if searchBox.Text ~= "" then
		local lowerSearch = string.lower(searchBox.Text)
		if not string.find(string.lower(item.Name), lowerSearch) then
			button.Visible = false
		end
	end
end

local function updateItem(item)
	local itemUI = ContentGrid:FindFirstChild(item.Name)

	if item.Value <= 0 and itemUI then
		local placeholderContainer = itemUI:FindFirstChild("Placeholder")
		if placeholderContainer then
			local viewport = placeholderContainer:FindFirstChild(item.Name)
			if viewport then
				ViewPortModule.DestroyViewport(viewport)
			end
		end

		itemUI:Destroy()
	elseif itemUI then
		local amountLabel = itemUI:FindFirstChild("Amount")
		local oldAmountStr = amountLabel.Text:gsub("x", "") 
		local oldAmount = tonumber(oldAmountStr)

		if oldAmount then
			totalQuantity += (item.Value - oldAmount)
		else
			totalQuantity += item.Value
		end

		titleText.Text = `Items: {totalQuantity}/∞`
		amountLabel.Text = "x" .. tostring(item.Value)
	else
		NewItem(item)
	end
end

-- INIT
itemsSelectionFrame.SelectionScrollingButtons.ViewButton.Activated:Connect(SelectionLibrary.View)
itemsSelectionFrame.SelectionScrollingButtons.UseButton.Activated:Connect(SelectionLibrary.Use)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	filterItems(searchBox.Text)
end)

local playerItemsFolder = LocalPlayer:WaitForChild("Items")
playerItemsFolder.ChildAdded:Connect(NewItem)

for _, item in playerItemsFolder:GetChildren() do
	NewItem(item)
	item.Changed:Connect(function()
		updateItem(item)
	end)
end