if true then return end

local goldColors = {
	Color3.fromRGB(234, 120, 36),   -- Bright Gold
	Color3.fromRGB(242, 167, 82),   -- Medium Gold
	Color3.fromRGB(234, 120, 36),  -- Goldenrod
}

local grad = script.Parent
local runService = game:GetService("RunService")
local t = 2 -- seconds per full cycle
local colorCount = #goldColors

runService.RenderStepped:Connect(function()
	local time = tick()
	local progress = (time % t) / t * (colorCount - 1)
	local index = math.floor(progress) + 1
	local nextIndex = index % colorCount + 1
	local lerpAlpha = progress % 1

	local color = goldColors[index]:Lerp(goldColors[nextIndex], lerpAlpha)
	grad.Color = ColorSequence.new(color)
end)
