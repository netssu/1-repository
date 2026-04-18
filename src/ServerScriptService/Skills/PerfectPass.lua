--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local FTBallService: any = require(ServerScriptService.Services.BallService)
local FTPlayerService: any = require(ServerScriptService.Services.PlayerService)
local MatchCutsceneLock = require(script.Parent.Utils.MatchCutsceneLock)

local CUTSCENE_MIN_DURATION: number = 516 / 60
local CUTSCENE_FINISH_TIMEOUT: number = CUTSCENE_MIN_DURATION + 5
local TEAMMATE_FRONT_DOT_MIN: number = 0.45
local TEAMMATE_FRONT_MAX_DISTANCE: number = 60
local ENEMY_MAX_DISTANCE: number = 60
local PERFECT_PASS_CUTSCENE_SOUND_ID: number = 103766926735598
local ZERO: number = 0
local FALLBACK_FORWARD: Vector3 = Vector3.new(0, 0, -1)
local BALL_CUTSCENE_HIDDEN_ATTR: string = "FTBall_CutsceneHidden"
local PERFECT_PASS_CUTSCENE_LOCK_ATTR: string = "FTPerfectPassCutsceneLocked"
local GROUND_RAY_HEIGHT: number = 24
local GROUND_RAY_DISTANCE: number = 80
local GROUND_CLEARANCE: number = 0.8
local GROUND_OFFSET_MIN: number = 0.25
local GROUND_SNAP_EPSILON: number = 0.05

type SelectedCast = {
	EnemyOne: Player?,
	EnemyTwo: Player?,
	Receiver: Player?,
}

local LockController = MatchCutsceneLock.new({
	CutsceneAttributeName = PERFECT_PASS_CUTSCENE_LOCK_ATTR,
})

local ActiveToken: number = 0
local ActiveSource: Player? = nil
local ActiveReceiver: Player? = nil
local ActiveAnchorPosition: Vector3? = nil
local ActiveStartedAt: number = 0
local ActiveClientConfirmed: boolean = false
local ActiveHiddenBall: {
	Ball: BasePart?,
	Container: Instance?,
	Parent: Instance?,
	Transparencies: {[Instance]: number},
}?

local function GetRoot(Character: Model?): BasePart?
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function IsFiniteNumber(Value: number): boolean
	return Value == Value and Value > -math.huge and Value < math.huge
end

local function SanitizeCutsceneCFrame(Target: any): CFrame?
	if typeof(Target) ~= "CFrame" then
		return nil
	end

	local Components = {Target:GetComponents()}
	for _, Component in Components do
		if not IsFiniteNumber(Component) then
			return nil
		end
	end

	return Target
end

local function ResolveAlignmentPart(Character: Model): BasePart?
	for _, PartName in { "Torso", "UpperTorso", "HumanoidRootPart" } do
		local Part: Instance? = Character:FindFirstChild(PartName, true)
		if Part and Part:IsA("BasePart") then
			return Part
		end
	end

	return Character:FindFirstChildWhichIsA("BasePart", true)
end

local function AlignCharacterToCutsceneCFrame(Character: Model, TargetCFrame: CFrame): ()
	local AlignmentPart: BasePart? = ResolveAlignmentPart(Character)
	if not AlignmentPart then
		return
	end

	local CharacterPivot: CFrame = Character:GetPivot()
	local AlignmentOffset: CFrame = CharacterPivot:ToObjectSpace(AlignmentPart.CFrame)
	Character:PivotTo(TargetCFrame * AlignmentOffset:Inverse())

	local Root: BasePart? = GetRoot(Character)
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function GetCampo(): Instance?
	local GameFolder: Instance? = workspace:FindFirstChild("Game")
	if not GameFolder then
		return nil
	end
	return GameFolder:FindFirstChild("Campo")
end

