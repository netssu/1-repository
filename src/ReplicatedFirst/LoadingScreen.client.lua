------------------//SERVICES
local Players: Players = game:GetService("Players")
local ContentProvider: ContentProvider = game:GetService("ContentProvider")
local ReplicatedFirst: ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")
local Debris: Debris = game:GetService("Debris")

------------------//CONSTANTS
local PERSISTENT_OVERLAY_NAME = "LoadingPersistentOverlay"

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui")

_G.Loaded = false

ReplicatedFirst:RemoveDefaultLoadingScreen()

local loadScreen: ScreenGui = playerGui:WaitForChild("LoadingScreen") :: ScreenGui
loadScreen.Enabled = true

local loadingContainer: Instance? = loadScreen:FindFirstChild("Loading")
local loadingScript: LocalScript? = nil

if loadingContainer then
	loadingScript = loadingContainer:FindFirstChildWhichIsA("LocalScript")
	if loadingScript then
		loadingScript.Enabled = true
	end
end

local imageLabel: Instance? = loadScreen:FindFirstChild("ImageLabel")
if imageLabel and imageLabel:IsA("ImageLabel") then
	imageLabel.ImageTransparency = 0
end

------------------//FUNCTIONS
local function find_logo(root: Instance): GuiObject?
	local logo = root:FindFirstChild("logo", true) or root:FindFirstChild("Logo", true)
	if logo and logo:IsA("GuiObject") then
		return logo
	end
	return nil
end

local function make_logo_fully_visible(logo: GuiObject?): ()
	if not logo then
		return
	end

	local nodes = { logo }

	for _, descendant in ipairs(logo:GetDescendants()) do
		table.insert(nodes, descendant)
	end

	for _, node in ipairs(nodes) do
		if node:IsA("ImageLabel") or node:IsA("ImageButton") then
			node.ImageTransparency = 0
		elseif node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
			node.TextTransparency = 0
			node.TextStrokeTransparency = 0
		elseif node:IsA("UIStroke") then
			node.Transparency = 0
		end
	end
end

local function spawn_shockwave(parent: Instance, centerPos: UDim2): ()
	local ring = Instance.new("Frame")
	ring.Name = "Shockwave"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = centerPos
	ring.Size = UDim2.new(0, 20, 0, 20)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 1
	ring.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 5
	stroke.Transparency = 0.2
	stroke.Parent = ring

	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 500, 0, 500),
	}):Play()

	TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Thickness = 1,
	}):Play()

	Debris:AddItem(ring, 0.8)
end

local function spawn_impact_sparkles(parent: Instance, centerPos: UDim2, count: number): ()
	for i = 1, count do
		task.delay((i - 1) * 0.015, function()
			local sparkle = Instance.new("Frame")
			sparkle.Name = "Sparkle"
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.Position = centerPos
			sparkle.BackgroundColor3 = Color3.fromRGB(
				200 + math.random(0, 55),
				200 + math.random(0, 55),
				200 + math.random(0, 55)
			)
			sparkle.BorderSizePixel = 0
			sparkle.ZIndex = 3

			local sz = math.random(4, 10)
			sparkle.Size = UDim2.new(0, sz, 0, sz)

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = sparkle

			sparkle.Parent = parent

			local angle = math.rad(math.random(0, 360))
			local dist = 80 + math.random(0, 180)
			local tx = centerPos.X.Offset + math.cos(angle) * dist
			local ty = centerPos.Y.Offset + math.sin(angle) * dist - 40

			TweenService:Create(sparkle, TweenInfo.new(0.6 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(centerPos.X.Scale, tx, centerPos.Y.Scale, ty),
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 2, 0, 2),
			}):Play()

			Debris:AddItem(sparkle, 1)
		end)
	end
end

