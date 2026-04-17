local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local ClanRemotes = Remotes.Clans
local ClansFrame = script.Parent.Parent.Parent.ClansFrame
local Internal = ClansFrame.Internal
local NumberValueConvert = require(ReplicatedStorage.AceLib.NumberValueConvert)
local ClanShop = require(ReplicatedStorage.ClansLib.ClanShop)
local DynamicPricing = require(ReplicatedStorage.ClansLib.ClanShop.DynamicPricing)
local ClanTags = require(ReplicatedStorage.ClansLib.ClanTags)
local PromptHandler = require(script.Parent.Parent.PromptModule)

local module = {}

module.conns = {}
for i,v in module.conns do
	v:Disconnect()
	v = nil
end


local VaultFrame = Internal.Vault


local CurrentClan = Player.ClanData.CurrentClan :: StringValue



module.updateClanConnection = nil

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local function updateConnection()
	if module.updateClanConnection then
		module.updateClanConnection:Disconnect()
		module.updateClanConnection = nil
	end

	if CurrentClan.Value ~= 'None' then
		local VaultAmount = ReplicatedStorage.Clans[CurrentClan.Value].Stats.Vault

		VaultFrame.BottomFrame.ClanCurrencyFrame.AmountLabel.Text = NumberValueConvert.convert(VaultAmount.Value)

		module.updateClanConnection = VaultAmount.Changed:Connect(function()
			VaultFrame.BottomFrame.ClanCurrencyFrame.AmountLabel.Text = NumberValueConvert.convert(VaultAmount.Value)
		end)
	end
end

updateConnection()

CurrentClan.Changed:Connect(updateConnection)

local TemplateTabButton = VaultFrame.CategoryFrame.ScrollingFrame.UIListLayout._TemplateTabButton

local inactiveBG = Color3.fromRGB(50,50,50)
local inactiveText = Color3.fromRGB(125,125,125)

local equippedBG = Color3.fromRGB(24, 24, 24)
local equippedText = Color3.fromRGB(248, 248, 248)

local unequippedText = Color3.fromRGB(24, 24, 24)
local unequippedBG = Color3.fromRGB(248, 248, 248)

local activeBG = Color3.fromRGB(95, 255, 87)
local activeText = Color3.fromRGB(0,50,0)

local prev = nil
local ttime = 0.2

local function switchSelectedCategory(v)
	if prev then
		tween(prev, ttime, {BackgroundColor3 = inactiveBG})
		tween(prev.TextLabel, ttime, {TextColor3 = inactiveText})

		VaultFrame[prev.TextLabel.Text].Visible = false

	end

	tween(v, ttime, {BackgroundColor3 = activeBG})
	tween(v.TextLabel, ttime, {TextColor3 = activeText})

	VaultFrame[v.TextLabel.Text].Visible = true

	prev = v
end

local function getKeyByIndex(i)
	for key, value in pairs(ClanShop.Shop) do
		if value.Index == i then
			return key
		end
	end
end

local first = true -- switchselectjeiajfoiscategory

local function findKeyBasedOnName(tbl, name)
	for i,v in tbl do
		if v.Name == name then
			return i
		end
	end
end

local function getUnitRarity(unit)
	local rarity = nil

	for i,v in ReplicatedStorage.Towers:GetChildren() do
		if v:IsA('Folder') then
			if v:FindFirstChild(unit) then
				rarity = v.Name
				break
			end
		end
	end

	return rarity
end

local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)


