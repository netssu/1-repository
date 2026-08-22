------------------//SERVICES
local Lighting: Lighting = game:GetService("Lighting")
local TweenService: TweenService = game:GetService("TweenService")

------------------//DEPENDENCIES
local cameraFovController = require(script.Parent.Parent:WaitForChild("CameraFovController"))

------------------//VARIABLES
local closeAnimation = {}
local closingDebounce = {}

------------------//FUNCTIONS
local function tween_blur(targetSize: number, duration: number): ()
	local blur = Lighting:FindFirstChild("UIBlur") or Lighting:FindFirstChildWhichIsA("BlurEffect")
	if not blur then
		return
	end

	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(blur, info, { Size = targetSize }):Play()
end

local function finish_close(inst: GuiObject, state, hasBlur: boolean, duration: number): ()
	inst.Visible = false
	if hasBlur then
		tween_blur(0, duration)
	end
	if inst:GetAttribute("fov") then
		cameraFovController.set_ui_fov(nil, duration)
	end

	if state then
		if state.origSize then
			inst.Size = state.origSize
		end
		if state.origPos then
			inst.Position = state.origPos
		end
		if inst:IsA("CanvasGroup") then
			inst.GroupTransparency = 0
		end
	end

	task.defer(function()
		closingDebounce[inst] = nil
		inst:SetAttribute("_is_closing", nil)
	end)
end

------------------//MAIN FUNCTIONS
function closeAnimation.run(inst: GuiObject, state, utils, sfx): ()
	if sfx and sfx.play_for then
		sfx.play_for(inst, "sfx_close")
	end

	local animationKind = inst:GetAttribute("open_anim") or "pop"
	local duration = inst:GetAttribute("open_t") or 0.25
	local closeTime = duration * 0.8
	local offset = inst:GetAttribute("open_offset_px") or 200
	local hasBlur = inst:GetAttribute("blur") ~= nil

	if inst:IsA("CanvasGroup") then
		local info = TweenInfo.new(closeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(inst, info, { GroupTransparency = 1 }):Play()
	end

	local targetProperty
	if animationKind == "slide_down" then
		local currentPosition = state.origPos or inst.Position
		targetProperty = {
			Position = UDim2.new(
				currentPosition.X.Scale,
				currentPosition.X.Offset,
				currentPosition.Y.Scale,
				currentPosition.Y.Offset - offset * 1.2
			),
		}
	elseif animationKind == "slide_up" then
		local currentPosition = state.origPos or inst.Position
		targetProperty = {
			Position = UDim2.new(
				currentPosition.X.Scale,
				currentPosition.X.Offset,
				currentPosition.Y.Scale,
				currentPosition.Y.Offset + offset * 1.2
			),
		}
	else
		local originalSize = state and state.origSize or inst.Size
		targetProperty = { Size = utils.scale_udim2(originalSize, 0.001) }
	end

	local tween = utils.tween(
		inst,
		targetProperty,
		closeTime,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)
	tween:Play()
	tween.Completed:Connect(function()
		finish_close(inst, state, hasBlur, closeTime)
	end)
end

function closeAnimation.bind(inst: GuiObject, state, utils, sfx): ()
	inst:GetPropertyChangedSignal("Visible"):Connect(function()
		if inst.Visible or not inst:GetAttribute("UIOpen") or closingDebounce[inst] then
			return
		end

		closingDebounce[inst] = true
		inst:SetAttribute("_is_closing", true)
		inst:SetAttribute("skip_open", true)
		inst.Visible = true
		closeAnimation.run(inst, state, utils, sfx)
	end)
end

------------------//INIT
return closeAnimation
