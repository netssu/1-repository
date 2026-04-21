return function(ScaleObject : ParticleEmitter | {}, NewSize)
	if math.abs(NewSize - 1) < 0.01 then
		return;
	end;
	if type(ScaleObject) ~= "table" then
		ScaleObject = { ScaleObject };
	end;

	for _, ActualObject : ParticleEmitter in ScaleObject do
		if  ActualObject:IsA("ParticleEmitter") then
			local SequenceKeypointTable = {};
			for  _, KeyPo in ActualObject.Size.Keypoints do	
				table.insert(SequenceKeypointTable, NumberSequenceKeypoint.new(KeyPo.Time, KeyPo.Value * NewSize, KeyPo.Envelope * NewSize));		
			end;
			ActualObject.Size = NumberSequence.new(SequenceKeypointTable);
			ActualObject.Drag = ActualObject.Drag * NewSize;
			ActualObject.VelocityInheritance = ActualObject.VelocityInheritance * NewSize;
			ActualObject.Speed = NumberRange.new(ActualObject.Speed.Min * NewSize, ActualObject.Speed.Max * NewSize);
			ActualObject.Acceleration = Vector3.new(ActualObject.Acceleration.X * NewSize, ActualObject.Acceleration.Y * NewSize, ActualObject.Acceleration.Z * NewSize);	
		end;
	end;
end;