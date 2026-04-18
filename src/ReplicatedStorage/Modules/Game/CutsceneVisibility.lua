--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)

local CutsceneVisibility = {}

local FULL_TRANSPARENCY: number = 1
local GAMEPLAY_CIRCLE_NAMES: {string} = {
	"PlayerMarker",
	"BallMarker",
	"AimMarker",
	"Circle",
	"AimCircle",
}
local STAMINA_ATTACHMENT_NAME: string = "StaminaBarAttachment"

export type CharacterVisibilityState = {
	PartModifiers: {[BasePart]: number},
	VisualTransparencies: {[Instance]: number},
	EnabledStates: {[Instance]: boolean},
	BillboardStates: {[BillboardGui]: boolean},
}

type GameplayArtifactTracker = {
	Root: Instance?,
	Parts: {BasePart},
}

export type GameplayArtifactState = {
	PartTransparencies: {[BasePart]: number},
	BillboardStates: {[BillboardGui]: boolean},
	CachedCircleTrackers: {[string]: GameplayArtifactTracker},
	CachedStaminaCharacter: Model?,
	CachedStaminaAttachment: Instance?,
	CachedStaminaBillboards: {BillboardGui},
}

type HideCharacterOptions = {
	HideEffects: boolean?,
	HideBillboards: boolean?,
}

type HideGameplayArtifactOptions = {
	HideCircles: boolean?,
	HideLocalStaminaBar: boolean?,
}

local function NewCharacterVisibilityState(): CharacterVisibilityState
	return {
		PartModifiers = {},
		VisualTransparencies = {},
		EnabledStates = {},
		BillboardStates = {},
	}
end

local function NewGameplayArtifactState(): GameplayArtifactState
	return {
		PartTransparencies = {},
		BillboardStates = {},
		CachedCircleTrackers = {},
		CachedStaminaCharacter = nil,
		CachedStaminaAttachment = nil,
		CachedStaminaBillboards = {},
	}
end

local function TrackPartModifier(State: CharacterVisibilityState, Part: BasePart): ()
	if State.PartModifiers[Part] == nil then
		State.PartModifiers[Part] = Part.LocalTransparencyModifier
	end
	Part.LocalTransparencyModifier = FULL_TRANSPARENCY
end

local function TrackVisualTransparency(State: CharacterVisibilityState, Visual: Instance): ()
	local TransparencyVisual: any = Visual
	if State.VisualTransparencies[Visual] == nil then
		State.VisualTransparencies[Visual] = TransparencyVisual.Transparency
	end
	TransparencyVisual.Transparency = FULL_TRANSPARENCY
end

local function TrackEnabledState(State: CharacterVisibilityState, Target: Instance): ()
	local EnabledTarget: any = Target
	if State.EnabledStates[Target] == nil then
		State.EnabledStates[Target] = EnabledTarget.Enabled == true
	end
	EnabledTarget.Enabled = false
end

local function TrackBillboardState(Map: {[BillboardGui]: boolean}, Billboard: BillboardGui): ()
	if Map[Billboard] == nil then
		Map[Billboard] = Billboard.Enabled
	end
	if Billboard.Enabled then
		Billboard.Enabled = false
	end
end

local function HideCharacterDescendant(
	State: CharacterVisibilityState,
	Descendant: Instance,
	Options: HideCharacterOptions
): ()
	if Descendant:IsA("BasePart") then
		TrackPartModifier(State, Descendant)
		return
	end

	if Descendant:IsA("Decal") or Descendant:IsA("Texture") then
		TrackVisualTransparency(State, Descendant)
		return
	end

	if Options.HideBillboards ~= false and Descendant:IsA("BillboardGui") then
		TrackBillboardState(State.BillboardStates, Descendant)
		return
	end

	if Options.HideEffects == false then
		return
	end

	if Descendant:IsA("ParticleEmitter")
		or Descendant:IsA("Beam")
		or Descendant:IsA("Trail")
		or Descendant:IsA("Light")
		or Descendant:IsA("Fire")
		or Descendant:IsA("Smoke")
		or Descendant:IsA("Sparkles")
		or Descendant:IsA("Highlight")
	then
		TrackEnabledState(State, Descendant)
	end
end

local function HideMarkerPart(State: GameplayArtifactState, Part: BasePart): ()
	if State.PartTransparencies[Part] == nil then
		State.PartTransparencies[Part] = Part.Transparency
	end
	if Part.Transparency ~= FULL_TRANSPARENCY then
		Part.Transparency = FULL_TRANSPARENCY
	end
end

