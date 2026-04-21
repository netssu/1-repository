-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- CONSTANTS
local PrestigeHandling = require(ReplicatedStorage:WaitForChild("Prestige"):WaitForChild("Main"):WaitForChild("PrestigeHandling"))
local ViewPortModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ViewPortModule"))
local AllFunc = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("VFX_Helper"))

local ShopZone = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Prestige"):WaitForChild("PrestigeShop")
local PrestigeZone = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Prestige"):WaitForChild("Prestige")
local CalculateServer = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Prestige"):WaitForChild("PrestigeCalculate")
local PrestigeReset = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Prestige"):WaitForChild("PrestigeReset")

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- Valores do Player
local PrestigeValue = Player:WaitForChild("Prestige")
local LevelValue = Player:WaitForChild("PlayerLevel")
local PrestigeTokens = Player:WaitForChild("PrestigeTokens")

local PrestigeUI = PlayerGui:WaitForChild("NewUI"):WaitForChild("Prestige")

local BoostsFrame = PrestigeUI:WaitForChild("Boosts")
local XPBoost = BoostsFrame:WaitForChild("XPBoost")
local LuckBoost = BoostsFrame:WaitForChild("Luck")

local MainFrame = PrestigeUI:WaitForChild("Main")
local ContentFrame = MainFrame:WaitForChild("Content")

-- Textos Gerais e Profile
local ProfileFrame = ContentFrame:WaitForChild("Profile")
local ProfileViewportFrame = ProfileFrame:WaitForChild("Placeholder"):WaitForChild("ViewportFrame")
local TextPrestige = ProfileFrame:WaitForChild("TextPrestige")

local TextContainer = ContentFrame:WaitForChild("Text")
local TextLevel = TextContainer:WaitForChild("Level")
local TextNextLevel = MainFrame:WaitForChild("TextNextLevel")

-- Botão Principal de Prestigiar
local PrestigeButtonFrame = ContentFrame:WaitForChild("Button")
local ActualPrestigeBtn = PrestigeButtonFrame:WaitForChild("Btn")

-- Card Central (Carrossel de Prestígio)
local PrestigeCard = ContentFrame:WaitForChild("Prestige")
local CardLocked = PrestigeCard:WaitForChild("Locked")
local CardObtained = PrestigeCard:WaitForChild("Obtained")
local CardPrestigeText = PrestigeCard:WaitForChild("PrestigeText")
local ArrowLeft = PrestigeCard:WaitForChild("ArrowLeft")
local ArrowRight = PrestigeCard:WaitForChild("ArrowRight")
local SlotsFrame = PrestigeCard:WaitForChild("Slots")

local TeleportOutPS = workspace:WaitForChild("Prestige"):WaitForChild("TeleportOut")

local ViewedPrestigeTier = 1
local WasMessage = false
local MaxPrestige = 10 

local ShopGUI = PlayerGui:WaitForChild("NewUI"):WaitForChild("PrestigeShop")
local ShopMain = ShopGUI:WaitForChild("Main")

local ShopCraft = ShopMain:WaitForChild("Craft")
local ShopCurrencyLabel = ShopCraft:WaitForChild("Onhand"):WaitForChild("TextAmount")

local ShopButtonsHolder = ShopMain:WaitForChild("ItemsTab"):WaitForChild("Content")


local TeleportOutShop = workspace:WaitForChild("PrestigeShop"):WaitForChild("TeleportOut")
local Prompt = PlayerGui:WaitForChild("CoreGameUI"):WaitForChild("Prompt"):WaitForChild("Prompt")

local ShopUnit = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShopUnit")
local PrestigeTokenChanged = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Prestige"):WaitForChild("PrestigeTokenChanged")

local selectedItem = nil
local debounce = {
	TraitPoint = false,
	ExtraStorage = false,
	VIP = false,
	["2x Speed"] = false,
	LuckySpins = false,
	["Display 3 Units"] = false,
	["3x Speed"] = false,
	LuckyWillpower = false,
	["Robux Unit"] = false,
	["Robux Unit (Shiny)"] = false,
}


-- FUNCTIONS
local function UpdateProfileViewport()
	for _, child in pairs(ProfileViewportFrame:GetChildren()) do
		if not child:IsA("UIAspectRatioConstraint") then
			child:Destroy()
		end
	end

	Character.Archivable = true
	local charClone = Character:Clone()
	Character.Archivable = false

	if charClone then
		charClone.Parent = ProfileViewportFrame

		if charClone.PrimaryPart then
			charClone:SetPrimaryPartCFrame(CFrame.new(0, 0, 0))
		end

		local camera = Instance.new("Camera")
		local head = charClone:FindFirstChild("Head")

		if head then
			camera.CFrame = CFrame.new(head.Position + (head.CFrame.LookVector * 2.2) + Vector3.new(0, 0.2, 0), head.Position)
			camera.FieldOfView = 50 
		end

		ProfileViewportFrame.CurrentCamera = camera
		camera.Parent = ProfileViewportFrame
	end
