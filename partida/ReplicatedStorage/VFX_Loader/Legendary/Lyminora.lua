-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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

module["Lyminora Attack"] = function(HRP, target)
	local Folder = VFX.Lyminora.First
	local speed = GameSpeed.Value or 1
	local characterModel = HRP.Parent

	if not HRP or not characterModel then return end

	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local AttackingValue = characterModel:FindFirstChild("Attacking")

	task.wait(0.65 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	if AttackingValue then AttackingValue.Value = true end

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

	task.wait(0.15 / speed)
	if not HRP or not characterModel or not targetRoot then return end

	local rightArm = characterModel:FindFirstChild("Right Arm")
	local gunPos = rightArm and rightArm:FindFirstChild("Regular") and rightArm.Regular:FindFirstChild("Pos")
	local startCFrame = gunPos and gunPos.CFrame or HRP.CFrame

	for i = 1, 5 do
		if not HRP or not characterModel or not targetRoot then break end

		local enemyPos = targetRoot.Position
		local randomOffset = Vector3.new(math.random(-3, 3), -1, math.random(-3, 3))
		local targetPoint = enemyPos + randomOffset

		UnitSoundEffectLib.playSound(characterModel, "Blaster" .. tostring(math.random(1, 3)), false)

		local projectileCFrame = CFrame.lookAt(startCFrame.Position, targetPoint)
		local projectile = VFX_Helper.CloneObject(
			vfxContainer,
			projectileCFrame,
			vfxFolder,
			2 / speed,
			false
		)

		for _, obj in projectile:GetDescendants() do
			if obj:IsA("ParticleEmitter") then
				if not string.find(string.lower(obj.Parent.Name), "impact") and not string.find(string.lower(obj.Parent.Name), "pop") then
					obj.Enabled = true
					local emitCount = obj:GetAttribute("EmitCount")
					if emitCount then
						obj:Emit(emitCount)
					end
				end
			end
		end

		local gunWind = rightArm and rightArm:FindFirstChild("Regular") and rightArm.Regular:FindFirstChild("Winnd")
		if gunWind then
			emitParticles(gunWind)
		end

		local distance = (startCFrame.Position - targetPoint).Magnitude
		local timeToTravel = distance / 100 

		local endCFrame = CFrame.lookAt(targetPoint, targetPoint + projectileCFrame.LookVector)
		local tween = TweenService:Create(projectile, TweenInfo.new(timeToTravel / speed, Enum.EasingStyle.Linear), {CFrame = endCFrame})
		tween:Play()

		task.wait(timeToTravel / speed)

		if projectile then
			VFX_Helper.OffAllParticles(projectile)

			for _, obj in projectile:GetDescendants() do
				if obj:IsA("ParticleEmitter") then
					if string.find(string.lower(obj.Parent.Name), "impact") or string.find(string.lower(obj.Parent.Name), "pop") or string.find(string.lower(obj.Parent.Name), "specs") then
						local emitCount = obj:GetAttribute("EmitCount") or 15
						obj:Emit(emitCount)
					end
				end
			end
			projectile.Transparency = 1
		end

		task.wait(0.09 / speed)
	end

	task.wait(1 / speed)
	if not HRP or not characterModel then return end

	if AttackingValue then AttackingValue.Value = false end
end

-- INIT
return module