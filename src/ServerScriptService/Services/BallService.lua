--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local ThrowPrediction = require(ReplicatedStorage.Modules.Game.ThrowPrediction)
local FTRefereeService = require(script.Parent.RefereeService)
local FTPlayerService = require(script.Parent.PlayerService)
local PlayerStatsTracker = require(ServerScriptService.Services.Utils.PlayerStatsTracker)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)

local BallStateModule = require(script.BallState)
local BallState = BallStateModule
local Utility = require(ReplicatedStorage.Modules.Game.Utility)

local FTBallService = {}

--\\ CONSTANTS \\ -- TR
local BALL_OFFSET_R6: CFrame = CFrame.new(-0.1, -1.3, -0.5) * CFrame.Angles(0, math.rad(90), 0)
local THROW_CONFIG = FTConfig.THROW_CONFIG
local MAX_THROW_DISTANCE: number = THROW_CONFIG.MaxThrowDistance
local MIN_THROW_POWER: number = THROW_CONFIG.MinThrowPower
local MAX_THROW_POWER: number = THROW_CONFIG.MaxThrowPower
local THROW_TIME_DIVISOR: number = THROW_CONFIG.TimeDivisor
local MIN_THROW_TIME: number = THROW_CONFIG.MinFlightTime
local MAX_THROW_TIME: number = THROW_CONFIG.MaxFlightTime
local THROW_SPAWN_VELOCITY_LEAD: number = THROW_CONFIG.SpawnVelocityLeadTime
local EXTRA_POINT_KICK_CINEMATIC_TIME: number = 0.8
local EXTRA_POINT_KICK_RELEASE_QUEUE: number = 0.12
local EXTRA_POINT_BALL_OFFSET: number = 1.5
local EXTRA_POINT_BALL_HEIGHT: number = 0.1
local EXTRA_POINT_POST_GOAL_CONTINUE_DURATION: number = 2.15
local EXTRA_POINT_POST_GOAL_GRAVITY: number = 72
local PASS_CATCH_WINDOW: number = 2
local MAX_CLIENT_THROW_RELEASE_LEAD: number = THROW_CONFIG.MaxClientReleaseLead
local MAX_CLIENT_THROW_RELEASE_BACKTRACK: number = THROW_CONFIG.MaxClientReleaseBacktrack
local MAX_CLIENT_THROW_RELEASE_QUEUE: number = 1 / 120
local INVULNERABLE_ATTR: string = "Invulnerable"
local TOUCHDOWN_PAUSE_ATTRIBUTE: string = "FTScoringPauseLocked"

--\\ MODULE STATE \\ -- TR
local BallInstance: BasePart? = nil
local BallWeld: Weld? = nil
local State = BallState.new()
local MatchEnabledInstance: BoolValue? = nil
local MatchStartedInstance: BoolValue? = nil
local MatchFolder: Folder? = nil
local possessionTeam: number? = nil
local interceptionListeners: {(info: {team: number, position: Vector3, yard: number}) -> ()} = {}
local lastInBoundsCarrierX: number? = nil
local lastInBoundsBallX: number? = nil
local outCooldownUntil: number = 0
local wasInAir: boolean = false
local lastThrowOriginX: number? = nil
local lastThrowTeam: number? = nil
local playEndCallbacks: {((pos: Vector3, reason: string, lastInBoundsX: number?, throwOriginX: number?, throwTeam: number?) -> ())} = {}
local inCampoChecker: ((pos: Vector3) -> boolean)? = nil
local extraPointActive: boolean = false
local extraPointKickToken: number = 0
local extraPointGoalTeam: number? = nil
local extraPointPostGoalTriggered: boolean = false
local extraPointPostGoalStartedAt: number = 0
local extraPointPostGoalOrigin: Vector3 = Vector3.zero
local extraPointPostGoalVelocity: Vector3 = Vector3.zero
local goalTouchCallbacks: {((goalTeam: number, part: BasePart) -> ())} = {}
local ballTouchedConnection: RBXScriptConnection? = nil
local lastTouchingParts: {[BasePart]: boolean} = {}
local BallDataValue: StringValue? = nil
local ExternalHolderModel: Model? = nil
local ExternalHolderTeam: number? = nil
local DetachBallFromPlayer: (Character: Model?) -> () = function(_Character: Model?): ()
end

type PriorityCatchRequest = {
	ExpiresAt: number,
	Radius: number,
	Priority: number,
	RequestedAt: number,
}

type PriorityCatchEntry = {
	Player: Player,
	Request: PriorityCatchRequest,
}

type PendingPassAttempt = {
	Passer: Player,
	Team: number,
	ArrivalTime: number,
	ExpireTime: number,
	ThrowOriginX: number?,
	Target: Vector3,
}

local PriorityCatchRequests: {[Player]: PriorityCatchRequest} = {}
local pendingPassAttempt: PendingPassAttempt? = nil

local GiveBallToPlayer: (Player: Player) -> ()
local FireToAllClients: () -> ()
local UpdateBallCarrierValue: (Player: Player?) -> ()
local AttachBallToPlayer: (Player: Player) -> ()
local function GetBallData(): StringValue?
	if BallDataValue and BallDataValue.Parent then
		return BallDataValue
	end
	local existing = ReplicatedStorage:FindFirstChild("FTBallData")
	if existing and existing:IsA("StringValue") then
		BallDataValue = existing
		return existing
	end
	local value = Instance.new("StringValue")
	value.Name = "FTBallData"
	value.Value = "Football"
	value.Parent = ReplicatedStorage
	BallDataValue = value
	return value
end

local function SetBallAttribute(name: string, value: any): ()
	local data = GetBallData()
	if data then
		data:SetAttribute(name, value)
	end
	if BallInstance and BallInstance:IsA("BasePart") then
		BallInstance:SetAttribute(name, value)
	end
end

local function GetNextBallSequence(): number
	local data = GetBallData()
	if not data then
		return 1
	end
	return (data:GetAttribute("FTBall_Seq") or 0) + 1
end

local function ClearExternalHolderState(): ()
	ExternalHolderModel = nil
	ExternalHolderTeam = nil
	SetBallAttribute("FTBall_ExternalHolder", nil)
end

local function GetExternalHolder(): Model?
	local holder = ExternalHolderModel
	if holder and holder.Parent ~= nil then
		return holder
	end
	if holder ~= nil then
		ClearExternalHolderState()
	end
	return nil
end

local function HasExternalHolder(): boolean
	return GetExternalHolder() ~= nil
end

local function GetBallAttachPartForModel(Model: Model?): BasePart?
	if not Model then
		return nil
	end

	local RightArm = (
		Model:FindFirstChild("Right Arm")
		or Model:FindFirstChild("RightHand")
		or Model:FindFirstChild("RightLowerArm")
		or Model:FindFirstChild("RightUpperArm")
	) :: BasePart?

	if RightArm then
		return RightArm
	end

	return Model:FindFirstChild("HumanoidRootPart") :: BasePart?
end
local function NotifyInterception(info: {team: number, position: Vector3, yard: number})
	for _, callback in interceptionListeners do
		task.spawn(callback, info)
	end
end

local function ClearPendingPassAttempt(): ()
	pendingPassAttempt = nil
end

local function GetYardAtPosition(Position: Vector3): number
	local gameFolder = Workspace:FindFirstChild("Game")
	local yardFolder = gameFolder and gameFolder:FindFirstChild("Jardas")
	local g1 = yardFolder and yardFolder:FindFirstChild("GTeam1")
	local g2 = yardFolder and yardFolder:FindFirstChild("GTeam2")
	local yard = 50
	if g1 and g2 and g1:IsA("BasePart") and g2:IsA("BasePart") then
		local startX = g1.Position.X
		local endX = g2.Position.X
		local length = endX - startX
		if math.abs(length) > 1e-3 then
			yard = math.clamp(((Position.X - startX) / length) * 100, 0, 100)
		end
	end
	return yard
end

local function StartPendingPassAttempt(
	Player: Player,
	LaunchTime: number,
	SpawnPos: Vector3,
	ValidTarget: Vector3,
	AppliedPower: number,
	TrackPassingStat: boolean?
): ()
	if TrackPassingStat == false then
		ClearPendingPassAttempt()
		return
	end

	local Team: number? = FTPlayerService:GetPlayerTeam(Player)
	if Team == nil then
		ClearPendingPassAttempt()
		return
	end

	local FlightTime: number = (ValidTarget - SpawnPos).Magnitude / math.max(AppliedPower, 0.05)
	local ArrivalTime: number = LaunchTime + FlightTime
	pendingPassAttempt = {
		Passer = Player,
		Team = Team,
		ArrivalTime = ArrivalTime,
		ExpireTime = ArrivalTime + PASS_CATCH_WINDOW,
		ThrowOriginX = SpawnPos.X,
		Target = ValidTarget,
	}
end

local function ResolveExpiredPendingPassAttempt(): ()
	local Attempt: PendingPassAttempt? = pendingPassAttempt
	if not Attempt then
		return
	end
	if Attempt.Passer.Parent == nil then
		ClearPendingPassAttempt()
		return
	end

	local Now: number = Workspace:GetServerTimeNow()
	if Now < Attempt.ExpireTime then
		return
	end

	if HasExternalHolder() or State:GetPossession() ~= nil then
		ClearPendingPassAttempt()
		return
	end
	if State:IsInAir() or not State:IsOnGround() then
		return
	end

	local Position: Vector3 = Attempt.Target
	if BallInstance and BallInstance:IsA("BasePart") then
		Position = BallInstance.Position
	end

	ClearPendingPassAttempt()
	for _, callback in playEndCallbacks do
		callback(Position, "Incomplete pass", nil, Attempt.ThrowOriginX, Attempt.Team)
	end
