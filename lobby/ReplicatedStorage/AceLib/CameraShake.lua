local module = {}

local RunService = game:GetService("RunService")

local activeShake = nil
local fadeConnection = nil
local currentIntensity = 0

function module.shakeCamera(duration: number | boolean, intensity: number)
	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Stop previous shake
	if activeShake then
		activeShake:Disconnect()
	end
	if fadeConnection then
		fadeConnection:Disconnect()
	end

	currentIntensity = intensity
	local startTime = tick()

	local function getShakeOffset()
		return Vector3.new(
			(math.random() - 0.5) * 2 * currentIntensity,
			(math.random() - 0.5) * 2 * currentIntensity,
			(math.random() - 0.5) * 2 * (currentIntensity / 2)
		)
	end

	activeShake = RunService.RenderStepped:Connect(function()
		if duration ~= true and tick() - startTime > duration then
			module.fadeOut(0.5)
			return
		end

		camera.CFrame = camera.CFrame * CFrame.new(getShakeOffset())
	end)
end

function module.fadeOut(fadeDuration: number)
	if fadeConnection then
		fadeConnection:Disconnect()
	end

	local startIntensity = currentIntensity
	local startTime = tick()

	fadeConnection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		local alpha = math.clamp(elapsed / fadeDuration, 0, 1)
		currentIntensity = startIntensity * (1 - alpha)

		if alpha >= 1 then
			currentIntensity = 0
			if activeShake then
				activeShake:Disconnect()
				activeShake = nil
			end
			fadeConnection:Disconnect()
			fadeConnection = nil
		end
	end)
end

return module
