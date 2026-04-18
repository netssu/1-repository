------------------//SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

------------------//VARIABLES
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local PlayerDataGuard = require(ReplicatedStorage.Modules.Game.PlayerDataGuard)
local CosmeticsData = require(ReplicatedStorage.Modules.Data.CosmeticsData)
local EmotesData = require(ReplicatedStorage.Modules.Data.EmotesData)
local PlayerCardsData = require(ReplicatedStorage.Modules.Data.PlayerCardsData)

local InventoryService = {}
InventoryService.__index = InventoryService
local _equipDebounce = {}
local COSMETIC_ATTRIBUTE_NAME = "IsCosmetic"

local TYPE_KEYS = {
	Cosmetic = { owned = "OwnedCosmetics", count = "OwnedCosmeticsCount", data = function() return CosmeticsData.Items end },
	Emote    = { owned = "OwnedEmotes",    count = "OwnedEmotesCount",    data = function() return EmotesData.Emotes end },
	Card     = { owned = "OwnedCards",     count = "OwnedCardsCount",     data = function() return PlayerCardsData.Cards end },
}

------------------//FUNCTIONS

local function playerOwnsItem(player, ownedKey, itemName)
	local ownedItems, hasData = PlayerDataGuard.GetOrDefault(player, { ownedKey }, nil)
	if not hasData or type(ownedItems) ~= "table" then return false end
	for _, owned in ipairs(ownedItems) do
		if owned == itemName then return true end
	end
	return false
end

local function getItemCount(player, countKey, itemName): number
	local countTable, hasData = PlayerDataGuard.GetOrDefault(player, { countKey }, {})
	if not hasData or type(countTable) ~= "table" then return 0 end
	return countTable[itemName] or 0
end

local function setItemCount(player, countKey, itemName, count: number)
	local countTable, hasData = PlayerDataGuard.GetOrDefault(player, { countKey }, {})
	if not hasData or type(countTable) ~= "table" then
		countTable = {}
	end
	local newTable = table.clone(countTable)
	newTable[itemName] = count
	PlayerDataManager:Set(player, { countKey }, newTable)
end

local function validateInventoryItem(itemType, itemName)
	local keys = TYPE_KEYS[itemType]
	if not keys then
		warn(`[InventoryService] Invalid item type: {itemType}`)
		return nil
	end

	local dataModule = keys.data()
	if not dataModule[itemName] then
		warn(`[InventoryService] Item not found in data: {itemName}`)
		return nil
	end

	return keys
end

local function grantValidatedItem(player, itemType, itemName, keys)
	PlayerDataManager:Insert(player, { keys.owned }, itemName)
	print(`[InventoryService] {player.Name} received {itemType}: {itemName}`)
end

local function sanitizeData(player, key)
	local currentItems, hasData = PlayerDataGuard.GetOrDefault(player, { key }, nil)
	if not hasData or type(currentItems) ~= "table" or #currentItems == 0 then return end

	local uniqueItems = {}
	local seen = {}
	local hasDuplicates = false

	for _, item in ipairs(currentItems) do
		if not seen[item] then
			seen[item] = true
			table.insert(uniqueItems, item)
		else
			hasDuplicates = true
		end
	end

	if hasDuplicates then
		PlayerDataManager:Set(player, { key }, uniqueItems)
		print(`[InventoryService] Cleaned duplicates for {player.Name} in {key}`)
	end
end

local function migrateOldCosmeticData(player)
	local oldCosmetic, hasLegacyData = PlayerDataGuard.GetOrDefault(player, { "EquippedCosmetic" }, nil)
	if hasLegacyData and type(oldCosmetic) == "string" and oldCosmetic ~= "" then
		print(`[InventoryService] Migrating legacy data for {player.Name}: {oldCosmetic}`)
		local newCosmetics, hasCosmeticsData = PlayerDataGuard.GetOrDefault(player, { "EquippedCosmetics" }, {})
		if not hasCosmeticsData or type(newCosmetics) ~= "table" then return end
		if #newCosmetics == 0 then
			table.insert(newCosmetics, oldCosmetic)
			PlayerDataManager:Set(player, { "EquippedCosmetics" }, newCosmetics)
			print(`[InventoryService] Data migrated successfully for {player.Name}`)
		end
	end
end

