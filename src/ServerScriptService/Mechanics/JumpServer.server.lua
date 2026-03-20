------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage: ServerStorage = game:GetService("ServerStorage")

------------------//MODULES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local PogoData = require(ReplicatedStorage.Modules.Datas.PogoData)
local WorldConfig = require(ReplicatedStorage.Modules.Datas.WorldConfig)

local analyticsOk, AnalyticsService = pcall(function()
	return require(ServerStorage.Modules.Utility:WaitForChild("AnalyticsService"))
end)
if not analyticsOk then
	warn("[PogoServer] AnalyticsService não encontrado:", AnalyticsService)
	AnalyticsService = nil
end

------------------//SETUP REMOTES
local REMOTE_NAME: string = "PogoEvent"
local pogoEvent: RemoteEvent = ReplicatedStorage.Assets.Remotes:WaitForChild(REMOTE_NAME) :: RemoteEvent

------------------//CONSTANTS
local SETTINGS = {
	BaseCoinReward = 10,
	MaxReboundDistance = 60,
	MinTimeBetweenRebounds = 0.2,
	RebirthPowerScale = 0.5,
}

------------------//VARIABLES
local playerStates: {[number]: {lastActionTime: number, serverCombo: number}} = {}

------------------//FUNCTIONS
local function get_state(player: Player): {lastActionTime: number, serverCombo: number}
	local st = playerStates[player.UserId]
	if not st then
		st = {
			lastActionTime = 0,
			serverCombo = 0,
		}
		playerStates[player.UserId] = st
	end
	return st
end

local function update_attributes(player: Player, status: string, combo: number): ()
	player:SetAttribute("PogoState", status)
	player:SetAttribute("CurrentCombo", combo)
end

local function get_layer_by_height(player: Player, character: Model): any
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local worldId = DataUtility.server.get(player, "CurrentWorld") or 1
	local worldData = WorldConfig.GetWorld(worldId)
	if not worldData or not worldData.layers then
		return nil
	end

	local layers = worldData.layers
	local currentY = rootPart.Position.Y

	for i = 1, #layers do
		local layer = layers[i]
		if currentY <= layer.maxHeight and currentY > layer.minHeight then
			return layer
		end
	end

	return layers[1]
end

local function validate_world_legitimacy(player: Player): boolean
	local currentWorldId = DataUtility.server.get(player, "CurrentWorld") or 1
	if currentWorldId == 1 then
		return true
	end

	local worldData = WorldConfig.GetWorld(currentWorldId)
	if not worldData then
		DataUtility.server.set(player, "CurrentWorld", 1)
		return false
	end

	local playerPower = DataUtility.server.get(player, "PogoSettings.base_jump_power") or 0
	local playerRebirths = DataUtility.server.get(player, "Rebirths") or 0

	local requiredPower = worldData.requiredPogoPower or 0
	local requiredRebirths = worldData.requiredRebirths or 0

	local powerOk = playerPower >= requiredPower
	local rebirthsOk = playerRebirths >= requiredRebirths

	if powerOk and rebirthsOk then
		return true
	end

	DataUtility.server.set(player, "CurrentWorld", 1)

	local worldOne = WorldConfig.GetWorld(1)
	if worldOne then
		if worldOne.gravityMult ~= nil then
			DataUtility.server.set(player, "PogoSettings.gravity_mult", worldOne.gravityMult)
		end

		local character = player.Character
		if character and worldOne.entryCFrame then
			character:PivotTo(worldOne.entryCFrame)

			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end

	return false
end

local function recalculate_player_stats(player: Player): ()
	local equippedId = DataUtility.server.get(player, "EquippedPogoId") or "Rustbucket"
	local rebirths = DataUtility.server.get(player, "Rebirths") or 0
	local ownedUpgrades = DataUtility.server.get(player, "OwnedRebirthUpgrades") or {}

	local pogoStats = PogoData.Get(equippedId)
	if not pogoStats then
		return
	end

	local basePower = pogoStats.Power or 0
	local rebirthMult = 1 + (rebirths * SETTINGS.RebirthPowerScale)

	local globalMult = player:GetAttribute("Multiplier") or 1.0
	if type(globalMult) ~= "number" then
		globalMult = 1.0
	end
	globalMult = math.max(1.0, globalMult)

	local springsBonus = table.find(ownedUpgrades, "ReinforcedSprings") and 1.10 or 1.0
	local finalPower = math.floor(basePower * rebirthMult * globalMult * springsBonus)

	DataUtility.server.set(player, "PogoSettings.base_jump_power", finalPower)
end

