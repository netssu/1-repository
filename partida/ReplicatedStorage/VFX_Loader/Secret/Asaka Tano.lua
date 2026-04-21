local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local module = {}
local rs = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX
local asakaTanoVFX = VFX["Asaka Tano"]

local function emitEffect(effect, parent, cleanupTime)
	if not effect then
		return
	end

	effect.Parent = parent or vfxFolder
	Debris:AddItem(effect, cleanupTime)
	VFX_Helper.EmitAllParticles(effect)
end

local function getStageFolder(stageName)
	return asakaTanoVFX:FindFirstChild(stageName) or (stageName == "Third" and asakaTanoVFX:FindFirstChild("Thrid"))
end

local function getStageEffect(folder, ...)
	if not folder then
		return nil
	end

	for _, name in ipairs({ ... }) do
		local child = folder:FindFirstChild(name)
		if child and not child:IsA("Sound") then
			return child
		end
	end

	for _, child in ipairs(folder:GetChildren()) do
		if not child:IsA("Sound") then
			return child
		end
	end

	return nil
end

local function setEffectCFrame(effect, cf)
	if not effect or not cf then
		return effect
	end

	local root = effect

	if effect:IsA("Model") then
		effect:PivotTo(cf)
	elseif effect:IsA("BasePart") then
		effect.CFrame = cf
	elseif effect:IsA("Attachment") then
		local holder = Instance.new("Part")
		holder.Name = effect.Name .. "_Holder"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(1, 1, 1)
		holder.CFrame = cf
		effect.Parent = holder
		root = holder
	end

	return root
end

local function emitStage(stageName, HRP, target, waitTime, cleanupTime, offset)
	local folder = getStageFolder(stageName)
	local speed = GameSpeed.Value

	task.wait(waitTime / speed)
	if not HRP or not HRP.Parent then
		return
	end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, "Slices1")
	UnitSoundEffectLib.playSound(HRP.Parent, "SaberSwing" .. tostring(math.random(1, 2)))

	local effect = getStageEffect(folder, stageName)
	if effect then
		effect = effect:Clone()

		local targetCFrame = HRP.CFrame
		if target and target:FindFirstChild("HumanoidRootPart") then
			targetCFrame = CFrame.new(target.HumanoidRootPart.Position)
		end

		effect = setEffectCFrame(effect, targetCFrame * (offset or CFrame.new()))
		emitEffect(effect, vfxFolder, cleanupTime / speed)
	end

	HRP.Parent.Attacking.Value = false
end

module["Cross Slash"] = function(HRP, target)
	emitStage("First", HRP, target, 0.1, 2, CFrame.new(0, 0, 0))
end

module["First Slash"] = function(HRP, target)
	emitStage("First", HRP, target, 0.1, 2, CFrame.new(0, 0, 0))
end

module["Vortex Strike"] = function(HRP, target)
	emitStage("Second", HRP, target, 0.1, 3, CFrame.new(0, 0.3, 0))
end

module["Saber Flurry"] = function(HRP, target)
	emitStage("Second", HRP, target, 0.1, 3, CFrame.new(0, 0.3, 0))
end

module["Circle of Light"] = function(HRP, target)
	emitStage("Third", HRP, target, 0.1, 7, CFrame.new())
end

return module
