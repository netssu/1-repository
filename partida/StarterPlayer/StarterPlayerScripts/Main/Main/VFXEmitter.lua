local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VFXPlayer = require(ReplicatedStorage.AceLib.VFXPlayer)

workspace:WaitForChild('ItemCache').DescendantAdded:Connect(function(obj)
	if obj:GetAttribute('ClientVFXPlay') then
		if obj:GetAttribute('ClientVFXPlayed') then
			VFXPlayer.emitVFX(obj)
		end

		obj:GetAttributeChangedSignal('ClientVFXPlayed'):Connect(function()
			if obj:GetAttribute('ClientVFXPlayed') then
				VFXPlayer.emitVFX(obj)
			else
				VFXPlayer.cutVFX(obj)
			end
		end)
	end	
end)

return {}