--!strict

local Lighting: Lighting = game:GetService("Lighting")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")

local HighlightEffect: any = require(ReplicatedStorage.Modules.Game.HighlightEffect)

local ImpactFrameFx = {}

local ASSETS_FOLDER_NAME: string = "Assets"
local EFFECTS_FOLDER_NAME: string = "Effects"
local BLACK_TEMPLATE_NAME: string = "ColorCorrection"
local WHITE_TEMPLATE_NAME: string = "ColorCorrection2"
local DEFAULT_SCOPE: string = "Default"
local EFFECT_NAME_PREFIX: string = "ImpactFrameFx_"
local HIGHLIGHT_KEY_PREFIX: string = "ImpactFrameFx::"

local DEFAULT_RENDER_FRAMES: number = 1
local DEFAULT_HOLD_TIME: number = 0
local DEFAULT_OUT_TIME: number = 0.1
local DEFAULT_DELAY_TIME: number = 0

local DEFAULT_HIGHLIGHT_DURATION: number = 0.14
local DEFAULT_HIGHLIGHT_FILL_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local DEFAULT_HIGHLIGHT_OUTLINE_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local DEFAULT_HIGHLIGHT_FILL_TRANSPARENCY: number = 0.72
local DEFAULT_HIGHLIGHT_OUTLINE_TRANSPARENCY: number = 0.18
local DEFAULT_HIGHLIGHT_FADE: TweenInfo = TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local IDENTITY_TINT: Color3 = Color3.new(1, 1, 1)
local DEFAULT_GREEN_TINT: Color3 = Color3.fromRGB(12, 128, 36)

type FrameStyle = "black" | "white" | "green"

type FrameStep = {
	Style: FrameStyle,
	Strength: number?,
	RenderFrames: number?,
	HoldTime: number?,
	OutTime: number?,
	DelayTime: number?,
	TintColor: Color3?,
}

type HighlightOptions = {
	Model: Model?,
	Duration: number?,
	FillColor: Color3?,
	OutlineColor: Color3?,
	FillTransparency: number?,
	OutlineTransparency: number?,
}

type SequenceOptions = {
	Scope: string?,
	Highlight: HighlightOptions?,
}

type ScopeState = {
	Token: number,
	Effects: {ColorCorrectionEffect},
}

local ScopeStates: {[string]: ScopeState} = {}

local function GetScopeKey(Scope: string?): string
	if Scope and Scope ~= "" then
		return Scope
	end
	return DEFAULT_SCOPE
end

local function GetScopeState(ScopeKey: string): ScopeState
	local Existing: ScopeState? = ScopeStates[ScopeKey]
	if Existing then
		return Existing
	end

	local Created: ScopeState = {
		Token = 0,
		Effects = {},
	}
	ScopeStates[ScopeKey] = Created
	return Created
end

local function GetEffectsFolder(): Instance?
	local AssetsFolder: Instance? = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER_NAME)
	if not AssetsFolder then
		return nil
	end
	return AssetsFolder:FindFirstChild(EFFECTS_FOLDER_NAME)
end

local function GetTemplateName(Style: FrameStyle): string
	if Style == "white" or Style == "green" then
		return WHITE_TEMPLATE_NAME
	end
	return BLACK_TEMPLATE_NAME
end

local function ResolvePreparedTintColor(Style: FrameStyle, TintColor: Color3?): Color3?
	if Style == "green" then
		return TintColor or DEFAULT_GREEN_TINT
	end
	if Style == "white" and TintColor then
		return TintColor
	end
	return nil
end

local function PrepareEffectForStyle(Effect: ColorCorrectionEffect, Style: FrameStyle, TintColor: Color3?): ()
	local PreparedTintColor: Color3? = ResolvePreparedTintColor(Style, TintColor)
	if PreparedTintColor then
		Effect.TintColor = PreparedTintColor
	end

	if Style == "green" then
		Effect.Brightness *= 0.55
		Effect.Contrast *= 0.82
	end
end

