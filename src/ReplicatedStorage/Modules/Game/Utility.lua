--!strict

local Workspace = game:GetService("Workspace")

local Utility = {}

--\\ PUBLIC FUNCTIONS \\ -- TR

function Utility.GetPositionAtTime(t: number, StartPos: Vector3, TargetPos: Vector3, Power: number, CurveFactor: number?): Vector3
	local Distance: number = (TargetPos - StartPos).Magnitude
	if Power <= 0 or Distance <= 0 then return StartPos end
	
	local TimeToTarget: number = Distance / Power
	local Progress: number = math.clamp(t / TimeToTarget, 0, 1)
	
	local HorizontalPos: Vector3 = StartPos:Lerp(TargetPos, Progress)
	
	local Curve: number = CurveFactor or 0
	local MaxHeight: number = Distance * Curve
	local Height: number = 4 * MaxHeight * Progress * (1 - Progress)
	
	return HorizontalPos + Vector3.new(0, Height, 0)
end

function Utility.GetImpactPoint(StartPos: Vector3, Direction: Vector3, MaxDist: number): Vector3
	local RayParams: RaycastParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Include
	
	--\\ STRICT MAP FILTERING \\ -- TR
	local Map: Instance? = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Mapa")
	if Map then
		RayParams.FilterDescendantsInstances = {Map}
	else
		RayParams.FilterType = Enum.RaycastFilterType.Exclude
		RayParams.FilterDescendantsInstances = {}
	end
	
	local Result: RaycastResult? = Workspace:Raycast(StartPos, Direction * MaxDist, RayParams)
	
	if Result then
		return Result.Position
	end
	
	local EndPoint: Vector3 = StartPos + Direction * MaxDist
	return Vector3.new(EndPoint.X, 0, EndPoint.Z)
end

function Utility.ClampToMap(Position: Vector3): Vector3
	local ClampedY: number = math.max(Position.Y, 0)
	return Vector3.new(Position.X, ClampedY, Position.Z)
end

return Utility