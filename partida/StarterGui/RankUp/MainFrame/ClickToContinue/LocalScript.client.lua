script.Parent:GetPropertyChangedSignal('TextTransparency'):Connect(function()
	script.Parent.UIStroke.Transparency = script.Parent.TextTransparency
end)