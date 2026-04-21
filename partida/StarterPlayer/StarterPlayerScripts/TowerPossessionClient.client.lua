------------------//SERVICES
local ContextActionService: ContextActionService = game:GetService("ContextActionService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")
local Debris: Debris = game:GetService("Debris")
local UserInputService: UserInputService = game:GetService("UserInputService")

------------------//CONSTANTS
local POSSESS_KEY: Enum.KeyCode = Enum.KeyCode.E
local POSSESS_ACTION_NAME: string = "PossessExitAction"
local SHOOT_ACTION_NAME: string = "PossessShootAction"
local CANCEL_ACTION_NAME: string = "PossessCancelAction"
local ABILITY_ONE_ACTION_NAME: string = "PossessAbilityOneAction"
local ABILITY_TWO_ACTION_NAME: string = "PossessAbilityTwoAction"
local BLOCK_ACTION_NAME: string = "PossessBlockAction"
local INPUT_PRIORITY: number = Enum.ContextActionPriority.High.Value + 100

local ABILITY_SLOT_COUNT: number = 3
local ABILITY_DEFAULT_COOLDOWN: number = 1
local POSSESSION_CAMERA_ANIM_DURATION: number = 0.9
local POSSESSION_CAMERA_BEHIND_DISTANCE: number = 6
local POSSESSION_CAMERA_BEHIND_HEIGHT: number = 2
local POSSESSION_CAMERA_LOOK_HEIGHT: number = 1.6
local POSSESSION_CAMERA_ENTER_HEIGHT_OFFSET: number = 0.08
local GROUND_CLEARANCE_HEIGHT: number = 1

local MAX_ENERGY: number = 100
local DRAIN_RATE: number = 0
local REGEN_RATE: number = 2
local VM_OFFSET: CFrame = CFrame.new(0, -0.8, -0.8)

local SWAY_POSITION_MULTIPLIER: number = 1.25
local SWAY_ROTATION_MULTIPLIER: number = 1
local SWAY_DAMPING: number = 18
local MAX_SWAY_POSITION: number = 0.18
local MAX_SWAY_ROTATION: number = 0.08

local VISIBLE_NAME_TOKENS: {string} = {
	"arm", "hand", "weapon", "sword", "blade", "gun",
	"rifle", "pistol", "bow", "staff", "wand", "shield",
}

local VISIBLE_EXACT_NAMES: {[string]: boolean} = {
	["left arm"] = true, ["right arm"] = true,
	["lefthand"] = true, ["righthand"] = true,
	["leftlowerarm"] = true, ["rightlowerarm"] = true,
	["leftupperarm"] = true, ["rightupperarm"] = true,
}

local BLOCKED_BODY_NAMES: {[string]: boolean} = {
	["head"] = true, ["torso"] = true, ["humanoidrootpart"] = true,
	["uppertorso"] = true, ["lowertorso"] = true,
	["left leg"] = true, ["right leg"] = true,
	["leftfoot"] = true, ["rightfoot"] = true,
	["leftlowerleg"] = true, ["rightlowerleg"] = true,
	["leftupperleg"] = true, ["rightupperleg"] = true,
}

local BLOCKED_BODY_TOKENS: {string} = {
	"torso", "leg", "foot", "head", "root", "pelvis",
}

------------------//VARIABLES
local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera

local events: Folder = ReplicatedStorage:WaitForChild("Events")
local possessEvent: RemoteEvent = events:WaitForChild("PossessTower")
local shootEvent: RemoteEvent = events:WaitForChild("PossessShoot")
local playVFXEvent: RemoteEvent = events:WaitForChild("PlayPossessVFX")

local vfxLoader = require(ReplicatedStorage:WaitForChild("VFX_Loader"))
local upgradesModule = require(ReplicatedStorage:WaitForChild("Upgrades"))
local PlayerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local controls = PlayerModule:GetControls()

local currentlyPossessing: Model? = nil
local originalCameraCFrame: CFrame? = nil
local currentEnergy: number = MAX_ENERGY
local isAnimatingCamera: boolean = false

local viewmodelFolder: Folder? = nil
local viewmodelModel: Model? = nil
local currentViewmodelCFrame: CFrame? = nil

local viewmodelSwayPosition: Vector3 = Vector3.zero
local viewmodelSwayRotation: Vector2 = Vector2.zero
local lastCameraCFrame: CFrame? = nil

local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local percentLabel: TextLabel = playerGui:WaitForChild("Ingame_HUD"):WaitForChild("CommandEnergy"):WaitForChild("Percent")
local inCommandFrame: GuiObject = playerGui:WaitForChild("Ingame_HUD"):WaitForChild("InCommandFrame")

local oldMaxZoom: number = player.CameraMaxZoomDistance
local oldMinZoom: number = player.CameraMinZoomDistance
local hiddenVFXParts = {}
local cachedUIStates = {}

local upgradeChangedConnection: RBXScriptConnection? = nil
local configUpgradeChangedConnection: RBXScriptConnection? = nil

type AbilitySlotState = {
	Frame: Frame,
	NameLabel: TextLabel,
	KeyLabel: TextLabel,
	CooldownFill: Frame,
	CooldownLabel: TextLabel,
	Cooldown: number,
	ReadyAt: number,
	AOEType: string?,
	AOESize: number?,
	Range: number?,
}

local targetingData = {
	Active = false,
	Slot = nil :: number?,
	UIIndex = nil :: number?,
	Indicator = nil :: BasePart?,
	MaxRange = 0,
}

