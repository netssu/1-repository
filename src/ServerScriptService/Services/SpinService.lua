
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local FTPlayerService = require(script.Parent.PlayerService)

local FTSpinService = {}

--\ MODULE STATE \ --
local RUN_DRAIN_MULTIPLIER = 0.3
local RUN_SPEED_THRESHOLD_DEFAULT = 17
local MIN_STAMINA_TO_RUN = FTConfig.TACKLE_CONFIG and FTConfig.TACKLE_CONFIG.MinStaminaToRun or 5
local playerStamina: {[Player]: number} = {}
local playerSpinCooldown: {[Player]: number} = {}
local playerSpinActive: {[Player]: boolean} = {}
local playerRunningFlag: {[Player]: boolean} = {}
local matchEnabledInstance: BoolValue? = nil
local matchStartedInstance: BoolValue? = nil
local matchFolder: Folder? = nil
local SetRunningState: (Player, boolean) -> ()

local INVULNERABLE_ATTR = "Invulnerable"
local SKILL_LOCK_ATTR = "FTSkillLocked"

--\ PRIVATE FUNCTIONS \ --
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

local function IsPlayerInMatch(Player: Player): boolean
    return FTPlayerService:IsPlayerInMatch(Player)
end

local function CanPlayerAct(Player: Player): boolean
    if not GetMatchEnabled() then return false end
    if not GetMatchStarted() then return false end
    if not IsPlayerInMatch(Player) then return false end
    if Player:GetAttribute(INVULNERABLE_ATTR) == true then
        return false
    end
    if Player:GetAttribute(SKILL_LOCK_ATTR) == true then
        return false
    end
    local character = Player.Character
    if character and character:GetAttribute(INVULNERABLE_ATTR) == true then
        return false
    end
    if character and character:GetAttribute(SKILL_LOCK_ATTR) == true then
        return false
    end
    return true
end

local function GetPlayerStamina(Player: Player): number
    if playerStamina[Player] == nil then
        playerStamina[Player] = FTConfig.STAMINA_CONFIG.MaxStamina
    end
    return playerStamina[Player]
end

local function SetPlayerStamina(Player: Player, Stamina: number): ()
    playerStamina[Player] = math.clamp(Stamina, 0, FTConfig.STAMINA_CONFIG.MaxStamina)
    Packets.PlayerStaminaUpdate:FireClient(Player, playerStamina[Player])
end

local function HasEnoughStamina(Player: Player): boolean
    local CurrentStamina = GetPlayerStamina(Player)
    local SpinCost = FlowBuffs.ApplyStaminaCostReduction(Player, FTConfig.STAMINA_CONFIG.SpinStaminaCost)
    return CurrentStamina >= SpinCost
end

local function RegenerateStamina(Player: Player, DeltaTime: number): ()
    local CurrentStamina = GetPlayerStamina(Player)
    if CurrentStamina >= FTConfig.STAMINA_CONFIG.MaxStamina then return end
    local NewStamina = CurrentStamina + (FTConfig.STAMINA_CONFIG.StaminaRegenRate * DeltaTime)
    SetPlayerStamina(Player, NewStamina)
end

local function DrainStaminaForRunning(Player: Player, DeltaTime: number): ()
    local CurrentStamina = GetPlayerStamina(Player)
    if CurrentStamina <= 0 then
        SetPlayerStamina(Player, 0)
        SetRunningState(Player, false)
        return
    end
    local drainRate = FlowBuffs.ApplyStaminaCostReduction(
        Player,
        (FTConfig.STAMINA_CONFIG.StaminaDrainRate or 0) * RUN_DRAIN_MULTIPLIER
    )
    local NewStamina = CurrentStamina - (drainRate * DeltaTime)
    SetPlayerStamina(Player, NewStamina)
end

local function CanUseSpin(Player: Player): boolean
    local attr = Player:GetAttribute("FTCanSpin")
    if attr ~= nil and attr == false then
        return false
    end
    local character = Player.Character
    if character then
        local charAttr = character:GetAttribute("FTCanSpin")
        if charAttr ~= nil and charAttr == false then
            return false
        end
    end
    if playerSpinActive[Player] then return false end
    if playerSpinCooldown[Player] and playerSpinCooldown[Player] > 0 then return false end
    if not HasEnoughStamina(Player) then return false end
    return true
end

local function GetSpinDuration(Player: Player): number
    return FTConfig.SPIN_CONFIG.SpinDuration + (FlowBuffs.GetDribbleBonus(Player) * 0.01)
end

