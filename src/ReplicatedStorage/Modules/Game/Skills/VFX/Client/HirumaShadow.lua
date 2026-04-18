--!strict

local Lighting: Lighting = game:GetService("Lighting")
local TweenService: TweenService = game:GetService("TweenService")

local HirumaShadow = {}

type ShadowState = {
	Active: boolean,
	Token: number,
	Effect: ColorCorrectionEffect?,
	Tween: Tween?,
}

local ZERO: number = 0
local ONE: number = 1

local EFFECT_NAME: string = "HirumaShadowDarken"
local TWEEN_IN_TIME: number = 0.08
local TWEEN_OUT_TIME: number = 0.14
local TARGET_BRIGHTNESS: number = -0.18
local TARGET_CONTRAST: number = 0.22
local TARGET_SATURATION: number = -0.28
local TARGET_TINT: Color3 = Color3.fromRGB(190, 190, 205)
local DEFAULT_TINT: Color3 = Color3.new(ONE, ONE, ONE)

local State: ShadowState = {
	Active = false,
	Token = ZERO,
	Effect = nil,
	Tween = nil,
}

local function StopTween(): ()
	if State.Tween then
		State.Tween:Cancel()
		State.Tween:Destroy()
		State.Tween = nil
	end
end

local function DestroyEffect(): ()
	if State.Effect and State.Effect.Parent ~= nil then
		State.Effect:Destroy()
	end
	State.Effect = nil
end

local function EnsureEffect(): ColorCorrectionEffect
	local Effect: ColorCorrectionEffect? = State.Effect
	if Effect and Effect.Parent == Lighting then
		return Effect
	end

	DestroyEffect()
	Effect = Instance.new("ColorCorrectionEffect")
	Effect.Name = EFFECT_NAME
	Effect.Enabled = true
	Effect.Brightness = 0
	Effect.Contrast = 0
	Effect.Saturation = 0
	Effect.TintColor = DEFAULT_TINT
	Effect.Parent = Lighting
	State.Effect = Effect
	return Effect
end

local function TweenEffect(Duration: number, Goal: {[string]: any}, DestroyOnComplete: boolean): ()
	local Effect: ColorCorrectionEffect = EnsureEffect()
	StopTween()
	local TweenInstance: Tween =
		TweenService:Create(Effect, TweenInfo.new(Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), Goal)
	State.Tween = TweenInstance
	TweenInstance:Play()
	TweenInstance.Completed:Connect(function()
		if State.Tween == TweenInstance then
			State.Tween = nil
		end
		if DestroyOnComplete and not State.Active then
			DestroyEffect()
		end
	end)
end

function HirumaShadow.Start(Data: {[string]: any}): ()
	local Action: string = tostring(Data.Action or "")
	local Token: number = math.floor(tonumber(Data.Token) or ZERO)

	if Action == "Start" then
		State.Active = true
		State.Token = Token
		TweenEffect(TWEEN_IN_TIME, {
			Brightness = TARGET_BRIGHTNESS,
			Contrast = TARGET_CONTRAST,
			Saturation = TARGET_SATURATION,
			TintColor = TARGET_TINT,
		}, false)
		return
	end

	if Action ~= "End" then
		return
	end
	if State.Active and Token ~= State.Token then
		return
	end

	State.Active = false
	State.Token = ZERO
	TweenEffect(TWEEN_OUT_TIME, {
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
		TintColor = DEFAULT_TINT,
	}, true)
end

function HirumaShadow.Cleanup(): ()
	State.Active = false
	State.Token = ZERO
	StopTween()
	DestroyEffect()
end

return HirumaShadow
