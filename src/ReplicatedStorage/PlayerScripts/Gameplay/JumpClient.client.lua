local Players: Players = game:GetService("Players")
local RunService: RunService = game:GetService("RunService")
local UserInputService: UserInputService = game:GetService("UserInputService")
local TweenService: TweenService = game:GetService("TweenService")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris: Debris = game:GetService("Debris")
local MarketplaceService: MarketplaceService = game:GetService("MarketplaceService")

local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local RockModule = require(ReplicatedStorage.Modules.Game:WaitForChild("RockModule"))
local CameraShaker = require(ReplicatedStorage.Modules.Libraries.CameraShaker)
local PopupModule = require(ReplicatedStorage.Modules.Libraries.PopupModule)
local WorldConfig = require(ReplicatedStorage.Modules.Datas.WorldConfig)
local NotificationUtility = require(ReplicatedStorage.Modules.Utility.NotificationUtility)
local SkillsData = require(ReplicatedStorage.Modules.Datas.PetsSkillsData)

local TutorialEvent = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):FindFirstChild("TutorialEvent")

local CONFIG = {
	RENDER_STEP = "PogoLogic",
	DEFAULT_GRAVITY = 196.2,
	ANIM_ID = "rbxassetid://105821789218134",

	PASS_AUTO = 1699595369,
	PASS_EASY = 1701310636,

	AUTOJUMP_CRITICAL = true,
	POWER_SCALE = 0.6,

	SMOOTH_DIST = 25,
	SMOOTH_BAR = 45,
	SMOOTH_PERFECT = 20,
	SMOOTH_VIGNETTE = 10,
	SMOOTH_FOV = 12,

	RAY_LEN = 500,
	RAY_LAND_THRESH = 3.0,
	RAY_VEL_THRESH = 8,
	RAY_FRAMES = 2,
	RAY_OFFSET = 1.2,

	jump_lock_time = 0.12,

	base_jump_power = 120,
	combo_bonus_power = 8,
	max_combo_power_cap = 250,
	gravity_mult = 1.4,
	miss_penalty_duration = 2,
	stun_duration = 1.5,
	stun_walkspeed = 6,
	stun_force_multiplier = 6.0,
	perfect_zone_percent = 0.3,
	forward_base_mult = 0.35,
	forward_combo_mult = 0.04,
	forward_max_speed = 60,
	forward_perfect_bonus = 1.3,

	air_mobility = 60,
	air_max_speed = 70,

	fov_base = 70,
	fov_max = 110,
	visual_max_height = 100,

	crater_enabled = true,
	crater_force_scale = 0.25,
	crater_min_impact = 40,
	crater_radius_min = 4.0,
	crater_radius_max = 7.5,
	crater_depth_min = 0.8,
	crater_depth_max = 1.5,
	critical_vfx_mult = 1.4,
	crater_min_voxel = 3,
	crater_reset_time = 3,
	crater_fly_percent = 0.4,
	crater_fly_cap = 8,
	crater_debris_time = 4,
	crater_vanish_delay = 0.06,
	crater_velocity = 35,
	crater_up_boost = 45,

	holding_threshold = 1.5,

	block_cooldown = 5,
	block_sticky_frames = 5,
	block_detect_range = 15,

	max_jump_velocity = 1000,

	low_power_fall_assist_threshold = 300,
	low_power_fall_assist_min_speed = 42,
	low_power_fall_assist_max_speed = 88,
	low_power_fall_assist_smooth = 16,
}

local function CreateVisualBar(hud: Instance)
	local existing = hud:FindFirstChild("BarContainer")
	if existing then
		existing:Destroy()
	end

	local container = Instance.new("Frame")
	container.Name = "BarContainer"
	container.Size = UDim2.new(0.4, 0, 0.04, 0)
	container.Position = UDim2.new(0.5, 0, 0.72, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.ZIndex = -50
	container.Parent = hud

	local scale = Instance.new("UIScale")
	scale.Parent = container

	local prompt = Instance.new("TextLabel")
	prompt.Name = "PromptLabel"
	prompt.Size = UDim2.new(1, 0, 1, 0)
	prompt.Position = UDim2.new(0.5, 0, -1.2, 0)
	prompt.AnchorPoint = Vector2.new(0.5, 1)
	prompt.BackgroundTransparency = 1
	prompt.Font = Enum.Font.GothamBlack
	prompt.Text = ""
	prompt.TextColor3 = Color3.fromRGB(255, 255, 255)
	prompt.TextSize = 20
	prompt.ZIndex = -50
	prompt.Parent = container

	local promptStroke = Instance.new("UIStroke")
	promptStroke.Thickness = 1.5
	promptStroke.Transparency = 0.55
	promptStroke.Parent = prompt

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 1, 0)
	track.BackgroundColor3 = Color3.fromRGB(30, 20, 16)
	track.BackgroundTransparency = 0.08
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.ZIndex = -50
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = Color3.fromRGB(85, 55, 35)
	trackStroke.Thickness = 1.5
	trackStroke.Transparency = 0.3
	trackStroke.Parent = track

	local pZone = Instance.new("Frame")
	pZone.Name = "PerfectZone"
	pZone.AnchorPoint = Vector2.new(1, 0.5)
	pZone.Position = UDim2.new(1, 0, 0.5, 0)
	pZone.Size = UDim2.new(CONFIG.perfect_zone_percent, 0, 1, 0)
	pZone.BackgroundColor3 = Color3.fromRGB(255, 190, 40)
	pZone.BackgroundTransparency = 0.5
	pZone.BorderSizePixel = 0
	pZone.Visible = false
	pZone.ZIndex = -49
	pZone.Parent = track

	local zoneCorner = Instance.new("UICorner")
	zoneCorner.CornerRadius = UDim.new(1, 0)
	zoneCorner.Parent = pZone

	local indicator = Instance.new("Frame")
	indicator.Name = "IndicatorLine"
	indicator.Size = UDim2.new(0.005, 0, 2, 0)
	indicator.Position = UDim2.new(0, 0, 0.5, 0)
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.BackgroundColor3 = Color3.fromRGB(255, 50, 20)
	indicator.BorderSizePixel = 0
	indicator.ZIndex = -48
	indicator.Parent = container

	local indCorner = Instance.new("UICorner")
	indCorner.CornerRadius = UDim.new(1, 0)
	indCorner.Parent = indicator

	local indStroke = Instance.new("UIStroke")
	indStroke.Color = Color3.fromRGB(20, 10, 5)
	indStroke.Thickness = 1
	indStroke.Transparency = 0.25
	indStroke.Parent = indicator

	return container, track, pZone, indicator, prompt, scale
end

local player: Player = Players.LocalPlayer
local camera: Camera = workspace.CurrentCamera or workspace:WaitForChild("Camera")
local pogoEvent: RemoteEvent = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("PogoEvent")

