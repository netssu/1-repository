local ReplicatedStorage = game:GetService('ReplicatedStorage')
type AchievementType = "finish_level" | "summon_unit" | "own_new_unit"

local Players = game.Players

local DataAchievement = require(ReplicatedStorage.Data.Achivements)
local Message = ReplicatedStorage.Events.Client.Message
local StoreModeStats = require(ReplicatedStorage.StoryModeStats)
local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)
local AchievementHelper = require(game.ReplicatedStorage.Modules.AchievementHelper)


function DeepLoadedInstance(parent : Instance, table : table) : boolean	-- will return if its successful or not / can handle string and numbers atm
	for index, element in table do
		if typeof(element) == "table" then

			local folder = Instance.new("Folder")
			folder.Name = index
			folder.Parent = parent

			local success = DeepLoadedInstance(folder, element)
			if not success then
				return false
			end

		else

			local basicValues = {
				number = "NumberValue",
				boolean = "BoolValue",
				string = "StringValue"
			}

			local elementType = typeof(element)
			if not basicValues[elementType] then 
				warn(`DeepLoadedInstance does not support {element} type`) 
				return false 
			end

			local newInstance = Instance.new(basicValues[elementType])
			newInstance.Name = index
			newInstance.Value = element
			newInstance.Parent = parent

		end
	end

	return true

end

local AchievementHandler = {}

function AchievementHandler.Init()

	if PlaceData.Lobby == game.PlaceId then
		game.ReplicatedStorage.Functions.RedeemAchievement.OnServerInvoke = AchievementHandler.RedeemAchievement
	end

	Players.PlayerAdded:Connect(AchievementHandler.PlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(AchievementHandler)(player)
	end
end

function AchievementHandler.PlayerAdded(Player : Player)
	repeat task.wait() until Player:FindFirstChild("DataLoaded")

	local AchievementsData = Player:FindFirstChild("AchievementsData") or Player:WaitForChild("AchievementsData")
	if not AchievementsData or Player.Parent == nil then return end
	AchievementHandler.GiveAllAchievement(Player)


	--Temporary Test
	--task.spawn(function()
	--	local types = {
	--		"finish_level",
	--		--"summon_unit",
	--		--"own_new_unit"
	--	}
	--	while true do
	--		local randomType = types[math.random(1, #types)]
	--		if randomType == "finish_level" then
	--			AchievementHandler.UpdateAchievementProgress(Player, randomType, {
	--				AddAmount = 1,
	--				World = math.random(1,2),
	--				Level = math.random(1,5),
	--				Mode = 2
	--			})
	--		else
	--			AchievementHandler.UpdateAchievementProgress(Player, randomType,{
	--				AddAmount = 1
	--			})
	--		end

	--		task.wait(2)
	--	end
	--end)
end

function AchievementHandler.GiveAllAchievement(Player : Player)
	--print(DataAchievement)
	for _, achievement in DataAchievement do
		local themeDetail = achievement.Theme
		for i, achievementInfo in achievement.Achievements do
			if Player.AchievementsData.Achievements:FindFirstChild(achievementInfo.AchievementId) then continue end
			AchievementHandler.GenerateAchievement(Player, achievementInfo, {LayoutOrder = i, ThemeId = themeDetail.ThemeId})
		end
		if not Player.AchievementsData.Themes:FindFirstChild(themeDetail.ThemeId) then
			AchievementHandler.GenerateTheme(Player, themeDetail)
		end

	end

end

function AchievementHandler.UpdateAchievementProgress(Player, AchievementType : AchievementType, AdditionalParem)

	for _, achievement in Player.AchievementsData.Achievements:GetChildren() do
		local achievementInfo = achievement.AchievementInfo
		local achievementRequirement = achievementInfo.AchievementRequirement
		local achievementType = achievementRequirement.Type
		if achievementType.Value ~= AchievementType then continue end
		if AchievementType == "finish_level" then
			if AdditionalParem.World ~= achievementRequirement.World.Value then continue end
			if AdditionalParem.Level ~= achievementRequirement.Level.Value then continue end
			if achievementRequirement:FindFirstChild("Mode") then
				if achievementRequirement.Mode.Value ~= AdditionalParem.Mode then
					continue 
				end
			end
		end

		local setAmount = math.clamp(achievement.AchievementProgress.Amount.Value + AdditionalParem.AddAmount, 0, achievementRequirement.Amount.Value)
		achievement.AchievementProgress.Amount.Value = setAmount
	end
end

function AchievementHandler.RedeemAchievement(Player, AchievementId)
	local AchievementsData = Player:FindFirstChild("AchievementsData") or Player:WaitForChild("AchievementsData")
	if not AchievementsData or Player.Parent == nil then return end

	local Advancement = AchievementsData.Achievements:FindFirstChild(AchievementId)



	if Advancement then
		print(Advancement)
		if Advancement.Claimed.Value == true then return end

		local canRedeem = false
		local type = Advancement.AchievementInfo.AchievementRequirement.Type.Value

		if type == 'finish_level' then
			local world = StoreModeStats.Worlds[Advancement.AchievementInfo.AchievementRequirement.World.Value]
			local num = Advancement.AchievementInfo.AchievementRequirement.Level.Value
			canRedeem = Advancement.AchievementInfo.AchievementRequirement.Amount.Value == Advancement.AchievementProgress.Amount.Value or false
		elseif type == "achievement_completed" then
			local achievementsCompleted, achievements = AchievementHelper.GetCompleteAchievement(Player, Advancement.ThemeId.Value)
			canRedeem = #achievementsCompleted == #achievementsCompleted or false
		end

		if canRedeem then
			-- make achievement as done
			Advancement.Claimed.Value = true
			Advancement.AchievementInfo.AchievementRequirement.Type.Value = 'achievement_completed'

			-- grant rewards for redeeming
			for i,v in pairs(Advancement.AchievementInfo.AchievementReward:GetChildren()) do
				Player[v.Name].Value += v.Value
				print(v.Name)
			end
			Message:FireClient(Player, "Redeemed Achievement", Color3.fromRGB(0, 255, 0))
		else
			Message:FireClient(Player, "Cant Redeem", Color3.fromRGB(255, 0, 0))
		end		
	end
end

function AchievementHandler.GenerateTheme(Player, ThemeInfo, AdditionalInfo)
	local themeData = {
		[ThemeInfo.ThemeId] = {
			ThemeInfo = ThemeInfo,
			LayoutOrder = ThemeInfo.LayoutOrder
		}
	}

	DeepLoadedInstance(Player.AchievementsData.Themes, themeData)

end

function AchievementHandler.GenerateAchievement(Player, AchievementInfo, AdditionalInfo)

	if Player.AchievementsData.Achievements:FindFirstChild(AchievementInfo.AchievementId) then return end

	local achievementData = { [AchievementInfo.AchievementId] = {
		AchievementInfo = AchievementInfo,
		LayoutOrder = AdditionalInfo.LayoutOrder,
		AchievementProgress = {
			Amount = 0
		},
		ThemeId = AdditionalInfo.ThemeId,
		Claimed = false
	}}

	DeepLoadedInstance(Player.AchievementsData.Achievements, achievementData)
end

return AchievementHandler
