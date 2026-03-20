------------------//SERVICES
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local REMOTE_FOLDER_NAME = "Remotes"
local EQUIP_REMOTE_NAME = "ActionRemote"
local MAX_BEST_SLOTS = 5
local MAX_PETS_DEFAULT = 1
local MAX_PETS_WITH_PASS = 3

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("DataUtility"))
local PogoData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PogoData"))
local DataPets = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PetsData"))
local PotionsData = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Datas"):WaitForChild("PotionsData"))

local equipRemote: RemoteEvent

------------------//FUNCTIONS
local function setup_remotes(): ()
	local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
	local remotesFolder = assetsFolder:FindFirstChild(REMOTE_FOLDER_NAME)

	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = REMOTE_FOLDER_NAME
		remotesFolder.Parent = assetsFolder
	end

	equipRemote = remotesFolder:FindFirstChild(EQUIP_REMOTE_NAME)
	if not equipRemote then
		equipRemote = Instance.new("RemoteEvent")
		equipRemote.Name = EQUIP_REMOTE_NAME
		equipRemote.Parent = remotesFolder
	end
end

local function count_dictionary(dict)
	local count = 0
	if type(dict) == "table" then
		for _ in pairs(dict) do count += 1 end
	end
	return count
end

local function get_first_free_slot(dict)
	for i = 1, MAX_BEST_SLOTS do
		if not dict[tostring(i)] then
			return tostring(i)
		end
	end
	return nil
end

local function handle_select_pogo(player: Player, pogoId: string)
	local ownedPogos = DataUtility.server.get(player, "OwnedPogos") or {}
	if not ownedPogos[pogoId] then
		warn(player.Name .. " tentou equipar pogo nao possuido: " .. tostring(pogoId))
		return
	end
	DataUtility.server.set(player, "EquippedPogoId", pogoId)
end

local function handle_select_pet(player: Player, petId: string)
	local ownedPets = DataUtility.server.get(player, "OwnedPets") or {}
	if not ownedPets[petId] then
		warn(player.Name .. " tentou equipar pet nao possuido: " .. tostring(petId))
		return
	end

	local equippedPets = DataUtility.server.get(player, "EquippedPets")
	if type(equippedPets) ~= "table" then
		equippedPets = {}
	end

	for slot, id in pairs(equippedPets) do
		if id == petId then
			equippedPets[slot] = nil
			DataUtility.server.set(player, "EquippedPets", equippedPets)
			return
		end
	end

	local gamepasses = DataUtility.server.get(player, "Gamepasses") or {}
	local hasExtraSlots = gamepasses.ExtraPetSlots == true
	local maxSlots = hasExtraSlots and MAX_PETS_WITH_PASS or MAX_PETS_DEFAULT

	local currentCount = count_dictionary(equippedPets)

	if currentCount >= maxSlots then
		local lowestSlot = nil
		for i = 1, maxSlots do
			if equippedPets[tostring(i)] then
				lowestSlot = tostring(i)
				break
			end
		end
		if lowestSlot then
			equippedPets[lowestSlot] = petId
		end
	else
		for i = 1, maxSlots do
			if not equippedPets[tostring(i)] then
				equippedPets[tostring(i)] = petId
				break
			end
		end
	end

	DataUtility.server.set(player, "EquippedPets", equippedPets)
end

local function handle_best_action(player: Player, categoryKey: string, ownedKey: string, action: string, payload: any)
	local ownedItems = DataUtility.server.get(player, ownedKey) or {}
	local bestItems = DataUtility.server.get(player, categoryKey) or {}
	local changed = false

	if action == "Add" then
		local itemId = payload
		if ownedItems[itemId] and count_dictionary(bestItems) < MAX_BEST_SLOTS then
			local slot = get_first_free_slot(bestItems)
			if slot then
				bestItems[slot] = itemId
				changed = true
			end
		end
	elseif action == "Remove" then
		local itemId = payload
		for slot, id in pairs(bestItems) do
			if id == itemId then
				bestItems[slot] = nil
				changed = true
				break
			end
		end
	elseif action == "Replace" then
		local oldId = payload.Old
		local newId = payload.New
		if ownedItems[newId] then
			for slot, id in pairs(bestItems) do
				if id == oldId then
					bestItems[slot] = newId
					changed = true
					break
				end
			end
		end
	elseif action == "Select" then
		if categoryKey == "BestPogos" then
			handle_select_pogo(player, payload)
		elseif categoryKey == "BestPets" then
			handle_select_pet(player, payload)
		end
	end

	if changed then
		DataUtility.server.set(player, categoryKey, bestItems)
	end
