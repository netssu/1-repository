local specialVFX = {}

local TweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")
local DebrisFol = workspace.Debris

function specialVFX.IceStomp(rig, startPos, spikeCount, startSize, sizeIncrement, decayTime, interval)
	local iceStompVFX = script.IceStomp
	local SpikeTemplate = iceStompVFX.Crystal
	local SpikePadTemplate = iceStompVFX.SpikePadding
	local direction = rig.HumanoidRootPart.CFrame.LookVector
	local lastSize = startSize
	local lastPosition = startPos.Position
	local spacingFactor = 0.2
	local paddingIncrease = 2
	local rotationalFactor = 20
	local spikePads = {}

	local rayOrigin = rig.HumanoidRootPart.Position
	local rayDirection = Vector3.new(0, -50, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Whitelist

	local whitelist = {}


	for _, v in pairs(game:GetService("CollectionService"):GetTagged("RockInclude")) do
		table.insert(whitelist, v)
	end
	rayParams.FilterDescendantsInstances = {whitelist}


	local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
	local floorY = rayResult and rayResult.Position.Y or startPos.Position.Y

	for i = 1, spikeCount do
		task.wait(interval or 0)

		local newSize = lastSize + Vector3.new(sizeIncrement, sizeIncrement, sizeIncrement)
		local distance = (lastSize.Z + newSize.Z) * spacingFactor
		local newPosition = lastPosition + (direction * distance)
		local heightAdjustment = (newSize.Y - lastSize.Y) / 2

		local xRotation, zRotation
		if i == spikeCount then
			xRotation = 0
			zRotation = math.rad(-30)
		else
			local sign = (i % 2 == 0) and 1 or -1
			xRotation = sign * math.rad(rotationalFactor)
			zRotation = math.rad(math.random(-25, -10))
		end

		local spikeRotation = rig.HumanoidRootPart.CFrame.Rotation
		local rotationOffset = CFrame.Angles(zRotation, 0, xRotation)

		local Spike = SpikeTemplate:Clone()
		Spike.Size = newSize
		Spike.CFrame = CFrame.new(newPosition) * CFrame.new(0, -newSize.Y / 2 + heightAdjustment, 0) * spikeRotation * rotationOffset
		Spike.Parent = DebrisFol

		local SpikePad = SpikePadTemplate:Clone()
		table.insert(spikePads, SpikePad)
		SpikePad.Size = Vector3.new(newSize.X + paddingIncrease, 0.1, newSize.Z + paddingIncrease)
		SpikePad.CFrame = CFrame.new(newPosition.X, floorY + 0.05, newPosition.Z) -- Use the found floor position
		SpikePad.Parent = DebrisFol

		local riseGoal = { CFrame = Spike.CFrame * CFrame.new(0, newSize.Y / 2, 0) }
		local riseTween = TweenService:Create(Spike, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), riseGoal)
		riseTween:Play()

		Spike.Size = Spike.Size + Vector3.new(0, Spike.Size.Y * 1.5, 0)

		task.delay(decayTime, function()
			local sinkGoal = { CFrame = Spike.CFrame * CFrame.new(0, -newSize.Y * 2, 0) }
			local sinkTween = TweenService:Create(Spike, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), sinkGoal)
			sinkTween:Play()
			sinkTween.Completed:Wait()

			Spike:Destroy()
			if i == spikeCount then
				for _, pad in ipairs(spikePads) do
					local shrinkGoal = { Size = Vector3.new(0, SpikePad.Size.Y, 0) }
					local shrinkTween = TweenService:Create(pad, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), shrinkGoal)
					shrinkTween:Play()

					spawn(function()
						shrinkTween.Completed:Wait()
						pad:Destroy()
					end)
				end
			end
		end)

		lastSize = newSize
		lastPosition = newPosition + Vector3.new(0, heightAdjustment, 0)
	end
end


return specialVFX
