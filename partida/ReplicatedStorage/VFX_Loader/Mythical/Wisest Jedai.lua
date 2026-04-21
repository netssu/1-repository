-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local RocksModule = require(ReplicatedStorage.Modules.RocksModule)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace
local wisestJediVFX = VFX:FindFirstChild("Wisest_Jedi")

-- FUNCTIONS
local module = {}

local function connect(p0, p1, c0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.Parent = p1
	return weld
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

local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

module["Wisest Jedai first attack"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local speed = GameSpeed.Value
	local Folder = wisestJediVFX:FindFirstChild("First")
	local characterModel = HRP.Parent
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	local firstEffect = getStageEffect(Folder, "First")
	local mainVFX

	if firstEffect then
		mainVFX = firstEffect:Clone()
		mainVFX = setEffectCFrame(mainVFX, HRP.CFrame)
		mainVFX.Parent = characterModel
		Debris:AddItem(mainVFX, 3 / speed)

		connect(HRP, mainVFX:IsA("Model") and (mainVFX.PrimaryPart or mainVFX:FindFirstChildWhichIsA("BasePart")) or mainVFX, CFrame.new())

		for _, obj in mainVFX:GetDescendants() do
			if obj:IsA("ParticleEmitter") and obj.Parent and string.find(string.lower(obj.Parent.Name), "fastwind") then
				obj.Enabled = true
				local emitCount = obj:GetAttribute("EmitCount") or 10
				obj:Emit(emitCount)
			end
		end
	end

	task.wait(0.08 / speed)
	if not HRP or not characterModel then return end

	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = true end

	UnitSoundEffectLib.playSound(characterModel, "SaberSwing" .. tostring(math.random(1, 2)), false)

	local enemyCFrame = CFrame.new(enemypos) * CFrame.Angles(HRP.CFrame:ToEulerAnglesXYZ())
	local targetDashPos = enemyCFrame + enemyCFrame.LookVector * -0.5

	TweenService:Create(HRP, TweenInfo.new(0.05 / speed, Enum.EasingStyle.Linear), {CFrame = targetDashPos}):Play()

	task.wait(0.05 / speed)

	if mainVFX then
		for _, obj in mainVFX:GetDescendants() do
			if obj:IsA("ParticleEmitter") and obj.Parent and string.find(string.lower(obj.Parent.Name), "shock") then
				local emitCount = obj:GetAttribute("EmitCount") or 30
				obj:Emit(emitCount)
			end
		end
	end

	task.wait(0.6 / speed)
	if not HRP or not characterModel then return end

	if mainVFX then
		VFX_Helper.OffAllParticles(mainVFX)
	end

	local towerBase = characterModel:FindFirstChild("TowerBasePart")
	if towerBase then
		HRP.CFrame = towerBase.CFrame
	end

	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = false end
end

module["Stone Throw"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local speed = GameSpeed.Value
	local Folder = wisestJediVFX:FindFirstChild("Second")
	local characterModel = HRP.Parent

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local startCFrame = HRP.CFrame

	task.wait(0.12 / speed)
	if not HRP or not characterModel then return end

	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = true end

	UnitSoundEffectLib.playSound(characterModel, "Force1", false)

	local secondEffect = getStageEffect(Folder, "Second")
	local projectile

	if secondEffect then
		local initialCFrame = startCFrame * CFrame.new(0, 0, -2) * CFrame.Angles(math.rad(-90), 0, 0)

		projectile = secondEffect:Clone()
		projectile = setEffectCFrame(projectile, initialCFrame)
		projectile.Parent = vfxFolder
		Debris:AddItem(projectile, 5 / speed)

		for _, obj in projectile:GetDescendants() do
			if obj:IsA("ParticleEmitter") and obj.Parent and (string.find(string.lower(obj.Parent.Name), "ground") or string.find(string.lower(obj.Parent.Name), "smoke")) then
				local emitCount = obj:GetAttribute("EmitCount") or 20
				obj:Emit(emitCount)
			end
		end

		local enemyFinalCFrame = CFrame.new(enemypos) * CFrame.Angles(startCFrame:ToEulerAnglesXYZ()) * CFrame.Angles(math.rad(-90), 0, 0)
		TweenService:Create(projectile, TweenInfo.new(1.2 / speed, Enum.EasingStyle.Linear), {CFrame = enemyFinalCFrame}):Play()
	end

	task.wait(1.2 / speed)
	if not HRP or not characterModel then return end

	UnitSoundEffectLib.playSound(characterModel, "Explosion", false)

	if projectile then
		for _, obj in projectile:GetDescendants() do
			if obj:IsA("ParticleEmitter") and obj.Parent and (string.find(string.lower(obj.Parent.Name), "impact") or string.find(string.lower(obj.Parent.Name), "specsclose") or string.find(string.lower(obj.Parent.Name), "pop")) then
				local emitCount = obj:GetAttribute("EmitCount") or 30
				obj:Emit(emitCount)
			end
		end

		task.delay(0.5, function()
			if projectile then
				projectile.Transparency = 1
				VFX_Helper.OffAllParticles(projectile)
			end
		end)
	end

	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = false end
end

module["Force Palm"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local speed = GameSpeed.Value
	local Folder = wisestJediVFX:FindFirstChild("Third")
	local characterModel = HRP.Parent

	UnitSoundEffectLib.playSound(characterModel, "Force1", false)

	task.wait(1 / speed)
	if not HRP or not characterModel then return end

	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = true end

	local RangeValue = characterModel:FindFirstChild("Config") and characterModel.Config:FindFirstChild("Range")
	local Range = RangeValue and RangeValue.Value or 10

	local thirdEffect = getStageEffect(Folder, "Third")

	if thirdEffect then
		local baseSpawnCFrame = HRP.CFrame * CFrame.new(0, 0, -2)

		local tiltedSpawnCFrame = baseSpawnCFrame * CFrame.new(0,0,0) * CFrame.Angles(math.rad(-90), 0, 0)

		local mainVFX = thirdEffect:Clone()
		mainVFX = setEffectCFrame(mainVFX, tiltedSpawnCFrame)
		mainVFX.Parent = vfxFolder
		Debris:AddItem(mainVFX, 4 / speed)

		emitParticles(mainVFX)

		local distance = Range - 2.5
		local finalPosition = baseSpawnCFrame.Position + (HRP.CFrame.LookVector * distance)

		local finalTiltedCFrame = CFrame.new(finalPosition) * tiltedSpawnCFrame.Rotation

		TweenService:Create(mainVFX, TweenInfo.new(0.5 / speed, Enum.EasingStyle.Linear), {CFrame = finalTiltedCFrame}):Play()
	end

	RocksModule.Trail(HRP.CFrame, HRP.CFrame.LookVector, Range - 2.5, 3, Vector3.new(0.5, 0.5, 0.5), 0.02, 0.05, 0.4, true, 6, 3)
	UnitSoundEffectLib.playSound(characterModel, "Explosion", false)

	task.wait(1 / speed)

	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = false end
end

-- INIT
return module