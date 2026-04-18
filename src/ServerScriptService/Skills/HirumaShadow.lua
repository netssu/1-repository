--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local TweenService: TweenService = game:GetService("TweenService")
local Workspace: Workspace = game:GetService("Workspace")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local HirumaSkillUtils: any = require(script.Parent.Utils.HirumaSkillUtils)
local FTPlayerService: any = require(ServerScriptService.Services.PlayerService)
local FTBallService: any = require(ServerScriptService.Services.BallService)
local FTSpinService: any = require(ServerScriptService.Services.SpinService)

type HiddenState = { [Instance]: number }
type CollisionState = {
	[BasePart]: {
		CanCollideBefore: boolean,
		CanTouchBefore: boolean,
		CanQueryBefore: boolean,
		MasslessBefore: boolean,
	},
}
type MovementState = {
	RootAnchoredBefore: boolean,
	AutoRotateBefore: boolean,
	WalkSpeedBefore: number,
	JumpPowerBefore: number,
	JumpHeightBefore: number,
	UseJumpPowerBefore: boolean,
}

local ZERO: number = 0
local ONE: number = 1
local MIN_DIRECTION_MAGNITUDE: number = 1e-4
local UP_VECTOR: Vector3 = Vector3.new(0, 1, 0)
local NORMAL_SEARCH_RANGE: number = 52
local AWAKEN_SEARCH_RANGE: number = 96
local NORMAL_DASH_DISTANCE: number = 44
local AWAKEN_DASH_DISTANCE: number = 88
local NORMAL_END_OFFSET: number = 3.5
local AWAKEN_END_OFFSET: number = 4.5
local NORMAL_DASH_DURATION: number = 0.78
local AWAKEN_DASH_DURATION: number = 0.62
local NORMAL_SWAY_AMPLITUDE: number = 0.95
local AWAKEN_SWAY_AMPLITUDE: number = 1.45
local CLONE_SPAWN_INTERVAL: number = 0.12
local CLONE_MIN_STEP_DISTANCE: number = 6
local CLONE_FADE_DURATION: number = 0.22
local CLONE_DESTROY_DELAY: number = 0.65
local CLONE_GROUND_EPSILON: number = 0.03
local BALL_HIDE_TRANSPARENCY: number = 1
local ATTR_INVULNERABLE: string = "Invulnerable"
local ATTR_AWAKEN_ACTIVE: string = "AwakenActive"
local ATTR_RESUME_RUN: string = "FTResumeRun"
local GROUND_RAY_HEIGHT: number = 24
local GROUND_RAY_DISTANCE: number = 80
local GROUND_CLEARANCE: number = 0.8

local ActiveTokens: { [Player]: number } = {}

local function FireLocalShadowVFX(Player: Player, Action: string, Token: number): ()
	local Success: boolean, ErrorMessage: any = pcall(function()
		Packets.Replicator:FireClient(Player, {
			Type = "HirumaShadow",
			Action = Action,
			Token = Token,
		})
	end)
	if not Success then
		warn(string.format("HirumaShadow local VFX failed for %s: %s", Player.Name, tostring(ErrorMessage)))
	end
end

local function IsAwakenActive(Player: Player, Character: Model): boolean
	return Player:GetAttribute(ATTR_AWAKEN_ACTIVE) == true or Character:GetAttribute(ATTR_AWAKEN_ACTIVE) == true
end

local function SetInvulnerable(Player: Player, Character: Model, Enabled: boolean): ()
	Player:SetAttribute(ATTR_INVULNERABLE, Enabled)
	Character:SetAttribute(ATTR_INVULNERABLE, Enabled)
end

local function ClearInvulnerable(Player: Player, Character: Model): ()
	Player:SetAttribute(ATTR_INVULNERABLE, false)
	Character:SetAttribute(ATTR_INVULNERABLE, false)
	local CurrentCharacter: Model? = Player.Character
	if CurrentCharacter and CurrentCharacter ~= Character then
		CurrentCharacter:SetAttribute(ATTR_INVULNERABLE, false)
	end
end

