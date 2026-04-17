for i,v in pairs(script.Parent:GetChildren()) do
	if v:IsA('Frame') then
		v.Visible = false
	end
end