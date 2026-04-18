local module = {}
local api = shared.fx
local RunS = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local IsClient, IsEdit = RunS:IsClient(), api.ui ~= nil
local get1CSV, getCSV, getCFrame = api.csv1, api.csv, api.getCFrame

local function map(n,min,max,newMin,newMax,noClamp)
	n = noClamp and n or math.clamp(n,math.min(min,max),math.max(min,max))
	return newMin+((n-min)/(max-min))*(newMax-newMin)
end

local Defaults = {
	Preset = {
		"Custom",
		"Explosion",
		"Earthquake",
		"Vibration",
	},

	Magnitude = 1,
	Roughness = 4,
	FadeInTime = 0.1,
	FadeOutTime = 0.5,
	RotInfluence = Vector3.one,
	PosInfluence = Vector3.one*0.15,
	FalloffDistance = NumberRange.new(100,500),

	Count = 2,
	Contrast = 40,
	Saturation = 0,
	TintColor = Color3.new(1, 1, 1),
	["-Duration"] = 0.05,
	["+Duration"] = 0.05,
	Range = 300,
	MinVisiblity = 0.5
}

do -- impact frames
	local function getVisiblity(Cam, WorldPoint, IgnoreList)
		Cam = Cam or workspace.CurrentCamera

		local VisiblityScale,Parts = -1,nil
		local _, CanSee = Cam:WorldToScreenPoint(WorldPoint)

		if CanSee then
			Parts = Cam:GetPartsObscuringTarget(
				{Cam.CFrame.Position, WorldPoint},
				IgnoreList or {}
			) local Transparnecys = 1

			for K, V in Parts do
				if V.Material.Name ~= "ForceField" then
					Transparnecys *= V.Transparency
				end
			end

			VisiblityScale = Transparnecys
		end

		return VisiblityScale, Parts
	end

	local Map = {"Count","TintColor","Range","Contrast","Saturation","MinVisiblity","-Duration","+Duration"}

	local selected = api.selected if IsEdit then
		module.ImpactFrames = Map
	else
		api.add {
			recolor = function(vfx, h,s,l,c, origins)
				local TintColor = origins and origins.IFTintColor
				local attr = not TintColor and vfx:GetAttribute("ImpactFrames")
				TintColor = TintColor or get1CSV(attr, "TintColor", Map, Defaults)
				if not TintColor then return end

				origins = origins or {}
				origins.IFTintColor = TintColor
				TintColor = api.adjustColor(TintColor, h,s,l,c)
				attr = (attr or vfx:GetAttribute("ImpactFrames")):split(",")
				attr[table.find(Map, "TintColor")] = TintColor
				vfx:SetAttribute("ImpactFrames", table.concat(attr))

				return origins
			end
		}
	end

	api.add {
		emit = function(VFX, attrs)
			local attr = attrs.ImpactFrames
			if not attr then return end
			
			local IF = getCSV(attr, Map, Defaults)
			local Camera = workspace.CurrentCamera
			local VFXPos = getCFrame(VFX).Position
			if not IF or (Camera.CFrame.Position-VFXPos).Magnitude > IF[3] or getVisiblity(Camera,VFXPos,{VFX, VFX:FindFirstAncestorOfClass("BasePart")}) < IF[6] then return end

			local Count,Color,_,Cont,Sat,_,D1,D2 = unpack(IF)

			Sat = Sat or 0
			local CCE = Instance.new("ColorCorrectionEffect")
			local Old = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
			CCE.Name, CCE.Archivable = "ImpactFrames", false
			Old = Old and Old.Saturation or 0
			
			CCE.Saturation, CCE.TintColor, CCE.Parent = Sat-Old-1, Color or Color3.new(1,1,1), Lighting

			Cont = Cont or 99
			D1,D2 = D1 or 1/18,D1 or D2 or 1/18

			while Count > 0 do
				Count -= 1
				CCE.Contrast = Cont
				task.wait(D1)
				if Count <= 0 then break end

				Count -= 1
				CCE.Contrast = -Cont
				task.wait(D2)
			end

			CCE:Destroy()
		end
	}
end

