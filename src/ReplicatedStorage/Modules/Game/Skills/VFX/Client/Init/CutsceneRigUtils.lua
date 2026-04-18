--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local CutsceneRigUtils = {}
local SkillAssetPreloader: any = require(script.Parent.Parent.Parent.Parent.Utils.SkillAssetPreloader)

local ZERO: number = 0

local ASSETS_FOLDER_NAME: string = "Assets"
local GAMEPLAY_FOLDER_NAME: string = "Gameplay"
local MODELO_FOLDER_NAME: string = "Modelo"
local TEAM_PREFIX: string = "Team"
local TEAM_HEAD_NAME: string = "Head"
local HELMET_NAME: string = "Capacete"
local HELMET_MOTOR_NAME: string = "CapaceteMotor6D"
local ACCESSORY_WELD_NAME: string = "AccessoryWeld"
local LOWPOLY_NAME: string = "Lowpoly"
local GAME_STATE_FOLDER_NAME: string = "FTGameState"
local COUNTDOWN_ACTIVE_NAME: string = "CountdownActive"
local MATCH_STARTED_NAME: string = "MatchStarted"
local PLAYER_TEAM_VALUE_PREFIX: string = "PlayerTeam_"
local COSMETIC_ATTRIBUTE_NAME: string = "IsCosmetic"

type AccessoryAppearanceMode = "All" | "HairOnly"

export type AppearanceOptions = {
	AccessoryMode: AccessoryAppearanceMode?,
}

local function NormalizeName(Name: string): string
	return string.lower(string.gsub(Name, "[%s_%-%.]", ""))
end

local function GetGameStateBoolValue(Name: string): boolean
	local GameStateFolder: Instance? = ReplicatedStorage:FindFirstChild(GAME_STATE_FOLDER_NAME)
	if not GameStateFolder then
		return false
	end

	local BoolValue: Instance? = GameStateFolder:FindFirstChild(Name)
	return BoolValue ~= nil and BoolValue:IsA("BoolValue") and BoolValue.Value == true
end

local function IsFieldAppearanceActive(): boolean
	return GetGameStateBoolValue(COUNTDOWN_ACTIVE_NAME) or GetGameStateBoolValue(MATCH_STARTED_NAME)
end

local function GetOrCreateAnimator(Parent: Instance): Animator
	local Existing: Animator? = Parent:FindFirstChildOfClass("Animator")
	if Existing then
		return Existing
	end

	local AnimatorInstance: Animator = Instance.new("Animator")
	AnimatorInstance.Parent = Parent
	return AnimatorInstance
end

local function FindHumanoidInModel(Model: Model): Humanoid?
	local DirectHumanoid: Humanoid? = Model:FindFirstChildOfClass("Humanoid")
	if DirectHumanoid then
		return DirectHumanoid
	end

	return Model:FindFirstChildWhichIsA("Humanoid", true)
end

local function FindAnimationControllerInModel(Model: Model): AnimationController?
	return Model:FindFirstChildWhichIsA("AnimationController", true)
end

local function ResolveAnimatedRigModel(Model: Model): Model
	local HumanoidInstance: Humanoid? = FindHumanoidInModel(Model)
	if HumanoidInstance and HumanoidInstance.Parent and HumanoidInstance.Parent:IsA("Model") then
		return HumanoidInstance.Parent
	end

	local AnimationControllerInstance: AnimationController? = FindAnimationControllerInModel(Model)
	if
		AnimationControllerInstance
		and AnimationControllerInstance.Parent
		and AnimationControllerInstance.Parent:IsA("Model")
	then
		return AnimationControllerInstance.Parent
	end

	return Model
end

local function FindPlayerTeamValue(SourcePlayer: Player): IntValue?
	local GameStateFolder: Instance? = ReplicatedStorage:FindFirstChild(GAME_STATE_FOLDER_NAME)
	if not GameStateFolder then
		return nil
	end

	local TeamValue: Instance? =
		GameStateFolder:FindFirstChild(PLAYER_TEAM_VALUE_PREFIX .. tostring(SourcePlayer.UserId))
	if TeamValue and TeamValue:IsA("IntValue") then
		return TeamValue
	end

	return nil
end

