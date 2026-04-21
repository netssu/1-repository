-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

module["Rifle Blast"] = function(HRP, target)
	local Folder = VFX["Dark Trooper"].First
	local speed = GameSpeed.Value or 1
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")
	if AttackingValue then AttackingValue.Value = true end

	UnitSoundEffectLib.playSound(characterModel, "LaserGun" .. tostring(math.random(1,4)), false)

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	task.wait(0.1 / speed)

	if not HRP or not characterModel or not vfxContainer then
		if AttackingValue then AttackingValue.Value = false end
		return
	end

	local function spawnVFX(spawnCFrame)
		local emitUp = VFX_Helper.CloneObject(
			vfxContainer,
			spawnCFrame,
			vfxFolder,
			3 / speed,
			false
		)

		emitParticles(emitUp)
	end

	local rightPoint = characterModel:FindFirstChild("RightHand") and characterModel.RightHand:FindFirstChild("Point")
	local leftPoint = characterModel:FindFirstChild("LeftHand") and characterModel.LeftHand:FindFirstChild("Point")

	if rightPoint and leftPoint then
		spawnVFX(rightPoint.CFrame)
		spawnVFX(leftPoint.CFrame)
	else
		spawnVFX(HRP.CFrame)
	end

	task.wait(0.13 / speed)

	if AttackingValue then AttackingValue.Value = false end
end

-- INIT
return module