local function BuildFallbackEffect(Style: FrameStyle, TintColor: Color3?): ColorCorrectionEffect
	local Effect: ColorCorrectionEffect = Instance.new("ColorCorrectionEffect")
	Effect.Name = EFFECT_NAME_PREFIX .. GetTemplateName(Style)
	Effect.Enabled = true

	if Style == "white" or Style == "green" then
		Effect.Brightness = 0.16
		Effect.Contrast = 0.22
		Effect.Saturation = -0.08
		Effect.TintColor = Color3.fromRGB(255, 255, 255)
		PrepareEffectForStyle(Effect, Style, TintColor)
		return Effect
	end

	Effect.Brightness = -0.14
	Effect.Contrast = 0.34
	Effect.Saturation = -0.24
	Effect.TintColor = Color3.fromRGB(20, 20, 20)
	return Effect
end

local function CloneFrameEffect(Style: FrameStyle, TintColor: Color3?): ColorCorrectionEffect
	local EffectsFolder: Instance? = GetEffectsFolder()
	local TemplateName: string = GetTemplateName(Style)
	if EffectsFolder then
		local Template: Instance? = EffectsFolder:FindFirstChild(TemplateName, true)
		if Template and Template:IsA("ColorCorrectionEffect") then
			local Clone: ColorCorrectionEffect = Template:Clone()
			Clone.Name = EFFECT_NAME_PREFIX .. TemplateName
			Clone.Enabled = true
			PrepareEffectForStyle(Clone, Style, TintColor)
			return Clone
		end
	end

	return BuildFallbackEffect(Style, TintColor)
end

local function ApplyStrength(Effect: ColorCorrectionEffect, Step: FrameStep): ()
	local Strength: number? = Step.Strength
	local Alpha: number = math.clamp(Strength or 1, 0, 1)
	if Alpha >= 0.999 then
		return
	end

	Effect.Brightness *= Alpha
	Effect.Contrast *= Alpha
	Effect.Saturation *= Alpha
end

local function DestroyEffect(Effect: ColorCorrectionEffect): ()
	if Effect.Parent ~= nil then
		Effect:Destroy()
	end
end

local function ClearScopeEffects(ScopeStateValue: ScopeState): ()
	for _, Effect: ColorCorrectionEffect in ScopeStateValue.Effects do
		DestroyEffect(Effect)
	end
	table.clear(ScopeStateValue.Effects)
end

local function RemoveTrackedEffect(ScopeStateValue: ScopeState, TargetEffect: ColorCorrectionEffect): ()
	for Index: number, Effect: ColorCorrectionEffect in ScopeStateValue.Effects do
		if Effect == TargetEffect then
			table.remove(ScopeStateValue.Effects, Index)
			return
		end
	end
end

local function ClearHighlightForScope(ScopeKey: string): ()
	HighlightEffect.ClearHighlight(HIGHLIGHT_KEY_PREFIX .. ScopeKey)
end

local function WaitRenderFrames(FrameCount: number?): ()
	local TotalFrames: number = math.max(1, math.floor((FrameCount or DEFAULT_RENDER_FRAMES) + 0.5))
	for _ = 1, TotalFrames do
		RunService.RenderStepped:Wait()
	end
end

local function FadeOutEffect(Effect: ColorCorrectionEffect, Duration: number?): ()
	local OutTime: number = math.max(0, Duration or DEFAULT_OUT_TIME)
	if OutTime <= 0 then
		DestroyEffect(Effect)
		return
	end

	local TweenInstance: Tween = TweenService:Create(Effect, TweenInfo.new(OutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
	})
	TweenInstance:Play()
	task.wait(OutTime)
	TweenInstance:Destroy()
	DestroyEffect(Effect)
end

local function PlayHighlight(ScopeKey: string, Token: number, Options: HighlightOptions?): ()
	if not Options or not Options.Model or Options.Model.Parent == nil then
		return
	end

	local HighlightKey: string = HIGHLIGHT_KEY_PREFIX .. ScopeKey
	local Highlight: Highlight? = HighlightEffect.EnsureHighlight(HighlightKey, {
		Name = "ImpactFrameHighlight",
		Parent = Options.Model,
		FillColor = Options.FillColor or DEFAULT_HIGHLIGHT_FILL_COLOR,
		OutlineColor = Options.OutlineColor or DEFAULT_HIGHLIGHT_OUTLINE_COLOR,
		FillTransparency = 1,
		OutlineTransparency = 1,
	})
	if not Highlight then
		return
	end

	HighlightEffect.SetHighlightMode(HighlightKey, "solid", {
		FillTransparency = Options.FillTransparency or DEFAULT_HIGHLIGHT_FILL_TRANSPARENCY,
		OutlineTransparency = Options.OutlineTransparency or DEFAULT_HIGHLIGHT_OUTLINE_TRANSPARENCY,
		FadeInfo = DEFAULT_HIGHLIGHT_FADE,
	})

	local Duration: number = math.max(0, Options.Duration or DEFAULT_HIGHLIGHT_DURATION)
	task.delay(Duration, function()
		local ScopeStateValue: ScopeState? = ScopeStates[ScopeKey]
		if not ScopeStateValue or ScopeStateValue.Token ~= Token then
			return
		end
		ClearHighlightForScope(ScopeKey)
	end)
