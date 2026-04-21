local RockModule = {}

local TS = game:GetService("TweenService")
local vfxfolder = workspace.VFX
function RockModule.SpawnPart(size, cf, centerCF, material, MaterialVariant, transparency, color, tweeninfo)
	local part = Instance.new("Part")
	part.Material = material
	part.MaterialVariant = MaterialVariant
	part.Size = Vector3.new(0,0,0)
	part.Name = "CraterPart"
	part.Transparency = transparency
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Color = color
	part.CFrame = centerCF
	TS:Create(part, tweeninfo, {Size=size,CFrame=cf}):Play()
	return part
end

function RockModule.RandomAngle()
	return CFrame.Angles(math.rad(math.random(0,360)), math.rad(math.random(0,360)), math.rad(math.random(0,360)))
end

function RockModule.Crater(origin, direction, segments, radius, height, width, xAngle, speed, lifetime)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local includedInstances = {}
	for i, v in game.Workspace:GetDescendants() do
		if v.Name.lower() == "terrain" or v.Name.lower() == "path" or v.Name.lower() == "track" then
			table.insert(includedInstances,v)
		end
	end
	params.FilterDescendantsInstances = includedInstances

	local cast = workspace:Raycast(origin, direction, params)

	if cast then
		local centerCF = CFrame.new(cast.Position,cast.Position + cast.Normal) * CFrame.Angles(math.rad(90),0,0)
		local angle = 360/segments
		local distance = radius * math.sin(math.rad((180 - angle)/2))
		local sideLength = 2 * (radius) * math.sin(math.rad(180/segments))
		for i = 1, segments do
			local size = Vector3.new(sideLength, height + math.random(-height,height)/10, width + math.random(-width,width)/10)
			local cf = centerCF * CFrame.Angles(0,math.rad((i-1) * angle), 0) * CFrame.new(0,0,-distance) * CFrame.Angles(math.rad(xAngle),0,0)
			local newCast = workspace:Raycast(cf.Position + cast.Normal * 2, cast.Normal * -4, params)
			if newCast then
				local diff = cf.Position - newCast.Position
				cf -= diff
				local part = RockModule.SpawnPart(
					size,
					cf,
					centerCF * CFrame.Angles(0,math.rad((i-1) * angle), 0),
					newCast.Material,
					newCast.Instance.Transparency,
					newCast.Instance.Color,
					TweenInfo.new(speed)
				)
				part.Parent = vfxfolder
				task.delay(lifetime,function()
					TS:Create(part,TweenInfo.new(speed), {Size = Vector3.new(0,0,0)}):Play()
					game.Debris:AddItem(part,speed)
				end)
			end
		end
	end
end

function RockModule.Trail(origin, direction, distance, width, size, widthM, sizeM, speed, round, segmentSize, lifetime)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local includedInstances = {}
	local map = workspace.Map:FindFirstChildOfClass("Folder")
	local includedInstances = {}
	local Build = if workspace.Info.TestingMode.Value ~= true then map.Build else nil
	local Path = if workspace.Info.TestingMode.Value ~= true then map.Path else nil
	local folders = {map.GroundPlace,Build,Path}
	for i, folder in folders do
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") then
				table.insert(includedInstances,part)
			end
		end
	end

	params.FilterDescendantsInstances = includedInstances
	local ti = TweenInfo.new(speed, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local c1, c2

	for i=1, distance do
		c1 = origin * CFrame.new(width + (i * widthM),5,-i)
		local newCast = workspace:Raycast(c1.Position, Vector3.new(0,-10,0), params)
		if newCast then
			c1 = CFrame.new(newCast.Position) * RockModule.RandomAngle()
			local MaterialVariant = nil
			if newCast.Instance.MaterialVariant then
				MaterialVariant = newCast.Instance.MaterialVariant
			end
			
			local part = RockModule.SpawnPart(
				size * (1 + (sizeM * i)), c1 * RockModule.RandomAngle(),
				c1 - Vector3.new(0,1,0),
				newCast.Material,
				MaterialVariant,
				newCast.Instance.Transparency,
				newCast.Instance.Color,
				ti
			)
			part.Parent = vfxfolder
			task.delay(lifetime,function()
				TS:Create(part,TweenInfo.new(speed), {Size = Vector3.new(0,0,0)}):Play()
				game.Debris:AddItem(part,speed)
			end)
		end

		c2 = origin * CFrame.new(-width - (i * widthM), 5, -i)
		local newCast = workspace:Raycast(c2.Position, Vector3.new(0,-10,0), params)
		if newCast then
			c2 = CFrame.new(newCast.Position) * RockModule.RandomAngle()
			local MaterialVariant = nil
			if newCast.Instance.MaterialVariant then
				MaterialVariant = newCast.Instance.MaterialVariant
			end
			local part = RockModule.SpawnPart(
				size * (1 + (sizeM * i)),
				c2 * RockModule.RandomAngle(),
				c2 - Vector3.new(0,1,0),
				newCast.Material,
				MaterialVariant,
				newCast.Instance.Transparency,
				newCast.Instance.Color,
				ti
			)
			part.Parent = vfxfolder
			task.delay(lifetime,function()
				TS:Create(part,TweenInfo.new(speed), {Size = Vector3.new(0,0,0)}):Play()
				game.Debris:AddItem(part,speed)
			end)
		end
		if i%segmentSize == 0 then
			wait()
		end
	end

	if round == true then
		local dist = (c1.Position - c2.Position).Magnitude
		local segments = math.ceil(dist)
		local center = CFrame.new((c1.Position + c2.Position)/2, (c1.Position + c2.Position)/2 + origin.LookVector) * CFrame.Angles(0,math.rad(-90),0)
		local angle = (180/segments)
		for i = 1, segments do
			local r1 = center * CFrame.Angles(0,math.rad((i-1) * angle),0) * CFrame.new(0,0,-dist/2)
			local newCast = workspace:Raycast(r1.Position + Vector3.new(0,1,0), Vector3.new(0,-10,0), params)
			if newCast then
				r1 = CFrame.new(newCast.Position) * RockModule.RandomAngle()
				local MaterialVariant = nil
				if newCast.Instance.MaterialVariant then
					MaterialVariant = newCast.Instance.MaterialVariant
				end
				local part = RockModule.SpawnPart(
					size * (1 + (sizeM * distance)),
					r1 * RockModule.RandomAngle(),
					r1 - Vector3.new(0,1,0),
					newCast.Material,
					MaterialVariant,
					newCast.Instance.Transparency,
					newCast.Instance.Color,
					ti
				)
				part.Parent = vfxfolder
				task.delay(lifetime,function()
					TS:Create(part,TweenInfo.new(speed), {Size = Vector3.new(0,0,0)}):Play()
					game.Debris:AddItem(part,speed)
				end)
			end
		end
	end
end

return RockModule
