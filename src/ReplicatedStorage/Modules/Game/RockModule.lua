local RockModule = {}
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local DebrisFolder: Folder

-- ============================================
-- CONFIGURAÇÕES VISUAIS
-- ============================================
local CONFIG = {
	-- Crater (Pedras em anel)
	crater_rise_height_min = 0.15, -- Era 0.3 (Sobe menos do chão)
	crater_rise_height_max = 0.3,  -- Era 0.6
	crater_rise_time = 0.15,       -- Sobe mais rápido
	crater_stay_time_min = 1.5,    -- Era 5.0 (Some bem mais rápido)
	crater_stay_time_max = 2.5,    -- Era 8.0
	crater_sink_time = 1.0,        -- Afunda mais rápido
	crater_lifetime = 10,

	-- Pedras menores que saem na borda da cratera (debris decorativo)
	crater_small_debris = true,
	crater_small_debris_count_min = 1, -- Menos pedrinhas
	crater_small_debris_count_max = 2,
	crater_small_debris_size_min = 0.2,
	crater_small_debris_size_max = 0.5, -- Bem menores

	-- Explosion (Pedras voando)
	explosion_velocity_min = 10,  -- Era 20 (Voa menos longe)
	explosion_velocity_max = 25,  -- Era 45
	explosion_upward_min = 10,    -- Sobe menos
	explosion_upward_max = 22,
	explosion_spin_speed = 4,
	explosion_lifetime = 2.0,     -- Some mais rápido
	explosion_fade_time = 0.5,

	-- Dust particles (Poeira central)
	dust_enabled = true,
	dust_count_min = 1,           -- Menos fumaça
	dust_count_max = 3,
	dust_size_min = 1.0,          -- Fumaça menor
	dust_size_max = 2.5,
	dust_lifetime = 0.5,          -- Some muito mais rápido
	dust_rise_speed = 3,          -- Sobe menos
	dust_spread = 4,              -- Espalha menos

	-- Validação
	max_ground_ray_distance = 50,
	min_surface_angle = 0.3, 
}

-- ============================================
-- UTILIDADES
-- ============================================

local function CheckDebrisFolder()
	DebrisFolder = workspace:FindFirstChild("Debris") :: Folder
	if not DebrisFolder then
		DebrisFolder = Instance.new("Folder")
		DebrisFolder.Name = "Debris"
		DebrisFolder.Parent = workspace
	end
end

--- Cria RaycastParams excluindo players, debris, e objetos com tag "RockModuleIgnore"
local function CreateRaycastParams(): RaycastParams
	local params = RaycastParams.new()

	local exclude = { DebrisFolder }
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			table.insert(exclude, plr.Character)
		end
	end
	for _, obj in CollectionService:GetTagged("RockModuleIgnore") do
		table.insert(exclude, obj)
	end

	params.FilterDescendantsInstances = exclude
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	return params
end

--- Faz raycast para baixo e valida se é uma superfície válida (chão, não parede)
local function RaycastGround(origin: Vector3, params: RaycastParams, maxDist: number?): RaycastResult?
	local dist = maxDist or CONFIG.max_ground_ray_distance
	local hit = workspace:Raycast(origin, Vector3.new(0, -dist, 0), params)

	if not hit then return nil end

	-- Ignora superfícies muito inclinadas (paredes/tetos)
	if hit.Normal.Y < CONFIG.min_surface_angle then return nil end

	return hit
end

--- Retorna cor/material/transparência de um RaycastResult
local function GetSurfaceAppearance(hit: RaycastResult): (Color3, Enum.Material, number)
	local inst = hit.Instance
	return inst.Color, inst.Material, inst.Transparency
end

--- Gera um tamanho de pedra com variação natural (não cúbica perfeita)
local function RandomRockSize(minS: number, maxS: number): Vector3
	local base = minS + math.random() * (maxS - minS)
	-- Variação por eixo para parecer mais orgânico
	local xScale = 0.7 + math.random() * 0.6
	local yScale = 0.5 + math.random() * 0.7
	local zScale = 0.7 + math.random() * 0.6
	return Vector3.new(base * xScale, base * yScale, base * zScale)
end

--- Gera uma rotação aleatória
local function RandomRotation(): CFrame
	return CFrame.Angles(
		math.rad(math.random(0, 360)),
		math.rad(math.random(0, 360)),
		math.rad(math.random(0, 360))
	)
