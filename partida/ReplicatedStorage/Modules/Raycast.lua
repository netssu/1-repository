local Raycast = {}

function Raycast.UpVector(Target: Part, Blacklist: {any: any}) : RaycastResult
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = Blacklist
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	return workspace:Raycast(Target.Position, Target.CFrame.UpVector * - 500, params)
end

return Raycast
