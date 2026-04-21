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
local tweenService = game:GetService("TweenService")
local StoryModeStats = require(rs.StoryModeStats)


local function tween(obj, length, details)
	tweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end


local function connect(p0, p1, c0)
	local weld = Instance.new("Weld")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = c0
	weld.Parent = p0
	return weld
end



module["Rock Throw"] = function(HRP, target)
	warn("Firing")
		local speed = GameSpeed.Value
		local Folder = VFX["Fifth Brother"].First
		local Range = HRP.Parent.Config:WaitForChild("Range").Value
		local enemypos = Vector3.new(target.HumanoidRootPart.Position.X, HRP.Position.Y, target.HumanoidRootPart.Position.Z)

		
		if not HRP or not HRP.Parent then return end
		HRP.Parent.Attacking.Value = true
		local rocks = {}

		local lookDirection = -HRP.CFrame.LookVector 
		local rightVector = HRP.CFrame.RightVector 

		for i, rockName in ({"Rock1", "Rock2", "Rock3"}) do
			local rock = Folder:WaitForChild(rockName):Clone()

			local offsetX = (i - 2) * 5 
			local spawnPosition = HRP.Position + lookDirection * 7 + rightVector * offsetX + Vector3.new(0, -5, 0)

			rock.CFrame = CFrame.new(spawnPosition)
			rock.Parent = vfxFolder
			table.insert(rocks, rock)
			Debris:AddItem(rock, 2 / speed)

		end

		for i, rock in (rocks) do
			task.spawn(function()
				local randomOffset = Vector3.new(math.random(-5, 5), -4, math.random(-5, 5))
				local readyRand = enemypos + randomOffset
				task.wait((i - 1) * 0.3 / speed) 
				if not HRP or not HRP.Parent then return end
				local connection = HRP.Parent.Destroying:Once(function()
					rock:Destroy()
				end)
				local startGroundEmit = Folder:WaitForChild("Startground"):Clone()
				startGroundEmit.Position = rock.Position + Vector3.new(0, 1.7, 0)
				startGroundEmit.Parent = vfxFolder
				Debris:AddItem(startGroundEmit, 2 / speed)
				VFX_Helper.EmitAllParticles(startGroundEmit)

				local upTime = math.random(10, 15) / 10 / speed

				local liftTween = TS:Create(rock, TweenInfo.new(upTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = rock.Position + Vector3.new(0, 17, 0)})
				local rotateTween = TS:Create(rock, TweenInfo.new(upTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Orientation = Vector3.new(math.random(0, 360), math.random(0, 360), math.random(0, 360))})

				liftTween:Play()
				rotateTween:Play()

				task.wait(upTime) 
				if not HRP or not HRP.Parent then return end

				local currentOrientation = rock.Orientation
				TS:Create(rock, TweenInfo.new(0.35 / speed, Enum.EasingStyle.Linear), {Orientation = Vector3.new(currentOrientation.X, currentOrientation.Y + 90, currentOrientation.Z)}):Play()

				task.wait(0.2/ speed)
				if not HRP or not HRP.Parent then return end


				TS:Create(rock, TweenInfo.new(0.15 / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = readyRand}):Play()
				task.wait(0.15 / speed)
				if not HRP or not HRP.Parent then return end

				local ground = Folder:WaitForChild("Ground"):Clone()
				ground.Position = readyRand + Vector3.new(0, 3, 0)
				ground.Parent = vfxFolder
				UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
				Debris:AddItem(ground, 1 / speed)
				VFX_Helper.EmitAllParticles(ground)
				connection:Disconnect()

			end)
		end
		task.wait(1 /speed)
		HRP.Parent.Attacking.Value = false
end

module["Saber Dash"] = function(HRP: BasePart, target: Model)
	warn("Running Saber Dash")
	local speed = GameSpeed.Value
	local Folder = VFX["Fifth Brother"].Second
	local characterModel = HRP.Parent
	local Range = characterModel.Config:WaitForChild("Range").Value
	local enemyPos = target:GetPivot().Position

	local originalCFrame = characterModel:GetPivot()
	task.wait(0.3 / speed)
	if not HRP or not HRP.Parent then return end

	characterModel.Attacking.Value = true


	local SaberDash = Folder["Saber Dash"]:Clone()
	SaberDash.Parent = workspace.VFX
	SaberDash.CFrame = HRP.CFrame

	local distance = (HRP.Position - enemyPos).Magnitude
	local timeToTravel = distance / speed

	TS:Create(SaberDash, TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear), {Position = enemyPos}):Play()
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))

	task.delay(speed, function()
		if SaberDash and SaberDash.Parent then
			warn("Destroying")
			SaberDash:Destroy()
		end
	end)

	for _, v in pairs(SaberDash:GetChildren()) do
		if v:IsA("ParticleEmitter") or v:IsA("Beam") then
			v.Enabled = true
		elseif v:IsA("Attachment") then
			for _, child in pairs(v:GetChildren()) do
				if child:IsA("ParticleEmitter") or child:IsA("Beam") then
					child.Enabled = true
				end
			end
		end
	end


	local targetCFrame = HRP.CFrame * CFrame.new(0, 0, -Range)
	TS:Create(HRP, TweenInfo.new(0.15/speed, Enum.EasingStyle.Linear), {CFrame = targetCFrame}):Play()

	task.wait(1 / speed)
	if not HRP or not HRP.Parent then return end
	characterModel:PivotTo(originalCFrame)
	
	
	Debris:AddItem(SaberDash, 1 / speed)


	characterModel.Attacking.Value = false
end


module["Force Slam"] = function(HRP: BasePart, target: Model)
	warn("Running Force Dash")
	local Folder = VFX.Kenobi.Second
	local anikinFolder = VFX["Fifth Brother"].Third
	local speed = GameSpeed.Value

	local MobName = target.Name
	local targetCF = target.HumanoidRootPart.CFrame
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local startCFrame = HRP.CFrame
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)

	task.wait(0.3/speed)
	VFX_Helper.SoundPlay(HRP,Folder.Second)
	HRP.Parent.Attacking.Value = true
	if not HRP or not HRP.Parent then return end
	if target then targetCF = target.HumanoidRootPart.CFrame end
	local Mob = if workspace.Info.TestingMode.Value then rs.Enemies.TestMap:FindFirstChildOfClass("Model"):Clone() else nil
	if not workspace.Info.TestingMode.Value then
		local folders  = StoryModeStats.Maps
		for _, folder in folders do
			for i, mob in rs.Enemies[folder]:GetChildren() do
				if mob.Name == MobName then
					Mob = mob:Clone()
				end
			end
		end
	end
	UnitSoundEffectLib.playSound(HRP.Parent, 'Force')
	Mob.PrimaryPart.CFrame = targetCF
	Mob.Parent = vfxFolder
	Debris:AddItem(Mob,2/speed)
	local connection = HRP.Parent.Destroying:Once(function()
		Mob:Destroy()
	end)
	Mob.HumanoidRootPart.Anchored = true
	local humanoid = Mob:FindFirstChildOfClass("Humanoid")
	local animation = Folder:WaitForChild("Animation")
	if humanoid  and animation then
		local animTrack = humanoid:LoadAnimation(animation)
		animTrack:Play() 
	end

	local forceChoke = anikinFolder["Force Slam"]:Clone()
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
	UnitSoundEffectLib.playSound(HRP.Parent, 'Explosion')
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

return module
