local TweenService = game:GetService("TweenService")

type Params = {
	Duration: number;
	DecalTween: number;
	MeshTween: string;
	PartTween: string;
}

local function getTweenData(obj: Instance, duration: number, prefix: string, defaultStyle: Enum.EasingStyle)
	local Params: Params = obj:GetAttribute(prefix .. "_TweenParams")    

	local DefaultParams = {
		{ "TweenStyle", defaultStyle },
		{ "TweenDirection", Enum.EasingDirection.Out },
	}

	local Values = {} :: {
		TweenStyle: Enum.EasingStyle,
		TweenDirection: Enum.EasingDirection,
	}

	if typeof(Params) == "string" then
		local Matches = { Params:match("(%a+),(%a+)") }

		for Index = 1, 2 do
			local Value = Matches[Index]
			local Param = DefaultParams[Index]

			local Key = Param[1]
			local Default = Param[2]

			if not Value then
				Values[Key] = Default
			else
				local Success = pcall(function()
					Values[Key] = Enum[Key][Value]
				end)

				if not Success then
					Values[Key] = Default
				end
			end
		end
	else
		for _, Param in DefaultParams do
			local Key = Param[1]
			local Default = Param[2]

			Values[Key] = Default
		end
	end

	return TweenInfo.new(duration, Values.TweenStyle, Values.TweenDirection)
end

return function(obj: BasePart)
	local Goal = obj.Parent:FindFirstChild("End")

	if not Goal then
		warn("Goal is not defined.")
		return
	end

	local Clone = obj:Clone()

	local StartTransparency = tonumber(obj.Parent:GetAttribute("StartTransparency")) or 0

	if Clone:IsA("MeshPart") then
		Clone.Transparency = StartTransparency
	elseif Clone:IsA("BasePart")  then
		if Clone:FindFirstChildOfClass("Decal") then
			Clone.Transparency = 1
		end
	end

	Clone.Parent = workspace.temp

	local Duration = tonumber(obj.Parent:GetAttribute("Duration")) or 0.1

	if Clone:FindFirstChildOfClass("Decal") then
		TweenService:Create(Clone, getTweenData(obj.Parent, Duration, "Part", Enum.EasingStyle.Cubic), { Size = Goal.Size, CFrame = Goal.CFrame}):Play()
	else
		TweenService:Create(Clone, getTweenData(obj.Parent, Duration, "Part", Enum.EasingStyle.Cubic), { Size = Goal.Size, CFrame = Goal.CFrame, Transparency = 1 }):Play()
	end


	local Mesh = Clone:FindFirstChildOfClass("SpecialMesh")
	local GoalMesh = Goal:FindFirstChildOfClass("SpecialMesh")   

	if Mesh and GoalMesh then
		TweenService:Create(Mesh, getTweenData(obj.Parent, Duration, "Mesh", Enum.EasingStyle.Sine), { Scale = GoalMesh.Scale }):Play()
	end

	local Decal = Clone:FindFirstChildOfClass("Decal")
	local GoalDecal = Goal:FindFirstChildOfClass("Decal")

	if Decal and GoalDecal then
		Decal.Transparency = 0
		TweenService:Create(Decal, getTweenData(obj.Parent, Duration, "Decal", Enum.EasingStyle.Cubic), { Transparency = GoalDecal.Transparency, Color3 = GoalDecal.Color3 }):Play()
	end

	task.delay(Duration, Clone.Destroy, Clone)
end

