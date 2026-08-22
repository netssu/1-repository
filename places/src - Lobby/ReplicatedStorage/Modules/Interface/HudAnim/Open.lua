------------------//SERVICES
local Lighting: Lighting = game:GetService("Lighting")
local TweenService: TweenService = game:GetService("TweenService")

------------------//DEPENDENCIES
local cameraFovController = require(script.Parent.Parent:WaitForChild("CameraFovController"))

------------------//CONSTANTS
local BLUR_IGNORED_FRAMES = {
	BlockInventoryFrame = true,
	PaintBlocksFrame = true,
}

------------------//VARIABLES
local openAnimation = {}

------------------//FUNCTIONS
local function get_blur_effect(): BlurEffect
	local blur = Lighting:FindFirstChildWhichIsA("BlurEffect")
	if blur then
		return blur
	end

	blur = Instance.new("BlurEffect")
	blur.Name = "UIBlur"
	blur.Size = 0
	blur.Parent = Lighting
	return blur
end

local function tween_blur(targetSize: number, duration: number): ()
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(get_blur_effect(), info, { Size = math.max(0, targetSize) }):Play()
end

------------------//MAIN FUNCTIONS
function openAnimation.run(inst: GuiObject, state, utils, sfx): ()
	if not inst:GetAttribute("UIOpen") then
		return
	end

	state.origPos = state.origPos or inst.Position
	state.origSize = state.origSize or inst.Size

	local animationKind = inst:GetAttribute("open_anim") or "pop"
	local duration = inst:GetAttribute("open_t") or 0.4
	local delayTime = inst:GetAttribute("open_delay") or 0
	local offset = inst:GetAttribute("open_offset_px") or 150
	local popScale = inst:GetAttribute("open_pop_scale") or 0.7
	local blurAmount = tonumber(inst:GetAttribute("blur"))
	local fovAmount = tonumber(inst:GetAttribute("fov"))

	if delayTime > 0 then
		task.wait(delayTime)
	end

	inst.Visible = true
	if animationKind == "slide_down" then
		inst.Position = UDim2.new(
			state.origPos.X.Scale,
			state.origPos.X.Offset,
			state.origPos.Y.Scale,
			state.origPos.Y.Offset - offset
		)
		utils.tween(inst, { Position = state.origPos }, duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
	elseif animationKind == "slide_up" then
		inst.Position = UDim2.new(
			state.origPos.X.Scale,
			state.origPos.X.Offset,
			state.origPos.Y.Scale,
			state.origPos.Y.Offset + offset
		)
		utils.tween(inst, { Position = state.origPos }, duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
	else
		inst.Size = utils.scale_udim2(state.origSize, popScale)
		inst.Position = state.origPos
		utils.tween(inst, { Size = state.origSize }, duration, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out):Play()
	end

	if blurAmount and blurAmount > 0 and not BLUR_IGNORED_FRAMES[inst.Name] then
		tween_blur(blurAmount, duration)
	end
	if fovAmount then
		cameraFovController.set_ui_fov(fovAmount, duration)
	end
	if sfx then
		sfx.play_for(inst, "sfx_open")
	end
end

------------------//INIT
return openAnimation
