local module = {}

local attempts = 10
local interval = 0.1

function module.attemptPcall(fn)
	local success = false
	local result = nil
	
	repeat
		local s,e = pcall(fn)
		success = s
		result = e
	until success
	
	return success, result
end


return module