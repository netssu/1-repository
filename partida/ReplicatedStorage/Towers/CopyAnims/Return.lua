local module = {}

for i, v in script.Parent:GetDescendants() do
	if v:IsA("Configuration") then
		module[v.Name] = v
	end
end

return module