end

local function UpdateSlots(tier)
	for _, child in pairs(SlotsFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "1" then
			child:Destroy()
		end
	end

	local template = SlotsFrame:FindFirstChild("1")
	if template then template.Visible = false end

	local rewardsForThisTier = {
		{
			Name = "Prestige Tokens", 
			Amount = tier, 
			isModel = false, 
			iconID = "rbxassetid://0" 
		}
	}

	for index, reward in ipairs(rewardsForThisTier) do
		local newSlot = template:Clone()
		newSlot.Name = "Reward_" .. index
		newSlot.Visible = true

		newSlot.Amount.Text = "x" .. tostring(reward.Amount)
		newSlot.NameReward.Text = reward.Name

		local vpFrame = newSlot:FindFirstChild("Placeholder"):FindFirstChild("ViewportFrame")
		local placeholderImg = newSlot:FindFirstChild("Placeholder"):FindFirstChild("Placeholder")

		if reward.isModel then
			placeholderImg.Visible = false
			vpFrame.Visible = true

			local viewport = ViewPortModule.CreateViewPort(reward.modelName)
			viewport.Parent = vpFrame
			viewport.Size = UDim2.new(1, 0, 1, 0)
		else
			vpFrame.Visible = false
			placeholderImg.Visible = true
			if reward.iconID ~= "rbxassetid://0" then
				placeholderImg.Image = reward.iconID
			end
		end

		newSlot.Parent = SlotsFrame
	end
end

local function UpdatePrestigeCard()
	CardPrestigeText.Text = "Prestige " .. tostring(ViewedPrestigeTier)

	if ViewedPrestigeTier <= PrestigeValue.Value then
		CardObtained.Visible = true
		CardLocked.Visible = false
	elseif ViewedPrestigeTier == PrestigeValue.Value + 1 then
		CardObtained.Visible = false
		CardLocked.Visible = false
	else
		CardObtained.Visible = false
		CardLocked.Visible = true
	end

	UpdateSlots(ViewedPrestigeTier)
end

local function UpdateMainUI()
	local currentPr = PrestigeValue.Value
	local currentLvl = LevelValue.Value
	local requiredLvl = PrestigeHandling.PrestigeRequirements[currentPr + 1]

	TextPrestige.Text = "Prestige " .. tostring(currentPr)
	TextLevel.Text = "Level: " .. tostring(currentLvl) 

	local XPBoostValue = currentPr * 10 
	XPBoost.Text = "XP : " .. tostring(XPBoostValue) .. "%"

	local LuckBoostValue = currentPr * 1.6
	LuckBoost.Text = string.format("Luck : %.1f%%", LuckBoostValue)

	if requiredLvl then
		TextNextLevel.Text = "Reach Player Level " .. tostring(requiredLvl) .. " to Prestige"

		if currentLvl >= requiredLvl then
			PrestigeButtonFrame.Visible = true
		else
			PrestigeButtonFrame.Visible = false
		end
	else
		TextNextLevel.Text = "Max Prestige Reached!"
		PrestigeButtonFrame.Visible = false
	end

	UpdateProfileViewport()
end

-- ==========================================
-- FUNÇÕES DO PRESTIGE SHOP
-- ==========================================
local function SetupShopViewPorts()
	local viewData = {
		["Dart Wader Maskless"] = ShopButtonsHolder:WaitForChild("Robux Unit"),	
	}

	local ViewExtraData = {
		["Dart Wader Maskless"] = ShopButtonsHolder:WaitForChild("Robux Unit (Shiny)")
	}

	-- Na nova UI, as imagens estão dentro de Placeholder -> Icon
	ShopButtonsHolder:WaitForChild("Robux Unit"):WaitForChild("Placeholder"):WaitForChild("Icon").Image = ""
	ShopButtonsHolder:WaitForChild("Robux Unit (Shiny)"):WaitForChild("Placeholder"):WaitForChild("Icon").Image = ""

	for itemName, iconFrame in pairs(viewData) do
		local vpFrame = iconFrame:WaitForChild("Placeholder"):WaitForChild("ViewportFrame")
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = vpFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end

	for itemName, iconFrame in pairs(ViewExtraData) do
		local vpFrame = iconFrame:WaitForChild("Placeholder"):WaitForChild("ViewportFrame")
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = vpFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end
end

local function ShopGiver(Type, Name, Quantity)
	if Type == false and Name == false and Quantity == false then
		_G.Message("Error when purchasing", Color3.new(1, 0.0941176, 0.0941176))
		return
	end

	if Type == "Gamepass" and Name == false and Quantity == false then
		_G.Message("You already own the gamepass", Color3.new(1, 0.0941176, 0.0941176))
		return
	end

	if (Type == "Currency" or Type == "Item" or Type == "Gamepass" or Type == "Unit") then
		_G.Message(tostring(Quantity) .. " x " .. Name.Name .. " Earned!", Color3.new(0, 1, 0), "Success")
	end
end

local function HandleButton(itemName)
	if debounce[itemName] then return end
	debounce[itemName] = true

	selectedItem = itemName
	Prompt.Visible = true

	task.wait(1)
	debounce[itemName] = false
end

-- Função auxiliar para conectar os botões do Shop, já que agora eles têm um "Btn" dentro
local function ConnectShopItem(frameName, itemDataName)
	local frame = ShopButtonsHolder:FindFirstChild(frameName)
	if frame then
		local btn = frame:FindFirstChild("Btn")
		if btn then
			btn.Activated:Connect(function() HandleButton(itemDataName) end)
		end
	end
end


-- INIT
Player.CharacterAdded:Connect(function(char)
	Character = char
	HumanoidRootPart = char:WaitForChild("HumanoidRootPart")
end)

-- ==========================================
-- INIT DO PRESTIGE SHOP
-- ==========================================
Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedItem then
		Prompt.Visible = false
		ShopUnit:FireServer(selectedItem)
		selectedItem = nil
	end
end)

Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedItem = nil
end)

