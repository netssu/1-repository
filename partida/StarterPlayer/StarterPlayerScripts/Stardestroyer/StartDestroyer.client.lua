local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local AudioPlayer = require(ReplicatedStorage.AceLib.AudioPlayer)

local TweenModule = require(ReplicatedStorage.AceLib.TweenModule)
local VFXPlayer = require(ReplicatedStorage.AceLib.VFXPlayer)
local CameraShake = require(ReplicatedStorage.AceLib.CameraShake)

local DestroyerRemotes = ReplicatedStorage.Remotes.DestroyerRemotes


UserInputService.InputBegan:Connect(function(key, gp)
	if not gp and Player.Character then
		if key.KeyCode == Enum.KeyCode.G then
			ReplicatedStorage.Remotes.DestroyerRemotes.CallDestroyer:FireServer()
		end
	end
end)