--!strict

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTGameService = require(script.Parent.GameService)
local FTBallService = require(script.Parent.BallService)
local FTPlayerService = require(script.Parent.PlayerService)
local PlayerStatsTracker = require(ServerScriptService.Services.Utils.PlayerStatsTracker)
local RagdollR6 = require(ReplicatedStorage.Modules.Game.RagdollR6)
local ZonePlus = require(ReplicatedStorage.Packages.ZonePlus)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)
local PlayerDataGuard = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local MatchCutsceneLock = require(ServerScriptService.Skills.Utils.MatchCutsceneLock)
local Utility = require(ReplicatedStorage.Modules.Game.Utility)

local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local SCORE_NOTIFY_DURATION: number = 2.4

local FTScoringService = {}
local FireExtraPointTransition: () -> ()

type ExtraPointState = {
    active: boolean,
    stage: number,
    team: number?,
    kicker: Player?,
    token: number,
    goalScored: boolean,
    ballInPlay: boolean,
    pending: boolean,
    pendingToken: number,
}
type ExtraPointTeleportPlan = {[Player]: CFrame}

local extraPointState: ExtraPointState = {
    active = false,
    stage = 0,
    team = nil,
    kicker = nil,
    token = 0,
    goalScored = false,
    ballInPlay = false,
    pending = false,
    pendingToken = 0,
}
local extraPointResultLocked: boolean = false
local extraPointLastBallPosition: Vector3? = nil
local extraPointLastBallFlightTime: number? = nil
local TOUCHDOWN_SHOWCASE_DURATION: number = 3.15
local TOUCHDOWN_GAMEPLAY_REOPEN_DURATION: number = 0.6
local TOUCHDOWN_PRE_CAM_DELAY: number = TOUCHDOWN_SHOWCASE_DURATION + TOUCHDOWN_GAMEPLAY_REOPEN_DURATION
local TOUCHDOWN_POST_SHOWCASE_CAM_DURATION: number = 4.25
local TOUCHDOWN_RAGDOLL_MIN_DURATION: number = 2.55
local TOUCHDOWN_RAGDOLL_MAX_DURATION: number = 4.75
local TOUCHDOWN_RAGDOLL_GROUND_CHECK_INTERVAL: number = 0.05
local TOUCHDOWN_RAGDOLL_GROUND_CHECK_DISTANCE: number = 6
local TOUCHDOWN_RAGDOLL_STABLE_GROUND_TIME: number = 0.18
local TOUCHDOWN_RAGDOLL_MAX_LANDING_VERTICAL_SPEED: number = 18
local TOUCHDOWN_BODY_VELOCITY_NAME: string = "TouchdownImpactVelocity"
local TOUCHDOWN_BODY_VELOCITY_DURATION: number = 0.72
local TOUCHDOWN_BODY_VELOCITY_FORCE: number = 140000
local TOUCHDOWN_BODY_VELOCITY_P: number = 25000
local TOUCHDOWN_IMPACT_HORIZONTAL_SPEED: number = 72
local TOUCHDOWN_IMPACT_VERTICAL_SPEED: number = 30
local TOUCHDOWN_PAUSE_FALLBACK_DELAY: number = TOUCHDOWN_RAGDOLL_MIN_DURATION
local TOUCHDOWN_DIRECTION_EPSILON: number = 1e-4
local TOUCHDOWN_FALLBACK_DIRECTION: Vector3 = Vector3.new(0, 0, -1)
local TOUCHDOWN_MOVER_CLASS_NAMES: {[string]: boolean} = {
	AlignOrientation = true,
	AlignPosition = true,
	AngularVelocity = true,
	BodyAngularVelocity = true,
	BodyGyro = true,
	BodyPosition = true,
	BodyVelocity = true,
	LinearVelocity = true,
	Torque = true,
	VectorForce = true,
}
local EXTRA_POINT_TELEPORT_DELAY: number = 0
local extraPointStoredSpeeds: {[Player]: number} = {}
local extraPointStoredJumps: {[Player]: {jumpPower: number, jumpHeight: number, useJumpPower: boolean}} = {}
local extraPointStoredAutoRotate: {[Player]: boolean} = {}
local EXTRA_POINT_SUCCESS_TRANSITION_DELAY: number = 2
local EXTRA_POINT_MISS_TRANSITION_DELAY: number = 0.25
local EXTRA_POINT_MIN_MISS_RESULT_TIME: number = 0.25
local EXTRA_POINT_FINALIZE_DELAY_AFTER_RESULT: number = 0.05
local EXTRA_POINT_SETUP_DURATION: number = 5
local EXTRA_POINT_UPRIGHT_DURATION: number = 1.5
local EXTRA_POINT_CORRECTIVE_RETRY_DELAY: number = 0.35
local EXTRA_POINT_MAX_CORRECTIVE_RETRIES: number = 1
local EXTRA_POINT_KICKER_CAM_DURATION: number = 1.6
local EXTRA_POINT_KICKER_CAM_DELAY: number = 1.2
local EXTRA_POINT_RETRY_PLANAR_TOLERANCE: number = 3
local EXTRA_POINT_RETRY_VERTICAL_TOLERANCE: number = 1
local EXTRA_POINT_GOAL_SAMPLE_STEP_TIME: number = 1 / 120
local EXTRA_POINT_GOAL_MAX_SAMPLES: number = 12
local EXTRA_POINT_PIVOT_BY_TEAM: {[number]: Vector3} = {
    [1] = Vector3.new(-248.935, 494.051, 9.895),
    [2] = Vector3.new(180.353, 494.051, 9.895),
}
local extraPointTransitionFired: boolean = false
local extraPointFailurePending: boolean = false
local touchdownLandingTokens: {[Model]: number} = {}

local uprightTokens: {[Player]: number} = {}
local ATTR_CAN_ACT = "FTCanAct"
local ATTR_CAN_THROW = "FTCanThrow"
local ATTR_CAN_SPIN = "FTCanSpin"
local ATTR_STUNNED = "FTStunned"
local ATTR_EXTRA_POINT_FROZEN = "FTExtraPointFrozen"
local ATTR_SKILL_LOCKED = "FTSkillLocked"
local ATTR_CHARGING_THROW = "FTChargingThrow"
local ATTR_MATCH_CUTSCENE_LOCKED = "FTMatchCutsceneLocked"
local ATTR_PERFECT_PASS_CUTSCENE_LOCKED = "FTPerfectPassCutsceneLocked"
local ATTR_CUTSCENE_HUD_HIDDEN = "FTCutsceneHudHidden"
local TOUCHDOWN_PAUSE_ATTRIBUTE = "FTScoringPauseLocked"
local touchdownPauseLock = MatchCutsceneLock.new({
    CutsceneAttributeName = TOUCHDOWN_PAUSE_ATTRIBUTE,
    AnchorRoot = false,
    EnforcePivot = false,
})

local function GetMatchPlayers(): {Player}
    local matchPlayers: {Player} = {}
    for _, player in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(player) then
            table.insert(matchPlayers, player)
        end
    end
    return matchPlayers
end

local function SetTouchdownPauseWindowActive(active: boolean, matchPlayers: {Player}?): ()
    if FTGameService.SetPlayEndLocked then
        FTGameService:SetPlayEndLocked(active)
    end

    local players = if matchPlayers ~= nil then matchPlayers else GetMatchPlayers()
    for _, player in players do
        player:SetAttribute(TOUCHDOWN_PAUSE_ATTRIBUTE, active)
        local character = player.Character
        if character then
            character:SetAttribute(TOUCHDOWN_PAUSE_ATTRIBUTE, active)
        end
    end
end

