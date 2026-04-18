local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Framework = require(ReplicatedStorage.Framework)
local Controllers = ReplicatedStorage:WaitForChild("Controllers")
local CameraController = require(Controllers:WaitForChild("CameraController"))
local GameplayGuiController = require(Controllers:WaitForChild("GameplayGuiController"))
local SpinController = require(Controllers:WaitForChild("SpinController"))

local ProximityPromptService = game:GetService("ProximityPromptService")
local PlayerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local ContextActionService = game:GetService("ContextActionService")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
GameplayGuiController.Start()

local RUN_KEY_PRIMARY = Enum.KeyCode.LeftControl
local RUN_KEY_SECONDARY = Enum.KeyCode.RightControl
local RUN_INPUT_BRIDGE_ACTION = "FTMainRunInputBridge"
local RUN_INPUT_BRIDGE_VERSION = "SingleSourceV3"
local RUN_INPUT_BRIDGE_FALLBACK_WINDOW = 0.12
local LastRunToggleKeyDown = false
local LastRunBridgeDispatchAt = 0

local function IsRunToggleKey(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Keyboard
		and (input.KeyCode == RUN_KEY_PRIMARY or input.KeyCode == RUN_KEY_SECONDARY)
end

local function IsRunToggleKeyDown(): boolean
	if UserInputService:IsKeyDown(RUN_KEY_PRIMARY) or UserInputService:IsKeyDown(RUN_KEY_SECONDARY) then
		return true
	end
	for _, input in UserInputService:GetKeysPressed() do
		if input.KeyCode == RUN_KEY_PRIMARY or input.KeyCode == RUN_KEY_SECONDARY then
			return true
		end
	end
	return false
end

local function EmitRunBridgeDebug(message: string): ()
	return
end

local function DispatchRunToggle(source: string, keyCode: Enum.KeyCode, gameProcessed: boolean): ()
	LastRunBridgeDispatchAt = os.clock()
	EmitRunBridgeDebug(string.format("%s:gpe=%s:key=%s", source, tostring(gameProcessed), keyCode.Name))
	SpinController.HandleExternalRunToggle(source, keyCode, gameProcessed)
end

local function HandleRunBridgeAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	inputObject: InputObject
): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if not IsRunToggleKey(inputObject) then
		return Enum.ContextActionResult.Pass
	end
	DispatchRunToggle("MainClient:ContextAction", inputObject.KeyCode, false)
	return Enum.ContextActionResult.Pass
end

local Admins = require(ReplicatedStorage:WaitForChild("Modules").Data.Admins)

Framework:Start():andThen(function()
	if not RunService:IsStudio() then
		print("[C]: Client load completed")
	end

	local Commands = require(ReplicatedStorage:WaitForChild("CmdrClient"))
	Commands:SetActivationKeys({ Enum.KeyCode.F4 })
	if not Admins[LocalPlayer.UserId] then
		Commands:SetEnabled(false)
	end

end)

ContextActionService:UnbindAction(RUN_INPUT_BRIDGE_ACTION)
ContextActionService:BindActionAtPriority(
	RUN_INPUT_BRIDGE_ACTION,
	HandleRunBridgeAction,
	false,
	Enum.ContextActionPriority.High.Value,
	RUN_KEY_PRIMARY,
	RUN_KEY_SECONDARY
)
EmitRunBridgeDebug(string.format("BridgeReady:%s", RUN_INPUT_BRIDGE_VERSION))

UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	if Input.KeyCode ~= Enum.KeyCode.LeftShift then
		return
	end
	if CameraController.IsShiftlockBlocked and CameraController:IsShiftlockBlocked() then
		return
	end
	local enabled = not CameraController:IsShiftlockRequested()
	CameraController:SetShiftlock(enabled)
end)

UserInputService.InputEnded:Connect(function(Input: InputObject, GameProcessed: boolean)
	if not IsRunToggleKey(Input) then
		return
	end
	LastRunToggleKeyDown = false
	EmitRunBridgeDebug(string.format("MainClient:InputEnded:gpe=%s:key=%s", tostring(GameProcessed), Input.KeyCode.Name))
end)

