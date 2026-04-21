local ContentProvider = game:GetService("ContentProvider")
local localplayer = game.Players.LocalPlayer
repeat task.wait() until localplayer:FindFirstChild('DataLoaded')
local playerSettings = localplayer:WaitForChild("Settings")
local musicPlayer = game.ReplicatedStorage:WaitForChild("Music"):WaitForChild("MusicPlayer")

local MusicLibrary = game.ReplicatedStorage:WaitForChild("MusicLibrary")
local InLobbyFolder = MusicLibrary:WaitForChild("InLobby")
local MaxVolume = musicPlayer.Volume
local ZoneModule = require(game.ReplicatedStorage.Modules.Zone)
local MaximumVolume = 100

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

function PlayMusic()
	local MusicInstances = {}
	local currentMusicIndex = 1

	local function PreloadMusicAssets()
		local loadList = {}
		for _, sound in InLobbyFolder:GetDescendants() do
			if not sound:IsA("Sound") then continue end
			table.insert(loadList, sound)
			table.insert(MusicInstances, sound)
		end
		ContentProvider:PreloadAsync(loadList)
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

function updateSoundVolume(soundGroup, newVolume)
	musicPlayer.Volume = playerSettings.MusicVolume.Value * MaximumVolume
end

playerSettings:WaitForChild("MusicVolume"):GetPropertyChangedSignal("Value"):Connect(function()
	updateSoundVolume()
end)
updateSoundVolume()


repeat task.wait(1) until game:IsLoaded()

local container = workspace:WaitForChild("BarBorders"):GetChildren()
local tweenService = game:GetService('TweenService')

local newZone =  ZoneModule.new(container)
local ttime = 0.2

local function tween(obj, length, details)
    tweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local Target = localplayer:WaitForChild('PlayerGui'):WaitForChild('RaidProgress'):WaitForChild('Frame')

newZone.playerEntered:Connect(function(player)
    if player == localplayer then
		if musicPlayer.SoundId ~= "rbxassetid://108081931421357" then
			LoadNewMusic("rbxassetid://108081931421357")
		end
	end
end)

-- rbxassetid://1835323501

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bindables = ReplicatedStorage.Bindables

Bindables.LoadMusic.Event:Connect(function(ID)
	if not ID then
		LoadNewMusic(musicPlayer.Parent.Parent.MusicLibrary.InLobby.Misc.Sound.SoundId)
	else
		LoadNewMusic(ID)
	end
end)

newZone.playerExited:Connect(function(player)
    if player == localplayer then
		LoadNewMusic(musicPlayer.Parent.Parent.MusicLibrary.InLobby.Misc.Sound.SoundId)
	end
end)

local container2 = workspace:WaitForChild('RaidsBorder'):WaitForChild('EVIL')

local newZone2 = ZoneModule.new(container2)

newZone2.playerEntered:Connect(function(player)
    if player == localplayer then
        tween(Target, ttime, {Position = UDim2.fromScale(0.5,0.1)})
        
		if musicPlayer.SoundId ~= "rbxassetid://9046705140" then
			LoadNewMusic("rbxassetid://9046705140")
		end
	end
end)

newZone2.playerExited:Connect(function(player)
    if player == localplayer then
        tween(Target, ttime, {Position = UDim2.fromScale(0.5,-0.2)})
		LoadNewMusic(musicPlayer.Parent.Parent.MusicLibrary.InLobby.Misc.Sound.SoundId)
	end
end)



PlayMusic()