------------------//SERVICES
local TweenService: TweenService = game:GetService("TweenService")

------------------//CONSTANTS
local GRADIENT_START: Vector2 = Vector2.new(-1, 0)
local GRADIENT_END: Vector2 = Vector2.new(1, 0)
local GRADIENT_TWEEN_INFO: TweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local HOVER_IN_TWEEN_INFO: TweenInfo = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local HOVER_OUT_TWEEN_INFO: TweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_SCALE: number = 1.045

------------------//VARIABLES
local activeGradientTweens: { [UIGradient]: Tween } = setmetatable({}, { __mode = "k" })
local activeScaleTweens: { [UIScale]: Tween } = setmetatable({}, { __mode = "k" })

------------------//FUNCTIONS
local function get_gradient(root: Instance?): UIGradient?
	if not root then
		return nil
	end

	if root:IsA("UIGradient") then
		return root
	end

	return root:FindFirstChildWhichIsA("UIGradient", true)
end

local function get_animation_target(button: GuiButton): GuiObject
	local targetMode = button:GetAttribute("UIAnimTarget")
	if targetMode == "Parent" or targetMode == "ParentScale" then
		local parent = button.Parent
		if parent and parent:IsA("GuiObject") then
			return parent
		end
	end
	return button
end

local function get_scale(button: GuiObject): UIScale
	local existingScale = button:FindFirstChild("InventoryCardScale")
	if existingScale and existingScale:IsA("UIScale") then
		return existingScale
	end

	local scale = Instance.new("UIScale")
	scale.Name = "InventoryCardScale"
	scale.Scale = 1
	scale.Parent = button
	return scale
end

local function play_gradient_once(root: Instance?): ()
	local gradient = get_gradient(root)
	if not gradient then
		return
	end

	local existingTween = activeGradientTweens[gradient]
	if existingTween then
		existingTween:Cancel()
	end

	gradient.Offset = GRADIENT_START
	local tween = TweenService:Create(gradient, GRADIENT_TWEEN_INFO, { Offset = GRADIENT_END })
	activeGradientTweens[gradient] = tween
	tween.Completed:Connect(function()
		if activeGradientTweens[gradient] == tween then
			activeGradientTweens[gradient] = nil
		end
		if gradient.Parent then
			gradient.Offset = GRADIENT_START
		end
		tween:Destroy()
	end)
	tween:Play()
end

local function tween_scale(scale: UIScale, targetScale: number, tweenInfo: TweenInfo): ()
	local existingTween = activeScaleTweens[scale]
	if existingTween then
		existingTween:Cancel()
	end

	local tween = TweenService:Create(scale, tweenInfo, { Scale = targetScale })
	activeScaleTweens[scale] = tween
	tween.Completed:Connect(function()
		if activeScaleTweens[scale] == tween then
			activeScaleTweens[scale] = nil
		end
		tween:Destroy()
	end)
	tween:Play()
end

------------------//MAIN FUNCTIONS
local inventoryCardEffects = {}

function inventoryCardEffects.bind(button: GuiButton): { RBXScriptConnection }
	local animationTarget = get_animation_target(button)
	local scale = get_scale(animationTarget)
	local effect = button:FindFirstChild("Effect") or animationTarget:FindFirstChild("Effect")
	button.AutoButtonColor = false

	local enterConnection = button.MouseEnter:Connect(function()
		play_gradient_once(effect)
		tween_scale(scale, HOVER_SCALE, HOVER_IN_TWEEN_INFO)
	end)
	local leaveConnection = button.MouseLeave:Connect(function()
		tween_scale(scale, 1, HOVER_OUT_TWEEN_INFO)
	end)
	local activatedConnection = button.Activated:Connect(function()
		play_gradient_once(effect)
	end)

	return { enterConnection, leaveConnection, activatedConnection }
end

------------------//INIT
return inventoryCardEffects