local crosshairGui: ScreenGui
local abilityHudGui: ScreenGui
local abilityHudContainer: Frame
local abilitySlots: {[number]: AbilitySlotState} = {}
local configure_ability_hud: (({[string]: any}?) -> ())? = nil

------------------//FUNCTIONS
local function create_line(gui: ScreenGui, size: UDim2, pos: UDim2): ()
	local line = Instance.new("Frame")
	line.Size = size
	line.Position = pos
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	line.BorderSizePixel = 0
	line.Parent = gui
end

local function setup_ui(): ()
	crosshairGui = Instance.new("ScreenGui")
	crosshairGui.Name = "PossessionCrosshair"
	crosshairGui.ResetOnSpawn = false
	crosshairGui.Enabled = false
	crosshairGui.Parent = playerGui

	local crosshairCenter = Instance.new("Frame")
	crosshairCenter.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshairCenter.Position = UDim2.fromScale(0.5, 0.5)
	crosshairCenter.Size = UDim2.fromOffset(4, 4)
	crosshairCenter.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
	crosshairCenter.BorderSizePixel = 0
	crosshairCenter.Parent = crosshairGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = crosshairCenter

	create_line(crosshairGui, UDim2.fromOffset(2, 8), UDim2.new(0.5, 0, 0.5, -12))
	create_line(crosshairGui, UDim2.fromOffset(2, 8), UDim2.new(0.5, 0, 0.5, 12))
	create_line(crosshairGui, UDim2.fromOffset(8, 2), UDim2.new(0.5, -12, 0.5, 0))
	create_line(crosshairGui, UDim2.fromOffset(8, 2), UDim2.new(0.5, 12, 0.5, 0))

	abilityHudGui = Instance.new("ScreenGui")
	abilityHudGui.Name = "PossessionAbilityHud"
	abilityHudGui.ResetOnSpawn = false
	abilityHudGui.Enabled = false
	abilityHudGui.Parent = playerGui

	abilityHudContainer = Instance.new("Frame")
	abilityHudContainer.Name = "Container"
	abilityHudContainer.AnchorPoint = Vector2.new(0.5, 1)
	abilityHudContainer.Position = UDim2.new(0.5, 0, 1, -20)
	abilityHudContainer.Size = UDim2.fromOffset(300, 80)
	abilityHudContainer.BackgroundTransparency = 1
	abilityHudContainer.Parent = abilityHudGui

	local abilityHudLayout = Instance.new("UIListLayout")
	abilityHudLayout.FillDirection = Enum.FillDirection.Horizontal
	abilityHudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	abilityHudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	abilityHudLayout.Padding = UDim.new(0, 12)
	abilityHudLayout.Parent = abilityHudContainer
end

local function create_ability_slot(index: number): AbilitySlotState
	local slotFrame = Instance.new("Frame")
	slotFrame.Name = string.format("AbilitySlot%d", index)
	slotFrame.Size = UDim2.fromOffset(70, 70)
	slotFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	slotFrame.BackgroundTransparency = 0.3
	slotFrame.BorderSizePixel = 0
	slotFrame.Parent = abilityHudContainer

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(150, 150, 150)
	stroke.Transparency = 0.2
	stroke.Parent = slotFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slotFrame

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "Key"
	keyLabel.BackgroundTransparency = 1
	keyLabel.Position = UDim2.fromOffset(4, 2)
	keyLabel.Size = UDim2.fromOffset(20, 16)
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.TextSize = 14
	keyLabel.TextXAlignment = Enum.TextXAlignment.Left
	keyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	keyLabel.Text = "Key"
	keyLabel.ZIndex = 5
	keyLabel.Parent = slotFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.new(0, 4, 1, -20)
	nameLabel.Size = UDim2.new(1, -8, 0, 18)
	nameLabel.Font = Enum.Font.GothamSemibold
	nameLabel.TextSize = 11
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = "Ability"
	nameLabel.ZIndex = 5
	nameLabel.Parent = slotFrame

	local cooldownFrame = Instance.new("Frame")
	cooldownFrame.Name = "CooldownFill"
	cooldownFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cooldownFrame.BackgroundTransparency = 0.5
	cooldownFrame.BorderSizePixel = 0
	cooldownFrame.AnchorPoint = Vector2.new(0.5, 1)
	cooldownFrame.Position = UDim2.new(0.5, 0, 1, 0)
	cooldownFrame.Size = UDim2.fromScale(1, 0)
	cooldownFrame.ZIndex = 3
	cooldownFrame.Parent = slotFrame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = cooldownFrame

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "Cooldown"
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Position = UDim2.fromScale(0, 0)
	cooldownLabel.Size = UDim2.fromScale(1, 1)
	cooldownLabel.Font = Enum.Font.GothamBold
	cooldownLabel.TextSize = 20
	cooldownLabel.TextXAlignment = Enum.TextXAlignment.Center
	cooldownLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	cooldownLabel.Text = ""
	cooldownLabel.ZIndex = 4
	cooldownLabel.Parent = slotFrame

	return {
		Frame = slotFrame,
		NameLabel = nameLabel,
		KeyLabel = keyLabel,
		CooldownFill = cooldownFrame,
		CooldownLabel = cooldownLabel,
		Cooldown = ABILITY_DEFAULT_COOLDOWN,
		ReadyAt = 0,
		AOEType = nil,
		AOESize = nil,
		Range = nil,
	}
end

local function refresh_camera(): ()
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		camera = currentCamera
		lastCameraCFrame = currentCamera.CFrame
		if viewmodelFolder then
			viewmodelFolder.Parent = currentCamera
		end
	end
end

