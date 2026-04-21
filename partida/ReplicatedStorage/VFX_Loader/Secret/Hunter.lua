local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace
local hunterVFX = VFX.Hunter

local module = {}

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

local function emitEffect(effect, parent, cleanupTime)
	if not effect then return end
	effect.Parent = parent or vfxFolder
	Debris:AddItem(effect, cleanupTime)
	VFX_Helper.EmitAllParticles(effect)
end

local function getStageEffect(folder, effectName)
	if not folder then return nil end
	return folder:FindFirstChild(effectName)
end

local function setEffectCFrame(effect, cf)
	if not effect or not cf then return effect end
	if effect:IsA("Model") then
		effect:PivotTo(cf)
	elseif effect:IsA("BasePart") then
		effect.CFrame = cf
	end
	return effect
end

module["Pistol"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = hunterVFX:FindFirstChild("First")
	local speed = GameSpeed.Value

	task.wait(0.3 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true

	local rightArm = HRP.Parent:FindFirstChild("Right Arm")
	if not rightArm then return end

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone.Anchored = false
		clone = setEffectCFrame(clone, rightArm.CFrame * CFrame.new(0, -0.5, -0.6) * CFrame.Angles(0, math.rad(-90), 0))
		clone.Parent = HRP.Parent

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = rightArm
		weld.Part1 = clone
		weld.Parent = clone

		UnitSoundEffectLib.playSound(HRP.Parent, 'Blaster' .. tostring(math.random(1, 3)))
		VFX_Helper.EmitAllParticles(clone)

		Debris:AddItem(clone, 0.4 / speed)
	end

	HRP.Parent.Attacking.Value = false
end

module["Electro Grenades"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = hunterVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true

	local RightArm = HRP.Parent:FindFirstChild("Right Arm")
	if not RightArm then return end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Flamethrower')

	local secondEffect = getStageEffect(Folder, "Second")
	if secondEffect then
		local clone = secondEffect:Clone()
		clone.Anchored = true
		clone = setEffectCFrame(clone, RightArm.CFrame)
		clone.Orientation += Vector3.new(0, -90, 0)
		clone.Parent = vfxFolder

		local travelSpeed = 12 * speed
		local timeToTravel = getMag(RightArm.Position, enemyPos) / travelSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, {Position = enemyPos})

		task.delay(timeToTravel, function()
			if HRP and HRP.Parent then
				UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
			end
		end)

		Debris:AddItem(clone, timeToTravel + (1.5 / speed))
	end

	HRP.Parent.Attacking.Value = false
end

module["Vibro Knife Throw"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = hunterVFX:FindFirstChild("Third")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	local RightArm = HRP.Parent:FindFirstChild("Right Arm")
	if not RightArm then return end

	HRP.Parent.Attacking.Value = true

	local thirdEffect = getStageEffect(Folder, "Third")
	if thirdEffect then
		local numberOfKnives = 3
		local spacing = 0.25
		local travelSpeed = 12 * speed
		local timeToTravel = getMag(RightArm.Position, enemyPos) / travelSpeed

		for i = 1, numberOfKnives do
			UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1, 2)))

			local clone = thirdEffect:Clone()
			clone.Anchored = true
			clone = setEffectCFrame(clone, RightArm.CFrame * CFrame.new((i - 2) * spacing, 0, 0))
			clone.Orientation += Vector3.new(0, -90, 0)
			clone.Parent = vfxFolder

			VFX_Helper.EmitAllParticles(clone)
			tween(clone, timeToTravel, {Position = enemyPos})

			Debris:AddItem(clone, timeToTravel + (1.5 / speed))
		end
	end

	HRP.Parent.Attacking.Value = false
end

return module