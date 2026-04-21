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

module["Crossblast"] = function(HRP, target)
	local Folder = VFX["Chompy"].First
	local speed = GameSpeed.Value or 1
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	UnitSoundEffectLib.playSound(characterModel, "Sniper1", false)

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	task.wait(0.15 / speed)

	if not HRP or not characterModel or not vfxContainer then return end

	local emitUp = VFX_Helper.CloneObject(
		vfxContainer,
		HRP.CFrame,
		vfxFolder,
		3 / speed,
		false
	)

	emitParticles(emitUp)
end

-- INIT
return module