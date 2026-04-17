-- Base64Encoder Module

local Base64Encoder = {}

local base64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function Base64Encoder.Encode(input)
	local output = ""
	local bytes = { string.byte(input, 1, #input) }

	for i = 1, #bytes, 3 do
		local b1 = bytes[i]
		local b2 = bytes[i + 1] or 0
		local b3 = bytes[i + 2] or 0

		local n = bit32.bor(
			bit32.lshift(b1, 16),
			bit32.lshift(b2, 8),
			b3
		)

		local c1 = bit32.band(bit32.rshift(n, 18), 63)
		local c2 = bit32.band(bit32.rshift(n, 12), 63)
		local c3 = bit32.band(bit32.rshift(n, 6), 63)
		local c4 = bit32.band(n, 63)

		output = output .. base64chars:sub(c1 + 1, c1 + 1)
			.. base64chars:sub(c2 + 1, c2 + 1)

		if i + 1 <= #bytes then
			output = output .. base64chars:sub(c3 + 1, c3 + 1)
		else
			output = output .. "="
		end

		if i + 2 <= #bytes then
			output = output .. base64chars:sub(c4 + 1, c4 + 1)
		else
			output = output .. "="
		end
	end

	return output
end

return Base64Encoder