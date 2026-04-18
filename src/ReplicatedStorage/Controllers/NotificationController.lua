local NotificationController = {}

------------------//SERVICES
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

------------------//CONSTANTS
local TWEEN_SLIDE_IN = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_SLIDE_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
local TWEEN_FADE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_BOUNCE_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_BOUNCE_OUT = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local DEFAULT_DURATION = 4
local MAX_NOTIFICATIONS = 4
local NOTIF_WIDTH = 380
local SLIDE_OFFSET_X = NOTIF_WIDTH + 60

local GLOW_IMAGE = "rbxassetid://4996891970"

local STYLES = {
	Success = {
		Border = Color3.fromRGB(50, 255, 100),
		Header = Color3.fromRGB(30, 180, 70),
		HeaderText = Color3.fromRGB(255, 255, 255),
		Icon = "✓",
		BtnColor = Color3.fromRGB(40, 220, 90),
		GlowColor = Color3.fromRGB(50, 255, 100),
	},
	Error = {
		Border = Color3.fromRGB(255, 50, 80),
		Header = Color3.fromRGB(180, 25, 55),
		HeaderText = Color3.fromRGB(255, 255, 255),
		Icon = "X",
		BtnColor = Color3.fromRGB(220, 40, 70),
		GlowColor = Color3.fromRGB(255, 50, 80),
	},
	Warning = {
		Border = Color3.fromRGB(255, 185, 0),
		Header = Color3.fromRGB(180, 128, 0),
		HeaderText = Color3.fromRGB(255, 255, 255),
		Icon = "⚠",
		BtnColor = Color3.fromRGB(220, 165, 0),
		GlowColor = Color3.fromRGB(255, 200, 0),
	},
	Info = {
		Border = Color3.fromRGB(0, 185, 255),
		Header = Color3.fromRGB(0, 110, 185),
		HeaderText = Color3.fromRGB(255, 255, 255),
		Icon = "ℹ",
		BtnColor = Color3.fromRGB(0, 165, 230),
		GlowColor = Color3.fromRGB(0, 200, 255),
	},
	Reward = {
		Border = Color3.fromRGB(255, 50, 200), 
		Header = Color3.fromRGB(185, 25, 145),
		HeaderText = Color3.fromRGB(255, 255, 255),
		Icon = "★",
		BtnColor = Color3.fromRGB(220, 40, 185),
		GlowColor = Color3.fromRGB(255, 80, 220),
	},
}

------------------//VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local notifGui
local container
local notifications = {}

------------------//HELPERS

local function tw(inst, info, goals)
	return TweenService:Create(inst, info, goals)
end

local function getTypeName(style)
	for k, v in pairs(STYLES) do
		if v == style then
			return k
		end
	end
	return "INFO"
end

------------------//GUI CREATION

local function createGui()
	local sg = Instance.new("ScreenGui")
	sg.Name = "ShopStyleNotifications"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = 200

	local frame = Instance.new("Frame")
	frame.Name = "Container"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(0, NOTIF_WIDTH + 30, 1, -110)
	frame.Position = UDim2.new(1, -(NOTIF_WIDTH + 24), 0, 96)
	frame.ClipsDescendants = false

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = frame

	frame.Parent = sg
	sg.Parent = playerGui
	return sg, frame
end

