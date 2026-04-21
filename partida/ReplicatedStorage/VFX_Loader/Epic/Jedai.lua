local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace.VFX

local module = {}

module["Jedai Attack"] = function(HRP, target)
	local speed = GameSpeed.Value or 1
	local Folder = VFX.Jedai.First
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")
	local enemypos = Vector3.new(targetRoot.Position.X, HRP.Position.Y, targetRoot.Position.Z)

	UnitSoundEffectLib.playSound(characterModel, "SaberSwing1", false)

	local vfxContainer
	for _, child in Folder:GetChildren() do
		if not child:IsA("Sound") then
			vfxContainer = child
			break
		end
	end

	local mainVFX
	if vfxContainer then
		mainVFX = VFX_Helper.CloneObject(
			vfxContainer,
			HRP.CFrame,
			characterModel,
			3 / speed,
			true
		)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = HRP
		weld.Part1 = mainVFX:IsA("Model") and (mainVFX.PrimaryPart or mainVFX:FindFirstChildWhichIsA("BasePart")) or mainVFX
		weld.Parent = mainVFX

		VFX_Helper.OnAllParticles(mainVFX)
	end

	task.wait(0.1 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	if AttackingValue then AttackingValue.Value = true end

	local enemyCFrame = CFrame.new(enemypos) * CFrame.Angles(HRP.CFrame:ToEulerAnglesXYZ())
	local targetDashPos = enemyCFrame + enemyCFrame.LookVector * -2.5

	TweenService:Create(HRP, TweenInfo.new(0.1 / speed, Enum.EasingStyle.Linear), {CFrame = targetDashPos}):Play()

	task.wait(0.1 / speed)

	if mainVFX then
		VFX_Helper.EmitAllParticles(mainVFX)
	end

	if not HRP or not characterModel then return end

	task.wait(0.54 / speed)
	if not HRP or not characterModel then return end

	if mainVFX then
		VFX_Helper.OffAllParticles(mainVFX)
	end

	local towerBase = characterModel:FindFirstChild("TowerBasePart")
	if towerBase then 
		HRP.CFrame = towerBase.CFrame 
	end

	if AttackingValue then AttackingValue.Value = false end
end

return module