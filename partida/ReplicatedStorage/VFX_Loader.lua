local module = {}
local RunService = game:GetService("RunService")
local rs = game:GetService("ReplicatedStorage")
local VFX = rs.VFX
local TS = game:GetService("TweenService")
local GameSpeed = game.Workspace.Info.GameSpeed
local Debris = game:GetService("Debris")
local LightningSparks = require(rs.VFXModules.LightningModule.LightningSparks)
local LightningModule = require(rs.VFXModules.LightningModule)
local FloatRocks = require(rs.VFXModules.FloatRocks)
local RocksModule = require(rs.VFXModules.RocksModule)
local vfxFolder = game.Workspace.VFX
local vfx_custom = require(rs.VFXModules.VFX_Custom)
local BezierCurve = require(rs.VFXModules.BezierCurve)

for i, unit in script:GetDescendants() do
    if not unit:IsA("ModuleScript") then continue end
	module[unit.Name] = require(unit) 
end

function module.getEnemyPos(enemy,oldpos)
	if enemy.PrimaryPart then
		return enemy.PrimaryPart.Position
	elseif enemy:FindFirstChild("HumanoidRootPart") then
		return enemy.HumanoidRootPart.Position
	else
		return oldpos
	end
end

module.SoundPlay = function(HRP, sound)
	local clone = sound:Clone()
	clone.Parent = HRP
	clone:Play()
	Debris:AddItem(clone,clone.TimeLength)
end

module.EmitAllParticles = function(container)
	for i, v in container:GetChildren() do
		if v:IsA("ParticleEmitter") then
			local emitCount = v:GetAttribute("EmitCount")
			if emitCount then
				v:Emit(emitCount)
			end
		else
			for x, y in v:GetDescendants() do
				if y:IsA("ParticleEmitter") then
					local emitCount = y:GetAttribute("EmitCount")
					if emitCount then
						y:Emit(emitCount)
					end
				end
			end
		end
	end
end

module.OnAllParticles = function(container)
	for i, v in container:GetChildren() do
		if v:IsA("ParticleEmitter") and v.Name ~= "TowerBasePart" then
			v.Enabled = true
		else
			for x, y in v:GetDescendants() do
				if y:IsA("ParticleEmitter") and v.Name ~= "TowerBasePart" then
					y.Enabled = true
				end
			end
		end
	end
end

module.OffAllParticles = function(container)
	for i, v in container:GetChildren() do
		if v:IsA("ParticleEmitter") and v.Name ~= "TowerBasePart" then
			v.Enabled = false
		else
			for x, y in v:GetDescendants() do
				if y:IsA("ParticleEmitter") and v.Name ~= "TowerBasePart" then
					y.Enabled = false
				end
			end

		end
	end
end



module.Transparency = function(container, switch)
	for i, v in container:GetChildren() do
		if v:IsA("Part")and v.Name ~= "HumanoidRootPart" and v.Name ~= "Lightning" and v.Name ~= "LightningBottom" and v.Name ~= "TowerBasePart" and v.Name ~= "VFXTowerBasePart" or v:IsA("MeshPart") then
			v.Transparency = switch
		else
			for x, y in v:GetDescendants() do
				if y:IsA("Part")and v.Name ~= "HumanoidRootPart" and v.Name ~= "Lightning" and v.Name ~= "LightningBottom" and v.Name ~= "TowerBasePart" and v.Name ~= "VFXTowerBasePart" or y:IsA("MeshPart") then
					y.Transparency = switch
				end
			end
		end
	end
end

module.CreateMotor6D = function(part0, part1, parent, cframe,deleteTime)
	local motor6D = Instance.new("Motor6D")
	motor6D.Name = "Motor6D"
	motor6D.Part0 = part0
	motor6D.Part1 = part1
	motor6D.Parent = parent
	motor6D.C0 = cframe
	Debris:AddItem(motor6D,deleteTime)
end

module.ScaleParticles = function(container,multiplier)
	for i, v in container:GetChildren() do
		if v:IsA("ParticleEmitter") then
			local newSize = {}
			for x, y in v.Size.Keypoints do
				table.insert(newSize,NumberSequenceKeypoint.new(y.Time,y.Value*multiplier))
			end 
			v.Size = NumberSequence.new(newSize)
			v.Speed = NumberRange.new(v.Speed.Min*multiplier,v.Speed.Max*multiplier)
			v.Acceleration*=multiplier
			v.VelocityInheritance*=multiplier
		else
			for x, particles in v:GetDescendants() do
				if particles:IsA("ParticleEmitter") then
					local newSize = {}
					for z, e in particles.Size.Keypoints do
						table.insert(newSize,NumberSequenceKeypoint.new(e.Time,e.Value*multiplier))
					end 
					particles.Size = NumberSequence.new(newSize)
					particles.Speed = NumberRange.new(particles.Speed.Min*multiplier,particles.Speed.Max*multiplier)
					particles.Acceleration*=multiplier
					particles.VelocityInheritance*=multiplier
				end
			end
		end
	end
