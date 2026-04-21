-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local GameSpeed = workspace.Info.GameSpeed

-- VARIABLES
local module = {}

-- FUNCTIONS
local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

module["Saber Slash"] = function(HRP, target)
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local Folder = VFX["3rd Sister"].First
	local saber = Folder["First"]:Clone()

	saber.CFrame = HRP.CFrame
	saber.Parent = HRP.Parent

	local speed = 16 * (GameSpeed.Value or 1)
	local enemyPos = targetRoot.Position
	local timeToTravel = getMag(HRP.Position, enemyPos) / speed

	tween(saber, timeToTravel, {Position = enemyPos})

	Debris:AddItem(saber, timeToTravel + 0.5) 

	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing')

	for _, child in saber:GetChildren() do
		if child:IsA("Attachment") then
			for _, particle in child:GetChildren() do
				if particle:IsA("ParticleEmitter") then
					particle.Enabled = true

					task.delay(0.1, function()
						particle.Enabled = false
					end)
				end
			end
		end
	end
end

-- INIT
return module