local function GetGroundY(Position: Vector3): number?
	local Campo: Instance? = GetCampo()
	if not Campo then
		return nil
	end

	local Params: RaycastParams = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Campo }

	local Origin: Vector3 = Position + Vector3.new(0, GROUND_RAY_HEIGHT, 0)
	local Result: RaycastResult? = workspace:Raycast(Origin, Vector3.new(0, -GROUND_RAY_DISTANCE, 0), Params)
	return Result and Result.Position.Y or nil
end

local function GetCampoPlaneY(): number?
	local Campo: Instance? = GetCampo()
	if not Campo then
		return nil
	end
	if Campo:IsA("BasePart") then
		return Campo.Position.Y + (Campo.Size.Y * 0.5)
	end
	if Campo:IsA("Model") then
		local CampoCFrame: CFrame, CampoSize: Vector3 = Campo:GetBoundingBox()
		return CampoCFrame.Position.Y + (CampoSize.Y * 0.5)
	end
	return nil
end

local function ResolveRootGroundOffset(Root: BasePart, HumanoidInstance: Humanoid): number
	local BaseOffset: number = (Root.Size.Y * 0.5) + math.max(HumanoidInstance.HipHeight, 0)
	local GroundY: number? = GetGroundY(Root.Position)
	if GroundY ~= nil then
		local MeasuredOffset: number = Root.Position.Y - GroundY
		if MeasuredOffset > GROUND_OFFSET_MIN then
			return math.max(MeasuredOffset, BaseOffset)
		end
	end
	return BaseOffset
end

local function AlignRootAboveGround(Position: Vector3, RootOffset: number): Vector3
	local GroundY: number? = GetGroundY(Position)
	if GroundY ~= nil then
		return Vector3.new(Position.X, GroundY + RootOffset + GROUND_CLEARANCE, Position.Z)
	end

	local PlaneY: number? = GetCampoPlaneY()
	if PlaneY ~= nil then
		return Vector3.new(Position.X, PlaneY + RootOffset + GROUND_CLEARANCE, Position.Z)
	end

	return Position
end

local function LiftCharacterAboveGroundIfNeeded(Character: Model): ()
	local Root: BasePart? = GetRoot(Character)
	if not Root then
		return
	end

	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return
	end

	local GroundedPosition: Vector3 = AlignRootAboveGround(
		Root.Position,
		ResolveRootGroundOffset(Root, HumanoidInstance)
	)
	local LiftAmount: number = GroundedPosition.Y - Root.Position.Y
	if LiftAmount <= GROUND_SNAP_EPSILON then
		return
	end

	Character:PivotTo(Character:GetPivot() + Vector3.new(0, LiftAmount, 0))
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	HumanoidInstance:ChangeState(Enum.HumanoidStateType.Running)
end

local function LiftPlayersAboveGroundIfNeeded(PlayersToLift: {Player}): ()
	for _, Player in PlayersToLift do
		local Character: Model? = Player.Character
		if not Character or Character.Parent == nil then
			continue
		end
		LiftCharacterAboveGroundIfNeeded(Character)
	end
end

local function IsValidMatchPlayer(Player: Player): boolean
	if not FTPlayerService:IsPlayerInMatch(Player) then
		return false
	end
	local Character: Model? = Player.Character
	if not Character or Character.Parent == nil then
		return false
	end
	return GetRoot(Character) ~= nil
end

local function GetMatchPlayers(): {Player}
	local Result: {Player} = {}
	for _, Player in Players:GetPlayers() do
		if IsValidMatchPlayer(Player) then
			table.insert(Result, Player)
		end
	end
	return Result
end

local function GetPlanarDirection(Vector: Vector3): Vector3?
	local Flat: Vector3 = Vector3.new(Vector.X, ZERO, Vector.Z)
	if Flat.Magnitude <= 0.001 then
		return nil
	end
	return Flat.Unit
end

local function GetPlanarDistance(A: Vector3, B: Vector3): number
	local Delta: Vector3 = A - B
	return Vector3.new(Delta.X, ZERO, Delta.Z).Magnitude
