--!strict

local TweenService = game:GetService("TweenService")

type HighlightEffectState = {
	Highlight: Highlight,
	Mode: "off" | "solid" | "pulse",
	Tween: Tween?,
}

type HighlightOptions = {
	FillTransparency: number?,
	OutlineTransparency: number?,
	FadeInfo: TweenInfo?,
	PulseDuration: number?,
	PulseMaxTransparency: number?,
	FillColor: Color3?,
	OutlineColor: Color3?,
	Name: string?,
	Parent: Instance?,
	Highlight: Highlight?,
}

local DEFAULT_FADE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local HIGHLIGHT_PULSE_SPEED: number = 2
local HIGHLIGHT_PULSE_MIN: number = 0.2
local HIGHLIGHT_PULSE_MAX: number = 0.8

local Effects: {[string]: HighlightEffectState} = {}

local HighlightEffect = {}

local function StopEffect(effect: HighlightEffectState): ()
	if effect.Tween then
		effect.Tween:Cancel()
		effect.Tween = nil
	end
	if effect.Highlight then
		effect.Highlight.Enabled = false
	end
	effect.Mode = "off"
end

function HighlightEffect.RegisterHighlight(key: string, highlight: Highlight): ()
	return HighlightEffect.EnsureHighlight(key, {
		Highlight = highlight,
	})
end

function HighlightEffect.EnsureHighlight(key: string, options: HighlightOptions?): Highlight?
	local existing = Effects[key]
	if existing then
		StopEffect(existing)
		if existing.Highlight then
			existing.Highlight:Destroy()
		end
		Effects[key] = nil
	end

	local highlight = options and options.Highlight or Instance.new("Highlight")
	highlight.Name = options and options.Name or (key .. "Highlight")
	highlight.FillColor = if options and options.FillColor then options.FillColor else Color3.fromRGB(255, 255, 255)
	highlight.OutlineColor = if options and options.OutlineColor then options.OutlineColor else highlight.FillColor
	highlight.FillTransparency = if options and options.FillTransparency ~= nil then options.FillTransparency else 0.5
	highlight.OutlineTransparency = if options and options.OutlineTransparency ~= nil then options.OutlineTransparency else 0.5
	highlight.Enabled = false

	if options and options.Parent then
		highlight.Parent = options.Parent
	end

	Effects[key] = {
		Highlight = highlight,
		Mode = "off",
		Tween = nil,
	}

	return highlight
end

function HighlightEffect.SetHighlightMode(key: string, mode: "off" | "solid" | "pulse", options: HighlightOptions?): ()
	local effect = Effects[key]
	if not effect then return end

	StopEffect(effect)

	if mode == "off" then
		return
	end

	local highlight = effect.Highlight
	local fillTransparency = options and options.FillTransparency or 0.5
	local outlineTransparency = options and options.OutlineTransparency or 0.3

	highlight.Enabled = true
	effect.Mode = mode

	if mode == "solid" then
		local fadeInfo = options and options.FadeInfo or DEFAULT_FADE_INFO
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 1
		local tween = TweenService:Create(highlight, fadeInfo, {
			FillTransparency = fillTransparency,
			OutlineTransparency = outlineTransparency,
		})
		effect.Tween = tween
		tween:Play()
		return
	end

	if mode == "pulse" then

		local Time = os.clock()
		local Alpha = (math.sin(Time * HIGHLIGHT_PULSE_SPEED) + 1) * 0.5
		highlight.FillTransparency = HIGHLIGHT_PULSE_MIN + Alpha * (HIGHLIGHT_PULSE_MAX - HIGHLIGHT_PULSE_MIN)
	end
end

function HighlightEffect.ClearHighlight(key: string): ()
	local effect = Effects[key]
	if not effect then return end
	StopEffect(effect)
	if effect.Highlight then
		effect.Highlight:Destroy()
	end
	Effects[key] = nil
end

return HighlightEffect
