
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local FTBallService = require(script.Parent.BallService)
local FTSpinService = require(script.Parent.SpinService)
local FTGameService = require(script.Parent.GameService)
local FTPlayerService = require(script.Parent.PlayerService)
local SoloTackleTestService = require(script.Parent.SoloTackleTestService)
local PlayerStatsTracker = require(ServerScriptService.Services.Utils.PlayerStatsTracker)
local RagdollR6 = require(ReplicatedStorage.Modules.Game.RagdollR6)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)

local FTTackleService = {}

--\ CONSTANTS \ -- TR
local ATTR_CAN_ACT = "FTCanAct"
local ATTR_CAN_THROW = "FTCanThrow"
local ATTR_CAN_SPIN = "FTCanSpin"
local ATTR_STUNNED = "FTStunned"
local ATTR_SKILL_LOCKED = "FTSkillLocked"

local INVULNERABLE_ATTR = "Invulnerable"
local COOLDOWN = FTConfig.TACKLE_CONFIG.Cooldown or 2
local STUN_DURATION = FTConfig.TACKLE_CONFIG.StunDuration or 1.2
local TACKLE_NOTIFY_DELAY = FTConfig.TACKLE_CONFIG.NotifyDelay or 0.15
local HITBOX_SIZE: Vector3 = FTConfig.TACKLE_CONFIG.HitboxSize or Vector3.new(6, 5, 8)
local HITBOX_FORWARD = FTConfig.TACKLE_CONFIG.HitboxForwardOffset or 3
local VELOCITY_PROJECTION = FTConfig.TACKLE_CONFIG.VelocityProjection or 0.05
local HITBOX_ACTIVE_TIME = FTConfig.TACKLE_CONFIG.ActiveTime or 0.45
local HITBOX_TICK = FTConfig.TACKLE_CONFIG.ActiveTick or (1 / 30)
local HITBOX_HEIGHT_PADDING = FTConfig.TACKLE_CONFIG.HitboxVerticalPadding or 1
local HITBOX_FORWARD_SPEED_SCALE = FTConfig.TACKLE_CONFIG.ForwardSpeedScale or 0.035
local HITBOX_MAX_EXTRA_FORWARD = FTConfig.TACKLE_CONFIG.MaxExtraForward or 3
local HITBOX_WIDTH_SPEED_SCALE = FTConfig.TACKLE_CONFIG.WidthSpeedScale or 0.015
local HITBOX_MAX_EXTRA_WIDTH = FTConfig.TACKLE_CONFIG.MaxExtraWidth or 2
local TARGET_POSITION_PROJECTION = FTConfig.TACKLE_CONFIG.TargetProjection or 0.1
local TARGET_SWEEP_SAMPLES = FTConfig.TACKLE_CONFIG.TargetSweepSamples or 3
local HITBOX_OVERLAP_MAX_PARTS = FTConfig.TACKLE_CONFIG.OverlapMaxParts or 48
local TACKLE_SNAP_CONTACT_DISTANCE = FTConfig.TACKLE_CONFIG.SnapContactDistance or 2.5
local TACKLE_SNAP_MAX_DISTANCE = FTConfig.TACKLE_CONFIG.SnapMaxDistance
	or (HITBOX_FORWARD + HITBOX_SIZE.Z + HITBOX_MAX_EXTRA_FORWARD + 1.5)
local BASE_WALK_SPEED = 16
local BASE_JUMP_POWER = 50
local BASE_JUMP_HEIGHT = 7.2

--\ MODULE STATE \ -- TR
local lastTackleTime: {[Player]: number} = {}
local matchEnabledInstance: BoolValue? = nil
local matchStartedInstance: BoolValue? = nil
local matchFolder: Folder? = nil

--\ HELPERS \ -- TR
local function SetAttribute(player: Player, attr: string, value: any): ()
    player:SetAttribute(attr, value)
    local character = player.Character
    if character then
        character:SetAttribute(attr, value)
    end