local function GetPlayerTeamNumber(SourcePlayer: Player): number?
	local TeamValue: IntValue? = FindPlayerTeamValue(SourcePlayer)
	if not TeamValue then
		return nil
	end
	if TeamValue.Value <= ZERO then
		return nil
	end
	return TeamValue.Value
end

local function GetTeamModel(TeamNumber: number): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	local GameplayFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(GAMEPLAY_FOLDER_NAME)
	local ModeloFolder: Instance? = GameplayFolder and GameplayFolder:FindFirstChild(MODELO_FOLDER_NAME)
	return ModeloFolder and ModeloFolder:FindFirstChild(TEAM_PREFIX .. tostring(TeamNumber))
end

local function ResolveHelmetBasePart(Source: Instance?): BasePart?
	if not Source then
		return nil
	end
	if Source:IsA("BasePart") then
		return Source
	end
	if Source:IsA("Model") then
		return Source.PrimaryPart or Source:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function FindCharacterHelmet(SourceCharacter: Model): BasePart?
	local DirectHelmet: Instance? = SourceCharacter:FindFirstChild(HELMET_NAME)
	local HelmetPart: BasePart? = ResolveHelmetBasePart(DirectHelmet)
	if HelmetPart then
		return HelmetPart
	end

	for _, Descendant in SourceCharacter:GetDescendants() do
		if NormalizeName(Descendant.Name) ~= NormalizeName(HELMET_NAME) then
			continue
		end

		HelmetPart = ResolveHelmetBasePart(Descendant)
		if HelmetPart then
			return HelmetPart
		end
	end

	return nil
end

local function FindTeamHelmetByNumber(TeamNumber: number): BasePart?
	if TeamNumber <= ZERO then
		return nil
	end

	local TeamModel: Instance? = GetTeamModel(TeamNumber)
	if not TeamModel then
		return nil
	end

	local TeamHeadSource: Instance? = TeamModel:FindFirstChild(TEAM_HEAD_NAME)
	return ResolveHelmetBasePart(TeamHeadSource)
end

local function FindTeamHelmet(SourcePlayer: Player?): BasePart?
	if not SourcePlayer then
		return nil
	end

	local TeamNumber: number? = GetPlayerTeamNumber(SourcePlayer)
	if not TeamNumber then
		return nil
	end

	return FindTeamHelmetByNumber(TeamNumber)
end

local function FindPlayerHelmetTemplate(SourcePlayer: Player?): BasePart?
	if not SourcePlayer then
		return nil
	end

	local SourceCharacter: Model? = SourcePlayer.Character
	if SourceCharacter then
		local ExistingHelmet: BasePart? = FindCharacterHelmet(SourceCharacter)
		if ExistingHelmet then
			return ExistingHelmet
		end
	end

	return FindTeamHelmet(SourcePlayer)
end

local function ClearPartAttachmentJoints(AttachedPart: BasePart): ()
	for _, Descendant in AttachedPart:GetDescendants() do
		local PreserveLowpolyJoint: boolean = false
		local Ancestor: Instance? = Descendant.Parent
		while Ancestor and Ancestor ~= AttachedPart do
			if Ancestor:IsA("MeshPart") and NormalizeName(Ancestor.Name) == NormalizeName(LOWPOLY_NAME) then
				PreserveLowpolyJoint = true
				break
			end
			Ancestor = Ancestor.Parent
		end

		if PreserveLowpolyJoint then
			continue
		end

		if
			Descendant:IsA("Motor6D")
			or Descendant:IsA("Weld")
			or Descendant:IsA("WeldConstraint")
			or Descendant:IsA("ManualWeld")
		then
			Descendant:Destroy()
		end
	end
end

local function HasTaggedAncestor(InstanceItem: Instance, StopAt: Instance?, AttributeName: string): boolean
	local Current: Instance? = InstanceItem
	while Current and Current ~= StopAt do
		if Current:GetAttribute(AttributeName) == true then
			return true
		end
		Current = Current.Parent
	end

	return false
end

local function SanitizeBasePartPhysics(Part: BasePart, ForceUnanchor: boolean?): ()
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.Massless = true
	Part.AssemblyLinearVelocity = Vector3.zero
	Part.AssemblyAngularVelocity = Vector3.zero

	if ForceUnanchor == true then
		Part.Anchored = false
	end
end

