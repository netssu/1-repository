------------------//SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

------------------//VARIABLES
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local uiRoot = playerGui:WaitForChild("UI")
local newRoot = playerGui:WaitForChild("GUI")
local playerHud = uiRoot:WaitForChild("GameHUD")

local hudScale = playerHud:FindFirstChild("UIScale")
if not hudScale then
	hudScale = Instance.new("UIScale")
	hudScale.Parent = playerHud
end

local isCanvasGroup = playerHud:IsA("CanvasGroup")

local OpenedFrames = {}
OpenedFrames.starter = {}
OpenedFrames.FrameClosed = Instance.new("BindableEvent")

local currentScaleTween = nil
local currentTranspTween = nil
local registeredFrames = {}

local IGNORE_LIST = {
	["GameHUD"] = true,
	["Codes"] = true,
	["Confirmation"] = true
}

------------------//FUNCTIONS
local function set_hud_visible(isVisible: boolean)
	if not playerHud then
		return
	end

	local scale = 1.5

	local tweenInfoIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenInfoOut = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	if currentScaleTween then
		currentScaleTween:Cancel()
	end

	if currentTranspTween then
		currentTranspTween:Cancel()
	end

	if isVisible then
		if not playerHud.Visible or (isCanvasGroup and playerHud.GroupTransparency == 1) then
			hudScale.Scale = 1.5 * scale
			if isCanvasGroup then
				playerHud.GroupTransparency = 1
			end
		end

		playerHud.Visible = true

		local scaleTween = TweenService:Create(hudScale, tweenInfoIn, { Scale = 1 })
		currentScaleTween = scaleTween
		scaleTween:Play()

		if isCanvasGroup then
			local transpTween = TweenService:Create(playerHud, tweenInfoIn, { GroupTransparency = 0 })
			currentTranspTween = transpTween
			transpTween:Play()
		end
	else
		local scaleTween = TweenService:Create(hudScale, tweenInfoOut, { Scale = 1.5 * scale })
		currentScaleTween = scaleTween
		scaleTween:Play()

		if isCanvasGroup then
			local transpTween = TweenService:Create(playerHud, tweenInfoOut, { GroupTransparency = 1 })
			currentTranspTween = transpTween
			transpTween:Play()
		end

		scaleTween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and currentScaleTween == scaleTween then
				playerHud.Visible = false
			end
		end)
	end
end

local function hide_other_pages(exception: GuiObject?)
	for _, frame in ipairs(registeredFrames) do
		if frame and frame.Parent and frame ~= exception and frame.Visible then
			frame.Visible = false
		end
	end
end

local function on_visibility_changed(frame: GuiObject)
	if not frame or not frame.Parent then
		return
	end

	if frame.Visible then
		hide_other_pages(frame)
	else
		OpenedFrames.FrameClosed:Fire(frame.Name)
	end
end

local function register_frame_internal(frame: GuiObject)
	if not frame or frame == playerHud or IGNORE_LIST[frame.Name] then
		return
	end

	if not table.find(registeredFrames, frame) then
		table.insert(registeredFrames, frame)

		frame:GetPropertyChangedSignal("Visible"):Connect(function()
			on_visibility_changed(frame)
		end)
	end
end

function OpenedFrames.starter.Register(context: {})
	local frame = context.gui
	if not frame or not frame:IsA("GuiObject") then
		return
	end

	register_frame_internal(frame)

	if frame.Visible then
		hide_other_pages(frame)
	end
end

function OpenedFrames.CloseParent(cfg: {})
	local btn = cfg.gui
	local targetGui = nil

	if btn then
		targetGui = btn:FindFirstAncestorWhichIsA("Frame") or btn:FindFirstAncestorWhichIsA("ScrollingFrame")
	end

	if targetGui then
		targetGui.Visible = false
	end
end

function OpenedFrames.OpenFrame(cfg: {})
	local btn = cfg.gui
	if not btn then
		return
	end

	local pageName = btn.Name
	local targetPage = newRoot:FindFirstChild(pageName) or uiRoot:FindFirstChild(pageName)

	if targetPage and targetPage:IsA("GuiObject") then
		register_frame_internal(targetPage)

		if targetPage.Visible then
			targetPage.Visible = false
		else
			hide_other_pages(targetPage)
			targetPage.Visible = true
		end
	else
		warn("OpenFrame: Page not found:", pageName)
	end
end

------------------//INIT
return OpenedFrames