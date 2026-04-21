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
local GameSpeed = game.Workspace.Info.GameSpeed
local RocksModule = require(rs.Modules.RocksModule)

function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end


module["Dual Laceration"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.MIF["Lyk Skaivoker"].First
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true

	task.wait(0.65/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local Emit = Folder:WaitForChild("Slashes"):Clone()
	Emit.CFrame = HRP.CFrame
	Emit.Parent = HRP
	Debris:AddItem(Emit,4/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = Emit
	weld.Parent = Emit

	local connection = HRP.Parent.Destroying:Once(function()
		Emit:Destroy()
	end)

	local targetCFrame = HRP.CFrame * CFrame.new(0, 0, -Range)
	TS:Create(HRP, TweenInfo.new(0.15/speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()
	local trail = Folder:WaitForChild("emiterrrr"):Clone()
	trail.CFrame = HRP.CFrame
	trail.Parent = HRP
	Debris:AddItem(trail,1/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = trail
	weld.Parent = trail
	VFX_Helper.OnAllParticles(trail)
	task.wait(0.02/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(Emit.one)
	task.wait(0.07/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(Emit.twoo)

	task.wait(0.05/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(trail)

	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))

	task.wait(1/speed)
	if not HRP or not HRP.Parent then return end
	local teleposr = Folder:WaitForChild("teleport"):Clone()
	teleposr.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	teleposr.Parent = vfxFolder	
	Debris:AddItem(teleposr, 1/speed)
	VFX_Helper.EmitAllParticles(teleposr)
	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	local teleposttt = Folder:WaitForChild("teleport"):Clone()
	teleposttt.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	teleposttt.Parent = vfxFolder	
	Debris:AddItem(teleposttt, 1/speed)
	VFX_Helper.EmitAllParticles(teleposttt)
	handleR.Enabled = false
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end


module["Echo Strike"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.MIF["Lyk Skaivoker"].Firstgrenn
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true

	task.wait(0.65/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local Emit = Folder:WaitForChild("Slashes"):Clone()
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))
	Emit.CFrame = HRP.CFrame
	Emit.Parent = HRP
	Debris:AddItem(Emit,4/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = Emit
	weld.Parent = Emit

	local connection = HRP.Parent.Destroying:Once(function()
		Emit:Destroy()
	end)

	local targetCFrame = HRP.CFrame * CFrame.new(0, 0, -Range)
	TS:Create(HRP, TweenInfo.new(0.15/speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()
	local trail = Folder:WaitForChild("emiterrrr"):Clone()
	trail.CFrame = HRP.CFrame
	trail.Parent = HRP
	Debris:AddItem(trail,1/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = trail
	weld.Parent = trail
	VFX_Helper.OnAllParticles(trail)
	task.wait(0.02/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(Emit.one)
	task.wait(0.07/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(Emit.twoo)

	task.wait(0.05/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(trail)



	task.wait(1/speed)
	if not HRP or not HRP.Parent then return end
	local teleposr = Folder:WaitForChild("teleport"):Clone()
	teleposr.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	teleposr.Parent = vfxFolder	
	Debris:AddItem(teleposr, 1/speed)
	VFX_Helper.EmitAllParticles(teleposr)
	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	local teleposttt = Folder:WaitForChild("teleport"):Clone()
	teleposttt.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	teleposttt.Parent = vfxFolder	
	Debris:AddItem(teleposttt, 1/speed)
	VFX_Helper.EmitAllParticles(teleposttt)
	handleR.Enabled = false
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end


module["Boulder Toss"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.MIF["Lyk Skaivoker"].Second
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local Debris = game:GetService("Debris")
	local TS = game:GetService("TweenService")

	local handleR = HRP.Parent["Right Arm"].Handle.Trail

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end
	handleR.Enabled = true
	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	local originalCFrame = HRP.CFrame
	local backOffset = HRP.CFrame.LookVector * -5
	local backCFrame = originalCFrame + backOffset

	local trail = Folder:WaitForChild("emiterrrr"):Clone()
	trail.CFrame = HRP.CFrame
	trail.Parent = HRP
	Debris:AddItem(trail,3/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = trail
	weld.Parent = trail

	local startrock = Folder:WaitForChild("startemit"):Clone()
	startrock.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	startrock.Parent = vfxFolder	
	Debris:AddItem(startrock, 1/speed)

	local teleposttt = Folder:WaitForChild("teleport"):Clone()
	teleposttt.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	teleposttt.Parent = vfxFolder	
	Debris:AddItem(teleposttt, 1/speed)
	TS:Create(HRP, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = backCFrame}):Play()
	UnitSoundEffectLib.playSound(HRP.Parent, 'Punch' .. tostring(math.random(1,3)))

	VFX_Helper.EmitAllParticles(teleposttt)
	task.wait(0.11 / speed)
	if not HRP or not HRP.Parent then return end
	local lookVector = originalCFrame.LookVector
	local rockStartPos = originalCFrame.Position - Vector3.new(0, 6, 0)

	local downCFrame = CFrame.new(rockStartPos, rockStartPos - Vector3.new(0, 1, 0))

	local rock = Folder:WaitForChild("Rock"):Clone()
	rock.CFrame = downCFrame
	rock.Parent = HRP
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
	Debris:AddItem(rock, 1.9/speed) 


	local connection = HRP.Parent.Destroying:Once(function()
		rock:Destroy()
	end)

	local liftTargetPosition = rockStartPos + Vector3.new(0, 5.8, 0)
	local liftTargetCFrame = CFrame.new(liftTargetPosition, liftTargetPosition + lookVector)

	local liftTween = TS:Create(rock, TweenInfo.new(0.75 / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = liftTargetCFrame})
	liftTween:Play()
	VFX_Helper.EmitAllParticles(startrock)

	task.wait(0.75 / speed)
	if not HRP or not HRP.Parent then return end

	local handexplod = Folder:WaitForChild("Explosion 1"):Clone()
	handexplod.CFrame = HRP.CFrame * CFrame.new(0, 0, -1.6)
	handexplod.Parent = HRP
	Debris:AddItem(handexplod, 2 / speed)



	local flyDistance = Range + 500
	local flyTargetPos = liftTargetPosition + lookVector * flyDistance
	local flyTargetCFrame = CFrame.new(flyTargetPos, flyTargetPos + lookVector)

	local flyTween = TS:Create(rock, TweenInfo.new(1.4 / speed, Enum.EasingStyle.Linear), { CFrame = flyTargetCFrame})
	flyTween:Play()
	VFX_Helper.EmitAllParticles(handexplod)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
	VFX_Helper.OnAllParticles(rock)
	RocksModule.Trail(HRP.CFrame,HRP.CFrame.LookVector *3 ,flyDistance,5.1,Vector3.new(0.6,0.6,0.6),0.02,0.05,0.4,true,12,3)

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end
	local telepost = Folder:WaitForChild("teleport"):Clone()
	telepost.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	telepost.Parent = vfxFolder	
	Debris:AddItem(telepost, 1/speed)
	VFX_Helper.EmitAllParticles(telepost)

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	handleR.Enabled = false
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()

end

module["Force Boulder"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.MIF["Lyk Skaivoker"].Secondgrenn
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local Debris = game:GetService("Debris")
	local TS = game:GetService("TweenService")

	local handleR = HRP.Parent["Right Arm"].Handle.Trail

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end
	handleR.Enabled = true
	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	local originalCFrame = HRP.CFrame
	local backOffset = HRP.CFrame.LookVector * -5
	local backCFrame = originalCFrame + backOffset

	local trail = Folder:WaitForChild("emiterrrr"):Clone()
	trail.CFrame = HRP.CFrame
	trail.Parent = HRP
	Debris:AddItem(trail,3/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = trail
	weld.Parent = trail

	local startrock = Folder:WaitForChild("startemit"):Clone()
	startrock.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	startrock.Parent = vfxFolder	
	Debris:AddItem(startrock, 1/speed)

	local teleposttt = Folder:WaitForChild("teleport"):Clone()
	teleposttt.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	teleposttt.Parent = vfxFolder	
	Debris:AddItem(teleposttt, 1/speed)
	TS:Create(HRP, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = backCFrame}):Play()

	VFX_Helper.EmitAllParticles(teleposttt)
	task.wait(0.11 / speed)
	if not HRP or not HRP.Parent then return end
	local lookVector = originalCFrame.LookVector
	local rockStartPos = originalCFrame.Position - Vector3.new(0, 6, 0)

	local downCFrame = CFrame.new(rockStartPos, rockStartPos - Vector3.new(0, 1, 0))

	local rock = Folder:WaitForChild("Rock"):Clone()
	rock.CFrame = downCFrame
	rock.Parent = HRP
	Debris:AddItem(rock, 1.9/speed) 

	
	local connection = HRP.Parent.Destroying:Once(function()
		UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
		rock:Destroy()
	end)

	local liftTargetPosition = rockStartPos + Vector3.new(0, 5.8, 0)
	local liftTargetCFrame = CFrame.new(liftTargetPosition, liftTargetPosition + lookVector)

	local liftTween = TS:Create(rock, TweenInfo.new(0.75 / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = liftTargetCFrame})
	liftTween:Play()
	VFX_Helper.EmitAllParticles(startrock)

	task.wait(0.75 / speed)
	if not HRP or not HRP.Parent then return end

	local handexplod = Folder:WaitForChild("Explosion 1"):Clone()
	handexplod.CFrame = HRP.CFrame * CFrame.new(0, 0, -1.6)
	handexplod.Parent = HRP
	Debris:AddItem(handexplod, 2 / speed)



	local flyDistance = Range + 500
	local flyTargetPos = liftTargetPosition + lookVector * flyDistance
	local flyTargetCFrame = CFrame.new(flyTargetPos, flyTargetPos + lookVector)

	local flyTween = TS:Create(rock, TweenInfo.new(1.4 / speed, Enum.EasingStyle.Linear), { CFrame = flyTargetCFrame})
	flyTween:Play()
	VFX_Helper.EmitAllParticles(handexplod)
	VFX_Helper.OnAllParticles(rock)
	RocksModule.Trail(HRP.CFrame,HRP.CFrame.LookVector *3 ,flyDistance,5.1,Vector3.new(0.6,0.6,0.6),0.02,0.05,0.4,true,12,3)

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end
	local telepost = Folder:WaitForChild("teleport"):Clone()
	telepost.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	telepost.Parent = vfxFolder	
	Debris:AddItem(telepost, 1/speed)
	VFX_Helper.EmitAllParticles(telepost)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	handleR.Enabled = false
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()

end

module["Lightsaber Barrage"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.MIF["Lyk Skaivoker"].thrid
	--VFX_Helper.SoundPlay(HRP,Folder.First)
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	local Range = HRP.Parent.Config:WaitForChild("Range").Value

	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end

	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true

	local trail = Folder:WaitForChild("emiterrrr"):Clone()
	trail.CFrame = HRP.CFrame
	trail.Parent = HRP
	Debris:AddItem(trail,2/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = trail
	weld.Parent = trail
	task.wait(0.25/speed)
	if not HRP or not HRP.Parent then return end

	task.wait(0.2/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	--local starsemit = Folder:WaitForChild("teleport"):Clone()
	--starsemit.Position = HRP.Position
	--starsemit.Parent = HRP.Parent
	--VFX_Helper.EmitAllParticles(starsemit)
	--Debris:AddItem(starsemit,2/speed)

	local End = CFrame.new(enemypos + Vector3.new(0,0.25,0))
	local Start	= HRP.CFrame
	local Middle = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,3,0) )
	local Middle2 = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,3,0))

	VFX_Helper.OnAllParticles(trail)
	for i = 1, 100, 5  do
		local t = i/100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, End.Position)
		HRP.CFrame = CFrame.new(NewPos)
		task.wait(0.014/speed)
	end
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))

	local slash = Folder:WaitForChild("Slash"):Clone()
	slash.Position = HRP.Position + Vector3.new(0,-1.3,0)
	slash.Parent = HRP
	Debris:AddItem(slash,3/speed)
	VFX_Helper.OnAllParticles(slash)

	task.wait(0.2/speed)	

	local points = {}
	local center = HRP.Position

	for i = 1, 30 do
		local angle = math.rad((360 / 18) * i)
		local radius = 6
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		local y = math.random(-0.8, 2)
		table.insert(points, center + Vector3.new(x, y, z))
	end

	for i = 1, #points do
		if not HRP or not HRP.Parent then return end
		HRP.CFrame = CFrame.new(points[i])
		task.wait(1.4 / #points / speed)
	end

	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(slash)
	task.wait(0.35/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(trail)

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	local teleposrrr = Folder:WaitForChild("teleport"):Clone()
	teleposrrr.CFrame = HRP.CFrame + Vector3.new(0,-0.5,0)
	teleposrrr.Parent = vfxFolder	
	Debris:AddItem(teleposrrr,1/speed)
	VFX_Helper.EmitAllParticles(teleposrrr)

	task.wait(1/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end
return module
