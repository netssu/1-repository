local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX

local module = {}

module["Turbo Laser"] = function(HRP, target)
	local Folder = VFX["Elite Commando"].First
	local speed = GameSpeed.Value or 1
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")

	task.wait(0.25 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	if AttackingValue then AttackingValue.Value = true end

	UnitSoundEffectLib.playSound(characterModel, "Blaster1", false)

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

	local startPos = HRP.Position
	local targetPos = targetRoot.Position
	local distance = (startPos - targetPos).Magnitude
	local travelSpeed = 80 
	local timeToTravel = distance / travelSpeed

	local startCFrame = CFrame.lookAt(startPos, targetPos)
	local mainVFX = VFX_Helper.CloneObject(
		vfxContainer,
		startCFrame,
		vfxFolder,
		(timeToTravel + 1.5) / speed, 
		true
	)

	VFX_Helper.OnAllParticles(mainVFX)

	local endCFrame = CFrame.lookAt(targetPos, targetPos + startCFrame.LookVector)
	local tweenInfo = TweenInfo.new(timeToTravel / speed, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(mainVFX, tweenInfo, {CFrame = endCFrame})
	tween:Play()

	task.wait(timeToTravel / speed)

	if mainVFX then
		VFX_Helper.OffAllParticles(mainVFX)
	end

	if AttackingValue then AttackingValue.Value = false end
end

return module