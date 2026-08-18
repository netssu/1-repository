# UI Controller Modularization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the UI Controller hold no hardcoded UI-instance references — drive all config through setters, split the default open/close menu animation into its own module, support per-section custom `SetOpen`/`SetClose`, and close the previously-open section with its proper close animation on swap.

**Architecture:** A new `Controller/DefaultTransition.luau` owns the default per-section scale animation plus the ambient menu effect (a `BlurEffect` it creates in `Lighting`, and FOV tween). The rewritten `Controller/init.luau` is a pure orchestrator: setters inject root/sections/hide-frames/hotkeys/callbacks/containers, an animation resolver returns the per-section custom animation or the default, and Open/Close/swap route through it. Ambient is raised on first open and lowered on last close so swaps don't flicker the blur.

**Tech Stack:** Roblox Luau, Rojo project, `Signal` package, existing `GuiClass` (`src/Shared/Classes/Gui`), `TweenFov` and `Utils` modules. Verification via Roblox Studio MCP (no headless Luau test runner exists in this repo).

## Global Constraints

- Private fields start with underscore `_`.
- No comments in code unless explaining non-obvious rationale.
- Descriptive function names; no magic numbers — use named constants.
- No deprecated Roblox/Luau APIs.
- Only two files change: `src/Shared/UI/Controller/init.luau` (rewrite) and `src/Shared/UI/Controller/DefaultTransition.luau` (new). Do NOT modify `src/Shared/UI/init.luau` or any consumer; the user wires the bootstrap.
- Custom animation contract: `fn(section: GuiObject) -> { Ended: Signal }`.
- `DefaultTransition` is a child ModuleScript of the Controller ModuleScript; require it from `init.luau` as `require(script.DefaultTransition)`.
- Verification requires Roblox Studio open with this place synced via Rojo, driven through the `Roblox_Studio` MCP tools (`execute_luau`, `get_console_output`). If Studio is unavailable, fall back to reading the diff for correctness and note that runtime smoke was skipped.

---

### Task 1: DefaultTransition module

**Files:**
- Create: `src/Shared/UI/Controller/DefaultTransition.luau`

**Interfaces:**
- Consumes: `ReplicatedStorage.Packages.Signal` (`Signal.new()` → has `:Fire()`, `:Destroy()`, `:Once(fn)`), `ReplicatedStorage.Shared.Modules.TweenFov` (`TweenFov:TweenTo(fov: number, tweenInfo: TweenInfo)`).
- Produces:
  - `:Open(section: GuiObject) -> { Ended: Signal }` — scales section `Scale` UIScale 0→1.
  - `:Close(section: GuiObject) -> { Ended: Signal }` — scales section `Scale` UIScale →0.
  - `:RaiseAmbient(section: GuiObject)` — FOV→open, blur→size (unless section name disabled).
  - `:LowerAmbient()` — FOV→close, blur→0.
  - `:SetOpenFov(n: number)`, `:SetCloseFov(n: number)`, `:SetBlurSize(n: number)`, `:DisableBlurFor(names: { string })`.

- [ ] **Step 1: Write the module file**

Create `src/Shared/UI/Controller/DefaultTransition.luau`:

```lua
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local TweenFov = require(ReplicatedStorage.Shared.Modules.TweenFov)

local DEFAULT_OPEN_FOV = 80
local DEFAULT_CLOSE_FOV = 70
local DEFAULT_BLUR_SIZE = 20
local TRANSITION_TIME = 0.3
local BLUR_NAME = "MenuBlur"

local OPEN_TWEEN_INFO = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN_INFO = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local AMBIENT_TWEEN_INFO = TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local module = {}

module._openFov = DEFAULT_OPEN_FOV
module._closeFov = DEFAULT_CLOSE_FOV
module._blurSize = DEFAULT_BLUR_SIZE
module._noBlurFor = {} :: { [string]: boolean }
module._sectionTweens = {} :: { [GuiObject]: Tween }
module._blurTween = nil :: Tween?

local function getOrCreateBlur(): BlurEffect
	local existing = Lighting:FindFirstChild(BLUR_NAME)
	if existing and existing:IsA("BlurEffect") then
		return existing
	end

	local blur = Instance.new("BlurEffect")
	blur.Name = BLUR_NAME
	blur.Size = 0
	blur.Enabled = true
	blur.Parent = Lighting
	return blur
end

module._blur = getOrCreateBlur()

local function ensureScale(section: GuiObject): UIScale
	local scale = section:FindFirstChild("Scale")
	if scale and scale:IsA("UIScale") then
		return scale
	end

	local newScale = Instance.new("UIScale")
	newScale.Name = "Scale"
	newScale.Scale = 1
	newScale.Parent = section
	return newScale
end

local function cancelSectionTween(section: GuiObject)
	local existing = module._sectionTweens[section]
	if existing then
		existing:Cancel()
		module._sectionTweens[section] = nil
	end
end

local function runScaleTween(section: GuiObject, tweenInfo: TweenInfo, targetScale: number)
	local animation = { Ended = Signal.new() }

	local scale = section:FindFirstChild("Scale")
	if not (scale and scale:IsA("UIScale")) then
		if targetScale == 0 then
			task.defer(function()
				animation.Ended:Fire()
				animation.Ended:Destroy()
			end)
			return animation
		end
		scale = ensureScale(section)
	end

	if targetScale == 1 then
		scale.Scale = 0
	end

	cancelSectionTween(section)

	local tween = TweenService:Create(scale, tweenInfo, { Scale = targetScale })
	module._sectionTweens[section] = tween

	tween.Completed:Once(function()
		if module._sectionTweens[section] == tween then
			module._sectionTweens[section] = nil
		end
		animation.Ended:Fire()
		animation.Ended:Destroy()
	end)

	tween:Play()
	return animation
end

local function tweenBlur(targetSize: number)
	if module._blurTween then
		module._blurTween:Cancel()
		module._blurTween = nil
	end

	if module._blur and module._blur.Parent then
		local tween = TweenService:Create(module._blur, AMBIENT_TWEEN_INFO, { Size = targetSize })
		module._blurTween = tween
		tween:Play()
	end
end

function module:SetOpenFov(fov: number)
	self._openFov = fov
end

function module:SetCloseFov(fov: number)
	self._closeFov = fov
end

function module:SetBlurSize(size: number)
	self._blurSize = size
end

function module:DisableBlurFor(names: { string })
	for _, name in names or {} do
		self._noBlurFor[name] = true
	end
end

function module:Open(section: GuiObject)
	return runScaleTween(section, OPEN_TWEEN_INFO, 1)
end

function module:Close(section: GuiObject)
	return runScaleTween(section, CLOSE_TWEEN_INFO, 0)
end

function module:RaiseAmbient(section: GuiObject)
	TweenFov:TweenTo(self._openFov, AMBIENT_TWEEN_INFO)

	if section and self._noBlurFor[section.Name] then
		return
	end

	tweenBlur(self._blurSize)
end

function module:LowerAmbient()
	TweenFov:TweenTo(self._closeFov, AMBIENT_TWEEN_INFO)
	tweenBlur(0)
end

return module
```

- [ ] **Step 2: Smoke-test in Studio**

With Studio open and the place synced, run via the `Roblox_Studio` MCP `execute_luau`:

```lua
local DefaultTransition = require(game.ReplicatedStorage.Shared.UI.Controller.DefaultTransition)
local gui = Instance.new("ScreenGui")
gui.Parent = game.Players.LocalPlayer.PlayerGui
local frame = Instance.new("Frame")
frame.Size = UDim2.fromScale(0.4, 0.4)
frame.Position = UDim2.fromScale(0.3, 0.3)
frame.Parent = gui

local opened = DefaultTransition:Open(frame)
DefaultTransition:RaiseAmbient(frame)
opened.Ended:Once(function() print("OPEN ENDED, scale:", frame.Scale.Scale) end)
task.wait(0.5)
print("MenuBlur exists:", game.Lighting:FindFirstChild("MenuBlur") ~= nil, "size:", game.Lighting.MenuBlur.Size)
local closed = DefaultTransition:Close(frame)
DefaultTransition:LowerAmbient()
closed.Ended:Once(function() print("CLOSE ENDED, scale:", frame.Scale.Scale) end)
task.wait(0.5)
gui:Destroy()
print("DEFAULTTRANSITION SMOKE OK")
```