local function StartTouchdownPause(): ()
    local matchPlayers = GetMatchPlayers()
    if #matchPlayers <= 0 then
        return
    end

    SetTouchdownPauseWindowActive(true, matchPlayers)
    touchdownPauseLock:Start(matchPlayers, 0)
    touchdownPauseLock:CaptureCurrentPivots(matchPlayers)
end

local function StopTouchdownPause(): ()
    touchdownPauseLock:Stop(nil)
    SetTouchdownPauseWindowActive(false)
	for _, player in GetMatchPlayers() do
		player:SetAttribute(ATTR_SKILL_LOCKED, false)
		player:SetAttribute(ATTR_CAN_ACT, true)
		player:SetAttribute(ATTR_CAN_THROW, true)
		player:SetAttribute(ATTR_CAN_SPIN, true)
        player:SetAttribute(TOUCHDOWN_PAUSE_ATTRIBUTE, false)
        local character = player.Character
		if character then
			character:SetAttribute(ATTR_SKILL_LOCKED, false)
			character:SetAttribute(ATTR_CAN_ACT, true)
			character:SetAttribute(ATTR_CAN_THROW, true)
			character:SetAttribute(ATTR_CAN_SPIN, true)
			character:SetAttribute(TOUCHDOWN_PAUSE_ATTRIBUTE, false)
		end
	end
end

local function SetTouchdownInputLocked(player: Player, locked: boolean): ()
	player:SetAttribute(ATTR_CAN_ACT, not locked)
	player:SetAttribute(ATTR_CAN_THROW, not locked)
	player:SetAttribute(ATTR_CAN_SPIN, not locked)
	player:SetAttribute(ATTR_SKILL_LOCKED, locked)

	local character = player.Character
	if character then
		character:SetAttribute(ATTR_CAN_ACT, not locked)
		character:SetAttribute(ATTR_CAN_THROW, not locked)
		character:SetAttribute(ATTR_CAN_SPIN, not locked)
		character:SetAttribute(ATTR_SKILL_LOCKED, locked)
	end
end

local function ClearTouchdownInterruptedState(player: Player): ()
	player:SetAttribute(ATTR_CHARGING_THROW, false)
	player:SetAttribute(ATTR_MATCH_CUTSCENE_LOCKED, false)
	player:SetAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED, false)
	player:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, false)

	local character = player.Character
	if not character then
		return
	end

	character:SetAttribute(ATTR_CHARGING_THROW, false)
	character:SetAttribute(ATTR_MATCH_CUTSCENE_LOCKED, false)
	character:SetAttribute(ATTR_PERFECT_PASS_CUTSCENE_LOCKED, false)
	character:SetAttribute(ATTR_CUTSCENE_HUD_HIDDEN, false)
end

local function ResolveTouchdownBlastDirection(scorer: Player): Vector3
	local character = scorer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local flatForward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flatForward.Magnitude > TOUCHDOWN_DIRECTION_EPSILON then
			return -flatForward.Unit
		end
	end

	return TOUCHDOWN_FALLBACK_DIRECTION
end

local function ResetTouchdownPlayerPhysics(character: Model, root: BasePart): ()
	for _, descendant in character:GetDescendants() do
		if TOUCHDOWN_MOVER_CLASS_NAMES[descendant.ClassName] == true then
			descendant:Destroy()
			continue
		end

		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function ApplyTouchdownBodyVelocity(root: BasePart, blastVelocity: Vector3): ()
	local existingVelocity = root:FindFirstChild(TOUCHDOWN_BODY_VELOCITY_NAME)
	if existingVelocity then
		existingVelocity:Destroy()
	end

	local bodyVelocity: BodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = TOUCHDOWN_BODY_VELOCITY_NAME
	bodyVelocity.MaxForce = Vector3.new(
		TOUCHDOWN_BODY_VELOCITY_FORCE,
		TOUCHDOWN_BODY_VELOCITY_FORCE,
		TOUCHDOWN_BODY_VELOCITY_FORCE
	)
	bodyVelocity.P = TOUCHDOWN_BODY_VELOCITY_P
	bodyVelocity.Velocity = blastVelocity
	bodyVelocity.Parent = root

	root.AssemblyLinearVelocity = blastVelocity
	Debris:AddItem(bodyVelocity, TOUCHDOWN_BODY_VELOCITY_DURATION)
end

local function IsTouchdownGrounded(character: Model, root: BasePart, humanoid: Humanoid): boolean
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return math.abs(root.AssemblyLinearVelocity.Y) <= TOUCHDOWN_RAGDOLL_MAX_LANDING_VERTICAL_SPEED
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }

	local result = Workspace:Raycast(
		root.Position,
		Vector3.new(0, -TOUCHDOWN_RAGDOLL_GROUND_CHECK_DISTANCE, 0),
		raycastParams
	)
	if not result then
		return false
	end

	local groundDistance = root.Position.Y - result.Position.Y
	if groundDistance > TOUCHDOWN_RAGDOLL_GROUND_CHECK_DISTANCE then
		return false
	end

	return math.abs(root.AssemblyLinearVelocity.Y) <= TOUCHDOWN_RAGDOLL_MAX_LANDING_VERTICAL_SPEED
end

local function MonitorTouchdownLanding(
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	onLanded: (() -> ())?
): ()
	local token = (touchdownLandingTokens[character] or 0) + 1
	touchdownLandingTokens[character] = token

	task.spawn(function()
		local startedAt = os.clock()
		local groundedAt: number? = nil

		while touchdownLandingTokens[character] == token do
			if character.Parent == nil or root.Parent == nil or humanoid.Parent == nil then
				touchdownLandingTokens[character] = nil
				return
			end

			local elapsed = os.clock() - startedAt
			if elapsed >= TOUCHDOWN_RAGDOLL_MIN_DURATION then
				if IsTouchdownGrounded(character, root, humanoid) then
					groundedAt = groundedAt or os.clock()
					if os.clock() - groundedAt >= TOUCHDOWN_RAGDOLL_STABLE_GROUND_TIME then
						break
					end
				else
					groundedAt = nil
				end
			end

			if elapsed >= TOUCHDOWN_RAGDOLL_MAX_DURATION then
				break
			end

			task.wait(TOUCHDOWN_RAGDOLL_GROUND_CHECK_INTERVAL)
		end

		if touchdownLandingTokens[character] ~= token then
			return
		end
		touchdownLandingTokens[character] = nil

		if character.Parent then
			RagdollR6.Clear(character)
		end

		if onLanded then
			onLanded()
		end
	end)
end

local function ApplyTouchdownImpact(scorer: Player): boolean
	local blastDirection = ResolveTouchdownBlastDirection(scorer)
	local scorerLandingTracked = false

	for _, player in GetMatchPlayers() do
		ClearTouchdownInterruptedState(player)
		SetTouchdownInputLocked(player, true)

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not root or not humanoid then
			continue
		end

		ResetTouchdownPlayerPhysics(character, root)
		humanoid:Move(Vector3.zero, false)

		if player == scorer then
			humanoid.AutoRotate = true
			humanoid.PlatformStand = false
			humanoid.Sit = false
			RagdollR6.Clear(character)
			scorerLandingTracked = true
			continue
		end

		RagdollR6.Apply(character)
		local blastVelocity = (blastDirection * TOUCHDOWN_IMPACT_HORIZONTAL_SPEED)
			+ Vector3.new(0, TOUCHDOWN_IMPACT_VERTICAL_SPEED, 0)
		ApplyTouchdownBodyVelocity(root, blastVelocity)
		MonitorTouchdownLanding(character, root, humanoid, nil)
	end

	return scorerLandingTracked
end

