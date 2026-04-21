local ReplicatedStorage = game:GetService("ReplicatedStorage")

local whitelist = {
	794444736,
	2309402771,
	2486324247
}

local fire = ReplicatedStorage.BOOM

script.Parent.TextButton.Activated:Connect(function()
	script.Parent.TextButton.TextColor3 = Color3.fromRGB(0,255,0)
	fire:FireServer(script.Parent.Type.Text, script.Parent.UserId.Text)
	task.wait(2)
	script.Parent.TextButton.TextColor3 = Color3.fromRGB(0,0,0)
end)