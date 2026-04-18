
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local WalkSpeedController = require(ReplicatedStorage.Controllers.WalkSpeedController)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local MatchPlayerUtils = require(ReplicatedStorage.Modules.Game.MatchPlayerUtils)
local GameplayGuiVisibility = require(ReplicatedStorage.Modules.Game.GameplayGuiVisibility)

local CountdownController = {}

--\\ CONSTANTS \\ -- TR
local COUNTDOWN_DURATION: number = 5
local FONT_FAMILY: Enum.Font = Enum.Font.SourceSansBold
local TEXT_SIZE: number = 120
local DESCRIPTION_TEXT_SIZE: number = 38
local TEXT_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local STROKE_COLOR: Color3 = Color3.fromRGB(0, 0, 0)
local STROKE_THICKNESS: number = 3
local STROKE_TRANSPARENCY: number = 0.5

local TWEEN_INFO_ENTER = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_INFO_EXIT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_INFO_BLUR = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local WALKSPEED_REQUEST_ID: string = "CountdownFreeze"
local FREEZE_INPUT_ACTION_ID: string = "FTCountdownFreezeInput"
local NOTIFY_DEFAULT_DURATION: number = 2.4
local COUNTDOWN_NUMBER_SWAP_DELAY: number = 0.05
local COUNTDOWN_GO_SWAP_DELAY: number = 0.08
local COUNTDOWN_GO_DISPLAY_DURATION: number = 1
local COUNTDOWN_GO_CLEANUP_DELAY: number = 0.3
local COUNTDOWN_GO_STOP_FALLBACK_DELAY: number = 1.6

--\\ MODULE STATE \\ -- TR
local LocalPlayer = Players.LocalPlayer
local GameGui: ScreenGui? = nil
local CountdownLabel: TextLabel? = nil
local CountdownStroke: UIStroke? = nil
local BlurEffect: BlurEffect? = nil
local IsCountdownActive: boolean = false
local GoSequenceActive: boolean = false
local IsNotifyActive: boolean = false
local NotifyFinishTime: number = 0
local NotifyToken: number = 0
local NotifyContainer: Frame? = nil
local NotifyLabel: TextLabel? = nil
local NotifyDescription: TextLabel? = nil
local NotifyScale: UIScale? = nil
local NotifyPulseTween: Tween? = nil
local CountdownTimeValueRef: IntValue? = nil
local CountdownActiveValueRef: BoolValue? = nil
local CountdownFreezeConnection: RBXScriptConnection? = nil
local StopLocalMovementFreeze: () -> ()
local ManualCountdownActive: boolean = false
local ManualCountdownToken: number = 0
local CountdownVisualToken: number = 0

type ManualCountdownOptions = {
	UseBlur: boolean?,
	ShowGo: boolean?,
	Interval: number?,
}

local function IsLocalPlayerInMatch(): boolean
	return MatchPlayerUtils.IsPlayerActive(LocalPlayer)
end

