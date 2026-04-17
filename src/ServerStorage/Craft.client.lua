--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--Templates
local MainTemplate = script.MainTemplate
local RequirementTemplate = script.RequirementTemplate

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
local CraftFrame = script.Parent.CraftFrame
local Main = CraftFrame.Main
local CraftScroll = Main.CraftScroll

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

function AddRarityGradient(container,rarity)
	local g = ReplicatedStorage.Borders:FindFirstChild(rarity) or ReplicatedStorage.Borders.Rare
	RemoveAllGradients(container)

	if typeof(container) == "table" then
		for _, c in container do
			local gc = g:Clone()
			gc.Parent = c

			task.spawn(function()

				if rarity == "Mythical" and c:IsA("TextLabel") then
					local grad = gc
					local t = 2.8
					local range = 7
					grad.Rotation = 0 --0

					while grad~=nil and grad.Parent~=nil do
						local loop = tick() % t / t
						local colors = {}
						for i = 1, range + 1, 1 do
							local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
							if loop - ((i - 1) / range) < 0 then
								z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
							end
							local d = ColorSequenceKeypoint.new((i - 1) / range, z)
							table.insert(colors, d)
						end
						grad.Color = ColorSequence.new(colors)
						wait()
					end

				else

					--from koreh077,wasnt sure if we are updating to the new gradient color so i kept it the old colors
					--if we are then remove the line below this comment

					--rarity = rarity == "Mythical" and "Unique" or rarity
					--gc.Color = TraitsModule.TraitColors[rarity == "Mythical" and "Unique" or rarity].Gradient
					while gc~=nil and gc.Parent~=nil do
						gc.Rotation = (gc.Rotation+2)%360
						task.wait()
					end
				end
			end)
		end
	elseif typeof(container) == "Instance" then
		local gc = g:Clone()
		gc.Parent = container
	end

	return

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
		local item = Player.Items[itemName]
		if craftSuccessully then
			UI_Handler.PlaySound("Redeem")
			_G.Message(`Successfully Crafted {ItemStats.Name}`, Color3.fromRGB(255, 170, 0))
			ViewModule.Item({
				ItemStats,
				item
			})
		else
			UI_Handler.PlaySound("Error")
			_G.Message("Not Enough Material", Color3.fromRGB(255, 0, 0))
		end



		onCooldown = false
	end

	for _, itemStats in ItemStatsModule do
		if itemStats.CraftingRequirement == nil then continue end

		local cloneMainTemplate = MainTemplate:Clone()
		cloneMainTemplate.Name = itemStats.Name
		cloneMainTemplate.Parent = CraftScroll

		cloneMainTemplate.ViewFrame.ItemName.Text = itemStats.Name

		AddRarityGradient({cloneMainTemplate.ViewFrame.ImageGrad, cloneMainTemplate.ViewFrame.GlowEffect}, itemStats.Rarity)
		SetViewport(itemStats.Name, cloneMainTemplate.ViewFrame)
		cloneMainTemplate.CraftButton.MouseButton1Down:Connect(function() CraftPress(itemStats) end)

		local requirementScroll = cloneMainTemplate.RequirementFrame.RequirementScroll

		for requirementName, amount in itemStats.CraftingRequirement do
			if requirementName == "Coins" then
				cloneMainTemplate.ViewFrame.CoinsAmount.Text = amount
				continue
			end

			local requireItemStats = ItemStatsModule[requirementName]

			local cloneRequirementTemplate = RequirementTemplate:Clone()
			cloneRequirementTemplate.Name = requirementName
			cloneRequirementTemplate.ItemQuantity.Text = `{0}/{amount}`
			cloneRequirementTemplate.Parent = requirementScroll

			AddRarityGradient({cloneRequirementTemplate.ImageGrad, cloneRequirementTemplate.GlowEffect}, requireItemStats.Rarity)
			SetViewport(requirementName, cloneRequirementTemplate)

		end

	end

end

function UpdateRequirementQuantity()
	for _, mainFrame in CraftScroll:GetChildren() do
		if not mainFrame:IsA("Frame") then continue end

		local itemStats = ItemStatsModule[mainFrame.Name]

		for _, requirementButton in mainFrame.RequirementFrame.RequirementScroll:GetChildren() do

			if not requirementButton:IsA("GuiButton") then continue end

			local matchPlayerItem = Player.Items:FindFirstChild(requirementButton.Name)

			if not matchPlayerItem or not itemStats then continue end
			local totalRequire = itemStats.CraftingRequirement[requirementButton.Name]
			if matchPlayerItem.Value >= totalRequire then
				requirementButton.ItemQuantity.Enough.Enabled = true
				requirementButton.ItemQuantity.NotEnough.Enabled = false
				requirementButton.ItemQuantity.Text = `{matchPlayerItem.Value}/{totalRequire}`
			else
				requirementButton.ItemQuantity.Enough.Enabled = false
				requirementButton.ItemQuantity.NotEnough.Enabled = true
				requirementButton.ItemQuantity.Text = `{matchPlayerItem.Value}/{totalRequire}`
			end
			--Color3.fromRGB(255, 0, 0)
		end

	end
end

function InZoneDetection()
	if #game.Workspace.Ignore:GetChildren() ~= 0 then return end
	local filter = OverlapParams.new()
	filter.FilterType = Enum.RaycastFilterType.Include
	filter.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}


	local touchedPlayer = false
	if #workspace:GetPartsInPart(workspace:WaitForChild("CraftHitBox"), filter) > 0 then
		touchedPlayer = true
		if DetectionCooldown == false and wasOpen == false then 
			wasOpen = true
			DetectionCooldown = true do
				task.delay(0.5,function()
					DetectionCooldown = false
				end)
			end
			_G.CloseAll("CraftFrame")
			--closeall("SummonFrame")
			UI_Handler.DisableAllButtons()
		end


	end

	if not touchedPlayer and wasOpen then
		_G.CloseAll()
		wasOpen = false
		UI_Handler.EnableAllButtons()
	end
end

AddAllItems()
UpdateRequirementQuantity()

for _, item in Player.Items:GetChildren() do
	item:GetPropertyChangedSignal("Value"):Connect(UpdateRequirementQuantity)
end



warn('registering crafting')

local Zone = require(ReplicatedStorage.Modules.Zone)
local CraftHitBox = workspace:WaitForChild('NewCraftHitBox')
local Container = Zone.new(CraftHitBox)


warn('woopnamgangnamsttyle')
Container.playerEntered:Connect(function(plr)
	if plr == Player then
		print('we entered the crafting zone!')
	end
end)