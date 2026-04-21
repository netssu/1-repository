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
local RocksModule = require(rs.Modules.RocksModule)

function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end
 
local function tween(obj, length, details)
	TS:Create(obj, TweenInfo.new(length), details):Play()
end
local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

module["Saber Throw"] = function(HRP, target)
	local Folder = VFX["Dart Mol"].First
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local speed = GameSpeed.Value

	task.wait(0.78/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local handlePos = HRP.Parent["Right Arm"].Handle
	local HRPCF = HRP.CFrame
	local startPosition = handlePos.Position 
	local targetPosition = HRPCF * CFrame.new(0, 0, -Range)

	VFX_Helper.Transparency(handlePos, 1)
	local emit = Folder:WaitForChild("Winnd"):Clone()
	emit.CFrame = HRP.CFrame * CFrame.new(0.5,0.8,-1.4)
	emit.Parent = vfxFolder
	Debris:AddItem(emit,3/speed)
	VFX_Helper.EmitAllParticles(emit)
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))
	local Handle: BasePart = handlePos:Clone()
	Handle.Anchored = true
	Handle.Parent = vfxFolder
	Debris:AddItem(Handle, 2.5/speed)
	VFX_Helper.OffAllParticles(handlePos)
	Handle.HandleM.Trail.Enabled = true
	Handle.HandleM.Trail2.Enabled = true
	for _, part in handlePos:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	VFX_Helper.OnAllParticles(Handle.HandleM.Part)
	VFX_Helper.OnAllParticles(Handle.HandleM.Part2)
	Handle.CFrame = HRPCF * CFrame.Angles(math.rad(90), 0, 0)
	local connection = HRP.Parent.Destroying:Once(function()
		Handle:Destroy()
	end)
	local fakeHandle = Handle:FindFirstChild("FakeHandleMotor")
	local function rotateChildren()
		for i = 1, 360, 10 do 
			if not HRP or not HRP.Parent then return end
			fakeHandle.Transform = CFrame.Angles(math.rad(i), math.rad(i), math.rad(i))
			task.wait(0.02/speed)
		end
		for i = 1, 360, 10 do 
			if not HRP or not HRP.Parent then return end
			fakeHandle.Transform = CFrame.Angles(math.rad(i), math.rad(i), math.rad(i))
			task.wait(0.02/speed)
		end
	end

	task.spawn(function()
		if not HRP or not HRP.Parent then return end
		rotateChildren()
	end)

	local tween = TS:Create(Handle, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {CFrame = targetPosition}):Play()
	task.wait(0.65/speed)
	if not HRP or not HRP.Parent then return end
	TS:Create(Handle, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {CFrame = handlePos.CFrame}):Play()
	task.wait(0.65/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.OffAllParticles(Handle.HandleM.Part)
	VFX_Helper.OffAllParticles(Handle.HandleM.Part2)

	Handle.HandleM.Trail.Enabled = false
	Handle.HandleM.Trail2.Enabled = false

	Handle.HandleM.Part.Transparency = 1
	Handle.HandleM.Part2.Transparency = 1

	handlePos.HandleM.Transparency = 0
	for _, part in handlePos:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end

	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end

module["Boulder Toss"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX["Tenth Brother"].Second
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local Debris = game:GetService("Debris")
	local TS = game:GetService("TweenService")


	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end
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
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

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
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()

end

module["Doom Leap"] = function(HRP, target)
	local Folder = VFX["Tenth Brother"].Third
	local speed = GameSpeed.Value
	local Range = HRP.Parent.Config:WaitForChild("Range").Value

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	--VFX_Helper.SoundPlay(HRP,Folder.Second)
	local trail = Folder:WaitForChild("Trail"):Clone()
	trail.CFrame = HRP.Parent["Right Arm"].Handle.CFrame * CFrame.Angles(0,math.rad(90),0)
	trail.Parent = vfxFolder
	Debris:AddItem(trail,2/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP.Parent["Right Arm"].Handle
	weld.Part1 = trail
	weld.Parent = trail
	
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local startemit = Folder:WaitForChild("Endlemit"):Clone()
	startemit.Position = HRP.Position
	startemit.Parent = vfxFolder
	Debris:AddItem(startemit,2/speed)
	VFX_Helper.EmitAllParticles(startemit)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')
	local End = CFrame.new(enemypos + Vector3.new(0,2,0))
	local Start	= HRP.CFrame
	local Middle = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,5,0) )
	local Middle2 = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,5,0))

	task.spawn(function()
		task.wait(0.5/speed)

		local Emit = Folder:WaitForChild("main"):Clone()
		Emit.Position = enemypos + Vector3.new(0,-0.5,0)
		Emit.Parent = vfxFolder
		Debris:AddItem(Emit,2/speed)
		VFX_Helper.EmitAllParticles(Emit)

	end)

	for i = 1, 100, 5  do
		local t = i/100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, End.Position)
		HRP.CFrame = CFrame.new(NewPos)
		task.wait(0.014/speed)
	end
	TS:Create(HRP, TweenInfo.new(0.1/speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(enemypos) }):Play()
	task.wait(1.2/speed)
	local teleposrSE = Folder:WaitForChild("Teleportbls"):Clone()
	teleposrSE.CFrame = HRP.CFrame + Vector3.new(0,-0.5,0)
	teleposrSE.Parent = vfxFolder	
	Debris:AddItem(teleposrSE,1/speed)
	VFX_Helper.EmitAllParticles(teleposrSE)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	local teleposr = Folder:WaitForChild("Teleportbls"):Clone()
	teleposr.CFrame = HRP.CFrame + Vector3.new(0,-0.5,0)
	teleposr.Parent = vfxFolder	
	Debris:AddItem(teleposr,1/speed)
	VFX_Helper.EmitAllParticles(teleposr)

	HRP.Parent.Attacking.Value = false

end


return module
