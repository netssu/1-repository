local player = game.Players.LocalPlayer
local Mouse = player:GetMouse()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local NormalReroll = player:WaitForChild("TraitPoint")
local LuckyReroll = player:WaitForChild("LuckyWillpower")

local UIHandlerModule = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))
local ChangeUnit = script.Parent.WillpowerFrame.Frame.Contents.Unit
local TraitReroll = script.Parent.WillpowerFrame.Frame.Bottom_Bar.Bottom_Bar.Reroll
local AutoReroll = script.Parent.WillpowerFrame.Frame.Bottom_Bar.Bottom_Bar.AutoReroll
local RobuxReroll = script.Parent.WillpowerFrame.Frame.Bottom_Bar.Bottom_Bar.LuckyWillpower
local MainFrame = script.Parent.WillpowerFrame.Frame
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local UnitFrame = ChangeUnit.Contents
local Tween = game:GetService("TweenService")
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local RunService = game:GetService("RunService")

local RerollText = script.Parent.WillpowerFrame.Frame.Contents.Willpower_Total
local LuckyText = script.Parent.WillpowerFrame.Frame.Contents.LuckyWillpower
local Luckyicon = script.Parent.WillpowerFrame.Frame.Contents.LuckyWillpowerIcon

local TraitLabel = script.Parent.WillpowerFrame.Frame.Contents.Current_Willpower.Unit_Willpower
local Upgrades = ReplicatedStorage.Upgrades

local UpgradesModule = require(ReplicatedStorage.Upgrades)
local UI_Handler = require(ReplicatedStorage.Modules.Client.UIHandler)
local Traits = require(ReplicatedStorage.Modules.Traits)
local Inventory = player.PlayerGui.UnitsGui.Inventory.Units
--// Colors
local baseColorBottom = Color3.fromRGB(27, 102, 0)
local baseColorTop = Color3.fromRGB(19, 163, 0)
local toggledColorBottom = Color3.fromRGB(102,0,0)
local toggledColorTop = Color3.fromRGB(255,0,0)

function updatePrice(SelectedTower)
	local statsTower = UpgradesModule[SelectedTower.Name]
	local priceMultiplier = 1
	local trait = SelectedTower:GetAttribute("Trait")

	if TraitsModule.Traits[trait] then
		if TraitsModule.Traits[trait]["Money"] then
			priceMultiplier = (1 - (TraitsModule.Traits[trait]["Money"] / 100))
		end
	end

	local priceVal = math.round(statsTower["Upgrades"][1].Price * priceMultiplier)
	MainFrame.Contents.Unit.Contents.UnitPrice.Text = priceVal .. " $"
end


--function FilterSupport()
--	local isNotEligible = {}

--	for i,v in Upgrades:GetDescendants() do
--		if v:IsA("ModuleScript") then
--			local Info  = require(v)
--			if Info[v.Name]["Support"] then
--				table.insert(isNotEligible, v.Name)
--			end

--		end
--	end

--	local unitChildren = Inventory.Frame.Left_Panel.Contents.Act.UnitsScroll:GetChildren()
--	for _, unit in unitChildren do
--		if not (unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue")) then continue end
--		for i,v in isNotEligible do
--			if unit.TowerValue.Value == v then
--				unit.Visible = false
--				break
--			end	
--		end	

--		Inventory:GetPropertyChangedSignal("Visible"):Once(function()
--			for _, unit in ipairs(unitChildren) do
--				if unit:IsA("ImageButton") and unit:FindFirstChild("TowerValue") then
--					unit.Visible = true
--				end
--			end
--		end)
--	end
--end


--RunService.RenderStepped:Connect(function(dt)
--	local rotationSpeed = 100 * dt
--	UnitFrame.GlowEffect.UIGradient.Rotation = (UnitFrame.GlowEffect.UIGradient.Rotation + rotationSpeed) % 360
--	UnitFrame.Image.UIGradient.Rotation = UnitFrame.GlowEffect.UIGradient.Rotation
--end)

RerollText.Text = NormalReroll.Value.."/1"
LuckyText.Text = LuckyReroll.Value.."/1"

if NormalReroll.Value >= 1 then
	RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(164, 30, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 24, 255))}
else
	RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
end

if LuckyReroll.Value >= 1 then
	LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(164, 30, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255, 24, 255))}
else
	LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
end


local cooldowntick = 0
local mythicalpluscooldown = false

local traitcolors = Traits.TraitColors

local SelectedTower = script.Parent.SelectedTower

