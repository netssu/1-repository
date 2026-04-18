local api = shared.fx
local RunS = game:GetService("RunService")
local IsClient, IsEdit = RunS:IsClient(), api.ui ~= nil

local LightningParts = require(script:WaitForChild("Lightning"))
local LightningAdorn = require(script:WaitForChild("LightningImageHandleAdornment"))
local LightningSparks = require(script:WaitForChild("LightningSparks"))

local LightningPartsSparks = LightningSparks
local LightningAdornSparks = LightningSparks

local rng = Random.new()
local function islightningbeamvfx(v, class)
	class = class or v.ClassName
	if class == "Attachment" then
		for _, child in ipairs(v:GetChildren()) do
			if child:IsA("Attachment") and child.Name:match("^[B-Z]$") then
				return true
			end
		end
	end
	return false
end

local num, temp = api.num, api.temp
local emit = api.emit

local function getProp(val, default)
	if typeof(val) == "NumberRange" then return val end
	return tonumber(val) or default
end

api.add {
	selector = "Attachment",
	retime = function(vfx, scale, origins, class)
		return origins
	end,
	recolor = function(vfx, h,s,l,c, origins, class)
		if not islightningbeamvfx(vfx, class) then return end

		local o = origins and origins.Color or vfx:GetAttribute("Color") or Color3.new(1,1,1)
		origins = origins or {}
		origins.Color = o

		vfx:SetAttribute("Color", api.adjustColor(o, h,s,l,c, true))
		return origins
	end,
	emit = function(vfx, attrs)
		if not islightningbeamvfx(vfx) then return end

		local A1 = vfx
		local endpoints = {}

		for _, child in ipairs(A1:GetChildren()) do
			if child:IsA("Attachment") and child.Name:match("^[B-Z]$") then
				table.insert(endpoints, child)
			end
		end

		if #endpoints == 0 then
			local target = A1:FindFirstChildOfClass("Attachment")
			if target then table.insert(endpoints, target) end
		end

		if #endpoints == 0 then return end

		local rawStyle = attrs.Style
		local Style = (type(rawStyle) == "string" and (rawStyle == "Parts" or rawStyle == "ImageHandleAdornment")) and rawStyle or "Parts"

		local rawAttrs = attrs
		attrs = {
			EmitCount = num(rawAttrs.EmitCount, 1),
			PartCount = getProp(rawAttrs.PartCount, 20),
			Style = Style,
			CurveSize0 = getProp(rawAttrs.CurveSize0, 0),
			CurveSize1 = getProp(rawAttrs.CurveSize1, 0),
			Thickness = num(rawAttrs.Thickness, 1),
			Frequency = getProp(rawAttrs.Frequency, 1),
			Speed = getProp(rawAttrs.Speed, 7),
			PulseSpeed = getProp(rawAttrs.PulseSpeed, 2),
			PulseLength = getProp(rawAttrs.PulseLength, 1),
			FadeLength = getProp(rawAttrs.FadeLength, 0.2),
			ContractFrom = getProp(rawAttrs.ContractFrom, 0.5),
			Color = rawAttrs.Color,
			Lifetime = rawAttrs.Duration, 
			DissipateTime = getProp(rawAttrs.DissipateTime, 0),
			DissipateStrength = getProp(rawAttrs.DissipateStrength, 0.5),
			MaxSparkCount = getProp(rawAttrs.MaxSparkCount, 5),
			SparkRate = getProp(rawAttrs.SparkRate, 1),
			SparkShape = rawAttrs.SparkShape or Enum.PartType.Cylinder,
			SparkSpeed = rawAttrs.SparkSpeed or NumberRange.new(4, 6),
			SparkDistance = rawAttrs.SparkDistance or NumberRange.new(3, 6),
			SparkParts = rawAttrs.SparkParts or NumberRange.new(8, 10),
			Shape = rawAttrs.Shape or Enum.PartType.Cylinder,
			SpreadAngle = rawAttrs.Spread or Vector2.zero,
			ThicknessMultiplier = rawAttrs.ThicknessMultiplier or NumberRange.new(0.2, 1),
			Radius = rawAttrs.Radius or NumberRange.new(0, 2.4),
			Transparency = rawAttrs.Transparency or NumberRange.new(0, 1)
		}

		local duration = num(attrs.Lifetime, 1)

		local results = {
			bolts = {},
			sparks = {},
			parts = {},
			adornments = {}
		}

		for _, A2 in ipairs(endpoints) do
			for i = 1, attrs.EmitCount do
				local targetA1 = A1
				local targetA2 = A2

				if attrs.SpreadAngle ~= Vector2.zero then
					local dir = A2.WorldPosition - A1.WorldPosition
					local spreadDir = api.spread(dir, attrs.SpreadAngle)
					local targetPos = A1.WorldPosition + spreadDir

					targetA2 = {
						WorldPosition = targetPos,
						WorldAxis = A2.WorldAxis
					}
				end

				local highlight = (typeof(A1) == "Instance") and A1:FindFirstChildOfClass("Highlight")
				local container
				if highlight and attrs.Style == "Parts" then
					container = Instance.new("Model")
					container.Name = "LightningBolt_" .. vfx.Name
					api.debris(container)
					local hClone = highlight:Clone()
					hClone.Adornee = container
					hClone.Parent = container
				end

				local partCount = num(attrs.PartCount)
				local speed = num(attrs.Speed)
				local pulseSpeed = num(attrs.PulseSpeed)
				local pulseLength = num(attrs.PulseLength)
				local fadeLength = num(attrs.FadeLength)
				local contractFrom = num(attrs.ContractFrom)
				local curveSize0 = num(attrs.CurveSize0)
				local curveSize1 = num(attrs.CurveSize1)
				local frequency = num(attrs.Frequency)

				local maxSparkCount = num(attrs.MaxSparkCount)
				local sparkRate = num(attrs.SparkRate)

				local dissipateTime = num(attrs.DissipateTime)
				local dissipateStrength = num(attrs.DissipateStrength)

				local bolt, LSparks
				if attrs.Style == "ImageHandleAdornment" then
					bolt = LightningAdorn.new(targetA1, targetA2, partCount)
					LSparks = LightningAdornSparks
					bolt.AnimationSpeed = speed
				else
					bolt = LightningParts.new(targetA1, targetA2, partCount, container, highlight ~= nil)
					LSparks = LightningPartsSparks
					bolt.Speed = speed
					bolt.Shape = attrs.Shape

					if container then
						local oldDestroy = bolt.Destroy
						bolt.Destroy = function(self)
							oldDestroy(self)
							if container then container:Destroy() end
						end
					end
				end

				bolt.CurveSize0 = curveSize0
				bolt.CurveSize1 = curveSize1
				bolt.Thickness = attrs.Thickness

				local tm = attrs.ThicknessMultiplier
				bolt.MinThicknessMultiplier = math.min(tm.Min, tm.Max)
				bolt.MaxThicknessMultiplier = math.max(tm.Min, tm.Max)

				local r = attrs.Radius
				bolt.MinRadius = math.min(r.Min, r.Max)
				bolt.MaxRadius = math.max(r.Min, r.Max)

				bolt.Frequency = frequency
				bolt.PulseSpeed = pulseSpeed

				if partCount < 10 then pulseLength = math.min(pulseLength, 1) end
				bolt.PulseLength = pulseLength

				bolt.FadeLength = fadeLength

				local minContract = (1 / (partCount * fadeLength)) + 0.01
				bolt.ContractFrom = math.max(contractFrom, minContract)

				local t = attrs.Transparency
				local minTr, maxTr = math.min(t.Min, t.Max), math.max(t.Min, t.Max)
				local minSpread = (2 / (partCount * fadeLength)) + 0.01
				if (maxTr - minTr) < minSpread then
					if minTr + minSpread <= 1 then maxTr = minTr + minSpread
					elseif 1 - minSpread >= 0 then minTr, maxTr = 1 - minSpread, 1
					else minTr, maxTr = 0, 1 end
				end
				bolt.MinTransparency, bolt.MaxTransparency = minTr, maxTr

				if attrs.Color then bolt.Color = attrs.Color end

				if maxSparkCount > 0 then
					local function configureSparks(sparks)
						sparks.SparkShape = attrs.SparkShape
						sparks.MinSpeed, sparks.MaxSpeed = attrs.SparkSpeed.Min, attrs.SparkSpeed.Max
						sparks.MinDistance, sparks.MaxDistance = attrs.SparkDistance.Min, attrs.SparkDistance.Max
						sparks.MinPartsPerSpark, sparks.MaxPartsPerSpark = attrs.SparkParts.Min, attrs.SparkParts.Max
						table.insert(results.sparks, sparks)
					end

					local function getFirstPart()
						local bp = bolt._Parts or bolt.Parts
						return bp and bp[1]
					end

					if sparkRate == 1 then
						configureSparks(LSparks.new(bolt, maxSparkCount))
					else
						task.spawn(function()
							while bolt and getFirstPart() and getFirstPart().Parent do
								configureSparks(LSparks.new(bolt, maxSparkCount))
								task.wait(sparkRate)
							end
						end)
					end
				end

				table.insert(results.bolts, bolt)
				local boltParts = bolt._Parts or bolt.Parts
				if boltParts then
					local targetList = attrs.Style == "ImageHandleAdornment" and results.adornments or results.parts
					for _, p in ipairs(boltParts) do table.insert(targetList, p) end
				end

				task.delay(duration, function()
					if bolt then
						if attrs.Style == "Parts" and dissipateTime > 0 then
							bolt:DestroyDissipate(dissipateTime, dissipateStrength)
						else
							bolt:Destroy()
						end
					end
				end)
			end
		end

		return results
	end
}

return {
	is = islightningbeamvfx
}