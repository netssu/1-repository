-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- CONSTANTS
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

module["Money Reward"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX["B2 Farm"].First

	if not HRP or not HRP.Parent then return end

	local soundEffect = Folder.First:FindFirstChildWhichIsA("Sound")

	if soundEffect then
		VFX_Helper.SoundPlay(HRP, soundEffect)
	end

	task.wait(0.15 / speed)
	if not HRP or not HRP.Parent then return end

	local emitUp = Folder.First:Clone()
	emitUp.Position = HRP.Position
	emitUp.Parent = vfxFolder
	Debris:AddItem(emitUp, 3 / speed)

	emitParticles(emitUp)
end

-- INIT
return module