end

local function CloneOptions(Options: any): {[string]: any}
	if type(Options) == "table" then
		return table.clone(Options)
	end
	return {}
end

local function RunStep(ScopeStateValue: ScopeState, Token: number, Step: FrameStep): boolean
	if ScopeStateValue.Token ~= Token then
		return false
	end

	ClearScopeEffects(ScopeStateValue)

	local Effect: ColorCorrectionEffect = CloneFrameEffect(Step.Style, Step.TintColor)
	ApplyStrength(Effect, Step)
	Effect.Parent = Lighting
	table.insert(ScopeStateValue.Effects, Effect)

	WaitRenderFrames(Step.RenderFrames)
	if ScopeStateValue.Token ~= Token then
		return false
	end

	local HoldTime: number = math.max(0, Step.HoldTime or DEFAULT_HOLD_TIME)
	if HoldTime > 0 then
		task.wait(HoldTime)
	end
	if ScopeStateValue.Token ~= Token then
		return false
	end

	FadeOutEffect(Effect, Step.OutTime)
	RemoveTrackedEffect(ScopeStateValue, Effect)

	if ScopeStateValue.Token ~= Token then
		return false
	end

	local DelayTime: number = math.max(0, Step.DelayTime or DEFAULT_DELAY_TIME)
	if DelayTime > 0 then
		task.wait(DelayTime)
	end

	return ScopeStateValue.Token == Token
end

function ImpactFrameFx.PlaySequence(Steps: {FrameStep}, Options: SequenceOptions?): ()
	local ScopeKey: string = GetScopeKey(if Options then Options.Scope else nil)
	local ScopeStateValue: ScopeState = GetScopeState(ScopeKey)
	ScopeStateValue.Token += 1
	local Token: number = ScopeStateValue.Token

	ClearScopeEffects(ScopeStateValue)
	ClearHighlightForScope(ScopeKey)
	PlayHighlight(ScopeKey, Token, if Options then Options.Highlight else nil)

	if #Steps <= 0 then
		return
	end

	task.spawn(function()
		for _, Step: FrameStep in Steps do
			if not RunStep(ScopeStateValue, Token, Step) then
				return
			end
		end

		if ScopeStateValue.Token == Token then
			ClearScopeEffects(ScopeStateValue)
		end
	end)
end

function ImpactFrameFx.PlaySingle(Options: any): ()
	local Style: FrameStyle = "black"
	if Options and Options.Style == "green" then
		Style = "green"
	elseif Options and Options.Style == "white" then
		Style = "white"
	end
	ImpactFrameFx.PlaySequence({
		{
			Style = Style,
			Strength = Options and Options.Strength or nil,
			RenderFrames = Options and Options.RenderFrames or nil,
			HoldTime = Options and Options.HoldTime or nil,
			OutTime = Options and Options.OutTime or nil,
			DelayTime = Options and Options.DelayTime or nil,
			TintColor = Options and Options.TintColor or nil,
		},
	}, Options)
end

function ImpactFrameFx.PlayBlack(Options: any): ()
	local Resolved: {[string]: any} = CloneOptions(Options)
	Resolved.Style = "black"
	ImpactFrameFx.PlaySingle(Resolved)
end

function ImpactFrameFx.PlayWhite(Options: any): ()
	local Resolved: {[string]: any} = CloneOptions(Options)
	Resolved.Style = "white"
	ImpactFrameFx.PlaySingle(Resolved)
end

function ImpactFrameFx.PlayGreen(Options: any): ()
	local Resolved: {[string]: any} = CloneOptions(Options)
	Resolved.Style = "green"
	ImpactFrameFx.PlaySingle(Resolved)
