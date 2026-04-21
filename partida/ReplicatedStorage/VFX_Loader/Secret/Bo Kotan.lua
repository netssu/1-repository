-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- CONSTANTS
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX_Helper = require(ReplicatedStorage.Modules:WaitForChild("VFX_Helper"))

-- VARIABLES
local rs = game:GetService("ReplicatedStorage")
local VFXFolder = rs:WaitForChild("VFX")
local workspaceVFX = workspace:FindFirstChild("VFX") or workspace

local module = {}

-- FUNCTIONS
local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function EmitAllParticles(container)
	if not container then return end
	VFX_Helper.EmitAllParticles(container)
end

-- INIT
module["Saber Slash"] = function(HRP, target)
	local GameSpeed = workspace.Info.GameSpeed
	local speed = GameSpeed.Value

	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	local vfxBase = VFXFolder["Bo Kotan"].First.First:Clone()
	vfxBase.CFrame = HRP.CFrame
	vfxBase.Parent = workspaceVFX

	local enemyPos = target.HumanoidRootPart.Position
	local travelSpeed = 16 * speed
	local timeToTravel = getMag(HRP.Position, enemyPos) / travelSpeed

	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))

	tween(vfxBase, timeToTravel, {Position = enemyPos})

	EmitAllParticles(vfxBase:FindFirstChild("Slash"))
	EmitAllParticles(vfxBase:FindFirstChild("FastWind"))

	task.delay(timeToTravel + 1, function()
		if vfxBase then vfxBase:Destroy() end
	end)
end

module["Saber Slam"] = function(HRP, target)
	local GameSpeed = workspace.Info.GameSpeed
	local speed = GameSpeed.Value

	if not HRP or not HRP.Parent or not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local character = HRP.Parent
	local isPossessed = character:GetAttribute("Possessed")
	local enemyPos = target.HumanoidRootPart.Position

	local vfxBase = VFXFolder["Bo Kotan"].First.First:Clone()
	vfxBase.Position = enemyPos
	vfxBase.Parent = workspaceVFX

	UnitSoundEffectLib.playSound(character, 'Explosion')

	if isPossessed then
		EmitAllParticles(vfxBase:FindFirstChild("Shock"))
		EmitAllParticles(vfxBase:FindFirstChild("StarThing"))
	else
		local spawnPoint = character:FindFirstChild("SpawnPoint")
		if not spawnPoint then
			spawnPoint = Instance.new("Part")
			spawnPoint.Name = "SpawnPoint"
			spawnPoint.Size = Vector3.new(0.5, 0.5, 0.5)
			spawnPoint.Anchored = true
			spawnPoint.CanCollide = false
			spawnPoint.Transparency = 1
			spawnPoint.CFrame = HRP.CFrame
			spawnPoint.Parent = character
		end

		local travelSpeed = 16 * speed
		local travelTime = (HRP.Position - enemyPos).Magnitude / travelSpeed
		local startTime = tick()

		while tick() - startTime < travelTime do
			local alpha = (tick() - startTime) / travelTime
			HRP.CFrame = HRP.CFrame:Lerp(CFrame.new(enemyPos), alpha)
			task.wait()
		end

		HRP.CFrame = CFrame.new(enemyPos)

		EmitAllParticles(vfxBase:FindFirstChild("Shock"))
		EmitAllParticles(vfxBase:FindFirstChild("StarThing"))

		task.wait(0.2)

		if spawnPoint then
			HRP.CFrame = spawnPoint.CFrame
		end
	end

	task.delay(2, function()
		if vfxBase then vfxBase:Destroy() end
	end)
end

return module