do -- camera shake
	local GlobalBind, ActiveShakes = 0, {}
	local RNG, totalShake = Random.new(), CFrame.identity
	RunS:BindToRenderStep("CameraShake", 2001, function(dt)
		if not next(ActiveShakes) then return end
		local cam, edit = workspace.CurrentCamera, not RunS:IsRunning()
		
		local total = CFrame.identity
		for _, v in ActiveShakes do
			total *= v.cframe
		end
		
		if edit then
			totalShake = total
			local cf = cam.CFrame
			local rx, ry = cf:ToOrientation()
			cam.CFrame = CFrame.fromOrientation(rx, ry, 0)*totalShake:Inverse()+cf.Position
		else
			cam.CFrame *= total
		end
	end)

	local function CameraShake(
		Magnitude,
		Roughness,
		FadeInDuration,
		RotInfluence,
		PosInfluence,
		Source,
		FalloffDistance
	)
		local FadeOutDuration = 0
		local Tick = RNG:NextNumber(-100, 100)

		PosInfluence *= 0.1
		FadeInDuration = FadeInDuration or 0
		local FadeTime = FadeInDuration > 0 and 0 or 1

		GlobalBind += 1
		local Bind = "LocalCameraShake"..tostring(GlobalBind)
		local Min, Max = FalloffDistance.Min, FalloffDistance.Max
		local Property = Source:IsA("Attachment") and "WorldPosition" or Source:IsA("BasePart") and "Position"
		
		local ShakeObj = {
			finish = function(n)
				n = n or 0
				if n <= 0 then
					FadeTime = 0
					FadeInDuration = 0
					FadeOutDuration = 0
					RunS:UnbindFromRenderStep(Bind)
					ActiveShakes[Source] = nil
					return
				end

				FadeInDuration, FadeOutDuration = 0, n
			end,
			cframe = CFrame.identity
		}
		
		RunS:BindToRenderStep(Bind, 202, function(dt)
			local Offset = vector.create(
				math.noise(Tick, 0),
				math.noise(0, Tick),
				math.noise(Tick, Tick)
			) * 0.5

			local sustain = FadeOutDuration <= 0

			if not sustain then
				FadeTime -= dt / FadeOutDuration
			elseif FadeInDuration > 0 and FadeTime < 1 then
				FadeTime += dt / FadeInDuration
			end

			FadeTime = math.clamp(FadeTime, 0, 1)

			if sustain then
				Tick += dt * Roughness
			else
				Tick += dt * Roughness * FadeTime
			end

			local ShakeOffset = Offset * Magnitude * FadeTime *
				map((workspace.CurrentCamera.CFrame.Position-Source[Property]).Magnitude, Min, Max, 1, 0)

			local RotAdd = ShakeOffset * RotInfluence
			ShakeObj.cframe = CFrame.new(ShakeOffset * PosInfluence) * CFrame.Angles(
				math.rad(RotAdd.X), math.rad(RotAdd.Y), math.rad(RotAdd.Z)
			)
			
			if FadeTime <= 0 and not sustain then
				ActiveShakes[Source] = nil
				RunS:UnbindFromRenderStep(Bind) return
			end
		end)
		
		ActiveShakes[Source] = ShakeObj
		return ShakeObj
	end

	local Presets, Map = {
		Vibration = {1, nil, 20, nil, vector.one, vector.one*0.2},
		Explosion = {8, 0.4, 6, 0.05, vector.create(1,1,2), vector.one*0.1},
		Earthquake = {4, nil, 3.5, nil, vector.create(1,1,3), vector.one*0.1},
		Custom = { Defaults.Magnitude, Defaults.FadeOutTime, Defaults.Roughness, Defaults.FadeInTime, Defaults.RotInfluence, Defaults.PosInfluence}
	}, {"Preset","FalloffDistance","Magnitude","FadeOutTime","Roughness","FadeInTime","RotInfluence","PosInfluence"}

	local defaultFunc = function(k, csv)
		if k == "Preset" then
			return "Custom"
		elseif not (csv and csv[1]) then
			return
		end
		
		local pos = table.find(Map, k) - 2
		return pos > 0 and (Presets[csv[1]] or {})[pos] or nil
	end
	
	if IsEdit then
		module.CameraShakeInfo = {
			Presets = Presets,
			AttributeMap = Map,
			DefaultFunction = defaultFunc
		}
	end
	
	api.add {
		enable = function(VFX, attrs)
			local attr = attrs.CameraShake
			if not attr or ActiveShakes[VFX] then return end
			local shake = getCSV(attr, Map, Defaults, defaultFunc)

			if not shake then return end
			CameraShake(shake[3], shake[5], shake[6], shake[7], shake[8], VFX, shake[2], shake[9])
		end,
		disable = function(VFX, attrs)
			local shake = ActiveShakes[VFX]
			if not shake then return end
			local attr = attrs.CameraShake

			if not attr then
				shake.finish()
				warn("[ScreenEffects]: no CameraShake attribute for fadeout (", VFX, ")")
			else
				shake.finish(getCSV(attr, Map, Defaults, defaultFunc)[4])
			end
		end,
		emit = function(VFX, attrs)
			local attr = attrs.CameraShake
			if not attr then return end
			local shake = getCSV(attr, Map, Defaults, defaultFunc)

			if not shake then return end
			local FadeIn, FadeOut = shake[6], shake[4]
			local shake = CameraShake(shake[3], shake[5], shake[6], shake[7], shake[8], VFX, shake[2], shake[9])
			task.wait(FadeIn) shake.finish(FadeOut)
		end
	}
end