local function buildNotification(title, message, style)
	-- ── Wrapper ───────────────────────────────────────────────────────────
	local wrapper = Instance.new("Frame")
	wrapper.Name = "NotifWrapper"
	wrapper.Size = UDim2.new(0, NOTIF_WIDTH, 0, 0)
	wrapper.AutomaticSize = Enum.AutomaticSize.Y
	wrapper.BackgroundTransparency = 1
	wrapper.Position = UDim2.new(0, SLIDE_OFFSET_X, 0, 0)
	wrapper.ClipsDescendants = false

	-- ── Drop shadow ───────────────────────────────────────────────────────
	local shadow = Instance.new("ImageLabel")
	shadow.BackgroundTransparency = 1
	shadow.Size = UDim2.new(1, 24, 1, 24)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 6)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Image = GLOW_IMAGE
	shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
	shadow.ImageTransparency = 0.5
	shadow.ZIndex = 1
	shadow.ScaleType = Enum.ScaleType.Stretch
	shadow.Parent = wrapper

	-- Neon glow halo
	local outerGlow = Instance.new("ImageLabel")
	outerGlow.Name = "OuterGlow"
	outerGlow.BackgroundTransparency = 1
	outerGlow.Size = UDim2.new(1, 40, 1, 40)
	outerGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	outerGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	outerGlow.Image = GLOW_IMAGE
	outerGlow.ImageColor3 = style.GlowColor
	outerGlow.ImageTransparency = 0.55
	outerGlow.ZIndex = 1
	outerGlow.ScaleType = Enum.ScaleType.Stretch
	outerGlow.Parent = wrapper

	-- ── Card body — dark background like the shop cards ───────────────────
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = wrapper
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

	-- Thick neon border — the defining shop UI trait
	local border = Instance.new("UIStroke")
	border.Color = style.Border
	border.Thickness = 4
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = card

	-- Inner border shimmer (double-border look, like the shop cards have)
	local innerBorder = Instance.new("Frame")
	innerBorder.Size = UDim2.new(1, -8, 1, -8)
	innerBorder.Position = UDim2.new(0, 4, 0, 4)
	innerBorder.BackgroundTransparency = 1
	innerBorder.BorderSizePixel = 0
	innerBorder.ZIndex = 3
	innerBorder.Parent = card
	Instance.new("UICorner", innerBorder).CornerRadius = UDim.new(0, 7)
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(255, 255, 255)
	innerStroke.Thickness = 1
	innerStroke.Transparency = 0.82
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerStroke.Parent = innerBorder

	-- ── Dot pattern overlay (sits on top of the dark bg, below everything else) ──
	local dotPattern = Instance.new("ImageLabel")
	dotPattern.Name = "DotPattern"
	dotPattern.BackgroundTransparency = 1
	dotPattern.AnchorPoint = Vector2.new(0.5, 0.5)
	dotPattern.Size = UDim2.fromScale(1, 1)
	dotPattern.Position = UDim2.fromScale(0.6, 0.5)
	dotPattern.Image = "rbxassetid://115291426115933"
	dotPattern.ImageTransparency = 0.9
	dotPattern.ScaleType = Enum.ScaleType.Crop
	dotPattern.ZIndex = 3
	dotPattern.Parent = card
	Instance.new("UICorner", dotPattern).CornerRadius = UDim.new(0, 10)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 44)
	header.BackgroundColor3 = style.Header
	header.BorderSizePixel = 0
	header.ZIndex = 4
	header.Parent = card

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local headerBottomFill = Instance.new("Frame")
	headerBottomFill.Size = UDim2.new(1, 0, 0, 10)
	headerBottomFill.Position = UDim2.new(0, 0, 1, -10)
	headerBottomFill.BackgroundColor3 = style.Header
	headerBottomFill.BorderSizePixel = 0
	headerBottomFill.ZIndex = 4
	headerBottomFill.Parent = header

	local headerDots = Instance.new("ImageLabel")
	headerDots.Name = "DotPattern"
	headerDots.BackgroundTransparency = 1
	headerDots.AnchorPoint = Vector2.new(0.5, 0.5)
	headerDots.Size = UDim2.fromScale(1, 1)
	headerDots.Position = UDim2.fromScale(0.6, 0.5)
	headerDots.Image = "rbxassetid://115291426115933"
	headerDots.ImageTransparency = 0.9
	headerDots.ScaleType = Enum.ScaleType.Crop
	headerDots.ZIndex = 5
	headerDots.Parent = header
	Instance.new("UICorner", headerDots).CornerRadius = UDim.new(0, 8)

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, -50, 1, 0)
	headerLabel.Position = UDim2.new(0, 46, 0, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = string.upper(title)
	headerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	headerLabel.TextSize = 18
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.TextYAlignment = Enum.TextYAlignment.Center
	headerLabel.TextWrapped = true
	headerLabel.ZIndex = 5
	headerLabel.Parent = header

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = Color3.fromRGB(0, 0, 0)
	headerStroke.Thickness = 3
	headerStroke.Transparency = 0
	headerStroke.Parent = headerLabel

	local iconCircle = Instance.new("Frame")
	iconCircle.Name = "IconCircle"
	iconCircle.Size = UDim2.new(0, 34, 0, 34)
	iconCircle.Position = UDim2.new(0, 6, 0.5, 0)
	iconCircle.AnchorPoint = Vector2.new(0, 0.5)
	iconCircle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	iconCircle.BackgroundTransparency = 0.4
	iconCircle.BorderSizePixel = 0
	iconCircle.ZIndex = 6
	iconCircle.Parent = header
	Instance.new("UICorner", iconCircle).CornerRadius = UDim.new(1, 0)
	local iconCircleStroke = Instance.new("UIStroke")
	iconCircleStroke.Color = Color3.fromRGB(255, 255, 255)
	iconCircleStroke.Thickness = 2
	iconCircleStroke.Transparency = 0.5
	iconCircleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	iconCircleStroke.Parent = iconCircle

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = style.Icon
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextSize = 20
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.ZIndex = 7
	iconLabel.Parent = iconCircle

	local iconTextStroke = Instance.new("UIStroke")
	iconTextStroke.Color = Color3.fromRGB(0, 0, 0)
	iconTextStroke.Thickness = 2.5
	iconTextStroke.Parent = iconLabel

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Position = UDim2.new(0, 0, 0, 44)
	body.BackgroundTransparency = 1
	body.ZIndex = 4
	body.Parent = card

	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingTop = UDim.new(0, 10)
	bodyPad.PaddingBottom = UDim.new(0, 14)
	bodyPad.PaddingLeft = UDim.new(0, 14)
	bodyPad.PaddingRight = UDim.new(0, 14)
	bodyPad.Parent = body

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.FillDirection = Enum.FillDirection.Vertical
	bodyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	bodyLayout.Padding = UDim.new(0, 6)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	if message and message ~= "" then
		local msgLabel = Instance.new("TextLabel")
		msgLabel.Name = "Message"
		msgLabel.Size = UDim2.new(1, 0, 0, 0)
		msgLabel.AutomaticSize = Enum.AutomaticSize.Y
		msgLabel.BackgroundTransparency = 1
		msgLabel.Text = message
		msgLabel.TextColor3 = Color3.fromRGB(215, 220, 225)
		msgLabel.TextSize = 14
		msgLabel.Font = Enum.Font.GothamBold
		msgLabel.TextXAlignment = Enum.TextXAlignment.Left
		msgLabel.TextWrapped = true
		msgLabel.LayoutOrder = 1
		msgLabel.ZIndex = 5
		msgLabel.Parent = body

		local msgStroke = Instance.new("UIStroke")
		msgStroke.Color = Color3.fromRGB(0, 0, 0)
		msgStroke.Thickness = 2
		msgStroke.Transparency = 0.1
		msgStroke.Parent = msgLabel
	end

	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(1, 0, 0, 10)
	progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel = 0
	progressBg.LayoutOrder = 2
	progressBg.ZIndex = 5
	progressBg.Parent = body
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

	local progressBgStroke = Instance.new("UIStroke")
	progressBgStroke.Color = style.Border
	progressBgStroke.Thickness = 2
	progressBgStroke.Transparency = 0.3
	progressBgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	progressBgStroke.Parent = progressBg

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(1, 0, 1, 0)
	progressFill.BackgroundColor3 = style.BtnColor
	progressFill.BorderSizePixel = 0
	progressFill.ZIndex = 6
	progressFill.Parent = progressBg
	Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

	local fillShine = Instance.new("Frame")
	fillShine.Size = UDim2.new(1, 0, 0.5, 0)
	fillShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	fillShine.BackgroundTransparency = 0.75
	fillShine.BorderSizePixel = 0
	fillShine.ZIndex = 7
	fillShine.Parent = progressFill
	Instance.new("UICorner", fillShine).CornerRadius = UDim.new(1, 0)

	return wrapper, card, progressFill, outerGlow, iconCircle
end

------------------//ANIMATIONS

local function slideIn(wrapper)
	local t = tw(wrapper, TWEEN_SLIDE_IN, { Position = UDim2.new(0, 0, 0, 0) })
	t:Play()
	return t
end

local function slideOut(wrapper, card)
	local t1 = tw(wrapper, TWEEN_SLIDE_OUT, { Position = UDim2.new(0, SLIDE_OFFSET_X, 0, 0) })
	local t2 = tw(card, TWEEN_FADE_OUT, { BackgroundTransparency = 1 })
	t1:Play()
	t2:Play()
	return t1
end

local function animateProgress(fill, duration)
	local t = tw(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })
	t:Play()
	return t