local playerGui: PlayerGui = player:WaitForChild("PlayerGui")
local uiRoot: ScreenGui | Folder = playerGui:WaitForChild("UI")
local hud: ScreenGui | Frame = uiRoot:WaitForChild("GameHUD")
local bottomBar: Frame = hud:WaitForChild("BottomBarFR")
local jumpButton: GuiButton = bottomBar:WaitForChild("JumpBT")
local autoJumpButton: GuiButton = bottomBar:WaitForChild("AutoJumpBT")

local vignette: ImageLabel = hud:WaitForChild("Vignette")
local whiteVignette: ImageLabel = hud:WaitForChild("WhiteVignette")

local barContainer, trackFrame, perfectZone, indicatorLine, promptLabel, containerScale = CreateVisualBar(hud)

local character: Model = player.Character or player.CharacterAdded:Wait()
local rootPart: BasePart = character:WaitForChild("HumanoidRootPart")
local humanoid: Humanoid = character:WaitForChild("Humanoid")

local humanoidStateConn: RBXScriptConnection? = nil
local jumpRequestConn: RBXScriptConnection? = nil
local camShake: any = nil

local last_falling_velocity: number = 0
local last_ground_distance: number = 0
local smooth_ground_distance: number = 0
local last_ground_hit_pos: Vector3? = nil
local last_ground_hit_normal: Vector3? = nil

local is_jump_held: boolean = false
local hold_start_time: number = 0
local is_sustained_hold: boolean = false

local auto_jump_active: boolean = false
local has_auto_jump_pass: boolean = false
local owns_auto_jump_pass: boolean = false
local gravityApplied: boolean = false

local jumpAnimation: Animation? = nil
local jumpTrack: AnimationTrack? = nil
local animToken: number = 0
local animHeartbeatConn: RBXScriptConnection? = nil

local auto_jump_start_time: number = os.clock()
local is_afk_mode: boolean = false
local raycastParams: RaycastParams = RaycastParams.new()

local debug_last_jump_start: number = os.clock()

local activeJumpVelocity: number? = nil
local jumpEnforceUntil: number = 0

local jumpLock: boolean = false

local block_zone_frames: number = 0
local block_cooldown_end: number = 0

local last_second_chance = 0
local temp_auto_jump_end = 0
local super_jump_ready = false

local skill_cooldowns_end = {}

local state = {
	is_grounded = true,
	current_combo = 0,
	distance_to_ground = 0,
	raw_ground_distance = 0,
	can_rebound = false,
	queued_jump = false,
	visual_bar_pct = 0,
	visual_perfect_size = 0,
	visual_white_vignette = 1,
	current_jump_peak = 50,
	last_jump_time = 0,
	jump_grace_time = 0,
	cooldown_end_time = 0,
	is_stunned = false,
	original_walkspeed = 16,
	visual_fov = camera.FieldOfView,
	is_falling = false,
	was_airborne = false,
	landed_frames = 0,
	on_block_zone = false,
}

local PROBE_OFFSETS = {
	Vector3.new(1, 0, 0),
	Vector3.new(-1, 0, 0),
	Vector3.new(0, 0, 1),
	Vector3.new(0, 0, -1),
	Vector3.new(0.707, 0, 0.707),
	Vector3.new(-0.707, 0, 0.707),
	Vector3.new(0.707, 0, -0.707),
	Vector3.new(-0.707, 0, -0.707),
}

local function useActiveAbility()
	local activeType = player:GetAttribute("EquippedSkill")
	if not activeType or activeType == "" then return end
	
	local skillInfo = SkillsData.GetSkillData(activeType)
	if not skillInfo or skillInfo.Type ~= "Active" then return end
	
	local activeCD = skillInfo.Cooldown or 10
	local now = os.clock()
	local cdEnd = skill_cooldowns_end[activeType] or 0
	
	if now < cdEnd then
		NotificationUtility:Warning("Skill on cooldown!", 2)
		return
	end
	
	skill_cooldowns_end[activeType] = now + activeCD
	player:SetAttribute("SkillCooldownEnd", now + activeCD)
	
	if activeType == "Dash" then
		if state.is_grounded then return end
		local dashForce = skillInfo.Value or 250
		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude < 0.1 then moveDir = rootPart.CFrame.LookVector end
		
		local currentY = rootPart.AssemblyLinearVelocity.Y
		local dashY = math.max(currentY, 40)
		
		rootPart.AssemblyLinearVelocity = Vector3.new(moveDir.X * dashForce, dashY, moveDir.Z * dashForce)
		PopupModule.Create(rootPart, "DASH!", Color3.fromRGB(100, 200, 255), { IsCritical = true, Direction = Vector3.new(0,3,0) })
		
	elseif activeType == "DoubleJump" then
		if state.is_grounded then return end
		local petJumpBoost = player:GetAttribute("PetJumpBoost") or 0
		local finalPower = (CONFIG.base_jump_power + petJumpBoost) * CONFIG.POWER_SCALE * 1.5
		local jumpVel = finalPower / math.sqrt(CONFIG.gravity_mult)
		
		if jumpVel < 150 then jumpVel = 150 end
		
		rootPart.AssemblyLinearVelocity = Vector3.new(rootPart.AssemblyLinearVelocity.X, jumpVel, rootPart.AssemblyLinearVelocity.Z)
		PopupModule.Create(rootPart, "DOUBLE JUMP!", Color3.fromRGB(150, 150, 255), { IsCritical = true, Direction = Vector3.new(0,3,0) })
		
	elseif activeType == "TempAutoJump" then
		local duration = skillInfo.Value or 8
		temp_auto_jump_end = now + duration
		PopupModule.Create(rootPart, "FRENZY!", Color3.fromRGB(255, 50, 50), { IsCritical = true, Direction = Vector3.new(0,3,0) })
		
	elseif activeType == "SuperJump" then
		super_jump_ready = true
		PopupModule.Create(rootPart, "SUPER JUMP READY!", Color3.fromRGB(255, 200, 50), { IsCritical = true, Direction = Vector3.new(0,3,0) })
	end
end

local function is_block_part(hitPart: Instance?): boolean
	if not hitPart then
		return false
	end

	local check: Instance? = hitPart
	while check and check ~= workspace do
		if check:GetAttribute("Block") then
			return true
		end
		check = check.Parent
	end

	return false
end

local function is_block_locked(): boolean
	return os.clock() < block_cooldown_end
end

local function get_layer_by_height(char: Model): any
	if not char then
		return nil
	end

	local rp = char:FindFirstChild("HumanoidRootPart")
	if not rp then
		return nil
	end

	local currentY = rp.Position.Y
	local worldId = DataUtility.client.get("CurrentWorld") or 1
	local worldData = WorldConfig.GetWorld(worldId)

	if worldData and worldData.layers then
		for _, layer in worldData.layers do
			if currentY <= layer.maxHeight and currentY > layer.minHeight then
				return layer
			end
		end
		return worldData.layers[1]
	end

	return nil