end

--- Lerp entre dois números
local function Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- ============================================
-- DUST / PARTÍCULAS DE POEIRA
-- ============================================

local function SpawnDust(position: Vector3, surfaceColor: Color3, radius: number, params: RaycastParams)
	if not CONFIG.dust_enabled then return end

	-- Quantidade de poeira escala com raio
	local dustScale = math.clamp(radius / 6, 0.5, 2.0)
	local countMin = math.floor(CONFIG.dust_count_min * dustScale)
	local countMax = math.floor(CONFIG.dust_count_max * dustScale)
	countMax = math.min(countMax, 12)
	local count = math.random(countMin, math.max(countMin, countMax))

	for i = 1, count do
		task.spawn(function()
			-- Delay leve para escalonar as partículas
			task.wait(math.random() * 0.1)

			local dust = Instance.new("Part")
			dust.Name = "Dust"
			dust.Parent = DebrisFolder
			dust.Anchored = true
			dust.CanCollide = false
			dust.CanQuery = false
			dust.CanTouch = false
			dust.CastShadow = false

			local size = Lerp(CONFIG.dust_size_min, CONFIG.dust_size_max, math.random())
			dust.Size = Vector3.new(size, size, size)
			dust.Shape = Enum.PartType.Ball

			-- Posiciona ao redor do impacto
			local angle = math.random() * math.pi * 2
			local dist = math.random() * radius * 0.8
			local offsetX = math.cos(angle) * dist
			local offsetZ = math.sin(angle) * dist
			dust.Position = position + Vector3.new(offsetX, 0.5, offsetZ)

			-- Aparência de poeira
			local h, s, v = surfaceColor:ToHSV()
			local dustColor = Color3.fromHSV(h, math.max(0, s - 0.15), math.min(1, v + 0.25))
			dust.Color = dustColor
			dust.Material = Enum.Material.SmoothPlastic
			dust.Transparency = 0.4

			-- Sobe e desaparece
			local targetY = dust.Position.Y + CONFIG.dust_rise_speed * (0.5 + math.random() * 0.5)
			local spreadX = (math.random() - 0.5) * CONFIG.dust_spread
			local spreadZ = (math.random() - 0.5) * CONFIG.dust_spread
			local targetPos = Vector3.new(dust.Position.X + spreadX, targetY, dust.Position.Z + spreadZ)
			local targetSize = dust.Size * (0.3 + math.random() * 0.3)

			local tweenInfo = TweenInfo.new(
				CONFIG.dust_lifetime * (0.8 + math.random() * 0.4),
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)

			TweenService:Create(dust, tweenInfo, {
				Position = targetPos,
				Size = targetSize,
				Transparency = 1,
			}):Play()

			Debris:AddItem(dust, CONFIG.dust_lifetime + 0.5)
		end)
	end
end

-- ============================================
-- SMALL DEBRIS (pedrinhas decorativas na borda)
-- ============================================

local function SpawnSmallDebris(center: Vector3, radius: number, surfaceColor: Color3, surfaceMaterial: Enum.Material, playerCollision: boolean)
	if not CONFIG.crater_small_debris then return end

	-- Quantidade escala com o raio da cratera
	local radiusScale = math.clamp(radius / 6, 0.5, 2.0)
	local countMin = math.floor(CONFIG.crater_small_debris_count_min * radiusScale)
	local countMax = math.floor(CONFIG.crater_small_debris_count_max * radiusScale)
	countMax = math.min(countMax, 10) -- cap performance
	local count = math.random(countMin, math.max(countMin, countMax))

	for i = 1, count do
		task.spawn(function()
			task.wait(math.random() * 0.15)

			local pebble = Instance.new("Part")
			pebble.Name = "Pebble"
			pebble.Parent = DebrisFolder
			pebble.Anchored = false
			pebble.CanCollide = true

			local sz = Lerp(CONFIG.crater_small_debris_size_min, CONFIG.crater_small_debris_size_max, math.random())
			pebble.Size = Vector3.new(sz * (0.8 + math.random() * 0.4), sz * (0.6 + math.random() * 0.5), sz * (0.8 + math.random() * 0.4))

			-- Posição na borda da cratera
			local angle = math.random() * math.pi * 2
			local dist = radius * (0.6 + math.random() * 0.5)
			pebble.Position = center + Vector3.new(math.cos(angle) * dist, 0.3, math.sin(angle) * dist)
			pebble.CFrame = pebble.CFrame * RandomRotation()

			pebble.Color = surfaceColor
			pebble.Material = surfaceMaterial

			if not playerCollision then
				pebble.CollisionGroup = "RockDebris"
			end

			-- Pequeno impulso para cima e para fora
			local pushDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local vel = Instance.new("BodyVelocity")
			vel.Velocity = pushDir * (5 + math.random() * 10) + Vector3.new(0, 8 + math.random() * 6, 0)
			vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			vel.P = 3000
			vel.Parent = pebble
			Debris:AddItem(vel, 0.2)

			Debris:AddItem(pebble, 6)

			-- Desaparece suavemente
			task.wait(4.5 + math.random() * 1)
			if pebble and pebble.Parent then
				TweenService:Create(pebble, TweenInfo.new(0.6, Enum.EasingStyle.Linear), {
					Size = Vector3.new(0.1, 0.1, 0.1),
					Transparency = 1,
				}):Play()
			end
		end)
	end
