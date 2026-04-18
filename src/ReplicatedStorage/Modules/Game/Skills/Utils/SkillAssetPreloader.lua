--!strict

local ContentProvider: ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillAssetPreloader = {}

local PRELOAD_TIMEOUT_SECONDS: number = 8
local PRELOAD_BATCH_SIZE: number = 32
local MAX_WARMUP_ANIMATIONS: number = 16
local ASSETS_FOLDER_NAME: string = "Assets"
local SKILLS_FOLDER_NAME: string = "Skills"
local GAMEPLAY_FOLDER_NAME: string = "Gameplay"
local GAMEPLAY_ANIMATIONS_FOLDER_NAME: string = "Animations"
local REPLICATED_ANIMS_FOLDER_NAME: string = "ReplicatedAnims"

local HARDCODED_ANIMATION_IDS: {string} = {
	"rbxassetid://95262290724141",
	"rbxassetid://80290482361953",
	"rbxassetid://112856364360709",
	"rbxassetid://130692247634665",
	"rbxassetid://133861434396390",
	"rbxassetid://99559528594805",
	"rbxassetid://81058310126191",
	"rbxassetid://138287143446844",
	"rbxassetid://89930416397899",
	"rbxassetid://90370067949767",
	"rbxassetid://89180310576323",
	"rbxassetid://110392321133932",
	"rbxassetid://127290660898054",
	"rbxassetid://75624000389909",
	"rbxassetid://94482355725357",
	"rbxassetid://71636906903127",
	"rbxassetid://90165335480707",
	"rbxassetid://93547343580033",
	"rbxassetid://107835182811910",
	"rbxassetid://92269723470797",
	"rbxassetid://108716391711708",
	"rbxassetid://135626075656395",
	"rbxassetid://121108990641515",
	"rbxassetid://85470698837607",
	"rbxassetid://79047209393791",
	"rbxassetid://118896817118038",
	"rbxassetid://86689212805396",
	"rbxassetid://108075363375540",
	"rbxassetid://99062290903472",
	"rbxassetid://116341697644287",
	"rbxassetid://137796689859898",
	"rbxassetid://108384873610738",
	"rbxassetid://117148234614030",
	"rbxassetid://93944476600675",
	"rbxassetid://73091054896777",
	"rbxassetid://98640734632647",
	"rbxassetid://134400225225538",
}

local CHARACTER_WARMUP_ANIMATION_IDS: {[string]: boolean} = {
	["rbxassetid://95262290724141"] = true,
	["rbxassetid://80290482361953"] = true,
	["rbxassetid://112856364360709"] = true,
	["rbxassetid://93944476600675"] = true,
	["rbxassetid://73091054896777"] = true,
	["rbxassetid://98640734632647"] = true,
	["rbxassetid://134400225225538"] = true,
}

local HasPreloadedAll: boolean = false
local PreloadInProgress: boolean = false
local CachedAssets: {Instance} = {}
local CachedAnimations: {Animation} = {}
local CachedCharacterWarmupAnimations: {Animation} = {}
local PendingWarmupCharacters: {[Model]: boolean} =
	setmetatable({}, { __mode = "k" }) :: {[Model]: boolean}
local WarmedAnimationIdsByAnimator: {[Animator]: {[string]: boolean}} =
	setmetatable({}, { __mode = "k" }) :: {[Animator]: {[string]: boolean}}

