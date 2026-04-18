
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local FTConfig = require(ReplicatedStorage.Modules.Game.Config)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)
local PlayerIdentity = require(ReplicatedStorage.Modules.Game.PlayerIdentity)
local FlowBuffs = require(ReplicatedStorage.Modules.Game.FlowBuffs)
local CutsceneRigUtils = require(ReplicatedStorage.Modules.Game.Skills.VFX.Client.Init.CutsceneRigUtils)

local FTPlayerService = {}
local SELECTION_ACTIVATION_INITIAL_DELAY = 0.15
local SELECTION_ACTIVATION_RETRY_INTERVAL = 0.2
local SELECTION_ACTIVATION_TIMEOUT = 12
local ATTR_MATCH_CUTSCENE_LOCKED = "FTMatchCutsceneLocked"
local PLAY_SELECTION_ZONE_PADDING = Vector3.new(1.5, 6, 1.5)
local LOBBY_STATE_PADDING = Vector3.new(6, 8, 6)
local LOBBY_SPAWN_ENFORCE_DURATION = 30
local LOBBY_SPAWN_ENFORCE_INTERVAL = 0.15
local LOBBY_SPAWN_MAX_OFFSET = 32
local INITIAL_SELECTION_GUARD_DURATION = 1.0
local COSMETIC_ACCESSORY_ATTRIBUTE = "IsCosmetic"
local MATCH_ACTIVE_ATTRIBUTE = MatchPlayerUtils.GetMatchActiveAttributeName()

--\\ TYPES \\ -- TR
type PlayerData = {
        Team: number?,
        Position: string?,
        ActiveInMatch: boolean?,
        PendingLobbyRespawn: boolean?,
        InitialSpawnHandled: boolean?,
        SelectionUnlockedAt: number?,
        AnimationTrack: AnimationTrack?,
        OriginalOutfit: {
                hadShirt: boolean,
                shirtTemplate: string,
                hadPants: boolean,
                pantsTemplate: string,
        }?,
        TeamHeadClone: BasePart?,
        MeshConn: RBXScriptConnection?,
        AccessoryCleanupConn: RBXScriptConnection?,
        AccessoryCleanupStateConns: {RBXScriptConnection}?,
}

--\\ MODULE STATE \\ -- TR
local DEBUG_OUTFIT: boolean = true
local DEBUG_POSITION_SPAWN: boolean = false
local PlayerDataStore: {[Player]: PlayerData} = {}
local MatchEnabledInstance: BoolValue? = nil
local MatchFolder: Folder? = nil
local PendingSelectionActivationTokens: {[Player]: number} = {}
local ActiveLobbySpawnTokens: {[Player]: number} = {}
local CachedGameService: any = nil
local GameServiceResolved: boolean = false
local CancelPendingSelectionActivation: (Player) -> ()
local ScheduleSelectionActivation: (Player) -> ()
local NotifyGameServiceOfSelection: (Player) -> ()

--\\ PRIVATE FUNCTIONS \\ -- TR
local function GetMatchFolder(): Folder?
        if MatchFolder and MatchFolder.Parent then return MatchFolder end

        local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
        if not GameStateFolder then return nil end

        MatchFolder = GameStateFolder:FindFirstChild("Match") :: Folder?
        return MatchFolder
end

local function GetMatchEnabled(): boolean
        if not MatchEnabledInstance then
                local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
                if GameStateFolder then
                        MatchEnabledInstance = GameStateFolder:FindFirstChild("MatchEnabled") :: BoolValue?
                end
        end
        return MatchEnabledInstance and MatchEnabledInstance.Value or false
end

local function GetLobbySpawnCFrame(): CFrame?
	local Lobby = Workspace:FindFirstChild("Lobby")
	local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
	if spawnLocation and spawnLocation:IsA("BasePart") then
		return spawnLocation.CFrame
	end

	if not Lobby then
		return nil
	end

	local spawn = Lobby:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame
	end
	if spawn and spawn:IsA("Model") then
		local primary = spawn.PrimaryPart or spawn:FindFirstChildWhichIsA("BasePart")
		if primary then
			return primary.CFrame
		end
	end

	local fallback = Lobby:FindFirstChildWhichIsA("SpawnLocation", true)
	if fallback then
		return fallback.CFrame
	end

	return nil
end

local function IsCountdownActive(): boolean
        local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
        if not GameStateFolder then
                return false
        end
        local CountdownActive = GameStateFolder:FindFirstChild("CountdownActive") :: BoolValue?
        return CountdownActive and CountdownActive.Value or false
end

local function IsMatchStarted(): boolean
        local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
        if not GameStateFolder then
                return false
        end
        local MatchStarted = GameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
        return MatchStarted and MatchStarted.Value or false
end

local function GetGameService(): any
	if GameServiceResolved then
		return CachedGameService
	end

	GameServiceResolved = true
	local GameServiceModule = script.Parent:FindFirstChild("GameService")
	if not GameServiceModule or not GameServiceModule:IsA("ModuleScript") then
		return nil
	end

	local Success, Result = pcall(require, GameServiceModule)
	if not Success then
		warn(string.format("FTPlayerService: failed to resolve GameService: %s", tostring(Result)))
		return nil
	end

	CachedGameService = Result
	return CachedGameService
end

local function DebugSpawn(message: string): ()
	if not DEBUG_POSITION_SPAWN then return end
	print("[DEBUG][FTPlayerService][Spawn] " .. message)
end

local function SetPlayerActiveState(Player: Player, Active: boolean): ()
	local Data = PlayerDataStore[Player]
	if Data then
		Data.ActiveInMatch = Active
	end
	MatchPlayerUtils.SetPlayerActive(Player, Active)
end

local function GetPlaySelectionZonePart(): BasePart?
	local Lobby = Workspace:FindFirstChild("Lobby")
	local Zones = Lobby and Lobby:FindFirstChild("Zones")
	local UI = Zones and Zones:FindFirstChild("UI")
	local PlayPart = UI and UI:FindFirstChild("Play")
	if PlayPart and PlayPart:IsA("BasePart") then
		return PlayPart
	end

	local FallbackPart = Lobby and Lobby:FindFirstChild("Play", true)
	if FallbackPart and FallbackPart:IsA("BasePart") then
		return FallbackPart
	end

	return nil
end

