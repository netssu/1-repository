local module = {}
local TS = game:GetService("TweenService")
local RunS = game:GetService("RunService")
local IsClient = RunS:IsClient()

local multiply = function(input, factor, a)
	local type1 = typeof(input)
	local type2 = typeof(factor)
	if not a and type1 == type2 then return input end
	factor = type2 == "NumberRange" and math.lerp(factor.Min, factor.Max, math.random()) or factor

	if type1 == "number" then
		return input
	elseif type1 == "NumberSequence" then
		local kps = {}
		for i, kp in input.Keypoints do
			kps[i] = NumberSequenceKeypoint.new(kp.Time, kp.Value*factor, kp.Envelope*factor)
		end

		return NumberSequence.new(kps)
	elseif type1 == "NumberRange" then
		return NumberRange.new(input.Min*factor, input.Max*factor)
	end
end

local lerp do
	local mergeTimes = function(aKps, bKps)
		local times, i, j, last = {}, 1, 1, -1
		local na, nb = #aKps, #bKps
		while i <= na or j <= nb do
			local ta = (i <= na) and aKps[i].Time or 2
			local tb = (j <= nb) and bKps[j].Time or 2
			local t
			if ta <= tb then
				t, i = ta, i + 1
			else
				t, j = tb, j + 1
			end
			if t - last > 1e-6 then
				times[#times+1], last = t, t
			end
		end
		if times[1] ~= 0 then table.insert(times, 1, 0) end
		if times[#times] ~= 1 then times[#times+1] = 1 end
		return times
	end

	local function sampleColor(kps, t)
		if t <= kps[1].Time then
			return kps[1].Value
		end

		for i = 1, #kps - 1 do
			local a, b = kps[i], kps[i + 1]
			if t <= b.Time then
				local alpha = (t - a.Time) / (b.Time - a.Time)
				return a.Value:Lerp(b.Value, alpha)
			end
		end

		return kps[#kps].Value
	end

	local function sampleNumber(kps, t)
		if t <= kps[1].Time then
			return kps[1].Value, kps[1].Envelope
		end

		for i = 1, #kps - 1 do
			local a, b = kps[i], kps[i + 1]
			if t <= b.Time then
				local u = (t - a.Time) / (b.Time - a.Time)
				return
					a.Value + (b.Value - a.Value) * u,
				a.Envelope + (b.Envelope - a.Envelope) * u
			end
		end

		return kps[#kps].Value, kps[#kps].Envelope
	end

	module.sampleNumber, module.sampleColor = sampleNumber, sampleColor

	lerp = function(a, b, alpha, typ)
		typ = typ or typeof(a)
		if typ == "NumberRange" then
			return NumberRange.new(
				math.lerp(a.Min, b.Min, alpha),
				math.lerp(a.Max, b.Max, alpha)
			)
		elseif typ == "NumberSequence" then
			a, b = a.Keypoints, b.Keypoints
			local times = mergeTimes(a, b)
			for i, t in times do
				local va, ea = sampleNumber(a, t)
				local vb, eb = sampleNumber(b, t)
				times[i] = NumberSequenceKeypoint.new(t, math.lerp(va, vb, alpha), math.lerp(ea, eb, alpha))
			end
			return NumberSequence.new(times)
		elseif typ == "ColorSequence" then
			a, b = a.Keypoints, b.Keypoints
			local times = mergeTimes(a, b)
			for i, t in times do
				times[i] = ColorSequenceKeypoint.new(t, sampleColor(a, t):Lerp(sampleColor(b, t), alpha))
			end
			return ColorSequence.new(times)
		elseif typ == "Color3" then
			return a:Lerp(b, alpha)
		elseif typ == "number" then
			return math.lerp(a, b, alpha)
		end

		error("Unsupported type: " .. tostring(typ))
	end
end

local Tweening = {}
module.tween = function(Object, Info, Goals, Attributes, yield)
	if Tweening[Object] then Tweening[Object]() end

	local ServiceSupported = {}
	local Starts, RealGoals = {}, {}

	for Prop, Goal in Goals do
		local Start = if Attributes and Attributes[Prop] then Object:GetAttribute(Prop) else Object[Prop]
		Starts[Prop] = Start

		local startype = typeof(Start)
		if not (Attributes and Attributes[Prop]) and not startype:find("Sequence", 5, true) then
			ServiceSupported[Prop] = Goal continue
		end

		if typeof(Goal) == "number" and startype ~= "number" then
			RealGoals[Prop] = multiply(Start, Goal, true)
		else
			RealGoals[Prop] = Goal
		end
	end

	local Cancel
	local Conn, Tween, TConn if next(ServiceSupported) then
		Tween = TS:Create(Object,Info,ServiceSupported)
		Tween:Play(); TConn = Tween.Completed:Once(function(...)
			if Tweening[Object] ~= Cancel then return end

			Tweening[Object] = nil if yield then
				coroutine.resume(yield, ...)
			end
		end)
	end

	local Time, Style, Dir = Info.Time,Info.EasingStyle,Info.EasingDirection

	if next(RealGoals) then
		local Alpha = 0
		Conn = RunS.Heartbeat:Connect(function(delta)
			if Tweening[Object] ~= Cancel then return end

			Alpha += delta / Time
			for Prop, Goal in RealGoals do
				if Attributes and Attributes[Prop] then
					Object:SetAttribute(lerp(Starts[Prop], Goal, TS:GetValue(Alpha, Style, Dir)))
				else
					Object[Prop] = lerp(Starts[Prop], Goal, TS:GetValue(Alpha, Style, Dir))
				end
			end

			if Alpha >= 1 then
				Tweening[Object] = nil
				Conn:Disconnect() if yield then
					coroutine.resume(yield)
				end
			end
		end)
	end

	Cancel = function()
		if Conn then Conn:Disconnect() end
		if yield then coroutine.resume(yield) end
		if Tween then TConn:Disconnect() Tween:Cancel() end

		if Tweening[Object] == Cancel then
			Tweening[Object] = nil
		end
	end

	Tweening[Object] = Cancel

	if yield then
		yield = coroutine.running()
		return coroutine.yield()
	end

	return Cancel
end

module.lerp = lerp
module.tweening = Tweening
module.multiply = multiply
module.num = function(n, d, int)
	if n == nil or type(n) == "number" then
		return n or d
	end

	return int and math.random(n.Min, n.Max) or math.lerp(n.Min, n.Max, math.random())
end

module.max = function(n, d)
	if n == nil or type(n) == "number" then
		return n or d
	end

	return n.Max
end

local round = math.round
module.convert = function(a, decode, typ, enum)
	typ = typ == "table" and "string" or typ

	if decode then
		if type(a) ~= "string" then return a end

		if enum then
			return enum[a]
		elseif typ == "number" then
			return tonumber(a) or a
		elseif typ == "Color3" then
			return Color3.fromRGB(unpack(a:split(":")))
		elseif typ == "Vector3" then
			return vector.create(unpack(a:split(";")))
		elseif typ == "boolean" then
			return (if a == "t" then true else (a ~= "f" and a))
		elseif typ == "Vector2" then
			return Vector2.new(unpack(a:split(";")))
		elseif typ == "NumberRange" then
			a = a:split("~")
			local m, mx = a[1], a[2]
			return NumberRange.new(tonumber(m), tonumber(mx))
		elseif typ == "EnumItem" then
			a = a:split(".")
			return Enum[a[1]][a[2]]
		end

		return a
	else
		if enum then
			return a.Name
		elseif typ == "boolean" then
			return a == true and "t" or "f"
		elseif typ == "number" then
			return string.gsub(tostring(round(a*100)/100), "^(0%.)", "."), nil
		elseif typ == "Color3" then
			return `{a.R*255//1}:{a.G*255//1}:{a.B*255//1}`
		elseif typ == "Vector3" then
			return string.gsub(`;{round(a.X*100)/100};{round(a.Y*100)/100};{round(a.Z*100)/100}`,";(0%.)", ";."):sub(2)
		elseif typ == "Vector2" then
			return string.gsub(`;{round(a.X*100)/100};{round(a.Y*100)/100}`,";(0%.)", ";."):sub(2)
		elseif typ == "NumberRange" then
			return string.gsub(`~{a.Min}~{a.Max}`,";(0%.)", ";."):sub(2)
		elseif typ == "EnumItem" then
			return a:gsub("^Enum%.", "")
		end

		return a
	end
end

local function NOP(...)return...end
module.RGBtoHSV = function(r, g, b) -- since :ToHSV() clamps to 255
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local delta = max - min

	local h
	if delta == 0 then
		h = 0
	elseif max == r then
		h = ((g - b) / delta) % 6
	elseif max == g then
		h = ((b - r) / delta) + 2
	else
		h = ((r - g) / delta) + 4
	end

	return h / 6, (max == 0) and 0 or (delta / max), max
end

local pool = {} do
	pool.__index = pool
	local Terrain = workspace.Terrain
	local nowhere, z = Vector3.one * 0xFFFFFFFFFFFFF, nil
	local temp = Terrain:FindFirstChild("TempVFX") or Terrain:FindFirstChildOfClass("Folder") or Terrain

	local t = {
		adornment = function(v, take, self)
			if v then v.Visible = take return end

			local arg = self[1]
			if typeof(arg) == "Instance" then
				v = arg:Clone()
			else
				v = Instance.new(arg or "LineHandleAdornment", temp)
			end

			v.Adornee, v.Color3 = Terrain, Color3.new(0.9, 0.9, 0.9)
			v.Visible, v.Parent = false, temp; (self[2] or NOP)(v)
			return v
		end,
		void = function(v, take, self)
			if v then if not take then
					v.Position = nowhere
					if v:IsA("BasePart") then
						v.Anchored = true
					end
				end return
			end

			local arg = self[1]
			if typeof(arg) == "Instance" then
				v = arg:Clone()
			else
				v = Instance.new(arg or "Part", temp)
			end

			v.Position, v.Parent = nowhere, temp
			;(self[2] or NOP)(v) return v
		end,
	} pool.t = t

	function pool.new(func, expansion, arg1, arg2)
		func = type(func) == "string" and t[func] or func
		return setmetatable({
			arg1, arg2,
			free = {},
			busy = {},
			func = func,
			expansion = expansion
		}, pool)
	end

	function pool:expand(n)
		local f, free = self.func, self.free
		for i = 1, n or self.expansion or 1 do
			local v = f(z, z, self)
			if typeof(v) == "Instance" then
				v.Destroying:Once(function()
					self.free[v], self.busy[v] = nil
				end)
			end

			free[v] = true
		end
		return self
	end

	function pool:give(x)
		x = self.func(x, false, self) or x
		self.busy[x], self.free[x] = nil, true
	end

	function pool:take()
		local f = self.func
		local free = self.free
		local x = next(free) if x == nil then
			self:expand() x = next(free)
		end free[x] = nil

		x = f and f(x, true, self) or x
		self.busy[x] = true
		return x
	end

	function pool:clear()
		local free, busy = self.free, self.busy
		for v in free do v:Destroy() end
		for v in busy do v:Destroy() end
		table.clear(free) table.clear(busy)
	end
end module.pool, module.NOP = pool, NOP

return module