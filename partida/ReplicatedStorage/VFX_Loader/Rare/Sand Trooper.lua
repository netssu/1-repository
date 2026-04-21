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

local function connect(p0, p1, c0)
	local weld = Instance.new("Weld")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = c0
	weld.Parent = p0	

	return weld
end

local function emitParticles(container)
	VFX_Helper.EmitAllParticles(container)
end

local function canAttack(HRP, target)
	if not HRP or not HRP.Parent then
		warn("no humanoidrootpart for unit")
		return false
	end
	if not target or not target:FindFirstChild("HumanoidRootPart") then
		warn("no target")
		return false
	end

	return true
end

module["Flamethrower"] = function(HRP, target)
	task.wait(.25)

	if not HRP or not target then
		return
	end

	local vfxFolder = VFX["Sand Trooper"].First
	local sandTrooperFX = vfxFolder["Flamethrower"]:Clone()
	sandTrooperFX.CFrame = HRP.CFrame * CFrame.new(-.5, .2, 0)
	sandTrooperFX.Parent = workspace.VFX

	local weld = connect(sandTrooperFX, HRP, CFrame.new(-.5, .2, 0))
	UnitSoundEffectLib.playSound(HRP.Parent, 'Flamethrower')

	for _, particle in sandTrooperFX:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			particle.Enabled = true
		end
	end	

	HRP.Parent.Attacking.Value = true

	task.delay(1.5, function()
		if HRP and HRP.Parent then
			HRP.Parent.Attacking.Value = false
		end

		for _, particle in sandTrooperFX:GetDescendants() do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = false
			end
		end	

		Debris:AddItem(sandTrooperFX, 1)

		if weld then
			weld:Destroy()
		end
	end)

	task.wait(1.5)

	if HRP.Parent:FindFirstChild("Humanoid") and HRP.Parent.Humanoid:FindFirstChildOfClass("Animator") then
		for _, track in HRP.Parent.Humanoid.Animator:GetPlayingAnimationTracks() do
			if track.Animation.AnimationId == "rbxassetid://72711407720938" then
				track:Stop(.1)
			end
		end
	end
end

return module