local function EndExtraPointKeepLive(): ()
    StopTouchdownPause()
    FireExtraPointTransition()
    extraPointState.active = false
    extraPointState.stage = 0
    extraPointState.team = nil
    extraPointState.kicker = nil
    extraPointState.goalScored = false
    extraPointState.ballInPlay = false
    extraPointState.pending = false
    extraPointState.token += 1
    extraPointResultLocked = false
    extraPointLastBallPosition = nil
    extraPointLastBallFlightTime = nil
    extraPointFailurePending = false
    for player, speed in extraPointStoredSpeeds do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        player:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
        if character then
            character:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
        end
        if humanoid then
            humanoid.WalkSpeed = FlowBuffs.ResolveRestoredWalkSpeed(player, speed, 16)
            local jumpData = extraPointStoredJumps[player]
            if jumpData then
                humanoid.UseJumpPower = jumpData.useJumpPower
                humanoid.JumpPower = jumpData.jumpPower
                humanoid.JumpHeight = jumpData.jumpHeight
            end
            local autoRotate = extraPointStoredAutoRotate[player]
            if autoRotate ~= nil then
                humanoid.AutoRotate = autoRotate
            end
        end
        extraPointStoredSpeeds[player] = nil
        extraPointStoredJumps[player] = nil
        extraPointStoredAutoRotate[player] = nil
    end
    for player, jumpData in extraPointStoredJumps do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.UseJumpPower = jumpData.useJumpPower
            humanoid.JumpPower = jumpData.jumpPower
            humanoid.JumpHeight = jumpData.jumpHeight
        end
        extraPointStoredJumps[player] = nil
    end
    for player, autoRotate in extraPointStoredAutoRotate do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = autoRotate
        end
        extraPointStoredAutoRotate[player] = nil
    end
    FTGameService:SetExtraPointActive(false)
    FTBallService:SetExtraPointActive(false)
    extraPointTransitionFired = false
end

local function GetNumericPlayerStat(player: Player, statName: string): number
    local value, _hasData = PlayerDataGuard.GetOrDefault(player, { statName }, 0)
    return tonumber(value) or 0
end

local function GetPlayerEquippedCard(player: Player): string
    local equippedCard, _hasData = PlayerDataGuard.GetOrDefault(player, { "EquippedCard" }, "")
    if typeof(equippedCard) == "string" then
        return equippedCard
    end
    return ""
end

FireExtraPointTransition = function(): ()
    if extraPointTransitionFired then
        return
    end

    extraPointTransitionFired = true
    Packets.ExtraPointEnd:Fire()
end

local function ScheduleExtraPointTransition(delayTime: number): ()
    if extraPointTransitionFired then
        return
    end

    extraPointTransitionFired = true
    local token = extraPointState.token
    local effectiveDelay = math.max(delayTime, 0)
    if effectiveDelay <= 0 then
        if extraPointState.active and extraPointState.token == token then
            Packets.ExtraPointEnd:Fire()
        end
        return
    end

    task.delay(effectiveDelay, function()
        if not extraPointState.active or extraPointState.token ~= token then
            return
        end

        Packets.ExtraPointEnd:Fire()
    end)
end

local function ResolveExtraPointMissDelay(baseDelay: number): number
    local elapsedFlightTime = 0
    local ballState = FTBallService:GetBallState()
    local physicsData = ballState and ballState:GetPhysicsData()
    if physicsData then
        elapsedFlightTime = math.max(0, Workspace:GetServerTimeNow() - physicsData.LaunchTime)
    end

    return math.max(baseDelay, EXTRA_POINT_MIN_MISS_RESULT_TIME - elapsedFlightTime)
end

local function FireTouchdownShowcase(player: Player): ()
    local playerId = PlayerIdentity.GetIdValue(player)
    if playerId <= 0 then
        return
    end

    local touchdownCount = GetNumericPlayerStat(player, "Touchdowns")
    local passingCount = GetNumericPlayerStat(player, "Passing")
    local tackleCount = GetNumericPlayerStat(player, "Tackles")
    local equippedCard = GetPlayerEquippedCard(player)

    Packets.TouchdownShowcase:Fire(
        playerId,
        equippedCard,
        touchdownCount,
        passingCount,
        tackleCount,
        TOUCHDOWN_SHOWCASE_DURATION
    )
end


local endzoneZones: {[number]: any} = {}
local goalZones: {[number]: any} = {}

local function GetPrimaryPart(container: Instance?): BasePart?
    if not container then
        return nil
    end
    if container:IsA("BasePart") then
        return container
    end
    if container:IsA("Model") and container.PrimaryPart then
        return container.PrimaryPart
    end
    for _, descendant in container:GetDescendants() do
        if descendant:IsA("BasePart") then
            return descendant
        end
    end
    return nil
end

local function GetMatchFolder(): Folder?
    local stateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
    if not stateFolder then
        return nil
    end
    return stateFolder:FindFirstChild("Match") :: Folder?
end

local function GetTeamPlayers(team: number): {Player}
    local folder = GetMatchFolder()
    if not folder then
        return {}
    end
    local teamFolder = folder:FindFirstChild("Team" .. team)
    if not teamFolder then
        return {}
    end
    local players: {Player} = {}
    for _, value in teamFolder:GetChildren() do
        if value:IsA("IntValue") and value.Value ~= 0 then
            local player = PlayerIdentity.ResolvePlayer(value.Value)
            if player then
                table.insert(players, player)
            end
        end
    end
    return players
end

