--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService: ServerScriptService = game:GetService("ServerScriptService")
local Lighting: Lighting = game:GetService("Lighting")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local HirumaSkillUtils: any = require(script.Parent.Utils.HirumaSkillUtils)
local FTBallService: any = require(ServerScriptService.Services.BallService)
local FTPlayerService: any = require(ServerScriptService.Services.PlayerService)
local FTSpinService: any = require(ServerScriptService.Services.SpinService)

local ZERO: number = 0
local MIN_DIRECTION_MAGNITUDE: number = 1e-4
local TEAMMATE_FRONT_DOT_MIN: number = 0.2
local NORMAL_RECEIVER_MAX_DISTANCE: number = 110
local AWAKEN_RECEIVER_MAX_DISTANCE: number = 220
local NORMAL_FORWARD_FALLBACK_DISTANCE: number = 72
local AWAKEN_FORWARD_FALLBACK_DISTANCE: number = 144
local NORMAL_RELEASE_DELAY: number = 0.22
local AWAKEN_RELEASE_DELAY: number = 0.14
local NORMAL_UNLOCK_DELAY: number = 0.52
local AWAKEN_UNLOCK_DELAY: number = 0.4
local EFFECT_FADE_DURATION: number = 0.2
local EFFECT_DESTROY_DELAY: number = 3
local NORMAL_THROW_SPEED: number = 1.15
local AWAKEN_THROW_SPEED: number = 1.4
local NORMAL_THROW_CURVE: number = 0.08
local AWAKEN_THROW_CURVE: number = 0.12
local NORMAL_THROW_TIME_DIVISOR: number = 96
local AWAKEN_THROW_TIME_DIVISOR: number = 132
local NORMAL_THROW_MIN_TIME: number = 0.6
local AWAKEN_THROW_MIN_TIME: number = 0.46
local NORMAL_THROW_MAX_TIME: number = 1.22
local AWAKEN_THROW_MAX_TIME: number = 1.05
local NORMAL_THROW_MAX_POWER: number = 150
local AWAKEN_THROW_MAX_POWER: number = 185
local ATTR_AWAKEN_ACTIVE: string = "AwakenActive"
local ATTR_RESUME_RUN: string = "FTResumeRun"
local THROW_IMPACT_CC_NAME: string = "HirumaThrowImpactCC"
local THROW_IMPACT_CC_DURATION: number = 0.3
local THROW_IMPACT_EARLY_OFFSET: number = 0.05

local function IsAwakenActive(Player: Player, Character: Model): boolean
	return Player:GetAttribute(ATTR_AWAKEN_ACTIVE) == true or Character:GetAttribute(ATTR_AWAKEN_ACTIVE) == true
end

local function ReleaseSkillLock(Player: Player, Character: Model): ()
	local ActiveCharacter: Model? = Player.Character or Character
	GlobalFunctions.SetSkillLock(Player, ActiveCharacter, false)
	if Character ~= ActiveCharacter then
		GlobalFunctions.SetSkillLock(nil, Character, false)
	end
end

local function ResumeRunning(Player: Player): ()
	if Player.Parent == nil then
		return
	end
	FTSpinService:SetRunningState(Player, true)
	Player:SetAttribute(ATTR_RESUME_RUN, true)
	task.delay(0.25, function()
		if Player.Parent ~= nil and Player:GetAttribute(ATTR_RESUME_RUN) == true then
			Player:SetAttribute(ATTR_RESUME_RUN, false)
		end
	end)
end

local function CloneThrowColorCorrectionTemplate(): ColorCorrectionEffect?
	local AwakenFolder: Instance? = HirumaSkillUtils.GetHirumaSkillFolder("Awaken")
	local LightingFolder: Instance? = AwakenFolder and HirumaSkillUtils.FindChildByAliases(AwakenFolder, { "Lighting" }, true)
	if not LightingFolder then
		return nil
	end
	local Effect: ColorCorrectionEffect? = LightingFolder:FindFirstChildWhichIsA("ColorCorrectionEffect", true)
	return Effect and Effect:Clone() or nil
end

