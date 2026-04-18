local debris = game:GetService("Debris")

local function playSoundAt(instance: Instance, soundId: number, volume: number?, pitch: boolean?): ()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. soundId
	sound.Volume = volume or 0.5
	sound.RollOffMaxDistance = 75
	sound.Parent = instance

	if pitch then
		local pitchEffect = Instance.new("PitchShiftSoundEffect")
		pitchEffect.Octave = math.random(90, 110) / 100
		pitchEffect.Parent = sound
	end

	sound:Play()
	sound.Ended:Connect(function()
		debris:AddItem(sound)
	end)
end

return playSoundAt
