local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GameSpeed = workspace.Info.GameSpeed
local effectsFolder = ReplicatedStorage.VFX
local wreckerVFX = effectsFolder.Wrecker

local function connect(p0, p1, c0)
	local weld = Instance.new("Weld")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = c0
	weld.Parent = p0	
	
	return weld
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local module = {}

return module
