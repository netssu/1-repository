------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local INVENTORY_ASSETS_NAME: string = "InventoryAssets"
local ITEMS_FOLDER_NAME: string = "Items"
local RENDERED_VISUAL_NAME: string = "InventoryVisual"
local VEHICLE_CATEGORY: string = "Livery"
local SUIT_CATEGORY: string = "Suit"
local HELMET_CATEGORY: string = "Helmets"
local DEFAULT_CAMERA_FOV: number = 40
local VEHICLE_VIEWPORT_REFERENCE_SIZE: number = 16
local HELMET_VIEWPORT_REFERENCE_SIZE: number = 2
local VEHICLE_CAMERA_DIRECTION: Vector3 = Vector3.new(0.9, 0.28, 0.65).Unit
local CHARACTER_CAMERA_DIRECTION: Vector3 = Vector3.new(0, 0, 1)
local CAMERA_DISTANCE_PADDING: number = 0.95
local MIN_CAMERA_DISTANCE_MULTIPLIER: number = 0.7
local MIN_VECTOR_MAGNITUDE: number = 0.001
local REFERENCE_STORAGE_NAME: string = "_ViewportReferences"
local HELMET_REFERENCE_NAME: string = "Helmets"
local HELMET_POSITION_OFFSET: CFrame = CFrame.new(0, 0.35, 0)
local HELMET_WORLD_ROTATION: CFrame = CFrame.Angles(0, math.rad(180), 0)
local JAY_HELMET_NAME: string = "Jay"
local JAY_CAMERA_DISTANCE: number = 3
local HELMET_VIEWPORT_TARGET_FRAME: CFrame = CFrame.fromMatrix(
	Vector3.zero,
	Vector3.xAxis,
	Vector3.yAxis,
	-Vector3.zAxis
)
local REFERENCE_NAMES: { string } = { "Car", "Helmets", "Rig" }
local BOUNDS_CORNERS: { Vector3 } = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, -1, 1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, -1, 1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
}
local TARGET_VEHICLE_FRAME: CFrame = CFrame.fromMatrix(
	Vector3.zero,
	Vector3.new(1, 0, 0),
	Vector3.new(0, 1, 0),
	Vector3.new(0, 0, -1)
)
local ASSET_NAME_ALIASES: { [string]: { [string]: string } } = {
	Suit = {
		["Citroen Racing"] = "Citroën Racing",
		["Porche Motorsport"] = "Porsche Motorsport",
	},
}

------------------//VARIABLES
local inventoryAssets: Folder?

export type PageConfig = {
	category: string,
	assetFolderNames: { string },
}

------------------//FUNCTIONS
local function get_inventory_assets(): Folder?
	if inventoryAssets and inventoryAssets.Parent then
		return inventoryAssets
	end

	local assets = ReplicatedStorage:FindFirstChild(INVENTORY_ASSETS_NAME)
	if assets and assets:IsA("Folder") then
		inventoryAssets = assets
		return assets
	end

	warn("[InventoryAssetRenderer] ReplicatedStorage.InventoryAssets not found")
	return nil
end

local function normalize_name(name: string): string
	return string.lower(string.gsub(name, "[%W_]", ""))
end

local function get_asset_folder(pageConfig: PageConfig): Folder?
	local assets = get_inventory_assets()
	local items = assets and assets:FindFirstChild(ITEMS_FOLDER_NAME)
	if not items then
		return nil
	end

	for _, folderName in pageConfig.assetFolderNames do
		local folder = items:FindFirstChild(folderName)
		if folder and folder:IsA("Folder") then
			return folder
		end
	end

	return nil
end

local function get_asset(pageConfig: PageConfig, itemName: string): Instance?
	local folder = get_asset_folder(pageConfig)
	if not folder then
		return nil
	end

	local asset = folder:FindFirstChild(itemName)
	if asset then
		return asset
	end

	local aliases = ASSET_NAME_ALIASES[pageConfig.category]
	local aliasName = aliases and aliases[itemName]
	if aliasName then
		asset = folder:FindFirstChild(aliasName)
		if asset then
			return asset
		end
	end

	local normalizedItemName = normalize_name(itemName)
	for _, child in folder:GetChildren() do
		if normalize_name(child.Name) == normalizedItemName then
			return child
		end
	end

	return nil
end

local function get_reference_storage(viewport: ViewportFrame): Folder?
	local parent = viewport.Parent
	if not parent then
		return nil
	end

	local storage = parent:FindFirstChild(REFERENCE_STORAGE_NAME)
	if storage and storage:IsA("Folder") then
		return storage
	end

	local newStorage = Instance.new("Folder")
	newStorage.Name = REFERENCE_STORAGE_NAME
	newStorage.Parent = parent
	return newStorage
