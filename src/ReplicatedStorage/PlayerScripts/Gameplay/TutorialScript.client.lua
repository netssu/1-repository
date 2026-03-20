------------------// SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

------------------// CONSTANTS
local TYPE_SOUND_ID = "rbxasset://sounds/electronicpingshort.wav"
local BEAM_TEXTURE_ID = "rbxassetid://16848361091" -- Replace with your own arrow texture if you have one.

------------------// VARIABLES
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local tutorialGui = playerGui:WaitForChild("Tutorial")
tutorialGui.IgnoreGuiInset = true
tutorialGui.Enabled = false

local spotlightContainer = tutorialGui:WaitForChild("SpotlightFrame")
spotlightContainer.Active = false
spotlightContainer.Selectable = false

local textLabel = tutorialGui:WaitForChild("Text")
textLabel.Active = false

local TutorialConfig = require(ReplicatedStorage.Modules.Datas.TutorialConfig)
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local OpenedFrames = require(ReplicatedStorage.Modules.Game.HudManager.OpenedFrames)
local UtilityFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local TutorialEvent = UtilityFolder:FindFirstChild("TutorialEvent")

local currentStage = 0
local activeBeam = nil
local activeBeamAttachments = {}
local activeArrowBillboard = nil
local activeArrowPart = nil
local activeArrowTween = nil
local stageConnections = {}

local textAnimToken = 0
local textFloatTween = nil
local focusPulseTween = nil

local focusFrame = spotlightContainer:WaitForChild("FocusFrame")
local spotFrames = {
	Top = spotlightContainer:WaitForChild("Top"),
	Bottom = spotlightContainer:WaitForChild("Bottom"),
	Left = spotlightContainer:WaitForChild("Left"),
	Right = spotlightContainer:WaitForChild("Right")
}

local typingSound = tutorialGui:FindFirstChild("TypingSound")
if not typingSound then
	typingSound = Instance.new("Sound")
	typingSound.Name = "TypingSound"
	typingSound.SoundId = TYPE_SOUND_ID
	typingSound.Volume = 0.14
	typingSound.PlaybackSpeed = 1.1
	typingSound.Parent = tutorialGui
end

------------------// FORWARD DECLARATIONS
local finishTutorial

------------------// HELPERS
local function utf8ToTable(text: string)
	local chars = {}
	for _, codepoint in utf8.codes(text) do
		table.insert(chars, utf8.char(codepoint))
	end
	return chars
end

local function stopTextAnimations()
	textAnimToken += 1

	if textFloatTween then
		textFloatTween:Cancel()
		textFloatTween = nil
	end

	textLabel.Rotation = 0
end

local function playTextFloat(basePos: UDim2)
	if textFloatTween then
		textFloatTween:Cancel()
	end

	textLabel.Position = basePos + UDim2.fromOffset(0, 4)
	textLabel.Rotation = 1.25

	textFloatTween = TweenService:Create(
		textLabel,
		TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{
			Position = basePos + UDim2.fromOffset(0, -4),
			Rotation = -1.25
		}
	)

	textFloatTween:Play()
end

local function typeText(fullText: string, charDelay: number?)
	textAnimToken += 1
	local thisToken = textAnimToken

	local chars = utf8ToTable(fullText or "")
	local lastSound = 0
	charDelay = charDelay or 0.022

	textLabel.Text = ""

	for _, char in ipairs(chars) do
		if thisToken ~= textAnimToken then
			return
		end

		textLabel.Text ..= char

		if char ~= " " and char ~= "\n" and (os.clock() - lastSound) > 0.035 then
			lastSound = os.clock()
			typingSound.TimePosition = 0
			typingSound:Play()
		end

		local waitTime = charDelay
		if char == "." or char == "!" or char == "?" then
			waitTime = charDelay * 5
		elseif char == "," then
			waitTime = charDelay * 2.5
		end

		task.wait(waitTime)
	end
end

local function startFocusPulse()
	if focusPulseTween then
		focusPulseTween:Cancel()
		focusPulseTween = nil
	end

	if focusFrame then
		focusFrame.Visible = false
	end

	for _, frame in pairs(spotFrames) do
		frame.Visible = false
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(0, 0)
	end