end

function ImpactFrameFx.PlayHold(Options: any): ()
	local HoldTime: number = if Options and Options.HoldTime ~= nil then Options.HoldTime else 0.08
	local Resolved: {[string]: any} = CloneOptions(Options)
	Resolved.HoldTime = HoldTime
	ImpactFrameFx.PlaySingle(Resolved)
end

function ImpactFrameFx.PlayCombo(Options: any): ()
	local FirstStyle: FrameStyle = "white"
	if Options and Options.FirstStyle == "black" then
		FirstStyle = "black"
	elseif Options and Options.FirstStyle == "green" then
		FirstStyle = "green"
	end

	local SecondStyle: FrameStyle = "black"
	if Options and Options.SecondStyle == "white" then
		SecondStyle = "white"
	elseif Options and Options.SecondStyle == "green" then
		SecondStyle = "green"
	end
	local GapTime: number = if Options and Options.GapTime ~= nil then Options.GapTime else 0

	ImpactFrameFx.PlaySequence({
		{
			Style = FirstStyle,
			Strength = Options and Options.FirstStrength or nil,
			RenderFrames = Options and Options.FirstRenderFrames or nil,
			HoldTime = Options and Options.FirstHoldTime or nil,
			OutTime = Options and Options.FirstOutTime or nil,
			DelayTime = GapTime,
			TintColor = Options and Options.FirstTintColor or Options and Options.TintColor or nil,
		},
		{
			Style = SecondStyle,
			Strength = Options and Options.SecondStrength or nil,
			RenderFrames = Options and Options.SecondRenderFrames or nil,
			HoldTime = Options and Options.SecondHoldTime or nil,
			OutTime = Options and Options.SecondOutTime or nil,
			DelayTime = Options and Options.SecondDelayTime or nil,
			TintColor = Options and Options.SecondTintColor or Options and Options.TintColor or nil,
		},
	}, Options)
end

function ImpactFrameFx.PlayAlternating(Options: any): ()
	local Count: number = math.max(1, math.floor((Options and Options.Count or 2) + 0.5))
	local FirstStyle: FrameStyle = "white"
	if Options and Options.FirstStyle == "black" then
		FirstStyle = "black"
	elseif Options and Options.FirstStyle == "green" then
		FirstStyle = "green"
	end

	local SecondStyle: FrameStyle = if FirstStyle == "white" then "black" else "white"
	if Options and Options.SecondStyle == "white" then
		SecondStyle = "white"
	elseif Options and Options.SecondStyle == "green" then
		SecondStyle = "green"
	elseif Options and Options.SecondStyle == "black" then
		SecondStyle = "black"
	end

	local Steps: {FrameStep} = {}
	for Index: number = 1, Count do
		local IsFirst: boolean = (Index % 2) == 1
		table.insert(Steps, {
			Style = if IsFirst then FirstStyle else SecondStyle,
			Strength = if IsFirst then (Options and Options.FirstStrength or Options and Options.Strength or nil) else (Options and Options.SecondStrength or Options and Options.Strength or nil),
			RenderFrames = Options and Options.RenderFrames or nil,
			HoldTime = Options and Options.HoldTime or nil,
			OutTime = Options and Options.OutTime or nil,
			DelayTime = Options and Options.GapTime or nil,
			TintColor = if IsFirst then (Options and Options.FirstTintColor or Options and Options.TintColor or nil) else (Options and Options.SecondTintColor or Options and Options.TintColor or nil),
		})
	end

	ImpactFrameFx.PlaySequence(Steps, Options)
end

function ImpactFrameFx.ClearScope(Scope: string?): ()
	local ScopeKey: string = GetScopeKey(Scope)
	local ScopeStateValue: ScopeState = GetScopeState(ScopeKey)
	ScopeStateValue.Token += 1
	ClearScopeEffects(ScopeStateValue)
	ClearHighlightForScope(ScopeKey)
end

function ImpactFrameFx.Cleanup(): ()
	for ScopeKey: string, ScopeStateValue: ScopeState in ScopeStates do
		ScopeStateValue.Token += 1
		ClearScopeEffects(ScopeStateValue)
		ClearHighlightForScope(ScopeKey)
	end
end

return ImpactFrameFx
