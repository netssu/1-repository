------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//CONSTANTS
local PRESERVED_POGOS = {
	["PoisonVine"] = true,
	["NeonArc"] = true,
	["GuidingStar"] = true,
}

local PRESERVED_PETS = {
	["Golden Unicorn"] = true,
	["Unicorn"] = true,
	["Cupcake"] = true,
	["Pony"] = true,
	["Cotton Candy Cow"] = true,
}

------------------//VARIABLES
local DataUtility = require(ReplicatedStorage.Modules.Utility.DataUtility)
local RebirthConfig = require(ReplicatedStorage.Modules.Datas.RebirthConfig)

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local rebirthEvent = remotesFolder:FindFirstChild("RebirthAction")
if not rebirthEvent then
	rebirthEvent = Instance.new("RemoteEvent")
	rebirthEvent.Name = "RebirthAction"
	rebirthEvent.Parent = remotesFolder
end

------------------//FUNCTIONS
local function filter_preserved(ownedTable, preservedList)
	local kept = {}
	if type(ownedTable) ~= "table" then return kept end
	for id, val in pairs(ownedTable) do
		if preservedList[id] then
			kept[id] = val
		end
	end
	return kept
end

local function handle_rebirth(player: Player)
	local currentRebirths = DataUtility.server.get(player, "Rebirths") or 0
	local currentCoins = DataUtility.server.get(player, "Coins") or 0
	local currentPower = DataUtility.server.get(player, "PogoSettings.base_jump_power") or 0
	local coinsReq, powerReq = RebirthConfig.GetRequirement(currentRebirths)

	if currentCoins >= coinsReq and currentPower >= powerReq then
		local newRebirthCount = currentRebirths + 1
		local currentTokens = DataUtility.server.get(player, "RebirthTokens") or 0

		local ownedPogos = DataUtility.server.get(player, "OwnedPogos") or {}
		local ownedPets = DataUtility.server.get(player, "OwnedPets") or {}

		local keptPogos = filter_preserved(ownedPogos, PRESERVED_POGOS)
		keptPogos["Rustbucket"] = true

		local keptPets = filter_preserved(ownedPets, PRESERVED_PETS)

		local equippedPogoId = DataUtility.server.get(player, "EquippedPogoId") or ""
		if not keptPogos[equippedPogoId] then
			equippedPogoId = "Rustbucket"
		end

		local equippedPets = DataUtility.server.get(player, "EquippedPets") or {}
		local keptEquippedPets = {}
		if type(equippedPets) == "table" then
			for slot, petId in pairs(equippedPets) do
				if keptPets[petId] then
					keptEquippedPets[slot] = petId
				end
			end
		end

		local newMultiplier = 1.0 + (newRebirthCount * 0.5)

		DataUtility.server.set(player, "Coins", 0)
		DataUtility.server.set(player, "PogoSettings.base_jump_power", RebirthConfig.POWER_RESET_VALUE)
		DataUtility.server.set(player, "OwnedPogos", keptPogos)
		DataUtility.server.set(player, "EquippedPogoId", equippedPogoId)
		DataUtility.server.set(player, "BestPogos", {})
		DataUtility.server.set(player, "OwnedPets", keptPets)
		DataUtility.server.set(player, "EquippedPets", keptEquippedPets)
		DataUtility.server.set(player, "BestPets", {})

		DataUtility.server.set(player, "Rebirths", newRebirthCount)
		DataUtility.server.set(player, "RebirthTokens", currentTokens + RebirthConfig.TOKENS_PER_REBIRTH)

		DataUtility.server.set(player, "RebirthMultiplier", newMultiplier)

		return true
	end

	return false
end

------------------//INIT
rebirthEvent.OnServerEvent:Connect(handle_rebirth)