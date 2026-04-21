local TweenService = game:GetService("TweenService")

local module = {}

function module.tween(obj: Instance, length: number, details: {})
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

return module