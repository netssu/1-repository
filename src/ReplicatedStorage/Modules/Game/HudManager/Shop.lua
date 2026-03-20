------------------//SERVICES
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

------------------//CONSTANTS
local SHINE_ROTATION_SPEED = 15

------------------//VARIABLES
local ShopController = {}
local localPlayer = Players.LocalPlayer

local ProductsData = require(
	ReplicatedStorage:WaitForChild("Modules")
		:WaitForChild("Datas")
		:WaitForChild("ProductsData")
)

local NotificationUtility = require(
	ReplicatedStorage:WaitForChild("Modules")
		:WaitForChild("Utility")
		:WaitForChild("NotificationUtility")
)

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local actionRemote = remotesFolder:FindFirstChild("ActionRemote")

local pendingPurchases = {}
local shineConnections = {}

------------------//FUNCTIONS
local function get_shop_frame()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then
		return nil
	end

	local gui = playerGui:WaitForChild("GUI", 10)
	if not gui then
		return nil
	end

	local shopFrame = gui:FindFirstChild("Shop", true)

	return shopFrame
end

local function try_auto_equip_pogo(productKey: string, productType: string)
	if not actionRemote then return end

	-- Check if this product corresponds to a pogo by looking for a PogoId in the product data
	local productData
	if productType == "DeveloperProduct" then
		productData = ProductsData.DeveloperProducts[productKey]
	elseif productType == "Gamepass" then
		productData = ProductsData.Gamepasses[productKey]
	end

	if not productData then return end

	-- Try multiple ways to find the pogo ID from product data
	local pogoId = productData.PogoId or productData.pogoId or productData.RewardId or productData.rewardId

	-- Fallback: if the productKey itself is the pogo ID
	if not pogoId and productData.Category == "Pogo" or productData.category == "Pogo" then
		pogoId = productKey
	end

	-- If we still don't have a pogoId, try using the productKey directly
	-- (common pattern: productKey matches the pogo ID)
	if not pogoId then
		pogoId = productKey
	end

	if pogoId then
		-- Small delay to let the server process the purchase and grant the pogo first
		task.delay(0.5, function()
			if actionRemote then
				actionRemote:FireServer("Pogos", "Select", pogoId)
			end
		end)
	end
end

local function prompt_purchase(productId: number, productType: string, productName: string, productKey: string)
	pendingPurchases[productId] = {
		productType = productType,
		productName = productName,
		productKey = productKey,
		timestamp = tick()
	}

	if productType == "DeveloperProduct" then
		MarketplaceService:PromptProductPurchase(localPlayer, productId)
	elseif productType == "Gamepass" then
		MarketplaceService:PromptGamePassPurchase(localPlayer, productId)
	else
		pendingPurchases[productId] = nil
	end
end

local function on_product_purchase_finished(player: Player, productId: number, wasPurchased: boolean)
	if player ~= localPlayer then return end

	local purchaseData = pendingPurchases[productId]
	if not purchaseData then return end

	if wasPurchased then
		NotificationUtility:Show({
			message = "🎉 " .. purchaseData.productName .. " purchased successfully!",
			type = "success",
			duration = 4,
			sound = true
		})

		try_auto_equip_pogo(purchaseData.productKey, purchaseData.productType)
	end

	pendingPurchases[productId] = nil
end

local function on_gamepass_purchase_finished(player: Player, gamepassId: number, wasPurchased: boolean)
	if player ~= localPlayer then return end

	local purchaseData = pendingPurchases[gamepassId]
	if not purchaseData then return end

	if wasPurchased then
		NotificationUtility:Show({
			message = "🎉 " .. purchaseData.productName .. " purchased successfully!",
			type = "success",
			duration = 4,
			sound = true
		})

		try_auto_equip_pogo(purchaseData.productKey, purchaseData.productType)
	end

	pendingPurchases[gamepassId] = nil
end

local function setup_buy_button(button: GuiButton)
	local productKey = button:GetAttribute("ProductKey")
	local productType = button:GetAttribute("ProductType")

	if not productKey or not productType then
		return
	end

	local productData
	local productId

	if productType == "DeveloperProduct" then
		productData = ProductsData.DeveloperProducts[productKey]
		if productData then
			productId = productData.ProductId
		end
	elseif productType == "Gamepass" then
		productData = ProductsData.Gamepasses[productKey]
		if productData then
			productId = productData.GamepassId
		end
	end

	if not productData or not productId then
		return
	end

	button.Activated:Connect(function()
		prompt_purchase(productId, productType, productData.Name or productKey, productKey)
	end)
end

local function setup_shine_animations(shopFrame: Frame)
	for _, conn in ipairs(shineConnections) do
		conn:Disconnect()
	end
	shineConnections = {}

	local shines = {}

	for _, descendant in ipairs(shopFrame:GetDescendants()) do
		if descendant:IsA("ImageLabel") and descendant.Name == "Shine" then
			table.insert(shines, descendant)

			local parent = descendant.Parent
			if parent and parent.Name == "MainContent" and parent:IsA("GuiObject") then
				parent.ClipsDescendants = true
			end
		end
	end

	if #shines == 0 then
		return
	end

	local conn = RunService.Heartbeat:Connect(function(dt)
		for _, shine in ipairs(shines) do
			if shine and shine.Parent then
				shine.Rotation = shine.Rotation + SHINE_ROTATION_SPEED * dt
			end
		end
	end)

	table.insert(shineConnections, conn)
end

local function setup_selector(shopFrame: Frame)
	local mainContent = shopFrame:FindFirstChild("MainContent")
	if not mainContent then
		return
	end

	local selector = mainContent:FindFirstChild("Selector")
	if not selector then
		return
	end

	local content = mainContent:FindFirstChild("Content")
	if not content then
		return
	end

	local categoryFrames: { [string]: Frame } = {}
	for _, child in ipairs(content:GetChildren()) do
		if child:IsA("Frame") then
			categoryFrames[child.Name] = child
			child.Visible = false
		end
	end

	local function show_category(targetName: string)
		for name, frame in pairs(categoryFrames) do
			frame.Visible = (name == targetName)
		end
	end

	local defaultCategory = categoryFrames["NormalPurchases"] and "NormalPurchases"
	if not defaultCategory then
		for name in pairs(categoryFrames) do
			defaultCategory = name
			break
		end
	end

	if defaultCategory then
		show_category(defaultCategory)
	end

	for _, button in ipairs(selector:GetDescendants()) do
		if button:IsA("GuiButton") then
			local targetFrame = categoryFrames[button.Name]
			if targetFrame then
				button.Activated:Connect(function()
					show_category(button.Name)
				end)
			end
		end
	end
end

local function setup_all_buy_buttons(shopFrame: Frame)
	local count = 0
	for _, descendant in ipairs(shopFrame:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Name == "BuyButton" then
			setup_buy_button(descendant)
			count += 1
		end
	end
end

local function initialize_shop()
	local shopFrame = get_shop_frame()
	if not shopFrame then return end

	setup_all_buy_buttons(shopFrame)
	setup_shine_animations(shopFrame)
	setup_selector(shopFrame)
end

------------------//INIT
MarketplaceService.PromptProductPurchaseFinished:Connect(on_product_purchase_finished)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(on_gamepass_purchase_finished)

task.spawn(function()
	initialize_shop()
end)

return ShopController