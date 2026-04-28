-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local Player = Players.LocalPlayer
local PlayerGUI = Player:WaitForChild("PlayerGui")

local NewUI = PlayerGUI:WaitForChild("NewUI")
local RaidShopGUI = NewUI:WaitForChild("RaidShop")

local Main = RaidShopGUI:WaitForChild("Main")
local RewardsTab = Main:WaitForChild("RewardsTab")
local RewardsMainFrame = RewardsTab:WaitForChild("Rewards")
local RewardsGrid = RewardsMainFrame:WaitForChild("Rewards") 

local CreditsLabel = RewardsTab:WaitForChild("Credits")
local RefreshLabel = RewardsTab:WaitForChild("Refresh")

local UIHandler = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local RaidShopPurchase = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Raid"):WaitForChild("RaidShopPurchase")
local CreditsChanged = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Raid"):WaitForChild("CreditsChanged")
local ViewPortModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ViewPortModule"))
local LoadingData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("LoadingRaidShopData"))

local GameGui = PlayerGUI:WaitForChild("GameGui")
local CurrencyCongratsLabel = GameGui:WaitForChild("PRShop"):WaitForChild("Success")
local Prompt = PlayerGUI:WaitForChild("CoreGameUI"):WaitForChild("Prompt"):WaitForChild("Prompt")

-- VARIABLES
local debounceFlags = {}
local selectedItem = nil

local buttons = {
	["Killer Helmet"] = RewardsGrid:FindFirstChild("EvoItem"),
	["2x Coins"] = RewardsGrid:FindFirstChild("2x Coins"),
	["2x Gems"] = RewardsGrid:FindFirstChild("2x Gems"),
	["2x XP"] = RewardsGrid:FindFirstChild("2x XP"),
	["Gems"] = RewardsGrid:FindFirstChild("Gems"),
	["x2 Buff"] = RewardsGrid:FindFirstChild("TwoxBuff"),
	["x3 Buff"] = RewardsGrid:FindFirstChild("threexBuff"),
	["RaidsRefresh"] = RewardsGrid:FindFirstChild("RaidRefreshes"),

	["Lucky Crystal"] = RewardsGrid:FindFirstChild("Lucky Crystal"),
	["Fortunate Crystal"] = RewardsGrid:FindFirstChild("Fortunate Crystal"),
	["TraitPoint"] = RewardsGrid:FindFirstChild("Traits"),
	["Junk Offering"] = RewardsGrid:FindFirstChild("Junk Offering")
}

-- FUNCTIONS
local function ShowSuccessMessage(typeOf, name, quantity)
	if typeOf == "Currency" then
		local itemName = typeof(name) == "Instance" and name.Name or tostring(name)
		CurrencyCongratsLabel.Text = tostring(quantity) .. "x " .. itemName .. " Earned!"
		CurrencyCongratsLabel.Visible = true
		task.wait(2)
		CurrencyCongratsLabel.Visible = false
	end

	if typeOf == nil then
		_G.Message("Purchase Failed", Color3.fromRGB(255, 5, 17))
	else
		UIHandler.CreateConfetti()
		_G.Message("Purchase Successful", Color3.fromRGB(28, 255, 3))
	end
end

local function SetupViewPorts()
	local viewData = {
		["Killer Helmet"] = RewardsGrid:FindFirstChild("EvoItem"),
		["Lucky Crystal"] = RewardsGrid:FindFirstChild("Lucky Crystal"),
		["Fortunate Crystal"] = RewardsGrid:FindFirstChild("Fortunate Crystal"),
		["Junk Offering"] = RewardsGrid:FindFirstChild("Junk Offering")
	}

	for itemName, card in pairs(viewData) do
		if card and card:FindFirstChild("Placeholder") and card.Placeholder:FindFirstChild("Icon") then
			local iconFrame = card.Placeholder.Icon
			iconFrame.Image = "" -- Remove a imagem atual

			local viewport = ViewPortModule.CreateViewPort(itemName)
			if viewport then
				viewport.Parent = iconFrame
				viewport.Size = UDim2.new(1, 0, 1, 0)
			end
		end
	end
end

local function SetupCurrencyListener()
	-- Aguarda o RaidData carregar no Player, já que o script inicia rápido no StarterPlayer
	local raidData = Player:WaitForChild("RaidData", 10)
	if raidData then
		local currency = raidData:WaitForChild("Credits", 10)
		if currency then
			currency:GetPropertyChangedSignal("Value"):Connect(function()
				CreditsChanged:FireServer(Player)
			end)
		end
	end
end

-- INIT
CreditsChanged.OnClientEvent:Connect(function(value)
	CreditsLabel.Text = "Credits: x" .. tostring(value)
end)

ReplicatedStorage.Remotes.Raid.RaidShopLoading.OnClientEvent:Connect(function(visible)
	RaidShopGUI.Visible = visible
	LoadingData.LoadCredits(Player, CreditsLabel)
	LoadingData.LoadRefresh(Player, RefreshLabel)
	SetupViewPorts()

	for itemName, button in pairs(buttons) do
		if button then -- Proteção caso o botão não exista na grid ainda
			if not debounceFlags[itemName] then
				debounceFlags[itemName] = false
			end

			-- Se o card for apenas um frame, talvez você precise usar InputBegan ou colocar um TextButton/ImageButton invisível dentro dele. 
			-- Presumindo que o card tenha a classe Button ou um botão interno configurado:
			button.Activated:Connect(function()
				if debounceFlags[itemName] then return end
				debounceFlags[itemName] = true

				selectedItem = itemName
				Prompt.Visible = true

				task.wait(1)
				debounceFlags[itemName] = false
			end)
		end
	end
end)

Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedItem then
		Prompt.Visible = false
		RaidShopPurchase:FireServer(selectedItem)
		selectedItem = nil
	end
end)

Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedItem = nil
end)

RaidShopPurchase.OnClientEvent:Connect(function(typeOf, name, quantity)
	ShowSuccessMessage(typeOf, name, quantity)
end)

SetupCurrencyListener()