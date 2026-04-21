local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed
 
local function tween(obj, length, details)
	TS:Create(obj, TweenInfo.new(length), details):Play()
end
local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

module["Saber Throw"] = function(HRP, target)
	local Folder = VFX.Count.First
	local CountFolder = VFX.Count
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local speed = GameSpeed.Value

	print(Range)

	task.wait(0.78/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true

	local lightsaber = HRP.Parent:WaitForChild("Ground1")
	local HRPCF = HRP.CFrame
	local startPosition = lightsaber.Position 
	local targetPosition = HRPCF * CFrame.new(0, 0, -Range)

	VFX_Helper.Transparency(lightsaber, 1)
	local emit = Folder:WaitForChild("Sabre Throw"):Clone()
	emit.CFrame = HRP.CFrame * CFrame.new(0.5,0.8,-1.4)
	emit.Parent = vfxFolder
	Debris:AddItem(emit,2/speed)
	VFX_Helper.EmitAllParticles(emit)

	local Handle: BasePart = CountFolder.First.Saber:Clone()
	Handle.Anchored = true
	Handle.Parent = vfxFolder

	Debris:AddItem(Handle, 2.5/speed)

	VFX_Helper.OffAllParticles(lightsaber)
	for _, part in lightsaber:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end

	Handle.CFrame = HRPCF * CFrame.Angles(math.rad(90), 0, 0)
	local connection = HRP.Parent.Destroying:Once(function()
		Handle:Destroy()
	end)

	local tween = TS:Create(Handle, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {CFrame = targetPosition}):Play()
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))
	task.wait(0.65/speed)
	if not HRP or not HRP.Parent then return end
	TS:Create(Handle, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {CFrame = lightsaber.CFrame}):Play()
	task.wait(0.65/speed)
	if not HRP or not HRP.Parent then return end

	for _, part in lightsaber:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = 0
		end
	end

	HRP.Parent.Attacking.Value = false
	connection:Disconnect()
end



module["Force Push"] = function(HRP, target)
	local Folder = VFX.Count.Second
	local speed = GameSpeed.Value
	local enemyPos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local ForcePushVFX = Folder.ForcePush:Clone()
	local emitters = {}

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true

	local RightArm = HRP.Parent:FindFirstChild("Right Arm")
	if not RightArm then return end

	ForcePushVFX.CFrame = RightArm.CFrame
	ForcePushVFX.Anchored = true
	ForcePushVFX.Orientation += Vector3.new(0,-90,0)
	ForcePushVFX.Parent = workspace.VFX

	local travelSpeed = 12
	local timeToTravel = getMag(RightArm.Position, enemyPos) / travelSpeed
	tween(ForcePushVFX, timeToTravel, {Position = enemyPos})
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

	task.delay(timeToTravel, function()
		if ForcePushVFX then
			ForcePushVFX:Destroy()
		end
	end)

	for i, particle in ForcePushVFX.Parent:GetDescendants() do
		if particle:IsA('ParticleEmitter') then
			table.insert(emitters, particle)
		end
	end

	warn(emitters)

	local displayed = false

	for _, emitter in emitters do
		emitter.Enabled = true
		task.delay(1 / speed, function() -- 0.15
			if not displayed then
				warn(emitters)
				displayed = true
			end

			if emitter then
				emitter.Enabled = false
			end
		end)
	end
	HRP.Parent.Attacking.Value = false
end



module["Force Lightning"] = function(HRP, target)
	local Folder = VFX.Count.Third
	local speed = GameSpeed.Value
	local enemyPos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local LightningVFX = Folder.ForceLightning:Clone()
	local emitters = {}

	task.wait(0.4 / speed)
	if not HRP or not HRP.Parent then return end

	HRP.Parent.Attacking.Value = true

	local RightArm = HRP.Parent:FindFirstChild("Right Arm")
	if not RightArm then return end

	LightningVFX.CFrame = RightArm.CFrame
	LightningVFX.Anchored = true
	LightningVFX.Orientation += Vector3.new(0,-90,0)
	LightningVFX.Parent = workspace.VFX

	local travelSpeed = 12
	local timeToTravel = getMag(RightArm.Position, enemyPos) / travelSpeed
	tween(LightningVFX, timeToTravel, {Position = enemyPos})
	UnitSoundEffectLib.playSound(HRP.Parent, 'Thunder')

	task.delay(timeToTravel, function()
		if LightningVFX then
			LightningVFX:Destroy()
		end
	end)

	for i, particle in LightningVFX.Parent:GetDescendants() do
		if particle:IsA('ParticleEmitter') then
			table.insert(emitters, particle)
		end
	end

	warn(emitters)

	local displayed = false

	for _, emitter in emitters do
		emitter.Enabled = true
		task.delay(1 / speed, function() -- 0.15
			if not displayed then
				warn(emitters)
				displayed = true
			end

			if emitter then
				emitter.Enabled = false
			end
		end)
	end
	HRP.Parent.Attacking.Value = false
end

return module
