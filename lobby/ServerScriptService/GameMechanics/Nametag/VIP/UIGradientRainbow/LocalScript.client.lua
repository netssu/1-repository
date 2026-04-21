grad = script.Parent -- the gradient
t = 1 -- amount of time it takes to get from 0 to 1
range = 7 -- amount of colors

while wait() do
	local loop = tick() % t / t -- returns value from 0 to 1
	colors = {} -- table of colors
	for i = 1, range + 1, 1 do
		z = Color3.fromHSV(loop - ((i - 1)/range), 1, 1)  -- subtracting by a fraction essentially "rewinds" the color to a previous state
		-- I subtract one from "i" because Lua has a starting index of one
		if loop - ((i - 1) / range) < 0 then -- the minimum is 0, if it goes below, add one
			z = Color3.fromHSV((loop - ((i - 1) / range)) + 1, 1, 1)
		end
		local d = ColorSequenceKeypoint.new((i - 1) / range, z)
		table.insert(colors, d) -- insert color into table
	end
	grad.Color = ColorSequence.new(colors) -- apply colorsequence
end