-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- CONSTANTS
local RARITY_PRIORITY = {
	["Rare"] = 1,
	["Epic"] = 2,
	["Legendary"] = 3,
	["Mythical"] = 4,
	["Secret"] = 5,
	["Exclusive"] = 6,
}

local RARITY_COLORS = {
	["Rare"] = { Bg = Color3.fromRGB(41, 128, 255), L1 = Color3.fromRGB(25, 90, 200), L2 = Color3.fromRGB(60, 150, 255), L3 = Color3.fromRGB(90, 180, 255), Lines = Color3.fromRGB(120, 200, 255) },
	["Epic"] = { Bg = Color3.fromRGB(140, 40, 255), L1 = Color3.fromRGB(100, 25, 200), L2 = Color3.fromRGB(160, 70, 255), L3 = Color3.fromRGB(180, 100, 255), Lines = Color3.fromRGB(210, 140, 255) },
	["Legendary"] = { Bg = Color3.fromRGB(255, 170, 0), L1 = Color3.fromRGB(200, 120, 0), L2 = Color3.fromRGB(255, 190, 40), L3 = Color3.fromRGB(255, 210, 80), Lines = Color3.fromRGB(255, 230, 140) },
	["Mythical"] = { Bg = Color3.fromRGB(255, 40, 40), L1 = Color3.fromRGB(180, 20, 20), L2 = Color3.fromRGB(255, 70, 70), L3 = Color3.fromRGB(255, 100, 100), Lines = Color3.fromRGB(255, 140, 140) },
	["Secret"] = { Bg = Color3.fromRGB(30, 30, 30), L1 = Color3.fromRGB(15, 15, 15), L2 = Color3.fromRGB(50, 50, 50), L3 = Color3.fromRGB(70, 70, 70), Lines = Color3.fromRGB(100, 100, 100) },
	["Exclusive"] = { Bg = Color3.fromRGB(255, 105, 180), L1 = Color3.fromRGB(200, 70, 140), L2 = Color3.fromRGB(255, 130, 195), L3 = Color3.fromRGB(255, 155, 210), Lines = Color3.fromRGB(255, 180, 225) }
}

-- VARIABLES
local Player = Players.LocalPlayer
repeat task.wait() until Player:FindFirstChild("DataLoaded")

local RS = ReplicatedStorage
local Events = RS:WaitForChild("Events")
local IndexClaim = Events:WaitForChild("IndexClaim")

local Upgrades = require(RS.Upgrades)
local ViewPort = require(RS.Modules.ViewPortModule)
local GradientsModule = require(RS.Modules.GradientsModule)
local ButtonAnimation = require(RS.Modules.ButtonAnimation)
local UiHandler = require(RS.Modules.Client.UIHandler)
local InfoModule = require(RS.Modules.SellAndFuse).RarityRewards
local Zone = require(RS.Modules.Zone)

local PlayerGui = Player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local IndexFrame = NewUI:WaitForChild("IndexFrame")
local Main = IndexFrame:WaitForChild("Main")
local ItemsTab = Main:WaitForChild("ItemsTab")
local Content = ItemsTab:WaitForChild("Content")
local Craft = Main:WaitForChild("Craft")
local GeneralClaimButton = nil

local TemplateUnit = Content:WaitForChild("1")
local UnitsIndex = Player:WaitForChild("Index"):WaitForChild("Units Index")
local Container = Zone.new(workspace:WaitForChild('IndexBox'):WaitForChild('IndexHitbox'))

local Clicked = false
local allUnitTable = {}
local unitIndexConnections = {}
local slotTemplateFallbacks = {
	Secret = "Mythical",
	Unique = "Mythical",
	Exclusive = "Mythical",
}
local cachedSlotTemplates