local function GetInstanceBounds(Target: Instance): (CFrame?, Vector3?)
	if Target:IsA("BasePart") then
		return Target.CFrame, Target.Size
	end

	if Target:IsA("Model") then
		return Target:GetBoundingBox()
	end

	local MinBound: Vector3? = nil
	local MaxBound: Vector3? = nil

	for _, Descendant in Target:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		local DescendantCFrame = Descendant.CFrame
		local HalfSize = Descendant.Size * 0.5
		local Corners = {
			DescendantCFrame:PointToWorldSpace(Vector3.new(HalfSize.X, HalfSize.Y, HalfSize.Z)),
			DescendantCFrame:PointToWorldSpace(Vector3.new(HalfSize.X, HalfSize.Y, -HalfSize.Z)),
			DescendantCFrame:PointToWorldSpace(Vector3.new(HalfSize.X, -HalfSize.Y, HalfSize.Z)),
			DescendantCFrame:PointToWorldSpace(Vector3.new(HalfSize.X, -HalfSize.Y, -HalfSize.Z)),
			DescendantCFrame:PointToWorldSpace(Vector3.new(-HalfSize.X, HalfSize.Y, HalfSize.Z)),
			DescendantCFrame:PointToWorldSpace(Vector3.new(-HalfSize.X, HalfSize.Y, -HalfSize.Z)),
			DescendantCFrame:PointToWorldSpace(Vector3.new(-HalfSize.X, -HalfSize.Y, HalfSize.Z)),
			DescendantCFrame:PointToWorldSpace(Vector3.new(-HalfSize.X, -HalfSize.Y, -HalfSize.Z)),
		}

		for _, Corner in Corners do
			if not MinBound then
				MinBound = Corner
				MaxBound = Corner
			else
				MinBound = Vector3.new(
					math.min(MinBound.X, Corner.X),
					math.min(MinBound.Y, Corner.Y),
					math.min(MinBound.Z, Corner.Z)
				)
				MaxBound = Vector3.new(
					math.max(MaxBound.X, Corner.X),
					math.max(MaxBound.Y, Corner.Y),
					math.max(MaxBound.Z, Corner.Z)
				)
			end
		end
	end

	if not MinBound or not MaxBound then
		return nil, nil
	end

	return CFrame.new((MinBound + MaxBound) * 0.5), MaxBound - MinBound
end

local function IsPointInsideBounds(Point: Vector3, BoundsCFrame: CFrame, BoundsSize: Vector3, Padding: Vector3?): boolean
	local Extra = Padding or Vector3.zero
	local LocalPosition = BoundsCFrame:PointToObjectSpace(Point)
	local HalfSize = (BoundsSize * 0.5) + Extra
	return math.abs(LocalPosition.X) <= HalfSize.X
		and math.abs(LocalPosition.Y) <= HalfSize.Y
		and math.abs(LocalPosition.Z) <= HalfSize.Z
end

local function IsPositionInsidePart(Part: BasePart, Position: Vector3, Padding: Vector3?): boolean
	return IsPointInsideBounds(Position, Part.CFrame, Part.Size, Padding)
end

local function IsCharacterInsideLobby(Character: Model): boolean?
	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		return nil
	end

	local Lobby = Workspace:FindFirstChild("Lobby")
	if not Lobby then
		return nil
	end

	local BoundsCFrame, BoundsSize = GetInstanceBounds(Lobby)
	if not BoundsCFrame or not BoundsSize then
		return nil
	end

	return IsPointInsideBounds(Root.Position, BoundsCFrame, BoundsSize, LOBBY_STATE_PADDING)
end

local function ShouldMoveCharacterToLobby(Character: Model): boolean
	local InLobby = IsCharacterInsideLobby(Character)
	if InLobby ~= nil then
		return InLobby == false
	end

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local LobbySpawnCFrame = GetLobbySpawnCFrame()
	if Root and LobbySpawnCFrame then
		local LobbyPosition = LobbySpawnCFrame.Position
		local DistanceFromLobby = (Root.Position - LobbyPosition).Magnitude
		return DistanceFromLobby > LOBBY_SPAWN_MAX_OFFSET or Root.Position.Y > (LobbyPosition.Y + 80)
	end

	return true
end

local function IsPlayerInsidePlaySelectionZone(Player: Player): boolean
	local PlayPart = GetPlaySelectionZonePart()
	if not PlayPart then
		return true
	end

	local Character = Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		return false
	end

	return IsPositionInsidePart(PlayPart, Root.Position, PLAY_SELECTION_ZONE_PADDING)
end

local function IsPlayerAllowedOnField(Player: Player): boolean
	return MatchPlayerUtils.IsPlayerActive(Player) and (IsCountdownActive() or IsMatchStarted())
end

local function CancelLobbySpawnEnforcement(Player: Player): ()
	ActiveLobbySpawnTokens[Player] = (ActiveLobbySpawnTokens[Player] or 0) + 1
end

local function IsPositionOccupied(TeamNumber: number, Position: string): boolean
        local Folder = GetMatchFolder()
        if not Folder then return false end

        local TeamFolder = Folder:FindFirstChild("Team" .. TeamNumber)
        if not TeamFolder then return false end

        local PositionValue = TeamFolder:FindFirstChild(Position) :: IntValue?
        if not PositionValue then return false end

        return PositionValue.Value ~= 0
end

local function GetPositionOccupant(TeamNumber: number, Position: string): number
        local Folder = GetMatchFolder()
        if not Folder then return 0 end

        local TeamFolder = Folder:FindFirstChild("Team" .. TeamNumber)
        if not TeamFolder then return 0 end

        local PositionValue = TeamFolder:FindFirstChild(Position) :: IntValue?
        if not PositionValue then return 0 end

        return PositionValue.Value
end

local function SetPositionOccupant(TeamNumber: number, Position: string, UserId: number): ()
	local Folder = GetMatchFolder()
	if not Folder then return end

        local TeamFolder = Folder:FindFirstChild("Team" .. TeamNumber)
        if not TeamFolder then return end

        local PositionValue = TeamFolder:FindFirstChild(Position) :: IntValue?
        if not PositionValue then return end

	PositionValue.Value = UserId
end

local function GetTeamModel(TeamNumber: number): Instance?
        local Assets = ReplicatedStorage:FindFirstChild("Assets")
        local Gameplay = Assets and Assets:FindFirstChild("Gameplay")
        local Modelo = Gameplay and Gameplay:FindFirstChild("Modelo")
        return Modelo and Modelo:FindFirstChild("Team" .. TeamNumber)
