local module = {}
local RS = game:GetService("ReplicatedStorage")
for _, unit in RS.Towers:GetDescendants() do
	if unit:IsA("Model") then
		module[unit.Name] = unit
	end
end

return module
