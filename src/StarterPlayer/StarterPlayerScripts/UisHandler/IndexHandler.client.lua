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
	["Rare"] = { Bg = Color3.fromRGB(30, 80, 160), L1 = Color3.fromRGB(50, 100, 180), L2 = Color3.fromRGB(70, 120, 200), L3 = Color3.fromRGB(90, 140, 220) },
	["Epic"] = { Bg = Color3.fromRGB(120, 40, 160), L1 = Color3.fromRGB(140, 60, 180), L2 = Color3.fromRGB(160, 80, 200), L3 = Color3.fromRGB(180, 100, 220) },
	["Legendary"] = { Bg = Color3.fromRGB(200, 120, 20), L1 = Color3.fromRGB(220, 140, 40), L2 = Color3.fromRGB(240, 160, 60), L3 = Color3.fromRGB(255, 180, 80) },
	["Mythical"] = { Bg = Color3.fromRGB(180, 30, 30), L1 = Color3.fromRGB(200, 50, 50), L2 = Color3.fromRGB(220, 70, 70), L3 = Color3.fromRGB(240, 90, 90) },
	["Secret"] = { Bg = Color3.fromRGB(20, 20, 20), L1 = Color3.fromRGB(50, 50, 50), L2 = Color3.fromRGB(80, 80, 80), L3 = Color3.fromRGB(110, 110, 110) },
	["Exclusive"] = { Bg = Color3.fromRGB(255, 105, 180), L1 = Color3.fromRGB(255, 130, 195), L2 = Color3.fromRGB(255, 155, 210), L3 = Color3.fromRGB(255, 180, 225) }
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

-- Referências da nova UI
local PlayerGui = Player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local IndexFrame = NewUI:WaitForChild("IndexFrame")
local Main = IndexFrame:WaitForChild("Main")
local ItemsTab = Main:WaitForChild("ItemsTab")
local Content = ItemsTab:WaitForChild("Content")
local Craft = Main:WaitForChild("Craft")

local TemplateUnit = Content:WaitForChild("1")
TemplateUnit.Visible = false -- Esconde o template original

local UnitsIndex = Player:WaitForChild("Index"):WaitForChild("Units Index")
local Clicked = false
local allUnitTable = {}

-- FUNCTIONS
local function ApplyRarityTheme(bgFrame, rarity)
	local theme = RARITY_COLORS[rarity] or RARITY_COLORS["Rare"] -- Fallback
	if bgFrame then
		bgFrame.BackgroundColor3 = theme.Bg
		if bgFrame:FindFirstChild("1") then bgFrame["1"].BackgroundColor3 = theme.L1 end
		if bgFrame:FindFirstChild("2") then bgFrame["2"].BackgroundColor3 = theme.L2 end
		if bgFrame:FindFirstChild("3") then bgFrame["3"].BackgroundColor3 = theme.L3 end
	end
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

local function Update()
	-- Se houver um contador global na nova UI, atualize-o aqui (ex: IndexFrame.Header.Count.Text)
	-- local Label = IndexFrame.Header.Count 
	-- Label.Text = PlayerOwnedUnits()

	for _, unitFrame in Content:GetChildren() do
		if unitFrame:IsA("Frame") and unitFrame.Name ~= "1" and unitFrame.Name ~= "UIGridLayout" then
			local unitName = unitFrame.Name
			local rarity = Upgrades[unitName].Rarity

			local vp = unitFrame.Placeholder:FindFirstChildOfClass("ViewportFrame")
			local unitData = UnitsIndex:FindFirstChild(unitName)

			local btn = unitFrame:FindFirstChild("Btn")
			local icon = unitFrame:FindFirstChild("Icon")
			local amount = unitFrame:FindFirstChild("Amount")
			local claim = unitFrame:FindFirstChild("Claim")

			-- Atualiza o texto de recompensa
			if amount then
				amount.Text = InfoModule[rarity]
			end

			if unitData then
				-- O Player DESBLOQUEOU o personagem
				if unitData.Value == false then
					-- Desbloqueado, mas NÃO resgatado
					btn.Visible = true
					icon.Visible = true
					amount.Visible = true
					claim.Visible = true
				else
					-- Desbloqueado e JÁ resgatado
					btn.Visible = false
					icon.Visible = false
					amount.Visible = false
					claim.Visible = false
				end

				-- Remove o efeito de esboço (Silhueta)
				if vp then
					vp.Ambient = Color3.new(0.784314, 0.784314, 0.784314)
					vp.LightColor = Color3.new(0.54902, 0.54902, 0.54902)
				end
			else
				-- O Player NÃO DESBLOQUEOU
				btn.Visible = false
				icon.Visible = false
				amount.Visible = false
				claim.Visible = false

				-- Aplica o efeito de esboço (Silhueta escura)
				if vp then
					vp.BackgroundColor3 = Color3.new(1, 0.956863, 0.968627)
					vp.Ambient = Color3.new(0, 0, 0)
					vp.LightColor = Color3.new(0, 0, 0)
				end
			end
		end
	end
