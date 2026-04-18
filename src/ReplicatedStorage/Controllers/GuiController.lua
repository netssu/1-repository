--!strict

local GuiController = {}

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local SoundController = require(ReplicatedStorage.Controllers.SoundController)
local FOVController = require(ReplicatedStorage.Controllers.FOVController)

local player: Player = Players.LocalPlayer
local playerGui: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local INFO: TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
local HOVER_INFO: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local ORNAMENT_INFO: TweenInfo = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ICON_SHAKE_INFO: TweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local ICON_RESET_INFO: TweenInfo = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_OFFSET_Y: number = -12
local ORNAMENT_EXPANDED_OFFSET_X: number = 5
local ORNAMENT_EXPANDED_SCALE: number = 1.04
local ORNAMENT_COLLAPSED_OFFSET_X: number = 2
local ORNAMENT_COLLAPSED_SCALE: number = 0.92
local ICON_SHAKE_ANGLE: number = 8
local ICON_SHAKE_OFFSET_X: number = 2
local ICON_SHAKE_SETTLE_MULTIPLIER: number = 0.45
local ICON_SHAKE_PAUSE_TIME: number = 0.65
local BLUR_SIZE: number = 15
local OPEN_FOV: number = 60
local DEFAULT_FOV: number = 70
local POSITION_SELECTION_ACTIVE_ATTRIBUTE = "FTPositionSelectionActive"
local IN_LOBBY_ATTRIBUTE = "FTIsInLobby"
local GUI_FOV_REQUEST_ID = "GuiController::OpenGui"
local INVENTORY_HOST_GUI_NAME = "Main"
local INVENTORY_TARGET_SIZE = UDim2.new(0.778, 0, 0.93, 0)
local INVENTORY_OPENED_POSITION = UDim2.new(0.5, 0, 0.5, 0)
local INVENTORY_PREOPEN_SCALE = 0.9
local INVENTORY_CLOSE_SCALE = 0.82
local INVENTORY_OPEN_OFFSET_Y = 26
local INVENTORY_CLOSE_OFFSET_Y = 18
local INVENTORY_OPEN_INFO = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local INVENTORY_CLOSE_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local MAIN_BUTTON_HOVER_INFO = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MAIN_BUTTON_RESET_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local MAIN_BUTTON_HOVER_SCALE = 1.04
local HUD_BOTTOM_HIDE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HUD_BOTTOM_SHOW_INFO = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local HUD_BOTTOM_OFFSET_Y = 34
local HUD_BOTTOM_COLLAPSED_SCALE = 0.94

local SYSTEM_GUIS: {[string]: boolean} = {
	HudGui = true,
	GameGui = true,
	LoadingGui = true,
	TeleportFadeGui = true,
	ExtraPointFadeGui = true,
	WaveTransitionGui = true,
	TouchdownWaveTransitionGui = true,
	Main = true,
}

local BLUR_IGNORED_GUIS: {[string]: boolean} = {
	InventoryGui = true,
	StatsGui = true,
	StylesGui = true,
	FlowGui = true,
}

type EmbeddedGuiConfig = {
	FrameName: string,
	OpenedPosition: UDim2?,
	TargetSize: UDim2?,
}

local EMBEDDED_GUI_CONFIGS: {[string]: EmbeddedGuiConfig} = {
	InventoryGui = {
		FrameName = "Inventory",
		OpenedPosition = INVENTORY_OPENED_POSITION,
		TargetSize = INVENTORY_TARGET_SIZE,
	},
	StatsGui = {
		FrameName = "Stats",
	},
	-- Adicione os seus tabs aqui:
	ShopGui = {
		FrameName = "ShopFrame",
	},
	Quests = {
		FrameName = "Quests",
	},
	SettingsGui = {
		FrameName = "SettingsFrame",
	}
	--[[
	FlowGui = {
		FrameName = "FlowGui",
	},
	StylesGui = {
		FrameName = "StylesGui",
	},
	]]
}

local EMBEDDED_CLOSE_BUTTON_NAMES = {
	"CloseBtn",
	"Close",
	"Exit",
	"CloseButton",
}

type GuiData = {
	OriginalSize: UDim2,
	OpenedPosition: UDim2,
}

type EmbeddedGuiData = {
	RootGui: ScreenGui,
	Frame: GuiObject,
	OpenedPosition: UDim2,
	TargetSize: UDim2,
}

type OrnamentData = {
	Instance: GuiObject,
	OriginalPosition: UDim2,
	OriginalSize: UDim2,
}

type IconData = {
	Instance: GuiObject,
	OriginalPosition: UDim2,
	OriginalRotation: number,
	LoopToken: number,
}

type HudButtonData = {
	LeftOrnament: OrnamentData?,
	RightOrnament: OrnamentData?,
	Icon: IconData?,
	OriginalPosition: UDim2,
	IsHovered: boolean,
}

