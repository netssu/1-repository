local module = {}

local RS = game:GetService("ReplicatedStorage")
local Borders = RS:WaitForChild("Borders")
module.addRarityGradient = function(container,rarity,forSummon,Trasparency,Rotation)
	local g = Borders:FindFirstChild(rarity) or Borders.Rare
	module.removeAllGradients(container)

	if typeof(container) == "table" then
		for _, c in container do
			local gc = g:Clone()
			gc.Parent = c
			if Trasparency then
				gc.Transparency = Trasparency
			end
			if Rotation then
				gc.Rotation = Rotation
			end
			local isMythical = rarity == "Mythical"

			--task.spawn(function()
			--	if isMythical and (forSummon or c:IsA("TextLabel")) then
			--		local grad = gc
			--		local t = 2.8
			--		local range = 7
			--		grad.Rotation = 0 --0

			--		while grad~=nil and grad.Parent~=nil do
			--			local loop = tick() % t / t
			--			local colors = {}
			--			for i = 1, range + 1, 1 do
			--				local z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)
			--				if loop - ((i - 1) / range) < 0 then
			--					z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
			--				end
			--				local d = ColorSequenceKeypoint.new((i - 1) / range, z)
			--				table.insert(colors, d)
			--			end
			--			grad.Color = ColorSequence.new(colors)
			--			wait()
			--		end

			--	else

			--		--from koreh077,wasnt sure if we are updating to the new gradient color so i kept it the old colors
			--		--if we are then remove the line below this comment

			--		--rarity = rarity == "Mythical" and "Unique" or rarity
			--		--gc.Color = TraitsModule.TraitColors[rarity == "Mythical" and "Unique" or rarity].Gradient
			--		while gc~=nil and gc.Parent~=nil do
			--			gc.Rotation = (gc.Rotation+2)%360
			--			task.wait()
			--		end
			--	end
			--end)
		end
	elseif typeof(container) == "Instance" then
		local gc = g:Clone()
		gc.Parent = container
		if Trasparency then
			gc.Transparency = Trasparency
		end
		if Rotation then
			gc.Rotation = Rotation
		end
	end

	return

end

module.removeAllGradients = function(container)
	if typeof(container) == "table" then
		for _, c in container do
			for i, v in c:GetChildren() do
				if v:IsA("UIGradient") then
					v:Destroy()
				end
			end
		end
	elseif typeof(container) == "Instance" then
		for i, v in container:GetChildren() do
			if v:IsA("UIGradient") then
				v:Destroy()
			end
		end
	end
end

return module