script.Parent.SelectedTower.Changed:Connect(function()
	local SelectedTower = script.Parent.SelectedTower

	if MainFrame.Contents.Unit.Contents:FindFirstChildOfClass("ViewportFrame") then MainFrame.Contents.Unit.Contents:FindFirstChildOfClass("ViewportFrame"):Destroy() end

	local trait = SelectedTower.Value:GetAttribute("Trait")
	if trait and trait ~= "" then
		TraitLabel.Text = trait
		--TraitLabel.Parent.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
		MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[trait].ImageID
		MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
		TraitLabel.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
		--TraitLabel.Parent.GlowEffect.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
	else
		TraitLabel.Text = "No WillPower"
		TraitLabel.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}
		--TraitLabel.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}
		--TraitLabel.Parent.GlowEffect.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))}
		MainFrame.Contents.Unit.Contents.TraitIcon.Image = ""
	end

	local statsTower = UpgradesModule[SelectedTower.Value.Name]
	local rarity = statsTower["Rarity"] or "Rare"
	--script.Parent.MainFrame.Unit.UIStroke.UIGradient.Color = game.ReplicatedStorage.Borders[rarity].Color
	MainFrame.Contents.Unit.Contents.Border.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color
	MainFrame.Contents.Unit.Contents.Glow.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color

	--script.Parent.MainFrame.Unit.Image.UIGradient.Color = ReplicatedStorage.Borders[rarity].Color

	MainFrame.Contents.Unit.Contents.Text_Container.Unit_Level.Text = SelectedTower.Value:GetAttribute("Level")
	--script.Parent.MainFrame.Unit.UnitLvl.Text = SelectedTower.Value:GetAttribute("Level")

	local CharModel = GetUnitModel[SelectedTower.Value.Name]
	local priceMultiplier = 1
	if TraitsModule.Traits[SelectedTower.Value:GetAttribute("Trait")] then
		if TraitsModule.Traits[SelectedTower.Value:GetAttribute("Trait")]["Money"] then
			priceMultiplier = (1-(TraitsModule.Traits[SelectedTower.Value:GetAttribute("Trait")]["Money"]/100))
		end
	end

	updatePrice(SelectedTower.Value)

	if SelectedTower.Value then
		SelectedTower.Value:GetAttributeChangedSignal("Trait"):Connect(function()
			updatePrice(SelectedTower.Value)
		end)
	end

	if CharModel then
		local vp = ViewPortModule.CreateViewPort(SelectedTower.Value.Name,SelectedTower.Value:GetAttribute("Shiny"),true)
		vp.ZIndex = 5
		vp.AnchorPoint = Vector2.new(.5,.5)
		vp.Position = UDim2.new(.5,0,.5,0)
		vp.Size = UDim2.new(1.1,0,1,0)
		vp.Parent = MainFrame.Contents.Unit.Contents
		if SelectedTower.Value:GetAttribute("Shiny") then
			MainFrame.Contents.Unit.Contents.Icon_Container.Shiny_Icon.Visible = true
		else
			MainFrame.Contents.Unit.Contents.Icon_Container.Shiny_Icon.Visible = false
		end

		UnitFrame.Text_Container.Unit_Level.Text = SelectedTower.Value:GetAttribute("Level")
		UnitFrame.Plus.Transparency = 1
		UnitFrame.Plus.UIStroke.Transparency = 1

		if player:FindFirstChild("OwnGamePasses"):FindFirstChild("2x Willpower Luck").Value == true or player:FindFirstChild("Buffs"):FindFirstChild("WillpowerLuckyCrystal") then
			UnitFrame.Indicator.ImageLabel.Visible = true
		end
		--UnitFrame.UName.Text = SelectedTower.Value.Name
	else
		print(SelectedTower.Value)
		warn("Selected tower was not found as a model. Selected tower name: "..SelectedTower.Value.Name)
	end
end)

NormalReroll.Changed:Connect(function()
	RerollText.Text = NormalReroll.Value.."/1"
	if NormalReroll.Value >= 1 then
		RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(177, 23, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(240, 28, 255))}
	else
		RerollText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
	end
end)

LuckyReroll.Changed:Connect(function()
	LuckyText.Text = LuckyReroll.Value.."/1"
	if LuckyReroll.Value >= 1 then
		LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(177, 23, 208)),ColorSequenceKeypoint.new(1,Color3.fromRGB(240, 28, 255))}
	else
		LuckyText.UIGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(208, 0, 0)),ColorSequenceKeypoint.new(1,Color3.fromRGB(175, 0, 0))}
	end
end)



MainFrame.Bottom_Bar.Bottom_Bar.Index.Activated:Connect(function()
	UIHandlerModule.PlaySound(MainFrame.Parent.Index.Visible and "Close" or "Open")

	MainFrame.Parent.Index.Visible = not MainFrame.Parent.Index.Visible
end)