type MainButtonData = {
	OriginalSize: UDim2,
}

type BottomFrameElementData = {
	OriginalPosition: UDim2,
	OriginalSize: UDim2,
}

GuiController._guis = {} :: {[string]: ScreenGui}
GuiController._guiData = {} :: {[string]: GuiData}
GuiController._currentGuiName = nil :: string?
GuiController._hudButtonsConnected = false
GuiController._hudButtonConnections = {} :: {[GuiButton]: {RBXScriptConnection}}
GuiController._hudButtonData = {} :: {[GuiButton]: HudButtonData}
GuiController._exitConnections = {} :: {[GuiButton]: RBXScriptConnection}
GuiController._mainButtonConnections = {} :: {[GuiButton]: {RBXScriptConnection}}
GuiController._mainButtonData = {} :: {[GuiButton]: MainButtonData}
GuiController._bottomFrameElements = {} :: {[GuiObject]: BottomFrameElementData}
GuiController._connections = {} :: {RBXScriptConnection}
GuiController._warnedMissing = {} :: {[string]: boolean}

local ActiveFrameTweens: {[GuiObject]: Tween} = {}
local ActiveHudTweens: {[Instance]: Tween} = {}
local scaleSize: (UDim2, number) -> UDim2

local function playSound(name: string, props: {[string]: any}?): ()
	if SoundController and SoundController.Play then
		SoundController:Play(name, props)
	end
end

local function ensureBlur(): BlurEffect
	local blur = Lighting:FindFirstChild("GuiBlur")
	if blur and blur:IsA("BlurEffect") then
		return blur
	end
	local newBlur = Instance.new("BlurEffect")
	newBlur.Name = "GuiBlur"
	newBlur.Size = 0
	newBlur.Parent = Lighting
	return newBlur
end

local function setVisuals(enableEffects: boolean, ignoreBlur: boolean?): ()
	local blur = ensureBlur()
	local targetBlur = (enableEffects and not ignoreBlur) and BLUR_SIZE or 0
	TweenService:Create(blur, INFO, { Size = targetBlur }):Play()

	local camera = workspace.CurrentCamera
	if camera then
		local targetFov = enableEffects and OPEN_FOV or DEFAULT_FOV
		if enableEffects then
			FOVController.AddRequest(GUI_FOV_REQUEST_ID, targetFov, nil, {
				TweenInfo = INFO,
			})
		else
			FOVController.RemoveRequest(GUI_FOV_REQUEST_ID)
		end
	end

	local hudGui = playerGui:FindFirstChild("HudGui")
	if hudGui and hudGui:IsA("ScreenGui") then
		local character = player.Character
		local positionSelectionActive = player:GetAttribute(POSITION_SELECTION_ACTIVE_ATTRIBUTE) == true
			or (character ~= nil and character:GetAttribute(POSITION_SELECTION_ACTIVE_ATTRIBUTE) == true)
		local inLobby = player:GetAttribute(IN_LOBBY_ATTRIBUTE) == true
			or (character ~= nil and character:GetAttribute(IN_LOBBY_ATTRIBUTE) == true)
		hudGui.Enabled = not enableEffects and not positionSelectionActive and inLobby
	end
end

local function playFrameTween(
	frame: GuiObject,
	goals: {[string]: any},
	onComplete: (() -> ())?,
	tweenInfo: TweenInfo?
): ()
	local runningTween = ActiveFrameTweens[frame]
	if runningTween then
		runningTween:Cancel()
	end

	local tween = TweenService:Create(frame, tweenInfo or INFO, goals)
	ActiveFrameTweens[frame] = tween

	tween.Completed:Once(function()
		if ActiveFrameTweens[frame] == tween then
			ActiveFrameTweens[frame] = nil
		end
		if onComplete then
			onComplete()
		end
	end)

	tween:Play()
end

local function getMainScreenGui(): ScreenGui?
	local mainGui = playerGui:FindFirstChild(INVENTORY_HOST_GUI_NAME)
	return if mainGui and mainGui:IsA("ScreenGui") then mainGui else nil
end

local function getEmbeddedGuiData(guiName: string): EmbeddedGuiData?
	local guiConfig = EMBEDDED_GUI_CONFIGS[guiName]
	if not guiConfig then
		return nil
	end

	local mainGui = getMainScreenGui()
	if not mainGui then
		return nil
	end

	local embeddedFrame = mainGui:FindFirstChild(guiConfig.FrameName)
		or mainGui:FindFirstChild(guiConfig.FrameName, true)
	if not embeddedFrame or not embeddedFrame:IsA("GuiObject") then
		return nil
	end

	return {
		RootGui = mainGui,
		Frame = embeddedFrame,
		OpenedPosition = guiConfig.OpenedPosition or embeddedFrame.Position,
		TargetSize = guiConfig.TargetSize or embeddedFrame.Size,
	}
