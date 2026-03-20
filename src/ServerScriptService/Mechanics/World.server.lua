------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//CONSTANTS
local DATA_UTILITY = require(ReplicatedStorage.Modules.Utility.DataUtility)
local WORLD_CONFIG = require(ReplicatedStorage.Modules.Datas.WorldConfig)
local POGO_DATA = require(ReplicatedStorage.Modules.Datas.PogoData) 

------------------//VARIABLES
local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local teleportRemote = remotesFolder:FindFirstChild("TeleportRemote")
local portalsFolder = workspace:WaitForChild("Portals")

local debounce = {}

------------------//FUNCTIONS (Core Teleport)
local function teleport_player(player: Player, worldData: any)
	local character = player.Character
	if not character then return end

	DATA_UTILITY.server.set(player, "PogoSettings.gravity_mult", worldData.gravityMult)
	character:PivotTo(worldData.entryCFrame)
	local maxUnlocked = DATA_UTILITY.server.get(player, "MaxWorldUnlocked") or 1

	if worldData.id > maxUnlocked then
		DATA_UTILITY.server.set(player, "MaxWorldUnlocked", worldData.id)
		print("[DEBUG-PORTAL] Novo mundo máximo desbloqueado para", player.Name, "-> Mundo", worldData.id)
	end
end

------------------//FUNCTIONS (Portals & Billboard)
local function get_required_pogo_name(requiredPower)
	local sortedPogos = POGO_DATA.GetSortedList()

	for _, pogo in ipairs(sortedPogos) do
		if pogo.Power >= requiredPower then
			return pogo.Name
		end
	end
	return "Unknown Pogo"
end

local function create_billboard(portalPart, worldData)
	local existing = portalPart:FindFirstChild("PortalBillboard")
	if existing then existing:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PortalBillboard"
	billboard.Size = UDim2.new(6, 0, 3, 0)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Parent = portalPart

	local label = Instance.new("TextLabel")
	label.Name = "Info"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.RichText = true

	local requiredPogo = get_required_pogo_name(worldData.requiredPogoPower)

	local text = worldData.name .. "\n⚡ Require: " .. requiredPogo
	if worldData.requiredRebirths > 0 then
		text = text .. "\n🔁 " .. worldData.requiredRebirths .. " Rebirth(s)"
	end

	label.Text = text
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = label
end

local function setup_portal(portalPart)
	local worldId = tonumber(portalPart.Name)
	if not worldId then return end

	local worldData = WORLD_CONFIG.GetWorld(worldId)
	if not worldData then return end

	create_billboard(portalPart, worldData)

	portalPart.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end

		if debounce[player.UserId] then return end
		debounce[player.UserId] = true

		print("=================================")
		print("[DEBUG-PORTAL] Jogador:", player.Name, "encostou no portal:", worldId)

		local rebirths = DATA_UTILITY.server.get(player, "Rebirths") or 0
		local pogoPower = DATA_UTILITY.server.get(player, "PogoSettings.base_jump_power") or 0

		print("[DEBUG-PORTAL] Status do Jogador -> Rebirths:", rebirths, "| Power:", pogoPower)
		print("[DEBUG-PORTAL] Requisitos Portal -> Rebirths:", worldData.requiredRebirths, "| Power:", worldData.requiredPogoPower)

		if rebirths < worldData.requiredRebirths then
			print("[DEBUG-PORTAL] ❌ Bloqueado! Faltam rebirths.")
			task.delay(1, function() debounce[player.UserId] = nil end)
			return
		end

		if pogoPower < worldData.requiredPogoPower then
			print("[DEBUG-PORTAL] ❌ Bloqueado! Falta força do pogo.")
			task.delay(1, function() debounce[player.UserId] = nil end)
			return
		end

		print("[DEBUG-PORTAL] ✅ Sucesso! Teleportando o jogador.")
		print("=================================")

		DATA_UTILITY.server.set(player, "CurrentWorld", worldData.id)
		teleport_player(player, worldData)

		task.delay(2, function()
			debounce[player.UserId] = nil
		end)
	end)
end

------------------//FUNCTIONS (Remotes & Respawns)
local function handle_ui_teleport(player: Player, targetWorldId: number)
	local maxUnlocked = DATA_UTILITY.server.get(player, "MaxWorldUnlocked") or 1
	local targetWorld = WORLD_CONFIG.GetWorld(targetWorldId)

	if not targetWorld then return end

	-- Agora ele verifica se o mundo alvo é menor ou igual ao MÁXIMO desbloqueado
	if targetWorldId <= maxUnlocked then
		DATA_UTILITY.server.set(player, "CurrentWorld", targetWorldId)
		teleport_player(player, targetWorld)
	else
		print("[DEBUG-PORTAL] UI Teleport recusado. Jogador não desbloqueou o Mundo", targetWorldId)
	end
end

local function on_player_added(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)

		local savedWorldId = DATA_UTILITY.server.get(player, "CurrentWorld") or 1
		local worldData = WORLD_CONFIG.GetWorld(savedWorldId)

		teleport_player(player, worldData)

		task.spawn(function()
			local hrp = character:WaitForChild("HumanoidRootPart", 10)
			if not hrp then return end

			while character and character:IsDescendantOf(game) do
				local currentId = DATA_UTILITY.server.get(player, "CurrentWorld") or 1
				local wData = WORLD_CONFIG.GetWorld(currentId)

				local currentY = hrp.Position.Y

				if currentY < -100 then
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.AssemblyAngularVelocity = Vector3.zero
					teleport_player(player, wData)
				end

				task.wait(0.5)
			end
		end)
	end)

	local lastRebirths = DATA_UTILITY.server.get(player, "Rebirths") or 0
	DATA_UTILITY.server.bind(player, "Rebirths", function(newVal)
		if newVal > lastRebirths then
			DATA_UTILITY.server.set(player, "CurrentWorld", 1)
			 DATA_UTILITY.server.set(player, "MaxWorldUnlocked", 1)

			local worldOne = WORLD_CONFIG.GetWorld(1)
			teleport_player(player, worldOne)
		end
		lastRebirths = newVal
	end)
end

------------------//INIT
Players.PlayerAdded:Connect(on_player_added)
Players.PlayerRemoving:Connect(function(player)
	debounce[player.UserId] = nil
end)

if teleportRemote then
	teleportRemote.OnServerEvent:Connect(function(player, targetWorldId)
		handle_ui_teleport(player, targetWorldId)
	end)
end

-- Inicializa os portais físicos
for _, portalPart in ipairs(portalsFolder:GetChildren()) do
	if portalPart:IsA("BasePart") then
		setup_portal(portalPart)
	end
end

portalsFolder.ChildAdded:Connect(function(child)
	if child:IsA("BasePart") then
		task.wait(0.1)
		setup_portal(child)
	end
end)
