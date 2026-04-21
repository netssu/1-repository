local module = {}

local LightningBolt = require(script.LightningBolt)
local LightningSparks = require(script.LightningBolt.LightningSparks)
local tw = game:GetService('TweenService')
local ts = game:GetService('TweenService')


function module.rocks(properties)
	local rand = Random.new()
	local defaultProperties = {
		amount = 10;
		minSideForce = 10;
		maxSideForce = 40;
		minYForce = 65;
		maxYForce = 130;
		minRotation = 5;
		maxRotation = 10;
		minSize = 2;
		maxSize = 4;
		color = Color3.fromRGB(163, 162, 165);
		material = Enum.Material.Rock;
		useColorAndMaterial = false;
		filter = {};
		transparency = 0;
		position = Vector3.new();
		tweenSizeTime = 0.1;
		mass = 1;
		radius = 0; 
		collide = false;
		useParticle = false;
		particleLifetime = 1.5;
	}

	properties = properties or defaultProperties

	for i,v in defaultProperties do
		if properties[i] == nil then
			properties[i] = defaultProperties[i]
		end
	end

	local minXZForce,maxXZForce = properties["minSideForce"],properties["maxSideForce"]
	local minYForce,maxYForce = properties["minYForce"],properties["maxYForce"]


	local pos = properties["position"]
	local radius = properties["radius"]

	for i=1,properties["amount"] do

		task.spawn(function()

			local offsetPos = pos+Vector3.new(rand:NextNumber(-radius,radius),0.5,rand:NextNumber(-radius,radius))
			local direction = Vector3.new(0,-4.5)

			local rayParams = RaycastParams.new()

			local chars = {}
			for _,plr in game:GetService("Players"):GetPlayers() do
				if plr.Character then
					table.insert(chars,plr.Character)
				end
			end

			for _,char in chars do
				table.insert(properties["filter"],char)
			end

			rayParams.FilterDescendantsInstances = properties["filter"]

			local rayResult = workspace:Raycast(offsetPos,direction,rayParams)

			local rockPos = rayResult and rayResult.Position or pos
			local rockMaterial = properties["useColorAndMaterial"] and properties["material"] or (rayResult and rayResult.Material or properties["material"])
			local rockColor = properties["useColorAndMaterial"] and properties["color"] or (rayResult and rayResult.Instance.Color or properties["color"])

			local rock = Instance.new("Part")

			local particle

			if properties["useParticle"] then
				particle = properties["useParticle"]:Clone()
				particle.Enabled = true
				particle.Parent = rock
			end

			rock.Size = Vector3.new()

			local sizeNumber = rand:NextNumber(properties["minSize"],properties["maxSize"])
			local endSize = Vector3.new(sizeNumber,sizeNumber,sizeNumber)

			ts:Create(rock,TweenInfo.new(properties["tweenSizeTime"],Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Size = endSize}):Play()

			rock.CustomPhysicalProperties = PhysicalProperties.new(properties["mass"],0.3,0.5,1,1)

			rock.Color = rockColor
			rock.Material = rockMaterial
			rock.Anchored = false
			rock.CanCollide = false
			rock.Transparency = properties["transparency"]

			local cosTheta = math.random()*2 - 1
			local theta = math.acos(cosTheta)
			local phi = math.random()*math.pi*2
			local x = math.sin(theta)*math.cos(phi)
			local y = math.sin(theta)*math.sin(phi)
			local z = cosTheta
			local v = Vector3.new(x, y, z)

			rock.CFrame = CFrame.lookAt(rockPos,rockPos+v)
			local startPos = rock.Position
			rock.Parent = workspace

			local velocityX = rand:NextNumber(-maxXZForce,maxXZForce)
			local velocityY = rand:NextNumber(minYForce,maxYForce)
			local velocityZ = rand:NextNumber(-maxXZForce,maxXZForce)

			if math.random() > 0.5 then
				velocityX = ( (velocityX > minXZForce or velocityX < -minXZForce) or (velocityZ > minXZForce or velocityZ < -minXZForce) ) and velocityX or (math.random()>0.5 and minXZForce or -minXZForce)
			else
				velocityZ = ( (velocityZ > minXZForce or velocityZ < -minXZForce) or (velocityX > minXZForce or velocityX < -minXZForce) ) and velocityZ or (math.random()>0.5 and minXZForce or -minXZForce)
			end

			local impulseVector = Vector3.new(velocityX,velocityY,velocityZ)

			rock.Velocity = impulseVector

			local rotationX = math.random()>0.5 and rand:NextNumber(properties["minRotation"],properties["maxRotation"]) or rand:NextNumber(-properties["minRotation"],-properties["maxRotation"])
			local rotationY = math.random()>0.5 and rand:NextNumber(properties["minRotation"],properties["maxRotation"]) or rand:NextNumber(-properties["minRotation"],-properties["maxRotation"])
			local rotationZ = math.random()>0.5 and rand:NextNumber(properties["minRotation"],properties["maxRotation"]) or rand:NextNumber(-properties["minRotation"],-properties["maxRotation"])

			local rotationVelocity = Vector3.new(rotationX,rotationY,rotationZ)

			rock.RotVelocity = rotationVelocity

			if properties["collide"] then
				task.delay(0.1,function()
					rock.CanCollide = true
					local touchCon
					touchCon = rock.Touched:Connect(function(obj)
						touchCon:Disconnect()

						task.delay(1+rand:NextNumber(-0.3,0.7),function()

							--disable particles
							if properties["useParticle"] then
								particle.Enabled = false

								task.wait(properties["particleLifetime"]-1)
							end

							ts:Create(rock,TweenInfo.new(0.5,Enum.EasingStyle.Linear),{Transparency = 1}):Play()

							task.delay(0.5,rock.Destroy,rock)

						end)

					end)
				end)



			else

				task.spawn(function()
					repeat
						task.wait()
					until rock.Position.Y < startPos.Y-5

					ts:Create(rock,TweenInfo.new(properties["tweenSizeTime"]+0.1,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Size = Vector3.new()}):Play()

					if properties["useParticle"] then
						particle.Enabled = false

						task.wait(properties["particleLifetime"]-(properties["tweenSizeTime"]+0.1))
					end

					game:GetService("Debris"):AddItem(rock,properties["tweenSizeTime"]+0.1)

				end)

			end

		end)
	end
