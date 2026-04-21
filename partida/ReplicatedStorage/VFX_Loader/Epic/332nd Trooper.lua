-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local VFX = ReplicatedStorage:WaitForChild("VFX")
local epicFolder = VFX:WaitForChild("Epic")
local trooperVFX = epicFolder:FindFirstChild("nd 332 Trooper") 

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules:WaitForChild("UnitSoundEffectLib"))
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

module["332nd Trooper Attack"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local speed = GameSpeed.Value
	local characterModel = HRP.Parent

	local enemyPosRaw = target.HumanoidRootPart.Position
	local enemypos = Vector3.new(enemyPosRaw.X, HRP.Position.Y, enemyPosRaw.Z)
	local lookAtPos = enemypos + Vector3.new(0, -1, 0)

	task.wait(0.84 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = true
	end

	if trooperVFX and trooperVFX:FindFirstChild("Sound") then
		VFX_Helper.SoundPlay(HRP, trooperVFX.Sound)
	end

	local rightArm = characterModel:FindFirstChild("Right Arm")
	local gun = rightArm and rightArm:FindFirstChild("Gun")
	local posPart = gun and gun:FindFirstChild("Pos")
	local startPos = posPart and posPart.Position or HRP.Position

	UnitSoundEffectLib.playSound(characterModel, 'Blaster1')

	local effectTemplate = getStageEffect(trooperVFX, "nd 332 Trooper")

	if effectTemplate then
		local spawnCFrame = CFrame.lookAt(startPos, lookAtPos)
		local clone = VFX_Helper.CloneObject(effectTemplate, spawnCFrame, vfxFolder, 2 / speed, false)

		setupAndAnchorVFX(clone)

		if clone:IsA("BasePart") then
			clone.Transparency = 1
		end

		local lightning = clone:FindFirstChild("Lightning")
		if lightning then
			VFX_Helper.OnAllParticles(lightning)
			VFX_Helper.EmitAllParticles(lightning)
		end

		task.delay(0.01 / speed, function()
			if clone and clone.Parent then
				local tween = TweenService:Create(clone, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {Position = lookAtPos})
				tween:Play()

				tween.Completed:Connect(function()
					if clone and clone.Parent then
						if clone:IsA("BasePart") then
							clone.Transparency = 1
						end

						if lightning then
							VFX_Helper.OffAllParticles(lightning)
						end

						local pop = clone:FindFirstChild("Pop")
						if pop then
							VFX_Helper.EmitAllParticles(pop)
						end
					end
				end)
			end
		end)
	end

	task.wait(1.2 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = false
	end
end

-- INIT
return module