do -- camera weld
	local defaultScale = vector.create(1,1,30)
	local defaultOffset = CFrame.new(0,0,-10)
	local oneeighty = CFrame.Angles(0,math.pi,0)

	local killconns = {}
	local killconns2 = {}
	local viewportConns = {}
	local function weld(Inst, Offset, dly)
		Offset = Offset or defaultOffset
		local Camera = workspace.CurrentCamera
		local setFunc = Inst:IsA("Attachment") and function(self, v) self.WorldCFrame = v end or Inst.PivotTo

		local update = type(Offset) == "function" and
			function() if dly then task.wait(dly) end setFunc(Inst,Camera.CFrame*Offset()*oneeighty) end
			or function() if dly then task.wait(dly) end setFunc(Inst,Camera.CFrame*Offset*oneeighty) end

		local conn = Camera:GetPropertyChangedSignal("CFrame"):Connect(update)

		local kill = killconns[Inst]
		if kill then kill:Disconnect() killconns[Inst] = nil end
		kill = (IsEdit and Inst.AncestryChanged or Inst.Destroying):Connect(function(_, parent)
			if parent == nil then conn:Disconnect() kill:Disconnect() killconns[Inst] = nil end
		end) killconns[Inst] = kill

		if dly then task.spawn(update) else update() end
		return conn, update
	end

	local function scalePart(Inst, Scale)
		Scale = Scale or defaultScale
		local Camera = workspace.CurrentCamera
		local isFunc = type(Scale) == "function"

		local update = function()
			local scale = isFunc and Scale() or Scale
			local viewport = Camera.ViewportSize

			local distance = scale.Z
			local fov = math.rad(Camera.FieldOfView)
			local height = 2 * distance * math.tan(fov/2)
			Inst.Size = vector.create(scale.X * height * viewport.X / viewport.Y, height * scale.Y, Inst.Size.Z)
		end

		local conn = Camera:GetPropertyChangedSignal("CFrame"):Connect(update)
		local conn2 = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)

		local kill = killconns2[Inst]
		if kill then kill:Disconnect() killconns2[Inst] = nil end
		kill = (IsEdit and Inst.AncestryChanged or Inst.Destroying):Connect(function(_, parent)
			if parent == nil then conn:Disconnect() kill:Disconnect() killconns2[Inst] = nil end
		end) killconns2[Inst] = kill

		update()
		return function()
			conn:Disconnect()
			conn2:Disconnect()
			kill:Disconnect()
			killconns2[Inst] = nil
		end, update
	end

	local welded = {}
	local VPScalers = {}
	local conns,scalers = {},{}
	local maxLifetime = api.maxLifetime

	api.add {
		enable = function(vfx, attrs)
			if welded[vfx] then return end
			local scale = attrs.CameraWeldScale
			local offset = attrs.CameraWeldOffset
			if not (offset or scale) then return end
			
			local noatt = vfx.ClassName ~= "Attachment"
			if noatt and not vfx:IsA("BasePart") then return end
			if noatt then vfx.Locked = true end

			local updOffset do -- welding
				local offset
				local func, upd = function()
					return offset or defaultOffset
				end, nil

				welded[vfx], upd = weld(vfx, func, attrs.CameraWeldDelay)

				function updOffset()
					local raw = vfx:GetAttribute("CameraWeldOffset")

					if scale then
						if raw then
							local pos = raw.Position
							local rot = raw-pos
							offset = rot+vector.create(pos.X,pos.Y,-scale.Z)
						else
							offset = CFrame.new(0,0,-scale.Z)
						end
					else
						offset = raw
					end

					upd()
				end

				updOffset()
				conns[vfx] = vfx:GetAttributeChangedSignal("CameraWeldOffset"):Connect(updOffset)
			end

			if noatt and scale then
				local func, upd = function()
					return scale
				end, nil

				scalers[vfx], upd = scalePart(vfx, func)
				VPScalers[vfx] = vfx:GetAttributeChangedSignal("CameraWeldScale"):Connect(function()
					scale = vfx:GetAttribute("CameraWeldScale") upd() updOffset()
				end)
			end
		end,
		disable = function(vfx)
			local welder = welded[vfx]
			if not welder then return end

			welded[vfx] = nil
			local conn = conns[vfx]
			local vpscaler = VPScalers[vfx]
			local scaleCancel = scalers[vfx]
			local noatt = vfx.ClassName ~= "Attachment"
			local LongestLifetime = maxLifetime(vfx)
			VPScalers[vfx], scalers[vfx], conns[vfx] = nil, nil, nil
			
			if LongestLifetime > 0.02 then
				task.delay(LongestLifetime, function()
					conn:Disconnect()
					welder:Disconnect()
					if scaleCancel then
						scaleCancel()
						vpscaler:Disconnect()
					end if noatt then vfx.Locked = false end
				end)
			else
				conn:Disconnect()
				welder:Disconnect()
				if scaleCancel then
					scaleCancel()
					vpscaler:Disconnect()
				end if noatt then vfx.Locked = false end
			end
		end
	}
end

return module