end

local function SelectReceiver(SourcePlayer: Player, SourceTeam: number, SourceRoot: BasePart, MatchPlayers: {Player}): Player?
	local Forward: Vector3? = GetPlanarDirection(SourceRoot.CFrame.LookVector)
	if not Forward then
		return nil
	end

	local BestPlayer: Player? = nil
	local BestDistance: number = math.huge

	for _, Candidate in MatchPlayers do
		if Candidate == SourcePlayer then
			continue
		end
		if FTPlayerService:GetPlayerTeam(Candidate) ~= SourceTeam then
			continue
		end

		local CandidateRoot: BasePart? = GetRoot(Candidate.Character)
		if not CandidateRoot then
			continue
		end

		local Offset: Vector3 = CandidateRoot.Position - SourceRoot.Position
		local FlatOffset: Vector3? = GetPlanarDirection(Offset)
		if not FlatOffset then
			continue
		end

		local Dot: number = Forward:Dot(FlatOffset)
		if Dot < TEAMMATE_FRONT_DOT_MIN then
			continue
		end

		local Distance: number = GetPlanarDistance(CandidateRoot.Position, SourceRoot.Position)
		if Distance > TEAMMATE_FRONT_MAX_DISTANCE then
			continue
		end
		if Distance >= BestDistance then
			continue
		end

		BestDistance = Distance
		BestPlayer = Candidate
	end

	return BestPlayer
end

local function SelectEnemies(SourceTeam: number, SourceRoot: BasePart, MatchPlayers: {Player}): (Player?, Player?)
	local Candidates: {{Player: Player, Distance: number}} = {}

	for _, Candidate in MatchPlayers do
		local CandidateTeam: number? = FTPlayerService:GetPlayerTeam(Candidate)
		if CandidateTeam == nil or CandidateTeam == SourceTeam then
			continue
		end

		local CandidateRoot: BasePart? = GetRoot(Candidate.Character)
		if not CandidateRoot then
			continue
		end

		local Distance: number = GetPlanarDistance(CandidateRoot.Position, SourceRoot.Position)
		if Distance > ENEMY_MAX_DISTANCE then
			continue
		end

		table.insert(Candidates, {
			Player = Candidate,
			Distance = Distance,
		})
	end

	table.sort(Candidates, function(A, B)
		return A.Distance < B.Distance
	end)

	local First: Player? = Candidates[1] and Candidates[1].Player or nil
	local Second: Player? = Candidates[2] and Candidates[2].Player or nil
	return First, Second
end

local function BuildCast(SourcePlayer: Player, SourceRoot: BasePart): SelectedCast?
	local SourceTeam: number? = FTPlayerService:GetPlayerTeam(SourcePlayer)
	if SourceTeam == nil then
		return nil
	end

	local MatchPlayers: {Player} = GetMatchPlayers()
	local Receiver: Player? = SelectReceiver(SourcePlayer, SourceTeam, SourceRoot, MatchPlayers)
	if not Receiver and not RunService:IsStudio() then
		return nil
	end
	local EnemyOne: Player?, EnemyTwo: Player? = SelectEnemies(SourceTeam, SourceRoot, MatchPlayers)

	return {
		EnemyOne = EnemyOne,
		EnemyTwo = EnemyTwo,
		Receiver = Receiver,
	}
end

local function GetBallStorageFolder(): Folder
	local Existing: Instance? = ReplicatedStorage:FindFirstChild("FTCutsceneStorage")
	if Existing and Existing:IsA("Folder") then
		return Existing
	end

	local Folder: Folder = Instance.new("Folder")
	Folder.Name = "FTCutsceneStorage"
	Folder.Parent = ReplicatedStorage
	return Folder
end

local function ResolveBallContainer(Ball: BasePart): Instance
	local GameFolder: Instance? = workspace:FindFirstChild("Game")
	if GameFolder then
		local Football: Instance? = GameFolder:FindFirstChild("Football")
		if Football and (Football == Ball or Ball:IsDescendantOf(Football)) then
			return Football
		end
	end
	return Ball