local function PlayThrowReleaseColorCorrection(): ()
	local Effect: ColorCorrectionEffect? = CloneThrowColorCorrectionTemplate()
	if not Effect then
		Effect = Instance.new("ColorCorrectionEffect")
		Effect.Name = THROW_IMPACT_CC_NAME
		Effect.Brightness = 0.08
		Effect.Contrast = 0.18
		Effect.Saturation = -0.12
		Effect.TintColor = Color3.fromRGB(255, 240, 255)
	end

	Effect.Name = THROW_IMPACT_CC_NAME
	Effect.Enabled = true
	Effect.Parent = Lighting

	local Tween: Tween = TweenService:Create(Effect, TweenInfo.new(THROW_IMPACT_CC_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
		TintColor = Color3.new(1, 1, 1),
	})
	Tween:Play()
	Tween.Completed:Connect(function()
		if Effect.Parent ~= nil then
			Effect:Destroy()
		end
	end)
end

local function GetRoot(Character: Model?): BasePart?
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function GetHumanoid(Character: Model?): Humanoid?
	if not Character then
		return nil
	end
	return Character:FindFirstChildOfClass("Humanoid")
end

local function GetPlanarDirection(Vector: Vector3): Vector3?
	local Flat: Vector3 = Vector3.new(Vector.X, ZERO, Vector.Z)
	if Flat.Magnitude <= MIN_DIRECTION_MAGNITUDE then
		return nil
	end
	return Flat.Unit
end

local function GetForward(Root: BasePart): Vector3
	local Forward: Vector3? = GetPlanarDirection(Root.CFrame.LookVector)
	return Forward or Vector3.new(0, 0, -1)
end

local function GetRemainingTrackDuration(Track: AnimationTrack?): number
	if not Track or Track.Length <= 0 then
		return 0
	end
	local TrackSpeed: number = Track.Speed
	if TrackSpeed <= 0 then
		TrackSpeed = 1
	end
	return math.max((Track.Length - Track.TimePosition) / TrackSpeed, 0)
end

local function FaceRootTowardsTarget(Root: BasePart, TargetPosition: Vector3): ()
	local Forward: Vector3? = GetPlanarDirection(TargetPosition - Root.Position)
	if not Forward then
		return
	end
	local RootPosition: Vector3 = Root.Position
	Root.AssemblyAngularVelocity = Vector3.zero
	Root.CFrame = CFrame.lookAt(RootPosition, RootPosition + Forward, Vector3.yAxis)
end

local function EstimateTravelTime(Distance: number, AwakenActive: boolean): number
	local TimeDivisor: number = if AwakenActive then AWAKEN_THROW_TIME_DIVISOR else NORMAL_THROW_TIME_DIVISOR
	local MinTime: number = if AwakenActive then AWAKEN_THROW_MIN_TIME else NORMAL_THROW_MIN_TIME
	local MaxTime: number = if AwakenActive then AWAKEN_THROW_MAX_TIME else NORMAL_THROW_MAX_TIME
	return math.clamp(Distance / math.max(TimeDivisor, 1), MinTime, MaxTime)
end

local function IsValidReceiver(Player: Player?, SourcePlayer: Player): boolean
	if not Player or Player == SourcePlayer then
		return false
	end
	if not FTPlayerService:IsPlayerInMatch(Player) then
		return false
	end
	local Character: Model? = Player.Character
	return Character ~= nil and Character.Parent ~= nil and GetRoot(Character) ~= nil
end

local function SelectReceiver(SourcePlayer: Player, SourceRoot: BasePart, AwakenActive: boolean): Player?
	local SourceTeam: number? = FTPlayerService:GetPlayerTeam(SourcePlayer)
	if SourceTeam == nil then
		return nil
	end

	local Forward: Vector3 = GetForward(SourceRoot)
	local MaxDistance: number = if AwakenActive then AWAKEN_RECEIVER_MAX_DISTANCE else NORMAL_RECEIVER_MAX_DISTANCE
	local BestPlayer: Player? = nil
	local BestDistance: number = if AwakenActive then -math.huge else math.huge

	for _, Candidate in Players:GetPlayers() do
		if Candidate == SourcePlayer then
			continue
		end
		if FTPlayerService:GetPlayerTeam(Candidate) ~= SourceTeam then
			continue
		end
		if not FTPlayerService:IsPlayerInMatch(Candidate) then
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

		local Distance: number = Vector3.new(Offset.X, ZERO, Offset.Z).Magnitude
		if Distance > MaxDistance then
			continue
		end

		if AwakenActive then
			if Distance <= BestDistance then
				continue
			end
		elseif Distance >= BestDistance then
			continue
		end

		BestPlayer = Candidate
		BestDistance = Distance
	end

	return BestPlayer