local function SelectRandomPlayer(team: number): Player?
    local list = GetTeamPlayers(team)
    if #list == 0 then
        return nil
    end
    return list[math.random(#list)]
end

local function RelativeToAbsoluteYard(relative: number, team: number): number
    local clamped = math.clamp(relative, 0, 100)
    if team == 1 then
        return clamped
    end
    return 100 - clamped
end

local function GetCustomPositionPart(team: number, name: string): BasePart?
    local gameFolder = Workspace:FindFirstChild("Game")
    local customFolder = gameFolder and (gameFolder:FindFirstChild("PositionsCustom1") or gameFolder:FindFirstChild("PositionsCustom1", true))
    local teamFolder = customFolder and (customFolder:FindFirstChild("Team" .. team) or customFolder:FindFirstChild("Team" .. team, true))
    local target = teamFolder and (teamFolder:FindFirstChild(name) or teamFolder:FindFirstChild(name, true))
    if target then
        return GetPrimaryPart(target)
    end
    return nil
end

local function GetAxisSizeFromPart(part: BasePart, axis: number): number
    if axis == 1 then
        return part.Size.X
    elseif axis == 2 then
        return part.Size.Y
    end
    return part.Size.Z
end

local function GetGoalPlaneAxisForPart(part: BasePart): (number, number)
    local xAxisInLocal = part.CFrame:VectorToObjectSpace(Vector3.xAxis)
    local absX = math.abs(xAxisInLocal.X)
    local absY = math.abs(xAxisInLocal.Y)
    local absZ = math.abs(xAxisInLocal.Z)
    local axis = 1
    local alignment = absX
    if absY > alignment then
        axis = 2
        alignment = absY
    end
    if absZ > alignment then
        axis = 3
        alignment = absZ
    end
    return axis, alignment
end

local function GetGoalPartSelectionScore(part: BasePart): number
    local planeAxis, axisAlignment = GetGoalPlaneAxisForPart(part)
    local thickness = math.max(GetAxisSizeFromPart(part, planeAxis), 0.05)
    local spanA = if planeAxis == 1 then part.Size.Y elseif planeAxis == 2 then part.Size.X else part.Size.X
    local spanB = if planeAxis == 3 then part.Size.Y else part.Size.Z
    local area = math.max(spanA, 0.05) * math.max(spanB, 0.05)
    local minSpan = math.min(spanA, spanB)
    local score = (area / thickness) * math.max(axisAlignment, 0.1)
    if minSpan < 2 then
        score *= 0.15
    elseif minSpan < 4 then
        score *= 0.45
    end
    local lowerName = string.lower(part.Name)
    if string.find(lowerName, "hitbox", 1, true) then
        score += 1_000_000
    end
    if string.find(lowerName, "trigger", 1, true) then
        score += 750_000
    end
    if string.find(lowerName, "zone", 1, true) then
        score += 500_000
    end
    if string.find(lowerName, "goal", 1, true) then
        score += 5_000
    end
    return score
end

local function ResolveGoalPart(container: Instance?): BasePart?
    if not container then
        return nil
    end
    if container:IsA("BasePart") then
        return container
    end
    local bestPart: BasePart? = nil
    local bestScore = -math.huge
    for _, descendant in container:GetDescendants() do
        if descendant:IsA("BasePart") then
            local score = GetGoalPartSelectionScore(descendant)
            if score > bestScore then
                bestScore = score
                bestPart = descendant
            end
        end
    end
    if bestPart then
        return bestPart
    end
    return GetPrimaryPart(container)
end

local function FindNamedDescendant(container: Instance?, targetName: string): Instance?
    if not container then
        return nil
    end

    local lowered = string.lower(targetName)
    for _, descendant in container:GetDescendants() do
        if string.lower(descendant.Name) == lowered then
            return descendant
        end
    end
    return nil
end

local function CollectNamedBaseParts(container: Instance?, targetName: string, excludedContainer: Instance?): {BasePart}
    local parts: {BasePart} = {}
    if not container then
        return parts
    end

    local lowered = string.lower(targetName)
    for _, descendant in container:GetDescendants() do
        if excludedContainer and descendant:IsDescendantOf(excludedContainer) then
            continue
        end
        if descendant:IsA("BasePart") and string.lower(descendant.Name) == lowered then
            table.insert(parts, descendant)
        end
    end

    return parts
end

local function CollectBaseParts(container: Instance?): {BasePart}
    local parts: {BasePart} = {}
    if not container then
        return parts
    end

    for _, descendant in container:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
        end
    end

    return parts
end

local function ShuffleInPlace<T>(list: {T}): ()
    for index = #list, 2, -1 do
        local swapIndex = math.random(index)
        list[index], list[swapIndex] = list[swapIndex], list[index]
    end
end

local function RemovePlayerFromList(list: {Player}, playerToRemove: Player?): {Player}
    local result: {Player} = {}
    for _, player in list do
        if player ~= playerToRemove then
            table.insert(result, player)
        end
    end
    return result
end

local function GetExtraPointPositionsModel(): Model?
    local gameFolder = Workspace:FindFirstChild("Game")
    local customPositions = gameFolder and (gameFolder:FindFirstChild("PositionsCustom1") or gameFolder:FindFirstChild("PositionsCustom1", true))
    if customPositions and customPositions:IsA("Model") then
        return customPositions
    end
    return nil
end

local function ResolveGroundedExtraPointTarget(player: Player, target: CFrame): CFrame
    local character = player.Character
    if character and FTGameService.ResolveGroundedTeleportCFrame then
        return FTGameService:ResolveGroundedTeleportCFrame(character, target)
    end

    return target
end

local function AnchorTeleport(player: Player, target: CFrame): ()
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local wasAnchored = false
    local wasPlatformStand = false
    if root then
        wasAnchored = root.Anchored
        root.Anchored = true
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if humanoid then
        wasPlatformStand = humanoid.PlatformStand
        humanoid.PlatformStand = true
        humanoid.Sit = false
        humanoid:Move(Vector3.zero, false)
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end
    local groundedTarget = ResolveGroundedExtraPointTarget(player, target)
    character:PivotTo(groundedTarget)
    task.defer(function()
        if root then
            root.Anchored = wasAnchored
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
        if humanoid then
            humanoid.PlatformStand = false
            humanoid.Sit = false
            humanoid.AutoRotate = true
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end)
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.Landed)
            end)
        end
    end)

end

local function PositionPlayerAtPart(player: Player, part: BasePart): ()
    AnchorTeleport(player, part.CFrame)
end

local function IsPlayerAtTeleportTarget(player: Player, target: CFrame): boolean
    local character = player.Character
    if not character then
        return false
    end

    local currentPivot = character:GetPivot()
    local expectedPivot = ResolveGroundedExtraPointTarget(player, target)
    local planarOffset = Vector3.new(
        currentPivot.Position.X - expectedPivot.Position.X,
        0,
        currentPivot.Position.Z - expectedPivot.Position.Z
    ).Magnitude
    if planarOffset > EXTRA_POINT_RETRY_PLANAR_TOLERANCE then
        return false
    end

    local verticalOffset = math.abs(currentPivot.Position.Y - expectedPivot.Position.Y)
    if verticalOffset > EXTRA_POINT_RETRY_VERTICAL_TOLERANCE then
        return false
    end

    return true
end

local function ApplyTeleportPlan(targets: ExtraPointTeleportPlan, onlyIfNeeded: boolean): boolean
    local teleportedAny = false
    for player, target in targets do
        if onlyIfNeeded and IsPlayerAtTeleportTarget(player, target) then
            continue
        end
        AnchorTeleport(player, target)
        teleportedAny = true
    end
    return teleportedAny
end