end

local function findEmbeddedCloseButton(embeddedFrame: Instance?): GuiButton?
	if not embeddedFrame then
		return nil
	end

	local closeContainer = embeddedFrame:FindFirstChild("CloseBtn") or embeddedFrame:FindFirstChild("CloseBtn", true)
	if closeContainer then
		local closeButton = closeContainer:FindFirstChild("Btn") or closeContainer:FindFirstChild("Btn", true)
		if closeButton and closeButton:IsA("GuiButton") then
			return closeButton
		end

		for _, descendant in ipairs(closeContainer:GetDescendants()) do
			if descendant:IsA("GuiButton") then
				return descendant
			end
		end
	end

	for _, buttonName in ipairs(EMBEDDED_CLOSE_BUTTON_NAMES) do
		local fallback = embeddedFrame:FindFirstChild(buttonName, true)
		if fallback and fallback:IsA("GuiButton") then
			return fallback
		end
	end

	return nil
end

local function animateEmbeddedGuiOpen(guiData: EmbeddedGuiData): ()
	local frame = guiData.Frame
	frame.Size = scaleSize(guiData.TargetSize, INVENTORY_PREOPEN_SCALE)
	frame.Position = guiData.OpenedPosition + UDim2.fromOffset(0, INVENTORY_OPEN_OFFSET_Y)
	frame.Visible = true
	guiData.RootGui.Enabled = true

	playFrameTween(frame, {
		Size = guiData.TargetSize,
		Position = guiData.OpenedPosition,
	}, nil, INVENTORY_OPEN_INFO)
end

local function animateEmbeddedGuiClose(guiData: EmbeddedGuiData, onComplete: (() -> ())?): ()
	local frame = guiData.Frame
	playFrameTween(frame, {
		Size = scaleSize(guiData.TargetSize, INVENTORY_CLOSE_SCALE),
		Position = guiData.OpenedPosition + UDim2.fromOffset(0, INVENTORY_CLOSE_OFFSET_Y),
	}, function()
		frame.Visible = false
		if onComplete then
			onComplete()
		end
	end, INVENTORY_CLOSE_INFO)
end

local function playHudTween(target: Instance, info: TweenInfo, goals: {[string]: any}): Tween
	local runningTween = ActiveHudTweens[target]
	if runningTween then
		runningTween:Cancel()
	end

	local tween = TweenService:Create(target, info, goals)
	ActiveHudTweens[target] = tween

	tween.Completed:Once(function()
		if ActiveHudTweens[target] == tween then
			ActiveHudTweens[target] = nil
		end
	end)

	tween:Play()
	return tween
end

local function stopHudTween(target: Instance): ()
	local runningTween = ActiveHudTweens[target]
	if not runningTween then
		return
	end
	runningTween:Cancel()
	ActiveHudTweens[target] = nil
end

scaleSize = function(size: UDim2, factor: number): UDim2
	return UDim2.new(
		size.X.Scale * factor,
		math.round(size.X.Offset * factor),
		size.Y.Scale * factor,
		math.round(size.Y.Offset * factor)
	)
end

local function offsetPosition(position: UDim2, xOffset: number): UDim2
	return UDim2.new(position.X.Scale, position.X.Offset + xOffset, position.Y.Scale, position.Y.Offset)
end

local function normalizeGuiName(name: string): string
	return string.lower((name:gsub("[%s_%-]", "")))
end

local function resolveOrnament(background: Instance?, names: {string}): OrnamentData?
	if not background then
		return nil
	end

	for _, name in names do
		local ornament: Instance? = background:FindFirstChild(name) or background:FindFirstChild(name, true)
		if ornament and ornament:IsA("GuiObject") then
			return {
				Instance = ornament,
				OriginalPosition = ornament.Position,
				OriginalSize = ornament.Size,
			}
		end
	end

	local normalizedNames: {[string]: boolean} = {}
	for _, name in names do
		normalizedNames[normalizeGuiName(name)] = true
	end

	for _, descendant in background:GetDescendants() do
		if descendant:IsA("GuiObject") and normalizedNames[normalizeGuiName(descendant.Name)] then
			return {
				Instance = descendant,
				OriginalPosition = descendant.Position,
				OriginalSize = descendant.Size,
			}
		end
	end

	return nil
end

local function resolveHudIcon(background: Instance?): IconData?
	if not background then
		return nil
	end

	local icon = background:FindFirstChild("Icon") or background:FindFirstChild("Icon", true)
	if not icon or not icon:IsA("GuiObject") then
		return nil
	end

	return {
		Instance = icon,
		OriginalPosition = icon.Position,
		OriginalRotation = icon.Rotation,
		LoopToken = 0,
	}
