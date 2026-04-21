-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX
local dartRaivenVFX = VFX["Dart Raiven"]

local module = {}

-- FUNCTIONS
local function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end

local function emitEffect(effect, parent, cleanupTime)
	if not effect then
		return
	end

	effect.Parent = parent or vfxFolder
	Debris:AddItem(effect, cleanupTime)
	VFX_Helper.EmitAllParticles(effect)
end

local function getStageEffect(folder, effectName)
	if not folder then
		return nil
	end
	return folder:FindFirstChild(effectName)
end

local function setEffectCFrame(effect, cf)
	if not effect or not cf then
		return effect
	end

	if effect:IsA("Model") then
		effect:PivotTo(cf)
	elseif effect:IsA("BasePart") then
		effect.CFrame = cf
	end

	return effect
end

-- INIT
module["Whirlwind of Darkness"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = dartRaivenVFX:FindFirstChild("Firsrt")
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.45 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, CFrame.new(enemypos))
		emitEffect(clone, vfxFolder, 4 / speed)
	end

	local enemyCFrame = CFrame.new(enemypos) * CFrame.Angles(HRP.CFrame:ToEulerAnglesXYZ())
	TweenService:Create(HRP, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = enemyCFrame + enemyCFrame.LookVector}):Play()
	task.wait(0.1 / speed)

	if not HRP or not HRP.Parent then return end

	for i = 1, 11 do
		if not HRP or not HRP.Parent then return end
		local randomOffset = Vector3.new(math.random(-6, 6), math.random(-1, 1), math.random(-6, 6))
		local randomPos = enemypos + randomOffset
		HRP.CFrame = CFrame.new(randomPos)
		task.wait(1.5 / 10 / speed) 
	end

	HRP.CFrame = CFrame.new(enemypos + Vector3.new(0, 0, -2))
	task.wait(0.75 / speed)

	if not HRP or not HRP.Parent then return end

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	HRP.Parent.Attacking.Value = false
end

module["Double Slash"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = dartRaivenVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing1')
	task.wait(0.8 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true

	local secondEffect = getStageEffect(Folder, "Second")
	if secondEffect then
		local clone = secondEffect:Clone()
		clone = setEffectCFrame(clone, CFrame.new(HRP.Position, enemypos))
		emitEffect(clone, vfxFolder, 3 / speed)
	end

	task.wait(0.16 / speed)
	if not HRP or not HRP.Parent then return end
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing2')

	task.wait(1.2 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = false
end

module["Doom Leap"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = dartRaivenVFX:FindFirstChild("thrid")
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.45 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing1')

	local End = CFrame.new(enemypos + Vector3.new(0, 2, 0))
	local Start = HRP.CFrame
	local Middle = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0, 5, 0))
	local Middle2 = CFrame.new((Start.Position + End.Position) / 2 + Vector3.new(0, 5, 0))

	task.spawn(function()
		task.wait(0.5 / speed)

		local thirdEffect = getStageEffect(Folder, "Third")
		if thirdEffect then
			local clone = thirdEffect:Clone()
			clone = setEffectCFrame(clone, CFrame.new(enemypos + Vector3.new(0, -0.5, 0)))
			emitEffect(clone, vfxFolder, 3 / speed)
		end
	end)

	for i = 1, 100, 5  do
		local t = i / 100
		local NewPos = cubicBezier(t, Start.Position, Middle.Position, Middle2.Position, End.Position)
		HRP.CFrame = CFrame.new(NewPos)
		task.wait(0.014 / speed)
	end

	TweenService:Create(HRP, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = CFrame.new(enemypos)}):Play()
	task.wait(1.2 / speed)

	if not HRP or not HRP.Parent then return end

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	HRP.Parent.Attacking.Value = false
end

return module