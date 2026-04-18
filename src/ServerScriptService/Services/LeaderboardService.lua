--!strict

local DataStoreService: DataStoreService = game:GetService("DataStoreService")
local PlayersService: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local Workspace: Workspace = game:GetService("Workspace")

local PlayerDataManager: any = require(ReplicatedStorage.Packages.PlayerDataManager)
local PlayerDataGuard: any = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)
local FTGameService = require(script.Parent.GameService)
local FTPlayerService = require(script.Parent.PlayerService)
local LobbyAvatars = require(script.Parent.Utils.LobbyAvatars)
local PlayerStatsTracker = require(script.Parent.Utils.PlayerStatsTracker)
local RankStats = require(script.Parent.Utils.RankStats)

local LeaderboardService = {}

type DisconnectHandle = {
	Disconnect: (self: DisconnectHandle) -> (),
}

type BoundPlayerData = {
	Connections: {DisconnectHandle},
}

type BoardEntry = {
	UserId: number,
	Score: number,
	Name: string,
	Thumbnail: string,
}

type MatchResult = {
	WinnerTeam: number?,
	Team1Score: number,
	Team2Score: number,
}

type BoardDisplayVariant = "Default" | "Tv"
type BoardSurfaceTarget = {
	SurfaceGui: SurfaceGui,
	Variant: BoardDisplayVariant,
}

local DEFAULT_PROFILE_STORE_KEY: string = "PlayerStore"
local PROFILE_STORE_KEY: string = tostring(PlayerDataManager._dataStoreKey or DEFAULT_PROFILE_STORE_KEY)

local LOBBY_NAME: string = "Lobby"
local LEADERBOARD_FOLDER_NAME: string = "Leaderboard"
local LEADERBOARD_PART_NAME: string = "Leaderboard"
local TV_MODEL_NAME: string = "Tv"
local TV_FIX_PART_NAME: string = "Fix"
local BOARD_TYPE_ATTR: string = "Type"
local RANK_ATTR: string = "Rank"
local RENDERED_ENTRY_ATTR: string = "RenderedLeaderboardEntry"
local DEFAULT_TOP_LIMIT: number = 50
local TV_TOP_LIMIT: number = 100
local MAX_ENTRY_FETCH_LIMIT: number = TV_TOP_LIMIT
local PODIUM_LIMIT: number = 3
local TIMER_TICK_SECONDS: number = 1
local TIMER_FLUSH_INTERVAL_SECONDS: number = 60
local ORDERED_FLUSH_INTERVAL_SECONDS: number = 60
local BOARD_BIND_RETRY_SECONDS: number = 1
local BOARD_REFRESH_INTERVAL_SECONDS: number = 60
local STARTUP_REFRESH_DELAY_SECONDS: number = 5
local EMPTY_PLAYER_NAME: string = "---"
local EMPTY_IMAGE: string = ""
local STUDIO_LIVE_DATASTORES_ATTRIBUTE: string = "ProfileStoreStudioUseLiveData"

local TITLE_PATH: {string} = { "Frame", "TextLabel" }
local LIST_PATH: {string} = { "List" }
local TEMPLATE_PATH: {string} = { "List", "LeaderboardTemplate" }
local PODIUM_PATH: {string} = { "Podium" }
local ENTRY_IMAGE_PATH: {string} = { "ImageOuter", "UserIMG" }
local NAME_LABEL_PATH: {string} = { "Head", "RankAttach", "BillboardGui", "PlayerName" }

local BoardModelsByType: {[string]: {Model}} = {}
local RefreshTypes: {string} = {}
local RefreshTypeIndex: number = 1
local PendingOrderedWrites: {[string]: {[number]: number}} = {}
local OrderedStores: {[string]: OrderedDataStore} = {}
local BoundPlayers: {[Player]: BoundPlayerData} = {}
local PendingTimerByPlayer: {[Player]: number} = {}
local TimerFlushElapsed: number = 0
local OrderedFlushElapsed: number = 0
local MatchEndedConnection: any = nil
local BoardFolderAddedConnection: RBXScriptConnection? = nil
local BoardFolderRemovedConnection: RBXScriptConnection? = nil
local PendingBoardRefreshToken: number = 0
local OrderedLeaderboardsEnabled: boolean = true
local OrderedLeaderboardsDisableReason: string? = nil
local OrderedLeaderboardsDisableWarned: boolean = false
local RefreshAllBoards: () -> () = function(): ()
end

