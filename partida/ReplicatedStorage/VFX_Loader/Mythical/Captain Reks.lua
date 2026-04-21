local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed

module["Captain Reks Attack"] = function(HRP, target)
	local Folder = VFX["Captain Reks"].First
	local speed = GameSpeed.Value

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	local HRPCF = HRP.CFrame
	if not HRP or not HRP.Parent then return end
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local direction = HRPCF.LookVector
	
	task.wait(0.45/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.SoundPlay(HRP,Folder.First)
	local targetPosition = (HRPCF * CFrame.new(0, 0, -Range)).Position
	
	local Ball = Folder:WaitForChild("Ball"):Clone()
	Ball.CFrame = HRP.Parent["Right Arm"].gun.Point.CFrame
	Ball.Position = HRP.Parent["Right Arm"].gun.Point.Position 
	Ball.Parent = vfxFolder
	Debris:AddItem(Ball,1/speed)
	task.wait(0.01/speed)

	local emitgun = HRP.Parent["Right Arm"].gun.Point
	VFX_Helper.EmitAllParticles(emitgun)
	TS:Create(Ball,TweenInfo.new(0.1/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	Ball.Transparency = 1
	VFX_Helper.OffAllParticles(Ball)

	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end

	local Secondball = Folder:WaitForChild("Ball"):Clone()
	Secondball.CFrame = HRP.Parent["Left Arm"].gun2.Point2.CFrame
	Secondball.Position = HRP.Parent["Left Arm"].gun2.Point2.Position
	Secondball.Parent = vfxFolder
	Debris:AddItem(Secondball,1/speed)
	task.wait(0.01/speed)

	local SecondEmit = HRP.Parent["Left Arm"].gun2.Point2
	VFX_Helper.EmitAllParticles(SecondEmit)
	TS:Create(Secondball,TweenInfo.new(0.1/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	Secondball.Transparency = 1
	VFX_Helper.OffAllParticles(Secondball)

	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end
	
	local Thrball = Folder:WaitForChild("Ball"):Clone()
	Thrball.CFrame = HRP.Parent["Right Arm"].gun.Point.CFrame
	Thrball.Position = HRP.Parent["Right Arm"].gun.Point.Position 
	Thrball.Parent = vfxFolder
	Debris:AddItem(Thrball,1/speed)
	task.wait(0.01/speed)
	VFX_Helper.EmitAllParticles(emitgun)
	TS:Create(Thrball,TweenInfo.new(0.1/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	Thrball.Transparency = 1
	VFX_Helper.OffAllParticles(Thrball)

	HRP.Parent.Attacking.Value = false
end


module["Hurricane Blaster"] = function(HRP, target)
	local Folder = VFX["Captain Reks"].Second
	local speed = GameSpeed.Value

	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	VFX_Helper.SoundPlay(HRP,Folder.First)
	task.wait(0.45/speed)
	if not HRP or not HRP.Parent then return end

	local Range = HRP.Parent.Config:WaitForChild("Range").Value

	local rightGun = HRP.Parent["Right Arm"].gun.Point
	local leftGun = HRP.Parent["Left Arm"].gun2.Point2

	for i = 1, 50 do
		if not HRP or not HRP.Parent then return end 

		local isRight = (i % 2 == 1) 
		local gunPoint = isRight and rightGun or leftGun

		local Ball = Folder:WaitForChild("Ball"):Clone()
		Ball.CFrame = gunPoint.CFrame 
		Ball.Parent = vfxFolder
		Debris:AddItem(Ball, 1)
		task.wait(0.01/speed)
		VFX_Helper.EmitAllParticles(gunPoint)

		local forwardPosition = Ball.CFrame * CFrame.new(0, 0, -Range)

		TS:Create(Ball, TweenInfo.new(0.1/speed, Enum.EasingStyle.Linear), {CFrame = forwardPosition}):Play()

		task.wait(0.06/speed)
		if not HRP or not HRP.Parent then return end
		task.spawn(function()
			task.wait(0.05/speed)
			Ball.Transparency = 1
			VFX_Helper.OffAllParticles(Ball)
		end)
		

		if not HRP or not HRP.Parent then return end
	end

	HRP.Parent.Attacking.Value = false
end

module["Double Squall"] = function(HRP, target)
	local Folder = VFX["Captain Reks"].Thrid
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.45 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	task.wait(0.45 / speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.SoundPlay(HRP,Folder.First)

	local rightGunEmit = HRP.Parent["Right Arm"].gun.Point
	local leftGunEmit = HRP.Parent["Left Arm"].gun2.Point2

	local RightBall = Folder:WaitForChild("Ball"):Clone()
	RightBall.CFrame = rightGunEmit.CFrame
	RightBall.Position = rightGunEmit.Position
	RightBall.Parent = vfxFolder
	Debris:AddItem(RightBall, 1 / speed)

	local LeftBall = Folder:WaitForChild("Ball"):Clone()
	LeftBall.CFrame = leftGunEmit.CFrame
	LeftBall.Position = leftGunEmit.Position
	LeftBall.Parent = vfxFolder
	Debris:AddItem(LeftBall, 1 / speed)
	VFX_Helper.EmitAllParticles(HRP.Parent["Right Arm"].gun.Point)
	VFX_Helper.EmitAllParticles(HRP.Parent["Left Arm"].gun2.Point2)
	task.wait(0.01)
	TS:Create(RightBall, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {Position = enemypos + Vector3.new(0,-1,0)}):Play()
	TS:Create(LeftBall, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {Position = enemypos + Vector3.new(0,-1,0)}):Play()

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end
	local explosion = Folder:WaitForChild("Explosion"):Clone()
	explosion.Position = enemypos + Vector3.new(0,-0.7,0)
	explosion.Parent = vfxFolder
	Debris:AddItem(explosion,3)
	VFX_Helper.EmitAllParticles(explosion)
	RightBall.Transparency = 1
	LeftBall.Transparency = 1
	VFX_Helper.OffAllParticles(RightBall)
	VFX_Helper.OffAllParticles(LeftBall)


	HRP.Parent.Attacking.Value = false
end



return module
