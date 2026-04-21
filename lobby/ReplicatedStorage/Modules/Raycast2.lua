local Raycast = {}

function Raycast.UpVector(Target: Model, List: {any}, distance: number?) : (RaycastResult)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = List
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	
	return workspace:Raycast(
		Target:GetPivot().Position + Vector3.new(0, 5, 0),
		Vector3.new(0, distance or -500, 0),
		params
	)
end

return Raycast
