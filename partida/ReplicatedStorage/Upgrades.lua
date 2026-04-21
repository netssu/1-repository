local module = {}

--for _, unit in script:GetDescendants() do
--	if unit:IsA("ModuleScript") then
--		for key, value in require(unit) do			
--			module[key] = value
--		end
--	end
--end

for _, unit in script:GetDescendants() do
	if unit:IsA("ModuleScript") then
		local success, data = pcall(require, unit)
		if success and type(data) == "table" then
			for key, value in data do
				if module[key] then
					warn("DUPLICATE UNIT KEY: " .. key .. " in " .. unit:GetFullName())
					continue	
				end
				
				module[key] = value
			end
		else
			warn("Failed to load", unit:GetFullName(), ":", data)
		end
	end
end

--print(module)

return module