end

local function SetBallCutsceneHidden(Hidden: boolean, Ball: BasePart?, Container: Instance?): ()
	local BallData: Instance? = ReplicatedStorage:FindFirstChild("FTBallData")
	if BallData then
		BallData:SetAttribute(BALL_CUTSCENE_HIDDEN_ATTR, Hidden)
	end
	if Container then
		Container:SetAttribute(BALL_CUTSCENE_HIDDEN_ATTR, Hidden)
	end
	if Ball and Ball ~= Container then
		Ball:SetAttribute(BALL_CUTSCENE_HIDDEN_ATTR, Hidden)
	end
end

local function SetInstanceTransparent(Target: Instance, Transparencies: {[Instance]: number}): ()
	if Target:IsA("BasePart") or Target:IsA("Decal") or Target:IsA("Texture") then
		local Visual: any = Target
		Transparencies[Target] = Visual.Transparency
		Visual.Transparency = 1
	end
end

local function HideBall(): ()
	local Ball: BasePart? = FTBallService:GetBallInstance()
	if not Ball then
		return
	end
	local Container: Instance = ResolveBallContainer(Ball)
	ActiveHiddenBall = {
		Ball = Ball,
		Container = Container,
		Parent = Container.Parent,
		Transparencies = {},
	}
	SetBallCutsceneHidden(true, Ball, Container)
	SetInstanceTransparent(Container, ActiveHiddenBall.Transparencies)
	for _, Descendant in Container:GetDescendants() do
		SetInstanceTransparent(Descendant, ActiveHiddenBall.Transparencies)
	end
	Container.Parent = GetBallStorageFolder()
end

local function RestoreBallContainer(): ()
	local HiddenBall = ActiveHiddenBall
	if not HiddenBall then
		return
	end
	local Container: Instance? = HiddenBall.Container
	if not Container then
		return
	end
	local RestoreParent: Instance? = HiddenBall.Parent
	if RestoreParent == nil then
		RestoreParent = workspace:FindFirstChild("Game")
	end
	if RestoreParent and Container.Parent ~= RestoreParent then
		Container.Parent = RestoreParent
	end
end

local function RestoreBallVisibility(): ()
	local HiddenBall = ActiveHiddenBall
	ActiveHiddenBall = nil
	if not HiddenBall then
		SetBallCutsceneHidden(false, nil, nil)
		return
	end
	local Ball: BasePart? = HiddenBall.Ball
	local Container: Instance? = HiddenBall.Container
	SetBallCutsceneHidden(false, Ball, Container)
	for Descendant, Transparency in HiddenBall.Transparencies do
		if Descendant.Parent ~= nil then
			local Visual: any = Descendant
			Visual.Transparency = Transparency
		end
	end
end

local function BroadcastCutscene(
	SourcePlayer: Player,
	AnchorPosition: Vector3,
	AnchorForward: Vector3,
	Cast: SelectedCast,
	Token: number
): ()
	local SourceUserId: number = SourcePlayer.UserId
	local EnemyOneId: number = if Cast.EnemyOne then Cast.EnemyOne.UserId else ZERO
	local EnemyTwoId: number = if Cast.EnemyTwo then Cast.EnemyTwo.UserId else ZERO
	local ReceiverId: number = if Cast.Receiver then Cast.Receiver.UserId else ZERO

	for _, Player in Players:GetPlayers() do
		if FTPlayerService:IsPlayerInMatch(Player) then
			Packets.PlaySound:FireClient(Player, PERFECT_PASS_CUTSCENE_SOUND_ID, false)
			Packets.PerfectPassCutscene:FireClient(
				Player,
				SourceUserId,
				AnchorPosition,
				AnchorForward,
				CUTSCENE_MIN_DURATION,
				Token,
				EnemyOneId,
				EnemyTwoId,
				ReceiverId
			)
		end
	end