end

local function ApplyTeamAppearance(Player: Player, TeamNumber: number): ()
        local Data = PlayerDataStore[Player]
        if not Data then return end
        local Character = Player.Character
        if not Character then return end

        local TeamModel = GetTeamModel(TeamNumber)

        if not Data.OriginalOutfit then
                local originalShirt = Character:FindFirstChildOfClass("Shirt")
                local originalPants = Character:FindFirstChildOfClass("Pants")
                Data.OriginalOutfit = {
                        hadShirt = originalShirt ~= nil,
                        shirtTemplate = if originalShirt then originalShirt.ShirtTemplate else "",
                        hadPants = originalPants ~= nil,
                        pantsTemplate = if originalPants then originalPants.PantsTemplate else "",
                }
        end

        local teamShirt = TeamModel:FindFirstChildOfClass("Shirt") :: Shirt?
        if teamShirt then
                local shirt = Character:FindFirstChildOfClass("Shirt")
                if not shirt then
                        shirt = Instance.new("Shirt")
                        shirt.Parent = Character
                end
                shirt.ShirtTemplate = teamShirt.ShirtTemplate
        end

        local teamPants = TeamModel:FindFirstChildOfClass("Pants") :: Pants?
        if teamPants then
                local pants = Character:FindFirstChildOfClass("Pants")
                if not pants then
                        pants = Instance.new("Pants")
                        pants.Parent = Character
                end
                pants.PantsTemplate = teamPants.PantsTemplate
        end

        local rawTeamHead = TeamModel:FindFirstChild("Head")
        local teamHead: BasePart? = nil
        if rawTeamHead then
                if rawTeamHead:IsA("BasePart") then
                        teamHead = rawTeamHead
                elseif rawTeamHead:IsA("Model") then
                        teamHead = rawTeamHead.PrimaryPart or rawTeamHead:FindFirstChildWhichIsA("BasePart")
                end
        end
        local characterHead = Character:FindFirstChild("Head") :: BasePart?
        if not characterHead then
                characterHead = Character:WaitForChild("Head", 2) :: BasePart?
        end
        if teamHead and teamHead:IsA("BasePart") and characterHead then
                if Data.TeamHeadClone and Data.TeamHeadClone.Parent then
                        Data.TeamHeadClone:Destroy()
                        Data.TeamHeadClone = nil
                end
                local headClone = teamHead:Clone()
                headClone.Name = "Capacete"
                headClone.Anchored = false
                headClone.CanCollide = false
                headClone.Massless = true
                headClone.Parent = Character
                headClone.CFrame = characterHead.CFrame

                CutsceneRigUtils.AttachPartToHeadWithMotor6D(characterHead, headClone)
                headClone.CFrame = characterHead.CFrame
                Data.TeamHeadClone = headClone
        end
end

local function RestorePlayerAppearance(Player: Player): ()
        local Data = PlayerDataStore[Player]
        if not Data then return end
        local Character = Player.Character
        if not Character then return end

        if Data.TeamHeadClone then
                if Data.TeamHeadClone.Parent then
                        Data.TeamHeadClone:Destroy()
                end
                Data.TeamHeadClone = nil
        end

        local outfit = Data.OriginalOutfit
        if outfit then
                local shirt = Character:FindFirstChildOfClass("Shirt")
                if outfit.hadShirt then
                        if not shirt then
                                shirt = Instance.new("Shirt")
                                shirt.Parent = Character
                        end
                        shirt.ShirtTemplate = outfit.shirtTemplate
                else
                        if shirt then
                                shirt:Destroy()
                        end
                end

                local pants = Character:FindFirstChildOfClass("Pants")
                if outfit.hadPants then
                        if not pants then
                                pants = Instance.new("Pants")
                                pants.Parent = Character
                        end
                        pants.PantsTemplate = outfit.pantsTemplate
                else
                        if pants then
                                pants:Destroy()
                        end
                end
        end

end

local function ClearPlayerPosition(Player: Player): ()
	local Data = PlayerDataStore[Player]
	if not Data then return end

	CancelPendingSelectionActivation(Player)

        if Data.AnimationTrack then
                Data.AnimationTrack:Stop()
                Data.AnimationTrack = nil
        end

	if not Data.Team or not Data.Position then return end

	local CurrentOccupant = GetPositionOccupant(Data.Team, Data.Position)
	local playerId = PlayerIdentity.GetIdValue(Player)
	if CurrentOccupant == playerId then
		SetPositionOccupant(Data.Team, Data.Position, 0)
	end

        Data.ActiveInMatch = false
	SetPlayerActiveState(Player, false)
        Data.Team = nil
        Data.Position = nil
end

local function RemoveCharacterMeshes(character: Model): ()
	for _, child in character:GetChildren() do
		if child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("CharacterMesh") then
			descendant:Destroy()
		end
	end
end

local function BindCharacterMeshCleanup(player: Player, character: Model): ()
	local data = PlayerDataStore[player]
	if data and data.MeshConn then
		data.MeshConn:Disconnect()
		data.MeshConn = nil
	end

	RemoveCharacterMeshes(character)
	local conn = character.ChildAdded:Connect(function(child)
		if child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end)
	if data then
		data.MeshConn = conn
	end
end

local function IsCharacterAccessoryInstance(InstanceItem: Instance): boolean
	return InstanceItem:IsA("Accessory") or InstanceItem:IsA("Hat")
end

local function ShouldKeepCharacterAccessory(AccessoryInstance: Instance): boolean
	return AccessoryInstance:GetAttribute(COSMETIC_ACCESSORY_ATTRIBUTE) == true
		or CutsceneRigUtils.IsHairAccessory(AccessoryInstance)
end

local function RemoveUnexpectedCharacterAccessory(Character: Model, AccessoryInstance: Instance): ()
	if AccessoryInstance.Parent ~= Character then
		return
	end
	if ShouldKeepCharacterAccessory(AccessoryInstance) then
		return
	end

	AccessoryInstance:Destroy()
end