local function BindFreezeInput(
	_actionName: string,
	_inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

--\\ PRIVATE FUNCTIONS \\ -- TR
local function GetOrCreateBlurEffect(): BlurEffect
	if BlurEffect then return BlurEffect end
	
	local ExistingBlur = Lighting:FindFirstChild("CountdownBlur")
	if ExistingBlur and ExistingBlur:IsA("BlurEffect") then
		BlurEffect = ExistingBlur
		return BlurEffect
	end
	
	BlurEffect = Instance.new("BlurEffect")
	BlurEffect.Name = "CountdownBlur"
	BlurEffect.Size = 0
	BlurEffect.Enabled = true
	BlurEffect.Parent = Lighting
	
	return BlurEffect
end

local function CreateCountdownLabel(): TextLabel
	local Label = Instance.new("TextLabel")
	Label.Name = "CountdownLabel"
	Label.Size = UDim2.new(1, 0, 1, 0)
	Label.AnchorPoint = Vector2.new(0.5, 0.5)
	Label.Position = UDim2.new(0.5, 0, 0.5, 0)
	Label.BackgroundTransparency = 1
	Label.Font = FONT_FAMILY
	Label.TextSize = TEXT_SIZE
	Label.TextColor3 = TEXT_COLOR
	Label.Text = ""
	Label.TextTransparency = 1
	Label.TextScaled = false
	Label.ZIndex = 100
	
	local Stroke = Instance.new("UIStroke")
	Stroke.Name = "CountdownStroke"
	Stroke.Thickness = STROKE_THICKNESS
	Stroke.Color = STROKE_COLOR
	Stroke.Transparency = STROKE_TRANSPARENCY
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	Stroke.Parent = Label
	
	CountdownStroke = Stroke
	
	return Label
end

local function EnsureNotifyContainer(): ()
	if not GameGui then
		return
	end
	if NotifyContainer then
		return
	end

	local container = Instance.new("Frame")
	container.Name = "NotifyContainer"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 100
	container.Parent = GameGui
	NotifyContainer = container

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = container
	NotifyScale = scale

	local mainLabel = CreateCountdownLabel()
	mainLabel.Name = "NotifyLabel"
	mainLabel.Parent = container
	NotifyLabel = mainLabel

	local desc = Instance.new("TextLabel")
	desc.Name = "NotifyDescription"
	desc.Size = UDim2.new(1, 0, 1, 0)
	desc.AnchorPoint = Vector2.new(0.5, 0.5)
	desc.Position = UDim2.new(0.5, 0, 0.5, TEXT_SIZE * 0.55)
	desc.BackgroundTransparency = 1
	desc.Font = FONT_FAMILY
	desc.TextSize = DESCRIPTION_TEXT_SIZE
	desc.TextColor3 = TEXT_COLOR
	desc.Text = ""
	desc.TextTransparency = 1
	desc.ZIndex = 100

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = STROKE_COLOR
	stroke.Transparency = STROKE_TRANSPARENCY
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = desc

	desc.Parent = container
	NotifyDescription = desc
end

local function AnimateNumberEnter(Label: TextLabel, useBlur: boolean?): ()
	Label.TextTransparency = 1
	Label.TextScaled = false
	Label.TextSize = TEXT_SIZE * 0.5
	
	local EnterTween = TweenService:Create(Label, TWEEN_INFO_ENTER, {
		TextTransparency = 0,
		TextSize = TEXT_SIZE,
	})
	EnterTween:Play()

	if useBlur ~= false then
		local Blur = GetOrCreateBlurEffect()
		local BlurInTween = TweenService:Create(Blur, TWEEN_INFO_BLUR, {
			Size = 8,
		})
		BlurInTween:Play()
	elseif BlurEffect then
		BlurEffect.Size = 0
	end
end

local function AnimateNumberExit(Label: TextLabel, useBlur: boolean?): ()
	local ExitTween = TweenService:Create(Label, TWEEN_INFO_EXIT, {
		TextTransparency = 1,
		TextSize = TEXT_SIZE * 1.5,
	})
	ExitTween:Play()

	if useBlur ~= false then
		local Blur = GetOrCreateBlurEffect()
		local BlurOutTween = TweenService:Create(Blur, TWEEN_INFO_BLUR, {
			Size = 0,
		})
		BlurOutTween:Play()
	elseif BlurEffect then
		BlurEffect.Size = 0
	end
end

local function SetGameGuiVisible(Visible: boolean): ()
	if not GameGui then
		local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if PlayerGui then
			GameGui = PlayerGui:FindFirstChild("GameGui") :: ScreenGui?
		end
	end

	if Visible and not IsLocalPlayerInMatch() then
		Visible = false
	end
	if Visible and GameplayGuiVisibility.IsGameplayGuiBlocked(LocalPlayer) then
		GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
		return
	end
	if GameGui then
		GameGui.Enabled = Visible
	end
end

local function CleanupCountdown(): ()
	CountdownVisualToken += 1
	StopLocalMovementFreeze()

	if CountdownLabel then
		CountdownLabel:Destroy()
		CountdownLabel = nil
	end
	CountdownStroke = nil
	
	if BlurEffect then
		BlurEffect.Size = 0
	end
	
	IsCountdownActive = false
	GoSequenceActive = false
end

local function EnsureCountdownLabelReady(): boolean
	if not GameGui then
		local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if PlayerGui then
			GameGui = PlayerGui:FindFirstChild("GameGui") :: ScreenGui?
		end
	end
	if not GameGui then
		return false
	end

	if CountdownLabel then
		CountdownLabel:Destroy()
		CountdownLabel = nil
		CountdownStroke = nil
	end

	CountdownLabel = CreateCountdownLabel()
	CountdownLabel.Parent = GameGui
	return true
end

local function CleanupManualCountdown(): ()
	ManualCountdownActive = false
	if IsCountdownActive or GoSequenceActive then
		return
	end

	if CountdownLabel then
		CountdownLabel:Destroy()
		CountdownLabel = nil
	end
	CountdownStroke = nil
	if BlurEffect then
		BlurEffect.Size = 0
	end
end

StopLocalMovementFreeze = function(): ()
	WalkSpeedController.RemoveRequest(WALKSPEED_REQUEST_ID)
	if CountdownFreezeConnection then
		CountdownFreezeConnection:Disconnect()
		CountdownFreezeConnection = nil
	end
	ContextActionService:UnbindAction(FREEZE_INPUT_ACTION_ID)
end

local function CleanupNotifyLabel(): ()
	if NotifyPulseTween then
		NotifyPulseTween:Cancel()
		NotifyPulseTween = nil
	end
	if NotifyContainer then
		NotifyContainer:Destroy()
		NotifyContainer = nil
	end
	NotifyLabel = nil
	NotifyDescription = nil
	NotifyScale = nil
	if BlurEffect then
		BlurEffect.Size = 0
	end
end

local function ForceCleanupLocalVisuals(): ()
	CleanupNotifyLabel()
	CleanupCountdown()
end

local function TryStartCountdownIfActive(): ()
	if CountdownActiveValueRef and CountdownActiveValueRef.Value and IsLocalPlayerInMatch() then
		if not IsCountdownActive then
			CountdownController.StartCountdown()
			if CountdownTimeValueRef then
				CountdownController.UpdateCountdownNumber(CountdownTimeValueRef.Value)
			end
		end
	end
end

local function ApplyLocalMovementFreeze(): ()
	local Character = LocalPlayer.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	Humanoid:Move(Vector3.zero, false)
	Humanoid.WalkSpeed = 0
	if Humanoid.UseJumpPower then
		Humanoid.JumpPower = 0
	else
		Humanoid.JumpHeight = 0
	end
	if Root then
		Root.AssemblyLinearVelocity = Vector3.zero
		Root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function StartLocalMovementFreeze(): ()
	ContextActionService:UnbindAction(FREEZE_INPUT_ACTION_ID)
	ContextActionService:BindAction(FREEZE_INPUT_ACTION_ID, BindFreezeInput, false, unpack(Enum.PlayerActions:GetEnumItems()))

	if CountdownFreezeConnection then
		return
	end

	CountdownFreezeConnection = RunService.Heartbeat:Connect(function()
		if not IsCountdownActive and not GoSequenceActive then
			CleanupCountdown()
			return
		end
		if not IsLocalPlayerInMatch() then
			CleanupCountdown()
			return
		end
		ApplyLocalMovementFreeze()
	end)

	ApplyLocalMovementFreeze()
end

local function RefreshLocalCountdownState(): ()
	if IsLocalPlayerInMatch() then
		TryStartCountdownIfActive()
		return
	end
	ForceCleanupLocalVisuals()
end

--\\ PUBLIC FUNCTIONS \\ -- TR
function CountdownController.Init(): ()
end

function CountdownController.Start(): ()
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	GameGui = PlayerGui:WaitForChild("GameGui") :: ScreenGui
	
	local GameState = ReplicatedStorage:WaitForChild("FTGameState")
	local CountdownActiveValue = GameState:FindFirstChild("CountdownActive") :: BoolValue?
	local CountdownTimeValue = GameState:FindFirstChild("CountdownTime") :: IntValue?
	CountdownActiveValueRef = CountdownActiveValue
	CountdownTimeValueRef = CountdownTimeValue
	
	if CountdownActiveValue then
		CountdownActiveValue.Changed:Connect(function(Value: boolean)
			if Value then
				CountdownController.StartCountdown()
			else
				CountdownController.StopCountdown()
			end
		end)
	end
	
	if CountdownTimeValue then
		CountdownTimeValue.Changed:Connect(function(Value: number)
			if IsCountdownActive and CountdownLabel then
				CountdownController.UpdateCountdownNumber(Value)
			end
			if IsCountdownActive then
				local remaining = math.max(1, Value + 2)
				WalkSpeedController.AddRequest(WALKSPEED_REQUEST_ID, 0, remaining, 100)
			end
		end)
	end

	if CountdownActiveValue and CountdownActiveValue.Value then
		CountdownController.StartCountdown()
		if CountdownTimeValue then
			CountdownController.UpdateCountdownNumber(CountdownTimeValue.Value)
		end
	end

	LocalPlayer:GetAttributeChangedSignal("FTSessionId"):Connect(function()
		RefreshLocalCountdownState()
	end)
	LocalPlayer:GetAttributeChangedSignal(MatchPlayerUtils.GetMatchActiveAttributeName()):Connect(function()
		RefreshLocalCountdownState()
	end)

	local MatchFolder = GameState:FindFirstChild("Match")
	if MatchFolder then
		for _, teamFolder in MatchFolder:GetChildren() do
			for _, positionValue in teamFolder:GetChildren() do
				if positionValue:IsA("IntValue") then
					positionValue.Changed:Connect(function()
						RefreshLocalCountdownState()
					end)
				end
			end
		end
		MatchFolder.ChildAdded:Connect(function(child)
			if child:IsA("Folder") then
				for _, positionValue in child:GetChildren() do
					if positionValue:IsA("IntValue") then
						positionValue.Changed:Connect(function()
							RefreshLocalCountdownState()
						end)
					end
				end
			end
		end)
	end
end

function CountdownController.StartCountdown(): ()
	if IsCountdownActive then return end
	if not IsLocalPlayerInMatch() then return end
	IsCountdownActive = true
	GoSequenceActive = false
	
	SetGameGuiVisible(true)
	
	local countdownDuration = COUNTDOWN_DURATION
	if CountdownTimeValueRef then
		countdownDuration = math.max(1, CountdownTimeValueRef.Value)
	end
	WalkSpeedController.AddRequest(WALKSPEED_REQUEST_ID, 0, countdownDuration + 2, 100)
	StartLocalMovementFreeze()
	
	if not GameGui then
		local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if PlayerGui then
			GameGui = PlayerGui:FindFirstChild("GameGui") :: ScreenGui?
		end
	end
	
	if GameGui then
		EnsureCountdownLabelReady()
	end
end

function CountdownController.UpdateCountdownNumber(Number: number): ()
	if not IsLocalPlayerInMatch() then return end
	if not CountdownLabel then return end
	if not IsCountdownActive and Number > 0 then return end

	CountdownVisualToken += 1
	local visualToken: number = CountdownVisualToken
	
	if Number > 0 then
		AnimateNumberExit(CountdownLabel)
		
		task.delay(COUNTDOWN_NUMBER_SWAP_DELAY, function()
			if CountdownVisualToken ~= visualToken then return end
			if not CountdownLabel then return end
			if not IsCountdownActive then return end
			
			CountdownLabel.Text = tostring(Number)
			SoundController:Play("Countdown" .. tostring(Number))
			AnimateNumberEnter(CountdownLabel)
		end)
	else
		GoSequenceActive = true
		AnimateNumberExit(CountdownLabel)
		
		task.delay(COUNTDOWN_GO_SWAP_DELAY, function()
			if CountdownVisualToken ~= visualToken then return end
			if not CountdownLabel then return end
			if not GoSequenceActive then return end
			CountdownLabel.Text = "GO!"
			CountdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			AnimateNumberEnter(CountdownLabel)
			
			task.delay(COUNTDOWN_GO_DISPLAY_DURATION, function()
				if CountdownVisualToken ~= visualToken then return end
				if not GoSequenceActive then return end
				if CountdownLabel then
					AnimateNumberExit(CountdownLabel)
					task.delay(COUNTDOWN_GO_CLEANUP_DELAY, function()
						if CountdownVisualToken ~= visualToken then return end
						if not GoSequenceActive then return end
						CleanupCountdown()
					end)
				end
			end)
		end)
	end
end

function CountdownController.StopCountdown(): ()
	if not IsCountdownActive and not GoSequenceActive then
		return
	end
	StopLocalMovementFreeze()
	
	if GoSequenceActive and IsLocalPlayerInMatch() then
		IsCountdownActive = false
		task.delay(COUNTDOWN_GO_STOP_FALLBACK_DELAY, function()
			if GoSequenceActive then
				CleanupCountdown()
			end
		end)
		return
	end
	CleanupCountdown()
end

function CountdownController.ForceCleanupVisuals(): ()
	ForceCleanupLocalVisuals()
end

function CountdownController.CancelManualCountdown(): ()
	ManualCountdownToken += 1
	CleanupManualCountdown()
end

function CountdownController.PlayManualCountdown(StartNumber: number, Options: ManualCountdownOptions?): boolean
	if IsCountdownActive or GoSequenceActive then
		return false
	end
	if not IsLocalPlayerInMatch() then
		return false
	end

	local startValue = math.max(1, math.floor(StartNumber + 0.5))
	local interval = if Options and typeof(Options.Interval) == "number" then math.max(Options.Interval, 0.2) else 1
	local useBlur = if Options and Options.UseBlur ~= nil then Options.UseBlur else true
	local showGo = if Options and Options.ShowGo ~= nil then Options.ShowGo else false

	ManualCountdownToken += 1
	local token = ManualCountdownToken
	ManualCountdownActive = true

	SetGameGuiVisible(true)
	if not EnsureCountdownLabelReady() or not CountdownLabel then
		ManualCountdownActive = false
		return false
	end

	task.spawn(function()
		for value = startValue, 1, -1 do
			if token ~= ManualCountdownToken or not ManualCountdownActive or not CountdownLabel then
				return
			end

			CountdownLabel.Text = tostring(value)
			AnimateNumberEnter(CountdownLabel, useBlur)
			SoundController:Play("Countdown" .. tostring(value))
			task.wait(math.max(interval - 0.25, 0.05))
			if token ~= ManualCountdownToken or not ManualCountdownActive or not CountdownLabel then
				return
			end
			AnimateNumberExit(CountdownLabel, useBlur)
			task.wait(0.25)
		end

		if token ~= ManualCountdownToken or not ManualCountdownActive or not CountdownLabel then
			return
		end

		if showGo then
			CountdownLabel.Text = "GO!"
			AnimateNumberEnter(CountdownLabel, useBlur)
			task.wait(0.75)
			if token ~= ManualCountdownToken or not ManualCountdownActive or not CountdownLabel then
				return
			end
			AnimateNumberExit(CountdownLabel, useBlur)
			task.wait(0.25)
		end

		if token ~= ManualCountdownToken then
			return
		end
		CleanupManualCountdown()
	end)

	return true
end

function CountdownController.IsActive(): boolean
	return IsCountdownActive
end

function CountdownController.Notify(Text: string, Description: string?, Duration: number?): ()
	if not IsLocalPlayerInMatch() then return end
	NotifyToken += 1
	local token = NotifyToken

	SetGameGuiVisible(true)

	if not GameGui then
		local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if PlayerGui then
			GameGui = PlayerGui:FindFirstChild("GameGui") :: ScreenGui?
		end
	end
	if not GameGui then
		return
	end

	EnsureNotifyContainer()
	if not NotifyLabel then
		return
	end
    NotifyLabel.Text = Text
    NotifyLabel.TextColor3 = TEXT_COLOR
    NotifyLabel.TextTransparency = 1
    NotifyLabel.TextScaled = false
    NotifyLabel.TextSize = TEXT_SIZE * 0.3
    local notifyEnterTween = TweenService:Create(NotifyLabel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        TextTransparency = 0,
        TextSize = TEXT_SIZE,
    })
    notifyEnterTween:Play()
    local blur = GetOrCreateBlurEffect()
    TweenService:Create(blur, TWEEN_INFO_BLUR, { Size = 8 }):Play()

	if NotifyDescription then
		local descText = Description or ""
		if descText ~= "" then
			NotifyDescription.Visible = true
			NotifyDescription.Text = descText
			NotifyDescription.TextColor3 = TEXT_COLOR
			NotifyDescription.TextTransparency = 1
			TweenService:Create(NotifyDescription, TWEEN_INFO_ENTER, {TextTransparency = 0}):Play()
		else
			NotifyDescription.Visible = false
		end
	end

	local holdDuration = if Duration and Duration > 0 then Duration else NOTIFY_DEFAULT_DURATION
	task.delay(holdDuration, function()
		if NotifyToken ~= token then
			return
		end
		if not NotifyLabel then
			return
		end
		AnimateNumberExit(NotifyLabel)
		if NotifyDescription and NotifyDescription.Visible then
			TweenService:Create(NotifyDescription, TWEEN_INFO_EXIT, {TextTransparency = 1}):Play()
		end
		task.delay(0.3, function()
			if NotifyToken ~= token then
				return
			end
			CleanupNotifyLabel()
		end)
	end)
end

return CountdownController