local function ClearSkillLock(Player: Player, Character: Model): ()
	local CurrentCharacter: Model? = Player.Character or Character
	GlobalFunctions.SetSkillLock(Player, CurrentCharacter, false)
	if CurrentCharacter ~= Character then
		GlobalFunctions.SetSkillLock(nil, Character, false)
	end
end

local function GetCampo(): Instance?
	local GameFolder: Instance? = Workspace:FindFirstChild("Game")
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
	Params.FilterDescendantsInstances = {Campo}

	local Origin: Vector3 = Position + Vector3.new(0, GROUND_RAY_HEIGHT, 0)
	local Result: RaycastResult? = Workspace:Raycast(Origin, Vector3.new(0, -GROUND_RAY_DISTANCE, 0), Params)
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
		local CFrameValue: CFrame, Size: Vector3 = Campo:GetBoundingBox()
		return CFrameValue.Position.Y + (Size.Y * 0.5)
	end
	return nil
end

local function ResolveRootGroundOffset(Root: BasePart, HumanoidInstance: Humanoid): number
	local BaseOffset: number = (Root.Size.Y * 0.5) + math.max(HumanoidInstance.HipHeight, 0)
	local GroundY: number? = GetGroundY(Root.Position)
	if GroundY ~= nil then
		local MeasuredOffset: number = Root.Position.Y - GroundY
		if MeasuredOffset > 0.25 then
			return math.max(MeasuredOffset, BaseOffset)
		end
	end
	return BaseOffset
end

local function AlignRootToGround(Position: Vector3, RootOffset: number): Vector3
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

local function SaveAndHideCharacter(Character: Model): HiddenState
	local Saved: HiddenState = {}
	for _, Descendant in Character:GetDescendants() do
		if Descendant:IsA("BasePart") or Descendant:IsA("Decal") or Descendant:IsA("Texture") then
			Saved[Descendant] = Descendant.Transparency
			Descendant.Transparency = 1
		end
	end
	return Saved
end

local function RestoreCharacterVisibility(Saved: HiddenState): ()
	for Item, PreviousTransparency in Saved do
		if Item.Parent == nil then
			continue
		end
		if Item:IsA("BasePart") or Item:IsA("Decal") or Item:IsA("Texture") then
			Item.Transparency = PreviousTransparency
		end
	end
end

local function DisableCharacterCollision(Character: Model): CollisionState
	local Saved: CollisionState = {}
	for _, Descendant in Character:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end
		Saved[Descendant] = {
			CanCollideBefore = Descendant.CanCollide,
			CanTouchBefore = Descendant.CanTouch,
			CanQueryBefore = Descendant.CanQuery,
			MasslessBefore = Descendant.Massless,
		}
		Descendant.CanCollide = false
		Descendant.CanTouch = false
		Descendant.CanQuery = false
		Descendant.Massless = true
	end
	return Saved
end

local function RestoreCharacterCollision(Saved: CollisionState): ()
	for Part, PartState in Saved do
		if Part.Parent == nil then
			continue
		end
		Part.CanCollide = PartState.CanCollideBefore
		Part.CanTouch = PartState.CanTouchBefore
		Part.CanQuery = PartState.CanQueryBefore
		Part.Massless = PartState.MasslessBefore
	end
end

local function FreezeCharacter(Root: BasePart, HumanoidInstance: Humanoid): MovementState
	local State: MovementState = {
		RootAnchoredBefore = Root.Anchored,
		AutoRotateBefore = HumanoidInstance.AutoRotate,
		WalkSpeedBefore = HumanoidInstance.WalkSpeed,
		JumpPowerBefore = HumanoidInstance.JumpPower,
		JumpHeightBefore = HumanoidInstance.JumpHeight,
		UseJumpPowerBefore = HumanoidInstance.UseJumpPower,
	}
	Root.Anchored = true
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	HumanoidInstance.AutoRotate = false
	HumanoidInstance.WalkSpeed = ZERO
	if HumanoidInstance.UseJumpPower then
		HumanoidInstance.JumpPower = ZERO
	else
		HumanoidInstance.JumpHeight = ZERO
	end
	HumanoidInstance.PlatformStand = false
	HumanoidInstance.Sit = false
	return State
