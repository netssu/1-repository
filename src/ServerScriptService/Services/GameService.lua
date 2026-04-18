--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local Signal = require(ReplicatedStorage.Packages.Signal)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local FTBallService = require(script.Parent.BallService)
local FTFlowService = require(script.Parent.FlowService)
local FTPlayerService = require(script.Parent.PlayerService)
local FTRefereeService = require(script.Parent.RefereeService)
local FTSkillService = require(script.Parent.SkillService)
local FTSpinService = require(script.Parent.SpinService)
local ZonePlus = require(ReplicatedStorage.Packages.ZonePlus)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)
local MatchIntroConfig = require(ReplicatedStorage.Modules.Game.MatchIntroConfig)
local MatchCutsceneLock = require(ServerScriptService.Skills.Utils.MatchCutsceneLock)

local FTGameService = {}
local MatchEndedSignal = Signal.new()
local COUNTDOWN_DURATION: number = 5
local START_COUNTDOWN_DURATION: number = 10

local COUNTDOWN_RELEASE_DELAY: number = 1.6
local DEBUG_TELEPORT_TRACE: boolean = false
local DEBUG_TELEPORT_DURATION: number = 6.0
local DEBUG_TELEPORT_INTERVAL: number = 0.25
local EXTRA_POINT_UPRIGHT_DURATION: number = 1.5
local TELEPORT_UPRIGHT_DURATION: number = 0.8
local TELEPORT_FADE_DURATION: number = 0.35
local TELEPORT_FADE_COOLDOWN: number = 0.3
local TELEPORT_GROUND_CHECK_HEIGHT: number = 12
local TELEPORT_GROUND_CHECK_DISTANCE: number = 128
local TELEPORT_GROUND_CLEARANCE: number = 0.05
local TELEPORT_ROOT_OFFSET_AIR_TOLERANCE: number = 3
local SCORE_NOTIFY_DURATION: number = 2.4
local DOWN_NOTIFY_DURATION: number = 1.6
local INCOMPLETE_PASS_LOSS_YARDS: number = 10
local LINE_POSITIONS_CLONE_NAME: string = "PositionsLineClone"
local LOS_VISIBLE_TRANSPARENCY: number = 0.3
local LOS_HIDDEN_TRANSPARENCY: number = 1
local MATCH_INTRO_END_TIME: number = MatchIntroConfig.FINISH_TIME
local MATCH_INTRO_LOCK_DURATION: number = MatchIntroConfig.LOCK_DURATION
local MATCH_INTRO_ACK_TIMEOUT: number = MatchIntroConfig.ACK_TIMEOUT
local MATCH_INTRO_TELEPORT_FADE_BUFFER: number = 2
local MATCH_INTRO_ACK_POLL_INTERVAL: number = 0.05
local MATCH_INTRO_LATE_REPLAY_GRACE_TIME: number = 2
local DEFAULT_SERIES_START_YARD: number = 50
local DEFAULT_POSSESSING_TEAM: number = 1
local DEFAULT_PLAYER_WALK_SPEED: number = 16
local DEFAULT_PLAYER_JUMP_POWER: number = 50
local DEFAULT_PLAYER_JUMP_HEIGHT: number = 7.2
local LEAVE_MATCH_REQUEST_COOLDOWN: number = 1

local ATTRIBUTE_NAMES = {
    FacingGoal = "FTFacingGoalTeam",
    Invulnerable = "Invulnerable",
    TouchdownPause = "FTScoringPauseLocked",
    CanAct = "FTCanAct",
    CanThrow = "FTCanThrow",
    CanSpin = "FTCanSpin",
    Stunned = "FTStunned",
    SkillLocked = "FTSkillLocked",
    AwakenReady = "AwakenReady",
    AwakenActive = "AwakenActive",
    AwakenCutsceneActive = "FTAwakenCutsceneActive",
    PerfectPassCutsceneLocked = "FTPerfectPassCutsceneLocked",
    MatchCutsceneLocked = "FTMatchCutsceneLocked",
    CutsceneHudHidden = "FTCutsceneHudHidden",
}
local SAFETY_POINTS: number = 2
local pendingCountdownToken: number = 0
local lastDownCarrier: Player? = nil
local lastPlayGain: number = 0
local playEndLocked: boolean = false
local cachedTeleportRootOffsets: {[Model]: number} =
    setmetatable({}, { __mode = "k" }) :: {[Model]: number}
local GetTeamSide: (team: number) -> string

type CountdownFreezeState = {
    Character: Model,
    Humanoid: Humanoid,
    Root: BasePart,
    WalkSpeedBefore: number,
    UseJumpPowerBefore: boolean,
    JumpPowerBefore: number,
    JumpHeightBefore: number,
    AutoRotateBefore: boolean,
    PlatformStandBefore: boolean,
}

local uprightTokens: {[Player]: number} = {}
local countdownStoredSpeeds: {[Player]: number} = {}
local countdownFreezeStates: {[Player]: CountdownFreezeState} = {}
local countdownCharacterConnections: {[Player]: RBXScriptConnection} = {}
local countdownToken: number = 0
local lastTeleportFade: number = 0
local teleportFadeSuppressedUntil: number = 0
local preMatchSequenceToken: number = 0
local preMatchSequenceActive: boolean = false
local introCutsceneLock = MatchCutsceneLock.new()
local introFinishAcks: {[number]: {[Player]: boolean}} = {}
local introFinishResolvers: {[number]: () -> ()} = {}
local activeIntroToken: number? = nil
local activeIntroPayload: {[string]: any}? = nil
local activeIntroRecipients: {[Player]: boolean} = {}
local activeIntroStartedAt: number = 0
local leaveMatchRequestCooldowns: {[Player]: number} = {}
local CachedTackleService: any = nil
local TackleServiceResolved: boolean = false

local GetPlayersInMatch

local function GetOrCreateValue(parent: Instance, name: string, className: string): Instance
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end

    local created = Instance.new(className)
    created.Name = name
    created.Parent = parent
    return created
end

local function ResetPlayerTeamValues(gameStateFolder: Folder): ()
    for _, child in gameStateFolder:GetChildren() do
        if child:IsA("IntValue") and string.sub(child.Name, 1, #"PlayerTeam_") == "PlayerTeam_" then
            child.Value = 0
        end
    end
end

local function SetInvulnerableForMatch(value: boolean): ()
    for _, player in GetPlayersInMatch() do
        player:SetAttribute(ATTRIBUTE_NAMES.Invulnerable, value)
        local character = player.Character
        if character then
            character:SetAttribute(ATTRIBUTE_NAMES.Invulnerable, value)
        end
    end
end

local function GetTackleService(): any
    if TackleServiceResolved then
        return CachedTackleService
    end

    TackleServiceResolved = true
    local ModuleScript = script.Parent:FindFirstChild("TackleService")
    if not ModuleScript or not ModuleScript:IsA("ModuleScript") then
        return nil
    end

    local Success: boolean, Result: any = pcall(require, ModuleScript)
    if not Success then
        warn(string.format("FTGameService: failed to resolve TackleService for leave-match reset: %s", tostring(Result)))
        return nil
    end

    CachedTackleService = Result
    return CachedTackleService
end

local function SetPlayerAndCharacterAttribute(Player: Player, AttributeName: string, Value: any): ()
    Player:SetAttribute(AttributeName, Value)
    local Character = Player.Character
    if Character then
        Character:SetAttribute(AttributeName, Value)
    end
end

local function ResetPlayerMovementState(Player: Player): ()
    local Character = Player.Character
    if not Character then
        return
    end

    local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if Root then
        Root.Anchored = false
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end

    local HumanoidInstance = Character:FindFirstChildOfClass("Humanoid")
    if not HumanoidInstance then
        return
    end

    FlowBuffs.ApplyHumanoidWalkSpeed(Player, HumanoidInstance, DEFAULT_PLAYER_WALK_SPEED)
    HumanoidInstance.UseJumpPower = true
    HumanoidInstance.JumpPower = DEFAULT_PLAYER_JUMP_POWER
    HumanoidInstance.JumpHeight = DEFAULT_PLAYER_JUMP_HEIGHT
    HumanoidInstance.AutoRotate = true
    HumanoidInstance.PlatformStand = false
    HumanoidInstance.Sit = false
end

local function ResetPlayerTransientMatchState(Player: Player): ()
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.Invulnerable, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.CanAct, true)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.CanThrow, true)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.CanSpin, true)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.Stunned, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.SkillLocked, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.AwakenReady, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.AwakenActive, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.AwakenCutsceneActive, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.PerfectPassCutsceneLocked, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.MatchCutsceneLocked, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.CutsceneHudHidden, false)
    SetPlayerAndCharacterAttribute(Player, ATTRIBUTE_NAMES.FacingGoal, 0)
    ResetPlayerMovementState(Player)
end

local function ClearActiveIntroState(Token: number?): ()
    if Token ~= nil and activeIntroToken ~= Token then
        return
    end

    activeIntroToken = nil
    activeIntroPayload = nil
    activeIntroStartedAt = 0
    table.clear(activeIntroRecipients)
end

local function CanPlayerLeaveMatch(Player: Player): boolean
    if FTPlayerService:IsPlayerInMatch(Player) then
        return true
    end
    if FTPlayerService.GetPlayerTeam and FTPlayerService:GetPlayerTeam(Player) ~= nil then
        return true
    end
    if FTPlayerService.GetPlayerPosition and FTPlayerService:GetPlayerPosition(Player) ~= nil then
        return true
    end
    return false
end

local function FreezePlayersForDownNotify(): ()
    for _, player in GetPlayersInMatch() do
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local prev = humanoid.WalkSpeed
            if prev <= 0 then
                prev = 16
            end
            if countdownStoredSpeeds[player] == nil then
                countdownStoredSpeeds[player] = prev
            end
            humanoid.WalkSpeed = 0
        end
    end
end

local function DebugTeleportTrace(player: Player, label: string): ()
    if not DEBUG_TELEPORT_TRACE then return end
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end
    local startTime = os.clock()
    task.spawn(function()
        while os.clock() - startTime <= DEBUG_TELEPORT_DURATION do
            if not root.Parent then break end
            local pos = root.Position
            local look = root.CFrame.LookVector
            local orient = root.Orientation
            print(("[TELEPORT TRACE] %s player=%s pos=(%.2f, %.2f, %.2f) look=(%.2f, %.2f, %.2f) orient=(%.2f, %.2f, %.2f)"):format(
                label,
                player.Name,
                pos.X, pos.Y, pos.Z,
                look.X, look.Y, look.Z,
                orient.X, orient.Y, orient.Z
            ))
            task.wait(DEBUG_TELEPORT_INTERVAL)
        end
    end)
end

local function FormatDebugVector3(value: Vector3): string
    return ("(%.2f, %.2f, %.2f)"):format(value.X, value.Y, value.Z)
end

local function ResolveTeleportForward(targetCFrame: CFrame): Vector3
    local planarForward = Vector3.new(targetCFrame.LookVector.X, 0, targetCFrame.LookVector.Z)
    if planarForward.Magnitude <= 1e-4 then
        return Vector3.new(0, 0, -1)
    end

    return planarForward.Unit
end

local function GetCampo(): Instance?
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then
        return nil
    end

    return gameFolder:FindFirstChild("Campo")
end

local function GetCampoPlaneY(campo: Instance): number?
    if campo:IsA("BasePart") then
        return campo.Position.Y + (campo.Size.Y * 0.5)
    end

    if campo:IsA("Model") then
        local cf, size = campo:GetBoundingBox()
        return cf.Position.Y + (size.Y * 0.5)
    end

    return nil
