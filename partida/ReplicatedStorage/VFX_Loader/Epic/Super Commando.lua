local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local repStorage = game:GetService('ReplicatedStorage')
local tweenService = game:GetService('TweenService')
local Debris = game:GetService("Debris")

local vfxFolder = repStorage.VFX
local supperCommandoVfx = vfxFolder["SuperCommando"]

local module = {}

local function emitParticles(particle: ParticleEmitter)
	local delayTime = particle:GetAttribute("DelayTime") or 0
	local emitCount = particle:GetAttribute("EmitCount") or particle.Rate

	if delayTime > 0 then
		task.delay(delayTime, function()
			particle:Emit(emitCount)
		end)
	else
		particle:Emit(emitCount)
	end
end

module["Pistol and Rocket"] = function(HRP, target)
	local rocketExplosion = supperCommandoVfx["Rocket Explosion"]:Clone()
	
	UnitSoundEffectLib.playSound(HRP.Parent, 'Rockets1')
	
	
	task.delay(1.3, function()
		rocketExplosion.CFrame = HRP.CFrame * CFrame.new(0,0,-2)
		rocketExplosion.Parent = workspace.VFX
		UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
		
		for _, particle in rocketExplosion:GetDescendants() do
			if not particle:IsA("ParticleEmitter") then continue end
			emitParticles(particle)
		end
		
		Debris:AddItem(rocketExplosion, 2)
	end)
end

return module