end

local function move_viewport_references_to_storage(viewport: ViewportFrame): ()
	local storage = get_reference_storage(viewport)
	if not storage then
		return
	end

	for _, referenceName in REFERENCE_NAMES do
		local reference = viewport:FindFirstChild(referenceName)
		if reference then
			if storage:FindFirstChild(referenceName) then
				reference:Destroy()
			else
				reference.Parent = storage
			end
		end
	end
end

local function get_viewport_reference(viewport: ViewportFrame, referenceName: string): Instance?
	local storage = get_reference_storage(viewport)
	local reference = storage and storage:FindFirstChild(referenceName)
	return reference or viewport:FindFirstChild(referenceName)
end

local function remove_scripts(root: Instance): ()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
end

local function get_world_position(instanceToRead: Instance): Vector3?
	if instanceToRead:IsA("BasePart") then
		return instanceToRead.Position
	end

	for _, descendant in instanceToRead:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant.Position
		end
	end

	if instanceToRead:IsA("Model") then
		return instanceToRead:GetPivot().Position
	end

	return nil
end

local function get_wheel_frame(root: Model): CFrame?
	local wheels = root:FindFirstChild("Wheels", true)
	if not wheels then
		return nil
	end

	local frontLeft = wheels:FindFirstChild("FL")
	local frontRight = wheels:FindFirstChild("FR")
	local rearLeft = wheels:FindFirstChild("RL")
	local rearRight = wheels:FindFirstChild("RR")
	if not frontLeft or not frontRight or not rearLeft or not rearRight then
		return nil
	end

	local frontLeftPosition = get_world_position(frontLeft)
	local frontRightPosition = get_world_position(frontRight)
	local rearLeftPosition = get_world_position(rearLeft)
	local rearRightPosition = get_world_position(rearRight)
	if not frontLeftPosition or not frontRightPosition or not rearLeftPosition or not rearRightPosition then
		return nil
	end

	local frontCenter = (frontLeftPosition + frontRightPosition) * 0.5
	local rearCenter = (rearLeftPosition + rearRightPosition) * 0.5
	local leftCenter = (frontLeftPosition + rearLeftPosition) * 0.5
	local rightCenter = (frontRightPosition + rearRightPosition) * 0.5
	local forwardRaw = frontCenter - rearCenter
	local rightRaw = rightCenter - leftCenter
	if forwardRaw.Magnitude <= MIN_VECTOR_MAGNITUDE or rightRaw.Magnitude <= MIN_VECTOR_MAGNITUDE then
		return nil
	end

	forwardRaw = forwardRaw.Unit
	rightRaw = rightRaw.Unit
	local right = rightRaw - forwardRaw * rightRaw:Dot(forwardRaw)
	if right.Magnitude <= MIN_VECTOR_MAGNITUDE then
		return nil
	end

	right = right.Unit
	local up = right:Cross(forwardRaw)
	if up.Magnitude <= MIN_VECTOR_MAGNITUDE then
		return nil
	end

	up = up.Unit
	if up.Y < 0 then
		right = -right
		up = right:Cross(forwardRaw).Unit
	end

	local forward = up:Cross(right)
	if forward.Magnitude <= MIN_VECTOR_MAGNITUDE then
		return nil
	end

	forward = forward.Unit
	if forward:Dot(forwardRaw) < 0 then
		forward = -forward
		right = -right
	end

	return CFrame.fromMatrix((frontCenter + rearCenter) * 0.5, right, up, -forward)
end

local function apply_viewport_delta(root: Model, delta: CFrame): ()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CFrame = delta * descendant.CFrame
		end
	end
end

local function align_model_to_helmet_frame(root: Model): ()
	local middle = root:FindFirstChild("Middle", true)
	if not middle or not middle:IsA("BasePart") then
		return
	end

	local targetFrame = CFrame.new(middle.Position) * HELMET_VIEWPORT_TARGET_FRAME
	apply_viewport_delta(root, targetFrame * middle.CFrame:Inverse())
end

local function normalize_vehicle(root: Model): ()
	local currentFrame = get_wheel_frame(root)
	local sourceFrame = currentFrame or root:GetPivot()
	apply_viewport_delta(root, TARGET_VEHICLE_FRAME * sourceFrame:Inverse())
end

