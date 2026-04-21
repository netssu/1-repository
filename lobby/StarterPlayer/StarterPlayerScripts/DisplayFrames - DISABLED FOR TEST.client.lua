-- disabled by ace, pls check that this doesnt cause issues
if true then return end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = game:GetService("Players").LocalPlayer
local PlayerGUI = Player.PlayerGui
local COREGAMEUI : ScreenGui = PlayerGUI:WaitForChild("CoreGameUI")

ReplicatedStorage.Remotes.DisplayFramesOnLoad.OnClientEvent:Connect(function(name)
	warn("Fired Display Event")
	local Folder : Folder = COREGAMEUI:FindFirstChild(name)
	
	task.delay(5, function()
		for i,v in Folder:GetChildren() do
			if v:IsA("Frame") then
				warn(v)
				_G:CloseAll("DailyRewards")
			end
		end		
	end)

end)