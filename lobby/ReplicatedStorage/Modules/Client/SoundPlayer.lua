local SoundService = game:GetService("SoundService")
local SoundFolder = SoundService.NewSFX

local module = {}

function module.PlaySound(name)
	local foundSound = nil
	
	for i,v in SoundFolder:GetChildren() do
		if v:FindFirstChild(name) then
			foundSound = v[name]
			break
		end
	end
	
	if foundSound then
		foundSound:Play()
	end
end


return module