local function get_visual_bounds(root: Model): (CFrame?, Vector3?)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local hasVisiblePart = false

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Transparency < 0.98 then
			hasVisiblePart = true
			local halfSize = descendant.Size * 0.5
			for _, cornerScale in BOUNDS_CORNERS do
				local corner = descendant.CFrame:PointToWorldSpace(Vector3.new(
					halfSize.X * cornerScale.X,
					halfSize.Y * cornerScale.Y,
					halfSize.Z * cornerScale.Z
				))
				minimum = minimum:Min(corner)
				maximum = maximum:Max(corner)
			end
		end
	end

	if not hasVisiblePart then
		return nil
	end

	local size = maximum - minimum
	return CFrame.new((minimum + maximum) * 0.5), size
end

local function apply_world_rotation(root: Model, rotation: CFrame): ()
	local boundsCFrame = get_visual_bounds(root)
	if not boundsCFrame then
		return
	end

	local center = boundsCFrame.Position
	apply_viewport_delta(root, CFrame.new(center) * rotation * CFrame.new(-center))
end

local function get_bounds_corners(boundsCFrame: CFrame, boundsSize: Vector3): { Vector3 }
	local halfSize = boundsSize * 0.5
	local corners: { Vector3 } = {}
	for _, cornerScale in BOUNDS_CORNERS do
		table.insert(corners, boundsCFrame:PointToWorldSpace(Vector3.new(
			halfSize.X * cornerScale.X,
			halfSize.Y * cornerScale.Y,
			halfSize.Z * cornerScale.Z
		)))
	end
	return corners
end

local function scale_model_to_reference(root: Model, referenceSize: number): ()
	local _, boundsSize = get_visual_bounds(root)
	if not boundsSize then
		return
	end

	local maximumDimension = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
	if maximumDimension <= MIN_VECTOR_MAGNITUDE then
		return
	end

	local scaleFactor = referenceSize / maximumDimension
	if math.abs(scaleFactor - 1) > MIN_VECTOR_MAGNITUDE then
		root:ScaleTo(scaleFactor)
	end
end

local function get_camera_distance(
	viewport: ViewportFrame,
	boundsCFrame: CFrame,
	boundsSize: Vector3,
	focus: Vector3,
	cameraDirection: Vector3
): number
	local viewportSize = viewport.AbsoluteSize
	local aspectRatio = if viewportSize.Y > 0 then viewportSize.X / viewportSize.Y else 1
	local halfVerticalFov = math.rad(DEFAULT_CAMERA_FOV * 0.5)
	local halfHorizontalFov = math.atan(math.tan(halfVerticalFov) * aspectRatio)
	local verticalTangent = math.tan(halfVerticalFov)
	local horizontalTangent = math.tan(halfHorizontalFov)
	local cameraBasis = CFrame.lookAt(Vector3.zero, -cameraDirection)
	local maximumRequiredDistance = 0

	for _, corner in get_bounds_corners(boundsCFrame, boundsSize) do
		local offset = corner - focus
		local depth = cameraDirection:Dot(offset)
		local verticalDistance = depth + math.abs(cameraBasis.UpVector:Dot(offset)) / verticalTangent
		local horizontalDistance = depth + math.abs(cameraBasis.RightVector:Dot(offset)) / horizontalTangent
		maximumRequiredDistance = math.max(maximumRequiredDistance, verticalDistance, horizontalDistance)
	end

	local maximumDimension = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
	return math.max(
		maximumRequiredDistance * CAMERA_DISTANCE_PADDING,
		maximumDimension * MIN_CAMERA_DISTANCE_MULTIPLIER
	)
end

local function create_viewport_camera(
	viewport: ViewportFrame,
	root: Model,
	shouldCenterToBounds: boolean,
	cameraDirectionOverride: Vector3?,
	cameraDistanceOverride: number?
): ()
	local boundsCFrame, boundsSize = get_visual_bounds(root)
	if not boundsCFrame or not boundsSize then
		boundsCFrame, boundsSize = root:GetBoundingBox()
	end

	local maximumDimension = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z)
	if maximumDimension <= 0 then
		return
	end

	for _, child in viewport:GetChildren() do
		if child:IsA("Camera") then
			child:Destroy()
		end
	end

	if shouldCenterToBounds then
		local centeredPivot = CFrame.new(-boundsCFrame.Position) * root:GetPivot()
		root:PivotTo(centeredPivot)
		boundsCFrame, boundsSize = get_visual_bounds(root)
		if not boundsCFrame or not boundsSize then
			boundsCFrame, boundsSize = root:GetBoundingBox()
		end
	end

	local camera = Instance.new("Camera")
	camera.Name = "InventoryCamera"
	camera.FieldOfView = DEFAULT_CAMERA_FOV
	local focus = boundsCFrame.Position
	local cameraDirection = cameraDirectionOverride
	if not cameraDirection then
		cameraDirection = if shouldCenterToBounds then CHARACTER_CAMERA_DIRECTION else VEHICLE_CAMERA_DIRECTION
	end
	local distance = cameraDistanceOverride or get_camera_distance(viewport, boundsCFrame, boundsSize, focus, cameraDirection)
	camera.CFrame = CFrame.lookAt(focus + cameraDirection * distance, focus)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function clear_viewport(viewport: ViewportFrame): ()
	viewport.CurrentCamera = nil
	for _, child in viewport:GetChildren() do
		if child:IsA("Camera") or child.Name == RENDERED_VISUAL_NAME then
			child:Destroy()
		end
	end
