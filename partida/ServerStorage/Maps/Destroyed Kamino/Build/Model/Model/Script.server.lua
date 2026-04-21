local model = script.Parent  -- This assumes the script is inside the model
local rotationSpeed = 1    -- Adjust rotation speed (degrees per frame, lower is slower)
local floatSpeed = 4         -- Adjust how fast the model floats up and down
local floatHeight = 0.6      -- Adjust the height of the float (how high it moves up and down)

-- Keep track of original position
local originalPosition = model:GetPrimaryPartCFrame().p
local time = 0

-- Make sure the model has a PrimaryPart set
if not model.PrimaryPart then
	warn("Make sure the model has a PrimaryPart set!")
	return
end

-- Create a loop to rotate and float the model
while true do
	-- Increment rotation angle
	local rotation = CFrame.Angles(0, math.rad(rotationSpeed), 0)

	-- Calculate the new position for floating (up and down)
	time = time + floatSpeed * 0.01
	local offset = math.sin(time) * floatHeight
	local newPosition = Vector3.new(originalPosition.X, originalPosition.Y + offset, originalPosition.Z)

	-- Apply rotation and position change
	local currentCFrame = model:GetPrimaryPartCFrame()
	local newCFrame = CFrame.new(newPosition) * (currentCFrame - currentCFrame.p) * rotation
	model:SetPrimaryPartCFrame(newCFrame)

	wait(0.01)  -- Controls how smooth the animation is (lower is smoother)
end