Then read `get_console_output`.
Expected: prints `OPEN ENDED, scale: 1`, `MenuBlur exists: true size:` ~20, `CLOSE ENDED, scale: 0`, `DEFAULTTRANSITION SMOKE OK`, and no errors. (Path is `ReplicatedStorage.Shared.UI.Controller.DefaultTransition` because the project maps `src/Shared` → `ReplicatedStorage.Shared`.)

- [ ] **Step 3: Commit**

```bash
git add src/Shared/UI/Controller/DefaultTransition.luau
git commit -m "feat: add DefaultTransition module for UI Controller"
```

---

### Task 2: Rewrite Controller as a setter-driven orchestrator

**Files:**
- Modify (full rewrite): `src/Shared/UI/Controller/init.luau`

**Interfaces:**
- Consumes (from Task 1): `require(script.DefaultTransition)` exposing `:Open`, `:Close`, `:RaiseAmbient`, `:LowerAmbient`, `:DisableBlurFor`, `:SetOpenFov`, `:SetCloseFov`, `:SetBlurSize`.
- Consumes (existing): `GuiClass:CreateHideObject(map) -> { Hide, Show }`, `GuiClass:CreateButton`, `GuiClass:LoadFrame`, `GuiClass:CreateFloatingAnimation`, `GuiClass.CreateWaveGradient`, `Utils:GetChildrenOfInstances(...)`, `Signal.new()`.
- Produces (public API consumed by the user's bootstrap):
  - Setters: `:SetRoot(root)`, `:SetSectionsContainer(c)`, `:SetHideFrames({[GuiObject]=UDim2})`, `:SetHotkeys({[string]={KeyCode}})`, `:SetSectionNameOverrides({[string]=string})`, `:SetOpenCallback(name, fn)`, `:SetCloseCallback(name, fn)`, `:RegisterButtonContainer(frame)`, `:SetButtonContainers({frame})`, `:RegisterLoadAnimation(name, {GuiObject})`, `:RegisterFloatingIcon(icon, options?)`, `:SetNoBlurFor({string})`, `:SetOpen(section, fn)`, `:SetClose(section, fn)`.
  - Behavior: `:init()`, `:Open(frame, load?)`, `:Close(frame)`, `:Toggle(frame)`, `:OpenWithReturn(frame, opener)`, `:ClearReturn(frame)`, `:HideGuis(closeSections?)`, `:ShowGuis()`, `:MatchFrame(button)`, `:AddFunctions(button)`, `:AddSectionFunctions(section)`, `:BindIsolatedFrames`, `:UnbindIsolatedFrames`, `:SetGuisOpenable(bool)`, `:GetOpenedUi()`, `:IsAnyMenuOpen()`.
  - `module.DefaultTransition` exposed for FOV/blur tuning.

- [ ] **Step 1: Replace the file contents**

Overwrite `src/Shared/UI/Controller/init.luau` with:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Signal = require(ReplicatedStorage.Packages.Signal)
local GuiClass = require(ReplicatedStorage.Shared.Classes.Gui)
local Utils = require(ReplicatedStorage.Shared.Modules.Utils)
local DefaultTransition = require(script.DefaultTransition)

local ISOLATED_RESTORE_DELAY = 0.3
local LOAD_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ICON_HOVER_TWEEN_INFO = TweenInfo.new(0.2)
local ICON_HOVER_ANGLE = 15

local module = {}
module.GuisHidden = false
module.GuisOpenable = true
module.DefaultTransition = DefaultTransition

module._root = nil :: Instance?
module._sectionsContainer = nil :: Instance?
module._hideFrames = {} :: { [GuiObject]: UDim2 }
module._hideGuiObj = nil
module._hotkeys = {} :: { [string]: { Enum.KeyCode } }
module._nameOverrides = {} :: { [string]: string }
module._openCallbacks = {} :: { [string]: () -> () }
module._closeCallbacks = {} :: { [string]: () -> () }
module._buttonContainers = {} :: { Instance }
module._loadAnimations = {} :: { [string]: { GuiObject } }
module._floatingIcons = {} :: { { icon: GuiObject, options: any } }
module._openAnims = {} :: { [GuiObject]: (GuiObject) -> any }
module._closeAnims = {} :: { [GuiObject]: (GuiObject) -> any }
module._initialized = false

module._isolatedFrameOriginalParents = {} :: { [Instance]: Instance }
module._closingFrame = nil
module._returnTargets = {} :: { [Instance]: Instance }

local FolderForIsolated = Instance.new("Folder")
FolderForIsolated.Name = "FolderForIsolated"
FolderForIsolated.Parent = ReplicatedStorage

local IsolatedFrameLoading = {} :: { [string]: { GuiObject } }

local OpenedUi = nil
local TargetUi = nil

local function ParkIsolatedFrames(sectionName: string)
	local frames = IsolatedFrameLoading[sectionName]
	if not frames then
		return
	end

	for _, frame in frames do
		if frame:IsA("ScrollingFrame") then
			frame:SetAttribute("CanvasPosition", frame.CanvasPosition)
		end
		frame.Parent = FolderForIsolated
	end
end

local function RestoreIsolatedFrames(sectionName: string)
	local frames = IsolatedFrameLoading[sectionName]
	if not frames then
		return
	end

	for _, frame in frames do
		local originalParent = module._isolatedFrameOriginalParents[frame]
		if originalParent then
			frame.Parent = originalParent
		end
		if frame:IsA("ScrollingFrame") then
			local savedPosition = frame:GetAttribute("CanvasPosition")
			if savedPosition then
				frame.CanvasPosition = savedPosition
			end
		end
	end
end

local function RestoreIsolatedFrameParent(frame: GuiObject)
	local originalParent = module._isolatedFrameOriginalParents[frame]
	if originalParent then
		frame.Parent = originalParent
	end
	module._isolatedFrameOriginalParents[frame] = nil
end

local function getOpenAnim(section: GuiObject): (GuiObject) -> any
	return module._openAnims[section]
		or function(target: GuiObject)
			return DefaultTransition:Open(target)
		end
end

local function getCloseAnim(section: GuiObject): (GuiObject) -> any
	return module._closeAnims[section]
		or function(target: GuiObject)
			return DefaultTransition:Close(target)
		end
end

local function ReopenReturnTarget(Frame)
	local returnTarget = module._returnTargets[Frame]
	if not returnTarget then
		return
	end
	module._returnTargets[Frame] = nil
	if returnTarget.Parent then
		module:Open(returnTarget)
	end
end

function module:SetRoot(root: Instance)
	self._root = root
end

function module:SetSectionsContainer(container: Instance)
	self._sectionsContainer = container
end

function module:SetHideFrames(map: { [GuiObject]: UDim2 })
	self._hideFrames = map or {}
end

function module:SetHotkeys(map: { [string]: { Enum.KeyCode } })
	self._hotkeys = map or {}
end

function module:SetSectionNameOverrides(map: { [string]: string })
	self._nameOverrides = map or {}
end

function module:SetOpenCallback(name: string, callback: () -> ())
	self._openCallbacks[name] = callback
end

function module:SetCloseCallback(name: string, callback: () -> ())
	self._closeCallbacks[name] = callback
end

function module:RegisterButtonContainer(container: Instance)
	if container and not table.find(self._buttonContainers, container) then
		table.insert(self._buttonContainers, container)
	end
end

function module:SetButtonContainers(containers: { Instance })
	self._buttonContainers = {}
	for _, container in containers or {} do
		self:RegisterButtonContainer(container)
	end
end

function module:RegisterLoadAnimation(sectionName: string, frames: { GuiObject })
	self._loadAnimations[sectionName] = frames
end

function module:RegisterFloatingIcon(icon: GuiObject, options: any?)
	if icon then
		table.insert(self._floatingIcons, { icon = icon, options = options })
	end
end

function module:SetNoBlurFor(names: { string })
	DefaultTransition:DisableBlurFor(names)
end

function module:SetOpen(section: GuiObject, animation: (GuiObject) -> any)
	self._openAnims[section] = animation
end

function module:SetClose(section: GuiObject, animation: (GuiObject) -> any)
	self._closeAnims[section] = animation
end

function module:SetGuisOpenable(boolean: boolean)
	self.GuisOpenable = boolean
end

function module:GetOpenedUi(): GuiObject?
	return OpenedUi
end

function module:IsAnyMenuOpen(): boolean
	return OpenedUi ~= nil
end

function module:MatchFrame(GuiButton: GuiButton | string)
	local ButtonName = typeof(GuiButton) == "Instance" and GuiButton.Name or GuiButton
	local MatchName = self._nameOverrides[ButtonName] or ButtonName:gsub("Button", "UI")

	local container = self._sectionsContainer or (self._root and self._root:FindFirstChild("Sections"))
	if not container then
		return nil
	end

	return container:FindFirstChild(MatchName)
end

function module:BindIsolatedFrames(sectionName: string, frames: GuiObject | { GuiObject })
	local frameList = if typeof(frames) == "Instance" then { frames :: GuiObject } else frames :: { GuiObject }

	local boundFrames = IsolatedFrameLoading[sectionName]
	if not boundFrames then
		boundFrames = {}
		IsolatedFrameLoading[sectionName] = boundFrames
	end

	for _, frame in frameList do
		if not table.find(boundFrames, frame) then
			table.insert(boundFrames, frame)
		end

		if not self._isolatedFrameOriginalParents[frame] then
			self._isolatedFrameOriginalParents[frame] = frame.Parent
		end
		frame.Parent = FolderForIsolated
	end
end

function module:UnbindIsolatedFrames(sectionName: string, frames: (GuiObject | { GuiObject })?)
	local boundFrames = IsolatedFrameLoading[sectionName]
	if not boundFrames then
		return
	end

	if frames then
		local frameList = if typeof(frames) == "Instance" then { frames :: GuiObject } else frames :: { GuiObject }

		for _, frame in frameList do
			local index = table.find(boundFrames, frame)
			if index then
				table.remove(boundFrames, index)
				RestoreIsolatedFrameParent(frame)
			end
		end

		if #boundFrames == 0 then
			IsolatedFrameLoading[sectionName] = nil
		end
	else
		for _, frame in boundFrames do
			RestoreIsolatedFrameParent(frame)
		end
		IsolatedFrameLoading[sectionName] = nil
	end
end

function module:Close(Frame)
	if not Frame then
		return
	end

	if TargetUi ~= Frame then
		return
	end

	ParkIsolatedFrames(Frame.Name)

	TargetUi = nil
	OpenedUi = nil
	module._closingFrame = Frame

	local CloseSignal = Signal.new()

	local closeResult = getCloseAnim(Frame)(Frame)

	if self._closeCallbacks[Frame.Name] then
		self._closeCallbacks[Frame.Name]()
	end

	local function finish()
		if module._closingFrame == Frame then
			module._closingFrame = nil
		end
		if TargetUi ~= Frame then
			if Frame.Parent then
				Frame.Visible = false
			end
			ReopenReturnTarget(Frame)
		end
		CloseSignal:Fire()
		CloseSignal:Destroy()
	end

	if closeResult and closeResult.Ended then
		closeResult.Ended:Once(finish)
	else
		finish()
	end

	DefaultTransition:LowerAmbient()

	return CloseSignal
end

function module:Open(Frame, LoadWithAnimation: { GuiObject }?)
	if not Frame then
		return
	end

	if TargetUi == Frame then
		return
	end

	if self.GuisHidden then
		return
	end

	if self.GuisOpenable == false then
		return
	end

	module._returnTargets[Frame] = nil

	local wasOpen = OpenedUi ~= nil

	if OpenedUi and OpenedUi ~= Frame then
		local previous = OpenedUi
		ParkIsolatedFrames(previous.Name)

		local closeResult = getCloseAnim(previous)(previous)
		if closeResult and closeResult.Ended then
			closeResult.Ended:Once(function()
				if TargetUi ~= previous and previous.Parent then
					previous.Visible = false
				end
			end)
		elseif previous.Parent then
			previous.Visible = false
		end

		if self._closeCallbacks[previous.Name] then
			self._closeCallbacks[previous.Name]()
		end
	end

	if self._loadAnimations[Frame.Name] then
		LoadWithAnimation = self._loadAnimations[Frame.Name]
	end

	for _, uiObject in LoadWithAnimation or {} do
		if uiObject and uiObject:IsA("GuiObject") then
			GuiClass:LoadFrame({
				frame = uiObject,
				tweenInfo = LOAD_TWEEN_INFO,
			})
		end
	end

	if IsolatedFrameLoading[Frame.Name] then
		ParkIsolatedFrames(Frame.Name)
		task.delay(ISOLATED_RESTORE_DELAY, function()
			RestoreIsolatedFrames(Frame.Name)
		end)
	end

	TargetUi = Frame
	OpenedUi = Frame

	if Frame.Parent then
		Frame.Visible = true
	end

	getOpenAnim(Frame)(Frame)

	if not wasOpen then
		DefaultTransition:RaiseAmbient(Frame)
	end

	if self._openCallbacks[Frame.Name] then
		self._openCallbacks[Frame.Name]()
	end
end

function module:OpenWithReturn(Frame, opener)
	if not (Frame and opener) then
		return
	end
	self:Open(Frame)
	module._returnTargets[Frame] = opener
end

function module:ClearReturn(Frame)
	if Frame then
		module._returnTargets[Frame] = nil
	end
end

function module:Toggle(Frame)
	if not Frame then
		return
	end

	if TargetUi == Frame then
		self:Close(Frame)
	else
		self:Open(Frame)
	end
end

function module:AddSectionFunctions(Section: Frame | ImageLabel | CanvasGroup)
	if not Section:FindFirstChild("Scale") then
		local FrameScale = Instance.new("UIScale")
		FrameScale.Scale = 0
		FrameScale.Parent = Section
		FrameScale.Name = "Scale"
	end

	local SectionMain = Section:FindFirstChild("Main")
	local SectionHolder = SectionMain and SectionMain:FindFirstChild("Holder")
	local CloseFrame = SectionHolder and SectionHolder:FindFirstChild("Close")
	local CloseButton: GuiButton = CloseFrame and CloseFrame:FindFirstChild("X_Button")

	local CloseFrameAlt = SectionMain and SectionMain:FindFirstChild("Close")
	local CloseButtonAlt: GuiButton = CloseFrameAlt and CloseFrameAlt:FindFirstChild("X_Button")

	if CloseButtonAlt then
		local NewButton = GuiClass:CreateButton(CloseButtonAlt, CloseFrameAlt, { Enum.KeyCode.ButtonB })

		NewButton:ObserveForVisibilityChange({ Section })

		NewButton.Clicked:Connect(function()
			module:Close(Section)
		end)
	end

	if CloseButton then
		local NewButton = GuiClass:CreateButton(CloseButton, CloseFrame, { Enum.KeyCode.ButtonB })

		NewButton:ObserveForVisibilityChange({ Section })

		NewButton.Clicked:Connect(function()
			module:Close(Section)
		end)
	end

	local SectionTitle = SectionHolder and SectionHolder:FindFirstChild("Title")
	local SectionTitleGradient = SectionTitle and SectionTitle:FindFirstChildWhichIsA("UIGradient")

	if SectionTitleGradient then
		local GradientEffect = GuiClass.CreateWaveGradient(SectionTitleGradient)

		if not Section.Visible then
			GradientEffect:stop()
		end

		Section:GetPropertyChangedSignal("Visible"):Connect(function()
			if not Section.Visible then
				GradientEffect:stop()
			else
				GradientEffect:start()
			end
		end)
	end
end

function module:AddFunctions(GuiButton: GuiButton)
	local MatchedFrame = self:MatchFrame(GuiButton)

	if MatchedFrame then
		self:AddSectionFunctions(MatchedFrame)
	end

	local NewButton = GuiClass:CreateButton(GuiButton, GuiButton, self._hotkeys[GuiButton.Name])
	NewButton:ObserveForVisibilityChange(self._buttonContainers)

	local ButtonIcon = GuiButton:FindFirstChild("Icon") :: ImageLabel?

	if ButtonIcon then
		local Gradient = ButtonIcon:FindFirstChildWhichIsA("UIGradient")

		if not Gradient then
			Gradient = Instance.new("UIGradient")
			Gradient.Rotation = 90
		end

		local LastSide = ICON_HOVER_ANGLE

		NewButton:AddHoverFunction(function(state: "Entered" | "Left")
			if state == "Entered" then
				local ChoosenSide = if LastSide == ICON_HOVER_ANGLE then -ICON_HOVER_ANGLE else ICON_HOVER_ANGLE
				LastSide = ChoosenSide
				TweenService:Create(ButtonIcon, ICON_HOVER_TWEEN_INFO, {
					Rotation = ChoosenSide,
				}):Play()

				Gradient.Enabled = false
			else
				TweenService:Create(ButtonIcon, ICON_HOVER_TWEEN_INFO, {
					Rotation = 0,
				}):Play()
				Gradient.Enabled = true
			end
		end)
	end

	NewButton.Clicked:Connect(function()
		if not MatchedFrame then
			return
		end

		self:Toggle(MatchedFrame)
	end)
end

function module:HideGuis(closeSections: boolean?)
	if not self._hideGuiObj then
		return
	end

	local Ended = self._hideGuiObj:Hide()
	self.GuisHidden = true

	if closeSections and OpenedUi then
		self:Close(OpenedUi)
	end

	if self._closingFrame then
		if self._closingFrame.Parent then
			self._closingFrame.Visible = false
		end
		local closingScale = self._closingFrame:FindFirstChild("Scale")
		if closingScale and closingScale.Parent then
			closingScale.Scale = 0
		end
		self._closingFrame = nil
	end

	if OpenedUi then
		local Scale = OpenedUi:FindFirstChild("Scale")
		if Scale and Scale.Parent then
			Scale.Scale = 0
		end
		if OpenedUi.Parent then
			OpenedUi.Visible = false
		end
		if self._closeCallbacks[OpenedUi.Name] then
			self._closeCallbacks[OpenedUi.Name]()
		end
		TargetUi = nil
		OpenedUi = nil
	end

	if self._root then
		Ended:Once(function()
			self._root.Enabled = false
		end)
	end

	return Ended
end

function module:ShowGuis()
	if self._root then
		self._root.Enabled = true
	end
	self.GuisHidden = false
	if self._hideGuiObj then
		self._hideGuiObj:Show()
	end
end

function module:init()
	if self._initialized then
		return
	end

	if not self._root then
		warn("UI Controller:init called before SetRoot; skipping wiring")
		return
	end

	self._hideGuiObj = GuiClass:CreateHideObject(self._hideFrames)

	if #self._buttonContainers > 0 then
		local Children = Utils:GetChildrenOfInstances(table.unpack(self._buttonContainers))

		for _, Child in ipairs(Children) do
			if Child:IsA("GuiButton") then
				Child.AutoButtonColor = false
				self:AddFunctions(Child)
			end
		end
	end

	for _, entry in self._floatingIcons do
		if entry.icon then
			GuiClass:CreateFloatingAnimation(entry.icon, entry.options)
		end
	end

	self._initialized = true
end

return module
```

- [ ] **Step 2: Verify guarded init no-ops without config**

With Studio open and synced, run via `execute_luau`:

```lua
local Controller = require(game.ReplicatedStorage.Shared.UI.Controller)
Controller._initialized = false
Controller._root = nil
Controller:init()
print("INIT GUARD OK, initialized:", Controller._initialized)
```

Read `get_console_output`.
Expected: a warning `UI Controller:init called before SetRoot; skipping wiring`, then `INIT GUARD OK, initialized: false`, and no hard error.

- [ ] **Step 3: Verify configure + open + swap + close**

With Studio open and synced, run via `execute_luau`:

```lua
local Controller = require(game.ReplicatedStorage.Shared.UI.Controller)

local screen = Instance.new("ScreenGui")
screen.Name = "ControllerSmoke"
screen.Parent = game.Players.LocalPlayer.PlayerGui

local sections = Instance.new("Folder")
sections.Name = "Sections"
sections.Parent = screen

local function makeSection(name)
	local f = Instance.new("Frame")
	f.Name = name
	f.Visible = false
	f.Size = UDim2.fromScale(0.4, 0.4)
	f.Position = UDim2.fromScale(0.3, 0.3)
	f.Parent = sections
	return f
end

local a = makeSection("AlphaUI")
local b = makeSection("BetaUI")

Controller._initialized = false
Controller:SetRoot(screen)
Controller:SetSectionsContainer(sections)
Controller:init()
print("CONFIGURED, initialized:", Controller._initialized)

Controller:Open(a)
task.wait(0.4)
print("A open:", a.Visible, "A scale:", a.Scale.Scale, "anyOpen:", Controller:IsAnyMenuOpen())

local customRan = false
Controller:SetClose(a, function(section)
	customRan = true
	local sig = require(game.ReplicatedStorage.Packages.Signal).new()
	task.defer(function() sig:Fire(); sig:Destroy() end)
	return { Ended = sig }
end)

Controller:Open(b)
task.wait(0.4)
print("custom close ran on swap:", customRan, "A visible:", a.Visible, "B open:", b.Visible, "B scale:", b.Scale.Scale)

Controller:Close(b)
task.wait(0.4)
print("B visible after close:", b.Visible, "anyOpen:", Controller:IsAnyMenuOpen())

screen:Destroy()
Controller._initialized = false
print("CONTROLLER SMOKE OK")
```

Read `get_console_output`.
Expected: `CONFIGURED, initialized: true`; `A open: true A scale: 1`; `custom close ran on swap: true A visible: false B open: true B scale: 1`; `B visible after close: false anyOpen: false`; `CONTROLLER SMOKE OK`; no errors.

- [ ] **Step 4: Confirm no leftover hardcoded UI references**

Run a content search over the file:

Grep pattern `WaitForChild|GuiBlur|PlayerGui|ButtonsFrame|Currencies|TweenFov|MENU_OPEN_FOV|MENU_CLOSE_FOV` in `src/Shared/UI/Controller/init.luau`.
Expected: zero matches (all such references now live only in `DefaultTransition.luau`, which legitimately keeps `TweenFov`).

- [ ] **Step 5: Commit**

```bash
git add src/Shared/UI/Controller/init.luau
git commit -m "refactor: make UI Controller setter-driven and instance-free"
```

---

## Notes for the implementer

- The Controller is loaded by `src/Shared/UI/init.luau`'s Modules loader, which auto-calls `:init()` with no config. The Step-2 guard makes that harmless. The user's own bootstrap will call the setters and then `:init()`; do not add that bootstrap here.
- `DefaultTransition` is a child of the Controller ModuleScript, so the loader does NOT auto-load it — correct, it has no `init`.
- Per-section custom animations are keyed by the section Instance (`_openAnims`/`_closeAnims`), so they survive renames but are dropped if the instance is destroyed/recreated — expected.
