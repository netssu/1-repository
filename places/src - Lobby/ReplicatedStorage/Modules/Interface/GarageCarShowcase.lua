------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local ASSET_FOLDER_NAME: string = "InventoryAssets"
local ITEMS_FOLDER_NAME: string = "Items"
local LIVERY_FOLDER_NAME: string = "Livery"
local PLOTS_FOLDER_NAME: string = "PlotsCars"
local CAMERA_FOLDER_NAME: string = "Cam"
local SHOWCASE_FOLDER_PREFIX: string = "_RemakeCarShowcase_"
local TARGET_LENGTH: number = 24
local TARGET_WIDTH: number = 7.9
local TARGET_HEIGHT: number = 7.2

type SlotInfo = {
	part: BasePart,
	camera: BasePart,
}

------------------//DEPENDENCIES
local dataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//VARIABLES
local localPlayer: Player
local showcaseFolder: Folder?
local slotInfos: { SlotInfo } = {}
local cameraAnchors: { BasePart } = {}
local isActive: boolean = false
local itemNames: { string } = {}
local equippedItemName: string?

------------------//FUNCTIONS
local function get_plots_folder(): Folder?
	local plots = workspace:FindFirstChild(PLOTS_FOLDER_NAME)
	return if plots and plots:IsA("Folder") then plots else nil
end

local function get_livery_assets(): Folder?
	local inventoryAssets = ReplicatedStorage:FindFirstChild(ASSET_FOLDER_NAME)
	local items = inventoryAssets and inventoryAssets:FindFirstChild(ITEMS_FOLDER_NAME)
	local livery = items and items:FindFirstChild(LIVERY_FOLDER_NAME)
	return if livery and livery:IsA("Folder") then livery else nil
end

local function get_horizontal_distance(first: Vector3, second: Vector3): number
	local difference = first - second
	return difference.X * difference.X + difference.Z * difference.Z
end

local function get_camera_anchors(plotsFolder: Folder): { BasePart }
	local anchors: { BasePart } = {}
	local cameraFolder = plotsFolder:FindFirstChild(CAMERA_FOLDER_NAME)
	if not cameraFolder then
		return anchors
	end

	for _, child in cameraFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(anchors, child)
		end
	end

	table.sort(anchors, function(first: BasePart, second: BasePart): boolean
		return first.Position.Z > second.Position.Z
	end)
	return anchors
end

local function get_slot_infos(plotsFolder: Folder, anchors: { BasePart }): { SlotInfo }
	local slots: { BasePart } = {}
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(slots, child)
		end
	end

	local groups: { { anchor: BasePart, slots: { BasePart } } } = {}
	for _, anchor in anchors do
		table.insert(groups, {
			anchor = anchor,
			slots = {},
		})
	end

	for _, slot in slots do
		local closestAnchor = anchors[1]
		local closestDistance = math.huge
		for _, anchor in anchors do
			local distance = get_horizontal_distance(slot.Position, anchor.Position)
			if distance < closestDistance then
				closestDistance = distance
				closestAnchor = anchor
			end
		end

		if closestAnchor then
			for _, group in groups do
				if group.anchor == closestAnchor then
					table.insert(group.slots, slot)
					break
				end
			end
		end
	end

	local infos: { SlotInfo } = {}
	for _, group in groups do
		table.sort(group.slots, function(first: BasePart, second: BasePart): boolean
			if group.anchor.Position.X >= 0 then
				return first.Position.X > second.Position.X
			end
			return first.Position.X < second.Position.X
		end)

		for _, slot in group.slots do
			table.insert(infos, {
				part = slot,
				camera = group.anchor,
			})
		end
	end

	return infos
end

local function ensure_layout(): ()
	local plotsFolder = get_plots_folder()
	if not plotsFolder then
		return
	end

	cameraAnchors = get_camera_anchors(plotsFolder)
	slotInfos = get_slot_infos(plotsFolder, cameraAnchors)
