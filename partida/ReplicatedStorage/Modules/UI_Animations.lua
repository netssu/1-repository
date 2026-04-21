local TweenService = game:GetService("TweenService")

local MOUSE_ENTER_SIZE = 1.1
local MOUSE_ENTER_DURATION = .2
local CLICK_SIZE = 1.2
local MOUSE_CLICK_DURATION = .2


local module = {}

local OriginalSizes = {}

local function On_Mouse_Enter(button, original_Size)
	local HoverSize = UDim2.new(
		original_Size.X.Scale*MOUSE_ENTER_SIZE,
		0,
		original_Size.Y.Scale*MOUSE_ENTER_SIZE,
		0
	)
	button:TweenSize(HoverSize, "Out", "Sine", MOUSE_ENTER_DURATION, true)
end

local function On_Mouse_Leave(button, original_Size)

	button:TweenSize(original_Size, "Out", "Sine", MOUSE_ENTER_DURATION, true)
end

local function On_Mouse_Click(button, original_Size)

	local ClickSize = UDim2.new(
		original_Size.X.Scale/CLICK_SIZE,
		0,
		original_Size.Y.Scale/CLICK_SIZE,
		0
	)

	button:TweenSize(ClickSize, "Out", "Sine", MOUSE_CLICK_DURATION, true)
end

function module.SetUp(button)

	if not table.find(OriginalSizes, button) then
		OriginalSizes[button] = button.Size
	end 

	local Main_Size = OriginalSizes[button]

	button.MouseEnter:Connect(function()
		On_Mouse_Enter(button, Main_Size)
	end)

	button.MouseLeave:Connect(function()
		On_Mouse_Leave(button, Main_Size)
	end)

	button.MouseButton1Down:Connect(function()
		On_Mouse_Click(button, Main_Size)
	end)

	button.MouseButton1Up:Connect(function()
		On_Mouse_Leave(button, Main_Size)
	end)
end



return module
