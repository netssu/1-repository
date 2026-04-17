-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- CONSTANTS
local ITEM_STATS_MODULE = require(ReplicatedStorage:WaitForChild("ItemStats"))
local VIEW_PORT_MODULE = require(ReplicatedStorage.Modules:WaitForChild("ViewPortModule"))
local UI_HANDLER = require(ReplicatedStorage.Modules.Client:WaitForChild("UIHandler"))
local ZONE_MODULE = require(ReplicatedStorage.Modules:WaitForChild("Zone"))

local RARITY_COLORS = {
	["Common"] = Color3.fromRGB(175, 175, 175),
	["Uncommon"] = Color3.fromRGB(85, 255, 0),
	["Rare"] = Color3.fromRGB(0, 170, 255),
	["Epic"] = Color3.fromRGB(170, 0, 255),
	["Legendary"] = Color3.fromRGB(255, 170, 0),
	["Mythical"] = Color3.fromRGB(255, 0, 0)
}

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local BuyTravelingMerchantItemRemoteFunction = ReplicatedStorage:WaitForChild("Functions"):WaitForChild("BuyTravelingMerchantItem")
local TravelingMerchant = workspace:WaitForChild("Merchant")
local merchant_gui = TravelingMerchant:WaitForChild("Model"):WaitForChild("merchant_gui")

local NewUI = PlayerGui:WaitForChild("NewUI")
local GalacticMarketGUI = NewUI:WaitForChild("Galactic_Market")
local MainFrame = GalacticMarketGUI:WaitForChild("Main")

local TopBar = MainFrame:WaitForChild("Bar"):WaitForChild("Bar")
local TimerFill = TopBar:WaitForChild("Fill")
local TimerText = TopBar:WaitForChild("Text")
local TimerDisplay = TopBar:WaitForChild("Timer")

local ProfileFrame = MainFrame:WaitForChild("Profile")
local ProfilePlaceholder = ProfileFrame:WaitForChild("Placeholder")
local ProfileRarity = ProfileFrame:WaitForChild("Rarity")
local ProfileRarityGradient = ProfileRarity:WaitForChild("UIGradient")
local BuyButton = ProfileFrame:WaitForChild("Button"):FindFirstChild("Btn", true) 

local ProfileBg = ProfileFrame:WaitForChild("Bg")
local ProfileBgStroke1 = ProfileBg:WaitForChild("1")
local ProfileBgStroke2 = ProfileBg:WaitForChild("2")

local StockContent = MainFrame:WaitForChild("Stock"):WaitForChild("Slots"):WaitForChild("Content")
local TemplateSlot = StockContent:WaitForChild("1")
TemplateSlot.Visible = false

local selectedButton = nil
local boughtAll = false

-- FUNCTIONS
local function SetElementColor(element, color)
	if not element then return end
	if element:IsA("UIStroke") then
		element.Color = color
	elseif element:IsA("GuiObject") then
		element.BackgroundColor3 = color
	end
end

local function AddGradient(containers, rarity)
	local gradientClones = {}
	local coroutineCreated = coroutine.create(function()
		local g = ReplicatedStorage.Borders:FindFirstChild(rarity) or ReplicatedStorage.Borders.Common
		for _, c in containers do
			local gc = g:Clone()
			table.insert(gradientClones, gc)
			gc.Parent = c
			task.spawn(function()
				if rarity == "Mythical" and c:IsA("TextLabel") then
					local grad = gc
					local t = 2.8
					local range = 7
					grad.Rotation = 0

					while grad ~= nil and grad.Parent ~= nil do
						local loop = tick() % t / t
						local colors = {}
						for i = 1, range + 1, 1 do
							local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
							if loop - ((i - 1) / range) < 0 then
								z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
							end
							local d = ColorSequenceKeypoint.new((i - 1) / range, z)
							table.insert(colors, d)
						end
						grad.Color = ColorSequence.new(colors)
						task.wait()
					end
				else
					while gc ~= nil and gc.Parent ~= nil do
						gc.Rotation = (gc.Rotation + 2) % 360
						task.wait()
					end
				end
			end)
		end
	end)

	coroutine.resume(coroutineCreated)

	return {
		Destroy = function()
			coroutine.close(coroutineCreated)
			for _, gradient in gradientClones do
				gradient:Destroy()
			end
		end,
	}
