--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local WaveTransition = require(ReplicatedStorage.Modules.WaveTransition)

local LocalPlayer: Player = Players.LocalPlayer

local TRANSITION_GUI_NAME: string = "WaveTransitionGui"
local DISPLAY_ORDER: number = 20000
local ZINDEX: number = 50
local RENDER_WAIT_STEPS: number = 2
local TRANSITION_IN_INFO: TweenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local TRANSITION_WAVE_WIDTH: number = 14
local TRANSITION_DIRECTION: Vector2 = Vector2.new(1, -0.7)

type OverlayState = {
	Overlay: ScreenGui,
	Transition: any,
	AlphaValue: NumberValue,
	ChangedConnection: RBXScriptConnection,
}

local State = {
	Token = 0 :: number,
	Pending = false :: boolean,
	Covered = false :: boolean,
	OverlayState = nil :: OverlayState?,
}

local function CreateOverlay(): OverlayState?
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	local existingOverlay = playerGui:FindFirstChild(TRANSITION_GUI_NAME)
	if existingOverlay then
		existingOverlay:Destroy()
	end

	local overlay = Instance.new("ScreenGui")
	overlay.Name = TRANSITION_GUI_NAME
	overlay.IgnoreGuiInset = true
	overlay.ResetOnSpawn = false
	overlay.DisplayOrder = DISPLAY_ORDER
	overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	overlay.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "WaveContainer"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromScale(1, 1)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.ZIndex = ZINDEX
	container.Parent = overlay

	for _ = 1, RENDER_WAIT_STEPS do
		if container.AbsoluteSize.X > 0 and container.AbsoluteSize.Y > 0 then
			break
		end
		RunService.RenderStepped:Wait()
	end

	local transition = WaveTransition.new(container, {
		color = Color3.new(0, 0, 0),
		width = TRANSITION_WAVE_WIDTH,
		waveDirection = TRANSITION_DIRECTION,
	})
	for _, square in ipairs(transition.squares) do
		square.ZIndex = ZINDEX
	end

	local alphaValue = Instance.new("NumberValue")
	alphaValue.Value = 0
	transition:Update(alphaValue.Value)

	local changedConnection = alphaValue.Changed:Connect(function()
		transition:Update(alphaValue.Value)
	end)

	return {
		Overlay = overlay,
		Transition = transition,
		AlphaValue = alphaValue,
		ChangedConnection = changedConnection,
	}
end

local function DestroyOverlay(overlayState: OverlayState?): ()
	if not overlayState then
		return
	end

	overlayState.ChangedConnection:Disconnect()
	overlayState.AlphaValue:Destroy()
	overlayState.Transition:Destroy()
	overlayState.Overlay:Destroy()
end

local Coordinator = {}

function Coordinator.BeginInAsync(): number
	State.Token += 1
	local token = State.Token
	State.Pending = true
	State.Covered = false
	DestroyOverlay(State.OverlayState)
	State.OverlayState = nil

	task.spawn(function()
		local overlayState = CreateOverlay()
		if State.Token ~= token then
			DestroyOverlay(overlayState)
			return
		end
		if not overlayState then
			State.Pending = false
			State.Covered = false
			return
		end

		State.OverlayState = overlayState

		local tweenIn = TweenService:Create(overlayState.AlphaValue, TRANSITION_IN_INFO, { Value = 1 })
		tweenIn:Play()
		tweenIn.Completed:Wait()

		if State.Token ~= token or State.OverlayState ~= overlayState then
			DestroyOverlay(overlayState)
			return
		end

		State.Pending = false
		State.Covered = true
	end)

	return token
end

function Coordinator.WaitForCovered(timeout: number?, startupGrace: number?): boolean
	local graceDeadline = os.clock() + (startupGrace or 0)
	local timeoutDeadline = os.clock() + (timeout or 1.5)

	while os.clock() < timeoutDeadline do
		if State.Covered then
			return true
		end
		if not State.Pending and State.OverlayState == nil and os.clock() >= graceDeadline then
			return false
		end
		RunService.Heartbeat:Wait()
	end

	return State.Covered
end

function Coordinator.ReleaseAfterDelay(delayTime: number?): ()
	local token = State.Token
	task.spawn(function()
		task.wait(delayTime)
		if State.Token ~= token then
			return
		end

		DestroyOverlay(State.OverlayState)
		if State.Token ~= token then
			return
		end

		State.OverlayState = nil
		State.Pending = false
		State.Covered = false
	end)
end

function Coordinator.Cancel(): ()
	State.Token += 1
	State.Pending = false
	State.Covered = false
	DestroyOverlay(State.OverlayState)
	State.OverlayState = nil
end

return Coordinator
