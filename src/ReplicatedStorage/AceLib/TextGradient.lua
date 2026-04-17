local module = {}

local function lerpColor(c1, c2, alpha)
	local r = c1.R + (c2.R - c1.R) * alpha
	local g = c1.G + (c2.G - c1.G) * alpha
	local b = c1.B + (c2.B - c1.B) * alpha
	return Color3.new(r, g, b)
end

local function getColorAt(t, colorSequence)
	local keypoints = colorSequence.Keypoints
	if t <= keypoints[1].Time then
		return keypoints[1].Value
	elseif t >= keypoints[#keypoints].Time then
		return keypoints[#keypoints].Value
	end

	for i = 1, #keypoints - 1 do
		local k1, k2 = keypoints[i], keypoints[i + 1]
		if t >= k1.Time and t <= k2.Time then
			local alpha = (t - k1.Time) / (k2.Time - k1.Time)
			return lerpColor(k1.Value, k2.Value, alpha)
		end
	end
end

function module.textGradient(text, colorSequence)
	local length = #text
	if length == 0 then return "" end

	local result = ""
	for i = 1, length do
		local t = (i - 1) / (length - 1)
		local color = getColorAt(t, colorSequence)
		local r = math.floor(color.R * 255)
		local g = math.floor(color.G * 255)
		local b = math.floor(color.B * 255)
		local hex = string.format("%02X%02X%02X", r, g, b)
		result ..= `<font color="#{hex}">` .. text:sub(i, i) .. `</font>`
	end

	return result
end

return module