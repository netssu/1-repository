local module = {}
local RS = game:GetService("ReplicatedStorage")
for _, boss in RS.Bosses:GetDescendants() do
	if boss:IsA("Model") then
		module[boss.Name] = boss
	end
end

return module
