------------------//SERVICES
local Players: Players = game:GetService("Players")
local PhysicsService: PhysicsService = game:GetService("PhysicsService")

------------------//CONSTANTS
local CHARACTERS_FOLDER_NAME: string = "Characters"
local PLAYER_COLLISION_GROUP: string = "Players"

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

------------------//MAIN FUNCTIONS
local function on_character_added(character: Model): ()
	character.Parent = ensure_characters_folder()

	for _, descendant in character:GetDescendants() do
		set_player_collision_group(descendant)
	end
	character.DescendantAdded:Connect(set_player_collision_group)
end

local function on_player_added(player: Player): ()
	player.CharacterAdded:Connect(on_character_added)
	if player.Character then
		on_character_added(player.Character)
	end
end

------------------//INIT
ensure_player_collision_group()
ensure_characters_folder()

for _, player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)