local function SetCharacterAccessoryCleanupEnabled(Player: Player, Character: Model, Enabled: boolean): ()
	local Data = PlayerDataStore[Player]
	if Data and Data.AccessoryCleanupConn then
		Data.AccessoryCleanupConn:Disconnect()
		Data.AccessoryCleanupConn = nil
	end

	if not Enabled then
		return
	end

	for _, Child in Character:GetChildren() do
		if not IsCharacterAccessoryInstance(Child) then
			continue
		end

		RemoveUnexpectedCharacterAccessory(Character, Child)
	end

	local Connection: RBXScriptConnection = Character.ChildAdded:Connect(function(Child: Instance): ()
		if not IsCharacterAccessoryInstance(Child) then
			return
		end

		RemoveUnexpectedCharacterAccessory(Character, Child)
	end)

	if Data then
		Data.AccessoryCleanupConn = Connection
	end
end

local function DisconnectAccessoryCleanupStateConnections(Data: PlayerData?): ()
	if not Data or not Data.AccessoryCleanupStateConns then
		return
	end

	for _, Connection in Data.AccessoryCleanupStateConns do
		Connection:Disconnect()
	end

	Data.AccessoryCleanupStateConns = nil
end

local function BindCharacterAccessoryCleanup(Player: Player, Character: Model): ()
	local Data = PlayerDataStore[Player]
	DisconnectAccessoryCleanupStateConnections(Data)

	local function RefreshAccessoryCleanup(): ()
		if Player.Character ~= Character then
			SetCharacterAccessoryCleanupEnabled(Player, Character, false)
			return
		end

		SetCharacterAccessoryCleanupEnabled(Player, Character, IsPlayerAllowedOnField(Player))
	end

	RefreshAccessoryCleanup()

	local Connections: {RBXScriptConnection} = {}
	table.insert(Connections, Player:GetAttributeChangedSignal(MATCH_ACTIVE_ATTRIBUTE):Connect(function(): ()
		RefreshAccessoryCleanup()
	end))

	local GameStateFolder: Instance? = ReplicatedStorage:FindFirstChild("FTGameState")
	if GameStateFolder then
		local CountdownActive: Instance? = GameStateFolder:FindFirstChild("CountdownActive")
		if CountdownActive and CountdownActive:IsA("BoolValue") then
			table.insert(Connections, CountdownActive.Changed:Connect(function(): ()
				RefreshAccessoryCleanup()
			end))
		end

		local MatchStarted: Instance? = GameStateFolder:FindFirstChild("MatchStarted")
		if MatchStarted and MatchStarted:IsA("BoolValue") then
			table.insert(Connections, MatchStarted.Changed:Connect(function(): ()
				RefreshAccessoryCleanup()
			end))
		end
	end

	if Data then
		Data.AccessoryCleanupStateConns = Connections
	end
end

local function SendPlayerToLobby(Player: Player): ()
	local Character = Player.Character
	if not Character then
		return
	end

	local SpawnCFrame = GetLobbySpawnCFrame()
	if not SpawnCFrame then
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end
	if Humanoid then
		Humanoid.PlatformStand = false
		Humanoid.Sit = false
		Humanoid.AutoRotate = true
		Humanoid:Move(Vector3.zero, false)
	end
	Character:PivotTo(SpawnCFrame)
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function EnforceLobbySpawnForCharacter(Player: Player, Character: Model): ()
	CancelLobbySpawnEnforcement(Player)
	local Token = ActiveLobbySpawnTokens[Player]
	local Deadline = os.clock() + LOBBY_SPAWN_ENFORCE_DURATION

	task.spawn(function()
		while os.clock() < Deadline do
			if ActiveLobbySpawnTokens[Player] ~= Token then
				return
			end
			if Player.Parent == nil or Player.Character ~= Character then
				return
			end
			if IsPlayerAllowedOnField(Player) then
				return
			end

			if ShouldMoveCharacterToLobby(Character) then
				SendPlayerToLobby(Player)
			end

			task.wait(LOBBY_SPAWN_ENFORCE_INTERVAL)
		end
	end)
end

local function CleanupPlayerMatchStateOnRespawn(Player: Player): ()
	local Services = ServerScriptService:FindFirstChild("Services")
	if Services then
		local FTBallServiceModule = Services:FindFirstChild("BallService")
		if FTBallServiceModule then
			local FTBallService = require(FTBallServiceModule)
			if FTBallService and FTBallService.DropBallFromPlayer then
				FTBallService:DropBallFromPlayer(Player)
			end
		end

		local FTSpinServiceModule = Services:FindFirstChild("SpinService")
		if FTSpinServiceModule then
			local FTSpinService = require(FTSpinServiceModule)
			if FTSpinService and FTSpinService.ResetPlayer then
				FTSpinService:ResetPlayer(Player)
			end
		end
	end

	FTPlayerService:LeaveMatch(Player)
end

local function FindTeamPositionTarget(TeamFolder: Instance, Position: string): Instance?
	local DirectTarget = TeamFolder:FindFirstChild(Position)
	if DirectTarget then
		return DirectTarget
	end

	return TeamFolder:FindFirstChild(Position, true)
end

local function GetPositionTargetCFrame(PositionTarget: Instance?): CFrame?
	if not PositionTarget then return nil end
	if PositionTarget:IsA("BasePart") then
		return PositionTarget.CFrame
	end
	if PositionTarget:IsA("Model") then
		local PrimaryPart = PositionTarget.PrimaryPart
		if PrimaryPart then
			return PrimaryPart.CFrame
		end

		local DescendantPart = PositionTarget:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
		if DescendantPart then
			return DescendantPart.CFrame
		end
	end

	return nil
end

local function PivotCharacterTo(Character: Model, TargetCFrame: CFrame): ()
	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local WasAnchored = false
	local WasPlatformStand = false

	if Root then
		WasAnchored = Root.Anchored
		Root.Anchored = true
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	if Humanoid then
		WasPlatformStand = Humanoid.PlatformStand
		Humanoid.PlatformStand = true
		Humanoid.Sit = false
		Humanoid:Move(Vector3.zero, false)
	end

	Character:PivotTo(TargetCFrame)

	if Root then
		Root.Anchored = WasAnchored
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end

	if Humanoid then
		Humanoid.PlatformStand = WasPlatformStand
		Humanoid.Sit = false
	end
end

