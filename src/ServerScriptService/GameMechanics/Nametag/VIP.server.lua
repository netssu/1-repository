local Players = game:GetService("Players")
--------- Tag Chat
local admins = require(game.ReplicatedStorage.Admins)
local gamepassId = 192964872
local service = game:GetService("MarketplaceService") 
local BadgeService = game:GetService("BadgeService")
local WelcomeBadge = 2162876883183795
local GroupId = 35339513
local RequiredRank = 254
local MeetDeveloperBadge = 296361498059703	
local ImageModule = require(game:GetService("ReplicatedStorage").Prestige.Main.Images)

local function isDeveloper(plr)
	local playerRank = plr:GetRankInGroup(GroupId)
	return playerRank >= RequiredRank
end

function main(Player, Character)
	repeat task.wait() until not Player or Player:FindFirstChild('DataLoaded')
	if Player and Player.Parent then -- hasnt left
		--Character:WaitForChild("Humanoid").DisplayDistanceType = ('None')

		Character:WaitForChild("HumanoidRootPart")

		local playerLevel = Player:WaitForChild("PlayerLevel")
		

		local overHead = script._overhead:Clone()
		overHead.Parent = Character.Head
		
		
		local prestige = Player:WaitForChild("Prestige")
		local PrestigeFrame = overHead.Frame.Prestige
		local Image = PrestigeFrame.PrestigeImage
		
		if prestige.Value > 0 then
			Image.Image = ImageModule[prestige.Value]
		else
			PrestigeFrame.Visible = false
		end
		
		overHead.Frame.Level_Frame.Level.Text = playerLevel.Value   
		overHead.Frame.Name_Frame.Name_Text.Text = Player.DisplayName

		local ValidRoles = {
			["Owner"] = Color3.fromRGB(255, 128, 0),
			["Content Creator"] = Color3.fromRGB(255, 0, 0),
			["Developer"] = Color3.fromRGB(0, 4, 255),
			["Developer+"] = Color3.fromRGB(0, 4, 255),
			["Manager"] = Color3.fromRGB(93, 43, 0),
			['Community Manager'] = Color3.fromRGB(101,185,158)
		}
		local PlayerRoleInGroup = Player:GetRoleInGroup(35339513)
		
		if ValidRoles[PlayerRoleInGroup] then

			overHead.Frame.Tag_Frame.Visible = true
			overHead.Frame.Tag_Frame.Tag_Text.Text = `[{PlayerRoleInGroup}]`
			overHead.Frame.Tag_Frame.Tag_Text.TextColor3 = ValidRoles[PlayerRoleInGroup]
		elseif Player.OwnGamePasses["Ultra VIP"].Value == true then
			overHead.Frame.Tag_Frame.Visible = true
			overHead.Frame.Tag_Frame.Tag_Text.UltraVIP_Gradient.Enabled = true
			overHead.Frame.Tag_Frame.Tag_Text.Text = `[ULTRA VIP]`
			overHead.Frame.Name_Frame.Name_Text.UltraVIP_Gradient.Enabled = true
		elseif Player.OwnGamePasses.VIP.Value == true then
			overHead.Frame.Tag_Frame.Visible = true
			overHead.Frame.Tag_Frame.Tag_Text.VIP_Gradient.Enabled = true
			overHead.Frame.Tag_Frame.Tag_Text.Text = `[VIP]`
			overHead.Frame.Name_Frame.Name_Text.VIP_Gradient.Enabled = true
		end
	end
end



game.Players.PlayerAdded:connect(function(Player)
	Player.CharacterAdded:connect(function(Character)
		main(Player, Character)
	end)
end)