local function FindPath(Root: Instance?, Path: {string}): Instance?
	if not Root then
		return nil
	end

	local Current: Instance? = Root
	for _, Name in Path do
		if not Current then
			return nil
		end

		Current = Current:FindFirstChild(Name)
	end

	return Current
end

local function ClampValue(Value: any): number
	return RankStats.ClampValue(Value)
end

local function GetCurrentMatchPlayers(): {Player}
	local MatchPlayers: {Player} = {}
	for _, PlayerInstance in PlayersService:GetPlayers() do
		if FTPlayerService:IsPlayerInMatch(PlayerInstance) then
			table.insert(MatchPlayers, PlayerInstance)
		end
	end
	return MatchPlayers
end

local function SetTextLabel(Target: Instance?, Text: string): ()
	if not Target or not Target:IsA("TextLabel") then
		return
	end

	Target.Text = Text
end

local function SetImage(Target: Instance?, Image: string): ()
	if not Target then
		return
	end
	if not Target:IsA("ImageLabel") and not Target:IsA("ImageButton") then
		return
	end

	Target.Image = Image
end

local function FindNamedDescendant(Root: Instance?, Name: string, ClassName: string?): Instance?
	if not Root then
		return nil
	end

	local DirectChild: Instance? = Root:FindFirstChild(Name, true)
	if DirectChild then
		if not ClassName or DirectChild:IsA(ClassName) then
			return DirectChild
		end
	end

	if not ClassName then
		return nil
	end

	for _, Descendant in Root:GetDescendants() do
		if Descendant.Name ~= Name then
			continue
		end
		if not Descendant:IsA(ClassName) then
			continue
		end

		return Descendant
	end

	return nil
end

local function IsInsideNamedAncestor(InstanceItem: Instance?, AncestorName: string, Root: Instance?): boolean
	if not InstanceItem then
		return false
	end

	local Current: Instance? = InstanceItem.Parent
	while Current and Current ~= Root do
		if Current.Name == AncestorName then
			return true
		end

		Current = Current.Parent
	end

	return false
end

local function ScheduleBoardRefresh(DelayTime: number?): ()
	PendingBoardRefreshToken += 1
	local CurrentToken: number = PendingBoardRefreshToken
	local EffectiveDelay: number = math.max(DelayTime or 0, 0)

	task.delay(EffectiveDelay, function(): ()
		if PendingBoardRefreshToken ~= CurrentToken then
			return
		end

		RefreshAllBoards()
	end)
end

local function ShouldRefreshForBoardDescendant(Descendant: Instance): boolean
	if Descendant:IsA("Model") and Descendant:GetAttribute(BOARD_TYPE_ATTR) ~= nil then
		return true
	end
	if Descendant:IsA("SurfaceGui") then
		return true
	end
	if Descendant:IsA("Folder") and Descendant.Name == "Characters" then
		return true
	end
	if Descendant:IsA("BasePart") and Descendant.Name == LEADERBOARD_PART_NAME then
		return true
	end

	return false
end

local function GetStoreName(BoardType: string): string
	local Definition: RankStats.BoardDef? = RankStats.GetBoardDef(BoardType)
	local StoreKey: string = if Definition then Definition.StoreKey else BoardType
	return string.format("%s_LB_%s", PROFILE_STORE_KEY, StoreKey)
end

local function IsOrderedLeaderboardAccessForbidden(ErrorMessage: any): boolean
	local Message: string = string.lower(tostring(ErrorMessage))
	return string.find(Message, "access forbidden", 1, true) ~= nil
		or string.find(Message, "http 403", 1, true) ~= nil
		or string.find(Message, "403", 1, true) ~= nil
end

local function DisableOrderedLeaderboards(Reason: any, SuppressWarning: boolean?): ()
	OrderedLeaderboardsEnabled = false
	OrderedLeaderboardsDisableReason = tostring(Reason)
	table.clear(PendingOrderedWrites)
	ScheduleBoardRefresh(0)

	if SuppressWarning then
		OrderedLeaderboardsDisableWarned = true
		return
	end

	if OrderedLeaderboardsDisableWarned then
		return
	end
	OrderedLeaderboardsDisableWarned = true

	local EnvironmentLabel: string = if RunService:IsStudio() then "Studio" else "server"
	warn(
		string.format(
			"LeaderboardService disabled ordered leaderboards for this %s session: %s",
			EnvironmentLabel,
			tostring(Reason)
		)
	)