end

local function GetTeleportGroundY(position: Vector3): number?
    local campo = GetCampo()
    if not campo then
        return nil
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { campo }
    params.IgnoreWater = true

    local rayOrigin = position + Vector3.new(0, TELEPORT_GROUND_CHECK_HEIGHT, 0)
    local rayDirection = Vector3.new(0, -TELEPORT_GROUND_CHECK_DISTANCE, 0)
    local result = Workspace:Raycast(rayOrigin, rayDirection, params)
    if result then
        return result.Position.Y
    end

    return GetCampoPlaneY(campo)
end

local function ResolveTeleportRootGroundOffset(character: Model): number?
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then
        return nil
    end

    local baseOffset = (root.Size.Y * 0.5) + math.max(humanoid.HipHeight, 0)
    local cachedOffset = cachedTeleportRootOffsets[character]
    local groundY = GetTeleportGroundY(root.Position)
    local isGrounded = humanoid.FloorMaterial ~= Enum.Material.Air
    if groundY ~= nil and isGrounded then
        local measuredOffset = root.Position.Y - groundY
        local maxMeasuredOffset = baseOffset + math.max(TELEPORT_ROOT_OFFSET_AIR_TOLERANCE, root.Size.Y)
        if measuredOffset > 0.25 and measuredOffset <= maxMeasuredOffset then
            local resolvedOffset = math.max(measuredOffset, baseOffset)
            cachedTeleportRootOffsets[character] = resolvedOffset
            return resolvedOffset
        end
    end

    if cachedOffset ~= nil and cachedOffset > 0 then
        return math.max(cachedOffset, baseOffset)
    end

    local lowestBodyY = math.huge
    for _, partName in {
        "LeftFoot",
        "RightFoot",
        "LeftLowerLeg",
        "RightLowerLeg",
        "Left Leg",
        "Right Leg",
        "LowerTorso",
        "Torso",
    } do
        local part = character:FindFirstChild(partName, true)
        if part and part:IsA("BasePart") then
            lowestBodyY = math.min(lowestBodyY, part.Position.Y - (part.Size.Y * 0.5))
        end
    end
    if lowestBodyY < math.huge then
        local rigOffset = root.Position.Y - lowestBodyY
        if rigOffset > 0.25 then
            local resolvedOffset = math.max(rigOffset, baseOffset)
            cachedTeleportRootOffsets[character] = resolvedOffset
            return resolvedOffset
        end
    end

    return baseOffset
end

local function ResolveGroundedTeleportCFrameForCharacter(character: Model, targetCFrame: CFrame): CFrame
    local groundY = GetTeleportGroundY(targetCFrame.Position)
    local rootGroundOffset = ResolveTeleportRootGroundOffset(character)
    if groundY == nil or rootGroundOffset == nil then
        return targetCFrame
    end

    local groundedPosition = Vector3.new(
        targetCFrame.Position.X,
        groundY + rootGroundOffset + TELEPORT_GROUND_CLEARANCE,
        targetCFrame.Position.Z
    )
    local forward = ResolveTeleportForward(targetCFrame)
    return CFrame.lookAt(groundedPosition, groundedPosition + forward, Vector3.yAxis)
end

local function DebugPositionTeleport(message: string): ()
    if not DEBUG_TELEPORT_TRACE then return end
    print("[DEBUG][FTGameService][Teleport] " .. message)
end

local function EnforceUpright(player: Player, forward: Vector3, duration: number): ()
    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not root then return end

    local flatForward = Vector3.new(forward.X, 0, forward.Z)
    if flatForward.Magnitude < 1e-4 then
        flatForward = Vector3.new(0, 0, -1)
    else
        flatForward = flatForward.Unit
    end

    local token = (uprightTokens[player] or 0) + 1
    uprightTokens[player] = token

    task.spawn(function()
        local startTime = os.clock()
        while os.clock() - startTime <= duration do
            if uprightTokens[player] ~= token then
                break
            end
            if not root.Parent then
                break
            end
            local pos = root.Position
            root.CFrame = CFrame.lookAt(pos, pos + flatForward, Vector3.yAxis)
            root.AssemblyAngularVelocity = Vector3.zero
            task.wait()
        end
    end)
end

--\\ TYPES \\ -- TR
type GameState = {
    MatchActive: boolean,
    MatchStarted: boolean,
    Quarter: number,
    GameTime: number,
    PlayClock: number,
    Down: number,
    YardsToGain: number,
    LineOfScrimmage: number,
    SeriesStartYard: number,
    TargetYard: number,
    PossessingTeam: number,
    Team1Score: number,
    Team2Score: number,
    Team1Timeouts: number,
    Team2Timeouts: number,
    IntermissionActive: boolean,
    IntermissionTime: number,
    CountdownActive: boolean,
    CountdownTime: number,
    ExtraPointActive: boolean,
}

type MatchResult = {
    WinnerTeam: number?,
    Team1Score: number,
    Team2Score: number,
}

type GameStateInstances = {
    GameTime: IntValue?,
    IntermissionTime: IntValue?,
    Team1Score: IntValue?,
    Team2Score: IntValue?,
    IntermissionActive: BoolValue?,
    MatchEnabled: BoolValue?,
    MatchStarted: BoolValue?,
    CountdownTime: IntValue?,
    CountdownActive: BoolValue?,
    BallCarrier: ObjectValue?,
}

--\\ MODULE STATE \\ -- TR
local gameState: GameState = {
    MatchActive = false,
    MatchStarted = false,
    Quarter = 1,
    GameTime = FTConfig.GAME_CONFIG.QuarterDuration,
    PlayClock = FTConfig.GAME_CONFIG.PlayClockDuration,
    Down = 1,
    YardsToGain = FTConfig.GAME_CONFIG.DownsToGain,
    LineOfScrimmage = 0,
    SeriesStartYard = 50,
    TargetYard = 60,
    PossessingTeam = 1,
    Team1Score = 0,
    Team2Score = 0,
    Team1Timeouts = FTConfig.GAME_CONFIG.TimeoutsPerHalf,
    Team2Timeouts = FTConfig.GAME_CONFIG.TimeoutsPerHalf,
    IntermissionActive = true,
    IntermissionTime = FTConfig.GAME_CONFIG.IntermissionDuration,
    CountdownActive = false,
    CountdownTime = START_COUNTDOWN_DURATION,
    ExtraPointActive = false,
}

local gameStateInstances: GameStateInstances = {}
local matchFolder: Folder? = nil
local fieldAnchors = {startX = nil :: number?, endX = nil :: number?}
local losMarker: BasePart? = nil
local campoZone: any = nil
local endzoneZones: {[number]: any} = {}

local function GetFieldAnchors(): (number, number)
    if fieldAnchors.startX and fieldAnchors.endX then
        return fieldAnchors.startX, fieldAnchors.endX
    end
    local gameFolder = Workspace:FindFirstChild("Game")
    local yardFolder = gameFolder and gameFolder:FindFirstChild("Jardas")
    local g1 = yardFolder and yardFolder:FindFirstChild("GTeam1")
    local g2 = yardFolder and yardFolder:FindFirstChild("GTeam2")
    if g1 and g2 and g1:IsA("BasePart") and g2:IsA("BasePart") then
        fieldAnchors.startX = g1.Position.X
        fieldAnchors.endX = g2.Position.X
    else
        fieldAnchors.startX = 0
        fieldAnchors.endX = 100
    end
    return fieldAnchors.startX, fieldAnchors.endX
end

local function YardToX(yard: number): number
    local startX, endX = GetFieldAnchors()
    local t = math.clamp(yard, 0, 100) / 100
    return startX + (endX - startX) * t
end

local function XToYard(x: number): number
    local startX, endX = GetFieldAnchors()
    local length = endX - startX
    if math.abs(length) < 1e-5 then
        return 50
    end
    return math.clamp(((x - startX) / length) * 100, 0, 100)
end

local function GetTeamDirection(team: number): number
    return team == 1 and 1 or -1
end

local function ToRelativeYard(absoluteYard: number, team: number): number
    if team == 1 then
        return absoluteYard
    else
        return 100 - absoluteYard
    end
end

local function RelativeToAbsoluteYard(relative: number, team: number): number
    local clamped = math.clamp(relative, 0, 100)
    if team == 1 then
        return clamped
    end
    return 100 - clamped
end

local function GetReferencePlane(): (number, number)
    local gameFolder = Workspace:FindFirstChild("Game")
    local positionsFolder = gameFolder and gameFolder:FindFirstChild("Positions")
    if positionsFolder then
        for _, teamFolder in positionsFolder:GetChildren() do
            if teamFolder:IsA("Folder") then
                for _, part in teamFolder:GetChildren() do
                    if part:IsA("BasePart") then
                        local pos = part.Position
                        return pos.Y, pos.Z
                    end
                end
            end
        end
    end
    return 0, 0
end

local function GetCampoZone()
    if campoZone then return campoZone end
    local gameFolder = Workspace:FindFirstChild("Game")
    local zonePart = gameFolder and gameFolder:FindFirstChild("CampoZone")
    if zonePart and zonePart:IsA("BasePart") then
        campoZone = ZonePlus.new(zonePart)
    end
    return campoZone
end

local function GetLobbySpawnCFrame(): CFrame?
    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    if spawnLocation and spawnLocation:IsA("BasePart") then
        return spawnLocation.CFrame
    end

    local lobby = Workspace:FindFirstChild("Lobby")
    if not lobby then
        return nil
    end

    local spawn = lobby:FindFirstChild("Spawn")
    if spawn and spawn:IsA("BasePart") then
        return spawn.CFrame
    end
    if spawn and spawn:IsA("Model") then
        local primary = spawn.PrimaryPart or spawn:FindFirstChildWhichIsA("BasePart")
        if primary then
            return primary.CFrame
        end
    end

    return nil
end

local function SetPlacarText(placar: Instance?, text: string): ()
    if not placar then
        return
    end
    local surfaceGui = placar:FindFirstChildWhichIsA("SurfaceGui", true)
    if not surfaceGui then
        return
    end
    local frame = surfaceGui:FindFirstChild("Frame")
    if not frame then
        return
    end
    local textLabel = frame:FindFirstChildWhichIsA("TextLabel")
    if not textLabel then
        textLabel = frame:FindFirstChild("TextLabel")
    end
    if textLabel then
        textLabel.Text = text
    end
end

local function UpdateScoreboards(): ()
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then
        return
    end
    local placar1Text = ("%d - %d"):format(gameState.Team1Score, gameState.Team2Score)
    local placar2Text = ("%d - %d"):format(gameState.Team2Score, gameState.Team1Score)
    SetPlacarText(gameFolder:FindFirstChild("Placar1"), placar1Text)
    SetPlacarText(gameFolder:FindFirstChild("Placar2"), placar2Text)
end

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

local function GetEndzoneZone(team: number): any
    if endzoneZones[team] then
        return endzoneZones[team]
    end
    local gameFolder = Workspace:FindFirstChild("Game")
    local endzones = gameFolder and gameFolder:FindFirstChild("Endzones")
    if not endzones then
        return nil
    end
    local part = GetPrimaryPart(endzones:FindFirstChild("Team" .. team))
    if part then
        local zone = ZonePlus.new(part)
        endzoneZones[team] = zone
        return zone
    end
    return nil
end

local function IsPointInEndzone(team: number, pos: Vector3): boolean
    local zone = GetEndzoneZone(team)
    if not zone then
        return false
    end
    return zone:findPoint(pos) == true
