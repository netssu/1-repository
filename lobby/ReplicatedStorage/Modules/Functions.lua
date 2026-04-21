--// Roblox Services
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

--// Module
local Functions = {}

function Functions.onInterval(callback: (...any) -> any, interval: number)
	local thread = task.spawn(function()
		while true do
			task.spawn(callback)
			task.wait(interval)
		end
	end)

	return function()
		task.cancel(thread)
	end
end

function Functions.callUntilSuccess(callback: (...any) -> any)
	task.spawn(function()
		while not pcall(callback) do
			task.wait()
		end
	end)
end

function Functions.tween(instance: Instance, tweenInfo: TweenInfo, props: { [string]: any })
	local tween = TweenService:Create(instance, tweenInfo, props)

	tween:Play()

	return tween
end

function Functions.addCommas(number: number)
	return tostring(number):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

function Functions.generateId()
	return string.lower(HttpService:GenerateGUID(false))
end

function Functions.getRainbowColor()
	return Color3.fromHSV((os.clock() * 0.2) % 1, 1, 1)
end

function Functions.createGleam(parent: GuiObject)
	local frame = Instance.new("Frame")
	frame.ZIndex = 1000
	frame.Size = UDim2.fromScale(1, 1)
	frame.Position = UDim2.fromScale(0, 0)
	frame.AnchorPoint = Vector2.new(0, 0)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BorderSizePixel = 0

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	gradient.Rotation = 30
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = frame
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.50, 0.50),
		NumberSequenceKeypoint.new(1, 1),
	})

	local tween = Functions.tween(gradient, TweenInfo.new(1.5), {
		Offset = Vector2.new(2, 0),
	})

	tween.Completed:Once(function()
		frame:Destroy()
	end)

	frame.Parent = parent

	return tween
end

return Functions