UserInputService.WindowFocusReleased:Connect(function()
	LastRunToggleKeyDown = false
	EmitRunBridgeDebug(string.format("MainClient:WindowFocusReleased:%s", RUN_INPUT_BRIDGE_VERSION))
end)

UserInputService.WindowFocused:Connect(function()
	LastRunToggleKeyDown = IsRunToggleKeyDown()
	EmitRunBridgeDebug(
		string.format(
			"MainClient:WindowFocused:%s:ctrlDown=%s",
			RUN_INPUT_BRIDGE_VERSION,
			tostring(LastRunToggleKeyDown)
		)
	)
end)

LastRunToggleKeyDown = IsRunToggleKeyDown()

RunService.Heartbeat:Connect(function()
	local isDown = IsRunToggleKeyDown()
	if isDown == LastRunToggleKeyDown then
		return
	end
	LastRunToggleKeyDown = isDown
	if not isDown then
		EmitRunBridgeDebug("MainClient:HeartbeatPollRelease")
		return
	end
	local now = os.clock()
	if now - LastRunBridgeDispatchAt <= RUN_INPUT_BRIDGE_FALLBACK_WINDOW then
		EmitRunBridgeDebug(
			string.format("MainClient:HeartbeatFallbackSuppressed:delta=%.3f", now - LastRunBridgeDispatchAt)
		)
		return
	end
	DispatchRunToggle("MainClient:HeartbeatFallback", RUN_KEY_PRIMARY, false)
end)

local GamepadIcons = {
	[Enum.KeyCode.ButtonX] = "rbxasset://textures/ui/Controls/xboxX.png",
	[Enum.KeyCode.ButtonY] = "rbxasset://textures/ui/Controls/xboxY.png",
	[Enum.KeyCode.ButtonA] = "rbxasset://textures/ui/Controls/xboxA.png",
	[Enum.KeyCode.ButtonB] = "rbxasset://textures/ui/Controls/xboxB.png",
	[Enum.KeyCode.DPadLeft] = "rbxasset://textures/ui/Controls/dpadLeft.png",
	[Enum.KeyCode.DPadRight] = "rbxasset://textures/ui/Controls/dpadRight.png",
	[Enum.KeyCode.DPadUp] = "rbxasset://textures/ui/Controls/dpadUp.png",
	[Enum.KeyCode.DPadDown] = "rbxasset://textures/ui/Controls/dpadDown.png",
	[Enum.KeyCode.ButtonSelect] = "rbxasset://textures/ui/Controls/xboxmenu.png",
	[Enum.KeyCode.ButtonL1] = "rbxasset://textures/ui/Controls/xboxLS.png",
	[Enum.KeyCode.ButtonR1] = "rbxasset://textures/ui/Controls/xboxRS.png",
}

local KeyboardIcons = {
	[Enum.KeyCode.Backspace] = "rbxasset://textures/ui/Controls/backspace.png",
	[Enum.KeyCode.Return] = "rbxasset://textures/ui/Controls/return.png",
	[Enum.KeyCode.LeftShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.RightShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.Tab] = "rbxasset://textures/ui/Controls/tab.png",
	[Enum.KeyCode.Escape] = "rbxasset://textures/ui/Controls/esc.png",
	[Enum.KeyCode.Space] = "rbxasset://textures/ui/Controls/spacebar.png",
}

local CharIcons = {
	["'"] = "rbxasset://textures/ui/Controls/apostrophe.png",
	[","] = "rbxasset://textures/ui/Controls/comma.png",
	["`"] = "rbxasset://textures/ui/Controls/graveaccent.png",
	["."] = "rbxasset://textures/ui/Controls/period.png",
	["/"] = "rbxasset://textures/ui/Controls/slash.png",
	[";"] = "rbxasset://textures/ui/Controls/semicolon.png",
	["["] = "rbxasset://textures/ui/Controls/bracketleft.png",
	["]"] = "rbxasset://textures/ui/Controls/bracketright.png",
	["\\"] = "rbxasset://textures/ui/Controls/backslash.png",
	["="] = "rbxasset://textures/ui/Controls/equals.png",
	["-"] = "rbxasset://textures/ui/Controls/minus.png",
}