end

local function animateOpen(gui: ScreenGui, guiData: GuiData): ()
	local mainFrame = gui:FindFirstChild("Main") :: GuiObject?
	if not mainFrame then
		gui.Enabled = true
		return
	end

	mainFrame.Size = UDim2.fromScale(0, 0)
	mainFrame.Position = UDim2.fromScale(guiData.OpenedPosition.X.Scale, 1.5)
	gui.Enabled = true

	playFrameTween(mainFrame, {
		Size = guiData.OriginalSize,
		Position = guiData.OpenedPosition,
	}, nil)
end

local function animateClose(gui: ScreenGui, guiData: GuiData): ()
	local mainFrame = gui:FindFirstChild("Main") :: GuiObject?
	if not mainFrame then
		gui.Enabled = false
		return
	end

	playFrameTween(mainFrame, {
		Size = UDim2.fromScale(0, 0),
		Position = UDim2.fromScale(guiData.OpenedPosition.X.Scale, 1.5),
	}, function()
		gui.Enabled = false
	end)
end

local function shouldManageGui(gui: ScreenGui): boolean
	if SYSTEM_GUIS[gui.Name] then
		return false
	end
	return CollectionService:HasTag(gui, "Gui") or gui:FindFirstChild("Main") ~= nil
end

local function shouldIgnoreBlur(guiName: string): boolean
	return BLUR_IGNORED_GUIS[guiName] == true
end

function GuiController.Init(self: GuiController): ()
	self.GuiOpened = Signal.new()
	self.GuiClosed = Signal.new()
end

function GuiController:_refreshHudButtonVisual(button: GuiButton, instant: boolean?): ()
	local buttonData = self._hudButtonData[button]
	if not buttonData then
		return
	end
	local expanded = buttonData.IsHovered or self._currentGuiName == button.Name

	local function animateOrnament(ornamentData: OrnamentData?, direction: number): ()
		if not ornamentData or ornamentData.Instance.Parent == nil then
			return
		end

		local targetPosition: UDim2
		local targetSize: UDim2
		if expanded then
			targetPosition = offsetPosition(ornamentData.OriginalPosition, ORNAMENT_EXPANDED_OFFSET_X * direction)
			targetSize = scaleSize(ornamentData.OriginalSize, ORNAMENT_EXPANDED_SCALE)
		else
			targetPosition = offsetPosition(ornamentData.OriginalPosition, -ORNAMENT_COLLAPSED_OFFSET_X * direction)
			targetSize = scaleSize(ornamentData.OriginalSize, ORNAMENT_COLLAPSED_SCALE)
		end

		if instant then
			stopHudTween(ornamentData.Instance)
			ornamentData.Instance.Position = targetPosition
			ornamentData.Instance.Size = targetSize
		else
			playHudTween(ornamentData.Instance, ORNAMENT_INFO, {
				Position = targetPosition,
				Size = targetSize,
			})
		end
	end

	animateOrnament(buttonData.LeftOrnament, -1)
	animateOrnament(buttonData.RightOrnament, 1)
end

function GuiController:_resetHudButtonIcon(buttonData: HudButtonData, instant: boolean?): ()
	local iconData = buttonData.Icon
	if not iconData or iconData.Instance.Parent == nil then
		return
	end

	if instant then
		stopHudTween(iconData.Instance)
		iconData.Instance.Position = iconData.OriginalPosition
		iconData.Instance.Rotation = iconData.OriginalRotation
		return
	end

	playHudTween(iconData.Instance, ICON_RESET_INFO, {
		Position = iconData.OriginalPosition,
		Rotation = iconData.OriginalRotation,
	})
end