end

local function GetOrderedStore(BoardType: string): OrderedDataStore
	local ExistingStore: OrderedDataStore? = OrderedStores[BoardType]
	if ExistingStore then
		return ExistingStore
	end

	local OrderedStore: OrderedDataStore = DataStoreService:GetOrderedDataStore(GetStoreName(BoardType))
	OrderedStores[BoardType] = OrderedStore
	return OrderedStore
end

local function QueueOrderedWrite(BoardType: string, UserId: number, Value: number): ()
	if not OrderedLeaderboardsEnabled then
		return
	end
	if UserId <= 0 then
		return
	end

	local PendingForType: {[number]: number}? = PendingOrderedWrites[BoardType]
	if not PendingForType then
		PendingForType = {}
		PendingOrderedWrites[BoardType] = PendingForType
	end

	PendingForType[UserId] = ClampValue(Value)
end

local function QueueOrderedWriteFromStat(StatName: string, UserId: number, Value: number): ()
	local BoardType: RankStats.BoardType? = RankStats.GetBoardTypeFromStatName(StatName)
	if not BoardType then
		return
	end

	QueueOrderedWrite(BoardType, UserId, Value)
	if not OrderedLeaderboardsEnabled then
		ScheduleBoardRefresh(0.25)
	end
end

local function FlushOrderedWrites(BoardType: string?): ()
	if not OrderedLeaderboardsEnabled then
		return
	end

	local TypesToFlush: {string} = {}
	if BoardType then
		table.insert(TypesToFlush, BoardType)
	else
		for _, CurrentType in RankStats.GetBoardTypes() do
			table.insert(TypesToFlush, CurrentType)
		end
	end

	for _, CurrentType in TypesToFlush do
		local PendingForType: {[number]: number}? = PendingOrderedWrites[CurrentType]
		if not PendingForType then
			continue
		end

		local OrderedStore: OrderedDataStore = GetOrderedStore(CurrentType)
		local CompletedUsers: {number} = {}

		for UserId, Value in PendingForType do
			local Key: string = tostring(UserId)
			local Success: boolean = false
			local ErrorMessage: any = nil

			if Value <= 0 then
				Success, ErrorMessage = pcall(OrderedStore.RemoveAsync, OrderedStore, Key)
			else
				Success, ErrorMessage = pcall(OrderedStore.SetAsync, OrderedStore, Key, Value)
			end

			if not Success then
				if IsOrderedLeaderboardAccessForbidden(ErrorMessage) then
					DisableOrderedLeaderboards(ErrorMessage)
					return
				end
				warn(
					string.format(
						"LeaderboardService failed to flush %s for %d: %s",
						CurrentType,
						UserId,
						tostring(ErrorMessage)
					)
				)
				continue
			end

			table.insert(CompletedUsers, UserId)
		end

		for _, UserId in CompletedUsers do
			PendingForType[UserId] = nil
		end

		if next(PendingForType) == nil then
			PendingOrderedWrites[CurrentType] = nil
		end
	end
end

local function GetBoardFolder(): Folder?
	local LobbyFolder: Instance? = Workspace:FindFirstChild(LOBBY_NAME)
	if not LobbyFolder then
		return nil
	end

	local BoardFolder: Instance? = LobbyFolder:FindFirstChild(LEADERBOARD_FOLDER_NAME)
	if not BoardFolder or not BoardFolder:IsA("Folder") then
		return nil
	end

	return BoardFolder
end

local function ResolveBoards(): ()
	local Groups: {[string]: {Model}} = {}
	local BoardFolder: Folder? = GetBoardFolder()
	if BoardFolder then
		for _, Child in BoardFolder:GetDescendants() do
			if not Child:IsA("Model") then
				continue
			end

			local BoardType: RankStats.BoardType? = RankStats.NormalizeBoardType(Child:GetAttribute(BOARD_TYPE_ATTR))
			if not BoardType then
				continue
			end

			local Group: {Model}? = Groups[BoardType]
			if not Group then
				Group = {}
				Groups[BoardType] = Group
			end

			table.insert(Group, Child)
		end
	end

	BoardModelsByType = Groups
	RefreshTypes = {}
	for _, BoardType in RankStats.GetBoardTypes() do
		local Group: {Model}? = Groups[BoardType]
		if not Group or #Group <= 0 then
			continue
		end

		table.insert(RefreshTypes, BoardType)
	end

	if RefreshTypeIndex > #RefreshTypes then
		RefreshTypeIndex = 1
	end