local TextKeys = {
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "Ctrl",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "Alt",
	[Enum.KeyCode.LeftShift] = "Shift",
	[Enum.KeyCode.RightShift] = "Shift",
	[Enum.KeyCode.F1] = "F1",
	[Enum.KeyCode.F2] = "F2",
	[Enum.KeyCode.F3] = "F3",
	[Enum.KeyCode.F4] = "F4",
	[Enum.KeyCode.F5] = "F5",
	[Enum.KeyCode.F6] = "F6",
	[Enum.KeyCode.F7] = "F7",
	[Enum.KeyCode.F8] = "F8",
	[Enum.KeyCode.F9] = "F9",
	[Enum.KeyCode.F10] = "F10",
	[Enum.KeyCode.F11] = "F11",
	[Enum.KeyCode.F12] = "F12",
	[Enum.KeyCode.Insert] = "Ins",
	[Enum.KeyCode.Delete] = "Del",
	[Enum.KeyCode.Home] = "Home",
	[Enum.KeyCode.End] = "End",
	[Enum.KeyCode.PageUp] = "PgUp",
	[Enum.KeyCode.PageDown] = "PgDown",
	[Enum.KeyCode.Print] = "PrtSc",
	[Enum.KeyCode.ScrollLock] = "ScrLk",
	[Enum.KeyCode.Pause] = "Pause",
	[Enum.KeyCode.NumLock] = "Num",
}

local LetterKeys = {
	Enum.KeyCode.A,
	Enum.KeyCode.B,
	Enum.KeyCode.C,
	Enum.KeyCode.D,
	Enum.KeyCode.E,
	Enum.KeyCode.F,
	Enum.KeyCode.G,
	Enum.KeyCode.H,
	Enum.KeyCode.I,
	Enum.KeyCode.J,
	Enum.KeyCode.K,
	Enum.KeyCode.L,
	Enum.KeyCode.M,
	Enum.KeyCode.N,
	Enum.KeyCode.O,
	Enum.KeyCode.P,
	Enum.KeyCode.Q,
	Enum.KeyCode.R,
	Enum.KeyCode.S,
	Enum.KeyCode.T,
	Enum.KeyCode.U,
	Enum.KeyCode.V,
	Enum.KeyCode.W,
	Enum.KeyCode.X,
	Enum.KeyCode.Y,
	Enum.KeyCode.Z,
}

local NumberKeys = {
	Enum.KeyCode.Zero,
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local PromptManager = {
	ActivePrompts = {},
	BillboardInstances = {},
	Connections = {},
	HideTweens = {},
	CreationTimes = {},
}

local CREATION_DEBOUNCE = 0.2
local HIDE_DELAY = 0.3
local HIDE_ANIMATION_TIME = 0.2

local function getScreenGui()
	if not PlayerGui:FindFirstChild("ProximityPrompts") then
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ProximityPrompts"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = PlayerGui
	end
	return PlayerGui:FindFirstChild("ProximityPrompts")
end

function PromptManager:HasActivePrompt(prompt)
	return self.ActivePrompts[prompt] == true
end

function PromptManager:HasBillboard(prompt)
	return self.BillboardInstances[prompt] and self.BillboardInstances[prompt].Parent ~= nil
end

function PromptManager:ForceCleanup(prompt)
	if self.HideTweens[prompt] then
		for _, tween in ipairs(self.HideTweens[prompt]) do
			tween:Play()
		end

		task.delay(HIDE_ANIMATION_TIME, function()
			if self.BillboardInstances[prompt] and self.BillboardInstances[prompt].Parent then
				self.BillboardInstances[prompt]:Destroy()
			end

			self:ClearPromptData(prompt)
		end)
	else
		if self.BillboardInstances[prompt] and self.BillboardInstances[prompt].Parent then
			self.BillboardInstances[prompt]:Destroy()
		end

		self:ClearPromptData(prompt)
	end
end

function PromptManager:ClearPromptData(prompt)
	if self.BillboardInstances[prompt] then
		self.BillboardInstances[prompt] = nil
	end

	if self.Connections[prompt] then
		for _, conn in ipairs(self.Connections[prompt]) do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		self.Connections[prompt] = nil
	end

	self.HideTweens[prompt] = nil
	self.ActivePrompts[prompt] = nil
	self.CreationTimes[prompt] = nil
end

function PromptManager:ScheduleCleanup(prompt)
	if not self:HasActivePrompt(prompt) then
		return
	end

	self.ActivePrompts[prompt] = false

	task.delay(HIDE_DELAY, function()
		if self:HasActivePrompt(prompt) then
			return
		end

		self:ForceCleanup(prompt)
	end)
end

function PromptManager:IsPromptValid(prompt)
	return prompt and prompt.Parent ~= nil and not prompt:GetAttribute("Hidden")
end

function PromptManager:ShouldCreatePrompt(prompt)
	local now = tick()

	if self.CreationTimes[prompt] and now - self.CreationTimes[prompt] < CREATION_DEBOUNCE then
		return false
	end

	if self:HasBillboard(prompt) then
		return false
	end

	if not self:IsPromptValid(prompt) then
		return false
	end

	return true
end

local function createProgressBarGradient(container, isRight)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.5, 1)
	frame.Position = UDim2.fromScale(isRight and 0.5 or 0, 0)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.Parent = container

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(2, 1)
	image.Position = UDim2.fromScale(isRight and -1 or 0, 0)
	image.Image = "rbxasset://textures/ui/Controls/RadialFill.png"
	image.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4999, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = isRight and 180 or 0
	gradient.Parent = image

	return gradient
