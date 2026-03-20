------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local GROUP_ID: number = 659849168
local REWARD_COINS: number = 3000
local COINS_PATH: string = "Coins"

local REMOTE_FOLDER_NAME: string = "ZoneRewardRemotes"
local NOTIFY_REMOTE_NAME: string = "Notify"

local TOUCH_COOLDOWN: number = 5
local NOTIFY_COOLDOWN: number = 5

local CLAIMED_PATH: string = "Rewards.GroupZoneClaimed"

------------------//VARIABLES
local lastTouchAt: {[number]: number} = {}
local lastNotifyAt: {[number]: number} = {}

local modulesFolder: Folder = ReplicatedStorage:WaitForChild("Modules") :: Folder
local dataUtility: any

local remotesFolder: Folder
local notifyRemote: RemoteEvent

local zonesFolder: Instance = workspace:WaitForChild("Zones")
local groupZone: Instance = zonesFolder:WaitForChild("Group")

------------------//FUNCTIONS
local function get_data_utility()
	local utilitysInst: Instance = modulesFolder:WaitForChild("Utility")

	if utilitysInst:IsA("Folder") then
		local mod = utilitysInst:FindFirstChild("DataUtility")
		if mod and mod:IsA("ModuleScript") then
			return require(mod)
		end
	elseif utilitysInst:IsA("ModuleScript") then
		return require(utilitysInst)
	end

	error("DataUtility não encontrado em ReplicatedStorage.Modules.Utilitys")
end

local function ensure_remotes(): ()
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		remotesFolder = existing
	else
		local f = Instance.new("Folder")
		f.Name = REMOTE_FOLDER_NAME
		f.Parent = ReplicatedStorage
		remotesFolder = f
	end

	local re = remotesFolder:FindFirstChild(NOTIFY_REMOTE_NAME)
	if re and re:IsA("RemoteEvent") then
		notifyRemote = re
	else
		local newRe = Instance.new("RemoteEvent")
		newRe.Name = NOTIFY_REMOTE_NAME
		newRe.Parent = remotesFolder
		notifyRemote = newRe
	end
end

local function try_notify(player: Player, payload: any): ()
	local now = os.clock()
	local last = lastNotifyAt[player.UserId]
	if last and (now - last) < NOTIFY_COOLDOWN then
		return
	end

	lastNotifyAt[player.UserId] = now
	notifyRemote:FireClient(player, payload)
end

local function get_player_from_hit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function can_touch(player: Player): boolean
	local now = os.clock()
	local last = lastTouchAt[player.UserId]
	if last and (now - last) < TOUCH_COOLDOWN then
		return false
	end
	lastTouchAt[player.UserId] = now
	return true
end

local function reward_player(player: Player): ()
	if not can_touch(player) then
		return
	end

	if not player:IsInGroup(GROUP_ID) then
		try_notify(player, {
			message = "Like the game and join our group to claim the reward!",
			type = "action",
			duration = 8,
			sound = true,
			title = "GROUP",
			buttonText = "OK"
		})
		return
	end

	local claimed = dataUtility.server.get(player, CLAIMED_PATH)
	if claimed == true then
		try_notify(player, {
			message = "You have already redeemed this reward.",
			type = "neutral",
			duration = 4,
			sound = true,
			title = "REWARD"
		})
		return
	end

	dataUtility.server.set(player, CLAIMED_PATH, true)

	local current = dataUtility.server.get(player, COINS_PATH)
	if type(current) ~= "number" then
		current = 0
	end

	dataUtility.server.set(player, COINS_PATH, current + REWARD_COINS)

	try_notify(player, {
		message = "Congratulations, you have redeemed the group reward!",
		type = "success",
		duration = 4,
		sound = true,
		title = "REWARD"
	})
end

local function get_zone_parts(inst: Instance): {BasePart}
	local out: {BasePart} = {}

	if inst:IsA("BasePart") then
		out[#out + 1] = inst
		return out
	end

	local desc = inst:GetDescendants()
	for _, d in ipairs(desc) do
		if d:IsA("BasePart") then
			out[#out + 1] = d
		end
	end

	return out
end

local function connect_part(part: BasePart): ()
	if not part.CanTouch then
		warn("AVISO: A part '" .. part.Name .. "' está com CanTouch desligado! O player não vai conseguir acionar o Touched.")
	end

	part.Touched:Connect(function(hit: BasePart)

		local player = get_player_from_hit(hit)
		if not player then
			return
		end

		reward_player(player)
	end)
end

------------------//INIT

dataUtility = get_data_utility()
ensure_remotes()

if dataUtility and dataUtility.server and dataUtility.server.ensure_remotes then
	dataUtility.server.ensure_remotes()
end

local parts = get_zone_parts(groupZone)

if #parts == 0 then
	warn("AVISO: Nenhuma part foi encontrada dentro de workspace.Zones.Group!")
else
	for _, part in ipairs(parts) do
		connect_part(part)
	end
end