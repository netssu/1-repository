local ts = game:GetService("TweenService")
local cas = game:GetService("ContextActionService")
local uis = game:GetService("UserInputService")

local cam = workspace.CurrentCamera

local humanoid = script.Parent:WaitForChild("Humanoid", 3)

local sprintAnim = humanoid:LoadAnimation(script:WaitForChild("SprintAnim"))

local isSprinting, ifSprintAnimPlaying = false, false

local FOVIn = ts:Create(
	cam,
	TweenInfo.new(.5),
	{FieldOfView = 100}
)

local FOVOut = ts:Create(
	cam,
	TweenInfo.new(.5),
	{FieldOfView = 70}
)

local function sprint(Type)
	if Type == "Begin" then
		isSprinting = true

		humanoid.WalkSpeed *= 2
	elseif Type == "Ended" then
		isSprinting = false

		humanoid.WalkSpeed = 16
	end
end

cas:BindAction("Sprint", function(_, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change then
		if isSprinting then return end
		sprint("Begin")
	elseif inputState == Enum.UserInputState.End then
		if not isSprinting then return end
		sprint("Ended")
	end
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR2)

cas:SetTitle("Sprint", "Sprint")
cas:SetPosition("Sprint", UDim2.new(1, -170,0, 100))

game:GetService("RunService").RenderStepped:Connect(function()
	if isSprinting and humanoid.MoveDirection.Magnitude > 0 then
		--FOVIn:Play()

		if humanoid:GetState() == Enum.HumanoidStateType.Running or humanoid:GetState() == Enum.HumanoidStateType.RunningNoPhysics then
			if not ifSprintAnimPlaying then
				sprintAnim:Play()
				ifSprintAnimPlaying = true
			end

		else

			if ifSprintAnimPlaying then
				sprintAnim:Stop()
				ifSprintAnimPlaying = false
			end

		end

	else
		--FOVOut:Play()

		if ifSprintAnimPlaying then
			sprintAnim:Stop()
			ifSprintAnimPlaying = false
		end
	end

end)

