local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Makes a tween of the model's scale with given Tween Info.
local function tweenModelScale(startScale: number, endScale: number, info: { any }, model: Model): ()
	local elapsed = 0
	local scale = 0

	local tweenInfo = TweenInfo.new(table.unpack(info))

	while elapsed < tweenInfo.Time do
		local deltaTime = RunService.Heartbeat:Wait()

		elapsed = math.min(elapsed + deltaTime, tweenInfo.Time)

		local alpha = TweenService:GetValue(elapsed / tweenInfo.Time, tweenInfo.EasingStyle, tweenInfo.EasingDirection)

		scale = startScale + alpha * (endScale - startScale)

		model:ScaleTo(scale)
	end
end

return tweenModelScale