local function GetSpawnPosition(Team: number, Position: string): CFrame?
        local Game = Workspace:FindFirstChild("Game")
        if not Game then
                DebugSpawn(("GetSpawnPosition failed team=%d position=%s reason=no_game_folder"):format(Team, Position))
                return nil
        end

        local Positions = Game:FindFirstChild("Positions")
        if not Positions then
                DebugSpawn(("GetSpawnPosition failed team=%d position=%s reason=no_positions_folder"):format(Team, Position))
                return nil
        end

        local TeamFolder = Positions:FindFirstChild("Team" .. Team)
        if not TeamFolder then
                DebugSpawn(("GetSpawnPosition failed team=%d position=%s reason=no_team_folder"):format(Team, Position))
                return nil
        end

        local PositionTarget = FindTeamPositionTarget(TeamFolder, Position)
        local TargetCFrame = GetPositionTargetCFrame(PositionTarget)
        if not PositionTarget or not TargetCFrame then
                DebugSpawn(("GetSpawnPosition failed team=%d position=%s reason=target_not_resolved target=%s"):format(
                        Team,
                        Position,
                        if PositionTarget then PositionTarget:GetFullName() else "nil"
                ))
                return nil
        end

        DebugSpawn(("GetSpawnPosition resolved team=%d position=%s target=%s destination=(%.2f, %.2f, %.2f)"):format(
                Team,
                Position,
                PositionTarget:GetFullName(),
                TargetCFrame.Position.X,
                TargetCFrame.Position.Y,
                TargetCFrame.Position.Z
        ))
        return TargetCFrame
end
local function PlayPositionAnimation(Player: Player, Position: string): ()
    local Data = PlayerDataStore[Player]
    if Data and Data.AnimationTrack then
        Data.AnimationTrack:Stop()
        Data.AnimationTrack = nil
    end

    local Character = Player.Character
    if not Character then return end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end

    Humanoid.WalkSpeed = 0

    local Animator = Humanoid:FindFirstChildOfClass("Animator")
    if not Animator then
        Animator = Instance.new("Animator")
        Animator.Parent = Humanoid
    end

    local Assets = ReplicatedStorage:FindFirstChild("Assets")
    if not Assets then return end
    local Gameplay = Assets:FindFirstChild("Gameplay")
    if not Gameplay then return end
    local Animations = Gameplay:FindFirstChild("Animations")
    if not Animations then return end

    local AnimationName = "Linebacker"
    if Position == "Quarter Back" then
        AnimationName = "QB"
    end
    local Animation = Animations:FindFirstChild(AnimationName) :: Animation?
    if Animation then
        local Track = Animator:LoadAnimation(Animation)
        Track.Looped = true
        Track.Priority = Enum.AnimationPriority.Action
        Track:Play()
        if Data then
            Data.AnimationTrack = Track
        end
    end
end

local function SpawnPlayer(Player: Player, Team: number, Position: string): boolean
	local Character = Player.Character or Player.CharacterAdded:Wait()
	if not Character then return false end

	DebugSpawn(("SpawnPlayer begin player=%s team=%d position=%s character=%s"):format(
		Player.Name,
		Team,
		Position,
		Character:GetFullName()
	))

	local SpawnCFrame = GetSpawnPosition(Team, Position)
	if not SpawnCFrame then
		DebugSpawn(("SpawnPlayer aborted player=%s team=%d position=%s reason=no_spawn_cframe"):format(
			Player.Name,
			Team,
			Position
		))
		return false
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
	if not Humanoid or not Humanoid:IsA("Humanoid") then
		DebugSpawn(("SpawnPlayer aborted player=%s team=%d position=%s reason=no_humanoid"):format(
			Player.Name,
			Team,
			Position
		))
		return false
	end

	local Root = Character:WaitForChild("HumanoidRootPart", 5)
	if not Root then
		DebugSpawn(("SpawnPlayer aborted player=%s team=%d position=%s reason=no_root_part"):format(
			Player.Name,
			Team,
			Position
		))
		return false
	end

	PivotCharacterTo(Character, SpawnCFrame)
	DebugSpawn(("SpawnPlayer pivoted player=%s team=%d position=%s destination=(%.2f, %.2f, %.2f)"):format(
		Player.Name,
		Team,
		Position,
		SpawnCFrame.Position.X,
		SpawnCFrame.Position.Y,
		SpawnCFrame.Position.Z
	))

	local countdownActive = IsCountdownActive()
	local matchStarted = IsMatchStarted()
	if not matchStarted or countdownActive then
		PlayPositionAnimation(Player, Position)
	else
		local Data = PlayerDataStore[Player]
		if Data and Data.AnimationTrack then
			Data.AnimationTrack:Stop()
			Data.AnimationTrack = nil
		end
	end
	ApplyTeamAppearance(Player, Team)
	SetPlayerActiveState(Player, true)
	if countdownActive then
			Humanoid.WalkSpeed = 0
	elseif Humanoid.WalkSpeed <= 0 then
			FlowBuffs.ApplyHumanoidWalkSpeed(Player, Humanoid, 16)
	end
	return true
end

local function ActivatePlayerForMatchWithoutTeleport(Player: Player, Team: number, Position: string): boolean
	local Character = Player.Character or Player.CharacterAdded:Wait()
	if not Character then
		return false
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
	if not Humanoid or not Humanoid:IsA("Humanoid") then
		return false
	end

	local Root = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart", 5)
	if not Root then
		return false
	end

	local Data = PlayerDataStore[Player]
	if Data and Data.AnimationTrack then
		Data.AnimationTrack:Stop()
		Data.AnimationTrack = nil
	end

	if not IsPlayerInsidePlaySelectionZone(Player) and not (IsCountdownActive() or IsMatchStarted()) then
		SendPlayerToLobby(Player)
	end

	ApplyTeamAppearance(Player, Team)
	SetPlayerActiveState(Player, true)

	if Humanoid.WalkSpeed <= 0 then
		FlowBuffs.ApplyHumanoidWalkSpeed(Player, Humanoid, 16)
	end

	DebugSpawn(("ActivatePlayerForMatchWithoutTeleport player=%s team=%d position=%s"):format(
		Player.Name,
		Team,
		Position
	))
	return true
end

CancelPendingSelectionActivation = function(Player: Player): ()
	PendingSelectionActivationTokens[Player] = (PendingSelectionActivationTokens[Player] or 0) + 1
end

local function IsIntroCutsceneLocked(Player: Player): boolean
	if Player:GetAttribute(ATTR_MATCH_CUTSCENE_LOCKED) == true then
		return true
	end

	local Character = Player.Character
	return Character ~= nil and Character:GetAttribute(ATTR_MATCH_CUTSCENE_LOCKED) == true
end

