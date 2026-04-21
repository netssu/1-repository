local module = {}

local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

module.unitButtonAnimation = function(button)

	local currentTween = nil
	local wasUp = false
	local tweenInfo = TweenInfo.new(0.05,Enum.EasingStyle.Sine)


	local animationQueue = {
	}
	local animations = {
		Enter = {
			tween = TweenService:Create(button.UIScale,tweenInfo,{
				Scale = 1.1
			}),
			priority = 4
		},
		Down = {
			tween = TweenService:Create(button.UIScale,tweenInfo,{
				Scale = .9
			}),
			priority = 3
		},
		Up = {
			tween = TweenService:Create(button.UIScale,tweenInfo,{
				Scale = 1.1
			}),
			priority = 2
		},
		--Default = {
		--	tween = TweenService:Create(button.UIScale,tweenInfo,{
		--		Scale = 1
		--	}),
		--	priority = 1
		--},
		Leave = {
			tween = TweenService:Create(button.UIScale,tweenInfo,{
				Scale = 1
			}),
			priority = 1
		}

	}

	local function updateAnimation(phase)
		if phase == "Leave" and not wasUp then
			updateAnimation("Up")
		end
		if currentTween ~= nil and currentTween.PlaybackState == Enum.PlaybackState.Playing  then currentTween.Completed:Wait() end

		if phase == "Up" then
			wasUp = true
		end
		if phase == "Leave" then
			wasUp = false
		end


		if phase then
			if #animationQueue > 0 then
				if table.find(animationQueue,phase) then print("return") return end
				for index,element in animationQueue do
					if animations[phase].priority >   animations[element].priority then
						table.insert(animationQueue,index,phase)
						break
					end
				end

				table.insert(animationQueue,phase)

			else
				table.insert(animationQueue,phase)
			end
		end

		currentTween = animations[animationQueue[1]].tween
		currentTween:Play()
		table.remove(animationQueue,1)

		currentTween.Completed:Wait()
		if #animationQueue > 0 then
			updateAnimation()
		end

	end


	button.MouseEnter:Connect(function()
		updateAnimation("Enter")
	end)

	button.MouseLeave:Connect(function()
		updateAnimation("Leave")
	end)

	button.MouseButton1Down:Connect(function()
		updateAnimation("Down")
	end)


	button.MouseButton1Up:Connect(function()
		updateAnimation("Up")
	end)

	--SelectionGui:GetPropertyChangedSignal("Visible"):Connect(function()
	--	task.wait(0.1)
	--	if not SelectionGui.Visible then
	--		updateAnimation("Default")
	--	end
	--end)

end

return module
