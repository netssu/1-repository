local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopZone = ReplicatedStorage.Remotes.Prestige.PrestigeShop
local PrestigeZone = ReplicatedStorage.Remotes.Prestige.Prestige
local LocalPlayer = game:GetService("Players").LocalPlayer
local PlayerGUI = LocalPlayer.PlayerGui
local ShopGUI = script.Parent.Parent.PrestigeShop.PrestigeShopFrame

local CurrencyLabel = ShopGUI.Frame.Contents.Currency.Amount
local PrestigeFunctions = require(script.PrestigeModule)
local PrestigeHandling = require(ReplicatedStorage.Prestige.Main.PrestigeHandling)
local ShopX = ShopGUI.Frame.X_Close
local Character = LocalPlayer.Character
local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
local TeleportOutShop = workspace:WaitForChild("PrestigeShop"):WaitForChild("TeleportOut")
local AllFunc = require(ReplicatedStorage.Modules.VFX_Helper)
local Message = ReplicatedStorage.Events.Client:WaitForChild("Message")
local WasMessage = false
local Player = game.Players.LocalPlayer
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

local PrestigeGUI = PlayerGUI:WaitForChild('CoreGameUI').Prestige.PrestigeFrame
local PrestigeX = PrestigeGUI.Frame.X_Close
local TeleportOutPS = workspace:WaitForChild("Prestige"):WaitForChild("TeleportOut")
local CurrentPrestigeLabel = PrestigeGUI.Frame.Contents.Current_Prestige.Contents.Prestige_Tier
local CurrentLevel = PrestigeGUI.Frame.Contents["Text Frame"].Current_Level
local PrestigeButton = PrestigeGUI.Frame.Contents["Prestige!"]
local Prestige = LocalPlayer:WaitForChild("Prestige")
local Level = LocalPlayer:FindFirstChild("PlayerLevel")
local Title = PrestigeGUI.Frame.Contents.Title
local Locked = PrestigeButton.Contents.Locked
local Bar = PrestigeGUI.Frame.Contents.Prestige_Frame.Bar
local LuckBoost = PrestigeGUI.Boosts.Luck
local XPBoost = PrestigeGUI.Boosts.XPBoost


local ShopModule = require(ReplicatedStorage.ShopSystem)
local ShopUnit = ReplicatedStorage.Remotes.ShopUnit
local BuyButton = ShopGUI.Frame.Contents.Selection
local ShopFrame = ShopGUI.Frame.Contents.Prestige_Frame
local ButtonsHolder = ShopFrame.Bar
local CurrencyCongratsLabel = PlayerGUI.GameGui.PRShop.Success
local PrestigeTokenChanged = ReplicatedStorage.Remotes.Prestige.PrestigeTokenChanged
local ErrorFrame = PlayerGUI.GameGui.PRShop.Error
local Prompt = PlayerGUI.CoreGameUI.Prompt.Prompt
local Break = false

local debounce = {
	TraitPoint = false,
	ExtraStorage = false,
	VIP = false,
	["2x Speed"] = false,
	LuckySpins = false,
	["Display 3 Units"] = false,
	["3x Speed"] = false,
	LuckyWillpower = false,
	["Robux Unit"] = false,
	["Robux Unit (Shiny)"] = false,
}




local function SetupViewPorts()
	local viewData = {
		["Dart Wader Maskless"] = ButtonsHolder["Robux Unit"],	
	}
	
	local ViewExtraData = {
		["Dart Wader Maskless"] = ButtonsHolder["Robux Unit (Shiny)"]
	}
	
	-- Clear Image property before setting up viewports
	 ButtonsHolder["Robux Unit"].Contents.Icon.Image = ""
	ButtonsHolder["Robux Unit (Shiny)"].Contents.Icon.Image = ""
	 

	for itemName, iconFrame in pairs(viewData) do
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = iconFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end
	
	
	
	for itemName, iconFrame in pairs(ViewExtraData) do
		local viewport = ViewPortModule.CreateViewPort(itemName)
		viewport.Parent = iconFrame
		viewport.Size = UDim2.new(1, 0, 1, 0)
	end
	
	
