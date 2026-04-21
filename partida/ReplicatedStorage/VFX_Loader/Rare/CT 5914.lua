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

local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

local function canAttack(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then
		warn("no target")
		return false
	end

	return true
end

module["Dual Wield Pistols"] = function(HRP, target)
	task.wait(.25)
	if not canAttack(HRP, target) then
		return
	end

	local folder = VFX["CT"]

	HRP.Parent.Attacking.Value = true

	local vfxPart = folder["2 Pistol Shot"]:Clone()
	local vfxCFrame = (HRP.CFrame * CFrame.new(0,0,-1)) * CFrame.Angles(0,math.rad(-90),0)

	vfxPart.CFrame = vfxCFrame
	vfxPart.Parent = workspace.VFX

	UnitSoundEffectLib.playSound(HRP.Parent, "LaserGun2")

	emitParticles(vfxPart)

	Debris:AddItem(vfxPart, 2)

	task.wait(.25)

	if HRP and HRP.Parent then
		HRP.Parent.Attacking.Value = false
	end
end

return module