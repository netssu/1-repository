-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX
local secondSisterVFX = VFX["Second Sister"]

local module = {}

-- FUNCTIONS
local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

local function setEffectCFrame(effect, cf)
	if not effect or not cf then
		return effect
	end

	if effect:IsA("Model") then
		effect:PivotTo(cf)
	elseif effect:IsA("BasePart") then
		effect.CFrame = cf
	end

	return effect
end

-- INIT
module["Saber Throw"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Folder = secondSisterVFX:FindFirstChild("First")
	local gameSpeedMulti = GameSpeed.Value
	local enemyPos = target.HumanoidRootPart.Position

	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1, 2)))

	local firstEffect = Folder and Folder:FindFirstChild("First")
	if firstEffect then
		local clone = firstEffect:Clone()
		clone = setEffectCFrame(clone, HRP.CFrame)
		clone.Parent = vfxFolder

		local projectileSpeed = 16 * gameSpeedMulti
		local timeToTravel = getMag(HRP.Position, enemyPos) / projectileSpeed

		VFX_Helper.EmitAllParticles(clone)

		tween(clone, timeToTravel, {Position = enemyPos})

		Debris:AddItem(clone, timeToTravel + (1.5 / gameSpeedMulti))
	end

	HRP.Parent.Attacking.Value = false
end

return module