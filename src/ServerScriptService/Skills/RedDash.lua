--!strict

local KeyframeSequenceProvider: KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets: any = require(ReplicatedStorage.Modules.Game.Packets)
local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local CutsceneRigUtils: any = require(ReplicatedStorage.Modules.Game.Skills.VFX.Client.Init.CutsceneRigUtils)
local FatGuySkillUtils: any = require(script.Parent.Utils.FatGuySkillUtils)

type SegmentConfig = {
	Index: number,
	StartMarker: string,
	EndMarker: string,
	TargetName: string,
}

type SegmentTarget = {
	Forward: Vector3,
	Position: Vector3,
}

type SkillState = {
	Active: boolean,
	Connections: {RBXScriptConnection},
	HandledMarkers: {[string]: boolean},
	MoveToken: number,
	Player: Player,
	ReplicatorStarted: boolean,
	ScheduledMarkers: {[string]: boolean},
	Session: any,
	SegmentDurations: {[number]: number},
	SegmentTargets: {[number]: SegmentTarget},
	Token: number,
	Track: AnimationTrack?,
	TrackStopped: boolean,
}

local SKILL_TYPE_NAME: string = "RedDash"
local ANIMATION_ID: string = "rbxassetid://134400225225538"
local DEFAULT_SEGMENT_DURATION: number = 0.14
local TRACK_STOP_GRACE: number = 0.35
local FALLBACK_TIMELINE_FPS: number = 60
local FALLBACK_TOTAL_FRAMES: number = 110
local TESTER_STYLE_ALIASES: {string} = {
	"Tester",
}
local SKILL_FOLDER_ALIASES: {string} = {
	"Red Dash",
}
local QUICK_PORTS_ALIASES: {string} = {
	"QuickPorts",
}
local MONITORED_MARKERS: {string} = {
	"Start1",
	"Tp1",
	"Start2",
	"Tp2",
	"Start3",
	"Tp3",
	"Star",
}
local SEGMENTS: {SegmentConfig} = {
	{
		Index = 1,
		StartMarker = "Start1",
		EndMarker = "Tp1",
		TargetName = "1",
	},
	{
		Index = 2,
		StartMarker = "Start2",
		EndMarker = "Tp2",
		TargetName = "2",
	},
	{
		Index = 3,
		StartMarker = "Start3",
		EndMarker = "Tp3",
		TargetName = "3",
	},
}

local ActiveStates: {[Player]: SkillState} = {}
local ActiveTokens: {[Player]: number} = {}
local MarkerTimesCache: {[string]: {[string]: number}} = {}