end

local function ResolvePendingPassAttempt(Catcher: Player?): ()
	local Attempt: PendingPassAttempt? = pendingPassAttempt
	ClearPendingPassAttempt()

	if not Attempt or not Catcher or Catcher.Parent == nil then
		return
	end

	local CatcherTeam: number? = FTPlayerService:GetPlayerTeam(Catcher)
	local CatchTime: number = Workspace:GetServerTimeNow()
	if CatcherTeam ~= Attempt.Team then
		return
	end
	if Catcher == Attempt.Passer then
		return
	end
	if CatchTime < Attempt.ArrivalTime or CatchTime > Attempt.ExpireTime then
		return
	end

	PlayerStatsTracker.AwardPass(Attempt.Passer)
end

local function ResolvePendingPassAttemptForExternalHolder(HolderModel: Model?, HolderTeam: number?): ()
	local Attempt: PendingPassAttempt? = pendingPassAttempt
	if not Attempt or not HolderModel or HolderModel.Parent == nil then
		return
	end

	local CatchTime: number = Workspace:GetServerTimeNow()
	local HolderIsNeutralTestRig: boolean = HolderModel:GetAttribute("FTSoloTackleRig") == true
	if CatchTime > Attempt.ExpireTime then
		ClearPendingPassAttempt()
		return
	end

	if not HolderIsNeutralTestRig and CatchTime < Attempt.ArrivalTime then
		ClearPendingPassAttempt()
		return
	end

	if not HolderIsNeutralTestRig and HolderTeam ~= Attempt.Team then
		ClearPendingPassAttempt()
		return
	end

	ClearPendingPassAttempt()
	PlayerStatsTracker.AwardPass(Attempt.Passer)
end

local function CompleteBallCatch(Player: Player, CatchPosition: Vector3?): ()
	local Character = Player.Character
	if not Character then
		return
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local EffectiveCatchPosition: Vector3 = CatchPosition or Vector3.zero
	if CatchPosition == nil then
		if Root then
			EffectiveCatchPosition = Root.Position
		elseif BallInstance and BallInstance:IsA("BasePart") then
			EffectiveCatchPosition = BallInstance.Position
		end
	end
	local PhysicsData = State:GetPhysicsData()

	State:SetInAir(false)
	State:SetPossession(Player)
	State:SetOnGround(false)
	ClearExternalHolderState()

	local NewTeam: number? = FTPlayerService:GetPlayerTeam(Player)
	if NewTeam then
		local PreviousTeam: number? = possessionTeam
		possessionTeam = NewTeam
		if PreviousTeam and PreviousTeam ~= NewTeam and PhysicsData ~= nil then
			NotifyInterception({
				team = NewTeam,
				position = EffectiveCatchPosition,
				yard = GetYardAtPosition(EffectiveCatchPosition),
			})
		end
	end

	ResolvePendingPassAttempt(Player)
	lastInBoundsCarrierX = nil
	lastInBoundsBallX = nil
	outCooldownUntil = 0
	State:ClearPhysicsData()

	UpdateBallCarrierValue(Player)
	AttachBallToPlayer(Player)
	if BallInstance and BallInstance:IsA("BasePart") then
		SetBallAttribute("FTBall_InAir", false)
		SetBallAttribute("FTBall_OnGround", false)
		SetBallAttribute("FTBall_Possession", PlayerIdentity.GetIdValue(Player))
		SetBallAttribute("FTBall_ExternalHolder", nil)
		SetBallAttribute("FTBall_GroundPos", nil)
		SetBallAttribute("FTBall_LaunchTime", nil)
		SetBallAttribute("FTBall_SpawnPos", nil)
		SetBallAttribute("FTBall_Target", nil)
		SetBallAttribute("FTBall_Power", nil)
		SetBallAttribute("FTBall_Curve", nil)
		SetBallAttribute("FTBall_Spin", nil)
	end

	FireToAllClients()
end

--\\ PRIVATE FUNCTIONS \\ -- TR
local function GetMatchEnabled(): boolean
	if not MatchEnabledInstance then
		local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
		if GameStateFolder then
			MatchEnabledInstance = GameStateFolder:FindFirstChild("MatchEnabled") :: BoolValue?
		end
	end
	return MatchEnabledInstance and MatchEnabledInstance.Value or false
end

local function GetMatchStarted(): boolean
	if not MatchStartedInstance then
		local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
		if GameStateFolder then
			MatchStartedInstance = GameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
		end
	end
	return MatchStartedInstance and MatchStartedInstance.Value or false
end

local function GetMatchFolder(): Folder?
	if MatchFolder then return MatchFolder end
	
	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if not GameStateFolder then return nil end
	
	MatchFolder = GameStateFolder:FindFirstChild("Match") :: Folder?
	return MatchFolder
end

local function IsPlayerInMatch(Player: Player): boolean
	return FTPlayerService:IsPlayerInMatch(Player)
end

local function CanPlayerAct(Player: Player): boolean
	if not GetMatchEnabled() then return false end
	if not IsPlayerInMatch(Player) then return false end
	return true
end

local function CanPlayerThrowWithOptions(Player: Player, IgnoreSkillLock: boolean?): boolean
	if not GetMatchEnabled() then return false end
	if not GetMatchStarted() then return false end
	if not IsPlayerInMatch(Player) then return false end
	if Player:GetAttribute("Invulnerable") == true then return false end
	if not IgnoreSkillLock and Player:GetAttribute("FTSkillLocked") == true then return false end
	local Character = Player.Character
	if Character then
		if Character:GetAttribute("Invulnerable") == true then return false end
		if not IgnoreSkillLock and Character:GetAttribute("FTSkillLocked") == true then return false end
	end
	return true
end

local function CanPlayerThrow(Player: Player): boolean
	return CanPlayerThrowWithOptions(Player, false)
end

local function IsPlayerProtectedFromPlayEnd(Player: Player?): boolean
	if not Player then
		return false
	end
	if Player:GetAttribute(INVULNERABLE_ATTR) == true or Player:GetAttribute(TOUCHDOWN_PAUSE_ATTRIBUTE) == true then
		return true
	end

	local Character = Player.Character
	if not Character then
		return false
	end

	return Character:GetAttribute(INVULNERABLE_ATTR) == true
		or Character:GetAttribute(TOUCHDOWN_PAUSE_ATTRIBUTE) == true
end

local function GetCampoHit(position: Vector3): RaycastResult?
	local Game = Workspace:FindFirstChild("Game")
	if not Game then return nil end
	local Campo = Game:FindFirstChild("Campo")
	if not Campo then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Campo }
	return Workspace:Raycast(position, Vector3.new(0, -50, 0), params)
end

local function GetCampoPlaneY(): number?
	local Game = Workspace:FindFirstChild("Game")
	if not Game then
		return nil
	end
	local Campo = Game:FindFirstChild("Campo")
	if not Campo then
		return nil
	end
	if Campo:IsA("BasePart") then
		return Campo.Position.Y + (Campo.Size.Y * 0.5)
	end
	if Campo:IsA("Model") then
		local cf, size = Campo:GetBoundingBox()
		return cf.Position.Y + (size.Y * 0.5)
	end
	return nil
end

local function GetExtraPointFixedPart(team: number?): BasePart?
	if not team or team <= 0 then
		return nil
	end
	local Game = Workspace:FindFirstChild("Game")
	if not Game then
		return nil
	end
	local fixedName = if team == 1 then "2TeamFixed" else "1TeamFixed"
	local part = Game:FindFirstChild(fixedName) :: BasePart?
	return part
end

local function GetGoalTeamFromPart(part: BasePart): number?
	local gameFolder = Workspace:FindFirstChild("Game")
	local goalFolder = gameFolder and gameFolder:FindFirstChild("Goal")
	if not goalFolder then
		return nil
	end
	local team1 = goalFolder:FindFirstChild("Team1")
	local team2 = goalFolder:FindFirstChild("Team2")
	if team1 and (part == team1 or part:IsDescendantOf(team1)) then
		return 1
	end
	if team2 and (part == team2 or part:IsDescendantOf(team2)) then
		return 2
	end
	return nil
end

local function GetGoalPartForTeam(team: number?): BasePart?
	if not team or team <= 0 then
		return nil
	end
	local gameFolder = Workspace:FindFirstChild("Game")
	local goalFolder = gameFolder and gameFolder:FindFirstChild("Goal")
	local goal = goalFolder and goalFolder:FindFirstChild("Team" .. team)
	if not goal then
		return nil
	end
	if goal:IsA("BasePart") then
		return goal
	end
	if goal:IsA("Model") and goal.PrimaryPart then
		return goal.PrimaryPart
	end
	for _, descendant in goal:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
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

