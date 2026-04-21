-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local VFX = ReplicatedStorage:WaitForChild("VFX")

-- VARIABLES
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace
local armoredCommandoVFX = VFX:FindFirstChild("Armored Commando")

-- INIT
local module = {}

-- FUNCTIONS
local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

local function disableInterference(characterModel, hrp)
	-- 1. Desliga os reflexos do Humanoid para ele não tocar animações de pulo/queda
	if characterModel:FindFirstChild("Humanoid") then
		characterModel.Humanoid.PlatformStand = true
	end

	if hrp then
		-- 2. Desliga o BodyGyro temporariamente para não brigar com o TweenService
		local bg = hrp:FindFirstChildOfClass("BodyGyro")
		if bg then
			bg.MaxTorque = Vector3.new(0, 0, 0)
		end

		-- 3. Ancora APENAS LOCALMENTE no client durante o ataque para a gravidade não puxar ele pro chão
		hrp.Anchored = true
	end
end

local function restoreInterference(characterModel, hrp, originalCFrame)
	if characterModel and characterModel:FindFirstChild("Attacking") then
		characterModel.Attacking.Value = false
	end

	if hrp then
		-- Força a posição exata da base para ele não ficar torto no chão
		local towerBase = characterModel:FindFirstChild("TowerBasePart")
		if towerBase then
			hrp.CFrame = towerBase.CFrame
		elseif originalCFrame then
			hrp.CFrame = originalCFrame
		end

		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

		-- Restaura a gravidade natural para ficar igual aos outros personagens
		hrp.Anchored = false

		-- Religa a estabilidade do BodyGyro
		local bg = hrp:FindFirstChildOfClass("BodyGyro")
		if bg then
			bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		end
	end

	if characterModel:FindFirstChild("Humanoid") then
		characterModel.Humanoid.PlatformStand = false
	end
end

local function getStageEffect(folder, effectName)
	if not folder then return nil end
	return folder:FindFirstChild(effectName)
end

local function setEffectCFrame(effect, cf)
	if not effect or not cf then return effect end
	if effect:IsA("Model") then
		effect:PivotTo(cf)
	elseif effect:IsA("BasePart") then
		effect.CFrame = cf
	end
	return effect
end

local function safeLookAt(originPos, targetPos)
	local distance = (originPos - targetPos).Magnitude
	if distance < 0.1 then
		return CFrame.new(originPos)
	end
	return CFrame.lookAt(originPos, targetPos)
end

