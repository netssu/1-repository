local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local module = {}
local activeTweens = {}

local function isServer()
	return RunService:IsServer()
end

local function getRunServiceEvent()
	return isServer() and RunService.Heartbeat or RunService.RenderStepped
end

local function lerp(start, goal, alpha)
	return start + (goal - start) * alpha
end

local function lerpCFrame(start, goal, alpha)
	return start:Lerp(goal, alpha)
end

local function getTweenKey(obj, property)
	return tostring(obj) .. ":" .. property
end

local function cancelExistingTween(obj, property)
	local key = getTweenKey(obj, property)
	if activeTweens[key] then
		activeTweens[key]:Disconnect()
		activeTweens[key] = nil
	end
end

local function registerTween(obj, property, connection)
	local key = getTweenKey(obj, property)
	activeTweens[key] = connection
end

local function unregisterTween(obj, property)
	local key = getTweenKey(obj, property)
	activeTweens[key] = nil
end

local function createRunServiceTween(obj, length, details, onComplete)
	local tweenInfo = typeof(length) == "number" and TweenInfo.new(length) or length
	local duration = tweenInfo.Time
	local easingStyle = tweenInfo.EasingStyle
	local easingDirection = tweenInfo.EasingDirection

	local startTime = tick()
	local startValues = {}
	local goalValues = {}
	local connections = {}

	for property, value in pairs(details) do
		cancelExistingTween(obj, property)
		startValues[property] = obj[property]
		goalValues[property] = value
	end

	for property in pairs(details) do
		local connection
		connection = getRunServiceEvent():Connect(function()
			local elapsed = tick() - startTime
			local alpha = math.min(elapsed / duration, 1)

			alpha = TweenService:GetValue(alpha, easingStyle, easingDirection)

			local startValue = startValues[property]
			local goalValue = goalValues[property]

			if typeof(startValue) == "CFrame" then
				obj[property] = lerpCFrame(startValue, goalValue, alpha)
			else
				obj[property] = lerp(startValue, goalValue, alpha)
			end

			if alpha >= 1 then
				connection:Disconnect()
				unregisterTween(obj, property)
				connections[property] = nil

				local allComplete = true
				for _ in pairs(connections) do
					allComplete = false
					break
				end

				if allComplete and onComplete then
					onComplete()
				end
			end
		end)

		connections[property] = connection
		registerTween(obj, property, connection)
	end

	return {
		connections = connections,
		Stop = function()
			for property, connection in pairs(connections) do
				connection:Disconnect()
				unregisterTween(obj, property)
			end
			connections = {}
		end
	}
end

local function createPivotTween(obj, pivotCFrame, length, runService)
	if runService then
		local property = obj:IsA('Model') and "PivotCFrame" or "WorldCFrame"
		local startCFrame = obj:IsA('Model') and obj:GetPivot() or obj.WorldCFrame

		cancelExistingTween(obj, property)

		local tweenObj = {[property] = startCFrame}
		local connection = createRunServiceTween(tweenObj, length, {[property] = pivotCFrame}, function()
			if obj:IsA('Model') then
				obj:PivotTo(pivotCFrame)
			else
				obj.WorldCFrame = pivotCFrame
			end
		end)

		registerTween(obj, property, connection.connections[property])

		return connection
	else
		local cfValue = Instance.new("CFrameValue")
		cfValue.Value = obj:IsA('Model') and obj:GetPivot() or obj.WorldCFrame

		local conn
		conn = cfValue.Changed:Connect(function()
			if obj:IsA('Model') then
				obj:PivotTo(cfValue.Value)
			else
				obj.WorldCFrame = cfValue.Value
			end
		end)

		local tween = TweenService:Create(cfValue, length, {Value = pivotCFrame})
		tween:Play()

		task.delay(length.Time, function()
			conn:Disconnect()
			cfValue:Destroy()
		end)

		return tween
	end
end

local function createRegularTween(obj, length, details, runService)
	if runService then
		return createRunServiceTween(obj, length, details)
	else
		local tween = TweenService:Create(obj, length, details)
		tween:Play()

		task.delay(length.Time, function()
			if tween then
				tween:Destroy()
			end
		end)

		return tween
	end
end

function module.tween(obj, length, details, runService)
	if typeof(length) == "number" then
		length = TweenInfo.new(length)
	end

	local pivotCFrame = details.CFrame or details.WorldCFrame
	if pivotCFrame then
		details.CFrame = nil
	end

	local pivotTween = nil
	if pivotCFrame and typeof(obj) == "Instance" and (obj:IsA("Model") or obj:IsA('Attachment')) then
		pivotTween = createPivotTween(obj, pivotCFrame, length, runService)
	end

	local otherTween = nil
	if next(details) ~= nil then
		otherTween = createRegularTween(obj, length, details, runService)
	end

	return pivotTween or otherTween
end

return module