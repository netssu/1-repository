-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX

-- VARIABLES
local module = {}

-- FUNCTIONS
local function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end

local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

module["Dakar Guard Attack"] = function(HRP, target)
	local Folder = VFX["Dakar Guard"].First
	local speed = GameSpeed.Value or 1
	local characterModel = HRP.Parent

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local enemypos = Vector3.new(targetRoot.Position.X, HRP.Position.Y, targetRoot.Position.Z)

	task.wait(0.35/speed)
	if not HRP or not characterModel then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")
	if AttackingValue then AttackingValue.Value = true end

	local soundEffect = Folder:FindFirstChildWhichIsA("Sound")
	if soundEffect then VFX_Helper.SoundPlay(HRP, soundEffect) end

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	if not vfxContainer then return end

	local mainVFX = vfxContainer:Clone()

	local trailAttachment = mainVFX:FindFirstChild("TrailAttachment", true)
	local sword = characterModel:FindFirstChild("Right Arm") and characterModel["Right Arm"]:FindFirstChild("sword")

	if trailAttachment and sword then
		local trailWeld = Instance.new("WeldConstraint")
		trailWeld.Part0 = sword
		trailWeld.Part1 = trailAttachment.Parent
		trailWeld.Parent = trailAttachment.Parent
	end

	local Start = HRP.CFrame
	local Offset = (enemypos - HRP.Position).unit * -2
	local EndCFrame = CFrame.new(enemypos + Offset)

	local Middle = CFrame.new((Start.Position + EndCFrame.Position) / 2 + Vector3.new(0, 4, 0))
	local Middle2 = CFrame.new((Start.Position + EndCFrame.Position) / 2 + Vector3.new(0, 3, 0))

	local startRotation = HRP.CFrame - HRP.Position
	UnitSoundEffectLib.playSound(characterModel, 'Flamethrower')

	mainVFX.Parent = vfxFolder
	if mainVFX:IsA("Model") then
		mainVFX:PivotTo(HRP.CFrame + Vector3.new(0, -1, 0))
	else
		mainVFX.CFrame = HRP.CFrame + Vector3.new(0, -1, 0)
	end
	Debris:AddItem(mainVFX, 3/speed)

	emitParticles(mainVFX)

	for i = 1, 100, 4.3 do
		local t = i / 100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, EndCFrame.Position)
		HRP.CFrame = CFrame.fromMatrix(NewPos, startRotation.XVector, startRotation.YVector, startRotation.ZVector)
		task.wait(0.005/speed)
	end

	task.wait(0.88/speed)
	if not HRP or not characterModel then return end

	local endVFX = vfxContainer:Clone()
	endVFX.Parent = vfxFolder
	if endVFX:IsA("Model") then
		endVFX:PivotTo(HRP.CFrame + Vector3.new(0, -0.5, 0))
	else
		endVFX.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
	end
	Debris:AddItem(endVFX, 2/speed)

	emitParticles(endVFX)

	local towerBase = characterModel:FindFirstChild("TowerBasePart")
	if towerBase then HRP.CFrame = towerBase.CFrame end
	if AttackingValue then AttackingValue.Value = false end
end

module["Whirlwind Slash"] = function(HRP, target)
	local Folder = VFX["Dakar Guard"].Second
	local speed = GameSpeed.Value or 1
	local characterModel = HRP.Parent

	task.wait(0.35/speed)
	if not HRP or not characterModel then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")
	if AttackingValue then AttackingValue.Value = true end

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	if not vfxContainer then
		if AttackingValue then AttackingValue.Value = false end
		return
	end

	local AOEEmit = vfxContainer:Clone()

	if AOEEmit:IsA("Model") then
		AOEEmit:PivotTo(HRP.CFrame)
	else
		AOEEmit.CFrame = HRP.CFrame
	end

	AOEEmit.Parent = HRP
	Debris:AddItem(AOEEmit, 2.5/speed)

	emitParticles(AOEEmit)

	if AttackingValue then AttackingValue.Value = false end
end

-- INIT
return module