-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local VFX = ReplicatedStorage:WaitForChild("VFX")
local sixthBrotherVFX = VFX:WaitForChild("Sixth Brother")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules:WaitForChild("UnitSoundEffectLib"))
local VFX_Helper = require(ReplicatedStorage.Modules:WaitForChild("VFX_Helper"))
local RocksModule = require(ReplicatedStorage.Modules:WaitForChild("RocksModule"))
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

module["Perish"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local Folder = sixthBrotherVFX:FindFirstChild("First")
	local speed = GameSpeed.Value
	local characterModel = HRP.Parent

	if Folder and Folder:FindFirstChild("First") and Folder.First:IsA("Sound") then
		VFX_Helper.SoundPlay(HRP, Folder.First)
	end

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	local effectTemplate = getStageEffect(Folder, "First")
	local effectClone

	if effectTemplate then
		local towerBase = characterModel:FindFirstChild("TowerBasePart")
		local spawnPos = towerBase and towerBase.Position or HRP.Position

		effectClone = VFX_Helper.CloneObject(effectTemplate, CFrame.new(spawnPos + Vector3.new(0, -0.5, 0)), vfxFolder, 3 / speed, false)
		setupAndAnchorVFX(effectClone)
	end

	task.wait(0.08 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = true
	end

	local enemyCFrame = CFrame.new(enemypos) * CFrame.Angles(HRP.CFrame:ToEulerAnglesXYZ())
	TweenService:Create(HRP, TweenInfo.new(0.05 / speed, Enum.EasingStyle.Linear), {CFrame = enemyCFrame + enemyCFrame.LookVector * -0.5}):Play()

	task.wait(0.05 / speed)
	if not HRP or not HRP.Parent then return end

	UnitSoundEffectLib.playSound(characterModel, 'SaberSwing' .. tostring(math.random(1, 2)))

	if effectClone then
		effectClone.CFrame = CFrame.new(enemypos + Vector3.new(0, -1, 0))
		VFX_Helper.EmitAllParticles(effectClone)

		local pointLight = effectClone:FindFirstChildWhichIsA("PointLight")
		if pointLight then
			TweenService:Create(pointLight, TweenInfo.new(0.7 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Brightness = 0}):Play()
		end
	end

	task.wait(0.6 / speed)
	if not HRP or not HRP.Parent then return end

	local towerBase = characterModel:FindFirstChild("TowerBasePart")
	if towerBase then
		HRP.CFrame = towerBase.CFrame
	end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = false
	end
end


module["Stone Throw"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local Folder = sixthBrotherVFX:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local characterModel = HRP.Parent

	local startCFrame = HRP.CFrame
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

	if Folder and Folder:FindFirstChild("Seconddd") then
		VFX_Helper.SoundPlay(HRP, Folder.Seconddd)
	end

	task.wait(0.12 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = true
	end

	if not Folder then return end

	local rockEmitTemplate = Folder:FindFirstChild("Rockemit")
	if rockEmitTemplate then
		local emitCF = startCFrame * CFrame.new(0, -0.7, -2) * CFrame.Angles(math.rad(90), 0, 0)
		VFX_Helper.CloneObject(rockEmitTemplate, emitCF, vfxFolder, 2 / speed, true)
	end

	local rockTemplate = Folder:FindFirstChild("Rock")
	local rock
	local connection

	if rockTemplate then
		local rockCF = startCFrame * CFrame.new(0, -5, -2)
		rock = VFX_Helper.CloneObject(rockTemplate, rockCF, vfxFolder, 4 / speed, false) 

		if characterModel:FindFirstChild("Destroying") then
			connection = characterModel.Destroying:Once(function()
				if rock and rock.Parent then rock:Destroy() end
			end)
		end

		local rockUpCFrame = rock.CFrame * CFrame.new(0, 10, 0)
		TweenService:Create(rock, TweenInfo.new(1 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = rockUpCFrame}):Play()
	end

	task.wait(1.2 / speed)
	if not HRP or not HRP.Parent then return end

	if rock then
		local enemyCFrame = CFrame.new(enemypos) * CFrame.Angles(HRP.CFrame:ToEulerAnglesXYZ())
		local targetCF = enemyCFrame + Vector3.new(0, -1, 0)
		TweenService:Create(rock, TweenInfo.new(0.18 / speed, Enum.EasingStyle.Linear), {CFrame = targetCF}):Play()
	end

	task.wait(0.18 / speed)
	if not HRP or not HRP.Parent then return end

	UnitSoundEffectLib.playSound(characterModel, 'Explosion')

	local groundEmitTemplate = Folder:FindFirstChild("GroundVfx")
	if groundEmitTemplate then
		local groundCF = CFrame.new(enemypos) * CFrame.Angles(HRP.CFrame:ToEulerAnglesXYZ()) + Vector3.new(0, -1, 0)
		VFX_Helper.CloneObject(groundEmitTemplate, groundCF, vfxFolder, 3 / speed, true)
	end

	if rock and rock.Parent then rock:Destroy() end
	if connection then connection:Disconnect() end
end

module["Force Palm"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local Folder = sixthBrotherVFX:FindFirstChild("Third") or sixthBrotherVFX:FindFirstChild("Thrid")
	local speed = GameSpeed.Value
	local characterModel = HRP.Parent

	local effectTemplate = getStageEffect(Folder, "Third")

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = true
	end

	UnitSoundEffectLib.playSound(characterModel, 'Force1')

	if effectTemplate then
		local leftArm = characterModel:FindFirstChild("Left Arm")
		local spawnPos = leftArm and leftArm.Position or HRP.Position

		local lookForwardCF = CFrame.lookAt(spawnPos, spawnPos + HRP.CFrame.LookVector)

		local finalCFrame = lookForwardCF * CFrame.Angles(math.rad(-90), 0, 0)

		local clone = VFX_Helper.CloneObject(effectTemplate, finalCFrame, vfxFolder, 4 / speed, true)
		setupAndAnchorVFX(clone)
	end

	local RangeConfig = characterModel:FindFirstChild("Config") and characterModel.Config:FindFirstChild("Range")
	local Range = RangeConfig and RangeConfig.Value or 15

	RocksModule.Trail(HRP.CFrame, HRP.CFrame.LookVector, Range - 2.5, 3, Vector3.new(0.5, 0.5, 0.5), 0.02, 0.05, 0.4, true, 6, 3)

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = false
	end
end

-- INIT
return module