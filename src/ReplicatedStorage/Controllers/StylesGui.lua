local StylesGui = {}

------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local MarketPlaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

------------------//PACKAGES
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

------------------//MODULES
local GuiController = require(ReplicatedStorage.Controllers.GuiController)
local NotificationController = require(ReplicatedStorage.Controllers.NotificationController)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local SlotsController = require(ReplicatedStorage.Controllers.SlotsController)
local GachaGuiUtil = require(ReplicatedStorage.Controllers.GachaGuiUtil)
local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)

local DataFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data")
local StylesData = require(DataFolder:WaitForChild("StylesData"))

local UiAnimations = require(ReplicatedStorage.Components.UIAnimation)

------------------//CONSTANTS
local TEXT_FADE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RARITY_HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RARITY_RESET_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CAMERA_OFFSET = CFrame.new(0, 2, -9)
local LOOK_AT_OFFSET = Vector3.new(0, 0.5, -0.5)
local CAMERA_FOLLOW_LERP_SPEED = 10
local CAMERA_RESTORE_TIMEOUT = 0.75
local CAMERA_RESTORE_DISTANCE = 10
local CAMERA_RESTORE_HEIGHT = 3
local CAMERA_RESTORE_LOOK_HEIGHT = 2
local RARITY_ORDER = { "Legendary", "Epic", "Rare", "Uncommon", "Common" }
local STYLE_RARITY_DISPLAY_ORDER = { "Rare", "Epic", "Legendary" }
local FREEZE_INPUT = "FREEZE_INPUT"
local POSITION_SELECTION_ACTIVE_ATTRIBUTE = "FTPositionSelectionActive"
local IN_LOBBY_ATTRIBUTE = "FTIsInLobby"
local MAX_STYLE_SLOTS = 4
local SLOT_PREFIX = "Slot"
local SLOT_SCROLL_STEP_SCALE = 0.75
local RARITY_HOVER_ROTATION = 7
local PREVIEW_STYLE_IDLE_FADE_TIME: number = 0.15

local PRODUCTS_ID = {
	["10Spins"] = 3547265441,
	["30Spins"] = 3547265566,
	["50Spins"] = 3547265643,
}

------------------//VARIABLES
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player.PlayerGui
local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

local currentUpdateSlotsFunction = nil
local currentUpdateTopFunction = nil

local StylesGuiState = {
	_trove = nil,
	_isSpinning = false,
}

local animations = {}
local activeCameraTween: Tween? = nil
local cameraFollowConnection: RBXScriptConnection? = nil
local cameraRestoreConnection: RBXScriptConnection? = nil
local previewCameraCFrame: CFrame? = nil
local previewControlsLocked: boolean = false
local previewStyleIdleModel: Model? = nil
local previewStyleIdleAnimationId: string? = nil
local styleSlotVisualRefsCache = setmetatable({}, { __mode = "k" })
------------------//HELPER FUNCTIONS

local function resolveCamera()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		camera = currentCamera
	end
	return camera
end

local function getHorizontalLookVector(rootPart: BasePart): Vector3
	local lookVector = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if lookVector.Magnitude >= 1e-4 then
		return lookVector.Unit
	end

	local activeCamera = resolveCamera()
	if activeCamera then
		local cameraLook = Vector3.new(activeCamera.CFrame.LookVector.X, 0, activeCamera.CFrame.LookVector.Z)
		if cameraLook.Magnitude >= 1e-4 then
			return cameraLook.Unit
		end
	end

	return Vector3.new(0, 0, -1)
end

local function getCameraBasisCFrame(rootPart: BasePart): CFrame
	local lookVector = getHorizontalLookVector(rootPart)
	return CFrame.lookAt(rootPart.Position, rootPart.Position + lookVector, Vector3.yAxis)
end

local formatMoney = GachaGuiUtil.FormatMoney
local getColorFromData = GachaGuiUtil.GetColorFromData
local toColorSequence = GachaGuiUtil.ToColorSequence
local findDescendantByNames = GachaGuiUtil.FindDescendantByNames
local findMain = GachaGuiUtil.FindMain
local findGuiButtonByNames = GachaGuiUtil.FindGuiButtonByNames
local findTopRightContainer = GachaGuiUtil.FindTopRightContainer
local findTopRightNormalContainer = GachaGuiUtil.FindTopRightNormalContainer
local findTopNameLabel = GachaGuiUtil.FindTopNameLabel
local findFirstTextLabel = GachaGuiUtil.FindFirstTextLabel
local findSlotExtension = GachaGuiUtil.FindSlotExtension
local findSlotExtensionDescriptionLabel = GachaGuiUtil.FindSlotExtensionDescriptionLabel
local setVisibleOnInstance = GachaGuiUtil.SetVisibleOnInstance
local findSlotScrollingFrame = GachaGuiUtil.FindSlotScrollingFrame
local scrollScrollingFrame = GachaGuiUtil.ScrollScrollingFrame
local updateSpinDisplay = GachaGuiUtil.UpdateSpinDisplay

local function findStyleDescriptionLabel(root: Instance?): TextLabel?
	return GachaGuiUtil.FindDescriptionLabel(root, { "DescriptionFrame" }, { "Description" })