end

local function popup_combo_number(combo: number, comboColor: Color3, isHighCombo: boolean): ()
	PopupModule.Create(rootPart, "x" .. combo, comboColor, {
		Direction = Vector3.new(math.random(-2, 2), 2, 0),
		Spread = 1,
		IsCritical = isHighCombo,
	})
end

local function popup_combo_fire(comboColor: Color3, isHighCombo: boolean): ()
	PopupModule.Create(rootPart, "🔥", comboColor, {
		Direction = Vector3.new(math.random(-2, 2), 3, 0),
		Spread = 1,
		IsCritical = isHighCombo,
	})
end

local function apply_rebirth_upgrades(): ()
	local ownedUpgrades = DataUtility.client.get("OwnedRebirthUpgrades") or {}

	local hasGamepass = false
	pcall(function()
		hasGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.PASS_EASY)
	end)

	if table.find(ownedUpgrades, "SoftLanding") or hasGamepass then
		CONFIG.perfect_zone_percent = 0.5
	else
		CONFIG.perfect_zone_percent = 0.3
	end

	if humanoid and humanoid.Parent then
		if table.find(ownedUpgrades, "SpeedBoots") then
			state.original_walkspeed = 24
		else
			state.original_walkspeed = 16
		end

		if not state.is_stunned then
			humanoid.WalkSpeed = state.original_walkspeed
		end
	end
end

local function exp_lerp(a: number, b: number, speed: number, dt: number): number
	local alpha = 1 - math.exp(-speed * dt)
	return a + (b - a) * alpha
end

local function apply_gravity(): ()
	local targetGravity = CONFIG.DEFAULT_GRAVITY * CONFIG.gravity_mult
	if math.abs(workspace.Gravity - targetGravity) > 0.1 then
		workspace.Gravity = targetGravity
		gravityApplied = true
	end
end

local function update_local_settings(newSettings: any): ()
	if not newSettings then
		return
	end

	for key, value in newSettings do
		CONFIG[key] = value
	end

	apply_gravity()
end

local function setup_camera_shaker(): ()
	if camShake then
		camShake:Stop()
	end

	camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame: CFrame)
		camera.CFrame = camera.CFrame * shakeCFrame
	end)

	camShake:Start()
end

local function update_raycast_filter(): ()
	local filter = { character }
	local debrisFolder = workspace:FindFirstChild("Debris")
	if debrisFolder then
		table.insert(filter, debrisFolder)
	end

	raycastParams.FilterDescendantsInstances = filter
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
end

local function single_ray(origin: Vector3, direction: Vector3): (number, RaycastResult?)
	local hit = workspace:Raycast(origin, direction, raycastParams)
	if hit then
		return hit.Distance, hit
	end
	return math.huge, nil
end

local function raycast_ground(): number
	if not rootPart or not rootPart.Parent or not humanoid or not humanoid.Parent then
		return last_ground_distance
	end

	update_raycast_filter()

	local rootPos = rootPart.Position
	local rootHalf = rootPart.Size.Y * 0.5
	local hipOffset = humanoid.HipHeight + rootHalf
	local downDir = Vector3.new(0, -CONFIG.RAY_LEN, 0)

	local centerDist, centerHit = single_ray(rootPos, downDir)
	local bestDist = centerDist
	local bestHit = centerHit

	local anyBlockDetected = false
	if centerHit and (centerDist - hipOffset) < CONFIG.block_detect_range then
		if is_block_part(centerHit.Instance) then
			anyBlockDetected = true
		end
	end

	for _, offset in PROBE_OFFSETS do
		local probeOrigin = rootPos + offset * CONFIG.RAY_OFFSET
		local dist, hit = single_ray(probeOrigin, downDir)

		if dist < bestDist then
			bestDist = dist
			bestHit = hit
		end

		if not anyBlockDetected and hit and (dist - hipOffset) < CONFIG.block_detect_range then
			if is_block_part(hit.Instance) then
				anyBlockDetected = true
			end
		end
	end

	if anyBlockDetected then
		block_zone_frames = CONFIG.block_sticky_frames
		state.on_block_zone = true
		block_cooldown_end = os.clock() + CONFIG.block_cooldown
	else
		if block_zone_frames > 0 then
			block_zone_frames -= 1
			state.on_block_zone = true
		else
			state.on_block_zone = false
		end
	end

	if bestHit then
		last_ground_hit_pos = bestHit.Position
		last_ground_hit_normal = bestHit.Normal

		local dist = bestDist - hipOffset
		dist = math.max(dist, 0)
		last_ground_distance = dist
		return dist
	end

	last_ground_distance = CONFIG.RAY_LEN
	return CONFIG.RAY_LEN
end

local function calculate_peak_height(velocity: number): number
	local g = workspace.Gravity
	if g <= 0 then
		g = CONFIG.DEFAULT_GRAVITY
	end
	return (velocity ^ 2) / (2 * g)
end

local function get_low_power_fall_limit(): number
	local currentBasePower = CONFIG.base_jump_power or 0

	if currentBasePower <= 0 then
		return math.huge
	end

	if currentBasePower >= CONFIG.low_power_fall_assist_threshold then
		return math.huge
	end

	local alpha = math.clamp(currentBasePower / CONFIG.low_power_fall_assist_threshold, 0, 1)

	return CONFIG.low_power_fall_assist_min_speed
		+ ((CONFIG.low_power_fall_assist_max_speed - CONFIG.low_power_fall_assist_min_speed) * alpha)
end

local function apply_low_power_fall_assist(dt: number): ()
	if state.is_grounded then
		return
	end

	if not rootPart or not rootPart.Parent then
		return
	end

	local currentVel = rootPart.AssemblyLinearVelocity
	if currentVel.Y >= 0 then
		return
	end

	local fallLimit = get_low_power_fall_limit()
	if fallLimit == math.huge then
		return
	end

	if currentVel.Y >= -fallLimit then
		return
	end

	local targetVelY = -fallLimit
	local newVelY = exp_lerp(currentVel.Y, targetVelY, CONFIG.low_power_fall_assist_smooth, dt)

	rootPart.AssemblyLinearVelocity = Vector3.new(
		currentVel.X,
		newVelY,
		currentVel.Z
	)
end

local function stop_jump_anim(): ()
	animToken += 1

	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end

	if jumpTrack then
		jumpTrack:Stop(0.1)
	end
end

