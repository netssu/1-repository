local button = script.Parent
local gradient = button.UIGradient
local ts = game:GetService("TweenService")
local ti = TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
local offset1 = {Offset = Vector2.new(2, 0)}
local create = ts:Create(gradient, ti, offset1)
local startingPos = Vector2.new(-2, 0)
local addWait = 2

gradient.Offset = startingPos

local function animate()
	
	create:Play()
	create.Completed:Wait()
	gradient.Offset = startingPos
	task.wait(addWait)
	animate()
	
end

animate()