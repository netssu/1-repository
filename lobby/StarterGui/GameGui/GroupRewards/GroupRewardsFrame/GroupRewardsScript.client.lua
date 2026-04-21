local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game.Players
local Player = Players.LocalPlayer
local TS = game:GetService("TweenService")
local UIHandlerModule = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIHandler"))

local Event = game.ReplicatedStorage.Events:WaitForChild("GroupRewards")
local GroupRewardsFrame = script.Parent.Frame
local RewardsFrame = script.Parent.Frame.RewardsFrame
local OpenFrame = script.Parent

local open = false

local function UpdUi()

	if Player.ClaimedGroupReward.Value  then
		GroupRewardsFrame.ClaimButton.Interactable = false
		GroupRewardsFrame.ClaimButton.TextLabel.Text = "Claimed"
		OpenFrame.Claimed.Visible = true
		GroupRewardsFrame.ClaimButton.Image = GroupRewardsFrame.ClaimButton.ClaimedTexture.Value
		GroupRewardsFrame.ClaimButton.TextLabel.Visible = false
		RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = true
		RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = true
		RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = "1/1"
		RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = "1/1"
	else
		if Player:IsInGroup(35339513) then
			OpenFrame.Claimed.Visible = false
			GroupRewardsFrame.ClaimButton.Image = GroupRewardsFrame.ClaimButton.NotClaimedTexture.Value
			GroupRewardsFrame.ClaimButton.TextLabel.Visible = true
			GroupRewardsFrame.ClaimButton.Interactable = true
			GroupRewardsFrame.ClaimButton.TextLabel.Text = "Claim"
			RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = true
			RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = true
			RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = "1/1"
			RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = "1/1"
		else
			OpenFrame.Claimed.Visible = false
			GroupRewardsFrame.ClaimButton.Image = GroupRewardsFrame.ClaimButton.NotClaimedTexture.Value
			GroupRewardsFrame.ClaimButton.TextLabel.Visible = true
			GroupRewardsFrame.ClaimButton.Interactable = true
			GroupRewardsFrame.ClaimButton.TextLabel.Text = "Claim"
			RewardsFrame.GroupFrame.Frame.ImageButton.UIGradient.Enabled = false
			RewardsFrame.LikeFrame.Frame.ImageButton.UIGradient.Enabled = false
			RewardsFrame.GroupFrame.Frame.ImageButton.TextLabel.Text = "0/1"
			RewardsFrame.LikeFrame.Frame.ImageButton.TextLabel.Text = "0/1"
		end
	end
end

GroupRewardsFrame.ClaimButton.MouseButton1Up:Connect(function()
	UpdUi()
	if Player:IsInGroup(35339513) then
		Event:FireServer(Player)
		_G.Message("Successfully",Color3.new(1, 0.666667, 0),nil, "Success")
	else
		_G.Message("You need join in group and like the Game",Color3.new(1, 0, 0),nil, "Error")
	end

end)

script.Parent.ExitButton.Activated:Connect(function()
    if open then
        UIHandlerModule.EnableAllButtons()
        script.Parent.Parent.Parent.Parent:WaitForChild("UnitsGui").Inventory.Units.Visible = false
    end
    OpenFrame.Visible = false
    open = false
	--local chr = Player.Character
	--if chr then
	--	chr:SetPrimaryPartCFrame(workspace.GroupRewardsTeleporters.TeleportOut.CFrame) 
		
	--end
end)

local Zone = require(ReplicatedStorage.Modules.Zone)
local Container = Zone.new(workspace:WaitForChild('GroupRewardsBox'):WaitForChild('JoinGroupandLikeHitbox'))

Container.playerEntered:Connect(function(plr)
	if plr == Player then
		UpdUi()
		UIHandlerModule.DisableAllButtons()
		_G.CloseAll('GroupRewards')
	end
end)

Container.playerExited:Connect(function(plr)
	if plr == Player then
		UIHandlerModule.EnableAllButtons()
		_G.CloseAll()
	end
end)