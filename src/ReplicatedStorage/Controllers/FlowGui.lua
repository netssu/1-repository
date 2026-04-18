local FlowGui = {}
------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local MarketPlaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

------------------//PACKAGES
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)

------------------//MODULES
local GuiController = require(ReplicatedStorage.Controllers.GuiController)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local InterfaceAnimations = require(ReplicatedStorage.Components.UIAnimation)
local NotificationController = require(ReplicatedStorage.Controllers.NotificationController)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local SlotsController = require(ReplicatedStorage.Controllers.SlotsController)
local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
local GachaGuiUtil = require(ReplicatedStorage.Controllers.GachaGuiUtil)

local DataFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data")
local FlowsData = require(DataFolder:WaitForChild("FlowsData"))
local AssetsFolder = ReplicatedStorage:WaitForChild("Assets")
local EffectsFolder = AssetsFolder:WaitForChild("Effects")
local AurasFolder = EffectsFolder:FindFirstChild("Auras")

------------------//CONSTANTS
local TEXT_FADE_INFO = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RARITY_HOVER_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RARITY_RESET_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CAMERA_OFFSET = CFrame.new(0, 2, -9)
local PREVIEW_CAMERA_DISTANCE = 10.5
local PREVIEW_CAMERA_HEIGHT_RATIO = 0.08
local LOOK_AT_OFFSET = Vector3.new(0, 0.5, 0)
local CAMERA_FOLLOW_LERP_SPEED = 10
local CAMERA_RESTORE_TIMEOUT = 0.75
local CAMERA_RESTORE_DISTANCE = 10
local CAMERA_RESTORE_HEIGHT = 3
local CAMERA_RESTORE_LOOK_HEIGHT = 2
local RARITY_ORDER = { "Legendary", "Epic", "Rare", "Uncommon", "Common" }
local FLOW_RARITY_DISPLAY_ORDER = { "Rare", "Epic", "Legendary" }
local FREEZE_INPUT = "FREEZE_INPUT"
local POSITION_SELECTION_ACTIVE_ATTRIBUTE = "FTPositionSelectionActive"
local IN_LOBBY_ATTRIBUTE = "FTIsInLobby"
local MAX_FLOW_SLOTS = 6
local SLOT_PREFIX = "Slot"
local PREVIEW_AURA_ATTRIBUTE = "FlowGuiPreviewAura"
local FLOW_AURA_ID_ATTRIBUTE = "FTFlowAuraId"
local SLOT_SCROLL_STEP_SCALE = 0.75
local PREVIEW_IDLE_ANIMATION_NAME = "Idle"
local RARITY_HOVER_ROTATION = 7
local PREVIEW_AURA_WELD_NAME = "FTFlowPreviewAuraWeld"

local FLOW_BUFF_LABELS = {
	{ Key = "Speed", Label = "Speed", Kind = "flat" },
	{ Key = "Throw", Label = "Throw", Kind = "flat" },
	{ Key = "CooldownReduction", Label = "Cooldown", Kind = "percentReduction" },
	{ Key = "Dribble", Label = "Dribble", Kind = "flat" },
	{ Key = "StaminaCostReduction", Label = "Stamina", Kind = "percentReduction" },
	{ Key = "TackleStunReduction", Label = "Tackle stun", Kind = "percentReduction" },
}

local PRODUCTS_ID = {
	["10Spins"] = 3547220420,
	["30Spins"] = 3547220649,
	["50Spins"] = 3547220837,
}

