-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local COLORS = {
	OWNED = {
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 150, 150)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 80))
		},
		InnerStroke = Color3.fromRGB(180, 180, 180),
		OuterStroke = Color3.fromRGB(60, 60, 60),
		MainColor = Color3.fromRGB(150, 150, 150)
	},
	LOCKED = {
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 30))
		},
		InnerStroke = Color3.fromRGB(255, 150, 150),
		OuterStroke = Color3.fromRGB(120, 20, 20),
		MainColor = Color3.fromRGB(255, 100, 100)
	},
	AVAILABLE = {
		Gradient = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 180, 30))
		},
		InnerStroke = Color3.fromRGB(150, 255, 150),
		OuterStroke = Color3.fromRGB(20, 120, 20),
		MainColor = Color3.fromRGB(100, 255, 100)
	}
}

-- Dopamine VFX config
local DOPAMINE = {
	-- Star burst from card
	STAR_COUNT = 12,
	STAR_ICON = "rbxassetid://6031075938",
	STAR_SIZE_MIN = 18,
	STAR_SIZE_MAX = 32,
	STAR_SPREAD = 160,
	STAR_DURATION_MIN = 0.5,
	STAR_DURATION_MAX = 0.9,
	STAR_STAGGER = 0.02,
	STAR_COLORS = {
		Color3.fromRGB(255, 220, 50),
		Color3.fromRGB(255, 180, 30),
		Color3.fromRGB(255, 255, 130),
		Color3.fromRGB(200, 255, 80),
		Color3.fromRGB(255, 150, 50),
	},

	-- Card flash
	FLASH_COLOR = Color3.fromRGB(255, 255, 200),
	FLASH_DURATION = 0.4,

	-- Viewport celebration
	VIEWPORT_SPIN_SPEED = 25,
	VIEWPORT_SPIN_DURATION = 1.2,
	VIEWPORT_BOUNCE_SCALE = 1.35,

	-- Big text popup
	POPUP_TEXT = "UNLOCKED!",
	POPUP_FONT = Enum.Font.FredokaOne,
	POPUP_SIZE = 38,
	POPUP_COLOR = Color3.fromRGB(255, 230, 50),
	POPUP_STROKE_COLOR = Color3.fromRGB(120, 70, 0),
	POPUP_HOLD = 0.8,
	POPUP_FADE = 0.5,

	-- Ring burst
	RING_COLOR = Color3.fromRGB(255, 220, 60),
	RING_DURATION = 0.6,

	-- Screen shake (subtle)
	SHAKE_INTENSITY = 3,
	SHAKE_DURATION = 0.25,
}

-- VARIABLES
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local PogoData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PogoData"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("WorldConfig"))
local NotificationUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("NotificationUtility"))
local MathUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("MathUtility"))
local SoundUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("SoundUtility"))
local SoundData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("SoundData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiFolder = playerGui:WaitForChild("GUI")
local vendorFrame = guiFolder:WaitForChild("VendorFrame")

local mainContent = vendorFrame:WaitForChild("MainContent")
local exitButton = vendorFrame:WaitForChild("ExitButton")
local headText = vendorFrame:WaitForChild("HeadText", 10)

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local actionRemote = remotesFolder:FindFirstChild("ActionRemote")

local currentCoins = 0
local currentRebirths = 0
local currentWorldId = 1
local ownedPogos = {}
local equippedPogoId = ""

local spawnedViewports = {}
local buttonConnections = {}
local celebrationSpins = {}

------------------//DOPAMINE VFX FUNCTIONS

local function get_frame_center_screen(frame: GuiObject): Vector2
	local pos = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	return Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)
end

