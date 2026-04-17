while task.wait(1) do
	local day = os.date("*t").day
	
	if workspace:GetAttribute("Day") ~= day then
		workspace:SetAttribute("Day", day)
	end
end