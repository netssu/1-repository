-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- CONSTANTS
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local LightningSparks = require(ReplicatedStorage.VFXModules.LightningBolt.LightningSparks)
local LightningModule = require(ReplicatedStorage.VFXModules.LightningModule)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX

-- VARIABLES
local module = {}

-- FUNCTIONS
local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

module["Red Guard Attack"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX["Red Guard"].First
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local enemypos = Vector3.new(targetRoot.Position.X, HRP.Position.Y, targetRoot.Position.Z)

	local rightArm = characterModel:FindFirstChild("Right Arm")
	local handle = rightArm and rightArm:FindFirstChild("Handle")
	local posPart = handle and handle:FindFirstChild("PosPart")

	task.wait(0.1 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	if posPart then
		VFX_Helper.OnAllParticles(posPart)
	end

	task.wait(0.73 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")
	if AttackingValue then AttackingValue.Value = true end

	UnitSoundEffectLib.playSound(characterModel, "Thunder", false)

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	if vfxContainer and posPart then
		local mainVFX = VFX_Helper.CloneObject(
			vfxContainer,
			CFrame.new(enemypos + Vector3.new(0, -1, 0)),
			vfxFolder,
			3 / speed,
			false
		)

		local startAtt = Instance.new("Attachment")
		startAtt.Parent = posPart

		local endAtt = mainVFX:FindFirstChild("Attachment") or Instance.new("Attachment", mainVFX)

		local Lightning = LightningModule.new(startAtt, endAtt, 9)
		Lightning.MinRadius = 0.5
		Lightning.MaxRadius = 1
		Lightning.AnimationSpeed = 5
		Lightning.FadeLength = 0.5
		Lightning.PulseLength = 5
		Lightning.Thickness = 0.
		Lightning.MinTransparency = 0.3
		Lightning.MaxTransparency = 2.5
		Lightning.ContractFrom = 3
		Lightning.PulseSpeed = math.random(8, 12)
		Lightning.MinThicknessMultiplier = 0.3
		Lightning.MaxThicknessMultiplier = 0.5
		Lightning.Color = ColorSequence.new(Color3.fromRGB(199, 0, 149), Color3.fromRGB(199, 0, 149))

		LightningSparks.new(Lightning)

		emitParticles(mainVFX)

		Debris:AddItem(startAtt, 3 / speed)
	end

	task.wait(0.3 / speed)

	if posPart then
		VFX_Helper.OffAllParticles(posPart)
	end

	if not HRP or not characterModel then return end
	if AttackingValue then AttackingValue.Value = false end
end

-- INIT
return module