-- FUNCTIONS
local function ApplyRarityTheme(bgFrame, rarity)
	local theme = RARITY_COLORS[rarity] or RARITY_COLORS["Rare"]
	if bgFrame then
		bgFrame.BackgroundColor3 = theme.Bg

		local child1 = bgFrame:FindFirstChild("1")
		if child1 then
			if child1:IsA("UIStroke") then child1.Color = theme.L1 else child1.BackgroundColor3 = theme.L1 end
		end

		local child2 = bgFrame:FindFirstChild("2")
		if child2 then
			if child2:IsA("UIStroke") then child2.Color = theme.L2 else child2.BackgroundColor3 = theme.L2 end
		end

		local child3 = bgFrame:FindFirstChild("3")
		if child3 then
			if child3:IsA("UIStroke") then child3.Color = theme.L3 else child3.BackgroundColor3 = theme.L3 end
		end

		local lines = bgFrame:FindFirstChild("Lines")
		if lines and lines:IsA("ImageLabel") then
			lines.ImageColor3 = theme.Lines
		end
	end
end

local function getSlotTemplatesContainer()
	if cachedSlotTemplates and cachedSlotTemplates.Parent then
		return cachedSlotTemplates
	end

	local templatesRoot = RS:FindFirstChild("Templates")
	cachedSlotTemplates = templatesRoot and templatesRoot:FindFirstChild("Slots")
	return cachedSlotTemplates
end

local function getSlotTemplateForRarity(rarity)
	local slotTemplates = getSlotTemplatesContainer()
	if not slotTemplates then
		return nil
	end

	local template = rarity and slotTemplates:FindFirstChild(rarity)
	if template then
		return template
	end

	local fallbackRarity = slotTemplateFallbacks[rarity]
	return fallbackRarity and slotTemplates:FindFirstChild(fallbackRarity) or nil
end

local function applySlotTemplateBackground(target, rarity)
	if not target then
		return false
	end

	local template = getSlotTemplateForRarity(rarity)
	local templateBackground = template and template:FindFirstChild("Bg")
	if not (templateBackground and templateBackground:IsA("GuiObject")) then
		return false
	end

	local currentBackground = target:FindFirstChild("Bg")
	if currentBackground then
		currentBackground:Destroy()
	end

	local backgroundClone = templateBackground:Clone()
	backgroundClone.Name = "Bg"
	backgroundClone.Parent = target
	return true
end

local function PlayerOwnedUnits()
	local folder = Player:WaitForChild("Index"):WaitForChild("Units Index")
	if not folder then return 0 end
	local PlayerHas = {}

	for _, unit in folder:GetChildren() do
		if not table.find(PlayerHas, unit.Name) then
			table.insert(PlayerHas, unit.Name)
		end
	end
	return #PlayerHas
end

local function setVisibleIfPresent(instance, visible)
	if instance and instance:IsA("GuiObject") then
		instance.Visible = visible
	end
end

local function findFirstGuiButton(root)
	if not root then
		return nil
	end

	if root:IsA("GuiButton") then
		return root
	end

	local preferredButton = root:FindFirstChild("Btn")
		or root:FindFirstChild("Button")

	if preferredButton and preferredButton:IsA("GuiButton") then
		return preferredButton
	end

	return root:FindFirstChildWhichIsA("GuiButton", true)
end

local function applyViewportState(viewport, isRevealed)
	if not viewport then
		return
	end

	if isRevealed then
		viewport.Ambient = Color3.new(0.784314, 0.784314, 0.784314)
		viewport.LightColor = Color3.new(0.54902, 0.54902, 0.54902)
		viewport.ImageColor3 = Color3.new(1, 1, 1)
		return
	end

	viewport.Ambient = Color3.new(0, 0, 0)
	viewport.LightColor = Color3.new(0, 0, 0)
	viewport.ImageColor3 = Color3.new(0, 0, 0)
end

