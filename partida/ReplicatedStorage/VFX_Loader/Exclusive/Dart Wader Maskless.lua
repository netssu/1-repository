-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local VFX = ReplicatedStorage:WaitForChild("VFX")
local DART_WADER_VFX = VFX:WaitForChild("Dart Wader Maskless")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX_Helper = require(ReplicatedStorage.Modules:WaitForChild("VFX_Helper"))
local GameSpeed = workspace:WaitForChild("Info"):WaitForChild("GameSpeed")
local vfxFolder = workspace:FindFirstChild("VFX") or workspace

-- FUNCTIONS
local module = {}

local function getStageEffect(folder, effectName)
	if not folder then return nil end
	return folder:FindFirstChild(effectName)
end

local function setupAndAnchorVFX(vfxInstance)
	if not vfxInstance then return end

	local parts = vfxInstance:IsA("BasePart") and {vfxInstance} or {}
	for _, desc in vfxInstance:GetDescendants() do
		if desc:IsA("BasePart") then
			table.insert(parts, desc)
		end
	end

	for _, part in ipairs(parts) do
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
	end
end

module["Fury"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local speed = GameSpeed.Value
	local Folder = DART_WADER_VFX:FindFirstChild("First")
	local characterModel = HRP.Parent
	local Range = characterModel.Config:WaitForChild("Range").Value
	local enemyPos = target.HumanoidRootPart.Position

	local originalCFrame = characterModel:GetPivot()
	UnitSoundEffectLib.playSound(HRP.Parent, 'Flamethrower')

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end

	characterModel.Attacking.Value = true

	local lookTarget = Vector3.new(enemyPos.X, HRP.Position.Y, enemyPos.Z)
	HRP.CFrame = CFrame.lookAt(HRP.Position, lookTarget)

	local firstEffect = getStageEffect(Folder, "First")

	if firstEffect then
		local spawnCFrame = HRP.CFrame * CFrame.Angles(0, math.rad(90), 0)

		local clone = VFX_Helper.CloneObject(firstEffect, spawnCFrame, vfxFolder, 5, true)
		setupAndAnchorVFX(clone)
	end

	local dashTime = 0.15 / speed
	local targetDashCFrame = HRP.CFrame * CFrame.new(0, 0, -Range)
	TweenService:Create(HRP, TweenInfo.new(dashTime, Enum.EasingStyle.Linear), {CFrame = targetDashCFrame}):Play()

	task.wait(dashTime) 
	if not HRP or not HRP.Parent then return end

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end

	characterModel:PivotTo(originalCFrame)
	characterModel.Attacking.Value = false
end

module["Force Slam"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local waderFolder = DART_WADER_VFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local targetCF = target.HumanoidRootPart.CFrame

	task.wait(1.1 / speed)
	if not HRP or not HRP.Parent then return end

	if not target or not target.Parent or not target.PrimaryPart or not target:FindFirstChild("HumanoidRootPart") then
		HRP.Parent.Attacking.Value = false
		return
	end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

	if waderFolder then
		local soundNode = waderFolder:FindFirstChildWhichIsA("Sound", true)
		if soundNode then
			VFX_Helper.SoundPlay(HRP, soundNode)
		end
	end

	HRP.Parent.Attacking.Value = true

	local Mob = target
	Mob.PrimaryPart.CFrame = targetCF
	Mob.HumanoidRootPart.Anchored = true

	local humanoid = Mob:FindFirstChildOfClass("Humanoid")
	local animation = waderFolder and waderFolder:FindFirstChild("Animation")
	if humanoid and animation and animation:IsA("Animation") then
		local animTrack = humanoid:LoadAnimation(animation)
		animTrack:Play() 
	end

	local secondEffect = getStageEffect(waderFolder, "Second")
	if secondEffect then
		local forceChoke = VFX_Helper.CloneObject(secondEffect, Mob.HumanoidRootPart.CFrame * CFrame.new(0, -1, 0), vfxFolder, 5, true)
		setupAndAnchorVFX(forceChoke)

		for _, desc in forceChoke:GetDescendants() do
			if desc:IsA("Sound") then
				desc:Play()
			end
		end
	end

	local Uppos = Mob.HumanoidRootPart.CFrame * CFrame.new(0, 10, 0)
	TweenService:Create(Mob.HumanoidRootPart, TweenInfo.new(1 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = Uppos}):Play()

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end

	if Mob and Mob:FindFirstChild("HumanoidRootPart") then
		TweenService:Create(Mob.HumanoidRootPart, TweenInfo.new(0.3 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCF}):Play()
	end

	task.wait(0.2 / speed)
	if not HRP or not HRP.Parent then return end

	if waderFolder then
		local groundObj = waderFolder:FindFirstChild("ground")
		if groundObj then
			local groundemit = VFX_Helper.CloneObject(groundObj, targetCF + Vector3.new(0, -1.2, 0), vfxFolder, 4 / speed, true)
			setupAndAnchorVFX(groundemit)
		end
	end

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end

	for _, part in Mob:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end

	task.delay(1 / speed, function()
		if Mob and Mob:FindFirstChild("HumanoidRootPart") then
			Mob.HumanoidRootPart.Anchored = false
		end
	end)

	HRP.Parent.Attacking.Value = false
end

module["AOE Attack"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local speed = GameSpeed.Value
	local Folder = DART_WADER_VFX:FindFirstChild("Third")

	if not HRP or not HRP.Parent or not HRP.Parent:FindFirstChild("TowerBasePart") then return end
	local characterModel = HRP.Parent

	task.wait(0.8 / speed)
	if not HRP or not HRP.Parent then return end

	characterModel.Attacking.Value = true
	UnitSoundEffectLib.playSound(characterModel, 'Force1')

	local thirdEffect = getStageEffect(Folder, "Third")

	if thirdEffect then
		local EmitCenter = VFX_Helper.CloneObject(thirdEffect, HRP.CFrame, vfxFolder, 6 / speed, true)
		setupAndAnchorVFX(EmitCenter)

		for _, desc in EmitCenter:GetDescendants() do
			if desc:IsA("Sound") then
				desc:Play() 
			end
		end
	end

	local jumpPos = HRP.CFrame * CFrame.new(0, 5, 0)
	TweenService:Create(HRP, TweenInfo.new(0.3 / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = jumpPos}):Play()

	task.wait(0.5 / speed)
	if not HRP or not HRP.Parent then return end

	local landPos = HRP.CFrame * CFrame.new(0, -5, 0)
	TweenService:Create(HRP, TweenInfo.new(0.15 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = landPos}):Play()

	task.wait(0.15 / speed)
	if not HRP or not HRP.Parent then return end

	UnitSoundEffectLib.playSound(characterModel, 'Force1')

	local points = {}
	local center = HRP.Position
	for i = 1, 6 do
		local angle = math.rad((360 / 6) * i)
		local radius = 10
		local x = math.cos(angle) * radius
		local z = math.sin(angle) * radius
		table.insert(points, center + Vector3.new(x, 0, z))
	end

	for i = 1, #points do
		if not HRP or not HRP.Parent then return end
		HRP.CFrame = CFrame.new(points[i])
		task.wait((0.3 / #points) / speed)
	end

	task.wait(0.2 / speed)

	if HRP and HRP.Parent and characterModel:FindFirstChild("TowerBasePart") then
		HRP.CFrame = characterModel.TowerBasePart.CFrame
		task.wait(0.5 / speed)

		if HRP and HRP.Parent then
			characterModel.Attacking.Value = false
		end
	end
end

-- INIT
return module