local function spawn_star_burst(parentGui: Instance, origin: Vector2): ()
	for i = 1, DOPAMINE.STAR_COUNT do
		task.delay((i - 1) * DOPAMINE.STAR_STAGGER, function()
			local starColor = DOPAMINE.STAR_COLORS[math.random(1, #DOPAMINE.STAR_COLORS)]
			local starSize = math.random(DOPAMINE.STAR_SIZE_MIN, DOPAMINE.STAR_SIZE_MAX)

			local star = Instance.new("ImageLabel")
			star.Name = "StarBurst"
			star.Image = DOPAMINE.STAR_ICON
			star.ImageColor3 = starColor
			star.BackgroundTransparency = 1
			star.Size = UDim2.new(0, starSize, 0, starSize)
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Position = UDim2.new(0, origin.X, 0, origin.Y)
			star.Rotation = math.random(0, 360)
			star.ZIndex = 200
			star.Parent = parentGui

			local scale = Instance.new("UIScale")
			scale.Scale = 0
			scale.Parent = star

			-- Pop in
			TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.2
			}):Play()

			task.delay(0.12, function()
				TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 1 }):Play()
			end)

			-- Fly outward
			local angle = math.rad(math.random(0, 360))
			local dist = DOPAMINE.STAR_SPREAD * (0.5 + math.random() * 0.5)
			local targetX = origin.X + math.cos(angle) * dist
			local targetY = origin.Y + math.sin(angle) * dist

			local flyDur = DOPAMINE.STAR_DURATION_MIN + math.random() * (DOPAMINE.STAR_DURATION_MAX - DOPAMINE.STAR_DURATION_MIN)

			TweenService:Create(star, TweenInfo.new(flyDur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, targetX, 0, targetY),
				Rotation = star.Rotation + math.random(-180, 180),
				ImageTransparency = 1,
			}):Play()

			TweenService:Create(scale, TweenInfo.new(flyDur * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.3
			}):Play()

			Debris:AddItem(star, flyDur + 0.2)
		end)
	end
end

local function spawn_ring_burst(parentGui: Instance, origin: Vector2): ()
	local ring = Instance.new("Frame")
	ring.Name = "RingBurst"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0, origin.X, 0, origin.Y)
	ring.Size = UDim2.new(0, 10, 0, 10)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 190
	ring.Parent = parentGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = DOPAMINE.RING_COLOR
	stroke.Thickness = 4
	stroke.Transparency = 0
	stroke.Parent = ring

	TweenService:Create(ring, TweenInfo.new(DOPAMINE.RING_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 280, 0, 280),
	}):Play()

	TweenService:Create(stroke, TweenInfo.new(DOPAMINE.RING_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Thickness = 1,
	}):Play()

	Debris:AddItem(ring, DOPAMINE.RING_DURATION + 0.1)
end

local function flash_card(stickFrame: Instance): ()
	--local flash = Instance.new("Frame")
	--flash.Name = "PurchaseFlash"
	--flash.Size = UDim2.new(1, 0, 1, 0)
	--flash.BackgroundColor3 = DOPAMINE.FLASH_COLOR
	----flash.BackgroundTransparency = 0.3
	--flash.BorderSizePixel = 0
	--flash.ZIndex = 100
	--flash.Parent = stickFrame

	--local corner = Instance.new("UICorner")
	--corner.CornerRadius = UDim.new(0, 8)
	--corner.Parent = flash

	--TweenService:Create(flash, TweenInfo.new(DOPAMINE.FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	--	BackgroundTransparency = 1,
	--})--:Play()

	--Debris:AddItem(flash, DOPAMINE.FLASH_DURATION + 0.1)
end