local function play_jump_anim_forward(): ()
	if not jumpTrack then
		return
	end

	animToken += 1
	local token = animToken

	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end

	if not jumpTrack.IsPlaying then
		jumpTrack:Play(0.1)
	end

	jumpTrack:AdjustSpeed(1)
	jumpTrack.TimePosition = math.max(jumpTrack.TimePosition, 0)

	animHeartbeatConn = RunService.Heartbeat:Connect(function()
		if not jumpTrack or token ~= animToken then
			return
		end

		local len = jumpTrack.Length
		if len and len > 0 then
			if jumpTrack.TimePosition >= (len - 0.03) then
				jumpTrack.TimePosition = math.max(len - 0.001, 0)
				jumpTrack:AdjustSpeed(0)
			end
		end
	end)
end

local function play_jump_anim_reverse(): ()
	if not jumpTrack then
		return
	end

	animToken += 1
	local token = animToken

	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end

	if not jumpTrack.IsPlaying then
		jumpTrack:Play(0.1)
	end

	local len = jumpTrack.Length
	if len and len > 0 then
		if jumpTrack.TimePosition <= 0.02 then
			jumpTrack.TimePosition = math.max(len - 0.001, 0)
		end
	end

	jumpTrack:AdjustSpeed(-1)

	animHeartbeatConn = RunService.Heartbeat:Connect(function()
		if not jumpTrack or token ~= animToken then
			return
		end

		if jumpTrack.TimePosition <= 0.02 then
			jumpTrack.TimePosition = 0
			jumpTrack:AdjustSpeed(0)
		end
	end)
end

local function trigger_landing_vfx(impactForce: number, isCritical: boolean): ()
	if not CONFIG.crater_enabled then
		return
	end

	if is_afk_mode then
		return
	end

	if not last_ground_hit_pos or not last_ground_hit_normal then
		return
	end

	local layerData = get_layer_by_height(character)
	if not layerData then
		return
	end

	local resistance = layerData.minBreakForce or 40
	local rawForce = math.abs(impactForce)
	if rawForce < resistance then
		return
	end

	local effectiveForce = math.max(0, rawForce - resistance)
	local tBase = math.clamp(effectiveForce / 200, 0, 1)

	local tExtended = 0
	if effectiveForce > 200 then
		tExtended = math.log(1 + (effectiveForce - 200) / 150)
	end

	local tTotal = tBase + tExtended
	local tCurve = tBase ^ 0.65

	local critMult = 1.0
	if isCritical then
		critMult = CONFIG.critical_vfx_mult + (tTotal * 0.2)
	end

	local radius = CONFIG.crater_radius_min
		+ (CONFIG.crater_radius_max - CONFIG.crater_radius_min) * tCurve
		+ (tExtended * 3.0)

	radius *= critMult

	local centerCFrame = CFrame.new(last_ground_hit_pos + Vector3.new(0, 1.5, 0))

	local minRocks = 4 + math.floor(4 * tCurve) + math.floor(tExtended * 2)
	local maxRocks = 6 + math.floor(6 * tCurve) + math.floor(tExtended * 3)

	if isCritical then
		minRocks = math.floor(minRocks * 1.4)
		maxRocks = math.floor(maxRocks * 1.4)
	end

	minRocks = math.min(minRocks, 18)
	maxRocks = math.min(maxRocks, 25)

	RockModule.Crater(centerCFrame, radius, minRocks, maxRocks, false)

	if tBase > 0.15 or isCritical then
		local debrisBase = 3 + math.floor(4 * tCurve)
		local debrisExtra = math.floor(tExtended * 2)
		local numExplosion = debrisBase + debrisExtra

		if isCritical then
			numExplosion = math.floor(numExplosion * 1.3)
		end

		numExplosion = math.min(numExplosion, 16)

		local szMin = 0.3 + (tCurve * 0.2) + (tExtended * 0.1)
		local szMax = 0.8 + (tCurve * 1.0) + (tExtended * 0.5)

		if isCritical then
			szMin *= 1.2
			szMax *= 1.3
		end

		RockModule.Explosion(centerCFrame, numExplosion, szMin, szMax, false)

		if tTotal > 0.7 or isCritical then
			local secondaryCount = math.floor(numExplosion * 0.3)
			secondaryCount = math.min(secondaryCount, 8)

			local spread = radius * 0.4
			local offsetX = (math.random() - 0.5) * spread * 2
			local offsetZ = (math.random() - 0.5) * spread * 2
			local secondaryCFrame = centerCFrame + Vector3.new(offsetX, 0, offsetZ)

			RockModule.Explosion(secondaryCFrame, secondaryCount, szMin * 0.5, szMax * 0.6, false)
		end
	end

	if tExtended > 1.0 then
		local extraRows = math.min(math.floor(tExtended * 0.5), 2)
		if extraRows > 0 then
			local rowRadius = radius + 3
			local rowRocksMin = math.min(math.floor(minRocks * 0.4), 8)
			local rowRocksMax = math.min(math.floor(maxRocks * 0.4), 12)

			for row = 1, extraRows do
				task.delay(row * 0.08, function()
					local r = rowRadius + (row * 2.5)
					RockModule.Crater(centerCFrame, r, rowRocksMin, rowRocksMax, false)
				end)
			end
		end
	end
end

local function apply_stun(): ()
	if state.is_stunned then
		return
	end

	state.is_stunned = true

	activeJumpVelocity = nil
	jumpEnforceUntil = 0

	if pogoEvent then
		pogoEvent:FireServer("Stunned", {})
	end

	PopupModule.Create(rootPart, "CRASH!", Color3.fromRGB(255, 50, 50), {
		IsCritical = true,
		Direction = Vector3.new(0, 2, 0),
	})

	local attr = player:GetAttribute("Multiplier")
	local multi = (attr and attr > 0 and attr or 1)

	local magnitude = math.clamp(3.5 * multi * CONFIG.stun_force_multiplier, 4.0, 25.0)
	local roughness = math.clamp(2.5 * multi * CONFIG.stun_force_multiplier, 3.0, 12.0)
	local maxDuration = 0.45 * math.clamp(CONFIG.stun_force_multiplier * 0.6, 0.5, 1.2)

	if camShake then
		camShake:ShakeOnce(magnitude, roughness, 0.05, maxDuration)
	end

	humanoid.WalkSpeed = CONFIG.stun_walkspeed

	task.delay(CONFIG.stun_duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = state.original_walkspeed
		end

		state.is_stunned = false

		if pogoEvent then
			pogoEvent:FireServer("Land", { status = "Idle" })
		end
	end)
end

local function lock_text_visuals(): ()
	if promptLabel then
		promptLabel.Visible = true
	end

	vignette.ImageColor3 = Color3.new(0, 0, 0)
	whiteVignette.ImageColor3 = Color3.new(1, 1, 1)
end

local function get_move_direction(): Vector3
	local moveDir = humanoid.MoveDirection
	local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z)

	if flatDir.Magnitude > 0.1 then
		return flatDir.Unit
	end

	local lookVector = rootPart.CFrame.LookVector
	local flatLook = Vector3.new(lookVector.X, 0, lookVector.Z)

	if flatLook.Magnitude > 0.1 then
		return flatLook.Unit
	end

	return Vector3.new(0, 0, -1)
