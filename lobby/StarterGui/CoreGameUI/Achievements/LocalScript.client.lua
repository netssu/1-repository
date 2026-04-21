local RedeemAchievement = game.ReplicatedStorage.Functions.RedeemAchievement

local AchievementHelper = require(game.ReplicatedStorage.Modules.AchievementHelper)
local UIHandler = require(game.ReplicatedStorage.Modules.Client.UIHandler)

local Main = script.Parent.AchievementsFrame.Main
local AchievementGroupTemplate = Main.Templates.AchievementGroupTemplate
local AchievementTemplate = Main.Templates.AchievementTemplate
local Themes = script.Parent.AchievementsFrame.Themes
local ThemeTemplate = Themes.Templates.ThemeTemplate

local Player = game.Players.LocalPlayer

local tracker = {}

function ThemeAdded(theme)
	local parem = CreateThemeGroup(theme)

	for _, achievementSub in parem.Achievements.Sub do
		local achievementInfo = achievementSub.Achievement.AchievementInfo
		local achievementRequirement = achievementInfo.AchievementRequirement
		local achievementProgress = achievementSub.Achievement.AchievementProgress

		achievementProgress.Amount.Changed:Connect(function()
			achievementSub.Gui.AchievementDescription.Text = `{achievementInfo.AchievementDescription.Value}({achievementProgress.Amount.Value}/{achievementRequirement.Amount.Value})`

			local achievementsCompleted, achievements = AchievementHelper.GetCompleteAchievement(Player, theme.ThemeInfo.ThemeId.Value)
			print(achievementsCompleted, achievements, (#achievementsCompleted/#achievements) * 100)
			parem.Theme.Gui.Completion.Text = `Completion: {(#achievementsCompleted/#achievements) * 100}%`
			parem.Achievements.Final.Gui.Progress.Bar.Size = UDim2.fromScale(#achievementsCompleted/#achievements, 1)
			if #achievementsCompleted == #achievements then
				parem.Achievements.Final.Gui.InComplete.Visible = false
				parem.Achievements.Final.Gui.Claim.Visible = true
			end
		end)

		for _, rewardGui in achievementSub.Gui.Rewards:GetChildren() do
			if not rewardGui:IsA("GuiButton") then continue end
			rewardGui.MouseButton1Down:Connect(function()
				RedeemAchievement:InvokeServer(achievementInfo.AchievementId.Value)
			end)
		end

		achievementSub.Achievement.Claimed.Changed:Connect(function()
			for _, rewardGui in achievementSub.Gui.Rewards:GetChildren() do
				if not rewardGui:IsA("GuiButton") then continue end
				rewardGui.Claimed.Visible = true
			end
		end)

	end
	
	parem.Achievements.Final.Achievement.Claimed.Changed:Connect(function()
		parem.Achievements.Final.Gui.Claim.Visible = false
		parem.Achievements.Final.Gui.InComplete.Visible = true
	end)
	
	parem.Theme.Gui.MouseButton1Down:Connect(function()
		SelectTheme(theme.ThemeInfo.ThemeId.Value)
	end)

end

function SelectTheme(themeId)
	for _, trackData in tracker do
		if trackData.Theme.Theme.ThemeInfo.ThemeId.Value == themeId then
			trackData.Theme.GroupGui.Visible = true
			trackData.Theme.Gui.SelectOn.Visible = true
			trackData.Theme.Gui.SelectOff.Visible = false
		else
			trackData.Theme.GroupGui.Visible = false
			trackData.Theme.Gui.SelectOn.Visible = false
			trackData.Theme.Gui.SelectOff.Visible = true
		end
	end
end

function CreateThemeGroup(theme)
	local themeInfo = theme.ThemeInfo

	local finalAchievement, achievements = AchievementHelper.GetAchievementsByThemeId(Player, themeInfo.ThemeId.Value)
	local achievementsCompleted, achievements = AchievementHelper.GetCompleteAchievement(Player, theme.ThemeInfo.ThemeId.Value)

	local groupClone = AchievementGroupTemplate:Clone()
	groupClone.Visible = true
	groupClone.Name = themeInfo.ThemeId.Value
	groupClone.Parent = Main

	groupClone.Final.MainProgress.Progress.Bar.Size = UDim2.fromScale(#achievementsCompleted/#achievements, 1)
	groupClone.Final.Claim.MouseButton1Down:Connect(function()
		RedeemAchievement:InvokeServer(finalAchievement.AchievementInfo.AchievementId.Value)
	end)
	
	if #achievementsCompleted == #achievements and not finalAchievement.Claimed.Value then
		groupClone.Final.InComplete.Visible = false
		groupClone.Final.Claim.Visible = true
	end


	local trackAchievements = {
		Final = {
			Achievement = finalAchievement,
			Gui = groupClone.Final
		},
		Sub = {}
	}

	--load all the achievement
	for _, achievement in achievements do
		local clone = AchievementTemplate:Clone()
		clone.Visible = true
		clone.AchievementName.Text = achievement.AchievementInfo.AchievementName.Value
		clone.AchievementDescription.Text = `{achievement.AchievementInfo.AchievementDescription.Value}({achievement.AchievementProgress.Amount.Value}/{achievement.AchievementInfo.AchievementRequirement.Amount.Value})`
		clone.LayoutOrder = achievement.LayoutOrder.Value
		clone.Parent = groupClone.Sub.Scrolls


		for _, reward in achievement.AchievementInfo.AchievementReward:GetChildren() do
			if not clone.Rewards:FindFirstChild(reward.Name) then continue end
			clone.Rewards[reward.Name].Visible = true
			clone.Rewards[reward.Name].Amount.Text = `x{reward.Value}`
			
			if achievement.Claimed.Value then
				clone.Rewards[reward.Name].Claimed.Visible = true
			end
			
		end

		trackAchievements.Sub[achievement.AchievementInfo.AchievementId.Value] = {
			Gui = clone,
			Achievement = achievement
		}
	end


	--load theme

	local themeClone = ThemeTemplate:Clone()
	themeClone.Name = themeInfo.ThemeId.Value
	themeClone.ThemeName.Text = themeInfo.ThemeName.Value
	themeClone.Visible = true
	themeClone.Completion.Text = `Completion: {(#achievementsCompleted/#achievements) * 100}%`
	themeClone.LayoutOrder = theme.LayoutOrder.Value
	themeClone.Icon.Image = themeInfo.ThemeImage.Value
	themeClone.Parent = Themes.Scrolls

	tracker[themeInfo.ThemeId] = {
		Theme = {
			Gui = themeClone,
			Theme = theme,
			GroupGui = groupClone
		},
		Achievements = trackAchievements
	}

	return tracker[themeInfo.ThemeId]

end

script.Parent.AchievementsFrame.ExitButton.MouseButton1Down:Connect(function()
	_G.CloseAll()
	UIHandler.EnableAllButtons()
end)

Player.AchievementsData.Themes.ChildAdded:Connect(ThemeAdded)
for _, theme in Player.AchievementsData.Themes:GetChildren() do
	ThemeAdded(theme)
end


local smallestOrder, themeId
for _, trackData in tracker do
	if smallestOrder ~= nil and trackData.Theme.Theme.LayoutOrder.Value > smallestOrder then continue end
	smallestOrder = trackData.Theme.Theme.LayoutOrder.Value
	themeId = trackData.Theme.Theme.ThemeInfo.ThemeId.Value
end

SelectTheme(themeId)