end

local function GetPrimaryBoardSurfaceGui(BoardModel: Model): SurfaceGui?
	local BoardPart: Instance? = BoardModel:FindFirstChild(LEADERBOARD_PART_NAME)
	if not BoardPart then
		BoardPart = FindNamedDescendant(BoardModel, LEADERBOARD_PART_NAME, "BasePart")
	end
	if BoardPart and BoardPart:IsA("BasePart") then
		local DirectSurfaceGui: SurfaceGui? = BoardPart:FindFirstChildWhichIsA("SurfaceGui") :: SurfaceGui?
		if DirectSurfaceGui then
			return DirectSurfaceGui
		end

		local NestedSurfaceGui: Instance? = BoardPart:FindFirstChildWhichIsA("SurfaceGui", true)
		if NestedSurfaceGui and NestedSurfaceGui:IsA("SurfaceGui") then
			return NestedSurfaceGui
		end
	end

	for _, Descendant in BoardModel:GetDescendants() do
		if not Descendant:IsA("SurfaceGui") then
			continue
		end
		if IsInsideNamedAncestor(Descendant, TV_MODEL_NAME, BoardModel) then
			continue
		end

		return Descendant
	end

	return nil
end

local function GetTvBoardSurfaceGui(BoardModel: Model): SurfaceGui?
	local TvModel: Instance? = FindNamedDescendant(BoardModel, TV_MODEL_NAME, "Model")
	if not TvModel then
		return nil
	end

	local FixPart: Instance? = FindNamedDescendant(TvModel, TV_FIX_PART_NAME, "BasePart")
	if FixPart and FixPart:IsA("BasePart") then
		local SurfaceGuiInstance: Instance? = FixPart:FindFirstChildWhichIsA("SurfaceGui", true)
		if SurfaceGuiInstance and SurfaceGuiInstance:IsA("SurfaceGui") then
			return SurfaceGuiInstance
		end
	end

	local FallbackSurfaceGui: Instance? = TvModel:FindFirstChildWhichIsA("SurfaceGui", true)
	if FallbackSurfaceGui and FallbackSurfaceGui:IsA("SurfaceGui") then
		return FallbackSurfaceGui
	end

	return nil
end

local function GetBoardSurfaceTargets(BoardModel: Model): {BoardSurfaceTarget}
	local Targets: {BoardSurfaceTarget} = {}
	local Seen: {[SurfaceGui]: boolean} = {}

	local PrimarySurfaceGui: SurfaceGui? = GetPrimaryBoardSurfaceGui(BoardModel)
	if PrimarySurfaceGui then
		Seen[PrimarySurfaceGui] = true
		table.insert(Targets, {
			SurfaceGui = PrimarySurfaceGui,
			Variant = "Default",
		})
	end

	local TvSurfaceGui: SurfaceGui? = GetTvBoardSurfaceGui(BoardModel)
	if TvSurfaceGui and not Seen[TvSurfaceGui] then
		table.insert(Targets, {
			SurfaceGui = TvSurfaceGui,
			Variant = "Tv",
		})
	end

	return Targets
end

local function ClearRenderedEntries(Template: Instance): ()
	local ParentInstance: Instance? = Template.Parent
	if not ParentInstance then
		return
	end

	for _, Child in ParentInstance:GetChildren() do
		if Child == Template then
			continue
		end
		if Child:GetAttribute(RENDERED_ENTRY_ATTR) ~= true then
			continue
		end

		Child:Destroy()
	end

	if Template:IsA("GuiObject") then
		Template.Visible = false
	end
end