end

local function ClearPlayerCooldown(player: Player): ()
	lastTackleTime[player] = nil
end

local function ClearAllCooldowns(): ()
	table.clear(lastTackleTime)
end

local function GetMatchEnabled(): boolean
    if not matchEnabledInstance then
        local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
        if GameStateFolder then
            matchEnabledInstance = GameStateFolder:FindFirstChild("MatchEnabled") :: BoolValue?
        end
    end
    return matchEnabledInstance and matchEnabledInstance.Value or false
end

local function GetMatchStarted(): boolean
    if not matchStartedInstance then
        local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
        if GameStateFolder then
            matchStartedInstance = GameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
        end
    end
    return matchStartedInstance and matchStartedInstance.Value or false
end

local function GetMatchFolder(): Folder?
    if matchFolder then return matchFolder end
    local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
    if not GameStateFolder then return nil end
    matchFolder = GameStateFolder:FindFirstChild("Match") :: Folder?
    return matchFolder
end

local function IsPlayerInMatch(player: Player): boolean
    return FTPlayerService:IsPlayerInMatch(player)
end

local function CanPlayerAct(player: Player): boolean
    if not GetMatchEnabled() then return false end
    if not GetMatchStarted() then return false end
    if not IsPlayerInMatch(player) then return false end
    if player:GetAttribute(ATTR_SKILL_LOCKED) == true then
        return false
    end
    local character = player.Character
    if character and character:GetAttribute(ATTR_STUNNED) == true then
        return false
    end
    if character and character:GetAttribute(ATTR_SKILL_LOCKED) == true then
        return false
    end
    if player:GetAttribute(ATTR_STUNNED) == true then
        return false
    end
    return true
end

local function SetRunningState(player: Player, isRunning: boolean): ()
    if FTSpinService and FTSpinService.SetRunningState then
        FTSpinService:SetRunningState(player, isRunning)
    end
end

local function StopCharacterMomentum(character: Model?): ()
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function ApplyStun(player: Player, duration: number): ()
    local actualDuration = FlowBuffs.ApplyTackleStunReduction(player, duration)
    SetAttribute(player, ATTR_STUNNED, true)
    SetAttribute(player, ATTR_CAN_ACT, false)
    SetAttribute(player, ATTR_CAN_THROW, false)
    SetAttribute(player, ATTR_CAN_SPIN, false)
    SetRunningState(player, false)

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if character then
        StopCharacterMomentum(character)
        RagdollR6.Apply(character, actualDuration)
    end
    if humanoid then
        humanoid.WalkSpeed = 0
    end
    local token = os.clock()

    local enforceConn: RBXScriptConnection? = nil
    enforceConn = RunService.Heartbeat:Connect(function()
        if player:GetAttribute(ATTR_STUNNED) ~= true then
            if enforceConn then
                enforceConn:Disconnect()
            end
            return
        end
        if humanoid then
            humanoid.WalkSpeed = 0
        end
    end)

    Packets.TackleStun:FireClient(player, actualDuration)
    local impactId = PlayerIdentity.GetIdValue(player)
    if impactId > 0 and Packets.TackleImpact then
        Packets.TackleImpact:Fire(impactId, actualDuration)
    end

    task.delay(actualDuration, function()
        if enforceConn then
            enforceConn:Disconnect()
        end
        SetAttribute(player, ATTR_STUNNED, false)
        SetAttribute(player, ATTR_CAN_ACT, true)
        SetAttribute(player, ATTR_CAN_THROW, true)
        SetAttribute(player, ATTR_CAN_SPIN, true)
        SetRunningState(player, false)

        if humanoid then
            FlowBuffs.ApplyHumanoidWalkSpeed(player, humanoid, BASE_WALK_SPEED)
        end
    end)
end