local function celebrate_viewport(stickFrame: Instance): ()
	local viewportHolder = stickFrame:FindFirstChild("PogoStickHolder", true)
	if not viewportHolder then return end

	local vpf = viewportHolder:FindFirstChild("StickViewport")
	if not vpf then return end

	-- Bounce scale on the viewport
	local vpScale = vpf:FindFirstChildOfClass("UIScale")
	if not vpScale then
		vpScale = Instance.new("UIScale")
		vpScale.Scale = 1
		vpScale.Parent = vpf
	end

	vpScale.Scale = 0.6
	TweenService:Create(vpScale, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Scale = 1.15
	}):Play()

	task.delay(0.5, function()
		if vpScale and vpScale.Parent then
			TweenService:Create(vpScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1
			}):Play()
		end
	end)

	-- Fast celebration spin
	local spinToken = tick()
	celebrationSpins[vpf] = spinToken

	local worldModel = vpf:FindFirstChildOfClass("WorldModel")
	local targetParent = worldModel or vpf
	local model = targetParent:FindFirstChildOfClass("Model")
	if not model or not model.PrimaryPart then return end

	local elapsed = 0
	local duration = DOPAMINE.VIEWPORT_SPIN_DURATION
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if celebrationSpins[vpf] ~= spinToken then
			conn:Disconnect()
			return
		end

		elapsed += dt
		if elapsed >= duration then
			celebrationSpins[vpf] = nil
			conn:Disconnect()
			return
		end

		-- Ease-out spin: fast at start, slows down
		local progress = elapsed / duration
		local speedMult = (1 - progress) ^ 1.5
		local rotDelta = DOPAMINE.VIEWPORT_SPIN_SPEED * speedMult * dt * 60

		if model and model.PrimaryPart and model.Parent then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(rotDelta), 0))
		else
			conn:Disconnect()
		end
	end)
end

local function spawn_popup_text(parentGui: Instance, origin: Vector2, text: string): ()
	local label = Instance.new("TextLabel")
	label.Name = "PurchasePopup"
	label.Size = UDim2.new(0, 300, 0, 60)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0, origin.X, 0, origin.Y - 10)
	label.BackgroundTransparency = 1
	label.Font = DOPAMINE.POPUP_FONT
	label.TextSize = DOPAMINE.POPUP_SIZE
	label.TextColor3 = DOPAMINE.POPUP_COLOR
	label.TextTransparency = 0
	label.ZIndex = 210
	label.Text = text
	label.Parent = parentGui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = DOPAMINE.POPUP_STROKE_COLOR
	stroke.Transparency = 0
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label

	-- Pop in
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.1
	}):Play()

	task.delay(0.3, function()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
	end)

	-- Hold then fade out
	task.delay(DOPAMINE.POPUP_HOLD, function()
		TweenService:Create(label, TweenInfo.new(DOPAMINE.POPUP_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			Position = label.Position + UDim2.new(0, 0, 0, -50),
		}):Play()

		TweenService:Create(stroke, TweenInfo.new(DOPAMINE.POPUP_FADE), {
			Transparency = 1,
		}):Play()

		TweenService:Create(scale, TweenInfo.new(DOPAMINE.POPUP_FADE, Enum.EasingStyle.Quad), {
			Scale = 0.7,
		}):Play()
	end)

	Debris:AddItem(label, DOPAMINE.POPUP_HOLD + DOPAMINE.POPUP_FADE + 0.2)
end

local function spawn_mini_sparkles(parentGui: Instance, origin: Vector2, count: number): ()
	for i = 1, count do
		task.delay(i * 0.04, function()
			local sparkle = Instance.new("Frame")
			sparkle.Name = "Sparkle"
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.BackgroundColor3 = DOPAMINE.STAR_COLORS[math.random(1, #DOPAMINE.STAR_COLORS)]
			sparkle.BorderSizePixel = 0
			sparkle.ZIndex = 195

			local sz = math.random(4, 8)
			sparkle.Size = UDim2.new(0, sz, 0, sz)

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = sparkle

			local spread = 60
			local sx = origin.X + math.random(-spread, spread)
			local sy = origin.Y + math.random(-spread, spread)
			sparkle.Position = UDim2.new(0, sx, 0, sy)
			sparkle.Rotation = math.random(0, 45)
			sparkle.Parent = parentGui

			local sparkScale = Instance.new("UIScale")
			sparkScale.Scale = 0
			sparkScale.Parent = sparkle

			TweenService:Create(sparkScale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1.5
			}):Play()

			local angle = math.rad(math.random(0, 360))
			local dist = 40 + math.random() * 80
			local tx = sx + math.cos(angle) * dist
			local ty = sy + math.sin(angle) * dist - 30

			TweenService:Create(sparkle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0, tx, 0, ty),
				BackgroundTransparency = 1,
				Rotation = sparkle.Rotation + math.random(-90, 90),
			}):Play()

			TweenService:Create(sparkScale, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0,
			}):Play()

			Debris:AddItem(sparkle, 0.8)
		end)
	end
