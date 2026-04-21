local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
module["Scout Attack"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.Scout.First
	VFX_Helper.SoundPlay(HRP,Folder.First)
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.15/speed)
	local HRPCF = HRP.CFrame
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local direction = HRPCF.LookVector
	local targetPosition = (HRPCF * CFrame.new(0, 0, -Range)).Position
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end

	local Ball = Folder:WaitForChild("Ball"):Clone()
	Ball.Trail.Color = ColorSequence.new(Color3.fromRGB(255,0,0))
	Ball.CFrame = HRP.Parent["Right Arm"].Point.CFrame
	Ball.Position = HRP.Parent["Right Arm"].Point.Position
	Ball.Parent = vfxFolder
	Debris:AddItem(Ball,1/speed)
	TS:Create(Ball,TweenInfo.new(0.13/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	task.wait(0.13/speed)
	if not HRP or not HRP.Parent then return end
	Ball.Transparency = 1
	HRP.Parent.Attacking.Value = false
end

return module