local function SanitizeInstancePhysicsRecursive(Root: Instance, ForceUnanchor: boolean?): ()
	if Root:IsA("BasePart") then
		SanitizeBasePartPhysics(Root, ForceUnanchor)
	end

	for _, Descendant in Root:GetDescendants() do
		if Descendant:IsA("BasePart") then
			SanitizeBasePartPhysics(Descendant, ForceUnanchor)
		end
	end
end

local function IsDescendantOf(Target: Instance?, Ancestor: Instance): boolean
	local Current: Instance? = Target
	while Current do
		if Current == Ancestor then
			return true
		end
		Current = Current.Parent
	end
	return false
end

local function GetAccessoryHandle(AccessoryInstance: Accessory): BasePart?
	local DirectHandle: Instance? = AccessoryInstance:FindFirstChild("Handle")
	if DirectHandle and DirectHandle:IsA("BasePart") then
		return DirectHandle
	end

	return AccessoryInstance:FindFirstChildWhichIsA("BasePart", true)
end

local function GetAccoutrementHandle(AccoutrementInstance: Instance): BasePart?
	if AccoutrementInstance:IsA("Accessory") then
		return GetAccessoryHandle(AccoutrementInstance)
	end

	local DirectHandle: Instance? = AccoutrementInstance:FindFirstChild("Handle")
	if DirectHandle and DirectHandle:IsA("BasePart") then
		return DirectHandle
	end

	return AccoutrementInstance:FindFirstChildWhichIsA("BasePart", true)
end

local function FindAccessoryAttachment(AccessoryInstance: Accessory): Attachment?
	local Handle: BasePart? = GetAccessoryHandle(AccessoryInstance)
	if not Handle then
		return nil
	end

	return Handle:FindFirstChildWhichIsA("Attachment", true)
end

local function IsHairAccessoryInstance(AccessoryInstance: Instance?): boolean
	if not AccessoryInstance or not AccessoryInstance:IsA("Accoutrement") then
		return false
	end

	if AccessoryInstance:IsA("Accessory") and AccessoryInstance.AccessoryType == Enum.AccessoryType.Hair then
		return true
	end

	if string.find(NormalizeName(AccessoryInstance.Name), "hair", 1, true) then
		return true
	end

	local Handle: BasePart? = GetAccoutrementHandle(AccessoryInstance)
	if not Handle then
		return false
	end

	for _, Descendant in Handle:GetDescendants() do
		if Descendant:IsA("Attachment") and NormalizeName(Descendant.Name) == "hairattachment" then
			return true
		end
	end

	return false
end

local function ResolveAccessoryAppearanceMode(Options: AppearanceOptions?): AccessoryAppearanceMode
	if Options and Options.AccessoryMode ~= nil then
		return Options.AccessoryMode
	end

	if IsFieldAppearanceActive() then
		return "HairOnly"
	end

	return "All"
end

local function ShouldCopyAccessory(AccessoryInstance: Accessory, Options: AppearanceOptions?): boolean
	local AccessoryMode: AccessoryAppearanceMode = ResolveAccessoryAppearanceMode(Options)
	if AccessoryMode == "All" then
		return true
	end

	return IsHairAccessoryInstance(AccessoryInstance)
end

local function FindMatchingRigAttachment(TargetRigModel: Model, AttachmentName: string): Attachment?
	for _, Descendant in TargetRigModel:GetDescendants() do
		if
			Descendant:IsA("Attachment")
			and Descendant.Name == AttachmentName
			and Descendant.Parent
			and Descendant.Parent:IsA("BasePart")
		then
			return Descendant
		end
	end

	return nil
end

local function RemoveAccessoryCharacterJoints(AccessoryInstance: Accessory): ()
	for _, Descendant in AccessoryInstance:GetDescendants() do
		if
			not (
				Descendant:IsA("Weld")
				or Descendant:IsA("ManualWeld")
				or Descendant:IsA("WeldConstraint")
				or Descendant:IsA("Motor6D")
			)
		then
			continue
		end

		local Part0: BasePart? = (Descendant :: any).Part0
		local Part1: BasePart? = (Descendant :: any).Part1
		local Part0InsideAccessory: boolean = IsDescendantOf(Part0, AccessoryInstance)
		local Part1InsideAccessory: boolean = IsDescendantOf(Part1, AccessoryInstance)
		if Descendant.Name == ACCESSORY_WELD_NAME or not (Part0InsideAccessory and Part1InsideAccessory) then
			Descendant:Destroy()
		end
	end