--[[
local function Reroll()
	local tower = script.Parent.SelectedTower.Value
	if tower then
		if not mythicalpluscooldown then
			mythicalpluscooldown = true
			local trait = game.ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower)
			if Traits.Traits[trait] then
				if Traits.Traits[trait].Rarity == "Unique" or Traits.Traits[trait].Rarity == "Mythical" then
					_G.Message("You got a "..Traits.Traits[trait].Rarity.." trait!",Color3.new(1, 0.666667, 0))
					UI_Handler.PlaySound("LuckActive")
					UI_Handler.CreateConfetti()
					task.delay(3, function()
						mythicalpluscooldown = false
					end)
				else
					task.delay(0.02, function()
						mythicalpluscooldown = false
					end)
				end


				TraitLabel.Size = UDim2.new(0,0,0,0)
				Tween:Create(TraitLabel,TweenInfo.new(0.5, Enum.EasingStyle.Exponential),{Size = UDim2.new(1, 0,0.67, 0)}):Play()
				TraitLabel.Text = trait
				MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[tower:GetAttribute("Trait")].ImageID
				MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
			--	TraitLabel.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
				TraitLabel.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
				--TraitLabel.Parent.GlowEffect.UIGradient.Color = traitcolors[Traits.Traits[trait].Rarity].Gradient
			else

				mythicalpluscooldown = false
				UIHandlerModule.PlaySound("Error")
				--_G.Message(trait,Color3.new(0.776471, 0.239216, 0.239216))
			end
		else
			--UIHandlerModule.PlaySound("Error")
			_G.Message("Please wait before rerolling again!",Color3.new(0.776471, 0.239216, 0.239216))
		end
	end
end
--]]

local function Reroll(LuckyRoll)
	warn(LuckyRoll)
	local tower = script.Parent.SelectedTower.Value
	if tower then
		if not mythicalpluscooldown then
			mythicalpluscooldown = true
			
			local trait = nil
			
			if LuckyRoll then
				 trait = game.ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower, LuckyRoll)
			else
				trait = game.ReplicatedStorage.Functions.BuyTrait:InvokeServer(tower)
			end
			local MythicalWillpowerPity = player:FindFirstChild("MythicalPityWP").Value
			local LegendaryWillpowerPity = player:FindFirstChild("LegendaryPityWP").Value

			local pityBars = player.PlayerGui.CoreGameUI.Willpower.WillpowerFrame.Frame:WaitForChild("Pity_Bars")
			local mythicalFrame = pityBars:WaitForChild("Mythical_Pity")
			local legendaryFrame = pityBars:WaitForChild("Legendar yPity")

			mythicalFrame.Contents.Bar.Size = UDim2.fromScale(MythicalWillpowerPity/500, 1)
			mythicalFrame.Contents.Pity.Text = MythicalWillpowerPity .. "/" .. 500

			legendaryFrame.Contents.Bar.Size = UDim2.fromScale(LegendaryWillpowerPity / 250, 1)
			legendaryFrame.Contents.Pity.Text = LegendaryWillpowerPity .. "/" .. 250

			if Traits.Traits[trait] then
				local rarity = Traits.Traits[trait].Rarity
				local color = traitcolors[rarity].Gradient

				if rarity == "Unique" or rarity == "Mythical" then
					_G.Message("You got a " .. rarity .. " trait!", Color3.new(1, 0.666667, 0))
					UI_Handler.PlaySound("LuckActive")
					UI_Handler.CreateConfetti()
					task.delay(3, function()
						mythicalpluscooldown = false
					end)
				else
					task.delay(0.02, function()
						mythicalpluscooldown = false
					end)
				end

				TraitLabel.Size = UDim2.new(0, 0, 0, 0)
				Tween:Create(TraitLabel, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Size = UDim2.new(1, 0, 0.67, 0)}):Play()
				TraitLabel.Text = trait
				warn(Traits.Traits[tower:GetAttribute("Trait")])
				MainFrame.Contents.Unit.Contents.TraitIcon.Image = Traits.Traits[tower:GetAttribute("Trait")].ImageID
				MainFrame.Contents.Unit.Contents.TraitIcon.UIGradient.Color = color
				TraitLabel.UIGradient.Color = color

				return rarity, trait
			else
				mythicalpluscooldown = false
				UIHandlerModule.PlaySound("Error")
				return nil
			end
		else
			_G.Message("Please wait before rerolling again!", Color3.new(0.776471, 0.239216, 0.239216))
			return nil
		end
	else
		_G.Message("Select a unit to start rolling!", Color3.new(255,0,0)) 
	end
end

local isAutoRerolling = false
local autoThread = nil


TraitReroll.Activated:Connect(function()
	if isAutoRerolling then _G.Message("Stop autorolling to roll manually!", Color3.new(255,0,0)) return end
	Reroll()
end)

local open = false
script.Parent.WillpowerFrame:GetPropertyChangedSignal('Visible'):Connect(function()
	if script.Parent.WillpowerFrame.Visible then
		open = true
	else
		open = false
	end
end)