end

local function apply_forward_momentum(finalPower: number, isPerfect: boolean): ()
	if not rootPart or not rootPart.Parent then
		return
	end

	local moveDir = get_move_direction()

	local forwardSpeed = finalPower * CONFIG.forward_base_mult
	local comboBonus = state.current_combo * CONFIG.forward_combo_mult * finalPower
	forwardSpeed += comboBonus

	if isPerfect then
		forwardSpeed *= CONFIG.forward_perfect_bonus
	end

	forwardSpeed = math.min(forwardSpeed, CONFIG.forward_max_speed)

	local humanoidMoveDir = humanoid.MoveDirection
	local isMoving = Vector3.new(humanoidMoveDir.X, 0, humanoidMoveDir.Z).Magnitude > 0.1

	if not isMoving then
		forwardSpeed *= 0.15
	end

	local horizontalBoost = moveDir * forwardSpeed

	local currentVel = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(
		horizontalBoost.X,
		currentVel.Y,
		horizontalBoost.Z
	)
end

local function perform_jump(isPerfectRebound: boolean, isChained: boolean): ()
	if not rootPart or not rootPart.Parent or not humanoid or not humanoid.Parent then
		return
	end

	if state.is_stunned then
		return
	end

	if is_block_locked() then
		return
	end

	local now = os.clock()
	if jumpLock then
		return
	end

	if (now - state.last_jump_time) < CONFIG.jump_lock_time then
		return
	end

	jumpLock = true
	state.is_grounded = false
	state.can_rebound = false
	state.queued_jump = false

	if not isPerfectRebound then
		local currentJumps = player:GetAttribute("Jumps") or 0
		player:SetAttribute("Jumps", currentJumps + 1)
	end

	state.last_jump_time = now
	debug_last_jump_start = state.last_jump_time
	state.jump_grace_time = now + 0.25
	state.is_falling = false
	state.was_airborne = false
	state.landed_frames = 0

	play_jump_anim_forward()

	local petJumpBoost = player:GetAttribute("PetJumpBoost") or 0
	local scaledBasePower = (CONFIG.base_jump_power + petJumpBoost) * CONFIG.POWER_SCALE
	local comboBonus = math.min(state.current_combo * CONFIG.combo_bonus_power, CONFIG.max_combo_power_cap)
	local finalPower = 0

	if isPerfectRebound then
		finalPower = (scaledBasePower + comboBonus) * 1.4
	else
		finalPower = scaledBasePower + comboBonus
		if isChained then
			finalPower *= 1.5
		else
			local visualBar = math.clamp(state.visual_bar_pct, 0, 1)
			local timingMultiplier = 1.5 - visualBar
			finalPower *= timingMultiplier
		end
	end

	finalPower = math.min(finalPower, scaledBasePower + CONFIG.max_combo_power_cap)

	if super_jump_ready then
		super_jump_ready = false
		local skillInfo = SkillsData.GetSkillData("SuperJump")
		local superMultiplier = (skillInfo and skillInfo.Value) or 2.5
		finalPower *= superMultiplier
		PopupModule.Create(rootPart, "SUPER JUMP!", Color3.fromRGB(255, 100, 255), { IsCritical = true, Direction = Vector3.new(0, 3, 0) })
	end

	local jumpVelocity = finalPower / math.sqrt(CONFIG.gravity_mult)
	jumpVelocity = math.min(jumpVelocity, CONFIG.max_jump_velocity)

	state.current_jump_peak = math.max(calculate_peak_height(jumpVelocity), 10)

	rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

	RunService.Heartbeat:Wait()

	if not rootPart or not rootPart.Parent then
		jumpLock = false
		return
	end

	rootPart.AssemblyLinearVelocity = Vector3.new(0, jumpVelocity, 0)

	activeJumpVelocity = jumpVelocity
	jumpEnforceUntil = os.clock() + 0.05

	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	task.delay(0.1, function()
		if humanoid and humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
	end)

	apply_forward_momentum(finalPower, isPerfectRebound)

	local soundName = isPerfectRebound and "CritJumpSound" or "NormalJumpSound"
	local soundId = isPerfectRebound and "rbxassetid://119490144266950" or "rbxassetid://131916027000817"
	local volume = isPerfectRebound and 0.8 or 0.5

	local jumpSound = rootPart:FindFirstChild(soundName)
	if not jumpSound then
		jumpSound = Instance.new("Sound")
		jumpSound.Name = soundName
		jumpSound.SoundId = soundId
		jumpSound.Volume = volume
		jumpSound.Parent = rootPart
	end
	jumpSound:Play()

	if isPerfectRebound then
		if TutorialEvent then
			TutorialEvent:Fire("PerfectLanding")
		end

		state.current_combo += 1
		local comboColor = Color3.fromRGB(255, 255, 255)
		local isHighCombo = false

		if state.current_combo >= 5 then
			comboColor = Color3.fromRGB(255, 100, 255)
			isHighCombo = true
		end

		popup_combo_number(state.current_combo, comboColor, isHighCombo)
		popup_combo_fire(comboColor, isHighCombo)

		whiteVignette.ImageColor3 = Color3.new(1, 1, 1)
		state.visual_white_vignette = 0.2

		if pogoEvent then
			pogoEvent:FireServer("Rebound", {
				combo = state.current_combo,
				isCritical = true,
				impactForce = math.abs(last_falling_velocity),
			})
		end

		if TutorialEvent then
			TutorialEvent:Fire("Jump")
		end
	else
		if state.current_combo > 0 then
			PopupModule.Create(rootPart, "x0", Color3.fromRGB(255, 80, 80), {
				Direction = Vector3.new(0, 2, 0),
				Spread = 1,
				IsCritical = false,
			})
		end

		state.current_combo = 0

		if pogoEvent then
			pogoEvent:FireServer("Jump", { impactForce = math.abs(last_falling_velocity) })
		end
	end

	state.can_rebound = false
	state.queued_jump = false
	state.visual_perfect_size = 0
	perfectZone.Visible = false
	indicatorLine.BackgroundColor3 = Color3.fromRGB(255, 50, 20)

	jumpLock = false
end