end

local function HasAccessoryRigJoint(AccessoryInstance: Accessory, TargetRigModel: Model): boolean
	for _, Descendant in AccessoryInstance:GetDescendants() do
		if
			not (
				Descendant:IsA("Weld")
				or Descendant:IsA("ManualWeld")
				or Descendant:IsA("WeldConstraint")
				or Descendant:IsA("Motor6D")
			)
		then
			continue
		end

		local Part0: BasePart? = (Descendant :: any).Part0
		local Part1: BasePart? = (Descendant :: any).Part1
		local Part0InsideAccessory: boolean = IsDescendantOf(Part0, AccessoryInstance)
		local Part1InsideAccessory: boolean = IsDescendantOf(Part1, AccessoryInstance)
		local RigPart: BasePart? = nil
		if Part0InsideAccessory and not Part1InsideAccessory then
			RigPart = Part1
		elseif Part1InsideAccessory and not Part0InsideAccessory then
			RigPart = Part0
		end

		if RigPart and IsDescendantOf(RigPart, TargetRigModel) then
			return true
		end
	end

	return false
end

local function CreateAccessoryWeld(TargetPart: BasePart, Handle: BasePart, C0: CFrame, C1: CFrame): ()
	for _, Child in Handle:GetChildren() do
		if Child:IsA("Weld") and Child.Name == ACCESSORY_WELD_NAME then
			Child:Destroy()
		end
	end

	local Weld: Weld = Instance.new("Weld")
	Weld.Name = ACCESSORY_WELD_NAME
	Weld.Part0 = TargetPart
	Weld.Part1 = Handle
	Weld.C0 = C0
	Weld.C1 = C1
	Weld.Parent = Handle
end

local function AttachAccessoryClone(TargetRigModel: Model, AccessoryClone: Accessory): ()
	local Handle: BasePart? = GetAccessoryHandle(AccessoryClone)
	local AccessoryAttachment: Attachment? = FindAccessoryAttachment(AccessoryClone)
	local TargetAttachment: Attachment? = if AccessoryAttachment
		then FindMatchingRigAttachment(TargetRigModel, AccessoryAttachment.Name)
		else nil
	local TargetHead: BasePart? = TargetRigModel:FindFirstChild("Head", true) :: BasePart?

	RemoveAccessoryCharacterJoints(AccessoryClone)
	AccessoryClone.Parent = TargetRigModel

	if not Handle then
		SanitizeInstancePhysicsRecursive(AccessoryClone, true)
		return
	end

	if TargetAttachment and AccessoryAttachment then
		Handle.CFrame = TargetAttachment.WorldCFrame * AccessoryAttachment.CFrame:Inverse()
		CreateAccessoryWeld(
			TargetAttachment.Parent :: BasePart,
			Handle,
			TargetAttachment.CFrame,
			AccessoryAttachment.CFrame
		)
	elseif TargetHead then
		Handle.CFrame = TargetHead.CFrame * AccessoryClone.AttachmentPoint
		CreateAccessoryWeld(TargetHead, Handle, AccessoryClone.AttachmentPoint, CFrame.new())
	end

	SanitizeInstancePhysicsRecursive(AccessoryClone, true)
end

local function AttachCosmeticModel(TargetRigModel: Model, SourceCosmeticModel: Model): ()
	local CosmeticClone: Model = SourceCosmeticModel:Clone()

	for _, Descendant in CosmeticClone:GetDescendants() do
		if Descendant:IsA("Motor6D") then
			local TargetPart: Instance? = TargetRigModel:FindFirstChild(Descendant.Name, true)
			if TargetPart and TargetPart:IsA("BasePart") then
				Descendant.Part0 = TargetPart
			end
		end
	end

	SanitizeInstancePhysicsRecursive(CosmeticClone, true)
	CosmeticClone.Parent = TargetRigModel
end

