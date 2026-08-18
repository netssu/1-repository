------------------//SERVICES
local Players: Players = game:GetService("Players")
local SoundService: SoundService = game:GetService("SoundService")

------------------//CONSTANTS
local JUMP_SOUND_ID = "rbxassetid://139980012524397"
local DEFAULT_RUNNING_SOUND_ID = "rbxasset://sounds/action_footsteps_plastic.mp3"
local BASE_FOOTSTEP_SPEED = 16
local MIN_RUNNING_SPEED = 1

------------------//VARIABLES
local player = Players.LocalPlayer
local characterConnections: {RBXScriptConnection} = {}
local activeSounds: {Sound} = {}

------------------//FUNCTIONS
local function create_sound(name: string, soundId: string, rootPart: BasePart, looped: boolean): Sound
	local existing = rootPart:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		existing:Destroy()
	end

	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Archivable = false
	sound.EmitterSize = 5
	sound.RollOffMaxDistance = 150
	sound.Volume = 0.65
	sound.Looped = looped
	sound.Parent = rootPart
	table.insert(activeSounds, sound)
	return sound
end

local function play_from_start(sound: Sound): ()
	sound.TimePosition = 0
	sound:Play()
end

local function get_footstep_sound(humanoid: Humanoid): Sound?
	local footsteps = SoundService:FindFirstChild("Footsteps")
	if not footsteps then
		return nil
	end

	local materialSound = footsteps:FindFirstChild(humanoid.FloorMaterial.Name)
	if materialSound and materialSound:IsA("Sound") then
		return materialSound
	end

	local fallback = footsteps:FindFirstChild("Plastic")
	if fallback and fallback:IsA("Sound") then
		return fallback
	end

	return nil
end

local function clear_character(): ()
	for _, connection in characterConnections do
		connection:Disconnect()
	end
	characterConnections = {}

	for _, sound in activeSounds do
		if sound.Parent then
			sound:Destroy()
		end
	end
	activeSounds = {}
end

------------------//MAIN FUNCTIONS
local function bind_character(character: Model): ()
	clear_character()

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local jumpSound = create_sound("Jumping", JUMP_SOUND_ID, rootPart, false)
	local runningSound = create_sound("Running", DEFAULT_RUNNING_SOUND_ID, rootPart, true)
	runningSound.Volume = 0

	table.insert(characterConnections, humanoid.StateChanged:Connect(function(_: Enum.HumanoidStateType, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Jumping then
			play_from_start(jumpSound)
		elseif newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Landed then
			runningSound:Stop()
		end
	end))

	table.insert(characterConnections, humanoid.Running:Connect(function(speed: number)
		if speed < MIN_RUNNING_SPEED or humanoid.FloorMaterial == Enum.Material.Air then
			runningSound:Stop()
			return
		end

		local materialSound = get_footstep_sound(humanoid)
		if materialSound then
			runningSound.SoundId = materialSound.SoundId
			runningSound.PlaybackSpeed = materialSound.PlaybackSpeed * math.clamp(speed / BASE_FOOTSTEP_SPEED, 0.65, 2.5)
			runningSound.Volume = materialSound.Volume
		else
			runningSound.SoundId = DEFAULT_RUNNING_SOUND_ID
			runningSound.PlaybackSpeed = math.clamp(speed / BASE_FOOTSTEP_SPEED, 0.65, 2.5)
			runningSound.Volume = 0.45
		end

		if not runningSound.Playing then
			runningSound:Play()
		end
	end))
end

------------------//INIT
player.CharacterAdded:Connect(bind_character)
player.CharacterRemoving:Connect(clear_character)

if player.Character then
	task.spawn(bind_character, player.Character)
end