local function BuildExtraPointFormationPlan(team: number, kicker: Player): (ExtraPointTeleportPlan?, number, number)
    local positionsModel = GetExtraPointPositionsModel()
    local targetPivot = EXTRA_POINT_PIVOT_BY_TEAM[team]
    if not positionsModel or not targetPivot then
        return nil, 0, 0
    end

    local currentPivot = positionsModel:GetPivot()
    positionsModel:PivotTo(CFrame.new(targetPivot) * currentPivot.Rotation)

    local scoringTeamModel = positionsModel:FindFirstChild("Team" .. team) or positionsModel:FindFirstChild("Team" .. team, true)
    if not scoringTeamModel then
        return nil, 0, 0
    end

    local otherModel = FindNamedDescendant(scoringTeamModel, "Other")
    local susPart = GetPrimaryPart(FindNamedDescendant(scoringTeamModel, "Sus"))
    local randomParts = CollectNamedBaseParts(scoringTeamModel, "Random", otherModel)
    local opponentParts = CollectBaseParts(otherModel)
    local scoringPlayers = RemovePlayerFromList(GetTeamPlayers(team), kicker)
    local opponentTeam = team == 1 and 2 or 1
    local opponentPlayers = GetTeamPlayers(opponentTeam)

    ShuffleInPlace(randomParts)
    ShuffleInPlace(opponentParts)
    ShuffleInPlace(scoringPlayers)
    ShuffleInPlace(opponentPlayers)

    if not susPart then
        susPart = randomParts[1]
    end
    if not susPart then
        return nil, 0, 0
    end
    if #scoringPlayers > 0 and #randomParts == 0 then
        return nil, 0, 0
    end
    if #opponentPlayers > 0 and #opponentParts == 0 then
        return nil, 0, 0
    end

    local targets: ExtraPointTeleportPlan = {
        [kicker] = susPart.CFrame,
    }

    for index, player in scoringPlayers do
        local targetPart = randomParts[((index - 1) % math.max(#randomParts, 1)) + 1]
        if targetPart then
            targets[player] = targetPart.CFrame
        end
    end

    for index, player in opponentPlayers do
        local targetPart = opponentParts[((index - 1) % math.max(#opponentParts, 1)) + 1]
        if targetPart then
            targets[player] = targetPart.CFrame
        end
    end

    return targets, #randomParts, #opponentParts
end

local function ApplyExtraPointFormation(team: number, kicker: Player, onlyIfNeeded: boolean): (boolean, ExtraPointTeleportPlan?)
    local targets, randomCount, opponentCount = BuildExtraPointFormationPlan(team, kicker)
    if not targets then
        return false, nil
    end

    local teleportedAny = ApplyTeleportPlan(targets, onlyIfNeeded)
    return teleportedAny, targets
end

local function GetGoalPartForTeam(team: number): BasePart?
    local gameFolder = Workspace:FindFirstChild("Game")
    local goalFolder = gameFolder and gameFolder:FindFirstChild("Goal")
    local target = goalFolder and goalFolder:FindFirstChild("Team" .. team)
    return ResolveGoalPart(target)
end

local function FreezePlayerForTeleport(player: Player, duration: number): ()
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local prevSpeed = humanoid.WalkSpeed
    local prevJumpPower = humanoid.JumpPower
    local prevJumpHeight = humanoid.JumpHeight
    local prevUseJumpPower = humanoid.UseJumpPower
    local prevAutoRotate = humanoid.AutoRotate
    humanoid.WalkSpeed = 0
    humanoid.UseJumpPower = true
    humanoid.JumpPower = 0
    humanoid.JumpHeight = 0
    humanoid.AutoRotate = false
    humanoid:Move(Vector3.zero, false)
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if FTPlayerService.StopPlayerAnimation then
        FTPlayerService:StopPlayerAnimation(player)
    end
    task.delay(duration, function()
        if humanoid.Parent and not extraPointState.active then
            humanoid.WalkSpeed = prevSpeed
            humanoid.UseJumpPower = prevUseJumpPower
            humanoid.JumpPower = prevJumpPower
            humanoid.JumpHeight = prevJumpHeight
            humanoid.AutoRotate = prevAutoRotate
        end
    end)
end

local function ResetPlayerPhysics(player: Player): ()
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if humanoid then
        humanoid.Sit = false
        humanoid.AutoRotate = true
        humanoid:Move(Vector3.zero, false)
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Landed)
        end)
    end
end

local function ClearTeleportStun(player: Player): ()
    player:SetAttribute(ATTR_STUNNED, false)
    player:SetAttribute(ATTR_CAN_ACT, true)
    player:SetAttribute(ATTR_CAN_THROW, true)
    player:SetAttribute(ATTR_CAN_SPIN, true)
    player:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
    local character = player.Character
    if character then
        character:SetAttribute(ATTR_STUNNED, false)
        character:SetAttribute(ATTR_CAN_ACT, true)
        character:SetAttribute(ATTR_CAN_THROW, true)
        character:SetAttribute(ATTR_CAN_SPIN, true)
        character:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
        RagdollR6.Clear(character)
    end
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.AutoRotate = true
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
end

local function IsPointInsidePart(part: BasePart, point: Vector3): boolean
    local localPos = part.CFrame:PointToObjectSpace(point)
    local half = part.Size * 0.5
    return math.abs(localPos.X) <= half.X
        and math.abs(localPos.Y) <= half.Y
        and math.abs(localPos.Z) <= half.Z
end

local function DidSegmentEnterPart(part: BasePart, fromPos: Vector3, toPos: Vector3): boolean
    if IsPointInsidePart(part, toPos) or IsPointInsidePart(part, fromPos) then
        return true
    end
    local segment = toPos - fromPos
    local distance = segment.Magnitude
    if distance < 1e-4 then
        return false
    end
    local smallestSize = math.max(math.min(part.Size.X, part.Size.Y, part.Size.Z), 1)
    local samples = math.clamp(math.ceil(distance / (smallestSize * 0.35)), 2, 16)
    for index = 1, samples - 1 do
        local alpha = index / samples
        if IsPointInsidePart(part, fromPos:Lerp(toPos, alpha)) then
            return true
        end
    end
    return false
end

local function GetVectorAxisValue(vector: Vector3, axis: number): number
    if axis == 1 then
        return vector.X
    elseif axis == 2 then
        return vector.Y
    end
    return vector.Z
end

local function GetPartThinAxis(part: BasePart): number
    if part.Size.Z < part.Size.X then
        return 3
    end
    return 1
end

local function GetDominantLocalAxisForWorldAxis(part: BasePart, worldAxis: Vector3): number
    local localAxis = part.CFrame:VectorToObjectSpace(worldAxis)
    local absX = math.abs(localAxis.X)
    local absY = math.abs(localAxis.Y)
    local absZ = math.abs(localAxis.Z)
    if absY >= absX and absY >= absZ then
        return 2
    elseif absZ >= absX then
        return 3
    end
    return 1
end

local function GetWorldAxisExtent(part: BasePart, worldAxis: Vector3): number
    local half = part.Size * 0.5
    local right = part.CFrame.RightVector
    local up = part.CFrame.UpVector
    local look = part.CFrame.LookVector
    return math.abs(right:Dot(worldAxis)) * half.X
        + math.abs(up:Dot(worldAxis)) * half.Y
        + math.abs(look:Dot(worldAxis)) * half.Z
end

local function GetSegmentAxisPlaneIntersection(
    fromPos: Vector3,
    toPos: Vector3,
    planeAxis: number,
    planeCoordinate: number
): Vector3?
    local fromCoord = GetVectorAxisValue(fromPos, planeAxis)
    local toCoord = GetVectorAxisValue(toPos, planeAxis)
    local delta = toCoord - fromCoord
    if math.abs(delta) <= 1e-4 then
        return nil
    end
    local alpha = (planeCoordinate - fromCoord) / delta
    if alpha < 0 or alpha > 1 then
        return nil
    end
    return fromPos:Lerp(toPos, math.clamp(alpha, 0, 1))
end

local function GetSegmentPartPlaneIntersectionLocal(part: BasePart, fromPos: Vector3, toPos: Vector3): (Vector3?, number?)
    local fromLocal = part.CFrame:PointToObjectSpace(fromPos)
    local toLocal = part.CFrame:PointToObjectSpace(toPos)
    local axis = GetPartThinAxis(part)
    local fromCoord = GetVectorAxisValue(fromLocal, axis)
    local toCoord = GetVectorAxisValue(toLocal, axis)
    local epsilon = 0.01
    local delta = toCoord - fromCoord
    if math.abs(delta) <= epsilon then
        return nil, nil
    end
    local alpha = fromCoord / (fromCoord - toCoord)
    if alpha < 0 or alpha > 1 then
        return nil, nil
    end
    if math.abs(fromCoord) <= epsilon and math.abs(toCoord) <= epsilon then
        return nil, nil
    end
    return fromLocal:Lerp(toLocal, math.clamp(alpha, 0, 1)), axis
end

local function IsGoalPlaneIntersectionInsidePart(
    part: BasePart,
    intersectionLocal: Vector3,
    planeAxis: number,
    padding: number
): boolean
    local half = part.Size * 0.5
    local verticalAxis = GetDominantLocalAxisForWorldAxis(part, Vector3.yAxis)
    for axis = 1, 3 do
        if axis == planeAxis then
            continue
        end
        local coord = GetVectorAxisValue(intersectionLocal, axis)
        local axisHalf = GetVectorAxisValue(half, axis)
        if axis == verticalAxis then
            -- Field goals are valid above the crossbar as long as they stay between the uprights.
            if coord < (-axisHalf - padding) then
                return false
            end
        elseif math.abs(coord) > (axisHalf + padding) then
            return false
        end
    end
    return true
end

local function ClassifySegmentGoalPlaneCross(
    part: BasePart,
    fromPos: Vector3,
    toPos: Vector3,
    padding: number
): string?
    local intersectionLocal, planeAxis = GetSegmentPartPlaneIntersectionLocal(part, fromPos, toPos)
    if not intersectionLocal or not planeAxis then
        return nil
    end
    if IsGoalPlaneIntersectionInsidePart(part, intersectionLocal, planeAxis, padding) then
        return "goal"
    end
    return "miss"
end

local function GetGoalPlaneBallPadding(ball: BasePart): number
    local largestAxis = math.max(ball.Size.X, ball.Size.Y, ball.Size.Z)
    return math.max(largestAxis * 0.5, 0.5)
end

local function GetBallPositionAtFlightTime(
    physicsData: {SpawnPos: Vector3, Target: Vector3, Power: number, CurveFactor: number?},
    flightTime: number
): Vector3
    return Utility.GetPositionAtTime(
        flightTime,
        physicsData.SpawnPos,
        physicsData.Target,
        physicsData.Power,
        physicsData.CurveFactor
    )
end

local function ClassifyExtraPointFieldGoalCross(
    goalPart: BasePart,
    physicsData: {LaunchTime: number, SpawnPos: Vector3, Target: Vector3, Power: number, CurveFactor: number?},
    fromFlightTime: number,
    toFlightTime: number,
    padding: number
): string?
    local distance = (physicsData.Target - physicsData.SpawnPos).Magnitude
    if physicsData.Power <= 0 or distance <= 1e-4 then
        return nil
    end
    local timeToTarget = distance / physicsData.Power
    local startTime = math.clamp(math.min(fromFlightTime, toFlightTime), 0, timeToTarget)
    local endTime = math.clamp(math.max(fromFlightTime, toFlightTime), 0, timeToTarget)
    local deltaTime = endTime - startTime
    if deltaTime <= 1e-4 then
        return nil
    end

    local goalPlaneX = goalPart.Position.X
    local goalCenterZ = goalPart.Position.Z
    local lateralHalf = GetWorldAxisExtent(goalPart, Vector3.zAxis)
    local verticalHalf = GetWorldAxisExtent(goalPart, Vector3.yAxis)
    local minGoalY = goalPart.Position.Y - verticalHalf - padding

    local samples = math.clamp(
        math.ceil(deltaTime / EXTRA_POINT_GOAL_SAMPLE_STEP_TIME),
        2,
        EXTRA_POINT_GOAL_MAX_SAMPLES
    )
    local previousSample = GetBallPositionAtFlightTime(physicsData, startTime)
    for index = 1, samples do
        local alpha = index / samples
        local sampleTime = startTime + (deltaTime * alpha)
        local currentSample = GetBallPositionAtFlightTime(physicsData, sampleTime)
        if DidSegmentEnterPart(goalPart, previousSample, currentSample) then
            return "goal"
        end
        local intersection = GetSegmentAxisPlaneIntersection(previousSample, currentSample, 1, goalPlaneX)
        if intersection then
            if math.abs(intersection.Z - goalCenterZ) <= (lateralHalf + padding) and intersection.Y >= minGoalY then
                return "goal"
            end
            return "miss"
        end
        previousSample = currentSample
    end
    return nil
end

local function IsBallPart(part: BasePart?): boolean
    if not part then
        return false
    end
    local ball = FTBallService:GetBallInstance()
    if not ball then
        return false
    end
    return part == ball or part:IsDescendantOf(ball)
end

local function FinalizeExtraPoint(nextTeam: number?, yardRelative: number?): ()
    StopTouchdownPause()
    FireExtraPointTransition()
    extraPointState.active = false
    extraPointState.stage = 0
    extraPointState.team = nil
    extraPointState.kicker = nil
    extraPointState.goalScored = false
    extraPointState.ballInPlay = false
    extraPointState.pending = false
    extraPointState.token += 1
    extraPointResultLocked = false
    extraPointLastBallPosition = nil
    extraPointLastBallFlightTime = nil
    extraPointFailurePending = false
    for player, speed in extraPointStoredSpeeds do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        player:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
        if character then
            character:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
        end
        if humanoid then
            humanoid.WalkSpeed = FlowBuffs.ResolveRestoredWalkSpeed(player, speed, 16)
            local jumpData = extraPointStoredJumps[player]
            if jumpData then
                humanoid.UseJumpPower = jumpData.useJumpPower
                humanoid.JumpPower = jumpData.jumpPower
                humanoid.JumpHeight = jumpData.jumpHeight
            end
            local autoRotate = extraPointStoredAutoRotate[player]
            if autoRotate ~= nil then
                humanoid.AutoRotate = autoRotate
            end
        end
        extraPointStoredSpeeds[player] = nil
        extraPointStoredJumps[player] = nil
        extraPointStoredAutoRotate[player] = nil
    end
    for player, jumpData in extraPointStoredJumps do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.UseJumpPower = jumpData.useJumpPower
            humanoid.JumpPower = jumpData.jumpPower
            humanoid.JumpHeight = jumpData.jumpHeight
        end
        extraPointStoredJumps[player] = nil
    end
    for player, autoRotate in extraPointStoredAutoRotate do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.AutoRotate = autoRotate
        end
        extraPointStoredAutoRotate[player] = nil
    end

    for _, p in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(p) then
            p:SetAttribute(ATTR_CAN_SPIN, true)
            local c = p.Character
            if c then
                c:SetAttribute(ATTR_CAN_SPIN, true)
            end
        end
    end

    FTGameService:SetInvulnerable(false)
    FTGameService:SetExtraPointActive(false)
    FTBallService:SetExtraPointActive(false)
    extraPointTransitionFired = false
    if nextTeam and yardRelative then
        local yard = RelativeToAbsoluteYard(yardRelative, nextTeam)
        FTGameService:BeginSeriesAtYard(yard, nextTeam)
        if FTGameService.SuppressTeleportFade then
            FTGameService:SuppressTeleportFade(2)
        end
        FTGameService:TeleportPlayersToYard(yard)

        for _, p in Players:GetPlayers() do
            if FTPlayerService:IsPlayerInMatch(p) then
                ClearTeleportStun(p)
                ResetPlayerPhysics(p)
                local c = p.Character
                local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
                if r then
                    r.Anchored = false
                end
            end
        end
        local runner = SelectRandomPlayer(nextTeam)
        if not runner then
            local fallbackTeam = nextTeam == 1 and 2 or 1
            runner = SelectRandomPlayer(fallbackTeam)
        end
        if runner then
            FTBallService:GiveBallToPlayer(runner)
        end
        FTGameService:StartCountdown(true)
    end
end
local function HandleExtraPointSuccess(): ()
    local team = extraPointState.team
    if not team then
        return
    end

    extraPointFailurePending = false
    extraPointResultLocked = true
    Packets.ExtraPointResult:Fire(true)
    FTGameService:AwardFieldGoal(team)
    local nextTeam = team == 1 and 2 or 1
    local token = extraPointState.token
    task.delay(EXTRA_POINT_SUCCESS_TRANSITION_DELAY, function()
        if extraPointState.token ~= token or not extraPointState.active then
            return
        end
        FinalizeExtraPoint(nextTeam, 50)
    end)
end

local function HandleExtraPointFailure(reason: string?): ()
    local team = extraPointState.team
    if not team then
        return
    end

    extraPointFailurePending = false
    extraPointResultLocked = true
    Packets.ExtraPointResult:Fire(false)
    ScheduleExtraPointTransition(EXTRA_POINT_MISS_TRANSITION_DELAY)
    local nextTeam = team == 1 and 2 or 1
    local token = extraPointState.token
    task.delay(EXTRA_POINT_MISS_TRANSITION_DELAY + EXTRA_POINT_FINALIZE_DELAY_AFTER_RESULT, function()
        if extraPointState.token ~= token or not extraPointState.active then
            return
        end
        FinalizeExtraPoint(nextTeam, 60)
    end)
end

local function ScheduleExtraPointFailure(reason: string?, delayTime: number?): ()
    if not extraPointState.active or extraPointResultLocked or extraPointFailurePending then
        return
    end

    extraPointFailurePending = true
    local token = extraPointState.token
    task.delay(math.max(delayTime or 0, 0), function()
        if extraPointState.token ~= token or not extraPointState.active or extraPointResultLocked then
            return
        end

        HandleExtraPointFailure(reason)
    end)
end

local function StartExtraPointSequence(team: number): ()
    StopTouchdownPause()
    if extraPointState.active then
        return
    end
    extraPointState.pending = false
    local kicker = SelectRandomPlayer(team)
    if not kicker then
        FTBallService:SetExtraPointActive(false)
        local opponent = team == 1 and 2 or 1
        local yard = RelativeToAbsoluteYard(50, opponent)
        FTGameService:BeginSeriesAtYard(yard, opponent)
        if FTGameService.SuppressTeleportFade then
            FTGameService:SuppressTeleportFade(2)
        end
        FTGameService:TeleportPlayersToYard(yard)
        local runner = SelectRandomPlayer(opponent)
        if runner then
            FTBallService:GiveBallToPlayer(runner)
        end
        FTGameService:StartCountdown(true)
        return
    end
    extraPointState.active = true
    extraPointState.stage = 1
    extraPointState.team = team
    extraPointState.kicker = kicker
    extraPointState.token += 1
    extraPointState.goalScored = false
    extraPointState.ballInPlay = false
    extraPointResultLocked = false
    extraPointLastBallPosition = nil
    extraPointLastBallFlightTime = nil
    extraPointTransitionFired = false
    extraPointFailurePending = false

    FTGameService:SetInvulnerable(true)
    FTGameService:SetExtraPointActive(true)
    FTBallService:SetExtraPointActive(true)

    for _, p in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(p) then
            p:SetAttribute(ATTR_CAN_SPIN, false)
            p:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
            local c = p.Character
            if c then
                c:SetAttribute(ATTR_CAN_SPIN, false)
                c:SetAttribute(ATTR_EXTRA_POINT_FROZEN, false)
            end
        end
    end
    local token = extraPointState.token
    for _, player in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(player) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if extraPointStoredSpeeds[player] == nil then
                    extraPointStoredSpeeds[player] = humanoid.WalkSpeed
                end
                if extraPointStoredJumps[player] == nil then
                    extraPointStoredJumps[player] = {
                        jumpPower = humanoid.JumpPower,
                        jumpHeight = humanoid.JumpHeight,
                        useJumpPower = humanoid.UseJumpPower,
                    }
                end
                if extraPointStoredAutoRotate[player] == nil then
                    extraPointStoredAutoRotate[player] = humanoid.AutoRotate
                end
            end
            ClearTeleportStun(player)
            ResetPlayerPhysics(player)

            player:SetAttribute(ATTR_CAN_SPIN, false)
            local c = player.Character
            if c then
                c:SetAttribute(ATTR_CAN_SPIN, false)
            end
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local storedAutoRotate = extraPointStoredAutoRotate[player]
                if storedAutoRotate ~= nil then
                    humanoid.AutoRotate = storedAutoRotate
                end
            end
        end
    end
    if EXTRA_POINT_TELEPORT_DELAY > 0 then
        task.wait(EXTRA_POINT_TELEPORT_DELAY)
        if extraPointState.token ~= token or not extraPointState.active then
            return
        end
    end
    FreezePlayerForTeleport(kicker, 0.35)
    local yard = RelativeToAbsoluteYard(82, team)
    FTGameService:BeginSeriesAtYard(yard, team)
    if FTGameService.SuppressTeleportFade then
        FTGameService:SuppressTeleportFade(2)
    end
    local formationPlanResolved = false
    local formationTargets: ExtraPointTeleportPlan? = nil
    local fallbackKickerTarget: CFrame? = nil
    local function ApplyFormationWithFallback(onlyIfNeeded: boolean): boolean
        if not formationPlanResolved then
            formationPlanResolved = true
            local _teleportedAny, builtTargets = ApplyExtraPointFormation(team, kicker, false)
            if builtTargets then
                formationTargets = builtTargets
                return true
            end
        elseif formationTargets then
            return ApplyTeleportPlan(formationTargets, onlyIfNeeded)
        end

        if onlyIfNeeded and fallbackKickerTarget and IsPlayerAtTeleportTarget(kicker, fallbackKickerTarget) then
            return false
        end
        if FTGameService.SuppressTeleportFade then
            FTGameService:SuppressTeleportFade(2)
        end
        FTGameService:TeleportPlayersToYard(yard, true)
        if kicker.Character then
            local customPart = GetCustomPositionPart(team, "SUS")
            if customPart then
                fallbackKickerTarget = customPart.CFrame
                if not onlyIfNeeded or not IsPlayerAtTeleportTarget(kicker, fallbackKickerTarget) then
                    AnchorTeleport(kicker, fallbackKickerTarget)
                end
            end
        end
        return true
    end
    ApplyFormationWithFallback(false)

    local function ApplyPostTeleportFreeze(): ()
        for _, player in Players:GetPlayers() do
            if FTPlayerService:IsPlayerInMatch(player) then
                player:SetAttribute(ATTR_EXTRA_POINT_FROZEN, true)
                local character = player.Character
                if character then
                    character:SetAttribute(ATTR_EXTRA_POINT_FROZEN, true)
                end
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    if extraPointStoredSpeeds[player] == nil then
                        extraPointStoredSpeeds[player] = humanoid.WalkSpeed
                    end
                    if extraPointStoredJumps[player] == nil then
                        extraPointStoredJumps[player] = {
                            jumpPower = humanoid.JumpPower,
                            jumpHeight = humanoid.JumpHeight,
                            useJumpPower = humanoid.UseJumpPower,
                        }
                    end
                    if extraPointStoredAutoRotate[player] == nil then
                        extraPointStoredAutoRotate[player] = humanoid.AutoRotate
                    end
                    humanoid.WalkSpeed = 0
                    humanoid.UseJumpPower = true
                    humanoid.JumpPower = 0
                    humanoid.JumpHeight = 0
                    humanoid.AutoRotate = false
                    humanoid:Move(Vector3.zero, false)
                end
                local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root then
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
                player:SetAttribute(ATTR_CAN_SPIN, false)
                if character then
                    character:SetAttribute(ATTR_CAN_SPIN, false)
                end
            end
        end
    end

    ApplyPostTeleportFreeze()
    task.spawn(function()
        while extraPointState.active and extraPointState.token == token do
            ApplyPostTeleportFreeze()
            task.wait(0.15)
        end
    end)

    for _, p in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(p) then
            local character = p.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if extraPointStoredSpeeds[p] == nil then
                    extraPointStoredSpeeds[p] = humanoid.WalkSpeed
                end
                if extraPointStoredJumps[p] == nil then
                    extraPointStoredJumps[p] = {
                        jumpPower = humanoid.JumpPower,
                        jumpHeight = humanoid.JumpHeight,
                        useJumpPower = humanoid.UseJumpPower,
                    }
                end
                humanoid.WalkSpeed = 0
                humanoid.UseJumpPower = true
                humanoid.JumpPower = 0
                humanoid.JumpHeight = 0
                humanoid.AutoRotate = false
                humanoid:Move(Vector3.zero, false)
                p:SetAttribute(ATTR_CAN_SPIN, false)
                p:SetAttribute(ATTR_EXTRA_POINT_FROZEN, true)
                if character then
                    character:SetAttribute(ATTR_CAN_SPIN, false)
                    character:SetAttribute(ATTR_EXTRA_POINT_FROZEN, true)
                end
            end
        end
    end
    if FTPlayerService.StopPlayerAnimation then
        FTPlayerService:StopPlayerAnimation(kicker)
    end
    local fgDesc = string.format("+%d POINTS", FTConfig.GAME_CONFIG.FieldGoalPoints)
    Packets.ScoreNotify:Fire("FIELD GOAL!", fgDesc, SCORE_NOTIFY_DURATION)
    FTBallService:PositionBallForExtraPoint(kicker, team)

    local seqToken = extraPointState.token
    task.delay(SCORE_NOTIFY_DURATION, function()
        if extraPointState.token ~= seqToken or not extraPointState.active then
            return
        end
        FTBallService:PositionBallForExtraPoint(kicker, team)
        Packets.ExtraPointStart:Fire(0, team)
        Packets.ExtraPointPreCam:Fire(PlayerIdentity.GetIdValue(kicker), EXTRA_POINT_SETUP_DURATION, "front")
    end)

    local seqToken2 = extraPointState.token
    task.delay(SCORE_NOTIFY_DURATION + EXTRA_POINT_SETUP_DURATION, function()
        if extraPointState.token ~= seqToken2 or not extraPointState.active then
            return
        end
        FTGameService:SetInvulnerable(false)
        extraPointState.stage = 2
        extraPointState.ballInPlay = false
        FTBallService:PositionBallForExtraPoint(kicker, team)
        Packets.ExtraPointStart:Fire(1, team)
    end)
end

local function OnEndzoneEntry(player: Player, zoneTeam: number): ()
    if not player then
        return
    end
    local ballState = FTBallService:GetBallState()
    local carrier = ballState and ballState:GetPossession()
    if carrier ~= player then
        return
    end
    if extraPointState.active then
        return
    end
    if extraPointState.pending then
        return
    end
    local playerTeam = FTPlayerService:GetPlayerTeam(player)
    if not playerTeam then
        return
    end
    if playerTeam == zoneTeam then
        return
    end
    FTGameService:SetInvulnerable(true)
    extraPointState.pending = true
    extraPointState.pendingToken += 1
    local pendingToken = extraPointState.pendingToken
    local landingResolved = false
    local showcaseWindowFinished = false
    local preCamStarted = false
    local function TryStartPreCam(): ()
        if preCamStarted or not landingResolved or not showcaseWindowFinished then
            return
        end
        if not extraPointState.pending or extraPointState.pendingToken ~= pendingToken then
            return
        end

        preCamStarted = true
        Packets.ExtraPointPreCam:Fire(
            PlayerIdentity.GetIdValue(player),
            TOUCHDOWN_POST_SHOWCASE_CAM_DURATION,
            "behind"
        )

        task.delay(TOUCHDOWN_POST_SHOWCASE_CAM_DURATION, function()
            if not preCamStarted then
                return
            end
            if not extraPointState.pending or extraPointState.pendingToken ~= pendingToken then
                return
            end

            extraPointState.pending = false
            StartExtraPointSequence(playerTeam)
        end)
    end
    local function StartTouchdownPauseAfterLanding(): ()
        if landingResolved then
            return
        end
        landingResolved = true

        if not extraPointState.pending or extraPointState.pendingToken ~= pendingToken then
            return
        end

        -- Keep the play paused through the showcase and pre-cam, but leave
        -- movement free until the extra-point formation actually begins.
        SetTouchdownPauseWindowActive(true)
        TryStartPreCam()
    end

    local scorerLandingTracked = ApplyTouchdownImpact(player)
    PlayerStatsTracker.AwardTouchdown(player)
    FireTouchdownShowcase(player)
    if scorerLandingTracked then
        StartTouchdownPauseAfterLanding()
    else
        task.delay(TOUCHDOWN_PAUSE_FALLBACK_DELAY, function()
            StartTouchdownPauseAfterLanding()
        end)
    end
    task.delay(TOUCHDOWN_PRE_CAM_DELAY, function()
        if not extraPointState.pending or extraPointState.pendingToken ~= pendingToken then
            return
        end

        showcaseWindowFinished = true
        TryStartPreCam()
    end)
    task.spawn(function()
        FTGameService:AwardTouchdown(playerTeam)
    end)
end

local function OnGoalPartEntered(part: BasePart, goalTeam: number): ()
    local isBall = IsBallPart(part)
    if not extraPointState.active or extraPointResultLocked then
        return
    end
    if not isBall then
        return
    end
    extraPointState.goalScored = true
    HandleExtraPointSuccess()
end

local function OnPlayEnd(position: Vector3, reason: string?, lastInBoundsX: number?, throwOriginX: number?, throwTeam: number?): ()
    if not extraPointState.active or extraPointResultLocked then
        return
    end
    ScheduleExtraPointFailure(reason, ResolveExtraPointMissDelay(EXTRA_POINT_MISS_TRANSITION_DELAY))
end

local function SetupZones(): ()
    local gameFolder = Workspace:FindFirstChild("Game") or Workspace:WaitForChild("Game", 5)
    if not gameFolder then
        return
    end
    local endzones = gameFolder:FindFirstChild("Endzones")
    if endzones then
        for team = 1, 2 do
            local part = GetPrimaryPart(endzones:FindFirstChild("Team" .. team))
            if part then
                local zone = ZonePlus.new(part)
                zone.playerEntered:Connect(function(player)
                    OnEndzoneEntry(player, team)
                end)
                endzoneZones[team] = zone
            end
        end
    end
    local goals = gameFolder:FindFirstChild("Goal")
    if goals then
        for team = 1, 2 do
            local part = GetGoalPartForTeam(team)
            if part then
                local zone = ZonePlus.new(part)
                zone.partEntered:Connect(function(partEntered)
                    OnGoalPartEntered(partEntered, team)
                end)
                goalZones[team] = zone
            end
        end
    end
end

function FTScoringService.Init(_self: typeof(FTScoringService)): ()
    SetupZones()
    FTBallService:SetPlayEndCallback(OnPlayEnd)
    FTBallService:SetGoalTouchCallback(function(goalTeam: number, _part: BasePart)
        if not extraPointState.active or extraPointResultLocked then
            return
        end
        extraPointState.goalScored = true
        HandleExtraPointSuccess()
    end)
end

function FTScoringService.Start(_self: typeof(FTScoringService)): ()
    RunService.Heartbeat:Connect(function()
        if not extraPointState.active or extraPointResultLocked then
            return
        end

        local kicker = extraPointState.kicker
        if not kicker or kicker.Parent == nil or not FTPlayerService:IsPlayerInMatch(kicker) then
            HandleExtraPointFailure("KickerUnavailable")
            return
        end

        if extraPointState.stage < 2 then
            return
        end
        local ballState = FTBallService:GetBallState()
        if not ballState then
            return
        end
        if ballState:IsInAir() then
            extraPointState.ballInPlay = true
        end
        if extraPointState.ballInPlay and ballState:IsInAir() == false then
            if ballState:GetPossession() ~= nil then
                EndExtraPointKeepLive()
                return
            end
            ScheduleExtraPointFailure("MissedGoal", ResolveExtraPointMissDelay(EXTRA_POINT_MISS_TRANSITION_DELAY))
            return
        end
    end)
end

return FTScoringService