local function AttachHelmetClone(TargetRigModel: Model, HelmetTemplate: BasePart): ()
	local TargetHead: BasePart? = TargetRigModel:FindFirstChild("Head", true) :: BasePart?
	if not TargetHead then
		return
	end

	local HelmetClone: BasePart = HelmetTemplate:Clone()
	HelmetClone.Name = HELMET_NAME
	HelmetClone.Anchored = false
	HelmetClone.CanCollide = false
	HelmetClone.CanTouch = false
	HelmetClone.CanQuery = false
	HelmetClone.Massless = true
	HelmetClone.AssemblyLinearVelocity = Vector3.zero
	HelmetClone.AssemblyAngularVelocity = Vector3.zero
	HelmetClone.Parent = TargetRigModel
	HelmetClone.CFrame = TargetHead.CFrame

	CutsceneRigUtils.AttachPartToHeadWithMotor6D(TargetHead, HelmetClone, HELMET_MOTOR_NAME)
end

local function ClearActorAppearance(ActorModel: Model): ()
	local RigModel: Model = ResolveAnimatedRigModel(ActorModel)
	for _, Descendant in RigModel:GetDescendants() do
		if
			Descendant:IsA("Accessory")
			or Descendant:IsA("Shirt")
			or Descendant:IsA("Pants")
			or Descendant:IsA("ShirtGraphic")
			or Descendant:IsA("BodyColors")
			or Descendant:IsA("CharacterMesh")
			or (Descendant:IsA("BasePart") and NormalizeName(Descendant.Name) == NormalizeName(HELMET_NAME))
			or (Descendant:IsA("Motor6D") and NormalizeName(Descendant.Name) == NormalizeName(HELMET_MOTOR_NAME))
			or HasTaggedAncestor(Descendant, RigModel, COSMETIC_ATTRIBUTE_NAME)
		then
			if Descendant.Parent then
				Descendant:Destroy()
			end
		end
	end

	local Head: BasePart? = RigModel:FindFirstChild("Head", true) :: BasePart?
	if not Head then
		return
	end

	for _, Child in Head:GetChildren() do
		if Child:IsA("Decal") or Child:IsA("Texture") then
			Child:Destroy()
		end
	end
end

function CutsceneRigUtils.NormalizeName(Name: string): string
	return NormalizeName(Name)
end

function CutsceneRigUtils.FindChildByAliases(Container: Instance?, Aliases: { string }, Recursive: boolean?): Instance?
	if not Container then
		return nil
	end

	for _, Alias in Aliases do
		local Direct: Instance? = Container:FindFirstChild(Alias, Recursive == true)
		if Direct then
			return Direct
		end
	end

	local AliasLookup: { [string]: boolean } = {}
	for _, Alias in Aliases do
		AliasLookup[NormalizeName(Alias)] = true
	end

	local Candidates: { Instance } = if Recursive == true then Container:GetDescendants() else Container:GetChildren()
	for _, Child in Candidates do
		if AliasLookup[NormalizeName(Child.Name)] then
			return Child
		end
	end

	return nil
end

function CutsceneRigUtils.FindAnimationByAliases(
	Container: Instance?,
	Aliases: { string },
	Recursive: boolean?
): Animation?
	if not Container then
		return nil
	end

	for _, Alias in Aliases do
		local Direct: Instance? = Container:FindFirstChild(Alias, Recursive == true)
		if Direct and Direct:IsA("Animation") then
			return Direct
		end
	end

	local AliasLookup: { [string]: boolean } = {}
	for _, Alias in Aliases do
		AliasLookup[NormalizeName(Alias)] = true
	end

	local Candidates: { Instance } = if Recursive == true then Container:GetDescendants() else Container:GetChildren()
	for _, Child in Candidates do
		if Child:IsA("Animation") and AliasLookup[NormalizeName(Child.Name)] then
			return Child
		end
	end

	return nil
end

function CutsceneRigUtils.FindHumanoidInModel(Model: Model): Humanoid?
	return FindHumanoidInModel(Model)
end

function CutsceneRigUtils.ResolveAnimatedRigModel(Model: Model): Model
	return ResolveAnimatedRigModel(Model)
end

function CutsceneRigUtils.GetPlayerTeamNumber(SourcePlayer: Player): number?
	return GetPlayerTeamNumber(SourcePlayer)
end

