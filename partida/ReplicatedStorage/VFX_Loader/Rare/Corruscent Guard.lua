local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed

module["Duoble Attack"] = function(HRP, target)
	local Folder = VFX.RAR["Corruscent Guard"].First
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.9/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	VFX_Helper.SoundPlay(HRP,Folder.Sound)

	local HRPCF = HRP.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local targetPosition = (HRPCF * CFrame.new(0, 0, -Range)).Position

	local Secondball = Folder:WaitForChild("Part"):Clone()
	Secondball.CFrame = HRP.Parent["Left Arm"].Gun2.Pos2.CFrame
	Secondball.Position = HRP.Parent["Left Arm"].Gun2.Pos2.Position
	Secondball.Parent = vfxFolder
	Debris:AddItem(Secondball,1/speed)
	task.wait(0.01/speed)

	local SecondEmit = HRP.Parent["Left Arm"].Gun2.Pos2
	VFX_Helper.EmitAllParticles(SecondEmit)
	TS:Create(Secondball,TweenInfo.new(0.1/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	Secondball.Transparency = 1
	VFX_Helper.OffAllParticles(Secondball)

	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end
	local Ball = Folder:WaitForChild("Part"):Clone()
	Ball.CFrame = HRP.Parent["Right Arm"].Gun.Pos.CFrame
	Ball.Position = HRP.Parent["Right Arm"].Gun.Pos.Position 
	Ball.Parent = vfxFolder
	Debris:AddItem(Ball,1/speed)
	task.wait(0.01/speed)

	local emitgun = HRP.Parent["Right Arm"].Gun.Pos
	VFX_Helper.EmitAllParticles(emitgun)
	TS:Create(Ball,TweenInfo.new(0.1/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	Ball.Transparency = 1
	VFX_Helper.OffAllParticles(Ball)

	HRP.Parent.Attacking.Value = false
end


return module