end

local function UpdateProfile(visible, itemName, itemButton)
	if not visible then
		ProfileRarity.Text = "Nothing"
		ProfileFrame:WaitForChild("NameItemProfile").Text = "Select an item"
		local get = ProfilePlaceholder:FindFirstChildOfClass("ViewportFrame")
		if get then get:Destroy() end

		local defaultColor = Color3.fromRGB(255, 255, 255)
		ProfileBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		SetElementColor(ProfileBgStroke1, defaultColor)
		SetElementColor(ProfileBgStroke2, defaultColor)
		ProfileRarityGradient.Color = ColorSequence.new(defaultColor)

		return
	end

	local itemStats = ITEM_STATS_MODULE[itemName]
	if itemStats then
		local oldButton = selectedButton
		local destroyGradient = AddGradient({ProfileRarity}, itemStats.Rarity).Destroy

		ProfileRarity.Text = itemStats.Rarity
		ProfileFrame:WaitForChild("NameItemProfile").Text = itemName

		local rarityColor = RARITY_COLORS[itemStats.Rarity] or Color3.fromRGB(255, 255, 255)

		ProfileBg.BackgroundColor3 = rarityColor
		SetElementColor(ProfileBgStroke1, rarityColor)
		SetElementColor(ProfileBgStroke2, rarityColor)

		ProfileRarityGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, rarityColor)
		})

		local get = ProfilePlaceholder:FindFirstChildOfClass("ViewportFrame")
		if get then get:Destroy() end

		local vp = VIEW_PORT_MODULE.CreateViewPort(itemName, false, true)
		vp.ZIndex = 5
		vp.AnchorPoint = Vector2.new(.5, .5)
		vp.Position = UDim2.fromScale(.5, .5)
		vp.Size = UDim2.fromScale(1, 1)
		vp.Parent = ProfilePlaceholder

		task.spawn(function()
			repeat task.wait() until selectedButton == nil or selectedButton ~= oldButton
			destroyGradient()
		end)
	end
end

local function BuyItem()
	if not selectedButton then return end

	local selectedName = selectedButton.Name
	local oldButton = selectedButton
	local buyRequestIsValid, returnMessage = pcall(function()
		return BuyTravelingMerchantItemRemoteFunction:InvokeServer(selectedName)
	end)

	warn(returnMessage)

	if buyRequestIsValid and returnMessage == "Valid" then
		local instanceItem = TravelingMerchant.Items:FindFirstChild(selectedName)
		if instanceItem then
			instanceItem:Destroy()
		end
		selectedButton = nil
		oldButton.Visible = false
		UpdateProfile(false)

		if _G.Message then
			_G.Message(returnMessage, Color3.fromRGB(255, 170, 0))
		end
	else
		if _G.Message then
			_G.Message(returnMessage, Color3.fromRGB(255, 0, 0))
		end
	end
end

local function CheckAlreadyAbought()
	local playerBoughtFromTravelingMerchant = Player:FindFirstChild("BoughtFromTravelingMerchant")
	if not playerBoughtFromTravelingMerchant then return end

	local merchantLeavingTime = playerBoughtFromTravelingMerchant:FindFirstChild("MerchantLeavingTime")
	local itemsBought = playerBoughtFromTravelingMerchant:FindFirstChild("ItemsBought")

	if not merchantLeavingTime or not itemsBought or merchantLeavingTime.Value ~= TravelingMerchant.LeavingAt.Value then 
		return 
	end

	local totalBought = 0
	for _, itemValue in itemsBought:GetChildren() do
		local itemUIButton = StockContent:FindFirstChild(itemValue.Name)
		local itemObject = TravelingMerchant.Items:FindFirstChild(itemValue.Name)

		if itemUIButton then
			itemUIButton.Visible = false
		end
		if itemObject then 
			totalBought += 1 
			itemObject:Destroy() 
		end
	end

	boughtAll = (totalBought == 3)
end