end

local function ShowUnit(UnitName)
	local rarity = Upgrades[UnitName].Rarity

	-- Limpa o Viewport antigo do Craft
	local oldVp = Craft.Placeholder:FindFirstChildOfClass("ViewportFrame")
	if oldVp then
		if oldVp.Name == UnitName then return end -- Já está selecionado
		oldVp:Destroy()
	end

	-- Aplica as cores de raridade no Craft.Bg
	ApplyRarityTheme(Craft.Bg, rarity)

	-- Cria o novo Viewport
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

		-- Verifica se o player possui a unidade para definir se será esboço ou normal
		if UnitsIndex:FindFirstChild(UnitName) ~= nil then
			-- Normal
			Vp.Ambient = Color3.new(0.784314, 0.784314, 0.784314)
			Vp.LightColor = Color3.new(0.54902, 0.54902, 0.54902)
		else
			-- Esboço
			Vp.BackgroundColor3 = Color3.new(1, 0.956863, 0.968627)
			Vp.Ambient = Color3.new(0, 0, 0)
			Vp.LightColor = Color3.new(0, 0, 0)
		end
	end
end

-- INIT
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

	-- Clona o template
	local Template = TemplateUnit:Clone()
	Template.Name = UnitName
	Template.LayoutOrder = index
	Template.Visible = true
	Template.Parent = Content
	
	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.fromScale(1, 1)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.ZIndex = 10
	clickButton.Parent = Template

	local uiScale = Instance.new("UIScale")
	uiScale.Parent = clickButton

	ButtonAnimation.unitButtonAnimation(clickButton)

	clickButton.Activated:Connect(function()
		ShowUnit(UnitName)
	end)

	local Vp = ViewPort.CreateViewPort(UnitName)
	if Vp then
		Vp.Name = UnitName
		Vp.ZIndex = 7
		Vp.Parent = Template.Placeholder

		if Template.Placeholder:FindFirstChild("Placeholder") then
			Template.Placeholder.Placeholder.Visible = false
		end
	end

	ApplyRarityTheme(Template.Bg, rarity)
end

Update()

UnitsIndex.ChildAdded:Connect(Update)

local GeneralClaimButton = IndexFrame:FindFirstChild("ClaimButton") 
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
			else
				_G.Message("No unclaimed unit rewards remaining", Color3.new(1, 0, 0), nil, "Error")
			end
		end
	end)
end

-- Zone / Hitbox Logic
local Zone = require(RS.Modules.Zone)
local Container = Zone.new(workspace:WaitForChild('IndexBox'):WaitForChild('IndexHitbox'))

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

if IndexFrame:FindFirstChild("Closebtn") then
	IndexFrame.Closebtn.Activated:Connect(function()
		local chr = Player.Character or Player.CharacterAdded:Wait()
		if chr then
			chr:SetPrimaryPartCFrame(workspace:WaitForChild("Index"):WaitForChild("TeleportOut").CFrame) 
			_G.CloseAll()
			UiHandler.EnableAllButtons()
		end
	end)
end