end

local function RestoreCharacterMovement(Root: BasePart, HumanoidInstance: Humanoid, State: MovementState): ()
	Root.Anchored = State.RootAnchoredBefore
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	HumanoidInstance.AutoRotate = State.AutoRotateBefore
	HumanoidInstance.WalkSpeed = State.WalkSpeedBefore
	HumanoidInstance.UseJumpPower = State.UseJumpPowerBefore
	if State.UseJumpPowerBefore then
		HumanoidInstance.JumpPower = State.JumpPowerBefore
	else
		HumanoidInstance.JumpHeight = State.JumpHeightBefore
	end
	HumanoidInstance.PlatformStand = false
	HumanoidInstance.Sit = false
end

local function EmitCharacterEffects(Character: Model, SkillFolder: Instance?): ()
	if not SkillFolder then
		return
	end
	local EmitFolder: Instance? = HirumaSkillUtils.FindChildByAliases(SkillFolder, { "Emit" }, false)
	local Clones: { Instance } = HirumaSkillUtils.CloneEmitFolderOntoCharacter(EmitFolder, Character)
	for _, Clone in Clones do
		HirumaSkillUtils.SetEffectsEnabledRecursive(Clone, true)
		HirumaSkillUtils.EmitRecursive(Clone)
	end
	task.delay(0.45, function()
		for _, Clone in Clones do
			if Clone.Parent ~= nil then
				Clone:Destroy()
			end
		end
	end)
end

local function GetGroundReferenceY(Position: Vector3): number?
	local GroundY: number? = GetGroundY(Position)
	if GroundY ~= nil then
		return GroundY
	end
	return GetCampoPlaneY()
end

local function GetCloneAnchorPart(Clone: Instance): BasePart?
	if Clone:IsA("BasePart") then
		return Clone
	end
	if not Clone:IsA("Model") then
		return nil
	end
	local Root: BasePart? = Clone:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	if Root then
		return Root
	end
	if Clone.PrimaryPart then
		return Clone.PrimaryPart
	end
	return Clone:FindFirstChildWhichIsA("BasePart", true)
end

local function MakeCloneCollisionless(Clone: Instance): ()
	local AnchorPart: BasePart? = GetCloneAnchorPart(Clone)

	local function ConfigurePart(Part: BasePart): ()
		Part.CanCollide = false
		Part.CanQuery = false
		Part.CanTouch = false
		Part.Massless = true
		Part.AssemblyLinearVelocity = Vector3.zero
		Part.AssemblyAngularVelocity = Vector3.zero
		Part.Anchored = AnchorPart == nil or Part == AnchorPart
	end

	if Clone:IsA("BasePart") then
		ConfigurePart(Clone)
	else
		for _, Descendant in Clone:GetDescendants() do
			if Descendant:IsA("BasePart") then
				ConfigurePart(Descendant)
			end
		end
	end

	if Clone:IsA("Model") then
		local HumanoidInstance: Humanoid? = Clone:FindFirstChildOfClass("Humanoid")
		if HumanoidInstance then
			HumanoidInstance.AutoRotate = false
			HumanoidInstance.PlatformStand = false
			HumanoidInstance.Sit = false
		end
	end
end

local function AlignCloneToGround(Clone: Instance): ()
	local GroundY: number? = GetGroundReferenceY(
		if Clone:IsA("Model") then Clone:GetPivot().Position else (Clone :: BasePart).Position
	)
	if GroundY == nil then
		return
	end

	if Clone:IsA("Model") then
		local BoxCFrame: CFrame, BoxSize: Vector3 = Clone:GetBoundingBox()
		local BottomY: number = BoxCFrame.Position.Y - (BoxSize.Y * 0.5)
		local ShiftY: number = (GroundY + CLONE_GROUND_EPSILON) - BottomY
		if math.abs(ShiftY) > 0.001 then
			Clone:PivotTo(Clone:GetPivot() + Vector3.new(0, ShiftY, 0))
		end
		return
	end

	local Part: BasePart = Clone :: BasePart
	local BottomY: number = Part.Position.Y - (Part.Size.Y * 0.5)
	local ShiftY: number = (GroundY + CLONE_GROUND_EPSILON) - BottomY
	if math.abs(ShiftY) > 0.001 then
		Part.CFrame = Part.CFrame + Vector3.new(0, ShiftY, 0)
	end
