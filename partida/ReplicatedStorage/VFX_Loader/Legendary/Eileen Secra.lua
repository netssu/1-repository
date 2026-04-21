-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX

-- VARIABLES
local module = {}

-- FUNCTIONS
local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

module["Eileen Secra Attack"] = function(HRP, target)
	local Folder = VFX["Eileen Secra"].First
	local speed = GameSpeed.Value or 1
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")
	local startCFrame = HRP.CFrame

	task.wait(0.5 / speed)
	if not HRP or not characterModel then return end

	if AttackingValue then AttackingValue.Value = true end

	UnitSoundEffectLib.playSound(characterModel, "SaberSwing1", false)
	UnitSoundEffectLib.playSound(characterModel, "SaberSwing2", false)

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	local mainVFX
	if vfxContainer then
		mainVFX = VFX_Helper.CloneObject(
			vfxContainer,
			HRP.CFrame,
			characterModel,
			3 / speed,
			false
		)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = HRP
		weld.Part1 = mainVFX:IsA("Model") and (mainVFX.PrimaryPart or mainVFX:FindFirstChildWhichIsA("BasePart")) or mainVFX
		weld.Parent = mainVFX

		emitParticles(mainVFX)
		VFX_Helper.OnAllParticles(mainVFX)
	end

	local RangeValue = characterModel:FindFirstChild("Config") and characterModel.Config:FindFirstChild("Range")
	local Range = RangeValue and RangeValue.Value or 10
	local finalPosition = HRP.CFrame * CFrame.new(0, 0, -Range)

	local steps = 12
	local duration = 0.4 / steps
	local amplitude = 3.5

	for i = 1, steps do
		local progress = i / steps
		local smoothProgress = math.sin(progress * math.pi * 0.4)
		local dynamicAmplitude = amplitude * (1 - progress)
		local offset = math.sin(progress * math.pi * 4) * dynamicAmplitude
		local intermediatePosition = startCFrame:Lerp(finalPosition, smoothProgress)
		intermediatePosition = intermediatePosition * CFrame.new(offset, 0, 0)

		TweenService:Create(HRP, TweenInfo.new(duration / speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = intermediatePosition}):Play()
		task.wait(duration / speed)
	end

	if mainVFX then
		VFX_Helper.OffAllParticles(mainVFX)
	end

	task.wait(0.1 / speed)
	if not HRP or not characterModel then return end

	local towerBase = characterModel:FindFirstChild("TowerBasePart")
	if towerBase then
		HRP.CFrame = towerBase.CFrame
	end

	if AttackingValue then AttackingValue.Value = false end

	task.wait(0.2 / speed)
end

-- INIT
return module