local function normalizeAnimationId(AnimationId: string): string
	if string.sub(AnimationId, 1, #"rbxassetid://") == "rbxassetid://" then
		return AnimationId
	end
	return "rbxassetid://" .. AnimationId
end

local function createPreloadAnimation(AnimationId: string): Animation
	local AnimationInstance: Animation = Instance.new("Animation")
	AnimationInstance.Name = "SkillAssetPreloadAnimation"
	AnimationInstance.AnimationId = normalizeAnimationId(AnimationId)
	return AnimationInstance
end

local function findHumanoidInModel(Target: Model): Humanoid?
	local DirectHumanoid: Humanoid? = Target:FindFirstChildOfClass("Humanoid")
	if DirectHumanoid then
		return DirectHumanoid
	end

	return Target:FindFirstChildWhichIsA("Humanoid", true)
end

local function findAnimationControllerInModel(Target: Model): AnimationController?
	return Target:FindFirstChildWhichIsA("AnimationController", true)
end

local function getOrCreateAnimator(Parent: Instance): Animator
	local ExistingAnimator: Animator? = Parent:FindFirstChildOfClass("Animator")
	if ExistingAnimator then
		return ExistingAnimator
	end

	local AnimatorInstance: Animator = Instance.new("Animator")
	AnimatorInstance.Parent = Parent
	return AnimatorInstance
end

local function getAnimatorFromModel(Target: Instance?, PreferAnimationController: boolean?): Animator?
	if not Target then
		return nil
	end

	if Target:IsA("Humanoid") or Target:IsA("AnimationController") then
		return getOrCreateAnimator(Target)
	end

	if not Target:IsA("Model") then
		return nil
	end

	if PreferAnimationController == true then
		local PreferredAnimationController: AnimationController? = findAnimationControllerInModel(Target)
		if PreferredAnimationController then
			return getOrCreateAnimator(PreferredAnimationController)
		end
	end

	local HumanoidInstance: Humanoid? = findHumanoidInModel(Target)
	if HumanoidInstance then
		return getOrCreateAnimator(HumanoidInstance)
	end

	local AnimationControllerInstance: AnimationController? = findAnimationControllerInModel(Target)
	if AnimationControllerInstance then
		return getOrCreateAnimator(AnimationControllerInstance)
	end

	return nil
end

local function getWarmedAnimationIds(AnimatorInstance: Animator): {[string]: boolean}
	local WarmedAnimationIds: {[string]: boolean}? = WarmedAnimationIdsByAnimator[AnimatorInstance]
	if WarmedAnimationIds then
		return WarmedAnimationIds
	end

	WarmedAnimationIds = {}
	WarmedAnimationIdsByAnimator[AnimatorInstance] = WarmedAnimationIds
	return WarmedAnimationIds
end

local function appendUniqueInstance(
	PreloadList: {Instance},
	SeenInstances: {[Instance]: boolean},
	InstanceItem: Instance?
): ()
	if not InstanceItem or SeenInstances[InstanceItem] then
		return
	end

	SeenInstances[InstanceItem] = true
	table.insert(PreloadList, InstanceItem)
end

local function appendUniqueAnimation(
	Animations: {Animation},
	SeenAnimationIds: {[string]: boolean},
	AnimationInstance: Animation
): ()
	local AnimationId: string = normalizeAnimationId(AnimationInstance.AnimationId)
	if AnimationId == "" or SeenAnimationIds[AnimationId] then
		return
	end

	SeenAnimationIds[AnimationId] = true
	table.insert(Animations, AnimationInstance)
end

local function appendHardcodedAnimations(
	PreloadList: {Instance},
	Animations: {Animation},
	SeenInstances: {[Instance]: boolean},
	SeenAnimationIds: {[string]: boolean}
): ()

	for _, AnimationId in HARDCODED_ANIMATION_IDS do
		local NormalizedAnimationId: string = normalizeAnimationId(AnimationId)
		if NormalizedAnimationId == "" or SeenAnimationIds[NormalizedAnimationId] then
			continue
		end

		local AnimationInstance: Animation = createPreloadAnimation(NormalizedAnimationId)
		appendUniqueInstance(PreloadList, SeenInstances, AnimationInstance)
		appendUniqueAnimation(Animations, SeenAnimationIds, AnimationInstance)
	end
end

local function collectAssetsFromRoot(
	Root: Instance?,
	PreloadList: {Instance},
	Animations: {Animation},
	SeenInstances: {[Instance]: boolean},
	SeenAnimationIds: {[string]: boolean}
): ()
	if not Root then
		return
	end

	for _, Descendant in Root:GetDescendants() do
		if Descendant:IsA("Animation") then
			appendUniqueInstance(PreloadList, SeenInstances, Descendant)
			appendUniqueAnimation(Animations, SeenAnimationIds, Descendant)
		elseif Descendant:IsA("ParticleEmitter")
			or Descendant:IsA("Beam")
			or Descendant:IsA("Trail")
			or Descendant:IsA("Texture")
			or Descendant:IsA("Decal")
			or Descendant:IsA("MeshPart")
			or Descendant:IsA("Sound")
		then
			appendUniqueInstance(PreloadList, SeenInstances, Descendant)
		end
	end
end

local function collectAssetsFromConfiguredFolders(): ({Instance}, {Animation})
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	local SkillsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(SKILLS_FOLDER_NAME)
	local GameplayFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(GAMEPLAY_FOLDER_NAME)
	local GameplayAnimationsFolder: Instance? =
		GameplayFolder and GameplayFolder:FindFirstChild(GAMEPLAY_ANIMATIONS_FOLDER_NAME)
	local ReplicatedAnimationsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(REPLICATED_ANIMS_FOLDER_NAME)

	local PreloadList: {Instance} = {}
	local Animations: {Animation} = {}
	local SeenInstances: {[Instance]: boolean} = {}
	local SeenAnimationIds: {[string]: boolean} = {}

	collectAssetsFromRoot(SkillsFolder, PreloadList, Animations, SeenInstances, SeenAnimationIds)
	collectAssetsFromRoot(GameplayAnimationsFolder, PreloadList, Animations, SeenInstances, SeenAnimationIds)
	collectAssetsFromRoot(ReplicatedAnimationsFolder, PreloadList, Animations, SeenInstances, SeenAnimationIds)
	appendHardcodedAnimations(PreloadList, Animations, SeenInstances, SeenAnimationIds)

	return PreloadList, Animations
end

local function warmupAnimationInstances(
	Target: Instance?,
	Animations: {Animation},
	MaxAnimations: number?,
	PreferAnimationController: boolean?
): ()
	local AnimatorInstance: Animator? = getAnimatorFromModel(Target, PreferAnimationController)
	if not AnimatorInstance then
		return
	end

	local WarmedAnimationIds: {[string]: boolean} = getWarmedAnimationIds(AnimatorInstance)
	local WarmedCount: number = 0
	for _, AnimationInstance in Animations do
		if MaxAnimations ~= nil and WarmedCount >= MaxAnimations then
			break
		end

		local NormalizedAnimationId: string = normalizeAnimationId(AnimationInstance.AnimationId)
		if WarmedAnimationIds[NormalizedAnimationId] then
			continue
		end

		local Success: boolean, TrackOrError: any = pcall(function()
			return AnimatorInstance:LoadAnimation(AnimationInstance)
		end)
		if Success and TrackOrError then
			local AnimationTrackInstance: AnimationTrack = TrackOrError :: AnimationTrack
			pcall(function()
				AnimationTrackInstance:Play(0, 0, 0)
				AnimationTrackInstance:Stop(0)
			end)
			AnimationTrackInstance:Destroy()
			WarmedAnimationIds[NormalizedAnimationId] = true
			WarmedCount += 1
		end
	end
end

local function warmupAnimations(Character: Model): ()
	warmupAnimationInstances(Character, CachedCharacterWarmupAnimations, MAX_WARMUP_ANIMATIONS, false)
end

local function waitForPreloadCompletion(TimeoutSeconds: number?): boolean
	local MaxWaitTime: number = math.max(TimeoutSeconds or PRELOAD_TIMEOUT_SECONDS, 0)
	local StartAt: number = os.clock()

	while not HasPreloadedAll and PreloadInProgress and os.clock() - StartAt < MaxWaitTime do
		task.wait(0.05)
	end

	return HasPreloadedAll
end

local function preloadAssetsInBatches(Assets: {Instance}): ()
	for Index = 1, #Assets, PRELOAD_BATCH_SIZE do
		local Batch: {Instance} = {}
		local BatchEnd: number = math.min(Index + PRELOAD_BATCH_SIZE - 1, #Assets)
		for BatchIndex = Index, BatchEnd do
			table.insert(Batch, Assets[BatchIndex])
		end

		pcall(function()
			ContentProvider:PreloadAsync(Batch)
		end)

		task.wait()
	end
end

function SkillAssetPreloader.PreloadAll(Options: {[string]: any}?): boolean
	local WaitForCompletion: boolean = Options ~= nil and Options.WaitForCompletion == true
	local TimeoutSeconds: number =
		if Options ~= nil and type(Options.TimeoutSeconds) == "number"
		then math.max(Options.TimeoutSeconds, 0)
		else PRELOAD_TIMEOUT_SECONDS

	if HasPreloadedAll then
		return true
	end
	if not PreloadInProgress then
		PreloadInProgress = true

		local assets, animations = collectAssetsFromConfiguredFolders()
		CachedAssets = assets
		CachedAnimations = animations
		CachedCharacterWarmupAnimations = {}
		for _, animation in animations do
			local AnimationId: string = normalizeAnimationId(animation.AnimationId)
			if CHARACTER_WARMUP_ANIMATION_IDS[AnimationId] then
				table.insert(CachedCharacterWarmupAnimations, animation)
			end
		end

		task.spawn(function()
			if #CachedAssets > 0 then
				preloadAssetsInBatches(CachedAssets)
			end
			HasPreloadedAll = true
			PreloadInProgress = false

			for Character in PendingWarmupCharacters do
				if Character.Parent ~= nil then
					warmupAnimations(Character)
				end
				PendingWarmupCharacters[Character] = nil
			end
		end)
	end

	if WaitForCompletion then
		return waitForPreloadCompletion(TimeoutSeconds)
	end

	return HasPreloadedAll
end

function SkillAssetPreloader.PreloadForCharacter(Character: Model?): ()
	if not Character then
		SkillAssetPreloader.PreloadAll()
		return
	end

	if HasPreloadedAll then
		warmupAnimations(Character)
		return
	end

	PendingWarmupCharacters[Character] = true
	SkillAssetPreloader.PreloadAll()
end

function SkillAssetPreloader.WarmupAnimationIdsForModel(
	Target: Instance?,
	AnimationIds: {string},
	PreferAnimationController: boolean?
): ()
	if not Target or #AnimationIds <= 0 then
		return
	end

	local AnimationInstances: {Animation} = {}
	for _, AnimationId in AnimationIds do
		if type(AnimationId) == "string" and AnimationId ~= "" then
			table.insert(AnimationInstances, createPreloadAnimation(AnimationId))
		end
	end

	warmupAnimationInstances(Target, AnimationInstances, nil, PreferAnimationController)

	for _, AnimationInstance in AnimationInstances do
		AnimationInstance:Destroy()
	end
end

function SkillAssetPreloader.IsPreloaded(): boolean
	return HasPreloadedAll
end

return SkillAssetPreloader