end

local function pulseGlow(outerGlow)
	local t = tw(
		outerGlow,
		TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ ImageTransparency = 0.3 }
	)
	t:Play()
	return t
end

local function bounceIcon(iconCircle)
	local t1 = tw(iconCircle, TWEEN_BOUNCE_IN, { Size = UDim2.new(0, 40, 0, 40) })
	t1:Play()
	t1.Completed:Connect(function()
		tw(iconCircle, TWEEN_BOUNCE_OUT, { Size = UDim2.new(0, 34, 0, 34) }):Play()
	end)
end

------------------//NOTIFICATION MANAGEMENT

local function removeNotification(notifData, instant)
	for i, d in ipairs(notifications) do
		if d == notifData then
			table.remove(notifications, i)
			break
		end
	end
	if notifData.ProgressTween then
		notifData.ProgressTween:Cancel()
	end
	if notifData.GlowTween then
		notifData.GlowTween:Cancel()
	end

	if instant then
		notifData.Wrapper:Destroy()
		return
	end

	local t = slideOut(notifData.Wrapper, notifData.Card)
	t.Completed:Connect(function()
		notifData.Wrapper:Destroy()
	end)
end

local function createNotification(title, message, notifType, duration)
	if not notifGui then
		notifGui, container = createGui()
	end

	if #notifications >= MAX_NOTIFICATIONS then
		removeNotification(notifications[1])
	end

	local style = STYLES[notifType] or STYLES.Info
	local dur = duration or DEFAULT_DURATION

	local wrapper, card, progressFill, outerGlow, iconCircle = buildNotification(title, message, style)

	wrapper.LayoutOrder = #notifications + 1
	wrapper.Parent = container

	local notifData = { Wrapper = wrapper, Card = card, ProgressTween = nil, GlowTween = nil }
	table.insert(notifications, notifData)

	slideIn(wrapper)

	task.spawn(function()
		task.wait(0.2)
		bounceIcon(iconCircle)
		notifData.GlowTween = pulseGlow(outerGlow)
		notifData.ProgressTween = animateProgress(progressFill, dur - 0.2)
	end)

	task.delay(dur, function()
		if wrapper.Parent then
			removeNotification(notifData)
		end
	end)
