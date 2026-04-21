-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

-- CONSTANTS
local VFX = ReplicatedStorage:WaitForChild("VFX")
local VFX_MODULES = ReplicatedStorage:WaitForChild("VFXModules")
local MODULES = ReplicatedStorage:WaitForChild("Modules")

-- VARIABLES
local UnitSoundEffectLib = require(VFX_MODULES:WaitForChild("UnitSoundEffectLib"))
local VFX_Helper = require(MODULES:WaitForChild("VFX_Helper"))
local GameSpeed = Workspace:WaitForChild("Info"):WaitForChild("GameSpeed")
local vfxFolder = Workspace:WaitForChild("VFX")

local module = {}

-- FUNCTIONS
module["Ki Mundi Attack"] = function(HRP, target)
	local speed = GameSpeed.Value
	local KiMundiFolder = VFX.LEGA["Ki Mundi"].First
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local targetHRP = target:FindFirstChild("HumanoidRootPart")

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then return end

	local handleR = HRP.Parent:FindFirstChild("Right Arm") and HRP.Parent["Right Arm"]:FindFirstChild("Handle")
	if handleR and handleR:FindFirstChild("Trail") then
		handleR.Trail.Enabled = true
	end

	task.wait(0.75 / speed)
	if not HRP or not HRP.Parent or not targetHRP then return end
	HRP.Parent.Attacking.Value = true
	local vfxTemplate = KiMundiFolder.First:Clone()

	local function bindAttachment(attName, targetPart, isPierce)
		local att = vfxTemplate:FindFirstChild(attName)
		if att then
			att.Parent = targetPart
			if isPierce then
				local relativeDir = targetPart.CFrame:PointToObjectSpace(targetHRP.Position)
				att.CFrame = CFrame.lookAt(Vector3.zero, relativeDir)
			else
				att.CFrame = CFrame.new()
			end
			Debris:AddItem(att, 4 / speed)
		end
		return att
	end

	local popAtt = bindAttachment("Pop", HRP, false)
	local pierceAtt = bindAttachment("pierce", HRP, true)

	local impactAtt = bindAttachment("Impact", targetHRP, false)
	local slashAtt = bindAttachment("Slash", targetHRP, false)

	local meshModel = vfxTemplate:FindFirstChild("MeshPartMesh")
	local beamModel = vfxTemplate:FindFirstChild("beamslash")

	local function setupTargetedModel(model)
		if not model then return end
		model.Parent = vfxFolder
		Debris:AddItem(model, 4 / speed)

		local startPart = model:FindFirstChild("Start")
		local endPart = model:FindFirstChild("End")

		if startPart then
			startPart.Transparency = 1
			startPart.Anchored = false 
			startPart.CanCollide = false
			startPart.Massless = true
			startPart.CFrame = HRP.CFrame

			local wStart = Instance.new("WeldConstraint")
			wStart.Part0 = HRP
			wStart.Part1 = startPart
			wStart.Parent = startPart
		end

		if endPart then
			endPart.Transparency = 1
			endPart.Anchored = false
			endPart.CanCollide = false
			endPart.Massless = true
			endPart.CFrame = targetHRP.CFrame

			local wEnd = Instance.new("WeldConstraint")
			wEnd.Part0 = targetHRP
			wEnd.Part1 = endPart
			wEnd.Parent = endPart
		end
	end

	setupTargetedModel(meshModel)
	setupTargetedModel(beamModel)

	vfxTemplate:Destroy()

	local connection = HRP.Parent.Destroying:Once(function()
		if popAtt then popAtt:Destroy() end
		if pierceAtt then pierceAtt:Destroy() end
		if impactAtt then impactAtt:Destroy() end
		if slashAtt then slashAtt:Destroy() end
		if meshModel then meshModel:Destroy() end
		if beamModel then beamModel:Destroy() end
	end)

	local targetCFrame = HRP.CFrame * CFrame.new(0, 0, -(Range - 2))
	TweenService:Create(HRP, TweenInfo.new(0.15 / speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()

	if popAtt then VFX_Helper.EmitAllParticles(popAtt) end
	if pierceAtt then VFX_Helper.EmitAllParticles(pierceAtt) end
	if meshModel then VFX_Helper.EmitAllParticles(meshModel) end
	if beamModel then VFX_Helper.OnAllBeams(beamModel) end 

	task.wait(0.09 / speed)
	if not HRP or not HRP.Parent or not targetHRP then return end

	if impactAtt then VFX_Helper.EmitAllParticles(impactAtt) end
	if slashAtt then VFX_Helper.EmitAllParticles(slashAtt) end

		UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1, 2)), false)

	task.wait(0.05 / speed)
	if not HRP or not HRP.Parent then return end

	if beamModel then VFX_Helper.OffAllBeams(beamModel) end

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end

	local teleportEffect1 = KiMundiFolder:FindFirstChild("teleport")
	if teleportEffect1 then
		local teleposr = teleportEffect1:Clone()
		teleposr.Transparency = 1
		teleposr.Anchored = true 
		teleposr.CanCollide = false
		teleposr.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
		teleposr.Parent = vfxFolder	
		Debris:AddItem(teleposr, 1 / speed)
		VFX_Helper.EmitAllParticles(teleposr)
	end

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame

	local teleportEffect2 = KiMundiFolder:FindFirstChild("teleport")
	if teleportEffect2 then
		local teleposttt = teleportEffect2:Clone()
		teleposttt.Transparency = 1
		teleposttt.Anchored = true
		teleposttt.CanCollide = false
		teleposttt.CFrame = HRP.CFrame + Vector3.new(0, -0.5, 0)
		teleposttt.Parent = vfxFolder	
		Debris:AddItem(teleposttt, 1 / speed)
		VFX_Helper.EmitAllParticles(teleposttt)
	end

	if handleR and handleR:FindFirstChild("Trail") then
		handleR.Trail.Enabled = false
	end
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end

-- INIT
return module