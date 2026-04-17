local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
repeat task.wait() until LocalPlayer:FindFirstChild("DataLoaded")

local FunctionsFolder = ReplicatedStorage:WaitForChild("Functions")
local GetMarketInfoByName = FunctionsFolder:WaitForChild("GetMarketInfoByName")
local GlobalFunctions = require(ReplicatedStorage.Modules.GlobalFunctions)
local UtilityFunctions = require(ReplicatedStorage.Modules.Functions)

local BuyEvent = ReplicatedStorage.Events.Buy

local UI = script.Parent
local GiftFolder = UI.Parent.Gift
local GiftFrame = GiftFolder.GiftFrame
local ShopFrame = UI.ShopFrame
local Container = ShopFrame.Contents.Contents

local SelectedGiftId = GiftFolder:WaitForChild("SelectedGiftId")

-- Updates purchase UI and gifting
local function SetupPassFrame(frame)
	local contents = frame.Contents
	local buyBtn, giftBtn, icon = contents.Buy, contents.Gift, contents.Icon
	local label = buyBtn.Contents.TextLabel

	local info = GetMarketInfoByName:InvokeServer(frame.Name)
	if not info then return warn(`[Shop UI] No market info for {frame.Name}`) end

	-- Handle owned gamepasses
	local ownedFlag = LocalPlayer.OwnGamePasses:FindFirstChild(frame.Name)
	if ownedFlag then
		local function update()
			if ownedFlag.Value then
				label.Text = "Owned"
			end
		end
		ownedFlag:GetPropertyChangedSignal("Value"):Connect(update)
		update()
	end

	-- Purchase logic
	buyBtn.MouseButton1Down:Connect(function()
		if info.OneTimePurchase and ownedFlag and ownedFlag.Value then return end
		BuyEvent:FireServer(info.Id)
	end)

	-- Gift logic
	giftBtn.MouseButton1Down:Connect(function()
		SelectedGiftId.Value = info.GiftId
		GiftFrame.Visible = true
	end)

	-- Fetch and show price
	task.spawn(function()
		local success, result = pcall(function()
			return MarketplaceService:GetProductInfo(
				info.Id,
				info.IsGamepass and Enum.InfoType.GamePass or Enum.InfoType.Product
			)
		end)
		if success and result and result.PriceInRobux then
			label.Text = `\u{E002}{UtilityFunctions.addCommas(result.PriceInRobux)}`
		end
	end)

	-- Add UI tags
	buyBtn:AddTag("Shine")
	giftBtn:AddTag("Shine")
	icon:AddTag("Bob")
	icon:AddTag("Scaling")
end

-- Close UI
ShopFrame.Main.X_Close.Activated:Connect(function()
	_G.CloseAll()
end)

-- Init all shop frames
for _, element in Container:GetDescendants() do
	if element:FindFirstChild("Buy") and element:FindFirstChild("Gift") then
		SetupPassFrame(element.Parent)
	end
end

-- Animation Handlers
local function Animate(tag, fn)
	CollectionService:GetInstanceAddedSignal(tag):Connect(fn)
	for _, obj in CollectionService:GetTagged(tag) do
		task.spawn(fn, obj)
	end
end