end

local function findBottomMiddleButton(main: Instance?, buttonNames: { string }): GuiButton?
	return GachaGuiUtil.FindBottomMiddleButton(main, buttonNames)
end

local function findBottomLeftExitButton(main: Instance?): GuiButton?
	return GachaGuiUtil.FindBottomLeftExitButton(main)
end

local function findSlotStyleNameLabel(slotButton: ImageButton): TextLabel?
	return GachaGuiUtil.FindSlotItemNameLabel(slotButton)
end

local function resolveStyleSlotVisualRefs(slotButton: ImageButton): any
	local cached = styleSlotVisualRefsCache[slotButton]
	if cached and cached.ItemNameLabel and cached.ItemNameLabel.Parent then
		return cached
	end

	local glowImage = slotButton:FindFirstChild("Glow")
	local refs = {
		ItemNameLabel = findSlotStyleNameLabel(slotButton),
		RarityLabel = slotButton:FindFirstChild("Rarity"),
		GlowImage = glowImage,
		MainGradient = slotButton:FindFirstChild("UIGradient"),
		GlowGradient = glowImage and glowImage:FindFirstChild("UIGradient"),
		LockIcon = slotButton:FindFirstChild("Lock", true),
		Extension = findSlotExtension(slotButton),
		ExtensionDescription = findSlotExtensionDescriptionLabel(slotButton),
	}

	for _, child in ipairs(slotButton:GetChildren()) do
		if child:IsA("UIStroke") then
			child:Destroy()
		end
	end

	styleSlotVisualRefsCache[slotButton] = refs
	return refs
end

local function ensureStyleSlotButtons(scrollingFrame: ScrollingFrame): { ImageButton }
	return GachaGuiUtil.EnsureSlotButtons(scrollingFrame, MAX_STYLE_SLOTS, SLOT_PREFIX, "FlowGuiSlotClickHandled")
end

local function getSelectedStyleSlot(): number
	return GachaGuiUtil.GetSelectedSlot(PlayerDataManager, player, { { "SelectedSlot" } }, MAX_STYLE_SLOTS, 1)
end

local function getStyleSlotKey(slotIndex: number): string
	return GachaGuiUtil.GetSlotKey(slotIndex, SLOT_PREFIX)
end

local function isStyleSlotUnlocked(unlockedSlots: { any }, slotIndex: number): boolean
	return GachaGuiUtil.IsSlotUnlocked(unlockedSlots, slotIndex, 1)
end

local function createPreviewStyleIdleAnimation(animationId: string): Animation
	local animation = Instance.new("Animation")
	animation.Name = "StylesGuiPreviewIdle"
	animation.AnimationId = animationId
	return animation
end

local function stopPreviewStyleIdleAnimation(): ()
	local animationId = previewStyleIdleAnimationId
	local animationModel = previewStyleIdleModel
	previewStyleIdleAnimationId = nil
	previewStyleIdleModel = nil

	if typeof(animationId) ~= "string" or animationId == "" or not animationModel then
		return
	end

	local animationSource = createPreviewStyleIdleAnimation(animationId)
	AnimationController.StopAnimationForModel(animationModel, animationSource, PREVIEW_STYLE_IDLE_FADE_TIME)
	animationSource:Destroy()
end

local function playPreviewStyleIdleAnimation(styleId: string?): ()
	local character = player.Character
	if not character or typeof(styleId) ~= "string" or styleId == "" then
		stopPreviewStyleIdleAnimation()
		return
	end

	local styleData = StylesData[styleId]
	local animationId = styleData and styleData.PreviewIdleAnimationId
	if typeof(animationId) ~= "string" or animationId == "" then
		stopPreviewStyleIdleAnimation()
		return
	end

	if previewStyleIdleModel and previewStyleIdleModel ~= character then
		stopPreviewStyleIdleAnimation()
	end

	if previewStyleIdleModel == character and previewStyleIdleAnimationId == animationId then
		local animationSource = createPreviewStyleIdleAnimation(animationId)
		local isPlaying = AnimationController.IsAnimationPlayingForModel(character, animationSource)
		animationSource:Destroy()
		if isPlaying then
			return
		end
	end

	stopPreviewStyleIdleAnimation()

	local animationSource = createPreviewStyleIdleAnimation(animationId)
	local track = AnimationController.PlayAnimationForModel(character, animationSource, {
		Looped = true,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = PREVIEW_STYLE_IDLE_FADE_TIME,
	})
	animationSource:Destroy()

	if track then
		previewStyleIdleModel = character
		previewStyleIdleAnimationId = animationId
	end
end

local function getCameraTargetCFrame()
	local activeCamera = resolveCamera()
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return activeCamera and activeCamera.CFrame or CFrame.new()
	end

	local rootPart = character.HumanoidRootPart
	local basisCFrame = getCameraBasisCFrame(rootPart)
	local camPosCFrame = basisCFrame:ToWorldSpace(CAMERA_OFFSET)
	local lookAtPosition = basisCFrame:PointToWorldSpace(LOOK_AT_OFFSET)
	return CFrame.lookAt(camPosCFrame.Position, lookAtPosition, Vector3.yAxis)
