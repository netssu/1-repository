local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)
if game.PlaceId == PlaceData.Game then
	for _, sound in script.Parent.Parent.VFX:GetDescendants() do
		if sound:IsA("Sound") then
			sound.SoundGroup = game.SoundService.Game
		end
	end
	for _, sound in script.Parent.Parent.Modules.Client.UIHandler.Sounds:GetChildren() do
		if sound:IsA("Sound") then
			sound.SoundGroup = game.SoundService.UI
		end
	end
end