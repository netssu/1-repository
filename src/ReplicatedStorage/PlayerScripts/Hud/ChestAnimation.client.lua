------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

------------------//CONSTANTS
local ASSETS_FOLDER = ReplicatedStorage:WaitForChild("Assets")
local CHEST_MODEL_SOURCE = ASSETS_FOLDER:WaitForChild("Chest"):WaitForChild("Chest")
local PARTICLE_SOURCE = ASSETS_FOLDER:WaitForChild("Effects"):WaitForChild("Star")

local CHEST_NAME = "Chest"
local DISTANCE_FROM_CAMERA = 7
local VERTICAL_OFFSET = -1.5
local VIEW_TILT = -25
local CAMERA_RECOIL_DISTANCE = 5
local TWEEN_CAMERA_RECOIL = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HOVER_AMPLITUDE = 0.3
local HOVER_SPEED = 2.5

local TWEEN_POP_UP = TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local TWEEN_SCALE_DOWN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local TWEEN_OPEN_LID = TweenInfo.new(0.7, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
local TWEEN_FLASH = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local TWEEN_BLUR = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local REWARD_RISE_DURATION = 1.2
local REWARD_FADE_DURATION = 0.5
local REWARD_ICON_SIZE = UDim2.fromOffset(80, 80)
local REWARD_SPACING = 100
local ICON_IMAGES = {
	Gold = "rbxassetid://82346463581106",
	Coins2x = "rbxassetid://81187465021797",
	Lucky2x = "rbxassetid://124014027649385",
}

------------------//VARIABLES
local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local isAnimating = false
local currentRenderConnection = nil
local currentVisualChest = nil
local currentLidAngle = 0
local lidRelativeOffset = CFrame.new()
local hoverTime = 0
local blurEffect = nil
local pendingRewards = nil

local rewardEvent = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("ChestRewardEvent")
local SoundController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("SoundUtility"))
local SoundsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("SoundData"))

------------------//FUNCTIONS
local function setupVisualModel(model)
	if not model:IsA("Model") then return false end

	if not model.PrimaryPart then
		local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("WoodBottom")
		if root then
			model.PrimaryPart = root
		else
			return false
		end
	end

	local lidModel = model:FindFirstChild("WoodTop")
	if lidModel and lidModel:IsA("Model") then
		if not lidModel.PrimaryPart then
			local mainPart = lidModel:FindFirstChild("WoodTop")
			if mainPart then
				lidModel.PrimaryPart = mainPart
			end
		end
		if model.PrimaryPart and lidModel.PrimaryPart then
			lidRelativeOffset = model.PrimaryPart.CFrame:Inverse() * lidModel:GetPivot()
		end
	end

	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CastShadow = false
		end
	end
	return true
end

local function playFlashEffect()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChestFlashUI"
	gui.IgnoreGuiInset = true
	gui.Parent = Player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.Parent = gui

	local tween = TweenService:Create(frame, TWEEN_FLASH, {BackgroundTransparency = 1})
	tween:Play()
	tween.Completed:Connect(function()
		gui:Destroy()
	end)
end

local function toggleBlur(state)
	if state then
		if not blurEffect then
			blurEffect = Instance.new("DepthOfFieldEffect")
			blurEffect.Name = "ChestFocus"
			blurEffect.FocusDistance = 0
			blurEffect.InFocusRadius = 15
			blurEffect.NearIntensity = 0
			blurEffect.FarIntensity = 0
			blurEffect.Parent = Lighting
			TweenService:Create(blurEffect, TWEEN_BLUR, {FarIntensity = 0.6}):Play()
		end
	else
		if blurEffect then
			local tween = TweenService:Create(blurEffect, TWEEN_BLUR, {FarIntensity = 0})
			tween:Play()
			tween.Completed:Connect(function()
				if blurEffect then blurEffect:Destroy() blurEffect = nil end
			end)
		end
	end
end

local function activateParticles(chestModel)
	local emitterPart = chestModel:FindFirstChild("EmitterPart")
	if emitterPart and PARTICLE_SOURCE then
		for _, child in pairs(PARTICLE_SOURCE:GetChildren()) do
			local newParticle = child:Clone()
			newParticle.Parent = emitterPart
			if newParticle:IsA("ParticleEmitter") then
				newParticle.Enabled = true
			end
		end
		if PARTICLE_SOURCE:IsA("ParticleEmitter") then
			local newParticle = PARTICLE_SOURCE:Clone()
			newParticle.Parent = emitterPart
			newParticle.Enabled = true
		end
	end
end