end

local function ResolveBallOwner(SourcePlayer: Player?): Player?
	if ActiveReceiver and IsValidMatchPlayer(ActiveReceiver) then
		return ActiveReceiver
	end
	if SourcePlayer and IsValidMatchPlayer(SourcePlayer) then
		return SourcePlayer
	end
	return nil
end

local function FinishCutscene(Token: number): ()
	if ActiveToken ~= Token then
		return
	end

	local SourcePlayer: Player? = ActiveSource
	local AnchorPosition: Vector3? = ActiveAnchorPosition
	local Owner: Player? = ResolveBallOwner(SourcePlayer)
	local MatchPlayers: {Player} = GetMatchPlayers()

	LiftPlayersAboveGroundIfNeeded(MatchPlayers)
	LockController:CaptureCurrentPivots(MatchPlayers)

	RestoreBallContainer()

	if Owner then
		FTBallService:GiveBallToPlayer(Owner)
	elseif AnchorPosition then
		FTBallService:DropBallAtPosition(AnchorPosition)
	end

	RestoreBallVisibility()
	LockController:Stop(nil)

	ActiveSource = nil
	ActiveReceiver = nil
	ActiveAnchorPosition = nil
	ActiveStartedAt = ZERO
	ActiveClientConfirmed = false
end

local function TryFinishCutscene(Token: number, Force: boolean): ()
	if ActiveToken ~= Token then
		return
	end

	if not Force then
		if os.clock() - ActiveStartedAt < CUTSCENE_MIN_DURATION then
			return
		end
		if not ActiveClientConfirmed then
			return
		end
	end

	FinishCutscene(Token)
end

local function PerfectPass(Character: Model): ()
	local SourcePlayer: Player? = Players:GetPlayerFromCharacter(Character)
	if not SourcePlayer then
		return
	end
	if ActiveSource ~= nil then
		return
	end

	local SourceRoot: BasePart? = GetRoot(Character)
	if not SourceRoot then
		return
	end

	local BallState = FTBallService:GetBallState()
	if not BallState or BallState:GetPossession() ~= SourcePlayer then
		return
	end

	local Cast: SelectedCast? = BuildCast(SourcePlayer, SourceRoot)
	if not Cast then
		return
	end

	ActiveToken += 1
	local Token: number = ActiveToken
	ActiveSource = SourcePlayer
	ActiveReceiver = Cast.Receiver
	ActiveAnchorPosition = SourceRoot.Position
	ActiveStartedAt = os.clock()
	ActiveClientConfirmed = false

	local SourceForward: Vector3 = GetPlanarDirection(SourceRoot.CFrame.LookVector) or FALLBACK_FORWARD

	HideBall()
	LockController:Start(GetMatchPlayers(), CUTSCENE_FINISH_TIMEOUT)
	BroadcastCutscene(SourcePlayer, SourceRoot.Position, SourceForward, Cast, Token)

	task.delay(CUTSCENE_MIN_DURATION, function()
		TryFinishCutscene(Token, false)
	end)
	task.delay(CUTSCENE_FINISH_TIMEOUT, function()
		TryFinishCutscene(Token, true)
	end)
end

Packets.PerfectPassCutsceneEnded.OnServerEvent:Connect(function(Player: Player, Token: number, FinalCFrame: any)
	if type(Token) ~= "number" then
		return
	end
	if Player ~= ActiveSource then
		return
	end
	if ActiveToken ~= math.floor(Token + 0.5) then
		return
	end

	local Character: Model? = Player.Character
	local SanitizedCFrame: CFrame? = SanitizeCutsceneCFrame(FinalCFrame)
	if Character and SanitizedCFrame then
		AlignCharacterToCutsceneCFrame(Character, SanitizedCFrame)
		LockController:CaptureCurrentPivots({ Player })
	end

	ActiveClientConfirmed = true
	TryFinishCutscene(ActiveToken, false)
end)

return PerfectPass