------------------//VARIABLES
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player.PlayerGui
local PlayerModule = require(player.PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()
local currentUpdateSlotsFunction = nil
local currentUpdateTopFunction = nil

local FlowGuiState = {
	_trove = nil,
	_isSpinning = false,
}

local animations = {}
local activeCameraTween: Tween? = nil
local cameraFollowConnection: RBXScriptConnection? = nil
local cameraRestoreConnection: RBXScriptConnection? = nil
local previewCameraCFrame: CFrame? = nil
local previewControlsLocked: boolean = false
local previewAuraFlowId: string? = nil
local previewFlowId: string? = nil
local previewIdleModel: Model? = nil
local previewFlowAnimationModel: Model? = nil
local previewFlowAnimationId: string? = nil
local flowSlotVisualRefsCache = setmetatable({}, { __mode = "k" })

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
local normalizeUiName = GachaGuiUtil.NormalizeUiName
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

local function findFlowDescriptionLabel(root: Instance?): TextLabel?
	return GachaGuiUtil.FindDescriptionLabel(root, { "DescriptionFrame" }, { "Description" })
end

local function findBottomMiddleButton(main: Instance?, buttonNames: { string }): GuiButton?
	return GachaGuiUtil.FindBottomMiddleButton(main, buttonNames)
end

local function findBottomLeftExitButton(main: Instance?): GuiButton?
	return GachaGuiUtil.FindBottomLeftExitButton(main)
end

local function findSlotFlowNameLabel(slotButton: ImageButton): TextLabel?
	return GachaGuiUtil.FindSlotItemNameLabel(slotButton)
end

local function resolveFlowSlotVisualRefs(slotButton: ImageButton): any
	local cached = flowSlotVisualRefsCache[slotButton]
	if cached and cached.ItemNameLabel and cached.ItemNameLabel.Parent then
		return cached
	end

	local glowImage = slotButton:FindFirstChild("Glow")
	local refs = {
		ItemNameLabel = findSlotFlowNameLabel(slotButton),
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

	flowSlotVisualRefsCache[slotButton] = refs
	return refs
end

local function ensureFlowSlotButtons(scrollingFrame: ScrollingFrame): { ImageButton }
	return GachaGuiUtil.EnsureSlotButtons(scrollingFrame, MAX_FLOW_SLOTS, SLOT_PREFIX, "FlowGuiSlotClickHandled")
end

local function isFlowSlotUnlocked(unlockedSlots: { any }, slotIndex: number): boolean
	return GachaGuiUtil.IsSlotUnlocked(unlockedSlots, slotIndex, 1)
end

local function getSelectedFlowSlot(): number
	return GachaGuiUtil.GetSelectedSlot(
		PlayerDataManager,
		player,
		{ { "SelectedFlowSlot" }, { "SelectedSlot" } },
		MAX_FLOW_SLOTS,
		1
	)
end

local function getFlowSlotKey(slotIndex: number): string
	return GachaGuiUtil.GetSlotKey(slotIndex, SLOT_PREFIX)
end

local function formatSignedNumber(value: number): string
	if value > 0 then
		return `+{tostring(value)}`
	end
	return tostring(value)
end

local function formatBuffValue(value: number, kind: string): string
	if kind == "percentReduction" then
		local percent = math.round(math.abs(value) * 100)
		return if value >= 0 then `-{tostring(percent)}%` else `+{tostring(percent)}%`
	end
	return formatSignedNumber(value)
end

local function getFlowBuffDescription(flowId: string?, data: any): string
	local definition = FlowBuffs.GetDefinition(flowId)
	if not definition or not definition.Buffs then
		return (data and data.Description) or "No Description"
	end

	local parts = {}
	for _, descriptor in ipairs(FLOW_BUFF_LABELS) do
		local value = definition.Buffs[descriptor.Key]
		if typeof(value) == "number" and value ~= 0 then
			table.insert(parts, `{descriptor.Label} {formatBuffValue(value, descriptor.Kind)}`)
		end
	end

	if #parts == 0 then
		return "No flow buffs."
	end
	return table.concat(parts, " | ")
end

local function setAuraEffectsEnabled(target: Instance, enabled: boolean, emitOnEnable: boolean?): ()
	local function apply(item: Instance): ()
		if item:IsA("ParticleEmitter") then
			item.Enabled = enabled
			if enabled and emitOnEnable then
				local emitCount = item:GetAttribute("EmitCount")
				if typeof(emitCount) == "number" and emitCount > 0 then
					item:Emit(math.max(1, math.round(emitCount)))
				end
			end
		elseif item:IsA("Beam")
			or item:IsA("Trail")
			or item:IsA("Light")
			or item:IsA("Fire")
			or item:IsA("Smoke")
			or item:IsA("Sparkles")
		then
			pcall(function()
				(item :: any).Enabled = enabled
			end)
		end
	end

	apply(target)
	for _, descendant in ipairs(target:GetDescendants()) do
		apply(descendant)
	end
end

local function resolveAurasFolder(): Instance?
	if AurasFolder and AurasFolder.Parent ~= nil then
		return AurasFolder
	end

	AurasFolder = EffectsFolder:FindFirstChild("Auras")
	return AurasFolder
end

local function getFlowPreviewFolder(): Instance?
	local lobby = workspace:FindFirstChild("lobby") or workspace:FindFirstChild("Lobby")
	if not lobby then
		return nil
	end
	return lobby:FindFirstChild("flow") or lobby:FindFirstChild("Flow")
end

local function getFlowPreviewModel(): Model?
	local previewFolder = getFlowPreviewFolder()
	if not previewFolder then
		return nil
	end
	local namedModel = previewFolder:FindFirstChild("Model")
	if namedModel and namedModel:IsA("Model") then
		return namedModel
	end
	for _, child in ipairs(previewFolder:GetChildren()) do
		if child:IsA("Model") then
			return child
		end
	end
	return nil
end

local function getFlowPreviewPositionAnchor(): BasePart?
	local previewFolder = getFlowPreviewFolder()
	local previewModel = getFlowPreviewModel()
	if not previewFolder then
		return nil
	end
	for _, child in ipairs(previewFolder:GetChildren()) do
		if child:IsA("BasePart") and (not previewModel or not child:IsDescendantOf(previewModel)) then
			return child
		end
	end
	return nil
end

local function getFlowPreviewCameraAnchor(): BasePart?
	local positionAnchor = getFlowPreviewPositionAnchor()
	if not positionAnchor then
		return nil
	end

	local normalizedName = normalizeUiName(positionAnchor.Name)
	if string.find(normalizedName, "camera", 1, true) or string.find(normalizedName, "cam", 1, true) then
		return positionAnchor
	end
	return nil
end

local function stopPreviewIdleAnimation(): ()
	if previewIdleModel then
		AnimationController.StopAnimationForModel(previewIdleModel, PREVIEW_IDLE_ANIMATION_NAME, 0.15)
		previewIdleModel = nil
	end
end

local function playPreviewIdleAnimation(): ()
	local previewModel = getFlowPreviewModel()
	if not previewModel then
		stopPreviewIdleAnimation()
		return
	end

	if previewIdleModel and previewIdleModel ~= previewModel then
		stopPreviewIdleAnimation()
	end

	if AnimationController.IsAnimationPlayingForModel(previewModel, PREVIEW_IDLE_ANIMATION_NAME) then
		previewIdleModel = previewModel
		return
	end

	local track = AnimationController.PlayAnimationForModel(previewModel, PREVIEW_IDLE_ANIMATION_NAME, {
		Looped = true,
		Priority = Enum.AnimationPriority.Idle,
		FadeTime = 0.15,
	})
	if track then
		previewIdleModel = previewModel
	end
end

local function createPreviewAnimationSource(animationId: string): Animation
	local animation = Instance.new("Animation")
	animation.Name = "FlowGuiPreviewAnimation"
	animation.AnimationId = animationId
	return animation
end

local function stopPreviewFlowAnimation(): ()
	local animationId = previewFlowAnimationId
	local animationModel = previewFlowAnimationModel
	previewFlowAnimationId = nil
	previewFlowAnimationModel = nil

	if typeof(animationId) ~= "string" or animationId == "" or not animationModel then
		return
	end

	local animationSource = createPreviewAnimationSource(animationId)
	AnimationController.StopAnimationForModel(animationModel, animationSource, 0.05)
	animationSource:Destroy()
end

local function playPreviewFlowAnimation(flowId: string?): ()
	local previewModel = getFlowPreviewModel()
	if not previewModel or typeof(flowId) ~= "string" or flowId == "" then
		stopPreviewFlowAnimation()
		return
	end

	local flowData = FlowsData[flowId]
	local animationId = flowData and flowData.AnimationId
	if typeof(animationId) ~= "string" or animationId == "" then
		stopPreviewFlowAnimation()
		return
	end

	if previewFlowAnimationModel and previewFlowAnimationModel ~= previewModel then
		stopPreviewFlowAnimation()
	end

	local animationSource = createPreviewAnimationSource(animationId)
	AnimationController.StopAnimationForModel(previewModel, animationSource, 0.05)
	local track = AnimationController.PlayAnimationForModel(previewModel, animationSource, {
		Looped = false,
		Priority = Enum.AnimationPriority.Action,
		FadeTime = 0.05,
	})
	animationSource:Destroy()

	if track then
		previewFlowAnimationModel = previewModel
		previewFlowAnimationId = animationId
	end
end

local function clearFlowPreviewAura(): ()
	stopPreviewFlowAnimation()

	local previewModel = getFlowPreviewModel()
	if not previewModel then
		previewAuraFlowId = nil
		return
	end
	for _, child in ipairs(previewModel:GetChildren()) do
		if child:GetAttribute(PREVIEW_AURA_ATTRIBUTE) == true then
			setAuraEffectsEnabled(child, false)
			child:Destroy()
		end
	end
	previewFlowId = nil
	previewAuraFlowId = nil
end

local function findCurrentCharacterAura(flowId: string): Instance?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:GetAttribute("IsAura") == true and child:GetAttribute(FLOW_AURA_ID_ATTRIBUTE) == flowId then
			return child
		end
	end
	return nil
end

local function getAuraTemplateForFlow(flowId: string): Instance?
	local characterAura = findCurrentCharacterAura(flowId)
	if characterAura then
		return characterAura
	end

	local resolvedAurasFolder = resolveAurasFolder()
	if not resolvedAurasFolder then
		return nil
	end

	local flowData = FlowsData[flowId]
	local auraModelName =
		if flowData and typeof(flowData.AuraModelName) == "string" and flowData.AuraModelName ~= ""
			then flowData.AuraModelName
			else flowId
	return resolvedAurasFolder:FindFirstChild(auraModelName)
end

local function getPreviewFallbackPart(previewModel: Model): BasePart?
	local humanoidRootPart = previewModel:FindFirstChild("HumanoidRootPart", true)
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		return humanoidRootPart
	end
	if previewModel.PrimaryPart then
		return previewModel.PrimaryPart
	end
	return previewModel:FindFirstChildWhichIsA("BasePart", true) or getFlowPreviewPositionAnchor()
end

local function findPreviewTargetPart(previewModel: Model, partName: string): BasePart?
	for _, descendant in ipairs(previewModel:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == partName then
			return descendant
		end
	end
	return getPreviewFallbackPart(previewModel)
end

local function attachPreviewAuraPart(auraPart: BasePart, previewModel: Model): ()
	local targetPart = findPreviewTargetPart(previewModel, auraPart.Name)
	if not targetPart then
		return
	end

	auraPart.Anchored = false
	auraPart.CanCollide = false
	auraPart.CanQuery = false
	auraPart.CanTouch = false
	auraPart.Massless = true
	auraPart.Transparency = 1
	auraPart.CFrame = targetPart.CFrame

	local weld = Instance.new("WeldConstraint")
	weld.Name = PREVIEW_AURA_WELD_NAME
	weld.Part0 = auraPart
	weld.Part1 = targetPart
	weld.Parent = auraPart
end

local function findPreviewAuraInstance(flowId: string?): Instance?
	local previewModel = getFlowPreviewModel()
	if not previewModel then
		return nil
	end

	for _, child in ipairs(previewModel:GetChildren()) do
		if child:GetAttribute(PREVIEW_AURA_ATTRIBUTE) ~= true then
			continue
		end
		if typeof(flowId) == "string" and flowId ~= "" and child:GetAttribute(FLOW_AURA_ID_ATTRIBUTE) ~= flowId then
			continue
		end
		return child
	end

	return nil
end

local function configurePreviewAura(auraClone: Instance, previewModel: Model, flowId: string): ()
	auraClone:SetAttribute(PREVIEW_AURA_ATTRIBUTE, true)
	auraClone:SetAttribute("IsAura", true)
	auraClone:SetAttribute(FLOW_AURA_ID_ATTRIBUTE, flowId)
	setAuraEffectsEnabled(auraClone, false)

	for _, descendant in ipairs(auraClone:GetDescendants()) do
		if descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end

	auraClone.Parent = previewModel

	if auraClone:IsA("BasePart") then
		attachPreviewAuraPart(auraClone, previewModel)
	end

	for _, descendant in ipairs(auraClone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			attachPreviewAuraPart(descendant, previewModel)
		end
	end

	setAuraEffectsEnabled(auraClone, true, false)
end

local function setFlowPreviewAura(flowId: string?, forceRefresh: boolean?): ()
	local auraTemplate = if typeof(flowId) == "string" and flowId ~= "" then getAuraTemplateForFlow(flowId) else nil
	local desiredAuraFlowId = if auraTemplate then flowId else nil
	if previewFlowId == flowId and previewAuraFlowId == desiredAuraFlowId and forceRefresh ~= true then
		return
	end

	clearFlowPreviewAura()
	if typeof(flowId) ~= "string" or flowId == "" then
		return
	end

	local previewModel = getFlowPreviewModel()
	previewFlowId = flowId
	if not previewModel or not auraTemplate then
		return
	end

	local auraClone = auraTemplate:Clone()
	configurePreviewAura(auraClone, previewModel, flowId)
	previewAuraFlowId = flowId
end

local function updateFlowPreview(flowId: string?, playChangeAnimation: boolean?, forceRefresh: boolean?): ()
	local normalizedFlowId = if typeof(flowId) == "string" and flowId ~= "" then flowId else nil
	local previousFlowId = previewFlowId

	setFlowPreviewAura(normalizedFlowId, forceRefresh)

	if playChangeAnimation == true and normalizedFlowId and (forceRefresh == true or previousFlowId ~= normalizedFlowId) then
		local previewAura = findPreviewAuraInstance(normalizedFlowId)
		if previewAura then
			setAuraEffectsEnabled(previewAura, true, true)
		end
		playPreviewFlowAnimation(normalizedFlowId)
	end
end

local function updatePreviewAuraForSelectedSlot(playChangeAnimation: boolean?): ()
	local selectedSlot = getSelectedFlowSlot()
	local currentSlots = PlayerDataManager:Get(player, { "FlowSlots" }) or {}
	local equippedId = currentSlots[getFlowSlotKey(selectedSlot)]
	updateFlowPreview(if typeof(equippedId) == "string" then equippedId else nil, playChangeAnimation, false)
end

local function getPreviewModelFocus(previewModel: Model): (Vector3, Vector3)
	local boundingCFrame, boundingSize = previewModel:GetBoundingBox()
	return boundingCFrame.Position, boundingSize
end

local function getCameraTargetCFrame()
	local activeCamera = resolveCamera()
	local previewModel = getFlowPreviewModel()
	if previewModel then
		local previewPivot = previewModel:GetPivot()
		local focusPosition, boundingSize = getPreviewModelFocus(previewModel)
		local lookAtPosition = focusPosition
		local cameraAnchor = getFlowPreviewCameraAnchor()
		if cameraAnchor then
			local anchorLocalPosition = previewPivot:ToObjectSpace(cameraAnchor.CFrame).Position
			local cameraLocalPosition = Vector3.new(anchorLocalPosition.X, anchorLocalPosition.Y, -math.abs(anchorLocalPosition.Z))
			local cameraPosition = previewPivot:PointToWorldSpace(cameraLocalPosition)
			return CFrame.lookAt(cameraPosition, lookAtPosition, Vector3.yAxis)
		end

		local previewLook = Vector3.new(previewPivot.LookVector.X, 0, previewPivot.LookVector.Z)
		if previewLook.Magnitude < 1e-4 then
			previewLook = Vector3.new(0, 0, -1)
		else
			previewLook = previewLook.Unit
		end
		local cameraHeight = boundingSize.Y * PREVIEW_CAMERA_HEIGHT_RATIO
		local cameraPosition = focusPosition + (previewLook * PREVIEW_CAMERA_DISTANCE) + Vector3.new(0, cameraHeight, 0)
		return CFrame.lookAt(cameraPosition, lookAtPosition, Vector3.yAxis)
	end

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

local function getFlowsGroupedByRarity()
	local grouped = {}

	for _, rarity in ipairs(RARITY_ORDER) do
		grouped[rarity] = {
			Flows = {},
			Color = Color3.new(1, 1, 1),
			Percentage = 0,
			FeaturedName = nil,
			FeaturedWeight = -math.huge,
		}
	end

	for _, data in pairs(FlowsData) do
		if data.Rarity and data.Rarity.Name then
			local rName = data.Rarity.Name

			if not grouped[rName] then
				grouped[rName] = {
					Color = data.Rarity.Color,
					Flows = {},
					Percentage = 0,
					FeaturedName = nil,
					FeaturedWeight = -math.huge,
				}
			end

			if grouped[rName].Color == Color3.new(1, 1, 1) and data.Rarity.Color then
				grouped[rName].Color = data.Rarity.Color
			end

			table.insert(grouped[rName].Flows, data.Name)
			grouped[rName].Percentage += (tonumber(data.Percentage) or 0)

			local flowWeight = tonumber(data.Percentage) or tonumber(data.Weight) or 0
			local featuredName = tostring(data.Name or "")
			if featuredName ~= ""
				and (
					flowWeight > grouped[rName].FeaturedWeight
					or (flowWeight == grouped[rName].FeaturedWeight and (grouped[rName].FeaturedName == nil or featuredName < grouped[rName].FeaturedName))
				)
			then
				grouped[rName].FeaturedWeight = flowWeight
				grouped[rName].FeaturedName = featuredName
			end
		end
	end

	for _, group in pairs(grouped) do
		table.sort(group.Flows)
	end

	return grouped
end

local function bindFreeze(
	_actionName: string,
	_inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult?
	return Enum.ContextActionResult.Sink
end

------------------//UI CONTROL FUNCTIONS

local function setupTopRightRarityFrame(normalContainer: Instance, groupedFlows, trove): boolean
	return GachaGuiUtil.SetupTopRightRarityFrame(
		normalContainer,
		groupedFlows,
		FLOW_RARITY_DISPLAY_ORDER,
		"Flows",
		"FlowGuiRarityFlowLabel",
		trove,
		TweenService,
		RARITY_HOVER_INFO,
		RARITY_RESET_INFO,
		RARITY_HOVER_ROTATION
	)
end

local function setupRarityList(gui: ScreenGui, trove)
	local main = findMain(gui)
	if not main then return end

	local groupedFlows = getFlowsGroupedByRarity()
	local normalContainer = findTopRightNormalContainer(main)
	if normalContainer and setupTopRightRarityFrame(normalContainer, groupedFlows, trove) then
		return
	end

	local topRight = findTopRightContainer(main)
	if not topRight then return end

	local template = topRight:FindFirstChild("SpinRarityTemplate")
	if not normalContainer or not template then return end

	for _, child in pairs(normalContainer:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local layoutOrder = 0

	for _, rarityName in ipairs(RARITY_ORDER) do
		local groupData = groupedFlows[rarityName]

		if groupData and #groupData.Flows > 0 then
			layoutOrder += 1
			local currentLayoutOrder = layoutOrder

			local rarityBtn = template:Clone()
			rarityBtn.Name = rarityName
			rarityBtn.LayoutOrder = currentLayoutOrder
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
			GachaGuiUtil.ConfigureRarityButtonDisplay(rarityBtn, rarityName, groupData, "Flows")

			if rarityBtn:FindFirstChild("Glow") then
				rarityBtn.Glow.ImageColor3 = groupData.Color
			end

			rarityBtn.Parent = normalContainer

			local isExpanded = false
			local activeListFrame = nil

			local btnConn = rarityBtn.Activated:Connect(function()
				if isExpanded then
					if activeListFrame then
						activeListFrame:Destroy()
						activeListFrame = nil
					end
					isExpanded = false
				else
					isExpanded = true

					local listFrame = Instance.new("Frame")
					listFrame.Name = rarityName .. "_List"
					listFrame.BackgroundTransparency = 1
					listFrame.Size = UDim2.fromScale(1, 0)
					listFrame.LayoutOrder = currentLayoutOrder

					local listLayout = Instance.new("UIListLayout")
					listLayout.SortOrder = Enum.SortOrder.LayoutOrder
					listLayout.Padding = UDim.new(0, 2)
					listLayout.Parent = listFrame

					local totalHeight = 0
					for i, flowName in ipairs(groupData.Flows) do
						local flowLabel = Instance.new("TextLabel")
						flowLabel.Name = flowName
						flowLabel.Text = flowName
						flowLabel.Size = UDim2.new(1, 0, 0, 20)
						flowLabel.BackgroundTransparency = 1
						flowLabel.TextColor3 = if groupData.Color
							then groupData.Color:Lerp(Color3.fromRGB(0, 0, 0), 0.22)
							else Color3.fromRGB(255, 255, 255)
						flowLabel.Font = Enum.Font.GothamBold
						flowLabel.TextSize = 14
						flowLabel.TextXAlignment = Enum.TextXAlignment.Left
						flowLabel.LayoutOrder = i

						local stroke = Instance.new("UIStroke")
						stroke.Name = "Outline"
						stroke.Thickness = 1.5
						stroke.Color = Color3.fromRGB(0, 0, 0)
						stroke.Transparency = 0.5
						stroke.Parent = flowLabel

						flowLabel.Parent = listFrame
						totalHeight = totalHeight + 22
					end

					listFrame.Size = UDim2.new(1, 0, 0, totalHeight)
					listFrame.Parent = normalContainer
					activeListFrame = listFrame
				end
			end)
			trove:Add(btnConn, "Disconnect")
		end
	end
end

local function setButtonAnimation(button: GuiButton)
	if not animations[button] then
		animations[button] = true
		InterfaceAnimations.new(button)
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
		GuiController:Close("FlowGui")
	end), "Disconnect")
end

local function setupLeftSlots(gui: ScreenGui, trove)
	local scrollingFrame = findSlotScrollingFrame(gui)
	if not scrollingFrame then
		warn("FlowGui: Slot ScrollingFrame not found.")
		return
	end
	ensureFlowSlotButtons(scrollingFrame)

	local function updateSlotsVisual(forceUpdate)
		if FlowGuiState._isSpinning and not forceUpdate then
			return
		end

		local slotsData = PlayerDataManager:Get(player, { "FlowSlots" }) or {}
		local selectedSlot = getSelectedFlowSlot()
		local unlockedSlots = PlayerDataManager:Get(player, { "UnlockedFlowSlots" }) or { 1 }
		local buttons = ensureFlowSlotButtons(scrollingFrame)

		for _, btn in ipairs(buttons) do
			local slotIndex = btn:GetAttribute("SlotIndex")
			if typeof(slotIndex) ~= "number" or slotIndex > MAX_FLOW_SLOTS then continue end

			local keyName = getFlowSlotKey(slotIndex)
			local flowIdInSlot = slotsData[keyName]
			local isUnlocked = isFlowSlotUnlocked(unlockedSlots, slotIndex)

			local slotVisualRefs = resolveFlowSlotVisualRefs(btn)
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
				then SlotsController.GetSlotPriceText("Flow")
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
			elseif flowIdInSlot and flowIdInSlot ~= "" then

				local flowData = FlowsData[flowIdInSlot]
				if flowData then
					if itemNameLabel then
						itemNameLabel.Text = flowData.Name
						itemNameLabel.TextColor3 = Color3.new(1, 1, 1)
					end
					if rarityLabel and flowData.Rarity then
						rarityLabel.Text = flowData.Rarity.Name
						rarityLabel.TextColor3 = flowData.Rarity.Color
					end
					if glowImage and flowData.Rarity then
						glowImage.ImageColor3 = flowData.Rarity.Color
						glowImage.Visible = true
					end
					if flowData.Rarity and flowData.Rarity.Color then
						local colorSeq = toColorSequence(flowData.Rarity.Color)
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

	local selectedSignal = PlayerDataManager:GetValueChangedSignal(player, { "SelectedFlowSlot" })
	local selectedConn = selectedSignal:Connect(function()
		updateSlotsVisual(false)
		if currentUpdateTopFunction then
			currentUpdateTopFunction()
		end
		updatePreviewAuraForSelectedSlot(true)
	end)
	trove:Add(selectedConn, "Disconnect")

	local legacySelectedSignal = PlayerDataManager:GetValueChangedSignal(player, { "SelectedSlot" })
	trove:Add(legacySelectedSignal:Connect(function()
		if PlayerDataManager:Get(player, { "SelectedFlowSlot" }) ~= nil then
			return
		end
		updateSlotsVisual(false)
		if currentUpdateTopFunction then
			currentUpdateTopFunction()
		end
		updatePreviewAuraForSelectedSlot(true)
	end), "Disconnect")

	local unlockedSignal = PlayerDataManager:GetValueChangedSignal(player, { "UnlockedFlowSlots" })
	trove:Add(unlockedSignal:Connect(function()
		updateSlotsVisual(true)
		if currentUpdateTopFunction then
			currentUpdateTopFunction()
		end
		updatePreviewAuraForSelectedSlot(false)
	end), "Disconnect")

	for i = 1, MAX_FLOW_SLOTS do
		local slotKey = "Slot" .. i
		local slotSignal = PlayerDataManager:GetValueChangedSignal(player, { "FlowSlots", slotKey })
		trove:Add(
			slotSignal:Connect(function()
				updateSlotsVisual(false)
				if currentUpdateTopFunction then
					currentUpdateTopFunction()
				end
				if FlowGuiState._isSpinning then
					return
				end
				if getFlowSlotKey(getSelectedFlowSlot()) == slotKey then
					updatePreviewAuraForSelectedSlot(true)
				end
			end),
			"Disconnect"
		)
	end

	if SlotsController.PriceTextChanged then
		trove:Add(SlotsController.PriceTextChanged:Connect(function(slotType: string)
			if slotType ~= "Flow" then
				return
			end
			updateSlotsVisual(true)
		end), "Disconnect")
	end

	for _, btn in ipairs(ensureFlowSlotButtons(scrollingFrame)) do
		local btnConn = btn.Activated:Connect(function()
			local buttonAttribute = btn:GetAttribute("SlotIndex")
			if typeof(buttonAttribute) ~= "number" or buttonAttribute > MAX_FLOW_SLOTS then return end

			local currentUnlocked = PlayerDataManager:Get(player, { "UnlockedFlowSlots" }) or { 1 }
			if not isFlowSlotUnlocked(currentUnlocked, buttonAttribute) then
				SlotsController.PromptPurchaseSlot("Flow", buttonAttribute)
				return
			end

			if Packets.RequestEquip then
				Packets.RequestEquip:Fire(`Flow:{tostring(buttonAttribute)}`)
			end
		end)
		trove:Add(btnConn, "Disconnect")
	end
end

------------------//ANIMATION FUNCTIONS

local function startRollingAnimation(gui: ScreenGui)
	task.spawn(function()
		local main = findMain(gui)
		if not main then return end

		local nameLabel = findTopNameLabel(main)
		local descLabel = findFlowDescriptionLabel(main)
		if not nameLabel or not descLabel then return end

		local flowKeys = {}
		for key, _ in pairs(FlowsData) do
			table.insert(flowKeys, key)
		end

		while FlowGuiState._isSpinning do
			if not gui.Enabled then break end

			local randomKey = flowKeys[math.random(1, #flowKeys)]
			local randomData = FlowsData[randomKey]

			if randomData then
				nameLabel.TextTransparency = 0.5
				descLabel.TextTransparency = 0.5
				nameLabel.Text = randomData.Name
				descLabel.Text = getFlowBuffDescription(randomKey, randomData)
				nameLabel.TextColor3 = getColorFromData(randomData)
				task.wait(0.05)
			end
		end
	end)
end

local function showFinalResult(gui: ScreenGui, resultId: string, resultData)
	local main = findMain(gui)
	if not main then return end

	local nameLabel = findTopNameLabel(main)
	local descLabel = findFlowDescriptionLabel(main)
	if not nameLabel or not descLabel then return end

	local finalColor = getColorFromData(resultData)

	task.spawn(function()
		TweenService:Create(nameLabel, TEXT_FADE_INFO, { TextTransparency = 1 }):Play()
		TweenService:Create(descLabel, TEXT_FADE_INFO, { TextTransparency = 1 }):Play()
		task.wait(0.15)

		nameLabel.Text = resultData.Name
		descLabel.Text = getFlowBuffDescription(resultId, resultData)
		nameLabel.TextColor3 = finalColor

		TweenService:Create(nameLabel, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
		TweenService:Create(descLabel, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
	end)
end

local function setupBuySpin(screenGui: ScreenGui, trove)
	local main = screenGui:FindFirstChild("Main") or screenGui:FindFirstChildWhichIsA("Frame")
	if not main then return end

	local frame = main:FindFirstChild("Frame")
	if not frame then return end

	local content = frame:FindFirstChild("Content")
	if not content then return end

	local container = content:FindFirstChild("Container")
	if not container then return end

	local scrollingFrame = container:FindFirstChildWhichIsA("ScrollingFrame")
	if not scrollingFrame then return end

	local spinsFrame = scrollingFrame:FindFirstChild("Spins")
	if not spinsFrame then return end

	for _, child in spinsFrame:GetChildren() do
		if not child:IsA("ImageButton") then continue end

		local robuxFrame = child:FindFirstChild("RobuxFrame")
		if not robuxFrame then continue end

		local buyButton = robuxFrame:FindFirstChild("BUYROBUX")
		if not buyButton then continue end

		setButtonAnimation(buyButton)

		local targetProductId = PRODUCTS_ID[child.Name]
		if not targetProductId then continue end

		local buyConnection = buyButton.MouseButton1Click:Connect(function()
			MarketPlaceService:PromptProductPurchase(player, targetProductId)
		end)
		trove:Add(buyConnection, "Disconnect")
	end
end

local function trackLuckySpin(button: GuiButton, trove)
	local spinDisplay = button:FindFirstChild("SpinQuantity", true) or findFirstTextLabel(button)
	if not spinDisplay or not spinDisplay:IsA("TextLabel") then return end

	local initialAmount = PlayerDataManager:Get(player, { "FlowLuckySpins" }) or 0
	spinDisplay.Text = `Lucky Spins: {tostring(initialAmount)}`

	local changedSignal = PlayerDataManager:GetValueChangedSignal(player, { "FlowLuckySpins" })
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
		if FlowGuiState._isSpinning then return end

		local luckySpins = PlayerDataManager:Get(player, { "FlowLuckySpins" }) or 0
		if luckySpins <= 0 then
			NotificationController.Notify("No Lucky Spins", "You don't have any Lucky Spins left.")
			return
		end

		FlowGui.Spin(screenGui, true)
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

function FlowGui.Spin(gui: ScreenGui, isLuckySpin: boolean?)
	if typeof(isLuckySpin) ~= "boolean" then
		isLuckySpin = false
	end

	local playerHasSkipActivated = PlayerDataManager:Get(player, { "Settings", "SkipSpinActivated" })
	if not playerHasSkipActivated then
		FlowGuiState._isSpinning = true
		startRollingAnimation(gui)
	end

	local result = Packets.RequestSpin:Fire("Flow", isLuckySpin)
	if typeof(result) == "string" then
		FlowGuiState._isSpinning = false
		if currentUpdateSlotsFunction then
			currentUpdateSlotsFunction(true)
		end
		if currentUpdateTopFunction then
			currentUpdateTopFunction()
		end
		NotificationController.NotifyError("Spin error", result, 1)
	end
end

function FlowGui.OnOpen(gui: ScreenGui)
	if FlowGuiState._trove then
		FlowGuiState._trove:Destroy()
		FlowGuiState._trove = nil
	end

	local main = findMain(gui)
	if not main then
		warn("FlowGui: Main frame not found.")
		return
	end

	FlowGuiState._trove = Trove.new()
	local trove = FlowGuiState._trove

	startPreviewMovementLock()
	startCameraFollow()
	playPreviewIdleAnimation()

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
	if moneyLabel then
		local function updateYenDisplay(val)
			moneyLabel.Text = "$" .. formatMoney(val)
		end

		local currentYen = PlayerDataManager:Get(player, { "Yen" }) or 0
		updateYenDisplay(currentYen)

		local yenSignal = PlayerDataManager:GetValueChangedSignal(player, { "Yen" })
		trove:Add(yenSignal:Connect(function(newVal)
			updateYenDisplay(newVal)
		end), "Disconnect")
	end

	local nameLabel = findTopNameLabel(main)
	local descLabel = findFlowDescriptionLabel(main)

	local function updateTopInfo()
		if FlowGuiState._isSpinning then return end
		if not nameLabel or not descLabel then return end

		local selectedSlot = getSelectedFlowSlot()
		local currentSlots = PlayerDataManager:Get(player, { "FlowSlots" }) or {}
		local equippedId = currentSlots[getFlowSlotKey(selectedSlot)]

		if equippedId and equippedId ~= "" and FlowsData[equippedId] then
			local data = FlowsData[equippedId]
			nameLabel.Text = data.Name
			descLabel.Text = getFlowBuffDescription(equippedId, data)
			nameLabel.TextColor3 = getColorFromData(data)
			nameLabel.TextTransparency = 0
			descLabel.TextTransparency = 0
		else
			nameLabel.Text = "No Flow Equipped"
			descLabel.Text = "Select a slot or spin to get a flow."
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	end

	currentUpdateTopFunction = updateTopInfo
	updateTopInfo()
	updatePreviewAuraForSelectedSlot(false)

	setupRarityList(gui, trove)
	setupLeftSlots(gui, trove)
	setupLuckySpin(gui, trove)
	setupSlotScrollButtons(gui, trove)
	setupExitButton(gui, trove)

	local currentSpins = PlayerDataManager:Get(player, { "SpinFlow" })
	if spinsLabel then
		updateSpinDisplay(spinsLabel, currentSpins or 0)
	end

	local spinSignal = PlayerDataManager:GetValueChangedSignal(player, { "SpinFlow" })
	trove:Add(spinSignal:Connect(function(newValue, _)
		if spinsLabel then
			updateSpinDisplay(spinsLabel, newValue)
		end
	end), "Disconnect")

	local buySpinsButton = findGuiButtonByNames(main, { "BuySpins", "Buy Spins" })
	if buySpinsButton then
		setButtonAnimation(buySpinsButton)

		local debounce = false
		local buyConnection = buySpinsButton.Activated:Connect(function()
			if debounce then return end
			debounce = true

			local screenGui = GuiController:Open("BuyFlowGui")
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
		local skipLabel = findFirstTextLabel(skipSpinsButton)
		local isSkipActivated = PlayerDataManager:Get(player, { "Settings", "SkipSpinActivated" })

		if skipLabel then
			skipLabel.Text = isSkipActivated and "SKIP SPINS: ON" or "SKIP SPINS: OFF"
		end
		setButtonAnimation(skipSpinsButton)

		local skipConnection = skipSpinsButton.Activated:Connect(function()
			local result = Packets.RequestSkipSpin:Fire("ActiveSkip")
			if typeof(result) == "nil" then return end
			if skipLabel then
				skipLabel.Text = result and "SKIP SPINS: ON" or "SKIP SPINS: OFF"
			end
		end)
		trove:Add(skipConnection, "Disconnect")
	end

	if spinButton then
		local spinBtnConn = spinButton.Activated:Connect(function()
			if FlowGuiState._isSpinning then return end

			local spinsNow = PlayerDataManager:Get(player, { "SpinFlow" }) or 0
			if spinsNow <= 0 then return end

			local selectedSlot = getSelectedFlowSlot()
			local currentUnlocked = PlayerDataManager:Get(player, { "UnlockedFlowSlots" }) or { 1 }
			if not isFlowSlotUnlocked(currentUnlocked, selectedSlot) then
				SlotsController.PromptPurchaseSlot("Flow", selectedSlot)
				return
			end

			FlowGui.Spin(gui, false)
		end)
		trove:Add(spinBtnConn, "Disconnect")
	end

	local packetConn = Packets.SpinResult.OnClientEvent:Connect(function(gachaType, resultId, _)
		if gachaType == "Flow" then
			FlowGuiState._isSpinning = false

			if currentUpdateSlotsFunction then
				currentUpdateSlotsFunction(true)
			end
			if currentUpdateTopFunction then
				currentUpdateTopFunction()
			end

			if not resultId then return end

			local finalData = FlowsData[resultId]
			if finalData then
				showFinalResult(gui, resultId, finalData)
				updateFlowPreview(resultId, true, true)
			else
				warn("FlowGui: Returned ID not found ->", resultId)
			end
		end
	end)
	trove:Add(packetConn, "Disconnect")
end

function FlowGui.OnClose()
	FlowGuiState._isSpinning = false
	currentUpdateSlotsFunction = nil
	currentUpdateTopFunction = nil

	if FlowGuiState._trove then
		FlowGuiState._trove:Destroy()
		FlowGuiState._trove = nil
	end

	ContextActionService:UnbindAction(FREEZE_INPUT)
	stopCameraTween()
	stopCameraFollow()
	stopPreviewIdleAnimation()
	clearFlowPreviewAura()
	restorePreviewMovement()
	restoreGameplayCamera(true)
	startCameraRestoreWatchdog()
	restoreLobbyHud()
end

function FlowGui.Start()
	GuiController.GuiOpened:Connect(function(guiName)
		if guiName == "FlowGui" then
			local gui = playerGui:FindFirstChild("FlowGui")
			if gui then
				FlowGui.OnOpen(gui)
			end
		end
	end)

	GuiController.GuiClosed:Connect(function(guiName)
		if guiName == "FlowGui" then
			FlowGui.OnClose()
		end
	end)
end

return FlowGui