end

local function createCircularProgressBar()
	local frame = Instance.new("Frame")
	frame.Name = "CircularProgressBar"
	frame.Size = UDim2.fromOffset(58, 58)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundTransparency = 1

	local progressValue = Instance.new("NumberValue")
	progressValue.Name = "Progress"
	progressValue.Parent = frame

	local rightGradient = createProgressBarGradient(frame, true)
	local leftGradient = createProgressBarGradient(frame, false)

	progressValue.Changed:Connect(function(value)
		local rotation = math.clamp(value * 360, 0, 360)
		rightGradient.Rotation = math.clamp(rotation, 180, 360)
		leftGradient.Rotation = math.clamp(rotation, 0, 180)
	end)

	return frame
end

local function getKeyDisplay(keyCode)
	if KeyboardIcons[keyCode] then
		return KeyboardIcons[keyCode], "icon"
	end

	local char = UserInputService:GetStringForKeyCode(keyCode)
	if char ~= "" and CharIcons[char] then
		return CharIcons[char], "icon"
	end

	if TextKeys[keyCode] then
		return TextKeys[keyCode], "text"
	end

	local char2 = UserInputService:GetStringForKeyCode(keyCode)
	if char2 ~= "" then
		return char2:upper(), "text"
	end

	for _, letter in ipairs(LetterKeys) do
		if keyCode == letter then
			local charName = tostring(keyCode):gsub("Enum%.KeyCode%.", "")
			return charName, "text"
		end
	end

	for _, number in ipairs(NumberKeys) do
		if keyCode == number then
			local num = tostring(keyCode):gsub("Enum%.KeyCode%.", "")
			if num == "Zero" then
				return "0", "text"
			end
			return num:sub(-1), "text"
		end
	end

	return tostring(keyCode):gsub("Enum%.KeyCode%.", ""), "text"
end