local function GetExtendedPositionAtTime(
	t: number,
	startPos: Vector3,
	targetPos: Vector3,
	power: number,
	curveFactor: number?
): Vector3
	local distance: number = (targetPos - startPos).Magnitude
	if power <= 0 or distance <= 0 then
		return startPos
	end
	local timeToTarget: number = distance / power
	local progress: number = math.max(t / timeToTarget, 0)
	local horizontalPos: Vector3 = startPos:Lerp(targetPos, progress)
	local curve: number = curveFactor or 0
	local maxHeight: number = distance * curve
	local height: number = 4 * maxHeight * progress * (1 - progress)
	return horizontalPos + Vector3.new(0, height, 0)
end

local function StartExtraPointPostGoalContinuation(goalTeam: number?, positionOverride: Vector3?): boolean
	if not extraPointActive or extraPointPostGoalTriggered then
		return false
	end

	local expectedGoalTeam: number? = extraPointGoalTeam
	if not expectedGoalTeam then
		return false
	end

	if goalTeam and goalTeam ~= expectedGoalTeam then
		return false
	end

	if not State:IsInAir() then
		return false
	end

	local physicsData = State:GetPhysicsData()
	if not physicsData or not physicsData.Target or not physicsData.SpawnPos then
		return false
	end

	local distance: number = (physicsData.Target - physicsData.SpawnPos).Magnitude
	if physicsData.Power <= 0 or distance <= 1e-4 then
		return false
	end

	local timeToTarget: number = distance / physicsData.Power
	if timeToTarget <= 1e-4 then
		return false
	end

	local serverTimeNow: number = Workspace:GetServerTimeNow()
	local currentTime: number = math.max(0, serverTimeNow - physicsData.LaunchTime)
	local progress: number = math.clamp(currentTime / timeToTarget, 0, 1)
	local horizontalVelocity: Vector3 = (physicsData.Target - physicsData.SpawnPos) / timeToTarget
	local curve: number = physicsData.CurveFactor or 0
	local maxHeight: number = distance * curve
	local verticalVelocity: number = (4 * maxHeight * (1 - (2 * progress))) / timeToTarget
	local startPosition: Vector3 = positionOverride
		or (if BallInstance and BallInstance:IsA("BasePart")
			then BallInstance.Position
			else Utility.GetPositionAtTime(
				currentTime,
				physicsData.SpawnPos,
				physicsData.Target,
				physicsData.Power,
				physicsData.CurveFactor
			))

	extraPointPostGoalTriggered = true
	extraPointPostGoalStartedAt = serverTimeNow
	extraPointPostGoalOrigin = startPosition
	extraPointPostGoalVelocity = horizontalVelocity + Vector3.new(0, verticalVelocity, 0)
	return true
end

local function TryStartExtraPointPostGoalSlow(
	fromPosition: Vector3,
	position: Vector3,
	currentTime: number,
	timeToTarget: number,
	physicsData: {LaunchTime: number, SpawnPos: Vector3, Target: Vector3, Power: number, CurveFactor: number?}
): boolean
	if not extraPointActive or extraPointPostGoalTriggered then
		return false
	end

	local goalTeam: number? = extraPointGoalTeam
	if not goalTeam then
		return false
	end

	local goalPart: BasePart? = GetGoalPartForTeam(goalTeam)
	if not goalPart then
		return false
	end

	if not DidSegmentEnterPart(goalPart, fromPosition, position) then
		return false
	end

	return StartExtraPointPostGoalContinuation(goalTeam, position)
end

local function CleanupPriorityCatchRequests(): ()
	local Now: number = os.clock()
	for Player, Request in PriorityCatchRequests do
		if Player.Parent == nil or Request.ExpiresAt <= Now then
			PriorityCatchRequests[Player] = nil
		end
	end
end

local function GetPlayerCatchRoot(Player: Player): BasePart?
	local Character: Model? = Player.Character
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function TryCatchBallByPlayer(Player: Player, Radius: number, AllowInAir: boolean?): boolean
	if not BallInstance or not BallInstance:IsA("BasePart") then
		return false
	end
	if HasExternalHolder() then
		return false
	end
	if State:GetPossession() ~= nil then
		return false
	end
	if not AllowInAir and State:IsInAir() then
		return false
	end
	if not IsPlayerInMatch(Player) then
		return false
	end

	local HumanoidRootPart: BasePart? = GetPlayerCatchRoot(Player)
	if not HumanoidRootPart then
		return false
	end

	local EffectiveRadius: number = math.max(Radius, FTConfig.GAME_CONFIG.CatchRadius)
	local Distance: number = (HumanoidRootPart.Position - BallInstance.Position).Magnitude
	if Distance > EffectiveRadius then
		return false
	end

	GiveBallToPlayer(Player)
	return true
end

local function TryPriorityCatch(): boolean
	CleanupPriorityCatchRequests()

	local OrderedRequests: {PriorityCatchEntry} = {}
	for Player, Request in PriorityCatchRequests do
		table.insert(OrderedRequests, {
			Player = Player,
			Request = Request,
		})
	end

	table.sort(OrderedRequests, function(Left: PriorityCatchEntry, Right: PriorityCatchEntry): boolean
		if Left.Request.Priority ~= Right.Request.Priority then
			return Left.Request.Priority > Right.Request.Priority
		end
		if Left.Request.RequestedAt ~= Right.Request.RequestedAt then
			return Left.Request.RequestedAt > Right.Request.RequestedAt
		end
		return Left.Player.UserId < Right.Player.UserId
	end)

	for _, Entry in OrderedRequests do
		if TryCatchBallByPlayer(Entry.Player, Entry.Request.Radius, true) then
			return true
		end
	end

	return false
end

local function TryAutoCatch(): ()
	if TryPriorityCatch() then
		return
	end
	if not BallInstance or not BallInstance:IsA("BasePart") then return end
	if HasExternalHolder() then return end
	if State:GetPossession() ~= nil then return end
	if State:IsInAir() then return end
	if not State:IsOnGround() then return end

	for _, Player in Players:GetPlayers() do
		if TryCatchBallByPlayer(Player, FTConfig.GAME_CONFIG.CatchRadius, false) then
			return
		end
	end
end

