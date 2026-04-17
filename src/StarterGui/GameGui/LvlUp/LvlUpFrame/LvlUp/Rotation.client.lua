if true then return end

while task.wait() do
	script.Parent.Unit.UIGradient.Rotation = (script.Parent.Unit.UIGradient.Rotation+2)%360

end