end

local function play_purchase_celebration(stickFrame: Instance, pogoName: string): ()
	local center = get_frame_center_screen(stickFrame)
	local screenGui = guiFolder

	-- No card flash / no yellow overlay

	-- Star burst from card center
	spawn_star_burst(screenGui, center)

	-- Ring burst expanding outward
	spawn_ring_burst(screenGui, center)

	-- Mini sparkles scattered
	spawn_mini_sparkles(screenGui, center, 8)

	-- "UNLOCKED!" popup
	task.delay(0.1, function()
		spawn_popup_text(screenGui, Vector2.new(center.X, center.Y - 60), DOPAMINE.POPUP_TEXT)
	end)

	-- Viewport celebration spin + bounce
	task.delay(0.05, function()
		celebrate_viewport(stickFrame)
	end)
end

local function play_equip_feedback(stickFrame: Instance): ()
	local center = get_frame_center_screen(stickFrame)

	-- Subtle sparkles for equip (not as intense as purchase)
	spawn_mini_sparkles(guiFolder, center, 5)

	-- Quick scale punch on the card
	local cardScale = stickFrame:FindFirstChildOfClass("UIScale")
	if not cardScale then
		cardScale = Instance.new("UIScale")
		cardScale.Scale = 1
		cardScale.Parent = stickFrame
	end

	cardScale.Scale = 0.95
	TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
		Scale = 1
	}):Play()
end

------------------//SHOP FUNCTIONS

local function start_viewport_rotation()
	RunService.RenderStepped:Connect(function()
		if not vendorFrame.Visible then return end

		for _, vpf in ipairs(spawnedViewports) do
			-- Skip if celebration spin is active
			if celebrationSpins[vpf] then continue end

			local worldModel = vpf:FindFirstChildOfClass("WorldModel")
			local targetParent = worldModel or vpf
			local model = targetParent:FindFirstChildOfClass("Model")

			if model and model.PrimaryPart then
				model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(1), 0))
			end
		end
	end)
end

local function set_button_text(btnFrame: Instance, text: string)
	local textHolder = btnFrame:FindFirstChild("TextHolder", true)
	if textHolder then
		local mainText = textHolder:FindFirstChild("MainText")
		local shadowText = textHolder:FindFirstChild("TextShadow")
		if mainText then mainText.Text = text end
		if shadowText then shadowText.Text = text end
	else
		local amountText = btnFrame:FindFirstChild("Amount", true)
		if amountText then amountText.Text = text end
	end
end

local function set_button_colors(btnFrame: Instance, colorData)
	if btnFrame:IsA("GuiButton") then
		btnFrame.AutoButtonColor = false
	end

	btnFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

	local uiGradient = btnFrame:FindFirstChildOfClass("UIGradient")
	if uiGradient then
		uiGradient.Color = colorData.Gradient
	else
		btnFrame.BackgroundColor3 = colorData.MainColor
	end

	local innerStroke = btnFrame:FindFirstChild("1", true)
	local outerStroke = btnFrame:FindFirstChild("2", true)

	if innerStroke and innerStroke:IsA("UIStroke") then
		innerStroke.Color = colorData.InnerStroke
	end
	if outerStroke and outerStroke:IsA("UIStroke") then
		outerStroke.Color = colorData.OuterStroke
	end
