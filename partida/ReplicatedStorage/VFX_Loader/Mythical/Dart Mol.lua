-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX
local dartMolVFX = VFX["Dart Mol"]

local module = {}

-- FUNCTIONS
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

	-- Pega diretamente a Part principal pelo nome
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
module["Dart Mol Attack"] = function(HRP, target)
	local Folder = dartMolVFX:FindFirstChild("First")
	local speed = GameSpeed.Value

	task.wait(0.78 / speed)
	if not HRP or not HRP.Parent then
		return
	end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, "SaberSwing" .. tostring(math.random(1, 2)))

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame * CFrame.new(0.5, 0.8, -1.4))
		emitEffect(clone, vfxFolder, 3 / speed)
	end

	HRP.Parent.Attacking.Value = false
end

module["Blades of Darkness"] = function(HRP, target)
	local Folder = dartMolVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value

	task.wait(0.5 / speed)
	if not HRP or not HRP.Parent then
		return
	end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, "SaberSwing" .. tostring(math.random(1, 2)))

	local secondEffect = getStageEffect(Folder, "Second")
	if target and target:FindFirstChild("HumanoidRootPart") then
		if secondEffect then
			local clone = secondEffect:Clone()
			clone = setEffectCFrame(clone, CFrame.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z))
			emitEffect(clone, vfxFolder, 4 / speed)
		end
	elseif secondEffect then
		local clone = secondEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		emitEffect(clone, vfxFolder, 4 / speed)
	end

	HRP.Parent.Attacking.Value = false
end

module["Ship Crash"] = function(HRP, target)
	local Folder = dartMolVFX:FindFirstChild("Third") 
	local speed = GameSpeed.Value

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then
		return
	end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, "SaberSwing" .. tostring(math.random(1, 2)))

	if target and target:FindFirstChild("HumanoidRootPart") then
		local thirdEffect = getStageEffect(Folder, "Third")
		if thirdEffect then
			local clone = thirdEffect:Clone()
			clone = setEffectCFrame(
				clone,
				CFrame.new(
					HRP.Position - HRP.CFrame.LookVector * 20 + Vector3.new(0, 90, 0),
					target.HumanoidRootPart.Position
				)
			)
			emitEffect(clone, vfxFolder, 4 / speed)
		end

		UnitSoundEffectLib.playSound(HRP.Parent, "Explosion")
	end

	HRP.Parent.Attacking.Value = false
end

return module