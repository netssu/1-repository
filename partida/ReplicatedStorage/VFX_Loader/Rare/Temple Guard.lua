local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local repStorage = game:GetService('ReplicatedStorage')
local tweenService = game:GetService('TweenService')
local Debris = game:GetService("Debris")

local vfxFolder = repStorage.VFX
local templeGuardVfx = vfxFolder["Temple Guard"]
local VFX_Helper = require(repStorage.Modules.VFX_Helper)

local module = {}

local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

function module.Shunt(HRP, target)
	local shunt = templeGuardVfx.Shunt:Clone()
	shunt.CFrame = HRP.CFrame * CFrame.new(0,0,-2)
	shunt.Parent = workspace.VFX

	task.delay(.5, function() -- random number to time with animation
		emitParticles(shunt)
		UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

		Debris:AddItem(shunt, 2)
	end)
end

return module