local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local offsetVal =  1.149 - 1.194
local fadeOutTime = 0.2
local fadeInTime = 0.3
local intervalDelay = 0.3
local numberSwitchTime = 1

local module = {}


function module.fadeIn(obj)
	local newPos = UDim2.fromScale(obj.OriginalPositionX.Value, obj.OriginalPositionY.Value)

	if obj:IsA('TextLabel') then
		tween(obj, fadeOutTime, {Position = newPos, TextTransparency = 0})
	else
		tween(obj, fadeOutTime, {Position = newPos, ImageTransparency = 0})
	end		
end

function module.fadeOut(obj: GuiBase2d)
	if not obj:FindFirstChild('OriginalPositionX') then
		local val = Instance.new('NumberValue')
		val.Name = 'OriginalPositionX'
		val.Value = obj.Position.X.Scale
		val.Parent = obj

		local val = Instance.new('NumberValue')
		val.Name = 'OriginalPositionY'
		val.Value = obj.Position.Y.Scale
		val.Parent = obj
	end


	local newPos = UDim2.fromScale(obj.Position.X.Scale, obj.Position.Y.Scale - offsetVal)

	if obj:IsA('TextLabel') then
		tween(obj, fadeOutTime, {Position = newPos, TextTransparency = 1})
	else
		tween(obj, fadeOutTime, {Position = newPos, ImageTransparency = 1})
	end		


	--tween(obj.UIStroke, fadeOutTime, {Transparency = 1})
end

function module.toggle(state)
	if state then
		script.Parent.Visible = true
		tween(script.Parent, fadeOutTime, {BackgroundTransparency = 0.3})
		local countTracker = 1
		for i = 1, #script.Parent.Main:GetChildren() do
			local num = script.Parent.Main:FindFirstChild(tostring(countTracker))
			if num and num:IsA('GuiBase2d') then
				for i, v in num:GetDescendants() do
					if v:IsA('GuiBase2d') and v.Name ~= 'Container' then
						module.fadeIn(v)
					end
				end
				
				task.wait(1)
				countTracker += 1
			end
		end
		
		task.wait(0.5)
		module.fadeIn(script.Parent.Continue)
		
		local Bindable = Instance.new('BindableEvent')
		script.Parent.Parent.ClansFrame.Interactable = false
		
		local conn1 = UserInputService.InputBegan:Connect(function(inpVal, gp)
			if not gp then
				if inpVal.UserInputType == Enum.UserInputType.MouseButton1 or inpVal.UserInputType == Enum.UserInputType.Touch then
					print('clocked')
					Bindable:Fire()
				end
			end
		end)
		
		Bindable.Event:Wait()
		
		script.Parent.Parent.ClansFrame.Interactable = true
		conn1:Disconnect()
		conn1 = nil
		Bindable:Destroy()
		
		module.toggle(false)
	else
		-- Disable
		for i,num in script.Parent.Main:GetChildren() do
			if num:IsA('GuiBase2d') then
				for i, v in num:GetDescendants() do
					if v:IsA('GuiBase2d') and v.Name ~= 'Container' then
						module.fadeOut(v)
					end
				end
			end
		end
		
		module.fadeOut(script.Parent.Continue)
		tween(script.Parent, fadeOutTime, {BackgroundTransparency = 1})
		task.wait(fadeOutTime)
		script.Parent.Visible = false
	end
end


return module
