local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local tweenService = game:GetService("TweenService")
function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end


local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	tweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

module["Command Roll"] = function(HRP, target)
	local Folder = VFX["Jungle Trooper"].First
	local speed = GameSpeed.Value
	local enemyPos = Vector3.new(
		target.HumanoidRootPart.Position.X,
		HRP.Position.Y,
		target.HumanoidRootPart.Position.Z
	)

	task.wait(0.77 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true

	local emitters = {}

	local RightArm = HRP.Parent:FindFirstChild('Right Arm')
	if RightArm then
		for i,v in RightArm:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				--print('found a particle!!!')
				table.insert(emitters, v)
			end
		end
	end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Blaster3')

	for _, emitter in emitters do
		emitter.Enabled = true
		task.delay(0.2 / speed, function()
			if emitter then emitter.Enabled = false end
		end)
	end
	
	HRP.Parent.Attacking.Value = false
end



return module