local function ResolvePlayersByUserIds(UserIds: {number}): {Player}
	local ResolvedPlayers: {Player} = {}
	local SeenUserIds: {[number]: boolean} = {}

	for _, UserId in UserIds do
		local RoundedUserId: number = math.floor(UserId + 0.5)
		if RoundedUserId <= 0 or SeenUserIds[RoundedUserId] then
			continue
		end

		SeenUserIds[RoundedUserId] = true
		local PlayerInstance: Player? = Players:GetPlayerByUserId(RoundedUserId)
		if PlayerInstance then
			table.insert(ResolvedPlayers, PlayerInstance)
		end
	end

	return ResolvedPlayers
end

local function AppendUniqueBasePart(Parts: {BasePart}, SeenParts: {[BasePart]: boolean}, Target: Instance): ()
	if not Target:IsA("BasePart") or SeenParts[Target] then
		return
	end

	SeenParts[Target] = true
	table.insert(Parts, Target)
end

local function AppendUniqueBillboard(
	Billboards: {BillboardGui},
	SeenBillboards: {[BillboardGui]: boolean},
	Target: Instance
): ()
	if not Target:IsA("BillboardGui") or SeenBillboards[Target] then
		return
	end

	SeenBillboards[Target] = true
	table.insert(Billboards, Target)
end

local function BuildGameplayArtifactTracker(Root: Instance): GameplayArtifactTracker
	local Parts: {BasePart} = {}
	local SeenParts: {[BasePart]: boolean} = {}

	AppendUniqueBasePart(Parts, SeenParts, Root)
	for _, Descendant in Root:GetDescendants() do
		AppendUniqueBasePart(Parts, SeenParts, Descendant)
	end

	return {
		Root = Root,
		Parts = Parts,
	}
end

local function ResolveGameplayArtifactTracker(
	State: GameplayArtifactState,
	MarkerName: string
): GameplayArtifactTracker?
	local CachedTracker: GameplayArtifactTracker? = State.CachedCircleTrackers[MarkerName]
	if CachedTracker and CachedTracker.Root and CachedTracker.Root.Parent ~= nil then
		return CachedTracker
	end

	local MarkerRoot: Instance? = workspace:FindFirstChild(MarkerName, true)
	if not MarkerRoot then
		State.CachedCircleTrackers[MarkerName] = nil
		return nil
	end

	local Tracker: GameplayArtifactTracker = BuildGameplayArtifactTracker(MarkerRoot)
	State.CachedCircleTrackers[MarkerName] = Tracker
	return Tracker
end

local function ResolveStaminaBillboards(
	State: GameplayArtifactState,
	LocalPlayer: Player
): {BillboardGui}
	local Character: Model? = LocalPlayer.Character
	if not Character then
		State.CachedStaminaCharacter = nil
		State.CachedStaminaAttachment = nil
		table.clear(State.CachedStaminaBillboards)
		return State.CachedStaminaBillboards
	end

	if State.CachedStaminaCharacter == Character
		and State.CachedStaminaAttachment ~= nil
		and State.CachedStaminaAttachment.Parent ~= nil
	then
		return State.CachedStaminaBillboards
	end

	State.CachedStaminaCharacter = Character
	State.CachedStaminaAttachment = Character:FindFirstChild(STAMINA_ATTACHMENT_NAME, true)
	table.clear(State.CachedStaminaBillboards)

	local Attachment: Instance? = State.CachedStaminaAttachment
	if not Attachment then
		return State.CachedStaminaBillboards
	end

	local SeenBillboards: {[BillboardGui]: boolean} = {}
	AppendUniqueBillboard(State.CachedStaminaBillboards, SeenBillboards, Attachment)
	for _, Descendant in Attachment:GetDescendants() do
		AppendUniqueBillboard(State.CachedStaminaBillboards, SeenBillboards, Descendant)
	end

	return State.CachedStaminaBillboards
end

function CutsceneVisibility.CreateCharacterVisibilityState(): CharacterVisibilityState
	return NewCharacterVisibilityState()
end

function CutsceneVisibility.CreateGameplayArtifactState(): GameplayArtifactState
	return NewGameplayArtifactState()
end

function CutsceneVisibility.HideCharacter(
	Character: Model?,
	ExistingState: CharacterVisibilityState?,
	Options: HideCharacterOptions?
): CharacterVisibilityState
	local State: CharacterVisibilityState = ExistingState or NewCharacterVisibilityState()
	if not Character then
		return State
	end

	local EffectiveOptions: HideCharacterOptions = Options or {}
	for _, Descendant in Character:GetDescendants() do
		HideCharacterDescendant(State, Descendant, EffectiveOptions)
	end

	return State
