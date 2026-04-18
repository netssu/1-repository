--!strict

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaveTransition = require(ReplicatedStorage:WaitForChild("Modules").WaveTransition)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

ReplicatedFirst:RemoveDefaultLoadingScreen()

local LoadingGui = PlayerGui:WaitForChild("LoadingGui") :: ScreenGui

LoadingGui.Enabled = true 
LoadingGui.IgnoreGuiInset = true 
local WorldImage = LoadingGui:WaitForChild("WorldImage")
local Main = WorldImage:WaitForChild("Main")
local TeleportInfo = Main:WaitForChild("Logo")
local LoadingtextLabel = WorldImage:WaitForChild("LoadingText")
local SkipButton = WorldImage:WaitForChild("SkipButton")

SkipButton.Visible = false
LoadingtextLabel.Visible = true
local ForceLoad = false
local FinishedPreloading = false
local MinimumLoadTime = 4
local CameraLockConnection = nil
local HudConnection = nil
local TextAnimationActive = true
local LogoEffectsActive = false
local logoMotionConnection = nil
local logoBasePosition = nil
local logoBaseRotation = nil
local logoScale = nil
local logoGradient = nil
local logoGradientBaseRotation = nil
local gradientSegments = nil
local gradientCycleDuration = 0
local transitionColor = Color3.new(0, 0, 0)
local PRELOAD_BATCH_SIZE = 24
local PRELOAD_MAX_WAIT_AFTER_MINIMUM = 6
local PRELOAD_PATHS = {
	{ "Assets", "Gameplay", "Animations" },
	{ "Assets", "ReplicatedAnims" },
	{ "Assets", "Skills" },
}
local PRELOAD_CLASS_WHITELIST: {[string]: boolean} = {
	Animation = true,
	Beam = true,
	Decal = true,
	ImageButton = true,
	ImageLabel = true,
	MeshPart = true,
	ParticleEmitter = true,
	Sound = true,
	Texture = true,
	Trail = true,
}

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local function hideHudGui(): ()
	local hudGui = PlayerGui:FindFirstChild("HudGui")
	if hudGui and hudGui:IsA("ScreenGui") then
		hudGui.Enabled = false
	end
end

hideHudGui()

HudConnection = PlayerGui.ChildAdded:Connect(function(child: Instance)
	if child == LoadingGui then
		return
	end
	if child.Name == "HudGui" and child:IsA("ScreenGui") then
		hideHudGui()
	end
end)

local loadingCamPart = nil

local function shouldPreloadInstance(instance: Instance): boolean
	return PRELOAD_CLASS_WHITELIST[instance.ClassName] == true
end

local function appendUniqueInstance(
	targets: {Instance},
	seen: {[Instance]: boolean},
	instance: Instance?
): ()
	if not instance or seen[instance] then
		return
	end
	seen[instance] = true
	table.insert(targets, instance)
end

local function resolveReplicatedPath(pathSegments: {string}): Instance?
	local current: Instance? = ReplicatedStorage
	for _, segment in pathSegments do
		if not current then
			return nil
		end
		current = current:FindFirstChild(segment)
	end
	return current
end

local function collectPreloadTargets(): {Instance}
	local targets: {Instance} = {}
	local seen: {[Instance]: boolean} = {}

	appendUniqueInstance(targets, seen, LoadingGui)

	for _, pathSegments in PRELOAD_PATHS do
		local root: Instance? = resolveReplicatedPath(pathSegments)
		if not root then
			continue
		end

		if shouldPreloadInstance(root) then
			appendUniqueInstance(targets, seen, root)
		end

		for _, descendant in root:GetDescendants() do
			if shouldPreloadInstance(descendant) then
				appendUniqueInstance(targets, seen, descendant)
			end
		end
	end

	return targets
end

