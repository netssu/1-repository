local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = game.Players.LocalPlayer
repeat task.wait() until player:FindFirstChild("DataLoaded")
player:WaitForChild("Settings")

local musicTemplate = ReplicatedStorage:WaitForChild("Music"):WaitForChild("MusicPlayer")
local musicPlayer = SoundService:FindFirstChild("MusicPlayer")
local MusicSoundGroup = SoundService:WaitForChild("Music")
local MusicLibrary = ReplicatedStorage:WaitForChild("MusicLibrary")
local InGameFolder = MusicLibrary:WaitForChild("InGame")

local StoryModeStatsModule = require(ReplicatedStorage:WaitForChild("StoryModeStats"))
local World = workspace:WaitForChild("Info"):WaitForChild("World")
local WorldName = StoryModeStatsModule.Worlds[World.Value]

if not musicPlayer or not musicPlayer:IsA("Sound") then
	musicPlayer = musicTemplate:Clone()
	musicPlayer.Name = musicTemplate.Name
	musicPlayer.Parent = SoundService
end

musicPlayer.SoundGroup = MusicSoundGroup
musicPlayer.Volume = musicTemplate.Volume

local function normalizeSoundId(id: number | string)
	local stringId = tostring(id)
	if not stringId:find("rbxassetid://", 1, true) then
		stringId = ("rbxassetid://%s"):format(stringId)
	end
	return stringId
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

function PlayMusic()
	local MusicInstances = {}
	local currentMusicIndex = 1

	if not WorldName then
		WorldName = "Death Star"
	end

	local function PreloadMusicAssets()
		local loadList = {}
		local worldFolder = InGameFolder:FindFirstChild(WorldName) or InGameFolder:FindFirstChild("Death Star")

		if not worldFolder then
			return
		end

		for _, sound in worldFolder:GetDescendants() do
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
		local currentSound = MusicInstances[currentMusicIndex]
		if not currentSound then
			currentMusicIndex = 1
			task.wait(1)
			continue
		end

		local successfulLoad, soundInstance = LoadNewMusic(currentSound.SoundId)
		currentMusicIndex = (currentMusicIndex < #MusicInstances and currentMusicIndex + 1) or 1
		if successfulLoad and soundInstance then
			soundInstance:Stop()
			soundInstance.TimePosition = 0
			soundInstance:Play()

			local waitDuration = soundInstance.TimeLength > 0 and soundInstance.TimeLength or 1
			task.wait(waitDuration)
		else
			task.wait(1)
		end
	end
end

repeat task.wait(1) until game:IsLoaded()
PlayMusic()
