--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local FTBallService = require(script.Parent.BallService)
local FTGameService = require(script.Parent.GameService)
local FTPlayerService = require(script.Parent.PlayerService)

local SoloTackleTestService = {}

local DRIBBLE_RIG_NAME = "TaclkeTest"
local CATCH_RIG_NAME = "TaclkeCatch"
local AUTO_CLONE_OFFSET = CFrame.new(0, 0, -12)
local CATCH_RADIUS = FTConfig.GAME_CONFIG.CatchRadius

type ApplyStunCallback = (Player, number) -> ()
type GameStateLike = {
	MatchStarted: boolean,
	CountdownActive: boolean,
	IntermissionActive: boolean,
	ExtraPointActive: boolean,
	PossessingTeam: number,
}

local CatchRigTeam: number? = nil

local function GetGameState(): GameStateLike?
	local State = FTGameService:GetGameState()
	if type(State) ~= "table" then
		return nil
	end
	return State :: any
end

local function ResolveRig(Name: string): Model?
	local InstanceItem = Workspace:FindFirstChild(Name)
	if InstanceItem and InstanceItem:IsA("Model") then
		return InstanceItem
	end
	return nil
end

local function ResolveRigRoot(Rig: Model?): BasePart?
	if not Rig then
		return nil
	end
	return (Rig.PrimaryPart or Rig:FindFirstChild("HumanoidRootPart") or Rig:FindFirstChildWhichIsA("BasePart", true)) :: BasePart?
end

local function PrepareRig(Rig: Model?): ()
	if not Rig then
		return
	end

	local Root = ResolveRigRoot(Rig)
	if not Root then
		return
	end

	if Rig.PrimaryPart ~= Root then
		pcall(function()
			Rig.PrimaryPart = Root
		end)
	end

	for _, Descendant in Rig:GetDescendants() do
		if Descendant:IsA("BasePart") then
			Descendant.CanCollide = false
			Descendant.CanTouch = false
			Descendant.CanQuery = false
		end
	end

	Root.Anchored = true
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero

	local Humanoid = Rig:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		Humanoid.WalkSpeed = 0
		Humanoid.AutoRotate = false
		Humanoid.PlatformStand = false
		Humanoid.Sit = false
		if Humanoid.UseJumpPower then
			Humanoid.JumpPower = 0
		else
			Humanoid.JumpHeight = 0
		end
	end

	Rig:SetAttribute("FTSoloTackleRig", true)
end

local function ResolveCatchRigTemplate(): Model?
	local Existing = ResolveRig(DRIBBLE_RIG_NAME)
	return Existing
end

local function EnsureCatchRig(): Model?
	local Existing = ResolveRig(CATCH_RIG_NAME)
	if Existing then
		PrepareRig(Existing)
		return Existing
	end

	local Template = ResolveCatchRigTemplate()
	if not Template then
		return nil
	end

	local Clone = Template:Clone()
	Clone.Name = CATCH_RIG_NAME
	Clone.Parent = Workspace

	local SourceRig = ResolveRig(DRIBBLE_RIG_NAME)
	if SourceRig then
		Clone:PivotTo(SourceRig:GetPivot() * AUTO_CLONE_OFFSET)
	else
		local SpawnLocation = Workspace:FindFirstChild("SpawnLocation")
		if SpawnLocation and SpawnLocation:IsA("BasePart") then
			Clone:PivotTo(SpawnLocation.CFrame * AUTO_CLONE_OFFSET)
		end
	end

	PrepareRig(Clone)
	return Clone
end

local function IsPointInBox(BoxCFrame: CFrame, Size: Vector3, Point: Vector3): boolean
	local LocalPos = BoxCFrame:PointToObjectSpace(Point)
	local Half = Size * 0.5
	return math.abs(LocalPos.X) <= Half.X
		and math.abs(LocalPos.Y) <= Half.Y
		and math.abs(LocalPos.Z) <= Half.Z
end

local function HasLineOfSight(AttackerRoot: BasePart, TargetRoot: BasePart): boolean
	local Direction = TargetRoot.Position - AttackerRoot.Position
	if Direction.Magnitude < 1e-3 then
		return true
	end

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { AttackerRoot.Parent, TargetRoot.Parent }
	Params.RespectCanCollide = true

	return Workspace:Raycast(AttackerRoot.Position, Direction, Params) == nil
end

local function IsRigInsideHitbox(Rig: Model?, BoxCFrame: CFrame, Size: Vector3, AttackerRoot: BasePart?): boolean
	local Root = ResolveRigRoot(Rig)
	if not Root then
		return false
	end
	if not IsPointInBox(BoxCFrame, Size, Root.Position) then
		return false
	end
	if AttackerRoot and not HasLineOfSight(AttackerRoot, Root) then
		return false
	end
	return true
end

local function GetYardAtPosition(Position: Vector3): number
	local GameFolder = Workspace:FindFirstChild("Game")
	local YardFolder = GameFolder and GameFolder:FindFirstChild("Jardas")
	local G1 = YardFolder and YardFolder:FindFirstChild("GTeam1")
	local G2 = YardFolder and YardFolder:FindFirstChild("GTeam2")
	local Yard = 50

	if G1 and G2 and G1:IsA("BasePart") and G2:IsA("BasePart") then
		local StartX = G1.Position.X
		local EndX = G2.Position.X
		local Length = EndX - StartX
		if math.abs(Length) > 1e-3 then
			Yard = math.clamp(((Position.X - StartX) / Length) * 100, 0, 100)
		end
	end

	return Yard
