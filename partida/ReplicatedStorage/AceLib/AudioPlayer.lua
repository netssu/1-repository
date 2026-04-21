local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

local module = {}
local sounds = {}

function module.playSound(sound: Sound, timeShouldRepeatAt: number)
	local soundRef = sound:Clone()
	table.insert(sounds, soundRef)
	soundRef.Parent = SoundService
	soundRef:Play()

	if timeShouldRepeatAt then
		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not soundRef or not soundRef.Parent then
				connection:Disconnect()
				return
			end

			if soundRef.TimePosition >= timeShouldRepeatAt then
				soundRef.TimePosition = 0
				soundRef:Play()
			end
		end) 
	end
end

function module.stopAllSounds()
	for i,v in sounds do
		v:Destroy()
	end
end

return module