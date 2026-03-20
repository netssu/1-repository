------------------// SERVICES
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")
local Workspace          = game:GetService("Workspace")
local Debris             = game:GetService("Debris")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")

------------------// CONSTANTS
local FASTER_HATCH_GAMEPASS_ID = 1702677369
local INTERACTION_DISTANCE = 15

local ANIM_SETTINGS = {
	DistanceStart     = 10.5,
	DistanceClose     = 5.5,
	ScriptableOffset  = 5,
	HoverSpeed        = 2,
	HoverAmp          = 0.15,
	EggScale          = 0.85,
	PetScale          = 1.0,
	EggVerticalOffset = -0.5,
	PetVerticalOffset = 0,
}

local SWING_SETTINGS = {
	Angle     = 28,
	Duration  = 0.18,
	ReturnDur = 0.22,
	Style     = Enum.EasingStyle.Quad,
}

local HOVER_SETTINGS = {
	ScaleBoost   = 1.08,
	ScaleSpeed   = 0.15,
	OutlineColor = Color3.fromRGB(255, 220, 60),
	OutlineWidth = 0.7,
	GlowTransp   = 0.35,
}

------------------// VARIABLES
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Utility = Modules:WaitForChild("Utility")
local Data    = Modules:WaitForChild("Datas")

local NotificationController = require(Utility:WaitForChild("NotificationUtility"))
local PETS_DATA_MODULE       = require(Data:WaitForChild("PetsData"))
local RARITYS_DATA_MODULE    = require(Data:WaitForChild("RaritysData"))
local EGGS_DATA_MODULE       = require(Data:WaitForChild("EggData"))

local sounData     = require(Data:WaitForChild("SoundData"))
local soundUtility = require(Utility:WaitForChild("SoundUtility"))

local ASSETS_FOLDER         = ReplicatedStorage:WaitForChild("Assets")
local EFFECTS_FOLDER        = ASSETS_FOLDER:WaitForChild("Effects")
local EGGS_ANIMATION_FOLDER = ASSETS_FOLDER:WaitForChild("Egg")

local REMOTE_NAME             = "EggGachaRemote"
local CHECK_FUNDS_REMOTE_NAME = "CheckEggFundsRemote"

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera    = Workspace.CurrentCamera
local MainUI    = PlayerGui:WaitForChild("UI")

local gachaRemote      = ASSETS_FOLDER:WaitForChild("Remotes"):WaitForChild(REMOTE_NAME)
local checkFundsRemote = ASSETS_FOLDER:WaitForChild("Remotes"):WaitForChild(CHECK_FUNDS_REMOTE_NAME)
local megaEggRemote    = ASSETS_FOLDER:WaitForChild("Remotes"):WaitForChild("MegaEggQueueRemote")

local isOpening         = false
local isWaitingForClick = false
local swingClickCount   = 0
local isSwinging        = false
local clickDebounce     = false

local renderConnection  = nil
local megaEggQueue      = {}
local isProcessingQueue = false

local animationFinished = Instance.new("BindableEvent")
local swingEvent        = Instance.new("BindableEvent")

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local gachaState = {
	Object          = nil,
	CurrentDistance = ANIM_SETTINGS.DistanceStart,
	BaseRotation    = 0,
	SwingAngle      = 0,
	IsPet           = false,
	HoverAlpha      = 0,
	FixedCameraCF   = CFrame.new(),
	OriginalSize    = Vector3.new(1, 1, 1),
	currentEggs     = {},
}

------------------// FUNCTIONS
local function checkIfPetIsOwned(petName)
	return false 
end

local function updateAllEggBoards()
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BillboardGui") then
			for _, uiElement in ipairs(descendant:GetDescendants()) do
				if uiElement:IsA("ImageLabel") then
					local petName = uiElement.Name
					local foundData = PETS_DATA_MODULE.GetPetData(petName)

					if not foundData and uiElement.Parent then
						petName = uiElement.Parent.Name
						foundData = PETS_DATA_MODULE.GetPetData(petName)
					end

					if foundData then
						if checkIfPetIsOwned(petName) then
							uiElement.ImageColor3 = Color3.fromRGB(255, 255, 255)
						else
							uiElement.ImageColor3 = Color3.fromRGB(0, 0, 0)
						end
					end
				end
			end
		end
	end
