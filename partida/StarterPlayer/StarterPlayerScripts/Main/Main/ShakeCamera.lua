local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraShake = require(ReplicatedStorage.AceLib.CameraShake)
local ShakeCamera = ReplicatedStorage.Remotes.Client.ShakeCamera

ShakeCamera.OnClientEvent:Connect(function(par1, par2)
	CameraShake.shakeCamera(par1, par2)
end)

return {}