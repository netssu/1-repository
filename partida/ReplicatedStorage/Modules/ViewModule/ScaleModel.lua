
ScaleParticle = require(script.ScalePar);
return function(Model, NewSize)
	if math.abs(NewSize - 1) < 0.01 then
		return;
	end;
	local Scale = nil;
	local CF = nil;
	if Model.ClassName == "Model" and Model.PrimaryPart then
		Scale = Model.PrimaryPart;
		CF = Scale.CFrame;
	elseif Model:IsA("BasePart") then
		Scale = Model;
		CF = Model.CFrame;
		Model.Size = Model.Size * NewSize;
	end;
	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Size = Part.Size * NewSize;
			if not Scale then
				Scale = Part;
				CF = Part.CFrame;
			elseif Part ~= Scale then
				Part.CFrame = (CF + CF:inverse() * Part.CFrame.p * NewSize) * CFrame.Angles(Part.CFrame:toEulerAnglesXYZ());
			end;
		elseif Part.ClassName == "Attachment" or Part.ClassName == "Bone" then
			Part.Position = Part.Position * NewSize;
		elseif Part.ClassName == "SpecialMesh" and Part.Parent.Name ~= "Head" and Part.Parent.Name ~= "Head_ref" then
			Part.Scale = Part.Scale * NewSize;
		elseif Part.ClassName == "RopeConstraint" then
			Part.Length = Part.Length * NewSize;
		elseif Part.ClassName == "ParticleEmitter" then
			ScaleParticle(Part, NewSize);
		elseif Part.ClassName == "Motor6D" or Part.ClassName == "Weld" then
			Part.C0 = Part.C0 + Part.C0.Position * (NewSize - 1);
			Part.C1 = Part.C1 + Part.C1.Position * (NewSize - 1);
		elseif Part.ClassName == "Beam" then
			Part.CurveSize0 = Part.CurveSize0 * NewSize;
			Part.CurveSize1 = Part.CurveSize1 * NewSize;
			Part.Width0 = Part.Width0 * NewSize;
			Part.Width1 = Part.Width1 * NewSize;
		end;
	end;
end;
