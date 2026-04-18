local api = shared.fx
local RunS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local IsClient, IsEdit = RunS:IsClient(), api.ui ~= nil

local function GetTweenData(attr, dur)
	if not attr then return end
	attr = attr:split(",")

	for k, v in attr do
		attr[k] = (v ~= "" and v or nil)
	end

	return TweenInfo.new(
		attr[6] or dur,
		Enum.EasingStyle[attr[1] or "Quad"],
		Enum.EasingDirection[attr[2] or "In"],
		tonumber(attr[3]) or 0,
		attr[4] == "t",
		tonumber(attr[5]) or 0
	)
end

local function Rotate(a, speed, weld)
	speed = type(speed) == "number" and vector.create(0,speed,0) or speed
	local c = (IsClient and RunS.PreRender or RunS.Heartbeat):Connect(function(dt)
		local b = speed*dt
		a[weld and "C0" or "CFrame"] *= CFrame.Angles(b.X, b.Y, b.Z)
	end)

	a.Destroying:Once(function()
		c:Disconnect()
	end)
end

local function PlayFlipbook(decal, textures, lifetime, easing)
	local i = 1
	if not textures then return end

	local len = #textures
	while decal.Parent do
		decal.Texture = textures[i]
		i = i == len and 1 or i+1
		task.wait(lifetime/len)
	end
end

local function ismeshvfx(v, class)
	class = class or v.ClassName
	if v:HasTag("MeshVFX") then return true end
	local g = (class == "Model" or class == "Folder" or class == "UnionOperation" or class == "MeshPart" or class == "Part") and v:FindFirstChild("End")
	if g and g:IsA("BasePart") then return true end
end

local emit = api.emit
local num, temp = api.num, api.temp
local containers = api.classes.container

