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

module["Force Choke"] = function(HRP, target)
	--warn("Firing VFX")
	local Folder = VFX.Kenobi.Second
	local anikinFolder = VFX.Anakin.Third
	local speed = GameSpeed.Value

	local MobName = target.Name
	if not target:FindFirstChild('HumanoidRootPart') then return end

	local targetCF = target.HumanoidRootPart.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local startCFrame = HRP.CFrame
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	--warn(target:GetChildren())
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')
	task.wait(0.4/speed)
	HRP.Parent.Attacking.Value = true
	if not HRP or not HRP.Parent then return end
	--print(target:GetChildren(), target, targetCF)
	if target then targetCF = target:WaitForChild("HumanoidRootPart").CFrame end
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

module["Force Throw"] = function(HRP, target)
	local folder = VFX.Anakin
	local throwFx = folder.Second["Force Throw"]:Clone()
	if not target:FindFirstChild('HumanoidRootPart') then return end
	local MobName = target.Name
	local targetCF = target.HumanoidRootPart.CFrame
	local speed = workspace.Info.GameSpeed.Value
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

	if not HRP or not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local Mob = target:Clone()

	if not Mob then return end

	throwFx.CFrame = HRP.CFrame
	throwFx.Parent = workspace.VFX	

	emitParticles(throwFx)

	Debris:AddItem(throwFx, 1/speed)

	Mob.PrimaryPart.CFrame = targetCF
	Mob.Parent = vfxFolder
	Debris:AddItem(Mob,1/speed)
	local connection = HRP.Parent.Destroying:Once(function()
		Mob:Destroy()
	end)

	HRP.Parent.Attacking.Value = true

	local pushDirection = (targetCF.Position-HRP.CFrame.Position).Unit

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Parent = Mob.HumanoidRootPart
	bodyVelocity.Velocity = pushDirection * 40
	bodyVelocity.MaxForce = Vector3.new(1,0,1) * 1000000

	warn('parented to the targets root part')

	Debris:AddItem(bodyVelocity, .2)

	task.wait(.5)

	if HRP and HRP.Parent then
		HRP.Parent.Attacking.Value = false
	end

end

module["Dual Wield"] = function(HRP, target)
	task.wait(.5)

	if not HRP or not HRP.Parent or not target or not target:FindFirstChild("HumanoidRootPart") then
		--warn("rejecting dual wield")
		return
	end

	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))

	local folder = VFX.Anakin.First
	local slash = folder.Slash:Clone()

	slash.CFrame = HRP.CFrame
	slash.Parent = workspace.VFX

	emitParticles(slash)

	Debris:AddItem(slash, 2)
end


return module