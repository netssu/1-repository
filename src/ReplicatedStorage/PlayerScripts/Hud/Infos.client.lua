------------------//SERVICES
local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris: Debris = game:GetService("Debris")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local IS_MOBILE: boolean = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local BASE_UI_SCALE: number = IS_MOBILE and 0.75 or 1
local ANIM_UI_SCALE: number = IS_MOBILE and 0.9 or 1.15
local FLY_COIN_SCALE_MAX: number = IS_MOBILE and 0.95 or 1.3

local STUDS_TO_METERS: number = 0.28
local COIN_ICON_ID: string = "rbxassetid://82346463581106"
local COIN_FLY_COUNT: number = 5
local COIN_FLY_SIZE: UDim2 = IS_MOBILE and UDim2.new(0, 24, 0, 24) or UDim2.new(0, 32, 0, 32)
local COIN_SPAWN_SPREAD: number = 80
local COIN_FLY_DURATION_MIN: number = 0.4
local COIN_FLY_DURATION_MAX: number = 0.8
local COIN_DELAY_STAGGER: number = 0.03

------------------//VARIABLES
local NotificationUtility = require(ReplicatedStorage.Modules.Utility.NotificationUtility)
local MathUtility = require(ReplicatedStorage.Modules.Utility.MathUtility)
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local PogoData = require(ReplicatedStorage.Modules.Datas.PogoData)
local PopupModule = require(ReplicatedStorage.Modules.Libraries.PopupModule)

local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

local oldUiFolder: ScreenGui = playerGui:WaitForChild("UI")
local hud: Frame = oldUiFolder:WaitForChild("GameHUD")
local infosFrame: Frame = hud:WaitForChild("Infos")
local numbersFrame: Frame = infosFrame:WaitForChild("Numbers")

local newGuiFolder: ScreenGui = playerGui:WaitForChild("GUI")

local coinsFrame: Frame = numbersFrame:WaitForChild("Coins")
local moneyLabel: TextLabel = coinsFrame:WaitForChild("TextLabel")
local moneyScale: UIScale = coinsFrame:FindFirstChild("UIScale")

local heightLabel: TextLabel = infosFrame:WaitForChild("Height")

local rbFrame: Frame = numbersFrame:WaitForChild("RB")
local rebirthLabel: TextLabel = rbFrame:WaitForChild("TextLabel")
local rebirthScale: UIScale = rbFrame:FindFirstChild("UIScale") :: UIScale

local character: Model = player.Character or player.CharacterAdded:Wait()
local rootPart: BasePart = character:WaitForChild("HumanoidRootPart")
local humanoid: Humanoid = character:WaitForChild("Humanoid")

local camera: Camera = workspace.CurrentCamera

local currentCoins: number = 0
local currentRebirths: number = 0

local displayCoinsValue = Instance.new("NumberValue")
local displayRebirthsValue = Instance.new("NumberValue")

local activeMoneyTweens: {[string]: Tween} = {}
local activeRebirthTweens: {[string]: Tween} = {}

local notifiedPogos: {[string]: boolean} = {}

------------------//FUNCTIONS
if not rebirthScale then
	rebirthScale = Instance.new("UIScale")
	rebirthScale.Scale = BASE_UI_SCALE
	rebirthScale.Parent = rbFrame
else
	rebirthScale.Scale = BASE_UI_SCALE
end

if not moneyScale then
	moneyScale = Instance.new("UIScale")
	moneyScale.Scale = BASE_UI_SCALE
	moneyScale.Parent = coinsFrame
else
	moneyScale.Scale = BASE_UI_SCALE
end

displayCoinsValue.Changed:Connect(function(val)
	moneyLabel.Text = tostring(MathUtility.format_number(math.floor(val)))
end)

displayRebirthsValue.Changed:Connect(function(val)
	rebirthLabel.Text = tostring(MathUtility.format_number(math.floor(val)))
end)

local function format_short(value: number): string
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(math.floor(value))
end

local function set_money_text(value: number): ()
	TweenService:Create(displayCoinsValue, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = value}):Play()
end

local function set_rebirth_text(value: number): ()
	TweenService:Create(displayRebirthsValue, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = value}):Play()