local function award_coins(player: Player, combo: number, isCritical: boolean, floorMult: number, impactForce: number): ()
	local rebirths = DataUtility.server.get(player, "Rebirths") or 0
	local ownedUpgrades = DataUtility.server.get(player, "OwnedRebirthUpgrades") or {}

	local equippedId = DataUtility.server.get(player, "EquippedPogoId") or "Rustbucket"
	local pogoStats = PogoData.Get(equippedId)
	local pogoCoinMult = (pogoStats and pogoStats.CoinMultiplier) or 1.0

	local rebirthMult = 1 + (rebirths * SETTINGS.RebirthPowerScale)

	local mult = player:GetAttribute("Multiplier") or 1.0
	if type(mult) ~= "number" then
		mult = 1.0
	end
	mult = math.max(1.0, mult)

	local critMultiplier = isCritical and 2 or 1
	local floorMultiplier = floorMult or 1

	local magnetMult = table.find(ownedUpgrades, "CoinMagnet") and 1.25 or 1.0
	local baseCalc = SETTINGS.BaseCoinReward * critMultiplier

	local reward = baseCalc * rebirthMult * mult * floorMultiplier * magnetMult * pogoCoinMult
	local finalReward = math.floor(reward)

	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	DataUtility.server.set(player, "Coins", currentCoins + finalReward)

	if AnalyticsService then
		local worldId = DataUtility.server.get(player, "CurrentWorld") or 1
		AnalyticsService.coins_earned(player, finalReward, "pogo_reward", {
			worldId = worldId,
			combo = combo,
			isCritical = isCritical,
			floorMult = floorMultiplier,
			impactForce = impactForce,
			equippedPogoId = equippedId,
		})
	end
end

local function handle_jump(player: Player, payload: any): ()
	if not validate_world_legitimacy(player) then
		return
	end

	local state = get_state(player)
	state.serverCombo = 0

	local totalJumps = DataUtility.server.get(player, "Stats.TotalJumps") or 0
	DataUtility.server.set(player, "Stats.TotalJumps", totalJumps + 1)

	local character = player.Character
	local floorMultiplier = 1
	local impactForce = (payload and payload.impactForce) or 0

	if character then
		local layerInfo = get_layer_by_height(player, character)
		if layerInfo then
			if impactForce >= (layerInfo.minBreakForce or 40) then
				floorMultiplier = layerInfo.coinMultiplier or 1
			else
				floorMultiplier = 0
			end
		end
	end

	if floorMultiplier > 0 then
		award_coins(player, 0, false, floorMultiplier, impactForce)
	end

	if AnalyticsService then
		local worldId = DataUtility.server.get(player, "CurrentWorld") or 1
		AnalyticsService.pogo_jump(player, worldId, floorMultiplier, impactForce)
	end

	update_attributes(player, "Jumping", 0)
end

local function handle_rebound(player: Player, _clientCombo: number, isCritical: boolean, payload: any): ()
	if not validate_world_legitimacy(player) then
		return
	end

	local state = get_state(player)
	local now = os.clock()

	local character = player.Character
	if not character then
		return
	end

	if (now - state.lastActionTime) < SETTINGS.MinTimeBetweenRebounds then
		return
	end

	local layerInfo = get_layer_by_height(player, character)
	if not layerInfo then
		state.serverCombo = 0
		update_attributes(player, "Reset", 0)
		return
	end

	state.serverCombo += 1
	local finalCombo = state.serverCombo

	local totalLandings = DataUtility.server.get(player, "Stats.TotalLandings") or 0
	DataUtility.server.set(player, "Stats.TotalLandings", totalLandings + 1)

	if isCritical then
		local perfectLandings = DataUtility.server.get(player, "Stats.PerfectLandings") or 0
		DataUtility.server.set(player, "Stats.PerfectLandings", perfectLandings + 1)
	end

	local highestCombo = DataUtility.server.get(player, "Stats.HighestCombo") or 0
	if finalCombo > highestCombo then
		DataUtility.server.set(player, "Stats.HighestCombo", finalCombo)
	end

	local impactForce = (payload and payload.impactForce) or 0
	local floorMultiplier = layerInfo.coinMultiplier or 1
	if impactForce < (layerInfo.minBreakForce or 40) then
		floorMultiplier = 0
	end

	if floorMultiplier > 0 then
		award_coins(player, finalCombo, isCritical, floorMultiplier, impactForce)
	end

	if AnalyticsService then
		local worldId = DataUtility.server.get(player, "CurrentWorld") or 1
		AnalyticsService.pogo_rebound(player, worldId, finalCombo, isCritical, floorMultiplier, impactForce)
	end

	update_attributes(player, "Rebounding", finalCombo)
	state.lastActionTime = now
end

local function handle_land(player: Player, status: string?): ()
	local state = get_state(player)
	state.serverCombo = 0

	local finalStatus = status or "Cooldown"

	if AnalyticsService then
		local worldId = DataUtility.server.get(player, "CurrentWorld") or 1
		AnalyticsService.pogo_land(player, worldId, finalStatus)
	end

	update_attributes(player, finalStatus, 0)
end

------------------//INIT
DataUtility.server.ensure_remotes()

pogoEvent.OnServerEvent:Connect(function(player: Player, action: string, payload: any)
	if action == "Jump" then
		handle_jump(player, payload)
		return
	end

	if action == "Rebound" then
		local combo = (payload and payload.combo) or 1
		local isCritical = (payload and payload.isCritical) == true
		handle_rebound(player, combo, isCritical, payload)
		return
	end

	if action == "Land" then
		local status = payload and payload.status
		handle_land(player, status)
		return
	end

	if action == "Stunned" then
		local state = get_state(player)
		state.serverCombo = 0
		update_attributes(player, "Stunned", 0)
		return
	end
end)

for _, player in Players:GetPlayers() do
	get_state(player)
	update_attributes(player, "Idle", 0)
	recalculate_player_stats(player)
end

Players.PlayerAdded:Connect(function(player: Player)
	get_state(player)
	update_attributes(player, "Idle", 0)
	recalculate_player_stats(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerStates[player.UserId] = nil
end)