local function preloadInBatches(targets: {Instance}): ()
	task.spawn(function()
		for index = 1, #targets, PRELOAD_BATCH_SIZE do
			local batch: {Instance} = {}
			local upperBound = math.min(index + PRELOAD_BATCH_SIZE - 1, #targets)
			for batchIndex = index, upperBound do
				table.insert(batch, targets[batchIndex])
			end

			pcall(function()
				ContentProvider:PreloadAsync(batch)
			end)

			task.wait()
		end

		FinishedPreloading = true
	end)
end

CameraLockConnection = RunService.RenderStepped:Connect(function()
	camera.CameraType = Enum.CameraType.Scriptable
	if loadingCamPart then
		camera.CFrame = loadingCamPart.CFrame
	else
		camera.CFrame = CFrame.new(0, 5000, 0) 
	end
end)

local function setupEnvironment()
	task.spawn(function()
		local foundPart = workspace:WaitForChild("LoadingCamera", 10)
		if foundPart then
			loadingCamPart = foundPart
		end
	end)

	task.spawn(function()
		local npcFolder = workspace:WaitForChild("Loading screen groups", 10)
		if npcFolder then
			for _, npc in pairs(npcFolder:GetChildren()) do
				if npc:IsA("Model") and npc:FindFirstChild("Humanoid") then
					local humanoid = npc.Humanoid
					local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
					local animObj = npc:FindFirstChild("Idle")

					if animObj and animObj:IsA("Animation") then
						local track = animator:LoadAnimation(animObj)
						track.Looped = true
						track:Play()
					end
				end
			end
		end
	end)
end

local function startLogoEffects()
	if LogoEffectsActive then return end
	if not TeleportInfo or not TeleportInfo.Parent then return end

	LogoEffectsActive = true
	logoBasePosition = TeleportInfo.Position
	logoBaseRotation = TeleportInfo.Rotation
	logoGradient = TeleportInfo:FindFirstChildOfClass("UIGradient")
	logoGradientBaseRotation = logoGradient and logoGradient.Rotation or nil
	gradientSegments = {
		{type = "lerp", from = 180, to = 93, dur = 0.8},
		{type = "hold", val = 93, dur = 1.0},
		{type = "lerp", from = 93, to = -93, dur = 2.2},
		{type = "hold", val = -93, dur = 1.0},
		{type = "lerp", from = -93, to = -180, dur = 0.8},
		{type = "lerp", from = -180, to = -93, dur = 0.8},
		{type = "hold", val = -93, dur = 1.0},
		{type = "lerp", from = -93, to = 93, dur = 2.2},
		{type = "hold", val = 93, dur = 1.0},
		{type = "lerp", from = 93, to = 180, dur = 0.8},
	}
	gradientCycleDuration = 0
	for _, seg in gradientSegments do
		gradientCycleDuration += seg.dur
	end

	logoScale = TeleportInfo:FindFirstChild("MotionScale")
	if not logoScale then
		logoScale = Instance.new("UIScale")
		logoScale.Name = "MotionScale"
		logoScale.Parent = TeleportInfo
	end

	local motionStart = os.clock()
	logoMotionConnection = RunService.RenderStepped:Connect(function()
		if not TeleportInfo.Parent then return end
		local t = os.clock() - motionStart
		local yOffset = math.sin(t * 1.05) * 10
		local pulse = 1 + math.sin(t * 1.4) * 0.023
		local tilt = math.sin(t * 0.75) * 1.5
		local gradientRotation = nil
		if logoGradientBaseRotation and gradientSegments and gradientCycleDuration > 0 then
			local cursor = t % gradientCycleDuration
			for _, seg in gradientSegments do
				if cursor <= seg.dur then
					if seg.type == "hold" then
						gradientRotation = seg.val
					else
						local alpha = cursor / seg.dur
						gradientRotation = seg.from + (seg.to - seg.from) * alpha
					end
					break
				else
					cursor -= seg.dur
				end
			end
			if gradientRotation then
				gradientRotation += logoGradientBaseRotation
			end
		end

		TeleportInfo.Position = logoBasePosition + UDim2.fromOffset(0, yOffset)
		TeleportInfo.Rotation = logoBaseRotation + tilt
		logoScale.Scale = pulse

		if logoGradient and gradientRotation then
			logoGradient.Rotation = gradientRotation
		end
	end)
end

local function stopLogoEffects()
	LogoEffectsActive = false
	if logoMotionConnection then
		logoMotionConnection:Disconnect()
		logoMotionConnection = nil
	end
	if TeleportInfo and TeleportInfo.Parent and logoBasePosition then
		TeleportInfo.Position = logoBasePosition
		TeleportInfo.Rotation = logoBaseRotation or 0
		if logoScale then
			logoScale.Scale = 1
		end
		if logoGradient and logoGradientBaseRotation then
			logoGradient.Rotation = logoGradientBaseRotation
		end
	end
end

setupEnvironment()
startLogoEffects()
local startTime = os.clock()
task.spawn(function()
	local preloadTargets = collectPreloadTargets()
	preloadInBatches(preloadTargets)
end)

task.spawn(function()
	local dots = {".", "..", "..."}
	local dotIndex = 1
	while TextAnimationActive do
		LoadingtextLabel.Text = "Loading" .. dots[dotIndex]
		dotIndex = (dotIndex % 3) + 1
		task.wait(0.5)
	end
end)

local function finalizeAndDestroy()
	if CameraLockConnection then
		CameraLockConnection:Disconnect()
		CameraLockConnection = nil
	end

	if HudConnection then
		HudConnection:Disconnect()
		HudConnection = nil
	end

	camera.CameraType = Enum.CameraType.Custom
	if Player.Character then
		local humanoid = Player.Character:FindFirstChild("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end

	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
	local hudGui = PlayerGui:FindFirstChild("HudGui")
	if hudGui and hudGui:IsA("ScreenGui") then
		hudGui.Enabled = true
	end

	if LoadingGui then
		LoadingGui:Destroy()
	end
end

local function playWaveAndFinish()
	local overlayGui = Instance.new("ScreenGui")
	overlayGui.Name = "WaveOverlayGui"
	overlayGui.IgnoreGuiInset = true
	overlayGui.ResetOnSpawn = false
	overlayGui.DisplayOrder = 9999
	overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlayGui.Parent = PlayerGui

	local overlay = Instance.new("Frame")
	overlay.Name = "WaveOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.AnchorPoint = Vector2.new(0.5, 0.5)
	overlay.Position = UDim2.fromScale(0.5, 0.5)
	overlay.ZIndex = 50
	overlay.Parent = overlayGui

	local transition = WaveTransition.new(overlay, {
		color = transitionColor,
		width = 14,
		waveDirection = Vector2.new(1, -0.7),
	})

	for _, square in ipairs(transition.squares) do
		square.ZIndex = 50
	end

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Value = 0
	transition:Update(alphaValue.Value)

	local connection = alphaValue.Changed:Connect(function()
		transition:Update(alphaValue.Value)
	end)

	local tweenIn = TweenService:Create(alphaValue, TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Value = 1})
	tweenIn.Completed:Once(function()
		finalizeAndDestroy()
		local tweenOut = TweenService:Create(alphaValue, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Value = 0})
		tweenOut.Completed:Once(function()
			connection:Disconnect()
			alphaValue:Destroy()
			transition:Destroy()
			overlayGui:Destroy()
		end)
		tweenOut:Play()
	end)

	tweenIn:Play()
