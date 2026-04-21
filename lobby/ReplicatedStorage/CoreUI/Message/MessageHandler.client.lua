local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenModule = require(ReplicatedStorage.AceLib.TweenModule)

local ttime = 1

_G.Message = function(text,color,sound,waveMessage,duration)
	task.spawn(function()
		if not waveMessage then
			local newMessage = script.Template:Clone()
			if color then
				newMessage.Template.TextColor3 = color
			end
			if sound then
				script.Parent.Sounds[sound]:Play()
			end
			newMessage.Template.Text = text
			newMessage.Parent = script.Parent.Frame
			
			TweenModule.tween(newMessage.Template, TweenInfo.new(ttime, Enum.EasingStyle.Elastic), {Rotation = 0})
			
			task.wait(ttime + 2)
			TweenModule.tween(newMessage.Template, ttime, {TextTransparency = 1})
			
			task.wait(ttime)
			newMessage:Destroy()

		else
			local newMessage = script.Image:Clone()
			if sound then
				script.Parent.Sounds[sound]:Play()
			end
			newMessage.Template.Text = text
			newMessage.Parent = script.Parent.Frame		
			
			TweenModule.tween(newMessage.Template, TweenInfo.new(ttime, Enum.EasingStyle.Elastic), {Rotation = 0})

			task.wait(ttime + 3)
			TweenModule.tween(newMessage.Template, ttime, {TextTransparency = 1})
			TweenModule.tween(newMessage.Template.UIStroke, ttime, {Transparency = 1})
			TweenModule.tween(newMessage, ttime, {BackgroundTransparency = 1})
			TweenModule.tween(newMessage.Border, ttime, {BackgroundTransparency = 1})
			TweenModule.tween(newMessage.Border1, ttime, {BackgroundTransparency = 1})
			
			task.wait(ttime)
			newMessage:Destroy()
		end
		
	end)
end

game.ReplicatedStorage.Events.Client.Message.OnClientEvent:Connect(function(text,color,sound,waveMessage)
	_G.Message(text,color,sound,waveMessage)
end)