end

local function stopCameraTween(): ()
	if activeCameraTween then
		activeCameraTween:Cancel()
		activeCameraTween = nil
	end
end

local function stopCameraFollow(): ()
	if cameraFollowConnection then
		cameraFollowConnection:Disconnect()
		cameraFollowConnection = nil
	end
	previewCameraCFrame = nil
end

local function stopCameraRestoreWatchdog(): ()
	if cameraRestoreConnection then
		cameraRestoreConnection:Disconnect()
		cameraRestoreConnection = nil
	end
end

local function getGameplayRestoreCFrame(): CFrame?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	local lookVector = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if lookVector.Magnitude < 1e-4 then
		lookVector = Vector3.new(0, 0, -1)
	else
		lookVector = lookVector.Unit
	end

	local focus = rootPart.Position + Vector3.new(0, CAMERA_RESTORE_LOOK_HEIGHT, 0)
	local cameraPosition = focus - (lookVector * CAMERA_RESTORE_DISTANCE) + Vector3.new(0, CAMERA_RESTORE_HEIGHT, 0)
	return CFrame.lookAt(cameraPosition, focus, Vector3.yAxis)
end

local function stopPreviewMovementLock(): ()
	if previewControlsLocked then
		Controls:Enable()
		previewControlsLocked = false
	end
end

local function applyPreviewMovementLock(): ()
	if not previewControlsLocked then
		Controls:Disable()
		previewControlsLocked = true
	end
end

local function startPreviewMovementLock(): ()
	applyPreviewMovementLock()
end

local function restorePreviewMovement(): ()
	stopPreviewMovementLock()
end

local function restoreLobbyHud(): ()
	local hudGui = playerGui:FindFirstChild("HudGui")
	if not hudGui or not hudGui:IsA("ScreenGui") then
		return
	end

	local function shouldEnableHud(): boolean
		if GuiController._currentGuiName ~= nil then
			return false
		end

		local character = player.Character
		local positionSelectionActive = player:GetAttribute(POSITION_SELECTION_ACTIVE_ATTRIBUTE) == true
			or (character ~= nil and character:GetAttribute(POSITION_SELECTION_ACTIVE_ATTRIBUTE) == true)
		if positionSelectionActive then
			return false
		end

		local playerInLobby = player:GetAttribute(IN_LOBBY_ATTRIBUTE)
		local characterInLobby = if character ~= nil then character:GetAttribute(IN_LOBBY_ATTRIBUTE) else nil
		return playerInLobby ~= false or characterInLobby ~= false
	end

	if shouldEnableHud() then
		hudGui.Enabled = true
		task.defer(function()
			if hudGui.Parent and shouldEnableHud() then
				hudGui.Enabled = true
			end
		end)
	end
end

local function restoreGameplayCamera(forceRelease: boolean?): ()
	local activeCamera = resolveCamera()
	if not activeCamera then
		return
	end

	activeCamera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		activeCamera.CameraSubject = humanoid
	end
	if forceRelease == true then
		local restoreCFrame = getGameplayRestoreCFrame()
		if restoreCFrame then
			activeCamera.CFrame = restoreCFrame
		end
	end
end

local function startCameraRestoreWatchdog(): ()
	stopCameraRestoreWatchdog()
	local deadline = os.clock() + CAMERA_RESTORE_TIMEOUT
	cameraRestoreConnection = RunService.Heartbeat:Connect(function()
		local activeCamera = resolveCamera()
		if not activeCamera then
			return
		end

		restoreGameplayCamera(true)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if (activeCamera.CameraType == Enum.CameraType.Custom and humanoid ~= nil and activeCamera.CameraSubject == humanoid)
			or os.clock() >= deadline
		then
			stopCameraRestoreWatchdog()
		end
	end)
end

local function startCameraFollow(): ()
	stopCameraTween()
	stopCameraRestoreWatchdog()
	stopCameraFollow()
	local activeCamera = resolveCamera()
	if not activeCamera then
		return
	end

	activeCamera.CameraType = Enum.CameraType.Scriptable
	previewCameraCFrame = activeCamera.CFrame
	cameraFollowConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local currentCamera = resolveCamera()
		if not currentCamera then
			return
		end
		if currentCamera.CameraType ~= Enum.CameraType.Scriptable then
			currentCamera.CameraType = Enum.CameraType.Scriptable
		end
		local alpha = 1 - math.exp(-CAMERA_FOLLOW_LERP_SPEED * math.clamp(deltaTime, 0, 0.1))
		local baseCFrame = previewCameraCFrame or currentCamera.CFrame
		previewCameraCFrame = baseCFrame:Lerp(getCameraTargetCFrame(), alpha)
		currentCamera.CFrame = previewCameraCFrame
	end)
end

