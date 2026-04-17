local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenModule = require(ReplicatedStorage.AceLib.TweenModule)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)

local plrData = ClientDataLoaded.getPlayerData()
local AurasFrame = script.Parent.AurasFrame
local ScrollingFrame = AurasFrame.ScrollingFrame

local EquippedAura = plrData['EquippedAura'] :: StringValue
local OwnedAuras = plrData['OwnedAuras'] :: Folder

local function tween(obj, state)
	local col = nil
	if state then
		col = Color3.fromRGB(255,255,255)
	else
		col = Color3.fromRGB(0,0,0)
	end
	TweenModule.tween(obj, 0.1, {TextColor3 = col})
end

local function createAuraContainer(aura, equipped)
	local ReplicatedAura = ReplicatedStorage.Auras[aura]
	
	local Container = ScrollingFrame.UIListLayout.Container:Clone()
	Container.Name = aura
	Container.EQUIP.TextButton.Activated:Connect(function()
		ReplicatedStorage.Remotes.EquipAura:FireServer(aura)
	end)
	
	local foundGradient = ReplicatedAura.RollName:FindFirstChild('UIGradient')
	
	if foundGradient then
		local savedGradient = foundGradient.Color :: ColorSequence
		local primaryCol = savedGradient.Keypoints[1].Value :: Color3
		local secondaryCol = savedGradient.Keypoints[2].Value :: Color3
		
		Container.UIGradient.Color = savedGradient
		Container.UIStroke.UIGradient.Color = savedGradient
		Container.TextLabel.UIGradient.Color = savedGradient
		Container.Icon.UIGradient.Color = savedGradient
		Container.Icon.ImageColor3 = Color3.fromRGB(255,255,255)
		
		for i,v in Container.Glows:GetChildren() do
			if v:IsA('ImageLabel') then
				v.ImageColor3 = primaryCol
			end
		end
		
	else
		Container.UIGradient.Enabled = false
		local savedCol = ReplicatedAura.RollName.TextColor3
		local secondaryCol = ReplicatedAura.RollName:FindFirstChild('UIStroke')
		if secondaryCol then
			secondaryCol = secondaryCol.Color
		end
		
		Container.TextLabel.TextColor3 = savedCol
		Container.TextLabel.UIGradient.Enabled = false
		if secondaryCol then
			Container.TextLabel.UIStroke.Color = secondaryCol
			Container.TextLabel.UIStroke.Enabled = true
		end
		
		
		Container.UIStroke.Color = savedCol
		Container.Icon.ImageColor3 = savedCol
		Container.UIStroke.UIGradient.Enabled = false
		--Container.BackgroundColor3 = savedCol
		
		
		
		for i,v in Container.Glows:GetChildren() do
			if v:IsA('ImageLabel') then
				v.ImageColor3 = savedCol
			end
		end
		
		Container.UIGradient.Enabled = false
	end
	
	Container.LayoutOrder = ReplicatedAura.LayoutOrder.Value
	Container.TextLabel.Text = aura
	
	local EquipContainer = Container.EQUIP :: Frame
	local currentlyEquipped = EquippedAura.Value == aura
	EquipContainer.BackgroundTransparency = if currentlyEquipped then 1 else 0
	EquipContainer.TextLabel.Text = if currentlyEquipped then 'Equipped' else 'Equip'
	tween(EquipContainer.TextLabel, currentlyEquipped)
	EquipContainer.TextButton.Visible = if currentlyEquipped then 1 else 0
	
	Container.Parent = ScrollingFrame
end

-- Connections
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
AurasFrame.CloseButton.Activated:Connect(function()
	_G.CloseAll()
end)

local old = EquippedAura.Value
EquippedAura.Changed:Connect(function()
	local found = ScrollingFrame:FindFirstChild(old)
	
	if found then
		local EquipContainer = found.EQUIP :: Frame
		EquipContainer.BackgroundTransparency = 0
		EquipContainer.TextLabel.Text = 'Equip'
		EquipContainer.TextButton.Visible = true
		tween(EquipContainer.TextLabel, nil)
	end
	
	local new = ScrollingFrame:FindFirstChild(EquippedAura.Value)
	
	if new then		
		local EquipContainer = new.EQUIP :: Frame
		EquipContainer.BackgroundTransparency = 1
		EquipContainer.TextLabel.Text = 'Equipped'
		EquipContainer.TextButton.Visible = false
		tween(EquipContainer.TextLabel, true)
	end
	
	old = EquippedAura.Value
end)

OwnedAuras.ChildAdded:Connect(function(obj)
	createAuraContainer(obj.Value)
end)

for i,v in OwnedAuras:GetChildren() do
	createAuraContainer(v.Value, v.Value == EquippedAura.Value)
end