function GuiController:_startHudButtonIconShake(button: GuiButton): ()
	local buttonData = self._hudButtonData[button]
	if not buttonData then
		return
	end

	local iconData = buttonData.Icon
	if not iconData or iconData.Instance.Parent == nil then
		return
	end

	iconData.LoopToken += 1
	local loopToken = iconData.LoopToken

	task.spawn(function()
		local function playShakeStep(rotationOffset: number, positionOffset: number): boolean
			if iconData.LoopToken ~= loopToken or not buttonData.IsHovered or button.Parent == nil then
				return false
			end

			local tween = playHudTween(iconData.Instance, ICON_SHAKE_INFO, {
				Position = offsetPosition(iconData.OriginalPosition, positionOffset),
				Rotation = iconData.OriginalRotation + rotationOffset,
			})
			tween.Completed:Wait()

			return iconData.LoopToken == loopToken and buttonData.IsHovered and button.Parent ~= nil
		end

		while iconData.LoopToken == loopToken and buttonData.IsHovered and button.Parent ~= nil do
			if not playShakeStep(-ICON_SHAKE_ANGLE, -ICON_SHAKE_OFFSET_X) then
				break
			end
			if not playShakeStep(ICON_SHAKE_ANGLE, ICON_SHAKE_OFFSET_X) then
				break
			end
			if not playShakeStep(
				-ICON_SHAKE_ANGLE * ICON_SHAKE_SETTLE_MULTIPLIER,
				-ICON_SHAKE_OFFSET_X * ICON_SHAKE_SETTLE_MULTIPLIER
			) then
				break
			end
			if not playShakeStep(
				ICON_SHAKE_ANGLE * ICON_SHAKE_SETTLE_MULTIPLIER,
				ICON_SHAKE_OFFSET_X * ICON_SHAKE_SETTLE_MULTIPLIER
			) then
				break
			end

			local resetTween = playHudTween(iconData.Instance, ICON_RESET_INFO, {
				Position = iconData.OriginalPosition,
				Rotation = iconData.OriginalRotation,
			})
			resetTween.Completed:Wait()
			if iconData.LoopToken ~= loopToken or not buttonData.IsHovered or button.Parent == nil then
				break
			end

			local pauseDeadline = os.clock() + ICON_SHAKE_PAUSE_TIME
			while iconData.LoopToken == loopToken and buttonData.IsHovered and button.Parent ~= nil and os.clock() < pauseDeadline do
				task.wait()
			end
		end

		if iconData.LoopToken ~= loopToken then
			return
		end
		self:_resetHudButtonIcon(buttonData)
	end)
end

function GuiController:_clearHudButtonHover(button: GuiButton, instant: boolean?): ()
	local buttonData = self._hudButtonData[button]
	if not buttonData then
		return
	end
	local originalPosition = buttonData.OriginalPosition

	buttonData.IsHovered = false
	if buttonData.Icon then
		buttonData.Icon.LoopToken += 1
	end
	self:_resetHudButtonIcon(buttonData, instant)

	if instant then
		stopHudTween(button)
		button.Position = originalPosition
	else
		playHudTween(button, HOVER_INFO, { Position = originalPosition })
	end

	self:_refreshHudButtonVisual(button, instant)
end

function GuiController:_clearAllHudButtonHover(instant: boolean?): ()
	for button in self._hudButtonData do
		if button.Parent == nil then
			self._hudButtonData[button] = nil
		else
			self:_clearHudButtonHover(button, instant)
		end
	end
end

function GuiController:_syncHudButtonSelection(): ()
	for button in self._hudButtonData do
		if button.Parent == nil then
			self._hudButtonData[button] = nil
		else
			self:_refreshHudButtonVisual(button)
		end
	end
end

function GuiController:_resetMainButton(button: GuiButton, instant: boolean?): ()
	local buttonData = self._mainButtonData[button]
	if not buttonData then
		return
	end

	if instant then
		stopHudTween(button)
		button.Size = buttonData.OriginalSize
		return
	end

	playHudTween(button, MAIN_BUTTON_RESET_INFO, {
		Size = buttonData.OriginalSize,
	})
end

function GuiController:_registerMainButton(button: GuiButton): ()
	if self._mainButtonConnections[button] then
		return
	end

	self._mainButtonData[button] = {
		OriginalSize = button.Size,
	}

	local conns: {RBXScriptConnection} = {}
	table.insert(conns, button.MouseEnter:Connect(function()
		local buttonData = self._mainButtonData[button]
		if not buttonData then
			return
		end
		SoundController:PlayUiHover()
		playHudTween(button, MAIN_BUTTON_HOVER_INFO, {
			Size = scaleSize(buttonData.OriginalSize, MAIN_BUTTON_HOVER_SCALE),
		})
	end))
	table.insert(conns, button.MouseLeave:Connect(function()
		self:_resetMainButton(button)
	end))
	table.insert(conns, button:GetPropertyChangedSignal("Visible"):Connect(function()
		if not button.Visible then
			self:_resetMainButton(button, true)
		end
	end))
	table.insert(conns, button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then
			self:_resetMainButton(button, true)
		end
	end))
	table.insert(conns, button.AncestryChanged:Connect(function()
		if button.Parent == nil then
			self:_resetMainButton(button, true)
		end
	end))

	self._mainButtonConnections[button] = conns
	self:_resetMainButton(button, true)
end

