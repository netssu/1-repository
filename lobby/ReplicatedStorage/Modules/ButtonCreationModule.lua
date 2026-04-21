local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local Borders = ReplicatedStorage.Borders
local Upgrades = require(ReplicatedStorage.Upgrades)
local ItemStats = require(ReplicatedStorage.ItemStats)
local Traits = require(ReplicatedStorage.Modules.Traits)


local module = {}

export type createdButton = {
	Instance: TextButton,
	setAmount: (self: createdButton) -> createdButton,
	setAmountColor: (self: createdButton) -> createdButton,
	setTrait: (self: createdButton) -> createdButton,
	setShiny: (self: createdButton) -> createdButton,
	Destroy: (self: createdButton) -> createdButton,
}

module.__index = module

function module.createButton(itemName: Folder) : createdButton
	local self = setmetatable({}, module) :: createdButton
	self.Instance = script.Button:Clone()
	local isItem = ViewPortModule.IsItem(itemName)
	local isShiny = false
	local hasTrait = false

	if typeof(itemName) == 'Instance' then -- passed in unit instance
		isShiny = itemName:GetAttribute('Shiny')
		hasTrait = itemName:GetAttribute('Trait')
		
		self:setAmount('LVL ' .. itemName:GetAttribute('Level'))
		itemName = itemName.Name
	else
		self:setAmount(1)
	end

	self.Instance.Shiny.Visible = isShiny
	if hasTrait and hasTrait ~= "" then
		self.Instance.TraitIcon.Image = Traits.Traits[hasTrait].ImageID
		self.Instance.TraitIcon.UIGradient.Color = 	Traits.TraitColors[Traits.Traits[hasTrait].Rarity].Gradient
		self.Instance.TraitIcon.UIGradient.Rotation = Traits.TraitColors[Traits.Traits[hasTrait].Rarity].GradientAngle
		self.Instance.TraitIcon.Visible = true
	end

	self.Instance.Destroying:Once(function()
		self = nil -- mem cleanup
	end)

	local vp = ViewPortModule.CreateViewPort(itemName, isShiny)

	if vp then
		vp.Parent = self.Instance
		vp.Position = UDim2.fromScale(0.5,1)
		vp.AnchorPoint = Vector2.new(0.5,1)
		vp.Size = UDim2.fromScale(1.15,1.15)
	elseif tostring(itemName) ~= 'nil' then
		warn(`VP not found for {itemName}`)
	end
			
	local foundCol = Upgrades[itemName]
	
	if not foundCol and isItem then
		foundCol = ItemStats[itemName].Rarity
	elseif foundCol then
		foundCol = foundCol.Rarity
	end
	
	if foundCol then
		local color = Borders[foundCol].Color
		self.Instance.UIGradient.Color = color
		self.Instance.BlurGlow.UIGradient.Color = color
	end
	
	if itemName then
		self.Instance.DisplayNameLabel.Text = itemName
	end -- else its a default one

	return self
end

function module:setAmount(amount: string) : createdButton
	if not tonumber(amount) then
		self.Instance.ItemCount.CountLabel.Text = amount
	else
		self.Instance.ItemCount.CountLabel.Text = amount .. 'x'
	end
	
	return self
end

function module:setAmountColor(color: Color3) : createdButton
	if color then
		self.Instance.ItemCount.CountLabel.TextColor3 = color
	else
		self.Instance.ItemCount.CountLabel.TextColor3 = Color3.fromRGB(255,255,255)
	end
	
	return self
end

function module:setTrait(hasTrait: string) : createdButton
	if hasTrait and hasTrait ~= "" then
		self.Instance.TraitIcon.Image = Traits.Traits[hasTrait].ImageID
		self.Instance.TraitIcon.UIGradient.Color = 	Traits.TraitColors[Traits.Traits[hasTrait].Rarity].Gradient
		self.Instance.TraitIcon.UIGradient.Rotation = Traits.TraitColors[Traits.Traits[hasTrait].Rarity].GradientAngle
		self.Instance.TraitIcon.Visible = true
	end
	return self
end

function module:setShiny(isShiny: boolean) : createdButton
	self.Instance.Shiny.Visible = isShiny
	return self
end

function module:Destroy() : createdButton
	self.Instance:Destroy()
	self = nil
	return self
end

return module