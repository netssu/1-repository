------------------//SERVICES
local Players: Players = game:GetService("Players")
local ContentProvider: ContentProvider = game:GetService("ContentProvider")
local TweenService: TweenService = game:GetService("TweenService")
local RunService: RunService = game:GetService("RunService")
local Lighting: Lighting = game:GetService("Lighting")

------------------//CONSTANTS
local CAMERA_START_POS = Vector3.new(-239.873, 140.562, -124.886)
local CAMERA_START_ORI = Vector3.new(-35.326, -13.573, 0)
local CAMERA_FORWARD_DISTANCE = 50
local CAMERA_MOVE_DURATION = 30
local CAMERA_ROTATE_SPEED = 0.3

local BAR_BG_COLOR = Color3.fromRGB(255, 255, 255)
local BAR_BORDER_COLOR = Color3.fromRGB(135, 190, 245)
local BAR_FILL_COLOR = Color3.fromRGB(30, 80, 160)
local BLUR_SIZE = 24
local BLUR_PROTECT_NAME = "_LoadingBlur_PROTECTED_"

local FADE_OUT_DURATION = 1.5
local UI_REVEAL_DURATION = 0.8

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local camera: Camera = workspace.CurrentCamera

local startCFrame: CFrame = CFrame.new(CAMERA_START_POS) * CFrame.Angles(
	math.rad(CAMERA_START_ORI.X),
	math.rad(CAMERA_START_ORI.Y),
	math.rad(CAMERA_START_ORI.Z)
)

local forwardDir: Vector3 = startCFrame.LookVector
local endPos: CFrame = CFrame.new(CAMERA_START_POS + forwardDir * CAMERA_FORWARD_DISTANCE) * CFrame.Angles(
	math.rad(CAMERA_START_ORI.X),
	math.rad(CAMERA_START_ORI.Y),
	math.rad(CAMERA_START_ORI.Z)
)

local loadingComplete = false
local movementComplete = false
local rotationAngleY = 0
local rotationAngleX = 0

local disabledGuis: {ScreenGui} = {}
local blurProtectConnection: RBXScriptConnection? = nil
local blurRef: BlurEffect? = nil
local blurProtectionActive = true

------------------//FUNCTIONS

local function disable_all_huds(): ()
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Name ~= "LoadingScreenGui" and child.Enabled == true then
			if not table.find(disabledGuis, child) then
				table.insert(disabledGuis, child)
			end
			child.Enabled = false
		end
	end
end

local function collect_and_hide_ui(gui: ScreenGui): {{instance: Instance, property: string, original: number}}
	local data: {{instance: Instance, property: string, original: number}} = {}

	for _, desc in gui:GetDescendants() do
		if desc:IsA("Frame") or desc:IsA("ScrollingFrame") or desc:IsA("CanvasGroup") or desc:IsA("ViewportFrame") then
			local obj = desc :: GuiObject
			if obj.BackgroundTransparency < 1 then
				table.insert(data, {instance = obj, property = "BackgroundTransparency", original = obj.BackgroundTransparency})
				obj.BackgroundTransparency = 1
			end
		end

		if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
			local img = desc :: ImageLabel
			if img.BackgroundTransparency < 1 then
				table.insert(data, {instance = img, property = "BackgroundTransparency", original = img.BackgroundTransparency})
				img.BackgroundTransparency = 1
			end
			if img.ImageTransparency < 1 then
				table.insert(data, {instance = img, property = "ImageTransparency", original = img.ImageTransparency})
				img.ImageTransparency = 1
			end
		end

		if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
			local txt = desc :: TextLabel
			if txt.BackgroundTransparency < 1 then
				table.insert(data, {instance = txt, property = "BackgroundTransparency", original = txt.BackgroundTransparency})
				txt.BackgroundTransparency = 1
			end
			if txt.TextTransparency < 1 then
				table.insert(data, {instance = txt, property = "TextTransparency", original = txt.TextTransparency})
				txt.TextTransparency = 1
			end
			if txt.TextStrokeTransparency < 1 then
				table.insert(data, {instance = txt, property = "TextStrokeTransparency", original = txt.TextStrokeTransparency})
				txt.TextStrokeTransparency = 1
			end
		end

		if desc:IsA("UIStroke") then
			local stroke = desc :: UIStroke
			if stroke.Transparency < 1 then
				table.insert(data, {instance = stroke, property = "Transparency", original = stroke.Transparency})
				stroke.Transparency = 1
			end
		end

		if desc:IsA("ScrollingFrame") then
			local scroll = desc :: ScrollingFrame
			if scroll.ScrollBarImageTransparency < 1 then
				table.insert(data, {instance = scroll, property = "ScrollBarImageTransparency", original = scroll.ScrollBarImageTransparency})
				scroll.ScrollBarImageTransparency = 1
			end
		end
	end

	return data