end

local function IsPointInCampoZone(pos: Vector3): boolean
    local zone = GetCampoZone()
    if not zone then return true end
    local inside = zone:findPoint(pos)
    return inside == true
end

local function EnsureLOSMarker(): BasePart?
    if losMarker and losMarker.Parent then
        return losMarker
    end
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then return nil end
    local marker = Instance.new("Part")
    marker.Name = "LineOfScrimmage"
    marker.Size = Vector3.new(0.5, 1, 219.754)
    marker.Anchored = true
    marker.CanCollide = false
    marker.Transparency = 0.3
    marker.Color = Color3.fromRGB(255, 0, 0)
    marker.Material = Enum.Material.Neon
    marker.Orientation = Vector3.new(0, 0, 0)
    marker.Parent = gameFolder
    losMarker = marker
    return marker
end

local function PositionLOSMarker(targetX: number)
    local marker = EnsureLOSMarker()
    if not marker then return end
    -- Fixed field plane provided by designer
    local REF_Y = 710.215
    local REF_Z = 10.553
    marker.Orientation = Vector3.new(0, 0, 0)
    marker.Position = Vector3.new(targetX, REF_Y, REF_Z)
end

local function SetLOSVisible(visible: boolean): ()
    local marker = EnsureLOSMarker()
    if not marker then
        return
    end

    marker.Transparency = if visible then LOS_VISIBLE_TRANSPARENCY else LOS_HIDDEN_TRANSPARENCY
end

--\\ PRIVATE FUNCTIONS \\ -- TR
local StartCountdown: (boolean?) -> ()
local BeginCountdownNow: (boolean?) -> ()
local BeginPreMatchSequence: () -> ()
local SendScoreNotify: (string, string?, number?) -> ()
local SendDownNotify: (number?, string?, string?) -> ()

local function CreateMatchFolder(): Folder
    local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState") :: Folder

    local Folder = GameStateFolder:FindFirstChild("Match") :: Folder?
    if Folder and not Folder:IsA("Folder") then
        Folder:Destroy()
        Folder = nil
    end

    if not Folder then
        Folder = Instance.new("Folder")
        Folder.Name = "Match"
        Folder.Parent = GameStateFolder
    end

    for TeamIndex = 1, 2 do
        local TeamFolder = Folder:FindFirstChild("Team" .. TeamIndex)
        if TeamFolder and not TeamFolder:IsA("Folder") then
            TeamFolder:Destroy()
            TeamFolder = nil
        end
        if not TeamFolder then
            TeamFolder = Instance.new("Folder")
            TeamFolder.Name = "Team" .. TeamIndex
            TeamFolder.Parent = Folder
        end

        for _, Position in FTConfig.PLAYER_POSITIONS do
            local PositionValue = TeamFolder:FindFirstChild(Position.Name)
            if PositionValue and not PositionValue:IsA("IntValue") then
                PositionValue:Destroy()
                PositionValue = nil
            end
            if not PositionValue then
                PositionValue = Instance.new("IntValue")
                PositionValue.Name = Position.Name
                PositionValue.Parent = TeamFolder
            end
            PositionValue.Value = 0
        end
    end

    return Folder
end

local function InitializeGameStateInstances(): ()
    local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
    if not GameStateFolder then
        GameStateFolder = Instance.new("Folder")
        GameStateFolder.Name = "FTGameState"
        GameStateFolder.Parent = ReplicatedStorage
    end

    local GameTimeInstance = GetOrCreateValue(GameStateFolder, "GameTime", "IntValue") :: IntValue
    GameTimeInstance.Value = gameState.GameTime
    gameStateInstances.GameTime = GameTimeInstance :: IntValue

    local IntermissionTimeInstance = GetOrCreateValue(GameStateFolder, "IntermissionTime", "IntValue") :: IntValue
    IntermissionTimeInstance.Value = gameState.IntermissionTime
    gameStateInstances.IntermissionTime = IntermissionTimeInstance :: IntValue

    local Team1ScoreInstance = GetOrCreateValue(GameStateFolder, "Team1Score", "IntValue") :: IntValue
    Team1ScoreInstance.Value = gameState.Team1Score
    gameStateInstances.Team1Score = Team1ScoreInstance :: IntValue

    local Team2ScoreInstance = GetOrCreateValue(GameStateFolder, "Team2Score", "IntValue") :: IntValue
    Team2ScoreInstance.Value = gameState.Team2Score
    gameStateInstances.Team2Score = Team2ScoreInstance :: IntValue
    UpdateScoreboards()

    local IntermissionActiveInstance = GetOrCreateValue(GameStateFolder, "IntermissionActive", "BoolValue") :: BoolValue
    IntermissionActiveInstance.Value = gameState.IntermissionActive
    gameStateInstances.IntermissionActive = IntermissionActiveInstance :: BoolValue

    local MatchEnabledInstance = GetOrCreateValue(GameStateFolder, "MatchEnabled", "BoolValue") :: BoolValue
    MatchEnabledInstance.Value = FTConfig.GAME_CONFIG.MatchEnabled
    gameStateInstances.MatchEnabled = MatchEnabledInstance :: BoolValue

    local MatchStartedInstance = GetOrCreateValue(GameStateFolder, "MatchStarted", "BoolValue") :: BoolValue
    MatchStartedInstance.Value = false
    gameStateInstances.MatchStarted = MatchStartedInstance :: BoolValue

    local CountdownTimeInstance = GetOrCreateValue(GameStateFolder, "CountdownTime", "IntValue") :: IntValue
    CountdownTimeInstance.Value = START_COUNTDOWN_DURATION
    gameStateInstances.CountdownTime = CountdownTimeInstance :: IntValue

    local CountdownActiveInstance = GetOrCreateValue(GameStateFolder, "CountdownActive", "BoolValue") :: BoolValue
    CountdownActiveInstance.Value = false
    gameStateInstances.CountdownActive = CountdownActiveInstance :: BoolValue

    local BallCarrierInstance = GetOrCreateValue(GameStateFolder, "BallCarrier", "ObjectValue") :: ObjectValue
    BallCarrierInstance.Value = nil
    gameStateInstances.BallCarrier = BallCarrierInstance :: ObjectValue

    ResetPlayerTeamValues(GameStateFolder :: Folder)
    matchFolder = CreateMatchFolder()

    local midfieldYard = DEFAULT_SERIES_START_YARD
    gameState.LineOfScrimmage = YardToX(midfieldYard)
    gameState.SeriesStartYard = midfieldYard
    gameState.TargetYard = midfieldYard + GetTeamDirection(gameState.PossessingTeam) * gameState.YardsToGain
    PositionLOSMarker(gameState.LineOfScrimmage)
    SetLOSVisible(false)
end

local function BeginSeries(atYard: number, possessingTeam: number): ()
    local clampedYard = math.clamp(atYard, 0, 100)
    gameState.PossessingTeam = possessingTeam
    gameState.SeriesStartYard = clampedYard
    gameState.LineOfScrimmage = YardToX(clampedYard)
    gameState.Down = 1
    gameState.YardsToGain = FTConfig.GAME_CONFIG.DownsToGain
    local dir = GetTeamDirection(possessingTeam)
    gameState.TargetYard = math.clamp(clampedYard + dir * gameState.YardsToGain, 0, 100)
    PositionLOSMarker(gameState.LineOfScrimmage)
    SetLOSVisible(gameState.CountdownActive or gameState.MatchStarted)
end

local function ResetMatchRoundState(ResetScores: boolean): ()
    gameState.MatchStarted = false
    gameState.MatchActive = false
    gameState.CountdownActive = false
    gameState.ExtraPointActive = false
    gameState.PlayClock = FTConfig.GAME_CONFIG.PlayClockDuration
    gameState.GameTime = FTConfig.GAME_CONFIG.QuarterDuration
    gameState.Quarter = 1
    gameState.CountdownTime = START_COUNTDOWN_DURATION
    gameState.PossessingTeam = DEFAULT_POSSESSING_TEAM
    gameState.Team1Timeouts = FTConfig.GAME_CONFIG.TimeoutsPerHalf
    gameState.Team2Timeouts = FTConfig.GAME_CONFIG.TimeoutsPerHalf

    if ResetScores then
        gameState.Team1Score = 0
        gameState.Team2Score = 0
    end

    BeginSeries(DEFAULT_SERIES_START_YARD, gameState.PossessingTeam)

    if gameStateInstances.MatchStarted then
        gameStateInstances.MatchStarted.Value = false
    end
    if gameStateInstances.CountdownActive then
        gameStateInstances.CountdownActive.Value = false
    end
    if gameStateInstances.CountdownTime then
        gameStateInstances.CountdownTime.Value = gameState.CountdownTime
    end
    if gameStateInstances.GameTime then
        gameStateInstances.GameTime.Value = gameState.GameTime
    end
    if gameStateInstances.Team1Score then
        gameStateInstances.Team1Score.Value = gameState.Team1Score
    end
    if gameStateInstances.Team2Score then
        gameStateInstances.Team2Score.Value = gameState.Team2Score
    end
    if gameStateInstances.BallCarrier then
        gameStateInstances.BallCarrier.Value = nil
    end

    UpdateScoreboards()
end


GetPlayersInMatch = function(): {Player}
    local PlayersInMatch: {Player} = {}
    for _, Player in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(Player) then
            table.insert(PlayersInMatch, Player)
        end
    end
    return PlayersInMatch
end

local function GetPlayerCountInMatch(): number
    local Count = 0
    for _, Player in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(Player) then
            Count += 1
        end
    end
    return Count
end

local function GetSelectedPlayerCount(): number
    if FTPlayerService.GetSelectedPlayerCount then
        return FTPlayerService:GetSelectedPlayerCount()
    end
    return 0
end

local function HasAnyPlayersInOrQueuedForMatch(): boolean
    if GetPlayerCountInMatch() > 0 then
        return true
    end
    return GetSelectedPlayerCount() > 0
end

local function StopAllPlayerAnimations(): ()
    local Services = ServerScriptService:FindFirstChild("Services")
    if not Services then return end

    local FTPlayerServiceModule = Services:FindFirstChild("PlayerService")
    if not FTPlayerServiceModule then return end

    local FTPlayerService = require(FTPlayerServiceModule)
    local PlayersInMatch = GetPlayersInMatch()

    for _, Player in PlayersInMatch do
        FTPlayerService:StopPlayerAnimation(Player)
    end
end

--\\ NEW: JUMP POWER CONTROL \\ -- TR
local function SetJumpPowerForMatchPlayers(Power: number): ()
    local PlayersInMatch = GetPlayersInMatch()
    for _, Player in PlayersInMatch do
        local Character = Player.Character
        if Character then
            local Humanoid = Character:FindFirstChildOfClass("Humanoid")
            if Humanoid then
                Humanoid.UseJumpPower = true
                Humanoid.JumpPower = Power
            end
        end
    end
end

local function GetCountdownRestoreWalkSpeed(player: Player, fallbackSpeed: number?): number
    local storedSpeed: number? = countdownStoredSpeeds[player]
    if typeof(storedSpeed) == "number" and storedSpeed > 0 then
        return storedSpeed
    end
    if typeof(fallbackSpeed) == "number" and fallbackSpeed > 0 then
        return fallbackSpeed
    end
    return 16
end