local function IsOnCooldown(player: Player): boolean
    local lastUse = lastTackleTime[player]
    return lastUse ~= nil and (os.clock() - lastUse) < COOLDOWN
end

local function MarkCooldown(player: Player): ()
    lastTackleTime[player] = os.clock()
end

local function GetPlanarVelocity(root: BasePart): Vector3
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end

local function GetHitboxSize(root: BasePart): Vector3
	local speed = GetPlanarVelocity(root).Magnitude
	local extraForward = math.clamp(speed * HITBOX_FORWARD_SPEED_SCALE, 0, HITBOX_MAX_EXTRA_FORWARD)
	local extraWidth = math.clamp(speed * HITBOX_WIDTH_SPEED_SCALE, 0, HITBOX_MAX_EXTRA_WIDTH)
	return Vector3.new(
		HITBOX_SIZE.X + extraWidth,
		HITBOX_SIZE.Y + HITBOX_HEIGHT_PADDING,
		HITBOX_SIZE.Z + extraForward
	)
end

local function BuildHitboxCFrame(root: BasePart): CFrame
    local planarVelocity = GetPlanarVelocity(root)
    local dynamicForward = math.clamp(planarVelocity.Magnitude * HITBOX_FORWARD_SPEED_SCALE, 0, HITBOX_MAX_EXTRA_FORWARD)
    local baseCF = root.CFrame * CFrame.new(0, 0, -(HITBOX_FORWARD + (dynamicForward * 0.5)))
    local projected = baseCF.Position + (planarVelocity * VELOCITY_PROJECTION)
    return CFrame.lookAt(projected, projected + root.CFrame.LookVector, root.CFrame.UpVector)
end

local function IsPointInBox(boxCFrame: CFrame, size: Vector3, point: Vector3): boolean
	local localPos = boxCFrame:PointToObjectSpace(point)
	local half = size * 0.5
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function HasLineOfSight(attackerRoot: BasePart, targetRoot: BasePart): boolean
	local direction = targetRoot.Position - attackerRoot.Position
	if direction.Magnitude < 1e-3 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attackerRoot.Parent, targetRoot.Parent }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(attackerRoot.Position, direction, params)
	return hit == nil
end

local function ResolvePlayerFromPart(part: BasePart): Player?
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function GetCharacterRoot(character: Model?): BasePart?
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function GetFlatDirectionFromRoots(attackerRoot: BasePart, targetRoot: BasePart): Vector3?
	local offset = targetRoot.Position - attackerRoot.Position
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	if flatOffset.Magnitude > 0.05 then
		return flatOffset.Unit
	end

	local look = attackerRoot.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.05 then
		return flatLook.Unit
	end

	return nil
end

local function SnapTackleContact(attacker: Player, target: Player): ()
	local attackerCharacter = attacker.Character
	local targetCharacter = target.Character
	local attackerRoot = GetCharacterRoot(attackerCharacter)
	local targetRoot = GetCharacterRoot(targetCharacter)
	if not attackerCharacter or not targetCharacter or not attackerRoot or not targetRoot then
		return
	end

	local flatDelta = Vector3.new(
		targetRoot.Position.X - attackerRoot.Position.X,
		0,
		targetRoot.Position.Z - attackerRoot.Position.Z
	)
	if flatDelta.Magnitude <= 0.05 or flatDelta.Magnitude > TACKLE_SNAP_MAX_DISTANCE then
		return
	end

	local flatDirection = GetFlatDirectionFromRoots(attackerRoot, targetRoot)
	if not flatDirection then
		return
	end

	local targetPlanar = Vector3.new(targetRoot.Position.X, attackerRoot.Position.Y, targetRoot.Position.Z)
	local desiredPlanar = targetPlanar - (flatDirection * TACKLE_SNAP_CONTACT_DISTANCE)
	local desiredCFrame = CFrame.lookAt(desiredPlanar, targetPlanar, Vector3.yAxis)

	attackerCharacter:PivotTo(desiredCFrame)
	attackerRoot.AssemblyLinearVelocity = Vector3.zero
	attackerRoot.AssemblyAngularVelocity = Vector3.zero

	local attackerHumanoid = attackerCharacter:FindFirstChildOfClass("Humanoid")
	if attackerHumanoid then
		attackerHumanoid:Move(Vector3.zero, false)
	end
