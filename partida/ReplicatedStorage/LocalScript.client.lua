local total = ''

for i,v in pairs(game.ReplicatedStorage.Upgrades:GetDescendants()) do
	if v:IsA('ModuleScript') then
		total ..= '------------\n'
		
		local data = require(v)[v.Name]
		local unitname = data['Name']
		
		total ..= unitname .. '\n'
		total ..= 'Stats:\n'
		
		for i,v in pairs(data['Upgrades']) do
			local addData = ''
			for attribute, value in pairs(v) do
				if typeof(value) == 'table' then continue end
				addData ..= attribute .. ' = ' .. value .. ', '
			end
			
			total ..= '[' .. tostring(i) .. '] - ' .. addData .. '\n'
		end		
		
		
		
		total ..= '------------\n'
	end
end

print(total)