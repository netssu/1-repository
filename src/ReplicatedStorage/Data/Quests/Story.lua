local module = {}

for _, childModule in script:GetChildren() do
	for _, info in require(childModule) do
		table.insert(module, info)
	end
end

return module
