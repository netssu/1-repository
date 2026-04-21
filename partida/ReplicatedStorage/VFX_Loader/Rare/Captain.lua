local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
module["Air Shot"] = function(HRP)
	local speed = GameSpeed.Value
	local Folder = VFX.Scout.First
	local GunPoint = HRP.Parent["Right Arm"].Gun.Point

	task.wait(1 / speed)
	
	VFX_Helper.SoundPlay(HRP, Folder.First)


	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local Ball = Folder:WaitForChild("Ball"):Clone()
	Ball.CFrame = GunPoint.CFrame
	Ball.Position = GunPoint.Position
	Ball.Parent = vfxFolder
	Debris:AddItem(Ball, 1 / speed)

	local targetPosition = HRP.Position + Vector3.new(0, 10, 0)

	TS:Create(Ball, TweenInfo.new(0.13 / speed, Enum.EasingStyle.Linear), {
		Position = targetPosition
	}):Play()
	
	task.wait(0.1)

	if not HRP or not HRP.Parent then return end
	Ball.Transparency = 1
	HRP.Parent.Attacking.Value = false
end

return module