end

-- ============================================
-- CRATER (Pedras que sobem do chão em anel)
-- ============================================

function RockModule.Crater(Center: CFrame, Radius: number, MinRocks: number, MaxRocks: number, PlayerCollision: boolean)
	Radius = Radius or 7
	MinRocks = MinRocks or 7
	MaxRocks = MaxRocks or 10
	if PlayerCollision == nil then PlayerCollision = true end

	CheckDebrisFolder()
	local params = CreateRaycastParams()

	-- Raycast principal para encontrar o chão
	local centerHit = RaycastGround(Center.Position, params, 1000)
	if not centerHit then return end

	local groundPos = centerHit.Position
	local surfaceColor, surfaceMaterial, surfaceTransparency = GetSurfaceAppearance(centerHit)
	local groundCFrame = CFrame.new(groundPos)

	local numRocks = math.random(MinRocks, MaxRocks)
	local angleStep = 360 / numRocks

	-- Poeira no centro
	SpawnDust(groundPos, surfaceColor, Radius, params)

	-- Pedrinhas decorativas
	SpawnSmallDebris(groundPos, Radius, surfaceColor, surfaceMaterial, PlayerCollision)

	for i = 1, numRocks do
		-- Ângulo com leve variação para não ficar perfeitamente simétrico
		local angle = (i - 1) * angleStep + math.random(-8, 8)
		local angleRad = math.rad(angle)

		-- Distância do centro com variação
		local distVariation = 0.75 + math.random() * 0.5
		local dist = Radius * distVariation

		-- Posição horizontal
		local offsetX = math.cos(angleRad) * dist
		local offsetZ = math.sin(angleRad) * dist
		local rockOrigin = groundPos + Vector3.new(offsetX, 5, offsetZ)

		-- Raycast individual para cada pedra - garante que está sobre chão real
		local rockHit = RaycastGround(rockOrigin, params, 20)
		if rockHit then
			local rockGroundPos = rockHit.Position
			local rockColor, rockMaterial, rockTransparency = GetSurfaceAppearance(rockHit)

			-- Tamanho proporcional à distância do centro (mais perto = maior)
			local distFactor = 1 - (math.min(dist, Radius) / Radius) * 0.4
			local baseMin = 2.0 * distFactor
			local baseMax = 4.5 * distFactor
			local rockSize = RandomRockSize(baseMin, baseMax)

			local rock = Instance.new("Part")
			rock.Name = "CraterRock"
			rock.Parent = DebrisFolder
			rock.Size = rockSize
			rock.Anchored = true
			rock.CanCollide = true

			-- Posiciona abaixo do chão (vai subir com tween)
			local sinkDepth = rockSize.Y + 1
			rock.CFrame = CFrame.new(rockGroundPos + Vector3.new(0, -sinkDepth, 0)) * RandomRotation()

			-- Inclinação leve para fora (mais natural)
			local tiltAngle = math.rad(math.random(5, 25))
			local tiltAxis = Vector3.new(math.cos(angleRad), 0, math.sin(angleRad))
			rock.CFrame = rock.CFrame * CFrame.fromAxisAngle(tiltAxis, tiltAngle)

			rock.Color = rockColor
			rock.Material = rockMaterial
			rock.Transparency = rockTransparency

			if not PlayerCollision then
				rock.CollisionGroup = "RockDebris"
			end

			Debris:AddItem(rock, CONFIG.crater_lifetime)

			-- A pedra sobe até ficar parcialmente enterrada no chão
			-- risePercent controla quanto da pedra fica visível (0.3 = 30% acima do chão)
			local risePercent = Lerp(CONFIG.crater_rise_height_min, CONFIG.crater_rise_height_max, math.random())
			local visibleAmount = rockSize.Y * risePercent * distFactor
			local targetPos = rockGroundPos + Vector3.new(0, visibleAmount - rockSize.Y * 0.5, 0)

			-- Delay escalonado do centro pra fora (onda de impacto)
			local delayTime = (dist / Radius) * 0.08

			task.spawn(function()
				if delayTime > 0 then task.wait(delayTime) end

				-- Sobe
				local riseTween = TweenService:Create(rock, TweenInfo.new(
					CONFIG.crater_rise_time,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out
					), {
						Position = targetPos,
					})
				riseTween:Play()

				-- Espera antes de afundar
				local stayTime = Lerp(CONFIG.crater_stay_time_min, CONFIG.crater_stay_time_max, math.random())
				task.wait(stayTime)

				-- Afunda de volta pro chão e some
				if rock and rock.Parent then
					local sinkTarget = rockGroundPos + Vector3.new(0, -rockSize.Y, 0)
					local sinkTween = TweenService:Create(rock, TweenInfo.new(
						CONFIG.crater_sink_time,
						Enum.EasingStyle.Sine,
						Enum.EasingDirection.In
						), {
							Position = sinkTarget,
							Size = Vector3.new(0.5, 0.5, 0.5),
							Transparency = 1,
						})
					sinkTween:Play()
				end
			end)
		end
	end
