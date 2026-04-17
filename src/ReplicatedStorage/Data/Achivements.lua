local module = {}

for _, childModule in script:GetChildren() do
	if childModule:IsA('ModuleScript') then
		table.insert(module, require(childModule))
	end
end

return module
