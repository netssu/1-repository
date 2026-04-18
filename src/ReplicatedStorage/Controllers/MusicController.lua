local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local musicIds = require(ReplicatedStorage.Modules.Game.MusicIds)
local packets = require(ReplicatedStorage.Modules.Game.Packets)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)
local PlaySoundAt = require(ReplicatedStorage.Modules.Platform.PlaySoundAt)

local INFO = TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut)

local MusicController = {}
MusicController._currentVolume = 0.25
MusicController._isMuted = false
MusicController._savedVolume = 0.25 
MusicController._currentTrackId = 0
MusicController._connections = {}

local function GetTargetMusicId(): number
	return musicIds.GetTargetTrackId(Players.LocalPlayer)
end

local function BuildAssetId(AssetId: number): string
	return "rbxassetid://" .. tostring(AssetId)
end

function MusicController.Init(self: MusicController): ()
	self._soundsFolder = Instance.new("Folder")
	self._soundsFolder.Name = "Sounds"
	self._soundsFolder.Parent = workspace
	
	self._music = Instance.new("Sound")
	self._music.Name = "BackgroundMusic"
	self._music.Volume = 0
	self._music.Looped = true
	self._music.Parent = workspace
	
	_G.MusicController = self
end

local function UpdateMusic(self: MusicController): ()
	local targetId = GetTargetMusicId()
	if targetId <= 0 then
		return
	end
	if self._currentTrackId == targetId and self._music.Playing then
		return
	end
	self._currentTrackId = targetId
	self:PlayMusic(targetId)
end

function MusicController.Start(self: MusicController): ()
	packets.PlaySound.OnClientEvent:Connect(function(soundId, pitch)
		self:PlaySound(soundId, pitch)
	end)

	local gameState = ReplicatedStorage:WaitForChild("FTGameState")
	local matchFolder = gameState:WaitForChild("Match") :: Folder

	local function bindValue(value: IntValue)
		table.insert(self._connections, value.Changed:Connect(function()
			UpdateMusic(self)
		end))
	end

	local function bindTeamFolder(teamFolder: Folder)
		for _, value in teamFolder:GetChildren() do
			if value:IsA("IntValue") then
				bindValue(value)
			end
		end
		table.insert(self._connections, teamFolder.ChildAdded:Connect(function(child)
			if child:IsA("IntValue") then
				bindValue(child)
				UpdateMusic(self)
			end
		end))
	end

	for _, teamFolder in matchFolder:GetChildren() do
		if teamFolder:IsA("Folder") then
			bindTeamFolder(teamFolder)
		end
	end
	table.insert(self._connections, matchFolder.ChildAdded:Connect(function(child)
		if child:IsA("Folder") then
			bindTeamFolder(child)
			UpdateMusic(self)
		end
	end))
	table.insert(self._connections, matchFolder.ChildRemoved:Connect(function()
		UpdateMusic(self)
	end))
	table.insert(self._connections, Players.LocalPlayer:GetAttributeChangedSignal("FTSessionId"):Connect(function()
		UpdateMusic(self)
	end))
	table.insert(self._connections, Players.LocalPlayer:GetAttributeChangedSignal(MatchPlayerUtils.GetMatchActiveAttributeName()):Connect(function()
		UpdateMusic(self)
	end))

	UpdateMusic(self)
end

function MusicController.SetVolume(self: MusicController, volumeScale: number)
	self._currentVolume = (volumeScale / 10) * 0.5

	if not self._isMuted then
		self._music.Volume = self._currentVolume
	else
		self._savedVolume = self._currentVolume
	end
end

function MusicController.SetEnabled(self: MusicController, isEnabled: boolean)
	self._isMuted = not isEnabled
	
	if self._isMuted then
		self._savedVolume = self._currentVolume
		self._music.Volume = 0
	else
		self._music.Volume = self._savedVolume or self._currentVolume
	end
end

function MusicController.Pause(self: MusicController): ()
	if not self._music.Playing then return end
	
	local tween = TweenService:Create(self._music, INFO, { Volume = 0 })
	tween:Play()
	tween.Completed:Wait()
	self._music:Stop()
end

function MusicController.PlayMusic(self: MusicController, musicId: number): ()
	self:Pause()
	
	self._music.SoundId = BuildAssetId(musicId)
	self._music:Play()
	
	local targetVol = self._isMuted and 0 or self._currentVolume
	TweenService:Create(self._music, INFO, { Volume = targetVol }):Play()
end

function MusicController.PlaySound(self: MusicController, soundId: number, pitch: boolean?): ()
	local sound = Instance.new("Sound")
	sound.SoundId = BuildAssetId(soundId)
	sound.Volume = 0.5
	sound.Parent = self._soundsFolder
	
	if pitch then
		local pitchEffect = Instance.new("PitchShiftSoundEffect")
		pitchEffect.Octave = math.random(90, 110) / 100
		pitchEffect.Parent = sound
	end
	
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

function MusicController.PlaySoundAt(_self: MusicController, soundId: number, instance: Instance)
	PlaySoundAt(instance, soundId, 0.5, false)
end

type MusicController = typeof(MusicController) & {
	_soundsFolder: Folder,
	_music: Sound,
}

return MusicController :: MusicController