end

local function IsTargetPredictedInHitbox(boxCFrame: CFrame, size: Vector3, root: BasePart): boolean
	if IsPointInBox(boxCFrame, size, root.Position) then
		return true
	end

	local character = root.Parent
	if character and character:IsA("Model") then
		local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
		if torso and IsPointInBox(boxCFrame, size, torso.Position) then
			return true
		end
	end

	local planarVelocity = GetPlanarVelocity(root)
	if planarVelocity.Magnitude <= 0.1 then
		return false
	end

	local projected = root.Position + (planarVelocity * TARGET_POSITION_PROJECTION)
	if IsPointInBox(boxCFrame, size, projected) then
		return true
	end

	local previous = root.Position - (planarVelocity * math.max(HITBOX_TICK, 1 / 60))
	for sampleIndex = 1, TARGET_SWEEP_SAMPLES do
		local alpha = sampleIndex / (TARGET_SWEEP_SAMPLES + 1)
		if IsPointInBox(boxCFrame, size, previous:Lerp(projected, alpha)) then
			return true
		end
	end

	return false
end

local function GetTargetsInHitbox(attacker: Player, boxCFrame: CFrame, size: Vector3): {Player}
	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local result = {}
	local seen: {[Player]: boolean} = {}

	local function TryAddTarget(candidate: Player): ()
		if candidate == attacker or seen[candidate] or not IsPlayerInMatch(candidate) then
			return
		end

		local character = candidate.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		if attackerRoot and not HasLineOfSight(attackerRoot, root) then
			return
		end

		seen[candidate] = true
		table.insert(result, candidate)
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = if attacker.Character then { attacker.Character } else {}
	overlapParams.MaxParts = HITBOX_OVERLAP_MAX_PARTS
	overlapParams.RespectCanCollide = false

	for _, part in Workspace:GetPartBoundsInBox(boxCFrame, size, overlapParams) do
		local targetPlayer = ResolvePlayerFromPart(part)
		if targetPlayer then
			TryAddTarget(targetPlayer)
		end
	end

	for _, player in Players:GetPlayers() do
		if player ~= attacker and not seen[player] and IsPlayerInMatch(player) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and IsTargetPredictedInHitbox(boxCFrame, size, root) then
				TryAddTarget(player)
			end
		end
	end

	if attackerRoot then
		table.sort(result, function(a: Player, b: Player): boolean
			local aCharacter = a.Character
			local bCharacter = b.Character
			local aRoot = aCharacter and aCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
			local bRoot = bCharacter and bCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
			local aDistance = if aRoot then (aRoot.Position - attackerRoot.Position).Magnitude else math.huge
			local bDistance = if bRoot then (bRoot.Position - attackerRoot.Position).Magnitude else math.huge
			return aDistance < bDistance
		end)
	end

	return result
end

local function HandleHit(attacker: Player, target: Player): boolean
    if target:GetAttribute(INVULNERABLE_ATTR) == true then
        return false
    end
    local character = target.Character
    if character and character:GetAttribute(INVULNERABLE_ATTR) == true then
        return false
    end

    local ballState = FTBallService:GetBallState()
    local carrier = ballState and ballState:GetPossession()

    PlayerStatsTracker.AwardTackle(attacker)

    if FTSpinService and FTSpinService.IsSpinActive and FTSpinService:IsSpinActive(target) then
        ApplyStun(attacker, STUN_DURATION)
        return true
    end

    SnapTackleContact(attacker, target)

    if carrier and carrier == target then
        ApplyStun(target, STUN_DURATION)
        local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
        if root then
            local hitPos = root.Position
            task.delay(TACKLE_NOTIFY_DELAY, function()
                FTGameService:ProcessPlayEnd(hitPos, "Tackle")
            end)
        end
        return true
    end
    ApplyStun(target, STUN_DURATION)
    return true