local function createPrompt(prompt, inputType, screenGui)
	local holdTweens = {}
	local releaseTweens = {}
	local hideTweens = {}
	local showTweens = {}

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local quickTweenInfo = TweenInfo.new(0.06, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Prompt"
	billboard.AlwaysOnTop = true

	local background = Instance.new("ImageLabel")
	background.Image = "rbxassetid://115789466235547"
	background.Size = UDim2.fromScale(0.5, 1)
	background.BackgroundTransparency = 1
	background.BackgroundColor3 = Color3.new(0.07, 0.07, 0.07)
	background.Parent = billboard

	Instance.new("UICorner").Parent = background

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.fromScale(1, 1)
	inputFrame.BackgroundTransparency = 1
	inputFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	inputFrame.Parent = background

	local inputContainer = Instance.new("Frame")
	inputContainer.Size = UDim2.fromScale(1, 1)
	inputContainer.Position = UDim2.fromScale(0.5, 0.5)
	inputContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	inputContainer.BackgroundTransparency = 1
	inputContainer.Parent = inputFrame

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = inputType == Enum.ProximityPromptInputType.Touch and 1.6 or 1.33
	uiScale.Parent = inputContainer

	table.insert(holdTweens, TweenService:Create(uiScale, tweenInfo, { Scale = 1.33 }))
	table.insert(releaseTweens, TweenService:Create(uiScale, tweenInfo, { Scale = 1 }))

	local actionText = Instance.new("TextLabel")
	actionText.Name = "ActionText"
	actionText.Size = UDim2.fromScale(1, 1)
	actionText.Font = Enum.Font.Montserrat
	actionText.TextSize = 19
	actionText.BackgroundTransparency = 1
	actionText.TextTransparency = 1
	actionText.TextColor3 = Color3.new(1, 1, 1)
	actionText.TextXAlignment = Enum.TextXAlignment.Left
	actionText.Parent = background

	table.insert(holdTweens, TweenService:Create(actionText, tweenInfo, { TextTransparency = 1 }))
	table.insert(releaseTweens, TweenService:Create(actionText, tweenInfo, { TextTransparency = 0 }))
	table.insert(hideTweens, TweenService:Create(actionText, quickTweenInfo, { TextTransparency = 1 }))
	table.insert(showTweens, TweenService:Create(actionText, quickTweenInfo, { TextTransparency = 0 }))

	local objectText = Instance.new("TextLabel")
	objectText.Name = "ObjectText"
	objectText.Size = UDim2.fromScale(1, 1)
	objectText.Font = Enum.Font.Montserrat
	objectText.TextSize = 14
	objectText.BackgroundTransparency = 1
	objectText.TextTransparency = 1
	objectText.TextColor3 = Color3.new(0.7, 0.7, 0.7)
	objectText.TextXAlignment = Enum.TextXAlignment.Left
	objectText.Parent = background

	table.insert(holdTweens, TweenService:Create(objectText, tweenInfo, { TextTransparency = 1 }))
	table.insert(releaseTweens, TweenService:Create(objectText, tweenInfo, { TextTransparency = 0 }))
	table.insert(hideTweens, TweenService:Create(objectText, quickTweenInfo, { TextTransparency = 1 }))
	table.insert(showTweens, TweenService:Create(objectText, quickTweenInfo, { TextTransparency = 0 }))

	table.insert(
		holdTweens,
		TweenService:Create(background, tweenInfo, { Size = UDim2.fromScale(0.5, 1), ImageTransparency = 0 })
	)
	table.insert(
		releaseTweens,
		TweenService:Create(background, tweenInfo, { Size = UDim2.fromScale(1, 1), ImageTransparency = 0 })
	)
	table.insert(
		hideTweens,
		TweenService:Create(background, tweenInfo, { Size = UDim2.fromScale(0.5, 1), ImageTransparency = 1 })
	)
	table.insert(
		showTweens,
		TweenService:Create(background, tweenInfo, { Size = UDim2.fromScale(1, 1), ImageTransparency = 0 })
	)

	local roundFrame = Instance.new("Frame")
	roundFrame.Name = "RoundFrame"
	roundFrame.Size = UDim2.fromOffset(48, 48)
	roundFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	roundFrame.Position = UDim2.fromScale(0.5, 0.5)
	roundFrame.BackgroundTransparency = 1
	roundFrame.Parent = inputContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = roundFrame

	table.insert(hideTweens, TweenService:Create(roundFrame, quickTweenInfo, { BackgroundTransparency = 1 }))
	table.insert(showTweens, TweenService:Create(roundFrame, quickTweenInfo, { BackgroundTransparency = 1 }))

	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local icon = GamepadIcons[prompt.GamepadKeyCode]
		if icon then
			local image = Instance.new("ImageLabel")
			image.Name = "ButtonImage"
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Size = UDim2.fromOffset(24, 24)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.BackgroundTransparency = 1
			image.ImageTransparency = 1
			image.Image = icon
			image.Parent = inputContainer

			table.insert(hideTweens, TweenService:Create(image, quickTweenInfo, { ImageTransparency = 1 }))
			table.insert(showTweens, TweenService:Create(image, quickTweenInfo, { ImageTransparency = 0 }))
		end
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		local image = Instance.new("ImageLabel")
		image.Name = "ButtonImage"
		image.BackgroundTransparency = 1
		image.ImageTransparency = 1
		image.Size = UDim2.fromOffset(25, 31)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Image = "rbxasset://textures/ui/Controls/TouchTapIcon.png"
		image.Parent = inputContainer

		table.insert(hideTweens, TweenService:Create(image, quickTweenInfo, { ImageTransparency = 1 }))
		table.insert(showTweens, TweenService:Create(image, quickTweenInfo, { ImageTransparency = 0 }))
	else
		local keyImage = Instance.new("ImageLabel")
		keyImage.Name = "KeyBackground"
		keyImage.BackgroundTransparency = 1
		keyImage.ImageTransparency = 1
		keyImage.Size = UDim2.fromOffset(28, 30)
		keyImage.AnchorPoint = Vector2.new(0.5, 0.5)
		keyImage.Position = UDim2.fromScale(0.5, 0.5)
		keyImage.Image = "rbxasset://textures/ui/Controls/key_single.png"
		keyImage.Parent = inputContainer

		table.insert(hideTweens, TweenService:Create(keyImage, quickTweenInfo, { ImageTransparency = 1 }))
		table.insert(showTweens, TweenService:Create(keyImage, quickTweenInfo, { ImageTransparency = 0 }))

		local display, displayType = getKeyDisplay(prompt.KeyboardKeyCode)

		if displayType == "icon" then
			local image = Instance.new("ImageLabel")
			image.Name = "ButtonImage"
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Size = UDim2.fromOffset(36, 36)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.BackgroundTransparency = 1
			image.ImageTransparency = 1
			image.Image = display
			image.Parent = inputContainer

			table.insert(hideTweens, TweenService:Create(image, quickTweenInfo, { ImageTransparency = 1 }))
			table.insert(showTweens, TweenService:Create(image, quickTweenInfo, { ImageTransparency = 0 }))
		else
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "ButtonText"
			textLabel.Position = UDim2.fromOffset(0, -1)
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.Font = Enum.Font.Montserrat
			textLabel.TextSize = #display > 2 and 12 or 14
			textLabel.BackgroundTransparency = 1
			textLabel.TextTransparency = 1
			textLabel.TextColor3 = Color3.new(1, 1, 1)
			textLabel.TextXAlignment = Enum.TextXAlignment.Center
			textLabel.Text = display
			textLabel.Parent = inputContainer

			table.insert(hideTweens, TweenService:Create(textLabel, quickTweenInfo, { TextTransparency = 1 }))
			table.insert(showTweens, TweenService:Create(textLabel, quickTweenInfo, { TextTransparency = 0 }))
		end
	end

	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		local button = Instance.new("TextButton")
		button.BackgroundTransparency = 1
		button.TextTransparency = 1
		button.Size = UDim2.fromScale(1, 1)
		button.Parent = billboard

		local isHolding = false

		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				if input.UserInputState ~= Enum.UserInputState.Change then
					prompt:InputHoldBegin()
					isHolding = true
				end
			end
		end)

		button.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				if isHolding then
					isHolding = false
					prompt:InputHoldEnd()
				end
			end
		end)

		billboard.Active = true
	end

	local progressBar
	local holdBeganConnection
	local holdEndedConnection

	if prompt.HoldDuration > 0 then
		progressBar = createCircularProgressBar()
		progressBar.Parent = inputContainer

		table.insert(
			holdTweens,
			TweenService:Create(
				progressBar.Progress,
				TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
				{ Value = 1 }
			)
		)

		table.insert(
			releaseTweens,
			TweenService:Create(
				progressBar.Progress,
				TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Value = 0 }
			)
		)

		holdBeganConnection = prompt.PromptButtonHoldBegan:Connect(function()
			for _, tween in ipairs(holdTweens) do
				tween:Play()
			end
		end)

		holdEndedConnection = prompt.PromptButtonHoldEnded:Connect(function()
			for _, tween in ipairs(releaseTweens) do
				tween:Play()
			end
		end)
	end

	local connections = {}

	local function addConnection(connection)
		table.insert(connections, connection)
	end

	local triggeredConnection = prompt.Triggered:Connect(function()
		for _, tween in ipairs(hideTweens) do
			tween:Play()
		end
	end)
	addConnection(triggeredConnection)

	if holdBeganConnection then
		addConnection(holdBeganConnection)
	end
	if holdEndedConnection then
		addConnection(holdEndedConnection)
	end

	local lastUpdate = 0
	local updateDebounce = 0.05

	local function updateUI()
		local now = tick()
		if now - lastUpdate < updateDebounce then
			return
		end
		lastUpdate = now

		local textWidth = 0
		if prompt.ActionText ~= "" or prompt.ObjectText ~= "" then
			local actionWidth =
				TextService:GetTextSize(prompt.ActionText, 19, Enum.Font.Montserrat, Vector2.new(1000, 1000)).X
			local objectWidth =
				TextService:GetTextSize(prompt.ObjectText, 14, Enum.Font.Montserrat, Vector2.new(1000, 1000)).X
			textWidth = math.max(actionWidth, objectWidth) + 72 + 24
		end

		local actionY = prompt.ObjectText ~= "" and 9 or 0

		actionText.Position = UDim2.new(0.5, 72 - textWidth / 2, 0, actionY)
		objectText.Position = UDim2.new(0.5, 72 - textWidth / 2, 0, -10)

		actionText.Text = prompt.ActionText
		objectText.Text = prompt.ObjectText
		actionText.AutoLocalize = prompt.AutoLocalize
		actionText.RootLocalizationTable = prompt.RootLocalizationTable
		objectText.AutoLocalize = prompt.AutoLocalize
		objectText.RootLocalizationTable = prompt.RootLocalizationTable

		background.Image = prompt.ActionText:match("R") and "rbxassetid://115789466235547"
			or "rbxassetid://89426684482295"

		billboard.Size = UDim2.fromOffset(textWidth, 72)
		billboard.SizeOffset = Vector2.new(
			prompt.UIOffset.X / billboard.Size.Width.Offset,
			prompt.UIOffset.Y / billboard.Size.Height.Offset
		)
	end

	updateUI()

	billboard.Adornee = prompt.Parent
	billboard.Parent = screenGui

	for _, tween in ipairs(showTweens) do
		tween:Play()
	end

	local triggerEndedConnection = prompt.TriggerEnded:Connect(function()
		for _, tween in ipairs(showTweens) do
			tween:Play()
		end
	end)
	addConnection(triggerEndedConnection)

	local changedConnection = prompt.Changed:Connect(updateUI)
	addConnection(changedConnection)

	return billboard, connections, hideTweens