local function getStylesGroupedByRarity()
	local grouped = {}
	local totalWeight = 0

	for _, rarity in ipairs(RARITY_ORDER) do
		grouped[rarity] = {
			Styles = {},
			Color = Color3.new(1, 1, 1),
			Percentage = 0,
			TotalWeight = 0,
			FeaturedName = nil,
			FeaturedWeight = -math.huge,
		}
	end

	for _, data in pairs(StylesData) do
		if data.Rarity and data.Rarity.Name then
			local rName = data.Rarity.Name
			local styleWeight = math.max((tonumber(data.Weight) or tonumber(data.Rarity.Weight) or 0), 0)
			totalWeight += styleWeight

			if not grouped[rName] then
				grouped[rName] = {
					Color = data.Rarity.Color,
					Styles = {},
					Percentage = 0,
					TotalWeight = 0,
					FeaturedName = nil,
					FeaturedWeight = -math.huge,
				}
			end

			if grouped[rName].Color == Color3.new(1, 1, 1) and data.Rarity.Color then
				grouped[rName].Color = data.Rarity.Color
			end

			table.insert(grouped[rName].Styles, data.Name)
			grouped[rName].TotalWeight += styleWeight

			local featuredName = tostring(data.Name or "")
			if featuredName ~= ""
				and (
					styleWeight > grouped[rName].FeaturedWeight
					or (styleWeight == grouped[rName].FeaturedWeight and (grouped[rName].FeaturedName == nil or featuredName < grouped[rName].FeaturedName))
				)
			then
				grouped[rName].FeaturedWeight = styleWeight
				grouped[rName].FeaturedName = featuredName
			end
		end
	end

	for _, group in pairs(grouped) do
		table.sort(group.Styles)
		if totalWeight > 0 and group.TotalWeight > 0 then
			group.Percentage = (group.TotalWeight / totalWeight) * 100
		end
	end

	return grouped
end

------------------//UI CONTROL FUNCTIONS

local function setupTopRightRarityFrame(normalContainer: Instance, groupedStyles, trove): boolean
	return GachaGuiUtil.SetupTopRightRarityFrame(
		normalContainer,
		groupedStyles,
		STYLE_RARITY_DISPLAY_ORDER,
		"Styles",
		"StylesGuiRarityStyleLabel",
		trove,
		TweenService,
		RARITY_HOVER_INFO,
		RARITY_RESET_INFO,
		RARITY_HOVER_ROTATION
	)
end