ScheduleSelectionActivation = function(Player: Player): ()
	CancelPendingSelectionActivation(Player)
	local Token = PendingSelectionActivationTokens[Player]

	task.spawn(function()
		task.wait(SELECTION_ACTIVATION_INITIAL_DELAY)
		local Deadline = os.clock() + SELECTION_ACTIVATION_TIMEOUT

		while PendingSelectionActivationTokens[Player] == Token and Player.Parent ~= nil do
			local Data = PlayerDataStore[Player]
			if not Data or not Data.Team or not Data.Position then
				return
			end
			if Data.ActiveInMatch then
				return
			end
			if os.clock() >= Deadline then
				return
			end

			if (IsCountdownActive() or IsMatchStarted()) and not IsIntroCutsceneLocked(Player) then
				if SpawnPlayer(Player, Data.Team, Data.Position) then
					return
				end
			end

			task.wait(SELECTION_ACTIVATION_RETRY_INTERVAL)
		end
	end)
end

NotifyGameServiceOfSelection = function(Player: Player): ()
	local GameService = GetGameService()
	if GameService and GameService.OnPlayerPositionSelected then
		GameService:OnPlayerPositionSelected(Player)
	end
end

local function UpdatePlayerTeamValue(Player: Player, Team: number): ()
	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if not GameStateFolder then return end

	local playerId = PlayerIdentity.GetIdValue(Player)
	local PlayerTeamValue = GameStateFolder:FindFirstChild("PlayerTeam_" .. playerId) :: IntValue?
	if not PlayerTeamValue then
			PlayerTeamValue = Instance.new("IntValue")
			PlayerTeamValue.Name = "PlayerTeam_" .. playerId
			PlayerTeamValue.Parent = GameStateFolder
	end
	PlayerTeamValue.Value = Team
end

local function ClearPlayerTeamValue(Player: Player): ()
	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if not GameStateFolder then
		return
	end

	local playerId = PlayerIdentity.GetIdValue(Player)
	local PlayerTeamValue = GameStateFolder:FindFirstChild("PlayerTeam_" .. playerId) :: IntValue?
	if PlayerTeamValue then
		PlayerTeamValue.Value = 0
	end
end

local function ClearGhostSelectionState(Player: Player): ()
	local playerId = PlayerIdentity.GetIdValue(Player)
	if playerId == 0 then
		return
	end

	local Folder = GetMatchFolder()
	if Folder then
		for TeamNumber = 1, 2 do
			local TeamFolder = Folder:FindFirstChild("Team" .. TeamNumber)
			if not TeamFolder then
				continue
			end

			for _, Position in FTConfig.PLAYER_POSITIONS do
				local PositionValue = TeamFolder:FindFirstChild(Position.Name)
				if PositionValue and PositionValue:IsA("IntValue") and PositionValue.Value == playerId then
					PositionValue.Value = 0
				end
			end
		end
	end

	ClearPlayerTeamValue(Player)
end

local function IsSelectionTemporarilyLocked(Player: Player): boolean
	local Data = PlayerDataStore[Player]
	if not Data then
		return false
	end

	local UnlockAt = Data.SelectionUnlockedAt
	return typeof(UnlockAt) == "number" and os.clock() < UnlockAt
end

local function ResolveSyncedSelectedPlayer(TeamNumber: number, PositionName: string, OccupantId: number): Player?
	if OccupantId == 0 then
		return nil
	end

	local FoundPlayer = PlayerIdentity.ResolvePlayer(OccupantId)
	if not FoundPlayer then
		return nil
	end
	if PlayerIdentity.GetIdValue(FoundPlayer) ~= OccupantId then
		return nil
	end

	local Data = PlayerDataStore[FoundPlayer]
	if not Data then
		return nil
	end
	if Data.Team ~= TeamNumber or Data.Position ~= PositionName then
		return nil
	end

	return FoundPlayer
end

local function CheckAndStartCountdown(): ()
	local Folder = GetMatchFolder()
	if not Folder then return end

	local PlayerCount = 0
	for TeamNumber = 1, 2 do
			local TeamFolder = Folder:FindFirstChild("Team" .. TeamNumber)
			if not TeamFolder then
					continue
			end
			for _, Position in FTConfig.PLAYER_POSITIONS do
					local PositionValue = TeamFolder:FindFirstChild(Position.Name)
					if PositionValue and PositionValue:IsA("IntValue") then
							local SelectedPlayer = ResolveSyncedSelectedPlayer(TeamNumber, Position.Name, PositionValue.Value)
							if SelectedPlayer then
									PlayerCount = PlayerCount + 1
							end
					end
			end
	end

	if PlayerCount >= MatchPlayerUtils.GetMinimumPlayersToStart() then
			local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
			if GameStateFolder then
					local CountdownActive = GameStateFolder:FindFirstChild("CountdownActive") :: BoolValue?
					local MatchStarted = GameStateFolder:FindFirstChild("MatchStarted") :: BoolValue?
					local IntermissionActive = GameStateFolder:FindFirstChild("IntermissionActive") :: BoolValue?

					if IntermissionActive and IntermissionActive.Value then return end
					if MatchStarted and MatchStarted.Value then return end
					if CountdownActive and CountdownActive.Value then return end

					local ServerScriptService = game:GetService("ServerScriptService")
					local Services = ServerScriptService:FindFirstChild("Services")
					if Services then
							local FTGameServiceModule = Services:FindFirstChild("GameService")
							if FTGameServiceModule then
									local FTGameService = require(FTGameServiceModule)
									FTGameService:StartCountdown()
							end
					end
			end
	end
end

local function ValidatePositionSelection(Player: Player, Position: string, TeamNumber: number): boolean
	local MatchEnabled = GetMatchEnabled()
	if not MatchEnabled then return false end

	local ValidPosition = false
	for _, ConfigPosition in FTConfig.PLAYER_POSITIONS do
			if ConfigPosition.Name == Position then
					ValidPosition = true
					break
			end
	end

	if not ValidPosition then return false end

	if TeamNumber ~= 1 and TeamNumber ~= 2 then return false end

	if IsPositionOccupied(TeamNumber, Position) then
			local CurrentOccupant = GetPositionOccupant(TeamNumber, Position)
			local playerId = PlayerIdentity.GetIdValue(Player)
			if CurrentOccupant ~= playerId then
					return false
			end
	end

	return true
end

