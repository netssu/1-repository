local runService = game:GetService("RunService")

local obj = script.Parent.Internal['Main_Unit_ Frame'].UIGradient
local speed = 60 -- degrees per second
local spinning = false
local angle = 0

-- Spin function
runService.RenderStepped:Connect(function(dt)
	if spinning then
		angle = (angle + speed * dt) % 360
		obj.Rotation = angle
	end
end)

script.valEnabled.Changed:Connect(function()
	spinning = script.valEnabled.Value
end)