local function UpdateBallPhysics(): ()
	if not BallInstance then return end
	BallInstance.CanCollide = false
	if not State:IsInAir() then
		if not extraPointActive then
			local owner = State:GetPossession()
			if owner and BallInstance:IsA("BasePart") then
				BallInstance.Anchored = false
				BallInstance.CanCollide = false
				if not BallWeld then
					local character = owner.Character
					local arm = character and (character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand") or character:FindFirstChild("RightLowerArm") or character:FindFirstChild("RightUpperArm")) :: BasePart?
					if arm then
						BallInstance.CFrame = arm.CFrame * BALL_OFFSET_R6
						BallInstance.AssemblyLinearVelocity = Vector3.zero
						BallInstance.AssemblyAngularVelocity = Vector3.zero
					end
				end
			end
		end
		return
	end
	
	local PhysicsData = State:GetPhysicsData()
	if not PhysicsData then return end
	
	--\\ GUARD CLAUSES \\ -- TR
	if not PhysicsData.Target or not PhysicsData.SpawnPos then return end
	
	local serverTimeNow: number = Workspace:GetServerTimeNow()
	local rawCurrentTime: number = serverTimeNow - PhysicsData.LaunchTime
	local Distance: number = (PhysicsData.Target - PhysicsData.SpawnPos).Magnitude
	local TimeToTarget: number = Distance / PhysicsData.Power
	local CurrentTime: number = rawCurrentTime
	local NewPosition: Vector3 = Utility.GetPositionAtTime(
		CurrentTime,
		PhysicsData.SpawnPos,
		PhysicsData.Target,
		PhysicsData.Power,
		PhysicsData.CurveFactor
	)
	local previousPosition = if BallInstance and BallInstance:IsA("BasePart")
		then BallInstance.Position
		else NewPosition

	if TryStartExtraPointPostGoalSlow(previousPosition, NewPosition, CurrentTime, TimeToTarget, PhysicsData) then
		if BallInstance and BallInstance:IsA("BasePart") then
			local spinFunction = FTConfig.BALL_SPIN_TYPES[PhysicsData.SpinType]
			if spinFunction then
				BallInstance.CFrame = CFrame.new(NewPosition) * spinFunction()
			else
				BallInstance.Position = NewPosition
			end
		end
		return
	end

	if extraPointPostGoalTriggered then
		local postGoalElapsed: number = math.max(0, serverTimeNow - extraPointPostGoalStartedAt)
		NewPosition = extraPointPostGoalOrigin
			+ (extraPointPostGoalVelocity * postGoalElapsed)
			+ Vector3.new(0, -0.5 * EXTRA_POINT_POST_GOAL_GRAVITY * postGoalElapsed * postGoalElapsed, 0)

		local groundHit = GetCampoHit(Vector3.new(NewPosition.X, NewPosition.Y + 10, NewPosition.Z))
		if groundHit and NewPosition.Y <= groundHit.Position.Y then
			State:SetInAir(false)
			State:SetOnGround(true)
			if BallInstance and BallInstance:IsA("BasePart") then
				BallInstance.Position = groundHit.Position
				BallInstance.Anchored = true
				BallInstance.CanCollide = false
				SetBallAttribute("FTBall_InAir", false)
				SetBallAttribute("FTBall_OnGround", true)
				SetBallAttribute("FTBall_Possession", 0)
				SetBallAttribute("FTBall_GroundPos", groundHit.Position)
				SetBallAttribute("FTBall_LaunchTime", nil)
			end
			return
		end

		if NewPosition.Y < -10 then
			State:SetInAir(false)
			State:SetOnGround(true)
			if BallInstance and BallInstance:IsA("BasePart") then
				BallInstance.Anchored = true
				SetBallAttribute("FTBall_InAir", false)
				SetBallAttribute("FTBall_OnGround", true)
				SetBallAttribute("FTBall_Possession", 0)
				SetBallAttribute("FTBall_LaunchTime", nil)
			end
			return
		end

		if BallInstance and BallInstance:IsA("BasePart") then
			local spinFunction = FTConfig.BALL_SPIN_TYPES[PhysicsData.SpinType]
			if spinFunction then
				BallInstance.CFrame = CFrame.new(NewPosition) * spinFunction()
			else
				BallInstance.Position = NewPosition
			end
		end
		return
	end

	if CurrentTime >= TimeToTarget then
		local Target = PhysicsData.Target
		local hit = GetCampoHit(Target + Vector3.new(0, 10, 0))
		if hit then
			Target = hit.Position
		end
		if extraPointActive and not extraPointPostGoalTriggered then
			if StartExtraPointPostGoalContinuation(nil, Target) then
				if BallInstance and BallInstance:IsA("BasePart") then
					local spinFunction = FTConfig.BALL_SPIN_TYPES[PhysicsData.SpinType]
					if spinFunction then
						BallInstance.CFrame = CFrame.new(Target) * spinFunction()
					else
						BallInstance.Position = Target
					end
				end
				return
			end
		end
		BallInstance.Position = Target
		State:SetInAir(false)
		State:SetOnGround(true)
		
		if BallInstance:IsA("BasePart") then
			BallInstance.Anchored = true
			BallInstance.CanCollide = false
			SetBallAttribute("FTBall_InAir", false)
			SetBallAttribute("FTBall_OnGround", true)
			SetBallAttribute("FTBall_Possession", 0)
			SetBallAttribute("FTBall_GroundPos", Target)
			SetBallAttribute("FTBall_LaunchTime", nil)
		end
		return
	end
	
	local groundHit = GetCampoHit(Vector3.new(NewPosition.X, NewPosition.Y + 10, NewPosition.Z))
	if groundHit and NewPosition.Y <= groundHit.Position.Y then
		State:SetInAir(false)
		State:SetOnGround(true)
		if BallInstance:IsA("BasePart") then
			BallInstance.Position = groundHit.Position
			BallInstance.Anchored = true
			BallInstance.CanCollide = false
			SetBallAttribute("FTBall_InAir", false)
			SetBallAttribute("FTBall_OnGround", true)
			SetBallAttribute("FTBall_Possession", 0)
			SetBallAttribute("FTBall_GroundPos", groundHit.Position)
			SetBallAttribute("FTBall_LaunchTime", nil)
		end
		return
	end

	if NewPosition.Y < -10 then
		State:SetInAir(false)
		State:SetOnGround(true)
		if BallInstance:IsA("BasePart") then
			BallInstance.Anchored = true
			SetBallAttribute("FTBall_InAir", false)
			SetBallAttribute("FTBall_OnGround", true)
			SetBallAttribute("FTBall_Possession", 0)
			SetBallAttribute("FTBall_GroundPos", NewPosition)
			SetBallAttribute("FTBall_LaunchTime", nil)
		end
		return
	end
	
	if BallInstance and BallInstance:IsA("BasePart") then
		BallInstance.Position = NewPosition
		
		local SpinFunction = FTConfig.BALL_SPIN_TYPES[PhysicsData.SpinType]
		if SpinFunction then
			local SpinCFrame: CFrame = SpinFunction()
			BallInstance.CFrame = CFrame.new(NewPosition) * SpinCFrame
		end
	end
end

local function InitializeBall(): ()
	local Game = Workspace:FindFirstChild("Game")
	if not Game then return end
	
	local ExistingBall = Game:FindFirstChild("Football")
	if ExistingBall then
		if ExistingBall:IsA("Model") then
			BallInstance = ExistingBall.PrimaryPart or ExistingBall:FindFirstChildWhichIsA("BasePart")
		elseif ExistingBall:IsA("BasePart") then
			BallInstance = ExistingBall
		end
		if BallInstance and BallInstance:IsA("BasePart") then
			SetBallAttribute("FTBall_InAir", false)
			SetBallAttribute("FTBall_OnGround", true)
			SetBallAttribute("FTBall_Possession", 0)
			SetBallAttribute("FTBall_GroundPos", BallInstance.Position)
			if BallInstance:GetAttribute("FTBall_Seq") == nil then
				SetBallAttribute("FTBall_Seq", 0)
			end
		end
		return
	end
	
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	if not Assets then return end
	
	local Gameplay = Assets:FindFirstChild("Gameplay")
	if not Gameplay then return end
	
	local Modelo = Gameplay:FindFirstChild("Modelo")
	if not Modelo then return end
	
	local BallModel = Modelo:FindFirstChild("Bola")
	if not BallModel then return end
	
	if BallModel:IsA("Model") then
		local cloneModel: Model = BallModel:Clone()
		cloneModel.Parent = Game
		cloneModel.Name = "Football"
		BallInstance = cloneModel.PrimaryPart or cloneModel:FindFirstChildWhichIsA("BasePart")
	elseif BallModel:IsA("BasePart") then
		local clonePart: BasePart = BallModel:Clone()
		clonePart.Name = "Football"
		clonePart.Parent = Game
		BallInstance = clonePart
	end
	
	if BallInstance and BallInstance:IsA("BasePart") then
		BallInstance.Anchored = true
		BallInstance.CanCollide = false
		BallInstance.CanTouch = true
		BallInstance.CanQuery = true
		BallInstance.Massless = true
		SetBallAttribute("FTBall_InAir", false)
		SetBallAttribute("FTBall_OnGround", true)
		SetBallAttribute("FTBall_Possession", 0)
		SetBallAttribute("FTBall_GroundPos", BallInstance.Position)
		SetBallAttribute("FTBall_Seq", 0)
		if ballTouchedConnection then
			ballTouchedConnection:Disconnect()
			ballTouchedConnection = nil
		end
		ballTouchedConnection = BallInstance.Touched:Connect(function(hit)
			if not hit or not hit:IsA("BasePart") then
				return
			end
			local goalTeam = GetGoalTeamFromPart(hit)
			if extraPointActive and goalTeam then
				local ballPosition = if BallInstance and BallInstance:IsA("BasePart") then BallInstance.Position else nil
				StartExtraPointPostGoalContinuation(goalTeam, ballPosition)
				for _, callback in goalTouchCallbacks do
					task.spawn(callback, goalTeam, hit)
				end
			end
		end)
	end
end

local function EnsureBallInstance(): BasePart?
	if BallInstance and BallInstance.Parent ~= nil then
		return BallInstance
	end

	BallInstance = nil
	BallWeld = nil
	InitializeBall()
	return BallInstance
end

local function CleanupMatchArtifacts(): ()
	local CurrentBall: BasePart? = BallInstance
	if CurrentBall and CurrentBall.Parent ~= nil then
		local Character: Model? = nil
		local Possessor: Player? = State:GetPossession()
		if Possessor then
			Character = Possessor.Character
		end
		DetachBallFromPlayer(Character)
	end

	State:SetInAir(false)
	State:SetPossession(nil)
	State:ClearPhysicsData()
	possessionTeam = nil
	ClearExternalHolderState()
	extraPointActive = false
	extraPointGoalTeam = nil
	extraPointPostGoalTriggered = false
	extraPointPostGoalStartedAt = 0
	extraPointPostGoalOrigin = Vector3.zero
	extraPointPostGoalVelocity = Vector3.zero
	lastInBoundsCarrierX = nil
	lastInBoundsBallX = nil
	outCooldownUntil = 0
	lastThrowOriginX = nil
	lastThrowTeam = nil
	ClearPendingPassAttempt()
	UpdateBallCarrierValue(nil)
	SetBallAttribute("FTBall_InAir", false)
	SetBallAttribute("FTBall_OnGround", false)
	SetBallAttribute("FTBall_Possession", 0)
	SetBallAttribute("FTBall_ExternalHolder", nil)
	SetBallAttribute("FTBall_GroundPos", nil)
	SetBallAttribute("FTBall_LaunchTime", nil)
	SetBallAttribute("FTBall_SpawnPos", nil)
	SetBallAttribute("FTBall_Target", nil)
	SetBallAttribute("FTBall_Power", nil)
	SetBallAttribute("FTBall_Curve", nil)
	SetBallAttribute("FTBall_Spin", nil)
	local BallData: StringValue? = GetBallData()
	local NextSeq: number = if BallData then ((BallData:GetAttribute("FTBall_Seq") or 0) + 1) else 1
	SetBallAttribute("FTBall_Seq", NextSeq)

	if ballTouchedConnection then
		ballTouchedConnection:Disconnect()
		ballTouchedConnection = nil
	end

	if CurrentBall and CurrentBall.Parent ~= nil then
		local Container: Instance? = CurrentBall.Parent
		if Container and Container:IsA("Model") and Container.Name == "Football" then
			Container:Destroy()
		else
			CurrentBall:Destroy()
		end
	end

	BallInstance = nil
	BallWeld = nil
	FireToAllClients()
end

function FireToAllClients(): ()
	for _, Player in Players:GetPlayers() do
		Packets.BallStateUpdate:FireClient(Player)
	end
end

local function ResolveExtraPointPlacement(Character: Model): (Vector3?, CFrame?)
	if not BallInstance or not BallInstance:IsA("BasePart") then
		return nil, nil
	end
	local hrp = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local foot = Character:FindFirstChild("RightFoot") or Character:FindFirstChild("Right Leg") or Character:FindFirstChild("RightLowerLeg")
	if not foot or not hrp then
		return nil, nil
	end

	local forward = hrp.CFrame.LookVector
	if forward.Magnitude < 1e-4 then
		forward = foot.CFrame.LookVector
	end
	local planarForward = Vector3.new(forward.X, 0, forward.Z)
	if planarForward.Magnitude < 1e-4 then
		local footForward = foot.CFrame.LookVector
		planarForward = Vector3.new(footForward.X, 0, footForward.Z)
	end
	if planarForward.Magnitude < 1e-4 then
		planarForward = Vector3.new(0, 0, -1)
	end
	planarForward = planarForward.Unit

	local basePos = foot.Position
	local desiredPos = Vector3.new(basePos.X, basePos.Y, basePos.Z) + planarForward * EXTRA_POINT_BALL_OFFSET
	local hit = GetCampoHit(desiredPos + Vector3.new(0, 5, 0))
	if hit then
		desiredPos = Vector3.new(desiredPos.X, hit.Position.Y + BallInstance.Size.Y * 0.5 + EXTRA_POINT_BALL_HEIGHT, desiredPos.Z)
	else
		local planeY = GetCampoPlaneY()
		local fallbackY = planeY or desiredPos.Y
		desiredPos = Vector3.new(desiredPos.X, fallbackY + BallInstance.Size.Y * 0.5 + EXTRA_POINT_BALL_HEIGHT, desiredPos.Z)
	end

	local orientation = CFrame.lookAt(desiredPos, desiredPos + planarForward) * CFrame.Angles(0, math.rad(-180), 0)
	return desiredPos, orientation
end

function UpdateBallCarrierValue(Player: Player?): ()
	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if not GameStateFolder then return end
	
	local BallCarrierValue = GameStateFolder:FindFirstChild("BallCarrier") :: ObjectValue?
	if BallCarrierValue then
		BallCarrierValue.Value = Player
	end
	if FTRefereeService and FTRefereeService.SetBallCarrier then
		FTRefereeService:SetBallCarrier(Player)
	end
end

DetachBallFromPlayer = function(Character: Model?): ()
	if BallWeld then
		BallWeld:Destroy()
		BallWeld = nil
	end

	if BallInstance then
		local function CleanupWelds(container: Instance)
			for _, descendant in container:GetDescendants() do
				if descendant:IsA("Weld") or descendant:IsA("WeldConstraint") then
					if descendant.Part0 == BallInstance or descendant.Part1 == BallInstance then
						descendant:Destroy()
					end
				end
			end
		end

		local parent = BallInstance.Parent
		if parent then
			CleanupWelds(parent)
		end
		if Character then
			CleanupWelds(Character)
		end
	end
	
	if BallInstance and BallInstance:IsA("BasePart") then
		pcall(function()
			BallInstance:SetNetworkOwner(nil)
		end)
		pcall(function()
			BallInstance:SetNetworkOwnershipAuto(true)
		end)
		BallInstance.Anchored = true
		BallInstance.CanCollide = false
		BallInstance.CanTouch = true
		BallInstance.CanQuery = true
	end
end

function AttachBallToPlayer(Player: Player): ()
	if not BallInstance or not BallInstance:IsA("BasePart") then return end
	
	local Character = Player.Character
	if not Character then return end
	
	local attachPart = GetBallAttachPartForModel(Character)
	if not attachPart then return end
	
	DetachBallFromPlayer(Character)
	
	--\\ STRICT PHYSICS PREVENTION FOR FLOATING \\ -- TR
	BallInstance.Anchored = false
	BallInstance.CanCollide = false
	BallInstance.CanTouch = false
	BallInstance.CanQuery = false
	BallInstance.Massless = true
	pcall(function()
		BallInstance:SetNetworkOwnershipAuto(false)
		BallInstance:SetNetworkOwner(Player)
	end)
	if attachPart.Name ~= "HumanoidRootPart" then
		BallInstance.CFrame = attachPart.CFrame * BALL_OFFSET_R6
	else
		BallInstance.CFrame = attachPart.CFrame * CFrame.new(0, 0.5, -1)
	end
	BallInstance.AssemblyLinearVelocity = Vector3.zero
	BallInstance.AssemblyAngularVelocity = Vector3.zero
	
	local weld = Instance.new("Weld")
	weld.Name = "BallWeld"
	weld.Part0 = attachPart
	weld.Part1 = BallInstance
	weld.C0 = if attachPart.Name ~= "HumanoidRootPart" then BALL_OFFSET_R6 else CFrame.new(0, 0.5, -1)
	weld.Parent = attachPart
	BallWeld = weld

	local humanoid = Character:FindFirstChildOfClass("Humanoid")
	if humanoid and not extraPointActive then
		local gameState = ReplicatedStorage:FindFirstChild("FTGameState")
		local countdownActive = false
		local intermissionActive = false
		if gameState then
			local countdownValue = gameState:FindFirstChild("CountdownActive") :: BoolValue?
			if countdownValue and countdownValue.Value then
				countdownActive = true
			end
			local intermissionValue = gameState:FindFirstChild("IntermissionActive") :: BoolValue?
			if intermissionValue and intermissionValue.Value then
				intermissionActive = true
			end
		end
		local isInvulnerable = Player:GetAttribute("Invulnerable") == true
		local isStunned = (Player:GetAttribute("FTStunned") == true) or (Character:GetAttribute("FTStunned") == true)
		if not countdownActive and not intermissionActive and not isInvulnerable and not isStunned then
			humanoid.PlatformStand = false
			humanoid.Sit = false
			humanoid.AutoRotate = true
			if humanoid.WalkSpeed <= 0 then
				FlowBuffs.ApplyHumanoidWalkSpeed(Player, humanoid, 16)
			end
			local root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Anchored then
				root.Anchored = false
			end
		end
	end
end

local function HoldBallByModel(Model: Model, TeamNumber: number?): boolean
	if not EnsureBallInstance() then
		return false
	end
	if not BallInstance or not BallInstance:IsA("BasePart") then
		return false
	end

	local attachPart = GetBallAttachPartForModel(Model)
	if not attachPart then
		return false
	end

	DetachBallFromPlayer(Model)
	ResolvePendingPassAttemptForExternalHolder(Model, TeamNumber)
	lastInBoundsCarrierX = nil
	lastInBoundsBallX = nil
	outCooldownUntil = 0
	State:SetInAir(false)
	State:SetPossession(nil)
	State:SetOnGround(false)
	State:ClearPhysicsData()
	UpdateBallCarrierValue(nil)

	ExternalHolderModel = Model
	ExternalHolderTeam = TeamNumber
	if TeamNumber ~= nil then
		possessionTeam = TeamNumber
	end

	BallInstance.Anchored = false
	BallInstance.CanCollide = false
	BallInstance.CanTouch = false
	BallInstance.CanQuery = false
	BallInstance.Massless = true
	pcall(function()
		BallInstance:SetNetworkOwner(nil)
		BallInstance:SetNetworkOwnershipAuto(true)
	end)

	local offset = if attachPart.Name ~= "HumanoidRootPart" then BALL_OFFSET_R6 else CFrame.new(0, 0.5, -1)
	BallInstance.CFrame = attachPart.CFrame * offset
	BallInstance.AssemblyLinearVelocity = Vector3.zero
	BallInstance.AssemblyAngularVelocity = Vector3.zero

	local weld = Instance.new("Weld")
	weld.Name = "BallWeld"
	weld.Part0 = attachPart
	weld.Part1 = BallInstance
	weld.C0 = offset
	weld.Parent = attachPart
	BallWeld = weld

	SetBallAttribute("FTBall_InAir", false)
	SetBallAttribute("FTBall_OnGround", false)
	SetBallAttribute("FTBall_Possession", 0)
	SetBallAttribute("FTBall_ExternalHolder", Model.Name)
	SetBallAttribute("FTBall_GroundPos", nil)
	SetBallAttribute("FTBall_LaunchTime", nil)
	SetBallAttribute("FTBall_SpawnPos", nil)
	SetBallAttribute("FTBall_Target", nil)
	SetBallAttribute("FTBall_Power", nil)
	SetBallAttribute("FTBall_Curve", nil)
	SetBallAttribute("FTBall_Spin", nil)
	SetBallAttribute("FTBall_RequestId", 0)
	SetBallAttribute("FTBall_RequestOwner", 0)
	SetBallAttribute("FTBall_Seq", GetNextBallSequence())

	FireToAllClients()
	return true
end

local function DropBallAtPosition(position: Vector3): ()
	if not BallInstance or not BallInstance:IsA("BasePart") then
		return
	end
	DetachBallFromPlayer()
	ClearExternalHolderState()

	State:SetInAir(false)
	State:SetPossession(nil)
	State:SetOnGround(true)
	State:ClearPhysicsData()
	UpdateBallCarrierValue(nil)

	local clamped = Utility.ClampToMap(position)
	local targetPos = clamped
	local hit = GetCampoHit(targetPos + Vector3.new(0, 10, 0))
	if hit then
		targetPos = Vector3.new(targetPos.X, hit.Position.Y + BallInstance.Size.Y * 0.5, targetPos.Z)
	else
		targetPos = Vector3.new(targetPos.X, targetPos.Y + BallInstance.Size.Y * 0.5, targetPos.Z)
	end
	BallInstance.Anchored = true
	BallInstance.CanCollide = false
	BallInstance.Position = targetPos
	SetBallAttribute("FTBall_InAir", false)
	SetBallAttribute("FTBall_OnGround", true)
	SetBallAttribute("FTBall_Possession", 0)
	SetBallAttribute("FTBall_ExternalHolder", nil)
	SetBallAttribute("FTBall_GroundPos", targetPos)
	SetBallAttribute("FTBall_LaunchTime", nil)
	SetBallAttribute("FTBall_SpawnPos", nil)
	SetBallAttribute("FTBall_Target", nil)
	SetBallAttribute("FTBall_Power", nil)
	SetBallAttribute("FTBall_Curve", nil)
	SetBallAttribute("FTBall_Spin", nil)

	FireToAllClients()
end

local function DropBallFromPlayer(Player: Player): ()
	if State:GetPossession() ~= Player then
		return
	end
	local character = Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	DropBallAtPosition(root.Position)
end

local function LaunchThrow(
	Player: Player,
	SpawnPos: Vector3,
	ValidTarget: Vector3,
	AppliedPower: number,
	SpinType: number,
	AppliedCurve: number?,
	LaunchTimeOverride: number?,
	RequestId: number?,
	TrackPassingStat: boolean?
): ()
	local Character = Player.Character
	if not Character then return end

	DetachBallFromPlayer(Character)
	ClearExternalHolderState()

	local launchTime = if typeof(LaunchTimeOverride) == "number"
		then LaunchTimeOverride
		else Workspace:GetServerTimeNow()
	StartPendingPassAttempt(Player, launchTime, SpawnPos, ValidTarget, AppliedPower, TrackPassingStat)
	State:SetInAir(true)
	State:SetPossession(nil)
	State:SetOnGround(false)
	State:SetPhysicsData({
		LaunchTime = launchTime,
		Power = AppliedPower,
		Target = ValidTarget,
		SpawnPos = SpawnPos,
		SpinType = SpinType,
		CurveFactor = AppliedCurve,
	})

	UpdateBallCarrierValue(nil)

	if BallInstance and BallInstance:IsA("BasePart") then
		local currentServerTime = Workspace:GetServerTimeNow()
		local solution = {
			spawnPos = SpawnPos,
			target = ValidTarget,
			power = AppliedPower,
			curve = if typeof(AppliedCurve) == "number" then AppliedCurve else 0.2,
			distance = (ValidTarget - SpawnPos).Magnitude,
			flightTime = (ValidTarget - SpawnPos).Magnitude / math.max(AppliedPower, 0.05),
		}
		local initialPos = ThrowPrediction.GetPositionAtServerTime(launchTime, currentServerTime, solution)
		BallInstance.Anchored = true
		BallInstance.CanCollide = false
		BallInstance.Position = initialPos
		SetBallAttribute("FTBall_InAir", true)
		SetBallAttribute("FTBall_OnGround", false)
		SetBallAttribute("FTBall_Possession", 0)
		SetBallAttribute("FTBall_ExternalHolder", nil)
		SetBallAttribute("FTBall_LaunchTime", launchTime)
		SetBallAttribute("FTBall_SpawnPos", SpawnPos)
		SetBallAttribute("FTBall_Target", ValidTarget)
		SetBallAttribute("FTBall_Power", AppliedPower)
		SetBallAttribute("FTBall_Curve", AppliedCurve)
		SetBallAttribute("FTBall_Spin", SpinType)
		SetBallAttribute("FTBall_GroundPos", nil)
		SetBallAttribute("FTBall_RequestId", if typeof(RequestId) == "number" then RequestId else 0)
		SetBallAttribute("FTBall_RequestOwner", PlayerIdentity.GetIdValue(Player))
		local seq = (BallInstance:GetAttribute("FTBall_Seq") or 0) + 1
		SetBallAttribute("FTBall_Seq", seq)
	end

	FireToAllClients()
end

local function ResolveThrowSpawnPosition(Player: Player): Vector3?
	local Character = Player.Character
	if not Character then
		return nil
	end

	local releaseState = ThrowPrediction.GetCharacterReleaseState(
		Character,
		if BallInstance and BallInstance:IsA("BasePart") then BallInstance.Position else nil,
		BALL_OFFSET_R6
	)
	if not releaseState then
		return nil
	end

	return releaseState.basePos + (releaseState.planarVelocity * THROW_SPAWN_VELOCITY_LEAD)
end

local function ExecuteSkillThrow(Player: Player, Target: Vector3, Settings: {[string]: any}?): (boolean, number, Vector3?)
	local IgnoreSkillLock: boolean = Settings ~= nil and Settings.IgnoreSkillLock == true
	if not CanPlayerThrowWithOptions(Player, IgnoreSkillLock) then
		return false, 0, nil
	end
	if State:GetPossession() ~= Player then
		return false, 0, nil
	end
	if typeof(Target) ~= "Vector3" then
		return false, 0, nil
	end

	local SpawnPos: Vector3? = ResolveThrowSpawnPosition(Player)
	if not SpawnPos then
		return false, 0, nil
	end

	local BaseMaxDistanceValue: number =
		if Settings and typeof(Settings.MaxDistance) == "number" then Settings.MaxDistance else MAX_THROW_DISTANCE
	local MaxDistanceValue: number = FlowBuffs.ApplyThrowDistanceBuff(Player, BaseMaxDistanceValue)
	local TimeDivisorValue: number = if Settings and typeof(Settings.TimeDivisor) == "number" then Settings.TimeDivisor else THROW_TIME_DIVISOR
	local MinTimeValue: number = if Settings and typeof(Settings.MinTime) == "number" then Settings.MinTime else MIN_THROW_TIME
	local MaxTimeValue: number = if Settings and typeof(Settings.MaxTime) == "number" then Settings.MaxTime else MAX_THROW_TIME
	local MaxPowerValue: number = if Settings and typeof(Settings.MaxPower) == "number" then Settings.MaxPower else MAX_THROW_POWER
	local CurveValue: number = if Settings and typeof(Settings.Curve) == "number" then math.clamp(Settings.Curve, 0, 1) else 0.22
	local solution = ThrowPrediction.ResolveLaunchFromReleaseState({
		basePos = SpawnPos,
		planarVelocity = Vector3.zero,
	}, Target, CurveValue, 0, {
		MaxDistance = MaxDistanceValue,
		TimeDivisor = TimeDivisorValue,
		MinTime = MinTimeValue,
		MaxTime = MaxTimeValue,
		MinPower = MIN_THROW_POWER,
		MaxPower = MaxPowerValue,
	})
	if not solution then
		return false, 0, nil
	end
	local SpinType: number = ThrowPrediction.ResolveSpinType(nil)

	lastThrowOriginX = solution.spawnPos.X
	lastThrowTeam = FTPlayerService:GetPlayerTeam(Player)
	LaunchThrow(Player, solution.spawnPos, solution.target, solution.power, SpinType, solution.curve, nil, nil, true)
	return true, solution.flightTime, solution.target
end

local function ResolveRequestedReleaseTime(receivedAt: number, requestedReleaseServerTime: number?): number
	if typeof(requestedReleaseServerTime) ~= "number" then
		return receivedAt
	end
	return math.clamp(
		requestedReleaseServerTime,
		receivedAt - MAX_CLIENT_THROW_RELEASE_BACKTRACK,
		receivedAt + math.min(MAX_CLIENT_THROW_RELEASE_LEAD, MAX_CLIENT_THROW_RELEASE_QUEUE)
	)
end

local function ResolveRequestedExtraPointKickReleaseTime(receivedAt: number, requestedReleaseServerTime: number?): number
	if typeof(requestedReleaseServerTime) ~= "number" then
		return receivedAt
	end
	return math.clamp(
		requestedReleaseServerTime,
		receivedAt - MAX_CLIENT_THROW_RELEASE_BACKTRACK,
		receivedAt + math.min(MAX_CLIENT_THROW_RELEASE_LEAD, EXTRA_POINT_KICK_RELEASE_QUEUE)
	)
end

local function BuildLaunchSolutionFromClient(
	Player: Player,
	clientSpawnPos: Vector3?,
	target: Vector3,
	power: number,
	curveFactor: number?
)
	if typeof(clientSpawnPos) ~= "Vector3" then
		return nil
	end
	local spawnPos = Utility.ClampToMap(clientSpawnPos)
	local offset = target - spawnPos
	if offset.Magnitude < 1e-4 then
		return nil
	end
	local direction = offset.Unit
	local MaxDistanceValue: number = FlowBuffs.ApplyThrowDistanceBuff(Player, MAX_THROW_DISTANCE)
	local clampedTarget = if offset.Magnitude > MaxDistanceValue
		then spawnPos + (direction * MaxDistanceValue)
		else target
	local validTarget = Utility.ClampToMap(clampedTarget)
	local distance = (validTarget - spawnPos).Magnitude
	if distance < 1e-4 then
		return nil
	end
	local appliedPower = math.clamp(power, MIN_THROW_POWER, MAX_THROW_POWER)
	return {
		spawnPos = spawnPos,
		target = validTarget,
		power = appliedPower,
		curve = math.clamp(if typeof(curveFactor) == "number" then curveFactor else 0.2, 0, 1),
		distance = distance,
		flightTime = distance / math.max(appliedPower, 0.05),
	}
end

local function HandleBallThrow(
	Player: Player,
	Target: Vector3,
	Power: number,
	CurveFactor: number?,
	RequestedReleaseServerTime: number?,
	ClientRequestId: number?,
	ClientSpawnPos: Vector3?
): ()
	if not CanPlayerThrow(Player) then
		return
	end
	if State:GetPossession() ~= Player then
		return
	end
	
	--\\ GUARD CLAUSES \\ -- TR
	if typeof(Target) ~= "Vector3" then
		return
	end
	if typeof(Power) ~= "number" or Power <= 0 then
		return
	end

	local receivedAt = Workspace:GetServerTimeNow()
	local releaseAt = ResolveRequestedReleaseTime(receivedAt, RequestedReleaseServerTime)

	local function ExecuteThrow(): ()
		if not CanPlayerThrow(Player) then
			return
		end
		if State:GetPossession() ~= Player then
			return
		end

		local currentServerTime = Workspace:GetServerTimeNow()
		local lateBy = math.max(0, currentServerTime - releaseAt)
		local releaseSpawnPos = ClientSpawnPos
		if BallInstance and BallInstance:IsA("BasePart") then
			releaseSpawnPos = BallInstance.Position
		end
		local solution = BuildLaunchSolutionFromClient(Player, releaseSpawnPos, Target, Power, CurveFactor)
		if not solution then
			return
		end
		local spinType = ThrowPrediction.ResolveSpinType(ClientRequestId)
		lastThrowOriginX = solution.spawnPos.X
		lastThrowTeam = FTPlayerService:GetPlayerTeam(Player)
		LaunchThrow(
			Player,
			solution.spawnPos,
			solution.target,
			solution.power,
			spinType,
			solution.curve,
			releaseAt,
			ClientRequestId,
			true
		)
	end

	local waitTime = releaseAt - receivedAt
	if waitTime > (1 / 120) then
		task.delay(waitTime, ExecuteThrow)
	else
		ExecuteThrow()
	end
end

local function HandleExtraPointKickRequest(
	Player: Player,
	Target: Vector3,
	Power: number,
	CurveFactor: number?,
	RequestedReleaseServerTime: number?,
	ClientRequestId: number?,
	ClientSpawnPos: Vector3?
): ()
	if not extraPointActive then
		return
	end
	if not CanPlayerThrow(Player) then
		return
	end
	if State:GetPossession() ~= Player then
		return
	end
	if typeof(Target) ~= "Vector3" then
		return
	end
	if typeof(Power) ~= "number" or Power <= 0 then
		return
	end

	local receivedAt = Workspace:GetServerTimeNow()
	local releaseAt = ResolveRequestedExtraPointKickReleaseTime(receivedAt, RequestedReleaseServerTime)

	extraPointKickToken += 1
	local token = extraPointKickToken
	Packets.ExtraPointKickCinematic:Fire(
		PlayerIdentity.GetIdValue(Player),
		math.clamp(releaseAt - receivedAt, 0.05, EXTRA_POINT_KICK_CINEMATIC_TIME)
	)

	local function ExecuteKick(): ()
		if extraPointKickToken ~= token then
			return
		end
		if not extraPointActive then
			return
		end
		if not CanPlayerThrow(Player) then
			return
		end
		if State:GetPossession() ~= Player then
			return
		end
		local character = Player.Character
		local releaseSpawnPos = ClientSpawnPos
		if character then
			local placement, orientation = ResolveExtraPointPlacement(character)
			if placement then
				releaseSpawnPos = placement
			elseif BallInstance and BallInstance:IsA("BasePart") then
				releaseSpawnPos = BallInstance.Position
			end
			if orientation and BallInstance and BallInstance:IsA("BasePart") then
				BallInstance.CFrame = orientation
			end
		elseif BallInstance and BallInstance:IsA("BasePart") then
			releaseSpawnPos = BallInstance.Position
		end
		local solution = BuildLaunchSolutionFromClient(Player, releaseSpawnPos, Target, Power, CurveFactor)
		if not solution then
			return
		end
		lastThrowOriginX = solution.spawnPos.X
		lastThrowTeam = FTPlayerService:GetPlayerTeam(Player)
		extraPointGoalTeam = if lastThrowTeam == 1 then 2 elseif lastThrowTeam == 2 then 1 else nil
		extraPointPostGoalTriggered = false
		extraPointPostGoalStartedAt = 0
		extraPointPostGoalOrigin = Vector3.zero
		extraPointPostGoalVelocity = Vector3.zero
		LaunchThrow(
			Player,
			solution.spawnPos,
			solution.target,
			solution.power,
			ThrowPrediction.ResolveSpinType(ClientRequestId),
			solution.curve,
			releaseAt,
			ClientRequestId,
			false
		)
	end

	local waitTime = releaseAt - receivedAt
	if waitTime > (1 / 120) then
		task.delay(waitTime, ExecuteKick)
	else
		ExecuteKick()
	end
end

local function HandleBallCatch(Player: Player): ()
	if not CanPlayerAct(Player) then return end
	if HasExternalHolder() then return end

	if TryPriorityCatch() then
		return
	end
	
	local Character = Player.Character
	if not Character then return end
	
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HumanoidRootPart then return end
	
	if not BallInstance or not BallInstance:IsA("BasePart") then return end
	
	local Distance: number = (HumanoidRootPart.Position - BallInstance.Position).Magnitude
	if Distance > FTConfig.GAME_CONFIG.CatchRadius then return end

	CompleteBallCatch(Player, HumanoidRootPart.Position)
end

local function HandleBallKick(Player: Player, Target: Vector3, Power: number, _IsFieldGoal: boolean): ()
	if not CanPlayerThrow(Player) then return end
	if State:GetPossession() ~= Player then return end
	
	local Character = Player.Character
	if not Character then return end
	
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HumanoidRootPart then return end
	
	local SpawnPos: Vector3 = HumanoidRootPart.Position
	local SpinType: number = 1
	
	local Direction: Vector3 = (Target - SpawnPos).Unit
	local ValidTarget: Vector3 = Utility.GetImpactPoint(SpawnPos, Direction, 200)
	ValidTarget = Utility.ClampToMap(ValidTarget)

	ClearPendingPassAttempt()
	
	DetachBallFromPlayer()
	ClearExternalHolderState()
	
	local launchTime = Workspace:GetServerTimeNow()
	State:SetInAir(true)
	State:SetPossession(nil)
	State:SetPhysicsData({
		LaunchTime = launchTime,
		Power = Power,
		Target = ValidTarget,
		SpawnPos = SpawnPos,
		SpinType = SpinType,
	})
	
	UpdateBallCarrierValue(nil)
	
	if BallInstance and BallInstance:IsA("BasePart") then
		BallInstance.Anchored = true
		SetBallAttribute("FTBall_InAir", true)
		SetBallAttribute("FTBall_OnGround", false)
		SetBallAttribute("FTBall_Possession", 0)
		SetBallAttribute("FTBall_ExternalHolder", nil)
		SetBallAttribute("FTBall_LaunchTime", launchTime)
		SetBallAttribute("FTBall_SpawnPos", SpawnPos)
		SetBallAttribute("FTBall_Target", ValidTarget)
		SetBallAttribute("FTBall_Power", Power)
		SetBallAttribute("FTBall_Curve", 0.2)
		SetBallAttribute("FTBall_Spin", SpinType)
		SetBallAttribute("FTBall_GroundPos", nil)
		local seq = (BallInstance:GetAttribute("FTBall_Seq") or 0) + 1
		SetBallAttribute("FTBall_Seq", seq)
	end
	
	FireToAllClients()
end

function GiveBallToPlayer(Player: Player): ()
	if not Player then return end
	if not EnsureBallInstance() then return end
	
	local Character = Player.Character
	if not Character then return end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	CompleteBallCatch(Player, if Root then Root.Position else nil)
end

local function PositionBallForExtraPoint(Player: Player, attackingTeam: number?): ()
	if not Player then return end
	if not EnsureBallInstance() then return end
	if not BallInstance or not BallInstance:IsA("BasePart") then return end

	local Character = Player.Character
	if not Character then return end
	local placement, orientation = ResolveExtraPointPlacement(Character)
	if not placement or not orientation then return end

	DetachBallFromPlayer(Character)
	ClearExternalHolderState()

	lastInBoundsCarrierX = nil
	lastInBoundsBallX = nil
	outCooldownUntil = 0
	ClearPendingPassAttempt()

	State:SetInAir(false)
	State:SetPossession(Player)
	local playerTeam = FTPlayerService:GetPlayerTeam(Player)
	if playerTeam then
		possessionTeam = playerTeam
	end
	State:ClearPhysicsData()

	UpdateBallCarrierValue(Player)
	extraPointActive = true
	
	BallInstance.CFrame = orientation
	BallInstance.AssemblyLinearVelocity = Vector3.zero
	BallInstance.AssemblyAngularVelocity = Vector3.zero
	BallInstance.Anchored = true
	BallInstance.CanCollide = false
	BallInstance.CanTouch = true
	BallInstance.CanQuery = true
	SetBallAttribute("FTBall_InAir", false)
	SetBallAttribute("FTBall_OnGround", false)
	SetBallAttribute("FTBall_Possession", PlayerIdentity.GetIdValue(Player))
	SetBallAttribute("FTBall_ExternalHolder", nil)
	SetBallAttribute("FTBall_GroundPos", nil)
	SetBallAttribute("FTBall_LaunchTime", nil)
	SetBallAttribute("FTBall_SpawnPos", nil)
	SetBallAttribute("FTBall_Target", nil)
	SetBallAttribute("FTBall_Power", nil)
	SetBallAttribute("FTBall_Curve", nil)
	SetBallAttribute("FTBall_Spin", nil)

	FireToAllClients()
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function FTBallService.Init(_self: typeof(FTBallService)): ()
	InitializeBall()
	
	Packets.BallThrow.OnServerEvent:Connect(HandleBallThrow)
	Packets.BallCatch.OnServerEvent:Connect(HandleBallCatch)
	Packets.BallKick.OnServerEvent:Connect(HandleBallKick)
	Packets.ExtraPointKickRequest.OnServerEvent:Connect(HandleExtraPointKickRequest)
end

function FTBallService.Start(_self: typeof(FTBallService)): ()
	RunService.Heartbeat:Connect(UpdateBallPhysics)
	RunService.Heartbeat:Connect(TryAutoCatch)
	RunService.Heartbeat:Connect(ResolveExpiredPendingPassAttempt)
	RunService.Heartbeat:Connect(function()
		if not BallInstance or not BallInstance:IsA("BasePart") then
			lastTouchingParts = {}
			return
		end
		if not State:IsInAir() then
			lastTouchingParts = {}
			return
		end
		if not BallInstance.CanQuery then
			BallInstance.CanQuery = true
		end
		local touching = Workspace:GetPartsInPart(BallInstance)
		local current: {[BasePart]: boolean} = {}
		for _, part in ipairs(touching) do
			if part:IsA("BasePart") and not part:IsDescendantOf(BallInstance) then
				current[part] = true
				if not lastTouchingParts[part] then
					local goalTeam = GetGoalTeamFromPart(part)
					if extraPointActive and goalTeam then
						local ballPosition = if BallInstance and BallInstance:IsA("BasePart") then BallInstance.Position else nil
						StartExtraPointPostGoalContinuation(goalTeam, ballPosition)
						for _, callback in goalTouchCallbacks do
							task.spawn(callback, goalTeam, part)
						end
					end
				end
			end
		end
		lastTouchingParts = current
	end)
	RunService.Heartbeat:Connect(function()
		if os.clock() < outCooldownUntil then return end
		local nowPos
		local carrier = State:GetPossession()
		if carrier then
			local character = carrier.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				nowPos = hrp.Position
				if IsPlayerProtectedFromPlayEnd(carrier) then
					if not inCampoChecker or inCampoChecker(nowPos) then
						lastInBoundsCarrierX = nowPos.X
					end
					return
				end
				if not inCampoChecker or inCampoChecker(nowPos) then
					lastInBoundsCarrierX = nowPos.X
				else
					for _, callback in playEndCallbacks do
						callback(nowPos, "Out with ball", lastInBoundsCarrierX)
					end
					outCooldownUntil = os.clock() + 1
				end
			end
		elseif State:IsInAir() and BallInstance and BallInstance:IsA("BasePart") then
			nowPos = BallInstance.Position
			if extraPointActive and extraPointPostGoalTriggered then
				lastInBoundsBallX = nowPos.X
				return
			end
			if not inCampoChecker or inCampoChecker(nowPos) then
				lastInBoundsBallX = nowPos.X
			else
				for _, callback in playEndCallbacks do
					task.delay(0.2, function()
						callback(nowPos, "Incomplete pass", nil, lastThrowOriginX, lastThrowTeam)
					end)
				end
				ClearPendingPassAttempt()
				State:SetInAir(false)
				State:SetOnGround(true)
				State:ClearPhysicsData()
				BallInstance.Anchored = true
				SetBallAttribute("FTBall_InAir", false)
				SetBallAttribute("FTBall_OnGround", true)
				SetBallAttribute("FTBall_Possession", 0)
				SetBallAttribute("FTBall_GroundPos", nowPos)
				SetBallAttribute("FTBall_LaunchTime", nil)
				outCooldownUntil = os.clock() + 1
			end
		end
		
	end)
end

function FTBallService.GetBallState(_self: typeof(FTBallService))
	return State
end

function FTBallService.GetBallInstance(_self: typeof(FTBallService)): BasePart?
	return EnsureBallInstance()
end

function FTBallService.GiveBallToPlayer(_self: typeof(FTBallService), Player: Player): ()
	GiveBallToPlayer(Player)
end

function FTBallService.HoldBallByModel(_self: typeof(FTBallService), Model: Model, TeamNumber: number?): boolean
	if typeof(Model) ~= "Instance" or not Model:IsA("Model") then
		return false
	end
	return HoldBallByModel(Model, TeamNumber)
end

function FTBallService.GetExternalHolder(_self: typeof(FTBallService)): Model?
	return GetExternalHolder()
end

function FTBallService.TryCatchByPlayer(_self: typeof(FTBallService), Player: Player, Radius: number?, AllowInAir: boolean?): boolean
	if typeof(Player) ~= "Instance" or not Player:IsA("Player") then
		return false
	end

	local EffectiveRadius: number =
		if type(Radius) == "number" then math.max(Radius, FTConfig.GAME_CONFIG.CatchRadius) else FTConfig.GAME_CONFIG.CatchRadius

	return TryCatchBallByPlayer(Player, EffectiveRadius, AllowInAir == true)
end

function FTBallService.SetCatchPriority(
	_self: typeof(FTBallService),
	Player: Player,
	Radius: number?,
	Duration: number?,
	Priority: number?
): ()
	if typeof(Player) ~= "Instance" or not Player:IsA("Player") then
		return
	end

	local EffectiveDuration: number = if type(Duration) == "number" then math.max(Duration, 0) else 0
	if EffectiveDuration <= 0 then
		PriorityCatchRequests[Player] = nil
		return
	end

	local EffectiveRadius: number =
		if type(Radius) == "number" then math.max(Radius, FTConfig.GAME_CONFIG.CatchRadius) else FTConfig.GAME_CONFIG.CatchRadius
	local EffectivePriority: number =
		if type(Priority) == "number" and Priority == Priority and Priority > -math.huge and Priority < math.huge
		then Priority
		else 0
	local RequestedAt: number = os.clock()

	PriorityCatchRequests[Player] = {
		ExpiresAt = RequestedAt + EffectiveDuration,
		Radius = EffectiveRadius,
		Priority = EffectivePriority,
		RequestedAt = RequestedAt,
	}
end

function FTBallService.ClearCatchPriority(_self: typeof(FTBallService), Player: Player): ()
	if typeof(Player) ~= "Instance" or not Player:IsA("Player") then
		return
	end

	PriorityCatchRequests[Player] = nil
end

function FTBallService.DropBallAtPosition(_self: typeof(FTBallService), position: Vector3): ()
	DropBallAtPosition(position)
end

function FTBallService.DropBallFromPlayer(_self: typeof(FTBallService), Player: Player): ()
	DropBallFromPlayer(Player)
end

function FTBallService.PositionBallForExtraPoint(_self: typeof(FTBallService), Player: Player, attackingTeam: number?): ()
	PositionBallForExtraPoint(Player, attackingTeam)
end

function FTBallService.CleanupMatchArtifacts(_self: typeof(FTBallService)): ()
	CleanupMatchArtifacts()
end

function FTBallService.DetachBall(_self: typeof(FTBallService)): ()
	DetachBallFromPlayer()
end

function FTBallService.SkillThrow(_self: typeof(FTBallService), Player: Player, Target: Vector3, Settings: {[string]: any}?): (boolean, number, Vector3?)
	return ExecuteSkillThrow(Player, Target, Settings)
end

function FTBallService.OnInterception(_self: typeof(FTBallService), callback: (info: {team: number, position: Vector3, yard: number}) -> ()): ()
	table.insert(interceptionListeners, callback)
end

function FTBallService.SetPlayEndCallback(_self: typeof(FTBallService), callback: (pos: Vector3, reason: string, lastInBoundsX: number?, throwOriginX: number?, throwTeam: number?) -> ()): ()
	if callback then
		table.insert(playEndCallbacks, callback)
	end
end

function FTBallService.SetCampoChecker(_self: typeof(FTBallService), checker: (pos: Vector3) -> boolean): ()
	inCampoChecker = checker
end

function FTBallService.SetGoalTouchCallback(_self: typeof(FTBallService), callback: (goalTeam: number, part: BasePart) -> ()): ()
	if callback then
		table.insert(goalTouchCallbacks, callback)
	end
end

function FTBallService.SetExtraPointActive(_self: typeof(FTBallService), active: boolean): ()
	extraPointActive = active == true
	extraPointPostGoalTriggered = false
	extraPointPostGoalStartedAt = 0
	extraPointPostGoalOrigin = Vector3.zero
	extraPointPostGoalVelocity = Vector3.zero
	if not extraPointActive then
		extraPointGoalTeam = nil
		lastTouchingParts = {}
		extraPointKickToken += 1
	end
end

return FTBallService