local function HandlePositionSelect(Player: Player, ...: any): ()
	local Args = {...}

	local Position = Args[1]
	local TeamNumber = Args[2]

	local function RejectSelection(): ()
		Packets.PositionSelectResult:FireClient(Player, false, 0, "")
	end

	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if GameStateFolder then
		local IntermissionActive = GameStateFolder:FindFirstChild("IntermissionActive") :: BoolValue?
		if IntermissionActive and IntermissionActive.Value then
			RejectSelection()
			return
		end
		local IntermissionTime = GameStateFolder:FindFirstChild("IntermissionTime") :: IntValue?
		if IntermissionTime and IntermissionTime.Value > 0 then
			RejectSelection()
			return
		end
	end

	if IsSelectionTemporarilyLocked(Player) then
		DebugSpawn(("RejectSelection early_guard player=%s"):format(Player.Name))
		RejectSelection()
		return
	end

	if type(Position) ~= "string" then
		RejectSelection()
		return
	end
	if type(TeamNumber) ~= "number" then
		RejectSelection()
		return
	end

	local TeamNumberInt = math.floor(TeamNumber)

	if not ValidatePositionSelection(Player, Position, TeamNumberInt) then
		RejectSelection()
		return
	end

	ClearPlayerPosition(Player)

	if not PlayerDataStore[Player] then
			PlayerDataStore[Player] = {
				ActiveInMatch = false,
				PendingLobbyRespawn = false,
				InitialSpawnHandled = false,
				SelectionUnlockedAt = 0,
				AccessoryCleanupConn = nil,
				AccessoryCleanupStateConns = nil,
			}
	end

	PlayerDataStore[Player].Team = TeamNumberInt
	PlayerDataStore[Player].Position = Position
	PlayerDataStore[Player].ActiveInMatch = false
	PlayerDataStore[Player].PendingLobbyRespawn = false
	SetPlayerActiveState(Player, false)

	local playerId = PlayerIdentity.GetIdValue(Player)
	SetPositionOccupant(TeamNumberInt, Position, playerId)

	UpdatePlayerTeamValue(Player, TeamNumberInt)

	Packets.PositionSelectResult:FireClient(Player, true, TeamNumberInt, Position)
	ScheduleSelectionActivation(Player)
	NotifyGameServiceOfSelection(Player)

	CheckAndStartCountdown()
end

local function HandlePlayerAdded(Player: Player): ()
	PlayerDataStore[Player] = {
		ActiveInMatch = false,
		PendingLobbyRespawn = false,
		InitialSpawnHandled = false,
		SelectionUnlockedAt = 0,
		AccessoryCleanupConn = nil,
		AccessoryCleanupStateConns = nil,
	}
	SetPlayerActiveState(Player, false)
	PlayerIdentity.AssignSessionId(Player)
	ClearGhostSelectionState(Player)

	local function HandleCharacterSpawn(Character: Model): ()
		BindCharacterMeshCleanup(Player, Character)
		BindCharacterAccessoryCleanup(Player, Character)

		local Data = PlayerDataStore[Player]
		if Data and Data.InitialSpawnHandled ~= true then
			Data.InitialSpawnHandled = true
			Data.SelectionUnlockedAt = os.clock() + INITIAL_SELECTION_GUARD_DURATION
			ClearGhostSelectionState(Player)
			if Data.Team ~= nil or Data.Position ~= nil then
				DebugSpawn(("CharacterAdded clearing unexpected initial selection player=%s team=%s position=%s"):format(
					Player.Name,
					tostring(Data.Team),
					tostring(Data.Position)
				))
				ClearPlayerPosition(Player)
			end
		end

		if Data and Data.PendingLobbyRespawn then
			Data.PendingLobbyRespawn = false
			task.wait(0.2)
			if Player.Character == Character then
				if ShouldMoveCharacterToLobby(Character) then
					SendPlayerToLobby(Player)
				end
				EnforceLobbySpawnForCharacter(Player, Character)
			end
			return
		end

		if Data and Data.Team and Data.Position then
			DebugSpawn(("CharacterAdded respawn forcing lobby player=%s team=%d position=%s"):format(
				Player.Name,
				Data.Team,
				Data.Position
			))
			Data.PendingLobbyRespawn = false
			CleanupPlayerMatchStateOnRespawn(Player)
			task.wait(0.2)
			if Player.Character == Character then
				if ShouldMoveCharacterToLobby(Character) then
					SendPlayerToLobby(Player)
				end
				EnforceLobbySpawnForCharacter(Player, Character)
			end
			return
		end

		if Data and Data.Team then
			task.wait(0.2)
			if Player.Character == Character then
				ApplyTeamAppearance(Player, Data.Team)
				if not IsPlayerAllowedOnField(Player) then
					if ShouldMoveCharacterToLobby(Character) then
						SendPlayerToLobby(Player)
					end
					EnforceLobbySpawnForCharacter(Player, Character)
				end
			end
			return
		end

		task.wait(0.2)
		if Player.Character ~= Character then
			return
		end
		if IsPlayerAllowedOnField(Player) then
			CancelLobbySpawnEnforcement(Player)
			return
		end
		if ShouldMoveCharacterToLobby(Character) then
			SendPlayerToLobby(Player)
		end
		EnforceLobbySpawnForCharacter(Player, Character)
	end

	Player.CharacterAdded:Connect(HandleCharacterSpawn)

	Player.CharacterRemoving:Connect(function(Character: Model)
		CancelLobbySpawnEnforcement(Player)
		local Data = PlayerDataStore[Player]
		if Data and Data.AccessoryCleanupConn then
			Data.AccessoryCleanupConn:Disconnect()
			Data.AccessoryCleanupConn = nil
		end
		DisconnectAccessoryCleanupStateConnections(Data)
		if not Data or not Data.Team or not Data.Position then
			return
		end
		if Player.Character ~= Character then
			return
		end

		Data.PendingLobbyRespawn = true
		CleanupPlayerMatchStateOnRespawn(Player)
	end)

	local ExistingCharacter = Player.Character
	if ExistingCharacter then
		task.defer(HandleCharacterSpawn, ExistingCharacter)
	end
end

