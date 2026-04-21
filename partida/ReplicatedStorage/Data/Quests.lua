local module = {}

for _, v in script:GetChildren() do
	local childModule = require(v)
	module[v.Name] = childModule
end

return module