local function land(): ()
	state.is_falling = false

	activeJumpVelocity = nil
	jumpEnforceUntil = 0

	stop_jump_anim()
	raycast_ground()

	if state.on_block_zone then
		state.is_grounded = true
		state.can_rebound = false
		state.queued_jump = false
		state.current_combo = 0

		if pogoEvent then
			pogoEvent:FireServer("Land", {
				status = "Blocked",
				impactForce = math.abs(last_falling_velocity),
			})
		end

		return
	end

	if is_block_locked() then
		state.is_grounded = true
		state.can_rebound = false
		state.queued_jump = false
		state.current_combo = 0

		if pogoEvent then
			pogoEvent:FireServer("Land", {
				status = "Blocked",
				impactForce = math.abs(last_falling_velocity),
			})
		end

		return
	end

	local isAutoJumpReady = auto_jump_active and has_auto_jump_pass
	local isCriticalAutoJump = isAutoJumpReady and CONFIG.AUTOJUMP_CRITICAL

	if (state.queued_jump or isCriticalAutoJump) and not state.is_stunned then
		perform_jump(true, true)
		trigger_landing_vfx(math.abs(last_falling_velocity), true)
		return
	elseif (is_jump_held or isAutoJumpReady) and not state.is_stunned then
		perform_jump(false, true)
		trigger_landing_vfx(math.abs(last_falling_velocity), false)
		return
	end

	if state.is_grounded then
		return
	end

	local secondChanceCD = player:GetAttribute("SecondChanceCD") or 0
	if secondChanceCD > 0 and (os.clock() - last_second_chance) >= secondChanceCD then
		last_second_chance = os.clock()
		player:SetAttribute("SkillCooldownEnd", os.clock() + secondChanceCD)
		PopupModule.Create(rootPart, "LIFESAVER!", Color3.fromRGB(100, 255, 100), { IsCritical = true, Direction = Vector3.new(0, 2, 0) })
		
		perform_jump(true, true) 
		trigger_landing_vfx(math.abs(last_falling_velocity), true)
		return
	end

	trigger_landing_vfx(math.abs(last_falling_velocity), false)

	local landingForce = math.abs(last_falling_velocity)

	if state.current_combo >= 1 then
		apply_stun()

		if pogoEvent then
			pogoEvent:FireServer("Land", {
				status = "Stunned",
				impactForce = landingForce,
			})
		end
	else
		if pogoEvent then
			pogoEvent:FireServer("Land", {
				status = "Cooldown",
				impactForce = landingForce,
			})
		end
	end

	state.is_grounded = true
	state.can_rebound = false
	state.current_combo = 0
	state.cooldown_end_time = os.clock() + CONFIG.miss_penalty_duration
end

local function handle_input(): ()
	local now = os.clock()

	if state.is_stunned then
		return
	end

	if is_block_locked() then
		return
	end

	if state.is_grounded then
		if now < state.cooldown_end_time then
			return
		end

		perform_jump(false, false)
		return
	end

	if state.can_rebound then
		state.queued_jump = true
		indicatorLine.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
	end
end

local function on_jump_pressed(): ()
	if is_jump_held then
		return
	end

	is_jump_held = true
	handle_input()
end

local function on_jump_released(): ()
	is_jump_held = false
end

local function bind_character(newCharacter: Model): ()
	character = newCharacter
	rootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")

	humanoid.UseJumpPower = true
	humanoid.JumpPower = 1
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)

	if jumpRequestConn then
		jumpRequestConn:Disconnect()
		jumpRequestConn = nil
	end

	jumpRequestConn = humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
		if humanoid.Jump then
			humanoid.Jump = false
			on_jump_pressed()

			task.delay(0.15, function()
				if not UserInputService:IsKeyDown(Enum.KeyCode.Space)
					and not UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) then
					on_jump_released()
				end
			end)
		end
	end)

	update_raycast_filter()
	apply_rebirth_upgrades()

	state.is_grounded = true
	state.current_combo = 0
	state.distance_to_ground = 0
	state.raw_ground_distance = 0
	state.can_rebound = false
	state.queued_jump = false
	state.visual_bar_pct = 0
	state.visual_perfect_size = 0
	state.visual_white_vignette = 1
	state.last_jump_time = 0
	state.jump_grace_time = 0
	state.cooldown_end_time = 0
	state.is_stunned = false
	state.current_jump_peak = CONFIG.visual_max_height
	state.is_falling = false
	state.was_airborne = false
	state.landed_frames = 0
	state.on_block_zone = false

	last_falling_velocity = 0
	last_ground_distance = 0
	smooth_ground_distance = 0
	last_ground_hit_pos = nil
	last_ground_hit_normal = nil

	activeJumpVelocity = nil
	jumpEnforceUntil = 0
	jumpLock = false

	hold_start_time = 0
	is_sustained_hold = false
	block_zone_frames = 0
	block_cooldown_end = 0

	barContainer, trackFrame, perfectZone, indicatorLine, promptLabel, containerScale = CreateVisualBar(hud)

	lock_text_visuals()
	setup_camera_shaker()

	gravityApplied = false
	apply_gravity()

	animToken += 1

	if animHeartbeatConn then
		animHeartbeatConn:Disconnect()
		animHeartbeatConn = nil
	end

	if jumpTrack then
		jumpTrack:Stop(0)
		jumpTrack = nil
	end

	jumpAnimation = Instance.new("Animation")
	jumpAnimation.AnimationId = CONFIG.ANIM_ID
	jumpTrack = humanoid:LoadAnimation(jumpAnimation)
	jumpTrack.Looped = false
	jumpTrack.Priority = Enum.AnimationPriority.Action

	if humanoidStateConn then
		humanoidStateConn:Disconnect()
		humanoidStateConn = nil
	end

	humanoidStateConn = humanoid.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Landed then
			land()
		elseif newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
			state.is_grounded = false
			state.landed_frames = 0
		end
	end)
end

local function check_grounded(dt: number): boolean
	local rawDist = state.raw_ground_distance
	local velY = rootPart.AssemblyLinearVelocity.Y
	local absVelY = math.abs(velY)

	local nearGround = rawDist < CONFIG.RAY_LAND_THRESH
	local lowVerticalVel = absVelY < CONFIG.RAY_VEL_THRESH

	if nearGround and lowVerticalVel then
		state.landed_frames += 1
	else
		state.landed_frames = 0
	end

	return state.landed_frames >= CONFIG.RAY_FRAMES
end