module["Beatdown"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local characterModel = HRP.Parent

	if characterModel:FindFirstChild("Attacking") and characterModel.Attacking.Value == true then return end
	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = true end

	local towerBase = characterModel:FindFirstChild("TowerBasePart")
	local originalCFrame = towerBase and towerBase.CFrame or HRP.CFrame

	-- ISOLA O BONECO DA FÍSICA PARA COMEÇAR O ATAQUE SEGURO
	disableInterference(characterModel, HRP)

	local speed = GameSpeed.Value
	local Folder = armoredCommandoVFX and armoredCommandoVFX:FindFirstChild("Second")

	task.wait(0.78 / speed)
	if not HRP or not characterModel then return end

	local secondEffect = getStageEffect(Folder, "Second")
	local mainVFX

	if secondEffect then
		mainVFX = secondEffect:Clone()
		mainVFX = setEffectCFrame(mainVFX, HRP.CFrame)
		mainVFX.Parent = characterModel
		Debris:AddItem(mainVFX, 3 / speed)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = HRP
		weld.Part1 = mainVFX:IsA("Model") and (mainVFX.PrimaryPart or mainVFX:FindFirstChildWhichIsA("BasePart")) or mainVFX
		weld.Parent = mainVFX

		for _, obj in mainVFX:GetDescendants() do
			if obj:IsA("ParticleEmitter") and obj.Parent and string.find(string.lower(obj.Parent.Name), "wind") then
				obj.Enabled = true
				emitParticles(obj)
			end
		end
	end

	if not target or not target:FindFirstChild("HumanoidRootPart") then
		restoreInterference(characterModel, HRP, originalCFrame)
		return
	end

	local flatEnemyPos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local distance = (HRP.Position - flatEnemyPos).Magnitude

	local lookDir = safeLookAt(HRP.Position, flatEnemyPos)
	local targetCFrame = lookDir + (lookDir.LookVector * (distance - 3))
	local timeToTravel = 0.15 / speed

	TweenService:Create(HRP, TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()

	local cancel = false
	task.spawn(function()
		while not cancel and task.wait(0.1) do
			if characterModel and characterModel.Parent then
				UnitSoundEffectLib.playSound(characterModel, "Punch" .. tostring(math.random(1, 3)), false)
			end
		end
	end)

	task.wait(timeToTravel)
	cancel = true

	if mainVFX then
		for _, obj in mainVFX:GetDescendants() do
			if obj:IsA("ParticleEmitter") and obj.Parent and (string.find(string.lower(obj.Parent.Name), "impact") or string.find(string.lower(obj.Parent.Name), "starthing")) then
				emitParticles(obj)
			end
		end
		VFX_Helper.OffAllParticles(mainVFX)
	end

	task.wait(1 / speed)

	-- RESTAURA A FÍSICA PARA ELE CONTINUAR NORMAL E EM PÉ
	restoreInterference(characterModel, HRP, originalCFrame)
end

module["Death Slam"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local characterModel = HRP.Parent

	if characterModel:FindFirstChild("Attacking") and characterModel.Attacking.Value == true then return end
	if characterModel:FindFirstChild("Attacking") then characterModel.Attacking.Value = true end

	local towerBase = characterModel:FindFirstChild("TowerBasePart")
	local originalCFrame = towerBase and towerBase.CFrame or HRP.CFrame

	-- ISOLA O BONECO DA FÍSICA PARA COMEÇAR O ATAQUE SEGURO
	disableInterference(characterModel, HRP)

	local speed = GameSpeed.Value
	local Folder = armoredCommandoVFX and armoredCommandoVFX:FindFirstChild("First")

	task.wait(0.2 / speed)
	if not HRP or not characterModel then return end

	local jumpHeight = 25
	local jumpTime = 0.35 / speed
	local slamTime = 0.2 / speed

	UnitSoundEffectLib.playSound(characterModel, "Force1", false)

	local jumpCFrame = HRP.CFrame + Vector3.new(0, jumpHeight, 0)
	TweenService:Create(HRP, TweenInfo.new(jumpTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = jumpCFrame}):Play()

	task.wait(jumpTime)

	if not HRP or not characterModel or not target or not target:FindFirstChild("HumanoidRootPart") then
		restoreInterference(characterModel, HRP, originalCFrame)
		return
	end

	local flatEnemyPos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local slamDistance = (HRP.Position - flatEnemyPos).Magnitude

	local lookDir = safeLookAt(HRP.Position, flatEnemyPos)
	local slamCFrame = lookDir + (lookDir.LookVector * (slamDistance - 2))

	TweenService:Create(HRP, TweenInfo.new(slamTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = slamCFrame}):Play()

	task.wait(slamTime)
	if not HRP or not characterModel then return end

	UnitSoundEffectLib.playSound(characterModel, "Explosion", false)

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local impactCFrame = CFrame.new(slamCFrame.Position - Vector3.new(0, HRP.Size.Y / 2, 0))
		local mainVFX = firstEffect:Clone()
		mainVFX = setEffectCFrame(mainVFX, impactCFrame)
		mainVFX.Parent = vfxFolder
		Debris:AddItem(mainVFX, 3 / speed)

		emitParticles(mainVFX)
	end

	task.wait(0.15 / speed)
	if not HRP or not characterModel then return end

	TweenService:Create(HRP, TweenInfo.new(0.3 / speed, Enum.EasingStyle.Linear), {CFrame = originalCFrame}):Play()

	task.wait(0.3 / speed)

	-- RESTAURA A FÍSICA PARA ELE CONTINUAR NORMAL E EM PÉ
	restoreInterference(characterModel, HRP, originalCFrame)
end

return module