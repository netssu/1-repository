local model = script.Parent  -- This assumes the script is inside the model
local floatSpeed = 4         -- Adjust how fast the model floats up and down
local floatHeight = 0.6      -- Adjust the height of the float (how high it moves up and down)

-- Make sure the model has a PrimaryPart set
if not model.PrimaryPart then
	warn("Make sure the model has a PrimaryPart set!")
	return
end

-- Keep track of original position
local originalPosition = model:GetPrimaryPartCFrame().p
local baseCFrame = model:GetPrimaryPartCFrame()
local time = 0

-- Create a loop to float the model up and down
while true do
	time = time + floatSpeed * 0.01
	local offset = math.sin(time) * floatHeight
	local newPosition = Vector3.new(originalPosition.X, originalPosition.Y + offset, originalPosition.Z)

	-- Apply only position change (no rotation)
	local newCFrame = CFrame.new(newPosition) * (baseCFrame - baseCFrame.p)
	model:SetPrimaryPartCFrame(newCFrame)

	wait(0.01)  -- Controls how smooth the animation is
end
