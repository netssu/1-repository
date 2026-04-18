local SoundController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local PACKETS = require(ReplicatedStorage.Modules.Game.Packets)
local DATA_SOUNDS = require(ReplicatedStorage.Modules.Data.SoundsData)

local ROLLOFF_MAX_DISTANCE = 75
local PITCH_MIN = 90
local PITCH_MAX = 110
local SOUND_ID_PATTERN = "%d+"
local UI_HOVER_SOUND_KEY = "HoverSound"
local UI_HOVER_FALLBACK_SOUND_KEY = "Select"
local UI_HOVER_VOLUME_SCALE = 1
local UI_HOVER_FALLBACK_VOLUME_SCALE = 0.55
local UI_HOVER_MIN_VOLUME = 0.6
local UI_HOVER_FALLBACK_MIN_VOLUME = 0.5

local sfxGroup = nil
local soundsFolder = nil

local _currentVolumeLevel = 5
local _isEnabled = true

local function getSoundInfo(key)
	if typeof(key) == "number" then 
		return key > 0 and {
			Id = key,
			BaseVolume = 1.0
		} or nil
	elseif typeof(key) == "string" then
		local soundData = DATA_SOUNDS.List[key]
		if soundData and soundData.Id and soundData.Id > 0 then
			return {
				Id = soundData.Id,
				BaseVolume = soundData.BaseVolume or 1.0
			}
		end
		
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local soundsFolder = assets and assets:FindFirstChild("Sounds")
		local sound = soundsFolder and soundsFolder:FindFirstChild(key)
		if not sound or not sound:IsA("Sound") then
			sound = SoundService:FindFirstChild(key)
		end
		
		if sound and sound:IsA("Sound") then
			local raw = sound.SoundId or ""
			local parsed = tonumber(string.match(raw, SOUND_ID_PATTERN))
			if parsed and parsed > 0 then
				return {
					Id = parsed,
					BaseVolume = sound.Volume or 1.0
				}
			end
		end
		return nil
	end
	return nil
end

local function createSoundInstance(soundInfo, parent, options)
	local props = options or {}
	
	local baseVolume = props.Volume or soundInfo.BaseVolume or 1.0
	
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundInfo.Id
	sound.Volume = baseVolume
	sound.SoundGroup = sfxGroup
	sound.Parent = parent

	if props.Pitch then
		local pitchEffect = Instance.new("PitchShiftSoundEffect")
		pitchEffect.Octave = math.random(PITCH_MIN, PITCH_MAX) / 100
		pitchEffect.Parent = sound
	end

	return sound
end

local function updateGroupVolume()
	if not sfxGroup then return end
	
	if _isEnabled then
		sfxGroup.Volume = _currentVolumeLevel / 10
	else
		sfxGroup.Volume = 0
	end
end

function SoundController.Init(self)
	soundsFolder = Instance.new("Folder")
	soundsFolder.Name = "ActiveSFX"
	soundsFolder.Parent = workspace

	local existingGroup = SoundService:FindFirstChild("SFXGroup")
	if existingGroup then
		sfxGroup = existingGroup
	else
		sfxGroup = Instance.new("SoundGroup")
		sfxGroup.Name = "SFXGroup"
		sfxGroup.Parent = SoundService
	end
	
	updateGroupVolume()
	
	_G.SoundController = self
end

function SoundController.SetVolume(self, volumeLevel)
	_currentVolumeLevel = volumeLevel
	updateGroupVolume()
end

function SoundController.SetEnabled(self, isEnabled)
	_isEnabled = isEnabled
	updateGroupVolume()
end

function SoundController.Start(self)
	PACKETS.PlaySound.OnClientEvent:Connect(function(soundId, pitch)
		self:Play(soundId, { Pitch = pitch })
	end)

	PACKETS.PlaySoundAt.OnClientEvent:Connect(function(soundId, instance)
		self:PlayAt(instance, soundId, { Pitch = true })
	end)
end

function SoundController.Play(self, soundKey, options)
	local soundInfo = getSoundInfo(soundKey)
	if not soundInfo then return nil end

	local sound = createSoundInstance(soundInfo, soundsFolder, options)
	sound:Play()
	sound.Ended:Once(function() 
		sound:Destroy() 
	end)
	
	return sound
end

function SoundController.PlayUiHover(self)
	local hoverSoundInfo = getSoundInfo(UI_HOVER_SOUND_KEY)
	if hoverSoundInfo then
		return self:Play(UI_HOVER_SOUND_KEY, {
			Volume = math.max((hoverSoundInfo.BaseVolume or 1) * UI_HOVER_VOLUME_SCALE, UI_HOVER_MIN_VOLUME),
		})
	end

	local fallbackSoundInfo = getSoundInfo(UI_HOVER_FALLBACK_SOUND_KEY)
	if not fallbackSoundInfo then
		return nil
	end

	return self:Play(UI_HOVER_FALLBACK_SOUND_KEY, {
		Volume = math.max(
			(fallbackSoundInfo.BaseVolume or 1) * UI_HOVER_FALLBACK_VOLUME_SCALE,
			UI_HOVER_FALLBACK_MIN_VOLUME
		),
	})
end

function SoundController.PlayAt(self, location, soundKey, options)
	local soundInfo = getSoundInfo(soundKey)
	if not soundInfo then return nil end

	local targetParent = nil
	local attachment = nil

	if typeof(location) == "Instance" then
		targetParent = location
	elseif typeof(location) == "Vector3" then
		local terrain = workspace.Terrain
		attachment = Instance.new("Attachment")
		attachment.WorldPosition = location
		attachment.Parent = terrain
		targetParent = attachment
	end

	local props = options or {}
	local sound = createSoundInstance(soundInfo, targetParent, {
		Volume = props.Volume,
		Pitch = props.Pitch
	})
	
	sound.RollOffMaxDistance = props.MaxDist or ROLLOFF_MAX_DISTANCE
	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
		if attachment then 
			attachment:Destroy() 
		end
	end)
	
	return sound
end

return SoundController
