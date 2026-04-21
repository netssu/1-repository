local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local PlayerGUI = Player:WaitForChild("PlayerGui")
local RaidShopGUI = PlayerGUI:WaitForChild("RaidGui").Raids["Raid Shop"]
local RightPanel = RaidShopGUI.Frame.Right_Panel
local CreditsLabel = RightPanel.Credits
local Refresh = RightPanel.Refresh
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)

local RaidShopPurchase = ReplicatedStorage.Remotes.Raid.RaidShopPurchase
local CreditsChanged = ReplicatedStorage.Remotes.Raid.CreditsChanged
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local LoadingData = require(ReplicatedStorage.Modules.LoadingRaidShopData)

local CurrencyCongratsLabel = PlayerGUI.GameGui.PRShop.Success
local Prompt = PlayerGUI.CoreGameUI.Prompt.Prompt

local debounceFlags = {}
local selectedItem = nil

local Contents = RightPanel.Contents.Rewards_Frame.Bar
local buttons = {
	["Killer Helmet"] = Contents.EvoItem,
	["2x Coins"] = Contents["2x Coins"],
	["2x Gems"] = Contents["2x Gems"],
	["2x XP"] = Contents["2x XP"],
	["Lucky Crystal"] = Contents["Lucky Crystal"],
	["Fortunate Crystal"] = Contents["Fortunate Crystal"],
	["TraitPoint"] = Contents.Traits,
	["Gems"] = Contents.Gems,
	["x2 Buff"] = Contents.TwoxBuff,
	["x3 Buff"] = Contents.threexBuff,
	["Junk Offering"] = Contents["Junk Offering"],
	["RaidsRefresh"] = Contents.RaidRefreshes
}

local function ShowSuccessMessage(typeOf, name, quantity)
	if type == "Currency" then
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
		["Killer Helmet"] = Contents.EvoItem.Item_Contents.Icon,
		["Lucky Crystal"] = Contents["Lucky Crystal"].Item_Contents.Icon,
		["Fortunate Crystal"] = Contents["Fortunate Crystal"].Item_Contents.Icon,
		["Junk Offering"] = Contents["Junk Offering"].Item_Contents.Icon
	}

	Contents.EvoItem.Item_Contents.Icon.Image = ""
	Contents["Fortunate Crystal"].Item_Contents.Icon.Image = ""
	Contents["Lucky Crystal"].Item_Contents.Icon.Image = ""

	for itemName, iconFrame in pairs(viewData) do
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = iconFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end
end

CreditsChanged.OnClientEvent:Connect(function(value)
	CreditsLabel.Text = "Credits: x" .. tostring(value)
end)

ReplicatedStorage.Remotes.Raid.RaidShopLoading.OnClientEvent:Connect(function(visible)
	RaidShopGUI.Visible = visible
	LoadingData.LoadCredits(Player, CreditsLabel)
	LoadingData.LoadRefresh(Player, Refresh)
	SetupViewPorts()

	for itemName, button in pairs(buttons) do
		if not debounceFlags[itemName] then
			debounceFlags[itemName] = false
		end

		button.Activated:Connect(function()
			if debounceFlags[itemName] then return end
			debounceFlags[itemName] = true

			selectedItem = itemName
			Prompt.Visible = true

			task.wait(1)
			debounceFlags[itemName] = false
		end)
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

local currency = Player:FindFirstChild("RaidData"):FindFirstChild("Credits")
currency:GetPropertyChangedSignal("Value"):Connect(function()
	CreditsChanged:FireServer(Player)
end)