local typeConfig = {
	Towers = function(button, category, itemName)
		-- towernmae; button.TitleLabel.Text
		button.ItemImageLabel.Image = ''
		local tower = {Name = itemName} -- legit just copy pasted from inventory module LOL
		local slot = button.ItemImageLabel.TowerSlot
		slot.Visible = true

		slot.Backend.Enabled = true
		local filteredName = tower.Name

		--if string.find(targetName, '[SHINY] ') then
		--warn('FOUND SHINE')
		filteredName = filteredName:gsub("%[SHINY%] ", "")

		local rarity = getUnitRarity(filteredName)
		if rarity == 'Mythical' or rarity == 'Secret' then
			slot.Backend.valEnabled.Value = true
		else
			slot.Backend.valEnabled.Value = false
		end

		local isShiny = button:FindFirstChild('Shiny')
		if isShiny then isShiny = true end

		slot.Internal.Glow.Visible = isShiny
		slot.Internal.Icon_Container.Shiny_Icon.Visible = isShiny

	
		local vp = ViewPortModule.CreateViewPort(filteredName, isShiny)
		vp.Parent = slot.Internal
		
		slot.Internal['Text_Container'].Unit_Name.Text = filteredName

		
		if rarity then
			local gradientRarity = ReplicatedStorage.Borders:FindFirstChild(rarity)
			if gradientRarity then
				slot.Internal.Glow.UIGradient.Color = gradientRarity.Color
				slot.Internal['Main_Unit_ Frame'].UIGradient.Color = gradientRarity.Color
			end
		end
		--end
		button.TitleLabel['Tower'].Enabled = true
	end,
	Items = function(button, category, itemName, itemData)		
		-- towernmae; button.TitleLabel.Text
		button.ItemImageLabel.Image = ''
		local tower = {Name = itemName} -- legit just copy pasted from inventory module LOL
		local slot = button.ItemImageLabel.TowerSlot
		
		slot.Visible = true

		slot.Backend.Enabled = true
		local filteredName = tower.Name

		--if string.find(targetName, '[SHINY] ') then
		--warn('FOUND SHINE')
		

		local vp = ViewPortModule.CreateViewPort(itemData.BackendName or filteredName)--, isShiny)
		vp.Parent = slot.Internal

		slot.Internal['Text_Container'].Unit_Name.Text = filteredName


		--if rarity then
		--	local gradientRarity = ReplicatedStorage.Borders:FindFirstChild(rarity)
		--	if gradientRarity then
		--		slot.Internal.Glow.UIGradient.Color = gradientRarity.Color
		--		slot.Internal['Main_Unit_ Frame'].UIGradient.Color = gradientRarity.Color
		--	end
		--end
		--end
		button.TitleLabel['Tower'].Enabled = true
	end,
	Tags = function(button, category, itemName)
		button.ItemImageLabel.Image = ''
		button.ItemImageLabel.BackgroundTransparency = 0
		--button.ItemImageLabel.BackgroundColor3 = ClanTags.Tags[button.TitleLabel.Text].Color
		ClanTags.ApplyTag(button.ItemImageLabel, button.TitleLabel.Text, true)
		ClanTags.ApplyTag(button.TitleLabel, button.TitleLabel.Text)
	end,
	['Default'] = function(button, category, itemName)
		button.ItemImageLabel.Image = ClanShop.Shop[category].Content[findKeyBasedOnName(ClanShop.Shop[category].Content, button.TitleLabel.Text)].Image
	end,
}

local prevFrames = {}
local totalCount = 0

for i,v in ClanShop.Shop do
	totalCount += 1
end

module.shopConns = {}