local function setupRarityList(gui: ScreenGui, trove)
	local main = findMain(gui)
	if not main then
		return
	end

	local groupedStyles = getStylesGroupedByRarity()
	local normalContainer = findTopRightNormalContainer(main)
	if normalContainer and setupTopRightRarityFrame(normalContainer, groupedStyles, trove) then
		return
	end

	local topRight = findTopRightContainer(main)
	if not topRight then
		return
	end

	local template = topRight:FindFirstChild("SpinRarityTemplate")
	if not normalContainer or not template then
		return
	end

	for _, child in pairs(normalContainer:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local layoutOrder = 0

	for _, rarityName in ipairs(RARITY_ORDER) do
		local groupData = groupedStyles[rarityName]

		if groupData and #groupData.Styles > 0 then
			layoutOrder += 1

			local rarityBtn = template:Clone()
			rarityBtn.Name = rarityName
			rarityBtn.LayoutOrder = layoutOrder
			rarityBtn.Visible = true
			rarityBtn.Rotation = 0
			GachaGuiUtil.ConnectRarityHoverAnimation(
				rarityBtn,
				TweenService,
				trove,
				RARITY_HOVER_INFO,
				RARITY_RESET_INFO,
				RARITY_HOVER_ROTATION
			)
			GachaGuiUtil.ConfigureRarityButtonDisplay(rarityBtn, rarityName, groupData, "Styles")

			if rarityBtn:FindFirstChild("Glow") then
				rarityBtn.Glow.ImageColor3 = groupData.Color
			end

			rarityBtn.Parent = normalContainer
		end
	end
end

local function setButtonAnimation(button: GuiButton)
	if not animations[button] then
		animations[button] = true
		UiAnimations.new(button)
	end
end

local function findExitButton(gui: ScreenGui): GuiButton?
	local main = findMain(gui)
	if not main then
		return nil
	end

	return findBottomLeftExitButton(main)
end

local function setupExitButton(gui: ScreenGui, trove)
	local exitButton = findExitButton(gui)
	if not exitButton then
		return
	end

	setButtonAnimation(exitButton)

	local guiControllerExitConnections = GuiController._exitConnections
	if guiControllerExitConnections and guiControllerExitConnections[exitButton] then
		return
	end

	trove:Add(exitButton.Activated:Connect(function()
		GuiController:Close("StylesGui")
	end), "Disconnect")
end

local function setupLeftSlots(gui: ScreenGui, trove)
	local scrollingFrame = findSlotScrollingFrame(gui)
	if not scrollingFrame then
		warn("StylesGui: Slot ScrollingFrame not found.")
		return
	end
	ensureStyleSlotButtons(scrollingFrame)

	local function updateSlotsVisual(forceUpdate)
		if StylesGuiState._isSpinning and not forceUpdate then
			return
		end

		local slotsData = PlayerDataManager:Get(player, { "StyleSlots" }) or {}
		local selectedSlot = getSelectedStyleSlot()
		local unlockedSlots = PlayerDataManager:Get(player, { "UnlockedStyleSlots" }) or { 1 }
		local buttons = ensureStyleSlotButtons(scrollingFrame)

		for _, btn in ipairs(buttons) do
			local slotIndex = btn:GetAttribute("SlotIndex")
			if typeof(slotIndex) ~= "number" or slotIndex > MAX_STYLE_SLOTS then
				continue
			end

			local keyName = getStyleSlotKey(slotIndex)
			local styleIdInSlot = slotsData[keyName]
			local isUnlocked = isStyleSlotUnlocked(unlockedSlots, slotIndex)

			local slotVisualRefs = resolveStyleSlotVisualRefs(btn)
			local itemNameLabel = slotVisualRefs.ItemNameLabel
			local rarityLabel = slotVisualRefs.RarityLabel
			local glowImage = slotVisualRefs.GlowImage
			local mainGradient = slotVisualRefs.MainGradient
			local glowGradient = slotVisualRefs.GlowGradient
			local lockIcon = slotVisualRefs.LockIcon
			local extension = slotVisualRefs.Extension
			local extensionDescription = slotVisualRefs.ExtensionDescription
			local showExtension = slotIndex ~= 1 and not isUnlocked

			setButtonAnimation(btn)
			btn.ImageTransparency = if isUnlocked then 0 else 0.5
			setVisibleOnInstance(lockIcon, not isUnlocked)
			setVisibleOnInstance(extension, showExtension)

			local slotPriceText = if showExtension and SlotsController.GetSlotPriceText
				then SlotsController.GetSlotPriceText("Style")
				else nil
			if showExtension and extensionDescription then
				extensionDescription.Text = slotPriceText or "0 R$"
			end

			if not isUnlocked then
				if itemNameLabel then
					itemNameLabel.Text = "Locked"
					itemNameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
				end
				if rarityLabel then
					rarityLabel.Text = "Unlock"
					rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
				if glowImage and glowImage:IsA("GuiObject") then
					glowImage.Visible = false
				end

				local whiteSeq = toColorSequence(Color3.new(1, 1, 1))
				if mainGradient then
					mainGradient.Color = whiteSeq
				end
				if glowGradient then
					glowGradient.Color = whiteSeq
				end
			elseif styleIdInSlot and styleIdInSlot ~= "" then
				local styleData = StylesData[styleIdInSlot]
				if styleData then
					if itemNameLabel then
						itemNameLabel.Text = styleData.Name
						itemNameLabel.TextColor3 = Color3.new(1, 1, 1)
					end

					if rarityLabel and styleData.Rarity then
						rarityLabel.Text = styleData.Rarity.Name
						rarityLabel.TextColor3 = styleData.Rarity.Color
					end

					if glowImage and styleData.Rarity then
						glowImage.ImageColor3 = styleData.Rarity.Color
						glowImage.Visible = true
					end

					if styleData.Rarity and styleData.Rarity.Color then
						local colorSeq = toColorSequence(styleData.Rarity.Color)
						if mainGradient then
							mainGradient.Color = colorSeq
						end
						if glowGradient then
							glowGradient.Color = colorSeq
						end
					end
				else
					if itemNameLabel then
						itemNameLabel.Text = "Unknown"
					end
					if rarityLabel then
						rarityLabel.Text = ""
					end
				end
			else
				if itemNameLabel then
					itemNameLabel.Text = "Empty"
					itemNameLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
				end

				if rarityLabel then
					rarityLabel.Text = ""
				end
				if glowImage then
					glowImage.Visible = false
				end

				local whiteSeq = toColorSequence(Color3.new(1, 1, 1))
				if mainGradient then
					mainGradient.Color = whiteSeq
				end
				if glowGradient then
					glowGradient.Color = whiteSeq
				end
			end

			btn:SetAttribute("Selected", slotIndex == selectedSlot)
		end
	end

	currentUpdateSlotsFunction = updateSlotsVisual
	updateSlotsVisual(true)

	local selectedSignal = PlayerDataManager:GetValueChangedSignal(player, { "SelectedSlot" })
	local selectedConn = selectedSignal:Connect(function()
		updateSlotsVisual(false)
		if currentUpdateTopFunction then
			currentUpdateTopFunction()
		end
	end)
	trove:Add(selectedConn, "Disconnect")

	local unlockedSignal = PlayerDataManager:GetValueChangedSignal(player, { "UnlockedStyleSlots" })
	trove:Add(unlockedSignal:Connect(function()
		updateSlotsVisual(true)
		if currentUpdateTopFunction then
			currentUpdateTopFunction()
		end
	end), "Disconnect")

	if SlotsController.PriceTextChanged then
		trove:Add(SlotsController.PriceTextChanged:Connect(function(slotType: string)
			if slotType ~= "Style" then
				return
			end
			updateSlotsVisual(true)
		end), "Disconnect")
	end

	for i = 1, MAX_STYLE_SLOTS do
		local slotKey = getStyleSlotKey(i)
		local slotSignal = PlayerDataManager:GetValueChangedSignal(player, { "StyleSlots", slotKey })
		trove:Add(
			slotSignal:Connect(function()
				updateSlotsVisual(false)
				if currentUpdateTopFunction then
					currentUpdateTopFunction()
				end
			end),
			"Disconnect"
		)
	end

	for _, btn in ipairs(ensureStyleSlotButtons(scrollingFrame)) do
		local btnConn = btn.Activated:Connect(function()
			local buttonAttribute = btn:GetAttribute("SlotIndex")
			if typeof(buttonAttribute) ~= "number" or buttonAttribute > MAX_STYLE_SLOTS then
				return
			end
			
			local currentUnlocked = PlayerDataManager:Get(player, { "UnlockedStyleSlots" }) or { 1 }
			if not isStyleSlotUnlocked(currentUnlocked, buttonAttribute) then
				SlotsController.PromptPurchaseSlot("Style", buttonAttribute)
				return
			end
			
			if Packets.RequestEquip then
				Packets.RequestEquip:Fire(`Style:{tostring(buttonAttribute)}`)
			end
		end)
		trove:Add(btnConn, "Disconnect")
	end
end

------------------//ANIMATION FUNCTIONS

local function startRollingAnimation(gui: ScreenGui)
	task.spawn(function()
		local main = findMain(gui)
		if not main then
			return
		end

		local nameLabel = findTopNameLabel(main)
		local descLabel = findStyleDescriptionLabel(main)
		if not nameLabel or not descLabel then
			return
		end

		local styleKeys = {}
		for key, _ in pairs(StylesData) do
			table.insert(styleKeys, key)
		end

		while StylesGuiState._isSpinning do
			if not gui.Enabled then
				break
			end

			local randomKey = styleKeys[math.random(1, #styleKeys)]
			local randomData = StylesData[randomKey]

			if randomData then
				nameLabel.TextTransparency = 0.5
				descLabel.TextTransparency = 0.5

				nameLabel.Text = randomData.Name
				descLabel.Text = randomData.Description or "..."

				nameLabel.TextColor3 = getColorFromData(randomData)

				task.wait(0.05)
			end
		end
	end)
end

local function showFinalResult(gui: ScreenGui, _resultId, resultData)
	local main = findMain(gui)
	if not main then
		return
	end

	local nameLabel = findTopNameLabel(main)
	local descLabel = findStyleDescriptionLabel(main)
	if not nameLabel or not descLabel then
		return
	end

	local finalColor = getColorFromData(resultData)

	task.spawn(function()
		TweenService:Create(nameLabel, TEXT_FADE_INFO, { TextTransparency = 1 }):Play()
		TweenService:Create(descLabel, TEXT_FADE_INFO, { TextTransparency = 1 }):Play()
		task.wait(0.15)

		nameLabel.Text = resultData.Name
		descLabel.Text = resultData.Description or "No description."
		nameLabel.TextColor3 = finalColor

		TweenService:Create(nameLabel, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
		TweenService:Create(descLabel, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	end)
end

local function bindFreeze(
	_actionName: string,
	_inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult?
	return Enum.ContextActionResult.Sink
end

local function setupBuySpin(screenGui: ScreenGui, trove)
	local main = screenGui:FindFirstChild("Main") or screenGui:FindFirstChildWhichIsA("Frame")
	if not main then
		return
	end

	local frame = main:FindFirstChild("Frame")
	if not frame then
		return
	end

	local content = frame:FindFirstChild("Content")
	if not content then
		return
	end

	local container = content:FindFirstChild("Container")
	if not container then
		return
	end

	local scrollingFrame = container:FindFirstChildWhichIsA("ScrollingFrame")
	if not scrollingFrame then
		return
	end

	local spinsFrame = scrollingFrame:FindFirstChild("Spins")
	if not spinsFrame then
		return
	end

	for _, child in spinsFrame:GetChildren() do
		if not child:IsA("ImageButton") then
			continue
		end

		local robuxFrame = child:FindFirstChild("RobuxFrame")
		if not robuxFrame then
			continue
		end

		local buyButton = robuxFrame:FindFirstChild("BUYROBUX")
		setButtonAnimation(buyButton)

		print(child.Name)
		local targetProductId = PRODUCTS_ID[child.Name]
		if not targetProductId then
			return
		end

		local buyConnection = buyButton.MouseButton1Click:Connect(function()
			MarketPlaceService:PromptProductPurchase(player, targetProductId)
		end)
		trove:Add(buyConnection, "Disconnect")
	end
end


local function trackLuckySpin(button: GuiButton, trove)
	local spinDisplay = button:FindFirstChild("SpinQuantity", true) or findFirstTextLabel(button)
	if not spinDisplay or not spinDisplay:IsA("TextLabel") then return end

	local initialAmount = PlayerDataManager:Get(player, { "StyleLuckySpins" }) or 0
	spinDisplay.Text = `Lucky Spins: {tostring(initialAmount)}`

	local changedSignal = PlayerDataManager:GetValueChangedSignal(player, { "StyleLuckySpins" })
	trove:Add(changedSignal:Connect(function(newValue: number)
		if typeof(newValue) ~= "number" then return end
		spinDisplay.Text = `Lucky Spins: {tostring(newValue)}`
	end), "Disconnect")
end

local function setupLuckySpin(screenGui: ScreenGui, trove)
	local main = findMain(screenGui)
	if not main then return end

	local button = findBottomMiddleButton(main, { "LuckySpins", "LuckySpin", "Lucky Spins", "Lucky Spin" })
	if not button then return end

	local clickConnection = button.Activated:Connect(function()
		if StylesGuiState._isSpinning then return end

		local luckySpins = PlayerDataManager:Get(player, { "StyleLuckySpins" }) or 0
		if luckySpins <= 0 then
			NotificationController.Notify("No Lucky Spins", "You don't have any Lucky Spins left.")
			return
		end

		StylesGui.Spin(screenGui, true)
	end)

	setButtonAnimation(button)
	trackLuckySpin(button, trove)
	trove:Add(clickConnection, "Disconnect")
end

local function findLeftScrollButton(main: Instance?, frameName: string): GuiButton?
	return GachaGuiUtil.FindLeftScrollButton(main, frameName)
end

local function setupSlotScrollButtons(gui: ScreenGui, trove)
	local main = findMain(gui)
	local scrollingFrame = findSlotScrollingFrame(gui)
	if not main or not scrollingFrame then
		return
	end

	local upButton = findLeftScrollButton(main, "Up")
	local downButton = findLeftScrollButton(main, "Down")

	local function scrollSlots(direction: number): ()
		scrollScrollingFrame(
			scrollingFrame,
			TweenService,
			SLOT_SCROLL_STEP_SCALE,
			direction,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		)
	end

	if upButton then
		setButtonAnimation(upButton)
		trove:Add(upButton.Activated:Connect(function()
			scrollSlots(-1)
		end), "Disconnect")
	end

	if downButton then
		setButtonAnimation(downButton)
		trove:Add(downButton.Activated:Connect(function()
			scrollSlots(1)
		end), "Disconnect")
	end
end

------------------//MAIN LOGIC


function StylesGui.Spin(gui: ScreenGui, isLuckySpin: boolean?)
	if typeof(isLuckySpin) ~= "boolean" then
		isLuckySpin = false
	end

	local playerHasSkipActivated = PlayerDataManager:Get(player, { "Settings", "SkipSpinActivated" })
	if not playerHasSkipActivated then
		StylesGuiState._isSpinning = true
		startRollingAnimation(gui)
	end

	local result = Packets.RequestSpin:Fire("Style", isLuckySpin)
	if typeof(result) == "string" then
		StylesGuiState._isSpinning = false
		if currentUpdateSlotsFunction then
			currentUpdateSlotsFunction(true)
		end
		if currentUpdateTopFunction then
			currentUpdateTopFunction()
		end
		NotificationController.NotifyError("Spin error", result, 1)
	end
end

function StylesGui.OnOpen(gui: ScreenGui)
	if StylesGuiState._trove then
		StylesGuiState._trove:Destroy()
		StylesGuiState._trove = nil
	end

	local main = findMain(gui)
	if not main then
		warn("StylesGui: Main frame not found.")
		return
	end

	StylesGuiState._trove = Trove.new()
	local trove = StylesGuiState._trove

	startPreviewMovementLock()
	startCameraFollow()

	ContextActionService:BindAction(FREEZE_INPUT, bindFreeze, false, unpack(Enum.PlayerActions:GetEnumItems()))

	local spinButton = findBottomMiddleButton(main, { "Spin", "Spins" })
	local spinsLabel = spinButton and (spinButton:FindFirstChild("SpinQuantity", true) or findFirstTextLabel(spinButton)) or nil
	if spinButton then
		setButtonAnimation(spinButton)
	end
	if spinsLabel and not spinsLabel:IsA("TextLabel") then
		spinsLabel = nil
	end

	local moneyRoot = findDescendantByNames(main, { "Money", "Yen" }, nil)
	local moneyLabel = findFirstTextLabel(moneyRoot)

	local function updateYenDisplay(val)
		if not moneyLabel then
			return
		end
		moneyLabel.Text = "$" .. formatMoney(val)
	end

	if moneyLabel then
		local currentYen = PlayerDataManager:Get(player, { "Yen" }) or 0
		updateYenDisplay(currentYen)

		local yenSignal = PlayerDataManager:GetValueChangedSignal(player, { "Yen" })
		trove:Add(
			yenSignal:Connect(function(newVal)
				updateYenDisplay(newVal)
			end),
			"Disconnect"
		)
	end

	local nameLabel = findTopNameLabel(main)
	local descLabel = findStyleDescriptionLabel(main)

	local function updateTopInfo()
		if StylesGuiState._isSpinning then
			return
		end
		if not nameLabel or not descLabel then
			return
		end

		local selectedSlot = getSelectedStyleSlot()
		local currentSlots = PlayerDataManager:Get(player, { "StyleSlots" }) or {}
		local equippedId = currentSlots[getStyleSlotKey(selectedSlot)]

		if equippedId and equippedId ~= "" and StylesData[equippedId] then
			local data = StylesData[equippedId]
			nameLabel.Text = data.Name
			descLabel.Text = data.Description or "No Description"
			nameLabel.TextColor3 = getColorFromData(data)

			nameLabel.TextTransparency = 0
			descLabel.TextTransparency = 0
			playPreviewStyleIdleAnimation(equippedId)
		else
			nameLabel.Text = "No Style Equipped"
			descLabel.Text = "Select a slot or spin to get a style."
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			playPreviewStyleIdleAnimation(nil)
		end
	end

	currentUpdateTopFunction = updateTopInfo
	updateTopInfo()

	setupRarityList(gui, trove)
	setupLeftSlots(gui, trove)
	setupLuckySpin(gui, trove)
	setupSlotScrollButtons(gui, trove)
	setupExitButton(gui, trove)

	local currentSpins = PlayerDataManager:Get(player, { "SpinStyle" })
	if spinsLabel then
		updateSpinDisplay(spinsLabel, currentSpins or 0)
	end

	local spinSignal = PlayerDataManager:GetValueChangedSignal(player, { "SpinStyle" })
	local connection = spinSignal:Connect(function(newValue, _oldvalue)
		if spinsLabel then
			updateSpinDisplay(spinsLabel, newValue)
		end
	end)
	trove:Add(connection, "Disconnect")

	local buySpinsButton = findGuiButtonByNames(main, { "BuySpins", "Buy Spins" })
	if buySpinsButton then
		setButtonAnimation(buySpinsButton)

		local debounce = false
		local buyConnection = buySpinsButton.Activated:Connect(function()
			if debounce then
				return
			end

			debounce = true
			local screenGui = GuiController:Open("BuyStyleGui")
			if not screenGui then
				debounce = false
				return
			end

			setupBuySpin(screenGui, trove)

			task.delay(1, function()
				debounce = false
			end)
		end)
		trove:Add(buyConnection, "Disconnect")
	end

	local skipSpinsButton = findGuiButtonByNames(main, { "SkipSpins", "Skip Spins" })
	if skipSpinsButton then
		setButtonAnimation(skipSpinsButton)

		local skipLabel = findFirstTextLabel(skipSpinsButton)
		local isSkipActivated = PlayerDataManager:Get(player, { "Settings", "SkipSpinActivated" })
		if skipLabel then
			skipLabel.Text = isSkipActivated and "SKIP SPINS: ON" or "SKIP SPINS: OFF"
		end

		local skipConnection = skipSpinsButton.Activated:Connect(function()
			local result = Packets.RequestSkipSpin:Fire("ActiveSkip")
			if typeof(result) == "nil" then
				return
			end

			if skipLabel then
				skipLabel.Text = result and "SKIP SPINS: ON" or "SKIP SPINS: OFF"
			end
		end)
		trove:Add(skipConnection, "Disconnect")
	end

	if spinButton then
		local spinBtnConn = spinButton.Activated:Connect(function()
			if StylesGuiState._isSpinning then
				return
			end

			local spinsNow = PlayerDataManager:Get(player, { "SpinStyle" }) or 0
			if spinsNow <= 0 then
				return
			end

			local selectedSlot = getSelectedStyleSlot()
			local currentUnlocked = PlayerDataManager:Get(player, { "UnlockedStyleSlots" }) or { 1 }
			if not isStyleSlotUnlocked(currentUnlocked, selectedSlot) then
				SlotsController.PromptPurchaseSlot("Style", selectedSlot)
				return
			end

			StylesGui.Spin(gui, false)
		end)
		trove:Add(spinBtnConn, "Disconnect")
	end

	local packetConn = Packets.SpinResult.OnClientEvent:Connect(function(gachaType, resultId, _)
		if gachaType == "Style" then
			StylesGuiState._isSpinning = false

			if currentUpdateSlotsFunction then
				currentUpdateSlotsFunction(true)
			end
			if currentUpdateTopFunction then
				currentUpdateTopFunction()
			end

			if not resultId then
				return
			end

			local finalData = StylesData[resultId]

			if finalData then
				showFinalResult(gui, resultId, finalData)
			else
				warn("StylesGui: Returned ID not found ->", resultId)
			end
		end
	end)
	trove:Add(packetConn, "Disconnect")
end

function StylesGui.OnClose()
	StylesGuiState._isSpinning = false
	currentUpdateSlotsFunction = nil
	currentUpdateTopFunction = nil

	if StylesGuiState._trove then
		StylesGuiState._trove:Destroy()
		StylesGuiState._trove = nil
	end

	ContextActionService:UnbindAction(FREEZE_INPUT)
	stopPreviewStyleIdleAnimation()
	stopCameraTween()
	stopCameraFollow()
	restorePreviewMovement()
	restoreGameplayCamera(true)
	startCameraRestoreWatchdog()
	restoreLobbyHud()
end

------------------//INIT

function StylesGui.Start()
	GuiController.GuiOpened:Connect(function(guiName)
		if guiName == "StylesGui" then
			local gui = playerGui:FindFirstChild("StylesGui")
			if gui then
				StylesGui.OnOpen(gui)
			end
		end
	end)

	GuiController.GuiClosed:Connect(function(guiName)
		if guiName == "StylesGui" then
			StylesGui.OnClose()
		end
	end)
end

return StylesGui
