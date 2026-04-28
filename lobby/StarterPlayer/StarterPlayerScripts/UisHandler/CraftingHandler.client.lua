-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- CONSTANTS
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local CraftingUI = NewUI:WaitForChild("Crafting")

local MainPanel = CraftingUI:WaitForChild("Main")
local CraftPanel = MainPanel:WaitForChild("Craft")
local ItemsTabContent = MainPanel:WaitForChild("ItemsTab"):WaitForChild("Content")

local ItemTemplate = ItemsTabContent:WaitForChild("1")
local MaterialTemplate = ItemTemplate:WaitForChild("Itemsrequired"):WaitForChild("1")

local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")
local ItemStatsModule = require(ReplicatedStorage:WaitForChild("ItemStats"))
local ViewModule = require(ModulesFolder:WaitForChild("ViewModule"))
local UI_Handler = require(ModulesFolder.Client:WaitForChild("UIHandler"))
local ViewPortModule = require(ModulesFolder:WaitForChild("ViewPortModule"))
local Zone = require(ModulesFolder:WaitForChild("Zone"))

local FunctionsFolder = ReplicatedStorage:WaitForChild("Functions")
local CraftFunction = FunctionsFolder:WaitForChild("Craft")

local CraftingZonePart = Workspace:WaitForChild("CraftHitbox"):WaitForChild("NewCraftHitBox")
local PlayerItems = Player:WaitForChild("Items")

-- VARIABLES
local onCooldown = false
local gradients = {}
local selectedItemName = nil

-- FUNCTIONS
local function RemoveAllGradients(container)
	if typeof(container) == "table" then
		for _, c in container do
			for _, v in c:GetChildren() do
				if v:IsA("UIGradient") then
					v:Destroy()
				end
			end
		end
	elseif typeof(container) == "Instance" then
		for _, v in container:GetChildren() do
			if v:IsA("UIGradient") then
				v:Destroy()
			end
		end
	end
end

local function AddRarityGradient(container, rarity)
	local bordersFolder = ReplicatedStorage:FindFirstChild("Borders")
	if not bordersFolder then return end

	local g = bordersFolder:FindFirstChild(rarity) or bordersFolder:FindFirstChild("Rare")
	if not g then return end

	RemoveAllGradients(container)

	local function addGradientTo(c)
		local gc = g:Clone()
		gc.Parent = c
		table.insert(gradients, {grad = gc, rarity = rarity, container = c})
	end

	if typeof(container) == "table" then
		for _, c in ipairs(container) do
			addGradientTo(c)
		end
	elseif typeof(container) == "Instance" then
		addGradientTo(container)
	end
end

local function UpdateGradients()
	for i = #gradients, 1, -1 do
		local data = gradients[i]
		local grad, rarity, container = data.grad, data.rarity, data.container
		if not grad or not grad.Parent or not container or not container.Parent then
			table.remove(gradients, i)
		else
			if rarity == "Mythical" and container:IsA("TextLabel") then
				local t = 2.8
				local range = 7
				local loop = (tick() % t) / t
				local colors = {}
				for j = 1, range + 1 do
					local hue = loop - ((j - 1) / range)
					if hue < 0 then hue = hue + 1 end
					colors[j] = ColorSequenceKeypoint.new((j - 1) / range, Color3.fromHSV(hue, 1, 1))
				end
				grad.Color = ColorSequence.new(colors)
				grad.Rotation = 0
			else
				grad.Rotation = (grad.Rotation + 2) % 360
			end
		end
	end
end

local function SetViewport(name, parentTo)
	for _, v in parentTo:GetChildren() do
		if v:IsA("ViewportFrame") then
			v:Destroy()
		end
	end

	local cloneViewport = ViewPortModule.CreateViewPort(name)
	if cloneViewport then
		cloneViewport.ZIndex = 6
		cloneViewport.Size = UDim2.new(1, 0, 1, 0)
		cloneViewport.Parent = parentTo
	end
end

local function CanCraft(itemStats)
	if not itemStats or not itemStats.CraftingRequirement then return false end
	for reqName, amount in itemStats.CraftingRequirement do
		local playerRequireItem = PlayerItems:FindFirstChild(reqName)
		if not playerRequireItem or playerRequireItem.Value < amount then 
			return false 
		end
	end
	return true
end

local function SelectItem(itemStats)
	selectedItemName = itemStats.Name

	CraftPanel.Title.Text = itemStats.Name
	CraftPanel.Description.Text = tostring(itemStats.Description)
	CraftPanel.Rarity.Text = itemStats.Rarity

	SetViewport(itemStats.Name, CraftPanel.Placeholder.ViewportFrame)
	AddRarityGradient(CraftPanel.Rarity, itemStats.Rarity)

	-- Exibe os detalhes do item apenas após ser selecionado
	CraftPanel.Title.Visible = true
	CraftPanel.Description.Visible = true
	CraftPanel.Rarity.Visible = true
	CraftPanel.Placeholder.Visible = true

	-- Exibe o botão de Craft apenas se tiver os requisitos
	CraftPanel.Button.Visible = CanCraft(itemStats)
