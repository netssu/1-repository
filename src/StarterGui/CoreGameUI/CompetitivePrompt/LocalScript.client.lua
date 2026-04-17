local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Zone = require(ReplicatedStorage.Modules.Zone)
local Area = workspace:WaitForChild('CompetitiveZone'):WaitForChild('CompZone')

local Container = Zone.new(Area)

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		_G.CloseAll('CompetitivePrompt')
	end
end)


Container.playerExited:Connect(function(plr)
	if plr == Player then
		_G.CloseAll()
	end
end)

local TeleportCompRemote = ReplicatedStorage.Remotes.TeleportMeToComp
local Confirm = script.Parent.CompetitivePromptFrame.Auto_Fuse_Frame.Contents.Select.Confirm

Confirm.Activated:Connect(function()
	TeleportCompRemote:FireServer()
	Confirm.Visible = false
	task.wait(15)
	Confirm.Visible = true
end)