end

module.CloneObject = function(object,pos,parent,debris,emit)

	local Part = object:Clone()
	if typeof(pos) == "Vector3" then
		Part.Position = pos
	else
		Part.CFrame = pos
	end 
	Part.Parent = parent
	Debris:AddItem(Part,debris)
	if emit then
		module.EmitAllParticles(Part)
	end
	return Part

end

local random = Random.new(tick())
function module.GetRandomNumber(min: number, max: number, decimals: boolean)
	if decimals then
		return random:NextNumber(min, max)
	else
		return random:NextInteger(min, max)
	end
end

function module.GetRandomSign()
	local sign = module.GetRandomNumber(-1, 1)
	if sign == 0 then
		sign = 1
	end
	return sign
end


function module.createBezier(finalPart: BasePart, rootPart: BasePart, params, secondparams)
	local start = rootPart.Position
	local goal = finalPart.Position

	local min, max = secondparams.Min, secondparams.Max
	local x = module.GetRandomNumber(min.X, max.X, true)
	x *= module.GetRandomSign()
	local y = module.GetRandomNumber(min.Y, max.Y, true)
	y *= module.GetRandomSign()
	local z = module.GetRandomNumber(min.Z, max.Z, true)
	z *= module.GetRandomSign()

	local alpha = module.GetRandomNumber(0.4, 0.6, true)
	local orientation = CFrame.Angles(CFrame.lookAt(rootPart.Position, goal):ToEulerAnglesXYZ())
	local middle = (CFrame.new(start:Lerp(goal, alpha)) * orientation) * CFrame.new(x, y, z)

	BezierCurve.Play(rootPart, {start, middle.Position, goal}, false, params)

	rootPart.Transparency = 1
	Debris:AddItem(rootPart, 0.5)
end

local function Tween(item, duration, style, direction, target)
	local newTween = TS:Create(item, TweenInfo.new(duration, style, direction), target)
	newTween:Play()

	return newTween
end

local function lerp(p0,p1,t)
	return p0*(1-t) + p1*t
end

local function quad(p0,p1,p2, t)
	local l1 = lerp(p0,p1,t)
	local l2 = lerp(p1,p2,t)
	local quad = lerp(l1,l2,t)
	return quad
end

local function tweenParticleSize(particleEmitter, startSize, endSize, duration)
	local startTime = tick()
	local endTime = startTime + duration

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local now = tick()
		local elapsedTime = now - startTime
		local alpha = elapsedTime / duration

		if alpha > 1 then
			alpha = 1
			connection:Disconnect()
		end

		local newSize = NumberSequence.new{
			NumberSequenceKeypoint.new(0, lerp(startSize, endSize, alpha)),
			NumberSequenceKeypoint.new(1, lerp(startSize, endSize, alpha))
		}

		particleEmitter.Size = newSize
	end)
end

local function tp(humrp,cf, obj)

	local x = {humrp,cf}

	for i = 1,2 do
		local model = obj
		model.CFrame = x[i]
		model.Parent = vfxFolder
		Debris:AddItem(model,5)

		module.OnAllParticles(model)
		delay(0.35,function()
			module.OffAllParticles(model)
		end)
	end
end	

local function Beam(model,dur,t,t2,x)
	for i,v in model:GetChildren() do
		if v:IsA('Beam') then
			local w0 = v.Width0 
			local w1 = v.Width1

			v.Width0 = 0
			v.Width1 = 0

			v.Enabled = true

			if t == nil then
				t = .15
			end

			if t2 == nil then
				t2 = .15
			end

			if x == nil then
				x = 2
			end

			TS:Create(v,TweenInfo.new(t2),{Width0 = w0*x;Width1 = w0*x}):Play()
			delay(.1,function()
				TS:Create(v,TweenInfo.new(t),{Width0 = w0;Width1 = w1}):Play()
				delay(dur,function()
					TS:Create(v,TweenInfo.new(t),{Width0 = 0;Width1 = 0}):Play()
				end)
			end)

		end
	end
end



--------------------------------------------------------SECRET--------------------------------------------------------

return module