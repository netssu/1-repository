local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GameSpeed = workspace.Info.GameSpeed
local effectsFolder = ReplicatedStorage.VFX
local wreckerVFX = effectsFolder.Wrecker

local function connect(p0, p1, c0)
	local weld = Instance.new("Weld")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = c0
	weld.Parent = p0	
	
	return weld
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local module = {}

module["Run it down"] = function(HRP, target)
	local Folder = wreckerVFX
	local speed = GameSpeed.Value * 16
	
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	
	if not HRP or not HRP.Parent then return end
	
	local mag = getMag(HRP.Position, target:GetPivot().Position)
	tween(HRP, mag/speed, {CFrame = CFrame.new(enemypos)})
	
	HRP.Parent.Attacking.Value = true
	
	local vfx = Folder.RunItDown:Clone()
	vfx.Parent = workspace.VFX
	
	local weld = connect(vfx, HRP, CFrame.new(0,-.5,0))
	
	for _, particle in vfx:GetDescendants() do
		if not particle:IsA("ParticleEmitter") then continue end
		particle.Enabled = true
	end
	
	local stop = false
	
	task.spawn(function()
		while not stop do
			UnitSoundEffectLib.playSound(HRP.Parent, 'Punch' .. tostring(math.random(1,3)))
			task.wait(1)
		end
	end)
	
	task.wait(mag / speed)

	if not HRP or not HRP.Parent then return end

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame
	
	for _, particle in vfx:GetDescendants() do
		if not particle:IsA("ParticleEmitter") then continue end
		particle.Enabled = false
	end
	
	stop = true
	HRP.Parent.Attacking.Value = false
	
	for _, track in HRP.Parent.Humanoid.Animator:GetPlayingAnimationTracks() do
		if track.Animation.AnimationId == "128527655134187" or track.Animation.AnimationId == "rbxassetid://128527655134187" then
			track:Stop(.1)
		end
	end
	
	Debris:AddItem(vfx, 2)
end

return module
