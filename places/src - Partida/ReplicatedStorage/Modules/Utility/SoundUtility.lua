------------------//SERVICES
local RunService: RunService = game:GetService("RunService")
local SoundService: SoundService = game:GetService("SoundService")

------------------//CONSTANTS
local DEFAULT_MUSIC_VOLUME = 0.5
local DEFAULT_SFX_VOLUME = 0.5
local FADE_DURATION = 1
local MAX_SFX_INSTANCES = 3

------------------//VARIABLES
local soundUtility = {}
local currentMusic: Sound? = nil
local musicVolume = DEFAULT_MUSIC_VOLUME
local sfxVolume = DEFAULT_SFX_VOLUME
local musicMuted = false
local sfxMuted = false
local activeSfx: {[Sound]: boolean} = {}

------------------//FUNCTIONS
local function ensure_sound_group(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		existing.Volume = volume
		return existing
	end

	local soundGroup = Instance.new("SoundGroup")
	soundGroup.Name = name
	soundGroup.Volume = volume
	soundGroup.Parent = SoundService
	return soundGroup
end

local musicGroup = ensure_sound_group("MusicGroup", musicVolume)
local sfxGroup = ensure_sound_group("SFXGroup", sfxVolume)

local function create_sound(soundId: string, parent: Instance, soundGroup: SoundGroup): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.SoundGroup = soundGroup
	sound.Parent = parent
	return sound
end

local function fade_sound(sound: Sound, targetVolume: number, duration: number): ()
	local startVolume = sound.Volume
	local elapsed = 0
	local connection: RBXScriptConnection?

	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not sound.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		elapsed += deltaTime
		local alpha = math.min(elapsed / duration, 1)
		sound.Volume = startVolume + (targetVolume - startVolume) * alpha

		if alpha >= 1 and connection then
			connection:Disconnect()
		end
	end)
end

local function clean_sfx(sound: Sound): ()
	activeSfx[sound] = nil
end

------------------//MAIN FUNCTIONS
function soundUtility.play_music(soundId: string, fadeIn: boolean?, shouldLoop: boolean?): Sound?
	if musicMuted then
		return nil
	end

	if currentMusic then
		soundUtility.stop_music(fadeIn)
	end

	local sound = create_sound(soundId, SoundService, musicGroup)
	sound.Looped = shouldLoop ~= false
	sound.Volume = if fadeIn then 0 else musicVolume
	currentMusic = sound
	sound:Play()

	if fadeIn then
		fade_sound(sound, musicVolume, FADE_DURATION)
	end

	return sound
end

function soundUtility.stop_music(fadeOut: boolean?): ()
	local sound = currentMusic
	if not sound then
		return
	end

	currentMusic = nil
	if fadeOut then
		fade_sound(sound, 0, FADE_DURATION)
		task.delay(FADE_DURATION, function()
			if sound.Parent then
				sound:Stop()
				sound:Destroy()
			end
		end)
		return
	end

	sound:Stop()
	sound:Destroy()
end

function soundUtility.pause_music(): ()
	if currentMusic and currentMusic.Playing then
		currentMusic:Pause()
	end
end

function soundUtility.resume_music(): ()
	if currentMusic and not currentMusic.Playing then
		currentMusic:Resume()
	end
end

function soundUtility.play_sfx(soundId: string, parent: Instance?, volume: number?, pitch: number?): Sound?
	if sfxMuted then
		return nil
	end

	local instanceCount = 0
	for sound in activeSfx do
		if sound.SoundId == soundId then
			instanceCount += 1
		end
	end

	if instanceCount >= MAX_SFX_INSTANCES then
		return nil
	end

	local sound = create_sound(soundId, parent or SoundService, sfxGroup)
	sound.Volume = (volume or 1) * sfxVolume
	sound.PlaybackSpeed = pitch or 1
	activeSfx[sound] = true
	sound.Ended:Connect(function()
		clean_sfx(sound)
		sound:Destroy()
	end)
	sound:Play()
	return sound
end

function soundUtility.stop_all_sfx(): ()
	for sound in activeSfx do
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	activeSfx = {}
end

function soundUtility.set_music_volume(volume: number): ()
	musicVolume = math.clamp(volume, 0, 1)
	musicGroup.Volume = musicVolume
	if currentMusic and not musicMuted then
		currentMusic.Volume = musicVolume
	end
end

function soundUtility.set_sfx_volume(volume: number): ()
	sfxVolume = math.clamp(volume, 0, 1)
	sfxGroup.Volume = sfxVolume
end

function soundUtility.get_music_volume(): number
	return musicVolume
end

function soundUtility.get_sfx_volume(): number
	return sfxVolume
end

function soundUtility.mute_music(mute: boolean): ()
	musicMuted = mute
	if currentMusic then
		currentMusic.Volume = if mute then 0 else musicVolume
	end
end

function soundUtility.mute_sfx(mute: boolean): ()
	sfxMuted = mute
	if mute then
		soundUtility.stop_all_sfx()
	end
end

function soundUtility.is_music_muted(): boolean
	return musicMuted
end

function soundUtility.is_sfx_muted(): boolean
	return sfxMuted
end

function soundUtility.get_current_music(): Sound?
	return currentMusic
end

------------------//INIT
return soundUtility
