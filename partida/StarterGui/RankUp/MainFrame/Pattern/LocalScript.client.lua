local TweenService = game:GetService('TweenService')

TweenService:Create(script.Parent, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut,-1), {Position = UDim2.fromScale(0,1)}):Play()