end

------------------//PUBLIC API

function NotificationController.Notify(title, message, duration)
	createNotification(title, message, "Info", duration)
end

function NotificationController.NotifySuccess(title, message, duration)
	createNotification(title, message, "Success", duration)
end

function NotificationController.NotifyError(title, message, duration)
	createNotification(title, message, "Error", duration)
end

function NotificationController.NotifyWarning(title, message, duration)
	createNotification(title, message, "Warning", duration)
end

function NotificationController.NotifyReward(rewardType, amount)
	local displayName = rewardType
	local emoji = "🎁"
	if rewardType == "Yen" then
		emoji = "💰"
		displayName = "Yen"
	elseif rewardType == "SpinStyle" then
		emoji = "✨"
		displayName = "Spin Style" .. (amount > 1 and "s" or "")
	elseif rewardType == "SpinFlow" then
		emoji = "🌊"
		displayName = "Spin Flow" .. (amount > 1 and "s" or "")
	end
	createNotification("YOU REDEEMED!", string.format("%s  +%d %s", emoji, amount, displayName), "Reward", 4.5)
end

function NotificationController.Clear()
	local snap = { table.unpack(notifications) }
	for _, data in ipairs(snap) do
		removeNotification(data, true)
	end
	notifications = {}
end

return NotificationController