local function CaptureCountdownFreezeState(
    player: Player,
    character: Model,
    humanoid: Humanoid,
    root: BasePart
): CountdownFreezeState
    local walkSpeedBefore: number = humanoid.WalkSpeed
    if walkSpeedBefore <= 0 then
        walkSpeedBefore = 16
    end
    if countdownStoredSpeeds[player] == nil then
        countdownStoredSpeeds[player] = walkSpeedBefore
    end

    local state: CountdownFreezeState = {
        Character = character,
        Humanoid = humanoid,
        Root = root,
        WalkSpeedBefore = walkSpeedBefore,
        UseJumpPowerBefore = humanoid.UseJumpPower,
        JumpPowerBefore = humanoid.JumpPower,
        JumpHeightBefore = humanoid.JumpHeight,
        AutoRotateBefore = humanoid.AutoRotate,
        PlatformStandBefore = humanoid.PlatformStand,
    }
    countdownFreezeStates[player] = state
    return state
end

local function RestoreCountdownFreezeForPlayer(player: Player): ()
    local state: CountdownFreezeState? = countdownFreezeStates[player]
    local character: Model? = if state then state.Character else player.Character
    local humanoid: Humanoid? = if state then state.Humanoid else (character and character:FindFirstChildOfClass("Humanoid"))
    local root: BasePart? = if state then state.Root else (character and character:FindFirstChild("HumanoidRootPart") :: BasePart?)
    local playerStillInMatch: boolean = FTPlayerService:IsPlayerInMatch(player)
    local fallbackWalkSpeed: number? = if state then state.WalkSpeedBefore else nil

    if root and root.Parent ~= nil then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    if humanoid and humanoid.Parent ~= nil then
        humanoid:Move(Vector3.zero)
        humanoid.WalkSpeed = FlowBuffs.ResolveRestoredWalkSpeed(
            player,
            GetCountdownRestoreWalkSpeed(player, fallbackWalkSpeed),
            DEFAULT_PLAYER_WALK_SPEED
        )
        if playerStillInMatch then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = 50
            humanoid.AutoRotate = true
            humanoid.PlatformStand = false
        elseif state then
            humanoid.UseJumpPower = state.UseJumpPowerBefore
            if state.UseJumpPowerBefore then
                humanoid.JumpPower = state.JumpPowerBefore
            else
                humanoid.JumpHeight = state.JumpHeightBefore
            end
            humanoid.AutoRotate = state.AutoRotateBefore
            humanoid.PlatformStand = state.PlatformStandBefore
        else
            humanoid.UseJumpPower = true
            if humanoid.JumpPower <= 0 then
                humanoid.JumpPower = 50
            end
            humanoid.AutoRotate = true
            humanoid.PlatformStand = false
        end
    end

    countdownFreezeStates[player] = nil
    countdownStoredSpeeds[player] = nil
end

local function ApplyCountdownFreezeToPlayer(player: Player): ()
    if player.Parent == nil or not FTPlayerService:IsPlayerInMatch(player) then
        RestoreCountdownFreezeForPlayer(player)
        return
    end

    local character: Model? = player.Character
    if not character then
        return
    end

    local humanoid: Humanoid? = character:FindFirstChildOfClass("Humanoid")
    local root: BasePart? = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not humanoid or not root then
        return
    end

    local state: CountdownFreezeState? = countdownFreezeStates[player]
    if not state or state.Character ~= character or state.Humanoid ~= humanoid or state.Root ~= root then
        state = CaptureCountdownFreezeState(player, character, humanoid, root)
    end

    humanoid:Move(Vector3.zero)
    humanoid.WalkSpeed = 0
    humanoid.AutoRotate = false
    humanoid.PlatformStand = false
    if humanoid.UseJumpPower then
        humanoid.JumpPower = 0
    else
        humanoid.JumpHeight = 0
    end

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function ApplyCountdownFreezeToMatchPlayers(): ()
    local activeMatchPlayers: {[Player]: boolean} = {}
    for _, player in GetPlayersInMatch() do
        activeMatchPlayers[player] = true
        ApplyCountdownFreezeToPlayer(player)
    end

    local playersToRelease: {Player} = {}
    local queued: {[Player]: boolean} = {}
    for player in countdownFreezeStates do
        if not activeMatchPlayers[player] or player.Parent == nil then
            table.insert(playersToRelease, player)
            queued[player] = true
        end
    end
    for player in countdownStoredSpeeds do
        if (not activeMatchPlayers[player] or player.Parent == nil) and not queued[player] then
            table.insert(playersToRelease, player)
        end
    end
    for _, player in playersToRelease do
        RestoreCountdownFreezeForPlayer(player)
    end
end

local function ReleaseAllCountdownFreezeStates(): ()
    local playersToRelease: {Player} = {}
    local queued: {[Player]: boolean} = {}
    for player in countdownFreezeStates do
        table.insert(playersToRelease, player)
        queued[player] = true
    end
    for player in countdownStoredSpeeds do
        if not queued[player] then
            table.insert(playersToRelease, player)
        end
    end
    for _, player in playersToRelease do
        RestoreCountdownFreezeForPlayer(player)
    end
end

local function BeginDownHold(): number
    pendingCountdownToken += 1
    local token = pendingCountdownToken
    FreezePlayersForDownNotify()
    SetJumpPowerForMatchPlayers(0)
    task.spawn(function()
        while pendingCountdownToken == token and not gameState.CountdownActive do
            for _, player in GetPlayersInMatch() do
                local character = player.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 0
                end
            end
            task.wait(0.2)
        end
    end)
    return token
end

local function ScheduleCountdownAfter(delaySeconds: number, token: number): ()
    task.delay(delaySeconds, function()
        if pendingCountdownToken ~= token then
            return
        end
        StartCountdown(true)
    end)
end

local function FindCenterPlayer(TeamNumber: number): Player?
    if not matchFolder then return nil end
    local TeamFolder = matchFolder:FindFirstChild("Team" .. TeamNumber)
    if not TeamFolder then return nil end
    local CenterValue = TeamFolder:FindFirstChild("Center") :: IntValue?
    if CenterValue and CenterValue.Value ~= 0 then
        local Player = PlayerIdentity.ResolvePlayer(CenterValue.Value)
        if Player and FTPlayerService:IsPlayerInMatch(Player) then
            return Player
        end
    end
    return nil
end

local function FindFirstPlayerInTeam(TeamNumber: number): Player?
    if not matchFolder then return nil end
    local TeamFolder = matchFolder:FindFirstChild("Team" .. TeamNumber)
    if not TeamFolder then return nil end
    for _, PositionValue in TeamFolder:GetChildren() do
        if PositionValue:IsA("IntValue") and PositionValue.Value ~= 0 then
            local Player = PlayerIdentity.ResolvePlayer(PositionValue.Value)
            if Player and FTPlayerService:IsPlayerInMatch(Player) then
                return Player
            end
        end
    end
    return nil
end

local function IsValidDownCarrier(player: Player?): boolean
    if not player then
        return false
    end
    if not FTPlayerService:IsPlayerInMatch(player) then
        return false
    end
    local team = FTPlayerService:GetPlayerTeam(player)
    if not team or team ~= gameState.PossessingTeam then
        return false
    end
    return true
end

local function DetermineBallCarrier(): Player?
    if IsValidDownCarrier(lastDownCarrier) then
        return lastDownCarrier
    end

    local primaryTeam = gameState.PossessingTeam
    local secondaryTeam = primaryTeam == 1 and 2 or 1

    for _, team in {primaryTeam, secondaryTeam} do
        local center = FindCenterPlayer(team)
        if center then return center end
    end

    for _, team in {primaryTeam, secondaryTeam} do
        local firstPlayer = FindFirstPlayerInTeam(team)
        if firstPlayer then return firstPlayer end
    end

    return nil
end

local function GetReferencePosition(player: Player): Vector3?
    local ballState = FTBallService:GetBallState()
    local carrier = ballState and ballState:GetPossession()
    local carrierCharacter = carrier and carrier.Character
    local carrierRoot = carrierCharacter and carrierCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
    if carrierRoot then
        return carrierRoot.Position
    end

    local ballPart = FTBallService:GetBallInstance()
    if ballPart and ballPart:IsA("BasePart") then
        return ballPart.Position
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
    return root and root.Position or nil
end

local function FindNearestYard(position: Vector3): BasePart?
    local gameFolder = Workspace:FindFirstChild("Game")
    local yardFolder = gameFolder and gameFolder:FindFirstChild("Jardas")
    if not yardFolder then return nil end

    local nearest: BasePart? = nil
    local nearestDistance = math.huge
    for _, yardPart in yardFolder:GetChildren() do
        if yardPart:IsA("BasePart") then
            local distance = math.abs(yardPart.Position.X - position.X)
            if distance < nearestDistance then
                nearestDistance = distance
                nearest = yardPart
            end
        end
    end
    return nearest
end

local function FindTeamPositionTarget(teamFolder: Instance, positionName: string): Instance?
    local directTarget = teamFolder:FindFirstChild(positionName)
    if directTarget then
        return directTarget
    end

    return teamFolder:FindFirstChild(positionName, true)
end

local function ResolvePositionPart(target: Instance?): BasePart?
    if not target then return nil end
    if target:IsA("BasePart") then
        return target
    end
    if target:IsA("Model") then
        if target.PrimaryPart then
            return target.PrimaryPart
        end

        local descendantPart = target:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
        if descendantPart then
            return descendantPart
        end
    end

    return nil
end

local function GetPositionPartFromFolder(positionsContainer: Instance, team: number, positionName: string): BasePart?
    local teamFolder = positionsContainer:FindFirstChild("Team" .. team)
    if not teamFolder then
        teamFolder = positionsContainer:FindFirstChild("Team" .. team, true)
    end
    if not teamFolder then return nil end
    return ResolvePositionPart(FindTeamPositionTarget(teamFolder, positionName))
end

local function ClearLinePositionsClone(gameFolder: Instance): ()
    local existingClone = gameFolder:FindFirstChild(LINE_POSITIONS_CLONE_NAME)
    if existingClone then
        existingClone:Destroy()
    end
end

local function GetPositionsReferenceAnchorPart(sourceContainer: Instance): BasePart?
    if sourceContainer:IsA("Model") and sourceContainer.PrimaryPart then
        return sourceContainer.PrimaryPart
    end

    local meioPart = ResolvePositionPart(sourceContainer:FindFirstChild("Meio", true))
    if meioPart then
        return meioPart
    end

    local folderMiddle = ResolvePositionPart(sourceContainer:FindFirstChild("MiddlePosition", true))
    if folderMiddle then
        return folderMiddle
    end

    local teamOneCenter = GetPositionPartFromFolder(sourceContainer, 1, "Center")
    if teamOneCenter then
        return teamOneCenter
    end

    local teamOneQuarterBack = GetPositionPartFromFolder(sourceContainer, 1, "Quarter Back")
    if teamOneQuarterBack then
        return teamOneQuarterBack
    end

    local genericPart = GetPrimaryPart(sourceContainer)
    if genericPart then
        return genericPart
    end

    return nil
end

