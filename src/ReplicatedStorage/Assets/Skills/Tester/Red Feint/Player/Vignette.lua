local Player = game:GetService("Players").LocalPlayer
local Gui = Player and Player:FindFirstChild("PlayerGui") or game:GetService("StarterGui")

local ScreenGui = Gui:FindFirstChild("Effects") if not ScreenGui then
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name, ScreenGui.IgnoreGuiInset, ScreenGui.ResetOnSpawn, ScreenGui.Parent = "Effects", true, false, Gui
end

local Template = script.Template
local TS = game:GetService("TweenService")
local Heartbeat = game:GetService("RunService").Heartbeat

local util = shared.fx.util
local num, scolor = util.num, util.sampleColor

return function(attrs)
	local Vignette = Template:Clone()
	Vignette.Name, Vignette.Parent = "Vignette", ScreenGui
	local sustain, fadein, fadeout = num(attrs.Sustain), num(attrs.FadeIn), num(attrs.FadeOut)
	
	local color = attrs.Color.Keypoints
	local lifetime = sustain + fadein + fadeout
	
	local t = 0
	local c = Heartbeat:Connect(function(delta)
		t += delta
		Vignette.ImageColor3 = scolor(color, t/lifetime)
	end)
	
	TS:Create(Vignette, TweenInfo.new(fadein), {
		ImageTransparency = attrs.Transparency
	}):Play()
	task.wait(fadein + sustain)
	TS:Create(Vignette, TweenInfo.new(fadeout), {
		ImageTransparency = 1
	}):Play()
	task.wait(fadeout)
	Vignette:Destroy()
	c:Disconnect()
end