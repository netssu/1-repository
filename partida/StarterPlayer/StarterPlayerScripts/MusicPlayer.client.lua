local ContentProvider = game:GetService("ContentProvider")

local player = game.Players.LocalPlayer
repeat task.wait() until player:FindFirstChild('DataLoaded')

local playerSettings = player:WaitForChild("Settings")
local musicPlayer = game.ReplicatedStorage:WaitForChild("Music"):WaitForChild("MusicPlayer")
local MusicSoundGroup = game.SoundService:WaitForChild("Music")
local MusicLibrary = game.ReplicatedStorage:WaitForChild("MusicLibrary")
local InGameFolder = MusicLibrary:WaitForChild("InGame")

local StoryModeStatsModule = require(game.ReplicatedStorage:WaitForChild("StoryModeStats"))
local World = workspace:WaitForChild("Info"):WaitForChild("World")
local WorldName = StoryModeStatsModule.Worlds[World.Value]

function PlayMusic()
	local MusicInstances = {}
	local currentMusicIndex = 1

	
	if not WorldName then
		WorldName = 'Death Star'
	end

	local function PreloadMusicAssets()
		local loadList = {}
		
		
		for _, sound in InGameFolder:WaitForChild(WorldName):GetDescendants() do
			if not sound:IsA("Sound") then continue end
			table.insert(loadList, sound)
			table.insert(MusicInstances, sound)
		end
		ContentProvider:PreloadAsync(loadList)
	end

	local function LoadNewMusic(id :number)
		local stringId =  `{id}` --rbxassetid://
		local totalLoadCount = 0
		repeat musicPlayer.SoundId = stringId; totalLoadCount += 1 task.wait(1) until musicPlayer.IsLoaded or totalLoadCount <10
		if musicPlayer.IsLoaded then
			return true, musicPlayer
		else
			return false
		end
	end


	PreloadMusicAssets()

	while true do

		local successfulLoad, soundInstance = LoadNewMusic(MusicInstances[currentMusicIndex].SoundId)
		currentMusicIndex = (#MusicInstances < currentMusicIndex and currentMusicIndex + 1) or 1
		if successfulLoad then

			soundInstance:Play()
			task.wait(soundInstance.TimeLength)
		end
		task.wait(1)
	end


	--LoadNewMusic(17493423883)

end

--playerSettings.MusicVolume:GetPropertyChangedSignal("Value"):Connect(function()
--	updateSoundVolume()
--end)
--updateSoundVolume()


repeat task.wait(1) until game:IsLoaded()
PlayMusic()