end

local function SpawnShadowClone(CloneTemplate: Instance, WorldCFrame: CFrame): Instance
	local Clone: Instance = CloneTemplate:Clone()
	if Clone:IsA("Model") then
		Clone:PivotTo(WorldCFrame)
	else
		(Clone :: BasePart).CFrame = WorldCFrame
	end
	AlignCloneToGround(Clone)
	MakeCloneCollisionless(Clone)
	Clone.Parent = workspace
	HirumaSkillUtils.SetEffectsEnabledRecursive(Clone, true)
	HirumaSkillUtils.EmitRecursive(Clone)
	if Clone:IsA("Model") then
		local Track: AnimationTrack? = HirumaSkillUtils.PlayGameplayAnimation(Clone, { "Idle" }, 1)
		if Track and Track.Length > 0 then
			pcall(function()
				Track.TimePosition = math.random() * Track.Length
			end)
		end
	end
	return Clone
end

local function GetForward(Root: BasePart): Vector3
	local Direction: Vector3 = Vector3.new(Root.CFrame.LookVector.X, ZERO, Root.CFrame.LookVector.Z)
	if Direction.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return Vector3.new(0, 0, -1)
	end
	return Direction.Unit
end

local function GetRight(Forward: Vector3): Vector3
	local Right: Vector3 = Forward:Cross(UP_VECTOR)
	if Right.Magnitude < MIN_DIRECTION_MAGNITUDE then
		return Vector3.new(1, 0, 0)
	end
	return Right.Unit
end

local function GetShadowSway(Alpha: number, Amplitude: number): number
	local Envelope: number = math.sin(Alpha * math.pi)
	local Primary: number = math.sin(Alpha * math.pi * 0.9)
	local Secondary: number = math.sin((Alpha * math.pi * 1.8) + 0.2) * 0.2
	return (Primary + Secondary) * Amplitude * Envelope
end

local function SnapCharacterToGround(
	Character: Model,
	Root: BasePart,
	HumanoidInstance: Humanoid,
	Position: Vector3,
	Forward: Vector3,
	RootOffset: number
): Vector3
	local GroundedPosition: Vector3 = AlignRootToGround(Position, RootOffset)
	Character:PivotTo(CFrame.lookAt(GroundedPosition, GroundedPosition + Forward, UP_VECTOR))
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	HumanoidInstance:ChangeState(Enum.HumanoidStateType.Running)
	return GroundedPosition
end

local function FindTargetAhead(Player: Player, Root: BasePart, Forward: Vector3, Range: number): (Player?, BasePart?)
	local SourceTeam: number? = FTPlayerService:GetPlayerTeam(Player)
	local SelectedPlayer: Player? = nil
	local SelectedRoot: BasePart? = nil
	local SelectedDistance: number = -math.huge

	for _, Candidate in Players:GetPlayers() do
		if Candidate == Player then
			continue
		end
		if FTPlayerService:GetPlayerTeam(Candidate) == nil then
			continue
		end
		if SourceTeam ~= nil and FTPlayerService:GetPlayerTeam(Candidate) == SourceTeam then
			continue
		end
		local CandidateCharacter: Model? = Candidate.Character
		local CandidateRoot: BasePart? = CandidateCharacter
			and CandidateCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not CandidateRoot then
			continue
		end
		local Offset: Vector3 = CandidateRoot.Position - Root.Position
		local Distance: number = Offset.Magnitude
		if Distance > Range then
			continue
		end
		local FlatOffset: Vector3 = Vector3.new(Offset.X, ZERO, Offset.Z)
		if FlatOffset.Magnitude < MIN_DIRECTION_MAGNITUDE then
			continue
		end
		local Dot: number = Forward:Dot(FlatOffset.Unit)
		if Dot < 0.35 then
			continue
		end
		if Distance > SelectedDistance then
			SelectedDistance = Distance
			SelectedPlayer = Candidate
			SelectedRoot = CandidateRoot
		end
	end

	return SelectedPlayer, SelectedRoot
