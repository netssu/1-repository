local TweenService = game:GetService("TweenService")
script.Parent.MouseButton1Click:Connect(function()
	TweenService:Create(script.Parent.Parent,TweenInfo.new(0.5,Enum.EasingStyle.Back),{Position = UDim2.new(1.2, 0,0.34, 0)}):Play()
	task.wait(0.25)
	script.Parent.Parent.Visible = false
end)