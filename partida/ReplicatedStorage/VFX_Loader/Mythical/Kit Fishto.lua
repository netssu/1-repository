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
local RunService = game:GetService("RunService")
local GameSpeed = workspace.Info.GameSpeed
local RocksModule = require(rs.Modules.RocksModule)


module["Jedi Fist attack"] = function(HRP, target)
	local Folder = VFX.MIF["Kit Fishto"].First
	local speed = GameSpeed.Value
	local Range = HRP.Parent.Config:WaitForChild("Range").Value

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	--VFX_Helper.SoundPlay(HRP,Folder.Second)
	
	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true
	
	task.wait(0.6/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	
	local slash = Folder:WaitForChild("Mainpart"):Clone()
	slash.CFrame = HRP.CFrame 
	slash.Parent = vfxFolder
	Debris:AddItem(slash,3/speed)

	local connection = HRP.Parent.Destroying:Once(function()
		slash:Destroy()
	end)

	task.wait(0.01/speed)
	if not HRP or not HRP.Parent then return end
	
	local targetPosition = ( HRP.CFrame * CFrame.new(0, 0, -Range))
	TS:Create(slash, TweenInfo.new(0.22/speed, Enum.EasingStyle.Linear), {CFrame = targetPosition}):Play()
	RocksModule.Trail(HRP.CFrame,HRP.CFrame.LookVector,Range,4.4,Vector3.new(0.3,0.5,0.3),0.02,0.05,0.4,true,6,1.5)

	VFX_Helper.EmitAllParticles(slash.Slash)

	task.wait(0.01/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(slash)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Punch' .. tostring(math.random(1,3)))
	task.wait(0.19/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(slash)
	for _,v in (slash:GetDescendants()) do	
		if v:IsA("Beam") then
			TS:Create(
				v,
				TweenInfo.new(0.4/speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Width0 = 0,Width1 = 0}
			):Play()
		end	
	end
	task.wait(1.2/speed)
	if not HRP or not HRP.Parent then return end
	
	connection:Disconnect()
	HRP.Parent.Attacking.Value = false
	handleR.Enabled = false
end


module["Force Surge"] = function(HRP, target)
	local Folder = VFX.MIF["Kit Fishto"].second
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true
	task.wait(0.78/speed)
	if not HRP or not HRP.Parent then return end
	local HRPCF = HRP.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	HRP.Parent.Attacking.Value = true

	local lych = Folder:WaitForChild("lych"):Clone()
	lych.Start.CFrame = HRP.Parent["Left Arm"].pos.CFrame
	lych.End.CFrame = HRP.Parent["Left Arm"].pos.CFrame
	lych.Parent = vfxFolder
	Debris:AddItem(lych, 4/speed)
	local connection = HRP.Parent.Destroying:Once(function()
		lych:Destroy()
	end)
	local targetPosition = ( HRP.CFrame * CFrame.new(0, -1, -Range))
	TS:Create(lych.End, TweenInfo.new(0.3/speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetPosition}):Play()
	VFX_Helper.OnAllParticles(lych.Start)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')
	task.wait(0.2/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OnAllParticles(lych.End)

	task.wait(0.9/speed)
	if not HRP or not HRP.Parent then return end
	for _,v in (lych:GetDescendants()) do	
		if v:IsA("Beam") then
			TS:Create(
				v,
				TweenInfo.new(0.5/speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Width0 = 0,Width1 = 0}
			):Play()
		end	
	end
	VFX_Helper.OffAllParticles(lych.End)
	VFX_Helper.OffAllParticles(lych.Start)

	task.wait(1/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
	handleR.Enabled = false
	connection:Disconnect()

end

module["Blade Rush"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.MIF["Kit Fishto"].Thrid
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true
	
	
	
	task.wait(0.75/speed)
	if not HRP or not HRP.Parent then return end
	
	local trail = Folder:WaitForChild("Trail"):Clone()
	trail.CFrame = HRP.CFrame
	trail.Parent = HRP
	Debris:AddItem(trail,3/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = trail
	weld.Parent = trail

	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local Emit = Folder:WaitForChild("Slash"):Clone()
	Emit.Parent = vfxFolder
	Emit:PivotTo(HRP.CFrame)
	Debris:AddItem(Emit, 4/speed)


	local connection = HRP.Parent.Destroying:Once(function()
		Emit:Destroy()
	end)
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing1')
	
	VFX_Helper.EmitAllParticles(Emit.slas1)
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	local targetCFrame = HRP.CFrame * CFrame.new(0, 0,-(Range - 1))
	TS:Create(HRP, TweenInfo.new(0.35/speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()
	VFX_Helper.OnAllParticles(Emit.Slashes)
	task.wait(0.3/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(Emit.Slashes)
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing2')
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(Emit.slash2)
	
	task.wait(0.7/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(trail)
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	VFX_Helper.EmitAllParticles(trail)
	
	handleR.Enabled = false
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end

return module