end


local selectedItem = nil

local function ShopGiver(Type, Name, Quantity)
	if Type == false and Name == false and Quantity == false then
		_G.Message("Error when purchasing", Color3.new(1, 0.0941176, 0.0941176))
		return
	end

	if Type == "Gamepass" and Name == false and Quantity == false then
		_G.Message("You already own the gamepass", Color3.new(1, 0.0941176, 0.0941176))
		return
	end

	if (Type == "Currency" or Type == "Item" or Type == "Gamepass" or Type == "Unit") then
		_G.Message(tostring(Quantity) .. " x " .. Name.Name .. " Earned!", Color3.new(0, 1, 0), "Success")
	end
end

local function HandleButton(itemName)
	if debounce[itemName] then return end
	debounce[itemName] = true

	selectedItem = itemName
	Prompt.Visible = true

	task.wait(1)
	debounce[itemName] = false
end

Prompt.Vote_Skip.Contents.Options.Yes.Activated:Connect(function()
	if selectedItem then
		Prompt.Visible = false
		ShopUnit:FireServer(selectedItem)
		selectedItem = nil
	end
end)

Prompt.Vote_Skip.Contents.Options.No.Activated:Connect(function()
	Prompt.Visible = false
	selectedItem = nil
end)

ShopZone.Event:Connect(function(vision)
	SetupViewPorts()
	ShopGUI.Visible = vision
	local currency = Player:FindFirstChild("PrestigeTokens")
	PrestigeHandling.CalculatePrestigeCurrency(CurrencyLabel, currency.Value)

	-- Connect buttons to purchase handlers
	ButtonsHolder.LuckySummons.Activated:Connect(function()
		HandleButton("LuckySpins")
	end)

	ButtonsHolder.Display.Activated:Connect(function()
		HandleButton("Display 3 Units")
	end)

	ButtonsHolder.Storage.Activated:Connect(function()
		HandleButton("Extra Storage")
	end)

	ButtonsHolder.VIP.Activated:Connect(function()
		HandleButton("VIP")
	end)

	ButtonsHolder["2X"].Activated:Connect(function()
		HandleButton("2x Speed")
	end)

	ButtonsHolder.Traits.Activated:Connect(function()
		HandleButton("TraitPoint")
	end)

	ButtonsHolder["3x Speed"].Activated:Connect(function()
		HandleButton("3x Speed")
	end)

	ButtonsHolder.LuckyWillpower.Activated:Connect(function()
		HandleButton("LuckyWillpower")
	end)

	
	ButtonsHolder["Robux Unit"].Activated:Connect(function()
		HandleButton("Dart Wader Maskless")
	end)

	ButtonsHolder["Robux Unit (Shiny)"].Activated:Connect(function()
		HandleButton("Shiny Dart Wader Maskless")
	end)

	currency:GetPropertyChangedSignal("Value"):Connect(function()
		PrestigeTokenChanged:FireServer(Player)
		PrestigeTokenChanged.OnClientEvent:Connect(function(value)
			CurrencyLabel.Text = value
		end)
	end)
end)

ShopUnit.OnClientEvent:Connect(function(Type, Name, Quantity)
	ShopGiver(Type, Name, Quantity)
end)

ShopX.Activated:Connect(function()
	print("Working")
	print(HumanoidRootPart)
	Character:PivotTo(TeleportOutShop.CFrame)
	ShopGUI.Visible = false
end)