end

local function toggleEggBoards(isVisible)
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "BuyPart" then
			local billboard = descendant:FindFirstChildOfClass("BillboardGui")
			if billboard then
				billboard.Enabled = isVisible
			end
		end
	end
end

local function findEggRoot(instance)
	local current = instance
	while current and current ~= Workspace do
		if EGGS_DATA_MODULE[current.Name] then return current, current.Name end
		local ref = current:GetAttribute("EggReference")
		if ref and EGGS_DATA_MODULE[ref] then return current, ref end
		current = current.Parent
	end
	return nil, nil
end

local function getNearestEgg()
	local char = Player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
	local hrp = char.HumanoidRootPart

	local closestDist = INTERACTION_DISTANCE
	local eggName = nil

	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant.Name == "BuyPart" and descendant.Parent and descendant.Parent.Name == "Meshes/done_Cylinder.007" then
			local dist = (hrp.Position - descendant.Position).Magnitude
			if dist <= closestDist then
				local root, name = findEggRoot(descendant)
				if root and name then
					closestDist = dist
					eggName = name
				end
			end
		end
	end
	return eggName
end

local function playSwing(direction)
	if isSwinging then return end
	isSwinging = true

	soundUtility.PlaySFX(sounData.SFX.Hatch)

	local target   = SWING_SETTINGS.Angle * direction
	local swingVal = Instance.new("NumberValue")
	swingVal.Value = 0

	swingVal.Changed:Connect(function(v)
		gachaState.SwingAngle = v
	end)

	local t1 = TweenService:Create(
		swingVal,
		TweenInfo.new(SWING_SETTINGS.Duration, SWING_SETTINGS.Style, Enum.EasingDirection.Out),
		{ Value = target }
	)
	t1:Play()
	t1.Completed:Wait()

	local t2 = TweenService:Create(
		swingVal,
		TweenInfo.new(SWING_SETTINGS.ReturnDur, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 0 }
	)
	t2:Play()
	t2.Completed:Wait()

	swingVal:Destroy()
	gachaState.SwingAngle = 0
	isSwinging = false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	if (isMouse or isTouch) and isWaitingForClick then
		swingEvent:Fire()
		return
	end

	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.R then
		if isOpening or clickDebounce then return end

		local eggName = getNearestEgg()
		if not eggName then return end

		local quantity = (input.KeyCode == Enum.KeyCode.E) and 1 or 3
		clickDebounce = true

		local ok, res = pcall(function()
			return checkFundsRemote:InvokeServer(eggName, quantity)
		end)

		if not ok or not res.success then
			local msg = "An error occurred!"
			if res and res.reason == "InsufficientFunds" then
				msg = "Not enough money to open " .. quantity .. " eggs!"
			end
			NotificationController:Show({ message = msg, type = "error", duration = 3 })
			task.delay(1.25, function() clickDebounce = false end)
			return
		end

		isOpening = true
		task.spawn(function()
			playGachaSequence(eggName, quantity)
			clickDebounce = false
		end)
	end
end)

local function checkFasterHatch()
	local success, hasPass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(Player.UserId, FASTER_HATCH_GAMEPASS_ID)
	end)
	return success and hasPass
end

local function spawnParticles(part, rarityColor, isExplosion)
	if not part then return end
	local template = EFFECTS_FOLDER:FindFirstChild("Sparkles")

	if template then
		local visuals = template:Clone()
		visuals.Parent = part

		local function applyColorToEmitter(emitter)
			if emitter:IsA("ParticleEmitter") then
				emitter.Color = ColorSequence.new(rarityColor)
				emitter.LightEmission = 0

				if isExplosion then 
					emitter:Emit(80) 
				else 
					emitter.Enabled = true 
				end
			end
		end

		applyColorToEmitter(visuals)

		for _, desc in ipairs(visuals:GetDescendants()) do
			applyColorToEmitter(desc)
		end

		if isExplosion then Debris:AddItem(visuals, 3) end
	end