local function updateChestTransform(dt)
	if not currentVisualChest or not currentVisualChest.PrimaryPart then return end

	hoverTime += dt
	local hoverY = math.sin(hoverTime * HOVER_SPEED) * HOVER_AMPLITUDE
	local cameraCF = Camera.CFrame
	local targetPosition = cameraCF * CFrame.new(0, VERTICAL_OFFSET + hoverY, -DISTANCE_FROM_CAMERA)
	local orientation = CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(math.rad(VIEW_TILT), 0, 0)
	currentVisualChest:PivotTo(targetPosition * orientation)

	local lid = currentVisualChest:FindFirstChild("WoodTop")
	if lid then
		local startCFrame = currentVisualChest.PrimaryPart.CFrame * lidRelativeOffset
		local hingePivot = CFrame.new(0, -0.5, 1.3)
		local rotation = CFrame.Angles(math.rad(currentLidAngle), 0, 0)
		lid:PivotTo(startCFrame * hingePivot * rotation * hingePivot:Inverse())
	end
end

local function animateLidOpening(chestModel)
	local lid = chestModel:FindFirstChild("WoodTop")
	if not lid then return end

	local angleVal = Instance.new("NumberValue")
	angleVal.Value = 0
	angleVal.Parent = lid

	local connection = angleVal.Changed:Connect(function(val)
		currentLidAngle = val
	end)

	local tween = TweenService:Create(angleVal, TWEEN_OPEN_LID, {Value = 110})
	tween:Play()

	task.spawn(function()
		tween.Completed:Wait()
		connection:Disconnect()
		angleVal:Destroy()
	end)

	return tween
end

local function getChest3DPosition()
	if not currentVisualChest or not currentVisualChest.PrimaryPart then return nil end
	local emitterPart = currentVisualChest:FindFirstChild("EmitterPart")
	return (emitterPart or currentVisualChest.PrimaryPart).Position
end

