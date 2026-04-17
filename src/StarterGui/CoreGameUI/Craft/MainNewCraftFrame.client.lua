--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Templates
local MainTemplate = script.Parent.NewCraftingFrame.Main.Left_Panel.Contents.Template
local Main = script.Parent.NewCraftingFrame.Main
local Right_Panel = Main.Right_Panel.Contents

--Modules
local ModulesFolder = ReplicatedStorage:WaitForChild("Modules")
local ItemStatsModule = require(ReplicatedStorage:WaitForChild("ItemStats"))
local ViewModule = require(ModulesFolder:WaitForChild("ViewModule"))
local UI_Handler = require(ReplicatedStorage.Modules.Client.UIHandler)
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
--Player
local Player = game.Players.LocalPlayer
Player:WaitForChild("Items")	--Wait for items to load, doesnt mean data will load

--PathsA
local CraftFrame = script.Parent.NewCraftingFrame
local Main = CraftFrame.Main
local CraftScroll = Main.Left_Panel.Contents

--Variables
local DetectionCooldown = false
local wasOpen = false

--RemoteFunctions
local FunctionsFolder = game.ReplicatedStorage:WaitForChild("Functions")
local CraftFunction = FunctionsFolder:WaitForChild("Craft")

--Functions
function RemoveAllGradients(container)
	if typeof(container) == "table" then
		for _, c in container do
			for i, v in c:GetChildren() do
				if v:IsA("UIGradient") then
					v:Destroy()
				end
			end
		end
	elseif typeof(container) == "Instance" then
		for i, v in container:GetChildren() do
			if v:IsA("UIGradient") then
				v:Destroy()
			end
		end
	end
end

--function AddRarityGradient(container,rarity)
--	local g = ReplicatedStorage.Borders:FindFirstChild(rarity) or ReplicatedStorage.Borders.Rare
--	RemoveAllGradients(container)

--	if typeof(container) == "table" then
--		for _, c in container do
--			local gc = g:Clone()
--			gc.Parent = c

--			task.spawn(function()

--				if rarity == "Mythical" and c:IsA("TextLabel") then
--					local grad = gc
--					local t = 2.8
--					local range = 7
--					grad.Rotation = 0 --0

--					while grad~=nil and grad.Parent~=nil do
--						local loop = tick() % t / t
--						local colors = {}
--						for i = 1, range + 1, 1 do
--							local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
--							if loop - ((i - 1) / range) < 0 then
--								z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
--							end
--							local d = ColorSequenceKeypoint.new((i - 1) / range, z)
--							table.insert(colors, d)
--						end
--						grad.Color = ColorSequence.new(colors)
--						wait()
--					end

--				else

--					--from koreh077,wasnt sure if we are updating to the new gradient color so i kept it the old colors
--					--if we are then remove the line below this comment

--					--rarity = rarity == "Mythical" and "Unique" or rarity
--					--gc.Color = TraitsModule.TraitColors[rarity == "Mythical" and "Unique" or rarity].Gradient
--					while gc~=nil and gc.Parent~=nil do
--						gc.Rotation = (gc.Rotation+2)%360
--						task.wait()
--					end
--				end
--			end)
--		end
--	elseif typeof(container) == "Instance" then
--		local gc = g:Clone()
--		gc.Parent = container
--	end

--	return

--end

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gradients = {}


--local function updateGradients(dt)
--	for i = #gradients, 1, -1 do
--		local data = gradients[i]
--		local grad, rarity, container = data.grad, data.rarity, data.container
--		if not grad or not grad.Parent or not container or not container.Parent then
--			table.remove(gradients, i)
--		else
--			if rarity == "Mythical" and container:IsA("TextLabel") then
--				local t = 2.8
--				local range = 7
--				local loop = (tick() % t) / t
--				local colors = {}
--				for j = 1, range + 1 do
--					local hue = loop - ((j - 1) / range)
--					if hue < 0 then hue = hue + 1 end
--					colors[j] = ColorSequenceKeypoint.new((j - 1) / range, Color3.fromHSV(hue, 1, 1))
--				end
--				grad.Color = ColorSequence.new(colors)
--				grad.Rotation = 0
--			else
--				grad.Rotation = (grad.Rotation + 2) % 360
--			end
--		end
--	end
--end