end

local function HandleTackleAttempt(player: Player, _boxCF: CFrame, _size: Vector3): ()
    if not CanPlayerAct(player) then return end
    if IsOnCooldown(player) then return end

    if player:GetAttribute(INVULNERABLE_ATTR) == true then
        return
    end
    local character = player.Character
    if character and character:GetAttribute(INVULNERABLE_ATTR) == true then
        return
    end

    local ballState = FTBallService:GetBallState()
    if ballState and ballState:GetPossession() == player then
        return
    end

    MarkCooldown(player)

    task.spawn(function()
        local startTime = os.clock()
        while os.clock() - startTime <= HITBOX_ACTIVE_TIME do
            if not CanPlayerAct(player) then
                break
            end
            local characterModel = player.Character
            local root = characterModel and characterModel:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not root then
                break
            end
            local boxCFrame = BuildHitboxCFrame(root)
            local boxSize = GetHitboxSize(root)
            local targets = GetTargetsInHitbox(player, boxCFrame, boxSize)
            local activeBallState = FTBallService:GetBallState()
            local carrier = activeBallState and activeBallState:GetPossession()
            if carrier then
                for index, target in targets do
                    if target == carrier then
                        table.remove(targets, index)
                        table.insert(targets, 1, target)
                        break
                    end
                end
            end
            local hit = false
            for _, target in targets do
                if HandleHit(player, target) then
                    hit = true
                    break
                end
            end
            if not hit and SoloTackleTestService and SoloTackleTestService.TryHandleTackleHit then
                if SoloTackleTestService:TryHandleTackleHit(player, boxCFrame, boxSize, root, ApplyStun, STUN_DURATION) then
                    PlayerStatsTracker.AwardTackle(player)
                    hit = true
                end
            end
            if hit then
                break
            end
            task.wait(HITBOX_TICK)
        end
    end)
end

--\ PUBLIC FUNCTIONS \ -- TR
function FTTackleService.Init(_self: typeof(FTTackleService)): ()
    Packets.TackleAttempt.OnServerEvent:Connect(HandleTackleAttempt)
    Players.PlayerRemoving:Connect(ClearPlayerCooldown)

    local gameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
    local matchStarted = gameStateFolder and gameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
    if matchStarted then
        matchStarted.Changed:Connect(function(active: boolean)
            if active ~= true then
                ClearAllCooldowns()
            end
        end)
    end
end

function FTTackleService.Start(_self: typeof(FTTackleService)): ()
end

function FTTackleService.ResetPlayer(_self: typeof(FTTackleService), Player: Player): ()
	ClearPlayerCooldown(Player)
	SetAttribute(Player, ATTR_STUNNED, false)
	SetAttribute(Player, ATTR_CAN_ACT, true)
	SetAttribute(Player, ATTR_CAN_THROW, true)
	SetAttribute(Player, ATTR_CAN_SPIN, true)
	SetRunningState(Player, false)

	local Character = Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if Root then
		Root.Anchored = false
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	local HumanoidInstance = Character and Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return
	end

	FlowBuffs.ApplyHumanoidWalkSpeed(Player, HumanoidInstance, BASE_WALK_SPEED)
	if HumanoidInstance.UseJumpPower then
		HumanoidInstance.JumpPower = BASE_JUMP_POWER
	else
		HumanoidInstance.JumpHeight = BASE_JUMP_HEIGHT
	end
	HumanoidInstance.PlatformStand = false
	HumanoidInstance.Sit = false
	HumanoidInstance.AutoRotate = true
end

return FTTackleService
