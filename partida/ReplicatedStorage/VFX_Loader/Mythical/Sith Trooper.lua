local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX
local sithTrooperVFX = VFX["Sith Trooper"]

local module = {}

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

module["Rocket Shot"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = sithTrooperVFX:FindFirstChild("First")
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.7 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	UnitSoundEffectLib.playSound(HRP.Parent, 'Rockets1')

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local startPos = HRP.Parent["Right Arm"].Gun.Pos.Position
		local lookAtPos = enemypos + Vector3.new(0, -1, 0)

		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, CFrame.lookAt(startPos, lookAtPos))
		clone.Parent = vfxFolder

		TweenService:Create(clone, TweenInfo.new(0.2 / speed, Enum.EasingStyle.Linear), {Position = lookAtPos}):Play()

		task.delay(0.2 / speed, function()
			emitEffect(clone, vfxFolder, 2 / speed)
			UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
		end)
	end

	task.wait(1)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

module["Alpha Strike"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = sithTrooperVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.65 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	task.wait(0.15 / speed)

	if not HRP or not HRP.Parent then return end

	local secondEffect = getStageEffect(Folder, "Second")

	for i = 1, 8 do
		if not HRP or not HRP.Parent then return end
		local randomoffset = Vector3.new(math.random(-5.5, 5.5), -1, math.random(-5.5, 5.5))
		local readyrand = enemypos + randomoffset

		if secondEffect then
			local clone = secondEffect:Clone()
			clone = setEffectCFrame(clone, HRP.Parent["Right Arm"].Gun.Pos.CFrame)
			clone.Parent = vfxFolder

			TweenService:Create(clone, TweenInfo.new(0.13 / speed, Enum.EasingStyle.Linear), {Position = readyrand}):Play()

			task.delay(0.13 / speed, function()
				emitEffect(clone, vfxFolder, 2 / speed)
				UnitSoundEffectLib.playSound(HRP.Parent, 'Blaster' .. tostring(math.random(1, 3)))
			end)
		end

		task.wait(0.1 / speed)
	end

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

module["High Energy Shot"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = sithTrooperVFX:FindFirstChild("Third")
	local speed = GameSpeed.Value
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	task.wait(0.75 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	task.wait(0.35 / speed)
	if not HRP or not HRP.Parent then return end

	local thirdEffect = getStageEffect(Folder, "Third")
	if thirdEffect then
		local startPos = HRP.Parent["Right Arm"].Gun.Pos.CFrame
		local lookAtPos = CFrame.new(enemypos + Vector3.new(0, -1, 0))

		local clone = thirdEffect:Clone()
		clone = setEffectCFrame(clone, startPos)
		clone.Parent = vfxFolder

		emitEffect(clone, vfxFolder, 4 / speed)
		UnitSoundEffectLib.playSound(HRP.Parent, 'EliteBlaster1')

		TweenService:Create(clone, TweenInfo.new(0.25 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = lookAtPos}):Play()
	end

	task.wait(2.3 / speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

return module