end

function CutsceneVisibility.HidePlayers(
	PlayersToHide: {Player},
	ExistingState: CharacterVisibilityState?,
	Options: HideCharacterOptions?
): CharacterVisibilityState
	local State: CharacterVisibilityState = ExistingState or NewCharacterVisibilityState()
	local EffectiveOptions: HideCharacterOptions = Options or {}

	for _, PlayerInstance in PlayersToHide do
		State = CutsceneVisibility.HideCharacter(PlayerInstance.Character, State, EffectiveOptions)
	end

	return State
end

function CutsceneVisibility.HidePlayersByUserIds(
	UserIds: {number},
	ExistingState: CharacterVisibilityState?,
	Options: HideCharacterOptions?
): CharacterVisibilityState
	return CutsceneVisibility.HidePlayers(ResolvePlayersByUserIds(UserIds), ExistingState, Options)
end

function CutsceneVisibility.HideMatchPlayers(
	ExistingState: CharacterVisibilityState?,
	Options: HideCharacterOptions?
): CharacterVisibilityState
	local PlayersToHide: {Player} = {}

	for _, PlayerInstance in Players:GetPlayers() do
		if MatchPlayerUtils.IsPlayerActive(PlayerInstance) then
			table.insert(PlayersToHide, PlayerInstance)
		end
	end

	return CutsceneVisibility.HidePlayers(PlayersToHide, ExistingState, Options)
end

function CutsceneVisibility.RestoreCharacters(State: CharacterVisibilityState?): ()
	if not State then
		return
	end

	for Part, PreviousModifier in State.PartModifiers do
		if Part.Parent ~= nil then
			Part.LocalTransparencyModifier = PreviousModifier
		end
	end
	table.clear(State.PartModifiers)

	for Visual, PreviousTransparency in State.VisualTransparencies do
		if Visual.Parent ~= nil then
			local TransparencyVisual: any = Visual
			TransparencyVisual.Transparency = PreviousTransparency
		end
	end
	table.clear(State.VisualTransparencies)

	for Target, PreviousEnabled in State.EnabledStates do
		if Target.Parent ~= nil then
			local EnabledTarget: any = Target
			EnabledTarget.Enabled = PreviousEnabled
		end
	end
	table.clear(State.EnabledStates)

	for Billboard, PreviousEnabled in State.BillboardStates do
		if Billboard.Parent ~= nil then
			Billboard.Enabled = PreviousEnabled
		end
	end
	table.clear(State.BillboardStates)
end

function CutsceneVisibility.HideGameplayArtifacts(
	LocalPlayer: Player?,
	ExistingState: GameplayArtifactState?,
	Options: HideGameplayArtifactOptions?
): GameplayArtifactState
	local State: GameplayArtifactState = ExistingState or NewGameplayArtifactState()
	local EffectiveOptions: HideGameplayArtifactOptions = Options or {}

	if EffectiveOptions.HideCircles ~= false then
		for _, MarkerName in GAMEPLAY_CIRCLE_NAMES do
			local MarkerTracker: GameplayArtifactTracker? = ResolveGameplayArtifactTracker(State, MarkerName)
			if not MarkerTracker then
				continue
			end

			for _, Part in MarkerTracker.Parts do
				if Part.Parent ~= nil then
					HideMarkerPart(State, Part)
				end
			end
		end
	end

	if EffectiveOptions.HideLocalStaminaBar == false or not LocalPlayer then
		return State
	end

	for _, Billboard in ResolveStaminaBillboards(State, LocalPlayer) do
		if Billboard.Parent ~= nil then
			TrackBillboardState(State.BillboardStates, Billboard)
		end
	end

	return State
end

function CutsceneVisibility.RestoreGameplayArtifacts(State: GameplayArtifactState?): ()
	if not State then
		return
	end

	for Part, PreviousTransparency in State.PartTransparencies do
		if Part.Parent ~= nil then
			Part.Transparency = PreviousTransparency
		end
	end
	table.clear(State.PartTransparencies)

	for Billboard, PreviousEnabled in State.BillboardStates do
		if Billboard.Parent ~= nil then
			Billboard.Enabled = PreviousEnabled
		end
	end
	table.clear(State.BillboardStates)

	table.clear(State.CachedCircleTrackers)
	State.CachedStaminaCharacter = nil
	State.CachedStaminaAttachment = nil
	table.clear(State.CachedStaminaBillboards)
end

return CutsceneVisibility
