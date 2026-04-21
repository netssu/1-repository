local module = {}

for _, item in script:GetDescendants() do
	if item:IsA("ModuleScript") then
		for key, value in require(item) do
			module[key] = value
		end
	end
end


return module