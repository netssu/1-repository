-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

-- CONSTANTS
local VFX = ReplicatedStorage:WaitForChild("VFX")
local MODULES = ReplicatedStorage:WaitForChild("Modules")

-- VARIABLES
local VFX_Helper = require(MODULES:WaitForChild("VFX_Helper"))
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local GameSpeed = Workspace:WaitForChild("Info"):WaitForChild("GameSpeed")

local module = {}

-- FUNCTIONS
module["C-3PO Farm Reward"] = function(HRP, target)
	local speed = GameSpeed.Value
	local FarmFolder = VFX.LEGA["C-3PO Farm"].First


	task.wait(0.7 / speed)
	if not HRP or not HRP.Parent then return end

	local vfxTemplate = FarmFolder.First:Clone()

	local emitAtt = vfxTemplate:FindFirstChild("Emit")
	local impactAtt = vfxTemplate:FindFirstChild("Impact")

	if emitAtt then
		emitAtt.Parent = HRP
		emitAtt.CFrame = CFrame.new() 
		Debris:AddItem(emitAtt, 3 / speed)
	end

	if impactAtt then
		impactAtt.Parent = HRP
		impactAtt.CFrame = CFrame.new() 
		Debris:AddItem(impactAtt, 3 / speed)
	end

	vfxTemplate:Destroy()

	task.wait(0.05 / speed)
	if not HRP or not HRP.Parent then return end

	if emitAtt then VFX_Helper.EmitAllParticles(emitAtt) end
	if impactAtt then VFX_Helper.EmitAllParticles(impactAtt) end
	UnitSoundEffectLib.playSound(HRP.Parent, 'Rockets1', false)
end

-- INIT
return module