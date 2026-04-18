--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local VisualFx = require(script.Parent.VisualFx)

local GoalEffects = {}

local DEFAULT_GOAL_EFFECT_NAME: string = "Yellow"
local GOAL_EFFECT_ROOT_NAME: string = "GoalEffectMain"
local GOAL_EFFECTS_FOLDER_NAME: string = "GoalEffect"
local GOAL_TIME_NAME_PREFIX: string = "GoalTime"
local VIGNETTE_GUI_NAME: string = "VignetteGui"
local VIGNETTE_OVERLAY_NAME: string = "Overlay"
local GOAL_EFFECT_LIFETIME: number = 3
local GOAL_EFFECT_DISABLE_LEAD_TIME: number = 0.15
local VIGNETTE_LIFETIME: number = 5
local VIGNETTE_FADE_INFO: TweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

export type Playback = {
	WorldEffect: Instance?,
	VignetteGui: ScreenGui?,
}

local function ResolveGoalSpawnPart(ScoringTeam: number): BasePart?
	local GameFolder: Instance? = Workspace:FindFirstChild("Game")
	if not GameFolder then
		return nil
	end

	local TargetGoalIndex: number = if ScoringTeam == 1 then 2 else if ScoringTeam == 2 then 1 else 0
	if TargetGoalIndex <= 0 then
		return nil
	end

	local GoalPart: Instance? = GameFolder:FindFirstChild(GOAL_TIME_NAME_PREFIX .. TargetGoalIndex)
	if GoalPart and GoalPart:IsA("BasePart") then
		return GoalPart
	end

	return nil
end

local function ResolveEffectTemplate(EffectName: string?): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	local GoalEffectsFolder: Instance? = AssetsFolder and AssetsFolder:FindFirstChild(GOAL_EFFECTS_FOLDER_NAME)
	if not GoalEffectsFolder then
		return nil
	end

	local VariantName: string = if typeof(EffectName) == "string" and EffectName ~= ""
		then EffectName
		else DEFAULT_GOAL_EFFECT_NAME
	local VariantFolder: Instance? = GoalEffectsFolder:FindFirstChild(VariantName)
	if not VariantFolder then
		return nil
	end

	local DirectRoot: Instance? = VariantFolder:FindFirstChild(GOAL_EFFECT_ROOT_NAME)
	if DirectRoot then
		return DirectRoot
	end

	local FallbackModel: Model? = VariantFolder:FindFirstChildWhichIsA("Model", true)
	if FallbackModel then
		return FallbackModel
	end

	local FallbackPart: BasePart? = VariantFolder:FindFirstChildWhichIsA("BasePart", true)
	if FallbackPart then
		return FallbackPart
	end

	return VisualFx.ResolveAttachmentTemplate(VariantFolder)
end

local function ResolveVignetteTemplate(PlayerGui: PlayerGui): ScreenGui?
	local DirectTemplate: Instance? = PlayerGui:FindFirstChild(VIGNETTE_GUI_NAME)
	if DirectTemplate and DirectTemplate:IsA("ScreenGui") then
		return DirectTemplate
	end

	local StarterTemplate: Instance? = StarterGui:FindFirstChild(VIGNETTE_GUI_NAME)
	if StarterTemplate and StarterTemplate:IsA("ScreenGui") then
		return StarterTemplate
	end

	return nil
end

local function CleanupLater(Target: Instance?, DelayTime: number): ()
	if not Target then
		return
	end

	task.delay(DelayTime, function(): ()
		if Target.Parent then
			Target:Destroy()
		end
	end)
end

local function DisableWorldEffect(Target: Instance?): ()
	if not Target then
		return
	end

	VisualFx.SetBillboardsEnabled(Target, false)
	VisualFx.SetTransientEffectsEnabled(Target, false)
end

local function CleanupWorldEffectLater(Target: Instance?): ()
	if not Target then
		return
	end

	local DisableDelay: number = math.max(GOAL_EFFECT_LIFETIME - GOAL_EFFECT_DISABLE_LEAD_TIME, 0)
	task.delay(DisableDelay, function(): ()
		if Target.Parent == nil then
			return
		end

		DisableWorldEffect(Target)
	end)

	CleanupLater(Target, GOAL_EFFECT_LIFETIME)
end

local function ResolveWorldEffectParent(EffectClone: Instance): Instance
	if EffectClone:IsA("Attachment") then
		return Workspace.Terrain
	end

	return Workspace
end

function GoalEffects.Play(PlayerGui: PlayerGui?, ScoringTeam: number, EffectName: string?): Playback
	local Result: Playback = {
		WorldEffect = nil,
		VignetteGui = nil,
	}

	if not PlayerGui then
		return Result
	end

	local GoalSpawnPart: BasePart? = ResolveGoalSpawnPart(ScoringTeam)
	local EffectTemplate: Instance? = ResolveEffectTemplate(EffectName)
	if GoalSpawnPart and EffectTemplate then
		local EffectClone: Instance = EffectTemplate:Clone()
		EffectClone.Parent = ResolveWorldEffectParent(EffectClone)
		VisualFx.PlaceAtWorldPosition(EffectClone, GoalSpawnPart.Position)
		VisualFx.SetBillboardsEnabled(EffectClone, true)
		VisualFx.SetTransientEffectsEnabled(EffectClone, true)
		VisualFx.EmitParticles(EffectClone)
		Result.WorldEffect = EffectClone
		CleanupWorldEffectLater(EffectClone)
	end

	local VignetteTemplate: ScreenGui? = ResolveVignetteTemplate(PlayerGui)
	if VignetteTemplate then
		local VignetteClone: ScreenGui = VignetteTemplate:Clone()
		VignetteClone.ResetOnSpawn = false
		VignetteClone.Enabled = true
		VignetteClone.Parent = PlayerGui
		Result.VignetteGui = VignetteClone

		local Overlay: Instance? = VignetteClone:FindFirstChild(VIGNETTE_OVERLAY_NAME, true)
		if Overlay and Overlay:IsA("ImageLabel") then
			Overlay.ImageTransparency = 1
			TweenService:Create(Overlay, VIGNETTE_FADE_INFO, {
				ImageTransparency = 0,
			}):Play()
		end

		CleanupLater(VignetteClone, VIGNETTE_LIFETIME)
	end

	return Result
end

function GoalEffects.Cleanup(Target: Playback?): ()
	if not Target then
		return
	end

	if Target.WorldEffect and Target.WorldEffect.Parent then
		DisableWorldEffect(Target.WorldEffect)
		Target.WorldEffect:Destroy()
	end

	if Target.VignetteGui and Target.VignetteGui.Parent then
		Target.VignetteGui:Destroy()
	end
end

return GoalEffects