end

local function update_buy_button(btnFrame: Instance, pogoId: string, pogoInfo: any)
	if not pogoId or not pogoInfo then return end

	local isOwned = (ownedPogos and ownedPogos[pogoId] == true)
	local isEquipped = (equippedPogoId == pogoId)

	if isEquipped then
		set_button_colors(btnFrame, COLORS.OWNED)
		set_button_text(btnFrame, "EQUIPPED")
		return
	elseif isOwned then
		set_button_colors(btnFrame, COLORS.AVAILABLE)
		set_button_text(btnFrame, "EQUIP")
		return
	end

	local canAfford = currentCoins >= (pogoInfo.Price or 0)
	local hasRebirths = currentRebirths >= (pogoInfo.RequiredRebirths or 0)

	if not hasRebirths then
		set_button_colors(btnFrame, COLORS.LOCKED)
		set_button_text(btnFrame, tostring(pogoInfo.RequiredRebirths or 0) .. " Rebirths")
	elseif not canAfford then
		set_button_colors(btnFrame, COLORS.LOCKED)
		set_button_text(btnFrame, "$" .. MathUtility.format_number(pogoInfo.Price or 0))
	else
		set_button_colors(btnFrame, COLORS.AVAILABLE)
		set_button_text(btnFrame, "$" .. MathUtility.format_number(pogoInfo.Price or 0))
	end
end

local function disconnect_old_buttons()
	for _, c in ipairs(buttonConnections) do
		c:Disconnect()
	end
	table.clear(buttonConnections)
end

local function refresh_all_buttons()
	for i = 1, 5 do
		local stickFrame = mainContent:FindFirstChild(tostring(i))
		if stickFrame and stickFrame.Visible then
			local pogoId = stickFrame:GetAttribute("CurrentPogoId")
			if pogoId then
				local pogoInfo = PogoData.Get(pogoId)
				local buyBtn = stickFrame:FindFirstChild("BuyButton", true)
				if buyBtn then
					update_buy_button(buyBtn, pogoId, pogoInfo)
				end
			end
		end
	end
end