end

local function ResolveThrowTarget(
	SourcePlayer: Player,
	SourceRoot: BasePart,
	AwakenActive: boolean,
	AimTarget: Vector3?
): (Vector3, Player?)
	local Receiver: Player? = SelectReceiver(SourcePlayer, SourceRoot, AwakenActive)
	if Receiver then
		local ReceiverRoot: BasePart? = GetRoot(Receiver.Character)
		if ReceiverRoot then
			local Distance: number = (ReceiverRoot.Position - SourceRoot.Position).Magnitude
			local LeadTime: number = math.clamp(EstimateTravelTime(Distance, AwakenActive), 0.1, 0.8)
			local Velocity: Vector3 = ReceiverRoot.AssemblyLinearVelocity
			local PredictedPosition: Vector3 = ReceiverRoot.Position + Vector3.new(Velocity.X, ZERO, Velocity.Z) * LeadTime
			return PredictedPosition, Receiver
		end
	end

	local Forward: Vector3 = GetForward(SourceRoot)
	if typeof(AimTarget) == "Vector3" then
		local AimDirection: Vector3? = GetPlanarDirection(AimTarget - SourceRoot.Position)
		if AimDirection then
			Forward = AimDirection
		end
	end
	local FallbackDistance: number =
		if AwakenActive then AWAKEN_FORWARD_FALLBACK_DISTANCE else NORMAL_FORWARD_FALLBACK_DISTANCE
	return SourceRoot.Position + (Forward * FallbackDistance), nil
end

local function SpawnEffectAt(Template: Instance, CFrameValue: CFrame, Parent: Instance): Instance
	local Clone: Instance = Template:Clone()
	if Clone:IsA("Model") then
		Clone:PivotTo(CFrameValue)
	else
		(Clone :: BasePart).CFrame = CFrameValue
	end
	Clone.Parent = Parent
	return Clone
end

local function ScheduleImpactCallback(DelayTime: number, Callback: () -> ()): ()
	local AdjustedDelay: number = math.max(DelayTime - THROW_IMPACT_EARLY_OFFSET, 0)
	if AdjustedDelay <= 0 then
		task.defer(Callback)
		return
	end

	local TriggerAt: number = os.clock() + AdjustedDelay
	local Connection: RBXScriptConnection? = nil
	Connection = RunService.Heartbeat:Connect(function()
		if os.clock() < TriggerAt then
			return
		end
		if Connection then
			Connection:Disconnect()
			Connection = nil
		end
		Callback()
	end)
end

local function WeldEffectToPartPreservingTransform(Root: BasePart, Target: Instance, WeldName: string?): ()
	local Name: string = WeldName or "SkillWeld"

	local function PreparePart(Part: BasePart): ()
		Part.Anchored = false
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false
		Part.Massless = true
	end

	local function WeldPart(Part: BasePart): ()
		local Weld: WeldConstraint = Instance.new("WeldConstraint")
		Weld.Name = Name
		Weld.Part0 = Root
		Weld.Part1 = Part
		Weld.Parent = Part
	end

	if Target:IsA("BasePart") then
		local Part: BasePart = Target
		PreparePart(Part)
		WeldPart(Part)
		return
	end

	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("BasePart") then
			PreparePart(Descendant)
			WeldPart(Descendant)
		end
	end
end

