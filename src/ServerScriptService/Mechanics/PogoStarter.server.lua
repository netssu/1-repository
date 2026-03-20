------------------// SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------// MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local PogoData = require(ReplicatedStorage.Modules.Datas.PogoData)

------------------// CONSTANTS
local POGO_ASSETS: Folder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pogos") :: Folder
local DEFAULT_POGO_ID: string = "Rustbucket"

------------------// FUNCTIONS
local function equip_pogo(player: Player, character: Model): ()
	local equipped_id: string = DataUtility.server.get(player, "EquippedPogoId") or DEFAULT_POGO_ID

	local pogo_data = PogoData.Get(equipped_id)
	if pogo_data then
		DataUtility.server.set(player, "PogoSettings.base_jump_power", pogo_data.Power)
	end

	local pogo_template: Instance? = POGO_ASSETS:FindFirstChild(equipped_id)

	if not pogo_template then
		warn("[PogoManager] Pogo '" .. tostring(equipped_id) .. "' not found. Using Default.")
		pogo_template = POGO_ASSETS:FindFirstChild(DEFAULT_POGO_ID)
	end

	if not pogo_template then
		warn("[PogoManager] Critical: Default Pogo missing.")
		return
	end

	local existing_pogo: Instance? = character:FindFirstChild("EquippedPogo")
	if existing_pogo then
		existing_pogo:Destroy()
	end

	local pogo_clone: Model = pogo_template:Clone() :: Model
	pogo_clone.Name = "EquippedPogo"

	local control_part: BasePart? = pogo_clone:FindFirstChild("control") :: BasePart
	if not control_part then
		pogo_clone:Destroy()
		warn("[PogoManager] Model '" .. pogo_clone.Name .. "' missing 'control' part.")
		return
	end

	local torso: BasePart? = character:FindFirstChild("Torso") :: BasePart or character:FindFirstChild("UpperTorso") :: BasePart
	if not torso then return end

	for _, part: Instance in pogo_clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			part.CanCollide = false
			part.Anchored = false
		end
	end

	local motor: Motor6D = torso:FindFirstChild("PogoConnector") or Instance.new("Motor6D")
	motor.Name = "PogoConnector"
	motor.Part0 = torso
	motor.Part1 = control_part
	motor.C0 = CFrame.new(-0.015, -2.901, -1.7)

	motor.C1 = control_part.PivotOffset * CFrame.Angles(0,math.rad(90),0)

	motor.Parent = torso

	pogo_clone.Parent = character
end

local function on_player_added(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model)
		task.wait(0.5)
		equip_pogo(player, character)
	end)

	DataUtility.server.bind(player, "EquippedPogoId", function(new_val: any)
		if player.Character then
			equip_pogo(player, player.Character)
		end
	end)
end

------------------// INIT
for _, player: Player in Players:GetPlayers() do
	on_player_added(player)
end

Players.PlayerAdded:Connect(on_player_added)