local module = {}

local function foundSound(character, soundName)	
	return character.PrimaryPart:FindFirstChild(soundName) or character.HumanoidRootPart:FindFirstChild(soundName) or character.Torso:FindFirstChild(soundName)
end

function module.playSound(character, soundName, looped)
	--local sound = foundSound(character, soundName)
	
	--if sound then
	--	sound:Play()
	--else
		local targetPart = character.PrimaryPart or character:FindFirstChild('HumanoidRootPart') or character:FindFirstChild('Torso')
		local sound: Sound = script[soundName]:Clone()
		sound.Looped = looped
		sound.Parent = targetPart
		sound:Play()
		
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		
	--end
end

function module.stopSound(character, soundName)
	local sound : Sound = foundSound(character, soundName)
	
	if sound then
		sound:Stop()
	end
end

return module