end

local function UpdateRequirementQuantity()
	for _, itemFrame in ItemsTabContent:GetChildren() do
		if not itemFrame:IsA("Frame") or itemFrame.Name == "1" then continue end

		local itemStats = ItemStatsModule[itemFrame.Name]
		if not itemStats then continue end

		for _, reqFrame in itemFrame.Itemsrequired:GetChildren() do
			if not reqFrame:IsA("Frame") or reqFrame.Name == "1" then continue end

			local reqName = reqFrame.Name
			local totalRequire = itemStats.CraftingRequirement[reqName]
			if not totalRequire then continue end

			local matchPlayerItem = PlayerItems:FindFirstChild(reqName)
			local playerHas = matchPlayerItem and matchPlayerItem.Value or 0

			reqFrame.Amount.Text = `{playerHas}/{totalRequire}`

			if playerHas >= totalRequire then
				reqFrame.Amount.TextColor3 = Color3.fromRGB(85, 255, 127) -- Verde se suficiente
			else
				reqFrame.Amount.TextColor3 = Color3.fromRGB(255, 85, 85) -- Vermelho se faltar
			end
		end
	end

	-- Atualiza dinamicamente a visibilidade do botão caso o item selecionado fique pronto para ser forjado
	if selectedItemName then
		local stats = ItemStatsModule[selectedItemName]
		if stats then
			CraftPanel.Button.Visible = CanCraft(stats)
		end
	end
end

local function AddAllItems()
	ItemTemplate.Visible = false
	MaterialTemplate.Visible = false

	for _, itemStats in ItemStatsModule do
		if not itemStats.CraftingRequirement then continue end

		local newItem = ItemTemplate:Clone()
		newItem.Name = itemStats.Name
		newItem.Visible = true
		newItem.Parent = ItemsTabContent

		local coinCost = itemStats.CraftingRequirement["Coins"] or 0
		newItem.Profile.Amount.Text = tostring(coinCost)
		newItem.Profile.NameItem.Text = itemStats.Name

		SetViewport(itemStats.Name, newItem.Profile.Placeholder.ViewportFrame)
		AddRarityGradient(newItem.Profile.Bg, itemStats.Rarity)

		newItem.Profile.Btn.Activated:Connect(function()
			SelectItem(itemStats)
		end)

		for reqName, amount in itemStats.CraftingRequirement do
			if reqName == "Coins" then continue end

			local reqStats = ItemStatsModule[reqName]
			local newReq = MaterialTemplate:Clone()
			newReq.Name = reqName
			newReq.Visible = true
			newReq.Parent = newItem.Itemsrequired

			SetViewport(reqName, newReq.Placeholder.ViewportFrame)
			if reqStats then
				AddRarityGradient(newReq.Bg, reqStats.Rarity)
			end
		end
	end
end

local function CraftPress()
	if onCooldown or not selectedItemName then return end
	onCooldown = true

	local itemStats = ItemStatsModule[selectedItemName]

	-- Dupla verificação no momento do clique por segurança
	if not CanCraft(itemStats) then
		onCooldown = false
		return 
	end

	local craftSuccessfully = CraftFunction:InvokeServer(selectedItemName)
	local item = PlayerItems:FindFirstChild(selectedItemName)

	if craftSuccessfully then
		UI_Handler.PlaySound("Redeem")
		_G.Message(`Successfully Crafted {itemStats.Name}`, Color3.fromRGB(255, 170, 0))
		ViewModule.Item({itemStats, item})
	else
		UI_Handler.PlaySound("Error")
		_G.Message("Not Enough Material", Color3.fromRGB(255, 0, 0))
	end

	onCooldown = false
end

-- INIT

CraftPanel.Title.Visible = false
CraftPanel.Description.Visible = false
CraftPanel.Rarity.Visible = false
CraftPanel.Placeholder.Visible = false
CraftPanel.Button.Visible = false

RunService.RenderStepped:Connect(UpdateGradients)
AddAllItems()
UpdateRequirementQuantity()

for _, item in PlayerItems:GetChildren() do
	item:GetPropertyChangedSignal("Value"):Connect(UpdateRequirementQuantity)
end

CraftPanel.Button.Btn.Activated:Connect(CraftPress)

local Container = Zone.new(CraftingZonePart)

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		_G.CloseAll("Crafting")
		UI_Handler.DisableAllButtons()
	end
end)

Container.playerExited:Connect(function(plr)
	if plr == Player then
		_G.CloseAll()
		UI_Handler.EnableAllButtons()
	end
end)