end

ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style == Enum.ProximityPromptStyle.Default then
		return
	end

	local manager = PromptManager

	if not manager:ShouldCreatePrompt(prompt) then
		manager.ActivePrompts[prompt] = true
		return
	end

	manager.CreationTimes[prompt] = tick()
	manager.ActivePrompts[prompt] = true

	local screenGui = getScreenGui()
	local billboard, connections, hideTweens = createPrompt(prompt, inputType, screenGui)

	manager.BillboardInstances[prompt] = billboard
	manager.Connections[prompt] = connections
	manager.HideTweens[prompt] = hideTweens

	local hiddenConnection
	hiddenConnection = prompt.PromptHidden:Connect(function()
		if manager:HasActivePrompt(prompt) then
			manager:ScheduleCleanup(prompt)
		end
	end)
	table.insert(connections, hiddenConnection)

	local destroyedConnection = prompt.AncestryChanged:Connect(function()
		if not prompt.Parent then
			manager:ForceCleanup(prompt)
		end
	end)
	table.insert(connections, destroyedConnection)

	local stateChangedConnection = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not prompt.Enabled then
			manager:ScheduleCleanup(prompt)
		end
	end)
	table.insert(connections, stateChangedConnection)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	local manager = PromptManager

	if manager:HasActivePrompt(prompt) then
		manager:ScheduleCleanup(prompt)
	end
end)

game.Players.LocalPlayer.CharacterAdded:Connect(function()
	for prompt, _ in pairs(PromptManager.ActivePrompts) do
		PromptManager:ForceCleanup(prompt)
	end
end)
