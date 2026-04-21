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
module["Soldier Attack"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX.Soldier.First
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")

	UnitSoundEffectLib.playSound(characterModel, "Blaster1", false)

	task.wait(0.15 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	if AttackingValue then AttackingValue.Value = true end

	task.wait(0.13 / speed)
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

	local function fireShot(tweenTime, waitTime)
		if not HRP or not characterModel or not targetRoot then return end

		local rightArm = characterModel:FindFirstChild("Right Arm")
		local gunPoint = rightArm and rightArm:FindFirstChild("Gun") and rightArm.Gun:FindFirstChild("Point")
		local startPos = gunPoint and gunPoint.Position or HRP.Position
		local targetPos = targetRoot.Position

		local startCFrame = CFrame.lookAt(startPos, targetPos)

		local projectile = VFX_Helper.CloneObject(
			vfxContainer,
			startCFrame,
			vfxFolder,
			(tweenTime + 1) / speed,
			false
		)

		for _, obj in projectile:GetDescendants() do
			if obj:IsA("ParticleEmitter") then
				obj.Enabled = true
				local emitCount = obj:GetAttribute("EmitCount") or 10
				obj:Emit(emitCount)
			end
		end

		local endCFrame = CFrame.lookAt(targetPos, targetPos + startCFrame.LookVector)
		TweenService:Create(projectile, TweenInfo.new(tweenTime / speed, Enum.EasingStyle.Linear), {CFrame = endCFrame}):Play()

		task.delay(tweenTime / speed, function()
			if projectile then
				VFX_Helper.OffAllParticles(projectile)
				projectile.Transparency = 1
			end
		end)

		task.wait(waitTime / speed)
	end

	fireShot(0.13, 0.03)
	fireShot(0.13, 0.03)
	fireShot(0.14, 0.04)

	if AttackingValue then AttackingValue.Value = false end
end

-- INIT
return module