local function NormalizeAnimationId(AnimationId: string | number): string
	local RawId: string = tostring(AnimationId)
	if string.sub(RawId, 1, #"rbxassetid://") == "rbxassetid://" then
		return RawId
	end
	return "rbxassetid://" .. RawId
end

local function NextToken(Current: number?): number
	return (Current or 0) + 1
end

local function TrackConnection(State: SkillState, Connection: RBXScriptConnection): ()
	table.insert(State.Connections, Connection)
end

local function FireReplicator(State: SkillState, Action: string, ExtraData: {[string]: any}?): ()
	local Payload: {[string]: any} = {
		Type = SKILL_TYPE_NAME,
		Action = Action,
		Token = State.Token,
		SourceUserId = State.Player.UserId,
	}

	if ExtraData then
		for Key, Value in ExtraData do
			Payload[Key] = Value
		end
	end

	for _, Observer in Players:GetPlayers() do
		Packets.Replicator:FireClient(Observer, Payload)
	end
end

local function ResolveSkillsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	if not AssetsFolder then
		return nil
	end
	return AssetsFolder:FindFirstChild("Skills")
end

local function ResolveSkillFolder(): Instance?
	local SkillsFolder: Instance? = ResolveSkillsFolder()
	if not SkillsFolder then
		return nil
	end

	local TesterFolder: Instance? = CutsceneRigUtils.FindChildByAliases(SkillsFolder, TESTER_STYLE_ALIASES, false)
	if not TesterFolder then
		return nil
	end

	return CutsceneRigUtils.FindChildByAliases(TesterFolder, SKILL_FOLDER_ALIASES, true)
end

local function ResolveQuickPortsTemplate(): Instance?
	local SkillFolder: Instance? = ResolveSkillFolder()
	if not SkillFolder then
		return nil
	end

	return CutsceneRigUtils.FindChildByAliases(SkillFolder, QUICK_PORTS_ALIASES, true)
end

local function GetInstanceCFrame(Target: Instance?): CFrame?
	if not Target then
		return nil
	end
	if Target:IsA("Model") then
		return Target:GetPivot()
	end
	if Target:IsA("BasePart") then
		return Target.CFrame
	end
	if Target:IsA("Attachment") then
		return Target.WorldCFrame
	end
	return nil
end

local function ResolveMarkerTimes(AnimationId: string): {[string]: number}
	local NormalizedAnimationId: string = NormalizeAnimationId(AnimationId)
	local Cached: {[string]: number}? = MarkerTimesCache[NormalizedAnimationId]
	if Cached then
		return Cached
	end

	local MarkerTimes: {[string]: number} = {}
	local Sequence: KeyframeSequence? = nil
	local Success: boolean, Result: any = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(NormalizedAnimationId)
	end)
	if Success and Result and Result:IsA("KeyframeSequence") then
		Sequence = Result
	else
		local NumericId: string? = string.match(NormalizedAnimationId, "%d+")
		if NumericId then
			local RetrySuccess: boolean, RetryResult: any = pcall(function()
				return KeyframeSequenceProvider:GetKeyframeSequenceAsync(NumericId)
			end)
			if RetrySuccess and RetryResult and RetryResult:IsA("KeyframeSequence") then
				Sequence = RetryResult
			end
		end
	end

	if Sequence then
		for _, Keyframe in Sequence:GetKeyframes() do
			local KeyframeTime: number = Keyframe.Time
			for _, Marker in Keyframe:GetMarkers() do
				local Existing: number? = MarkerTimes[Marker.Name]
				if Existing == nil or KeyframeTime < Existing then
					MarkerTimes[Marker.Name] = KeyframeTime
				end
			end
		end
		Sequence:Destroy()
	end

	MarkerTimesCache[NormalizedAnimationId] = MarkerTimes
	return MarkerTimes
end

local function ResolveSegmentDurations(): {[number]: number}
	local MarkerTimes: {[string]: number} = ResolveMarkerTimes(ANIMATION_ID)
	local Durations: {[number]: number} = {}

	for _, Segment in SEGMENTS do
		local StartTime: number? = MarkerTimes[Segment.StartMarker]
		local EndTime: number? = MarkerTimes[Segment.EndMarker]
		if StartTime ~= nil and EndTime ~= nil and EndTime > StartTime then
			Durations[Segment.Index] = math.max(EndTime - StartTime, DEFAULT_SEGMENT_DURATION)
		else
			Durations[Segment.Index] = DEFAULT_SEGMENT_DURATION
		end
	end

	return Durations
end

local function ResolveFallbackDurationSeconds(Track: AnimationTrack?): number
	local TrackDuration: number = FatGuySkillUtils.GetTrackDuration(Track, FALLBACK_TOTAL_FRAMES, FALLBACK_TIMELINE_FPS)
	return math.max(TrackDuration, FALLBACK_TOTAL_FRAMES / FALLBACK_TIMELINE_FPS) + TRACK_STOP_GRACE
end

local function ResolveSegmentTargets(Session: any): {[number]: SegmentTarget}?
	local QuickPortsTemplate: Instance? = ResolveQuickPortsTemplate()
	if not QuickPortsTemplate then
		return nil
	end

	local TemplatePivot: CFrame? = GetInstanceCFrame(QuickPortsTemplate)
	if not TemplatePivot then
		return nil
	end

	local Targets: {[number]: SegmentTarget} = {}
	for _, Segment in SEGMENTS do
		local TemplateTarget: Instance? = QuickPortsTemplate:FindFirstChild(Segment.TargetName, true)
		local TemplateTargetCFrame: CFrame? = GetInstanceCFrame(TemplateTarget)
		if not TemplateTargetCFrame then
			return nil
		end

		local RelativeCFrame: CFrame = TemplatePivot:ToObjectSpace(TemplateTargetCFrame)
		local WorldCFrame: CFrame = Session.Root.CFrame:ToWorldSpace(RelativeCFrame)
		Targets[Segment.Index] = {
			Position = WorldCFrame.Position,
			Forward = GlobalFunctions.ResolveDirection(WorldCFrame.LookVector, Session.Forward),
		}
	end

	return Targets
