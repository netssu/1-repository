local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local PlayerGUI : PlayerGui = Player:WaitForChild("PlayerGui") 
local ChallengeShopGUI : ScreenGui = PlayerGUI:WaitForChild('CoreGameUI').ChallengeShop.ChallengeShopFrame :: Frame	
local Main : Frame = ChallengeShopGUI.Frame.Main
local CreditsLabel : TextLabel = Main.Credits
local Prompt : Frame = PlayerGUI.CoreGameUI.Prompt.Prompt


local ChallengePurchase = ReplicatedStorage.Events.Challenges.ChallengePurchase
local CreditsChanged = ReplicatedStorage.Events.Challenges.CheckCurrency
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local LoadingData = require(ReplicatedStorage.Modules.LoadingRaidShopData)

local CurrencyCongratsLabel = PlayerGUI.GameGui.PRShop.Success
local debounceFlags = {}

local Contents = Main.Contents.Rewards_Frame.Bar
warn(Contents:GetChildren())
local buttons = {
	["Crystal (Green)"] = Contents["Crystal (Green)"],
	["Crystal (Blue)"] = Contents["Crystal (Blue)"],
	["Crystal (Red)"] = Contents["Red Crystal"],
	["Crystal (Pink)"] = Contents["Crystal (Pink)"],
	["Crystal (Celestial)"] = Contents["Crystal (Celestial)"],
	["Gems"] = Contents.Gems,
	["Lucky Crystal"] = Contents["Lucky Crystal"],
	["Fortunate Crystal"] = Contents["Fortunate Crystal"],
	["TraitPoint"] = Contents.TraitPoint,
	["Credits"] = Contents.Credits,
	["Crystal"] = Contents.Crystal,
	["Sixth Brother"] = Contents["Sixth Brother"],
}

-- Hi dani, rainbow doesn't seem to be parented to contents, are you currently working on this? - mathrix
-- Fixed

local MessageEvent = ReplicatedStorage.Events.Client.Message

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
		_G.Message("Purchase Successful", Color3.fromRGB(28, 255, 3))
	end
end

-- UI setup
local function SetupViewPorts()
	local viewData = {
		["Crystal (Pink)"] = Contents["Crystal (Pink)"].Item_Contents.Icon,
		["Lucky Crystal"] = Contents["Lucky Crystal"].Item_Contents.Icon,
		["Crystal (Green)"] = Contents["Crystal (Green)"].Item_Contents.Icon,
		["Crystal (Blue)"] = Contents["Crystal (Blue)"].Item_Contents.Icon,
		["Crystal (Red)"] = Contents["Red Crystal"].Item_Contents.Icon,
		["Crystal (Celestial)"] = Contents["Crystal (Celestial)"].Item_Contents.Icon,
		["Crystal"] = Contents["Crystal"].Item_Contents.Icon,
		["Sixth Brother"] = Contents["Sixth Brother"].Item_Contents.Icon,
	}

	-- Clear Image property before setting up viewports
	Contents["Crystal (Pink)"].Item_Contents.Icon.Image = ""
	Contents["Lucky Crystal"].Item_Contents.Icon.Image = ""
	Contents["Crystal (Green)"].Item_Contents.Icon.Image = ""
	Contents["Crystal (Blue)"].Item_Contents.Icon.Image = ""
	Contents["Red Crystal"].Item_Contents.Icon.Image = ""
	Contents["Crystal (Celestial)"].Item_Contents.Icon.Image = ""

	for itemName, iconFrame in pairs(viewData) do
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = iconFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end
end






local selectedItem = nil

Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedItem then
		Prompt.Visible = false
		ChallengePurchase:FireServer(selectedItem)
		selectedItem = nil
	end
end)

Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedItem = nil
end)

ChallengeShopGUI:GetPropertyChangedSignal("Visible"):Connect(function()
	if ChallengeShopGUI.Visible then
		--_G:CloseAll()
		local creditsValue = CreditsChanged:InvokeServer(Player)
		CreditsLabel.Text = "Republic-Credits: x" .. tostring(creditsValue)
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
	end
end)

ReplicatedStorage.Events.Challenges.ChallengeShopLoading.Event:Connect(function(visible)
	
end)

ChallengePurchase.OnClientEvent:Connect(function(typeOf, name, quantity)
	ShowSuccessMessage(typeOf, name, quantity)
end)


local currency = Player:FindFirstChild("RepublicCredits")
currency:GetPropertyChangedSignal("Value"):Connect(function()
	local creditsValue = CreditsChanged:InvokeServer(Player)
	warn(creditsValue)
	CreditsLabel.Text = "Republic-Credits: x" .. tostring(creditsValue)
end)
