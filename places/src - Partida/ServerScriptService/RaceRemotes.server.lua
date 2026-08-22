------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local EVENTS_FOLDER_NAME: string = "Events"
local RACE_FOLDER_NAME: string = "Race"
local ATTACK_REMOTE_NAME: string = "AttackMode"
local DAMAGE_REMOTE_NAME: string = "Damage"
local RACE_STATE_ATTRIBUTE_NAME: string = "RaceState"
local ATTACK_AVAILABLE_ATTRIBUTE_NAME: string = "AttackAvailable"
local ATTACK_ACTIVE_ATTRIBUTE_NAME: string = "AttackActive"
local ATTACK_DURATION_SECONDS: number = 180

------------------//TYPES
type AttackConfig = {
	durations: { number },
	totalSeconds: number,
	maxActivations: number,
	used: number,
}

------------------//FUNCTIONS
local function get_or_create_folder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = name
	newFolder.Parent = parent
	return newFolder
end

local function ensure_remote_objects(): RemoteFunction
	local eventsFolder = get_or_create_folder(ReplicatedStorage, EVENTS_FOLDER_NAME)
	local raceFolder = get_or_create_folder(eventsFolder, RACE_FOLDER_NAME)
	local attackMode = raceFolder:FindFirstChild(ATTACK_REMOTE_NAME)
	if not attackMode or not attackMode:IsA("RemoteFunction") then
		if attackMode then
			attackMode:Destroy()
		end
		attackMode = Instance.new("RemoteFunction")
		attackMode.Name = ATTACK_REMOTE_NAME
		attackMode.Parent = raceFolder
	end

	local damage = eventsFolder:FindFirstChild(DAMAGE_REMOTE_NAME)
	if not damage or not damage:IsA("RemoteEvent") then
		if damage then
			damage:Destroy()
		end
		damage = Instance.new("RemoteEvent")
		damage.Name = DAMAGE_REMOTE_NAME
		damage.Parent = eventsFolder
	end

	return attackMode :: RemoteFunction
end

------------------//MAIN FUNCTIONS
local attackMode = ensure_remote_objects()
attackMode.OnServerInvoke = function(player: Player, action: string): (boolean, AttackConfig | string | number)
	if action == "GetConfig" then
		return true, {
			durations = { ATTACK_DURATION_SECONDS },
			totalSeconds = ATTACK_DURATION_SECONDS,
			maxActivations = 1,
			used = if player:GetAttribute(ATTACK_ACTIVE_ATTRIBUTE_NAME) == true then 1 else 0,
		}
	end

	if action ~= "RequestActivate" then
		return false, "InvalidAction"
	end
	if player:GetAttribute(RACE_STATE_ATTRIBUTE_NAME) ~= "Racing" then
		return false, "RaceNotActive"
	end
	if player:GetAttribute(ATTACK_AVAILABLE_ATTRIBUTE_NAME) ~= true then
		return false, "AttackNotAvailable"
	end
	if player:GetAttribute(ATTACK_ACTIVE_ATTRIBUTE_NAME) == true then
		return false, "AttackAlreadyActive"
	end

	player:SetAttribute(ATTACK_AVAILABLE_ATTRIBUTE_NAME, false)
	player:SetAttribute(ATTACK_ACTIVE_ATTRIBUTE_NAME, true)
	task.delay(ATTACK_DURATION_SECONDS, function()
		if player.Parent then
			player:SetAttribute(ATTACK_ACTIVE_ATTRIBUTE_NAME, false)
		end
	end)
	return true, ATTACK_DURATION_SECONDS
end

------------------//INIT