local function playCosmeticAnimation(cosmeticModel, animationId)
	if not animationId then return end

	local animator = nil
	local animationController = cosmeticModel:FindFirstChild("AnimationController")
	if animationController then
		animator = animationController:FindFirstChild("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = animationController
		end
	else
		local character = cosmeticModel.Parent
		local humanoid = character and character:FindFirstChild("Humanoid")
		if humanoid then
			animator = humanoid:FindFirstChild("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = humanoid
			end
		end
	end

	if not animator then
		warn("[InventoryService] Could not find an Animator for:", cosmeticModel.Name)
		return
	end

	local animationObj = Instance.new("Animation")
	animationObj.AnimationId = animationId
	animationObj.Name = "CosmeticAnim_" .. cosmeticModel.Name
	animationObj.Parent = cosmeticModel

	local success, track = pcall(function()
		return animator:LoadAnimation(animationObj)
	end)

	if success and track then
		track.Looped = true
		track:Play()
	else
		warn("[InventoryService] Error loading animation:", animationId)
	end
end

local function markCosmeticInstance(cosmeticInstance)
	if not cosmeticInstance then return end
	cosmeticInstance:SetAttribute(COSMETIC_ATTRIBUTE_NAME, true)
end

local function attachCosmeticWithMotors(character, cosmeticModel)
	local itemData = CosmeticsData.Items[cosmeticModel.Name]
	local motorOffsets = itemData and itemData.MotorOffsets or {}

	for _, descendant in ipairs(cosmeticModel:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local bodyPart = character:FindFirstChild(descendant.Name)
			if bodyPart then
				descendant.Part0 = bodyPart
				if motorOffsets[descendant.Name] then
					descendant.C0 = motorOffsets[descendant.Name]
				end
			else
				warn("[InventoryService] Body part not found for motor:", descendant.Name)
			end
		end
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Massless = true
			descendant.Anchored = false
		end
	end
	cosmeticModel.Parent = character
end

local function removeVisualCosmetic(character, cosmeticName)
	if not character then return end
	for _, child in ipairs(character:GetChildren()) do
		if child.Name == cosmeticName and child:GetAttribute(COSMETIC_ATTRIBUTE_NAME) == true then
			child:Destroy()
		end
	end
end

local function addVisualCosmetic(player, cosmeticName)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local itemData = CosmeticsData.Items[cosmeticName]
	if not itemData or not itemData.Model then return end

	local newCosmetic = itemData.Model:Clone()
	newCosmetic.Name = cosmeticName
	markCosmeticInstance(newCosmetic)

	if newCosmetic:IsA("Accessory") then
		humanoid:AddAccessory(newCosmetic)
	elseif newCosmetic:IsA("Model") then
		attachCosmeticWithMotors(character, newCosmetic)
	end

	if itemData.AnimationId then
		task.delay(0.1, function()
			if newCosmetic and newCosmetic.Parent then
				playCosmeticAnimation(newCosmetic, itemData.AnimationId)
			end
		end)
	end
end

function InventoryService:_equipCosmetic(player, cosmeticName)
	local lastTime = _equipDebounce[player.UserId] or 0
	local now = os.clock()
	if (now - lastTime) < 0.3 then return end
	_equipDebounce[player.UserId] = now

	if cosmeticName == "" then return end
	if not playerOwnsItem(player, "OwnedCosmetics", cosmeticName) then return end

	local currentEquipped, hasEquippedData = PlayerDataGuard.GetOrDefault(player, { "EquippedCosmetics" }, {})
	if not hasEquippedData or type(currentEquipped) ~= "table" then return end
	local newEquippedList = table.clone(currentEquipped)

	local foundIndex = table.find(newEquippedList, cosmeticName)
	if foundIndex then
		table.remove(newEquippedList, foundIndex)
		removeVisualCosmetic(player.Character, cosmeticName)
		print(`[Inventory] Unequipped: {cosmeticName}`)
	else
		local itemData = CosmeticsData.Items[cosmeticName]
		if not itemData then return end

		if itemData.BodyPart then
			for i = #newEquippedList, 1, -1 do
				local existingName = newEquippedList[i]
				local existingData = CosmeticsData.Items[existingName]
				if existingData and existingData.BodyPart == itemData.BodyPart then
					removeVisualCosmetic(player.Character, existingName)
					table.remove(newEquippedList, i)
				end
			end
		end

		table.insert(newEquippedList, cosmeticName)
		addVisualCosmetic(player, cosmeticName)
		print(`[Inventory] Equipped: {cosmeticName}`)
	end

	PlayerDataManager:Set(player, { "EquippedCosmetics" }, newEquippedList)
end

function InventoryService:_equipEmote(player, emoteName)
	if emoteName == "" then return end
	if not playerOwnsItem(player, "OwnedEmotes", emoteName) then return end

	local currentEquipped, hasData = PlayerDataGuard.GetOrDefault(player, { "EquippedEmotes" }, {})
	if not hasData or type(currentEquipped) ~= "table" then
		currentEquipped = {}
	end

	local newEquippedList = table.clone(currentEquipped)
	local foundIndex = table.find(newEquippedList, emoteName)

	if foundIndex then
		table.remove(newEquippedList, foundIndex)
	else
		if #newEquippedList < 8 then
			table.insert(newEquippedList, emoteName)
		else
			return
		end
	end

	PlayerDataManager:Set(player, { "EquippedEmotes" }, newEquippedList)
end

function InventoryService:_equipCard(player, cardName)
	if cardName ~= "" and not playerOwnsItem(player, "OwnedCards", cardName) then return end
	local current, hasData = PlayerDataGuard.GetOrDefault(player, { "EquippedCard" }, "")
	if not hasData then return end
	PlayerDataManager:Set(player, { "EquippedCard" }, current == cardName and "" or cardName)
end

function InventoryService:GiveItem(player, itemType, itemName)
	local keys = validateInventoryItem(itemType, itemName)
	if not keys then
		return false
	end

	if playerOwnsItem(player, keys.owned, itemName) then
		return false
	end

	grantValidatedItem(player, itemType, itemName, keys)
	return true
end

function InventoryService:GiveItems(player, items)
	if type(items) ~= "table" or #items == 0 then
		warn("[InventoryService] Invalid item pack")
		return false
	end

	local validatedItems = {}
	for _, item in ipairs(items) do
		if type(item) ~= "table" or type(item.ItemType) ~= "string" or type(item.ItemName) ~= "string" then
			warn("[InventoryService] Invalid item in pack")
			return false
		end

		local keys = validateInventoryItem(item.ItemType, item.ItemName)
		if not keys then
			return false
		end

		table.insert(validatedItems, {
			ItemType = item.ItemType,
			ItemName = item.ItemName,
			Keys = keys,
		})
	end

	for _, item in ipairs(validatedItems) do
		grantValidatedItem(player, item.ItemType, item.ItemName, item.Keys)
	end

	return true
end

function InventoryService:GetItemCount(player, itemType, itemName): number
	local keys = TYPE_KEYS[itemType]
	if not keys then return 0 end
	return getItemCount(player, keys.count, itemName)
end

function InventoryService:RemoveItem(player, itemType, itemName)
	local keys = TYPE_KEYS[itemType]
	if not keys then
		warn(`[InventoryService] Invalid item type: {itemType}`)
		return false
	end

	local ownedItems, hasData = PlayerDataGuard.GetOrDefault(player, { keys.owned }, nil)
	if not hasData or type(ownedItems) ~= "table" then return false end

	local itemIndex = table.find(ownedItems, itemName)
	if not itemIndex then
		warn(`[InventoryService] {player.Name} does not own: {itemName}`)
		return false
	end

	PlayerDataManager:Remove(player, { keys.owned }, itemIndex)
	setItemCount(player, keys.count, itemName, 0)
	print(`[InventoryService] Removed from {player.Name}: {itemName}`)
	return true
end

------------------//INIT

function InventoryService:Start()
	Packets.RequestEquipCosmetic.OnServerEvent:Connect(function(player, cosmeticName)
		self:_equipCosmetic(player, cosmeticName)
	end)
	Packets.RequestEquipEmote.OnServerEvent:Connect(function(player, emoteName)
		self:_equipEmote(player, emoteName)
	end)
	Packets.RequestEquipCard.OnServerEvent:Connect(function(player, cardName)
		self:_equipCard(player, cardName)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			pcall(function()
				migrateOldCosmeticData(player)
				sanitizeData(player, "EquippedCosmetics")
			end)
		end)

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not humanoid then return end

			task.delay(1, function()
				if not player.Parent then return end

				local savedCosmetics, hasData = PlayerDataGuard.GetOrDefault(player, { "EquippedCosmetics" }, {})
				if not hasData or type(savedCosmetics) ~= "table" then return end

				for _, cosmeticName in ipairs(savedCosmetics) do
					if playerOwnsItem(player, "OwnedCosmetics", cosmeticName) and CosmeticsData.Items[cosmeticName] then
						local itemData = CosmeticsData.Items[cosmeticName]
						if itemData.Model then
							local newCosmetic = itemData.Model:Clone()
							newCosmetic.Name = cosmeticName
							markCosmeticInstance(newCosmetic)

							if newCosmetic:IsA("Accessory") then
								humanoid:AddAccessory(newCosmetic)
							elseif newCosmetic:IsA("Model") then
								attachCosmeticWithMotors(character, newCosmetic)
							end

							if itemData.AnimationId then
								task.delay(0.1, function()
									if newCosmetic and newCosmetic.Parent then
										playCosmeticAnimation(newCosmetic, itemData.AnimationId)
									end
								end)
							end
						end
					end
				end
			end)
		end)
	end)

	print("[InventoryService] Started")
end

function InventoryService:Init() end

return InventoryService
