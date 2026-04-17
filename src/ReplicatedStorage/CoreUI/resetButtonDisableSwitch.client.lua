local StarterGui = game:GetService('StarterGui')

local s,e

repeat
	s, e = pcall(function()
		StarterGui:SetCore("ResetButtonCallback",false)
	end)
until s