local function RefreshListContainer(ParentInstance: Instance?, SurfaceGuiInstance: SurfaceGui?): ()
	if not ParentInstance or not ParentInstance:IsA("ScrollingFrame") then
		return
	end

	ParentInstance.Active = true
	ParentInstance.Selectable = true
	ParentInstance.ScrollingEnabled = true
	ParentInstance.ScrollingDirection = Enum.ScrollingDirection.Y
	ParentInstance.ClipsDescendants = true
	ParentInstance.AutomaticCanvasSize = Enum.AutomaticSize.Y
	if ParentInstance.ScrollBarThickness <= 0 then
		ParentInstance.ScrollBarThickness = 8
	end
	ParentInstance.CanvasSize = UDim2.new(0, 0, 1, 0)

	if SurfaceGuiInstance then
		pcall(function()
			(SurfaceGuiInstance :: any).Active = true
		end)
	end
end

local function RenderListEntries(
	SurfaceGuiInstance: SurfaceGui,
	BoardType: string,
	Entries: {BoardEntry},
	RenderLimit: number
): ()
	local Template: Instance? = FindPath(SurfaceGuiInstance, TEMPLATE_PATH)
	if not Template then
		Template = SurfaceGuiInstance:FindFirstChild("LeaderboardTemplate", true)
	end
	if not Template then
		return
	end

	ClearRenderedEntries(Template)

	local ParentInstance: Instance? = Template.Parent
	if not ParentInstance then
		return
	end

	local RenderCount: number = math.min(#Entries, math.max(RenderLimit, 0))
	for RankNumber: number = 1, RenderCount do
		local Entry: BoardEntry = Entries[RankNumber]
		local Clone: Instance = Template:Clone()
		Clone.Name = "Entry" .. tostring(RankNumber)
		Clone:SetAttribute(RENDERED_ENTRY_ATTR, true)

		if Clone:IsA("GuiObject") then
			Clone.LayoutOrder = RankNumber
			Clone.Visible = true
		end

		SetTextLabel(Clone:FindFirstChild("Rank"), "# " .. tostring(RankNumber))
		SetTextLabel(Clone:FindFirstChild("Username"), Entry.Name)
		SetTextLabel(Clone:FindFirstChild("Score"), RankStats.FormatScore(BoardType, Entry.Score))
		SetImage(FindPath(Clone, ENTRY_IMAGE_PATH), Entry.Thumbnail)

		Clone.Parent = ParentInstance
	end

	RefreshListContainer(ParentInstance, SurfaceGuiInstance)
end

local function RenderTitle(SurfaceGuiInstance: SurfaceGui, BoardType: string, Variant: BoardDisplayVariant): ()
	local TitleLabel: Instance? = FindPath(SurfaceGuiInstance, TITLE_PATH)
	if not TitleLabel then
		local HeaderRoot: Instance? = SurfaceGuiInstance:FindFirstChild("Frame")
		if not HeaderRoot then
			HeaderRoot = SurfaceGuiInstance:FindFirstChildWhichIsA("Frame")
		end
		if HeaderRoot then
			TitleLabel = HeaderRoot:FindFirstChildWhichIsA("TextLabel", true)
		end
	end

	SetTextLabel(TitleLabel, RankStats.GetBoardTitle(BoardType, Variant))
end

local function RenderPodiumImages(SurfaceGuiInstance: SurfaceGui, Entries: {BoardEntry}): ()
	local PodiumRoot: Instance? = FindPath(SurfaceGuiInstance, PODIUM_PATH)
	if not PodiumRoot then
		PodiumRoot = FindNamedDescendant(SurfaceGuiInstance, "Podium", "Frame")
	end
	if not PodiumRoot then
		return
	end

	for RankNumber: number = 1, PODIUM_LIMIT do
		local PodiumSlot: Instance? = PodiumRoot:FindFirstChild("#" .. tostring(RankNumber))
		if not PodiumSlot then
			PodiumSlot = FindNamedDescendant(PodiumRoot, "#" .. tostring(RankNumber), nil)
		end
		local Entry: BoardEntry? = Entries[RankNumber]
		SetImage(
			PodiumSlot and (PodiumSlot:FindFirstChild("UserIMG") or FindNamedDescendant(PodiumSlot, "UserIMG", nil)),
			if Entry then Entry.Thumbnail else EMPTY_IMAGE
		)
	end
end

local function FindRankModel(CharactersFolder: Instance, RankNumber: number): Model?
	for _, Child in CharactersFolder:GetChildren() do
		if not Child:IsA("Model") then
			continue
		end

		local RankValue: any = Child:GetAttribute(RANK_ATTR)
		if typeof(RankValue) ~= "number" then
			continue
		end
		if math.floor(RankValue) ~= RankNumber then
			continue
		end

		return Child
	end

	return nil
end

local function RenderCharacterPodium(BoardModel: Model, Entries: {BoardEntry}): ()
	local CharactersFolder: Instance? = BoardModel:FindFirstChild("Characters")
	if not CharactersFolder then
		CharactersFolder = BoardModel:FindFirstChild("Characters", true)
	end
	if not CharactersFolder then
		return
	end

	for RankNumber: number = 1, PODIUM_LIMIT do
		local CharacterModel: Model? = FindRankModel(CharactersFolder, RankNumber)
		if not CharacterModel then
			continue
		end

		local Entry: BoardEntry? = Entries[RankNumber]
		local PlayerName: string = if Entry then Entry.Name else EMPTY_PLAYER_NAME
		local NameLabel: Instance? = FindPath(CharacterModel, NAME_LABEL_PATH)
		if not NameLabel then
			NameLabel = FindNamedDescendant(CharacterModel, "PlayerName", "TextLabel")
		end
		SetTextLabel(NameLabel, PlayerName)

		if not Entry then
			continue
		end

		LobbyAvatars.ApplyUser(CharacterModel, Entry.UserId)
	end
end

local function ReadFallbackTopEntries(BoardType: string): {BoardEntry}
	local Definition: RankStats.BoardDef? = RankStats.GetBoardDef(BoardType)
	if not Definition then
		return {}
	end

	local Entries: {BoardEntry} = {}
	for _, PlayerInstance in PlayersService:GetPlayers() do
		if PlayerInstance.UserId <= 0 then
			continue
		end

		local Value, HasData = PlayerDataGuard.GetOrDefault(PlayerInstance, { Definition.StatName }, 0)
		if not HasData then
			continue
		end

		local Score: number = ClampValue(Value)
		if Score <= 0 then
			continue
		end

		table.insert(Entries, {
			UserId = PlayerInstance.UserId,
			Score = Score,
			Name = PlayerInstance.Name,
			Thumbnail = LobbyAvatars.GetThumbnail(PlayerInstance.UserId),
		})
	end

	table.sort(Entries, function(Left: BoardEntry, Right: BoardEntry): boolean
		if Left.Score == Right.Score then
			return Left.UserId < Right.UserId
		end

		return Left.Score > Right.Score
	end)

	while #Entries > MAX_ENTRY_FETCH_LIMIT do
		table.remove(Entries)
	end

	return Entries
end

local function ReadTopEntries(BoardType: string): {BoardEntry}
	if not OrderedLeaderboardsEnabled then
		return ReadFallbackTopEntries(BoardType)
	end

	FlushOrderedWrites(BoardType)
	if not OrderedLeaderboardsEnabled then
		return ReadFallbackTopEntries(BoardType)
	end

	local OrderedStore: OrderedDataStore = GetOrderedStore(BoardType)
	local Success: boolean, PagesOrError: any = pcall(OrderedStore.GetSortedAsync, OrderedStore, false, MAX_ENTRY_FETCH_LIMIT)
	if not Success then
		if IsOrderedLeaderboardAccessForbidden(PagesOrError) then
			DisableOrderedLeaderboards(PagesOrError)
			return ReadFallbackTopEntries(BoardType)
		end
		warn(string.format("LeaderboardService failed to fetch %s: %s", BoardType, tostring(PagesOrError)))
		return ReadFallbackTopEntries(BoardType)
	end

	local Pages: DataStorePages = PagesOrError
	local PageSuccess: boolean, RawPageOrError: any = pcall(Pages.GetCurrentPage, Pages)
	if not PageSuccess then
		warn(string.format("LeaderboardService failed to read page for %s: %s", BoardType, tostring(RawPageOrError)))
		return ReadFallbackTopEntries(BoardType)
	end

	local RawPage: {any} = RawPageOrError
	local Entries: {BoardEntry} = {}
	for _, RawEntry in RawPage do
		local UserId: number = tonumber(RawEntry.key) or 0
		local Score: number = ClampValue(RawEntry.value)
		if UserId <= 0 or Score <= 0 then
			continue
		end

		table.insert(Entries, {
			UserId = UserId,
			Score = Score,
			Name = LobbyAvatars.GetUserName(UserId),
			Thumbnail = LobbyAvatars.GetThumbnail(UserId),
		})
	end

	if #Entries <= 0 then
		return ReadFallbackTopEntries(BoardType)
	end

	return Entries
end

local function RenderBoard(BoardModel: Model, BoardType: string, Entries: {BoardEntry}): ()
	for _, SurfaceTarget in GetBoardSurfaceTargets(BoardModel) do
		local RenderLimit: number = if SurfaceTarget.Variant == "Tv" then TV_TOP_LIMIT else DEFAULT_TOP_LIMIT
		RenderTitle(SurfaceTarget.SurfaceGui, BoardType, SurfaceTarget.Variant)
		RenderListEntries(SurfaceTarget.SurfaceGui, BoardType, Entries, RenderLimit)
		if SurfaceTarget.Variant == "Default" then
			RenderPodiumImages(SurfaceTarget.SurfaceGui, Entries)
		end
	end

	RenderCharacterPodium(BoardModel, Entries)
end

local function RefreshBoardType(BoardType: string): ()
	local Models: {Model}? = BoardModelsByType[BoardType]
	if not Models or #Models <= 0 then
		return
	end

	local Entries: {BoardEntry} = ReadTopEntries(BoardType)
	for _, BoardModel in Models do
		RenderBoard(BoardModel, BoardType, Entries)
	end
end

RefreshAllBoards = function(): ()
	ResolveBoards()
	for _, BoardType in RefreshTypes do
		RefreshBoardType(BoardType)
	end
end

local function BindBoardFolderConnections(): boolean
	local BoardFolder: Folder? = GetBoardFolder()
	if not BoardFolder then
		return false
	end

	if BoardFolderAddedConnection then
		BoardFolderAddedConnection:Disconnect()
		BoardFolderAddedConnection = nil
	end
	if BoardFolderRemovedConnection then
		BoardFolderRemovedConnection:Disconnect()
		BoardFolderRemovedConnection = nil
	end

	BoardFolderAddedConnection = BoardFolder.DescendantAdded:Connect(function(Descendant: Instance): ()
		if not ShouldRefreshForBoardDescendant(Descendant) then
			return
		end

		ScheduleBoardRefresh(0.15)
	end)
	BoardFolderRemovedConnection = BoardFolder.DescendantRemoving:Connect(function(Descendant: Instance): ()
		if not ShouldRefreshForBoardDescendant(Descendant) then
			return
		end

		ScheduleBoardRefresh(0.15)
	end)

	return true
end

local function FlushTimerForPlayer(PlayerInstance: Player): ()
	local PendingSeconds: number = math.floor(PendingTimerByPlayer[PlayerInstance] or 0)
	if PendingSeconds <= 0 then
		return
	end

	local Success: boolean = PlayerStatsTracker.AddTimer(PlayerInstance, PendingSeconds)
	if not Success then
		return
	end

	PendingTimerByPlayer[PlayerInstance] = math.max((PendingTimerByPlayer[PlayerInstance] or 0) - PendingSeconds, 0)
end

local function FlushTimerForPlayers(PlayerList: {Player}?): ()
	if PlayerList then
		for _, PlayerInstance in PlayerList do
			FlushTimerForPlayer(PlayerInstance)
		end
		return
	end

	for _, PlayerInstance in PlayersService:GetPlayers() do
		FlushTimerForPlayer(PlayerInstance)
	end
end

local function SyncPlayerStats(PlayerInstance: Player): ()
	if PlayerInstance.UserId <= 0 then
		return
	end

	for _, StatName in RankStats.GetStatNames() do
		local Value: any = nil
		local HasData: boolean = false
		Value, HasData = PlayerDataGuard.GetOrDefault(PlayerInstance, { StatName }, 0)
		if not HasData then
			continue
		end

		QueueOrderedWriteFromStat(StatName, PlayerInstance.UserId, ClampValue(Value))
	end
end

local function DisconnectPlayer(PlayerInstance: Player): ()
	local BoundData: BoundPlayerData? = BoundPlayers[PlayerInstance]
	if BoundData then
		for _, Handle in BoundData.Connections do
			Handle:Disconnect()
		end
	end

	BoundPlayers[PlayerInstance] = nil
end

local function BindPlayer(PlayerInstance: Player): ()
	DisconnectPlayer(PlayerInstance)

	local Connections: {DisconnectHandle} = {}
	BoundPlayers[PlayerInstance] = {
		Connections = Connections,
	}
	PendingTimerByPlayer[PlayerInstance] = PendingTimerByPlayer[PlayerInstance] or 0

	for _, StatName in RankStats.GetStatNames() do
		local CurrentStatName: string = StatName
		local Handle: DisconnectHandle = PlayerDataGuard.ConnectValueChanged(
			PlayerInstance,
			{ CurrentStatName },
			function(NewValue: any): ()
				QueueOrderedWriteFromStat(CurrentStatName, PlayerInstance.UserId, ClampValue(NewValue))
			end,
			{
				OnConnected = function(): ()
					SyncPlayerStats(PlayerInstance)
				end,
			}
		)
		table.insert(Connections, Handle)
	end

	task.defer(function(): ()
		SyncPlayerStats(PlayerInstance)
	end)
end

local function HandleMatchEnded(Result: MatchResult): ()
	local MatchPlayers: {Player} = GetCurrentMatchPlayers()
	FlushTimerForPlayers(nil)

	local WinnerTeam: number? = Result.WinnerTeam
	if not WinnerTeam then
		return
	end

	for _, PlayerInstance in MatchPlayers do
		local PlayerTeam: number? = FTPlayerService:GetPlayerTeam(PlayerInstance)
		if PlayerTeam ~= WinnerTeam then
			continue
		end

		PlayerStatsTracker.AwardWin(PlayerInstance)
	end
end

local function RunServiceLoops(): ()
	task.spawn(function(): ()
		while true do
			task.wait(TIMER_TICK_SECONDS)

			for _, PlayerInstance in PlayersService:GetPlayers() do
				PendingTimerByPlayer[PlayerInstance] = (PendingTimerByPlayer[PlayerInstance] or 0) + TIMER_TICK_SECONDS
			end

			TimerFlushElapsed += TIMER_TICK_SECONDS
			OrderedFlushElapsed += TIMER_TICK_SECONDS

			if TimerFlushElapsed >= TIMER_FLUSH_INTERVAL_SECONDS then
				FlushTimerForPlayers(nil)
				TimerFlushElapsed = 0
			end

			if OrderedFlushElapsed >= ORDERED_FLUSH_INTERVAL_SECONDS then
				FlushOrderedWrites(nil)
				OrderedFlushElapsed = 0
			end
		end
	end)

	task.spawn(function(): ()
		task.wait(STARTUP_REFRESH_DELAY_SECONDS)
		RefreshAllBoards()

		while true do
			task.wait(BOARD_REFRESH_INTERVAL_SECONDS)
			RefreshAllBoards()
		end
	end)
end

function LeaderboardService.Init(_self: typeof(LeaderboardService)): ()
	if RunService:IsStudio() and game:GetAttribute(STUDIO_LIVE_DATASTORES_ATTRIBUTE) ~= true then
		DisableOrderedLeaderboards("Studio data stores disabled", true)
	end

	ResolveBoards()
	BindBoardFolderConnections()

	if MatchEndedConnection then
		MatchEndedConnection:Disconnect()
		MatchEndedConnection = nil
	end

	local MatchEndedSignal: any = FTGameService:GetMatchEndedSignal()
	if MatchEndedSignal and MatchEndedSignal.Connect then
		MatchEndedConnection = MatchEndedSignal:Connect(HandleMatchEnded)
	end

	PlayersService.PlayerAdded:Connect(function(PlayerInstance: Player): ()
		BindPlayer(PlayerInstance)
	end)

	PlayersService.PlayerRemoving:Connect(function(PlayerInstance: Player): ()
		FlushTimerForPlayer(PlayerInstance)
		DisconnectPlayer(PlayerInstance)
		PendingTimerByPlayer[PlayerInstance] = nil
		ScheduleBoardRefresh(0.25)
	end)

	for _, PlayerInstance in PlayersService:GetPlayers() do
		BindPlayer(PlayerInstance)
	end
end

function LeaderboardService.Start(_self: typeof(LeaderboardService)): ()
	RunServiceLoops()

	task.spawn(function(): ()
		while not BindBoardFolderConnections() do
			task.wait(BOARD_BIND_RETRY_SECONDS)
		end
	end)
end

return LeaderboardService