local function animate_logo(logo: GuiObject?): ()
	if not logo then
		return
	end

	local originalPos = logo.Position
	local originalAnchor = logo.AnchorPoint
	local parent = logo.Parent

	local uiScale = logo:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = logo
	end

	logo.AnchorPoint = originalAnchor
	logo.Position = originalPos - UDim2.new(0, 0, 0.3, 0)
	uiScale.Scale = 1.4
	logo.Rotation = -8

	local function set_logo_transparency(t: number): ()
		for _, node in ipairs(logo:GetDescendants()) do
			if node:IsA("ImageLabel") or node:IsA("ImageButton") then
				node.ImageTransparency = t
			elseif node:IsA("TextLabel") then
				node.TextTransparency = t
				node.TextStrokeTransparency = math.min(t + 0.3, 1)
			elseif node:IsA("UIStroke") then
				node.Transparency = t
			end
		end

		if logo:IsA("ImageLabel") then
			logo.ImageTransparency = t
		end
	end

	set_logo_transparency(1)

	task.delay(0.05, function()
		local fadeSteps = 8

		for step = 1, fadeSteps do
			local alpha = step / fadeSteps
			set_logo_transparency(1 - alpha)
			task.wait(0.15 / fadeSteps)
		end

		set_logo_transparency(0)
	end)

	local slamInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.05)
	local slamTween = TweenService:Create(logo, slamInfo, {
		Position = originalPos + UDim2.new(0, 0, 0.01, 0),
		Rotation = 2,
	})

	local scaleSlamInfo = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.05)
	local scaleSlam = TweenService:Create(uiScale, scaleSlamInfo, {
		Scale = 1.05,
	})

	slamTween:Play()
	scaleSlam:Play()

	slamTween.Completed:Connect(function()
		local squashInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(uiScale, squashInfo, { Scale = 0.92 }):Play()

		local logoCenter = UDim2.new(
			originalPos.X.Scale,
			originalPos.X.Offset,
			originalPos.Y.Scale,
			originalPos.Y.Offset + 20
		)

		spawn_shockwave(parent, logoCenter)

		spawn_impact_sparkles(parent, UDim2.new(
			0,
			parent.AbsoluteSize.X * originalPos.X.Scale + originalPos.X.Offset,
			0,
			parent.AbsoluteSize.Y * originalPos.Y.Scale + originalPos.Y.Offset
			), 14)

		task.delay(0.08, function()
			local bounceInfo = TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)

			TweenService:Create(logo, bounceInfo, {
				Position = originalPos,
				Rotation = 0,
			}):Play()

			TweenService:Create(uiScale, bounceInfo, {
				Scale = 1,
			}):Play()
		end)

		task.delay(0.8, function()
			local floatUp = true
			local floatOffset = 6

			task.spawn(function()
				while logo and logo.Parent and not _G.Loaded do
					local targetY = floatUp and -floatOffset or floatOffset
					local rotTarget = floatUp and -1.2 or 1.2
					local scaleTarget = floatUp and 1.02 or 0.98

					TweenService:Create(logo, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						Position = originalPos + UDim2.new(0, 0, 0, targetY),
						Rotation = rotTarget,
					}):Play()

					TweenService:Create(uiScale, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						Scale = scaleTarget,
					}):Play()

					floatUp = not floatUp
					task.wait(1.8)
				end

				if logo and logo.Parent then
					TweenService:Create(logo, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Position = originalPos,
						Rotation = 0,
					}):Play()

					TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Scale = 1,
					}):Play()
				end
			end)
		end)
	end)
end

local function fade_logo_out(logo: GuiObject?): ()
	if not logo then
		return
	end

	local uiScale = logo:FindFirstChildOfClass("UIScale")
	local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)

	if uiScale then
		TweenService:Create(uiScale, fadeInfo, { Scale = 0.7 }):Play()
	end

	TweenService:Create(logo, fadeInfo, {
		Position = logo.Position + UDim2.new(0, 0, 0.05, 0),
		Rotation = 3,
	}):Play()

	local nodes = { logo }

	for _, descendant in ipairs(logo:GetDescendants()) do
		table.insert(nodes, descendant)
	end

	local fadeTweens = {}
	local nodeFadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	for _, node in ipairs(nodes) do
		if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then
			table.insert(fadeTweens, TweenService:Create(node, nodeFadeInfo, {
				BackgroundTransparency = 1,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}))
		elseif node:IsA("ImageLabel") or node:IsA("ImageButton") then
			table.insert(fadeTweens, TweenService:Create(node, nodeFadeInfo, {
				BackgroundTransparency = 1,
				ImageTransparency = 1,
			}))
		elseif node:IsA("GuiObject") then
			table.insert(fadeTweens, TweenService:Create(node, nodeFadeInfo, {
				BackgroundTransparency = 1,
			}))
		elseif node:IsA("UIStroke") then
			table.insert(fadeTweens, TweenService:Create(node, nodeFadeInfo, {
				Transparency = 1,
			}))
		end
	end

	for _, tween in ipairs(fadeTweens) do
		tween:Play()
	end

	task.wait(0.5)
end

