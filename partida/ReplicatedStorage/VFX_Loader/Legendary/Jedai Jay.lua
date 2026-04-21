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

module["Saber Slash"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX["Jedai Jay"].First
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")

	if AttackingValue then AttackingValue.Value = true end

	UnitSoundEffectLib.playSound(characterModel, "SaberSwing" .. tostring(math.random(1, 2)), false)

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
	local startCFrame = CFrame.lookAt(startPos, targetPos)

	local travelSpeed = 16
	local distance = (startPos - targetPos).Magnitude
	local timeToTravel = distance / travelSpeed

	local projectile = VFX_Helper.CloneObject(
		vfxContainer,
		startCFrame,
		vfxFolder,
		(timeToTravel + 1) / speed,
		false
	)

	for _, obj in projectile:GetDescendants() do
		if obj:IsA("ParticleEmitter") then
			if string.find(string.lower(obj.Parent.Name), "slash") or string.find(string.lower(obj.Parent.Name), "starthing") then
				obj.Enabled = true
				emitParticles(obj)
			end
		end
	end

	local endCFrame = CFrame.lookAt(targetPos, targetPos + startCFrame.LookVector)
	TweenService:Create(projectile, TweenInfo.new(timeToTravel / speed, Enum.EasingStyle.Linear), {CFrame = endCFrame}):Play()

	task.wait(timeToTravel / speed)

	if projectile then
		for _, obj in projectile:GetDescendants() do
			if obj:IsA("ParticleEmitter") then
				if string.find(string.lower(obj.Parent.Name), "hit") or string.find(string.lower(obj.Parent.Name), "impact") or string.find(string.lower(obj.Parent.Name), "pierce") then
					emitParticles(obj)
				end
			end
		end

		VFX_Helper.OffAllParticles(projectile)
		projectile.Transparency = 1
	end

	if not HRP or not characterModel then return end
	if AttackingValue then AttackingValue.Value = false end
end

return module