end

local function disconnectStageConnections()
	for _, connection in pairs(stageConnections) do
		if typeof(connection) == "RBXScriptConnection" then
			if connection.Connected then
				connection:Disconnect()
			end
		elseif type(connection) == "table" and connection.Disconnect then
			pcall(function()
				connection:Disconnect()
			end)
		end
	end
	stageConnections = {}
end

local function destroyBeam()
	if activeBeam then
		activeBeam:Destroy()
		activeBeam = nil
	end

	for _, attachment in pairs(activeBeamAttachments) do
		if attachment and attachment.Parent then
			attachment:Destroy()
		end
	end
	activeBeamAttachments = {}

	if activeArrowTween then
		activeArrowTween:Cancel()
		activeArrowTween = nil
	end

	if activeArrowBillboard then
		activeArrowBillboard:Destroy()
		activeArrowBillboard = nil
	end

	if activeArrowPart then
		activeArrowPart:Destroy()
		activeArrowPart = nil
	end
end

local function createArrowMarker(target: any, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TutorialArrow"
	billboard.Size = UDim2.fromOffset(56, 56)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "⬇"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = billboard

	if typeof(target) == "Instance" and target:IsA("BasePart") then
		billboard.Adornee = target
		billboard.Parent = tutorialGui
	elseif typeof(target) == "Vector3" then
		local part = Instance.new("Part")
		part.Name = "TutorialArrowMarker"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Position = target
		part.Parent = Workspace

		activeArrowPart = part
		billboard.Adornee = part
		billboard.Parent = tutorialGui
	else
		billboard:Destroy()
		return
	end

	activeArrowBillboard = billboard

	activeArrowTween = TweenService:Create(
		billboard,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(0, 5.2, 0) }
	)
	activeArrowTween:Play()
end

local function createBeam(startPart: BasePart, target: any, beamColor: Color3): Beam
	destroyBeam()

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "TutorialBeamStart"
	attachment0.Position = Vector3.new(0, 2.2, 0)
	attachment0.Parent = startPart

	local attachment1
	local targetForArrow = target

	if typeof(target) == "Vector3" then
		local terrainPart = Workspace.Terrain
		attachment1 = Instance.new("Attachment")
		attachment1.Name = "TutorialBeamEnd"
		attachment1.WorldPosition = target + Vector3.new(0, 2, 0)
		attachment1.Parent = terrainPart
	elseif typeof(target) == "Instance" and target:IsA("BasePart") then
		attachment1 = Instance.new("Attachment")
		attachment1.Name = "TutorialBeamEnd"
		attachment1.Position = Vector3.new(0, math.max(target.Size.Y * 0.5, 1.5), 0)
		attachment1.Parent = target
	else
		warn("[Tutorial] Invalid beam target type.")
		return nil
	end

	table.insert(activeBeamAttachments, attachment0)
	table.insert(activeBeamAttachments, attachment1)

	local colorToUse = Color3.fromRGB(255, 255, 255)

	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.FaceCamera = true
	beam.Width0 = 1.0
	beam.Width1 = 1.35
	beam.Color = ColorSequence.new(colorToUse)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 0.18)
	})
	beam.Texture = BEAM_TEXTURE_ID
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureSpeed = 2.2
	beam.TextureLength = 1.25
	beam.Segments = 12
	beam.Parent = startPart

	activeBeam = beam
	createArrowMarker(targetForArrow, colorToUse)

	return beam
end

local function getGuiElement(path: string): GuiObject?
	local parts = string.split(path, ".")
	local current = playerGui

	for _, part in ipairs(parts) do
		local child = current:FindFirstChild(part)
		if not child then
			warn("[Tutorial] GUI element not found at path:", path, "- stopped at:", part)
			return nil
		end
		current = child
	end

	return current
end

