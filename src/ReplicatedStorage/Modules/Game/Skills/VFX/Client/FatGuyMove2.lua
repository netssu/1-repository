--!strict

local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace: Workspace = game:GetService("Workspace")

local FOVController: any = require(ReplicatedStorage.Controllers.FOVController)

local FatGuyMove2 = {}

local REQUEST_ID_PREFIX: string = "FatGuyMove2_"
local REQUEST_PRIORITY: number = 12
local DEFAULT_DURATION: number = 1.15
local MIN_DURATION: number = 0.2
local PRE_DROP_FOV_TARGET: number = 50
local PRE_DROP_TWEEN: TweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRE_DROP_HOLD_TIME: number = 0.08
local PRE_DROP_RECOVER_BUFFER: number = 0.1
local BASE_FOV_BOOST: number = 4
local MAX_FOV_BOOST: number = 18
local RAMP_MIN_DURATION: number = 0.35
local RAMP_TWEEN_STYLE: Enum.EasingStyle = Enum.EasingStyle.Quart
local RAMP_TWEEN_DIRECTION: Enum.EasingDirection = Enum.EasingDirection.Out
local ARMOR_FOV_TARGET: number = 120
local ARMOR_FOV_TWEEN: TweenInfo = TweenInfo.new(0.42, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
local SLOWDOWN_FOV_TARGET: number = 30
local SLOWDOWN_DROP_TWEEN: TweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SLOWDOWN_HOLD_AFTER_END_TIME: number = 1
local SLOWDOWN_RECOVER_TWEEN: TweenInfo = TweenInfo.new(0.34, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

type StateType = {
	Active: boolean,
	Token: number,
	Duration: number,
	RequestId: string?,
	ArmorHoldActive: boolean,
	SlowdownActive: boolean,
	EndRecoveryScheduled: boolean,
	StoredMinZoomDistance: number?,
	StoredMaxZoomDistance: number?,
}

local LocalPlayer: Player = Players.LocalPlayer

local State: StateType = {
	Active = false,
	Token = 0,
	Duration = DEFAULT_DURATION,
	RequestId = nil,
	ArmorHoldActive = false,
	SlowdownActive = false,
	EndRecoveryScheduled = false,
	StoredMinZoomDistance = nil,
	StoredMaxZoomDistance = nil,
}

local function GetCurrentZoomDistance(): number?
	local Camera: Camera? = Workspace.CurrentCamera
	if not Camera then
		return nil
	end

	local FocusDistance: number = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude
	if FocusDistance > 0 then
		return FocusDistance
	end

	return nil
end

local function LockCameraZoomOut(): ()
	if State.StoredMinZoomDistance == nil then
		State.StoredMinZoomDistance = LocalPlayer.CameraMinZoomDistance
	end
	if State.StoredMaxZoomDistance == nil then
		State.StoredMaxZoomDistance = LocalPlayer.CameraMaxZoomDistance
	end

	local CurrentZoomDistance: number =
		GetCurrentZoomDistance()
		or State.StoredMaxZoomDistance
		or LocalPlayer.CameraMaxZoomDistance

	local LockedMaxZoomDistance: number = math.max(CurrentZoomDistance, LocalPlayer.CameraMinZoomDistance)
	LocalPlayer.CameraMaxZoomDistance = LockedMaxZoomDistance
end

local function RestoreCameraZoomOut(): ()
	if State.StoredMinZoomDistance ~= nil then
		LocalPlayer.CameraMinZoomDistance = State.StoredMinZoomDistance
	end
	if State.StoredMaxZoomDistance ~= nil then
		LocalPlayer.CameraMaxZoomDistance = State.StoredMaxZoomDistance
	end

	State.StoredMinZoomDistance = nil
	State.StoredMaxZoomDistance = nil
end

local function RemoveRequest(): ()
	if State.RequestId then
		FOVController.RemoveRequest(State.RequestId)
		State.RequestId = nil
	end
end

local function Stop(): ()
	RemoveRequest()
	RestoreCameraZoomOut()
	State.Active = false
	State.Token = 0
	State.Duration = DEFAULT_DURATION
	State.ArmorHoldActive = false
	State.SlowdownActive = false
	State.EndRecoveryScheduled = false
end

local function QueueRamp(Token: number, RequestId: string, Duration: number): ()
	task.delay(PRE_DROP_HOLD_TIME, function()
		if not State.Active or State.Token ~= Token or State.RequestId ~= RequestId then
			return
		end
		if State.ArmorHoldActive then
			return
		end

		local BaseFov: number = FOVController.GetBaseFOV()
		local RampTarget: number = BaseFov + BASE_FOV_BOOST + MAX_FOV_BOOST
		local RampDuration: number = math.max(Duration - PRE_DROP_RECOVER_BUFFER, RAMP_MIN_DURATION)

		FOVController.AddRequest(RequestId, RampTarget, REQUEST_PRIORITY, {
			TweenInfo = TweenInfo.new(RampDuration, RAMP_TWEEN_STYLE, RAMP_TWEEN_DIRECTION),
		})
	end)
end

local function Begin(Token: number, Duration: number): ()
	Stop()

	local RequestId: string = REQUEST_ID_PREFIX .. tostring(Token)
	local SkillDuration: number = math.max(Duration, MIN_DURATION)

	State.Active = true
	State.Token = Token
	State.Duration = SkillDuration
	State.RequestId = RequestId
	State.ArmorHoldActive = false
	State.SlowdownActive = false
	State.EndRecoveryScheduled = false

	LockCameraZoomOut()

	FOVController.AddRequest(RequestId, PRE_DROP_FOV_TARGET, REQUEST_PRIORITY, {
		TweenInfo = PRE_DROP_TWEEN,
	})

	QueueRamp(Token, RequestId, SkillDuration)
end

local function BeginSlowdown(Token: number): ()
	if not State.Active or State.Token ~= Token or not State.RequestId then
		return
	end

	State.ArmorHoldActive = false
	State.SlowdownActive = true

	FOVController.AddRequest(State.RequestId, SLOWDOWN_FOV_TARGET, REQUEST_PRIORITY, {
		TweenInfo = SLOWDOWN_DROP_TWEEN,
	})
end

local function BeginSlowdownRecovery(Token: number): ()
	if State.Token ~= Token or not State.RequestId or State.EndRecoveryScheduled then
		return
	end

	State.EndRecoveryScheduled = true
	local RequestId: string = State.RequestId

	task.delay(SLOWDOWN_HOLD_AFTER_END_TIME, function()
		if State.Token ~= Token or State.RequestId ~= RequestId then
			return
		end

		FOVController.AddRequest(RequestId, FOVController.GetBaseFOV(), REQUEST_PRIORITY, {
			TweenInfo = SLOWDOWN_RECOVER_TWEEN,
		})

		task.delay(SLOWDOWN_RECOVER_TWEEN.Time + 0.05, function()
			if State.Token ~= Token or State.RequestId ~= RequestId then
				return
			end

			Stop()
		end)
	end)
end

function FatGuyMove2.Start(Data: {[string]: any}): ()
	local Action: string = tostring(Data.Action or "")
	local TokenValue: any = Data.Token
	if type(TokenValue) ~= "number" then
		return
	end

	local Token: number = math.floor(TokenValue)
	if Action == "Start" then
		local DurationValue: any = Data.Duration
		local Duration: number = if type(DurationValue) == "number" then DurationValue else DEFAULT_DURATION
		Begin(Token, Duration)
		return
	end
	if Action == "ArmorActivate" and State.Token == Token then
		State.ArmorHoldActive = true
		if State.RequestId then
			FOVController.AddRequest(State.RequestId, ARMOR_FOV_TARGET, REQUEST_PRIORITY, {
				TweenInfo = ARMOR_FOV_TWEEN,
			})
		end
		return
	end
	if Action == "Slowdown" and State.Token == Token then
		BeginSlowdown(Token)
		return
	end
	if Action == "End" and State.Token == Token then
		if State.SlowdownActive then
			State.Active = false
			State.ArmorHoldActive = false
			BeginSlowdownRecovery(Token)
		else
			Stop()
		end
	end
end

function FatGuyMove2.Cleanup(): ()
	Stop()
end

return FatGuyMove2
