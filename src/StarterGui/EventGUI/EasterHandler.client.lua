-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Player = game:GetService("Players").LocalPlayer
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

-- EasterShop GUI
local EasterShopGUI = Player.PlayerGui.EventGUI.EasterShop
local Contents = EasterShopGUI.Frame.Right_Panel.Contents.Rewards_Frame.Bar
local EggsCounter = EasterShopGUI:WaitForChild("Frame").Right_Panel.Eggs
local Prompt = Player.PlayerGui.CoreGameUI.Prompt.Prompt
local CurrencyCongratsLabel = Player.PlayerGui.GameGui.PRShop.Success

-- Events
local Remotes = ReplicatedStorage.Remotes
local EasterShop = Remotes.Easter.EasterShop
local EasterEvent = Remotes.Easter.EasterElevator
local EggsChanged = Remotes.Easter.EggsChanged
local EasterShopPurchase = Remotes.Easter.EasterShopPurchase

-- Values
local Eggs = Player:FindFirstChild("GoldenRepublicCredits")
local debounceFlags = {}
local selectedEasterItem = nil

-- Buttons
local Buttons = {
	["Gems"] = Contents.Gems,
	["Crystal"] = Contents.EpicCrystal,
	["Crystal (Blue)"] = Contents["Crystal (Blue)"],
	["Crystal (Pink)"] = Contents["Crystal (Pink)"],
	["Crystal (Green)"] = Contents["Crystal (Green)"],
	["Crystal (Red)"] = Contents["Crystal (Red)"],
	["Crystal (Celestial)"] = Contents["Crystal (Celestial)"],
	["Event Double Luck"] = Contents["Double Event Luck"],
	["TraitPoint"] = Contents["TraitPoint"]
}

-- Functions
local function ShowSuccessMessage(typeOf, name, quantity)
	--if typeOf == "Currency" then
	--	local itemName = typeof(name) == "Instance" and name.Name or tostring(name)
	--	CurrencyCongratsLabel.Text = tostring(quantity) .. "x " .. itemName .. " Earned!"
	--	CurrencyCongratsLabel.Visible = true
	--	task.wait(2)
	--	CurrencyCongratsLabel.Visible = false
	--end

	print(typeOf, "LocalSideMessage")

	if typeOf == nil then
		_G.Message("Purchase Failed", Color3.fromRGB(255, 5, 17))
	else
		_G.Message("Purchase Successful", Color3.fromRGB(28, 255, 3))
	end
end

local function SetupViewPorts()
	local viewData = {
		["Crystal"] = Contents.EpicCrystal.Item_Contents.Icon,
		["Crystal (Blue)"] = Contents["Crystal (Blue)"].Item_Contents.Icon,
		["Crystal (Pink)"] = Contents["Crystal (Pink)"].Item_Contents.Icon,
		["Crystal (Green)"] = Contents["Crystal (Green)"].Item_Contents.Icon,
		["Crystal (Red)"] = Contents["Crystal (Red)"].Item_Contents.Icon,
		["Crystal (Celestial)"] = Contents["Crystal (Celestial)"].Item_Contents.Icon,
	}

	Contents.EpicCrystal.Item_Contents.Icon.Image = ""
	Contents["Crystal (Blue)"].Item_Contents.Icon.Image = ""
	Contents["Crystal (Pink)"].Item_Contents.Icon.Image = ""
	Contents["Crystal (Green)"].Item_Contents.Icon.Image = ""
	Contents["Crystal (Red)"].Item_Contents.Icon.Image = ""
	Contents["Crystal (Celestial)"].Item_Contents.Icon.Image = ""

	for itemName, iconFrame in viewData do
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = iconFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end
end

-- Handle button clicks with prompt
EasterShop.OnClientEvent:Connect(function(visibility)
	print(Eggs)
	EasterShopGUI.Visible = visibility
	EggsCounter.Text = "Golden-RC: x" .. tostring(Eggs.Value)
	SetupViewPorts()

	for itemName, button in Buttons do
		if not debounceFlags[itemName] then
			debounceFlags[itemName] = false
		end

		button.Activated:Connect(function()
			if debounceFlags[itemName] then return end
			debounceFlags[itemName] = true

			selectedEasterItem = itemName
			Prompt.Visible = true

			task.wait(1)
			debounceFlags[itemName] = false
		end)
	end
end)

-- Confirm prompt
Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedEasterItem then
		Prompt.Visible = false
		EasterShopPurchase:FireServer(selectedEasterItem)
		selectedEasterItem = nil
	end
end)

-- Cancel prompt
Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedEasterItem = nil
end)

-- Show success/failure
EasterShopPurchase.OnClientEvent:Connect(function(typeOf, name, quantity)
	ShowSuccessMessage(typeOf, name, quantity)
end)

-- Update egg count label
Eggs:GetPropertyChangedSignal("Value"):Connect(function()
	EggsCounter.Text = "Golden-RC: x " .. tostring(Eggs.Value)
end)

