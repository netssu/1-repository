local SoundService = game:GetService("SoundService")

local module = {}

function module.playSound(soundName)
	local sound : Sound = script[soundName]:Clone()
	
	sound.Parent = SoundService
	
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	
	sound:Play()
end

return module