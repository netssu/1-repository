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

module["104th Trooper Attack"] = function(HRP, target)
	local Folder = VFX.RAR["Trooper 104th"]
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.9/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	--VFX_Helper.SoundPlay(HRP,Folder.Sound)


	local fire = Folder:WaitForChild("Fire"):Clone()
	fire.CFrame = HRP.Parent["Right Arm"].Handle.Pos.CFrame
	fire.Parent = HRP
	UnitSoundEffectLib.playSound(HRP.Parent, 'Flamethrower')
	
	Debris:AddItem(fire,2.5/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP.Parent["Right Arm"].Handle.Pos
	weld.Part1 = fire
	weld.Parent = fire
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end

	VFX_Helper.OnAllParticles(fire)
	task.wait(1.4/speed)
	if not HRP or not HRP.Parent then return end

	VFX_Helper.OffAllParticles(fire)
	task.wait(1.5/speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = false
end


return module