end

local function IsCurrentState(State: SkillState): boolean
	if not State.Active then
		return false
	end
	if ActiveStates[State.Player] ~= State then
		return false
	end
	return FatGuySkillUtils.IsSessionActive(State.Session)
end

local function StopState(State: SkillState): ()
	if not State.Active then
		return
	end

	State.Active = false
	FatGuySkillUtils.EndSkill(State.Session)
end

local function ResolveIncompleteSegment(State: SkillState): SegmentConfig?
	for Index = #SEGMENTS, 1, -1 do
		local Segment: SegmentConfig = SEGMENTS[Index]
		if State.HandledMarkers[Segment.StartMarker] and not State.HandledMarkers[Segment.EndMarker] then
			return Segment
		end
	end

	return nil
end

local function HasPendingScheduledMarkers(State: SkillState): boolean
	for MarkerName, _ in State.ScheduledMarkers do
		if not State.HandledMarkers[MarkerName] then
			return true
		end
	end

	return false
end

local function BeginSegmentMove(State: SkillState, SegmentIndex: number): ()
	local SegmentTarget: SegmentTarget? = State.SegmentTargets[SegmentIndex]
	if not SegmentTarget then
		return
	end

	State.MoveToken += 1
	local MoveToken: number = State.MoveToken
	local StartPosition: Vector3 = State.Session.Root.Position
	local Duration: number = math.max(State.SegmentDurations[SegmentIndex] or DEFAULT_SEGMENT_DURATION, 0.01)

	task.spawn(function()
		FatGuySkillUtils.RunHeartbeatLoop(Duration, function(): boolean
			return IsCurrentState(State) and State.MoveToken == MoveToken
		end, function(Elapsed: number): boolean
			local Alpha: number = math.clamp(Elapsed / Duration, 0, 1)
			local Position: Vector3 = StartPosition:Lerp(SegmentTarget.Position, Alpha)
			FatGuySkillUtils.SetCharacterTransform(State.Session, Position, SegmentTarget.Forward)
			return Alpha < 1
		end)

		if not IsCurrentState(State) or State.MoveToken ~= MoveToken then
			return
		end

		FatGuySkillUtils.SetCharacterTransform(State.Session, SegmentTarget.Position, SegmentTarget.Forward)
	end)
end

local function CompleteSegmentMove(State: SkillState, SegmentIndex: number): ()
	local SegmentTarget: SegmentTarget? = State.SegmentTargets[SegmentIndex]
	if not SegmentTarget then
		return
	end

	State.MoveToken += 1
	FatGuySkillUtils.SetCharacterTransform(State.Session, SegmentTarget.Position, SegmentTarget.Forward)
end

local function HandleMarker(State: SkillState, MarkerName: string): ()
	if not IsCurrentState(State) then
		return
	end
	if State.HandledMarkers[MarkerName] then
		return
	end

	State.HandledMarkers[MarkerName] = true
	FireReplicator(State, "Marker", {
		MarkerName = MarkerName,
	})

	if MarkerName == "Start1" then
		BeginSegmentMove(State, 1)
		return
	end
	if MarkerName == "Tp1" then
		CompleteSegmentMove(State, 1)
		return
	end
	if MarkerName == "Start2" then
		BeginSegmentMove(State, 2)
		return
	end
	if MarkerName == "Tp2" then
		CompleteSegmentMove(State, 2)
		return
	end
	if MarkerName == "Start3" then
		BeginSegmentMove(State, 3)
		return
	end
	if MarkerName == "Tp3" then
		CompleteSegmentMove(State, 3)
	end
end