local function update_loop(dt: number): ()
	if not rootPart or not rootPart.Parent or not humanoid or not humanoid.Parent then
		return
	end

	local now = os.clock()

	if temp_auto_jump_end > now then
		auto_jump_active = true
		has_auto_jump_pass = true
	else
		if not owns_auto_jump_pass and has_auto_jump_pass then
			auto_jump_active = false
			has_auto_jump_pass = false
		end
	end

	if activeJumpVelocity and now < jumpEnforceUntil then
		local currentVel = rootPart.AssemblyLinearVelocity
		if currentVel.Y > 0 and currentVel.Y < (activeJumpVelocity * 0.85) then
			rootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, activeJumpVelocity, currentVel.Z)
		end
	elseif activeJumpVelocity and now >= jumpEnforceUntil then
		activeJumpVelocity = nil
	end

	if is_jump_held then
		if hold_start_time == 0 then
			hold_start_time = now
		end
		is_sustained_hold = (now - hold_start_time) >= CONFIG.holding_threshold
	else
		hold_start_time = 0
		is_sustained_hold = false
	end

	if auto_jump_active then
		if (now - auto_jump_start_time) > 300 then
			if not is_afk_mode then
				is_afk_mode = true
				NotificationUtility:Warning("You seem AFK. Destruction VFX disabled for performance.", 5)
			end
		end
	else
		auto_jump_start_time = now
		if is_afk_mode then
			is_afk_mode = false
			NotificationUtility:Success("Welcome back! VFX Enabled.", 4)
		end
	end

	local velocity = rootPart.AssemblyLinearVelocity
	local speedTotal = velocity.Magnitude

	if speedTotal > CONFIG.max_jump_velocity * 1.5 then
		local clamped = velocity.Unit * CONFIG.max_jump_velocity * 1.5
		rootPart.AssemblyLinearVelocity = clamped
		velocity = clamped
		speedTotal = clamped.Magnitude
	end

	local rawDist = raycast_ground()
	state.raw_ground_distance = rawDist

	smooth_ground_distance = exp_lerp(smooth_ground_distance, rawDist, CONFIG.SMOOTH_DIST, dt)
	state.distance_to_ground = smooth_ground_distance

	if not state.is_grounded then
		state.was_airborne = true

		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude > 0.1 then
			local flatVel = Vector3.new(velocity.X, 0, velocity.Z)
			local currentSpeed = flatVel.Magnitude
			local targetSpeed = math.clamp(currentSpeed, 20, CONFIG.air_max_speed)

			local targetVel = moveDir.Unit * targetSpeed
			local lerpFactor = math.min(dt * (CONFIG.air_mobility / 15), 0.3)
			local newFlatVel = flatVel:Lerp(targetVel, lerpFactor)

			rootPart.AssemblyLinearVelocity = Vector3.new(newFlatVel.X, velocity.Y, newFlatVel.Z)
		end

		apply_low_power_fall_assist(dt)
		velocity = rootPart.AssemblyLinearVelocity

		if now > state.jump_grace_time then
			if check_grounded(dt) then
				land()
			end
		end
	else
		state.was_airborne = false
		state.landed_frames = 0
	end

	if state.is_grounded and not jumpLock and not is_block_locked() and (is_jump_held or (auto_jump_active and has_auto_jump_pass)) and not state.is_stunned then
		if now >= state.cooldown_end_time then
			perform_jump(false, true)
		end
	end

	if velocity.Y < 0 then
		last_falling_velocity = velocity.Y
		if not state.is_grounded and not state.is_falling and velocity.Y < -5 then
			state.is_falling = true
			play_jump_anim_reverse()
		end
	else
		if not state.is_grounded then
			state.is_falling = false
		end
	end

	local targetFov = CONFIG.fov_base
	local targetBarPct = 0
	local targetPerfectSize = 0
	local targetScale = 1
	local targetLineColor = Color3.fromRGB(255, 50, 20)
	local targetZoneTransparency = 0.5
	local targetZoneColor = Color3.fromRGB(255, 190, 40)
	local promptText = ""
	local promptColor = Color3.fromRGB(255, 255, 255)

	barContainer.Rotation = exp_lerp(barContainer.Rotation, 0, CONFIG.SMOOTH_BAR, dt)

	local targetVignetteTransparency = 1
	if velocity.Y > 10 then
		local speedFactor = math.clamp((velocity.Y - 10) / 100, 0, 0.6)
		targetVignetteTransparency = 1 - speedFactor
	end
	vignette.ImageTransparency = exp_lerp(vignette.ImageTransparency, targetVignetteTransparency, CONFIG.SMOOTH_VIGNETTE, dt)

	local targetWhiteTransparency = 1
	local targetWhiteColor = Color3.new(1, 1, 1)
	if auto_jump_active then
		targetWhiteTransparency = 0.5
		targetWhiteColor = Color3.fromRGB(50, 255, 100)
	end
	whiteVignette.ImageColor3 = whiteVignette.ImageColor3:Lerp(targetWhiteColor, dt * 5)
	state.visual_white_vignette = exp_lerp(state.visual_white_vignette, targetWhiteTransparency, CONFIG.SMOOTH_VIGNETTE, dt)
	whiteVignette.ImageTransparency = state.visual_white_vignette

	local blockLocked = is_block_locked()

	if state.is_grounded then
		if blockLocked then
			local remaining = math.max(block_cooldown_end - now, 0)
			local secs = math.ceil(remaining)
			promptText = "BLOCKED! " .. secs .. "s"
			promptColor = Color3.fromRGB(180, 80, 60)
			targetScale = 1
			targetBarPct = math.clamp(remaining / CONFIG.block_cooldown, 0, 1)
			targetLineColor = Color3.fromRGB(120, 60, 40)
		elseif now < state.cooldown_end_time or state.is_stunned then
			promptText = "JUMP!"
			promptColor = Color3.fromRGB(255, 180, 80)
			targetScale = 1
			local remaining = state.cooldown_end_time - now
			local duration = state.is_stunned and CONFIG.stun_duration or CONFIG.miss_penalty_duration
			targetBarPct = math.clamp(remaining / duration, 0, 1)
			targetLineColor = Color3.fromRGB(160, 100, 55)
		else
			if is_sustained_hold then
				promptText = "HOLDING"
				promptColor = Color3.fromRGB(255, 180, 50)
				targetLineColor = Color3.fromRGB(255, 160, 30)
			else
				promptText = "JUMP!"
				promptColor = Color3.fromRGB(255, 220, 100)
				targetLineColor = auto_jump_active and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 50, 20)
			end
			targetScale = 1
			targetBarPct = 0
		end
	else
		local safePeak = math.max(state.current_jump_peak, 5)
		targetBarPct = math.clamp(smooth_ground_distance / safePeak, 0, 1)
		targetPerfectSize = CONFIG.perfect_zone_percent

		if velocity.Y > 0 then
			if is_sustained_hold then
				promptText = "HOLDING"
				promptColor = Color3.fromRGB(255, 180, 50)
				targetLineColor = Color3.fromRGB(255, 160, 30)
			else
				promptText = "WAIT..."
				promptColor = Color3.fromRGB(220, 160, 80)
				targetLineColor = auto_jump_active and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 50, 20)
			end
			targetScale = 1
		elseif velocity.Y < -5 then
			local inWindow = targetBarPct <= CONFIG.perfect_zone_percent

			if inWindow then
				state.can_rebound = true
				if is_sustained_hold then
					promptText = "HOLDING"
					promptColor = Color3.fromRGB(255, 230, 100)
				else
					promptText = "TAP NOW!"
					promptColor = Color3.fromRGB(255, 255, 220)
				end

				local pulse = math.sin(now * 22) * 0.5 + 0.5
				targetLineColor = Color3.fromRGB(255, 50, 20):Lerp(Color3.fromRGB(255, 255, 200), pulse * 0.8)
				targetScale = 1.18 + math.sin(now * 22) * 0.06
				targetZoneTransparency = 0.15
				targetZoneColor = Color3.fromRGB(255, 230, 80)
			else
				state.can_rebound = false
				state.queued_jump = false

				if is_sustained_hold then
					promptText = "HOLDING"
					promptColor = Color3.fromRGB(255, 180, 50)
					targetLineColor = Color3.fromRGB(255, 160, 30)
				else
					promptText = "PREPARE..."
					promptColor = Color3.fromRGB(220, 160, 80)
					targetLineColor = auto_jump_active and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 50, 20)
				end

				local tensionFactor = math.clamp(1 - targetBarPct, 0, 1)
				targetScale = 1 + (tensionFactor * 0.15)
			end
		else
			state.can_rebound = false

			if is_sustained_hold then
				promptText = "HOLDING"
				promptColor = Color3.fromRGB(255, 180, 50)
				targetLineColor = Color3.fromRGB(255, 160, 30)
			else
				promptText = "WAIT..."
				promptColor = Color3.fromRGB(200, 160, 100)
				targetLineColor = auto_jump_active and Color3.fromRGB(80, 255, 100) or Color3.fromRGB(255, 50, 20)
			end

			targetScale = 1
		end
	end

	promptLabel.Text = promptText
	promptLabel.TextColor3 = promptLabel.TextColor3:Lerp(promptColor, 1 - math.exp(-12 * dt))

	containerScale.Scale = exp_lerp(containerScale.Scale, targetScale, 20, dt)

	state.visual_bar_pct = exp_lerp(state.visual_bar_pct, targetBarPct, CONFIG.SMOOTH_BAR, dt)
	local progress = 1 - math.clamp(state.visual_bar_pct, 0, 1)
	indicatorLine.Position = UDim2.new(progress, 0, 0.5, 0)
	indicatorLine.BackgroundColor3 = indicatorLine.BackgroundColor3:Lerp(targetLineColor, 1 - math.exp(-15 * dt))

	state.visual_perfect_size = exp_lerp(state.visual_perfect_size, targetPerfectSize, CONFIG.SMOOTH_PERFECT, dt)

	if not state.is_grounded and state.visual_perfect_size > 0.001 then
		perfectZone.Size = UDim2.new(state.visual_perfect_size, 0, 1, 0)
		perfectZone.BackgroundColor3 = perfectZone.BackgroundColor3:Lerp(targetZoneColor, 1 - math.exp(-10 * dt))
		perfectZone.BackgroundTransparency = exp_lerp(perfectZone.BackgroundTransparency, targetZoneTransparency, 10, dt)
		perfectZone.Visible = true
	else
		perfectZone.Visible = false
	end

	if speedTotal > 10 then
		local percent = math.clamp(speedTotal / 200, 0, 1)
		targetFov = CONFIG.fov_base + (CONFIG.fov_max - CONFIG.fov_base) * percent
	end

	state.visual_fov = exp_lerp(state.visual_fov, targetFov, CONFIG.SMOOTH_FOV, dt)
	camera.FieldOfView = state.visual_fov
