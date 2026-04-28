local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local localplayer = game.Players.LocalPlayer
repeat task.wait() until localplayer:FindFirstChild("DataLoaded")
local playerSettings = localplayer:WaitForChild("Settings")

local musicTemplate = ReplicatedStorage:WaitForChild("Music"):WaitForChild("MusicPlayer")
local musicPlayer = SoundService:FindFirstChild("MusicPlayer")
local MusicSoundGroup = SoundService:WaitForChild("Music")
local MusicLibrary = ReplicatedStorage:WaitForChild("MusicLibrary")
local InLobbyFolder = MusicLibrary:WaitForChild("InLobby")
local DefaultLobbySoundId = InLobbyFolder:WaitForChild("Misc"):WaitForChild("Sound").SoundId
local MaxVolume = musicTemplate.Volume
local ZoneModule = require(ReplicatedStorage.Modules.Zone)

local BAR_BORDER_SOUND_ID = "rbxassetid://108081931421357"
local RAID_BORDER_SOUND_ID = "rbxassetid://9046705140"

if not musicPlayer or not musicPlayer:IsA("Sound") then
	musicPlayer = musicTemplate:Clone()
	musicPlayer.Name = musicTemplate.Name
	musicPlayer.Parent = SoundService
end

musicPlayer.SoundGroup = MusicSoundGroup
musicPlayer.Volume = MaxVolume

local activeOverrides = {
	Bindable = nil,
	BarBorder = false,
	RaidBorder = false,
}

local function normalizeSoundId(id: number | string)
	local stringId = tostring(id)
	if not stringId:find("rbxassetid://", 1, true) then
		stringId = ("rbxassetid://%s"):format(stringId)
	end
	return stringId
end

local function getOverrideSoundId()
	if activeOverrides.Bindable then
		return activeOverrides.Bindable
	end

	if activeOverrides.RaidBorder then
		return RAID_BORDER_SOUND_ID
	end

	if activeOverrides.BarBorder then
		return BAR_BORDER_SOUND_ID
	end

	return nil
end

local function LoadNewMusic(id: number | string)
	local stringId = normalizeSoundId(id)
	local totalLoadCount = 0

	musicPlayer.SoundId = stringId

	pcall(function()
		ContentProvider:PreloadAsync({ musicPlayer })
	end)

	while not musicPlayer.IsLoaded and totalLoadCount < 10 do
		totalLoadCount += 1
		task.wait(0.5)
	end

	if musicPlayer.IsLoaded then
		return true, musicPlayer
	end

	return false
end

local function refreshMusic()
	musicPlayer:Stop()
	musicPlayer.TimePosition = 0
end

function PlayMusic()
	local MusicInstances = {}
	local currentMusicIndex = 1

	local function PreloadMusicAssets()
		local loadList = {}
		for _, sound in InLobbyFolder:GetDescendants() do
			if not sound:IsA("Sound") then
				continue
			end

			table.insert(loadList, sound)
			table.insert(MusicInstances, sound)
		end

		if #loadList > 0 then
			ContentProvider:PreloadAsync(loadList)
		end
	end

	PreloadMusicAssets()

	if #MusicInstances == 0 then
		return
	end

	while true do
		local overrideSoundId = getOverrideSoundId()
		local targetSoundId
		local shouldAdvancePlaylist = false

		if overrideSoundId then
			targetSoundId = overrideSoundId
		else
			local currentSound = MusicInstances[currentMusicIndex]
			if not currentSound then
				currentMusicIndex = 1
				task.wait(1)
				continue
			end

			targetSoundId = currentSound.SoundId
			shouldAdvancePlaylist = true
		end

		local successfulLoad, soundInstance = LoadNewMusic(targetSoundId)
		if successfulLoad and soundInstance then
			soundInstance.TimePosition = 0
			soundInstance:Play()

			local loadedSoundId = soundInstance.SoundId
			local startedAt = os.clock()
			local waitDuration = soundInstance.TimeLength > 0 and soundInstance.TimeLength or 1

			repeat
				task.wait(0.25)
			until not soundInstance.IsPlaying
				or soundInstance.SoundId ~= loadedSoundId
				or os.clock() - startedAt >= waitDuration
		else
			task.wait(1)
		end

		if shouldAdvancePlaylist then
			currentMusicIndex = (currentMusicIndex < #MusicInstances and currentMusicIndex + 1) or 1
		end
	end
end

local function updateSoundVolume()
	musicPlayer.Volume = MaxVolume
end

playerSettings:WaitForChild("MusicVolume"):GetPropertyChangedSignal("Value"):Connect(updateSoundVolume)
updateSoundVolume()

repeat task.wait(1) until game:IsLoaded()

local container = workspace:WaitForChild("BarBorders"):GetChildren()
local newZone = ZoneModule.new(container)
local ttime = 0.2

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local Target = localplayer:WaitForChild("PlayerGui"):WaitForChild("RaidProgress"):WaitForChild("Frame")

newZone.playerEntered:Connect(function(player)
	if player == localplayer then
		activeOverrides.BarBorder = true
		refreshMusic()
	end
end)

local Bindables = ReplicatedStorage.Bindables

Bindables.LoadMusic.Event:Connect(function(ID)
	activeOverrides.Bindable = ID and normalizeSoundId(ID) or nil
	refreshMusic()
end)

newZone.playerExited:Connect(function(player)
	if player == localplayer then
		activeOverrides.BarBorder = false
		refreshMusic()
	end
end)

local container2 = workspace:WaitForChild("RaidsBorder"):WaitForChild("EVIL")

local newZone2 = ZoneModule.new(container2)

newZone2.playerEntered:Connect(function(player)
	if player == localplayer then
		activeOverrides.RaidBorder = true
		tween(Target, ttime, { Position = UDim2.fromScale(0.5, 0.1) })
		refreshMusic()
	end
end)

newZone2.playerExited:Connect(function(player)
	if player == localplayer then
		activeOverrides.RaidBorder = false
		tween(Target, ttime, { Position = UDim2.fromScale(0.5, -0.2) })
		if not getOverrideSoundId() and musicPlayer.SoundId ~= normalizeSoundId(DefaultLobbySoundId) then
			LoadNewMusic(DefaultLobbySoundId)
		end
		refreshMusic()
	end
end)

if musicPlayer.SoundId ~= normalizeSoundId(DefaultLobbySoundId) then
	LoadNewMusic(DefaultLobbySoundId)
end

PlayMusic()
