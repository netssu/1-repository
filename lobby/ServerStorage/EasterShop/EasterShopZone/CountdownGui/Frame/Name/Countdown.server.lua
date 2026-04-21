local textLabel = script.Parent
local stroke = textLabel.UIStroke

local TargetTime = os.time({
	year = 2025,
	month = 4,
	day = 26,
	hour = 16,
	min = 0,
	sec = 0
})

local function numbertotime(number)
	local Days = math.floor(number / 86400)
	local Hours = math.floor(number % 86400 / 3600)
	local Minutes = math.floor(number % 3600 / 60)
	local Seconds = number % 60

	if Minutes < 10 and Hours > 0 then
		Minutes = "0" .. Minutes
	end

	if Seconds < 10 then
		Seconds = "0" .. Seconds
	end

	if Days > 0 then
		return `{Days}:{Hours}:{Minutes}:{Seconds}`
	else
		return `{Hours}:{Minutes}:{Seconds}`
	end
end

while true do
	local timeRemaining = TargetTime - os.time()

	if timeRemaining <= 0 then
		textLabel.Text = "Easter Event has Ended!"
		break
	end

	textLabel.Text = "Easter Event Ending in " .. numbertotime(timeRemaining)

	textLabel.TextTransparency = 0.2
	textLabel.TextStrokeTransparency = 0.2
	stroke.Transparency = 0.2
	task.wait(1)

	textLabel.TextTransparency = 0.9
	textLabel.TextStrokeTransparency = 0.9
	stroke.Transparency = 1
	task.wait(1)
end
