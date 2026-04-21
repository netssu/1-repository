local StarterGui = game:GetService('StarterGui')
while task.wait() do
	local s,e = pcall(function()
		StarterGui:SetCore("ResetButtonCallback",false)
	end)

	if s then break end
end