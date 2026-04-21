-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- CONSTANTS
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Interfaces
local EasterShopGUI = PlayerGui:WaitForChild("NewUI"):WaitForChild("EasterShop")
local Main = EasterShopGUI:WaitForChild("Main")
local RewardsTab = Main:WaitForChild("RewardsTab")
local Contents = RewardsTab:WaitForChild("Rewards"):WaitForChild("Rewards")
local TextAmount = RewardsTab:WaitForChild("TextAmount")

local Prompt = PlayerGui:WaitForChild("CoreGameUI"):WaitForChild("Prompt"):WaitForChild("Prompt")
local CurrencyCongratsLabel = PlayerGui:WaitForChild("GameGui"):WaitForChild("PRShop"):WaitForChild("Success")

-- Remotes & Modules
local ViewPortModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ViewPortModule"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EasterShop = Remotes:WaitForChild("Easter"):WaitForChild("EasterShop")
local EasterEvent = Remotes.Easter:WaitForChild("EasterElevator")
local EggsChanged = Remotes.Easter:WaitForChild("EggsChanged")
local EasterShopPurchase = Remotes.Easter:WaitForChild("EasterShopPurchase")

-- VARIABLES
local Eggs = Player:WaitForChild("GoldenRepublicCredits")
local debounceFlags = {}
local selectedEasterItem = nil

local Buttons = {
	["Gems"] = Contents:WaitForChild("Gems"),
	["Crystal"] = Contents:WaitForChild("EpicCrystal"),
	["Crystal (Blue)"] = Contents:WaitForChild("Crystal (Blue)"),
	["Crystal (Pink)"] = Contents:WaitForChild("Crystal (Pink)"),
	["Crystal (Green)"] = Contents:WaitForChild("Crystal (Green)"),
	["Crystal (Red)"] = Contents:WaitForChild("Crystal (Red)"),
	["Crystal (Celestial)"] = Contents:WaitForChild("Crystal (Celestial)"),
	["Event Double Luck"] = Contents:WaitForChild("Double Event Luck"),
	["TraitPoint"] = Contents:WaitForChild("TraitPoint")
}

-- FUNCTIONS
local function ShowSuccessMessage(typeOf, name, quantity)
	print(typeOf, "LocalSideMessage")

	if typeOf == nil then
		_G.Message("Purchase Failed", Color3.fromRGB(255, 5, 17))
	else
		_G.Message("Purchase Successful", Color3.fromRGB(28, 255, 3))
	end
end

local function SetupViewPorts()
	local viewData = {
		["Crystal"] = Contents.EpicCrystal.Placeholder.Icon,
		["Crystal (Blue)"] = Contents["Crystal (Blue)"].Placeholder.Icon,
		["Crystal (Pink)"] = Contents["Crystal (Pink)"].Placeholder.Icon,
		["Crystal (Green)"] = Contents["Crystal (Green)"].Placeholder.Icon,
		["Crystal (Red)"] = Contents["Crystal (Red)"].Placeholder.Icon,
		["Crystal (Celestial)"] = Contents["Crystal (Celestial)"].Placeholder.Icon,
	}

	for itemName, iconFrame in pairs(viewData) do
		iconFrame.Image = ""
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = iconFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end
end

-- INIT

-- Configura os botões da loja
for itemName, button in pairs(Buttons) do
	debounceFlags[itemName] = false

	button.Activated:Connect(function()
		if debounceFlags[itemName] then return end
		debounceFlags[itemName] = true

		selectedEasterItem = itemName
		Prompt.Visible = true

		task.wait(1)
		debounceFlags[itemName] = false
	end)
end

-- Abre a loja e atualiza a quantidade de moedas
EasterShop.OnClientEvent:Connect(function(visibility)
	EasterShopGUI.Visible = visibility
	TextAmount.Text = "Golden-RC: x" .. tostring(Eggs.Value)
	SetupViewPorts()
end)

-- Botão Sim do Prompt
Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedEasterItem then
		Prompt.Visible = false
		EasterShopPurchase:FireServer(selectedEasterItem)
		selectedEasterItem = nil
	end
end)

-- Botão Não do Prompt
Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedEasterItem = nil
end)

-- Feedback de Sucesso/Falha
EasterShopPurchase.OnClientEvent:Connect(function(typeOf, name, quantity)
	ShowSuccessMessage(typeOf, name, quantity)
end)

-- Atualiza a label em tempo real se a quantidade de moedas mudar enquanto a loja estiver aberta
Eggs:GetPropertyChangedSignal("Value"):Connect(function()
	TextAmount.Text = "Golden-RC: x" .. tostring(Eggs.Value)
end)