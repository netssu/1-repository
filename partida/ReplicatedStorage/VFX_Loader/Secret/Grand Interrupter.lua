local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace
local grandInquisitorVFX = VFX["Grand Inquisitor"]

local module = {}

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
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

local function getStageEffect(folder, effectName)
	if not folder then return nil end
	return folder:FindFirstChild(effectName)
end

module["Saber Throw"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = grandInquisitorVFX:FindFirstChild("First")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = true
	end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Rockets' .. tostring(math.random(1, 2)))

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local travelSpeed = 16 * speed
		local timeToTravel = getMag(HRP.Position, enemyPos) / travelSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, {Position = enemyPos})
		Debris:AddItem(clone, timeToTravel + (1.5 / speed))
	end

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = false
	end
end

module["Force Lightning"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = grandInquisitorVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = true
	end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Thunder1')

	local secondEffect = getStageEffect(Folder, "Second")
	if secondEffect then
		local clone = secondEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local travelSpeed = 16 * speed
		local timeToTravel = getMag(HRP.Position, enemyPos) / travelSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, {Position = enemyPos})
		Debris:AddItem(clone, timeToTravel + (1.5 / speed))
	end

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = false
	end
end

module["Jedai Explosion"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = grandInquisitorVFX:FindFirstChild("Third")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position

	task.wait(0.05 / speed)
	if not HRP or not HRP.Parent then return end

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = true
	end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')
	task.delay(0.05 / speed, function()
		if HRP and HRP.Parent then
			UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
		end
	end)

	local thirdEffect = getStageEffect(Folder, "Third")
	if thirdEffect then
		local clone = thirdEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local explosionSpeed = 3.5 * speed
		local timeToTravel = getMag(HRP.Position, enemyPos) / explosionSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, {Position = enemyPos})
		Debris:AddItem(clone, timeToTravel + (1.5 / speed))
	end

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = false
	end
end

return module