local function HandlePlayerRemoving(Player: Player): ()
	CancelLobbySpawnEnforcement(Player)
	CancelPendingSelectionActivation(Player)
	ClearPlayerPosition(Player)
	local data = PlayerDataStore[Player]
	if data and data.MeshConn then
		data.MeshConn:Disconnect()
		data.MeshConn = nil
	end
	if data and data.AccessoryCleanupConn then
		data.AccessoryCleanupConn:Disconnect()
		data.AccessoryCleanupConn = nil
	end
	DisconnectAccessoryCleanupStateConnections(data)

	local GameStateFolder = ReplicatedStorage:FindFirstChild("FTGameState")
	if GameStateFolder then
			local playerId = PlayerIdentity.GetIdValue(Player)
			local PlayerTeamValue = GameStateFolder:FindFirstChild("PlayerTeam_" .. playerId)
			if PlayerTeamValue then
					PlayerTeamValue:Destroy()
			end
	end

	PlayerDataStore[Player] = nil
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function FTPlayerService.Init(_self: typeof(FTPlayerService)): ()
	Packets.PositionSelect.OnServerEvent:Connect(function(Player: Player, ...)
			HandlePositionSelect(Player, ...)
	end)

	Players.PlayerAdded:Connect(HandlePlayerAdded)
	Players.PlayerRemoving:Connect(HandlePlayerRemoving)

	for _, Player in Players:GetPlayers() do
			HandlePlayerAdded(Player)
	end
end

function FTPlayerService.Start(_self: typeof(FTPlayerService)): ()
end

function FTPlayerService.GetPlayerTeam(_self: typeof(FTPlayerService), Player: Player): number?
	local Data = PlayerDataStore[Player]
	if not Data then return nil end
	return Data.Team
end

function FTPlayerService.GetPlayerPosition(_self: typeof(FTPlayerService), Player: Player): string?
	local Data = PlayerDataStore[Player]
	if not Data then return nil end
	return Data.Position
end

function FTPlayerService.PlayPositionAnimation(_self: typeof(FTPlayerService), Player: Player): ()
	local Data = PlayerDataStore[Player]
	if not Data or not Data.Position then return end
	PlayPositionAnimation(Player, Data.Position)
end

function FTPlayerService.IsPlayerInMatch(_self: typeof(FTPlayerService), Player: Player): boolean
	local Data = PlayerDataStore[Player]
	if not Data then return false end
	return Data.ActiveInMatch == true
end

function FTPlayerService.GetSelectedPlayerCount(_self: typeof(FTPlayerService)): number
	local Count = 0
	local Folder = GetMatchFolder()
	if not Folder then
		return Count
	end

	for TeamNumber = 1, 2 do
		local TeamFolder = Folder:FindFirstChild("Team" .. TeamNumber)
		if not TeamFolder then
			continue
		end
		for _, Position in FTConfig.PLAYER_POSITIONS do
			local PositionValue = TeamFolder:FindFirstChild(Position.Name) :: IntValue?
			if PositionValue then
				local SelectedPlayer = ResolveSyncedSelectedPlayer(TeamNumber, Position.Name, PositionValue.Value)
				if SelectedPlayer then
					Count += 1
				end
			end
		end
	end

	return Count
end

function FTPlayerService.GetSelectedPlayersForTeam(_self: typeof(FTPlayerService), TeamNumber: number): {Player}
	local SelectedPlayers: {Player} = {}
	local Folder = GetMatchFolder()
	if not Folder then
		return SelectedPlayers
	end

	local TeamFolder = Folder:FindFirstChild("Team" .. TeamNumber)
	if not TeamFolder then
		return SelectedPlayers
	end

	for _, Position in FTConfig.PLAYER_POSITIONS do
		local PositionValue = TeamFolder:FindFirstChild(Position.Name) :: IntValue?
		if PositionValue then
			local FoundPlayer = ResolveSyncedSelectedPlayer(TeamNumber, Position.Name, PositionValue.Value)
			if FoundPlayer then
				table.insert(SelectedPlayers, FoundPlayer)
			end
		end
	end

	return SelectedPlayers
end

function FTPlayerService.GetSelectedPlayers(_self: typeof(FTPlayerService)): {Player}
	local SelectedPlayers: {Player} = {}
	for TeamNumber = 1, 2 do
		for _, Player in FTPlayerService:GetSelectedPlayersForTeam(TeamNumber) do
			table.insert(SelectedPlayers, Player)
		end
	end
	return SelectedPlayers
end

function FTPlayerService.PrepareSelectedPlayersForIntro(_self: typeof(FTPlayerService)): {Player}
	local PreparedPlayers: {Player} = {}

	for _, Player in FTPlayerService:GetSelectedPlayers() do
		local Data = PlayerDataStore[Player]
		if not Data or not Data.Team then
			continue
		end

		local Character = Player.Character
		if Character and Character.Parent ~= nil then
			ApplyTeamAppearance(Player, Data.Team)
			table.insert(PreparedPlayers, Player)
		end
	end

	return PreparedPlayers
end

function FTPlayerService.ActivateSelectedPlayersForMatch(_self: typeof(FTPlayerService)): {Player}
	local ActivatedPlayers: {Player} = {}

	for _, Player in FTPlayerService:GetSelectedPlayers() do
		local Data = PlayerDataStore[Player]
		if not Data or not Data.Team or not Data.Position then
			continue
		end

		if Data.ActiveInMatch then
			table.insert(ActivatedPlayers, Player)
			continue
		end

		local SpawnSucceeded = if IsCountdownActive() or IsMatchStarted()
			then SpawnPlayer(Player, Data.Team, Data.Position)
			else ActivatePlayerForMatchWithoutTeleport(Player, Data.Team, Data.Position)
		if SpawnSucceeded then
			table.insert(ActivatedPlayers, Player)
		else
			ClearPlayerPosition(Player)
			ClearPlayerTeamValue(Player)
		end
	end

	return ActivatedPlayers
end

function FTPlayerService.StopPlayerAnimation(_self: typeof(FTPlayerService), Player: Player): ()
	local Data = PlayerDataStore[Player]
	if not Data then return end

	if Data.AnimationTrack then
			Data.AnimationTrack:Stop()
			Data.AnimationTrack = nil
	end
end

function FTPlayerService.LeaveMatch(_self: typeof(FTPlayerService), Player: Player): ()
	SetPlayerActiveState(Player, false)
	ClearPlayerPosition(Player)
	UpdatePlayerTeamValue(Player, 0)
	RestorePlayerAppearance(Player)
	local Data = PlayerDataStore[Player]
	if Data then
			Data.OriginalOutfit = nil
			Data.TeamHeadClone = nil
	end
end

return FTPlayerService
