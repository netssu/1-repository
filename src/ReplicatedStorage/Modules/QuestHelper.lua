type QuestType = "summon_unit" | "finish_level" | "kills" | "clear_waves_multiplayer" | "finish_any_story_level" | "daily_login"
type QuestCategory = "story" | "daily" | "weekly" | "infinite" | "event"
type UpdateProgressAdditionalParem = { AddAmount : number, World : number?, Level : number? }
type AdditionalQuestInfo = { QuestCategory : QuestCategory }

local QuestHelper = {}

function QuestHelper.IsQuestComplete(Player : Player, Quest : Folder)
	local completed = Quest.QuestInfo.QuestRequirement.Type.Value == "free" or (Quest.QuestProgress.Amount.Value >= Quest.QuestInfo.QuestRequirement.Amount.Value) or false
	local amount, requireAmount
	if Quest.QuestInfo.QuestRequirement.Type.Value == "free" then
		amount = 1
		requireAmount = 1
	else
		amount = Quest.QuestProgress.Amount.Value
		requireAmount = Quest.QuestInfo.QuestRequirement.Amount.Value
	end
	return completed, amount, requireAmount
end

function QuestHelper.GetQuestsByCategory(Player : Player, QuestCategory : QuestCategory)
	local questsData = Player:FindFirstChild("QuestsData")
	local quests = questsData and questsData:FindFirstChild("Quests") or nil
	if not quests then return {} end

	local list = {}
	
	for _, quest in quests:GetChildren() do
		if quest.QuestCategory.Value ~= QuestCategory then continue end
		table.insert(list, quest)
	end
	return list
end

return QuestHelper