end

local function handle_use_potion(player: Player, potionId: string)
	local potionInfo = PotionsData.Get(potionId)
	if not potionInfo then
		warn(player.Name .. " tentou usar pocao invalida: " .. tostring(potionId))
		return
	end

	local potions = DataUtility.server.get(player, "Potions") or {}
	local currentAmount = potions[potionId] or 0

	if currentAmount <= 0 then
		warn(player.Name .. " tentou usar " .. potionId .. " mas nao possui nenhuma.")
		return
	end

	potions[potionId] = currentAmount - 1
	if potions[potionId] <= 0 then
		potions[potionId] = nil
	end
	DataUtility.server.set(player, "Potions", potions)

	local boostManager = _G.BoostManager
	if boostManager and boostManager.activateBoost then
		boostManager.activateBoost(player, potionInfo.BoostName, potionInfo.Duration)
	else
		warn("BoostManager nao encontrado em _G!")
	end
end

local function handle_buy_pogo(player: Player, pogoId: string)
	local pogoInfo = PogoData.Get(pogoId)
	if not pogoInfo then return end

	local ownedPogos = DataUtility.server.get(player, "OwnedPogos") or {}
	if ownedPogos[pogoId] then return end

	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	local currentRebirths = DataUtility.server.get(player, "RebirthTokens") or 0

	if currentCoins >= pogoInfo.Price and currentRebirths >= pogoInfo.RequiredRebirths then
		DataUtility.server.set(player, "Coins", currentCoins - pogoInfo.Price)
		ownedPogos[pogoId] = true
		DataUtility.server.set(player, "OwnedPogos", ownedPogos)

		DataUtility.server.set(player, "EquippedPogoId", pogoId)
	else
		warn(player.Name .. " tentou comprar o Pogo " .. pogoId .. " mas nao tinha os requisitos!")
	end
end

local function on_equip_request(player: Player, category: string, action: string, payload: any)
	if type(category) ~= "string" or type(action) ~= "string" then return end

	if category == "Pogos" then
		if action == "Buy" then
			handle_buy_pogo(player, payload)
		else
			handle_best_action(player, "BestPogos", "OwnedPogos", action, payload)
		end
	elseif category == "Pets" then
		handle_best_action(player, "BestPets", "OwnedPets", action, payload)
	elseif category == "Potions" then
		if action == "Use" then
			handle_use_potion(player, payload)
		end
	end
end

local function sanitize_player_data(player: Player)
	for _, categoryKey in ipairs({"BestPets", "BestPogos"}) do
		local bestItems = DataUtility.server.get(player, categoryKey) or {}
		local changed = false

		for slot, _ in pairs(bestItems) do
			if tonumber(slot) and tonumber(slot) > MAX_BEST_SLOTS then
				bestItems[slot] = nil
				changed = true
			end
		end

		if changed then
			DataUtility.server.set(player, categoryKey, bestItems)
		end
	end

	local equippedPets = DataUtility.server.get(player, "EquippedPets")
	if type(equippedPets) ~= "table" then
		DataUtility.server.set(player, "EquippedPets", {})
	end
end

------------------//INIT
setup_remotes()
equipRemote.OnServerEvent:Connect(on_equip_request)

Players.PlayerAdded:Connect(function(player)
	task.wait(2)
	sanitize_player_data(player)
end)

return {}