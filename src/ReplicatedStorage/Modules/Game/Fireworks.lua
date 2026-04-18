local Fireworks = {}

--[ Services ]--
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

--[ Variables ]--
local FireworkAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Gameplay"):WaitForChild("Modelo"):WaitForChild("Particles")

--[ Utils ]--
local RNG = Random.new()
local Colors = {
	Color3.fromRGB(255, 49, 49),
	Color3.fromRGB(255, 179, 55),
	Color3.fromRGB(255, 255, 53),
	Color3.fromRGB(105, 255, 79),
	Color3.fromRGB(70, 252, 255),
	Color3.fromRGB(193, 85, 255),
	Color3.fromRGB(255, 169, 225),
}

local function MakeFirework(position: Vector3)
	if not position then return end

	task.spawn(function()
		local RandomColor = Colors[RNG:NextInteger(1, #Colors)]

		local NewPart = Instance.new("Part")
		NewPart.CanCollide = false
		NewPart.Anchored = true
		NewPart.Transparency = 1
		NewPart.CFrame = CFrame.new(position)
		NewPart.Size = Vector3.new(0.2, 0.2, 0.2)
		NewPart.Name = "Firework"
		NewPart.Parent = workspace

		local Trail = FireworkAssets:FindFirstChild("Trail")
		if Trail then
			Trail = Trail:Clone()
			Trail.Parent = NewPart
		end

		local Time = RNG:NextNumber(8, 11)
		local Height = RNG:NextNumber(4, 7)
		TweenService:Create(NewPart, TweenInfo.new(Time / 10, Enum.EasingStyle.Linear), {CFrame = CFrame.new(position + Vector3.new(0, Height, 0))}):Play()

		task.wait(1)

		if Trail then
			Trail.Enabled = false
		end

		local ExplosionParticle = FireworkAssets:FindFirstChild("Explosion")
		if ExplosionParticle then
			ExplosionParticle = ExplosionParticle:Clone()
			ExplosionParticle.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, RandomColor),
				ColorSequenceKeypoint.new(1, RandomColor),
			})
			ExplosionParticle.Parent = NewPart
			ExplosionParticle:Emit(25)
		end

		Debris:AddItem(NewPart, 4)
	end)
end

function Fireworks.PlayFireworks(object: Instance)
	if not object then return end
	local baseCFrame: CFrame
	if object:IsA("BasePart") then
		baseCFrame = object.CFrame
	elseif object:IsA("Model") then
		baseCFrame = object:GetPivot()
	else
		return
	end

	local NumberOfFireworks = RNG:NextInteger(4, 6)
	local WhenToStop = 0

	while WhenToStop < NumberOfFireworks do
		local offset = Vector3.new(RNG:NextNumber(-4, 4), -2, RNG:NextNumber(-4, 4))
		MakeFirework(baseCFrame.Position + offset)
		WhenToStop = WhenToStop + 1
	end
end

return Fireworks