end

local function get_showcase_folder(): Folder
	if showcaseFolder and showcaseFolder.Parent then
		return showcaseFolder
	end

	local folderName = SHOWCASE_FOLDER_PREFIX .. tostring(localPlayer.UserId)
	local existingFolder = workspace:FindFirstChild(folderName)
	if existingFolder and existingFolder:IsA("Folder") then
		showcaseFolder = existingFolder
		return existingFolder
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder:SetAttribute("RemakeGarageShowcase", true)
	folder.Parent = workspace
	showcaseFolder = folder
	return folder
end

local function get_asset(itemName: string): Model?
	local assets = get_livery_assets()
	if not assets then
		return nil
	end

	local asset = assets:FindFirstChild(itemName, true)
	return if asset and asset:IsA("Model") then asset else nil
end

local function get_equipped_item_name(): string?
	local equipped = dataUtility.client.get("Inventory.Equipped.Livery")
	if type(equipped) == "string" and get_asset(equipped) then
		return equipped
	end
	return nil
end

local function prepare_model(model: Model): ()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
end

local function get_wheel_center(model: Model, wheelNames: { string }): Vector3?
	local wheels = model:FindFirstChild("Wheels", true)
	if not wheels then
		return nil
	end

	local total = Vector3.zero
	local count = 0
	for _, wheelName in wheelNames do
		local wheel = wheels:FindFirstChild(wheelName, true)
		if wheel and wheel:IsA("BasePart") then
			total += wheel.Position
			count += 1
		end
	end

	return if count > 0 then total / count else nil
end

local function get_vehicle_axes(model: Model): (Vector3, Vector3?)
	local frontCenter = get_wheel_center(model, { "FL", "FR", "WheelSuspension_FL", "WheelSuspension_FR" })
	local rearCenter = get_wheel_center(model, { "RL", "RR", "WheelSuspension_BL", "WheelSuspension_BR" })
	if frontCenter and rearCenter then
		local forward = frontCenter - rearCenter
		if forward.Magnitude > 0.01 then
			return forward.Unit, (frontCenter + rearCenter) / 2
		end
	end

	return -model:GetPivot().LookVector, model:GetPivot().Position
end

local function align_model_to_slot(model: Model, slot: BasePart): ()
	local sourceForward, sourceCenter = get_vehicle_axes(model)
	local targetForward = slot.CFrame.LookVector
	local sourceRotation = CFrame.lookAt(Vector3.zero, sourceForward, Vector3.yAxis)
	local targetRotation = CFrame.lookAt(Vector3.zero, targetForward, Vector3.yAxis)
	local rotationDelta = targetRotation * sourceRotation:Inverse()
	local currentPivot = model:GetPivot()
	model:PivotTo(CFrame.new(slot.Position) * rotationDelta * CFrame.new(-sourceCenter) * currentPivot)

	local _, originalSize = model:GetBoundingBox()
	local longitudinalSize = math.max(originalSize.X, originalSize.Z)
	local lateralSize = math.min(originalSize.X, originalSize.Z)
	local scale = math.min(
		TARGET_LENGTH / math.max(longitudinalSize, 0.01),
		TARGET_WIDTH / math.max(lateralSize, 0.01),
		TARGET_HEIGHT / math.max(originalSize.Y, 0.01)
	)
	if scale > 0 and math.abs(scale - 1) > 0.01 then
		model:ScaleTo(scale)
	end

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local bottom = boundsCFrame.Position.Y - boundsSize.Y / 2
	local offset = Vector3.new(slot.Position.X - boundsCFrame.Position.X, slot.Position.Y - bottom, slot.Position.Z - boundsCFrame.Position.Z)
	model:PivotTo(model:GetPivot() + offset)
end

local function clear_showcase(): ()
	if not showcaseFolder then
		return
	end

	for _, child in showcaseFolder:GetChildren() do
		child:Destroy()
	end