local function Update()
	for _, unitFrame in Content:GetChildren() do
		if unitFrame:IsA("Frame") and unitFrame.Name ~= "1" and unitFrame.Name ~= "UIGridLayout" then
			local unitName = unitFrame.Name
			local rarity = Upgrades[unitName].Rarity

			-- AQUI ESTÁ A CORREÇÃO: Busca exatamente o Viewport correto pelo nome do personagem
			local placeholder = unitFrame:FindFirstChild("Placeholder")
			local vp = placeholder and placeholder:FindFirstChild(unitName)
			local unitData = UnitsIndex:FindFirstChild(unitName)

			local btn = unitFrame:FindFirstChild("Btn")
			local icon = unitFrame:FindFirstChild("Icon")
			local amount = unitFrame:FindFirstChild("Amount")
			local claim = unitFrame:FindFirstChild("Claim")

			if amount then
				amount.Text = InfoModule[rarity]
			end

			if unitData then
				if unitData.Value == false then
					-- ESTADO 2: Desbloqueado mas NÃO coletou (Mostra botão e ESBOÇO PRETO)
					setVisibleIfPresent(btn, true)
					setVisibleIfPresent(icon, true)
					setVisibleIfPresent(amount, true)
					setVisibleIfPresent(claim, true)
					applyViewportState(vp, false)
				else
					-- ESTADO 3: Desbloqueado e JÁ coletou (Esconde botão e mostra NORMAL)
					setVisibleIfPresent(btn, false)
					setVisibleIfPresent(icon, false)
					setVisibleIfPresent(amount, false)
					setVisibleIfPresent(claim, false)
					applyViewportState(vp, true)
				end
			else
				-- ESTADO 1: Não possui o personagem (Esconde botão e mostra ESBOÇO PRETO)
				setVisibleIfPresent(btn, false)
				setVisibleIfPresent(icon, false)
				setVisibleIfPresent(amount, false)
				setVisibleIfPresent(claim, false)
				applyViewportState(vp, false)
			end
		end
	end
end

local function ShowUnit(UnitName)
	local rarity = Upgrades[UnitName].Rarity

	local oldVp = Craft.Placeholder:FindFirstChildOfClass("ViewportFrame")
	if oldVp then
		if oldVp.Name == UnitName then return end
		oldVp:Destroy()
	end

	ApplyRarityTheme(Craft.Bg, rarity)

	local Vp = ViewPort.CreateViewPort(UnitName)
	if Vp then
		Vp.Name = UnitName
		Vp.ZIndex = 7
		Vp.Parent = Craft.Placeholder

		local Model = Vp:FindFirstChildOfClass("WorldModel") and Vp:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
		if Model then
			local part = Model:FindFirstChild("HumanoidRootPart") or Model.PrimaryPart
			if part and not Model:GetAttribute('CFrame') then 
				part.CFrame = CFrame.new(0, 0, -2.25) * CFrame.Angles(0, math.rad(-180), 0)
			end
		end

		local unitData = UnitsIndex:FindFirstChild(UnitName)

		if unitData then
			if unitData.Value == false then
				-- ESTADO 2: Desbloqueado mas NÃO coletou (ESBOÇO PRETO)
				applyViewportState(Vp, false)
			else
				-- ESTADO 3: Desbloqueado e JÁ coletou (NORMAL)
				applyViewportState(Vp, true)
			end
		else
			-- ESTADO 1: Não possui o personagem (ESBOÇO PRETO)
			applyViewportState(Vp, false)
		end
	end
end

local function bindUnitIndexValue(unitValue)
	if not unitValue or not unitValue:IsA("BoolValue") or unitIndexConnections[unitValue] then
		return
	end

	unitIndexConnections[unitValue] = unitValue:GetPropertyChangedSignal("Value"):Connect(Update)
end

local function refreshSelectedUnitPreview()
	local selectedViewport = Craft.Placeholder:FindFirstChildOfClass("ViewportFrame")
	if not selectedViewport then
		return
	end

	local unitData = UnitsIndex:FindFirstChild(selectedViewport.Name)
	applyViewportState(selectedViewport, unitData and unitData.Value == true)
end

local function claimUnit(unitName)
	if Clicked then
		return
	end

	local unitData = UnitsIndex:FindFirstChild(unitName)
	if not unitData or unitData.Value == true then
		ShowUnit(unitName)
		return
	end

	Clicked = true
	task.delay(0.5, function()
		Clicked = false
	end)

	IndexClaim:FireServer(unitName)
	task.wait(0.1)
	Update()
	refreshSelectedUnitPreview()
