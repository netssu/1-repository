local Speed = 1.5

--// Part you want to spin
local SpinPart = script.Parent.Spin

--// Spinning
while true do
	if not SpinPart then
		SpinPart = script.Parent:FindFirstChild("Spin")
	end


	print("HI")
	if SpinPart then
		SpinPart.Orientation += Vector3.new(0, 1.5, 0)
	end
	
	task.wait(0.01) --How often the part turns, I set it to 0.01, so it spins every 0.01 seconds. You can change this, but lower number = smoother.
end