local function getDynamicFirstPogo(): GuiObject?
	local guiFolder = playerGui:FindFirstChild("GUI")
	if not guiFolder then
		return nil
	end

	local vendorFrame = guiFolder:FindFirstChild("VendorFrame")
	if not vendorFrame or not vendorFrame.Visible then
		return nil
	end

	local mainContent = vendorFrame:FindFirstChild("MainContent")
	if not mainContent then
		return nil
	end

	for i = 1, 5 do
		local stickFrame = mainContent:FindFirstChild(tostring(i))
		if stickFrame and stickFrame.Visible then
			local buyBtn = stickFrame:FindFirstChild("BuyButton", true)
			if buyBtn then
				local amountText = buyBtn:FindFirstChild("Amount", true)
				local mainText = buyBtn:FindFirstChild("MainText", true)

				local buttonText = ""
				if amountText then
					buttonText = amountText.Text
				elseif mainText then
					buttonText = mainText.Text
				end

				if buttonText ~= "OWNED" then
					return buyBtn
				end
			end
		end
	end

	return nil
end

local function getDynamicFirstPet(): GuiObject?
	local guiFolder = playerGui:FindFirstChild("GUI")
	if not guiFolder then
		return nil
	end

	local invFrame = guiFolder:FindFirstChild("InventoryFrame")
	if not invFrame or not invFrame.Visible then
		return nil
	end

	local mainContent = invFrame:FindFirstChild("MainContent")
	if not mainContent then
		return nil
	end

	task.wait(0.5)

	local COLOR_EQUIPPED = Color3.fromRGB(197, 255, 209)
	local pets = {}

	for _, child in pairs(mainContent:GetChildren()) do
		if child:IsA("Frame") and child.Visible and child.Name ~= "UIGridLayout" then
			table.insert(pets, child)
		end
	end

	if #pets == 0 then
		return nil
	end

	for _, pet in ipairs(pets) do
		if pet.BackgroundColor3 ~= COLOR_EQUIPPED then
			return pet
		end
	end

	return pets[1]
end

local function getSpotlightTarget(guiObject: GuiObject, paddingPx: number): (UDim2, UDim2)
	local absPos = guiObject.AbsolutePosition
	local absSize = guiObject.AbsoluteSize
	local inset = GuiService:GetGuiInset()

	local centerX = absPos.X + (absSize.X * 0.5)
	local centerY = absPos.Y + (absSize.Y * 0.5) + inset.Y

	local targetW = absSize.X + (paddingPx * 2)
	local targetH = absSize.Y + (paddingPx * 2)

	return UDim2.fromOffset(centerX, centerY), UDim2.fromOffset(targetW, targetH)
end

local function tweenSpotlight(duration: number, targetPos: UDim2?, targetSize: UDim2?, easingStyle: Enum.EasingStyle?, isCircle: boolean?)
	if focusFrame then
		focusFrame.Visible = false
		focusFrame.BackgroundTransparency = 1
		focusFrame.Size = UDim2.fromOffset(0, 0)
	end

	for _, frame in pairs(spotFrames) do
		frame.Visible = false
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(0, 0)
		frame.Active = false
	end
end

local function updateTextLabel(stageData: any)
	stopTextAnimations()

	local finalText = stageData.Text.Text or ""
	local basePos = stageData.Text.Position or UDim2.fromScale(0.5, 0.14)

	textLabel.Position = basePos
	textLabel.Size = stageData.Text.Size or UDim2.fromScale(0.56, 0.1)
	textLabel.TextSize = stageData.Text.TextSize or 18
	textLabel.Text = ""
	textLabel.TextTransparency = 0

	textLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.BackgroundTransparency = 0.08
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

	local textStroke = textLabel:FindFirstChildWhichIsA("UIStroke")
	if textStroke then
		textStroke.Color = Color3.fromRGB(0, 0, 0)
		textStroke.Transparency = 0
		textStroke.Thickness = 1.5
	end

	playTextFloat(basePos)

	task.spawn(function()
		typeText(finalText, stageData.Text.TypeSpeed or 0.022)
	end)
end