end

task.wait(2)

DataUtility.client.ensure_remotes()

local initialSettings = DataUtility.client.get("PogoSettings")
update_local_settings(initialSettings)
apply_gravity()

DataUtility.client.bind("PogoSettings", function(newSettings: any)
	update_local_settings(newSettings)
end)

DataUtility.client.bind("PogoSettings.base_jump_power", function(newPower: number)
	CONFIG.base_jump_power = newPower
end)

DataUtility.client.bind("PogoSettings.gravity_mult", function(newMult: number)
	CONFIG.gravity_mult = newMult
	gravityApplied = false
	apply_gravity()
end)

DataUtility.client.bind("OwnedRebirthUpgrades", function()
	apply_rebirth_upgrades()
end)

lock_text_visuals()

last_ground_distance = CONFIG.visual_max_height
smooth_ground_distance = CONFIG.visual_max_height

bind_character(character)

player.CharacterAdded:Connect(function(newCharacter: Model)
	bind_character(newCharacter)
end)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr: Player, passId: number, wasPurchased: boolean)
	if plr ~= player or not wasPurchased then
		return
	end

	if passId == CONFIG.PASS_AUTO then
		owns_auto_jump_pass = true
		has_auto_jump_pass = true
		if CONFIG.AUTOJUMP_CRITICAL then
			auto_jump_active = true
		end
		if autoJumpButton then
			autoJumpButton.Visible = true
		end
	elseif passId == CONFIG.PASS_EASY then
		CONFIG.perfect_zone_percent = 0.5
	end
end)

player:GetAttributeChangedSignal("EquippedSkill"):Connect(function()
	local activeType = player:GetAttribute("EquippedSkill")
	if activeType and activeType ~= "" then
		local cdEnd = skill_cooldowns_end[activeType] or 0
		if cdEnd > os.clock() then
			player:SetAttribute("SkillCooldownEnd", cdEnd)
		else
			player:SetAttribute("SkillCooldownEnd", 0)
		end
	else
		player:SetAttribute("SkillCooldownEnd", 0)
	end
end)

player:GetAttributeChangedSignal("TriggerActiveSkill"):Connect(function()
	useActiveAbility()
end)

UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then
		return
	end
	
	if input.KeyCode == Enum.KeyCode.Space then
		on_jump_pressed()
	elseif input.KeyCode == Enum.KeyCode.ButtonA then
		on_jump_pressed()
	elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
		useActiveAbility()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gpe: boolean)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		on_jump_released()
	end
end)

if jumpButton then
	jumpButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			on_jump_pressed()
		end
	end)

	jumpButton.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			on_jump_released()
		end
	end)
end

if autoJumpButton then
	autoJumpButton.MouseButton1Click:Connect(function()
		if not owns_auto_jump_pass then
			MarketplaceService:PromptGamePassPurchase(player, CONFIG.PASS_AUTO)
			return
		end

		auto_jump_active = not auto_jump_active

		local targetSize = auto_jump_active and UDim2.new(1.2, 0, 1.2, 0) or UDim2.new(1, 0, 1, 0)
		TweenService:Create(autoJumpButton, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = targetSize,
		}):Play()
	end)
end

task.spawn(function()
	local success, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, CONFIG.PASS_AUTO)
	end)

	if success and owns then
		owns_auto_jump_pass = true
		has_auto_jump_pass = true
		if CONFIG.AUTOJUMP_CRITICAL then
			auto_jump_active = true
		end
		if autoJumpButton then
			autoJumpButton.Visible = true
		end
	end
end)

RunService:BindToRenderStep(CONFIG.RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, update_loop)