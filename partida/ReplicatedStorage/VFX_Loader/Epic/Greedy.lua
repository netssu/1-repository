local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX

local module = {}

module["Burst Fire"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX.Greedy.First
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")

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

	local points = {
		characterModel:FindFirstChild("LPoint"), 
		characterModel:FindFirstChild("RPoint")
	}

	for i = 1, 4 do
		if not HRP or not characterModel or not targetRoot then break end

		UnitSoundEffectLib.playSound(characterModel, "BlasterBurst1", false)

		local currentPoint = points[(i % 2) + 1]
		local startPos = currentPoint and currentPoint.Position or HRP.Position
		local targetPos = targetRoot.Position

		local startCFrame = CFrame.lookAt(startPos, targetPos)

		local projectile = VFX_Helper.CloneObject(
			vfxContainer,
			startCFrame,
			vfxFolder,
			(0.13 + 1) / speed,
			true
		)

		VFX_Helper.OnAllParticles(projectile)

		local endCFrame = CFrame.lookAt(targetPos, targetPos + startCFrame.LookVector)
		TweenService:Create(projectile, TweenInfo.new(0.13 / speed, Enum.EasingStyle.Linear), {CFrame = endCFrame}):Play()

		task.delay(0.13 / speed, function()
			if projectile then
				VFX_Helper.OffAllParticles(projectile)
				projectile.Transparency = 1
			end
		end)

		task.wait(0.5 / speed)
	end

	if not HRP or not characterModel then return end
	if AttackingValue then AttackingValue.Value = false end
end

return module