function GuiController:_connectMainButtons(): ()
	local mainGui = getMainScreenGui()
	if not mainGui then
		return
	end

	for _, descendant in ipairs(mainGui:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			self:_registerMainButton(descendant)
		end
	end
end

function GuiController:_connectEmbeddedCloseButtons(): ()
	for guiName, _ in pairs(EMBEDDED_GUI_CONFIGS) do
		local embeddedGuiData = getEmbeddedGuiData(guiName)
		if not embeddedGuiData then
			continue
		end

		local closeButton = findEmbeddedCloseButton(embeddedGuiData.Frame)
		if not closeButton then
			continue
		end

		self:_registerMainButton(closeButton)
		if self._exitConnections[closeButton] then
			continue
		end

		self._exitConnections[closeButton] = closeButton.Activated:Connect(function()
			playSound("SoundClick", { Pitch = true })
			self:Close(guiName)
		end)
	end
end

function GuiController:_getHudBottomFrameElements(bottomFrame: GuiObject): {GuiObject}
	local elements = {}
	for _, child in ipairs(bottomFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			if not self._bottomFrameElements[child] then
				self._bottomFrameElements[child] = {
					OriginalPosition = child.Position,
					OriginalSize = child.Size,
				}
			end
			table.insert(elements, child)
		end
	end
	return elements
end

function GuiController:_animateHudBottomFrame(show: boolean, onComplete: (() -> ())?): ()
	local hudGui = playerGui:FindFirstChild("HudGui")
	if not hudGui or not hudGui:IsA("ScreenGui") then
		if onComplete then
			onComplete()
		end
		return
	end

	local bottomFrame = hudGui:FindFirstChild("BottomFrame")
	if not bottomFrame or not bottomFrame:IsA("GuiObject") then
		if onComplete then
			onComplete()
		end
		return
	end

	local elements = self:_getHudBottomFrameElements(bottomFrame)
	if #elements == 0 then
		if onComplete then
			onComplete()
		end
		return
	end

	if show then
		if not hudGui.Enabled then
			if onComplete then
				onComplete()
			end
			return
		end
	elseif not hudGui.Enabled then
		if onComplete then
			onComplete()
		end
		return
	end

	local remaining = #elements
	local function markCompleted(): ()
		remaining -= 1
		if remaining <= 0 and onComplete then
			onComplete()
		end
	end

	for _, element in ipairs(elements) do
		local elementData = self._bottomFrameElements[element]
		if not elementData or element.Parent == nil then
			markCompleted()
			continue
		end

		local collapsedPosition = elementData.OriginalPosition + UDim2.fromOffset(0, HUD_BOTTOM_OFFSET_Y)
		local collapsedSize = scaleSize(elementData.OriginalSize, HUD_BOTTOM_COLLAPSED_SCALE)
		local tween: Tween
		if show then
			stopHudTween(element)
			element.Position = collapsedPosition
			element.Size = collapsedSize
			tween = playHudTween(element, HUD_BOTTOM_SHOW_INFO, {
				Position = elementData.OriginalPosition,
				Size = elementData.OriginalSize,
			})
		else
			tween = playHudTween(element, HUD_BOTTOM_HIDE_INFO, {
				Position = collapsedPosition,
				Size = collapsedSize,
			})
		end
		tween.Completed:Once(markCompleted)
	end
end

function GuiController:_registerHudButton(button: GuiButton): ()
	if self._hudButtonConnections[button] then
		return
	end

	local originalPos = button.Position
	local background = button:FindFirstChild("Background")
	self._hudButtonData[button] = {
		LeftOrnament = resolveOrnament(background, { "Orenament2", "Ornament2" }),
		RightOrnament = resolveOrnament(background, { "Orenament", "Ornament" }),
		Icon = resolveHudIcon(background),
		OriginalPosition = originalPos,
		IsHovered = false,
	}
	local conns: {RBXScriptConnection} = {}

	table.insert(conns, button.Activated:Connect(function()
		self:_clearHudButtonHover(button, true)
		playSound("SoundClick", { Pitch = true })
		self:Toggle(button.Name)
	end))

	table.insert(conns, button.MouseEnter:Connect(function()
		local buttonData = self._hudButtonData[button]
		if buttonData then
			buttonData.IsHovered = true
		end
		SoundController:PlayUiHover()
		playHudTween(button, HOVER_INFO, {
			Position = originalPos + UDim2.fromOffset(0, HOVER_OFFSET_Y),
		})
		self:_refreshHudButtonVisual(button)
		self:_startHudButtonIconShake(button)
	end))

	table.insert(conns, button.MouseLeave:Connect(function()
		self:_clearHudButtonHover(button)
	end))

	table.insert(conns, button:GetPropertyChangedSignal("Visible"):Connect(function()
		if not button.Visible then
			self:_clearHudButtonHover(button, true)
		end
	end))

	table.insert(conns, button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if button.AbsoluteSize.X <= 0 or button.AbsoluteSize.Y <= 0 then
			self:_clearHudButtonHover(button, true)
		end
	end))

	table.insert(conns, button.AncestryChanged:Connect(function()
		if button.Parent == nil then
			self:_clearHudButtonHover(button, true)
		end
	end))

	self._hudButtonConnections[button] = conns
	self:_refreshHudButtonVisual(button, true)
	local buttonData = self._hudButtonData[button]
	if buttonData then
		self:_resetHudButtonIcon(buttonData, true)
	end
end

function GuiController:_connectHudButtons(): ()
	if self._hudButtonsConnected then
		return
	end

	local hudGui = playerGui:WaitForChild("HudGui", 10)
	if not hudGui or not hudGui:IsA("ScreenGui") then
		return
	end

	local bottomFrame = hudGui:WaitForChild("BottomFrame", 10)
	if not bottomFrame then
		return
	end

	for _, child in ipairs(bottomFrame:GetChildren()) do
		if child:IsA("GuiButton") then
			self:_registerHudButton(child)
		end
	end

	table.insert(self._connections, bottomFrame.ChildAdded:Connect(function(child)
		if child:IsA("GuiButton") then
			self:_registerHudButton(child)
		end
	end))

	self._hudButtonsConnected = true
end

function GuiController:_connectExitButtons(gui: ScreenGui): ()
	local main = gui:FindFirstChild("Main")
	if not main then
		return
	end

	for _, instance in ipairs(main:GetDescendants()) do
		if instance:IsA("GuiButton") and instance.Name == "Exit" and not self._exitConnections[instance] then
			self._exitConnections[instance] = instance.Activated:Connect(function()
				playSound("SoundClick", { Pitch = true })
				self:Close(gui.Name)
			end)
		end
	end
end

function GuiController:_removeGui(guiName: string): ()
	self._guis[guiName] = nil
	self._guiData[guiName] = nil
	self._warnedMissing[guiName] = nil

	if self._currentGuiName == guiName then
		self._currentGuiName = nil
		setVisuals(false)
		self:_syncHudButtonSelection()
		self.GuiClosed:Fire(guiName)
	end
end

function GuiController.Start(self: GuiController): ()
	ensureBlur()

	table.insert(self._connections, CollectionService:GetInstanceAddedSignal("Gui"):Connect(function(instance)
		if instance:IsA("ScreenGui") then
			self:AddGui(instance)
		end
	end))

	table.insert(self._connections, playerGui.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") then
			self:AddGui(child)
		end
		if child.Name == "HudGui" and child:IsA("ScreenGui") then
			task.defer(function()
				self:_connectHudButtons()
			end)
		end
		if child.Name == INVENTORY_HOST_GUI_NAME and child:IsA("ScreenGui") then
			task.defer(function()
				self:_connectMainButtons()
				self:_connectEmbeddedCloseButtons()
			end)
		end
	end))

	table.insert(self._connections, playerGui.ChildRemoved:Connect(function(child)
		if child:IsA("ScreenGui") then
			self:_removeGui(child.Name)
		end
	end))

	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			self:AddGui(child)
		end
	end

	self:_connectHudButtons()
	self:_connectMainButtons()
	self:_connectEmbeddedCloseButtons()
