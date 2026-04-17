if true then return end

local RunService = game:GetService("RunService")
local rotationSpeed = 360 / 6  -- 1 full spin every 6 seconds
local uiGradients = {}

for _, v in pairs(script.Parent:GetDescendants()) do
	if v:IsA("UIGradient") then
		table.insert(uiGradients, v)
	end
end

local currentRotation = 0

RunService.RenderStepped:Connect(function(dt)
	dt = math.clamp(dt, 0, 1/30) -- prevent spikes
	currentRotation = (currentRotation + rotationSpeed * dt) % 360

	for i = 1, #uiGradients do
		uiGradients[i].Rotation = currentRotation
	end
end)
