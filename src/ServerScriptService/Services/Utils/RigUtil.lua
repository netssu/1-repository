--!strict

local PhysicsService: PhysicsService = game:GetService("PhysicsService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace: Workspace = game:GetService("Workspace")

local RigUtil = {}

local LOBBY_NAME: string = "Lobby"
local ASSETS_FOLDER_NAME: string = "Assets"
local GAMEPLAY_FOLDER_NAME: string = "Gameplay"
local ANIMATIONS_FOLDER_NAME: string = "Animations"
local EMOTES_FOLDER_NAME: string = "Emotes"
local DANCE_ATTRIBUTE: string = "Dance"
local DEFAULT_COLLISION_GROUP: string = "Default"
local PLAYER_COLLISION_GROUP: string = "RigUtilPlayer"
local LOBBY_RIG_COLLISION_GROUP: string = "RigUtilLobbyRig"

local TRACK_FADE_TIME: number = 0.15
local TRACK_WEIGHT: number = 1
local TRACK_SPEED: number = 1
local DANCE_WATCHDOG_INTERVAL: number = 0.5
local TRACK_VERIFICATION_DELAY: number = 0.15
local TABLE_IDLE_NAME: string = "tableidle"
local AESINY_RIG_NAME: string = "Aesiny"
local AESINY_IDLE_ANIMATION_NAME: string = "IdleZZ"

type RigAnimationTarget = Humanoid | AnimationController

type RigState = {
	Model: Model,
	Humanoid: Humanoid?,
	AnimationController: AnimationController?,
	AnimationTarget: RigAnimationTarget,
	Animator: Animator,
	Track: AnimationTrack?,
	TrackStoppedConnection: RBXScriptConnection?,
	AttributeConnection: RBXScriptConnection?,
	AncestryConnection: RBXScriptConnection?,
	DescendantConnection: RBXScriptConnection?,
	AnimationTargetConnection: RBXScriptConnection?,
}

type PlayerState = {
	Character: Model?,
	CharacterAddedConnection: RBXScriptConnection?,
	CharacterRemovingConnection: RBXScriptConnection?,
	DescendantConnection: RBXScriptConnection?,
}

local RandomGenerator: Random = Random.new()

local ActiveLobby: Instance? = nil
local Started: boolean = false
local LobbyConnections: { RBXScriptConnection } = {}
local WorkspaceConnections: { RBXScriptConnection } = {}
local RigStates: { [Model]: RigState } = {}
local PlayerStates: { [Player]: PlayerState } = {}
local CachedEmotesFolder: Instance? = nil
local CachedAnimations: { Animation } = {}
local WatchdogToken: number = 0
local PendingDanceQueue: { Model } = {}
local PendingDanceLookup: { [Model]: boolean } = {}
local DanceQueueWorkerRunning: boolean = false

local function NormalizeName(Name: string): string
	return string.lower(string.gsub(Name, "[%s_%-%./]", ""))
end

local function DisconnectConnection(Connection: RBXScriptConnection?): ()
	if Connection then
		Connection:Disconnect()
	end
end

local function DisconnectConnectionList(ConnectionList: { RBXScriptConnection }): ()
	for _, Connection in ConnectionList do
		Connection:Disconnect()
	end
	table.clear(ConnectionList)
end

local function DisconnectTrackStoppedConnection(State: RigState): ()
	DisconnectConnection(State.TrackStoppedConnection)
	State.TrackStoppedConnection = nil
end

local function ResetDanceQueue(): ()
	table.clear(PendingDanceQueue)
	table.clear(PendingDanceLookup)
	DanceQueueWorkerRunning = false
end

local function StopTrack(State: RigState): ()
	local Track: AnimationTrack? = State.Track
	if not Track then
		DisconnectTrackStoppedConnection(State)
		return
	end

	State.Track = nil
	DisconnectTrackStoppedConnection(State)
	Track:Stop(TRACK_FADE_TIME)
	Track:Destroy()
end

local function EnsureCollisionGroupRegistered(GroupName: string): ()
	local IsRegistered: boolean = false
	local Success: boolean, Result: any = pcall(function(): boolean
		return PhysicsService:IsCollisionGroupRegistered(GroupName)
	end)
	if Success and Result == true then
		IsRegistered = true
	end
	if IsRegistered then
		return
	end

	local RegisterSuccess: boolean, RegisterError: any = pcall(function()
		PhysicsService:RegisterCollisionGroup(GroupName)
	end)
	if not RegisterSuccess then
		warn(string.format("RigUtil: failed to register collision group %s: %s", GroupName, tostring(RegisterError)))
	end
end

local function ConfigureCollisionGroups(): ()
	EnsureCollisionGroupRegistered(PLAYER_COLLISION_GROUP)
	EnsureCollisionGroupRegistered(LOBBY_RIG_COLLISION_GROUP)

	local Success: boolean, ErrorMessage: any = pcall(function()
		PhysicsService:CollisionGroupSetCollidable(PLAYER_COLLISION_GROUP, LOBBY_RIG_COLLISION_GROUP, false)
	end)
	if not Success then
		warn(string.format("RigUtil: failed to configure collision groups: %s", tostring(ErrorMessage)))
	end
end

local function SetPartCollisionGroup(Part: BasePart, GroupName: string): ()
	if Part.CollisionGroup == GroupName then
		return
	end

	Part.CollisionGroup = GroupName
end

local function ApplyCollisionGroupToModel(ModelInstance: Model, GroupName: string): ()
	for _, Descendant in ModelInstance:GetDescendants() do
		if Descendant:IsA("BasePart") then
			SetPartCollisionGroup(Descendant, GroupName)
		end
	end
end

local function IsDanceEnabled(ModelInstance: Model): boolean
	return ModelInstance:GetAttribute(DANCE_ATTRIBUTE) == true
end

local function IsInsideActiveLobby(InstanceItem: Instance): boolean
	local LobbyInstance: Instance? = ActiveLobby
	if not LobbyInstance then
		return false
	end

	return InstanceItem == LobbyInstance or InstanceItem:IsDescendantOf(LobbyInstance)
end

local function ResolveRigModelFromHumanoid(HumanoidInstance: Humanoid): Model?
	local ParentInstance: Instance? = HumanoidInstance.Parent
	if ParentInstance and ParentInstance:IsA("Model") then
		return ParentInstance
	end

	return nil
end

local function ResolveRigHumanoid(ModelInstance: Model): Humanoid?
	local DirectHumanoid: Humanoid? = ModelInstance:FindFirstChildOfClass("Humanoid")
	if DirectHumanoid then
		return DirectHumanoid
	end

	return nil
end

local function ResolveRigAnimationController(ModelInstance: Model): AnimationController?
	local DirectAnimationController: AnimationController? =
		ModelInstance:FindFirstChildWhichIsA("AnimationController", true)
	if DirectAnimationController then
		return DirectAnimationController
	end

	return nil
end

local function ResolveRigModelFromAnimationController(AnimationControllerInstance: AnimationController): Model?
	local ParentInstance: Instance? = AnimationControllerInstance.Parent
	if ParentInstance and ParentInstance:IsA("Model") then
		return ParentInstance
	end

	return nil
end

local function ResolveRigAnimationTarget(ModelInstance: Model): (RigAnimationTarget?, Humanoid?, AnimationController?)
	local HumanoidInstance: Humanoid? = ResolveRigHumanoid(ModelInstance)
	if HumanoidInstance then
		return HumanoidInstance, HumanoidInstance, nil
	end

	local AnimationControllerInstance: AnimationController? = ResolveRigAnimationController(ModelInstance)
	if AnimationControllerInstance then
		return AnimationControllerInstance, nil, AnimationControllerInstance
	end

	return nil, nil, nil
end

local function GetOrCreateAnimator(AnimationTarget: RigAnimationTarget): Animator
	local AnimatorInstance: Animator? = AnimationTarget:FindFirstChildOfClass("Animator")
	if AnimatorInstance then
		return AnimatorInstance
	end

	AnimatorInstance = Instance.new("Animator")
	AnimatorInstance.Parent = AnimationTarget
	return AnimatorInstance
end

local function ResolveAnimationsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	if not AssetsFolder then
		return nil
	end

	local GameplayFolder: Instance? = AssetsFolder:FindFirstChild(GAMEPLAY_FOLDER_NAME)
	if not GameplayFolder then
		return nil
	end

	return GameplayFolder:FindFirstChild(ANIMATIONS_FOLDER_NAME)
end

local function FindAnimationAsset(AnimationsRoot: Instance, AnimationName: string): Animation?
	local DirectAnimation: Instance? = AnimationsRoot:FindFirstChild(AnimationName, true)
	if DirectAnimation and DirectAnimation:IsA("Animation") then
		return DirectAnimation
	end

	local NormalizedAnimationName: string = NormalizeName(AnimationName)
	for _, Descendant in AnimationsRoot:GetDescendants() do
		if Descendant:IsA("Animation") and NormalizeName(Descendant.Name) == NormalizedAnimationName then
			return Descendant
		end
	end

	return nil
end

local function ResolveEmotesFolder(): Instance?
	local AnimationsFolder: Instance? = ResolveAnimationsFolder()
	if not AnimationsFolder then
		return nil
	end

	return AnimationsFolder:FindFirstChild(EMOTES_FOLDER_NAME)
end

local function GetCachedAnimations(): { Animation }
	local EmotesFolder: Instance? = ResolveEmotesFolder()
	if EmotesFolder == CachedEmotesFolder and #CachedAnimations > 0 then
		return CachedAnimations
	end

	CachedEmotesFolder = EmotesFolder
	table.clear(CachedAnimations)

	if not EmotesFolder then
		return CachedAnimations
	end

	for _, Descendant in EmotesFolder:GetDescendants() do
		if Descendant:IsA("Animation") then
			table.insert(CachedAnimations, Descendant)
		end
	end

	table.sort(CachedAnimations, function(Left: Animation, Right: Animation): boolean
		return Left.Name < Right.Name
	end)

	return CachedAnimations
end

local function GetShuffledDanceAnimations(): { Animation }
	local Animations: { Animation } = table.clone(GetCachedAnimations())
	for Index = #Animations, 2, -1 do
		local SwapIndex: number = RandomGenerator:NextInteger(1, Index)
		Animations[Index], Animations[SwapIndex] = Animations[SwapIndex], Animations[Index]
	end

	return Animations
end

local function IsAesinyTableIdleRig(ModelInstance: Model): boolean
	if NormalizeName(ModelInstance.Name) ~= NormalizeName(AESINY_RIG_NAME) then
		return false
	end

	local ParentInstance: Instance? = ModelInstance.Parent
	return ParentInstance ~= nil and NormalizeName(ParentInstance.Name) == NormalizeName(TABLE_IDLE_NAME)
end

local function GetForcedAnimationName(ModelInstance: Model): string?
	if IsAesinyTableIdleRig(ModelInstance) then
		return AESINY_IDLE_ANIMATION_NAME
	end

	return nil
end

local function ShouldAnimateRig(ModelInstance: Model): boolean
	return IsDanceEnabled(ModelInstance) or GetForcedAnimationName(ModelInstance) ~= nil
end

local function IsRigAlive(State: RigState): boolean
	local HumanoidInstance: Humanoid? = State.Humanoid
	if not HumanoidInstance then
		return true
	end

	return HumanoidInstance.Health > 0
end

local function GetPreferredAnimationsForRig(ModelInstance: Model): { Animation }
	local ForcedAnimationName: string? = GetForcedAnimationName(ModelInstance)
	local Candidates: { Animation } = {}

	if ForcedAnimationName then
		local AnimationsFolder: Instance? = ResolveAnimationsFolder()
		if AnimationsFolder then
			local ForcedAnimation: Animation? = FindAnimationAsset(AnimationsFolder, ForcedAnimationName)
			if ForcedAnimation then
				table.insert(Candidates, ForcedAnimation)
			end
		end
	end

	for _, AnimationInstance in GetShuffledDanceAnimations() do
		if not table.find(Candidates, AnimationInstance) then
			table.insert(Candidates, AnimationInstance)
		end
	end

	return Candidates
end

local function IsTrackActiveOnAnimator(AnimatorInstance: Animator, Track: AnimationTrack?): boolean
	if not Track or not Track.IsPlaying then
		return false
	end

	local Success: boolean, PlayingTracksOrError: any = pcall(function(): { AnimationTrack }
		return AnimatorInstance:GetPlayingAnimationTracks()
	end)
	if not Success or type(PlayingTracksOrError) ~= "table" then
		return Track.IsPlaying
	end

	for _, PlayingTrack in PlayingTracksOrError do
		if PlayingTrack == Track then
			return true
		end
	end

	return false
end

local CleanupRig: (Model) -> ()
local ApplyPlayerCharacterCollisionGroup: (Model) -> ()

local function DisconnectPlayerDescendantConnection(PlayerInstance: Player): ()
	local State: PlayerState? = PlayerStates[PlayerInstance]
	if not State then
		return
	end

	DisconnectConnection(State.DescendantConnection)
	State.DescendantConnection = nil
end

ApplyPlayerCharacterCollisionGroup = function(Character: Model): ()
	ApplyCollisionGroupToModel(Character, PLAYER_COLLISION_GROUP)

	local PlayerInstance: Player? = Players:GetPlayerFromCharacter(Character)
	if not PlayerInstance then
		return
	end

	local State: PlayerState? = PlayerStates[PlayerInstance]
	if not State then
		return
	end

	DisconnectPlayerDescendantConnection(PlayerInstance)
	State.Character = Character
	State.DescendantConnection = Character.DescendantAdded:Connect(function(Descendant: Instance)
		if Descendant:IsA("BasePart") then
			SetPartCollisionGroup(Descendant, PLAYER_COLLISION_GROUP)
		end
	end)
end

local QueueDancePlayback: (Model) -> ()
local StartDanceQueueWorker: () -> ()

local function PlayRandomDanceNow(State: RigState): ()
	if not ShouldAnimateRig(State.Model) then
		StopTrack(State)
		return
	end
	if not IsInsideActiveLobby(State.Model) then
		StopTrack(State)
		return
	end
	if not IsRigAlive(State) then
		StopTrack(State)
		return
	end

	local ExistingTrack: AnimationTrack? = State.Track
	if ExistingTrack and IsTrackActiveOnAnimator(State.Animator, ExistingTrack) then
		return
	end
	if ExistingTrack then
		StopTrack(State)
	end

	for _, AnimationInstance in GetPreferredAnimationsForRig(State.Model) do
		local Success: boolean, TrackOrError: any = pcall(function(): AnimationTrack
			return State.Animator:LoadAnimation(AnimationInstance)
		end)
		if not Success then
			warn(
				string.format(
					"RigUtil: failed to load dance animation for %s: %s",
					State.Model:GetFullName(),
					tostring(TrackOrError)
				)
			)
			continue
		end

		local Track: AnimationTrack = TrackOrError :: AnimationTrack
		Track.Looped = true
		Track.Priority = Enum.AnimationPriority.Action4

		local StartedTrack: boolean, PlayError: any = pcall(function()
			Track:Play(TRACK_FADE_TIME, TRACK_WEIGHT, TRACK_SPEED)
		end)
		if not StartedTrack then
			warn(
				string.format(
					"RigUtil: failed to play dance animation for %s: %s",
					State.Model:GetFullName(),
					tostring(PlayError)
				)
			)
			Track:Destroy()
			continue
		end

		State.Track = Track
		DisconnectTrackStoppedConnection(State)
		State.TrackStoppedConnection = Track.Stopped:Connect(function()
			if State.Track == Track then
				State.Track = nil
			end
			DisconnectTrackStoppedConnection(State)
			if not Started then
				return
			end
			if not ShouldAnimateRig(State.Model) then
				return
			end
			if not IsInsideActiveLobby(State.Model) then
				return
			end
			task.defer(function()
				if Started and ShouldAnimateRig(State.Model) and IsInsideActiveLobby(State.Model) then
					QueueDancePlayback(State.Model)
				end
			end)
		end)

		task.delay(TRACK_VERIFICATION_DELAY, function()
			if not Started then
				return
			end
			if RigStates[State.Model] ~= State then
				return
			end
			if State.Track ~= Track then
				return
			end
			if not ShouldAnimateRig(State.Model) or not IsInsideActiveLobby(State.Model) then
				return
			end
			if IsTrackActiveOnAnimator(State.Animator, Track) then
				return
			end

			StopTrack(State)
			QueueDancePlayback(State.Model)
		end)

		return
	end
end

StartDanceQueueWorker = function(): ()
	if DanceQueueWorkerRunning then
		return
	end

	DanceQueueWorkerRunning = true
	task.spawn(function()
		while Started do
			local NextModel: Model? = table.remove(PendingDanceQueue, 1)
			if not NextModel then
				break
			end

			PendingDanceLookup[NextModel] = nil
			local State: RigState? = RigStates[NextModel]
			if
				State
				and State.Model.Parent ~= nil
				and IsInsideActiveLobby(State.Model)
				and ShouldAnimateRig(State.Model)
				and IsRigAlive(State)
			then
				PlayRandomDanceNow(State)
			end

			task.wait()
		end

		DanceQueueWorkerRunning = false
		if Started and #PendingDanceQueue > 0 then
			StartDanceQueueWorker()
		end
	end)
end

QueueDancePlayback = function(ModelInstance: Model): ()
	if PendingDanceLookup[ModelInstance] then
		return
	end

	PendingDanceLookup[ModelInstance] = true
	table.insert(PendingDanceQueue, ModelInstance)
	StartDanceQueueWorker()
end

local function RefreshRig(ModelInstance: Model): ()
	if not IsInsideActiveLobby(ModelInstance) then
		CleanupRig(ModelInstance)
		return
	end

	local AnimationTarget, ResolvedHumanoid, ResolvedAnimationController = ResolveRigAnimationTarget(ModelInstance)
	if not AnimationTarget then
		CleanupRig(ModelInstance)
		return
	end

	local State: RigState? = RigStates[ModelInstance]
	local AnimatorInstance: Animator = GetOrCreateAnimator(AnimationTarget)
	if not State then
		State = {
			Model = ModelInstance,
			Humanoid = ResolvedHumanoid,
			AnimationController = ResolvedAnimationController,
			AnimationTarget = AnimationTarget,
			Animator = AnimatorInstance,
			Track = nil,
			TrackStoppedConnection = nil,
			AttributeConnection = nil,
			AncestryConnection = nil,
			DescendantConnection = nil,
			AnimationTargetConnection = nil,
		}
		RigStates[ModelInstance] = State
	end

	local AnimationTargetChanged: boolean = State.AnimationTarget ~= AnimationTarget
	State.Model = ModelInstance
	State.Humanoid = ResolvedHumanoid
	State.AnimationController = ResolvedAnimationController
	State.AnimationTarget = AnimationTarget
	State.Animator = AnimatorInstance
	ApplyCollisionGroupToModel(ModelInstance, LOBBY_RIG_COLLISION_GROUP)

	if not State.AttributeConnection then
		State.AttributeConnection = ModelInstance:GetAttributeChangedSignal(DANCE_ATTRIBUTE):Connect(function()
			RefreshRig(ModelInstance)
		end)
	end

	if not State.AncestryConnection then
		State.AncestryConnection = ModelInstance.AncestryChanged:Connect(function()
			if not IsInsideActiveLobby(ModelInstance) then
				CleanupRig(ModelInstance)
				return
			end
			RefreshRig(ModelInstance)
		end)
	end

	if not State.DescendantConnection then
		State.DescendantConnection = ModelInstance.DescendantAdded:Connect(function(Descendant: Instance)
			if Descendant:IsA("BasePart") then
				SetPartCollisionGroup(Descendant, LOBBY_RIG_COLLISION_GROUP)
			end
		end)
	end

	if AnimationTargetChanged then
		StopTrack(State)
		DisconnectConnection(State.AnimationTargetConnection)
		State.AnimationTargetConnection = nil
	end

	if not State.AnimationTargetConnection then
		State.AnimationTargetConnection = AnimationTarget.AncestryChanged:Connect(function()
			if not AnimationTarget.Parent then
				RefreshRig(ModelInstance)
				return
			end
			if not IsInsideActiveLobby(ModelInstance) then
				CleanupRig(ModelInstance)
			end
		end)
	end

	if ShouldAnimateRig(ModelInstance) then
		QueueDancePlayback(ModelInstance)
		return
	end

	StopTrack(State)
end

CleanupRig = function(ModelInstance: Model): ()
	local State: RigState? = RigStates[ModelInstance]
	if not State then
		return
	end

	RigStates[ModelInstance] = nil
	PendingDanceLookup[ModelInstance] = nil
	local CollisionGroup: string = DEFAULT_COLLISION_GROUP
	if IsInsideActiveLobby(ModelInstance) and IsAesinyTableIdleRig(ModelInstance) then
		CollisionGroup = LOBBY_RIG_COLLISION_GROUP
	end
	ApplyCollisionGroupToModel(ModelInstance, CollisionGroup)
	StopTrack(State)
	DisconnectConnection(State.AttributeConnection)
	DisconnectConnection(State.AncestryConnection)
	DisconnectConnection(State.DescendantConnection)
	DisconnectConnection(State.AnimationTargetConnection)
end

local function CleanupAllRigs(): ()
	for ModelInstance, _ in RigStates do
		CleanupRig(ModelInstance)
	end
end

local function RefreshAesinyAncestor(Source: Instance): ()
	local AesinyModel: Model? = Source:FindFirstAncestor(AESINY_RIG_NAME)
	if not AesinyModel or not AesinyModel:IsA("Model") then
		return
	end
	if not IsAesinyTableIdleRig(AesinyModel) then
		return
	end

	ApplyCollisionGroupToModel(AesinyModel, LOBBY_RIG_COLLISION_GROUP)
	task.defer(function()
		RefreshRig(AesinyModel)
	end)
end

local function RegisterRigFromHumanoid(HumanoidInstance: Humanoid): ()
	local ModelInstance: Model? = ResolveRigModelFromHumanoid(HumanoidInstance)
	if not ModelInstance then
		return
	end
	if not IsInsideActiveLobby(ModelInstance) then
		return
	end

	RefreshRig(ModelInstance)
end

local function RegisterRigFromAnimationController(AnimationControllerInstance: AnimationController): ()
	local ModelInstance: Model? = ResolveRigModelFromAnimationController(AnimationControllerInstance)
	if not ModelInstance then
		return
	end
	if not IsInsideActiveLobby(ModelInstance) then
		return
	end

	RefreshRig(ModelInstance)
end

local function ScanLobby(LobbyInstance: Instance): ()
	if LobbyInstance:IsA("Model") then
		local LobbyHumanoid: Humanoid? = LobbyInstance:FindFirstChildOfClass("Humanoid")
		local LobbyAnimationController: AnimationController? =
			LobbyInstance:FindFirstChildOfClass("AnimationController")
		if LobbyHumanoid or LobbyAnimationController then
			RefreshRig(LobbyInstance)
		end
	end

	for _, Descendant in LobbyInstance:GetDescendants() do
		if Descendant:IsA("Humanoid") then
			RegisterRigFromHumanoid(Descendant)
		elseif Descendant:IsA("AnimationController") then
			RegisterRigFromAnimationController(Descendant)
		end
	end

	local TableIdleInstance: Instance? = LobbyInstance:FindFirstChild(TABLE_IDLE_NAME)
	if TableIdleInstance then
		local AesinyInstance: Instance? = TableIdleInstance:FindFirstChild(AESINY_RIG_NAME)
		if AesinyInstance and AesinyInstance:IsA("Model") then
			ApplyCollisionGroupToModel(AesinyInstance, LOBBY_RIG_COLLISION_GROUP)
			RefreshRig(AesinyInstance)
		end
	end
end

local function DetachLobby(): ()
	DisconnectConnectionList(LobbyConnections)
	CleanupAllRigs()
	ResetDanceQueue()
	ActiveLobby = nil
end

local function AttachLobby(LobbyInstance: Instance): ()
	if ActiveLobby == LobbyInstance then
		return
	end

	DetachLobby()
	ActiveLobby = LobbyInstance

	table.insert(
		LobbyConnections,
		LobbyInstance.DescendantAdded:Connect(function(Descendant: Instance)
			if Descendant:IsA("Humanoid") then
				RegisterRigFromHumanoid(Descendant)
				RefreshAesinyAncestor(Descendant)
				return
			end
			if Descendant:IsA("AnimationController") then
				RegisterRigFromAnimationController(Descendant)
				RefreshAesinyAncestor(Descendant)
				return
			end
			if Descendant:IsA("Model") and IsAesinyTableIdleRig(Descendant) then
				ApplyCollisionGroupToModel(Descendant, LOBBY_RIG_COLLISION_GROUP)
				task.defer(function()
					RefreshRig(Descendant)
				end)
				return
			end
			if Descendant:IsA("BasePart") then
				local ParentModel: Model? = Descendant:FindFirstAncestor(AESINY_RIG_NAME)
				if ParentModel and ParentModel:IsA("Model") and IsAesinyTableIdleRig(ParentModel) then
					SetPartCollisionGroup(Descendant, LOBBY_RIG_COLLISION_GROUP)
				end
			end
		end)
	)

	table.insert(
		LobbyConnections,
		LobbyInstance.DescendantRemoving:Connect(function(Descendant: Instance)
			if Descendant:IsA("Humanoid") then
				local ModelInstance: Model? = ResolveRigModelFromHumanoid(Descendant)
				if ModelInstance then
					task.defer(function()
						RefreshRig(ModelInstance)
					end)
				end
				RefreshAesinyAncestor(Descendant)
				return
			end
			if Descendant:IsA("AnimationController") then
				local ModelInstance: Model? = ResolveRigModelFromAnimationController(Descendant)
				if ModelInstance then
					task.defer(function()
						RefreshRig(ModelInstance)
					end)
				end
				RefreshAesinyAncestor(Descendant)
				return
			end

			if Descendant:IsA("Model") and RigStates[Descendant] then
				CleanupRig(Descendant)
			end
		end)
	)

	ScanLobby(LobbyInstance)
end

local function HandlePlayerCharacterRemoving(PlayerInstance: Player, Character: Model): ()
	local State: PlayerState? = PlayerStates[PlayerInstance]
	if not State then
		return
	end
	if State.Character ~= Character then
		return
	end

	DisconnectPlayerDescendantConnection(PlayerInstance)
	State.Character = nil
end

local function HandlePlayerAdded(PlayerInstance: Player): ()
	local State: PlayerState = {
		Character = nil,
		CharacterAddedConnection = nil,
		CharacterRemovingConnection = nil,
		DescendantConnection = nil,
	}
	PlayerStates[PlayerInstance] = State

	State.CharacterAddedConnection = PlayerInstance.CharacterAdded:Connect(function(Character: Model)
		ApplyPlayerCharacterCollisionGroup(Character)
	end)
	State.CharacterRemovingConnection = PlayerInstance.CharacterRemoving:Connect(function(Character: Model)
		HandlePlayerCharacterRemoving(PlayerInstance, Character)
	end)

	local Character: Model? = PlayerInstance.Character
	if Character then
		ApplyPlayerCharacterCollisionGroup(Character)
	end
end

local function HandlePlayerRemoving(PlayerInstance: Player): ()
	local State: PlayerState? = PlayerStates[PlayerInstance]
	if not State then
		return
	end

	if State.Character then
		ApplyCollisionGroupToModel(State.Character, DEFAULT_COLLISION_GROUP)
	end
	DisconnectConnection(State.CharacterAddedConnection)
	DisconnectConnection(State.CharacterRemovingConnection)
	DisconnectConnection(State.DescendantConnection)
	PlayerStates[PlayerInstance] = nil
end

local function CleanupPlayers(): ()
	for PlayerInstance, State in PlayerStates do
		if State.Character then
			ApplyCollisionGroupToModel(State.Character, DEFAULT_COLLISION_GROUP)
		end
		DisconnectConnection(State.CharacterAddedConnection)
		DisconnectConnection(State.CharacterRemovingConnection)
		DisconnectConnection(State.DescendantConnection)
		PlayerStates[PlayerInstance] = nil
	end
end

local function HandleWorkspaceChildAdded(Child: Instance): ()
	if Child.Name ~= LOBBY_NAME then
		return
	end

	AttachLobby(Child)
end

local function HandleWorkspaceChildRemoved(Child: Instance): ()
	if Child ~= ActiveLobby then
		return
	end

	DetachLobby()
end

local function StartDanceWatchdog(): ()
	WatchdogToken += 1
	local CurrentToken: number = WatchdogToken

	task.spawn(function()
		while Started and WatchdogToken == CurrentToken do
			for ModelInstance, State in RigStates do
				if not ModelInstance.Parent then
					CleanupRig(ModelInstance)
					continue
				end
				if not ShouldAnimateRig(ModelInstance) then
					if State.Track then
						StopTrack(State)
					end
					continue
				end
				if not IsInsideActiveLobby(ModelInstance) then
					CleanupRig(ModelInstance)
					continue
				end
				if not IsRigAlive(State) then
					StopTrack(State)
					continue
				end
				if not IsTrackActiveOnAnimator(State.Animator, State.Track) then
					QueueDancePlayback(ModelInstance)
				end
			end

			task.wait(DANCE_WATCHDOG_INTERVAL)
		end
	end)
end

function RigUtil.Start(): ()
	if Started then
		return
	end
	Started = true

	ConfigureCollisionGroups()

	local LobbyInstance: Instance? = Workspace:FindFirstChild(LOBBY_NAME)
	if LobbyInstance then
		AttachLobby(LobbyInstance)
	end

	for _, PlayerInstance in Players:GetPlayers() do
		HandlePlayerAdded(PlayerInstance)
	end

	StartDanceWatchdog()

	table.insert(WorkspaceConnections, Players.PlayerAdded:Connect(HandlePlayerAdded))
	table.insert(WorkspaceConnections, Players.PlayerRemoving:Connect(HandlePlayerRemoving))
	table.insert(WorkspaceConnections, Workspace.ChildAdded:Connect(HandleWorkspaceChildAdded))
	table.insert(WorkspaceConnections, Workspace.ChildRemoved:Connect(HandleWorkspaceChildRemoved))
end

function RigUtil.Stop(): ()
	if not Started then
		return
	end
	Started = false
	WatchdogToken += 1
	ResetDanceQueue()

	DetachLobby()
	CleanupPlayers()
	DisconnectConnectionList(WorkspaceConnections)
end

return RigUtil
