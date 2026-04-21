local gradient = script.Parent
local ts = game:GetService("TweenService")
local speed = 3
local ti = TweenInfo.new(speed, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local offset1 = {Offset = Vector2.new(1, 0)}
local create = ts:Create(gradient, ti, offset1)
local startingPos = Vector2.new(-1, 0)

gradient.Offset = startingPos

local function animate()
	create:Play()
	create.Completed:Wait()
	gradient.Offset = startingPos

	animate()
end

animate()

