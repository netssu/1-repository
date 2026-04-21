local UIS = game:GetService("UserInputService")
local MarketPlaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local Upgrades = require(ReplicatedStorage.Upgrades)
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local MarketModule = require(ReplicatedStorage.Modules.MarketModule)
local itemStatsModule = require(ReplicatedStorage:WaitForChild("ItemStats"))
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local GradientsModule = require(ReplicatedStorage.Modules.GradientsModule)
local ButtonAnimation = require(ReplicatedStorage.Modules.ButtonAnimation)
local Signal = require(ReplicatedStorage.Modules.Core.Signal)

--local cameraPos = CFrame.new(-66.1679077, 52.7778358, 63.0225792, 0.907316506, 0.129972085, -0.399854928, 0, 0.951020598, 0.30912742, 0.420448244, -0.280476421, 0.862876713)

local SummonFrame = script.Parent.SummonFrame
local ExitFrame = script.Parent.ExitFrame
local SkipFrame = script.Parent.SkipSummon
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local IndexButton = SummonFrame.Banner.Index
local ChancesFrame = SummonFrame.ChancesFrame
local SetAutoSellEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SetAutoSell")

local CS = ColorSequence.new
local CSK = ColorSequenceKeypoint.new
local C3 = Color3.new

local AutoSummon = false

local SecretUnit1 = "Anekan Skaivoker"
local SecretUnit2 = "Palpotin"

_G.canSummon = true

local player = game.Players.LocalPlayer
player:WaitForChild("DataLoaded")

local GemsPriceSingle = 50
local GemsPriceT = 450

local ScaleMulti = 0.8

local towerViewFolder = Instance.new("Folder")
towerViewFolder.Name = "TowerView"
towerViewFolder.Parent = workspace.Camera
local skipConn

local FrameForViewport = SummonFrame.Banner.Contents
local CurrentHour = workspace.CurrentHour

local SummonNPC = workspace:WaitForChild("SummonNPC")
local SummonNPCNames = {"Mythical1","Mythical2","Mythical3"}
local Rarities = {"Secret","Mythical","Legendary","Epic","Rare"}

--warn('XO1')

local function updateBanner()
	--warn("Attribute changed.")
	for i, v in workspace.SummonNPC:GetChildren() do
		local folder = v:FindFirstChildOfClass("Folder")
		if folder then
			folder:ClearAllChildren()
		end
	end

	for _, Rarity in SummonNPCNames do
		local Model:Model = GetUnitModel[game.Workspace.CurrentHour:GetAttribute(Rarity)]:Clone()
		local Scale = Model:GetScale()
		Model:ScaleTo(Scale * ScaleMulti)
		local HRP = Model:WaitForChild("HumanoidRootPart")
		local Humanoid:Humanoid = Model:WaitForChild("Humanoid")
		local animations = Model:FindFirstChild("Animations")
		HRP.Anchored = true
		if HRP and Humanoid then
			pcall(function()
				
				HRP.CFrame = SummonNPC[Rarity]:WaitForChild("PositionPart").CFrame
				Model.Parent = SummonNPC[Rarity].Unit
				local animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)

				if animations then
					local track = animator:LoadAnimation(Model.Animations.Idle)
					track:Play()
					track:Destroy()
				end
			end)
		end
	end

	for i=1, 3 do
		if game.Workspace.CurrentHour:GetAttribute("Mythical"..i) ~= "" and game.Workspace.CurrentHour:GetAttribute("Mythical"..i) ~= nil then
			if GetUnitModel[game.Workspace.CurrentHour:GetAttribute("Mythical"..i)] then
				local FoundVp = FrameForViewport["Unit"..i]:FindFirstChildOfClass("ViewportFrame")
				if FoundVp then
					FoundVp:Destroy()
					--warn("Found vp wipe it")
				else
					--warn("Not Found vp")
				end

				local vp = ViewPortModule.CreateViewPort(game.Workspace.CurrentHour:GetAttribute("Mythical"..i))
				vp.Parent = FrameForViewport["Unit"..i]
				--FrameForViewport["Unit"..i].TextFrame.UnitName.Text = game.Workspace.CurrentHour:GetAttribute("Mythical"..i)

				FrameForViewport['UnitDesc'..i].Text.name.Text = game.Workspace.CurrentHour:GetAttribute("Mythical"..i)

				--vp.ZIndex = if i == 3 then 3 else FrameForViewport["Unit"..i].ZIndex
				vp.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.1,1))

				GradientsModule.addRarityGradient({FrameForViewport['UnitDesc'..i].Text.Rarity},"Mythical")
				--script.Parent.Parent.Parent.BannerSurfaceGui.BannerFrame[`Unit{i}`]:ClearAllChildren()
				--local vp2 = vp:Clone()
				--script.Parent.Parent.Parent.BannerSurfaceGui.BannerFrame[`Unit{i}`]:ClearAllChildren()
			end
		end
	end

	local FoundVp = FrameForViewport.SecretUnit1:FindFirstChildOfClass("ViewportFrame")
	if FoundVp then
		FoundVp:Destroy()
	end
	local FoundVp2 = FrameForViewport.SecretUnit2:FindFirstChildOfClass("ViewportFrame")
	if FoundVp2 then
		FoundVp2:Destroy()
	end
	local vp = ViewPortModule.CreateViewPort(SecretUnit1)
	vp.Parent = FrameForViewport.SecretUnit1
	vp.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.3,1) * CFrame.Angles(0,math.rad(180),0) )
	vp.ZIndex = 1
	vp.Ambient = Color3.new(0,0,0)
	vp.LightColor = Color3.new(0,0,0)

	local vp2 = ViewPortModule.CreateViewPort(SecretUnit2)
	vp2.Parent = FrameForViewport.SecretUnit2
	vp2.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp2.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.3,1) * CFrame.Angles(0,math.rad(180),0) )
	vp2.ZIndex = 1
	vp2.Ambient = Color3.new(0,0,0)
	vp2.LightColor = Color3.new(0,0,0)
