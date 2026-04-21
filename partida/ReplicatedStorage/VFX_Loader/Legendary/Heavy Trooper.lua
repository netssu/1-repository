local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX

local module = {}

local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

module["Heavy Trooper Attack"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX["Heavy Trooper"].First
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")

	task.wait(0.15 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	if AttackingValue then AttackingValue.Value = true end

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
	local regular = rightArm and rightArm:FindFirstChild("Regular")
	local gunPoint = regular and regular:FindFirstChild("Ball")
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

	task.wait(0.02 / speed)

	if gunPoint then
		VFX_Helper.EmitAllParticles(gunPoint)
	end

	UnitSoundEffectLib.playSound(characterModel, "EliteBlaster1", false)

	local endCFrame = CFrame.lookAt(targetPos, targetPos + startCFrame.LookVector)
	TweenService:Create(projectile, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = endCFrame}):Play()

	task.wait(0.1 / speed)

	if projectile then
		VFX_Helper.OffAllParticles(projectile)
		projectile.Transparency = 1
	end

	task.wait(0.1 / speed)

	if not HRP or not characterModel then return end
	if AttackingValue then AttackingValue.Value = false end
end

return module