end

local function restore_all_huds(): ()
	local tweenInfo = TweenInfo.new(UI_REVEAL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, gui in disabledGuis do
		local transparencyData = collect_and_hide_ui(gui)
		gui.Enabled = true

		for _, entry in transparencyData do
			local props = {}
			props[entry.property] = entry.original
			TweenService:Create(entry.instance, tweenInfo, props):Play()
		end
	end

	disabledGuis = {}
end

local function make_blur(): BlurEffect
	local blur: BlurEffect = Instance.new("BlurEffect")
	blur.Name = BLUR_PROTECT_NAME
	blur.Size = BLUR_SIZE
	blur.Enabled = true
	blur.Parent = Lighting
	return blur
end

local function create_protected_blur(): ()
	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BlurEffect") and effect.Name == BLUR_PROTECT_NAME then
			effect:Destroy()
		end
	end

	blurRef = make_blur()
	blurProtectionActive = true

	blurProtectConnection = RunService.Heartbeat:Connect(function()
		if not blurProtectionActive then
			return
		end

		local current = blurRef

		if not current or not current.Parent then
			local found = Lighting:FindFirstChild(BLUR_PROTECT_NAME)
			if found and found:IsA("BlurEffect") then
				blurRef = found
				current = found
			else
				blurRef = make_blur()
				current = blurRef
			end
		end

		if current.Size ~= BLUR_SIZE then
			current.Size = BLUR_SIZE
		end
		if current.Enabled ~= true then
			current.Enabled = true
		end
	end)
end

local function stop_blur_protection(): ()
	blurProtectionActive = false
	if blurProtectConnection then
		blurProtectConnection:Disconnect()
		blurProtectConnection = nil
	end
end

local function create_loading_gui(): (ScreenGui, Frame, TextLabel)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LoadingScreenGui"
	screenGui.DisplayOrder = 999
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local barContainer = Instance.new("Frame")
	barContainer.Name = "BarContainer"
	barContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	barContainer.Position = UDim2.fromScale(0.5, 0.85)
	barContainer.Size = UDim2.new(0.35, 0, 0, 8)
	barContainer.BackgroundColor3 = BAR_BG_COLOR
	barContainer.BorderSizePixel = 0
	barContainer.Parent = screenGui

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 6)
	barCorner.Parent = barContainer

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = BAR_BORDER_COLOR
	barStroke.Thickness = 2
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = barContainer

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = BAR_FILL_COLOR
	barFill.BorderSizePixel = 0
	barFill.Parent = barContainer

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = barFill

	local percentLabel = Instance.new("TextLabel")
	percentLabel.Name = "PercentLabel"
	percentLabel.AnchorPoint = Vector2.new(0.5, 1)
	percentLabel.Position = UDim2.new(0.5, 0, 0, -10)
	percentLabel.Size = UDim2.new(0.5, 0, 0, 24)
	percentLabel.BackgroundTransparency = 1
	percentLabel.Font = Enum.Font.GothamBold
	percentLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	percentLabel.TextSize = 16
	percentLabel.Text = "0%"
	percentLabel.TextStrokeTransparency = 0.7
	percentLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	percentLabel.Parent = barContainer

	screenGui.Parent = playerGui

	return screenGui, barFill, percentLabel