end

function module.SetRock(Middle,Cound,Area,Size,dur)
	spawn(function()

		local C = Cound or 5
		local A = Area or 25
		local Si = Size or 25

		local RockModel = Instance.new("Model")
		RockModel.Name = "Rock"

		RockModel.Parent = workspace.CurrentCamera
		game.Debris:AddItem(RockModel,12)

		local Info = TweenInfo.new(
			.3, 
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.Out, 
			0, 
			false, 
			0 
		)

		local SS = Area/7.5 * 20
		local Goals = {
			Size = Vector3.new(SS,SS,SS);
		}

		delay(0.1,function()
			local Goals = {
				Transparency = 1
			}

		end)

		for i = 1,C do
			local Rather = A * math.random(5,10)/7.5


			local R = Instance.new("Part")
			R.Parent = RockModel
			R.Material = "Slate"
			R.Name = "Rock".. math.random(.5,50) * math.random(.5,50)
			R.Color = Color3.new(0.2, 0.2, 0.2)
			R.Anchored = true
			R.CanCollide = false

			R.Size = Vector3.new(Si*1,Si*1,Si*1)
			R.CFrame = Middle * CFrame.new( (math.cos(math.rad((i *  (-360 / C) )))* Rather) ,-9, (math.sin(math.rad((i *  (-360 / C)))) * Rather)) 
			R.CFrame = CFrame.new(R.Position,Middle.Position)


			spawn(function()
				local Info = TweenInfo.new(
					.25, -- Time
					Enum.EasingStyle.Sine, 
					Enum.EasingDirection.Out, 
					0, 
					false,
					0 
				)


				local Goals = {
					Position = R.Position + Vector3.new(0,6.5,0)

				}


				local Tween = tw:Create(R, Info, Goals)
				Tween:Play()


			end)
		end

		for i,rock in RockModel:GetChildren() do
			rock.CanCollide = false
		end

		wait(dur)
		for i,rock in RockModel:GetChildren() do
			local Info = TweenInfo.new(
				2, 
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				0, 
				false, 
				0 
			)

			local Goals = {
				Transparency = 1;
				Position = rock.Position + Vector3.new(0,-3,0);
				Size = Vector3.new(0,0,0)
			}	

			local Tween = tw:Create(rock, Info, Goals)
			Tween:Play()

		end

	end)