local function executeStage(stageNumber: number)
	disconnectStageConnections()
	destroyBeam()

	local stageData = TutorialConfig.getStage(stageNumber)
	if not stageData or not stageData.Enabled then
		finishTutorial()
		return
	end

	updateTextLabel(stageData)

	local foundButton = nil

	if stageData.Spotlight and stageData.Spotlight.Enabled then
		task.spawn(function()
			if stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_POGO" or stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_PET" then
				task.wait(0.5)

				if stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_POGO" then
					foundButton = getDynamicFirstPogo()
					if not foundButton then
						task.wait(0.5)
						foundButton = getDynamicFirstPogo()
					end
				elseif stageData.Spotlight.GuiPath == "DYNAMIC_FIRST_PET" then
					foundButton = getDynamicFirstPet()
					if not foundButton then
						task.wait(0.5)
						foundButton = getDynamicFirstPet()
					end
				end
			else
				task.wait(0.1)
				foundButton = getGuiElement(stageData.Spotlight.GuiPath)
			end

			if foundButton then
				local pos, size = getSpotlightTarget(foundButton, stageData.Spotlight.Padding or 10)
				local isCircle = stageData.Spotlight.IsCircle == true
				tweenSpotlight(0.25, pos, size, Enum.EasingStyle.Quad, isCircle)
			else
				if stageData.Spotlight.GuiPath then
					warn("[Tutorial] Element not found:", stageData.Spotlight.GuiPath)
				end

				if stageData.Spotlight.Position and stageData.Spotlight.Size then
					local isCircle = stageData.Spotlight.IsCircle == true
					tweenSpotlight(0.25, stageData.Spotlight.Position, stageData.Spotlight.Size, nil, isCircle)
				else
					tweenSpotlight(0.25)
				end
			end
		end)
	else
		tweenSpotlight(0.25)
	end

	if stageData.Trail and stageData.Trail.Enabled then
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			local hrp = character:WaitForChild("HumanoidRootPart", 5)

			if not hrp then
				return
			end

			if stageData.Trail.TargetType == "World" and type(stageData.Trail.TargetPath) == "string" then
				local targetName = stageData.Trail.TargetPath
				local targetPart = Workspace:FindFirstChild(targetName, true)

				if not targetPart and targetName == "CommonEgg" then
					local folderEgg = Workspace:FindFirstChild("FolderEgg")
					if folderEgg then
						local model = folderEgg:FindFirstChild("CommonEgg")
						if model then
							targetPart = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
						end
					end
				end

				if targetPart then
					createBeam(hrp, targetPart, stageData.Trail.Color)
				end
			elseif stageData.Trail.TargetType == "Position" and type(stageData.Trail.TargetPath) == "table" then
				local pos = Vector3.new(
					stageData.Trail.TargetPath.X,
					stageData.Trail.TargetPath.Y,
					stageData.Trail.TargetPath.Z
				)
				createBeam(hrp, pos, stageData.Trail.Color)
			end
		end)
	end

	local condition = stageData.WaitForCondition

	if condition == "Wait" then
		task.wait(stageData.ConditionValue or 2)
		player:SetAttribute("TutorialStage", stageNumber + 1)

	elseif condition == "PositionReached" then
		local targetPos = Vector3.new(0, 0, 0)
		if type(stageData.ConditionValue) == "table" then
			targetPos = Vector3.new(stageData.ConditionValue.X, stageData.ConditionValue.Y, stageData.ConditionValue.Z)
		end

		local requiredDistance = stageData.ConditionRadius or 3

		local conn = RunService.Heartbeat:Connect(function()
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				local dist = (char.HumanoidRootPart.Position - targetPos).Magnitude
				if dist <= requiredDistance then
					tweenSpotlight(0.35)
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "CoinsReached" then
		local targetCoins = stageData.ConditionValue or 200
		local startJumps = player:GetAttribute("Jumps") or 0

		local jumpConn = player:GetAttributeChangedSignal("Jumps"):Connect(function()
			local currentJumps = player:GetAttribute("Jumps") or 0
			if currentJumps > startJumps then
				tweenSpotlight(0.35)
			end
		end)
		table.insert(stageConnections, jumpConn)

		local function checkCoins(val)
			if val and val >= targetCoins then
				task.wait(0.35)
				tweenSpotlight(0.35)
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end

		local currentCoins = DataUtility.client.get("Coins")
		if currentCoins and currentCoins >= targetCoins then
			checkCoins(currentCoins)
		else
			local bindConn = DataUtility.client.bind("Coins", function(coins)
				checkCoins(coins)
			end)
			table.insert(stageConnections, bindConn)
		end

	elseif condition == "Jumps" then
		local requiredJumps = stageData.ConditionValue or 1
		local startJumps = player:GetAttribute("Jumps") or 0
		local jumpsCounted = 0

		local conn = player:GetAttributeChangedSignal("Jumps"):Connect(function()
			local current = player:GetAttribute("Jumps") or 0
			if current > startJumps then
				local diff = current - startJumps
				jumpsCounted += diff
				startJumps = current

				if jumpsCounted >= 1 then
					tweenSpotlight(0.35)
				end

				if jumpsCounted >= requiredJumps then
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "ButtonClick" then
		task.spawn(function()
			local attempts = 0
			while not foundButton and attempts < 12 do
				task.wait(0.2)
				attempts += 1
			end

			local targetBtn = foundButton or (stageData.Spotlight.GuiPath and getGuiElement(stageData.Spotlight.GuiPath))
			if targetBtn and targetBtn:IsA("GuiObject") then
				local triggered = false

				local function triggerNextStage()
					if triggered then
						return
					end
					triggered = true
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end

				if targetBtn:IsA("GuiButton") or targetBtn:IsA("ImageButton") or targetBtn:IsA("TextButton") then
					table.insert(stageConnections, targetBtn.Activated:Connect(triggerNextStage))
					table.insert(stageConnections, targetBtn.MouseButton1Click:Connect(triggerNextStage))
				else
					table.insert(stageConnections, targetBtn.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							triggerNextStage()
						end
					end))

					local inputConn = UserInputService.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							local mousePos = UserInputService:GetMouseLocation()
							local inset = GuiService:GetGuiInset()

							local x = mousePos.X
							local y = mousePos.Y - inset.Y

							local pos = targetBtn.AbsolutePosition
							local size = targetBtn.AbsoluteSize

							if x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y then
								triggerNextStage()
							end
						end
					end)
					table.insert(stageConnections, inputConn)
				end
			end
		end)

	elseif condition == "PogoPurchase" then
		local function checkPogoBought(val)
			if val then
				local count = 0
				for _ in pairs(val) do
					count += 1
				end

				if count > 1 then
					task.wait(0.35)
					tweenSpotlight(0.35)
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end
		end

		local currentPogos = DataUtility.client.get("OwnedPogos")
		local currentCount = 0
		if currentPogos then
			for _ in pairs(currentPogos) do
				currentCount += 1
			end
		end

		if currentCount > 1 then
			checkPogoBought(currentPogos)
		else
			local bindConn = DataUtility.client.bind("OwnedPogos", function(pogos)
				checkPogoBought(pogos)
			end)
			table.insert(stageConnections, bindConn)
		end

	elseif condition == "Purchase" then
		local conn = player:GetAttributeChangedSignal("LastPurchase"):Connect(function()
			if player:GetAttribute("LastPurchase") == stageData.ConditionValue then
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "ShopClosed" or condition == "InventoryClosed" then
		local targetFrameName = condition == "ShopClosed" and "VendorFrame" or "InventoryFrame"
		local guiFolder = playerGui:FindFirstChild("GUI")
		local frame = nil

		if guiFolder then
			frame = guiFolder:FindFirstChild(targetFrameName)
		else
			frame = playerGui:FindFirstChild(targetFrameName, true)
		end

		if frame then
			local conn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
				if not frame.Visible then
					task.wait(0.2)
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end)
			table.insert(stageConnections, conn)

			if not frame.Visible then
				task.wait(0.3)
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end

		if OpenedFrames and type(OpenedFrames) == "table" and OpenedFrames.FrameClosed then
			local conn = OpenedFrames.FrameClosed.Event:Connect(function(fName)
				if fName == "Shop" or fName == targetFrameName then
					task.wait(0.35)
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end)
			table.insert(stageConnections, conn)
		end

	elseif condition == "ConfirmationOpened" then
		local guiFolder = playerGui:FindFirstChild("GUI")
		local confFrame = guiFolder and guiFolder:FindFirstChild("ConfirmationFrame")

		if confFrame then
			local conn = confFrame:GetPropertyChangedSignal("Visible"):Connect(function()
				if confFrame.Visible then
					task.wait(0.2)
					player:SetAttribute("TutorialStage", stageNumber + 1)
				end
			end)
			table.insert(stageConnections, conn)

			if confFrame.Visible then
				task.wait(0.3)
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end

	elseif condition == "EggPurchase" then
		local advanced = false

		local function advanceStage()
			if advanced then
				return
			end
			advanced = true
			task.wait(0.35)
			player:SetAttribute("TutorialStage", stageNumber + 1)
		end

		if player:GetAttribute("EggAnimationFinished") == true then
			player:SetAttribute("EggAnimationFinished", false)
		end

		local conn = player:GetAttributeChangedSignal("EggAnimationFinished"):Connect(function()
			if player:GetAttribute("EggAnimationFinished") == true then
				local lastEgg = player:GetAttribute("LastEggPurchase")
				local expectedEgg = stageData.ConditionValue

				advanceStage()
			end
		end)
		table.insert(stageConnections, conn)

		task.spawn(function()
			while player:GetAttribute("Tutorial") and player:GetAttribute("TutorialStage") == stageNumber and not advanced do
				local ownedPets = DataUtility.client.get("OwnedPets")
				if ownedPets then
					for petName, isOwned in pairs(ownedPets) do
						if isOwned == true then
							advanceStage()
							return
						end
					end
				end
				task.wait(4)
			end
		end)
	elseif condition == "PetEquipped" then
		local function checkPetEquipped()
			local equippedPets = DataUtility.client.get("EquippedPets")
			if equippedPets then
				for _, petId in pairs(equippedPets) do
					if petId and petId ~= "" then
						return true
					end
				end
			end
			return false
		end

		if checkPetEquipped() then
			task.wait(0.35)
			player:SetAttribute("TutorialStage", stageNumber + 1)
		else
			local bindConn = DataUtility.client.bind("EquippedPets", function(val)
				if val then
					for _, petId in pairs(val) do
						if petId and petId ~= "" then
							task.wait(0.35)
							player:SetAttribute("TutorialStage", stageNumber + 1)
							return
						end
					end
				end
			end)
			table.insert(stageConnections, bindConn)
		end

	elseif condition == "RingCollected" then
		local startRings = player:GetAttribute("RingsCollected") or 0

		local conn = player:GetAttributeChangedSignal("RingsCollected"):Connect(function()
			local currentRings = player:GetAttribute("RingsCollected") or 0
			if currentRings > startRings then
				tweenSpotlight(0.35)
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end)
		table.insert(stageConnections, conn)

	elseif condition == "PerfectLanding" then

	elseif condition == "ChestOpened" then
		local startChests = player:GetAttribute("ChestsOpened") or 0

		local conn = player:GetAttributeChangedSignal("ChestsOpened"):Connect(function()
			local currentChests = player:GetAttribute("ChestsOpened") or 0
			if currentChests > startChests then
				tweenSpotlight(0.35)
				player:SetAttribute("TutorialStage", stageNumber + 1)
			end
		end)
		table.insert(stageConnections, conn)
	end
