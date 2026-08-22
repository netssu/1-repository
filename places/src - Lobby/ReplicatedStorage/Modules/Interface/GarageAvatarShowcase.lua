------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local TERRAIN_NAME: string = "Terrain"
local GARAGE_NAME: string = "Garage"
local RIG_NAME: string = "Rig"
local ITEMS_FOLDER_NAME: string = "Items"
local SUITS_FOLDER_NAME: string = "Suits"
local HELMETS_FOLDER_NAME: string = "Helmets"
local CUSTOM_HELMET_NAME: string = "CustomizationHelmet"
local FACE_DECAL_NAME: string = "face"
local DEFAULT_HELMET_NAME: string = "Default"
local HELMET_HEIGHT_OFFSET: number = 0.05
local NEW_HELMET_ORIENTATION: CFrame = CFrame.fromOrientation(0, math.rad(90), 0)
local NEW_HELMET_NAMES: { [string]: boolean } = {
	["Livery Winner"] = true,
	["Mecha Pilot"] = true,
	Kyubiko = true,
	Kurobushi = true,
	Sakura = true,
}

------------------//DEPENDENCIES
local dataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("DataUtility"))

------------------//VARIABLES
local activeRig: Model?
local isActive: boolean = false
local activeSuitName: string?
local activeHelmetName: string?
local localPlayer: Player?
local characterAppearanceConnection: RBXScriptConnection?
local originalBodyColors: BodyColors?
local originalFace: Decal?
local originalPartColors: { [string]: Color3 } = {}

local BODY_PART_NAMES: { string } = {
	"Head",
	"Torso",
	"Right Arm",
	"Left Arm",
	"Right Leg",
	"Left Leg",
}

------------------//FUNCTIONS
local function get_rig(): Model?
	local terrain = workspace:FindFirstChild(TERRAIN_NAME)
	local garage = terrain and terrain:FindFirstChild(GARAGE_NAME)
	local rig = garage and garage:FindFirstChild(RIG_NAME)
	return if rig and rig:IsA("Model") then rig else nil
end

local function get_player_character(): Model?
	local character = localPlayer and localPlayer.Character
	return if character and character:IsA("Model") then character else nil
end

local function get_character_description(character: Model?): HumanoidDescription?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local success, description = pcall(function(): HumanoidDescription
		return humanoid:GetAppliedDescription()
	end)
	return if success then description else nil
end

local function get_items_folder(): Folder?
	local inventoryAssets = ReplicatedStorage:FindFirstChild("InventoryAssets")
	local items = inventoryAssets and inventoryAssets:FindFirstChild(ITEMS_FOLDER_NAME)
	return if items and items:IsA("Folder") then items else nil
end

local function get_asset(folderName: string, itemName: string): Instance?
	local items = get_items_folder()
	local folder = items and items:FindFirstChild(folderName)
	if not folder then
		return nil
	end

	local exact = folder:FindFirstChild(itemName)
	if exact then
		return exact
	end

	local normalizedName = string.lower(string.gsub(itemName, "[%W_]", ""))
	for _, child in folder:GetChildren() do
		local normalizedChildName = string.lower(string.gsub(child.Name, "[%W_]", ""))
		if normalizedChildName == normalizedName then
			return child
		end
	end
	return nil
end

local function remove_class(rig: Model, className: string): ()
	for _, descendant in rig:GetDescendants() do
		if descendant.ClassName == className then
			descendant:Destroy()
		end
	end
end

local function clear_rig_wearables(rig: Model): ()
	for _, className in { "Shirt", "Pants", "ShirtGraphic", "CharacterMesh", "Accessory", "Accoutrement", "BodyColors" } do
		remove_class(rig, className)
	end
	local customHelmet = rig:FindFirstChild(CUSTOM_HELMET_NAME)
	if customHelmet then
		customHelmet:Destroy()
	end

	local head = rig:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		for _, child in head:GetChildren() do
			if child:IsA("Decal") then
				child:Destroy()
			end
		end
	end
end

local function capture_original_appearance(rig: Model): ()
	originalBodyColors = nil
	local bodyColors = rig:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		local clone = bodyColors:Clone()
		if clone:IsA("BodyColors") then
			originalBodyColors = clone
		end
	end

	originalFace = nil
	local head = rig:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		for _, child in head:GetChildren() do
			if child:IsA("Decal") then
				local clone = child:Clone()
				if clone:IsA("Decal") then
					originalFace = clone
				end
				break
			end
		end
	end

	table.clear(originalPartColors)
	for _, partName in BODY_PART_NAMES do
		local part = rig:FindFirstChild(partName, true)
		if part and part:IsA("BasePart") then
			originalPartColors[partName] = part.Color
		end
	end