local function ClonePositionsFolderAtLine(targetX: number): Instance?
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then return nil end

    local sourceContainer = gameFolder:FindFirstChild("Positions")
    if not sourceContainer then
        sourceContainer = gameFolder:FindFirstChild("Positions", true)
    end
    if not sourceContainer then return nil end

    ClearLinePositionsClone(gameFolder)

    local anchorPart = GetPositionsReferenceAnchorPart(sourceContainer)
    local anchorX = anchorPart and anchorPart.Position.X or nil
    local cloneContainer = sourceContainer:Clone()
    cloneContainer.Name = LINE_POSITIONS_CLONE_NAME

    local deltaX = if anchorX ~= nil then (targetX - anchorX) else 0
    if cloneContainer:IsA("Model") then
        local cloneAnchorPart = GetPositionsReferenceAnchorPart(cloneContainer)
        if cloneAnchorPart then
            cloneContainer:PivotTo(cloneContainer:GetPivot() + Vector3.new(targetX - cloneAnchorPart.Position.X, 0, 0))
        else
            for _, descendant in cloneContainer:GetDescendants() do
                if descendant:IsA("BasePart") then
                    descendant.CFrame = descendant.CFrame + Vector3.new(deltaX, 0, 0)
                end
            end
        end
    else
        for _, descendant in cloneContainer:GetDescendants() do
            if descendant:IsA("BasePart") then
                descendant.CFrame = descendant.CFrame + Vector3.new(deltaX, 0, 0)
            end
        end
    end

    cloneContainer.Parent = gameFolder
    local cloneAnchorPart = GetPositionsReferenceAnchorPart(cloneContainer)
    DebugPositionTeleport(("clone positions source=%s clone=%s anchor=%s cloneAnchor=%s targetX=%.2f deltaX=%.2f cloneAnchorX=%s"):format(
        sourceContainer:GetFullName(),
        cloneContainer:GetFullName(),
        if anchorPart then anchorPart:GetFullName() else "nil",
        if cloneAnchorPart then cloneAnchorPart:GetFullName() else "nil",
        targetX,
        deltaX,
        if cloneAnchorPart then string.format("%.2f", cloneAnchorPart.Position.X) else "nil"
    ))
    return cloneContainer
end

local function GetTeleportPositionsFolder(targetX: number, forceCustom: boolean?): (Instance?, string)
    local gameFolder = Workspace:FindFirstChild("Game")
    if not gameFolder then
        return nil, "missing_game"
    end

    if forceCustom or gameState.ExtraPointActive then
        ClearLinePositionsClone(gameFolder)
        local customPositions = gameFolder:FindFirstChild("PositionsCustom1")
        if not customPositions then
            customPositions = gameFolder:FindFirstChild("PositionsCustom1", true)
        end
        return customPositions, "custom_direct"
    end

    if not gameState.MatchStarted then
        ClearLinePositionsClone(gameFolder)
        local regularPositions = gameFolder:FindFirstChild("Positions")
        if not regularPositions then
            regularPositions = gameFolder:FindFirstChild("Positions", true)
        end
        return regularPositions, "pre_match_positions"
    end

    return ClonePositionsFolderAtLine(targetX), "positions_clone"
end

local function SetPlayerFacingGoal(player: Player, goalTeam: number): ()
    if not player then return end
    player:SetAttribute(ATTRIBUTE_NAMES.FacingGoal, 0)
    player:SetAttribute(ATTRIBUTE_NAMES.FacingGoal, goalTeam)
    local character = player.Character
    if character then
        character:SetAttribute(ATTRIBUTE_NAMES.FacingGoal, 0)
        character:SetAttribute(ATTRIBUTE_NAMES.FacingGoal, goalTeam)
    end
end

local function TeleportMatchPlayersToX(targetX: number, forceCustom: boolean?): ()
    local now = os.clock()
    if now >= teleportFadeSuppressedUntil and now - lastTeleportFade >= TELEPORT_FADE_COOLDOWN then
        lastTeleportFade = now
        Packets.TeleportFade:Fire(TELEPORT_FADE_DURATION)
    end
    local teleportPositionsFolder, teleportMode = GetTeleportPositionsFolder(targetX, forceCustom)
    DebugPositionTeleport(("begin mode=%s targetX=%.2f forceCustom=%s matchStarted=%s extraPoint=%s folder=%s"):format(
        teleportMode,
        targetX,
        tostring(forceCustom == true),
        tostring(gameState.MatchStarted),
        tostring(gameState.ExtraPointActive),
        if teleportPositionsFolder then teleportPositionsFolder:GetFullName() else "nil"
    ))
    if not teleportPositionsFolder then
        DebugPositionTeleport(("abort reason=no_positions_folder mode=%s targetX=%.2f"):format(teleportMode, targetX))
        return
    end
    for _, player in Players:GetPlayers() do
        if not FTPlayerService:IsPlayerInMatch(player) then
            continue
        end
        local team = FTPlayerService:GetPlayerTeam(player)
        local positionName = FTPlayerService:GetPlayerPosition(player)
        if not team or not positionName then
            continue
        end
        local positionPart = GetPositionPartFromFolder(teleportPositionsFolder, team, positionName)
        local character = player.Character
        if not character then
            DebugPositionTeleport(("skip player=%s team=%d position=%s reason=no_character"):format(
                player.Name,
                team,
                positionName
            ))
            continue
        end
        if not positionPart then
            DebugPositionTeleport(("skip player=%s team=%d position=%s reason=no_position_part mode=%s"):format(
                player.Name,
                team,
                positionName,
                teleportMode
            ))
            continue
        end
        local baseCFrame = positionPart.CFrame
        local basePos = baseCFrame.Position
        local goalTeam = if team == 1 then 2 else 1
        local finalCFrame = if gameState.ExtraPointActive
            then ResolveGroundedTeleportCFrameForCharacter(character, baseCFrame)
            else baseCFrame
        DebugPositionTeleport(("player=%s team=%d position=%s mode=%s target=%s base=%s final=%s"):format(
            player.Name,
            team,
            positionName,
            teleportMode,
            positionPart:GetFullName(),
            FormatDebugVector3(basePos),
            FormatDebugVector3(finalCFrame.Position)
        ))
        local finalForward = finalCFrame.LookVector
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

        character:PivotTo(finalCFrame)
        SetPlayerFacingGoal(player, goalTeam)
        DebugTeleportTrace(player, "TeleportPlayersToYard")

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
                if gameState.CountdownActive then
                    humanoid.WalkSpeed = 0
                end
            end
            local uprightDuration = if gameState.ExtraPointActive then EXTRA_POINT_UPRIGHT_DURATION else TELEPORT_UPRIGHT_DURATION
            EnforceUpright(player, finalForward, uprightDuration)

            -- Role pose (QB/Linebacker) should only be applied after teleport.
            if gameState.ExtraPointActive then
                if FTPlayerService.StopPlayerAnimation then
                    FTPlayerService:StopPlayerAnimation(player)
                end
            elseif gameState.CountdownActive then
                if FTPlayerService.PlayPositionAnimation then
                    FTPlayerService:PlayPositionAnimation(player)
                end
            elseif FTPlayerService.StopPlayerAnimation then
                FTPlayerService:StopPlayerAnimation(player)
            end
        end)
    end
    if FTRefereeService and teleportMode == "positions_clone" then
        if FTRefereeService.TeleportToPosition then
            local refY, refZ = GetReferencePlane()
            FTRefereeService:TeleportToPosition(Vector3.new(targetX, refY, refZ))
        elseif FTRefereeService.PlayRequestBall then
            FTRefereeService:PlayRequestBall()
        end
    end
end
local function BuildPlaySnapshot(positionX: number): { 
    currentX: number,
    currentYard: number,
    lineYard: number,
    playGain: number,
    seriesGain: number,
    yardsToGain: number,
    offenseTeam: number,
 }      
    local offenseTeam = gameState.PossessingTeam
    local currentYard = XToYard(positionX)
    local lineYard = XToYard(gameState.LineOfScrimmage)
    local relCurrent = ToRelativeYard(currentYard, offenseTeam)
    local relLine = ToRelativeYard(lineYard, offenseTeam)
    local relSeriesStart = ToRelativeYard(gameState.SeriesStartYard, offenseTeam)
    local playGain = relCurrent - relLine
    local seriesGain = relCurrent - relSeriesStart
    local yardsToGain = math.max(0, FTConfig.GAME_CONFIG.DownsToGain - math.max(seriesGain, 0))
    return {
        currentX = positionX,
        currentYard = currentYard,
        lineYard = lineYard,
        playGain = playGain,
        seriesGain = seriesGain,
        yardsToGain = yardsToGain,
        offenseTeam = offenseTeam,
    }
end

local function IsCarrierProtectedFromPlayEnd(player: Player?): boolean
    if not player then
        return false
    end
    if player:GetAttribute(ATTRIBUTE_NAMES.Invulnerable) == true
        or player:GetAttribute(ATTRIBUTE_NAMES.TouchdownPause) == true
    then
        return true
    end

    local character = player.Character
    if not character then
        return false
    end

    return character:GetAttribute(ATTRIBUTE_NAMES.Invulnerable) == true
        or character:GetAttribute(ATTRIBUTE_NAMES.TouchdownPause) == true
end