end

-- ============================================
-- EXPLOSION (Debris que voam com física)
-- ============================================

function RockModule.Explosion(Center: CFrame, TotalRocks: number, MinSize: number, MaxSize: number, PlayerCollision: boolean)
	TotalRocks = TotalRocks or 7
	MinSize = MinSize or 0.5
	MaxSize = MaxSize or 2.5
	if PlayerCollision == nil then PlayerCollision = false end

	CheckDebrisFolder()
	local params = CreateRaycastParams()

	local hit = RaycastGround(Center.Position, params, 100)
	if not hit then return end

	local groundPos = hit.Position
	local surfaceColor, surfaceMaterial, surfaceTransparency = GetSurfaceAppearance(hit)

	for i = 1, TotalRocks do
		task.spawn(function()
			-- Micro delay escalonado para não spawnar tudo no mesmo frame
			if i > 1 then task.wait(math.random() * 0.04) end

			local rock = Instance.new("Part")
			rock.Name = "ExplosionDebris"
			rock.Parent = DebrisFolder
			rock.Anchored = false
			rock.CanCollide = true
			rock.CastShadow = false

			-- Formas variadas
			local shapeRoll = math.random(1, 10)
			if shapeRoll <= 2 then
				-- Laje fina (20%)
				local sz = Lerp(MinSize, MaxSize, math.random())
				rock.Size = Vector3.new(sz * (1.5 + math.random()), 0.15 + math.random() * 0.15, sz * (1.5 + math.random()))
			elseif shapeRoll <= 4 then
				-- Pedra achatada (20%)
				local sz = Lerp(MinSize, MaxSize, math.random())
				rock.Size = Vector3.new(sz * (0.9 + math.random() * 0.4), sz * 0.4, sz * (0.9 + math.random() * 0.4))
			else
				-- Pedra irregular (60%)
				rock.Size = RandomRockSize(MinSize, MaxSize)
			end

			-- Posição inicial levemente variada ao redor do centro
			local spawnOffset = Vector3.new(
				(math.random() - 0.5) * 2,
				0.5 + math.random() * 1,
				(math.random() - 0.5) * 2
			)
			rock.CFrame = CFrame.new(groundPos + spawnOffset) * RandomRotation()

			-- Cor com leve variação pra cada pedra
			local h, s, v = surfaceColor:ToHSV()
			local colorVar = (math.random() - 0.5) * 0.08
			rock.Color = Color3.fromHSV(
				math.clamp(h + colorVar * 0.5, 0, 1),
				math.clamp(s + colorVar, 0, 1),
				math.clamp(v + colorVar, 0, 1)
			)
			rock.Material = surfaceMaterial
			rock.Transparency = surfaceTransparency

			if not PlayerCollision then
				rock.CollisionGroup = "RockDebris"
			end

			-- Velocidade escala com MaxSize (impactos maiores = debris voam mais longe)
			-- MaxSize serve como proxy da "força do impacto"
			local powerScale = math.clamp(MaxSize / 1.5, 0.6, 2.0) -- capped at 2x instead of 3x

			local angle = math.random() * math.pi * 2
			local horizSpeed = Lerp(CONFIG.explosion_velocity_min, CONFIG.explosion_velocity_max, math.random()) * powerScale
			local upSpeed = Lerp(CONFIG.explosion_upward_min, CONFIG.explosion_upward_max, math.random()) * powerScale

			-- Pedras menores voam mais longe e mais alto
			local sizeFactor = rock.Size.Magnitude / (MaxSize * 1.7)
			local inverseSizeMult = 1 + (1 - math.clamp(sizeFactor, 0, 1)) * 0.6
			horizSpeed *= inverseSizeMult
			upSpeed *= inverseSizeMult

			local velocity = Vector3.new(
				math.cos(angle) * horizSpeed,
				upSpeed,
				math.sin(angle) * horizSpeed
			)

			local bodyVel = Instance.new("BodyVelocity")
			bodyVel.Velocity = velocity
			bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bodyVel.P = 5000
			bodyVel.Parent = rock
			-- Impulso dura mais em impactos fortes
			Debris:AddItem(bodyVel, 0.15 + powerScale * 0.05)

			-- Rotação durante o voo (mais violenta com mais força)
			local spinMult = CONFIG.explosion_spin_speed * powerScale
			local angVel = Instance.new("BodyAngularVelocity")
			angVel.AngularVelocity = Vector3.new(
				(math.random() - 0.5) * spinMult * 2,
				(math.random() - 0.5) * spinMult * 2,
				(math.random() - 0.5) * spinMult * 2
			)
			angVel.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			angVel.P = 1000
			angVel.Parent = rock
			Debris:AddItem(angVel, 0.2 + powerScale * 0.1)

			Debris:AddItem(rock, CONFIG.explosion_lifetime + 1)

			-- Fade out gradual
			task.wait(CONFIG.explosion_lifetime - CONFIG.explosion_fade_time)
			if rock and rock.Parent then
				TweenService:Create(rock, TweenInfo.new(
					CONFIG.explosion_fade_time,
					Enum.EasingStyle.Linear
					), {
						Size = Vector3.new(0.1, 0.1, 0.1),
						Transparency = 1,
					}):Play()
			end
		end)
	end
