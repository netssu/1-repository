------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)

------------------//CONSTANTS
local MAX_MULTIPLIER_CAP: number = 20.0

------------------//VARIABLES
local assetsFolder = ReplicatedStorage:FindFirstChild("Assets") or Instance.new("Folder")
assetsFolder.Name = "Assets"
assetsFolder.Parent = ReplicatedStorage

local remotesFolder = assetsFolder:FindFirstChild("Remotes") or Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = assetsFolder

local ringEvent = remotesFolder:FindFirstChild("RingEvent") or Instance.new("RemoteEvent")
ringEvent.Name = "RingEvent"
ringEvent.Parent = remotesFolder

local collectedByPlayer: {[number]: {[Instance]: boolean}} = {}
local ringBonusByPlayer: {[number]: number} = {} 
local pogoStateConns: {[number]: RBXScriptConnection} = {}

------------------//FUNCTIONS
local function ensure_player_table(player: Player): {[Instance]: boolean}
	local t = collectedByPlayer[player.UserId]
	if not t then
		t = {}
		collectedByPlayer[player.UserId] = t
	end
	return t
end

local function reset_player(player: Player): ()
	collectedByPlayer[player.UserId] = {}

	local currentBonus = ringBonusByPlayer[player.UserId] or 0
	local currentMult = player:GetAttribute("Multiplier") or 1

	if currentBonus > 0 then
		local restoredMult = math.max(1, currentMult - currentBonus)
		player:SetAttribute("Multiplier", restoredMult)
	end

	ringBonusByPlayer[player.UserId] = 0
	ringEvent:FireClient(player, "Restore")
end

local function get_ring_value(ring: BasePart): number?
	local raw = tonumber(ring.Name)
	if not raw then
		return nil
	end

	if raw >= 1 then
		return raw / 10
	end

	return raw
end

local function process_collection(player: Player, ring: BasePart): ()
	local pogoState = player:GetAttribute("PogoState")
	if pogoState == "Idle" or pogoState == "Stunned" then
		return
	end

	local ringValue = get_ring_value(ring)
	if not ringValue then
		return
	end

	local collected = ensure_player_table(player)
	if collected[ring] then
		return
	end
	collected[ring] = true

	local ownedUpgrades = DataUtility.server.get(player, "OwnedRebirthUpgrades") or {}
	if table.find(ownedUpgrades, "RingMastery") then
		ringValue = ringValue * 1.5 
	end

	local currentMult = player:GetAttribute("Multiplier") or 1
	local currentBonus = ringBonusByPlayer[player.UserId] or 0

	local potentialMult = currentMult + ringValue

	if potentialMult > MAX_MULTIPLIER_CAP then
		local difference = MAX_MULTIPLIER_CAP - currentMult
		if difference <= 0 then 
			return 
		end
		ringValue = difference
		potentialMult = MAX_MULTIPLIER_CAP
	end

	local newBonus = currentBonus + ringValue

	ringBonusByPlayer[player.UserId] = newBonus
	player:SetAttribute("Multiplier", potentialMult)

	ringEvent:FireClient(player, "Collect", potentialMult, ring, ringValue)
end

local function bind_player(player: Player): ()
	collectedByPlayer[player.UserId] = {}
	ringBonusByPlayer[player.UserId] = 0

	if pogoStateConns[player.UserId] then
		pogoStateConns[player.UserId]:Disconnect()
	end

	pogoStateConns[player.UserId] = player:GetAttributeChangedSignal("PogoState"):Connect(function()
		local pogoState = player:GetAttribute("PogoState")
		if pogoState == "Idle" or pogoState == "Stunned" or pogoState == "Cooldown" then
			reset_player(player)
		end
	end)
end

local function unbind_player(player: Player): ()
	if pogoStateConns[player.UserId] then
		pogoStateConns[player.UserId]:Disconnect()
		pogoStateConns[player.UserId] = nil
	end

	collectedByPlayer[player.UserId] = nil
	ringBonusByPlayer[player.UserId] = nil
end

------------------//INIT
ringEvent.OnServerEvent:Connect(function(player: Player, action: string, payload: any)
	if action == "RequestCollect" then
		local ring = payload
		if ring and typeof(ring) == "Instance" and ring:IsA("BasePart") then
			process_collection(player, ring)
		end
	end
end)

local players = Players:GetPlayers()
for _, p in players do
	bind_player(p)
end

Players.PlayerAdded:Connect(bind_player)
Players.PlayerRemoving:Connect(unbind_player)