local function ProcessPlayEnd(position: Vector3, reason: string?, lastInBoundsX: number?, throwOriginX: number?, throwTeam: number?): {report: {[string]: any}}
    local previousLOS = gameState.LineOfScrimmage
    if gameState.ExtraPointActive then
        return {report = {}}
    end
    -- Guard against duplicated play-end events while a down/countdown
    -- transition is already being processed.
    if playEndLocked or gameState.CountdownActive then
        return {report = {}}
    end
    playEndLocked = true
    local ballState = FTBallService:GetBallState()
    local carrier = ballState and ballState:GetPossession() or nil
    if IsCarrierProtectedFromPlayEnd(carrier) then
        playEndLocked = false
        return {report = {}}
    end
    local isPassIncomplete = reason == "Incomplete pass"
    local outOfBounds = not IsPointInCampoZone(position)
    local isPassOut = reason == "Out pass"
    local offenseTeam = throwTeam or gameState.PossessingTeam
    if reason == "Tackle" and IsPointInEndzone(offenseTeam, position) then
        local newTeam = offenseTeam == 1 and 2 or 1
        local restartYard = RelativeToAbsoluteYard(20, newTeam)
        BeginSeries(restartYard, newTeam)
        TeleportMatchPlayersToX(YardToX(restartYard))
        if FTRefereeService and FTRefereeService.PlayRequestBall then
            FTRefereeService:PlayRequestBall()
        end
        SetInvulnerableForMatch(true)
        local downToken = BeginDownHold()
        lastPlayGain = 0
        local desc = ("%d+ POINTS %s"):format(SAFETY_POINTS, GetTeamSide(newTeam))
        SendScoreNotify("SAFETY!", desc, SCORE_NOTIFY_DURATION)
        task.delay(SCORE_NOTIFY_DURATION + 0.15, function()
            if gameState.ExtraPointActive then
                return
            end
            if pendingCountdownToken ~= downToken then
                return
            end
            SendDownNotify()
            ScheduleCountdownAfter(DOWN_NOTIFY_DURATION, downToken)
        end)
        return {report = {
            currentYard = restartYard,
            lineYard = restartYard,
            playGain = 0,
            seriesGain = 0,
            yardsRemaining = FTConfig.GAME_CONFIG.DownsToGain,
            currentDown = gameState.Down,
            maxDowns = FTConfig.GAME_CONFIG.MaxDowns,
            possessionTeam = gameState.PossessingTeam,
            targetYard = gameState.TargetYard,
            outOfBounds = false,
        }}
    end
    local dir = GetTeamDirection(offenseTeam)
    local startX, endX = GetFieldAnchors()
    local yardsToWorld = (endX - startX) / 100
    local throwYard: number? = nil
    local penaltyYard: number? = nil

    local spotX: number
    if isPassIncomplete then
        if throwOriginX then
            throwYard = XToYard(throwOriginX)
            penaltyYard = math.clamp(throwYard - dir * INCOMPLETE_PASS_LOSS_YARDS, 0, 100)
            spotX = YardToX(penaltyYard)
        else
            spotX = previousLOS
        end
    elseif outOfBounds and isPassOut then
        if throwOriginX then
            throwYard = XToYard(throwOriginX)
            penaltyYard = math.clamp(throwYard - dir * 5, 0, 100)
            local penaltyX = YardToX(penaltyYard)
            spotX = penaltyX
        else
            spotX = previousLOS
        end
    elseif outOfBounds then
        if lastInBoundsX then
            spotX = lastInBoundsX
        else
            spotX = (gameState.Down == 1) and YardToX(gameState.SeriesStartYard) or previousLOS
        end
    else
        spotX = position.X
    end

    local snapshot = BuildPlaySnapshot(spotX)
    if outOfBounds and isPassOut then
        local relSeriesStart = ToRelativeYard(gameState.SeriesStartYard, snapshot.offenseTeam)
        local relSpot = ToRelativeYard(XToYard(spotX), snapshot.offenseTeam)
        snapshot.playGain = relSpot - relSeriesStart
        snapshot.seriesGain = snapshot.playGain
        if snapshot.playGain == 0 then
            snapshot.playGain = -5 
        end
        snapshot.yardsToGain = math.max(0, FTConfig.GAME_CONFIG.DownsToGain - math.max(snapshot.seriesGain, 0))
    end

    local verb = snapshot.playGain >= 0 and "advanced" or "lost"
    gameState.LineOfScrimmage = spotX
    if (outOfBounds and isPassOut) or isPassIncomplete then
        gameState.SeriesStartYard = XToYard(spotX)
    else
        if gameState.Down == 1 then
            gameState.SeriesStartYard = XToYard(spotX)
        end
    end
    dir = GetTeamDirection(gameState.PossessingTeam)
    gameState.TargetYard = math.clamp(gameState.SeriesStartYard + dir * gameState.YardsToGain, 0, 100)
    PositionLOSMarker(spotX)
    if FTRefereeService and FTRefereeService.PlayRequestBall then
        FTRefereeService:PlayRequestBall()
    end

    local carrierTeam = carrier and FTPlayerService:GetPlayerTeam(carrier) or nil
    if carrierTeam and carrierTeam ~= gameState.PossessingTeam then
        BeginSeries(snapshot.currentYard, carrierTeam)
        lastPlayGain = snapshot.playGain
        if IsValidDownCarrier(carrier) then
            lastDownCarrier = carrier
        else
            lastDownCarrier = nil
        end
        SetInvulnerableForMatch(true)
        local downToken = BeginDownHold()
        SendDownNotify()
        if not gameState.ExtraPointActive then
            ScheduleCountdownAfter(DOWN_NOTIFY_DURATION, downToken)
        end
        return {report = {
            currentYard = snapshot.currentYard,
            lineYard = XToYard(gameState.LineOfScrimmage),
            playGain = snapshot.playGain,
            seriesGain = 0,
            yardsRemaining = gameState.YardsToGain,
            currentDown = gameState.Down,
            maxDowns = FTConfig.GAME_CONFIG.MaxDowns,
            possessionTeam = gameState.PossessingTeam,
            targetYard = gameState.TargetYard,
            outOfBounds = outOfBounds,
        }}
    end

    if not outOfBounds and not isPassIncomplete and snapshot.seriesGain >= FTConfig.GAME_CONFIG.DownsToGain then
        BeginSeries(snapshot.currentYard, snapshot.offenseTeam)
    else
        if gameState.Down >= FTConfig.GAME_CONFIG.MaxDowns then
            local newTeam = snapshot.offenseTeam == 1 and 2 or 1
            BeginSeries(snapshot.currentYard, newTeam)
        else
            gameState.Down += 1
            gameState.YardsToGain = snapshot.yardsToGain or FTConfig.GAME_CONFIG.DownsToGain
        end
    end

    if IsValidDownCarrier(carrier) then
        lastDownCarrier = carrier
    elseif not IsValidDownCarrier(lastDownCarrier) then
        lastDownCarrier = nil
    end
    lastPlayGain = snapshot.playGain

    SetInvulnerableForMatch(true)
    local downToken = BeginDownHold()
    if isPassIncomplete then
        SendDownNotify(
            nil,
            "INCOMPLETE PASS!",
            ("LOST %d YARDS"):format(INCOMPLETE_PASS_LOSS_YARDS)
        )
    else
        SendDownNotify()
    end
    if not gameState.ExtraPointActive then
        ScheduleCountdownAfter(DOWN_NOTIFY_DURATION, downToken)
    end

    return {report = {
        currentYard = snapshot.currentYard,
        lineYard = snapshot.lineYard,
        playGain = snapshot.playGain,
        seriesGain = snapshot.seriesGain,
        yardsRemaining = math.max(0, FTConfig.GAME_CONFIG.DownsToGain - math.max(snapshot.seriesGain, 0)),
        currentDown = gameState.Down,
        maxDowns = FTConfig.GAME_CONFIG.MaxDowns,
        possessionTeam = gameState.PossessingTeam,
        targetYard = gameState.TargetYard,
        outOfBounds = outOfBounds,
    }}
end

local function HandleDebugReset(player: Player): ()
    if not FTPlayerService:IsPlayerInMatch(player) then return end

    local referencePosition = GetReferencePosition(player)
    if not referencePosition then
        Packets.DebugResetReport:FireClient(player, {
            success = false,
            message = "Could not find the reference position.",
        })
        return
    end

    local result = ProcessPlayEnd(referencePosition, "Player")

    Packets.DebugResetReport:FireClient(player, {
        success = true,
        playGain = result.report.playGain,
        seriesGain = result.report.seriesGain,
        currentYard = result.report.currentYard,
        lineYard = result.report.lineYard,
        targetYard = result.report.targetYard,
        currentDown = result.report.currentDown,
        maxDowns = result.report.maxDowns,
        possessionTeam = result.report.possessionTeam,
    })
end

local function HandleInterception(info: {team: number, position: Vector3, yard: number}): ()
    gameState.PossessingTeam = info.team
    gameState.SeriesStartYard = info.yard
    gameState.LineOfScrimmage = YardToX(info.yard)
    gameState.Down = 1
    gameState.YardsToGain = FTConfig.GAME_CONFIG.DownsToGain
    gameState.TargetYard = math.clamp(info.yard + GetTeamDirection(info.team) * gameState.YardsToGain, 0, 100)
end

local function GiveBallToCarrier(Player: Player): ()
    local Services = ServerScriptService:FindFirstChild("Services")
    if not Services then return end

    local FTBallServiceModule = Services:FindFirstChild("BallService")
    if not FTBallServiceModule then return end

    local FTBallService = require(FTBallServiceModule)
    FTBallService:GiveBallToPlayer(Player)
end

local function StartMatch(): ()
    if gameState.MatchStarted then return end

    gameState.MatchStarted = true
    gameState.MatchActive = true

    if gameStateInstances.MatchStarted then
        gameStateInstances.MatchStarted.Value = true
    end

    BeginSeries(50, gameState.PossessingTeam)
    SetLOSVisible(true)

    StopAllPlayerAnimations()
    --\\ RESET JUMP POWER TO NORMAL \\ -- TR
    SetJumpPowerForMatchPlayers(50)
end

BeginCountdownNow = function(allowDuringMatch: boolean?): ()
    if gameState.CountdownActive then return end
    if gameState.MatchStarted and not allowDuringMatch then return end

    local PlayerCount = GetPlayerCountInMatch()
    DebugPositionTeleport(("StartCountdown allowDuringMatch=%s matchStarted=%s playerCount=%d lineOfScrimmage=%.2f"):format(
        tostring(allowDuringMatch == true),
        tostring(gameState.MatchStarted),
        PlayerCount,
        gameState.LineOfScrimmage
    ))
    if PlayerCount < 1 then
        playEndLocked = false
        return
    end

    SetLOSVisible(true)

    pendingCountdownToken += 1
    gameState.CountdownActive = true
    local countdownDuration = if allowDuringMatch then COUNTDOWN_DURATION else START_COUNTDOWN_DURATION
    gameState.CountdownTime = countdownDuration
    countdownToken += 1
    local localToken = countdownToken

    if gameStateInstances.CountdownActive then
        gameStateInstances.CountdownActive.Value = true
    end
    if gameStateInstances.CountdownTime then
        gameStateInstances.CountdownTime.Value = countdownDuration
    end

    if not gameState.ExtraPointActive then
        SetInvulnerableForMatch(true)
        TeleportMatchPlayersToX(gameState.LineOfScrimmage)
    end
    ApplyCountdownFreezeToMatchPlayers()

    task.spawn(function()
        while gameState.CountdownActive and countdownToken == localToken do
            ApplyCountdownFreezeToMatchPlayers()
            RunService.Heartbeat:Wait()
        end
    end)

    local BallCarrier = DetermineBallCarrier()
    if BallCarrier then
        lastDownCarrier = BallCarrier
        GiveBallToCarrier(BallCarrier)
    end

    task.spawn(function()
        while gameState.CountdownTime > 0 and gameState.CountdownActive do
            task.wait(1)
            gameState.CountdownTime = gameState.CountdownTime - 1
            if gameStateInstances.CountdownTime then
                gameStateInstances.CountdownTime.Value = gameState.CountdownTime
            end
        end

        if gameState.CountdownActive then
            gameState.CountdownActive = false
            if gameStateInstances.CountdownActive then
                gameStateInstances.CountdownActive.Value = false
            end
            if not allowDuringMatch then
                StartMatch()
            end
        end
        for _, player in GetPlayersInMatch() do
            if FTPlayerService.StopPlayerAnimation then
                FTPlayerService:StopPlayerAnimation(player)
            end
        end

        SetJumpPowerForMatchPlayers(50)
        ReleaseAllCountdownFreezeStates()

        task.delay(COUNTDOWN_RELEASE_DELAY, function()
            if countdownToken == localToken then
                SetInvulnerableForMatch(false)
                playEndLocked = false
            end
        end)
    end)
end

local StartIntermission: () -> ()

local function ResetMatchPositions(): ()
    if not matchFolder then
        local gameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
        matchFolder = gameStateFolder and gameStateFolder:FindFirstChild("Match") :: Folder?
    end
    if not matchFolder then
        return
    end
    for _, TeamFolder in matchFolder:GetChildren() do
        for _, PositionValue in TeamFolder:GetChildren() do
            if PositionValue:IsA("IntValue") then
                PositionValue.Value = 0
            end
        end
    end
end

local function SendPlayerToLobby(Player: Player): ()
    local character = Player.Character
    if not character then
        return
    end
    local spawnCFrame = GetLobbySpawnCFrame()
    if not spawnCFrame then
        return
    end
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.Sit = false
        humanoid.AutoRotate = true
        humanoid:Move(Vector3.zero, false)
    end
    character:PivotTo(spawnCFrame)
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function LeaveMatchPlayer(Player: Player): ()
    RestoreCountdownFreezeForPlayer(Player)
    if FTBallService and FTBallService.DropBallFromPlayer then
        FTBallService:DropBallFromPlayer(Player)
    end
    if FTSpinService and FTSpinService.ResetPlayer then
        FTSpinService:ResetPlayer(Player)
    end
    if FTFlowService and FTFlowService.ResetPlayer then
        FTFlowService:ResetPlayer(Player)
    end
    if FTSkillService and FTSkillService.ResetPlayer then
        FTSkillService:ResetPlayer(Player)
    end
    local TackleService = GetTackleService()
    if TackleService and TackleService.ResetPlayer then
        TackleService:ResetPlayer(Player)
    end
    if FTPlayerService and FTPlayerService.LeaveMatch then
        FTPlayerService:LeaveMatch(Player)
    end
    ResetPlayerTransientMatchState(Player)
    SendPlayerToLobby(Player)