local function clamp_vector3_magnitude(value: Vector3, maxMagnitude: number): Vector3
	local magnitude = value.Magnitude
	if magnitude > maxMagnitude and magnitude > 0 then
		return value.Unit * maxMagnitude
	end
	return value
end

local function clamp_vector2_magnitude(value: Vector2, maxMagnitude: number): Vector2
	local magnitude = value.Magnitude
	if magnitude > maxMagnitude and magnitude > 0 then
		return value.Unit * maxMagnitude
	end
	return value
end

local function get_camera_head(towerModel: Model, towerRoot: BasePart): BasePart
	local head = towerModel:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	local newHead = Instance.new("Part")
	newHead.Name = "Head"
	newHead.Size = Vector3.new(1, 1, 1)
	newHead.Transparency = 1
	newHead.CanCollide = false
	newHead.CanTouch = false
	newHead.CanQuery = false
	newHead.Massless = true
	newHead.CFrame = towerRoot.CFrame * CFrame.new(0, 1.5, 0)
	newHead.Parent = towerModel

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = towerRoot
	weld.Part1 = newHead
	weld.Parent = newHead

	return newHead
end

local function get_possession_focus_position(towerRoot: BasePart): Vector3
	return towerRoot.Position + Vector3.new(0, POSSESSION_CAMERA_LOOK_HEIGHT, 0)
end

local function get_possession_behind_cframe(towerRoot: BasePart): CFrame
	local focusPosition = get_possession_focus_position(towerRoot)
	local lookVector = towerRoot.CFrame.LookVector
	local behindPosition = focusPosition - (lookVector * POSSESSION_CAMERA_BEHIND_DISTANCE) + Vector3.new(0, POSSESSION_CAMERA_BEHIND_HEIGHT, 0)

	return CFrame.lookAt(behindPosition, focusPosition)
end

local function get_possession_enter_cframe(towerModel: Model, towerRoot: BasePart): CFrame
	local head = get_camera_head(towerModel, towerRoot)
	local enterPosition = head.Position + Vector3.new(0, POSSESSION_CAMERA_ENTER_HEIGHT_OFFSET, 0)
	local lookPosition = enterPosition + towerRoot.CFrame.LookVector

	return CFrame.lookAt(enterPosition, lookPosition)
end

local function getAimPosition(): Vector3
	local rayOrigin = camera.CFrame.Position
	local rayDirection = camera.CFrame.LookVector * 2000
	local raycastParams = RaycastParams.new()

	local filterList = {}
	if player.Character then
		table.insert(filterList, player.Character)
	end
	if currentlyPossessing then
		table.insert(filterList, currentlyPossessing)
	end
	if viewmodelFolder then
		table.insert(filterList, viewmodelFolder)
	end

	raycastParams.FilterDescendantsInstances = filterList
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if rayResult then
		return rayResult.Position
	end

	return rayOrigin + rayDirection
end

local function clear_viewmodel(): ()
	if viewmodelFolder then
		viewmodelFolder:Destroy()
		viewmodelFolder = nil
	end

	viewmodelModel = nil
	currentViewmodelCFrame = nil
	viewmodelSwayPosition = Vector3.zero
	viewmodelSwayRotation = Vector2.zero
	lastCameraCFrame = nil
end

local function cancel_targeting(): ()
	targetingData.Active = false
	targetingData.Slot = nil
	targetingData.UIIndex = nil

	if targetingData.Indicator then
		targetingData.Indicator:Destroy()
		targetingData.Indicator = nil
	end
end

local function toggle_targeting(uiIndex: number, serverSlot: number?, slotData: AbilitySlotState): ()
	if targetingData.Active and targetingData.UIIndex == uiIndex then
		cancel_targeting()
		return
	end

	if os.clock() < abilitySlots[uiIndex].ReadyAt then
		return
	end

	cancel_targeting()

	targetingData.Active = true
	targetingData.UIIndex = uiIndex
	targetingData.Slot = serverSlot
	targetingData.MaxRange = slotData.Range or 20

	local radius = slotData.AOESize or 10
	local indicator = Instance.new("Part")
	indicator.Name = "SplashIndicator"
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Size = Vector3.new(0.5, radius * 2, radius * 2)
	indicator.Orientation = Vector3.new(0, 0, 90)
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.CanQuery = false
	indicator.CanTouch = false
	indicator.Transparency = 0.6
	indicator.Color = Color3.fromRGB(0, 255, 255)
	indicator.Material = Enum.Material.ForceField
	indicator.Parent = workspace

	targetingData.Indicator = indicator
end

local function is_seed_viewmodel_part(part: BasePart): boolean
	local lowerName = string.lower(part.Name)
	if VISIBLE_EXACT_NAMES[lowerName] then
		return true
	end

	for _, token in VISIBLE_NAME_TOKENS do
		if string.find(lowerName, token, 1, true) then
			return true
		end
	end

	return false
end

local function is_blocked_body_part(part: BasePart): boolean
	local lowerName = string.lower(part.Name)
	if is_seed_viewmodel_part(part) then
		return false
	end

	if BLOCKED_BODY_NAMES[lowerName] then
		return true
	end

	for _, token in BLOCKED_BODY_TOKENS do
		if string.find(lowerName, token, 1, true) then
			return true
		end
	end

	return false
end

local function add_part_link(adjacency: {[BasePart]: {BasePart}}, part0: BasePart?, part1: BasePart?): ()
	if not part0 or not part1 then
		return
	end

	if not adjacency[part0] then
		adjacency[part0] = {}
	end

	if not adjacency[part1] then
		adjacency[part1] = {}
	end

	table.insert(adjacency[part0], part1)
	table.insert(adjacency[part1], part0)
