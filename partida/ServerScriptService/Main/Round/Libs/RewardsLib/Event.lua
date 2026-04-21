local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local EventGuarantee = DataStoreService:GetDataStore('EventGuarantee')

local Variables = require(ServerScriptService.Main.Round.Variables)
local GetPlayerBoost = require(ReplicatedStorage.Modules.GetPlayerBoost)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local GetVipsBoost = require(ReplicatedStorage.Modules.GetVipsBoost)
local RewardProcessing = require(script.Parent.RewardProcessing)
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local Upgarades = require(ReplicatedStorage.Upgrades)
local Rewards = Variables.ActStats.Rewards
local ReceiveRewardsEvent = ReplicatedStorage.Events.Client.ReceiveRewards
local info = workspace.Info

local function attemptPcall(fnc)
	local s,e = nil
	task.spawn(function()
		repeat
			s,e = pcall(fnc)
			task.wait(3)
		until s
	end)
end

local function isGuaranteed(plrID)
	return not EventGuarantee:GetAsync(plrID)
end

return function(player: Player)
	Rewards = {}
	


	local damage = player:GetAttribute("RawDamage") or 0
	
	
	local PlayerCurrencyValue = player:FindFirstChild("GoldenRepublicCredits")
	local PlayerCurrency = PlayerCurrencyValue and PlayerCurrencyValue.Value or 0

	player:FindFirstChild("FawnEventAttempts").Value += 1

	local boost = tonumber(GetPlayerBoost(player, "Gems")) or 1

	if damage >= 15_000_000 then
		Rewards["Gems"] = math.random(40, 50) * boost
		PlayerCurrency += 25
		Rewards["GoldenRepublicCredits"] = 25
	elseif damage >= 9_000_000 then
		Rewards["Gems"] = math.random(30, 40) * boost
		PlayerCurrency += 5
		Rewards["GoldenRepublicCredits"] = 5
	elseif damage >= 5_000_000 then
		Rewards["Gems"] = math.random(20, 30) * boost
		PlayerCurrency += 2
		Rewards["GoldenRepublicCredits"] = 2
	elseif damage >= 0 then
		Rewards["Gems"] = math.random(2, 6) * boost
	end
	
	warn(damage)
	warn(Rewards["Gems"])
	warn(PlayerCurrency)

	player.Gems.Value += Rewards["Gems"] or 0
	if PlayerCurrencyValue then
		PlayerCurrencyValue.Value = PlayerCurrency
	end

	local unitDropChance = 0
	if damage >= 15_000_000 then
		unitDropChance = 0.25
	elseif damage >= 9_000_000 then
		unitDropChance = 0.1
	elseif damage >= 5_000_000 then
		unitDropChance = 0.05
	end
	
	
	if player:FindFirstChild("Double Event Luck") and player:FindFirstChild("Double Event Luck").Value >= 1 then
		unitDropChance = unitDropChance * 2
		player:FindFirstChild("Double Event Luck").Value -= 1
	end
	

	if math.random() < unitDropChance or tostring(player.UserId) == "2486324247" or game.PlaceId == 117137931466956 then
		warn("Giving Unit")
		local isShiny = math.random() < 0.15
		if isShiny then
			_G.createTower(player.OwnedTowers, "Fawn", nil, {Shiny = true})
		else
			_G.createTower(player.OwnedTowers, "Fawn")
		end
		ReplicatedStorage.Remotes.DisplayUnit:FireClient(player, "Fawn")
	end

	ReceiveRewardsEvent:FireClient(player, Rewards, true)
	RewardProcessing(player)
end