end

game.Workspace.CurrentHour.AttributeChanged:Connect(updateBanner)

local EvoUnits = {}

for _, unit in Upgrades do
	if unit.Evolve and unit.Evolve.EvolvedUnit then
		EvoUnits[unit.Evolve.EvolvedUnit] = true
	end
end

for _, rarity in Rarities do
	local Scroll = ChancesFrame.ScrollingFrame
	GradientsModule.addRarityGradient({Scroll[rarity].TitleBar,Scroll[rarity].TitleBar.UIStroke,Scroll[rarity].TitleBar.ImageCover,Scroll[rarity].TitleBar.TextLabel,Scroll[rarity].TitleBar.Percent},rarity,true)
end

--warn('XO2')

local blackList = {
	'Asaka Tano',
    'Asaka Tano (Outcast)',
	'Egg Bane',
	'Cad Bunny',
	--TEMP
	'Quinion Vas',
	'Tenth Brother',
	"Sixth Brother",
	"Sith Trooper",
	"Dart Wader Maskless",
}

for _, unit in Upgrades do
	if not EvoUnits[unit.Name] and not table.find(blackList, unit.Name) then
		if unit.Rarity == "Exclusive" then continue end
		local template = script.TemplateButton:Clone()
		template.Name = unit.Name
		template.Parent = ChancesFrame.ScrollingFrame[unit.Rarity].UnitHolder
		
		

        --print(unit.Name)
		local vp = ViewPortModule.CreateViewPort(unit.Name)
		
		if not vp then
			--warn("Failed to create viewport for:", unit.Name)
			continue
		end
		
		vp.ZIndex = 6
		vp.Parent = template

		ButtonAnimation.unitButtonAnimation(template)

		if unit.Rarity == "Secret" then
			vp.LightColor = Color3.new(0,0,0)
			vp.Ambient = Color3.new(0,0,0)
			GradientsModule.addRarityGradient({template.Image,template.GlowEffect,template:FindFirstChildOfClass("ViewportFrame")},unit.Rarity)
		else
			GradientsModule.addRarityGradient({template.Image,template.GlowEffect},unit.Rarity)
		end

	end
end

--warn('XO3')

SummonFrame.Banner.X_Close.Activated:Connect(function()
	local chr = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
	if chr then
		chr:SetPrimaryPartCFrame(workspace.SummonTeleporters.TeleportOut.CFrame) 
		_G.CloseAll()
		UiHandler.EnableAllButtons()
	end
end)