local function ApplyTeamClothingByNumber(TeamNumber: number, ActorModel: Model): ()
	local TeamModel: Instance? = GetTeamModel(TeamNumber)
	if not TeamModel then
		return
	end

	local TargetRigModel: Model = ResolveAnimatedRigModel(ActorModel)

	local TeamShirt: Shirt? = TeamModel:FindFirstChildOfClass("Shirt")
	if TeamShirt then
		local ShirtInstance: Shirt? = TargetRigModel:FindFirstChildOfClass("Shirt")
		if not ShirtInstance then
			ShirtInstance = Instance.new("Shirt")
			ShirtInstance.Parent = TargetRigModel
		end
		ShirtInstance.ShirtTemplate = TeamShirt.ShirtTemplate
	end

	local TeamPants: Pants? = TeamModel:FindFirstChildOfClass("Pants")
	if TeamPants then
		local PantsInstance: Pants? = TargetRigModel:FindFirstChildOfClass("Pants")
		if not PantsInstance then
			PantsInstance = Instance.new("Pants")
			PantsInstance.Parent = TargetRigModel
		end
		PantsInstance.PantsTemplate = TeamPants.PantsTemplate
	end
end

function CutsceneRigUtils.ApplyTeamHelmet(SourcePlayer: Player?, ActorModel: Model): ()
	local TargetRigModel: Model = ResolveAnimatedRigModel(ActorModel)
	local HelmetTemplate: BasePart? = FindPlayerHelmetTemplate(SourcePlayer)
	if not HelmetTemplate then
		return
	end

	AttachHelmetClone(TargetRigModel, HelmetTemplate)
end

function CutsceneRigUtils.ApplyTeamAppearanceByNumber(TeamNumber: number, ActorModel: Model): ()
	if TeamNumber <= ZERO then
		return
	end

	ApplyTeamClothingByNumber(TeamNumber, ActorModel)

	local TargetRigModel: Model = ResolveAnimatedRigModel(ActorModel)
	local HelmetTemplate: BasePart? = FindTeamHelmetByNumber(TeamNumber)
	if not HelmetTemplate then
		return
	end

	AttachHelmetClone(TargetRigModel, HelmetTemplate)
end

function CutsceneRigUtils.AttachPartToHeadWithMotor6D(
	TargetHead: BasePart,
	AttachedPart: BasePart,
	MotorName: string?
): Motor6D
	ClearPartAttachmentJoints(AttachedPart)
	AttachedPart.CFrame = TargetHead.CFrame

	local Motor: Motor6D = Instance.new("Motor6D")
	Motor.Name = MotorName or HELMET_MOTOR_NAME
	Motor.Part0 = TargetHead
	Motor.Part1 = AttachedPart
	Motor.C0 = TargetHead.CFrame:ToObjectSpace(AttachedPart.CFrame)
	Motor.C1 = CFrame.new()
	Motor.Parent = AttachedPart

	return Motor
end

function CutsceneRigUtils.GetAnimatorFromModel(Target: Instance, PreferAnimationController: boolean?): Animator?
	if Target:IsA("Humanoid") then
		return GetOrCreateAnimator(Target)
	end

	if Target:IsA("AnimationController") then
		return GetOrCreateAnimator(Target)
	end

	if not Target:IsA("Model") then
		return nil
	end

	if PreferAnimationController == true then
		local PreferredAnimationController: AnimationController? = FindAnimationControllerInModel(Target)
		if PreferredAnimationController then
			return GetOrCreateAnimator(PreferredAnimationController)
		end
	end

	local HumanoidInstance: Humanoid? = FindHumanoidInModel(Target)
	if HumanoidInstance then
		return GetOrCreateAnimator(HumanoidInstance)
	end

	local AnimationControllerInstance: AnimationController? = FindAnimationControllerInModel(Target)
	if AnimationControllerInstance then
		return GetOrCreateAnimator(AnimationControllerInstance)
	end

	return nil
end

function CutsceneRigUtils.LoadAnimationTrack(
	Target: Instance,
	AnimationId: string,
	Priority: Enum.AnimationPriority?,
	PreferAnimationController: boolean?
): AnimationTrack?
	local AnimatorInstance: Animator? = CutsceneRigUtils.GetAnimatorFromModel(Target, PreferAnimationController)
	if not AnimatorInstance then
		return nil
	end

	if type(AnimationId) ~= "string" or AnimationId == "" then
		return nil
	end

	SkillAssetPreloader.WarmupAnimationIdsForModel(Target, { AnimationId }, PreferAnimationController)

	local AnimationInstance: Animation = Instance.new("Animation")
	AnimationInstance.AnimationId = AnimationId
	local Track: AnimationTrack = AnimatorInstance:LoadAnimation(AnimationInstance)
	AnimationInstance:Destroy()
	Track.Looped = false
	Track.Priority = Priority or Enum.AnimationPriority.Action
	return Track
