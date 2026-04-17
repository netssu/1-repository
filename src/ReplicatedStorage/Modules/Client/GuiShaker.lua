local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Main = {}
Main.__index = Main

local noise = math.noise
local sin, cos = math.sin, math.cos

function Lerp(a,b,n)
	return (b-a)/(1/n)
end

function Main.new(Params: {Speed: number, instance: Instance})
	return setmetatable({
		instance = Params.instance,
		Speed = Params.Speed,
		
		Start = tick(),
		Instances = {},
	}, Main)
end

function Main:ShakeOnce(FinishTime: number, roughness: number, WidthRotation: boolean?)
	local Position = self.instance.Position
	local Rotation = self.instance.Rotation
	local Speed = self.Speed
	local Acceleration = 0
	
	local Settings = {["Position"] = Position, ["Rotation"] = Rotation}
	local Info = TweenInfo.new(5/Speed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local Out = TweenService:Create(self.instance, Info, Settings)
	
	local Instances = self.Instances
	local Start = tick()
	
	Instances[self.instance] = RunService.RenderStepped:Connect(function(dt)
		if tick()-Start < FinishTime then
			local t = tick()-Start
			
			local clamp = math.clamp(Acceleration, 0, 2)
			Acceleration += 0.1

			local calc = (sin(t * Speed) * roughness or 0.0005) / clamp
			local calc_cos = (cos(t * Speed) * roughness or 0.0005) / clamp
			local calc_rot = (sin(t * Speed) * 0.8 or 0.8) * math.pi / clamp
			
			local Position2 = UDim2.new(calc, 0, calc_cos/2, 0)
			
			task.delay(t/2, function()
				Acceleration -= 0.1
			end)

			self.instance.Position = Position + Position2
			self.instance.Rotation = WidthRotation and Lerp(Rotation, calc_rot, t)
		else
			if Instances[self.instance] then
				Out:Play()
				Instances[self.instance]:Disconnect()
				table.clear(Instances)
			end
		end
	end)
end

function Main:UnbindTo(name)
	if self.Instances[name] then
		self.Instances[name]:Disconnect()
		table.remove(self.Instances, name)
	else
		return
	end
end

return Main.new
