local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UnitSoundEffectLib = require(ReplicatedStorage.VFXModules.UnitSoundEffectLib)


local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GameSpeed = workspace.Info.GameSpeed
local effectsFolder = ReplicatedStorage.VFX
local vfx = workspace.VFX
local wreckerVFX = effectsFolder.Wrecker

local VFX_Helper = require(ReplicatedStorage.Modules.VFX_Helper)

local function connect(p0, p1, c0)
	local weld = Instance.new("Weld")
	weld.Part0 = p0
	weld.Part1 = p1
	weld.C0 = c0
	weld.Parent = p0	

	return weld
end

local function tween(obj, length, details)
	TS:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

local function getMag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

local module = {}

module["Double Sabre Throw"] = function(HRP: BasePart, target: Model)
	local Folder = ReplicatedStorage.VFX["Brevious"].First
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local speed = GameSpeed.Value

	task.wait(0.3/speed)
	
	if not HRP or not HRP.Parent then 
		warn("No humanoid root part..")
		return 
	end
	
	HRP.Parent.Attacking.Value = true

	local blueLightSaber = HRP.Parent.RightArmBlueSaber
	local greenLightSaber = HRP.Parent.LeftArmGreenSaber
	local HRPCF = HRP.CFrame
	local startPosition = blueLightSaber.Position 
	local targetPosition = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)

	for _, part in blueLightSaber:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Transparency = 1
		end
		if part:IsA("ParticleEmitter") then
			part.Enabled = false
		end
	end
	
	for _, part in greenLightSaber:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Transparency = 1
		end
		if part:IsA("ParticleEmitter") then
			part.Enabled = false
		end
	end

	local emit = Folder:WaitForChild("BluePart"):Clone()
	local emit2 = Folder:WaitForChild("GreenPart"):Clone()
	emit.Position = (HRP.CFrame * CFrame.new(0.5,0.8,-.2)).Position
	emit.Parent = vfx
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing1')
	Debris:AddItem(emit,3/speed)

	print(Range)

	local tween = TS:Create(emit, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {Position = targetPosition + Vector3.new(0,0,-25)})
	tween:Play()
	
	print("Playing tween on: " .. emit.Name)
	
	task.wait(0.3/speed)
	
	if not HRP or not HRP.Parent then 
		return 
	end
	
	emit2.Position = (HRP.CFrame * CFrame.new(-0.5,0.8,-.5)).Position
	emit2.Parent = vfx
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing2')
	Debris:AddItem(emit2, 3/speed)
	
	TS:Create(emit2, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {Position = targetPosition + Vector3.new(0,0,-25)}):Play()

	local handleTween = TS:Create(emit, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {Position = blueLightSaber.Position})
	handleTween:Play()
	
	handleTween.Completed:Once(function()
		if emit then
			for _, particle in emit:GetDescendants() do
				if not particle:IsA("ParticleEmitter") then continue end
				particle.Enabled = false
			end

			task.delay(1, function()
				if emit then
					emit:Destroy()
				end
			end)
		end
		
		for _, part in blueLightSaber:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				part.Transparency = 0
			end
			if part:IsA("ParticleEmitter") then
				part.Enabled = true
			end
		end
	end)
	
	task.wait(0.3/speed)
	
	if not HRP or not HRP.Parent then return end

	local returnTween = TS:Create(emit2, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {Position = greenLightSaber.Position})
	returnTween:Play()

	returnTween.Completed:Once(function()
		if emit2 then
			for _, particle in emit2:GetDescendants() do
				if not particle:IsA("ParticleEmitter") then continue end
				particle.Enabled = false
			end
			
			task.delay(1, function()
				if emit2 then
					emit2:Destroy()
				end
			end)
		end
		
		for _, part in greenLightSaber:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				part.Transparency = 0
			end
			if part:IsA("ParticleEmitter") then
				part.Enabled = true
			end
		end
	end)

	HRP.Parent.Attacking.Value = false
end

module["Sabre Spin"] = function(HRP: BasePart, target: Model)
	local Folder = ReplicatedStorage.VFX["Brevious"].Second
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local speed = GameSpeed.Value

	task.wait(0.3/speed)

	if not HRP or not HRP.Parent then 
		warn("No humanoid root part..")
		return 
	end

	HRP.Parent.Attacking.Value = true

	local blueLightSaber = HRP.Parent.RightArmBlueSaber
	local HRPCF = HRP.CFrame
	local startPosition = blueLightSaber.Position 
	local targetPosition = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)

	for _, part in blueLightSaber:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("MeshPart") then
			part.Transparency = 1
		end
		if part:IsA("ParticleEmitter") then
			part.Enabled = false
		end
	end

	local emit = Folder:WaitForChild("Sabre Spin"):Clone()
	emit.Position = (HRP.CFrame * CFrame.new(0.5,0.8,-.2)).Position
	emit.Parent = vfx
	Debris:AddItem(emit,3/speed)
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing' .. tostring(math.random(1,2)))

	local tween = TS:Create(emit, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {Position = targetPosition + Vector3.new(0,0,-25)})
	tween:Play()

	task.wait(0.3/speed)

	if not HRP or not HRP.Parent then 
		return 
	end

	local handleTween = TS:Create(emit, TweenInfo.new(0.65/speed, Enum.EasingStyle.Linear), {Position = blueLightSaber.Position})
	handleTween:Play()

	handleTween.Completed:Once(function()
		if emit then
			for _, particle in emit:GetDescendants() do
				if not particle:IsA("ParticleEmitter") then continue end
				particle.Enabled = false
			end

			task.delay(1, function()
				if emit then
					emit:Destroy()
				end
			end)
		end

		for _, part in blueLightSaber:GetDescendants() do
			if part:IsA("BasePart") or part:IsA("MeshPart") then
				part.Transparency = 0
			end
			if part:IsA("ParticleEmitter") then
				part.Enabled = true
			end
		end
	end)

	HRP.Parent.Attacking.Value = false
end

module["Sabre Barrage"] = function(HRP, target)
	warn("Saber barrage..")
	
	local Folder = ReplicatedStorage.VFX["Brevious"].Third
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local speed = GameSpeed.Value * 16

	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)

	if not HRP or not HRP.Parent then return end

	local mag = getMag(HRP.Position, target:GetPivot().Position)
	tween(HRP, mag/speed, {CFrame = CFrame.new(enemypos)})

	HRP.Parent.Attacking.Value = true

	local breviousFx = Folder["Sabre Barrage"]:Clone()
	breviousFx.Parent = workspace.VFX

	local weld = connect(breviousFx.PrimaryPart, HRP, CFrame.new(0,-1,0))

	for _, particle in breviousFx:GetDescendants() do
		if not particle:IsA("ParticleEmitter") then continue end
		particle.Enabled = true
	end
	UnitSoundEffectLib.playSound(HRP.Parent, 'SaberSwing1')
	task.wait(mag / speed)

	if not HRP or not HRP.Parent then return end

	HRP.CFrame = HRP.Parent:WaitForChild("TowerBasePart").CFrame

	for _, particle in breviousFx:GetDescendants() do
		if not particle:IsA("ParticleEmitter") then continue end
		particle.Enabled = false
	end

	HRP.Parent.Attacking.Value = false

	for _, track in HRP.Parent.Humanoid.Animator:GetPlayingAnimationTracks() do
		if track.Animation.AnimationId == "106829327004680" or track.Animation.AnimationId == "rbxassetid://106829327004680" then
			track:Stop(.1)
		end
	end

	Debris:AddItem(breviousFx, 4)
end

return module
