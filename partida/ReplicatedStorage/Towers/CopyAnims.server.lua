local Name = "Animations"
local Returned = require(script.Return)
local upgradesModule = require(script.Parent.Parent.Upgrades)
for _, v in script.Parent:GetDescendants() do
	if v:IsA("Model") and v:FindFirstChild("Humanoid") and Returned[v.Name] then
		local Configuration = Returned[v.Name]:Clone()
		Configuration.Name = Name
		Configuration.Parent = v
	end

	local NotEvoUnit = nil --IF EVO UNIT
	for unitName, Info in upgradesModule do
		if Info.Evolve and Info.Evolve.EvolvedUnit == v.Name then
			NotEvoUnit = unitName
		end
	end
    if NotEvoUnit then
        pcall(function()
    		local Configuration = Returned[NotEvoUnit]:Clone()
    		Configuration.Name = Name
            Configuration.Parent = v
        end) -- if u remove the pcall, u can see NotEvoUnit is nil or whatever
	end 
end
