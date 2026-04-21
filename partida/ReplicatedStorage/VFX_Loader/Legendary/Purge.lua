-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace

-- VARIABLES
local VFX = ReplicatedStorage.VFX
local purgeVFX = VFX.Purge
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local module = {}

-- FUNCTIONS
local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, targetCFrame)
	if obj:IsA("Model") then
		if obj.PrimaryPart then
			TweenService:Create(obj.PrimaryPart, TweenInfo.new(length, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()
		else
			local cfValue = Instance.new("CFrameValue")
			cfValue.Value = obj:GetPivot()
			cfValue.Changed:Connect(function(newCf)
				obj:PivotTo(newCf)
			end)
			local tw = TweenService:Create(cfValue, TweenInfo.new(length, Enum.EasingStyle.Linear), {Value = targetCFrame})
			tw:Play()
			Debris:AddItem(cfValue, length + 0.1)
		end
	elseif obj:IsA("BasePart") then
		TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()
	end
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

-- INIT
module["Electric Blast"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = purgeVFX:FindFirstChild("First")
	local speed = GameSpeed.Value

	task.wait(0.3 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'Thunder')

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame * CFrame.new(0, 0, -2))
		clone.Parent = vfxFolder

		VFX_Helper.EmitAllParticles(clone)
		Debris:AddItem(clone, 2 / speed)
	end

	HRP.Parent.Attacking.Value = false
end

module["Electric Judgement"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = purgeVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position
	local targetCFrame = CFrame.new(enemyPos)

	task.wait(0.3 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'Thunder')

	local secondEffect = getStageEffect(Folder, "Second")
	if secondEffect then
		local clone = secondEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local distance = getMag(HRP.Position, enemyPos)
		local timeToTravel = math.clamp(distance / (30 * speed), 0.5 / speed, 1.5 / speed)

		local ballAttachment = clone:FindFirstChild("Ball")
		if ballAttachment then
			for _, v in ballAttachment:GetChildren() do
				if v:IsA("ParticleEmitter") then
					v.Enabled = true
				end
			end
		end

		tween(clone, timeToTravel, targetCFrame)
		Debris:AddItem(clone, timeToTravel + (1.5 / speed))

		task.delay(timeToTravel, function()
			if clone and clone.Parent and ballAttachment then
				for _, v in ballAttachment:GetChildren() do
					if v:IsA("ParticleEmitter") then
						v.Enabled = false
					end
				end
			end
		end)
	end

	HRP.Parent.Attacking.Value = false
end

return module