end

local function startTutorial()
	local tutorialCompleted = DataUtility.client.get("TutorialCompleted")
	if tutorialCompleted then
		return
	end

	currentStage = 0
	tutorialGui.Enabled = true

	focusFrame.Visible = false
	focusFrame.Size = UDim2.fromOffset(0, 0)
	focusFrame.Position = UDim2.fromScale(0.5, 0.5)
	focusFrame.BackgroundTransparency = 1
	focusFrame.Active = false
	focusFrame.Selectable = false

	for _, child in ipairs(focusFrame:GetChildren()) do
		if child:IsA("UIStroke") then
			child.Transparency = 1
		end
	end

	for _, frame in pairs(spotFrames) do
		frame.Visible = false
		frame.Size = UDim2.fromScale(0, 0)
		frame.BackgroundTransparency = 1
		frame.Active = false
		frame.Selectable = false

		if frame:IsA("TextButton") then
			frame.Text = ""
			frame.AutoButtonColor = false
		end
	end

	spotlightContainer.BackgroundTransparency = 1
	spotlightContainer.BorderSizePixel = 0
	spotlightContainer.AnchorPoint = Vector2.new(0, 0)
	spotlightContainer.Position = UDim2.fromScale(0, 0)
	spotlightContainer.Size = UDim2.fromScale(1, 1)
	spotlightContainer.ZIndex = 1

	textLabel.ZIndex = 40
	textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	textLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.BackgroundTransparency = 0.08
	textLabel.TextColor3 = Color3.fromRGB(20, 20, 20)
	textLabel.TextWrapped = true
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextTransparency = 0
	textLabel.Rotation = 0

	if not textLabel:FindFirstChildWhichIsA("UIStroke") then
		local textStroke = Instance.new("UIStroke")
		textStroke.Color = Color3.fromRGB(0, 0, 0)
		textStroke.Thickness = 1.5
		textStroke.Transparency = 0.75
		textStroke.Parent = textLabel
	end

	if not textLabel:FindFirstChildWhichIsA("UICorner") then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = textLabel
	end

	if not textLabel:FindFirstChildWhichIsA("UIPadding") then
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 14)
		padding.PaddingRight = UDim.new(0, 14)
		padding.PaddingTop = UDim.new(0, 8)
		padding.PaddingBottom = UDim.new(0, 8)
		padding.Parent = textLabel
	end

	startFocusPulse()

	player:SetAttribute("TutorialStage", 0)
	player:SetAttribute("Tutorial", true)
	player:SetAttribute("Jumps", 0)

	executeStage(0)