return function(Character: Model, Context: { [string]: any }?): ()
	local Player: Player? = Players:GetPlayerFromCharacter(Character)
	if not Player then
		return
	end

	local SkillFolder: Instance? = HirumaSkillUtils.GetHirumaSkillFolder("Throw")
	local ModelContainer: Instance? = HirumaSkillUtils.FindChildByAliases(SkillFolder, { "Model" }, true)
	local ThrowTemplate: Instance? = HirumaSkillUtils.FindChildByAliases(ModelContainer, { "throw" }, true)
	local ImpactTemplate: Instance? = HirumaSkillUtils.FindChildByAliases(ModelContainer, { "throw impact" }, true)
	local Root: BasePart? = GetRoot(Character)
	if not SkillFolder or not Root then
		return
	end

	local AwakenActive: boolean = IsAwakenActive(Player, Character)
	local ResumeRunningAfterThrow: boolean = FTSpinService:GetRunningState(Player)
	local SkillFinished: boolean = false
	local ThrowTrack: AnimationTrack? = HirumaSkillUtils.PlayGameplayAnimation(
		Character,
		{ "ThrowPass" },
		if AwakenActive then AWAKEN_THROW_SPEED else NORMAL_THROW_SPEED
	)
	if ThrowTrack then
		ThrowTrack.Priority = Enum.AnimationPriority.Action
	end
	local FacingLockConnection: RBXScriptConnection? = nil
	local FacingTrackConnection: RBXScriptConnection? = nil
	local FacingLockActive: boolean = false
	local FacingTarget: Vector3? = nil
	local FacingReleaseAt: number = 0
	local FacingHumanoid: Humanoid? = GetHumanoid(Character)
	local FacingOriginalAutoRotate: boolean? = if FacingHumanoid then FacingHumanoid.AutoRotate else nil

	GlobalFunctions.SetSkillLock(Player, Character, true)
	Player:SetAttribute(ATTR_RESUME_RUN, false)

	local function ReleaseFacingLock(): ()
		FacingLockActive = false
		FacingTarget = nil
		FacingReleaseAt = 0
		if FacingLockConnection then
			FacingLockConnection:Disconnect()
			FacingLockConnection = nil
		end
		if FacingTrackConnection then
			FacingTrackConnection:Disconnect()
			FacingTrackConnection = nil
		end
		if FacingHumanoid and FacingHumanoid.Parent ~= nil then
			FacingHumanoid.AutoRotate = if FacingOriginalAutoRotate ~= nil then FacingOriginalAutoRotate else true
		end
	end

	local function StartFacingLock(TargetPosition: Vector3, HoldDuration: number): ()
		local CurrentRoot: BasePart? = GetRoot(Character)
		local CurrentHumanoid: Humanoid? = GetHumanoid(Character)
		if Player.Parent == nil or Player.Character ~= Character or Character.Parent == nil or not CurrentRoot or not CurrentHumanoid then
			return
		end

		if FacingTrackConnection then
			FacingTrackConnection:Disconnect()
			FacingTrackConnection = nil
		end
		if FacingLockConnection then
			FacingLockConnection:Disconnect()
			FacingLockConnection = nil
		end

		FacingHumanoid = CurrentHumanoid
		FacingOriginalAutoRotate = CurrentHumanoid.AutoRotate
		FacingTarget = TargetPosition
		FacingReleaseAt = os.clock() + math.max(HoldDuration, 0.1)
		FacingLockActive = true
		CurrentHumanoid.AutoRotate = false
		FaceRootTowardsTarget(CurrentRoot, TargetPosition)

		if ThrowTrack then
			FacingTrackConnection = ThrowTrack.Stopped:Connect(function()
				ReleaseFacingLock()
			end)
		end

		FacingLockConnection = RunService.Heartbeat:Connect(function()
			if not FacingLockActive then
				ReleaseFacingLock()
				return
			end
			if Player.Parent == nil or Player.Character ~= Character or Character.Parent == nil or os.clock() >= FacingReleaseAt then
				ReleaseFacingLock()
				return
			end

			local ActiveRoot: BasePart? = GetRoot(Character)
			local ActiveHumanoid: Humanoid? = GetHumanoid(Character)
			local ActiveTarget: Vector3? = FacingTarget
			if not ActiveRoot or not ActiveHumanoid or not ActiveTarget then
				ReleaseFacingLock()
				return
			end

			FacingHumanoid = ActiveHumanoid
			ActiveHumanoid.AutoRotate = false
			FaceRootTowardsTarget(ActiveRoot, ActiveTarget)
		end)
	end

	local function FinishSkill(): ()
		if SkillFinished then
			return
		end
		SkillFinished = true
		ReleaseSkillLock(Player, Character)
		if ResumeRunningAfterThrow then
			ResumeRunning(Player)
		end
	end

	local ReleaseDelay: number = if AwakenActive then AWAKEN_RELEASE_DELAY else NORMAL_RELEASE_DELAY
	local UnlockDelay: number = if AwakenActive then AWAKEN_UNLOCK_DELAY else NORMAL_UNLOCK_DELAY
	task.delay(UnlockDelay, function()
		FinishSkill()
	end)

	task.delay(ReleaseDelay, function()
		if Character.Parent == nil or Root.Parent == nil then
			FinishSkill()
			return
		end

		HirumaSkillUtils.PlayConfiguredSoundAtCharacterRoot(Character, "HirumaThrow")
		local AimTarget: Vector3? = if Context and typeof(Context.AimTarget) == "Vector3" then Context.AimTarget else nil
		local ThrowTarget: Vector3, Receiver: Player? = ResolveThrowTarget(Player, Root, AwakenActive, AimTarget)
		local RemainingTrackDuration: number = GetRemainingTrackDuration(ThrowTrack)
		local FacingHoldDuration: number =
			if RemainingTrackDuration > 0 then RemainingTrackDuration else math.max(UnlockDelay - ReleaseDelay, 0.1)
		StartFacingLock(ThrowTarget, FacingHoldDuration)

		local Success: boolean, TravelTime: number, FinalTarget: Vector3? =
			FTBallService:SkillThrow(Player, ThrowTarget, {
				IgnoreSkillLock = true,
				MaxDistance = if AwakenActive then 320 else 220,
				TimeDivisor = if AwakenActive then AWAKEN_THROW_TIME_DIVISOR else NORMAL_THROW_TIME_DIVISOR,
				MinTime = if AwakenActive then AWAKEN_THROW_MIN_TIME else NORMAL_THROW_MIN_TIME,
				MaxTime = if AwakenActive then AWAKEN_THROW_MAX_TIME else NORMAL_THROW_MAX_TIME,
				MaxPower = if AwakenActive then AWAKEN_THROW_MAX_POWER else NORMAL_THROW_MAX_POWER,
				Curve = if AwakenActive then AWAKEN_THROW_CURVE else NORMAL_THROW_CURVE,
			})
		if Success then
			PlayThrowReleaseColorCorrection()
			if ThrowTemplate then
				local ThrowEffect: Instance = SpawnEffectAt(ThrowTemplate, Root.CFrame, Character)
				WeldEffectToPartPreservingTransform(Root, ThrowEffect, "HirumaThrowEffectWeld")
				HirumaSkillUtils.SetEffectsEnabledRecursive(ThrowEffect, true)
				HirumaSkillUtils.EmitRecursive(ThrowEffect)
				HirumaSkillUtils.FadeOutAndDestroy({ ThrowEffect }, EFFECT_FADE_DURATION, EFFECT_DESTROY_DELAY)
			end
		end
		FinishSkill()
		if not Success or typeof(FinalTarget) ~= "Vector3" then
			return
		end

		ScheduleImpactCallback(TravelTime, function()
			local ImpactPosition: Vector3 = FinalTarget
			if IsValidReceiver(Receiver, Player) then
				local ReceiverRoot: BasePart? = GetRoot(Receiver.Character)
				if ReceiverRoot then
					ImpactPosition = ReceiverRoot.Position
					FTBallService:GiveBallToPlayer(Receiver)
					Packets.ThrowPassCatch:FireClient(Receiver, "Catch")
				end
			end

			if not ImpactTemplate then
				return
			end

			local ImpactEffect: Instance = SpawnEffectAt(ImpactTemplate, CFrame.new(ImpactPosition), workspace)
			HirumaSkillUtils.SetEffectsEnabledRecursive(ImpactEffect, true)
			HirumaSkillUtils.EmitRecursive(ImpactEffect)
			HirumaSkillUtils.FadeOutAndDestroy({ ImpactEffect }, EFFECT_FADE_DURATION, EFFECT_DESTROY_DELAY)
		end)
	end)
end