AutoReroll.Activated:Connect(function()
	local tower = script.Parent.SelectedTower.Value
	if not tower then _G.Message("Select a unit to start rolling!", Color3.new(255,0,0)) return end

	isAutoRerolling = not isAutoRerolling

	if isAutoRerolling then
		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(toggledColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(toggledColorTop)
	else
		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(baseColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(baseColorTop)
	end
	
	warn('autoroll time')

	task.spawn(function()
		while isAutoRerolling do
			local result, trait = Reroll()

			if not open then
				warn("Frame Not Open")
				isAutoRerolling = false
				break
			end

			print(trait, result)

			if result == "Mythical" or trait == 'Cosmic Crusader' or trait == "Waders Will" then
				warn("Mythic Trait")
				isAutoRerolling = false

				break
			end

			if player.TraitPoint.Value <= 0 then
				warn("No More Traits")
				isAutoRerolling = false
				break
			end

			task.wait(0.25) -- Wait a bit to prevent spamming
		end

		AutoReroll.Contents.UIGradient.Color = ColorSequence.new(baseColorBottom)
		AutoReroll.Contents.Contents.UIGradient.Color = ColorSequence.new(baseColorTop)
	end)
end)

local ClickButtonUnit =  MainFrame.Contents.Unit

ChangeUnit.Activated:Connect(function()
	--script.Parent.Parent.Visible = false
	local Inventory = player.PlayerGui.UnitsGui.Inventory.Units

	--Inventory.Visible = true
	--game.TweenService:Create(Inventory,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position = UDim2.fromScale(0.5,0.5)}):Play()
	_G.CloseAll("Units")
	

	_G.traitTowerSelection = true
end)

local CheckIfExists = ReplicatedStorage.Functions.BuyNowWP



RobuxReroll.MouseButton1Down:Connect(function()
local Check = CheckIfExists:InvokeServer("LuckyWillpower")

warn(Check)
if not Check then
	MarketplaceService:PromptProductPurchase(player,3221515245)
else
	Reroll(true)
end
end)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userID,productID,isPurchase)
	--print(productID,isPurchase)
	if userID ~= player.UserId then return end
	--print(not isPurchase,productID ~= 3221515245)
	if not isPurchase or productID ~= 3221515245 then return end
	--print("Reroll")
	Reroll()
end)

MainFrame.X_Close.Activated:Connect(function()
	_G.CloseAll()
end)

local Functions = game.ReplicatedStorage:WaitForChild("Functions")
local GetMarketInfoByName = Functions:WaitForChild("GetMarketInfoByName")
local BuyEvent = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("Buy")
local GiftFolder = script.Parent.Parent.Parent:WaitForChild('CoreGameUI').Gift
local GiftFrame = GiftFolder.GiftFrame
local SelectedGiftId = GiftFolder.SelectedGiftId

local function NewTokenUI(ui)
	local BuyButton = ui.Contents:WaitForChild("Buy")
	local GiftButton = ui.Contents:WaitForChild("Gift")

	local Info = GetMarketInfoByName:InvokeServer(ui.Name) --Market.GetInfoOfName(ui.Name)

	BuyButton.MouseButton1Down:Connect(function()
		BuyEvent:FireServer(Info.Id)
	end)

	GiftButton.MouseButton1Down:Connect(function()
		SelectedGiftId.Value = Info.GiftId
		GiftFrame.Visible = true
	end)
end

for _, ui in MainFrame.Parent.Side_Shop.Contents:GetChildren() do
	if not ui:FindFirstChild("Contents") then continue end
	NewTokenUI(ui)
end

local Zone = require(ReplicatedStorage.Modules.Zone)
local Container = workspace:WaitForChild('Willpower'):WaitForChild('Willpower'):WaitForChild("Hitbox")
local zone = Zone.new(Container)

zone.playerEntered:Connect(function(plr)
	if plr == player then
		UIHandlerModule.DisableAllButtons()
		_G.CloseAll("WillpowerFrame")
		_G.CanSummon = false
		open = true

		local MythicalWillpowerPity = player:FindFirstChild("MythicalPityWP").Value
		player.PlayerGui.CoreGameUI.Willpower.WillpowerFrame.Frame.Pity_Bars.Mythical_Pity.Contents.Bar.Size = UDim2.fromScale(MythicalWillpowerPity/500,1)
		player.PlayerGui.CoreGameUI.Willpower.WillpowerFrame.Frame.Pity_Bars.Mythical_Pity.Contents.Pity.Text = MythicalWillpowerPity.."/"..500
	end
end)

zone.playerExited:Connect(function(plr)
	if plr == player then
		_G.CanSummon = true
		_G.traitTowerSelection = false
		_G.CloseAll()
		UIHandlerModule.EnableAllButtons()
	end
end)