local function populate_shop()
	local worldData = WorldConfig.GetWorld(currentWorldId)
	if worldData and headText then
		headText.Text = worldData.name .. " Pogo Sticks"
	end

	local sortedPogos = PogoData.GetSortedList()
	local pogosToLoad = {}

	local maxOrder = currentWorldId * 5
	local minOrder = maxOrder - 4

	for _, pogo in ipairs(sortedPogos) do
		if pogo.Order >= minOrder and pogo.Order <= maxOrder then
			table.insert(pogosToLoad, pogo)
		end
	end

	table.clear(spawnedViewports)
	disconnect_old_buttons()

	for i = 1, 5 do
		local stickFrame = mainContent:FindFirstChild(tostring(i))
		local pogo = pogosToLoad[i]

		if not stickFrame then
			continue
		end

		if not pogo then
			stickFrame.Visible = false
			stickFrame:SetAttribute("CurrentPogoId", nil)
			continue
		end

		stickFrame.Visible = true
		stickFrame:SetAttribute("CurrentPogoId", pogo.Id)

		local nameHolder = stickFrame:FindFirstChild("StickNameHolder", true)
		if nameHolder then
			local mainText = nameHolder:FindFirstChild("MainText")
			local shadowText = nameHolder:FindFirstChild("TextShadow")
			local upperName = string.upper(pogo.Name or pogo.Id)
			if mainText then mainText.Text = upperName end
			if shadowText then shadowText.Text = upperName end
		end

		local speedStat = stickFrame:FindFirstChild("SpeedStat", true)
		if speedStat then
			local amount = speedStat:FindFirstChild("Amount", true)
			if amount then amount.Text = tostring(pogo.AirMobility or 0) end
		end

		local springStat = stickFrame:FindFirstChild("SpringStat", true)
		if springStat then
			local amount = springStat:FindFirstChild("Amount", true)
			if amount then amount.Text = tostring(pogo.Power or 0) end
		end

		local viewportHolder = stickFrame:FindFirstChild("PogoStickHolder", true)
		if viewportHolder then
			local oldViewport = viewportHolder:FindFirstChild("StickViewport")
			if oldViewport then oldViewport:Destroy() end

			local generatedVpf = PogoData.GetPogoViewport(pogo.Id)
			if generatedVpf then
				generatedVpf.Size = UDim2.new(1, 0, 1, 0)
				generatedVpf.Position = UDim2.new(0.5, 0, 0.5, 0)
				generatedVpf.AnchorPoint = Vector2.new(0.5, 0.5)
				generatedVpf.Name = "StickViewport"
				generatedVpf.ZIndex = 5
				generatedVpf.Parent = viewportHolder
				table.insert(spawnedViewports, generatedVpf)
			end
		end

		local buyBtn = stickFrame:FindFirstChild("BuyButton", true)
		if buyBtn then
			update_buy_button(buyBtn, pogo.Id, pogo)

			local connection = buyBtn.InputBegan:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end

				-- Already owned → equip
				if ownedPogos and ownedPogos[pogo.Id] == true then
					if equippedPogoId ~= pogo.Id then
						if actionRemote then
							SoundUtility.PlaySFX(SoundData.SFX.Buy)
							actionRemote:FireServer("Pogos", "Select", pogo.Id)
							play_equip_feedback(stickFrame)
						end
					end
					return
				end

				-- Check requirements
				if currentRebirths < (pogo.RequiredRebirths or 0) then
					NotificationUtility:Error("You need " .. tostring(pogo.RequiredRebirths or 0) .. " Rebirths to buy this!", 3)
					return
				end

				if currentCoins < (pogo.Price or 0) then
					NotificationUtility:Error("Not enough coins!", 3)
					return
				end

				-- PURCHASE!
				if actionRemote then
					SoundUtility.PlaySFX(SoundData.SFX.Buy)
					actionRemote:FireServer("Pogos", "Buy", pogo.Id)

					-- Play the dopamine celebration
					play_purchase_celebration(stickFrame, pogo.Name or pogo.Id)

					task.delay(0.15, refresh_all_buttons)
				else
					warn("Remote 'ActionRemote' não encontrado em Assets/Remotes")
				end
			end)

			table.insert(buttonConnections, connection)
		end
	end

	refresh_all_buttons()
end

-- INIT
DataUtility.client.ensure_remotes()

currentCoins = DataUtility.client.get("Coins") or 0
currentRebirths = DataUtility.client.get("RebirthTokens") or DataUtility.client.get("Rebirths") or 0
ownedPogos = DataUtility.client.get("OwnedPogos") or {}
equippedPogoId = DataUtility.client.get("EquippedPogoId") or ""
currentWorldId = DataUtility.client.get("CurrentWorld") or 1

DataUtility.client.bind("Coins", function(val)
	currentCoins = val or 0
	refresh_all_buttons()
end)

DataUtility.client.bind("RebirthTokens", function(val)
	currentRebirths = val or 0
	refresh_all_buttons()
end)

DataUtility.client.bind("Rebirths", function(val)
	currentRebirths = val or 0
	refresh_all_buttons()
end)

DataUtility.client.bind("OwnedPogos", function(val)
	ownedPogos = val or {}
	refresh_all_buttons()
end)

DataUtility.client.bind("EquippedPogoId", function(val)
	equippedPogoId = val or ""
	refresh_all_buttons()
end)

DataUtility.client.bind("CurrentWorld", function(val)
	currentWorldId = val or 1
	populate_shop()
end)

if exitButton then
	exitButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			vendorFrame.Visible = false
		end
	end)
end

task.spawn(function()
	task.wait(1)
	populate_shop()
	start_viewport_rotation()
end)