-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local VFX = ReplicatedStorage:WaitForChild("VFX")
local epicFolder = VFX:FindFirstChild("Epic")
local commandoVFX = epicFolder and epicFolder:FindFirstChild("Commando")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
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

module["Commando Attack"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local speed = GameSpeed.Value
	local characterModel = HRP.Parent
	local RangeConfig = characterModel:FindFirstChild("Config") and characterModel.Config:FindFirstChild("Range")
	local Range = RangeConfig and RangeConfig.Value or 20
	local direction = HRP.CFrame.LookVector

	task.wait(0.98 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = true
	end

	local rightArm = characterModel:FindFirstChild("Right Arm")
	local gunn = rightArm and rightArm:FindFirstChild("Gunn")
	local posPart = gunn and gunn:FindFirstChild("Pos")

	local effectTemplate = getStageEffect(commandoVFX, "Commando")

	for i = 1, 12 do
		if not HRP or not HRP.Parent then break end

		local startPos = posPart and posPart.Position or HRP.Position
		local scatterOffset = Vector3.new(math.random(-3, 3), math.random(-1, 1), math.random(-3, 3))
		local endPos = startPos + (direction * Range) + scatterOffset

		UnitSoundEffectLib.playSound(characterModel, 'Blaster2', false)

		if effectTemplate then
			local clone = VFX_Helper.CloneObject(effectTemplate, CFrame.new(startPos), vfxFolder, 2 / speed, false)

			setupAndAnchorVFX(clone)

			if clone:IsA("BasePart") then
				clone.Transparency = 0
			end

			task.delay(0.02 / speed, function()
				if clone and clone.Parent then
					local tween = TweenService:Create(clone, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {Position = endPos})
					tween:Play()

					tween.Completed:Connect(function()
						if clone and clone.Parent then
							if clone:IsA("BasePart") then
								clone.Transparency = 1 
							end
							VFX_Helper.EmitAllParticles(clone)
						end
					end)
				end
			end)
		end
	end

	task.wait(1.5 / speed)
	if not HRP or not HRP.Parent then return end

	if characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = false
	end
end

-- INIT
return module