end

function CutsceneRigUtils.LoadAnimationTrackFromTemplate(
	Target: Instance,
	AnimationTemplate: Animation,
	Priority: Enum.AnimationPriority?,
	PreferAnimationController: boolean?
): AnimationTrack?
	local AnimatorInstance: Animator? = CutsceneRigUtils.GetAnimatorFromModel(Target, PreferAnimationController)
	if not AnimatorInstance then
		return nil
	end

	if AnimationTemplate.AnimationId ~= "" then
		SkillAssetPreloader.WarmupAnimationIdsForModel(
			Target,
			{ AnimationTemplate.AnimationId },
			PreferAnimationController
		)
	end

	local AnimationInstance: Animation = AnimationTemplate:Clone()
	local Track: AnimationTrack = AnimatorInstance:LoadAnimation(AnimationInstance)
	AnimationInstance:Destroy()
	Track.Looped = false
	Track.Priority = Priority or Enum.AnimationPriority.Action
	return Track
end

function CutsceneRigUtils.FindModelRootPart(Model: Model): BasePart?
	local Root: BasePart? = Model:FindFirstChild("HumanoidRootPart", true) :: BasePart?
	if Root then
		return Root
	end

	local RigModel: Model = ResolveAnimatedRigModel(Model)
	if RigModel.PrimaryPart then
		return RigModel.PrimaryPart
	end
	if Model.PrimaryPart then
		return Model.PrimaryPart
	end

	return Model:FindFirstChildWhichIsA("BasePart", true)
end

function CutsceneRigUtils.PrepareAnimatedModel(Model: Model): ()
	local HumanoidInstance: Humanoid? = FindHumanoidInModel(Model)
	if HumanoidInstance then
		HumanoidInstance.AutoRotate = false
		HumanoidInstance.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		HumanoidInstance.PlatformStand = false
		HumanoidInstance.Sit = false
	end

	local RootPart: BasePart? = CutsceneRigUtils.FindModelRootPart(Model)
	for _, Descendant in Model:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		Descendant.Anchored = Descendant == RootPart
		Descendant.CanCollide = false
		Descendant.CanTouch = false
		Descendant.CanQuery = false
		Descendant.Massless = true
		Descendant.AssemblyLinearVelocity = Vector3.zero
		Descendant.AssemblyAngularVelocity = Vector3.zero
	end
end

local function ApplyCharacterAppearance(SourceCharacter: Model, ActorModel: Model, Options: AppearanceOptions?): ()
	local TargetRigModel: Model = ResolveAnimatedRigModel(ActorModel)
	ClearActorAppearance(ActorModel)

	local SourceBodyColors: BodyColors? = SourceCharacter:FindFirstChildOfClass("BodyColors")
	if SourceBodyColors then
		local BodyColorsClone: BodyColors = SourceBodyColors:Clone()
		BodyColorsClone.Parent = TargetRigModel
	end

	for _, SourceChild in SourceCharacter:GetChildren() do
		if SourceChild:IsA("Shirt") or SourceChild:IsA("Pants") or SourceChild:IsA("ShirtGraphic") then
			local Clone: Instance = SourceChild:Clone()
			Clone.Parent = TargetRigModel
		end
	end

	for _, SourceChild in SourceCharacter:GetChildren() do
		if not SourceChild:IsA("CharacterMesh") then
			continue
		end

		local Clone: CharacterMesh = SourceChild:Clone()
		Clone.Parent = TargetRigModel
	end

	local TargetHumanoid: Humanoid? = FindHumanoidInModel(TargetRigModel)
	for _, SourceChild in SourceCharacter:GetChildren() do
		if not SourceChild:IsA("Accessory") then
			continue
		end
		if not ShouldCopyAccessory(SourceChild, Options) then
			continue
		end

		local AccessoryClone: Accessory = SourceChild:Clone()
		if TargetHumanoid then
			local AttachedWithHumanoid: boolean = pcall(function()
				TargetHumanoid:AddAccessory(AccessoryClone)
			end)
			if AttachedWithHumanoid and HasAccessoryRigJoint(AccessoryClone, TargetRigModel) then
				SanitizeInstancePhysicsRecursive(AccessoryClone, true)
			else
				AttachAccessoryClone(TargetRigModel, AccessoryClone)
			end
		else
			AttachAccessoryClone(TargetRigModel, AccessoryClone)
		end
	end

	for _, SourceChild in SourceCharacter:GetChildren() do
		if not SourceChild:IsA("Model") then
			continue
		end
		if SourceChild:GetAttribute(COSMETIC_ATTRIBUTE_NAME) ~= true then
			continue
		end

		AttachCosmeticModel(TargetRigModel, SourceChild)
	end

	for _, SourceDescendant in SourceCharacter:GetDescendants() do
		if not SourceDescendant:IsA("BasePart") then
			continue
		end
		if SourceDescendant:FindFirstAncestorOfClass("Accessory") then
			continue
		end
		if HasTaggedAncestor(SourceDescendant, SourceCharacter, COSMETIC_ATTRIBUTE_NAME) then
			continue
		end

		local TargetPart: Instance? = TargetRigModel:FindFirstChild(SourceDescendant.Name, true)
		if TargetPart and TargetPart:IsA("BasePart") then
			TargetPart.Color = SourceDescendant.Color
		end
	end

	local SourceHead: BasePart? = SourceCharacter:FindFirstChild("Head", true) :: BasePart?
	local TargetHead: BasePart? = TargetRigModel:FindFirstChild("Head", true) :: BasePart?
	if not SourceHead or not TargetHead then
		SanitizeInstancePhysicsRecursive(TargetRigModel)
		return
	end

	for _, SourceChild in SourceHead:GetChildren() do
		if SourceChild:IsA("Decal") or SourceChild:IsA("Texture") then
			local FaceClone: Instance = SourceChild:Clone()
			FaceClone.Parent = TargetHead
		end
	end

	SanitizeInstancePhysicsRecursive(TargetRigModel)