local function createRewardIcon(iconType, value, index)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ChestRewardIcon"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = Player:WaitForChild("PlayerGui")

	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "IconContainer"
	iconFrame.Size = REWARD_ICON_SIZE
	iconFrame.BackgroundTransparency = 1
	iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	iconFrame.Parent = screenGui

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = iconFrame

	if iconType == "Gold" then
		icon.Image = ICON_IMAGES.Gold
		icon.ImageColor3 = Color3.fromRGB(255, 215, 0)
	elseif iconType == "Coins2x" then
		icon.Image = ICON_IMAGES.Coins2x
		icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	elseif iconType == "Lucky2x" then
		icon.Image = ICON_IMAGES.Lucky2x
		icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end

	if iconType == "Gold" and value then
		local valueLabel = Instance.new("TextLabel")
		valueLabel.Name = "Value"
		valueLabel.Size = UDim2.fromScale(1.5, 0.4)
		valueLabel.Position = UDim2.fromScale(0.5, 1.1)
		valueLabel.AnchorPoint = Vector2.new(0.5, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = "+" .. tostring(value)
		valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		valueLabel.TextStrokeTransparency = 0.5
		valueLabel.TextScaled = true
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.Parent = iconFrame
	else
		local boostLabel = Instance.new("TextLabel")
		boostLabel.Name = "BoostText"
		boostLabel.Size = UDim2.fromScale(1.5, 0.4)
		boostLabel.Position = UDim2.fromScale(0.5, 1.1)
		boostLabel.AnchorPoint = Vector2.new(0.5, 0)
		boostLabel.BackgroundTransparency = 1
		boostLabel.Text = iconType
		boostLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		boostLabel.TextStrokeTransparency = 0.5
		boostLabel.TextScaled = true
		boostLabel.Font = Enum.Font.GothamBold
		boostLabel.Parent = iconFrame
	end

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.Size = UDim2.fromScale(1.5, 1.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundTransparency = 1
	glow.Image = "rbxassetid://4695575676"
	glow.ImageColor3 = icon.ImageColor3
	glow.ImageTransparency = 0.5
	glow.ZIndex = 0
	glow.Parent = iconFrame

	task.spawn(function()
		local rotationSpeed = 50
		while glow and glow.Parent do
			glow.Rotation += rotationSpeed * task.wait()
		end
	end)

	return screenGui, iconFrame
end

local function animateRewardFromChest(iconType, value, index)
	local chest3DPos = getChest3DPosition()
	if not chest3DPos then return end

	local startScreenPos, onScreen = Camera:WorldToViewportPoint(chest3DPos)
	if not onScreen then return end

	local screenGui, iconFrame = createRewardIcon(iconType, value, index)
	if not screenGui then return end

	iconFrame.Position = UDim2.fromOffset(startScreenPos.X, startScreenPos.Y)
	iconFrame.Size = UDim2.fromOffset(0, 0)

	local offsetX = (index - 1.5) * REWARD_SPACING
	local finalX = startScreenPos.X + offsetX
	local finalY = startScreenPos.Y - 200

	local popTween = TweenService:Create(iconFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = REWARD_ICON_SIZE})
	popTween:Play()
	task.wait(0.2)

	local riseTween = TweenService:Create(iconFrame, TweenInfo.new(REWARD_RISE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.fromOffset(finalX, finalY)})
	riseTween:Play()
	riseTween.Completed:Wait()
	task.wait(0.8)

	local fadeInfo = TweenInfo.new(REWARD_FADE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	for _, child in pairs(iconFrame:GetDescendants()) do
		if child:IsA("ImageLabel") then
			TweenService:Create(child, fadeInfo, {ImageTransparency = 1}):Play()
		elseif child:IsA("TextLabel") then
			TweenService:Create(child, fadeInfo, {TextTransparency = 1}):Play()
			TweenService:Create(child, fadeInfo, {TextStrokeTransparency = 1}):Play()
		elseif child:IsA("Frame") then
			TweenService:Create(child, fadeInfo, {BackgroundTransparency = 1}):Play()
		end
	end

	task.wait(REWARD_FADE_DURATION)
	screenGui:Destroy()
end

local function displayRewards(rewards)
	if not rewards then return end

	local rewardItems = {}

	if rewards.gold and rewards.gold > 0 then
		table.insert(rewardItems, {type = "Gold", value = rewards.gold})
	end

	if rewards.potion then
		local iconType = rewards.potion
		if iconType == "CoinsPotion" then iconType = "Coins2x"
		elseif iconType == "LuckyPotion" then iconType = "Lucky2x" end
		table.insert(rewardItems, {type = iconType, value = nil})
	elseif rewards.boost then
		table.insert(rewardItems, {type = rewards.boost, value = nil})
	end

	for index, reward in ipairs(rewardItems) do
		task.spawn(function()
			task.wait((index - 1) * 0.15)
			animateRewardFromChest(reward.type, reward.value, index)
		end)
	end
end

local function playChestSequence(rewards)
	if isAnimating then return end
	isAnimating = true

	local originalCameraCFrame = Camera.CFrame
	local originalCameraType = Camera.CameraType
	Camera.CameraType = Enum.CameraType.Scriptable

	local recoilTween = TweenService:Create(Camera, TWEEN_CAMERA_RECOIL, {CFrame = originalCameraCFrame * CFrame.new(0, 0, CAMERA_RECOIL_DISTANCE)})
	recoilTween:Play()

	hoverTime = 0
	currentLidAngle = 0
	toggleBlur(true)

	currentVisualChest = CHEST_MODEL_SOURCE:Clone()
	if not setupVisualModel(currentVisualChest) then
		isAnimating = false
		Camera.CameraType = originalCameraType
		return
	end

	currentVisualChest.Parent = Camera

	local scaleValue = Instance.new("NumberValue")
	scaleValue.Value = 0.01
	currentVisualChest:ScaleTo(0.01)

	local scaleConnection = scaleValue.Changed:Connect(function(val)
		if currentVisualChest then currentVisualChest:ScaleTo(val) end
	end)

	local popUpTween = TweenService:Create(scaleValue, TWEEN_POP_UP, {Value = 1})
	popUpTween:Play()

	currentRenderConnection = RunService.RenderStepped:Connect(updateChestTransform)
	popUpTween.Completed:Wait()
	scaleConnection:Disconnect()
	scaleValue:Destroy()

	task.spawn(function()
		SoundController.PlaySFX(SoundsData.SFX.OpenChest, Camera)
	end)

	task.wait(0.2)

	local openTween = animateLidOpening(currentVisualChest)
	playFlashEffect()
	activateParticles(currentVisualChest)
	openTween.Completed:Wait()

	if Player:GetAttribute("Tutorial") == true then
		local currentChests = Player:GetAttribute("ChestsOpened") or 0
		Player:SetAttribute("ChestsOpened", currentChests + 1)
	end

	if rewards then
		task.spawn(function()
			SoundController.PlaySFX(SoundsData.SFX.PurchaseChest, Camera)
		end)
		task.wait(0.3)
		displayRewards(rewards)
		task.wait(2.5)
	else
		task.wait(2)
	end

	local exitScaleValue = Instance.new("NumberValue")
	exitScaleValue.Value = 1

	local exitConnection = exitScaleValue.Changed:Connect(function(val)
		if currentVisualChest then currentVisualChest:ScaleTo(val) end
	end)

	local exitTween = TweenService:Create(exitScaleValue, TWEEN_SCALE_DOWN, {Value = 0.01})
	exitTween:Play()
	toggleBlur(false)
	exitTween.Completed:Wait()

	exitConnection:Disconnect()
	exitScaleValue:Destroy()

	if currentRenderConnection then
		currentRenderConnection:Disconnect()
		currentRenderConnection = nil
	end

	if currentVisualChest then
		currentVisualChest:Destroy()
		currentVisualChest = nil
	end

	local returnTween = TweenService:Create(Camera, TWEEN_CAMERA_RECOIL, {CFrame = originalCameraCFrame})
	returnTween:Play()
	returnTween.Completed:Wait()
	Camera.CameraType = originalCameraType

	isAnimating = false
end

------------------//INIT
rewardEvent.OnClientEvent:Connect(function(rewards)
	playChestSequence(rewards)
end)