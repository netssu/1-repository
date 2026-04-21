local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GroupId = 35339513
local ImageModule = require( game:GetService("ReplicatedStorage").Prestige.Main.Images )
local ValidRoles : { [string] : Color3 } = {
	["Owner"] = Color3.fromRGB(255, 128, 0),
	["Content Creator"] = Color3.fromRGB(255, 0, 0),
	["Developer"] = Color3.fromRGB(0, 4, 255),
	["Developer+"] = Color3.fromRGB(0, 4, 255),
	["Manager"] = Color3.fromRGB(93, 43, 0),
	['Community Manager'] = Color3.fromRGB(101,185,158)
}
local White = Color3.new( 1 , 1 , 1 )
local Yellow = Color3.new( 1 , 1 , 0 )

local ULTRA = script.ULTRA
local Nametag = script.Nametag
local ClanTags = require(ReplicatedStorage.ClansLib.ClanTags)


local OnNametag = function(Character:Model, Player:Player)
	repeat
		task.wait( 0.15 )
	until not Player or Player:FindFirstChild('DataLoaded')
	if not Player or not Player.Parent then print('nope') return end
	local Head = Character:FindFirstChild('Head')
	if not Head then print('nopee') return end
	--
	local NewNametag = Head:FindFirstChild(Nametag.Name) or Nametag:Clone()
	
	-- 
	NewNametag.NameDisplay.Text = Player.DisplayName
	NewNametag.Parent = Head

	NewNametag.LevelFrame.LevelDisplay.Text = tostring( ( Player:WaitForChild('PlayerLevel') :: IntValue ).Value )

	local Prestige = Player:WaitForChild('Prestige') :: IntValue
	local IsPrestige = Prestige.Value > 0
	NewNametag.LevelFrame.LevelLabel.Prestige.Visible = IsPrestige
	if IsPrestige then
		NewNametag.LevelFrame.LevelLabel.Prestige.Image = ImageModule[Prestige.Value]
	end

	local RankDisplay = NewNametag.RankDisplay
	local PlayerRoleInGroup = Player:GetRoleInGroup( GroupId )
	local IsTaggedRank = ValidRoles[PlayerRoleInGroup]

	local OwnGamePasses = Player.OwnGamePasses
	local OwnsUltraVIP = OwnGamePasses["Ultra VIP"].Value
	local OwnsVIP = OwnGamePasses.VIP.Value

	local StreakNum = Player.Streak.Value

	if StreakNum ~= 0 then
		NewNametag.LevelFrame.LevelDisplay.FireIcon.TextLabel.Text = StreakNum
		NewNametag.LevelFrame.LevelDisplay.FireIcon.Visible = true
	end


	RankDisplay.Visible = IsTaggedRank or OwnsUltraVIP or OwnsVIP
	RankDisplay.Text = ( IsTaggedRank and `[ {PlayerRoleInGroup} ]` ) or ( OwnsUltraVIP and '[ ULTRA VIP ]' ) or ( OwnsVIP and '[ VIP ]') or ''
	RankDisplay.TextColor3 = IsTaggedRank or ( ( OwnsVIP and not OwnsUltraVIP ) and Yellow ) or White
	if OwnsUltraVIP then
		ULTRA:Clone().Parent = RankDisplay
	end
	
	if Player:FindFirstChild('ClansLoaded') then
		local CurrentClan = Player.ClanData.CurrentClan.Value
		local ClanData = ReplicatedStorage.Clans:FindFirstChild(CurrentClan)
		if CurrentClan ~= 'None' and ClanData then
			NewNametag.ClanTag.Text = `[{CurrentClan}]`
			
			
			local tagColor = ClanTags.Tags[ClanData['ActiveColor'].Value].Color
			if typeof(tagColor) ~= 'table' then
				NewNametag.ClanTag.TextColor3 = tagColor
				NewNametag.ClanTag.UIGradient.Color = script.UIGradient.Color
			else
				local keypoints = {}
				local count = #tagColor
				for i, color in ipairs(tagColor) do
					local position = (i - 1) / (count - 1)
					table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
				end
				local gradient = ColorSequence.new(keypoints)
				NewNametag.ClanTag.TextColor3 = Color3.fromRGB(255,255,255)
				NewNametag.ClanTag.UIGradient.Color = gradient
			end
			
			NewNametag.ClanTag.Visible = true
		else
			NewNametag.ClanTag.Visible = false
		end
	end
end

local Players : Players = game:GetService('Players')
Players.PlayerAdded:Connect(function( Player : Player )
	Player.CharacterAdded:Connect(function( Character : Model )
		OnNametag( Character , Player )
	end)
end)

script.Apply.Event:Connect(function(plr)
	OnNametag(plr.Character, plr)
end)