end

local function get_parent_basepart(obj: Instance, rootModel: Model): BasePart?
	local current = obj.Parent
	while current and current ~= rootModel do
		if current:IsA("BasePart") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function has_visible_basepart_ancestor(obj: Instance, rootModel: Model, visibleParts: {[BasePart]: boolean}): boolean
	local current = obj.Parent
	while current and current ~= rootModel do
		if current:IsA("BasePart") and visibleParts[current] then
			return true
		end
		current = current.Parent
	end
	return false
end

local function collect_visible_viewmodel_parts(model: Model): {[BasePart]: boolean}
	local visibleParts: {[BasePart]: boolean} = {}
	local adjacency: {[BasePart]: {BasePart}} = {}
	local queue: {BasePart} = {}

	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") and is_seed_viewmodel_part(obj) then
			visibleParts[obj] = true
			table.insert(queue, obj)
		end
	end

	for _, obj in model:GetDescendants() do
		if obj:IsA("Motor6D") or obj:IsA("Weld") or obj:IsA("WeldConstraint") then
			add_part_link(adjacency, obj.Part0, obj.Part1)
		elseif obj:IsA("RigidConstraint") then
			local part0 = obj.Attachment0 and obj.Attachment0.Parent
			local part1 = obj.Attachment1 and obj.Attachment1.Parent
			add_part_link(adjacency, part0 and part0:IsA("BasePart") and part0 or nil, part1 and part1:IsA("BasePart") and part1 or nil)
		end
	end

	local queueIndex = 1
	while queueIndex <= #queue do
		local currentPart = queue[queueIndex]
		queueIndex += 1

		if adjacency[currentPart] then
			for _, neighbor in adjacency[currentPart] do
				if not visibleParts[neighbor] and not is_blocked_body_part(neighbor) then
					visibleParts[neighbor] = true
					table.insert(queue, neighbor)
				end
			end
		end
	end

	return visibleParts
end

local function configure_viewmodel(model: Model): ()
	for _, obj in model:GetDescendants() do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("FaceControls") or obj:IsA("ParticleEmitter") then
			obj:Destroy()
		end
	end

	local visibleParts = collect_visible_viewmodel_parts(model)

	for _, obj in model:GetDescendants() do
		if obj:IsA("BasePart") then
			local hasVisibleAncestor = has_visible_basepart_ancestor(obj, model, visibleParts)

			if get_parent_basepart(obj, model) and not hasVisibleAncestor then
				obj:Destroy()
			else
				obj.Anchored = false
				obj.CanCollide = false
				obj.CanTouch = false
				obj.CanQuery = false
				obj.CastShadow = false
				obj.Massless = true
				obj.Transparency = (visibleParts[obj] or hasVisibleAncestor) and 0 or 1
			end
		elseif obj:IsA("Humanoid") then
			obj.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			obj.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		end
	end

	local rootPart = model:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = true
		model.PrimaryPart = rootPart
	end
end

local function create_viewmodel(sourceModel: Model): ()
	clear_viewmodel()

	viewmodelFolder = Instance.new("Folder")
	viewmodelFolder.Name = "Viewmodel"
	viewmodelFolder.Parent = camera

	viewmodelModel = sourceModel:Clone()
	viewmodelModel.Name = "VM"
	viewmodelModel.Parent = viewmodelFolder

	configure_viewmodel(viewmodelModel)
	currentViewmodelCFrame = camera.CFrame * VM_OFFSET
	lastCameraCFrame = camera.CFrame
end

local function toggle_camera_vfx(isVisible: boolean): ()
	if not isVisible then
		hiddenVFXParts = {}

		for _, child in camera:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(hiddenVFXParts, {instance = child, trans = child.Transparency})
				child.Transparency = 1

				for _, desc in child:GetDescendants() do
					if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
						table.insert(hiddenVFXParts, {instance = desc, trans = desc.Transparency})
						desc.Transparency = 1
					end
				end
			end
		end
	else
		for _, data in hiddenVFXParts do
			if data.instance and data.instance.Parent then
				data.instance.Transparency = data.trans
			end
		end

		hiddenVFXParts = {}
	end
end

local function hideAndCacheUIElements(): ()
	cachedUIStates = {}
	local list = {
		["Slots"] = true,
		["SelectionUi"] = true,
		["PhoneControls"] = true,
		["Controls"] = true,
	}

	for _, ui in playerGui:GetDescendants() do
		if list[ui.Name] and ui:IsA("GuiObject") then
			table.insert(cachedUIStates, {element = ui, wasVisible = ui.Visible})
			ui.Visible = false
		end
	end
end

local function restoreUIElements(): ()
	for _, data in cachedUIStates do
		if data.element and data.element.Parent then
			data.element.Visible = data.wasVisible
		end
	end

	cachedUIStates = {}
end

local function disconnect_upgrade_watchers(): ()
	if upgradeChangedConnection then
		upgradeChangedConnection:Disconnect()
		upgradeChangedConnection = nil
	end

	if configUpgradeChangedConnection then
		configUpgradeChangedConnection:Disconnect()
		configUpgradeChangedConnection = nil
	end
end

local function read_numeric_upgrade_value(valueObject: Instance?): number?
	if not valueObject then
		return nil
	end

	if valueObject:IsA("IntValue") or valueObject:IsA("NumberValue") then
		return valueObject.Value
	end

	if valueObject:IsA("StringValue") then
		return tonumber(valueObject.Value)
	end

	return nil