local function should_skip_instance(instance: Instance, ignoredRoots: { Instance }?): boolean
	if not ignoredRoots then
		return false
	end

	for _, root in ipairs(ignoredRoots) do
		if instance == root or instance:IsDescendantOf(root) then
			return true
		end
	end

	return false
end

local function fade_out_loading_screen(screen: ScreenGui, ignoredRoots: { Instance }?): ()
	local fadeTweens = {}
	local fadeInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	for _, descendant in ipairs(screen:GetDescendants()) do
		if should_skip_instance(descendant, ignoredRoots) then
			continue
		end

		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			table.insert(fadeTweens, TweenService:Create(descendant, fadeInfo, {
				BackgroundTransparency = 1,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}))
		elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
			table.insert(fadeTweens, TweenService:Create(descendant, fadeInfo, {
				BackgroundTransparency = 1,
				ImageTransparency = 1,
			}))
		elseif descendant:IsA("GuiObject") then
			table.insert(fadeTweens, TweenService:Create(descendant, fadeInfo, {
				BackgroundTransparency = 1,
			}))
		elseif descendant:IsA("UIStroke") then
			table.insert(fadeTweens, TweenService:Create(descendant, fadeInfo, {
				Transparency = 1,
			}))
		end
	end

	for _, tween in ipairs(fadeTweens) do
		tween:Play()
	end

	if #fadeTweens > 0 then
		fadeTweens[1].Completed:Wait()
	else
		task.wait(0.8)
	end
end

local function safe_preload(instances: { Instance }): ()
	if #instances == 0 then
		return
	end

	local success, err = pcall(function()
		ContentProvider:PreloadAsync(instances)
	end)

	if not success then
		warn(("[LoadingScreen] Preload falhou: %s"):format(tostring(err)))
	end
end

local function collect_preload_targets(): { Instance }
	local targets = {}
	local roots = {
		ReplicatedStorage:FindFirstChild("Assets"),
		ReplicatedStorage:FindFirstChild("Animations"),
		playerGui:FindFirstChild("Main"),
	}

	for _, root in ipairs(roots) do
		if root then
			table.insert(targets, root)

			for _, descendant in ipairs(root:GetDescendants()) do
				table.insert(targets, descendant)
			end
		end
	end

	if #targets == 0 then
		targets = game:GetDescendants()
	end

	return targets
end

local function wait_for_screen_guis(timeout: number): ()
	local guiNames = { "UI", "GUI" }
	local deadline = os.clock() + timeout

	for _, name in ipairs(guiNames) do
		while os.clock() < deadline do
			local gui = playerGui:FindFirstChild(name)
			if gui then
				break
			end
			task.wait(0.1)
		end
	end
end

local function enable_main_guis(): ()
	local guiNames = { "UI", "GUI" }

	for _, name in ipairs(guiNames) do
		local gui = playerGui:WaitForChild(name, 10)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = true
		end
	end
end

local function move_loading_container_to_overlay(screen: ScreenGui, container: Instance?): ScreenGui?
	if not container then
		return nil
	end

	local existing = playerGui:FindFirstChild(PERSISTENT_OVERLAY_NAME)
	if existing and existing:IsA("ScreenGui") then
		existing:Destroy()
	end

	local overlay = Instance.new("ScreenGui")
	overlay.Name = PERSISTENT_OVERLAY_NAME
	overlay.ResetOnSpawn = false
	overlay.IgnoreGuiInset = screen.IgnoreGuiInset
	overlay.DisplayOrder = screen.DisplayOrder
	overlay.ZIndexBehavior = screen.ZIndexBehavior
	overlay.Enabled = true
	overlay.Parent = playerGui

	container.Parent = overlay

	return overlay
end

------------------//MAIN FUNCTIONS
local logo = find_logo(loadScreen)
make_logo_fully_visible(logo)
animate_logo(logo)

if not game:IsLoaded() then
	game.Loaded:Wait()
end

wait_for_screen_guis(15)
safe_preload(collect_preload_targets())

task.wait(0.8)

if loadingScript then
	loadingScript.Enabled = false
end

local overlay = move_loading_container_to_overlay(loadScreen, loadingContainer)

_G.Loaded = true

fade_logo_out(logo)

local ignoredRoots: { Instance }? = nil
if logo then
	ignoredRoots = { logo }
end

fade_out_loading_screen(loadScreen, ignoredRoots)

loadScreen.Enabled = false
loadScreen:Destroy()
overlay:Destroy()

enable_main_guis()

------------------//INIT