end

-- ============================================
-- CRATER ROWS (múltiplos anéis)
-- ============================================

function RockModule.CraterRows(Center: CFrame, Radius: number, Rows: number, NextRowRadius: number, MinRocks: number, MaxRocks: number, PlayerCollision: boolean)
	if PlayerCollision == nil then PlayerCollision = true end
	Radius = Radius or 7
	MinRocks = MinRocks or 7
	MaxRocks = MaxRocks or 10
	Rows = Rows or 3
	NextRowRadius = NextRowRadius or 4

	local currentRadius = Radius
	for i = 1, Rows do
		-- Delay entre cada anel (onda de expansão)
		task.delay((i - 1) * 0.12, function()
			RockModule.Crater(Center, currentRadius, MinRocks * i, MaxRocks * i, PlayerCollision)
		end)
		currentRadius += NextRowRadius
	end
end

-- ============================================
-- CLEAR DEBRIS
-- ============================================

function RockModule.ClearDebris(Fade: boolean)
	CheckDebrisFolder()

	if Fade then
		for _, v in DebrisFolder:GetChildren() do
			if v:IsA("BasePart") then
				task.spawn(function()
					-- Delay aleatório para não sumir tudo de uma vez
					task.wait(math.random() * 0.3)
					TweenService:Create(v, TweenInfo.new(0.75, Enum.EasingStyle.Linear), {
						Size = Vector3.new(0.1, 0.1, 0.1),
						Transparency = 1,
					}):Play()
					Debris:AddItem(v, 1)
				end)
			end
		end
	else
		DebrisFolder:ClearAllChildren()
	end
end

return RockModule