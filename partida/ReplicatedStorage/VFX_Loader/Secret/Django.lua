-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace

-- VARIABLES
local VFX = ReplicatedStorage.VFX
local djangoVFX = VFX.Django
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
			-- Fallback seguro para Models sem PrimaryPart usando CFrameValue
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

-- INIT
module["Pistol and rocket"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = djangoVFX:FindFirstChild("First")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position
	local targetCFrame = CFrame.new(enemyPos)

	task.wait(0.3 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'EliteBlaster1')

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local projSpeed = 16 * speed
		local timeToTravel = getMag(HRP.Position, enemyPos) / projSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, targetCFrame)
		Debris:AddItem(clone, timeToTravel + (1.5 / speed))
	end

	HRP.Parent.Attacking.Value = false
end

module["Rockets"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = djangoVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position
	local targetCFrame = CFrame.new(enemyPos)

	task.wait(0.3 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'Rockets' .. tostring(math.random(1, 2)))

	local secondEffect = getStageEffect(Folder, "Second")
	if secondEffect then
		local clone = secondEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local projSpeed = 16 * speed
		local timeToTravel = getMag(HRP.Position, enemyPos) / projSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, targetCFrame)
		Debris:AddItem(clone, timeToTravel + (1.5 / speed))

		task.delay(timeToTravel, function()
			if HRP and HRP.Parent then
				UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
			end
		end)
	end

	HRP.Parent.Attacking.Value = false
end

module["Flamethrower"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = djangoVFX:FindFirstChild("Third")
	local speed = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position
	local targetCFrame = CFrame.new(enemyPos)

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	local RightArm = HRP.Parent:FindFirstChild("Right Arm")
	if not RightArm then return end

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'Flamethrower')

	local thirdEffect = getStageEffect(Folder, "Third")
	if thirdEffect then
		local clone = thirdEffect:Clone()
		clone.Anchored = true
		clone = setEffectCFrame(clone, RightArm.CFrame)

		-- Correção para rotacionar corretamente Models e BaseParts
		if clone:IsA("Model") then
			clone:PivotTo(clone:GetPivot() * CFrame.Angles(0, math.rad(-90), 0))
		else
			clone.Orientation += Vector3.new(0, -90, 0)
		end

		clone.Parent = vfxFolder

		local travelSpeed = 12 * speed
		local timeToTravel = getMag(RightArm.Position, enemyPos) / travelSpeed

		VFX_Helper.EmitAllParticles(clone)
		tween(clone, timeToTravel, targetCFrame)
		Debris:AddItem(clone, timeToTravel + (1.5 / speed))
	end

	HRP.Parent.Attacking.Value = false
end

return module