local MedalLib = require(ReplicatedStorage.Modules.MedalLib)

local Lighting = game:GetService("Lighting")
local NewUIBlur = Lighting.NewUIBlur

local function summon(amount, HolocronSummon, isLucky)
	if not _G.canSummon then return end
	if not SummonFrame.Visible then return end

	if not player.TutorialWin.Value and not player.TutorialLossGemsClaimed.Value then
		if amount ~= 10 then return end -- can only summon 10 if not tut
		
		warn('Tut is not completed')
		player.Character:PivotTo(workspace:WaitForChild('TutorialTeleportOut').CFrame)
	end



	_G.canSummon = false

	local result = game.ReplicatedStorage.Functions.SummonBannerEvent:InvokeServer(amount, HolocronSummon, isLucky)
	if typeof(result) ~= "table" then
		_G.canSummon = true
		UiHandler.PlaySound("Error")
		_G.Message(result, Color3.fromRGB(221, 0, 0))
		return
	end

	local Skip = nil
	if not isLucky then
		Skip = player:WaitForChild("Settings"):WaitForChild("SummonSkip").Value
		SummonFrame.Visible = false

		if Skip then
			SkipFrame.UIScale.Scale = 0
			SkipFrame.Visible = true
			TweenService:Create(SkipFrame.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = 1}):Play()
		end
	end
	
	NewUIBlur.Enabled = false
	local conn = NewUIBlur.Changed:Connect(function()
		NewUIBlur.Enabled = false
	end)
	

	local templates = {}
	local traitDataCache = {}
	local shouldConfetti = false

	for towerindex, Data in result do
		local Unit = Data.Tower

		if Skip and Unit then
			local UnitStats = Upgrades[Unit.Name]
			if UnitStats then
				if UnitStats.Rarity == "Mythical" then
					shouldConfetti = true
				end

				local Template = SkipFrame.Frame.TemplateButton:Clone()
				Template.Name = Unit.Name
				Template.LayoutOrder = towerindex
				Template.Visible = true
				Template.Parent = SkipFrame.Frame
				Template.UIScale.Scale = 0

				local trait = Unit:GetAttribute("Trait")
				if trait and trait ~= "" then
					local traitInfo = traitDataCache[trait]
					if not traitInfo then
						traitInfo = TraitsModule.Traits[trait]
						traitDataCache[trait] = traitInfo
					end
					if traitInfo then
						Template.TraitIcon.Visible = true
						Template.TraitIcon.Image = traitInfo.ImageID
						Template.TraitIcon.UIGradient.Color = TraitsModule.TraitColors[traitInfo.Rarity].Gradient
						Template.TraitIcon.UIGradient.Rotation = TraitsModule.TraitColors[traitInfo.Rarity].GradientAngle
						TweenService:Create(Template.TraitIcon.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
					end
				end

				if Unit:GetAttribute("Shiny") then
					Template.Shiny.Visible = true
				end

				local isTraitMythical = false
				if trait and traitDataCache[trait] then
					local grade = {Rare = 1, Epic = 2, Legendary = 3, Mythical = 4, Unique = 5}
					isTraitMythical = (grade[traitDataCache[trait].Rarity] or 0) >= grade.Mythical
				end

				if Data.AutoSell and not Unit:GetAttribute("Shiny") and not isTraitMythical then
					Template.Sold.Visible = true
					TweenService:Create(Template.Sold.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
				end

				local ViewPort = ViewPortModule.CreateViewPort(Unit.Name)
				ViewPort.Parent = Template
				ViewPort.ZIndex = 7

				GradientsModule.addRarityGradient({Template.Image, Template.GlowEffect}, UnitStats.Rarity)
				table.insert(templates, Template)

				--MedalLib.triggerClip('UNIT_SUMMON', `{${UnitStats.Rarity}} {${Unit.Name}}`, {player}, {"SaveClip"}, {duration = 30})
			end
		elseif Skip and Data.Item then
			local item = Data.Item
			local Template = SkipFrame.Frame.TemplateButton:Clone()
			Template.Name = item.Name
			Template.LayoutOrder = towerindex
			Template.Visible = true
			Template.Parent = SkipFrame.Frame
			Template.UIScale.Scale = 0

			local ViewPort = ViewPortModule.CreateViewPort("Star")
			ViewPort.Parent = Template
			GradientsModule.addRarityGradient({Template.Image, Template.GlowEffect}, itemStatsModule.Star.Rarity)
			table.insert(templates, Template)
			shouldConfetti = true
		else
			local tower = Data.Tower
			if tower then
				UiHandler.PlaySound("Redeem")
				SummonFrame.Visible = false
				local Tower = GetUnitModel[tower.Name]
				local statsTower = Upgrades[tower.Name]

				local trait = tower:GetAttribute("Trait")
				local isTraitMythical = false
				if trait and trait ~= "" then
					local traitInfo = traitDataCache[trait]
					if not traitInfo then
						traitInfo = TraitsModule.Traits[trait]
						traitDataCache[trait] = traitInfo
					end
					local grade = {Rare = 1, Epic = 2, Legendary = 3, Mythical = 4, Unique = 5}
					isTraitMythical = (grade[traitInfo.Rarity] or 0) >= grade.Mythical
				end

				if Data.AutoSell and not tower:GetAttribute("Shiny") and not isTraitMythical then
					_G.Message("Unit Sold", Color3.fromRGB(255, 170, 0), true)
				end

				if Tower and statsTower then
					--MedalLib.triggerClip('UNIT_SUMMON', `{${statsTower.Rarity}} {${Tower.Name}}`, {player}, {"SaveClip"}, {duration = 30})
					if statsTower.Rarity == "Mythical" then
						shouldConfetti = true
					end

					local nextUnit = false
					ViewModule.Hatch({statsTower, tower, function() nextUnit = true end, true, AutoSummon})
					repeat task.wait() until nextUnit
				end
			elseif Data.Item then
				local item = Data.Item
				local nextItem = false
				shouldConfetti = true
				UiHandler.PlaySound("Redeem")
				SummonFrame.Visible = false
				ViewModule.Item({itemStatsModule.Star, item, function() nextItem = true end, "1", AutoSummon})
				repeat task.wait() until nextItem
			end
		end
	end

	if shouldConfetti then
		UiHandler.CreateConfetti()
	end

	--if Skip then
	--	task.wait(2)
	--end
	
	task.defer(function() -- 0.2, delay
		task.wait(0.2)
		for _, template in templates do
			local UIScale = template:FindFirstChild("UIScale")
			if UIScale then
				TweenService:Create(UIScale, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
			end
		end
	end)

	task.defer(function() -- 0.6
		task.wait(0.6)
				
		--warn('kaboom')
		
		if Skip then
			task.wait(1.5)
			TweenService:Create(SkipFrame.UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {Scale = 0}):Play()
		end

		for _, v in SkipFrame.Frame:GetChildren() do
			if v:IsA("TextButton") and v.Name ~= "TemplateButton" then
				v:Destroy()
			end
		end

		_G.canSummon = true
		SummonFrame.Visible = true

		if AutoSummon then
			summon(1, HolocronSummon)
		end
	end)
	
	if not ReplicatedStorage:FindFirstChild('SummonDone') then
		Instance.new('BoolValue', ReplicatedStorage).Name = 'SummonDone'
	end
	
	conn:Disconnect()
	conn = nil
	NewUIBlur.Enabled = true
end



local ForceSummon = ReplicatedStorage.Remotes.ForceSummon
local Functions = ReplicatedStorage.Functions
local summonBannerEvent = Functions:WaitForChild("SummonBannerEvent")

local autoSummonButton = SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Auto_Summon
local autoColorSeqBottom  = autoSummonButton.Contents.UIGradient.Color
local autoColorSeq = autoSummonButton.Contents.Contents.UIGradient.Color -- Track base color
local toggleColorSeqBottom = ColorSequence.new(Color3.new(0.462745, 0, 0)) -- Bottom part of the button (I suck at naming things)
local toggleColorSeq = ColorSequence.new(Color3.new(255,0,0)) -- Top part of the button


ForceSummon.OnClientEvent:Connect(function()
	--print('we have been forced to summon!')
	summon(1)
end)


SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Summon_1x.Activated:Connect(function() summon(1) end)
SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Summon_10x.Activated:Connect(function() summon(10) end)
SummonFrame.Banner.Summon_Holocron.Activated:Connect(function() summon(1,true) end)
SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Lucky_Summons.Activated:Connect(function() summon(1, nil, true) end)

ExitFrame.Trigger.Activated:Connect(function()
	AutoSummon = false
	ExitFrame.Visible = false
end)

autoSummonButton.Activated:Connect(function()
	ExitFrame.Visible = true

	AutoSummon = true
	summon(1)
end)



player:WaitForChild("MythicalPity").Changed:Connect(function()
	script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Bar.Size = UDim2.fromScale(player.MythicalPity.Value/400,1)
	script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Pity.Text = player.MythicalPity.Value.."/"..400

	--script.Parent.SummonFrame.Banner.Mythical.ProgressBar.Size = UDim2.new(player.MythicalPity.Value/400,0,1,0)
	--script.Parent.SummonFrame.Banner.Mythical.NumberLabel.Text = player.MythicalPity.Value.."/"..400
end)

player:WaitForChild("LegendaryPity").Changed:Connect(function()
	script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Bar.Size = UDim2.fromScale(player.LegendaryPity.Value/200,1)
	script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Pity.Text = player.LegendaryPity.Value.."/"..200
	-- 26/400

	--script.Parent.SummonFrame.Banner.Legendary.ProgressBar.Size = UDim2.new(player.LegendaryPity.Value/200,0,1,0)
	--script.Parent.SummonFrame.Banner.Legendary.NumberLabel.Text = player.LegendaryPity.Value.."/"..200
end)

task.wait(1)

script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Bar.Size = UDim2.fromScale(player.MythicalPity.Value/400,1)
script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Pity.Text = player.MythicalPity.Value.."/"..400

script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Bar.Size = UDim2.fromScale(player.LegendaryPity.Value/200,1)
script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Pity.Text = player.LegendaryPity.Value.."/"..200

task.wait(3)
updateBanner()

IndexButton.MouseButton1Down:Connect(function()

	_G.CloseAll()

	ChancesFrame.Visible = true

end)

--ChancesFrame.Close.MouseButton1Down:Connect(function()

--	ChancesFrame.Visible = false
--	_G.CloseAll("SummonFrame")
--end)

SummonFrame.Side_Shop.Contents.Lucky_Crystal.Contents.Buy.MouseButton1Down:Connect(function()
	MarketPlaceService:PromptProductPurchase(player,MarketModule.Items[1].ProductID)
end)
SummonFrame.Side_Shop.Contents["Fortunate Crystal"].Contents.Buy.MouseButton1Down:Connect(function()
	MarketPlaceService:PromptProductPurchase(player,MarketModule.Items[2].ProductID)
end)

local PassesList = require(ReplicatedStorage.Modules.PassesList)

local function findProductID(id)
	local result = nil

	for i,v in MarketModule.Gems do
		if v.Name == id then
			result = v.ProductID
			break
		end
    end
    
    if not result then
        if PassesList.Information[id] then
            result = PassesList.Information[id].Id
        end
    end

	return result
end

-- shop
for i,v in SummonFrame.Side_Shop.Contents:GetChildren() do
	if v:IsA('Frame') and not string.match(v.Name, "Crystal") then
		v.Contents.Buy.Activated:Connect(function()
			MarketPlaceService:PromptProductPurchase(player, findProductID(v.Name))
		end)
	end
end



function UpdateAutoSell()
	for _, rarityObject in player:WaitForChild("AutoSell"):GetChildren() do
		local rarityButton = SummonFrame.Banner.Sell_Menu.Select_Rarity:FindFirstChild(rarityObject.Name)
		if not rarityButton then continue end
		rarityButton.IsActive.Value = rarityObject.Value
		if rarityButton.IsActive.Value  then
			rarityButton.Contents.Lines.UIGradient.Enabled = false
			rarityButton.Contents.Lines.ImageColor3 = Color3.fromRGB(0,255,0)
		else
			rarityButton.Contents.Lines.UIGradient.Enabled = true
			rarityButton.Contents.Lines.ImageColor3 = Color3.fromRGB(255,255,255)
		end
	end
end

for _,object in SummonFrame.Banner.Sell_Menu.Select_Rarity:GetChildren() do
	if not object:IsA("GuiButton") then continue end
	object.Activated:Connect(function()
		object.IsActive.Value = not object.IsActive.Value
		--if object:FindFirstChild("ActiveImage") then
		if object.IsActive.Value  then
			object.Contents.Lines.UIGradient.Enabled = false
			object.Contents.Lines.ImageColor3 = Color3.fromRGB(0,255,0)
		else
			object.Contents.Lines.UIGradient.Enabled = true
			object.Contents.Lines.ImageColor3 = Color3.fromRGB(255,255,255)
		end
		--end
		SetAutoSellEvent:FireServer(object.Name, object.IsActive.Value)
	end)
end

player:WaitForChild("AutoSell").ChildAdded:Connect(UpdateAutoSell)
UpdateAutoSell()

MarketPlaceService.PromptProductPurchaseFinished:Connect(function(userID,productID,isPurchased)
	if not isPurchased then return end

	--if productID == 2659785711 then
	--	script.Sounds.Redeem:Play()
	--	local towerStats = Upgrades["Frenk"]
	--	ViewModule.Hatch({
	--		towerStats,
	--		game.Players.LocalPlayer.OwnedTowers:WaitForChild("Frenk")
	--	})
	--	_G.CloseAll()
	--	return
	--end

	--if productID == 2675907803 or 2678784918 or 2678786531 or 2678798950 then
	--	script.Sounds.Redeem:Play()
	--	local towerStats = Upgrades["Ice Man"]
	--	ViewModule.Hatch({
	--		towerStats,
	--		script.Units["Ice Man"]
	--	})
	--	_G.CloseAll()
	--	return
	--end

	local itemName do
		for _,info in MarketModule.Items do
			if info.ProductID == productID then
				itemName = info.Name
				break
			end
		end
	end

	if itemName == nil then return end
	local itemStats = itemStatsModule[itemName]
	ViewModule.Item({
		itemStats
	})

end)

local function numbertotime(number)
	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) %60
	local Seconds = math.floor(number % 60)

	if Mintus < 10 and Hours > 0 then
		Mintus = "0"..Mintus
	end

	if Seconds < 10 then
		Seconds = "0"..Seconds
	end

	if Hours > 0 then
		return `{Hours}:{Mintus}:{Seconds}`
	else
		return `{Mintus}:{Seconds}`
	end
end



local wasOpen = false
local onCooldown = false

local Zone = require(ReplicatedStorage.Modules.Zone)
local zone = Zone.new(workspace.SummonTeleporters.SummonArea)

--local zone = zone.fromRegion(workspace.SummonTeleporters.SummonArea.CFrame, workspace.SummonTeleporters.SummonArea.Size)

--warn('ACCTIVATEAHFUSAHDUIFAS')

zone.playerEntered:Connect(function(plr)
    if plr.Character:FindFirstChild('Humanoid') and plr == player then	
        if not game.Workspace.CurrentCamera:FindFirstChild("DepthOfField") then
            local depthOfField = Instance.new("DepthOfFieldEffect",game.Workspace.CurrentCamera)
		end
		
		print(plr.Name .. " entered")
        _G.CloseAll("SummonFrame")
        UiHandler.DisableAllButtons({'Exp_Frame','Units_Bar',"Currency","Level","SummonFrame"})
    end
end)
zone.playerExited:Connect(function(plr)
	if not plr then return end
	local character = plr.Character or plr.CharacterAdded:Wait()
	if not character then return end
	
	if character:FindFirstChild('Humanoid') and plr == player then	
        if game.Workspace.CurrentCamera:FindFirstChild("DepthOfField") then
            game.Workspace.CurrentCamera:FindFirstChild("DepthOfField"):Destroy()
        end
        _G.CloseAll()
        --ChancesFrame.Visible = false
        UiHandler.EnableAllButtons()
    end
end)



local function ChangeChances(multiplayer,rareChance)
	local NoLuckChances = {
		Mythical = 0.1,
		Legendary = 1,
		Epic = 14.6,
		Rare = 27.7,
	}
	for Rarity, Chance in NoLuckChances do
		for i, v in SummonFrame.Banner:GetDescendants() do
			if v.Name == Rarity.."Chance" then
				if multiplayer ~= nil then
					if v.Name == "MythicalChance" and multiplayer == 1.5 then
						v.Text = 0.15 .. "%"
					else
						if v.Name ~= "RareChance" then
							v.Text = Chance * multiplayer .. "%"
						else
							v.Text = rareChance .. "%"
						end
					end
				else
					v.Text = Chance .. "%"
				end
			end
		end
	end
end

while true do
    task.wait(2)
	if player.Items["Holocron Summon Cube"].Value > 0 then
		SummonFrame.Banner.Summon_Holocron.Visible = true
	else
		SummonFrame.Banner.Summon_Holocron.Visible = false
	end
	--local minutes = math.floor(secondsDifference / 60)
	--local seconds = secondsDifference % 60
	if player.OwnGamePasses.VIP.Value == true then
		SummonFrame.Banner.PriceLabel.Text = 40
	end
	if player.OwnGamePasses["Ultra VIP"].Value == true then
		SummonFrame.Banner.PriceLabel.Text = 35
	end
	local untilNextHourToSeconds =  ( (math.floor( os.time()/1800 ) + 1) * 1800 ) - os.time()
	local currentMinutePerHour = math.floor(untilNextHourToSeconds/60)

	local seconds = math.floor( untilNextHourToSeconds % 60 ) 

	--SummonFrame.Banner["Banner Timer"].Text = `Refreshes in: {currentMinutePerHour}:{string.format("%.2i",seconds)}`
	SummonFrame.Banner.Contents.Refresh_Bar.Contents.Timer.Text = `{currentMinutePerHour}:{string.format("%.2i",seconds)}`

	script.Parent.Buffs.Visible = true
	for i, v in script.Parent.Buffs:GetChildren() do
		if v:IsA("ImageLabel") and player.Buffs:FindFirstChild(v.Name) then
			--warn('VIBE CHECK THEY HAVE IT!' .. v.Name)
			local buff = player.Buffs:FindFirstChild(v.Name)
			local duration = numbertotime(math.max((buff.StartTime.Value + buff.Duration.Value) - os.time(),0))
			v.BuffText.Text = `x{buff.Multiplier.Value}: {duration}`
			if v.Visible == false then
				v.Visible = true
			end
		elseif v:IsA("ImageLabel") and not player.Buffs:FindFirstChild(v.Name) then
			if v.Visible == true then
				v.Visible = false
			end
		end
	end
    local Buffs = script.Parent.Buffs
    local LuckText = SummonFrame.Banner.LuckText
    local Colors = script.LuckTextColors

    local activeBuffs = {
        {
            name = "LuckyCrystal",
            multiplier = 1.5,
            chance = 25.1,
            text = "x1.5 Luck",
            gradient = Colors.LuckyCrystalG.Color,
            stroke = Colors.LuckyCrystalS.Color,
        },
        {
            name = "FortunateCrystal",
            multiplier = 2,
            chance = 22.5,
            text = "x2 Luck",
            gradient = Colors.UltraLuckG.Color,
            stroke = Colors.UltraLuckS.Color,
        },
    }

    local totalMultiplier = 1
    local selectedBuff = nil

    for _, buff in ipairs(activeBuffs) do
        if Buffs[buff.name].Visible then
            totalMultiplier *= buff.multiplier
            if not selectedBuff or buff.multiplier > selectedBuff.multiplier then
                selectedBuff = buff
            end
        end
    end

    if selectedBuff then
        -- Adjust chance however you want; here just using the chance from the most powerful buff
		ChangeChances(totalMultiplier, selectedBuff.chance)
		
		if player.OwnGamePasses['x2 Luck'].Value then
			totalMultiplier += 1
		end
		
        LuckText.Text = "x" .. totalMultiplier .. " Luck"
        LuckText.UIGradient.Color = selectedBuff.gradient
        LuckText.UIStroke.Color = selectedBuff.stroke
    else
        ChangeChances(nil)
        
        if player.OwnGamePasses['x2 Luck'].Value then
            LuckText.Text = "x2 Luck"
        else
            LuckText.Text = "x1 Luck"
        end
        
        LuckText.UIGradient.Color = CS{CSK(0, C3(.75, .75, .75)), CSK(1, C3(1, 1, 1))}
        LuckText.UIStroke.Color = Color3.new(0.494118, 0.494118, 0.494118)
    end

end