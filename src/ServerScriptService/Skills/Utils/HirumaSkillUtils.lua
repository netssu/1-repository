--!strict

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")

local SoundsData: any = require(ReplicatedStorage.Modules.Data.SoundsData)
local PlaySoundAt: any = require(ReplicatedStorage.Modules.Platform.PlaySoundAt)

local HirumaSkillUtils = {}

local ASSETS_FOLDER_NAME: string = "Assets"
local SKILLS_FOLDER_NAME: string = "Skills"
local HIRUMA_FOLDER_NAME: string = "Hiruma"
local GAMEPLAY_FOLDER_NAME: string = "Gameplay"
local ANIMATIONS_FOLDER_NAME: string = "Animations"
local DEFAULT_EMIT_COUNT: number = 1

local function NormalizeName(Name: string): string
	return string.lower(string.gsub(Name, "[%s_%-%.]", ""))
end

function HirumaSkillUtils.FindChildByAliases(Container: Instance?, Aliases: { string }, Recursive: boolean?): Instance?
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

function HirumaSkillUtils.GetHirumaSkillFolder(SkillName: string): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	local SkillsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(SKILLS_FOLDER_NAME)
	local HirumaFolder: Instance? = SkillsFolder and SkillsFolder:FindFirstChild(HIRUMA_FOLDER_NAME)
	if not HirumaFolder then
		return nil
	end
	return HirumaSkillUtils.FindChildByAliases(HirumaFolder, { SkillName }, false)
end

function HirumaSkillUtils.PlayConfiguredSoundAtCharacterRoot(Character: Model?, SoundKey: string, Pitch: boolean?): ()
	if not Character then
		return
	end

	local Root: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not Root then
		return
	end

	local SoundInfo: any = SoundsData.List[SoundKey]
	if type(SoundInfo) ~= "table" or type(SoundInfo.Id) ~= "number" or SoundInfo.Id <= 0 then
		return
	end

	PlaySoundAt(Root, SoundInfo.Id, SoundInfo.BaseVolume, Pitch)
end

function HirumaSkillUtils.EmitRecursive(Target: Instance?): ()
	if not Target then
		return
	end
	local function EmitParticle(Emitter: ParticleEmitter): ()
		local EmitCountValue: any = Emitter:GetAttribute("EmitCount")
			or Emitter:GetAttribute("emitcount")
			or Emitter:GetAttribute("Emitcount")
		local EmitCount: number = if type(EmitCountValue) == "number"
			then math.max(1, math.floor(EmitCountValue + 0.5))
			else DEFAULT_EMIT_COUNT
		Emitter:Emit(EmitCount)
	end

	if Target:IsA("ParticleEmitter") then
		EmitParticle(Target)
	end
	for _, Descendant in Target:GetDescendants() do
		if Descendant:IsA("ParticleEmitter") then
			EmitParticle(Descendant)
		end
	end
end

function HirumaSkillUtils.SetEffectsEnabledRecursive(Target: Instance?, Enabled: boolean): ()
	if not Target then
		return
	end
	local function Apply(Item: Instance): ()
		if Item:IsA("ParticleEmitter") or Item:IsA("Beam") or Item:IsA("Trail") or Item:IsA("Light") then
			pcall(function()
				(Item :: any).Enabled = Enabled
			end)
		end
	end
	Apply(Target)
	for _, Descendant in Target:GetDescendants() do
		Apply(Descendant)
	end
end

function HirumaSkillUtils.CloneEmitFolderOntoCharacter(EmitFolder: Instance?, Character: Model): { Instance }
	local Clones: { Instance } = {}
	if not EmitFolder then
		return Clones
	end
	for _, SourcePart in EmitFolder:GetChildren() do
		local TargetPart: Instance? = Character:FindFirstChild(SourcePart.Name, true)
		if not TargetPart then
			continue
		end
		for _, Effect in SourcePart:GetChildren() do
			local Clone: Instance = Effect:Clone()
			Clone.Parent = TargetPart
			table.insert(Clones, Clone)
		end
	end
	return Clones
end

function HirumaSkillUtils.GetGameplayAnimation(AnimationAliases: { string }): Animation?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	local GameplayFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(GAMEPLAY_FOLDER_NAME)
	local AnimationsFolder: Instance? = GameplayFolder and GameplayFolder:FindFirstChild(ANIMATIONS_FOLDER_NAME)
	if not AnimationsFolder then
		return nil
	end
	local AnimationInstance: Instance? = HirumaSkillUtils.FindChildByAliases(AnimationsFolder, AnimationAliases, true)
	return if AnimationInstance and AnimationInstance:IsA("Animation") then AnimationInstance else nil
end

function HirumaSkillUtils.PlayGameplayAnimation(
	Model: Model,
	AnimationAliases: { string },
	Speed: number?,
	StartTimePosition: number?
): AnimationTrack?
	local HumanoidInstance: Humanoid? = Model:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return nil
	end
	local AnimatorInstance: Animator? = HumanoidInstance:FindFirstChildOfClass("Animator")
	if not AnimatorInstance then
		AnimatorInstance = Instance.new("Animator")
		AnimatorInstance.Parent = HumanoidInstance
	end
	local AnimationTemplate: Animation? = HirumaSkillUtils.GetGameplayAnimation(AnimationAliases)
	if not AnimationTemplate then
		return nil
	end
	local Track: AnimationTrack = AnimatorInstance:LoadAnimation(AnimationTemplate)
	Track.Priority = Enum.AnimationPriority.Action
	Track.Looped = false
	Track:Play()
	if typeof(StartTimePosition) == "number" and StartTimePosition >= 0 then
		pcall(function()
			Track.TimePosition = StartTimePosition
		end)
	end
	if typeof(Speed) == "number" and Speed > 0 then
		Track:AdjustSpeed(Speed)
	end
	return Track
end

function HirumaSkillUtils.FadeOutAndDestroy(Targets: { Instance }, FadeDuration: number, DestroyDelay: number): ()
	local TweenInfoInstance: TweenInfo = TweenInfo.new(FadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function FadeInstance(Item: Instance): ()
		if Item:IsA("BasePart") then
			TweenService:Create(Item, TweenInfoInstance, { Transparency = 1 }):Play()
			return
		end
		if Item:IsA("Decal") or Item:IsA("Texture") then
			TweenService:Create(Item, TweenInfoInstance, { Transparency = 1 }):Play()
		end
	end

	for _, Target in Targets do
		HirumaSkillUtils.SetEffectsEnabledRecursive(Target, false)
		FadeInstance(Target)
		for _, Descendant in Target:GetDescendants() do
			FadeInstance(Descendant)
		end
		task.delay(DestroyDelay, function()
			if Target.Parent ~= nil then
				Target:Destroy()
			end
		end)
	end
end

return HirumaSkillUtils
