local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)
local VFX = ReplicatedStorage.VFX
local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local GameSpeed = workspace.Info.GameSpeed
local vfxFolder = workspace:FindFirstChild("VFX") or workspace
local ninthSisterVFX = VFX["Ninth Sister"]

local module = {}

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

local function connect(p0, p1, c0)
	local part0 = p0:IsA("Model") and p0.PrimaryPart or p0
	if not part0 then return end

	local weld = Instance.new("Weld")
	weld.Part0 = part0
	weld.Part1 = p1
	weld.C0 = c0
	weld.Parent = part0
	return weld
end

local function getStageEffect(folder, effectName)
	if not folder then return nil end
	return folder:FindFirstChild(effectName)
end

module["Charge Down"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end
	if not HRP or not HRP.Parent then return end

	local Folder = ninthSisterVFX:FindFirstChild("First")
	local speed = GameSpeed.Value * 16
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)
	local isPossessed = HRP.Parent:GetAttribute("Possessed")

	local isControlling = false
	if isPossessed and workspace.CurrentCamera.CameraSubject then
		if workspace.CurrentCamera.CameraSubject.Parent == HRP.Parent then
			isControlling = true
		end
	end

	local mag = getMag(HRP.Position, target:GetPivot().Position)

	if not isPossessed then
		tween(HRP, mag / speed, {CFrame = CFrame.new(enemypos)})
	elseif isControlling then
		local direction = enemypos - HRP.Position
		if direction.Magnitude > 0.01 then
			direction = direction.Unit
		else
			direction = HRP.CFrame.LookVector
		end

		local dashForce = Instance.new("BodyVelocity")
		dashForce.MaxForce = Vector3.new(100000, 0, 100000)
		dashForce.Velocity = direction * speed
		dashForce.Parent = HRP
		Debris:AddItem(dashForce, mag / speed)
	end

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = true
	end

	local firstEffect = getStageEffect(Folder, "First")
	if firstEffect then
		local vfx = firstEffect:Clone()

		if vfx:IsA("BasePart") then
			vfx.CanCollide, vfx.CanQuery, vfx.CanTouch, vfx.Massless, vfx.Anchored = false, false, false, true, false
		end
		for _, desc in vfx:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.CanCollide, desc.CanQuery, desc.CanTouch, desc.Massless, desc.Anchored = false, false, false, true, false
			end
		end

		vfx.Parent = vfxFolder

		UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')
		UnitSoundEffectLib.playSound(HRP.Parent, 'Punch' .. tostring(math.random(1, 3)))

		connect(vfx, HRP, CFrame.new(0, -.5, 0))

		for _, particle in vfx:GetDescendants() do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = true
			end
		end

		task.wait(mag / speed)

		if not HRP or not HRP.Parent then return end

		if not isPossessed and HRP.Parent:FindFirstChild("TowerBasePart") then
			HRP.CFrame = HRP.Parent.TowerBasePart.CFrame
		end

		for _, particle in vfx:GetDescendants() do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = false
			end
		end

		Debris:AddItem(vfx, 2)
	end

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = false
	end

	local humanoid = HRP.Parent:FindFirstChild("Humanoid")
	if humanoid and humanoid:FindFirstChild("Animator") then
		for _, track in humanoid.Animator:GetPlayingAnimationTracks() do
			if track.Animation.AnimationId == "128527655134187" or track.Animation.AnimationId == "rbxassetid://128527655134187" or track.Animation.AnimationId == "132379076203645" or track.Animation.AnimationId == "rbxassetid://132379076203645" then
				track:Stop(.1)
			end
		end
	end
end

