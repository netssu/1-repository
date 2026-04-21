-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace

-- VARIABLES
local VFX = ReplicatedStorage.VFX
local quinionVFX = VFX["Quinion Vas"]
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
module["Saber Throw"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = quinionVFX:FindFirstChild("First")
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local speed = GameSpeed.Value

	task.wait(0.78 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1, 2)))

	local lightsaber = HRP.Parent["Right Arm"]:FindFirstChild("Ground1")
	local HRPCF = HRP.CFrame
	local targetPosition = HRPCF * CFrame.new(0, 0, -Range)

	if lightsaber then
		VFX_Helper.Transparency(lightsaber, 1)
		VFX_Helper.OffAllParticles(lightsaber)
		for _, part in lightsaber:GetDescendants() do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end
	end

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, HRPCF * CFrame.Angles(math.rad(90), 0, 0))
		clone.Parent = vfxFolder

		for _, v in clone:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		local travelTime = 0.65 / speed
		tween(clone, travelTime, targetPosition)

		task.delay(travelTime, function()
			if not HRP or not HRP.Parent or not lightsaber then return end
			tween(clone, travelTime, lightsaber.CFrame)

			task.delay(travelTime, function()
				if clone then clone:Destroy() end
				if lightsaber then
					for _, part in lightsaber:GetDescendants() do
						if part:IsA("BasePart") then
							part.Transparency = 0
						end
					end
				end
			end)
		end)
	end

	HRP.Parent.Attacking.Value = false
end

module["Force Push"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = quinionVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position
	local targetCFrame = CFrame.new(enemyPos)

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	local RightArm = HRP.Parent:FindFirstChild("Right Arm")
	if not RightArm then return end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

	local secondEffect = getStageEffect(Folder, "Second")
	if secondEffect then
		local clone = secondEffect:Clone()
		clone = setEffectCFrame(clone, RightArm.CFrame)

		if clone:IsA("Model") then
			clone:PivotTo(clone:GetPivot() * CFrame.Angles(0, math.rad(-90), 0))
		else
			clone.Orientation += Vector3.new(0, -90, 0)
		end

		clone.Parent = vfxFolder

		local travelSpeed = 12 * speed
		local timeToTravel = getMag(RightArm.Position, enemyPos) / travelSpeed

		for _, v in clone:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = true
			end
		end

		tween(clone, timeToTravel, targetCFrame)
		Debris:AddItem(clone, timeToTravel + (0.5 / speed))

		task.delay(timeToTravel, function()
			if clone and clone.Parent then
				for _, v in clone:GetDescendants() do
					if v:IsA("ParticleEmitter") then
						v.Enabled = false
					end
				end
			end
		end)
	end

	HRP.Parent.Attacking.Value = false
end

module["Saber Slash"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = quinionVFX:FindFirstChild("Third")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position
	local targetCFrame = CFrame.new(enemyPos)

	if not HRP or not HRP.Parent then return end
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1, 2)))

	local thirdEffect = getStageEffect(Folder, "Third")
	if thirdEffect then
		local clone = thirdEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local travelSpeed = 16 * speed
		local timeToTravel = getMag(HRP.Position, enemyPos) / travelSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, targetCFrame)
		Debris:AddItem(clone, timeToTravel + (1 / speed))
	end
end

return module