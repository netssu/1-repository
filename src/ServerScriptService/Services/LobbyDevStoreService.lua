local LobbyDevStoreService = {}

-- SERVICES
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

-- CONSTANTS
local LOBBY_NAME = "Lobby"
local DEV_FOLDER_NAME = "Dev"
local EMOTE_TAG = "EMOTE"
local ANIME_TAG = "ANIME"
local TOXIC_TAG = "TOXIC"
local TIKTOK_TAG = "TIKTOK"
local PLAYER_CARD_TAG = "PLAYER CARD"
local ROBUX_ICON = utf8.char(0xE002)
local THIN_SPACE = utf8.char(0x200A)
local ROBUX_PREFIX = ROBUX_ICON .. THIN_SPACE

local JOJO_POSE_ANIMATION_ID = "rbxassetid://94255944463199"
local TAKE_THE_L_ANIMATION_ID = "rbxassetid://92621326488754"
local SHUFFLE_ANIMATION_ID = "rbxassetid://91319337370874"

local ANIME_PACK_ITEM = {
	ProductId = 3571623754,
	DisplayName = "Anime Emotes",
	AnimationId = JOJO_POSE_ANIMATION_ID,
}

local TOXIC_PACK_ITEM = {
	ProductId = 3571623981,
	DisplayName = "Toxic Emotes",
	AnimationId = TAKE_THE_L_ANIMATION_ID,
}

local TIKTOK_PACK_ITEM = {
	ProductId = 3571624100,
	DisplayName = "TikTok Emotes",
	AnimationId = SHUFFLE_ANIMATION_ID,
}

local STORE_ITEMS = {
	[ANIME_TAG] = {
		[ANIME_TAG] = ANIME_PACK_ITEM,
		DEFAULT = ANIME_PACK_ITEM,
	},
	[TOXIC_TAG] = {
		[TOXIC_TAG] = TOXIC_PACK_ITEM,
		DEFAULT = TOXIC_PACK_ITEM,
	},
	[TIKTOK_TAG] = {
		[TIKTOK_TAG] = TIKTOK_PACK_ITEM,
		["TIK TOK"] = TIKTOK_PACK_ITEM,
		DEFAULT = TIKTOK_PACK_ITEM,
	},
	[EMOTE_TAG] = {
		[ANIME_TAG] = ANIME_PACK_ITEM,
		["ANIME EMOTES"] = ANIME_PACK_ITEM,
		["JOJO POSE"] = {
			ProductId = 3571623754,
			DisplayName = "Anime Emotes",
			AnimationId = JOJO_POSE_ANIMATION_ID,
		},
		["JOJOPOSE"] = {
			ProductId = 3571623754,
			DisplayName = "Anime Emotes",
			AnimationId = JOJO_POSE_ANIMATION_ID,
		},
		[TOXIC_TAG] = TOXIC_PACK_ITEM,
		["TOXIC EMOTES"] = TOXIC_PACK_ITEM,
		["TAKE THE L"] = {
			ProductId = 3571623981,
			DisplayName = "Toxic Emotes",
			AnimationId = TAKE_THE_L_ANIMATION_ID,
		},
		[TIKTOK_TAG] = TIKTOK_PACK_ITEM,
		["TIK TOK"] = TIKTOK_PACK_ITEM,
		["TIKTOK EMOTES"] = TIKTOK_PACK_ITEM,
		["SHUFFLE"] = {
			ProductId = 3571624100,
			DisplayName = "TikTok Emotes",
			AnimationId = SHUFFLE_ANIMATION_ID,
		},
	},
	[PLAYER_CARD_TAG] = {
		["VIP"] = {
			ProductId = 3571625715,
			ItemName = "VIP",
		},
		["VIP CARD"] = {
			ProductId = 3571625715,
			ItemName = "VIP",
		},
		["DIAMOND"] = {
			ProductId = 3571625783,
			ItemName = "DIAMOND",
		},
		["DIAMOND CARD"] = {
			ProductId = 3571625783,
			ItemName = "DIAMOND",
		},
	},
}

local TAG_ALIASES = {
	[EMOTE_TAG] = EMOTE_TAG,
	[ANIME_TAG] = ANIME_TAG,
	[TOXIC_TAG] = TOXIC_TAG,
	[TIKTOK_TAG] = TIKTOK_TAG,
	TIK_TOK = TIKTOK_TAG,
	["TIK TOK"] = TIKTOK_TAG,
	[PLAYER_CARD_TAG] = PLAYER_CARD_TAG,
	PLAYER_CARD = PLAYER_CARD_TAG,
	PLAYERCARD = PLAYER_CARD_TAG,
}

