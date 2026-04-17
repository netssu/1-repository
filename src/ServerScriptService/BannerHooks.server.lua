local RunService = game:GetService("RunService")

if RunService:IsStudio() or game.PlaceId == 117137931466956 then return end

local Webhooks = require(game.ReplicatedStorage.Modules.Webhooks)
local ChallengeModule = require(game.ReplicatedStorage.Modules.ChallengeModule)
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)

local DataStoreService = game:GetService("DataStoreService")
local BannerHookStore = DataStoreService:GetDataStore("BannerHookStore")
local banner = workspace.CurrentHour
local COOLDOWN = 120

local function updateIfDue(key, currentTimestamp)
	local success, updated = pcall(function()
		return BannerHookStore:UpdateAsync(key, function(old)
			old = old or 0
			if currentTimestamp - old >= COOLDOWN then
				return currentTimestamp
			end
			return nil
		end)
	end)
	return success and updated == currentTimestamp
end

local function sendBanner()
	local description = "# MYTHICALS\n"
	for i = 1, 3 do
		local val = banner:GetAttribute("Mythical" .. i)
		if val then
			val = "・ **"..val.."**"
			description ..= string.format("## %d %s\n", i, val)
		end
	end

	Webhooks.Embed({
		Color = "red",
		Description = description,
		Title = "Live Banner",
	})
end

local function sendChallenge()
	local DataFolder = workspace.ChallengeElevators.Data

	local ChallengeNumber = DataFolder.ChallengeNumber.Value
	local ChallengeRewardNumber = DataFolder.ChallengeRewardNumber.Value
	local World = DataFolder.World.Value
	local Level = DataFolder.Level.Value
	local RefreshingAt = DataFolder.RefreshingAt.Value

	local ChallengeData = ChallengeModule.Data[ChallengeNumber]
	local ChallengeRewardData = ChallengeModule.Rewards[ChallengeData.Difficulty]
	local WorldName = StoryModeStats.Worlds[World]
	local BossName = StoryModeStats.LevelName[WorldName][Level]
	local WorldImageURL = StoryModeStats.Images[World]

	local description = "# CHALLENGE BANNER\n"
	description ..= "# **World:** " .. WorldName .. "\n"
	description ..= "## **Act:** " .. Level .. " - **" .. BossName .. "**\n"
	description ..= "**Challenge:** " .. ChallengeData.Name .. "\n"
	description ..= "**Description:** " .. ChallengeData.Description .. "\n"
	description ..= "**Rewards:** " .. ChallengeRewardData.Description .. "\n"

	Webhooks.Embed({
		Color = "red",
		Description = description,
		Title = "Live Banner",
	})
end

while task.wait(1) do
	local currentTimestamp = os.time(os.date("!*t"))
	local minute = DateTime.now():ToUniversalTime().Minute

	if minute == 0 or minute == 30 then
		if updateIfDue("WebhookLastSend", currentTimestamp) then
			sendBanner()
			sendChallenge()
		end
	end
end
