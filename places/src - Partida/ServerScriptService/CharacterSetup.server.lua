------------------//SERVICES
local Players: Players = game:GetService("Players")
local PhysicsService: PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//CONSTANTS
local CHARACTERS_FOLDER_NAME: string = "Characters"
local PLAYER_COLLISION_GROUP: string = "Players"
local SUIT_CATEGORY: string = "Suit"
local HELMET_CATEGORY: string = "Helmets"
local EQUIPPED_HELMET_NAME: string = "EquippedHelmet"
local HELMET_OFFSET_ATTRIBUTE_NAME: string = "HelmetVisualOffsetY"

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local serverModules: Folder = ServerStorage:WaitForChild("Modules")
local inventoryAssetResolver = require(serverModules:WaitForChild("InventoryAssetResolver"))

------------------//VARIABLES
local charactersFolder: Folder

------------------//FUNCTIONS
local function ensure_characters_folder(): Folder
	local existingFolder = workspace:FindFirstChild(CHARACTERS_FOLDER_NAME)
	if existingFolder then
		if not existingFolder:IsA("Folder") then
			error("workspace.Characters precisa ser uma Folder")
		end
		charactersFolder = existingFolder
		return charactersFolder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = CHARACTERS_FOLDER_NAME
	newFolder.Parent = workspace
	charactersFolder = newFolder
	return charactersFolder
end

local function set_player_collision_group(instance: Instance): ()
	if instance:IsA("BasePart") then
		instance.CollisionGroup = PLAYER_COLLISION_GROUP
	end
end

local function ensure_player_collision_group(): ()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYER_COLLISION_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(
		PLAYER_COLLISION_GROUP,
		PLAYER_COLLISION_GROUP,
		false
	)
end

local function remove_head_accessories(character: Model): ()
	for _, descendant in character:GetChildren() do
		if not descendant:IsA("Accessory") then
			continue
		end

		local accessoryType = descendant.AccessoryType
		if accessoryType == Enum.AccessoryType.Hat
			or accessoryType == Enum.AccessoryType.Hair
			or accessoryType == Enum.AccessoryType.Face
			or accessoryType == Enum.AccessoryType.Neck then
			descendant:Destroy()
		end
	end
end

local function apply_suit(character: Model, equippedSuit: any): ()
	local suitTemplate = inventoryAssetResolver.get_item_template(SUIT_CATEGORY, equippedSuit)
	if not suitTemplate then
		return
	end

	for _, child in character:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") then
			child:Destroy()
		end
	end

	for _, child in suitTemplate:GetChildren() do
		if child:IsA("Shirt") or child:IsA("Pants") then
			child:Clone().Parent = character
		end
	end
end

local function prepare_helmet_part(part: BasePart): ()
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CollisionGroup = PLAYER_COLLISION_GROUP
end

local function apply_helmet(character: Model, equippedHelmet: any): ()
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local oldHelmet = character:FindFirstChild(EQUIPPED_HELMET_NAME)
	if oldHelmet then
		oldHelmet:Destroy()
	end

	remove_head_accessories(character)

	local helmet = inventoryAssetResolver.clone_item_template(HELMET_CATEGORY, equippedHelmet)
	if not helmet or not helmet:IsA("Model") then
		return
	end

	helmet.Name = EQUIPPED_HELMET_NAME
	helmet.Parent = character

	local middle = helmet:FindFirstChild("Middle")
	if not middle or not middle:IsA("BasePart") then
		helmet:Destroy()
		return
	end

	local visualOffset = tonumber(helmet:GetAttribute(HELMET_OFFSET_ATTRIBUTE_NAME)) or 0
	local middleOffset = helmet:GetPivot():ToObjectSpace(middle.CFrame)
	helmet:PivotTo(head.CFrame * CFrame.new(0, visualOffset, 0) * middleOffset:Inverse())

	for _, descendant in helmet:GetDescendants() do
		if descendant:IsA("BasePart") then
			prepare_helmet_part(descendant)
			if descendant ~= middle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = middle
				weld.Part1 = descendant
				weld.Parent = middle
			end
		end
	end

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = head
	headWeld.Part1 = middle
	headWeld.Parent = middle
end

local function apply_inventory(character: Model, player: Player): ()
	local equippedSuit = dataUtility.server.get(player, "Inventory.Equipped.Suit")
	local equippedHelmet = dataUtility.server.get(player, "Inventory.Equipped.Helmets")
	apply_suit(character, equippedSuit)
	apply_helmet(character, equippedHelmet)
end

------------------//MAIN FUNCTIONS
local function on_character_added(player: Player, character: Model): ()
	character.Parent = ensure_characters_folder()

	for _, descendant in character:GetDescendants() do
		set_player_collision_group(descendant)
	end
	character.DescendantAdded:Connect(set_player_collision_group)

	task.spawn(apply_inventory, character, player)
end

local function on_player_added(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model)
		on_character_added(player, character)
	end)
	if player.Character then
		on_character_added(player, player.Character)
	end
end

------------------//INIT
ensure_player_collision_group()
ensure_characters_folder()

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