local TAG_SIGNALS = {
	EMOTE_TAG,
	ANIME_TAG,
	TOXIC_TAG,
	TIKTOK_TAG,
	"TIK_TOK",
	"TIK TOK",
	PLAYER_CARD_TAG,
	"PLAYER_CARD",
	"PLAYERCARD",
}

local ActiveLobby = nil
local ActiveDevFolder = nil
local Started = false
local LobbyConnections = {}
local DevConnections = {}
local ConnectedPrompts = setmetatable({}, { __mode = "k" })
local ActiveEmoteTracks = setmetatable({}, { __mode = "k" })
local ProductPriceTextCache = {}
local PromptDebounce = {}

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function normalizeKey(value)
	local normalized = string.upper(tostring(value or ""))
	normalized = string.gsub(normalized, "[_%-%s]+", " ")
	normalized = string.gsub(normalized, "^%s+", "")
	normalized = string.gsub(normalized, "%s+$", "")
	return normalized
end

local function compactKey(value)
	return string.gsub(normalizeKey(value), "%s+", "")
end

local function stripPackSuffix(value)
	local strippedValue = string.gsub(tostring(value or ""), "%s+[Pp][Aa][Cc][Kk]$", "")
	return strippedValue
end

local function readNumberAttribute(instance, attributeNames)
	for _, attributeName in ipairs(attributeNames) do
		local value = instance:GetAttribute(attributeName)
		if type(value) == "number" then
			return value
		end

		if type(value) == "string" then
			local numericValue = tonumber(value)
			if numericValue then
				return numericValue
			end
		end
	end

	return nil
end

local function readStringAttribute(instance, attributeNames)
	for _, attributeName in ipairs(attributeNames) do
		local value = instance:GetAttribute(attributeName)
		if type(value) == "string" and value ~= "" then
			return value
		end
	end

	return nil
end

local function normalizeAnimationId(value)
	if type(value) == "number" then
		return "rbxassetid://" .. tostring(value)
	end

	if type(value) ~= "string" or value == "" then
		return nil
	end

	if string.match(value, "^%d+$") then
		return "rbxassetid://" .. value
	end

	return value
end

local function isInsideActiveDev(instance)
	local devFolder = ActiveDevFolder
	return devFolder ~= nil and (instance == devFolder or instance:IsDescendantOf(devFolder))
end

local function getAliasForName(instanceName)
	return TAG_ALIASES[normalizeKey(instanceName)] or TAG_ALIASES[compactKey(instanceName)]
end

local function getPackTagForName(instanceName)
	local tagName = getAliasForName(instanceName)
	if tagName == ANIME_TAG or tagName == TOXIC_TAG or tagName == TIKTOK_TAG then
		return tagName
	end

	return nil
end

local function resolveStoreTag(instance)
	local packTagName = getPackTagForName(instance.Name)
	if packTagName then
		return packTagName
	end

	for tagName, canonicalTag in pairs(TAG_ALIASES) do
		if CollectionService:HasTag(instance, tagName) then
			return canonicalTag
		end
	end

	return getAliasForName(instance.Name)
end

local function resolveStoreItem(tagName, element)
	local attributeProductId = readNumberAttribute(element, {
		"DevProductId",
		"ProductId",
		"LobbyDevProductId",
	})
	if attributeProductId then
		local displayName = readStringAttribute(element, { "DisplayName", "ItemName" }) or element.Name
		return {
			ProductId = attributeProductId,
			DisplayName = displayName,
			ItemName = displayName,
			AnimationId = normalizeAnimationId(element:GetAttribute("AnimationId")),
		}
	end

	local itemsByName = STORE_ITEMS[tagName]
	if not itemsByName then
		return nil
	end

	local elementName = readStringAttribute(element, { "DisplayName", "ItemName" }) or element.Name
	local normalizedElementName = normalizeKey(elementName)
	local compactElementName = compactKey(elementName)
	local directMatch = itemsByName[normalizedElementName] or itemsByName[compactElementName]
	if directMatch then
		return directMatch
	end

	for configuredName, storeItem in pairs(itemsByName) do
		if compactKey(configuredName) == compactElementName then
			return storeItem
		end
	end

	return itemsByName.DEFAULT
end

local function findTaggedStoreElement(instance)
	local current = instance
	while current and current ~= ActiveDevFolder do
		local tagName = resolveStoreTag(current)
		if tagName then
			return current, tagName
		end
		current = current.Parent
	end

	return nil, nil
