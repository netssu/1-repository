type QuestType = "summon_unit" | "finish_level" | "kills" | "clear_waves_multiplayer" | "finish_any_story_level" | "daily_login"
type QuestCategory = "story" | "daily" | "weekly" | "infinite" | "event"
type UpdateProgressAdditionalParem = { AddAmount : number, World : number?, Level : number? }
type AdditionalQuestInfo = { QuestCategory : QuestCategory }

local AchievementHelper = {}

function AchievementHelper.GetCompleteAchievement(Player, ThemeId)--auto exclude final
	local _, achievements = AchievementHelper.GetAchievementsByThemeId(Player, ThemeId)
	
	local completedList = {}
	for _, achievement in achievements do
		if achievement.AchievementProgress.Amount.Value == achievement.AchievementInfo.AchievementRequirement.Amount.Value then
			table.insert(completedList, achievement)
		end
	end
	
	return completedList, achievements
	
end

function AchievementHelper.GetAchievementsByThemeId(Player : Player, ThemeId, AddtionalInfo)
	local achievementsData = Player:FindFirstChild("AchievementsData")
	local achievements = achievementsData and achievementsData:FindFirstChild("Achievements") or nil
	if not achievements then return {} end

	local list = {}
	local finalAchievement = nil
	for _, achievement in achievements:GetChildren() do
		if achievement.ThemeId.Value ~= ThemeId then continue end
		if achievement.AchievementInfo:FindFirstChild("Final") and achievement.AchievementInfo.Final.Value == true then
			finalAchievement = achievement
		else
			table.insert(list, achievement)
		end
	end
	return finalAchievement, list
end

return AchievementHelper
