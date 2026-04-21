local Module = {}

for _, module : ModuleScript in script:GetChildren() do
	if module.ClassName ~= "ModuleScript" then continue end
	Module[module.Name] = require(module)
end

return (Module)