end

local function ResetMatchToSelectionIdle(): ()
    pendingCountdownToken += 1
    countdownToken += 1
    preMatchSequenceToken += 1
    preMatchSequenceActive = false
    introCutsceneLock:Stop(nil)
    table.clear(introFinishAcks)
    table.clear(introFinishResolvers)
    ClearActiveIntroState(nil)

    if FTBallService.CleanupMatchArtifacts then
        FTBallService:CleanupMatchArtifacts()
    end

    ReleaseAllCountdownFreezeStates()
    SetInvulnerableForMatch(false)
    ResetMatchRoundState(true)
    ResetMatchPositions()
    SetLOSVisible(false)

    gameState.IntermissionActive = false
    gameState.IntermissionTime = 0
    lastDownCarrier = nil
    lastPlayGain = 0
    playEndLocked = false
    teleportFadeSuppressedUntil = 0

    if gameStateInstances.IntermissionActive then
        gameStateInstances.IntermissionActive.Value = false
    end
    if gameStateInstances.IntermissionTime then
        gameStateInstances.IntermissionTime.Value = 0
    end
end

local function ResetMatchIfEmptyAfterLeave(): ()
    if HasAnyPlayersInOrQueuedForMatch() then
        return
    end

    ResetMatchToSelectionIdle()
end

local function BuildMatchIntroPayload(Token: number): {[string]: any}
    local Team1: {number} = {}
    local Team2: {number} = {}

    if FTPlayerService.GetSelectedPlayersForTeam then
        for _, Player in FTPlayerService:GetSelectedPlayersForTeam(1) do
            table.insert(Team1, PlayerIdentity.GetIdValue(Player))
        end
        for _, Player in FTPlayerService:GetSelectedPlayersForTeam(2) do
            table.insert(Team2, PlayerIdentity.GetIdValue(Player))
        end
    end

    return {
        Team1 = Team1,
        Team2 = Team2,
        Token = Token,
    }
end

local function FireMatchIntroCutscene(PlayersInCutscene: {Player}, Token: number): ()
    local Payload = BuildMatchIntroPayload(Token)
    activeIntroToken = Token
    activeIntroPayload = Payload
    activeIntroStartedAt = os.clock()
    table.clear(activeIntroRecipients)
    for _, Player in PlayersInCutscene do
        if Player.Parent == nil then
            continue
        end
        activeIntroRecipients[Player] = true
        Packets.MatchIntroCutscene:FireClient(Player, Payload)
    end
end

local function EnsurePlayerReceivesActiveIntro(Player: Player): ()
    if Player.Parent == nil then
        return
    end
    if not preMatchSequenceActive then
        return
    end
    if activeIntroToken == nil or activeIntroPayload == nil then
        return
    end
    if (os.clock() - activeIntroStartedAt) > MATCH_INTRO_LATE_REPLAY_GRACE_TIME then
        return
    end
    if activeIntroRecipients[Player] == true then
        return
    end

    activeIntroRecipients[Player] = true
    Packets.MatchIntroCutscene:FireClient(Player, activeIntroPayload)
end

local function HaveAllIntroPlayersFinished(Token: number, PlayersInCutscene: {Player}): boolean
    local AckMap: {[Player]: boolean}? = introFinishAcks[Token]
    if not AckMap then
        return false
    end

    for _, Player in PlayersInCutscene do
        if Player.Parent == nil then
            continue
        end
        if AckMap[Player] ~= true then
            return false
        end
    end

    return true
end

local function ChooseOpeningTeam(): number
    local AvailableTeams: {number} = {}

    if FTPlayerService.GetSelectedPlayersForTeam then
        if #FTPlayerService:GetSelectedPlayersForTeam(1) > 0 then
            table.insert(AvailableTeams, 1)
        end
        if #FTPlayerService:GetSelectedPlayersForTeam(2) > 0 then
            table.insert(AvailableTeams, 2)
        end
    end

    if #AvailableTeams == 1 then
        return AvailableTeams[1]
    end

    return if math.random() < 0.5 then 1 else 2
end

BeginPreMatchSequence = function(): ()
    if preMatchSequenceActive then
        return
    end
    if gameState.CountdownActive or gameState.MatchStarted or gameState.IntermissionActive then
        return
    end

    local MinimumPlayers: number = MatchPlayerUtils.GetMinimumPlayersToStart()
    local SelectedPlayerCount: number = if FTPlayerService.GetSelectedPlayerCount
        then FTPlayerService:GetSelectedPlayerCount()
        else 0
    if SelectedPlayerCount < MinimumPlayers then
        playEndLocked = false
        return
    end

    preMatchSequenceActive = true
    preMatchSequenceToken += 1
    local Token: number = preMatchSequenceToken

    teleportFadeSuppressedUntil = math.max(
        teleportFadeSuppressedUntil,
        os.clock() + MATCH_INTRO_LOCK_DURATION + MATCH_INTRO_TELEPORT_FADE_BUFFER
    )
    SetLOSVisible(false)

    local SelectedPlayers: {Player} = if FTPlayerService.GetSelectedPlayers
        then FTPlayerService:GetSelectedPlayers()
        else {}
    if #SelectedPlayers < MinimumPlayers then
        preMatchSequenceActive = false
        playEndLocked = false
        return
    end

    if FTPlayerService.PrepareSelectedPlayersForIntro then
        FTPlayerService:PrepareSelectedPlayersForIntro()
        task.wait(0.15)
    end

    local LockToken: number = introCutsceneLock:Start(
        SelectedPlayers,
        MATCH_INTRO_LOCK_DURATION
    )
    introFinishAcks[Token] = {}
    FireMatchIntroCutscene(Players:GetPlayers(), Token)

    task.spawn(function()
        local IntroStartAt: number = os.clock()
        local IntroReadyAt: number = IntroStartAt + MATCH_INTRO_END_TIME
        local IntroAckDeadline: number = IntroReadyAt + MATCH_INTRO_ACK_TIMEOUT
        local CurrentSelectedPlayers: {Player} = {}
        local ActivatedPlayers: {Player} = {}
        local PlayersPrepared: boolean = false
        local SequenceResolved: boolean = false
        local OpeningTeam: number = ChooseOpeningTeam()

        local function ResolveSelectedPlayers(): {Player}
            return if FTPlayerService.GetSelectedPlayers
                then FTPlayerService:GetSelectedPlayers()
                else {}
        end

        local function ClearIntroFinishState(): ()
            introFinishAcks[Token] = nil
            introFinishResolvers[Token] = nil
            ClearActiveIntroState(Token)
        end

        local function LeaveActivatedPlayers(): ()
            for _, Player in ActivatedPlayers do
                LeaveMatchPlayer(Player)
            end
        end

        local function AbortPreMatchSequence(CleanupActivatedPlayers: boolean): ()
            if SequenceResolved then
                return
            end

            SequenceResolved = true
            ClearIntroFinishState()
            introCutsceneLock:Stop(LockToken)
            preMatchSequenceActive = false
            playEndLocked = false

            if CleanupActivatedPlayers then
                LeaveActivatedPlayers()
            end
        end

        local function PreparePlayersForMatchStart(): boolean
            if PlayersPrepared then
                return true
            end

            CurrentSelectedPlayers = ResolveSelectedPlayers()
            if #CurrentSelectedPlayers < MinimumPlayers then
                return false
            end

            gameState.PossessingTeam = OpeningTeam
            ActivatedPlayers = if FTPlayerService.ActivateSelectedPlayersForMatch
                then FTPlayerService:ActivateSelectedPlayersForMatch()
                else {}
            if #ActivatedPlayers < MinimumPlayers then
                return false
            end

            introCutsceneLock:CaptureCurrentPivots(ActivatedPlayers)
            PlayersPrepared = true
            return true
        end

        local function FinalizePreMatchSequence(): ()
            if SequenceResolved then
                return
            end

            CurrentSelectedPlayers = ResolveSelectedPlayers()
            if #CurrentSelectedPlayers < MinimumPlayers then
                AbortPreMatchSequence(PlayersPrepared)
                return
            end

            ClearIntroFinishState()

            if preMatchSequenceToken ~= Token or gameState.MatchStarted then
                SequenceResolved = true
                return
            end

            -- Move the live characters on the exact ACK of tween-in completion,
            -- with the loop below only serving as a timeout fallback.
            if not PlayersPrepared and not PreparePlayersForMatchStart() then
                AbortPreMatchSequence(true)
                return
            end

            SequenceResolved = true
            introCutsceneLock:Stop(LockToken)
            preMatchSequenceActive = false
            BeginCountdownNow(false)
        end

        local function TryResolveIntroCompletion(): ()
            if SequenceResolved or os.clock() < IntroReadyAt then
                return
            end

            CurrentSelectedPlayers = ResolveSelectedPlayers()
            if #CurrentSelectedPlayers < MinimumPlayers then
                AbortPreMatchSequence(PlayersPrepared)
                return
            end

            if HaveAllIntroPlayersFinished(Token, CurrentSelectedPlayers) then
                FinalizePreMatchSequence()
            end
        end

        introFinishResolvers[Token] = function()
            task.defer(TryResolveIntroCompletion)
        end

        while os.clock() < IntroAckDeadline do
            if preMatchSequenceToken ~= Token or gameState.MatchStarted then
                ClearIntroFinishState()
                return
            end

            CurrentSelectedPlayers = ResolveSelectedPlayers()
            if #CurrentSelectedPlayers < MinimumPlayers then
                AbortPreMatchSequence(PlayersPrepared)
                return
            end

            TryResolveIntroCompletion()
            if SequenceResolved then
                return
            end

            task.wait(MATCH_INTRO_ACK_POLL_INTERVAL)
        end

        if SequenceResolved then
            return
        end

        FinalizePreMatchSequence()
    end)
end

StartCountdown = function(allowDuringMatch: boolean?): ()
    if allowDuringMatch then
        BeginCountdownNow(true)
        return
    end

    if gameState.MatchStarted or gameState.CountdownActive or gameState.IntermissionActive then
        return
    end

    BeginPreMatchSequence()
end

local function EndMatch(): ()
    if not gameState.MatchStarted then
        return
    end

    local WinnerTeam: number? = nil
    if gameState.Team1Score > gameState.Team2Score then
        WinnerTeam = 1
    elseif gameState.Team2Score > gameState.Team1Score then
        WinnerTeam = 2
    end

    local Result: MatchResult = {
        WinnerTeam = WinnerTeam,
        Team1Score = gameState.Team1Score,
        Team2Score = gameState.Team2Score,
    }
    MatchEndedSignal:Fire(Result)

    pendingCountdownToken += 1
    countdownToken += 1
    preMatchSequenceToken += 1
    preMatchSequenceActive = false
    introCutsceneLock:Stop(nil)
    ClearActiveIntroState(nil)
    if FTBallService.CleanupMatchArtifacts then
        FTBallService:CleanupMatchArtifacts()
    end
    ResetMatchRoundState(true)
    ReleaseAllCountdownFreezeStates()
    for _, player in Players:GetPlayers() do
        if FTPlayerService:IsPlayerInMatch(player) then
            LeaveMatchPlayer(player)
        end
    end
    ResetMatchPositions()
    StartIntermission()
