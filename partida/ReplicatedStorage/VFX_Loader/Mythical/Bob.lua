local module = {}
local rs = game:GetService("ReplicatedStorage")
local Effects = rs.VFX
local vfxFolder = workspace.VFX
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local VFX = rs.VFX
local VFX_Helper = require(rs.Modules.VFX_Helper)
local GameSpeed = workspace.Info.GameSpeed

module["Hip Shot"] = function(HRP, target)
	local Folder = VFX["Bob"]["Hip Shot"]
	local speed = GameSpeed.Value

	VFX_Helper.SoundPlay(HRP,Folder.First)
	local enemypos = Vector3.new(target.HumanoidRootPart.Position.X,HRP.Position.Y,target.HumanoidRootPart.Position.Z)
	task.wait(0.15/speed)
	local HRPCF = HRP.CFrame
	if not HRP or not HRP.Parent then return end
	HRP.Parent.Attacking.Value = true
	local Range = HRP.Parent.Config:WaitForChild("Range").Value
	local direction = HRPCF.LookVector
	local targetPosition = (HRPCF * CFrame.new(0, 0, -Range)).Position
	task.wait(0.1/speed)
	if not HRP or not HRP.Parent then return end

	local Ball = Folder:WaitForChild("Ball"):Clone()
	Ball.CFrame = HRP.Parent.Point.CFrame
	Ball.Position = HRP.Parent.Point.Position
	Ball.Parent = vfxFolder
	Debris:AddItem(Ball,1/speed)
	TS:Create(Ball,TweenInfo.new(0.13/speed,Enum.EasingStyle.Linear),{Position = targetPosition}):Play()
	task.wait(0.13/speed)
	if not HRP or not HRP.Parent then return end
	Ball.Transparency = 1
	HRP.Parent.Attacking.Value = false
end

module["Rocket Shot"] = function(HRP, target)
	local Folder = VFX["Bob"].Rocket
	local speed = GameSpeed.Value

	local Ball = Folder:WaitForChild("Ball"):Clone()
	local start = HRP.Position + Vector3.new(0, 2, 0) 
	local finish = target.HumanoidRootPart.Position + Vector3.new(0, -2, 0)
	local mid = (start + finish) / 2 + Vector3.new(0, 3, 0)

	Ball.Position = HRP.Position
	Ball.Parent = vfxFolder
	Debris:AddItem(Ball, 2/speed)
	VFX_Helper.SoundPlay(HRP, "Sniper" .. tostring(math.random(1,3)))

	TS:Create(Ball, TweenInfo.new(0.25/speed, Enum.EasingStyle.Linear), {Position = start}):Play()
	task.wait(0.25/speed)

	local t = 0
	local duration = 0.5 / speed
	local steps = 30
	for i = 1, steps do
		t = i / steps
		local a = start:Lerp(mid, t)
		local b = mid:Lerp(finish, t)
		local bezier = a:Lerp(b, t)
		Ball.Position = bezier

		if i == steps then
			local vfxPart = Folder.Explosion:Clone()
			vfxPart.Position = finish
			vfxPart.Parent = workspace.Terrain
			VFX_Helper.EmitAllParticles(vfxPart.Explosion)
			VFX_Helper.SoundPlay(vfxPart, "Explosion")
			Debris:AddItem(vfxPart, 2)

		end

		task.wait(duration / steps)
	end


	Ball.Transparency = 1
	HRP.Parent.Attacking.Value = false
end


module["Rocket Barrage"] = function(HRP, target)
	local Folder = VFX["Bob"].Rocket
	local speed = GameSpeed.Value

	local rocketCount = 3
	local delayBetween = 1 / speed 
	local xOffsets = {-1, 0, 1}

	HRP.Parent.Attacking.Value = true

	for i = 1, rocketCount do
		task.spawn(function()
			local xOffset = xOffsets[i]
			local rise = 2 + i

			local Ball = Folder:WaitForChild("Ball"):Clone()
			local start = HRP.Position + Vector3.new(xOffset, rise, 0)
			local finish = target.HumanoidRootPart.Position + Vector3.new(0, -2, 0)
			local mid = (start + finish) / 2 + Vector3.new(0, 3, 0)

			Ball.Position = HRP.Position
			Ball.Parent = vfxFolder
			Debris:AddItem(Ball, 2 / speed)
			VFX_Helper.SoundPlay(HRP, "Sniper" .. tostring(math.random(1,3)))

			TS:Create(Ball, TweenInfo.new(0.25 / speed, Enum.EasingStyle.Linear), {Position = start}):Play()
			task.wait(0.25 / speed)

			local t = 0
			local duration = 0.5 / speed
			local steps = 30
			for j = 1, steps do
				t = j / steps
				local a = start:Lerp(mid, t)
				local b = mid:Lerp(finish, t)
				local bezier = a:Lerp(b, t)
				Ball.Position = bezier
				task.wait(duration / steps)
			end

			local vfxPart = Folder.Explosion:Clone()
			vfxPart.Position = finish
			vfxPart.Parent = workspace.Terrain
			VFX_Helper.EmitAllParticles(vfxPart.Explosion)
			VFX_Helper.SoundPlay(vfxPart, "Explosion")
			Debris:AddItem(vfxPart, 2)

			Ball.Transparency = 1
		end)

		task.wait(delayBetween)
	end


	task.wait(1)
	HRP.Parent.Attacking.Value = false
end




return module