end

function module.lightning(part1,part2,color,curve,spd)

	if curve == nil then
		curve = 0
	end

	if spd == nil then
		spd = 15
	end

	local attach1 = nil
	local attach2 = nil

	if part1:IsA('Attachment') then
		attach1 = part1
		attach2 = part2
	else
		attach1 = Instance.new("Attachment", part1)
		attach1.Name = "Attachment1"
		attach2 = Instance.new("Attachment", part2)
		attach2.Name = "Attachment2"
	end
	local a1, a2 = attach1, attach2
	local Beam = Instance.new("Beam", workspace)
	Beam.Attachment0 = attach1
	Beam.Attachment1 = attach2
	Beam.Transparency = NumberSequence.new(1)
	spawn(function()
		for i = 1,2 do
			local ranCF = CFrame.fromAxisAngle((part2.Position - part1.Position).Unit, 0 * math.random() * math.pi)
			local A1, A2 = {}, {}
			A1.WorldPosition, A1.WorldAxis = a1.WorldPosition, ranCF*a1.WorldAxis
			A2.WorldPosition, A2.WorldAxis = a2.WorldPosition, ranCF*a2.WorldAxis
			local NewBolt = LightningBolt.new(A1, A2, 75)
			NewBolt.CurveSize0, NewBolt.CurveSize1 = Beam.CurveSize0, 0
			NewBolt.PulseSpeed = spd
			NewBolt.PulseLength = .75
			NewBolt.FadeLength = .25
			NewBolt.Color = color
			local NewSparks = LightningSparks.new(NewBolt)
			task.wait(.2)
		end
		Beam:Destroy()
	end)
end


function module.Beam(model,dur,t,t2,x)
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

			tw:Create(v,TweenInfo.new(t2),{Width0 = w0*x;Width1 = w0*x}):Play()
			delay(.1,function()
				tw:Create(v,TweenInfo.new(t),{Width0 = w0;Width1 = w1}):Play()
				delay(dur,function()
					tw:Create(v,TweenInfo.new(t),{Width0 = 0;Width1 = 0}):Play()
				end)
			end)

		end
	end
end

function module.On(particle)
	for i,v in particle:GetChildren() do
		if v:IsA('ParticleEmitter') then
			v.Enabled = true

		elseif v:IsA('Attachment') then
			for i,v2 in v:GetChildren() do
				if v2:IsA("ParticleEmitter") then
					v2.Enabled = true
				end
			end
		end
	end
end

function module.Off(particle)
	for i,v in particle:GetChildren() do
		if v:IsA('ParticleEmitter') then
			v.Enabled = false

		elseif v:IsA('Attachment') then
			for i,v2 in v:GetChildren() do
				v2.Enabled = false
			end
		end
	end
end

function module.Particle(particle,dl)
	for i,v in particle:GetChildren() do
		if v:IsA('ParticleEmitter') then
			v.Enabled = true

			delay(dl,function()
				v.Enabled = false
			end)
		elseif v:IsA('Attachment') then
			for i,v2 in v:GetChildren() do
				if v2:IsA("ParticleEmitter") then
					v2.Enabled = true

					delay(dl,function()
						v2.Enabled = false
					end)
				end
			end
		end
	end
end

function module.Emit(particle,x)
	for i,v in particle:GetChildren() do
		if v:IsA('ParticleEmitter') then
			v:Emit(x)
		elseif v:IsA('Attachment') then
			for i,v2 in v:GetChildren() do
				if v2:IsA("ParticleEmitter") then
					v2:Emit(x)
				end
			end
		end
	end
end

function module.EmitAttr(particle)
	for i,v in particle:GetChildren() do
		if v:IsA('ParticleEmitter') then
			v:Emit(v:GetAttribute("EmitCount"))
		elseif v:IsA('Attachment') then
			for i,v2 in v:GetChildren() do
				if v2:IsA("ParticleEmitter") then
					v2:Emit(v2:GetAttribute("EmitCount"))
				end
			end
		end
	end
end