end

local function apply_description_body_colors(rig: Model, description: HumanoidDescription): ()
	local bodyColors = Instance.new("BodyColors")
	bodyColors.Name = "Body Colors"
	bodyColors.HeadColor3 = description.HeadColor
	bodyColors.TorsoColor3 = description.TorsoColor
	bodyColors.LeftArmColor3 = description.LeftArmColor
	bodyColors.RightArmColor3 = description.RightArmColor
	bodyColors.LeftLegColor3 = description.LeftLegColor
	bodyColors.RightLegColor3 = description.RightLegColor
	bodyColors.Parent = rig
end

local function apply_player_body_colors(rig: Model, character: Model?, description: HumanoidDescription?): ()
	local sourceBodyColors = character and character:FindFirstChildOfClass("BodyColors")
	if sourceBodyColors then
		local clone = sourceBodyColors:Clone()
		if clone:IsA("BodyColors") then
			clone.Parent = rig
		end
	elseif description then
		apply_description_body_colors(rig, description)
	end

	for _, partName in BODY_PART_NAMES do
		local sourcePart = character and character:FindFirstChild(partName, true)
		local targetPart = rig:FindFirstChild(partName, true)
		if sourcePart and sourcePart:IsA("BasePart") and targetPart and targetPart:IsA("BasePart") then
			targetPart.Color = sourcePart.Color
		end
	end
end

local function get_face_texture(character: Model?, description: HumanoidDescription?): string?
	local head = character and character:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		for _, child in head:GetChildren() do
			if child:IsA("Decal") and child.Face == Enum.NormalId.Front and child.Texture ~= "" then
				return child.Texture
			end
		end
	end

	if not description then
		return nil
	end

	local faceId = description.Face
	if type(faceId) == "number" then
		return if faceId > 0 then "rbxassetid://" .. tostring(faceId) else nil
	end
	if type(faceId) ~= "string" or faceId == "" then
		return nil
	end

	return if string.find(faceId, "rbxassetid://", 1, true)
		then faceId
		else "rbxassetid://" .. faceId
end

local function apply_player_face(rig: Model, character: Model?, description: HumanoidDescription?): ()
	local targetHead = rig:FindFirstChild("Head", true)
	if not targetHead or not targetHead:IsA("BasePart") then
		return
	end

	local sourceHead = character and character:FindFirstChild("Head", true)
	local sourceFace = sourceHead and sourceHead:FindFirstChild(FACE_DECAL_NAME)
	if sourceFace and sourceFace:IsA("Decal") then
		sourceFace:Clone().Parent = targetHead
		return
	end

	local faceTexture = get_face_texture(character, description)
	if not faceTexture then
		return
	end

	local face = Instance.new("Decal")
	face.Name = FACE_DECAL_NAME
	face.Face = Enum.NormalId.Front
	face.Texture = faceTexture
	face.Parent = targetHead
end

local function clone_wearable(source: Instance, rig: Model, removedClasses: { [string]: boolean }): boolean
	local isWearable = source:IsA("Shirt")
		or source:IsA("Pants")
		or source:IsA("ShirtGraphic")
		or source:IsA("BodyColors")
		or source:IsA("CharacterMesh")
	if not isWearable then
		return false
	end

	if not removedClasses[source.ClassName] then
		remove_class(rig, source.ClassName)
		removedClasses[source.ClassName] = true
	end

	source:Clone().Parent = rig
	return true
end

local function apply_suit(rig: Model, suitName: string?): boolean
	if not suitName then
		return false
	end

	local source = get_asset(SUITS_FOLDER_NAME, suitName)
	if not source then
		return false
	end

	local applied = false
	local removedClasses: { [string]: boolean } = {}
	applied = clone_wearable(source, rig, removedClasses) or applied
	for _, descendant in source:GetDescendants() do
		applied = clone_wearable(descendant, rig, removedClasses) or applied
	end
	return applied
end

local function clear_helmet_joints(root: Instance): ()
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Weld") or descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
			descendant:Destroy()
		end
	end
end

local function prepare_helmet(clone: Instance): ()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function weld_helmet_to_head(clone: Instance, head: BasePart): ()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