local function updateShopContent()
	for i,v in prevFrames do
		v:Destroy()
	end
	for i,v in module.shopConns do
		v:Disconnect()
		v = nil
	end
	
	for i,v in VaultFrame.CategoryFrame.ScrollingFrame:GetChildren() do
		if v:IsA('ImageButton') then
			v:Destroy()
		end
	end

	prevFrames = {}

	if CurrentClan.Value == 'None' then return end

	for i = 1, totalCount do
		local key = getKeyByIndex(i)
		local Category = ClanShop.Shop[key]

		local CategoryTemplateButton = TemplateTabButton:Clone()
		CategoryTemplateButton.LayoutOrder = i
		CategoryTemplateButton.TextLabel.Text = key

		CategoryTemplateButton.Activated:Connect(function()
			switchSelectedCategory(CategoryTemplateButton)
		end)

		CategoryTemplateButton.Parent = VaultFrame.CategoryFrame.ScrollingFrame

		local ScrollingContentFrame = VaultFrame.TemplateContentFrame:Clone()


		ScrollingContentFrame.Visible = false
		ScrollingContentFrame.Name = key
		ScrollingContentFrame.Parent = VaultFrame
		--ScrollingContentFrame = key
		for i, Item in Category.Content do
			-- This is the actual bulk of the SHOP CONTENT ITEMS!!!!! (finally)
			local template = ScrollingContentFrame.UIListLayout._TemplateShopFrame:Clone()

			template.LayoutOrder = i

			template.Name = Item.Name
			
			template.TitleLabel.Text = Item.Name

 			if string.find(Item.Name, '[SHINY] ') then
				Instance.new('Folder', template).Name = 'Shiny'
				--template.TitleLabel.Text = "[SHINY] " .. template.TitleLabel.Text
			end
			
			-- key = itemType, such as Towers, Items etc(category)
			if typeConfig[key] then
				typeConfig[key](template, key, Item.Name, Item)
			else
				typeConfig['Default'](template, key, Item.Name)
			end

			if not Item.DynamicPrice then
				template.CostLabel.Text = NumberValueConvert.convert(Item.Price)
			else
				template.CostLabel.Text = DynamicPricing.PriceFuncs[key][Item.Name](CurrentClan.Value)
				local conn = DynamicPricing.PriceEvents[key][Item.Name](template.CostLabel, CurrentClan.Value, key, Item.Name) -- automatically update
				table.insert(module.shopConns, conn)
			end

			template.DescriptionLabel.Text = Item.Description

			template.UseButton.Activated:Connect(function()
				if template.UseButton.TextLabel.Text == 'EQUIP' then
					PromptHandler.disablePrompt()
					PromptHandler.enablePrompt('Loading')
					local result = ClanRemotes.Equip:InvokeServer(Item.Name, key)
					_G.Message(result)

					PromptHandler.disablePrompt()
				else
					PromptHandler.disablePrompt()
					PromptHandler.enablePrompt('Loading')
					local result = ClanRemotes.PurchaseClanShop:InvokeServer(Item.Name, key)
					_G.Message(result)
					PromptHandler.disablePrompt()
				end
			end)

			template.Parent = ScrollingContentFrame
			template.Visible = true
		end

		if first then
			switchSelectedCategory(CategoryTemplateButton)
			first = false
		end
	end


	-- stuff
	-- ClanColors <- clan colors
	local clanData = ReplicatedStorage.Clans:FindFirstChild(CurrentClan.Value)
	if clanData then
		local SelectedTag = clanData.ActiveColor
		local function handleTag(v)
			local FoundTag = VaultFrame['Tags'][v.Value]
			--VaultFrame['Tags'][v.Value].Visible = false -- we already own it so mark it as "OWNED or smth"

			FoundTag.CostLabel.Visible = false

			if SelectedTag.Value ~= v.Value then
				FoundTag.UseButton.TextLabel.Text = 'EQUIP'
				FoundTag.UseButton.Active = true
				tween(FoundTag.UseButton, ttime, {BackgroundColor3 = unequippedBG})
				tween(FoundTag.UseButton.TextLabel, ttime, {TextColor3 = unequippedText})
			else
				FoundTag.UseButton.TextLabel.Text = 'EQUIPPED'
				FoundTag.UseButton.Active = false
				tween(FoundTag.UseButton, ttime, {BackgroundColor3 = equippedBG})
				tween(FoundTag.UseButton.TextLabel, ttime, {TextColor3 = equippedText})
			end
		end
		local function update()
			for i,v in clanData.ClanColors:GetChildren() do		
				handleTag(v)
			end
		end

		update()
		clanData.ClanColors.ChildAdded:Connect(handleTag)
		SelectedTag.Changed:Connect(update)
	end
end

updateShopContent()

CurrentClan.Changed:Connect(updateShopContent)

return module