--RunService.RenderStepped:Connect(updateGradients)

function AddRarityGradient(container, rarity)
	local g = ReplicatedStorage.Borders:FindFirstChild(rarity) or ReplicatedStorage.Borders.Rare
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



function AddAllItems()	--This function load up all the items in ItemsStats with Requirement

	local function SetViewport(name, parentTo)
		
		local cloneViewport = ViewPortModule.CreateViewPort(name)
		cloneViewport.ZIndex = 6
		cloneViewport.Parent = parentTo
	end
	local onCooldown = false
	local function CraftPress(ItemStats)
		if onCooldown then return end
		--_G.CloseAll("NewCraftingFrame")
		onCooldown = true
		local itemName = ItemStats.Name
		local haveAllRequiremnt = true

		for requireName, amount in ItemStats.CraftingRequirement do
			local playerRequireItem = Player.Items:FindFirstChild(requireName)
			if not playerRequireItem or playerRequireItem.Value < amount then 
				haveAllRequiremnt = false 
				break 
			end
		end

		local craftSuccessully = CraftFunction:InvokeServer(itemName)
		warn(craftSuccessully)
		local item = Player.Items[itemName]
		if craftSuccessully then
			UI_Handler.PlaySound("Redeem")
			_G.Message(`Successfully Crafted {ItemStats.Name}`, Color3.fromRGB(255, 170, 0))
			warn(item, ItemStats)
			ViewModule.Item({
				ItemStats,
				item
			})
		else
			UI_Handler.PlaySound("Error")
			_G.Message("Not Enough Material", Color3.fromRGB(255, 0, 0))
		end


		MainTemplate.Visible = false
		onCooldown = false
	end

	for _, itemStats in ItemStatsModule do
		if itemStats.CraftingRequirement == nil then continue end

		local cloneMainTemplate = MainTemplate:Clone()
		
		local button = cloneMainTemplate.Contents.Item_Main

		button.Activated:Connect(function()
			warn(button.Parent.Parent.Name)
			local Name = Right_Panel.Title.Names
			Name.Text = button.Parent.Parent.Name
			local Item 
			for i,v in ReplicatedStorage.ItemStats:GetDescendants() do
				if v.Name == button.Parent.Parent.Name and v:IsA("ModuleScript") then
					warn("Found")
					Item = ItemStatsModule[v.Name]
				end
			end



			local Description = Right_Panel.Title.Description
			warn(Item["Description"])
			Description.Text = tostring(Item.Description)




			local RarityLabel = Right_Panel.Title.Rarity
			RarityLabel.Text = Item.Rarity
			


			local rarity = Item.Rarity
			
			
			
			local ViewPort = Right_Panel.Parent.ViewportFrame
			
			for i, v in ViewPort:GetChildren() do
				if v:IsA("ViewportFrame") then
					v:Destroy()
				end
			end
			
			
			local NewViewport = ViewPortModule.CreateViewPort(Item.Name)
			
			--local ItemClone = ReplicatedStorage.Items:FindFirstChild(rarity):FindFirstChild(Item.Name):Clone()
			--ItemClone.Parent = ViewPort
			
			NewViewport.Parent = ViewPort
			NewViewport.Size = UDim2.new(1,0,1,0)

			AddRarityGradient(RarityLabel, rarity)



		end)
		
		local debounce = false
		cloneMainTemplate.Name = itemStats.Name
		cloneMainTemplate.Parent = CraftScroll

		cloneMainTemplate.Contents.Item_Main.Contents.Title.Text = itemStats.Name

		AddRarityGradient({cloneMainTemplate.Contents.Item_Main.Contents.Border.UIGradient, cloneMainTemplate.Contents.Item_Main.Contents.Glow.UIGradient}, itemStats.Rarity)
		SetViewport(itemStats.Name, cloneMainTemplate.Contents.Item_Main.Contents.ViewportFrame)
		Player.PlayerGui.CoreGameUI.Craft.NewCraftingFrame.Main.Right_Panel.Contents.Options.Bar.Buy.Activated:Connect(function() CraftPress(ItemStatsModule[Right_Panel.Title.Names.Text]) end)
		Player.PlayerGui.CoreGameUI.Craft.NewCraftingFrame.Main.Right_Panel.Contents.Options.Bar.View.Activated:Connect(function()
			if debounce then return end
			debounce = true
			UI_Handler.PlaySound("Redeem")
			ViewModule.Item({
				ItemStatsModule[Right_Panel.Title.Names.Text],
				Right_Panel.Title.Names.Text
				
			})
			task.wait(0.5, function()
				debounce = false
			end)
			
		end)
		
		
		
		local requirementScroll = cloneMainTemplate.Contents.Requirements.Contents

		for requirementName, amount in itemStats.CraftingRequirement do
			if requirementName == "Coins" then
				cloneMainTemplate.Contents.Item_Main.Contents.Text_Container.Cost.Text = amount
				continue
			end

			local requireItemStats = ItemStatsModule[requirementName]

			local cloneRequirementTemplate = MainTemplate.Contents.Requirements.Contents.Component:Clone()
			cloneRequirementTemplate.Name = requirementName
			cloneRequirementTemplate.Cost.Text = `{0}/{amount}`
			cloneRequirementTemplate.Parent = requirementScroll

			AddRarityGradient({cloneRequirementTemplate.Contents.Border.UIGradient, cloneRequirementTemplate.Contents.Glow.UIGradient}, requireItemStats.Rarity)
			SetViewport(requirementName, cloneRequirementTemplate)
			
			
			for i,v in requirementScroll:GetChildren() do
				if v:IsA("GuiButton") and v.Name == "Component" then
					v.Visible = false
				end
			end
			
		end

	end
	

