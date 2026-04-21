-- SERVICES
local rs = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

-- CONSTANTS

-- VARIABLES
local VFX = rs:WaitForChild("VFX")
local vfxFolder = workspace:FindFirstChild("VFX") or workspace
local VFX_Helper = require(rs.Modules:WaitForChild("VFX_Helper"))
local UnitSoundEffectLib = require(rs.VFXModules:WaitForChild("UnitSoundEffectLib"))
local GameSpeed = workspace.Info:WaitForChild("GameSpeed")

-- FUNCTIONS
local module = {}

local function getEnemyPos(HRP, target)
	if target and target:FindFirstChild("HumanoidRootPart") then
		local pos = target.HumanoidRootPart.Position
		return Vector3.new(pos.X, HRP.Position.Y, pos.Z)
	end

	local range = HRP.Parent.Config:WaitForChild("Range").Value
	return (HRP.CFrame * CFrame.new(0, 0, -range)).Position
end

local function getVisual(folder, visualName)
	if not folder then return nil end
	local obj = folder:FindFirstChild(visualName)
	if obj and (obj:IsA("BasePart") or obj:IsA("Model")) then
		return obj
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") or child:IsA("Model") then
			return child
		end
	end

	return nil
end

local function playSimpleSkill(HRP, target, folderName, visualName, getCFrame, lifeTime, attackTime, offTime)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local unit = HRP.Parent
	local speed = GameSpeed.Value
	local folder = VFX:WaitForChild("Palpotin"):FindFirstChild(folderName)

	if not folder then return end

	local sound = folder:FindFirstChild("Sound")
	local template = getVisual(folder, visualName)

	if not template then return end

	if sound and sound:IsA("Sound") then
		VFX_Helper.SoundPlay(HRP, sound)
	end

	if unit:FindFirstChild("Attacking") then
		unit.Attacking.Value = true
	end

	local cframePos = getCFrame(HRP, target)
	local lifeT = (lifeTime or 3) / speed

	local vfx = VFX_Helper.CloneObject(template, cframePos, vfxFolder, lifeT, true)

	if unit:FindFirstChild("Destroying") then
		unit.Destroying:Once(function()
			if vfx and vfx.Parent then
				vfx:Destroy()
			end
		end)
	end

	task.delay((attackTime or 0.5) / speed, function()
		if unit and unit.Parent and unit:FindFirstChild("Attacking") then
			unit.Attacking.Value = false
		end
	end)
end

module["Palpotin light"] = function(HRP, target)
	if not HRP or not HRP.Parent then return end

	UnitSoundEffectLib.playSound(HRP.Parent, "Thunder", false)

	playSimpleSkill(
		HRP,
		target,
		"First",
		"First",
		function(HRP, target)
			local enemyPos = getEnemyPos(HRP, target)
			local spawnPos = HRP.Position + HRP.CFrame.LookVector * 4
			return CFrame.lookAt(spawnPos, enemyPos)
		end,
		2.5,
		0.45,
		0.2
	)

	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local speed = GameSpeed.Value
	local impactFolder = VFX:WaitForChild("Palpotin"):FindFirstChild("FirstImpact")

	if impactFolder then
		local impactTemplate = getVisual(impactFolder, "FirstImpact")
		if impactTemplate then
			local enemyPos = getEnemyPos(HRP, target)
			local cframePos = CFrame.new(enemyPos)
			local lifeT = 2 / speed

			VFX_Helper.CloneObject(impactTemplate, cframePos, vfxFolder, lifeT, true)
		end
	end
end

module["Doom Bolt"] = function(HRP, target)
	if not HRP or not HRP.Parent then return end

	UnitSoundEffectLib.playSound(HRP.Parent, "Flamethrower", false)

	playSimpleSkill(
		HRP,
		target,
		"Second",
		"Second",
		function(HRP, target)
			local enemyPos = getEnemyPos(HRP, target)
			return CFrame.new(enemyPos)
		end,
		3,
		0.55,
		0.25
	)
end

module["Emperor Rage"] = function(HRP, target)
	playSimpleSkill(
		HRP,
		target,
		"Thrid", 
		"Third",
		function(HRP, target)
			local enemyPos = getEnemyPos(HRP, target)
			return CFrame.new(enemyPos)
		end,
		3.5,
		0.8,
		0.4
	)
end

-- INIT
return module