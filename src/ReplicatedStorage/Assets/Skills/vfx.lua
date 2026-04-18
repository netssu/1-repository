local _ = [=[
v1.0

Preamble.

This is the license of the VFX Module of the plugin.

  - You are allowed to use the module commercially in your games.

  - You can modify and distribute your version as long as the license is retained.

  - If you violate the license you are required to stop use and distribution of
  the module and any Derivative Work and you may be terminated from using the plugin.

End of Preamble.

1. Definitions
  - "We" or "Us" refers to the copyright holder.
  - "You" means any individual exercising the rights of this license.
  - "Module" means the source code that is used to play vfx in-game and any compiled form of it.
  - "Derivative Work" means any work based on, derived from, or incorporating the Module.
  - "Plugin" the plugin that is used to create VFX to emit using this Module. (https://vfxer.pages.dev/plugin)

2. Grant of Rights
  - You may distribute the Module or Derivative Works **only** if you include an unaltered copy of this license.
  - You may use the Module **only** in Roblox game context (including roblox studio playtest) and not through plugins.
  - Derivative Works must **not** be branded or presented as the original and must give credit to the copyright holder.

3. Conditions
  - You must comply with and accept the terms of any add-ons you install or use.
  - Every copy, version, and Derivative Work must include an unaltered copy of this license and must **only**
  run in the context mentioned in Section 2, any other context like plugin or other developer tools are not allowed.

4. Warranty
  The Module is provided **"as is"**, without any warranty, express or implied,
  including merchantability, fitness for a particular purpose, or non-infringement.

5. Liability
  The copyright holder is not responsible for damages, losses, or legal claims,
  but will make reasonable efforts to correct reported problems when possible.

6. Termination
  This license ends automatically if you break any of its rules.
  Upon termination, you must stop all use and distribution of the Module and any Derivative Works.
  The copyright holder may also revoke your access to other tools (Plugin) or services they provide.
  We may also revoke or terminate your license at any time, for any reason.

7. Versioning
  The copyright holder may update the license with notice.
  Continuing to use any version of the Module or any Derivative Works after notice means
  you accept the new version of the license and must update the license in your version/copy.
]=]

--[===[--
	plugin: https://vfxer.pages.dev/plugin
	discord: https://discord.gg/XdZHsU9dNw
	license: https://github.com/fnuuy/vfx-plugin/LICENSE
	
	This module is not open-source and requires explicit permission to-
	use except to play VFX made with the plugin above in games (read license)
	though some add-ons can be open-source if they state that in their module.
	
	you are NOT allowed to edit/remove this comment or take anything from the module.

	read the documentation: https://vfxer.gitbook.io/plugin

	by: @fnuuy (discord)
--]===]--

local API = {}
local Terrain = workspace.Terrain
local RunS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local temp = Terrain:FindFirstChild("TempVFX")

if temp then
	temp:ClearAllChildren()
else
	temp = Instance.new("Folder")
	temp.Name, temp.Parent = "TempVFX", Terrain
end

local util = require(script.util)

local NOP = util.NOP
local emitters, enablers, disablers = {}, {}, {}
local num, tween, max, multiply = util.num, util.tween, util.max, util.multiply

API.temp = temp
temp.AncestryChanged:Connect(function(_, parent)
	if parent == Terrain then return end
	temp.Parent = Terrain
end) temp.Destroying:Once(function()
	warn(`WHY DESTROY TempVFX? restart studio..`)
end)

local VFXClasses = {
	Beam = true,
	Decal = true,
	Trail = true,
	SpotLight = true,
	PointLight = true,
	SurfaceLight = true,
	ParticleEmitter = true
}
local ContainerClasses = {
	Part = true,
	Model = true,
	Folder = true,
	MeshPart = true,
	Attachment = true
}
local OtherClasses = {
	Sound = true,
	Highlight = true,
	ObjectValue = true,
	ModuleScript = true
}

local AllClasses = {}
for k, v in VFXClasses do
	AllClasses[k] = v
end for k, v in ContainerClasses do
	AllClasses[k] = v
end for k, v in OtherClasses do
	AllClasses[k] = v
end

local getCFrame
local enabled = {}
local emit, enable, disable

local emit1 = function(vfx, attrs, repeating, n)
	for _, f in emitters do
		task.spawn(f, vfx, attrs, repeating)
	end

	local class = vfx.ClassName
	local Duration = attrs.EmitDuration
	if ContainerClasses[class] and not attrs.EmitBreak then
		local children = vfx:GetChildren()
		local RandomPicks = attrs.EmitRandom

		if RandomPicks then
			local len = #children
			local max = attrs.MaxPicks
			local picked = max and {}
			for i=1,num(RandomPicks, 1, true) do
				local v = children[math.random(len)]
				while picked and picked[v] >= max do
					v = children[math.random(len)]
				end

				emit(v, nil, repeating)
			end

			if Duration == nil then return end
		end

		for _, v in children do
			if v.Name:sub(1, 6) ~= "EmitOn" then
				emit(v, nil, repeating)
			end
		end

		if Duration == nil then return end
	end

	if class == "ModuleScript" then
		task.spawn(function()
			local f = require(vfx)
			if f and type(f) == "function" then
				task.spawn(f, attrs, repeating)
			elseif repeating then
				warn(`A script that emits more than once ({vfx:GetFullName()}) must return a function`)
			end return
		end)
	end

	local TweenIn, TweenOut = attrs.TweenIn, attrs.TweenOut

	if class == "ParticleEmitter" then
		local count = num(attrs.EmitCount, 0, true)
		if count >= 0.5 then vfx:Emit(count) end
	elseif class == "Sound" and not (Duration or TweenIn or TweenOut) then
		if attrs.Clone then
			local clone = vfx:Clone()
			clone.Parent = vfx.Parent
			vfx = clone

			task.delay(vfx.TimeLength/vfx.PlaybackSpeed, vfx.Destroy, vfx)
		end


		vfx:Play() return
	elseif class == "ObjectValue" then
		local obj = vfx.Value if obj then
			local r = obj:GetAttributes() for k, v in attrs do
				if k:sub(1, 10) == "EmitRepeat" then continue end
				r[k] = v
			end

			r._ObjectValue = vfx
			emit(obj, r, repeating)
		end return
	end

	if Duration or TweenIn or TweenOut then
		Duration = num(Duration, 0)

		if Duration == -1 then
			enable(vfx, attrs, repeating)
			return
		end

		task.spawn(function()
			if attrs.Clone == true then
				attrs.Clone = 1
				local clone = vfx:Clone()
				clone:SetAttribute("Clone", 1)
				clone.Parent = vfx.Parent

				task.wait(Duration + (enable(clone, attrs, repeating, n) or 0))
				disable(clone, attrs, repeating, n)
				clone:Destroy()
			else
				local n = (enabled[vfx] or 0)+1
				local t, cancel1 = enable(vfx, attrs, repeating, n)

				task.wait(Duration + (t or 0))

				if enabled[vfx] ~= n then
					if cancel1 then cancel1() end
					return
				end

				local _, cancel2 = disable(vfx, attrs, repeating, n)
				if cancel2 == false then return end
				enabled[vfx] = nil;
			end
		end)
	end
end

local Repeating = {}
emit = function(vfx, attrs, repeating, n)
	if not vfx:IsDescendantOf(game) then return end

	local nodelay = attrs == 0
	attrs = not nodelay and attrs or vfx:GetAttributes()
	local DELAY = nodelay and 0 or num(attrs.EmitDelay, 0)
	local Repeat = num(attrs.EmitRepeat, 0, true)+1

	if Repeat > 1 then
		local RepeatDelay = attrs.EmitRepeatDelay or 0.1

		task.delay(DELAY, function()
			local s = (Repeating[vfx] or 0)+1
			Repeating[vfx] = s

			for i = 1, Repeat do
				if Repeating[vfx] ~= s or vfx.Parent == nil then return end
				if not vfx:IsDescendantOf(game) then break end

				emit1(vfx, attrs, i < Repeat)
				local dly = num(RepeatDelay, 0.5)
				if dly >= 0.02 then task.wait(num(dly)) end
			end

			Repeating[vfx] = nil
		end) return
	end

	if DELAY < 0.02 then
		emit1(vfx, attrs, repeating, n)
	else
		task.delay(DELAY, emit1, vfx, attrs, repeating, n)
	end
end

local TweenOrigins = {}
local TypeOnes, TypeZeros = {
	number = 1,
	NumberRange = NumberRange.new(1),
	NumberSequence = NumberSequence.new(1),
	ColorSequence = ColorSequence.new(Color3.new(1,1,1)),

	Color3 = Color3.new(1,1,1),
	Vector3 = Vector3.one
}, {
	number = 0,
	NumberRange = NumberRange.new(0),
	NumberSequence = NumberSequence.new(0),
	ColorSequence = ColorSequence.new(Color3.new()),

	Color3 = Color3.new(0,0,0),
	Vector3 = Vector3.zero
}

local tweening = util.tweening
local Enableable = table.clone(VFXClasses)
Enableable.Decal, Enableable.Highlight = nil, true

local enable1 = function(vfx, attrs, repeating, n)
	n = n or (enabled[vfx] or 0)+1
	enabled[vfx] = n

	for _, f in enablers do f(vfx, attrs, repeating, n) end

	local class = vfx.ClassName
	if ContainerClasses[class] and not attrs.EmitBreak then
		for _, v in vfx:GetChildren() do
			local children = vfx:GetChildren()
			local RandomPicks = attrs.EmitRandom

			if RandomPicks then
				local len = #children
				local max = attrs.MaxPicks
				local picked = max and {}
				for i=1,num(RandomPicks, 1, true) do
					local v = children[math.random(len)]
					while picked and picked[v] >= max do
						v = children[math.random(len)]
					end

					enable(v, nil, repeating)
				end

				return
			end

			for _, v in children do
				if v.Name:sub(1, 6) ~= "EmitOn" then
					enable(v, nil, repeating)
				end
			end
		end return
	end

	local IsSound = class == "Sound"

	if Enableable[class] then
		vfx.Enabled = true
	elseif IsSound then
		vfx.TimePosition, vfx.Looped, vfx.Playing = attrs.StartTime or 0, true, true
	end

	local InTime = num(attrs.TweenIn, 0)

	if InTime > 0.02 then
		local ToAttribute = attrs.TweenProperties
		local ToTween = ToAttribute

		if not ToTween then
			ToTween = (class == "Beam" and {"Width0", "Width1"}) or (vfx:IsA("Light") and {"Brightness"}) or (IsSound and {"Volume"}) or {"Transparency"}
			if not ToTween then return end
		else
			ToTween = ToTween:gsub("%s", ""):split(",")
		end

		local Properties = TweenOrigins[vfx] if not Properties then
			Properties = {}; for _, v in ToTween do
				Properties[v] = vfx[v]
			end TweenOrigins[vfx] = Properties
		end

		local Start = attrs.TweenStart

		if Start then
			local starttype = typeof(Start)
			if starttype == "string" then
				Start = Start:split(",")

				for k,v in Start do
					Start[k] = tonumber(v) or v
				end

				for k, p in ToTween do
					local strt = Start[k]
					local v = Properties[p]
					if strt then
						vfx[p] = multiply(strt, TypeOnes[typeof(v)])
					else
						if p == "Transparency" then
							vfx[p] = TypeOnes[typeof(v)]
							continue
						end

						vfx[p] = ToAttribute and TypeZeros[typeof(v)] or 0
					end
				end
			else
				if TypeOnes[starttype] then
					local p = ToTween[1]
					vfx[p] = multiply(Start, TypeOnes[typeof(Properties[p])])
				else
					vfx[ToTween[1]] = Start
				end
			end
		else
			for p, v in Properties do
				local v = Properties[p]
				if p == "Transparency" then
					vfx[p] = TypeOnes[typeof(v)]
					continue
				end

				vfx[p] = ToAttribute and TypeZeros[typeof(v)] or 0
			end
		end

		return InTime, tween(vfx, TweenInfo.new(InTime), Properties)
	end

	return InTime
end

local disable1 = function(vfx, attrs, repeating, n)
	do
		local c = enabled[vfx]
		if not c or (n and n ~= c) then return end
		n = n or c
	end

	for _, f in disablers do f(vfx, attrs, repeating, n) end

	local class = vfx.ClassName
	if ContainerClasses[class] and not attrs.EmitBreak then
		for _, v in vfx:GetChildren() do
			task.spawn(disable, v, nil, repeating)
		end return
	end

	local IsSound = class == "Sound"
	local IsClone = attrs.Clone == 1
	local OutTime = num(attrs.TweenOut, 0)

	if OutTime <= 0.02 then
		TweenOrigins[vfx] = nil
	end

	if OutTime > 0.02 then
		local ToAttribute = attrs.TweenProperties
		local ToTween = ToAttribute

		if not ToTween then
			ToTween = (class == "Beam" and {"Width0", "Width1"}) or (vfx:IsA("Light") and {"Brightness"}) or (IsSound and {"Volume"}) or {"Transparency"}
		else
			ToTween = ToTween:gsub("%s", ""):split(",")
		end

		local Properties = TweenOrigins[vfx]

		if not Properties then
			Properties = {}; for _, v in ToTween do
				Properties[v] = vfx[v]
			end; TweenOrigins[vfx] = Properties
		end

		local End = attrs.TweenEnd
		local Goal = {} if End then
			local endtype = typeof(End)
			if endtype == "string" then
				End = End:split(",")

				for k,v in End do
					End[k] = tonumber(v) or v
				end

				for k, p in ToTween do
					local nd = End[k]
					local v = Properties[p]
					if nd then
						Goal[p] = multiply(nd, TypeOnes[typeof(Properties[p])])
					else
						if p == "Transparency" then
							Goal[p] = TypeOnes[typeof(v)]
							continue
						end

						Goal[p] = ToAttribute and TypeZeros[typeof(v)] or 0
					end
				end
			else
				local t = TypeOnes[endtype]

				if t then
					for k, v in ToTween do
						Goal[v] = multiply(End, TypeOnes[typeof(Properties[v])])
					end
				else
					Goal[ToTween[1]] = End
				end
			end
		else
			for p, v in Properties do
				local v = Properties[p]
				if p == "Transparency" then
					Goal[p] = TypeOnes[typeof(v)]
					continue
				end

				Goal[p] = ToAttribute and TypeZeros[typeof(v)] or 0
			end
		end

		local cancel = tween(vfx, TweenInfo.new(OutTime), Goal)
		if repeating == true then return OutTime, cancel end
		task.wait(OutTime + 0.02)
		if enabled[vfx] ~= n then return OutTime, false end

		if Enableable[class] then
			vfx.Enabled = false
		elseif IsSound then
			vfx.Playing = false
		end

		if attrs.ResetOnFinish and not IsClone then
			local IsParticle = class == "ParticleEmitter"

			if IsParticle or class == "Trail" then
				task.wait(IsParticle and vfx.Lifetime.Max or vfx.Lifetime)
				if enabled[vfx] ~= n then return OutTime, false end
			end

			for k, v in Properties do
				vfx[k] = v
			end

			TweenOrigins[vfx] = nil
		end
	elseif Enableable[class] then
		vfx.Enabled = false
	elseif IsSound then
		vfx.Playing = false
	end

	enabled[vfx] = nil
	return OutTime
end

local looping = {}
enable = function(vfx, attrs, repeating, n)
	if not vfx:IsDescendantOf(game) then return end

	attrs = attrs or vfx:GetAttributes()
	if attrs.EmitRepeat == -1 and attrs.Clone ~= 1 then
		if looping[vfx] then return end
		if not attrs.Clone and (attrs.EmitDuration or attrs.TweenIn or attrs.TweenOut) then
			warn(`Can't loop {vfx} because it gets Enabled on Emit (put in something and loop that or use Clone attribute)`)
			return
		end

		task.spawn(function()
			local i = 0
			looping[vfx] = true
			attrs = nil --<| remove attributes cache to get new

			repeat
				i += 1
				if vfx.Parent == nil then return end
				if looping[vfx] == nil or not vfx:IsDescendantOf(game) or vfx:GetAttribute("EmitRepeat") ~= -1 then
					break
				end

				local dly = num(vfx:GetAttribute("EmitRepeatDelay"), 0.1)
				task.spawn(emit1, vfx, attrs or vfx:GetAttributes(), dly) task.wait(dly)
			until nil

			looping[vfx] = nil
		end) return
	elseif vfx.ClassName == "ObjectValue" then
		local obj = vfx.Value if obj then
			local r = obj:GetAttributes() for k, v in attrs do
				if k:sub(1,10) == "EmitRepeat" then continue end
				r[k] = v
			end

			enable(obj, r, repeating)
		end return
	end

	return enable1(vfx, attrs, repeating, n)
end

disable = function(vfx, attrs, repeating, n)
	attrs = attrs or vfx:GetAttributes()

	if looping[vfx] then
		looping[vfx] = nil
		return
	elseif vfx.ClassName == "ObjectValue" then
		local obj = vfx.Value if obj then
			local r = obj:GetAttributes() for k, v in attrs do
				if k:sub(1,10) == "EmitRepeat" then continue end
				r[k] = v
			end

			disable(obj, r, repeating)
		end return
	end

	local toEmit = vfx:FindFirstChild("EmitOnDisable")
	if toEmit then emit(toEmit) end

	return disable1(vfx, attrs, repeating, n)
end

local getDefault = function(d, f, k,...)
	local v = f and f(k,...)
	return (if v == nil then d[k] else v)
end

local conv = util.convert
-- CSV is Comma Seperated Values attributes (like impact frames)
local function get1CSV(t, s, map, d, f, enums, ...)
	if not t then return end t = t:split(",")

	local v = t[table.find(map, s)]
	local dflt = getDefault(d, f, s, t, ...)
	return (if v == "" or v == nil then dflt else conv(v,true,typeof(dflt),enums and enums[s]))
end

local function getCSV(t, map, d, f, enums, ...)
	if not t then return end t = t:split(",")

	for k, s in map do
		local v = t[k]
		local dflt = getDefault(d, f, s, t, ...)
		t[k] = if v == "" or v == nil then dflt else conv(v,true,typeof(dflt),enums and enums[s])
	end

	return t
end

local EffectSelector = ".VFX"

for k in VFXClasses do
	EffectSelector ..= ","..k
end for k in OtherClasses do
	EffectSelector ..= ","..k
end

local getEffects = function(a, t)
	t = t or {}
	if type(a) == "table" then
		for _, v in a do
			local class = v.ClassName
			if VFXClasses[class] or OtherClasses[class] or v:HasTag("VFX") then
				table.insert(t, v)
			end

			for _, x in v:QueryDescendants(EffectSelector) do
				table.insert(t, x)
			end
		end

		return t
	end

	do
		local class = a.ClassName
		if VFXClasses[class] or OtherClasses[class] or a:HasTag("VFX") then
			table.insert(t, a)
		end
	end

	for _, v in a:QueryDescendants(EffectSelector) do
		table.insert(t, v)
	end

	return t
end

getCFrame = function(obj, class)
	class = class or obj.ClassName
	if not AllClasses[class] then return end

	if class == "Beam" then
		local att = obj.Attachment0 or obj.Attachment1
		return att and att.WorldCFrame
	elseif class == "Folder" or not ContainerClasses[class] then
		local p = obj:FindFirstAncestorOfClass("Attachment")
		local att = p ~= nil
		p = p or obj:FindFirstAncestorWhichIsA("PVInstance")

		if not p then return end
		if p:IsA("Model") then return p:GetPivot() end
		return p[att and "WorldCFrame" or "CFrame"]
	end

	return obj[class == "Attachment" and "WorldCFrame" or "CFrame"]
end

local RGBtoHSV = util.RGBtoHSV
local function adjustColor(Color, H,S,L, y)
	if typeof(Color) == "ColorSequence" then
		local KPs = Color.Keypoints

		for K, KP in KPs do
			KPs[K] = ColorSequenceKeypoint.new(KP.Time, adjustColor(KP.Value, H,S,L, y))
		end return ColorSequence.new(KPs)
	end

	H,S,L = H or 0, S or 0, L or 0

	L /= 100 S /= 100
	local hsvH, hsvS, hsvV
	local hdr = 1; if y then
		hdr = math.max(1, Color.R, Color.G, Color.B)
		hsvH, hsvS, hsvV = RGBtoHSV(Color.R / hdr, Color.G / hdr, Color.B / hdr)
	else
		hsvH, hsvS, hsvV = Color:ToHSV()
	end

	y = y and NOP or math.clamp
	local l = (2 - hsvS) * hsvV / 2
	local newS = (l == 0 or l == 1) and 0 or (hsvV - l) / math.min(l, 1 - l)

	local hslS, hslL = y(newS + S, 0, 1), y(l + L, 0, 1)
	local newV = hslL + hslS * math.min(hslL, 1 - hslL)

	local c = Color3.fromHSV(
		(hsvH + (H / 360)) % 1,
		(newV == 0) and 0 or 2 * (1 - hslL / newV),
		newV
	)

	if hdr > 1 then
		c = Color3.new(c.R * hdr, c.G * hdr, c.B * hdr)
	end

	return c
end

local _destroy = function(a)
	a:Destroy()
end

local maxLifetime = function(a, noAttributes)
	local LongestLifetime = 0
	for _, v in a:GetDescendants() do
		local class = v.ClassName
		local IsPE = class == "ParticleEmitter"

		if IsPE or class == "Trail" then
			local lt = v.Lifetime
			lt = IsPE and lt.Max or lt

			if not noAttributes then
				lt += max(v:GetAttribute("EmitDelay"), 0)
				local dur = max(v:GetAttribute("EmitDuration"), 0)
				if dur == -1 then return nil end
				lt += dur
			end

			LongestLifetime = lt > LongestLifetime and lt or LongestLifetime
		end
	end

	return LongestLifetime
end

local cbdestroy = function(a, cb)
	if cb(a) == true then return true end
	a:Destroy()
end

API.destroyAfter = function(a, dly, cb)
	dly = dly or maxLifetime(a)

	if dly >= 0.02 then
		task.delay(dly, cb and cbdestroy or _destroy, a, cb)
	else
		if cb and cb(a) == true then return true end
		a:Destroy()
	end
end

-- // Shifters \\ --
local PropertyClasses = {
	Width0 = "Beam",
	Width1 = "Beam",
	TextureSpeed = "Beam",

	Volume = "Sound",
	PlaybackSpeed = "Sound",
	EmitCount = "ParticleEmitter",

	Size = "ParticleEmitter",
	Speed = "ParticleEmitter",
	RotSpeed = "ParticleEmitter",
	Acceleration = "ParticleEmitter",

	Drag = "ParticleEmitter",
	Rate = "ParticleEmitter",

	Lifetime = "ParticleEmitter",
	FlipbookFramerate = "ParticleEmitter"
}

local AttrNames = {
	TweenIn = true,
	TweenOut = true,
	EmitCount = true,
	EmitDelay = true,
	EmitRepeat = true,
	EmitDuration = true,
	EmitRepeatDelay = true
}

local function GetSet(a, b, c)
	if AttrNames[b] then
		if c ~= nil then
			a:SetAttribute(b, c)
		else
			return a:GetAttribute(b)
		end
	end

	if c ~= nil then
		pcall(function(t, k, v) t[k] = v end, a, b, c)
	else
		return a[b]
	end
end

local function ReDo(vfx, scale, origins, t, ers)
	if ers then
		for selector, funcs in ers do
			if origins then
				local o = origins[vfx]
				for _, f in funcs do o = f(vfx, scale, o) or o end
				origins[vfx] = o
			else
				for _, f in funcs do f(vfx, scale, false) end
			end

			for _, v in vfx:QueryDescendants(selector) do
				if origins then
					local o = origins[v]
					for _, f in funcs do o = f(v, scale, o) or o end
					origins[v] = o
				else
					for _, f in funcs do f(v, scale, false) end
				end
			end
		end
	end

	local effects = vfx:GetDescendants()
	table.insert(effects, vfx)

	for _, V in effects do
		local class = V.ClassName
		if AllClasses[class] == nil then continue end
		local Origins = origins and origins[V]

		for Property, var in t do
			local PC = PropertyClasses[Property]
			if PC and PC ~= class then continue end

			local Origin if Origins then
				Origin = Origins[Property] if not Origin then
					Origin = GetSet(V, Property)
					Origins[Property] = Origin
				end
			else
				Origin = GetSet(V, Property)
				if origins then origins[V] = {[Property] = Origin} end
			end

			if Origin == nil then continue end

			local t = typeof(Origin)
			local x = var and scale or 1/scale
			x = Property == "Acceleration" and x^2 or x

			if t == "NumberSequence" then
				local KPs = Origin.Keypoints

				for K, KP in KPs do
					KPs[K] = NumberSequenceKeypoint.new(KP.Time, KP.Value*x, KP.Envelope)
				end GetSet(V, Property, NumberSequence.new(KPs))
			elseif t == "NumberRange" then
				GetSet(V, Property, NumberRange.new(Origin.Min*x, Origin.Max*x))
			else
				GetSet(V, Property, Origin*x)
			end
		end
	end
end

local Retimes, Rescales = {
	TweenIn = false,
	TweenOut = false,
	EmitDelay = false,
	EmitDuration = false,
	EmitRepeatDelay = false,

	Drag = true,
	Rate = true,
	Speed = true,
	RotSpeed = true,
	Lifetime = false,
	Acceleration = true,
	FlipbookFramerate = true,

	TextureSpeed = true,
	PlaybackSpeed = true,
}, {
	Size = true,
	Speed = true,
	Volume = true,
	Width0 = true,
	Width1 = true,
	Acceleration = true,
}

local retimers = {}
API.retime = function(vfx, scale, origins)
	ReDo(vfx, scale, origins, Retimes, retimers)
end

local rescalers = {}
API.rescale = function(vfx, scale, origins)
	ReDo(vfx, scale, origins, Rescales, rescalers)
end

local recolorers = {}
local function gset(t,k,v) if v == nil then return t[k] end t[k] = v end

local function recolor1(v, p, h,s,l, Origins, origins, hdr)
	local ok
	local Origin if Origins then
		Origin = Origins[p] if not Origin then
			ok, Origin = pcall(gset, v, p)
			if not ok then return end
			Origins[p] = Origin
		end
	else
		ok, Origin = pcall(gset, v, p)
		if not ok then return end

		if origins then
			origins[v] = {[p] = Origin}
		end
	end

	v[p] = adjustColor(Origin, h,s,l, hdr)
end

API.recolor = function(vfx, h, s, l, origins)
	for selector, funcs in recolorers do
		if origins then
			local o = origins[vfx]
			for _, f in funcs do o = f(vfx, h,s,l, o) or o end
			origins[vfx] = o
		else
			for _, f in funcs do f(vfx, h,s,l, false) end
		end

		for _, v in vfx:QueryDescendants(selector) do
			if origins then
				local o = origins[v]
				for _, f in funcs do o = f(v, h,s,l, o) or o end
				origins[v] = o
			else
				for _, f in funcs do f(v, h,s,l, false) end
			end
		end
	end

	for _, v in getEffects(vfx) do
		local class = v.ClassName
		local hdr = class == "Decal"
		local Origins = origins and origins[v] -- instance origins
		
		local ColorAttr = Origins._Color or v:GetAttribute("Color")
		if ColorAttr then v:SetAttribute("Color", adjustColor(ColorAttr, h,s,l)) end

		if class == "Decal" then
			recolor1(v, "Color3", h,s,l, Origins, origins, true)
		elseif class == "Highlight" then
			recolor1(v, "FillColor", h,s,l, Origins, origins)
			recolor1(v, "OutlineColor", h,s,l, Origins, origins)
		else
			recolor1(v, "Color", h,s,l, Origins, origins)
		end
	end
end

local adders = {
	emit = emitters,
	enable = enablers,
	disable = disablers,
	recolor = recolorers,
	retime = retimers,
	rescale = rescalers
}

local noSelector = {
	emit = true,
	enable = true,
	disable = true
}

API.add = function(t, selector)
	selector = selector or t.selector or "Instance"

	for k, f in t do
		local adder = adders[k]
		if not adder then continue end

		if noSelector[k] then
			table.insert(adder, f)
			continue
		end

		local g = adder[selector]
		if g == nil then g = {} adder[selector] = g end
		table.insert(g, f)
	end
end

API.classes, API.getset = {
	all = AllClasses,
	vfx = VFXClasses,
	other = OtherClasses,
	container = ContainerClasses
}, GetSet

API.util, API.num = util, num
API.enabled, API.looping = enabled, looping

API.getCFrame = getCFrame
API.adjustColor = adjustColor
API.maxLifetime = maxLifetime
API.csv, API.csv1 = getCSV, get1CSV
API.tween, API.getEffects = tween, getEffects
API.emit, API.enable, API.disable = emit, enable, disable

local onReady = {}
shared.fx, API.onReady = API, onReady
if shared.vfx == nil then shared.vfx = API end

-- // Add-ons \\ --
local addons = script.addons:GetChildren()
local loadedAddons, addonsCount = 0, #addons

for _, v in addons do
	task.defer(function(m)
		API[m.Name] = require(m)
		
		loadedAddons += 1
		if loadedAddons >= addonsCount then
			API.onReady = nil
			for _, f in onReady do f() end
		end
	end, v)
end

-- // EnabledVFX \\ --
onReady._enable = function()
	for _, v in game:GetService("CollectionService"):GetTagged("EnabledVFX") do
		enable(v)
	end
end

return API