local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed

function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end

local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

module["Assault Rifle"] = function(HRP: BasePart, target: Model)
	local Folder = VFX["Crosshair"].First
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local speed = GameSpeed.Value

	task.wait(.2 / speed)

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local assaultRifle = Folder["Assult Rifle"]:Clone()
	assaultRifle.CFrame = HRP.CFrame * CFrame.new(0,0,-.5)
	assaultRifle.Parent = vfxFolder

	UnitSoundEffectLib.playSound(HRP.Parent, 'Sniper' .. tostring(math.random(1,3)))

	emitParticles(assaultRifle)

	Debris:AddItem(assaultRifle, 2)

	task.wait(.2 / speed)

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

module["Sniper"] = function(HRP: BasePart, target: Model)
	local Folder = VFX["Crosshair"].Second
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local speed = GameSpeed.Value

	task.wait(.2 / speed)

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local sniper = Folder["Sniper Multiple Hit"]:Clone()
	sniper.CFrame = HRP.CFrame * CFrame.new(0,0,-.5)
	sniper.Parent = vfxFolder
	UnitSoundEffectLib.playSound(HRP.Parent, 'Sniper' .. tostring(math.random(1,3)))

	emitParticles(sniper)

	Debris:AddItem(sniper, 2)

	task.wait(.2 / speed)

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

module["Sniper Boom"] = function(HRP: BasePart, target: Model)
	local Folder = VFX["Crosshair"].Third
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local speed = GameSpeed.Value

	task.wait(.2 / speed)

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local sniper = Folder["Sniper Boom"]:Clone()
	sniper.CFrame = HRP.CFrame * CFrame.new(0,0,-.5)
	sniper.Parent = vfxFolder
	UnitSoundEffectLib.playSound(HRP.Parent, 'Sniper' .. tostring(math.random(1,3)))

	emitParticles(sniper)

	Debris:AddItem(sniper, 2)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
	task.wait(.2 / speed)

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

return module