end

local function flashScreen(color, duration)
	local gui = Instance.new("ScreenGui")
	gui.IgnoreGuiInset = true
	gui.Parent = PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.Parent = gui

	local tween = TweenService:Create(frame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function() gui:Destroy() end)
end

local function togglePlayerControl(lock)
	local char = Player.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.Anchored = lock
		if lock then
			local offsetCamCF = Camera.CFrame * CFrame.new(0, 15, ANIM_SETTINGS.ScriptableOffset)
			Camera.CFrame = offsetCamCF
			gachaState.FixedCameraCF = offsetCamCF
			Camera.CameraType = Enum.CameraType.Custom
			char.Humanoid.WalkSpeed = 0
		else
			Camera.CameraType = Enum.CameraType.Custom
			char.Humanoid.WalkSpeed = 16
		end
	end
end

local function startRenderLoop()
	if renderConnection then renderConnection:Disconnect() end
	local startTime = os.clock()

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		if not gachaState.Object or not gachaState.Object.Parent then return end

		gachaState.HoverAlpha += dt * ANIM_SETTINGS.HoverSpeed
		local hoverY = math.sin(gachaState.HoverAlpha) * ANIM_SETTINGS.HoverAmp

		local rotationCF = CFrame.Angles(0, math.rad(gachaState.BaseRotation), 0)

		if not gachaState.IsPet then
			rotationCF = rotationCF * CFrame.Angles(0, 0, math.rad(gachaState.SwingAngle))
		end

		local currentVerticalOffset = gachaState.IsPet and ANIM_SETTINGS.PetVerticalOffset or ANIM_SETTINGS.EggVerticalOffset

		local finalCF = Camera.CFrame
			* CFrame.new(0, 0, -gachaState.CurrentDistance)
			* CFrame.new(0, hoverY + currentVerticalOffset, 0)
			* rotationCF

		gachaState.Object.CFrame = finalCF

		local baseScale = gachaState.IsPet and ANIM_SETTINGS.PetScale or ANIM_SETTINGS.EggScale
		gachaState.Object.Size = gachaState.OriginalSize * baseScale
	end)
end

local function cleanup()
	isOpening         = false
	isWaitingForClick = false
	swingClickCount   = 0
	isSwinging        = false

	if renderConnection then renderConnection:Disconnect() end
	if gachaState.Object then gachaState.Object:Destroy() end

	togglePlayerControl(false)
	TweenService:Create(Camera, TweenInfo.new(0.6), { FieldOfView = 70 }):Play()
	animationFinished:Fire()

	toggleEggBoards(true)
	updateAllEggBoards()
end

local function getAnimationEggName(eggName)
	local searchName = eggName .. " Egg"
	if EGGS_ANIMATION_FOLDER:FindFirstChild(searchName) then return searchName end
	if EGGS_ANIMATION_FOLDER:FindFirstChild(eggName)    then return eggName    end

	local eggData = EGGS_DATA_MODULE[eggName]
	if eggData and eggData.Model then
		local modelName = eggData.Model.Name
		if EGGS_ANIMATION_FOLDER:FindFirstChild(modelName) then return modelName end
	end

	for _, egg in ipairs(EGGS_ANIMATION_FOLDER:GetChildren()) do
		if egg.Name:find(eggName) then
			if string.find(egg.Name, "Golden") and not string.find(eggName, "Golden") then continue end
			return egg.Name
		end
	end

	return searchName
end