end

local function findDescendantByCompactName(parent, descendantName)
	local directMatch = parent:FindFirstChild(descendantName, true)
	if directMatch then
		return directMatch
	end

	local targetKey = compactKey(descendantName)
	for _, descendant in ipairs(parent:GetDescendants()) do
		if compactKey(descendant.Name) == targetKey then
			return descendant
		end
	end

	return nil
end

local function findTextLabel(parent, labelName)
	local label = findDescendantByCompactName(parent, labelName)
	if label and label:IsA("TextLabel") then
		return label
	end

	return nil
end

local function setTextLabelText(parent, labelName, text)
	local label = findTextLabel(parent, labelName)
	if label then
		label.Text = text
	end
end

local function getStoreItemDisplayName(element, storeItem)
	if storeItem then
		if type(storeItem.DisplayName) == "string" and storeItem.DisplayName ~= "" then
			return stripPackSuffix(storeItem.DisplayName)
		end
		if type(storeItem.ItemName) == "string" and storeItem.ItemName ~= "" then
			return stripPackSuffix(storeItem.ItemName)
		end
	end

	return stripPackSuffix(element.Name)
end

local function getHeaderItemTypeText(tagName)
	if tagName == ANIME_TAG or tagName == TOXIC_TAG or tagName == TIKTOK_TAG then
		return tagName .. "S EMOTES"
	end

	return tagName .. "S"
end

local function configureHeader(element, tagName)
	local header = findDescendantByCompactName(element, "HeaderTemplate")
	if not header then
		return
	end

	if header:IsA("LayerCollector") then
		header.Enabled = true
	end

	setTextLabelText(header, "ItemType", getHeaderItemTypeText(tagName))
end

local function getProductPriceText(productId)
	local cachedPriceText = ProductPriceTextCache[productId]
	if cachedPriceText then
		return cachedPriceText
	end

	local getProductInfo = MarketplaceService.GetProductInfoAsync or MarketplaceService.GetProductInfo
	local success, productInfo = pcall(getProductInfo, MarketplaceService, productId, Enum.InfoType.Product)
	if success and type(productInfo) == "table" and productInfo.PriceInRobux ~= nil then
		local priceText = ROBUX_PREFIX .. tostring(productInfo.PriceInRobux)
		ProductPriceTextCache[productId] = priceText
		return priceText
	end

	warn("[LobbyDevStoreService] Could not resolve Robux price for product:", productId, productInfo)
	local fallbackPriceText = ROBUX_PREFIX .. "?"
	ProductPriceTextCache[productId] = fallbackPriceText
	return fallbackPriceText
end

local function applyPromptPrice(prompt, productId)
	prompt.ActionText = ROBUX_PREFIX .. "..."

	task.spawn(function()
		local priceText = getProductPriceText(productId)
		if prompt.Parent and prompt:GetAttribute("LobbyDevProductId") == productId then
			prompt.ActionText = priceText
		end
	end)
end

local function configurePrompt(prompt, element, storeItem)
	local productId = storeItem.ProductId
	if type(productId) ~= "number" then
		return
	end

	prompt:SetAttribute("LobbyDevProductId", productId)
	local displayName = getStoreItemDisplayName(element, storeItem)
	prompt:SetAttribute("LobbyDevItemName", displayName)
	prompt:SetAttribute("LobbyDevPackName", displayName)
	prompt.Enabled = true
	prompt.RequiresLineOfSight = false
	if prompt.MaxActivationDistance <= 0 then
		prompt.MaxActivationDistance = 10
	end
	prompt.ObjectText = displayName
	applyPromptPrice(prompt, productId)

	if ConnectedPrompts[prompt] then
		return
	end
	ConnectedPrompts[prompt] = true

	prompt.Triggered:Connect(function(player)
		local currentProductId = prompt:GetAttribute("LobbyDevProductId")
		if type(currentProductId) ~= "number" then
			return
		end

		local debounceKey = `{player.UserId}:{currentProductId}`
		if PromptDebounce[debounceKey] then
			return
		end
		PromptDebounce[debounceKey] = true

		local success, err = pcall(function()
			MarketplaceService:PromptProductPurchase(player, currentProductId)
		end)
		if not success then
			warn("[LobbyDevStoreService] PromptProductPurchase failed:", currentProductId, err)
		end

		task.delay(2, function()
			PromptDebounce[debounceKey] = nil
		end)
	end)
end