end

return function(Character: Model): ()
	local Player: Player? = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local HumanoidInstance: Humanoid? = Character:FindFirstChildOfClass("Humanoid")
	if not Root or not HumanoidInstance then
		return
	end

	local SkillFolder: Instance? = HirumaSkillUtils.GetHirumaSkillFolder("Shadow")
	local CloneTemplate: Instance? = HirumaSkillUtils.FindChildByAliases(SkillFolder, { "Clone", "CLone" }, false)
	if not SkillFolder or not CloneTemplate then
		return
	end

	local Token: number = (ActiveTokens[Player] or ZERO) + ONE
	ActiveTokens[Player] = Token
	Player:SetAttribute(ATTR_RESUME_RUN, false)

	local AwakenActive: boolean = IsAwakenActive(Player, Character)
	local ResumeRunningAfterShadow: boolean = FTSpinService:GetRunningState(Player)
	local Range: number = if AwakenActive then AWAKEN_SEARCH_RANGE else NORMAL_SEARCH_RANGE
	local Forward: Vector3 = GetForward(Root)
	local Right: Vector3 = GetRight(Forward)
	local RootGroundOffset: number = ResolveRootGroundOffset(Root, HumanoidInstance)
	local _TargetPlayer: Player?, TargetRoot: BasePart? = FindTargetAhead(Player, Root, Forward, Range)

	local StartPosition: Vector3 = Root.Position
	local EndOffset: number = if AwakenActive then AWAKEN_END_OFFSET else NORMAL_END_OFFSET
	local DashDistance: number = if AwakenActive then AWAKEN_DASH_DISTANCE else NORMAL_DASH_DISTANCE
	local Destination: Vector3
	if TargetRoot then
		local TargetPosition: Vector3 = TargetRoot.Position - (Forward * EndOffset)
		Destination = AlignRootToGround(Vector3.new(TargetPosition.X, Root.Position.Y, TargetPosition.Z), RootGroundOffset)
	else
		local TargetPosition: Vector3 = Root.Position + (Forward * DashDistance)
		Destination = AlignRootToGround(Vector3.new(TargetPosition.X, Root.Position.Y, TargetPosition.Z), RootGroundOffset)
	end
	StartPosition = AlignRootToGround(StartPosition, RootGroundOffset)

	local SavedVisibility: HiddenState? = nil
	local SavedCollision: CollisionState? = nil
	local MovementState: MovementState? = nil
	local BallInstance: BasePart? = nil
	local BallWasHidden: boolean = false
	local BallTransparencyBefore: number = ZERO
	local Clones: { Instance } = {}
	local FinalPosition: Vector3? = nil
	local LocalVFXStarted: boolean = false

	local function Cleanup(): ()
		if BallInstance and BallWasHidden and BallInstance.Parent ~= nil then
			BallInstance.Transparency = BallTransparencyBefore
		end
		if SavedVisibility then
			RestoreCharacterVisibility(SavedVisibility)
		end
		if SavedCollision then
			RestoreCharacterCollision(SavedCollision)
		end
		if MovementState and Character.Parent ~= nil and Root.Parent ~= nil and HumanoidInstance.Parent ~= nil then
			RestoreCharacterMovement(Root, HumanoidInstance, MovementState)
			if FinalPosition ~= nil then
				HirumaSkillUtils.PlayGameplayAnimation(Character, { "Shadow" }, 1)
				task.defer(function()
					for _ = 1, 2 do
						if Character.Parent == nil or Root.Parent == nil or HumanoidInstance.Parent == nil then
							break
						end
						SnapCharacterToGround(Character, Root, HumanoidInstance, FinalPosition, Forward, RootGroundOffset)
						RunService.Heartbeat:Wait()
					end
				end)
			end
		end
		if LocalVFXStarted then
			FireLocalShadowVFX(Player, "End", Token)
		end
		ClearSkillLock(Player, Character)
		ClearInvulnerable(Player, Character)
		task.defer(function()
			ClearSkillLock(Player, Character)
			ClearInvulnerable(Player, Character)
			if ResumeRunningAfterShadow and Player.Parent ~= nil then
				FTSpinService:SetRunningState(Player, true)
				Player:SetAttribute(ATTR_RESUME_RUN, true)
				task.delay(0.25, function()
					if Player.Parent ~= nil and Player:GetAttribute(ATTR_RESUME_RUN) == true then
						Player:SetAttribute(ATTR_RESUME_RUN, false)
					end
				end)
			end
		end)
		HirumaSkillUtils.FadeOutAndDestroy(Clones, CLONE_FADE_DURATION, CLONE_DESTROY_DELAY)
		if ActiveTokens[Player] == Token then
			ActiveTokens[Player] = nil
		end
	end

	local Success: boolean, ErrorMessage: any = xpcall(function()
		SavedVisibility = SaveAndHideCharacter(Character)
		SavedCollision = DisableCharacterCollision(Character)
		MovementState = FreezeCharacter(Root, HumanoidInstance)
		BallInstance = FTBallService:GetBallInstance()
		local BallState = FTBallService:GetBallState()
		if BallInstance and BallState and BallState:GetPossession() == Player then
			BallTransparencyBefore = BallInstance.Transparency
			BallInstance.Transparency = BALL_HIDE_TRANSPARENCY
			BallWasHidden = true
		end

		SetInvulnerable(Player, Character, true)
		GlobalFunctions.SetSkillLock(Player, Character, true)
		FireLocalShadowVFX(Player, "Start", Token)
		HirumaSkillUtils.PlayConfiguredSoundAtCharacterRoot(Character, "Shadow")
		LocalVFXStarted = true
		EmitCharacterEffects(Character, SkillFolder)

		local DashDuration: number = if AwakenActive then AWAKEN_DASH_DURATION else NORMAL_DASH_DURATION
		local SwayAmplitude: number = if AwakenActive then AWAKEN_SWAY_AMPLITUDE else NORMAL_SWAY_AMPLITUDE
		local StartTime: number = os.clock()
		local LastCloneAt: number = -CLONE_SPAWN_INTERVAL
		local LastClonePosition: Vector3? = nil

		while true do
			if ActiveTokens[Player] ~= Token then
				break
			end
			if Character.Parent == nil or Root.Parent == nil then
				break
			end
			local Elapsed: number = os.clock() - StartTime
			local Alpha: number = math.clamp(Elapsed / DashDuration, 0, 1)
			local EasedAlpha: number = TweenService:GetValue(Alpha, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
			local Sway: number = GetShadowSway(EasedAlpha, SwayAmplitude)
			local Position: Vector3 = StartPosition:Lerp(Destination, EasedAlpha) + (Right * Sway)
			Position = AlignRootToGround(Position, RootGroundOffset)
			Character:PivotTo(CFrame.lookAt(Position, Position + Forward, UP_VECTOR))
			Root.AssemblyLinearVelocity = Vector3.zero
			Root.AssemblyAngularVelocity = Vector3.zero

			if (Elapsed - LastCloneAt) >= CLONE_SPAWN_INTERVAL then
				local CanSpawnClone: boolean = LastClonePosition == nil
					or (Position - LastClonePosition).Magnitude >= CLONE_MIN_STEP_DISTANCE
				if CanSpawnClone then
					LastCloneAt = Elapsed
					LastClonePosition = Position
					table.insert(Clones, SpawnShadowClone(CloneTemplate, Character:GetPivot()))
				end
			end

			if Alpha >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end

		if Character.Parent ~= nil and Root.Parent ~= nil then
			FinalPosition = SnapCharacterToGround(Character, Root, HumanoidInstance, Destination, Forward, RootGroundOffset)
			EmitCharacterEffects(Character, SkillFolder)
		end

	end, debug.traceback)

	Cleanup()
	if not Success then
		warn(string.format("HirumaShadow failed for %s: %s", Player.Name, tostring(ErrorMessage)))
	end
end
