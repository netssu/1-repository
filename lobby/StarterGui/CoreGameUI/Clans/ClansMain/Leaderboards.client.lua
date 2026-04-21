local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClansFrame = script.Parent.Parent.ClansFrame.Internal
local LeaderboardFrame = ClansFrame.Leaderboards

local ClanRemotes = ReplicatedStorage.Remotes.Clans
local GetLeaderboard = ClanRemotes.GetLeaderboard -- Gems, XP, Kills

repeat task.wait() until Player:FindFirstChild('ClansLoaded')

local CurrentClan = Player.ClanData.CurrentClan
local ClanLevelCalculation = require(ReplicatedStorage.ClansLib.ClanLevelCalculation)
local NumberValueConvert = require(ReplicatedStorage.AceLib.NumberValueConvert)

local HomeFrame = ClansFrame.Home

while true do
	task.wait(10)
	local GemsLeaderboard = GetLeaderboard:InvokeServer('Gems')
	local KillsLeaderboard = GetLeaderboard:InvokeServer('Kills')
	local XPLeaderboard = GetLeaderboard:InvokeServer('XP')
	
	--print('Leaderboards, gems, kills, XP:')
	local LeaderboardData = {
		Vault = GemsLeaderboard,
		Kills = KillsLeaderboard,
		XP = XPLeaderboard
	}
	
	
	-- {Clan = clan_id,Value = value,Image = image, Description = description}
	

	for LBType, v in LeaderboardData do
		-- i = LB type
		-- v = data
		if #v == 0 then continue end
		
		local TargetLB: ScrollingFrame = LeaderboardFrame[LBType].ScrollingFrame
		if TargetLB:FindFirstChild('LoadingLabel') then -- idk some stupid error
			TargetLB.LoadingLabel.Visible = false -- not loading anymore ;)
		end
		
		for i,v:Frame in TargetLB:GetChildren() do
			if v:IsA('GuiBase2d') then
				v:Destroy()
			end
		end
		
		local foundUsInLB = false
		
		for position, data in v do
			-- check if its us!
			if data.Clan == CurrentClan.Value then
				foundUsInLB = true
				TargetLB.Parent.RankLabel.Text = '#' .. tostring(position)
				HomeFrame.ClanRankFrame[LBType].Rank.RankLabel.Text = '#' .. tostring(position)
			end
			
			
			local template: Frame = TargetLB.UIListLayout._TemplateLeaderboardFrame:Clone()
			
			if position < 4 then
				template.ClanIcon.RankFrame.Medal.TextLabel.Text = position
				template.ClanIcon.RankFrame.Medal.UIGradient.Color = script[tostring(position)].Color
			else
				template.ClanIcon.RankFrame.Visible = false
			end
			
			template.Name = data.Clan
			template.LayoutOrder = position
			
			template.ClanName.Text = data.Clan
			template.ClanIcon.Image = `rbxassetid://{data.Image}`
			template.Description.Text = data.Description
			template.TrackingLabel.Text = NumberValueConvert.convert(data.Value)
			
			if LBType == 'XP' then
				template.TrackingLabel.Text ..= ' XP'
				template.LVL.Text = 'LVL ' .. ClanLevelCalculation.getLevelFromXP(tonumber(data.Value))
			end
			
			template.Parent = TargetLB
			
			task.wait()
		end
		
		
		if not foundUsInLB then
			-- #>100
			TargetLB.Parent.RankLabel.Text = '#>100'
			HomeFrame.ClanRankFrame[LBType].Rank.RankLabel.Text = '#>100'
		end
		
		
	end
	
	
end