end

function GuiController.AddGui(self: GuiController, gui: ScreenGui): ()
	if gui.Parent ~= playerGui then
		return
	end
	if not shouldManageGui(gui) then
		return
	end

	self._guis[gui.Name] = gui
	self._warnedMissing[gui.Name] = nil

	local mainFrame = gui:FindFirstChild("Main")
	if mainFrame and mainFrame:IsA("GuiObject") then
		self._guiData[gui.Name] = {
			OriginalSize = mainFrame.Size,
			OpenedPosition = mainFrame.Position,
		}
		self:_connectExitButtons(gui)
	else
		self._guiData[gui.Name] = nil
	end

	if self._currentGuiName ~= gui.Name then
		gui.Enabled = false
	end
end

function GuiController.Open(self: GuiController, guiName: string): (ScreenGui?)
	if EMBEDDED_GUI_CONFIGS[guiName] then
		local embeddedGuiData = getEmbeddedGuiData(guiName)
		if not embeddedGuiData then
			if not self._warnedMissing[guiName] then
				self._warnedMissing[guiName] = true
				warn(`[GuiController]: No embedded gui found with name "{guiName}".`)
			end
			return nil
		end
		self._warnedMissing[guiName] = nil

		if self._currentGuiName == guiName then
			return nil
		end

		if self._currentGuiName then
			self:Close(self._currentGuiName :: string, true) 
		end

		self:_connectMainButtons()
		self:_connectEmbeddedCloseButtons()
		self:_clearAllHudButtonHover(true)
		self._currentGuiName = guiName
		self:_syncHudButtonSelection()

		self:_animateHudBottomFrame(false, function()
			setVisuals(true, shouldIgnoreBlur(guiName))
			animateEmbeddedGuiOpen(embeddedGuiData)
		end)

		self.GuiOpened:Fire(guiName)
		return embeddedGuiData.RootGui
	end

	local gui = self._guis[guiName]
	if not gui or gui.Parent ~= playerGui then
		if not self._warnedMissing[guiName] then
			self._warnedMissing[guiName] = true
			warn(`[GuiController]: No Gui found with name "{guiName}".`)
		end
		return nil
	end
	self._warnedMissing[guiName] = nil

	if self._currentGuiName == guiName then
		return nil
	end

	if self._currentGuiName then
		self:Close(self._currentGuiName :: string, true)
	end

	self:_clearAllHudButtonHover(true)
	setVisuals(true, shouldIgnoreBlur(guiName))
	self._currentGuiName = guiName
	self:_syncHudButtonSelection()

	local guiData = self._guiData[guiName]
	if guiData then
		animateOpen(gui, guiData)
	else
		gui.Enabled = true
	end

	self.GuiOpened:Fire(guiName)
	return gui