module["Force Choke"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local SisterFolder = ninthSisterVFX:FindFirstChild("Second")
	local SharedFolder = VFX:FindFirstChild("Kenobi") and VFX.Kenobi:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local MobName = target.Name
	local targetCF = target.HumanoidRootPart.CFrame

	task.wait(0.6 / speed)
	if not HRP or not HRP.Parent then return end

	if SharedFolder and SharedFolder:FindFirstChild("Second") then
		VFX_Helper.SoundPlay(HRP, SharedFolder.Second)
	end
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = true
	end

	if target and target:FindFirstChild("HumanoidRootPart") then 
		targetCF = target.HumanoidRootPart.CFrame 
	end

	local Mob = nil
	if workspace.Info.TestingMode.Value then 
		local testMob = ReplicatedStorage.Enemies.TestMap:FindFirstChildOfClass("Model")
		if testMob then Mob = testMob:Clone() end
	else
		for _, folder in ipairs(StoryModeStats.Maps) do
			if ReplicatedStorage.Enemies:FindFirstChild(folder) then
				local mobFound = ReplicatedStorage.Enemies[folder]:FindFirstChild(MobName)
				if mobFound then
					Mob = mobFound:Clone()
					break
				end
			end
		end
	end

	if not Mob and target then
		Mob = target:Clone()
	end

	if not Mob or not Mob:FindFirstChild("HumanoidRootPart") then 
		if HRP.Parent:FindFirstChild("Attacking") then HRP.Parent.Attacking.Value = false end
		return 
	end

	Mob.PrimaryPart = Mob:FindFirstChild("HumanoidRootPart")
	Mob:PivotTo(targetCF)
	Mob.Parent = vfxFolder
	Debris:AddItem(Mob, 3 / speed)

	local connection
	connection = HRP.Parent.Destroying:Once(function()
		if Mob then Mob:Destroy() end
	end)

	Mob.HumanoidRootPart.Anchored = true
	local humanoid = Mob:FindFirstChildOfClass("Humanoid")

	local animation = SharedFolder and SharedFolder:FindFirstChild("Animation")
	if humanoid and animation then
		local animTrack = humanoid:LoadAnimation(animation)
		animTrack:Play() 
	end

	local secondEffect = getStageEffect(SisterFolder, "Second")
	local forceChoke
	if secondEffect then
		forceChoke = secondEffect:Clone()
		forceChoke.Parent = vfxFolder
		connect(forceChoke, Mob.HumanoidRootPart, CFrame.new(0, -1, 0))

		for _, particle in forceChoke:GetDescendants() do
			if particle:IsA("ParticleEmitter") then particle.Enabled = true end
		end
	end

	local Uppos = Mob.HumanoidRootPart.CFrame * CFrame.new(0, 10, 0)
	TweenService:Create(Mob.HumanoidRootPart, TweenInfo.new(1 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = Uppos}):Play()

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then 
		if connection then connection:Disconnect() end 
		return 
	end

	if forceChoke then
		for _, particle in forceChoke:GetDescendants() do
			if particle:IsA("ParticleEmitter") then particle.Enabled = false end
		end
		Debris:AddItem(forceChoke, 2)
	end

	TweenService:Create(Mob.HumanoidRootPart, TweenInfo.new(0.3 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCF}):Play()

	task.wait(0.2 / speed)
	if not HRP or not HRP.Parent then 
		if connection then connection:Disconnect() end 
		return 
	end

	local groundObj = SharedFolder and SharedFolder:FindFirstChild("ground")
	if groundObj then
		local groundemit = groundObj:Clone()
		groundemit.CFrame = targetCF + Vector3.new(0, -1.2, 0)
		groundemit.Parent = vfxFolder
		Debris:AddItem(groundemit, 3 / speed)
		VFX_Helper.EmitAllParticles(groundemit)
	end

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then 
		if connection then connection:Disconnect() end 
		return 
	end

	for _, part in Mob:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(1 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
		end
	end

	if HRP.Parent:FindFirstChild("Attacking") then HRP.Parent.Attacking.Value = false end
	if connection then connection:Disconnect() end
end

module["Force Slam"] = function(HRP, target)
	if not target or not target:FindFirstChild("HumanoidRootPart") then return end

	local SisterFolder = ninthSisterVFX:FindFirstChild("Third")
	local SharedFolder = VFX:FindFirstChild("Kenobi") and VFX.Kenobi:FindFirstChild("Second")
	local speed = GameSpeed.Value
	local MobName = target.Name
	local targetCF = target.HumanoidRootPart.CFrame

	task.wait(1.1 / speed)
	if not HRP or not HRP.Parent then return end

	if SharedFolder and SharedFolder:FindFirstChild("Second") then
		VFX_Helper.SoundPlay(HRP, SharedFolder.Second)
	end
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force1')

	if HRP.Parent:FindFirstChild("Attacking") then
		HRP.Parent.Attacking.Value = true
	end

	if target and target:FindFirstChild("HumanoidRootPart") then 
		targetCF = target.HumanoidRootPart.CFrame 
	end

	local Mob = nil
	if workspace.Info.TestingMode.Value then 
		local testMob = ReplicatedStorage.Enemies.TestMap:FindFirstChildOfClass("Model")
		if testMob then Mob = testMob:Clone() end
	else
		for _, folder in ipairs(StoryModeStats.Maps) do
			if ReplicatedStorage.Enemies:FindFirstChild(folder) then
				local mobFound = ReplicatedStorage.Enemies[folder]:FindFirstChild(MobName)
				if mobFound then
					Mob = mobFound:Clone()
					break
				end
			end
		end
	end

	if not Mob and target then
		Mob = target:Clone()
	end

	if not Mob or not Mob:FindFirstChild("HumanoidRootPart") then 
		if HRP.Parent:FindFirstChild("Attacking") then HRP.Parent.Attacking.Value = false end
		return 
	end

	Mob.PrimaryPart = Mob:FindFirstChild("HumanoidRootPart")
	Mob:PivotTo(targetCF)
	Mob.Parent = vfxFolder
	Debris:AddItem(Mob, 3 / speed)

	local connection
	connection = HRP.Parent.Destroying:Once(function()
		if Mob then Mob:Destroy() end
	end)

	Mob.HumanoidRootPart.Anchored = true
	local humanoid = Mob:FindFirstChildOfClass("Humanoid")

	local animation = SharedFolder and SharedFolder:FindFirstChild("Animation")
	if humanoid and animation then
		local animTrack = humanoid:LoadAnimation(animation)
		animTrack:Play() 
	end

	local thirdEffect = getStageEffect(SisterFolder, "Third")
	local forceChoke
	if thirdEffect then
		forceChoke = thirdEffect:Clone()
		forceChoke.Parent = vfxFolder
		connect(forceChoke, Mob.HumanoidRootPart, CFrame.new(0, -1, 0))

		for _, particle in forceChoke:GetDescendants() do
			if particle:IsA("ParticleEmitter") then particle.Enabled = true end
		end
	end

	local Uppos = Mob.HumanoidRootPart.CFrame * CFrame.new(0, 10, 0)
	TweenService:Create(Mob.HumanoidRootPart, TweenInfo.new(1 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = Uppos}):Play()

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then 
		if connection then connection:Disconnect() end 
		return 
	end

	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')

	if forceChoke then
		for _, particle in forceChoke:GetDescendants() do
			if particle:IsA("ParticleEmitter") then particle.Enabled = false end
		end
		Debris:AddItem(forceChoke, 2)
	end

	TweenService:Create(Mob.HumanoidRootPart, TweenInfo.new(0.3 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCF}):Play()

	task.wait(0.2 / speed)
	if not HRP or not HRP.Parent then 
		if connection then connection:Disconnect() end 
		return 
	end

	local groundObj = SharedFolder and SharedFolder:FindFirstChild("ground")
	if groundObj then
		local groundemit = groundObj:Clone()
		groundemit.CFrame = targetCF + Vector3.new(0, -1.2, 0)
		groundemit.Parent = vfxFolder
		Debris:AddItem(groundemit, 3 / speed)
		VFX_Helper.EmitAllParticles(groundemit)
	end

	task.wait(0.1 / speed)
	if not HRP or not HRP.Parent then 
		if connection then connection:Disconnect() end 
		return 
	end

	for _, part in Mob:GetDescendants() do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(1 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 1}):Play()
		end
	end

	if HRP.Parent:FindFirstChild("Attacking") then HRP.Parent.Attacking.Value = false end
	if connection then connection:Disconnect() end
end

return module