end



function UpdateRequirementQuantity()
	for _, mainFrame in CraftScroll:GetChildren() do
		if not mainFrame:IsA("Frame") then continue end

		local itemStats = ItemStatsModule[mainFrame.Name]

		for _, requirementButton in mainFrame.Contents.Requirements.Contents:GetChildren() do

			if not requirementButton:IsA("GuiButton") then continue end

			local matchPlayerItem = Player.Items:FindFirstChild(requirementButton.Name)

			if not matchPlayerItem or not itemStats then continue end
			local totalRequire = itemStats.CraftingRequirement[requirementButton.Name]
			if matchPlayerItem.Value >= totalRequire then
				requirementButton.Cost.Enough.Enabled = true
				requirementButton.Cost.NotEnough.Enabled = false
				requirementButton.Cost.Text = `{matchPlayerItem.Value}/{totalRequire}`
			else
				requirementButton.Cost.Enough.Enabled = false
				requirementButton.Cost.NotEnough.Enabled = true
				requirementButton.Cost.Text = `{matchPlayerItem.Value}/{totalRequire}`
			end
			--Color3.fromRGB(255, 0, 0)
		end

	end
end


AddAllItems()
UpdateRequirementQuantity()

for _, item in Player.Items:GetChildren() do
	item:GetPropertyChangedSignal("Value"):Connect(UpdateRequirementQuantity)
end

CraftFrame.Main.X_Close.Activated:Connect(function()
	_G.CloseAll("NewCraftingFrame")
end)

for i,v in Main.Left_Panel.Contents:GetChildren() do
	if v:IsA("Frame") and v.Name == "Template" then
		v.Visible = false
	end
end

local Zone = require(ReplicatedStorage.Modules.Zone)
local CraftingZonePart = workspace:WaitForChild('CraftHitbox'):WaitForChild('NewCraftHitBox')
local Container = Zone.new(CraftingZonePart)

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		print('we entered the crafting zone!')
		_G.CloseAll("NewCraftingFrame")
		UI_Handler.DisableAllButtons()
	end
end)

Container.playerExited:Connect(function(plr)
	if plr == Player then
		print('we left the crafting zone')
		_G.CloseAll()
		UI_Handler.EnableAllButtons()
	end
end)