end

local function update_height(): ()
	if not rootPart or not humanoid then return end

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	params.FilterType = Enum.RaycastFilterType.Exclude

	local hit = workspace:Raycast(rootPart.Position, Vector3.new(0, -10000, 0), params)
	local heightStuds = 0
	if hit then
		local offset = humanoid.HipHeight + (rootPart.Size.Y / 2)
		heightStuds = hit.Distance - offset
	end

	heightStuds = math.max(heightStuds, 0)
	local heightMeters = math.floor(heightStuds * STUDS_TO_METERS)
	heightLabel.Text = tostring(heightMeters) .. " m"
end

local function get_world_to_screen_pos(): Vector2?
	if not rootPart then return nil end
	local screenPos, onScreen = camera:WorldToScreenPoint(rootPart.Position + Vector3.new(0, 3, 0))
	if onScreen then
		return Vector2.new(screenPos.X, screenPos.Y)
	end
	return nil
end

local function get_coin_target(): Vector2
	local pos = coinsFrame.AbsolutePosition
	local size = coinsFrame.AbsoluteSize
	return Vector2.new(pos.X + size.X - 35, pos.Y + size.Y + 15)
end

local function spawn_gain_label(amount: number): ()
	local txt = Instance.new("TextLabel")
	txt.Name = "GainLabel"
	txt.Text = "+" .. format_short(amount)
	txt.Font = Enum.Font.FredokaOne
	txt.TextSize = IS_MOBILE and 20 or 28
	txt.TextColor3 = Color3.fromRGB(150, 255, 150)
	txt.BackgroundTransparency = 1
	txt.AnchorPoint = Vector2.new(0.5, 0.5)

	local target = get_coin_target()
	txt.Position = UDim2.new(0, target.X, 0, target.Y + 10)
	txt.Parent = oldUiFolder

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(0, 60, 0)
	stroke.Parent = txt

	local pScale = Instance.new("UIScale")
	pScale.Scale = 0
	pScale.Parent = txt

	TweenService:Create(pScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	TweenService:Create(txt, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, target.X, 0, target.Y + 50),
		TextTransparency = 1
	}):Play()

	TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1
	}):Play()

	Debris:AddItem(txt, 1.5)
end

local function spawn_flying_coins(): ()
	local startScreenPos = get_world_to_screen_pos()
	if not startScreenPos then
		local viewportSize = camera.ViewportSize
		startScreenPos = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	end

	local targetPos = get_coin_target()

	for i = 1, COIN_FLY_COUNT do
		task.delay((i - 1) * COIN_DELAY_STAGGER, function()
			local coin = Instance.new("ImageLabel")
			coin.Name = "FlyingCoin"
			coin.Image = COIN_ICON_ID
			coin.BackgroundTransparency = 1
			coin.Size = COIN_FLY_SIZE
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.ZIndex = 100

			local offsetX = math.random(-COIN_SPAWN_SPREAD, COIN_SPAWN_SPREAD)
			local offsetY = math.random(-COIN_SPAWN_SPREAD, COIN_SPAWN_SPREAD)
			local spawnPos = UDim2.new(0, startScreenPos.X + offsetX, 0, startScreenPos.Y + offsetY)
			coin.Position = spawnPos
			coin.Rotation = math.random(-30, 30)

			local coinScale = Instance.new("UIScale")
			coinScale.Scale = 0
			coinScale.Parent = coin

			coin.Parent = oldUiFolder

			local popIn = TweenService:Create(coinScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = FLY_COIN_SCALE_MAX })
			popIn:Play()
			popIn.Completed:Wait()

			TweenService:Create(coinScale, TweenInfo.new(0.05), { Scale = BASE_UI_SCALE }):Play()

			local flyDuration = COIN_FLY_DURATION_MIN + math.random() * (COIN_FLY_DURATION_MAX - COIN_FLY_DURATION_MIN)
			local targetUDim = UDim2.new(0, targetPos.X, 0, targetPos.Y)

			local flyTween = TweenService:Create(coin, TweenInfo.new(flyDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = targetUDim,
				Rotation = 0,
			})

			local shrinkTween = TweenService:Create(coinScale, TweenInfo.new(flyDuration * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.5 })

			flyTween:Play()
			task.delay(flyDuration * 0.5, function()
				shrinkTween:Play()
			end)

			flyTween.Completed:Connect(function()
				coin:Destroy()
			end)

			Debris:AddItem(coin, flyDuration + 0.5)
		end)
	end
