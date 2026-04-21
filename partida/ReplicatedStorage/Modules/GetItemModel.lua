local module = {}
local RS = game:GetService("ReplicatedStorage")
for _, item in RS.Items:GetDescendants() do
	if item:IsA("Model") then
		module[item.Name] = item
	end
end

return module