end

local function get_unique_item_names(): { string }
	local owned = dataUtility.client.get("Inventory.Owned.Livery")
	local equipped = get_equipped_item_name()
	local names: { string } = {}
	local seen: { [string]: boolean } = {}

	if type(equipped) == "string" then
		table.insert(names, equipped)
		seen[equipped] = true
	end
	if type(owned) == "table" then
		for _, itemName in owned do
			if type(itemName) == "string" and not seen[itemName] then
				table.insert(names, itemName)
				seen[itemName] = true
			end
		end
	end

	if #names == 0 and get_asset("Default") then
		table.insert(names, "Default")
	end
	return names
end

local function build_showcase(): ()
	ensure_layout()
	clear_showcase()
	itemNames = get_unique_item_names()
	equippedItemName = get_equipped_item_name()
	local folder = get_showcase_folder()

	for index, itemName in itemNames do
		local slotInfo = slotInfos[index]
		local source = get_asset(itemName)
		if slotInfo and source then
			local model = source:Clone()
			model.Name = itemName
			model:SetAttribute("RemakeGarageItem", itemName)
			model:SetAttribute("RemakeGarageSlot", index)
			model:SetAttribute("RemakeGarageEquipped", itemName == equippedItemName)
			prepare_model(model)
			model.Parent = folder
			align_model_to_slot(model, slotInfo.part)
		end
	end

	folder:SetAttribute("RemakeGarageItemCount", #itemNames)
end

local function get_showcase_pair(): (Model?, SlotInfo?)
	if not showcaseFolder or not showcaseFolder.Parent then
		return nil, nil
	end

	local fallbackModel: Model?
	local fallbackSlot: SlotInfo?
	for _, child in showcaseFolder:GetChildren() do
		local slotIndex = child:GetAttribute("RemakeGarageSlot")
		if child:IsA("Model") and type(slotIndex) == "number" then
			local slotInfo = slotInfos[slotIndex]
			if slotInfo then
				fallbackModel = fallbackModel or child
				fallbackSlot = fallbackSlot or slotInfo
				if child:GetAttribute("RemakeGarageEquipped") == true then
					return child, slotInfo
				end
			end
		end
	end

	return fallbackModel, fallbackSlot
end

local function get_model_camera_target(model: Model, slotInfo: SlotInfo): CFrame?
	local boundsCFrame = model:GetBoundingBox()
	local cameraOffset = boundsCFrame.Position - slotInfo.part.Position
	local cameraPosition = slotInfo.camera.Position + cameraOffset
	return CFrame.lookAt(cameraPosition, boundsCFrame.Position, Vector3.yAxis)
end

------------------//MAIN FUNCTIONS
local function car_showcase_activate(player: Player): ()
	localPlayer = player
	isActive = true
	build_showcase()
end

local function car_showcase_refresh(): ()
	if isActive then
		build_showcase()
	end
end

local function car_showcase_deactivate(): ()
	isActive = false
	clear_showcase()
	if showcaseFolder then
		showcaseFolder:Destroy()
		showcaseFolder = nil
	end
	itemNames = {}
	equippedItemName = nil
end

local function car_showcase_get_camera_target(): CFrame?
	if #slotInfos == 0 then
		ensure_layout()
	end
	local firstSlot = slotInfos[1]
	local firstModel, modelSlot = get_showcase_pair()
	if firstModel and modelSlot then
		local modelTarget = get_model_camera_target(firstModel, modelSlot)
		if modelTarget then
			return modelTarget
		end
	end

	return if firstSlot then firstSlot.camera.CFrame else cameraAnchors[1] and cameraAnchors[1].CFrame
end

------------------//INIT
return {
	activate = car_showcase_activate,
	refresh = car_showcase_refresh,
	deactivate = car_showcase_deactivate,
	get_camera_target = car_showcase_get_camera_target,
}