end

finishTutorial = function()
	disconnectStageConnections()
	destroyBeam()
	stopTextAnimations()

	if focusPulseTween then
		focusPulseTween:Cancel()
		focusPulseTween = nil
	end

	focusFrame.Visible = false
	focusFrame.BackgroundTransparency = 1
	focusFrame.Size = UDim2.fromOffset(0, 0)

	for _, frame in pairs(spotFrames) do
		frame.Visible = false
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromScale(0, 0)
	end

	TweenService:Create(textLabel, TweenInfo.new(0.35), {
		TextTransparency = 1,
		BackgroundTransparency = 1
	}):Play()

	local textStroke = textLabel:FindFirstChildWhichIsA("UIStroke")
	if textStroke then
		TweenService:Create(textStroke, TweenInfo.new(0.35), {
			Transparency = 1
		}):Play()
	end

	task.wait(0.5)
	tutorialGui.Enabled = false

	player:SetAttribute("Tutorial", nil)
	player:SetAttribute("TutorialStage", nil)
	currentStage = 0

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local remotes = assets:FindFirstChild("Remotes")
		if remotes then
			local finishEvent = remotes:FindFirstChild("FinishTutorial")
			if finishEvent then
				finishEvent:FireServer()
			end
		end
	end
end

------------------// INIT
player:GetAttributeChangedSignal("TutorialStage"):Connect(function()
	if not player:GetAttribute("Tutorial") then
		return
	end

	local newStage = player:GetAttribute("TutorialStage")
	if newStage and newStage > currentStage then
		currentStage = newStage
		executeStage(currentStage)
	end
end)

TutorialEvent.Event:Connect(function(action)
	local stageNumber = player:GetAttribute("TutorialStage")
	if stageNumber == 11 then
		tweenSpotlight(0.35)
		player:SetAttribute("TutorialStage", stageNumber + 1)
	end
end)


task.spawn(function()
	if not player.Character then
		player.CharacterAdded:Wait()
	end

	local tutorialCompleted = DataUtility.client.get("TutorialCompleted")
	local rebirths = DataUtility.client.get("Rebirths") or 0
	local pogos = DataUtility.client.get("OwnedPogos")

	local count = 0
	if pogos then
		for _ in pairs(pogos) do
			count += 1
		end
	end

	if tutorialCompleted or count > 1 or rebirths > 0 then
		return
	end

	startTutorial()
end)