------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local SoundController = require(ReplicatedStorage.Modules.Utility.SoundUtility)
local SoundData = require(ReplicatedStorage.Modules.Datas.SoundData)

local LOADING_MUSIC_SOUND_ID: string = "rbxassetid://136422008135190"
local LOADING_SOUND_NAME: string = "LoadingMusic"
local LOADING_VOLUME: number = 0.6
local LOADING_FADE_OUT_TIME: number = 1.5

------------------//VARIABLES
local loadingSound: Sound? = nil

------------------//FUNCTIONS
local function is_loaded(): boolean
	return _G.Loaded == true
end

local function create_loading_sound(): Sound
	local existing = workspace:FindFirstChild(LOADING_SOUND_NAME)
	if existing and existing:IsA("Sound") then
		existing:Destroy()
	end

	local sound = Instance.new("Sound")
	sound.Name = LOADING_SOUND_NAME
	sound.SoundId = LOADING_MUSIC_SOUND_ID
	sound.Looped = true
	sound.Volume = LOADING_VOLUME
	sound.RollOffMaxDistance = 1000000
	sound.EmitterSize = 1000000
	sound.Parent = workspace
	return sound
end

local function fade_out_and_destroy(sound: Sound, duration: number): ()
	if not sound or sound.Parent == nil then
		return
	end

	local tween = TweenService:Create(sound, TweenInfo.new(duration), { Volume = 0 })
	tween:Play()
	tween.Completed:Wait()

	if sound.Parent ~= nil then
		sound:Stop()
		sound:Destroy()
	end
end

local function play_main_menu_music(): ()
	pcall(function()
		SoundController.PlayMusic(SoundData.Music.MainMenu, true, true)
	end)
end

------------------//MAIN FUNCTIONS
local function run_music_flow(): ()
	if is_loaded() then
		play_main_menu_music()
		return
	end

	loadingSound = create_loading_sound()
	loadingSound:Play()

	while not is_loaded() do
		RunService.Heartbeat:Wait()
	end

	if loadingSound then
		fade_out_and_destroy(loadingSound, LOADING_FADE_OUT_TIME)
		loadingSound = nil
	end

	play_main_menu_music()
end

------------------//INIT
run_music_flow()