function module.Particle2(v,dl)
	if v:IsA('ParticleEmitter') then
		v.Enabled = true

		delay(dl,function()
			v.Enabled = false
		end)
	elseif v:IsA('Attachment') then
		for i,v2 in v:GetChildren() do
			v2.Enabled = true

			delay(dl,function()
				v2.Enabled = false
			end)
		end
	end
end

function module.Mesh_Animation(m)
	local e = m.Keyframes
	local max = #e:GetChildren()
	spawn(function()
		for i = 1,max do
			local o = e:FindFirstChild(i-1)
			local n = e:FindFirstChild(i)

			if i-1 <= 0 then
				e:FindFirstChild(max).Transparency = 1
			else
				o.Transparency = 1
			end

			n.Transparency = 0
			game:GetService('RunService').Heartbeat:wait()
		end
	end)
end

function module.FloorBreak(m,max,cf,humrp)
	for i = 1,max do
		local p = Instance.new("Part",workspace)
		p.Anchored = false
		p.CanCollide = false
		p.Size = Vector3.new(1.5,1.5,1.5)
		p.CFrame =  cf
		p.Orientation = Vector3.new(math.random(-180,180),math.random(-180,180),math.random(-180,180))
		p.Velocity = Vector3.new(math.random(-m,m),math.random(-m,100),math.random(-m,m))
		game.Debris:AddItem(p,1)

		local ray = Ray.new(p.Position,Vector3.new(0,-50,0))
		local part,pos = workspace:FindPartOnRayWithIgnoreList(ray,{p,humrp})
		if part then
			p.Color = part.Color
			p.Material = p.Material
		end
		game:GetService('RunService').Heartbeat:Wait()
	end
end

function module.Clone(x_,TF,DF)
	local TimeFade = TF
	local DelayFade = DF

	local function Clone_(v_)
		local v = v_:Clone()

		for i,v2 in v:GetChildren() do
			if v2:IsA('Motor6D') or v2:IsA('WeldConstraint') or v2:IsA('Decal') then
				v2:Destroy()
			end
		end
		v.Transparency = .65
		v.CanTouch = false
		v.CanCollide = false
		v.Anchored = true
		v.Material = Enum.Material.Neon
		v.Color = Color3.new(0.501961, 0.733333, 0.858824)
		v.Parent = workspace

		delay(DelayFade,function()
			game.TweenService:Create(v,TweenInfo.new(TimeFade),{Transparency = 1}):play()
			delay(TimeFade,function()
				v:Destroy()
			end)
		end)
	end

	local x = x_:Clone()
	for i, v in x:GetChildren() do
		if v.Name == 'FakeHead' then
			Clone_(v)
		elseif v:IsA("Part") and v.Name ~= "HumanoidRootPart" then
			Clone_(v)
		elseif v:IsA("Part") and v.Name == "Head" then
			Clone_(v)
		elseif v.Name == 'Acc' then
			for i,v2 in v.Hair:GetChildren() do
				Clone_(v2)
			end
		end
	end
end

function module.Fade(humrp,n,x,t)
	local bool = nil
	if n == 0 then
		bool = true
	else
		bool = false
	end
	for i, v in x:GetChildren() do
		if v.Name == 'FakeHead' then
			game.TweenService:Create(v,TweenInfo.new(t),{Transparency = n}):play()
			game.TweenService:Create(v.face,TweenInfo.new(t),{Transparency = n}):play()
		elseif v:IsA("Part") and v.Name ~= "HumanoidRootPart" then
			game.TweenService:Create(v,TweenInfo.new(t),{Transparency = n}):play()
		elseif v:IsA("Part") and v.Name == "Head" then
			game.TweenService:Create(v,TweenInfo.new(t),{Transparency = n}):play()
		elseif v.Name == 'Acc' then
			for i,v2 in v:GetChildren() do
				if v2.Name == 'Hair' then
					for i,v3 in v2:GetChildren() do
						game.TweenService:Create(v3,TweenInfo.new(t),{Transparency = n}):play()
					end
				elseif v2.Name == 'Particle' then
					for i,v3 in v2:GetChildren() do
						if v3:IsA('ParticleEmitter') then
							v3.Enabled = bool
						end
					end
				else
					game.TweenService:Create(v2,TweenInfo.new(t),{Transparency = n}):play()
				end
			end
		end
	end
end


return module


