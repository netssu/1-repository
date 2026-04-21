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

module["Rifleman Attack"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX.Rifleman.First
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")

	UnitSoundEffectLib.playSound(characterModel, "Blaster1", false)

	task.wait(0.15 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	if AttackingValue then AttackingValue.Value = true end

	task.wait(0.1 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	if not vfxContainer then
		if AttackingValue then AttackingValue.Value = false end
		return
	end

	local rightArm = characterModel:FindFirstChild("Right Arm")
	local gunPoint = rightArm and rightArm:FindFirstChild("Gun") and rightArm.Gun:FindFirstChild("Point")
	local startPos = gunPoint and gunPoint.Position or HRP.Position
	local targetPos = targetRoot.Position

	local startCFrame = CFrame.lookAt(startPos, targetPos)

	local projectile = VFX_Helper.CloneObject(
		vfxContainer,
		startCFrame,
		vfxFolder,
		(0.1 + 1) / speed,
		false
	)

	emitParticles(projectile)

	local endCFrame = CFrame.lookAt(targetPos, targetPos + startCFrame.LookVector)
	TweenService:Create(projectile, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = endCFrame}):Play()

	task.wait(0.1 / speed)

	if projectile then
		VFX_Helper.OffAllParticles(projectile)
		projectile.Transparency = 1
	end

	if not HRP or not characterModel then return end
	if AttackingValue then AttackingValue.Value = false end
end

-- INIT
return module