local function ScheduleMarkerFallbacks(State: SkillState): ()
	local MarkerTimes: {[string]: number} = ResolveMarkerTimes(ANIMATION_ID)
	for _, MarkerName in MONITORED_MARKERS do
		local MarkerTime: number? = MarkerTimes[MarkerName]
		if MarkerTime == nil then
			continue
		end

		State.ScheduledMarkers[MarkerName] = true
		task.delay(MarkerTime, function()
			if not IsCurrentState(State) then
				return
			end
			if State.HandledMarkers[MarkerName] then
				return
			end
			HandleMarker(State, MarkerName)
		end)
	end
end

return function(Character: Model): ()
	local Session: any = FatGuySkillUtils.BeginSkill(Character, {
		AnchorRoot = false,
		CaptureNetworkOwner = true,
		ForcePhysicsState = false,
	})
	if not Session then
		return
	end

	local Player: Player = Session.Player
	local ExistingState: SkillState? = ActiveStates[Player]
	if ExistingState then
		StopState(ExistingState)
	end

	FatGuySkillUtils.WarmAnimations(Session.Character, {
		ANIMATION_ID,
	})

	local SegmentTargets: {[number]: SegmentTarget}? = ResolveSegmentTargets(Session)
	if not SegmentTargets then
		FatGuySkillUtils.EndSkill(Session)
		return
	end

	local Track: AnimationTrack? = FatGuySkillUtils.LoadAnimationTrack(Session.Character, ANIMATION_ID)
	if not Track then
		FatGuySkillUtils.EndSkill(Session)
		return
	end

	local Token: number = NextToken(ActiveTokens[Player])
	ActiveTokens[Player] = Token

	local State: SkillState = {
		Active = true,
		Connections = {},
		HandledMarkers = {},
		MoveToken = 0,
		Player = Player,
		ReplicatorStarted = false,
		ScheduledMarkers = {},
		Session = Session,
		SegmentDurations = ResolveSegmentDurations(),
		SegmentTargets = SegmentTargets,
		Token = Token,
		Track = Track,
		TrackStopped = false,
	}

	ActiveStates[Player] = State

	FatGuySkillUtils.RegisterCleanup(Session, function()
		State.MoveToken += 1
		GlobalFunctions.DisconnectAll(State.Connections)
		if State.Track then
			State.Track:Stop(0)
			State.Track:Destroy()
			State.Track = nil
		end
		if State.ReplicatorStarted then
			State.ReplicatorStarted = false
			FireReplicator(State, "End", nil)
		end
		if ActiveStates[Player] == State then
			ActiveStates[Player] = nil
		end
		if ActiveTokens[Player] == State.Token then
			ActiveTokens[Player] = nil
		end
	end)

	for _, MarkerName in MONITORED_MARKERS do
		TrackConnection(State, Track:GetMarkerReachedSignal(MarkerName):Connect(function()
			HandleMarker(State, MarkerName)
		end))
	end

	TrackConnection(State, Track.Stopped:Connect(function()
		State.TrackStopped = true
	end))

	TrackConnection(State, Player.CharacterRemoving:Connect(function(RemovingCharacter: Model)
		if RemovingCharacter ~= Session.Character then
			return
		end
		StopState(State)
	end))

	Track.Priority = Enum.AnimationPriority.Action
	Track.Looped = false
	Track:Play(0.02, 1, 1)

	State.ReplicatorStarted = true
	FireReplicator(State, "Start", nil)
	ScheduleMarkerFallbacks(State)

	FatGuySkillUtils.RunHeartbeatLoop(ResolveFallbackDurationSeconds(Track), function(): boolean
		return IsCurrentState(State)
	end, function(): boolean
		Session.Root.AssemblyLinearVelocity = Vector3.zero
		Session.Root.AssemblyAngularVelocity = Vector3.zero
		if State.TrackStopped then
			if HasPendingScheduledMarkers(State) then
				return true
			end

			local IncompleteSegment: SegmentConfig? = ResolveIncompleteSegment(State)
			if IncompleteSegment then
				HandleMarker(State, IncompleteSegment.EndMarker)
			end
			return false
		end
		return true
	end)

	if IsCurrentState(State) then
		StopState(State)
	end
end