end

local function animate_element(scaleObj: UIScale, store: {[string]: Tween}): ()
	if store["scale"] then store["scale"]:Cancel() end

	scaleObj.Scale = ANIM_UI_SCALE

	local tScale = TweenService:Create(scaleObj, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Scale = BASE_UI_SCALE })
	store["scale"] = tScale
	tScale:Play()
end

local function check_pogo_availability(): ()
	local ownedPogos = DataUtility.client.get("OwnedPogos") or {}
	local sortedPogos = PogoData.GetSortedList()

	for _, pogo in ipairs(sortedPogos) do
		if ownedPogos[pogo.Id] or notifiedPogos[pogo.Id] then
			continue
		end

		local price = pogo.Price or 0
		local reqRebirths = pogo.RequiredRebirths or 0

		if currentCoins >= price and currentRebirths >= reqRebirths then
			notifiedPogos[pogo.Id] = true

			if pogo.Name == "Basic Pogo" then
				return
			end

			NotificationUtility:Action(
				pogo.Name .. " is now available!",
				"OPEN",
				function()
					local vendorFrame = newGuiFolder:FindFirstChild("VendorFrame")
					if vendorFrame then
						vendorFrame.Visible = true
					end
				end,
				5
			)
		end
	end
end

local function update_money_visuals(newAmount: number): ()
	local diff = newAmount - currentCoins
	if diff > 0 and currentCoins > 0 then
		spawn_flying_coins()
		spawn_gain_label(diff)
		animate_element(moneyScale, activeMoneyTweens)

		local text = "+" .. format_short(diff)
		local isLarge = diff >= 1000
		local popFontSize = IS_MOBILE and (isLarge and 40 or 30) or (isLarge and 55 or 45)
		
		PopupModule.Create(rootPart, text, Color3.fromRGB(255, 204, 0), {
			Duration = 1.2,
			Direction = Vector3.new(-(math.random(1, 2)), math.random(-1, 1), 0),
			StartOffset = Vector3.new(0, 0, 0),
			Spread = 1,
			IsCritical = isLarge,
			FontSize = popFontSize,
		})
	end
	currentCoins = newAmount
	set_money_text(newAmount)
	check_pogo_availability()
end

local function update_rebirth_visuals(newVal: number): ()
	if newVal == currentRebirths then return end

	if newVal > currentRebirths then
		animate_element(rebirthScale, activeRebirthTweens)
	end

	currentRebirths = newVal
	set_rebirth_text(newVal)
end

------------------//INIT
DataUtility.client.ensure_remotes()

player.CharacterAdded:Connect(function(newChar: Model)
	character = newChar
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	humanoid = newChar:WaitForChild("Humanoid")
end)

RunService.RenderStepped:Connect(update_height)

local initialCoins = DataUtility.client.get("Coins") or 0
currentCoins = initialCoins
displayCoinsValue.Value = initialCoins
moneyLabel.Text = tostring(MathUtility.format_number(math.floor(initialCoins)))

local initialRebirths = DataUtility.client.get("RebirthTokens") or 0
currentRebirths = initialRebirths
displayRebirthsValue.Value = initialRebirths
rebirthLabel.Text = tostring(MathUtility.format_number(math.floor(initialRebirths)))

DataUtility.client.bind("Coins", update_money_visuals)
DataUtility.client.bind("RebirthTokens", update_rebirth_visuals)

task.spawn(function()
	local ownedPogos = DataUtility.client.get("OwnedPogos") or {}
	local sortedPogos = PogoData.GetSortedList()

	for _, pogo in ipairs(sortedPogos) do
		local price = pogo.Price or 0
		local reqRebirths = pogo.RequiredRebirths or 0

		if ownedPogos[pogo.Id] or (currentCoins >= price and currentRebirths >= reqRebirths) then
			notifiedPogos[pogo.Id] = true
		end
	end
end)