end

local function get_tower_upgrade_level(towerModel: Model): number
	local towerData = upgradesModule[towerModel.Name]
	local maxUpgradeIndex = (towerData and towerData.Upgrades and #towerData.Upgrades) or 1
	local config = towerModel:FindFirstChild("Config")

	local rawUpgrade: number? = nil

	if config then
		rawUpgrade = read_numeric_upgrade_value(config:FindFirstChild("Upgrades"))
	end

	if rawUpgrade == nil then
		local attrUpgrades = towerModel:GetAttribute("Upgrades")
		if attrUpgrades ~= nil then
			rawUpgrade = tonumber(attrUpgrades)
		end
	end

	if rawUpgrade == nil and config then
		rawUpgrade = read_numeric_upgrade_value(config:FindFirstChild("Upgrade"))
	end

	if rawUpgrade == nil then
		local attrUpgrade = towerModel:GetAttribute("Upgrade")
		if attrUpgrade ~= nil then
			rawUpgrade = tonumber(attrUpgrade)
		end
	end

	rawUpgrade = math.max(1, math.floor(rawUpgrade or 1))
	local progressionIndex = math.clamp(rawUpgrade, 1, maxUpgradeIndex)

	return progressionIndex
end

local function get_possession_abilities_from_tower(towerModel: Model): {{[string]: any}?}
	local towerData = upgradesModule[towerModel.Name]
	if not towerData or not towerData.Upgrades or not towerData.Upgrades[1] then
		return {nil, nil}
	end

	local unlockedUpgradeIndex = get_tower_upgrade_level(towerModel)
	local basicAttackName = towerData.Upgrades[1].AttackName

	local attackProgression = {}
	local abilityNames = {}

	for index, upgradeData in towerData.Upgrades do
		if index > unlockedUpgradeIndex then
			break
		end

		local attackName = upgradeData.AttackName
		if attackName then
			attackProgression[attackName] = {
				Name = attackName,
				Cooldown = upgradeData.Cooldown or ABILITY_DEFAULT_COOLDOWN,
				AOEType = upgradeData.AOEType,
				AOESize = upgradeData.AOESize,
				Range = upgradeData.Range,
			}

			if attackName ~= basicAttackName and not table.find(abilityNames, attackName) then
				table.insert(abilityNames, attackName)
			end
		end
	end

	local ability1 = abilityNames[1] and attackProgression[abilityNames[1]] or nil
	local ability2 = abilityNames[2] and attackProgression[abilityNames[2]] or nil

	return {ability1, ability2}
end

local function refresh_possession_ability_hud_from_tower(): ()
	if not currentlyPossessing or not configure_ability_hud then
		return
	end

	local towerData = upgradesModule[currentlyPossessing.Name]
	if not towerData or not towerData.Upgrades or not towerData.Upgrades[1] then
		configure_ability_hud(nil)
		return
	end

	local baseUpgrade = towerData.Upgrades[1]
	local abilities = get_possession_abilities_from_tower(currentlyPossessing)

	local hudData = {
		Basic = {
			Name = baseUpgrade.AttackName or "Attack",
			Cooldown = baseUpgrade.Cooldown or ABILITY_DEFAULT_COOLDOWN,
			AOEType = baseUpgrade.AOEType,
			AOESize = baseUpgrade.AOESize,
			Range = baseUpgrade.Range,
		},
		Abilities = abilities,
	}

	configure_ability_hud(hudData)
end

local function reset_ability_hud(): ()
	for _, slot in abilitySlots do
		slot.Cooldown = ABILITY_DEFAULT_COOLDOWN
		slot.ReadyAt = 0
		slot.CooldownFill.Size = UDim2.fromScale(1, 0)
		slot.CooldownLabel.Text = ""
		slot.Frame.Visible = false
	end
end

configure_ability_hud = function(possessionData: {[string]: any}?): ()
	reset_ability_hud()

	if not possessionData then
		return
	end

	local function setup_slot(index: number, data: {[string]: any}?, defaultKey: string): ()
		local slot = abilitySlots[index]
		if data and slot then
			slot.NameLabel.Text = (typeof(data.Name) == "string" and data.Name ~= "") and data.Name or ("Attack " .. index)
			slot.Cooldown = (typeof(data.Cooldown) == "number" and data.Cooldown > 0) and data.Cooldown or ABILITY_DEFAULT_COOLDOWN
			slot.KeyLabel.Text = defaultKey
			slot.AOEType = data.AOEType
			slot.AOESize = data.AOESize
			slot.Range = data.Range
			slot.Frame.Visible = true
		end
	end

	setup_slot(1, possessionData.Basic, "M1")

	if possessionData.Abilities then
		setup_slot(2, possessionData.Abilities[1], "1")
		setup_slot(3, possessionData.Abilities[2], "2")
	end
end

local function trigger_ability_cooldown(uiSlotIndex: number): boolean
	local slot = abilitySlots[uiSlotIndex]
	if not slot or not slot.Frame.Visible or os.clock() < slot.ReadyAt then
		return false
	end

	slot.ReadyAt = os.clock() + slot.Cooldown
	slot.CooldownFill.Size = UDim2.fromScale(1, 1)

	local tween = TweenService:Create(slot.CooldownFill, TweenInfo.new(slot.Cooldown, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 0),
	})
	tween:Play()

	return true
end