PrestigeZone.Event:Connect(function(vision)
	if vision then
		_G.CloseAll('Prestige')
	else
		_G.CloseAll()
	end
	
	--PrestigeGUI.Visible = vision
	print(Prestige.Value)
	CurrentPrestigeLabel.Text = "Prestige " .. Prestige.Value
	CurrentLevel.Text = "Level " .. Level.Value
	local RequireLevel = PrestigeHandling.PrestigeRequirements[Prestige.Value + 1]
	Title.Text = "Reach Level " .. tostring(RequireLevel) .. " To Prestige"
	local success = PrestigeHandling.CanPrestige(LocalPlayer)
	
	print(success)
	
	if success then
		Locked.Visible = false
	end
	
	local XPBoostValue = (1 + (Prestige.Value * 10)/100)
	XPBoost.Text = "Current XP Multiplier: " .. "x".. tostring(XPBoostValue)
	
	local LuckBoostValue = Prestige.Value * 1.6
	local formattedLuck = string.format("%.1f%%", LuckBoostValue)
	LuckBoost.Text = "Current Luck Multiplier: ".. "x".. formattedLuck .. "%"
	
	
	local yellowStrokeGradient = script.YellowStrokeGradient
	local YellowGradient = script.YellowGradient
	local redGradient = script.RedUIGradient
	local redStroke = script.RedUIStroke
	local greenStroke = script.GreenUIStroke			
	local green = script.GreenGradient
	
	
	
	local unlocked = 0
	for _, v in ipairs(Bar:GetChildren()) do
		if v:IsA("Frame") then
			unlocked += 1
			if unlocked <= Prestige.Value then
				v.Locked.Visible = false
				if v.Name == "Prestige_Preview1" then
					local Prestige1G = greenStroke:Clone()
					v.Contents.UIStroke.Enabled = false
					v.Contents.YellowGradient.Enabled = false
					Prestige1G.Parent = v.Contents
					local Prestige1GB = green:Clone()
					Prestige1GB.Parent = v.Contents
					v.Obtained.Visible = true
					continue
				end
				local PrestigeG = greenStroke:Clone()
				local PrestigeGB = green:Clone()
				v.Contents.UIGradient.Enabled = false
				v.Contents.UIStroke.Enabled = false
				PrestigeG.Parent = v.Contents
				PrestigeGB.Parent = v.Contents
				v.Obtained.Visible = true
			elseif unlocked == Prestige.Value + 1 then
				v.Locked.Visible = false
				local Prestige1Y = YellowGradient:Clone()
				local Prestige1S = yellowStrokeGradient:Clone()
				v.Contents.UIStroke.Enabled = true
				v.Contents.UIStroke.UIGradient.Color = ColorSequence.new(Color3.fromRGB(255, 234, 0))
				Prestige1Y.Parent = v.Contents
				Prestige1S.Parent = v.Contents.UIStroke
				v.Obtained.Visible = false
			else
				break
			end
		end
	end


	
	
end)


PrestigeX.Activated:Connect(function()
	PrestigeGUI.Visible = false
	Character:PivotTo(TeleportOutPS.CFrame)
end)


local CalculateServer = ReplicatedStorage.Remotes.Prestige.PrestigeCalculate
local PrestigeReset = ReplicatedStorage.Remotes.Prestige.PrestigeReset
PrestigeButton.Activated:Connect(function()
	if Locked.Visible == true then
		return
	else
		print("Activated")
		local CanPrestige = false
		
		local value = AllFunc.HaveEquipUnits(LocalPlayer)
		if not value then
			CanPrestige = true
		
		else
			if not WasMessage  then
				WasMessage = true
				task.spawn(function()
					task.wait(1)
					WasMessage = false
				end)
				_G.Message("Must Have All Your Units Unequipped", Color3.new(1, 0, 0))
			end
		end
		
		
		
		if CanPrestige then
			CalculateServer:FireServer(LocalPlayer)
		end
	end
end)

Prestige:GetPropertyChangedSignal("Value"):Connect(function()
	PrestigeReset:FireServer(LocalPlayer)
	task.wait(0.1)
	PrestigeGUI.Visible = false
	 Character:PivotTo(TeleportOutPS.CFrame)
	local TweenService = game:GetService("TweenService")
	local SuccessLabel = script.Parent.Success

	SuccessLabel.Text = "Prestige " .. Prestige.Value .. " Unlocked!\n" .. LocalPlayer:FindFirstChild("PrestigeTokens").Value .. " " .. "Prestige Tokens Owned In Total"
	SuccessLabel.Visible = true
	SuccessLabel.TextTransparency = 0

	local fadeOutTween = TweenService:Create(
		SuccessLabel,
		TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 2), -- 2s delay before 2s fade
		{TextTransparency = 1}
	)

	fadeOutTween:Play()

end)