end

local function preload_assets(barFill: Frame, percentLabel: TextLabel): ()
	local assets = game:GetDescendants()
	local totalAssets: number = #assets
	local loaded: number = 0

	for _, asset in assets do
		ContentProvider:PreloadAsync({asset})
		loaded += 1

		disable_all_huds()

		local progress = loaded / totalAssets
		barFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		percentLabel.Text = tostring(math.floor(progress * 100)) .. "%"
	end

	barFill.Size = UDim2.fromScale(1, 1)
	percentLabel.Text = "100%"
	loadingComplete = true
end

local function fade_out_loading(screenGui: ScreenGui): ()
	local barContainer = screenGui:FindFirstChild("BarContainer") :: Frame?
	local tweenInfo = TweenInfo.new(FADE_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	if barContainer then
		local barStroke = barContainer:FindFirstChildOfClass("UIStroke")
		local barFill = barContainer:FindFirstChild("BarFill")
		local percentLabel = barContainer:FindFirstChild("PercentLabel")

		TweenService:Create(barContainer, tweenInfo, {BackgroundTransparency = 1}):Play()
		if barStroke then
			TweenService:Create(barStroke, tweenInfo, {Transparency = 1}):Play()
		end
		if barFill then
			TweenService:Create(barFill, tweenInfo, {BackgroundTransparency = 1}):Play()
		end
		if percentLabel then
			TweenService:Create(percentLabel :: TextLabel, tweenInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		end
	end

	stop_blur_protection()

	local activeBlur: BlurEffect? = Lighting:FindFirstChild(BLUR_PROTECT_NAME) :: BlurEffect?
	if not activeBlur or not activeBlur.Parent then
		activeBlur = make_blur()
	end
	TweenService:Create(activeBlur, tweenInfo, {Size = 0}):Play()

	restore_all_huds()

	task.wait(FADE_OUT_DURATION + 0.2)

	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BlurEffect") and effect.Name == BLUR_PROTECT_NAME then
			effect:Destroy()
		end
	end

	screenGui:Destroy()
end

------------------//MAIN FUNCTIONS

local function run_camera_movement(): ()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = startCFrame

	local elapsed = 0

	local moveConnection: RBXScriptConnection
	moveConnection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt

		if not movementComplete then
			local alpha = math.clamp(elapsed / CAMERA_MOVE_DURATION, 0, 1)
			local easedAlpha = alpha * alpha * (3 - 2 * alpha)

			camera.CFrame = startCFrame:Lerp(endPos, easedAlpha)

			if alpha >= 1 then
				movementComplete = true
				elapsed = 0
			end
		else
			rotationAngleY += dt * CAMERA_ROTATE_SPEED * 0.5
			rotationAngleX += dt * CAMERA_ROTATE_SPEED * 0.15 * math.sin(elapsed * 0.3)

			local baseCFrame = endPos
			camera.CFrame = baseCFrame * CFrame.Angles(
				math.rad(rotationAngleX),
				math.rad(rotationAngleY),
				0
			)

			if loadingComplete then
				moveConnection:Disconnect()
			end
		end
	end)

	repeat task.wait(0.1) until loadingComplete
	if moveConnection.Connected then
		moveConnection:Disconnect()
	end
end

------------------//INIT
disable_all_huds()

create_protected_blur()
local screenGui, barFill, percentLabel = create_loading_gui()

task.spawn(run_camera_movement)
preload_assets(barFill, percentLabel)

task.wait(0.5)

fade_out_loading(screenGui)

camera.CameraType = Enum.CameraType.Custom