end

local function render_suit(viewport: ViewportFrame, asset: Instance): boolean
	local rig = viewport:FindFirstChild("Rig")
	if not rig or not rig:IsA("Model") then
		return false
	end

	for _, child in rig:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end

	for _, child in asset:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Clone().Parent = rig
		end
	end

	create_viewport_camera(viewport, rig, true)
	return true
end

local function configure_model_viewport(viewport: ViewportFrame, model: Model, pageConfig: PageConfig, itemName: string?): ()
	if pageConfig.category == HELMET_CATEGORY then
		local reference = get_viewport_reference(viewport, HELMET_REFERENCE_NAME)
		local referencePivot = if reference and reference:IsA("Model") then reference:GetPivot() else CFrame.new()
		local targetPivot = referencePivot * HELMET_POSITION_OFFSET
		apply_viewport_delta(model, targetPivot * model:GetPivot():Inverse())
		scale_model_to_reference(model, HELMET_VIEWPORT_REFERENCE_SIZE)
		apply_world_rotation(model, HELMET_WORLD_ROTATION)
		if itemName == JAY_HELMET_NAME then
			align_model_to_helmet_frame(model)
		end
		local boundsCFrame = get_visual_bounds(model)
		if boundsCFrame then
			apply_viewport_delta(model, CFrame.new(targetPivot.Position - boundsCFrame.Position))
		end
		local cameraDistanceOverride = if itemName == JAY_HELMET_NAME then JAY_CAMERA_DISTANCE else nil
		create_viewport_camera(viewport, model, false, CHARACTER_CAMERA_DIRECTION, cameraDistanceOverride)
		return
	end

	local isVehicle = pageConfig.category == VEHICLE_CATEGORY
	if isVehicle then
		normalize_vehicle(model)
		scale_model_to_reference(model, VEHICLE_VIEWPORT_REFERENCE_SIZE)
		normalize_vehicle(model)
	end

	create_viewport_camera(viewport, model, not isVehicle)
end

local function render_model(viewport: ViewportFrame, asset: Instance, pageConfig: PageConfig, itemName: string): boolean
	local clone = asset:Clone()
	remove_scripts(clone)
	if clone:IsA("Folder") then
		local model = Instance.new("Model")
		model.Name = RENDERED_VISUAL_NAME
		model.Parent = viewport
		for _, child in clone:GetChildren() do
			child.Parent = model
		end
		clone:Destroy()
		configure_model_viewport(viewport, model, pageConfig, itemName)
		return true
	end

	if clone:IsA("Model") then
		clone.Name = RENDERED_VISUAL_NAME
		clone.Parent = viewport
		configure_model_viewport(viewport, clone, pageConfig, itemName)
		return true
	end

	clone:Destroy()
	return false
end

local function render_existing_viewport(viewport: ViewportFrame, pageConfig: PageConfig, itemName: string): boolean
	local model = viewport:FindFirstChildWhichIsA("Model")
	if not model then
		return false
	end

	configure_model_viewport(viewport, model, pageConfig, itemName)
	return true
end

------------------//MAIN FUNCTIONS
local inventoryAssetRenderer = {}

function inventoryAssetRenderer.render(viewport: ViewportFrame, pageConfig: PageConfig, itemName: string): boolean
	local asset = get_asset(pageConfig, itemName)
	if pageConfig.category ~= SUIT_CATEGORY and asset then
		move_viewport_references_to_storage(viewport)
		clear_viewport(viewport)
	end

	if asset then
		local rendered = if pageConfig.category == SUIT_CATEGORY
			then render_suit(viewport, asset)
			else render_model(viewport, asset, pageConfig, itemName)
		if rendered then
			return true
		end
	end

	return render_existing_viewport(viewport, pageConfig, itemName)
end

------------------//INIT
return inventoryAssetRenderer