end

local function ResolveRestartYard(Result: any, FallbackPosition: Vector3?): number?
	if type(Result) == "table" then
		local Report = Result.report
		if type(Report) == "table" then
			local CurrentYard = Report.currentYard
			if typeof(CurrentYard) == "number" then
				return math.clamp(CurrentYard, 0, 100)
			end

			local LineYard = Report.lineYard
			if typeof(LineYard) == "number" then
				return math.clamp(LineYard, 0, 100)
			end
		end
	end

	if FallbackPosition then
		return GetYardAtPosition(FallbackPosition)
	end

	return nil
end

local function ResolveOpposingTeam(PlayerInstance: Player?): number
	local PlayerTeam = if PlayerInstance then FTPlayerService:GetPlayerTeam(PlayerInstance) else nil
	if PlayerTeam == 1 then
		return 2
	end
	if PlayerTeam == 2 then
		return 1
	end

	local State = GetGameState()
	if State and State.PossessingTeam == 1 then
		return 2
	end

	return 1
end

local function ShouldRunTests(): boolean
	local State = GetGameState()
	return State ~= nil
		and State.MatchStarted == true
		and State.IntermissionActive ~= true
		and State.CountdownActive ~= true
		and State.ExtraPointActive ~= true
end

local function IsCatchRigHolding(CatchRig: Model?): boolean
	if not CatchRig or not FTBallService.GetExternalHolder then
		return false
	end
	return FTBallService:GetExternalHolder() == CatchRig
end

local function TryCatchBallForRig(): ()
	if not ShouldRunTests() then
		return
	end

	local CatchRig = EnsureCatchRig()
	if not CatchRig then
		return
	end
	PrepareRig(CatchRig)

	if IsCatchRigHolding(CatchRig) then
		return
	end

	local BallState = FTBallService:GetBallState()
	if not BallState or BallState:GetPossession() ~= nil then
		return
	end
	if not BallState:IsInAir() and not BallState:IsOnGround() then
		return
	end

	local Ball = FTBallService:GetBallInstance()
	local Root = ResolveRigRoot(CatchRig)
	if not Ball or not Root then
		return
	end
	if (Ball.Position - Root.Position).Magnitude > CATCH_RADIUS then
		return
	end

	local CatchTeam = ResolveOpposingTeam(nil)
	if FTBallService.HoldBallByModel and FTBallService:HoldBallByModel(CatchRig, nil) then
		CatchRigTeam = CatchTeam
	end
end

local function SyncRigs(): ()
	local DribbleRig = ResolveRig(DRIBBLE_RIG_NAME)
	if DribbleRig then
		PrepareRig(DribbleRig)
	end

	local CatchRig = EnsureCatchRig()
	if CatchRig then
		PrepareRig(CatchRig)
	end

	if CatchRig == nil or not IsCatchRigHolding(CatchRig) then
		CatchRigTeam = nil
	end
end

function SoloTackleTestService.Init(_self: typeof(SoloTackleTestService)): ()
	SyncRigs()
end

function SoloTackleTestService.Start(_self: typeof(SoloTackleTestService)): ()
	RunService.Heartbeat:Connect(function()
		SyncRigs()
		TryCatchBallForRig()
	end)
end

function SoloTackleTestService.TryHandleTackleHit(
	_self: typeof(SoloTackleTestService),
	Attacker: Player,
	BoxCFrame: CFrame,
	Size: Vector3,
	AttackerRoot: BasePart?,
	ApplyStun: ApplyStunCallback,
	StunDuration: number
): boolean
	if typeof(Attacker) ~= "Instance" or not Attacker:IsA("Player") then
		return false
	end
	if typeof(ApplyStun) ~= "function" then
		return false
	end
	if not ShouldRunTests() then
		return false
	end

	local CatchRig = EnsureCatchRig()
	if CatchRig and CatchRigTeam ~= nil and IsCatchRigHolding(CatchRig) then
		PrepareRig(CatchRig)
		if IsRigInsideHitbox(CatchRig, BoxCFrame, Size, AttackerRoot) then
			local Root = ResolveRigRoot(CatchRig)
			FTBallService:GiveBallToPlayer(Attacker)
			CatchRigTeam = nil
			if Root then
				local Result = FTGameService:ProcessPlayEnd(Root.Position, "Tackle")
				local RestartYard = ResolveRestartYard(Result, Root.Position)
				if RestartYard ~= nil then
					task.defer(function()
						FTGameService:TeleportPlayersToYard(RestartYard)
					end)
				end
			end
			return true
		end
	end

	local DribbleRig = ResolveRig(DRIBBLE_RIG_NAME)
	if DribbleRig then
		PrepareRig(DribbleRig)
		if IsRigInsideHitbox(DribbleRig, BoxCFrame, Size, AttackerRoot) then
			ApplyStun(Attacker, StunDuration)
			return true
		end
	end

	return false
end

return SoloTackleTestService
