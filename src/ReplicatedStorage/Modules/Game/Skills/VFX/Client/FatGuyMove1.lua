--!strict

local Lighting: Lighting = game:GetService("Lighting")
local Workspace: Workspace = game:GetService("Workspace")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService: TweenService = game:GetService("TweenService")

local GlobalFunctions: any = require(ReplicatedStorage.Modules.Game.Skills.GlobalFunctions)
local FOVController: any = require(ReplicatedStorage.Controllers.FOVController)

local FatGuyMove1 = {}

local CHARGE_CAMERA_SHAKE_INTENSITY: number = 0.048
local CHARGE_CAMERA_SHAKE_NOISE_SPEED: number = 4.2
local BLOCK_CAMERA_SHAKE_INTENSITY: number = 0.024
local BLOCK_CAMERA_SHAKE_DURATION: number = 0.5
local BLOCK_CAMERA_SHAKE_NOISE_SPEED: number = 4.8
local REQUEST_ID_PREFIX: string = "FatGuyMove1_"
local CHARGE_REQUEST_SUFFIX: string = "_Charge"
local BLOCK_REQUEST_SUFFIX: string = "_Block"
local BLOCK_RETURN_REQUEST_SUFFIX: string = "_BlockReturn"
local CHARGE_REQUEST_PRIORITY: number = 11
local BLOCK_REQUEST_PRIORITY: number = 18
local LEVEL_ONE_FOV: number = 50
local LEVEL_TWO_FOV: number = 30
local CHARGE_LEVEL_TWEEN: TweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLOCK_PUNCH_FOV_MIN: number = 108
local BLOCK_PUNCH_FOV_MAX: number = 124
local BLOCK_SETTLE_FOV_MIN: number = 101
local BLOCK_SETTLE_FOV_MAX: number = 112
local BLOCK_SETTLE_DELAY_MIN: number = 0.08
local BLOCK_SETTLE_DELAY_MAX: number = 0.13
local BLOCK_FOV_HOLD_DURATION_MIN: number = 0.28
local BLOCK_FOV_HOLD_DURATION_MAX: number = 0.44
local BLOCK_FOV_PUNCH_TWEEN_MIN: TweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local BLOCK_FOV_PUNCH_TWEEN_MAX: TweenInfo = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local BLOCK_FOV_SETTLE_TWEEN_MIN: TweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local BLOCK_FOV_SETTLE_TWEEN_MAX: TweenInfo = TweenInfo.new(0.26, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local BLOCK_FOV_OUT_TWEEN_MIN: TweenInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local BLOCK_FOV_OUT_TWEEN_MAX: TweenInfo = TweenInfo.new(0.56, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local IMPACT_EFFECT_NAME: string = "FatGuyMove1ImpactCC"
local IMPACT_TINT: Color3 = Color3.fromRGB(255, 239, 220)
local IMPACT_TWEEN_IN_TIME: number = 0.035
local IMPACT_TWEEN_OUT_TIME: number = 0.18
local IMPACT_BRIGHTNESS_MIN: number = 0.08
local IMPACT_BRIGHTNESS_MAX: number = 0.18
local IMPACT_CONTRAST_MIN: number = 0.2
local IMPACT_CONTRAST_MAX: number = 0.42
local IMPACT_SATURATION_MIN: number = -0.08
local IMPACT_SATURATION_MAX: number = -0.22

type StateType = {
	Active: boolean,
	Token: number,
	ChargeLevel: number,
	ChargeShakeStopper: (() -> ())?,
	BlockShakeStopper: (() -> ())?,
	ChargeFovRequestId: string?,
	BlockFovRequestId: string?,
	BlockReturnFovRequestId: string?,
	BlockSequence: number,
	ImpactEffect: ColorCorrectionEffect?,
	ImpactTween: Tween?,
}

local State: StateType = {
	Active = false,
	Token = 0,
	ChargeLevel = 0,
	ChargeShakeStopper = nil,
	BlockShakeStopper = nil,
	ChargeFovRequestId = nil,
	BlockFovRequestId = nil,
	BlockReturnFovRequestId = nil,
	BlockSequence = 0,
	ImpactEffect = nil,
	ImpactTween = nil,
}

local function LerpNumber(MinValue: number, MaxValue: number, Alpha: number): number
	return MinValue + ((MaxValue - MinValue) * Alpha)
end

local function GetBlockIntensityAlpha(): number
	return math.clamp(State.ChargeLevel / 2, 0, 1)
end

local function StopImpactTween(): ()
	if State.ImpactTween then
		State.ImpactTween:Cancel()
		State.ImpactTween:Destroy()
		State.ImpactTween = nil
	end
end

local function DestroyImpactEffect(): ()
	if State.ImpactEffect and State.ImpactEffect.Parent == Lighting then
		State.ImpactEffect:Destroy()
	end
	State.ImpactEffect = nil
end

local function EnsureImpactEffect(): ColorCorrectionEffect
	local Effect: ColorCorrectionEffect? = State.ImpactEffect
	if Effect and Effect.Parent == Lighting then
		return Effect
	end

	DestroyImpactEffect()
	Effect = Instance.new("ColorCorrectionEffect")
	Effect.Name = IMPACT_EFFECT_NAME
	Effect.Enabled = true
	Effect.Brightness = 0
	Effect.Contrast = 0
	Effect.Saturation = 0
	Effect.TintColor = Color3.new(1, 1, 1)
	Effect.Parent = Lighting
	State.ImpactEffect = Effect
	return Effect
end

local function PlayImpactFrame(IntensityAlpha: number): ()
	local Effect: ColorCorrectionEffect = EnsureImpactEffect()
	local Alpha: number = math.clamp(IntensityAlpha, 0, 1)
	local TargetBrightness: number = LerpNumber(IMPACT_BRIGHTNESS_MIN, IMPACT_BRIGHTNESS_MAX, Alpha)
	local TargetContrast: number = LerpNumber(IMPACT_CONTRAST_MIN, IMPACT_CONTRAST_MAX, Alpha)
	local TargetSaturation: number = LerpNumber(IMPACT_SATURATION_MIN, IMPACT_SATURATION_MAX, Alpha)
	StopImpactTween()

	Effect.Brightness = 0
	Effect.Contrast = 0
	Effect.Saturation = 0
	Effect.TintColor = Color3.new(1, 1, 1)

	local InTween: Tween = TweenService:Create(
		Effect,
		TweenInfo.new(IMPACT_TWEEN_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Brightness = TargetBrightness,
			Contrast = TargetContrast,
			Saturation = TargetSaturation,
			TintColor = IMPACT_TINT,
		}
	)
	local OutTween: Tween = TweenService:Create(
		Effect,
		TweenInfo.new(IMPACT_TWEEN_OUT_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{
			Brightness = 0,
			Contrast = 0,
			Saturation = 0,
			TintColor = Color3.new(1, 1, 1),
		}
	)

	State.ImpactTween = InTween
	InTween:Play()
	InTween.Completed:Once(function()
		if State.ImpactTween ~= InTween then
			return
		end
		State.ImpactTween = OutTween
		OutTween:Play()
		OutTween.Completed:Once(function()
			if State.ImpactTween == OutTween then
				State.ImpactTween = nil
			end
			if not State.Active then
				DestroyImpactEffect()
			end
		end)
	end)
end

local function EnsureRequestIds(): ()
	if State.Token <= 0 then
		return
	end

	local RequestPrefix: string = REQUEST_ID_PREFIX .. tostring(State.Token)
	State.ChargeFovRequestId = RequestPrefix .. CHARGE_REQUEST_SUFFIX
	State.BlockFovRequestId = RequestPrefix .. BLOCK_REQUEST_SUFFIX
	State.BlockReturnFovRequestId = RequestPrefix .. BLOCK_RETURN_REQUEST_SUFFIX
end

local function StopChargeShake(): ()
	if State.ChargeShakeStopper then
		State.ChargeShakeStopper()
		State.ChargeShakeStopper = nil
	end
end

local function StopBlockShake(): ()
	if State.BlockShakeStopper then
		State.BlockShakeStopper()
		State.BlockShakeStopper = nil
	end
end

local function ClearChargeFovRequest(): ()
	if State.ChargeFovRequestId then
		FOVController.RemoveRequest(State.ChargeFovRequestId)
	end
end

local function ClearBlockFovRequests(): ()
	if State.BlockFovRequestId then
		FOVController.RemoveRequest(State.BlockFovRequestId)
	end
	if State.BlockReturnFovRequestId then
		FOVController.RemoveRequest(State.BlockReturnFovRequestId)
	end
end

local function StopChargePresentation(): ()
	StopChargeShake()
	ClearChargeFovRequest()
	State.ChargeLevel = 0
end

local function StopBlockPresentation(): ()
	State.BlockSequence += 1
	StopBlockShake()
	ClearBlockFovRequests()
end

local function Stop(): ()
	StopChargePresentation()
	StopBlockPresentation()
	State.Active = false
	State.Token = 0
	State.ChargeFovRequestId = nil
	State.BlockFovRequestId = nil
	State.BlockReturnFovRequestId = nil
	StopImpactTween()
	DestroyImpactEffect()
end

local function ApplyChargeLevel(Level: number): ()
	local ClampedLevel: number = math.clamp(Level, 0, 2)
	State.ChargeLevel = ClampedLevel
	EnsureRequestIds()

	if ClampedLevel <= 0 or not State.ChargeFovRequestId then
		ClearChargeFovRequest()
		return
	end

	local TargetFov: number = if ClampedLevel >= 2 then LEVEL_TWO_FOV else LEVEL_ONE_FOV
	FOVController.AddRequest(State.ChargeFovRequestId, TargetFov, CHARGE_REQUEST_PRIORITY, {
		TweenInfo = CHARGE_LEVEL_TWEEN,
	})
end

local function PlayBlockImpact(): ()
	if not State.Active then
		return
	end

	EnsureRequestIds()
	StopBlockPresentation()

	if not State.BlockFovRequestId or not State.BlockReturnFovRequestId then
		return
	end

	local BlockSequence: number = State.BlockSequence
	local BaseFov: number = FOVController.GetBaseFOV()
	local IntensityAlpha: number = GetBlockIntensityAlpha()
	local BlockPunchFov: number = LerpNumber(BLOCK_PUNCH_FOV_MIN, BLOCK_PUNCH_FOV_MAX, IntensityAlpha)
	local BlockSettleFov: number = LerpNumber(BLOCK_SETTLE_FOV_MIN, BLOCK_SETTLE_FOV_MAX, IntensityAlpha)
	local BlockSettleDelay: number = LerpNumber(BLOCK_SETTLE_DELAY_MIN, BLOCK_SETTLE_DELAY_MAX, IntensityAlpha)
	local BlockHoldDuration: number =
		LerpNumber(BLOCK_FOV_HOLD_DURATION_MIN, BLOCK_FOV_HOLD_DURATION_MAX, IntensityAlpha)
	local BlockShakeIntensity: number =
		LerpNumber(BLOCK_CAMERA_SHAKE_INTENSITY * 0.8, BLOCK_CAMERA_SHAKE_INTENSITY * 1.45, IntensityAlpha)
	local BlockPunchTween: TweenInfo =
		if IntensityAlpha >= 0.5 then BLOCK_FOV_PUNCH_TWEEN_MAX else BLOCK_FOV_PUNCH_TWEEN_MIN
	local BlockSettleTween: TweenInfo =
		if IntensityAlpha >= 0.5 then BLOCK_FOV_SETTLE_TWEEN_MAX else BLOCK_FOV_SETTLE_TWEEN_MIN
	local BlockOutTween: TweenInfo =
		if IntensityAlpha >= 0.5 then BLOCK_FOV_OUT_TWEEN_MAX else BLOCK_FOV_OUT_TWEEN_MIN

	StopChargeShake()
	PlayImpactFrame(0.6 + (IntensityAlpha * 0.4))
	FOVController.AddRequest(State.BlockFovRequestId, BlockPunchFov, BLOCK_REQUEST_PRIORITY, {
		TweenInfo = BlockPunchTween,
	})
	ClearChargeFovRequest()
	State.ChargeLevel = 0

	local Camera: Camera? = Workspace.CurrentCamera
	if Camera then
		State.BlockShakeStopper = GlobalFunctions.StartCameraShake(
			Camera,
			BlockShakeIntensity,
			BLOCK_CAMERA_SHAKE_DURATION,
			BLOCK_CAMERA_SHAKE_NOISE_SPEED
		)
	end

	task.delay(BlockSettleDelay, function()
		if not State.Active or State.BlockSequence ~= BlockSequence then
			return
		end
		if not State.BlockFovRequestId then
			return
		end

		FOVController.AddRequest(State.BlockFovRequestId, BlockSettleFov, BLOCK_REQUEST_PRIORITY, {
			TweenInfo = BlockSettleTween,
		})
	end)

	task.delay(BlockHoldDuration, function()
		if not State.Active or State.BlockSequence ~= BlockSequence then
			return
		end
		if not State.BlockFovRequestId or not State.BlockReturnFovRequestId then
			return
		end

		FOVController.RemoveRequest(State.BlockFovRequestId)
		FOVController.AddRequest(State.BlockReturnFovRequestId, BaseFov, BLOCK_REQUEST_PRIORITY - 1, {
			TweenInfo = BlockOutTween,
			Duration = BlockOutTween.Time,
		})
	end)
end

local function StartCharge(Token: number, Level: number): ()
	Stop()

	State.Active = true
	State.Token = Token
	State.ChargeLevel = 0
	EnsureRequestIds()

	local Camera: Camera? = Workspace.CurrentCamera
	if Camera then
		State.ChargeShakeStopper = GlobalFunctions.StartCameraShake(
			Camera,
			CHARGE_CAMERA_SHAKE_INTENSITY,
			0,
			CHARGE_CAMERA_SHAKE_NOISE_SPEED
		)
	end

	ApplyChargeLevel(Level)
end

function FatGuyMove1.Start(Data: {[string]: any}): ()
	local Action: string = tostring(Data.Action or "")
	local TokenValue: any = Data.Token
	if type(TokenValue) ~= "number" then
		return
	end

	local Token: number = math.floor(TokenValue)
	if Action == "Start" then
		local LevelValue: any = Data.Level
		local InitialLevel: number = if type(LevelValue) == "number" then math.floor(LevelValue) else 0
		StartCharge(Token, InitialLevel)
		return
	end

	if State.Token ~= Token then
		return
	end

	if Action == "ChargeLevel" then
		local LevelValue: any = Data.Level
		if type(LevelValue) == "number" then
			ApplyChargeLevel(math.floor(LevelValue))
		end
		return
	end

	if Action == "Jump" then
		StopChargeShake()
		return
	end

	if Action == "Block" then
		PlayBlockImpact()
		return
	end

	if Action == "End" then
		Stop()
	end
end

function FatGuyMove1.Cleanup(): ()
	Stop()
end

return FatGuyMove1
