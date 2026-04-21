local ServerStorage = game:GetService("ServerStorage")
local MobsSpecification = require(ServerStorage.ServerModules.MobsSpecification)

local function mag(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

task.spawn(function()
	while task.wait(.5) do
		for i,v in workspace.Towers:GetChildren() do
			if v == script.Parent then continue end
			
			print(script.Parent.Name .. " is applying debuff to: " .. v.Name)
			
			local position = script.Parent:GetPivot().Position

			if mag(script.Parent:GetPivot().Position, v:GetPivot().Position) < 15 then
				MobsSpecification.applyEffect(script.Parent, v, "Debuff", "Damage Decrease", 30)
			end
		end
	end
end)
