local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed

module["Hired Killer Attack"] = function(HRP, target)
	local Folder = VFX["Hired Killer"].First
	local speed = GameSpeed.Value

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.6/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.SoundPlay(HRP,Folder.Sound)
	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	local HRPCF = HRP.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local targetPosition = (HRPCF * CFrame.new(0, 0, -Range)).Position
	
	local Fire = Folder:WaitForChild("Fire"):Clone()
	Fire.CFrame = HRP.Parent["Left Arm"].Pos.CFrame
	Fire.Position = HRP.Parent["Left Arm"].Pos.Position 
	Fire.Parent = HRP
	Debris:AddItem(Fire,4/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP.Parent["Left Arm"].Pos
	weld.Part1 = Fire
	weld.Parent = Fire
	
	VFX_Helper.OnAllParticles(Fire)
	task.wait(1.8/speed)
	VFX_Helper.OffAllParticles(Fire)
	HRP.Parent.Attacking.Value = false
end


module["Storm Barrage"] = function(HRP, target)
	local Folder = VFX["Hired Killer"].Thrid
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.6/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.SoundPlay(HRP,Folder.Sound)

	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	for i = 1, 11 do
		if not HRP or not  HRP.Parent then return end

		local randomoffset = Vector3.new(math.random(-3.5,3.5),-1,math.random(-3.5,3.5))
		local readyrand = enemypos + randomoffset

		local rocket = Folder:WaitForChild("Rocket"):Clone()
		rocket.CFrame = HRP.Parent["Left Arm"].Pos.CFrame
		rocket.Position = HRP.Parent["Left Arm"].Pos.Position
		rocket.Parent = vfxFolder
		Debris:AddItem(rocket,2/speed)
		task.wait(0.012/speed)
		TS:Create(rocket,TweenInfo.new(0.2/speed,Enum.EasingStyle.Linear),{Position = readyrand}):Play()
		task.wait(0.1/speed)
		local Endlemit = Folder:WaitForChild("Explosion"):Clone()
		Endlemit.Position = readyrand + Vector3.new(0,-0.7,0)
		Endlemit.Parent = vfxFolder
		Debris:AddItem(Endlemit,2/speed)
		task.wait(0.02/speed)
		VFX_Helper.EmitAllParticles(Endlemit)
		VFX_Helper.OffAllParticles(rocket)
		rocket.Transparency = 1
	end

	HRP.Parent.Attacking.Value = false
end


module["Deadshot"] = function(HRP, target)
	local Folder = VFX["Hired Killer"].Second
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(1.15/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	local HRPCF = HRP.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	VFX_Helper.SoundPlay(HRP,Folder.Sound)

	local Ball = Folder:WaitForChild("Ball"):Clone()
	Ball.CFrame = HRP.Parent["Right Arm"].Handle.PosHandle.CFrame
	Ball.Position = HRP.Parent["Right Arm"].Handle.PosHandle.Position 
	Ball.Parent = vfxFolder
	Debris:AddItem(Ball,2/speed)
	task.wait(0.05/speed)
	TS:Create(Ball,TweenInfo.new(0.1/speed,Enum.EasingStyle.Linear),{Position = enemypos}):Play()
	task.wait(0.1/speed)
	local emit = Folder:WaitForChild("EndlEmit"):Clone()
	emit.Position = enemypos + Vector3.new(0,-1,0)
	emit.Parent = vfxFolder
	Debris:AddItem(emit,3/speed)
	VFX_Helper.EmitAllParticles(emit)
	VFX_Helper.OffAllParticles(Ball)
	Ball.Transparency = 1
	HRP.Parent.Attacking.Value = false
end



return module
