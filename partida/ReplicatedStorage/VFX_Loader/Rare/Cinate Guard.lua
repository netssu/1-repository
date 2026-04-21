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

module["Cinate Attack"] = function(HRP, target)
	local Folder = VFX.RAR["Cinate Guard"]
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.82/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	--VFX_Helper.SoundPlay(HRP,Folder.Sound)

	local HRPCF = HRP.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local targetPosition = (HRPCF * CFrame.new(0, 0, -Range)).Position

	local Ball = Folder:WaitForChild("Patronys"):Clone()
	Ball.CFrame = HRP.Parent["Right Arm"].Gun.pos.CFrame
	Ball.Position = HRP.Parent["Right Arm"].Gun.pos.Position 
	Ball.Parent = HRP
	Debris:AddItem(Ball,1/speed)
	task.wait(0.01/speed)

	local emitgun = HRP.Parent["Right Arm"].Gun.pos
	VFX_Helper.EmitAllParticles(emitgun)
	TS:Create(Ball,TweenInfo.new(0.1/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	UnitSoundEffectLib.playSound(HRP.Parent, "Blaster" .. tostring(math.random(1,3)))
	task.wait(0.085/speed)
	if not HRP or not HRP.Parent then return end
	Ball.Transparency = 1
	task.wait(0.01/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(Ball)
	
	local lastboom = Folder:WaitForChild("bomchik"):Clone()
	lastboom.Position = Ball.Position
	lastboom.Parent = vfxFolder
	Debris:AddItem(lastboom,2/speed)
	VFX_Helper.EmitAllParticles(lastboom)
	

	HRP.Parent.Attacking.Value = false
end


return module
