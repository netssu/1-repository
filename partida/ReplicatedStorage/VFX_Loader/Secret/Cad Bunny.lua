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

function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end


module["Easter Shot"] = function(HRP, target)
	local Folder = VFX.MIF["Bounty Bunny"].First
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	task.wait(0.92 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	 VFX_Helper.SoundPlay(HRP, Folder.Sound)

	local Ball1 = Folder:WaitForChild("eggs1"):Clone()
	local randomoffset1 = Vector3.new(math.random(-2, 2), -1, math.random(-2, 2))
	local readyrand1 = enemypos + randomoffset1
	Ball1.CFrame = HRP.Parent["Left Arm"].Gun.Pos.CFrame
	Ball1.Position = HRP.Parent["Left Arm"].Gun.Pos.Position
	Ball1.Parent = vfxFolder
	Debris:AddItem(Ball1, 2 / speed)
	task.wait(0.001 / speed)
	
	local targetCFrame1 = CFrame.new(readyrand1)
	TS:Create(Ball1, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame1}):Play()
	task.wait(0.085 / speed)

	if not HRP or not HRP.Parent then return end
	local Endlemit1 = Folder:WaitForChild("Explosion_blue1"):Clone()
	Endlemit1.Position = readyrand1 + Vector3.new(0, 0.23, 0)
	Endlemit1.Parent = vfxFolder
	Debris:AddItem(Endlemit1, 2 / speed)
	VFX_Helper.EmitAllParticles(Endlemit1)
	UnitSoundEffectLib.playSound(HRP.Parent, 'EliteBlaster1')
	Ball1.eggs.Transparency = 1

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end

	local Ball2 = Folder:WaitForChild("eggs2"):Clone()
	local randomoffset2 = Vector3.new(math.random(-4, 4), -1, math.random(-4, 4))
	local readyrand2 = enemypos + randomoffset2
	Ball2.CFrame = HRP.Parent["Left Arm"].Gun.Pos.CFrame
	Ball2.Position = HRP.Parent["Left Arm"].Gun.Pos.Position
	Ball2.Parent = vfxFolder
	Debris:AddItem(Ball2, 2 / speed)
	task.wait(0.001 / speed)

	local targetCFrame2 = CFrame.new(readyrand2)
	TS:Create(Ball2, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame2}):Play()
	task.wait(0.085 / speed)

	if not HRP or not HRP.Parent then return end
	local Endlemit2 = Folder:WaitForChild("Explosion_yellou2"):Clone()
	Endlemit2.Position = readyrand2 + Vector3.new(0, 0.23, 0)
	Endlemit2.Parent = vfxFolder
	Debris:AddItem(Endlemit2, 2 / speed)
	VFX_Helper.EmitAllParticles(Endlemit2)
	Ball2.Cylinder.Transparency = 1

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end

	local Ball3 = Folder:WaitForChild("eggs3"):Clone()
	local randomoffset3 = Vector3.new(math.random(-3, 3), -1, math.random(-3, 3))
	local readyrand3 = enemypos + randomoffset3
	Ball3.CFrame = HRP.Parent["Left Arm"].Gun.Pos.CFrame
	Ball3.Position = HRP.Parent["Left Arm"].Gun.Pos.Position
	Ball3.Parent = vfxFolder
	Debris:AddItem(Ball3, 2 / speed)
	task.wait(0.001 / speed)

	local targetCFrame3 = CFrame.new(readyrand3)
	TS:Create(Ball3, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame3}):Play()
	task.wait(0.085 / speed)

	if not HRP or not HRP.Parent then return end
	local Endlemit3 = Folder:WaitForChild("Explosion_bereza"):Clone()
	Endlemit3.Position = readyrand3 + Vector3.new(0, 0.23, 0)
	Endlemit3.Parent = vfxFolder
	Debris:AddItem(Endlemit3, 2 / speed)
	VFX_Helper.EmitAllParticles(Endlemit3)
	Ball3.Cylinder.Transparency = 1

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