end

function GuiController.Close(self: GuiController, guiName: string, suppressBottomFrame: boolean?): ()
	warn('SUPPRESS BOTTOM FRAME IS ', suppressBottomFrame)
	if EMBEDDED_GUI_CONFIGS[guiName] then
		local embeddedGuiData = getEmbeddedGuiData(guiName)
		local wasCurrent = self._currentGuiName == guiName
		local wasEnabled = embeddedGuiData ~= nil and embeddedGuiData.Frame.Visible

		if not embeddedGuiData then
			if wasCurrent then
				self._currentGuiName = nil
				setVisuals(false)
				if not suppressBottomFrame then
					self:_animateHudBottomFrame(true, nil)
					self:_syncHudButtonSelection()
				end
				
				self.GuiClosed:Fire(guiName)
			elseif not self._warnedMissing[guiName] then
				self._warnedMissing[guiName] = true
				warn(`[GuiController]: No embedded gui found with name "{guiName}" to close.`)
			end
			return
		end
		self._warnedMissing[guiName] = nil

		self:_clearAllHudButtonHover(true)
		if wasEnabled then
			if suppressBottomFrame then
				-- troca de GUI: fecha instantaneamente sem animação nem callbacks
				embeddedGuiData.Frame.Visible = false
			else
				animateEmbeddedGuiClose(embeddedGuiData, function()
					setVisuals(false)
					self:_animateHudBottomFrame(true, nil)
				end)
			end
		end

		if wasCurrent then
			self._currentGuiName = nil
			self:_syncHudButtonSelection()
			if not wasEnabled then
				setVisuals(false)
				if not suppressBottomFrame then
					self:_animateHudBottomFrame(true, nil)
				end
			end
		end

		if wasEnabled or wasCurrent then
			self.GuiClosed:Fire(guiName)
		end
		return
	end

	local gui = self._guis[guiName]
	local wasCurrent = self._currentGuiName == guiName
	local wasEnabled = gui and gui.Enabled or false

	if not gui then
		if wasCurrent then
			self._currentGuiName = nil
			setVisuals(false)
			self:_syncHudButtonSelection()
			self.GuiClosed:Fire(guiName)
		elseif not self._warnedMissing[guiName] then
			self._warnedMissing[guiName] = true
			warn(`[GuiController]: No Gui found with name "{guiName}" to close.`)
		end
		return
	end
	self._warnedMissing[guiName] = nil

	self:_clearAllHudButtonHover(true)
	local guiData = self._guiData[guiName]
	if wasEnabled then
		if guiData then
			animateClose(gui, guiData)
		else
			gui.Enabled = false
		end
	end

	if wasCurrent then
		self._currentGuiName = nil
		setVisuals(false)
		self:_syncHudButtonSelection()
	end

	if wasEnabled or wasCurrent then
		self.GuiClosed:Fire(guiName)
	end
end

function GuiController.Toggle(self: GuiController, guiName: string): ()
	if self._currentGuiName == guiName then
		self:Close(guiName)
	else
		self:Open(guiName)
	end
end

type GuiController = typeof(GuiController) & {
	GuiOpened: Signal.Signal<string>,
	GuiClosed: Signal.Signal<string>,
	_guis: {[string]: ScreenGui},
	_guiData: {[string]: GuiData},
	_currentGuiName: string?,
	_hudButtonsConnected: boolean,
	_hudButtonConnections: {[GuiButton]: {RBXScriptConnection}},
	_hudButtonData: {[GuiButton]: HudButtonData},
	_exitConnections: {[GuiButton]: RBXScriptConnection},
	_mainButtonConnections: {[GuiButton]: {RBXScriptConnection}},
	_mainButtonData: {[GuiButton]: MainButtonData},
	_bottomFrameElements: {[GuiObject]: BottomFrameElementData},
	_connections: {RBXScriptConnection},
	_warnedMissing: {[string]: boolean},
}

return GuiController :: GuiController
