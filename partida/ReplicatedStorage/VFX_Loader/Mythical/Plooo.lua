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
local RocksModule = require(rs.Modules.RocksModule)
local StoryModeStats = require(rs.StoryModeStats)
local GameSpeed = workspace.Info.GameSpeed

function cubicBezier(t, p0, p1, p2, p3)
	return (1 - t)^3*p0 + 3*(1 - t)^2*t*p1 + 3*(1 - t)*t^2*p2 + t^3*p3
end

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

module["Rebound Bullets"] = function(HRP: BasePart, target: Model)
	warn("Rebound initiated")
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))
end

module["Force Slam"] = function(HRP: BasePart, target: Model)
	local Folder = VFX.Kenobi.Second
	local anikinFolder = VFX.Anakin.Third
	local speed = GameSpeed.Value

	local MobName = target.Name
	local targetCF = target.HumanoidRootPart.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local startCFrame = HRP.CFrame
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)

	task.wait(1.1/speed)
	VFX_Helper.SoundPlay(HRP,Folder.Second)
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')
	HRP.Parent.Attacking.Value = true
	if not HRP or not HRP.Parent then return end
	if target then targetCF = target.HumanoidRootPart.CFrame end
	local Mob = if workspace.Info.TestingMode.Value then rs.Enemies.TestMap:FindFirstChildOfClass("Model"):Clone() else nil
	if not workspace.Info.TestingMode.Value then
		local folders = StoryModeStats.Maps
		for _, folder in folders do
			for i, mob in rs.Enemies[folder]:GetChildren() do
				if mob.Name == MobName then
					Mob = mob:Clone()
				end
			end
		end
	end
	Mob.PrimaryPart.CFrame = targetCF
	Mob.Parent = vfxFolder
	Debris:AddItem(Mob,2/speed)
	local connection = HRP.Parent.Destroying:Once(function()
		Mob:Destroy()
	end)
	Mob.HumanoidRootPart.Anchored = true
	local humanoid = Mob:FindFirstChildOfClass("Humanoid")
	local animation = Folder:WaitForChild("Animation")
	if humanoid and animation then
		local animTrack = humanoid:LoadAnimation(animation)
		animTrack:Play()
	end

	local forceChoke = anikinFolder["Force Choke"]:Clone()
	forceChoke.Parent = workspace.VFX

	connect(forceChoke, Mob.HumanoidRootPart, CFrame.new(0,-1,0))

	for _, particle in forceChoke:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			particle.Enabled = true
		end
	end

	local Uppos = Mob.HumanoidRootPart.CFrame * CFrame.new(0,10,0)
	local tweenUp = TS:Create(Mob.HumanoidRootPart, TweenInfo.new(1/speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = Uppos}):Play()
	task.wait(1/speed)
	if not HRP or not HRP.Parent then return end
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

	for _, particle in forceChoke:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			particle.Enabled = false
		end
	end

	Debris:AddItem(forceChoke, 2)

	local tweendown = TS:Create(Mob.HumanoidRootPart, TweenInfo.new(0.3/speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCF}):Play()
	task.wait(0.2/speed)
	if not HRP or not HRP.Parent then return end
	local groundemit = Folder:WaitForChild("ground"):Clone()
	groundemit.CFrame = targetCF + Vector3.new(0,-1.2,0)
	groundemit.Parent = vfxFolder
	Debris:AddItem(groundemit,3/speed)
	VFX_Helper.EmitAllParticles(groundemit)
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end
	for _, part in Mob:GetDescendants() do
		if part:IsA("BasePart") then
			TS:Create(part, TweenInfo.new(1/speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
		end
	end
	HRP.Parent.Attacking.Value = false
	connection:Disconnect()

end

module["Sniper Boom"] = function(HRP: BasePart, target: Model)
	local Folder = VFX["Crosshair"].Third
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local speed = GameSpeed.Value

	task.wait(.2 / speed)

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	UnitSoundEffectLib.playSound(HRP.Parent, 'Sniper' .. tostring(math.random(1,3)))

	local sniper = Folder["Sniper Boom"]:Clone()
	sniper.CFrame = HRP.CFrame * CFrame.new(0,0,-.5)
	sniper.Parent = vfxFolder

	emitParticles(sniper)

	Debris:AddItem(sniper, 2)

	task.wait(.2 / speed)

	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = false
end

module["Force Reckoning"] = function(HRP, target)
	local speed = GameSpeed.Value
	local Folder = VFX.Ploo.Folder
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	local lig1 = Folder:WaitForChild("Light"):Clone()
	lig1.CFrame = HRP.Parent["Right Arm"].Pos22.CFrame
	lig1.Parent = vfxFolder
	Debris:AddItem(lig1,2/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP.Parent["Right Arm"].Pos22
	weld.Part1 = lig1
	weld.Parent = lig1
	local light = Folder:WaitForChild("Light"):Clone()
	light.CFrame = HRP.Parent["Left Arm"].Pos.CFrame
	light.Parent = vfxFolder
	Debris:AddItem(light,2/speed)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = HRP.Parent["Left Arm"].Pos
	weld.Part1 = light
	weld.Parent = light

	VFX_Helper.OnAllParticles(lig1)
	VFX_Helper.OnAllParticles(light)

	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

	task.wait(0.6/speed)
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	VFX_Helper.SoundPlay(HRP,Folder.Sound)

	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local targetPosition = (HRP.CFrame * CFrame.new(0, 0, -Range)).Position

	local starsemit = Folder:WaitForChild("Electrigemit"):Clone()
	starsemit.CFrame = HRP.CFrame
	starsemit.Parent = HRP.Parent
	VFX_Helper.OnAllParticles(starsemit)
	Debris:AddItem(starsemit,3/speed)
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end

	TS:Create(starsemit,TweenInfo.new(0.25/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	VFX_Helper.OffAllParticles(lig1)
	VFX_Helper.OffAllParticles(light)
	task.wait(0.22/speed)
	if not HRP or not HRP.Parent then return end

	VFX_Helper.OffAllParticles(starsemit)


	HRP.Parent.Attacking.Value = false
end

return module