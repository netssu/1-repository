local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer

-- Cache frequently used values
local CAMERA_OFFSET = Vector3.new(0, 1.5, 0)
local CAMERA_WEIGHT = 20

-- State variables
local Character, Humanoid, RootPart, Head
local stop = false
local connection

-- Character setup function
local function setupCharacter()
	Character = Player.Character
	if not Character then return false end

	Humanoid = Character:FindFirstChild("Humanoid")
	RootPart = Character:FindFirstChild("HumanoidRootPart")
	Head = Character:FindFirstChild("Head")

	return Humanoid and RootPart and Head
end

-- Main camera update function
local function updateCamera(deltaTime)
	-- Early returns for invalid states
	if stop or not Character or not Humanoid or not RootPart or not Head then
		return
	end

	-- Check if humanoid is dead
	if Humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	-- Calculate and apply camera offset
	local objectSpace = RootPart.CFrame:ToObjectSpace(Head.CFrame)
	local targetOffset = objectSpace.Position - CAMERA_OFFSET

	Humanoid.CameraOffset = Humanoid.CameraOffset:Lerp(targetOffset, deltaTime * CAMERA_WEIGHT)
end

-- Character respawn handler
local function onCharacterAdded(newCharacter)
	-- Clean up old connection if it exists
	if connection then
		connection:Disconnect()
	end

	-- Wait for character to be fully loaded
	if not setupCharacter() then
		newCharacter.ChildAdded:Wait() -- Wait for children to load
		setupCharacter()
	end

	-- Bind the camera update function
	connection = RunService:BindToRenderStep("FollowHead", Enum.RenderPriority.Camera.Value + 1, updateCamera)
end

-- Settings handler
local function handleSettings()
	local success, settings = pcall(function()
		return Player:WaitForChild('DataLoaded', 10) and Player:WaitForChild('Settings', 5)
	end)

	if not success or not settings then
		warn("Failed to load player settings")
		return
	end

	local reduceMotion = settings:FindFirstChild('ReduceMotion')
	if reduceMotion then
		-- Set initial state
		stop = reduceMotion.Value

		-- Connect to changes
		reduceMotion.Changed:Connect(function()
			stop = reduceMotion.Value
		end)
	end
end

-- Initialize
if Player.Character then
	onCharacterAdded(Player.Character)
end

-- Connect to future character spawns
Player.CharacterAdded:Connect(onCharacterAdded)

-- Handle settings in a separate thread to avoid blocking
task.spawn(handleSettings)

return {}