local function HandleSpinActivate(Player: Player): ()
    if not CanPlayerAct(Player) then return end
    if not CanUseSpin(Player) then return end
    if Player:GetAttribute(INVULNERABLE_ATTR) == true then return end
    local Character = Player.Character
    if not Character then return end
    if Character:GetAttribute(INVULNERABLE_ATTR) == true then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end
    local CurrentStamina = GetPlayerStamina(Player)
    local SpinCost = FlowBuffs.ApplyStaminaCostReduction(Player, FTConfig.STAMINA_CONFIG.SpinStaminaCost)
    SetPlayerStamina(Player, CurrentStamina - SpinCost)
    playerSpinActive[Player] = true
    playerSpinCooldown[Player] = FTConfig.SPIN_CONFIG.SpinCooldown
    task.delay(GetSpinDuration(Player), function()
        playerSpinActive[Player] = false
    end)
end

SetRunningState = function(Player: Player, isRunning: boolean): ()
    playerRunningFlag[Player] = isRunning
end

local function HandleRunningStateUpdate(Player: Player, isRunning: boolean): ()
    SetRunningState(Player, isRunning == true)
end

local function IsPlayerRunning(Player: Player): boolean
    if not CanPlayerAct(Player) then return false end
    local Character = Player.Character
    if not Character then return false end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not Humanoid or not root then return false end
    local runningAttr = playerRunningFlag[Player] == true
    if runningAttr ~= true then
        return false
    end
    local moveDirMag = Humanoid.MoveDirection.Magnitude
    local velocityMag = root.AssemblyLinearVelocity.Magnitude
    local isMoving = moveDirMag > 0.05 or velocityMag > 2
    if not isMoving then
        return false
    end
    if GetPlayerStamina(Player) < MIN_STAMINA_TO_RUN then
        SetRunningState(Player, false)
        return false
    end
    return runningAttr and isMoving
end

local function UpdateStaminaRegeneration(DeltaTime: number): ()
    for _, Player in Players:GetPlayers() do
        if IsPlayerRunning(Player) then
            DrainStaminaForRunning(Player, DeltaTime)
            if playerRunningFlag[Player] and GetPlayerStamina(Player) <= 0 then
                SetRunningState(Player, false)
            end
        elseif not playerSpinActive[Player] then
            RegenerateStamina(Player, DeltaTime)
        end
    end
end

local function UpdateCooldowns(DeltaTime: number): ()
    for Player, Cooldown in playerSpinCooldown do
        if Cooldown > 0 then
            playerSpinCooldown[Player] = Cooldown - DeltaTime
            if playerSpinCooldown[Player] <= 0 then
                playerSpinCooldown[Player] = 0
            end
        end
    end
end

local function ResetPlayerState(Player: Player): ()
    playerSpinActive[Player] = nil
    playerSpinCooldown[Player] = nil
    playerRunningFlag[Player] = nil
    SetPlayerStamina(Player, FTConfig.STAMINA_CONFIG.MaxStamina)
end

local function HandlePlayerAdded(Player: Player): ()
    playerStamina[Player] = FTConfig.STAMINA_CONFIG.MaxStamina
    playerSpinCooldown[Player] = 0
    playerSpinActive[Player] = false
    playerRunningFlag[Player] = false
    task.defer(function()
        Packets.PlayerStaminaUpdate:FireClient(Player, playerStamina[Player])
    end)
end

local function HandlePlayerRemoving(Player: Player): ()
    playerStamina[Player] = nil
    playerSpinCooldown[Player] = nil
    playerSpinActive[Player] = nil
    playerRunningFlag[Player] = nil
end

--\ PUBLIC FUNCTIONS \ --
function FTSpinService.Init(_self: typeof(FTSpinService)): ()
    Packets.SpinActivate.OnServerEvent:Connect(HandleSpinActivate)
    Packets.RunningStateUpdate.OnServerEvent:Connect(HandleRunningStateUpdate)
    Players.PlayerAdded:Connect(HandlePlayerAdded)
    Players.PlayerRemoving:Connect(HandlePlayerRemoving)
    for _, Player in Players:GetPlayers() do
        HandlePlayerAdded(Player)
    end
end

function FTSpinService.Start(_self: typeof(FTSpinService)): ()
    RunService.Heartbeat:Connect(function(DeltaTime)
        UpdateStaminaRegeneration(DeltaTime)
        UpdateCooldowns(DeltaTime)
    end)
end

function FTSpinService.GetPlayerStamina(_self: typeof(FTSpinService), Player: Player): number
    return GetPlayerStamina(Player)
end

function FTSpinService.IsSpinActive(_self: typeof(FTSpinService), Player: Player): boolean
    return playerSpinActive[Player] == true
end

function FTSpinService.SetRunningState(_self: typeof(FTSpinService), Player: Player, isRunning: boolean): ()
    SetRunningState(Player, isRunning)
end

function FTSpinService.GetRunningState(_self: typeof(FTSpinService), Player: Player): boolean
    return playerRunningFlag[Player] == true
end

function FTSpinService.ResetPlayer(_self: typeof(FTSpinService), Player: Player): ()
    ResetPlayerState(Player)
end

return FTSpinService
