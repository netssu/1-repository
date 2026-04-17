local model = script.Parent  -- This assumes the script is inside the model
local rotationSpeed = 0.02      -- Adjust rotation speed (degrees per frame, lower is slower)

-- Make sure the model has a PrimaryPart set
if not model.PrimaryPart then
	warn("Make sure the model has a PrimaryPart set!")
	return
end

-- Create a loop to continuously rotate the model
while true do
	-- Create a rotation around the Y-axis
	local rotation = CFrame.Angles(0, math.rad(rotationSpeed), 0)

	-- Apply rotation while keeping current position
	local currentCFrame = model:GetPrimaryPartCFrame()
	local newCFrame = currentCFrame * rotation
	model:SetPrimaryPartCFrame(newCFrame)

	wait(0.01)  -- Controls how smooth the animation is (lower is smoother)
end