end

function CutsceneRigUtils.ApplyPlayerAppearance(
	SourcePlayer: Player,
	ActorModel: Model,
	Options: AppearanceOptions?
): ()
	local SourceCharacter: Model? = SourcePlayer.Character
	if not SourceCharacter then
		return
	end

	ApplyCharacterAppearance(SourceCharacter, ActorModel, Options)
	CutsceneRigUtils.ApplyTeamHelmet(SourcePlayer, ActorModel)
end

function CutsceneRigUtils.ApplyModelAppearance(SourceModel: Model, ActorModel: Model, Options: AppearanceOptions?): ()
	ApplyCharacterAppearance(SourceModel, ActorModel, Options)
end

function CutsceneRigUtils.IsHairAccessory(AccessoryInstance: Instance?): boolean
	return IsHairAccessoryInstance(AccessoryInstance)
end

function CutsceneRigUtils.MoveInstanceToPosition(InstanceItem: Instance, Position: Vector3): ()
	if InstanceItem:IsA("Model") then
		local Pivot: CFrame = InstanceItem:GetPivot()
		InstanceItem:PivotTo(Pivot + (Position - Pivot.Position))
		return
	end

	if InstanceItem:IsA("BasePart") then
		InstanceItem.CFrame += Position - InstanceItem.Position
	end
end

function CutsceneRigUtils.EmitFromAttributes(Target: Instance?): ()
	if not Target then
		return
	end

	local function Apply(Emitter: ParticleEmitter): ()
		local EmitCountValue: any = Emitter:GetAttribute("EmitCount")
			or Emitter:GetAttribute("emitcount")
			or Emitter:GetAttribute("Emitcount")
		local EmitDurationValue: any = Emitter:GetAttribute("EmitDuration")
			or Emitter:GetAttribute("emitduration")
			or Emitter:GetAttribute("Emitduration")
		local EmitCount: number = if type(EmitCountValue) == "number"
			then math.max(1, math.floor(EmitCountValue + 0.5))
			else 1

		Emitter:Emit(EmitCount)

		if type(EmitDurationValue) == "number" and EmitDurationValue > ZERO then
			Emitter.Enabled = true
			task.delay(EmitDurationValue, function()
				if Emitter.Parent == nil then
					return
				end
				Emitter.Enabled = false
			end)
		end
	end

	if Target:IsA("ParticleEmitter") then
		Apply(Target)
	end

	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("ParticleEmitter") then
			Apply(Descendant)
		end
	end
end

return CutsceneRigUtils