end

local function UpdateGameClock(): ()
    if gameState.IntermissionActive then
        if gameState.IntermissionTime > 0 then
            gameState.IntermissionTime = gameState.IntermissionTime - 1
            if gameStateInstances.IntermissionTime then
                gameStateInstances.IntermissionTime.Value = gameState.IntermissionTime
            end
        else
            gameState.IntermissionActive = false
            gameState.IntermissionTime = 0
            if gameStateInstances.IntermissionActive then
                gameStateInstances.IntermissionActive.Value = false
            end
            if gameStateInstances.IntermissionTime then
                gameStateInstances.IntermissionTime.Value = 0
            end
            StartCountdown(false)
        end
        return
    end

    if not gameStateInstances.MatchEnabled or not gameStateInstances.MatchEnabled.Value then return end
    if not gameState.MatchStarted then return end
    if not gameState.MatchActive then return end

    if gameState.GameTime > 0 then
        gameState.GameTime = gameState.GameTime - 1
        if gameStateInstances.GameTime then
            gameStateInstances.GameTime.Value = gameState.GameTime
        end
        if gameState.GameTime <= 0 then
            gameState.GameTime = 0
            if gameStateInstances.GameTime then
                gameStateInstances.GameTime.Value = 0
            end
            EndMatch()
            return
        end
    end

    if gameState.PlayClock > 0 then
        gameState.PlayClock = gameState.PlayClock - 1
    end
end

local function ResetDown(): ()
    gameState.Down = 1
    gameState.YardsToGain = FTConfig.GAME_CONFIG.DownsToGain
end

GetTeamSide = function(team: number): string
    return if team == 1 then "HOME" else "AWAY"
end

SendScoreNotify = function(message: string, description: string?, duration: number?): ()
    Packets.ScoreNotify:Fire(message, description or "", duration or SCORE_NOTIFY_DURATION)
end

SendDownNotify = function(duration: number?, messageOverride: string?, descriptionOverride: string?): ()
    local desc = descriptionOverride or ""
    if desc == "" then
        local gain = math.floor(math.abs(lastPlayGain) + 0.5)
        if gain > 0 then
            if lastPlayGain >= 0 then
                desc = ("GAINED %d YARDS"):format(gain)
            else
                desc = ("LOST %d YARDS"):format(gain)
            end
        end
    end
    local message = if typeof(messageOverride) == "string" and messageOverride ~= ""
        then messageOverride
        else ("DOWN %d!"):format(gameState.Down)
    SendScoreNotify(message, desc, duration or DOWN_NOTIFY_DURATION)
end

local function AwardTouchdown(Team: number): ()
    if Team == 1 then
        gameState.Team1Score = gameState.Team1Score + FTConfig.GAME_CONFIG.TouchdownPoints
        if gameStateInstances.Team1Score then
            gameStateInstances.Team1Score.Value = gameState.Team1Score
        end
    else
        gameState.Team2Score = gameState.Team2Score + FTConfig.GAME_CONFIG.TouchdownPoints
        if gameStateInstances.Team2Score then
            gameStateInstances.Team2Score.Value = gameState.Team2Score
        end
    end
    UpdateScoreboards()
    ResetDown()
end

local function AwardFieldGoal(Team: number): ()
    if Team == 1 then
        gameState.Team1Score = gameState.Team1Score + FTConfig.GAME_CONFIG.FieldGoalPoints
        if gameStateInstances.Team1Score then
            gameStateInstances.Team1Score.Value = gameState.Team1Score
        end
    else
        gameState.Team2Score = gameState.Team2Score + FTConfig.GAME_CONFIG.FieldGoalPoints
        if gameStateInstances.Team2Score then
            gameStateInstances.Team2Score.Value = gameState.Team2Score
        end
    end
    UpdateScoreboards()
    ResetDown()
    local desc = ("%d+ POINTS %s"):format(FTConfig.GAME_CONFIG.FieldGoalPoints, GetTeamSide(Team))
    SendScoreNotify("FIELD GOAL!", desc, SCORE_NOTIFY_DURATION)
end

StartIntermission = function(): ()
    gameState.IntermissionActive = true
    gameState.IntermissionTime = FTConfig.GAME_CONFIG.IntermissionDuration
    lastDownCarrier = nil
    lastPlayGain = 0
    playEndLocked = false
    preMatchSequenceToken += 1
    preMatchSequenceActive = false
    introCutsceneLock:Stop(nil)
    ClearActiveIntroState(nil)
    SetLOSVisible(false)
    if gameStateInstances.IntermissionActive then
        gameStateInstances.IntermissionActive.Value = true
    end
    if gameStateInstances.IntermissionTime then
        gameStateInstances.IntermissionTime.Value = gameState.IntermissionTime
    end
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function FTGameService.Init(_self: typeof(FTGameService)): ()
    InitializeGameStateInstances()
    StartIntermission()
    local function BindCountdownCharacterLifecycle(player: Player): ()
        if countdownCharacterConnections[player] then
            countdownCharacterConnections[player]:Disconnect()
            countdownCharacterConnections[player] = nil
        end
        countdownCharacterConnections[player] = player.CharacterAdded:Connect(function(character: Model)
            if not gameState.CountdownActive then
                return
            end
            task.defer(function()
                if player.Parent == nil or player.Character ~= character or not gameState.CountdownActive then
                    return
                end
                ApplyCountdownFreezeToPlayer(player)
            end)
        end)
    end

    Players.PlayerAdded:Connect(function(player: Player)
        BindCountdownCharacterLifecycle(player)
        task.defer(function()
            EnsurePlayerReceivesActiveIntro(player)
        end)
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        if countdownCharacterConnections[player] then
            countdownCharacterConnections[player]:Disconnect()
            countdownCharacterConnections[player] = nil
        end
        countdownFreezeStates[player] = nil
        countdownStoredSpeeds[player] = nil
        leaveMatchRequestCooldowns[player] = nil
        task.defer(ResetMatchIfEmptyAfterLeave)
    end)
    for _, player in Players:GetPlayers() do
        BindCountdownCharacterLifecycle(player)
    end
    Packets.DebugResetRequest.OnServerEvent:Connect(HandleDebugReset)
    Packets.MatchIntroFinished.OnServerEvent:Connect(function(Player: Player, TokenValue: number)
        if typeof(TokenValue) ~= "number" then
            return
        end

        local AckMap: {[Player]: boolean}? = introFinishAcks[TokenValue]
        if not AckMap then
            return
        end

        AckMap[Player] = true

        local Resolver = introFinishResolvers[TokenValue]
        if Resolver then
            Resolver()
        end
    end)
    Packets.LeaveMatch.OnServerEvent:Connect(function(Player: Player)
        if not CanPlayerLeaveMatch(Player) then
            return
        end

        local AvailableAt = leaveMatchRequestCooldowns[Player] or 0
        local Now = os.clock()
        if Now < AvailableAt then
            return
        end

        leaveMatchRequestCooldowns[Player] = Now + LEAVE_MATCH_REQUEST_COOLDOWN
        LeaveMatchPlayer(Player)
        ResetMatchIfEmptyAfterLeave()
    end)
    if FTBallService.OnInterception then
        FTBallService:OnInterception(HandleInterception)
    end
    if FTBallService.SetPlayEndCallback then
        FTBallService:SetPlayEndCallback(function(pos: Vector3, reason: string, lastInBoundsX: number?, throwOriginX: number?, throwTeam: number?)
            ProcessPlayEnd(pos, reason, lastInBoundsX, throwOriginX, throwTeam)
        end)
    end
    if FTBallService.SetCampoChecker then
        FTBallService:SetCampoChecker(function(pos: Vector3)
            return IsPointInCampoZone(pos)
        end)
    end
end

function FTGameService.Start(_self: typeof(FTGameService)): ()
    task.spawn(function()
        while true do
            task.wait(1)
            UpdateGameClock()
        end
    end)
end

function FTGameService.GetGameState(_self: typeof(FTGameService)): GameState
    return gameState
end

function FTGameService.GetMatchEndedSignal(_self: typeof(FTGameService)): any
    return MatchEndedSignal
end

function FTGameService.SetMatchActive(_self: typeof(FTGameService), Active: boolean): ()
    gameState.MatchActive = Active
end

function FTGameService.ProcessPlayEnd(_self: typeof(FTGameService), position: Vector3, reason: string?, lastInBoundsX: number?, throwOriginX: number?, throwTeam: number?): {report: {[string]: any}}
    return ProcessPlayEnd(position, reason, lastInBoundsX, throwOriginX, throwTeam)
end

function FTGameService.AwardTouchdown(_self: typeof(FTGameService), Team: number): ()
    AwardTouchdown(Team)
end

function FTGameService.AwardFieldGoal(_self: typeof(FTGameService), Team: number): ()
    AwardFieldGoal(Team)
end

function FTGameService.ResolveGroundedTeleportCFrame(_self: typeof(FTGameService), Character: Model, Target: CFrame): CFrame
    return ResolveGroundedTeleportCFrameForCharacter(Character, Target)
end

function FTGameService.TeleportPlayersToYard(_self: typeof(FTGameService), Yard: number, forceCustom: boolean?): ()
    local clampedYard = math.clamp(Yard, 0, 100)
    local targetX = YardToX(clampedYard)
    TeleportMatchPlayersToX(targetX, forceCustom)
end

function FTGameService.BeginSeriesAtYard(_self: typeof(FTGameService), Yard: number, Team: number): ()
    BeginSeries(Yard, Team)
end

function FTGameService.SetExtraPointActive(_self: typeof(FTGameService), Active: boolean): ()
    gameState.ExtraPointActive = Active
end

function FTGameService.SetPlayEndLocked(_self: typeof(FTGameService), Locked: boolean): ()
    playEndLocked = Locked == true
end

function FTGameService.SetInvulnerable(_self: typeof(FTGameService), value: boolean): ()
    SetInvulnerableForMatch(value)
end

function FTGameService.IsIntermissionActive(_self: typeof(FTGameService)): boolean
    return gameState.IntermissionActive
end

function FTGameService.IsMatchStarted(_self: typeof(FTGameService)): boolean
    return gameState.MatchStarted
end

function FTGameService.SuppressTeleportFade(_self: typeof(FTGameService), duration: number?): ()
    local seconds = if typeof(duration) == "number" and duration > 0 then duration else 1.5
    teleportFadeSuppressedUntil = math.max(teleportFadeSuppressedUntil, os.clock() + seconds)
end

function FTGameService.IsPlayerInMatch(_self: typeof(FTGameService), Player: Player): boolean
    return FTPlayerService:IsPlayerInMatch(Player)
end

function FTGameService.StartCountdown(_self: typeof(FTGameService), allowDuringMatch: boolean?): ()
    StartCountdown(allowDuringMatch)
end

function FTGameService.OnPlayerPositionSelected(_self: typeof(FTGameService), Player: Player): ()
    EnsurePlayerReceivesActiveIntro(Player)
end

function FTGameService.AdvanceDown(_self: typeof(FTGameService)): ()
    gameState.Down = gameState.Down + 1
    if gameState.Down > FTConfig.GAME_CONFIG.MaxDowns then
        gameState.Down = 1
        gameState.YardsToGain = FTConfig.GAME_CONFIG.DownsToGain
    end
end

function FTGameService.IsPointInCampo(_self: typeof(FTGameService), position: Vector3): boolean
    return IsPointInCampoZone(position)
end

return FTGameService