end

GeneralClaimButton = findFirstGuiButton(
	IndexFrame:FindFirstChild("Button")
	or IndexFrame:FindFirstChild("ClaimButton")
)

if not GeneralClaimButton then
	warn("[Index] General claim button not found under IndexFrame")
end

-- INIT
TemplateUnit.Visible = false

for Name, Stats in Upgrades do
	if not table.find(allUnitTable, Name) then
		table.insert(allUnitTable, Name)
	end
end

table.sort(allUnitTable, function(a, b)
	if not Upgrades[a] or not Upgrades[b] then return false end
	if not RARITY_PRIORITY[Upgrades[a].Rarity] or not RARITY_PRIORITY[Upgrades[b].Rarity] then return false end
	return RARITY_PRIORITY[Upgrades[a].Rarity] < RARITY_PRIORITY[Upgrades[b].Rarity]
end)

for index, UnitName in allUnitTable do
	local rarity = Upgrades[UnitName].Rarity

	local Template = TemplateUnit:Clone()
	Template.Name = UnitName
	Template.LayoutOrder = index
	Template.Visible = true
	Template.Parent = Content

	local function handleUnitSelection()
		ShowUnit(UnitName)
	end

	local function handleUnitClaim()
		claimUnit(UnitName)
	end

	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.fromScale(1, 1)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.ZIndex = 1
	clickButton.Parent = Template:FindFirstChild("Placeholder") or Template

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = clickButton

	ButtonAnimation.unitButtonAnimation(clickButton)

	clickButton.Activated:Connect(handleUnitSelection)

	local unitButton = findFirstGuiButton(
		Template:FindFirstChild("Button")
		or Template:FindFirstChild("Btn")
	)
	if unitButton and unitButton:IsA("GuiButton") then
		if not unitButton:FindFirstChildOfClass("UIScale") then
			Instance.new("UIScale").Parent = unitButton
		end

		ButtonAnimation.unitButtonAnimation(unitButton)
		unitButton.Activated:Connect(handleUnitClaim)
	end

	local Vp = ViewPort.CreateViewPort(UnitName)
	if Vp then
		Vp.Name = UnitName
		Vp.ZIndex = 7
		Vp.Parent = Template.Placeholder

		if Template.Placeholder:FindFirstChild("Placeholder") then
			Template.Placeholder.Placeholder.Visible = false
		end
	end

	if not applySlotTemplateBackground(Template, rarity) then
		ApplyRarityTheme(Template.Bg, rarity)
	end
end

Update()

for _, unitValue in UnitsIndex:GetChildren() do
	bindUnitIndexValue(unitValue)
end

UnitsIndex.ChildAdded:Connect(function(unitValue)
	bindUnitIndexValue(unitValue)
	Update()
end)

UnitsIndex.ChildRemoved:Connect(function(unitValue)
	local connection = unitIndexConnections[unitValue]
	if connection then
		connection:Disconnect()
		unitIndexConnections[unitValue] = nil
	end

	Update()
end)

if GeneralClaimButton then
	GeneralClaimButton.Activated:Connect(function()
		if not Clicked then
			Clicked = true
			task.delay(1, function() Clicked = false end)

			local CanClaim = false
			for _, Unit in UnitsIndex:GetChildren() do
				if Unit.Value == false then
					CanClaim = true
					break
				end
			end

			if CanClaim then
				IndexClaim:FireServer()
				task.wait(0.1)
				Update()
				refreshSelectedUnitPreview()
			else
				_G.Message("No unclaimed unit rewards remaining", Color3.new(1, 0, 0), nil, "Error")
			end
		end
	end)
end

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		UiHandler.DisableAllButtons()
		_G.CloseAll("IndexFrame")
	end
end)

Container.playerExited:Connect(function(plr)
	if plr == Player then
		_G.CloseAll()
		UiHandler.EnableAllButtons()
	end
end)