local function keep_tower_above_ground(towerRoot: BasePart): ()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {towerRoot.Parent}

	local hit = workspace:Raycast(towerRoot.Position + Vector3.new(0, 3, 0), Vector3.new(0, -50, 0), raycastParams)
	if hit then
		local minY = hit.Position.Y + (towerRoot.Size.Y * 0.5) + GROUND_CLEARANCE_HEIGHT
		if towerRoot.Position.Y < minY then
			towerRoot.CFrame = CFrame.new(towerRoot.Position.X, minY, towerRoot.Position.Z) * (towerRoot.CFrame - towerRoot.Position)
		end
	end
end

local function play_possession_camera_animation(towerModel: Model, towerRoot: BasePart): ()
	local originalCameraType = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseIconEnabled = false

	local startCamCFrame = camera.CFrame
	local behindCamCFrame = get_possession_behind_cframe(towerRoot)
	local enterCamCFrame = get_possession_enter_cframe(towerModel, towerRoot)

	local firstStageDuration = POSSESSION_CAMERA_ANIM_DURATION * 0.55
	local secondStageDuration = POSSESSION_CAMERA_ANIM_DURATION * 0.45

	local elapsed = 0
	while elapsed < POSSESSION_CAMERA_ANIM_DURATION and currentlyPossessing and towerRoot.Parent do
		local dt = RunService.RenderStepped:Wait()
		elapsed += dt

		if elapsed <= firstStageDuration then
			local alpha = math.clamp(elapsed / firstStageDuration, 0, 1)
			local easedAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			camera.CFrame = startCamCFrame:Lerp(behindCamCFrame, easedAlpha)
		else
			local alpha = math.clamp((elapsed - firstStageDuration) / secondStageDuration, 0, 1)
			local easedAlpha = TweenService:GetValue(alpha, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
			camera.CFrame = behindCamCFrame:Lerp(enterCamCFrame, easedAlpha)
		end
	end

	camera.CFrame = enterCamCFrame
	camera.CameraType = originalCameraType
end

------------------//MAIN FUNCTIONS
local function on_possess_confirm(towerModel: Model?, state: boolean, possessionData: {[string]: any}?): ()
	if isAnimatingCamera then
		return
	end

	if state and towerModel then
		isAnimatingCamera = true
		inCommandFrame.Visible = true

		-- Salva a posição exata da câmera do jogador
		originalCameraCFrame = camera.CFrame

		currentlyPossessing = towerModel
		currentEnergy = MAX_ENERGY

		hideAndCacheUIElements()
		toggle_camera_vfx(false)

		local hrp = towerModel:FindFirstChild("HumanoidRootPart")
		local humanoid = towerModel:FindFirstChild("Humanoid")

		if hrp and hrp:IsA("BasePart") then
			keep_tower_above_ground(hrp)
			get_camera_head(towerModel, hrp)

			hrp.Anchored = true
			hrp.AssemblyLinearVelocity = Vector3.zero

			if humanoid and humanoid:IsA("Humanoid") then
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			end

			play_possession_camera_animation(towerModel, hrp)

			hrp.Anchored = false

			if humanoid and humanoid:IsA("Humanoid") then
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end
		end

		if humanoid and humanoid:IsA("Humanoid") then
			camera.CameraSubject = humanoid
		end

		oldMinZoom = player.CameraMinZoomDistance
		oldMaxZoom = player.CameraMaxZoomDistance

		player.CameraMinZoomDistance = 0.5
		player.CameraMaxZoomDistance = 0.5
		camera.CameraType = Enum.CameraType.Custom

		UserInputService.MouseIconEnabled = false
		crosshairGui.Enabled = true
		abilityHudGui.Enabled = true
		configure_ability_hud(possessionData)
		refresh_possession_ability_hud_from_tower()

		disconnect_upgrade_watchers()

		local config = towerModel:FindFirstChild("Config")

		if towerModel:GetAttribute("Upgrades") ~= nil then
			upgradeChangedConnection = towerModel:GetAttributeChangedSignal("Upgrades"):Connect(refresh_possession_ability_hud_from_tower)
		elseif towerModel:GetAttribute("Upgrade") ~= nil then
			upgradeChangedConnection = towerModel:GetAttributeChangedSignal("Upgrade"):Connect(refresh_possession_ability_hud_from_tower)
		end

		if config then
			local upgradesValue = config:FindFirstChild("Upgrades")
			if upgradesValue and (upgradesValue:IsA("IntValue") or upgradesValue:IsA("NumberValue") or upgradesValue:IsA("StringValue")) then
				configUpgradeChangedConnection = upgradesValue.Changed:Connect(refresh_possession_ability_hud_from_tower)
			else
				local upgradeValue = config:FindFirstChild("Upgrade")
				if upgradeValue and (upgradeValue:IsA("IntValue") or upgradeValue:IsA("NumberValue") or upgradeValue:IsA("StringValue")) then
					configUpgradeChangedConnection = upgradeValue.Changed:Connect(refresh_possession_ability_hud_from_tower)
				end
			end
		end

		ContextActionService:BindActionAtPriority(
			BLOCK_ACTION_NAME,
			function()
				return Enum.ContextActionResult.Sink
			end,
			false,
			INPUT_PRIORITY,
			Enum.KeyCode.Three,
			Enum.KeyCode.Four,
			Enum.KeyCode.Five,
			Enum.KeyCode.Six,
			Enum.KeyCode.Q,
			Enum.KeyCode.R,
			Enum.KeyCode.X,
			Enum.KeyCode.LeftControl,
			Enum.KeyCode.RightControl,
			Enum.KeyCode.LeftShift,
			Enum.KeyCode.RightShift
		)

		create_viewmodel(towerModel)
		isAnimatingCamera = false
	else
		isAnimatingCamera = false
		inCommandFrame.Visible = false
		currentlyPossessing = nil
		restoreUIElements()
		cancel_targeting()

		-- Restaura o modo de câmera clássico
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = oldMaxZoom

		-- Força a câmera a se afastar para o padrão de terceira pessoa
		local targetThirdPersonZoom = 12.5
		if targetThirdPersonZoom > oldMaxZoom then
			targetThirdPersonZoom = oldMaxZoom
		end
		player.CameraMinZoomDistance = targetThirdPersonZoom

		-- Defer para voltar aos limites reais originais após o recálculo do Roblox
		task.defer(function()
			player.CameraMinZoomDistance = oldMinZoom
		end)

		camera.CameraType = Enum.CameraType.Custom

		if player.Character and player.Character:FindFirstChild("Humanoid") then
			-- Volta o foco para o personagem e deixa o sistema nativo cuidar da transição limpa
			camera.CameraSubject = player.Character.Humanoid
		end

		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
		crosshairGui.Enabled = false
		abilityHudGui.Enabled = false
		reset_ability_hud()
		disconnect_upgrade_watchers()

		ContextActionService:UnbindAction(BLOCK_ACTION_NAME)
		toggle_camera_vfx(true)
		clear_viewmodel()
	end
end

local function on_possess_action(_: string, inputState: Enum.UserInputState, _: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	if isAnimatingCamera then
		return Enum.ContextActionResult.Sink
	end

	if currentlyPossessing then
		possessEvent:FireServer(nil)
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

local function fire_possession_attack(uiSlotIndex: number, serverSlotIndex: number?): Enum.ContextActionResult
	if currentlyPossessing then
		if not trigger_ability_cooldown(uiSlotIndex) then
			return Enum.ContextActionResult.Sink
		end

		shootEvent:FireServer(getAimPosition(), camera.CFrame.LookVector, serverSlotIndex)
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

local function on_shoot_action(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or isAnimatingCamera then
		return Enum.ContextActionResult.Pass
	end

	if targetingData.Active and currentlyPossessing then
		if trigger_ability_cooldown(targetingData.UIIndex) then
			shootEvent:FireServer(targetingData.Indicator.Position, camera.CFrame.LookVector, targetingData.Slot)
		end
		cancel_targeting()
		return Enum.ContextActionResult.Sink
	end

	local slot = abilitySlots[1]
	if slot and slot.Frame.Visible and slot.AOEType == "Splash" then
		toggle_targeting(1, nil, slot)
		return Enum.ContextActionResult.Sink
	end

	return fire_possession_attack(1, nil)
end

local function on_cancel_action(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin and targetingData.Active then
		cancel_targeting()
		return Enum.ContextActionResult.Sink
	end

	return Enum.ContextActionResult.Pass
end

local function on_ability_one_action(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or isAnimatingCamera then
		return Enum.ContextActionResult.Pass
	end

	local slot = abilitySlots[2]
	if slot.Frame.Visible and slot.AOEType == "Splash" then
		toggle_targeting(2, 1, slot)
		return Enum.ContextActionResult.Sink
	end

	return fire_possession_attack(2, 1)
end

local function on_ability_two_action(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin or isAnimatingCamera then
		return Enum.ContextActionResult.Pass
	end

	local slot = abilitySlots[3]
	if slot.Frame.Visible and slot.AOEType == "Splash" then
		toggle_targeting(3, 2, slot)
		return Enum.ContextActionResult.Sink
	end

	return fire_possession_attack(3, 2)
end

local function on_play_vfx(towerModel: Model, moduleName: string, attackName: string, hitPosition: Vector3): ()
	local humanoidRootPart = towerModel:FindFirstChild("HumanoidRootPart")

	if currentlyPossessing == towerModel and viewmodelModel then
		local vmHRP = viewmodelModel:FindFirstChild("HumanoidRootPart")
		if vmHRP then
			humanoidRootPart = vmHRP
		end
	end

	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return
	end

	for _, partName in {"TowerBasePart", "VFXTowerBasePart"} do
		local basePart = towerModel:FindFirstChild(partName)
		if basePart and basePart:IsA("BasePart") then
			basePart.CFrame = humanoidRootPart.CFrame
		end
	end

	local mockTarget = Instance.new("Model")
	mockTarget.Name = "DummyEnemy"

	local mockHRP = Instance.new("Part")
	mockHRP.Name = "HumanoidRootPart"
	mockHRP.Size = Vector3.new(2, 2, 2)
	mockHRP.CFrame = CFrame.new(hitPosition)
	mockHRP.Anchored = true
	mockHRP.Transparency = 1
	mockHRP.CanCollide = false
	mockHRP.Parent = mockTarget

	mockTarget.PrimaryPart = mockHRP
	Instance.new("Humanoid", mockTarget)

	mockTarget.Parent = workspace:FindFirstChild("VFX") or workspace
	Debris:AddItem(mockTarget, 5)

	local vfxFunction = nil

	if vfxLoader[moduleName] and type(vfxLoader[moduleName]) == "table" and vfxLoader[moduleName][attackName] then
		vfxFunction = vfxLoader[moduleName][attackName]
	else
		for _, subModule in vfxLoader do
			if type(subModule) == "table" and subModule[attackName] then
				vfxFunction = subModule[attackName]
				break
			end
		end
	end

	if vfxFunction then
		task.spawn(function()
			pcall(function()
				vfxFunction(humanoidRootPart, mockTarget)
			end)
		end)
	else
		warn(string.format("[PossessionClient] O VFX '%s' não foi encontrado em nenhum módulo do VFX_Loader!", attackName))
	end
end

local function sync_viewmodel_motors(): ()
	if not currentlyPossessing or not viewmodelModel then
		return
	end

	for _, obj in currentlyPossessing:GetDescendants() do
		if obj:IsA("Motor6D") and obj.Parent then
			local vmPart = viewmodelModel:FindFirstChild(obj.Parent.Name, true)
			local vmMotor = vmPart and vmPart:FindFirstChild(obj.Name)

			if vmMotor and vmMotor:IsA("Motor6D") then
				vmMotor.Transform = obj.Transform
			end
		end
	end
end

local function on_render_step(deltaTime: number): ()
	if currentlyPossessing and not isAnimatingCamera then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

		if DRAIN_RATE <= 0 then
			currentEnergy = MAX_ENERGY
		else
			currentEnergy = math.max(0, currentEnergy - (DRAIN_RATE * deltaTime))
			if currentEnergy <= 0 then
				possessEvent:FireServer(nil)
				currentlyPossessing = nil
			end
		end
	elseif not currentlyPossessing then
		currentEnergy = math.min(MAX_ENERGY, currentEnergy + (REGEN_RATE * deltaTime))
	end

	percentLabel.Text = math.floor(currentEnergy) .. "%"

	for _, slot in abilitySlots do
		if slot.Frame.Visible then
			local remaining = math.max(0, slot.ReadyAt - os.clock())
			if remaining > 0 then
				slot.CooldownLabel.Text = string.format("%.1f", remaining)
			else
				slot.CooldownLabel.Text = ""
			end
		end
	end

	if currentlyPossessing and not isAnimatingCamera then
		local humanoid = currentlyPossessing:FindFirstChild("Humanoid")
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid:Move(controls:GetMoveVector(), true)
		end
	end

	if viewmodelModel and viewmodelModel.PrimaryPart and not isAnimatingCamera then
		local baseCFrame = camera.CFrame * VM_OFFSET
		local deltaCFrame = lastCameraCFrame and lastCameraCFrame:ToObjectSpace(camera.CFrame) or CFrame.new()
		local deltaPosition = deltaCFrame.Position
		local deltaPitch, deltaYaw = deltaCFrame:ToOrientation()

		local targetSwayPos = clamp_vector3_magnitude(
			Vector3.new(-deltaPosition.X, -deltaPosition.Y, deltaPosition.Z * 0.25) * SWAY_POSITION_MULTIPLIER,
			MAX_SWAY_POSITION
		)

		local targetSwayRot = clamp_vector2_magnitude(
			Vector2.new(-deltaPitch, -deltaYaw) * SWAY_ROTATION_MULTIPLIER,
			MAX_SWAY_ROTATION
		)

		local swayAlpha = 1 - math.exp(-SWAY_DAMPING * deltaTime)
		viewmodelSwayPosition = viewmodelSwayPosition:Lerp(targetSwayPos, swayAlpha)
		viewmodelSwayRotation = viewmodelSwayRotation:Lerp(targetSwayRot, swayAlpha)

		currentViewmodelCFrame = baseCFrame * CFrame.new(viewmodelSwayPosition) * CFrame.Angles(viewmodelSwayRotation.X, viewmodelSwayRotation.Y, 0)
		viewmodelModel:PivotTo(currentViewmodelCFrame)
		sync_viewmodel_motors()
	end

	lastCameraCFrame = camera.CFrame

	if targetingData.Active and targetingData.Indicator and currentlyPossessing then
		local aimPos = getAimPosition()
		local towerHRP = currentlyPossessing:FindFirstChild("HumanoidRootPart")

		if towerHRP and towerHRP:IsA("BasePart") then
			local towerPos = towerHRP.Position
			local flatTowerPos = Vector3.new(towerPos.X, aimPos.Y, towerPos.Z)
			local dist = (aimPos - flatTowerPos).Magnitude

			if dist > targetingData.MaxRange then
				local dir = (aimPos - flatTowerPos).Unit
				aimPos = flatTowerPos + (dir * targetingData.MaxRange)
			end

			aimPos = aimPos + Vector3.new(0, 0.2, 0)
			targetingData.Indicator.CFrame = CFrame.new(aimPos) * CFrame.Angles(0, 0, math.rad(90))
		end
	end
end

------------------//INIT
setup_ui()

for i = 1, ABILITY_SLOT_COUNT do
	abilitySlots[i] = create_ability_slot(i)
end

inCommandFrame.Visible = false

ContextActionService:BindActionAtPriority(POSSESS_ACTION_NAME, on_possess_action, false, INPUT_PRIORITY, POSSESS_KEY)
ContextActionService:BindActionAtPriority(SHOOT_ACTION_NAME, on_shoot_action, false, INPUT_PRIORITY, Enum.UserInputType.MouseButton1)
ContextActionService:BindActionAtPriority(CANCEL_ACTION_NAME, on_cancel_action, false, INPUT_PRIORITY, Enum.UserInputType.MouseButton2)
ContextActionService:BindActionAtPriority(ABILITY_ONE_ACTION_NAME, on_ability_one_action, false, INPUT_PRIORITY, Enum.KeyCode.One)
ContextActionService:BindActionAtPriority(ABILITY_TWO_ACTION_NAME, on_ability_two_action, false, INPUT_PRIORITY, Enum.KeyCode.Two)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refresh_camera)
possessEvent.OnClientEvent:Connect(on_possess_confirm)
playVFXEvent.OnClientEvent:Connect(on_play_vfx)
RunService.RenderStepped:Connect(on_render_step)