end

local function FinishLoadingSequence()
	stopLogoEffects()

	if TeleportInfo then
		TeleportInfo.Visible = false
	end

	SkipButton.Visible = false
	LoadingtextLabel.Visible = false

	local hudGui = PlayerGui:FindFirstChild("HudGui")
	if hudGui and hudGui:IsA("ScreenGui") then
		hudGui.Enabled = false
	end

	playWaveAndFinish()
end

UserInputService.InputBegan:Connect(function(Input, GPE)
	if GPE then return end
	if not SkipButton.Visible then return end

	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.KeyCode == Enum.KeyCode.ButtonA then
		if not ForceLoad then
			ForceLoad = true
		end
	end
end)

task.spawn(function()
	while (os.clock() - startTime) < MinimumLoadTime do
		task.wait(0.1)
	end

	TextAnimationActive = false
	LoadingtextLabel.Visible = false
	SkipButton.Visible = true
	
	task.spawn(function()
		while SkipButton.Parent and not ForceLoad do
			TweenService:Create(SkipButton, TweenInfo.new(0.5), {TextTransparency = 0.5}):Play()
			task.wait(0.5)
			TweenService:Create(SkipButton, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
			task.wait(0.5)
		end
	end)

	local autoContinueAt = startTime + MinimumLoadTime + PRELOAD_MAX_WAIT_AFTER_MINIMUM

	repeat
		task.wait(0.1)
	until game:IsLoaded() and (ForceLoad or FinishedPreloading or os.clock() >= autoContinueAt)

	FinishLoadingSequence()
end)
