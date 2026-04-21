local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
local RootPart: Part = Character:WaitForChild("HumanoidRootPart")

Humanoid.Died:Connect(function()
	Character = Player.Character or Player.CharacterAdded:Wait()
	Humanoid = Character:WaitForChild("Humanoid")
	RootPart = Character:WaitForChild("HumanoidRootPart")
end)

local CameraWeight = 20

local stop = false

RunService:BindToRenderStep("FollowHead", Enum.RenderPriority.Camera.Value + 1, function(DeltaTime: number)
	if not Character or (Humanoid:GetState() == Enum.HumanoidStateType.Dead) or stop then
		return
	end

	local Head: Part = Character:FindFirstChild("Head")
	if not Head then return end
	

	local ObjectSpace = RootPart.CFrame:ToObjectSpace(Head.CFrame)
	Humanoid.CameraOffset =
		Humanoid.CameraOffset:Lerp(ObjectSpace.Position - Vector3.new(0, 1.5, 0), DeltaTime * CameraWeight)

	local Tween = TweenService:Create(
		Humanoid,
		TweenInfo.new(0.055, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{ CameraOffset = ObjectSpace.Position - Vector3.new(0, 1.5, 0) }
	)
	Tween:Play()
	Tween = nil

	task.wait()
end)

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local Settings = Player:WaitForChild('Settings')
local ReduceMotion = Settings:WaitForChild('ReduceMotion')

local function update()
	if ReduceMotion.Value then
		stop = true
	else
		stop = false
	end
end

update()

ReduceMotion.Changed:Connect(update)