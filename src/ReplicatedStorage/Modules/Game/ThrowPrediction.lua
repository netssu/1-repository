--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local Utility = require(ReplicatedStorage.Modules.Game.Utility)

export type ReleaseState = {
	basePos: Vector3,
	planarVelocity: Vector3,
}

export type LaunchSolution = {
	spawnPos: Vector3,
	target: Vector3,
	power: number,
	curve: number,
	distance: number,
	flightTime: number,
}

local ThrowPrediction = {}

local function ClampCurve(curveFactor: number?): number
	if typeof(curveFactor) ~= "number" then
		return 0.2
	end
	return math.clamp(curveFactor, 0, 1)
end

function ThrowPrediction.GetCharacterReleaseState(
	character: Model,
	ballPosition: Vector3?,
	ballOffset: CFrame?
): ReleaseState?
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoidRootPart then
		return nil
	end

	local rightArm = character:FindFirstChild("Right Arm")
		or character:FindFirstChild("RightHand")
		or character:FindFirstChild("RightLowerArm")
		or character:FindFirstChild("RightUpperArm")

	local basePos: Vector3
	local velocity = humanoidRootPart.AssemblyLinearVelocity

	if rightArm and rightArm:IsA("BasePart") then
		basePos = if ballOffset then (rightArm.CFrame * ballOffset).Position else rightArm.Position
		velocity = rightArm.AssemblyLinearVelocity
	elseif typeof(ballPosition) == "Vector3" then
		basePos = ballPosition
	else
		basePos = humanoidRootPart.Position
	end

	return {
		basePos = basePos,
		planarVelocity = Vector3.new(velocity.X, 0, velocity.Z),
	}
end

function ThrowPrediction.ResolveLaunchFromReleaseState(
	releaseState: ReleaseState,
	target: Vector3,
	curveFactor: number?,
	motionTimeOffset: number?,
	overrideConfig: {[string]: any}?
): LaunchSolution?
	if typeof(target) ~= "Vector3" then
		return nil
	end

	local throwConfig = FTConfig.THROW_CONFIG
	local maxDistance = if overrideConfig and typeof(overrideConfig.MaxDistance) == "number"
		then overrideConfig.MaxDistance
		else throwConfig.MaxThrowDistance
	local minPower = if overrideConfig and typeof(overrideConfig.MinPower) == "number"
		then overrideConfig.MinPower
		else throwConfig.MinThrowPower
	local maxPower = if overrideConfig and typeof(overrideConfig.MaxPower) == "number"
		then overrideConfig.MaxPower
		else throwConfig.MaxThrowPower
	local timeDivisor = if overrideConfig and typeof(overrideConfig.TimeDivisor) == "number"
		then overrideConfig.TimeDivisor
		else throwConfig.TimeDivisor
	local minFlightTime = if overrideConfig and typeof(overrideConfig.MinTime) == "number"
		then overrideConfig.MinTime
		else throwConfig.MinFlightTime
	local maxFlightTime = if overrideConfig and typeof(overrideConfig.MaxTime) == "number"
		then overrideConfig.MaxTime
		else throwConfig.MaxFlightTime

	local spawnPos = releaseState.basePos + (releaseState.planarVelocity * (motionTimeOffset or 0))
	local offset = target - spawnPos
	if offset.Magnitude < 1e-4 then
		return nil
	end

	local direction = offset.Unit
	local clampedTarget = if offset.Magnitude > maxDistance then spawnPos + (direction * maxDistance) else target
	local validTarget = Utility.ClampToMap(clampedTarget)
	local distance = (validTarget - spawnPos).Magnitude
	if distance < 1e-4 then
		return nil
	end

	local desiredFlightTime = math.clamp(distance / math.max(timeDivisor, 1), minFlightTime, maxFlightTime)
	local appliedPower = math.clamp(distance / math.max(desiredFlightTime, 0.05), minPower, maxPower)

	return {
		spawnPos = spawnPos,
		target = validTarget,
		power = appliedPower,
		curve = ClampCurve(curveFactor),
		distance = distance,
		flightTime = distance / math.max(appliedPower, 0.05),
	}
end

function ThrowPrediction.ResolveSpinType(requestId: number?): number
	if typeof(requestId) ~= "number" or requestId <= 0 then
		return 1
	end
	return ((math.floor(requestId) - 1) % 3) + 1
end

function ThrowPrediction.GetPositionAtServerTime(
	launchTime: number,
	serverTime: number,
	solution: LaunchSolution
): Vector3
	local elapsed = math.max(0, serverTime - launchTime)
	return Utility.GetPositionAtTime(elapsed, solution.spawnPos, solution.target, solution.power, solution.curve)
end

return ThrowPrediction