api.add {
	selector = "Folder,BasePart,Model",
	retime = function(vfx, scale, origins, class)
		if not ismeshvfx(vfx, class) then return end

		local o, r
		if origins ~= false then
			if origins then
				o = origins.MFXDuration or vfx:GetAttribute("Duration") or 1
				r = origins.MFXRotSpeed or vfx:GetAttribute("RotSpeed") or Vector3.zero
			else
				origins = {}
				o = vfx:GetAttribute("Duration") or 1
				r = vfx:GetAttribute("RotSpeed") or Vector3.zero
			end
		end

		origins.MFXDuration, origins.MFXRotSpeed = o, r; r = r*scale
		o = scale == 0 and 0 or type(o) == "number" and o/scale or NumberRange.new(o.Min/scale, o.Max/scale)
		o, r = o ~= 1 and o or nil, r ~= Vector3.zero and r or nil

		vfx:SetAttribute("Duration", o); vfx:SetAttribute("RotSpeed", r)
		return origins
	end,
	recolor = function(vfx, h,s,l,c, origins, class)
		local name = vfx.Name
		class = class or vfx.ClassName
		if ismeshvfx(vfx, class) or (ismeshvfx(vfx.Parent) and vfx:IsA("BasePart")) then
			if class == "Folder" or class == "Model" then return end

			local o = origins and origins.Color or vfx.Color
			if not o then return end
			origins = origins or {}

			origins.Color = o
			vfx.Color = api.adjustColor(o, h,s,l,c, true)
			return origins
		end
	end,
	emit = function(vfx, attrs)
		if not workspace:IsAncestorOf(vfx) then return end

		local name = vfx.Name
		local class = vfx.ClassName
		local container = (class == "Folder" or class == "Model") and vfx
		if not (vfx:IsA("BasePart") or container) or name == "End" then
			return
		end

		local parent = vfx.Parent
		if parent == temp then return end
		if name == "Start" or name == "End" and containers[parent.ClassName] and parent ~= workspace then
			if IsEdit then parent:SetAttribute("EmitBreak", true) emit(parent) end return
		end

		local End
		if container then
			vfx = container:FindFirstChild("Start")
			if not vfx then return end
			End = container:FindFirstChild("End")
		else
			container = vfx
			End = vfx:FindFirstChild("End")
		end

		if not (End and End:IsA("BasePart")) then return end -- later might make end not required
		attrs.EmitBreak = true

		local Duration = attrs.Duration
		local Locked = attrs.LockedToPart
		local Decal = vfx:FindFirstChildOfClass("Decal")
		local partparams = attrs.Part_TweenParams or ""
		local Params = type(Duration) == "number" and GetTweenData(partparams, Duration)

		local RotSpeed = attrs.RotSpeed
		local EmitCount = num(attrs.EmitCount, 1)
		local StartTransp = attrs.StartTransparency
		local FadeIn = num(attrs.FadeInTime, 0)
		if RotSpeed then RotSpeed = RotSpeed*math.rad(1) end

		local Clean if EmitCount > 1 then
			Clean = vfx:Clone()
			local children = Clean:GetChildren()

			if container == vfx then
				if End then
					Clean:FindFirstChild("End"):Destroy()
				end

				for k, v in children do
					if v.Name == "MeshEmit" then
						children[k] = nil
						v:Destroy()
					end
				end
			end
		end

		local goal
		local special
		local osize, opos
		local specialgoal
		Locked = Locked and {} -- here its weldgoal
		local origin = vfx.CFrame
		local cfrotspeed = Vector3.zero
		local DecalGoals, DecalAttrs if End then
			DecalGoals = {}
			local cf = End.CFrame
			local poso = origin.Position

			if Locked then
				cf = End.CFrame:Inverse() * vfx.CFrame
				poso = (origin:Inverse() * vfx.CFrame).Position
			end

			special = End:FindFirstChild("Mesh")
			specialgoal = special and {Scale = specialgoal}
			osize, opos = special and special.Scale or End.Size, cf.Position

			local rot1 = origin-poso
			local rot2 = cf-opos if rot1 ~= rot2 then
				if Locked then
					cfrotspeed = vector.zero
				else
					cfrotspeed = vector.create(rot2:ToEulerAnglesXYZ())-vector.create(rot1:ToEulerAnglesXYZ())
				end
			end origin = poso

			goal = {
				Color = End.Color, Size = if special then nil else osize,
				Transparency = attrs.EndTransparency or 1
			}

			if Locked then
				if cfrotspeed.Magnitude > 0.1 then Locked.C1 = cf else Locked.C1 = CFrame.new(poso) end
			else
				if cfrotspeed.Magnitude > 0.1 then goal.CFrame = cf else goal.Position = poso end
			end
		end

		DecalAttrs = {}
		for _, decal in vfx:QueryDescendants(">Decal") do
			local name = decal.Name
			local decalGoal = End and End:FindFirstChild(name)
			
			if decalGoal then
				DecalGoals[name] = {
					Color3 = decalGoal.Color3,
					Transparency = attrs.FadeDecals and (attrs.EndTransparency or 1) or nil
				}
			end

			local a = decal:GetAttributes()
			local fb = a.Flipbook if fb then
				fb = fb:split(",")
				for k, v in fb do fb[k] = "rbxassetid://"..v end
				a.Flipbook = fb
			end

			DecalAttrs[name] = a
		end

		local ranrot = attrs.Rotation
		ranrot = ranrot and ranrot:Abs()*math.rad(1)

		local spread = attrs.SpreadAngle
		local distance, scale = attrs.Distance, attrs.Scale
		local forward = End and End.CFrame.LookVector

		local EmitClone = attrs.EmitClone
		for i=1,num(attrs.EmitCount, 1) do
			local clone = (Clean or vfx):Clone()
			local children = clone:GetChildren()

			if not Clean and container == vfx and End then
				clone:FindFirstChild("End"):Destroy()
			end

			local Weld if Locked then
				Weld = Instance.new("Weld")
				Weld.Part0, Weld.Part1 = vfx, clone
				Weld.C1 = clone.CFrame:Inverse()*vfx.CFrame
				clone.Massless, clone.Anchored = true, false
				Weld.Parent = clone
			end

			clone.Name = "MeshEmit" api.debris(clone)
			local dur, d, s = num(Duration, 1), num(distance, 1), num(scale, 1)
			local params = Params or GetTweenData(partparams, dur)

			local StartT = StartTransp or (not DecalGoals and 0.75) or 0
			
			if DecalGoals then
				for name, decalGoal in DecalGoals do
					local decal, a = clone:FindFirstChild(name), DecalAttrs[name]
					local st = StartTransp or 0

					if FadeIn > 0 then
						decal.Transparency = 1
						TS:Create(decal, TweenInfo.new(FadeIn), {Transparency = st}):Play()

						local mainGoal = table.clone(decalGoal)
						mainGoal.Transparency = nil
						TS:Create(decal, GetTweenData(a.TweenParams, dur) or params, mainGoal):Play()

						local endT = decalGoal.Transparency
						if endT then
							task.delay(FadeIn, function()
								if not decal.Parent then return end
								local rem = dur - FadeIn
								if rem > 0 then
									TS:Create(decal, TweenInfo.new(rem), {Transparency = endT}):Play()
								else
									decal.Transparency = endT
								end
							end)
						end
					else
						decal.Transparency = st
						TS:Create(decal, GetTweenData(a.TweenParams, dur) or params, decalGoal):Play()
					end
					task.spawn(PlayFlipbook, decal, a.Flipbook, dur)
				end
			else
				if FadeIn > 0 then
					clone.Transparency = 1
					TS:Create(clone, TweenInfo.new(FadeIn), {Transparency = StartT}):Play()
				else
					clone.Transparency = StartT
				end
				
				for name, a in DecalAttrs do
					local decal = clone:FindFirstChild(name)
					local st = StartTransp or 0

					if FadeIn > 0 then
						decal.Transparency = 1
						TS:Create(decal, TweenInfo.new(FadeIn), {Transparency = st}):Play()
					else
						decal.Transparency = st
					end
					task.spawn(PlayFlipbook, decal, a.Flipbook, dur)
				end
			end

			local m = special and clone:FindFirstChild("Mesh")

			local rps = cfrotspeed/dur

			if Locked then
				if RotSpeed then rps += RotSpeed Rotate(Weld, rps, true) elseif rps.Magnitude > 0.01 then Rotate(Weld, rps, true) end
			else
				if RotSpeed then rps += RotSpeed Rotate(clone, rps) elseif rps.Magnitude > 0.01 then Rotate(clone, rps) end
			end

			if s ~= 1 then
				if m then m.Scale *= s else clone.Size *= s end
			end

			if goal then
				if specialgoal then specialgoal.Scale = osize*s else goal.Size = osize*s end

				local pos = opos if d > 0 and not spread then
					pos = origin + (opos-origin)*d
				end local obj, prop = Locked and Weld or clone, Locked and "C0" or "CFrame"

				if spread or d < 0 then
					local gg = (opos-origin)*d
					local dir = spread and api.spread(gg, spread) or gg

					if attrs.FacePath then
						obj[prop] *= CFrame.lookAlong(Vector3.zero, -dir-forward)*CFrame.Angles(-math.pi/2, 0, 0)
					end

					pos = origin + dir
				end if ranrot then
					local x, y, z = ranrot.X, ranrot.Y, ranrot.Z
					obj[prop] *= CFrame.Angles(math.random(-x,x), math.random(-y,y), math.random(-z,z))
				end

				if Locked then
					Locked.C1 = CFrame.new(pos)
				else
					goal.Position = pos
				end

				if special and osize then
					TS:Create(m, params, specialgoal):Play()
				end

				if FadeIn > 0 then
					local mainGoal = table.clone(goal)
					mainGoal.Transparency = nil
					TS:Create(clone, params, mainGoal):Play()
					if Locked then TS:Create(Weld,params,Locked):Play() end

					local endT = goal.Transparency
					if endT then
						task.delay(FadeIn, function()
							if not clone.Parent then return end
							local rem = dur - FadeIn
							if rem > 0 then
								TS:Create(clone, TweenInfo.new(rem), {Transparency = endT}):Play()
							else
								clone.Transparency = endT
							end
						end)
					end
				else
					TS:Create(clone, params, goal):Play()
					if Locked then TS:Create(Weld,params,Locked):Play() end
				end
			end

			if EmitClone then
				emit(clone)
				api.destroyAfter(clone, math.max(api.maxLifetime(clone), dur))
			else
				api.destroyAfter(clone, dur)
			end
		end
	end
}

return {
	is = ismeshvfx
}