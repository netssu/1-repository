local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules
local MouseOverModule = require(ReplicatedStorage.Modules.MouseOverModule)
local CategorySwitcher = require(script.Parent.CategorySwitcher)

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local module = {}

local ClansFrame = script.Parent.Parent.ClansFrame

local ttime = 0.1

for i,v in ClansFrame.Internal.Info.Container:GetChildren() do
	if v:IsA('GuiBase2d') then
		local MouseEnter, MouseLeave = MouseOverModule.MouseEnterLeaveEvent(v)
		
		MouseEnter:Connect(function()
			tween(v.Container.PatternPreview, ttime, {ImageTransparency = 0.6})
			tween(v.Glow, ttime, {ImageTransparency = 0})
		end)
		
		MouseLeave:Connect(function()
			tween(v.Container.PatternPreview, ttime, {ImageTransparency = 0.95})
			tween(v.Glow, ttime, {ImageTransparency = 1})
		end)
		
		v.Activated:Connect(function()
			CategorySwitcher.setCategory(v.Name)
		end)
	end
end

for i,v in script:GetChildren() do
	if v.Name == 'Template' then continue end
	task.spawn(function()
		require(v)
	end)
end


return module