local function apply_helmet(rig: Model, helmetName: string?): boolean
	if not helmetName or helmetName == DEFAULT_HELMET_NAME then
		return false
	end

	local source = get_asset(HELMETS_FOLDER_NAME, helmetName)
	local head = rig:FindFirstChild("Head", true)
	if not source or not head or not head:IsA("BasePart") then
		return false
	end

	local clone = source:Clone()
	clone.Name = CUSTOM_HELMET_NAME
	prepare_helmet(clone)
	clear_helmet_joints(clone)

	local middle = clone:FindFirstChild("Middle", true)
	if middle and middle:IsA("BasePart") then
		local targetMiddle = head.CFrame * CFrame.new(0, HELMET_HEIGHT_OFFSET, 0)
		local targetPivot = targetMiddle * middle.CFrame:ToObjectSpace(clone:GetPivot())
		clone:PivotTo(targetPivot)
	else
		clone:PivotTo(head.CFrame * CFrame.new(0, HELMET_HEIGHT_OFFSET, 0))
	end

	if NEW_HELMET_NAMES[helmetName] then
		local currentPivot = clone:GetPivot()
		clone:PivotTo(CFrame.new(currentPivot.Position) * NEW_HELMET_ORIENTATION)
	end

	clone.Parent = rig
	weld_helmet_to_head(clone, head)
	return true
end

local function apply_equipped_items(rig: Model): ()
	clear_rig_wearables(rig)
	local character = get_player_character()
	local description = get_character_description(character)
	apply_player_body_colors(rig, character, description)
	apply_player_face(rig, character, description)
	activeSuitName = dataUtility.client.get("Inventory.Equipped.Suit")
	activeHelmetName = dataUtility.client.get("Inventory.Equipped.Helmets")
	if type(activeSuitName) ~= "string" then
		activeSuitName = nil
	end
	if type(activeHelmetName) ~= "string" then
		activeHelmetName = nil
	end

	apply_suit(rig, activeSuitName)
	apply_helmet(rig, activeHelmetName)
	rig:SetAttribute("RemakeGarageSuit", activeSuitName or "")
	rig:SetAttribute("RemakeGarageHelmet", activeHelmetName or "")
	rig:SetAttribute("RemakeGarageHelmetVisible", rig:FindFirstChild(CUSTOM_HELMET_NAME) ~= nil)
end

local function reset_rig(rig: Model): ()
	clear_rig_wearables(rig)
	if originalBodyColors then
		originalBodyColors:Clone().Parent = rig
	end

	local head = rig:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") and originalFace then
		originalFace:Clone().Parent = head
	end

	for _, partName in BODY_PART_NAMES do
		local part = rig:FindFirstChild(partName, true)
		local color = originalPartColors[partName]
		if part and part:IsA("BasePart") and color then
			part.Color = color
		end
	end

	rig:SetAttribute("RemakeGarageSuit", "")
	rig:SetAttribute("RemakeGarageHelmet", "")
	rig:SetAttribute("RemakeGarageHelmetVisible", false)
end

local function disconnect_character_appearance(): ()
	if characterAppearanceConnection then
		characterAppearanceConnection:Disconnect()
		characterAppearanceConnection = nil
	end
end

local function bind_character_appearance(): ()
	disconnect_character_appearance()
	if not localPlayer then
		return
	end

	characterAppearanceConnection = localPlayer.CharacterAppearanceLoaded:Connect(function()
		if isActive and activeRig then
			apply_equipped_items(activeRig)
		end
	end)
end

------------------//MAIN FUNCTIONS
local function avatar_showcase_activate(): ()
	localPlayer = Players.LocalPlayer
	local rig = get_rig()
	if not localPlayer or not rig then
		return
	end

	activeRig = rig
	isActive = true
	capture_original_appearance(rig)
	bind_character_appearance()
	apply_equipped_items(rig)
end

local function avatar_showcase_refresh(): ()
	if isActive and activeRig then
		apply_equipped_items(activeRig)
	end
end

local function avatar_showcase_deactivate(): ()
	isActive = false
	disconnect_character_appearance()
	if activeRig then
		reset_rig(activeRig)
	end
	activeRig = nil
	activeSuitName = nil
	activeHelmetName = nil
	localPlayer = nil
	originalBodyColors = nil
	originalFace = nil
	table.clear(originalPartColors)
end

------------------//INIT
return {
	activate = avatar_showcase_activate,
	refresh = avatar_showcase_refresh,
	deactivate = avatar_showcase_deactivate,
}