local function configurePrompts(element, storeItem)
	if element:IsA("ProximityPrompt") then
		configurePrompt(element, element, storeItem)
	end

	for _, descendant in ipairs(element:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			configurePrompt(descendant, element, storeItem)
		end
	end
end

local function stopEmoteTrack(element)
	local trackState = ActiveEmoteTracks[element]
	if not trackState then
		return
	end

	ActiveEmoteTracks[element] = nil
	pcall(function()
		trackState.Track:Stop()
		trackState.Track:Destroy()
	end)
	if trackState.Animation then
		trackState.Animation:Destroy()
	end
end

local function playEmoteAnimation(element, storeItem)
	local animationId = storeItem.AnimationId
	if type(animationId) ~= "string" or animationId == "" then
		return
	end

	local humanoid = element:FindFirstChildWhichIsA("Humanoid", true)
	if not humanoid then
		return
	end

	local existingTrackState = ActiveEmoteTracks[element]
	if existingTrackState and existingTrackState.AnimationId == animationId then
		if existingTrackState.Track and not existingTrackState.Track.IsPlaying then
			existingTrackState.Track:Play()
		end
		return
	end

	stopEmoteTrack(element)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animation = Instance.new("Animation")
	animation.Name = "LobbyDevEmoteAnimation"
	animation.AnimationId = animationId
	animation.Parent = element

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not success or not track then
		animation:Destroy()
		warn("[LobbyDevStoreService] Could not load emote animation:", element:GetFullName(), animationId, track)
		return
	end

	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	ActiveEmoteTracks[element] = {
		AnimationId = animationId,
		Track = track,
		Animation = animation,
	}
end

local function configureElement(element, tagName)
	if not isInsideActiveDev(element) then
		return
	end

	local storeItem = resolveStoreItem(tagName, element)
	configureHeader(element, tagName)

	if not storeItem then
		warn(`[LobbyDevStoreService] No product configured for {tagName}: {element:GetFullName()}`)
		return
	end

	configurePrompts(element, storeItem)

	if storeItem.AnimationId then
		playEmoteAnimation(element, storeItem)
	end
end

local function configureFromInstance(instance)
	if not isInsideActiveDev(instance) then
		return
	end

	local element, tagName = findTaggedStoreElement(instance)
	if not element or not tagName then
		return
	end

	configureElement(element, tagName)
end

local function scanDevFolder(devFolder)
	for _, child in ipairs(devFolder:GetChildren()) do
		configureFromInstance(child)
	end
	for _, descendant in ipairs(devFolder:GetDescendants()) do
		configureFromInstance(descendant)
	end
end

local function attachDevFolder(devFolder)
	if ActiveDevFolder == devFolder then
		return
	end

	disconnectAll(DevConnections)
	ActiveDevFolder = devFolder

	if not devFolder then
		return
	end

	table.insert(DevConnections, devFolder.DescendantAdded:Connect(function(descendant)
		task.defer(configureFromInstance, descendant)
	end))

	table.insert(DevConnections, devFolder.DescendantRemoving:Connect(function(descendant)
		if ActiveEmoteTracks[descendant] then
			stopEmoteTrack(descendant)
		end
	end))

	scanDevFolder(devFolder)
end

local function attachLobby(lobby)
	if ActiveLobby == lobby then
		return
	end

	disconnectAll(LobbyConnections)
	attachDevFolder(nil)
	ActiveLobby = lobby

	if not lobby then
		return
	end

	local devFolder = lobby:FindFirstChild(DEV_FOLDER_NAME)
	if devFolder then
		attachDevFolder(devFolder)
	end

	table.insert(LobbyConnections, lobby.ChildAdded:Connect(function(child)
		if child.Name == DEV_FOLDER_NAME then
			attachDevFolder(child)
		end
	end))

	table.insert(LobbyConnections, lobby.ChildRemoved:Connect(function(child)
		if child == ActiveDevFolder then
			attachDevFolder(nil)
		end
	end))
end

function LobbyDevStoreService:Init()
	return
end

function LobbyDevStoreService:Start()
	if Started then
		return
	end
	Started = true

	local lobby = Workspace:FindFirstChild(LOBBY_NAME)
	if lobby then
		attachLobby(lobby)
	end

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == LOBBY_NAME then
			attachLobby(child)
		end
	end)

	Workspace.ChildRemoved:Connect(function(child)
		if child == ActiveLobby then
			attachLobby(nil)
		end
	end)

	for _, tagName in ipairs(TAG_SIGNALS) do
		CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
			task.defer(configureFromInstance, instance)
		end)
	end
end

return LobbyDevStoreService