local function LoadTravelingMerchantItemToFrame()
	for _, button in StockContent:GetChildren() do
		if not button:IsA("Frame") and not button:IsA("GuiButton") then continue end
		if button.Name == "1" or TravelingMerchant.Items:FindFirstChild(button.Name) then continue end
		button:Destroy()
	end

	local totalChecks = 0
	for _, item in TravelingMerchant.Items:GetChildren() do
		if StockContent:FindFirstChild(item.Name) then
			totalChecks += 1
		end
	end

	if totalChecks == #TravelingMerchant.Items:GetChildren() then return end

	for _, ui in StockContent:GetChildren() do
		if (ui:IsA("Frame") or ui:IsA("GuiButton")) and ui ~= TemplateSlot then
			ui:Destroy()
		end
	end

	for _, item in TravelingMerchant.Items:GetChildren() do
		local itemStats = ITEM_STATS_MODULE[item.Name]
		local slot = TemplateSlot:Clone()

		slot.Name = item.Name
		slot.Visible = true

		local slotPlaceholder = slot:WaitForChild("Placeholder")
		local slotBtn = slot:WaitForChild("Btn")
		local slotAmount = slot:WaitForChild("Amount")
		local slotNameItem = slot:WaitForChild("NameItem")

		local viewPort = VIEW_PORT_MODULE.CreateViewPort(item.Name)
		viewPort.ZIndex = 2
		viewPort.Parent = slotPlaceholder

		if itemStats then
			local NewAmount = tostring(itemStats.Price.Amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
			slotAmount.Text = NewAmount
			slotNameItem.Text = tostring(itemStats.Name or item.Name)
		end

		slot.Parent = StockContent

		slotBtn.MouseButton1Down:Connect(function()
			selectedButton = slot
			UpdateProfile(true, item.Name, slot)
		end)
	end
end

local function Detection()
	local isLeaving = TravelingMerchant.isOpen.Value
	local timeTarget = isLeaving and TravelingMerchant.LeavingAt.Value or TravelingMerchant.ReturnAt.Value
	local secondsDifference = timeTarget - math.floor(os.time())

	if secondsDifference < 0 then secondsDifference = 0 end

	local minutes = math.floor(secondsDifference / 60)
	local seconds = secondsDifference % 60
	local timeFormatted = string.format("%d:%02d", minutes, seconds)
	local fillScale = math.clamp(secondsDifference / 1800, 0, 1)

	-- O problema estava na verificação "GalacticMarketGUI.Enabled". Como é um frame, o correto é ".Visible".
	if GalacticMarketGUI.Visible then
		local targetColor = isLeaving and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 0, 4)

		TimerFill.Size = UDim2.fromScale(fillScale, 1)
		TimerFill.BackgroundColor3 = targetColor

		TimerText.Text = isLeaving and 'Leaving In' or 'Returning In'
		TimerDisplay.Text = timeFormatted
	end

	merchant_gui.NameGui.Enabled = true
	merchant_gui.NameGui.Frame.Time.Text = (isLeaving and "Leaving in: " or "Returning in: ") .. timeFormatted

	LoadTravelingMerchantItemToFrame()
end

-- INIT
if BuyButton then
	BuyButton.MouseButton1Down:Connect(BuyItem)
end

UpdateProfile(false)

local playerBoughtFolder = Player:WaitForChild("BoughtFromTravelingMerchant", 10)
if playerBoughtFolder then
	local itemsBoughtFolder = playerBoughtFolder:WaitForChild("ItemsBought", 10)
	if itemsBoughtFolder then
		itemsBoughtFolder.ChildAdded:Connect(CheckAlreadyAbought)
	end
end

TravelingMerchant:WaitForChild("Items").ChildAdded:Connect(CheckAlreadyAbought)
CheckAlreadyAbought()
LoadTravelingMerchantItemToFrame()

local Container = ZONE_MODULE.new(TravelingMerchant:WaitForChild('DetectionZone'))

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		if _G.CloseAll then
			_G.CloseAll("Galactic_Market")
		end
	end
end)

Container.playerExited:Connect(function(plr)
	if plr == Player then
		if _G.CloseAll then
			_G.CloseAll()
		end
	end
end)

task.spawn(function()
	while task.wait(0.1) do
		Detection()
	end
end)