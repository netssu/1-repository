local Rocks = {}

local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local PS = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local Modules = RS.Modules
local partCacheMod = require(script.PartCache)
local Deb = game:GetService("Debris")

local cacheFolder
if not workspace:FindFirstChild("Debris") then
	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "Debris"
	cacheFolder.Parent = workspace
else
	cacheFolder = workspace.Debris
end

local partCache = partCacheMod.new(Instance.new("Part"), 1, cacheFolder)

function Rocks.Ground(Pos, Distance, Size, filter, MaxRocks, Ice, despawnTime)
	local random = Random.new()
	
	local angle = 30
	local otherAngle = 360/MaxRocks
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter or {}
	if game.Players.LocalPlayer and game.Players.LocalPlayer.Character then
		table.insert(params.FilterDescendantsInstances, game.Players.LocalPlayer.Character)
	end
	table.insert(params.FilterDescendantsInstances, cacheFolder)

	local size
	size = Size or Vector3.new(2, 2, 2)
	local pos = Pos
	despawnTime = despawnTime or 3

	local function OuterRocksLoop ()
		for i = 1, MaxRocks do
			local cf = CFrame.new(Pos)
			local newCF = cf * CFrame.fromEulerAnglesXYZ(0, math.rad(angle), 0) * CFrame.new(Distance/2 + Distance/2.7, 10, 0)
			local ray = workspace:Raycast(newCF.Position, Vector3.new(0, -20, 0), params)
			angle += otherAngle
			if ray then
				local part = partCache:GetPart()
				local hoof = partCache:GetPart()
				--Deb:AddItem(part,3)
				--Deb:AddItem(hoof,3)
				part.CFrame = CFrame.new(ray.Position - Vector3.new(0, 0.5, 0), Pos) * CFrame.fromEulerAnglesXYZ(random:NextNumber(-.25, .5), random:NextNumber(-.25, .25), random:NextNumber(-.25, .25))
				part.Size = Vector3.new(size.X * 1.3, size.Y/1.4, size.Z * 1.3) * random:NextNumber(1, 1.5)
				
				hoof.Size = Vector3.new(part.Size.X * 1.01, part.Size.Y * 0.25, part.Size.Z * 1.01)
				hoof.CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - hoof.Size.Y / 2.1, 0)
				
				part.Parent = cacheFolder
				hoof.Parent = cacheFolder
				
				if ray.Instance.Material == Enum.Material.Concrete or ray.Instance.Material == Enum.Material.Air or ray.Instance.Material == Enum.Material.Wood or ray.Instance.Material == Enum.Material.Neon or ray.Instance.Material == Enum.Material.WoodPlanks then
					part.Material = ray.Instance.Material	
					hoof.Material = ray.Instance.Material	
				else
					part.Material = Enum.Material.Concrete
					hoof.Material = ray.Instance.Material	
				end

				part.BrickColor = BrickColor.new("Dark grey")
				part.Anchored = true
				part.CanTouch = false
				part.CanCollide = false
				part.CanQuery = false

				hoof.BrickColor = ray.Instance.BrickColor
				hoof.Anchored = true
				hoof.CanTouch = false
				hoof.CanCollide = false
				hoof.CanQuery = false

				if Ice then
					part.BrickColor = BrickColor.new("Pastel light blue")
					hoof.BrickColor = BrickColor.new("Lily white")
					part.Material = Enum.Material.Ice
					hoof.Material = Enum.Material.Sand
				end
				
				task.delay(despawnTime, function()
					TS:Create(part,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01)}):Play()
					TS:Create(hoof,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01), CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - part.Size.Y / 2.1, 0)}):Play()
					
					task.delay(0.6, function()
						partCache:ReturnPart(part)
						partCache:ReturnPart(hoof)
					end)
				end)
			end		
		end
	end

	local function InnerRocksLoop ()
		for i = 1, MaxRocks do
			local cf = CFrame.new(Pos)
			local newCF = cf * CFrame.fromEulerAnglesXYZ(0, math.rad(angle), 0) * CFrame.new(Distance/2 + Distance/10, 10, 0)
			local ray = game.Workspace:Raycast(newCF.Position, Vector3.new(0, -20, 0), params)
			angle += otherAngle
			if ray then
				local part = partCache:GetPart()
				local hoof = partCache:GetPart()
				--Deb:AddItem(part,3)
				--Deb:AddItem(hoof,3)

				part.CFrame = CFrame.new(ray.Position - Vector3.new(0, size.Y * 0.4, 0), Pos) * CFrame.fromEulerAnglesXYZ(random:NextNumber(-1,-0.3),random:NextNumber(-0.15,0.15),random:NextNumber(-.15,.15))
				part.Size = Vector3.new(size.X * 1.3, size.Y * 0.7, size.Z * 1.3) * random:NextNumber(1, 1.5)

				hoof.Size = Vector3.new(part.Size.X * 1.01, part.Size.Y * 0.25, part.Size.Z * 1.01)
				hoof.CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - hoof.Size.Y / 2.1, 0)

				part.Parent = cacheFolder
				hoof.Parent = cacheFolder

				if ray.Instance.Material == Enum.Material.Concrete or ray.Instance.Material == Enum.Material.Air or ray.Instance.Material == Enum.Material.Wood or ray.Instance.Material == Enum.Material.Neon or ray.Instance.Material == Enum.Material.WoodPlanks then
					part.Material = ray.Instance.Material	
					hoof.Material = ray.Instance.Material	
				else
					part.Material = Enum.Material.Concrete --ray.Instance.Material	
					hoof.Material = ray.Instance.Material	
				end

				part.BrickColor = BrickColor.new("Dark grey") --ray.Instance.BrickColor
				part.Anchored = true
				part.CanTouch = false
				part.CanCollide = false
				part.CanQuery = false

				hoof.BrickColor = ray.Instance.BrickColor
				hoof.Anchored = true
				hoof.CanTouch = false
				hoof.CanCollide = false
				hoof.CanQuery = false

				if Ice then
					part.BrickColor = BrickColor.new("Pastel light blue")
					hoof.BrickColor = BrickColor.new("Lily white")
					part.Material = Enum.Material.Ice
					hoof.Material = Enum.Material.Sand
				end

				task.delay(despawnTime, function()
					TS:Create(part,TweenInfo.new(0.5),{Size = Vector3.new(0, 0, 0)}):Play()
					TS:Create(hoof,TweenInfo.new(0.5),{Size = Vector3.new(0, 0, 0), CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - part.Size.Y / 2.1, 0)}):Play()
					

					task.delay(0.6, function()
						partCache:ReturnPart(part)
						partCache:ReturnPart(hoof)
					end)
				end)
			end		
		end
	end
	InnerRocksLoop()
	OuterRocksLoop()
