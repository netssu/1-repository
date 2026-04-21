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

function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end



module["Sword Throw"] = function(HRP, target)
	local Folder = VFX.MIF["Mace Vindy"].thrid
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local handlePos = HRP.Parent["Right Arm"].Handle
	local handleR = handlePos.Trail
	local handleRR = handlePos.TrailL
	local handleRRR = handlePos.TrailLP
	handleR.Enabled = true
	handleRR.Enabled = true
	handleRRR.Enabled = true

	local handleModel = Instance.new("Model")
	handleModel.Name = "SwordClone"
	handleModel.Parent = vfxFolder

	local Handle = handlePos:Clone()
	Handle.Anchored = true
	Handle.CanCollide = false
	Handle.Parent = handleModel

	for _, obj in handlePos.Parent:GetChildren() do
		if obj:IsA("BasePart") and obj ~= handlePos then
			if obj:FindFirstChildWhichIsA("WeldConstraint") or obj:FindFirstChildWhichIsA("Weld") then
				local partClone = obj:Clone()
				partClone.Anchored = true
				partClone.CanCollide = false
				partClone.Parent = handleModel
			end
		end
	end

	handleModel.PrimaryPart = Handle

	handlePos.Transparency = 1
	for _, part in handlePos:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end

	handleR.Enabled = false
	handleRR.Enabled = false
	handleRRR.Enabled = false

	local startPos = HRP.Position
	local lookCFrame = CFrame.new(startPos, enemypos)
	handleModel:SetPrimaryPartCFrame(lookCFrame * CFrame.Angles(0, math.rad(180), 0))

	Debris:AddItem(handleModel, 1.65 / speed)

	local connection = HRP.Parent.Destroying:Once(function()
		handleModel:Destroy()
	end)

	local distance = (enemypos - startPos).Magnitude
	local flyTime = 0.25 / speed
	local endPos = lookCFrame.Position + lookCFrame.LookVector * distance
	local endCFrame = CFrame.new(endPos, endPos + lookCFrame.LookVector) * CFrame.Angles(math.rad(-20), math.rad(180), 0)

	TS:Create(handleModel.PrimaryPart, TweenInfo.new(flyTime, Enum.EasingStyle.Linear), {
		CFrame = endCFrame + Vector3.new(0, -0.5, 0)
	}):Play()
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))
	local explosions = Folder:WaitForChild("Explosions"):Clone()
	explosions.Position = enemypos 
	explosions.Parent = HRP
	Debris:AddItem(explosions,3/speed)
	task.wait(0.25 / speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(explosions)
	task.wait(1.1 / speed)
	if not HRP or not HRP.Parent then return end
	TS:Create(handleModel.PrimaryPart, TweenInfo.new(0.3 / speed, Enum.EasingStyle.Linear), {
		CFrame = handlePos.CFrame
	}):Play()
	task.wait(0.3 / speed)

	handlePos.Transparency = 0
	for _, part in handlePos:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end

	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end


module["Blade Descent"] = function(HRP, target)
	local Folder = VFX.MIF["Mace Vindy"].First
	local speed = GameSpeed.Value
	local Range = HRP.Parent.Config:WaitForChild("Range").Value

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	--VFX_Helper.SoundPlay(HRP,Folder.Second)
	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true

	task.wait(0.45/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	
	local startemit = Folder:WaitForChild("Starteffect"):Clone()
	startemit.CFrame = HRP.CFrame + Vector3.new(0,-0.6,0)
	startemit.Parent = vfxFolder
	Debris:AddItem(startemit,2/speed)
	
	
	local End = CFrame.new(enemypos + Vector3.new(0,2,0))
	local Start	= HRP.CFrame
	local Middle = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,3,0) )
	local Middle2 = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,3,0))

	local slash = Folder:WaitForChild("Slash"):Clone()
	slash.CFrame = HRP.CFrame
	slash.Parent = HRP
	Debris:AddItem(slash,2/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = slash
	weld.Parent = slash

	local trail = Folder:WaitForChild("taril"):Clone()
	trail.CFrame = HRP.CFrame
	trail.Parent = HRP
	Debris:AddItem(trail,2/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP
	weld.Part1 = trail
	weld.Parent = trail
	
	VFX_Helper.EmitAllParticles(startemit)

	for i = 1, 100, 4  do
		local t = i/100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, End.Position)
		HRP.CFrame = CFrame.new(NewPos, NewPos + Start.LookVector)
		task.wait(0.007/speed)
		if not HRP or not HRP.Parent then return end
	end
	
	VFX_Helper.EmitAllParticles(slash)
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))	
	
	local descentDirection = (End.Position - Start.Position).Unit
	local shiftedPosition = enemypos + descentDirection * 2 + Vector3.new(0, -1, 0)
	
	local endlemit = Folder:WaitForChild("Slam"):Clone()
	endlemit.Position = shiftedPosition 
	endlemit.Parent = vfxFolder
	Debris:AddItem(endlemit,3/speed)
	
	TS:Create(HRP, TweenInfo.new(0.07/speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(enemypos, enemypos + Start.LookVector) }):Play()
	VFX_Helper.EmitAllParticles(endlemit)
	task.wait(1/speed)
	if not HRP or not HRP.Parent then return end

	local teleposrSE = Folder:WaitForChild("teleport"):Clone()
	teleposrSE.CFrame = HRP.CFrame + Vector3.new(0,-0.5,0)
	teleposrSE.Parent = vfxFolder	
	Debris:AddItem(teleposrSE,1/speed)
	VFX_Helper.EmitAllParticles(teleposrSE)
	
	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	local teleposr = Folder:WaitForChild("teleport"):Clone()
	teleposr.CFrame = HRP.CFrame + Vector3.new(0,-0.5,0)
	teleposr.Parent = vfxFolder	
	Debris:AddItem(teleposr,1/speed)
	VFX_Helper.EmitAllParticles(teleposr)
	handleR.Enabled = false
	task.wait(1/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false

end


module["Stone Uplift"] = function(HRP, target)
	local Folder = VFX.MIF["Mace Vindy"].second
	local speed = GameSpeed.Value
	local Range = HRP.Parent.Config:WaitForChild("Range").Value

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local handleR = HRP.Parent["Right Arm"].Handle.Trail
	handleR.Enabled = true

	task.wait(0.95 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local rock = Folder:WaitForChild("Main"):Clone()
	rock.CFrame = CFrame.new(enemypos + Vector3.new(0, -9, 0)) 
	rock.Parent = vfxFolder
	Debris:AddItem(rock, 3/speed)

	local connection = HRP.Parent.Destroying:Once(function()
		rock:Destroy()
	end)
	local rockemit = Folder:WaitForChild("Ground"):Clone()
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')
	rockemit.Position = enemypos + Vector3.new(0,-1,0)
	rockemit.Parent = vfxFolder
	Debris:AddItem(rockemit, 5/speed)
	VFX_Helper.EmitAllParticles(rockemit)

	TS:Create(rock, TweenInfo.new(0.15/speed, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
		CFrame = rock.CFrame + Vector3.new(0, 10, 0)
	}):Play()


	handleR.Enabled = false
	task.wait(1.5/ speed)
	if not HRP or not HRP.Parent then return end
	

	TS:Create(rock, TweenInfo.new(0.3/speed, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		CFrame = rock.CFrame + Vector3.new(0, -11, 0)
	}):Play()
	
	local rockemitTwo = Folder:WaitForChild("Groundend"):Clone()
	rockemitTwo.Position = enemypos + Vector3.new(0,-1,0)
	rockemitTwo.Parent = vfxFolder
	Debris:AddItem(rockemitTwo, 2/speed)
	task.wait(0.15/speed)
	if not HRP or not HRP.Parent then return end
	VFX_Helper.EmitAllParticles(rockemitTwo)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

	HRP.Parent.Attacking.Value = false
	connection:Disconnect()

end



return module
