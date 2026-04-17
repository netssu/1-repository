local TweenService = game:GetService("TweenService")

local module = {}

module.guidata = {}

function module.setup(gui)
	if module.guidata[gui] then
		return
	end
	module.guidata[gui] = UDim2.fromScale(gui.Position.X.Scale, gui.Position.Y.Scale)
end

function module.opengui(gui)
	gui.Visable = true
	
	local tweenInfo = TweenInfo.new(0.4)
	local goal = {Position = module.guidata[gui]}
	
	local tween = TweenService:Create(gui, tweenInfo, goal)
	tween:Play()
end

function module.closegui(gui)
	local tweenInfo = TweenInfo.new(0.4)
	local goal = {Position = UDim2.fromScale(module.guidata[gui], 1.4)}
	
	local tween = TweenService:Create(gui, tweenInfo, goal)
	tween:Play()
	
	task.delay(0.4, function()
		gui.Visable = false
	end)
end

return module
