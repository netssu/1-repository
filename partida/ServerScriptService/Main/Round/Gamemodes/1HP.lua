local module = {}
for _, map in script:GetChildren() do
	for i, v in map:GetChildren() do
		if not module[map.Name] then
			module[map.Name] = {}
		end
		module[map.Name][v.Name] = require(v)
	end
end

return module