local function createClickTextLabel()
	local screenGui = Instance.new("ScreenGui")
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder   = 150
	screenGui.ResetOnSpawn   = false
	screenGui.Name           = "ClickToHatchGui"
	screenGui.Parent         = PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(320, 60)
	frame.Position = UDim2.new(0.5, -160, 0.82, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Click to hatch!"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 45
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label

	return screenGui, label
end

local function resolveUI(state: boolean)
	local BarScreen  = PlayerGui:FindFirstChild("BAR")
	local MainScreen = PlayerGui:FindFirstChild("UI")
	if BarScreen  and BarScreen:IsA("ScreenGui")  then BarScreen.Enabled  = state end
	if MainScreen and MainScreen:IsA("ScreenGui") then MainScreen.Enabled = state end
end

local function openEgg(eggName, forcedPetName, isAutoOpen)
	local isFaster  = checkFasterHatch()
	local speedMult = isFaster and 0.5 or 1.2

	local animEggName    = getAnimationEggName(eggName)
	local eggModelSource = EGGS_ANIMATION_FOLDER:FindFirstChild(animEggName)

	if not eggModelSource then
		cleanup()
		return nil
	end

	for _, v in eggModelSource:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			local emitCount = v:GetAttribute("EmitCount") or 10
			v:Emit(emitCount)
		end
	end

	local visualEgg = eggModelSource:Clone()
	visualEgg.CanCollide = false
	visualEgg.Anchored   = true
	visualEgg.Parent     = Camera

	gachaState.Object          = visualEgg
	gachaState.OriginalSize    = visualEgg.Size
	gachaState.CurrentDistance = ANIM_SETTINGS.DistanceStart
	if animEggName == "Frost Egg" or animEggName == "FrostEgg" then
		gachaState.BaseRotation = 180 + 90 
	else
		gachaState.BaseRotation = 180
	end
	gachaState.SwingAngle      = 0
	gachaState.IsPet           = false
	gachaState.HoverAlpha      = 0

	table.insert(gachaState.currentEggs, visualEgg)
	startRenderLoop()

	local petNameResult = forcedPetName

	local distValue = Instance.new("NumberValue")
	distValue.Value = gachaState.CurrentDistance
	distValue.Changed:Connect(function(v) gachaState.CurrentDistance = v end)
	TweenService:Create(distValue,
		TweenInfo.new(1.5 * speedMult, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
		{ Value = ANIM_SETTINGS.DistanceClose }):Play()

	task.wait(1.5 * speedMult)
	distValue:Destroy()

	if isAutoOpen then
		task.spawn(function() playSwing(1) end)
		task.wait(SWING_SETTINGS.Duration + SWING_SETTINGS.ReturnDur + 0.05)
		task.spawn(function() playSwing(-1) end)
		task.wait(SWING_SETTINGS.Duration + SWING_SETTINGS.ReturnDur + 0.05)
	else
		swingClickCount   = 0
		isWaitingForClick = true

		local swingDirections = { 1, -1 }

		while swingClickCount < 2 do
			swingEvent.Event:Wait()

			swingClickCount += 1
			local dir = swingDirections[swingClickCount]

			task.spawn(function() playSwing(dir) end)

			if swingClickCount == 2 then
				task.wait(SWING_SETTINGS.Duration + SWING_SETTINGS.ReturnDur + 0.05)
			end
		end

		isWaitingForClick = false
	end

	if not petNameResult then
		cleanup()
		return nil
	end

	local petData = PETS_DATA_MODULE.GetPetData(petNameResult)
	if not petData then
		cleanup()
		return nil
	end

	local rawRarity = petData.Raritys or "Common"
	local cleanRarity = string.gsub(rawRarity, "Golden%s*", "")
	cleanRarity = string.match(cleanRarity, "^%s*(.-)%s*$")

	local rarityInfo  = RARITYS_DATA_MODULE[cleanRarity]
	local rarityColor = rarityInfo and rarityInfo.Color or Color3.fromRGB(255, 255, 255)

	TweenService:Create(Camera,
		TweenInfo.new(0.35 * speedMult, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = 45 }):Play()
	task.wait(0.35 * speedMult)

	flashScreen(Color3.new(1, 1, 1), 0.45 * speedMult)

	spawnParticles(visualEgg, rarityColor, true)
	visualEgg:Destroy()

	return petData, rarityColor, speedMult, isFaster
end

function playGachaSequence(eggName, quantity, forcedPetNames)
	quantity = math.clamp(math.floor(tonumber(quantity) or 1), 1, 10)

	resolveUI(false)
	toggleEggBoards(false)
	Player:SetAttribute("EggAnimationFinished", false)
	Player:SetAttribute("LastEggPurchase", eggName)
	togglePlayerControl(true)

	local petNames = forcedPetNames
	if not petNames then
		local ok, res = pcall(function()
			return gachaRemote:InvokeServer(eggName, quantity)
		end)
		if not ok or type(res) ~= "table" then
			resolveUI(true)
			isOpening = false
			togglePlayerControl(false)
			return
		end
		petNames = res
	end

	for i = 1, #petNames do
		local isAutoOpen = (i > 1) 
		local clickScreen = nil

		if not isAutoOpen then
			clickScreen = createClickTextLabel()
		end

		local petData, rarityColor, speedMult, isFaster = openEgg(eggName, petNames[i], isAutoOpen)

		if clickScreen then clickScreen:Destroy() end

		if not petData or not petData.MeshPart then
			cleanup()
			resolveUI(true)
			return
		end

		local visualPet = petData.MeshPart:Clone()
		visualPet.CanCollide = false
		visualPet.Anchored   = true
		visualPet.Parent     = Camera

		gachaState.Object          = visualPet
		gachaState.OriginalSize    = visualPet.Size
		gachaState.IsPet           = true
		gachaState.SwingAngle      = 0
		gachaState.BaseRotation    = 180
		gachaState.CurrentDistance = ANIM_SETTINGS.DistanceClose

		visualPet.Size = gachaState.OriginalSize * 0.01

		local popSpeed = 0.045 / (isFaster and 2 or 1)
		for t = 0, 1, popSpeed do
			local overshoot = 1.2
			local period    = 0.3
			local decay     = 6.0
			local scale = 1 + overshoot * math.pow(2, -decay * t) * math.sin((t - period / 4) * (2 * math.pi) / period)
			if t < 0.05 then scale = t * 20 end
			visualPet.Size = gachaState.OriginalSize * (ANIM_SETTINGS.PetScale * scale)
			RunService.RenderStepped:Wait()
		end
		visualPet.Size = gachaState.OriginalSize * ANIM_SETTINGS.PetScale

		spawnParticles(visualPet, rarityColor, false)

		Player:SetAttribute("EggAnimationFinished", true)

		local rotationValue = Instance.new("NumberValue")
		rotationValue.Value = 180
		rotationValue.Changed:Connect(function(v) gachaState.BaseRotation = v end)
		TweenService:Create(rotationValue,
			TweenInfo.new(4 * speedMult, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Value = 180 + 360 }):Play()

		task.wait(2.5 * speedMult)

		local exitSpeed = 0.08 * (isFaster and 2 or 1)
		for t = 1, 0, -exitSpeed do
			visualPet.Size = gachaState.OriginalSize * math.max(0.01, ANIM_SETTINGS.PetScale * t)
			RunService.RenderStepped:Wait()
		end

		rotationValue:Destroy()

		if gachaState.Object then
			gachaState.Object:Destroy()
			gachaState.Object = nil
		end

		if i < #petNames then
			isWaitingForClick = false
			swingClickCount   = 0
			isSwinging        = false
			if renderConnection then renderConnection:Disconnect() end
			TweenService:Create(Camera, TweenInfo.new(0.3), { FieldOfView = 70 }):Play()
			task.wait(0.4)
		end
	end

	resolveUI(true)
	cleanup()
end

local function process_mega_egg_queue()
	if isProcessingQueue then return end
	isProcessingQueue = true

	while #megaEggQueue > 0 do
		if isOpening then animationFinished.Event:Wait() end

		local entry = table.remove(megaEggQueue, 1)
		if not entry then break end

		task.wait(2)

		local GUI = PlayerGui:WaitForChild("GUI", 5)
		if GUI then
			local shop = GUI:FindFirstChild("Shop")
			if shop then shop.Visible = false end
		end

		isOpening = true
		task.spawn(function() playGachaSequence(entry.eggName, nil, entry.petNames) end)
		animationFinished.Event:Wait()
	end

	isProcessingQueue = false
end

------------------// INIT
updateAllEggBoards()

megaEggRemote.OnClientEvent:Connect(function(eggName: string, petsToAnimate: {string})
	table.insert(megaEggQueue, { eggName = eggName, petNames = petsToAnimate })
	task.spawn(process_mega_egg_queue)
end)