local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportToChamberEvent = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("TeleportToChamber")

local ConfirmationFrame = script.Parent:WaitForChild("AfkChamberFrame")
local TeleportButton = ConfirmationFrame.Auto_Fuse_Frame.Contents.Select.Confirm
local RunService = game:GetService('RunService')

local UI_Handler = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))

local Player = game.Players.LocalPlayer

local teleportCooldown = false
TeleportButton.Activated:Connect(function()
	TeleportToChamberEvent:FireServer()
	teleportCooldown = true
	task.wait(10)
	teleportCooldown = false
end)

local Timechamber = workspace:WaitForChild('TimeChamber'):WaitForChild('Hitbox')
local Zone = require(ReplicatedStorage.Modules.Zone)
local Container = Zone.new(Timechamber)

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		_G.CloseAll('AfkChamberFrame')
		UI_Handler.DisableAllButtons()
	end
end)


Container.playerExited:Connect(function(plr)
	if plr == Player then
		_G.CloseAll()
		UI_Handler.EnableAllButtons()
	end
end)
