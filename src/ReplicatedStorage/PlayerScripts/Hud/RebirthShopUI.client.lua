-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS

-- VARIABLES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local RebirthShopData = require(ReplicatedStorage.Modules.Datas.RebirthShopData)
local SoundUtility = require(ReplicatedStorage.Modules.Utility.SoundUtility)
local SoundData = require(ReplicatedStorage.Modules.Datas.SoundData)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiFolder = playerGui:WaitForChild("GUI")

local vendorFrameRebirth = guiFolder:WaitForChild("VendorFrameRebirth")
local mainContent = vendorFrameRebirth:WaitForChild("MainContent")
local template = mainContent:WaitForChild("Template")

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local shopEvent = remotesFolder:WaitForChild("RebirthShopEvent")

local createdSlots = {}

-- FUNCTIONS
local function setup_shop()
	template.Visible = false 

	for _, itemData in ipairs(RebirthShopData.Items) do
		local newSlot = template:Clone()
		newSlot.Name = itemData.Id
		newSlot.Visible = true

		newSlot.RebirthNameHolder.MainText.Text = itemData.Name
		newSlot.RebirthNameHolder.TextShadow.Text = itemData.Name
		newSlot.RebirthHolder.IconRebirth.Image = itemData.IconId
		newSlot.BottomContent.InfoDisplay.Content.TextRebirth.Text = itemData.Desc

		local buyButton = newSlot.BottomContent.BuyButton
		buyButton.MouseButton1Click:Connect(function()
			local owned = DataUtility.client.get("OwnedRebirthUpgrades") or {}
			if not table.find(owned, itemData.Id) then
				-- Efeito sonoro adicionado aqui
				SoundUtility.PlaySFX(SoundData.SFX.Buy)
				shopEvent:FireServer("Purchase", itemData.Id)
			end
		end)

		newSlot.Parent = mainContent
		createdSlots[itemData.Id] = { Slot = newSlot, Data = itemData }
	end
end

local function update_ui()
	local owned = DataUtility.client.get("OwnedRebirthUpgrades") or {}
	local currentTokens = DataUtility.client.get("RebirthTokens") or 0

	for _, slotInfo in pairs(createdSlots) do
		local slot = slotInfo.Slot
		local itemData = slotInfo.Data
		local buyButton = slot.BottomContent.BuyButton

		local btnText = buyButton:FindFirstChildWhichIsA("TextLabel")
		if not btnText and buyButton:IsA("TextButton") then
			btnText = buyButton
		end

		if btnText then
			if table.find(owned, itemData.Id) then
				btnText.Text = "OWNED"
			else
				btnText.Text = "PURCHASE (" .. itemData.Price .. " RP)"
			end
		end
	end
end

-- INIT
setup_shop()
update_ui()

DataUtility.client.bind("OwnedRebirthUpgrades", update_ui)
DataUtility.client.bind("RebirthTokens", update_ui)