ShopZone.Event:Connect(function(vision)
	SetupShopViewPorts()
	ShopGUI.Visible = vision

	local currency = Player:FindFirstChild("PrestigeTokens")
	PrestigeHandling.CalculatePrestigeCurrency(ShopCurrencyLabel, currency.Value)

	-- Conectando os botões com base nos nomes da nova imagem
	ConnectShopItem("LuckySummons", "LuckySpins")
	ConnectShopItem("Display", "Display 3 Units")
	ConnectShopItem("Storage", "Extra Storage")
	ConnectShopItem("Vip", "VIP")
	ConnectShopItem("2X", "2x Speed")
	ConnectShopItem("Traits", "TraitPoint")
	ConnectShopItem("3x Speed", "3x Speed")
	ConnectShopItem("LuckyWillpower", "LuckyWillpower")
	ConnectShopItem("Robux Unit", "Dart Wader Maskless")
	ConnectShopItem("Robux Unit (Shiny)", "Shiny Dart Wader Maskless")

	currency:GetPropertyChangedSignal("Value"):Connect(function()
		PrestigeTokenChanged:FireServer(Player)
		PrestigeTokenChanged.OnClientEvent:Connect(function(value)
			ShopCurrencyLabel.Text = value
		end)
	end)
end)

ShopUnit.OnClientEvent:Connect(function(Type, Name, Quantity)
	ShopGiver(Type, Name, Quantity)
end)

if ShopX then
	ShopX.Activated:Connect(function()
		if Character and Character.PrimaryPart then
			Character:PivotTo(TeleportOutShop.CFrame)
		end
		ShopGUI.Visible = false
	end)
end

PrestigeZone.Event:Connect(function(vision)
	if vision then
		_G.CloseAll('Prestige')
		PrestigeUI.Visible = true

		ViewedPrestigeTier = PrestigeValue.Value + 1
		if ViewedPrestigeTier == 0 or ViewedPrestigeTier > MaxPrestige then 
			ViewedPrestigeTier = math.clamp(ViewedPrestigeTier, 1, MaxPrestige)
		end

		UpdateMainUI()
		UpdatePrestigeCard()
	else
		_G.CloseAll()
		PrestigeUI.Visible = false
	end
end)

ArrowLeft.Activated:Connect(function()
	if ViewedPrestigeTier > 1 then
		ViewedPrestigeTier -= 1
		UpdatePrestigeCard()
	end
end)

ArrowRight.Activated:Connect(function()
	if ViewedPrestigeTier < MaxPrestige then
		ViewedPrestigeTier += 1
		UpdatePrestigeCard()
	end
end)

ActualPrestigeBtn.Activated:Connect(function()
	if not PrestigeButtonFrame.Visible then return end 

	local hasUnitsEquipped = AllFunc.HaveEquipUnits(Player)

	if not hasUnitsEquipped then
		CalculateServer:FireServer(Player)
	else
		if not WasMessage then
			WasMessage = true
			task.spawn(function()
				task.wait(1)
				WasMessage = false
			end)
			_G.Message("Must Have All Your Units Unequipped", Color3.new(1, 0, 0))
		end
	end
end)


PrestigeValue:GetPropertyChangedSignal("Value"):Connect(function()
	PrestigeReset:FireServer(Player)
	task.wait(0.1)
	PrestigeUI.Visible = false

	if Character and Character.PrimaryPart then
		Character:PivotTo(TeleportOutPS.CFrame)
	end

	UpdateMainUI()
end)