end

function Rocks.Boom(properties)

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
	local rand = Random.new()
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

			TS:Create(rock,TweenInfo.new(properties["tweenSizeTime"],Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Size = endSize}):Play()

			rock.CustomPhysicalProperties = PhysicalProperties.new(properties["mass"],0.3,0.5,1,1)

			rock.Color = rockColor
			rock.Material = rockMaterial
			rock.Anchored = false
			rock.CanCollide = false
			rock.CanQuery = false
			rock.CanTouch = false
			rock.Transparency = 1
			delay(0.175, function()
				rock.Transparency = properties["transparency"]
			end)

			local cosTheta = math.random()*2 - 1
			local theta = math.acos(cosTheta)
			local phi = math.random()*math.pi*2
			local x = math.sin(theta)*math.cos(phi)
			local y = math.sin(theta)*math.sin(phi)
			local z = cosTheta
			local v = Vector3.new(x, y, z)

			rock.CFrame = CFrame.lookAt(rockPos,rockPos+v)
			local startPos = rock.Position
			rock.Parent = game.Workspace.VFX

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

							TS:Create(rock,TweenInfo.new(0.5,Enum.EasingStyle.Linear),{Transparency = 1}):Play()

							task.delay(0.5,rock.Destroy,rock)

						end)

					end)
				end)



			else

				task.spawn(function()
					repeat
						task.wait()
					until rock.Position.Y < startPos.Y-5

					TS:Create(rock,TweenInfo.new(properties["tweenSizeTime"]+0.1,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Size = Vector3.new()}):Play()

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

return Rocks