module["Bunny Boom"] = function(HRP, target)
	local Folder = VFX.MIF["Bounty Bunny"].second
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.35 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local kosharPos = HRP.Parent["Right Arm"].koshar


	local handleModel = Instance.new("Model")
	handleModel.Name = "SwordClone"
	handleModel.Parent = vfxFolder
	Debris:AddItem(handleModel,0.88 / speed)
	local kosharCopy = kosharPos:Clone()
	kosharCopy.Anchored = true
	kosharCopy.CanCollide = false
	kosharCopy.Parent = handleModel
	UnitSoundEffectLib.playSound(HRP.Parent, 'Rockets' .. tostring(math.random(1,2)))

	for _, obj in kosharPos.Parent:GetChildren() do
		if obj:IsA("BasePart") and obj ~= kosharPos then
			if obj:FindFirstChildWhichIsA("WeldConstraint") or obj:FindFirstChildWhichIsA("Weld") then
				local partClone = obj:Clone()
				partClone.Anchored = true
				partClone.CanCollide = false
				partClone.Parent = handleModel
			end
		end
	end
	
	handleModel.PrimaryPart = kosharCopy

	kosharPos.Transparency = 1
	for _, part in kosharPos:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	local startPos = HRP.Position
	local lookCFrame = CFrame.new(startPos, enemypos)
	handleModel:SetPrimaryPartCFrame(lookCFrame)

	

	local connection = HRP.Parent.Destroying:Once(function()
		handleModel:Destroy()
	end)

	local distance = (enemypos - startPos).Magnitude
	local endPos = lookCFrame.Position + lookCFrame.LookVector * distance
	local endCFrame = CFrame.new(endPos, endPos + lookCFrame.LookVector) * CFrame.Angles(0,0, 0)

	local End = CFrame.new(endCFrame.Position + Vector3.new(0, -0.5, 0))
	local Start	= HRP.CFrame
	local Middle = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,4,0) )
	local Middle2 = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,4,0))
	VFX_Helper.SoundPlay(HRP, Folder.Sound)

	for i = 1, 100, 4 do
		local t = i / 100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, End.Position)

		if not HRP or not HRP.Parent or not handleModel or not handleModel.PrimaryPart then
			
			return
		end

		handleModel:SetPrimaryPartCFrame(CFrame.new(NewPos))
		task.wait(0.01 / speed)
	end


	local explosions = Folder:WaitForChild("expolosions"):Clone()
	explosions.PrimaryPart = explosions:WaitForChild("mid")
	explosions:SetPrimaryPartCFrame(CFrame.new(enemypos + Vector3.new(0,-0.4,0) ))
	explosions.Parent = HRP
	Debris:AddItem(explosions, 3/speed)
	VFX_Helper.EmitAllParticles(explosions)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

	task.wait(1.5 / speed)
	if not HRP or not HRP.Parent then return end
	kosharPos.Transparency = 0
	for _, part in kosharPos:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end

	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end

module["Easter Boom"] = function(HRP, target)
	local Folder = VFX.MIF["Bounty Bunny"].thrid
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local EGGS = HRP.Parent["Torso"]:WaitForChild("egss")
	local RightArm = HRP.Parent:WaitForChild("Right Arm")

	EGGS.Transparency = 1

	local eggClone = EGGS:Clone()
	eggClone.Anchored = false
	eggClone.CanCollide = false
	eggClone.Transparency = 0
	eggClone.Parent = vfxFolder

	eggClone.Size = eggClone.Size + Vector3.new(0.223, 0.321, 0.224)
	local connection = HRP.Parent.Destroying:Once(function()
		eggClone:Destroy()
	end)


	local attach = Instance.new("Motor6D")
	attach.Part0 = RightArm
	attach.Part1 = eggClone
	attach.C0 = CFrame.new(0, -0.5, 0) 
	attach.Parent = RightArm

	task.wait(0.7 / speed)

	attach:Destroy()
	eggClone.Anchored = true

	local startPos = RightArm.Position
	local lookCFrame = CFrame.new(startPos, enemypos)
	local distance = (enemypos - startPos).Magnitude
	local endPos = lookCFrame.Position + lookCFrame.LookVector * distance
	local endCFrame = CFrame.new(endPos, endPos + lookCFrame.LookVector)
	local End = CFrame.new(endCFrame.Position + Vector3.new(0, -0.5, 0))
	local Start = CFrame.new(startPos)
	local Middle = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,4,0))
	local Middle2 = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0,4,0))
	VFX_Helper.SoundPlay(HRP, Folder.Sound)

	for i = 1, 100, 4 do
		local t = i / 100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, End.Position)
		eggClone.CFrame = CFrame.new(NewPos)
		task.wait(0.01 / speed)
		if not HRP or not HRP.Parent then return end
	end

	local explosions = Folder:WaitForChild("Explosion"):Clone()
	explosions.Position = enemypos 
	explosions.Parent = HRP
	Debris:AddItem(explosions, 3 / speed)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
	VFX_Helper.EmitAllParticles(explosions)

	eggClone:Destroy()

	task.wait(1.2 / speed)
	if not HRP or not HRP.Parent then return end
	EGGS.Transparency = 0

	HRP.Parent.Attacking.Value = false
	connection:Disconnect()

end

return module
