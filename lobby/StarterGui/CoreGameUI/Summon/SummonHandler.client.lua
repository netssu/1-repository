local UIS = game:GetService("UserInputService")
local MarketPlaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local PhysicsService = game:GetService("PhysicsService")
local TweenService = game:GetService("TweenService")
local TraitsModule = require(ReplicatedStorage.Modules.Traits)
local Upgrades = require(ReplicatedStorage.Upgrades)
local ViewModule = require(ReplicatedStorage.Modules.ViewModule)
local MarketModule = require(ReplicatedStorage.Modules.MarketModule)
local itemStatsModule = require(ReplicatedStorage:WaitForChild("ItemStats"))
local GetUnitModel = require(ReplicatedStorage.Modules.GetUnitModel)
local GradientsModule = require(ReplicatedStorage.Modules.GradientsModule)
local ButtonAnimation = require(ReplicatedStorage.Modules.ButtonAnimation)
local Signal = require(ReplicatedStorage.Modules.Core.Signal)

--local cameraPos = CFrame.new(-66.1679077, 52.7778358, 63.0225792, 0.907316506, 0.129972085, -0.399854928, 0, 0.951020598, 0.30912742, 0.420448244, -0.280476421, 0.862876713)

local SummonFrame = script.Parent.SummonFrame
local ExitFrame = script.Parent.ExitFrame
local SkipFrame = script.Parent.SkipSummon
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local IndexButton = SummonFrame.Banner.Index
local ChancesFrame = SummonFrame.ChancesFrame
local SetAutoSellEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SetAutoSell")

local CS = ColorSequence.new
local CSK = ColorSequenceKeypoint.new
local C3 = Color3.new

local AutoSummon = false
local suppressLegacySummonGuard = false
local suppressNewSummonVisibilityLog = false
local summonSummaryPending = false
local SUMMON_DEBUG_LOGS_ENABLED = false

local SecretUnit1 = "Anekan Skaivoker"
local SecretUnit2 = "Palpotin"

_G.canSummon = true

local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
player:WaitForChild("DataLoaded")

local GemsPriceSingle = 50
local GemsPriceT = 450

local ScaleMulti = 0.8
local currentBannerIndex = 1

local towerViewFolder = Instance.new("Folder")
towerViewFolder.Name = "TowerView"
towerViewFolder.Parent = workspace.Camera
local skipConn

local FrameForViewport = SummonFrame.Banner.Contents
local CurrentHour = workspace.CurrentHour

local function findChildPath(root, path)
	local current = root

	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
		if not current then
			return nil
		end
	end

	return current
end

local function findFirstGuiButton(root)
	if not root then return nil end
	if root:IsA("GuiButton") then
		return root
	end

	local preferredButton = root:FindFirstChild("Btn")
		or root:FindFirstChild("Button")

	if preferredButton and preferredButton:IsA("GuiButton") then
		return preferredButton
	end

	return root:FindFirstChildWhichIsA("GuiButton", true)
end

local function debugSummonOpen(...)
	if SUMMON_DEBUG_LOGS_ENABLED then
		warn("[SummonOpenDebug]", ...)
	end
end

local function setTextValue(target, value)
	if target and (target:IsA("TextLabel") or target:IsA("TextButton")) then
		target.Text = tostring(value)
	end
end

local function clearViewportChildren(container)
	if not container then return end

	if container:IsA("ViewportFrame") then
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("WorldModel") or child:IsA("Camera") or child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		return
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ViewportFrame") or child:IsA("WorldModel") then
			child:Destroy()
		end
	end
end

local function applyViewportOffset(viewport, offset)
	local worldModel = viewport and viewport:FindFirstChildOfClass("WorldModel")
	local model = worldModel and worldModel:FindFirstChildOfClass("Model")

	if model and model.PrimaryPart then
		model:SetPrimaryPartCFrame(model.PrimaryPart.CFrame * (offset or CFrame.new(0, 0.15, 1)))
	end
end

local function copyViewportProperty(targetViewport, sourceViewport, propertyName)
	local readOk, value = pcall(function()
		return sourceViewport[propertyName]
	end)

	if not readOk then
		return
	end

	pcall(function()
		targetViewport[propertyName] = value
	end)
end

local function attachViewport(container, unitName, offset)
	clearViewportChildren(container)

	if not container or not unitName or unitName == "" or not GetUnitModel[unitName] then
		return nil
	end

	local viewport = ViewPortModule.CreateViewPort(unitName)
	if not viewport then
		return nil
	end

	if container:IsA("ViewportFrame") then
		applyViewportOffset(viewport, offset)

		copyViewportProperty(container, viewport, "BackgroundTransparency")
		copyViewportProperty(container, viewport, "ImageTransparency")
		copyViewportProperty(container, viewport, "ImageColor3")
		copyViewportProperty(container, viewport, "Ambient")
		copyViewportProperty(container, viewport, "LightColor")
		copyViewportProperty(container, viewport, "LightDirection")
		copyViewportProperty(container, viewport, "CurrentCamera")

		local worldModel = viewport:FindFirstChildOfClass("WorldModel")
		if worldModel then
			worldModel.Parent = container
		end

		if ViewPortModule.DestroyViewport then
			ViewPortModule.DestroyViewport(viewport)
		else
			viewport:Destroy()
		end
		return container
	end

	viewport.Parent = container
	applyViewportOffset(viewport, offset)
	return viewport
end

local function setStrokeColor(target, color)
	if not target then return end

	for _, child in ipairs(target:GetChildren()) do
		if child:IsA("UIStroke") then
			child.Color = color
		end
	end
end

local function setGradientColor(target, colorSequence)
	if not target then return end

	local gradient = target:FindFirstChildOfClass("UIGradient") or target:FindFirstChild("UIGradient")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = colorSequence
	end
end

local function formatCompactNumber(value)
	if typeof(value) ~= "number" then
		return tostring(value or "")
	end

	local formatted = tostring(math.floor(value + 0.5))
	while true do
		local newFormatted, substitutions = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = newFormatted
		if substitutions == 0 then
			break
		end
	end

	return formatted
end

local function getNewSummonsFrame(waitForLoad)
	local newUI = playerGui:FindFirstChild("NewUI")
	if not newUI and waitForLoad then
		newUI = playerGui:WaitForChild("NewUI", 2)
	end

	local summons = newUI and newUI:FindFirstChild("Summons")
	if not summons and waitForLoad and newUI then
		summons = newUI:WaitForChild("Summons", 2)
	end

	if summons and summons:IsA("GuiObject") then
		debugSummonOpen(
			"getNewSummonsFrame",
			"waitForLoad=" .. tostring(waitForLoad),
			"found=" .. summons:GetFullName(),
			"class=" .. summons.ClassName,
			"visible=" .. tostring(summons.Visible)
		)
		return summons
	end

	debugSummonOpen(
		"getNewSummonsFrame",
		"waitForLoad=" .. tostring(waitForLoad),
		"found=nil"
	)

	return nil
end

local function isSummonVisible()
	local newSummons = getNewSummonsFrame()
	if newSummons then
		return newSummons.Visible
	end

	return SummonFrame.Visible
end

local function setSummonVisible(visible)
	local newSummons = getNewSummonsFrame(true)
	if newSummons then
		suppressLegacySummonGuard = true
		suppressNewSummonVisibilityLog = true
		debugSummonOpen(
			"setSummonVisible:new",
			"visible=" .. tostring(visible),
			"newBefore=" .. tostring(newSummons.Visible),
			"legacyBefore=" .. tostring(SummonFrame.Visible)
		)
		newSummons.Visible = visible
		SummonFrame.Visible = false
		suppressNewSummonVisibilityLog = false
		suppressLegacySummonGuard = false
		debugSummonOpen(
			"setSummonVisible:new:after",
			"newAfter=" .. tostring(newSummons.Visible),
			"legacyAfter=" .. tostring(SummonFrame.Visible)
		)
		return
	end

	debugSummonOpen("setSummonVisible:legacy", "visible=" .. tostring(visible))
	suppressLegacySummonGuard = true
	SummonFrame.Visible = visible
	suppressLegacySummonGuard = false
end

local function openPreferredSummonMenu()
	if summonSummaryPending then
		return
	end

	local targetName = getNewSummonsFrame(true) and "Summons" or "SummonFrame"
	debugSummonOpen("openPreferredSummonMenu", "target=" .. tostring(targetName))
	_G.CloseAll(targetName)
	setSummonVisible(true)
end

local function closePreferredSummonMenu()
	debugSummonOpen("closePreferredSummonMenu")
	setSummonVisible(false)
	_G.CloseAll()
end

if getNewSummonsFrame(true) then
	suppressLegacySummonGuard = true
	SummonFrame.Visible = false
	suppressLegacySummonGuard = false
end

SummonFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	local newSummons = getNewSummonsFrame()
	debugSummonOpen(
		"legacy-visible-changed",
		"legacyVisible=" .. tostring(SummonFrame.Visible),
		"newVisible=" .. tostring(newSummons and newSummons.Visible),
		"skipVisible=" .. tostring(SkipFrame.Visible),
		"exitVisible=" .. tostring(ExitFrame.Visible),
		"guardSuppressed=" .. tostring(suppressLegacySummonGuard)
	)

	if suppressLegacySummonGuard or not newSummons then
		return
	end

	if SummonFrame.Visible then
		debugSummonOpen("legacy-guard:forcing-hidden")
		suppressLegacySummonGuard = true
		SummonFrame.Visible = false
		suppressLegacySummonGuard = false

		if not newSummons.Visible and not SkipFrame.Visible and not summonSummaryPending then
			suppressNewSummonVisibilityLog = true
			newSummons.Visible = true
			suppressNewSummonVisibilityLog = false
			debugSummonOpen("legacy-guard:restored-new", "newVisible=" .. tostring(newSummons.Visible))
		end
	end
end)

local initialNewSummons = getNewSummonsFrame(true)
if initialNewSummons then
	initialNewSummons:GetPropertyChangedSignal("Visible"):Connect(function()
		debugSummonOpen(
			"new-visible-changed",
			"newVisible=" .. tostring(initialNewSummons.Visible),
			"legacyVisible=" .. tostring(SummonFrame.Visible),
			"logSuppressed=" .. tostring(suppressNewSummonVisibilityLog)
		)
	end)
end

local function getSingleSummonCost()
	if player.OwnGamePasses["Ultra VIP"].Value then
		return 35
	end

	if player.OwnGamePasses.VIP.Value then
		return 40
	end

	return 50
end

local function getBannerUnitsForIndex(bannerIndex)
	local safeBannerIndex = math.clamp(tonumber(bannerIndex) or 1, 1, 3)
	local units = {}

	for mythicalIndex = 1, 3 do
		local unitName = CurrentHour:GetAttribute(string.format("Banner%dMythical%d", safeBannerIndex, mythicalIndex))

		if not unitName and safeBannerIndex == 1 then
			unitName = CurrentHour:GetAttribute("Mythical" .. mythicalIndex)
		end

		if unitName and unitName ~= "" then
			table.insert(units, unitName)
		end
	end

	if #units == 0 then
		for mythicalIndex = 1, 3 do
			local fallbackUnit = CurrentHour:GetAttribute("Mythical" .. mythicalIndex)
			if fallbackUnit and fallbackUnit ~= "" then
				table.insert(units, fallbackUnit)
			end
		end
	end

	return units
end

local function getCurrentBannerUnits()
	return getBannerUnitsForIndex(currentBannerIndex)
end

local function formatBannerCountdown(totalSeconds)
	local safeSeconds = math.max(math.floor(tonumber(totalSeconds) or 0), 0)
	local hours = math.floor(safeSeconds / 3600)
	local minutes = math.floor((safeSeconds % 3600) / 60)
	local seconds = safeSeconds % 60

	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local SummonNPC = workspace:WaitForChild("SummonNPC")
local SummonNPCNames = {"Mythical1","Mythical2","Mythical3"}
local Rarities = {"Secret","Mythical","Legendary","Epic","Rare"}
local AutoSellButtonOrder = {
	Rare = "1",
	Epic = "2",
	Legendary = "3",
}
local previewDebugRegistry = {}

local function warnPreviewOnce(key, ...)
	if not SUMMON_DEBUG_LOGS_ENABLED then
		return
	end

	if previewDebugRegistry[key] then
		return
	end

	previewDebugRegistry[key] = true
	warn(...)
end

local function formatStatValue(value)
	if typeof(value) ~= "number" then
		return tostring(value or "")
	end

	if math.floor(value) == value then
		return tostring(value)
	end

	return string.format("%.1f", value)
end

local RewardRarityPriority = {
	Secret = 7,
	Mythical = 6,
	Unique = 5,
	Legendary = 4,
	Epic = 3,
	Rare = 2,
	Common = 1,
}

local function getTraitInfo(traitName, traitDataCache)
	if not traitName or traitName == "" then
		return nil
	end

	local traitInfo = traitDataCache[traitName]
	if traitInfo == nil then
		traitInfo = TraitsModule.Traits[traitName]
		traitDataCache[traitName] = traitInfo
	end

	return traitInfo
end

local function isTraitMythicalOrBetter(traitName, traitDataCache)
	local traitInfo = getTraitInfo(traitName, traitDataCache)
	if not traitInfo then
		return false
	end

	return (RewardRarityPriority[traitInfo.Rarity] or 0) >= (RewardRarityPriority.Mythical or 0)
end

local function buildSummonRewardName(baseName, isShiny, traitName)
	local displayName = tostring(baseName or "Reward")

	if isShiny then
		displayName = "Shiny " .. displayName
	end

	if traitName and traitName ~= "" then
		displayName = displayName .. " [" .. traitName .. "]"
	end

	return displayName
end

local function getSummonRewardSortScore(entry)
	local score = (RewardRarityPriority[entry.rarity] or 0) * 1000

	if entry.isShiny then
		score += 200
	end

	if entry.hasMythicTrait then
		score += 100
	end

	if not entry.wasSold then
		score += 25
	end

	score += math.min(entry.quantity or 1, 99)
	return score
end

local function buildSummonSummary(result)
	local traitDataCache = {}
	local groupedEntries = {}
	local orderedEntries = {}
	local totalQuantity = 0

	for _, data in ipairs(result or {}) do
		local tower = data.Tower
		if tower then
			local towerName = tower.Name
			local towerStats = Upgrades[towerName]
			local traitName = tower:GetAttribute("Trait")
			local isShiny = tower:GetAttribute("Shiny") == true
			local hasMythicTrait = isTraitMythicalOrBetter(traitName, traitDataCache)
			local wasSold = data.AutoSell and not isShiny and not hasMythicTrait
			local entryKey = string.format(
				"tower:%s:%s:%s:%s",
				towerName,
				tostring(isShiny),
				tostring(traitName or ""),
				tostring(wasSold)
			)

			local entry = groupedEntries[entryKey]
			if not entry then
				entry = {
					name = towerName,
					displayName = buildSummonRewardName(towerName, isShiny, traitName),
					viewportName = towerName,
					quantity = 0,
					rarity = towerStats and towerStats.Rarity or nil,
					wasSold = wasSold,
					isShiny = isShiny,
					hasMythicTrait = hasMythicTrait,
					sortScore = 0,
				}
				groupedEntries[entryKey] = entry
				table.insert(orderedEntries, entry)
			end

			entry.quantity += 1
			entry.sortScore = getSummonRewardSortScore(entry)
			totalQuantity += 1
		elseif data.Item then
			local item = data.Item
			local itemName = typeof(item) == "Instance" and item.Name or tostring(item)
			local itemStats = itemStatsModule[itemName] or itemStatsModule.Star
			local entryKey = "item:" .. tostring(itemName)

			local entry = groupedEntries[entryKey]
			if not entry then
				entry = {
					name = itemName,
					displayName = tostring(itemName),
					viewportName = itemStats and itemStats.Name or itemName,
					quantity = 0,
					rarity = itemStats and itemStats.Rarity or nil,
					wasSold = false,
					isShiny = false,
					hasMythicTrait = false,
					sortScore = 0,
				}
				groupedEntries[entryKey] = entry
				table.insert(orderedEntries, entry)
			end

			entry.quantity += 1
			entry.sortScore = getSummonRewardSortScore(entry)
			totalQuantity += 1
		end
	end

	table.sort(orderedEntries, function(a, b)
		if a.sortScore ~= b.sortScore then
			return a.sortScore > b.sortScore
		end

		if (a.quantity or 0) ~= (b.quantity or 0) then
			return (a.quantity or 0) > (b.quantity or 0)
		end

		return tostring(a.displayName) < tostring(b.displayName)
	end)

	local featured = orderedEntries[1]
	if not featured then
		return nil
	end

	return {
		summaryTitle = totalQuantity > 1 and "Summon Results" or "Summon Result",
		entries = orderedEntries,
		featured = featured,
		totalQuantity = totalQuantity,
	}
end

local function setAutomaticRewardPopupSuppressed(isSuppressed)
	if typeof(_G.SetRewardPopupSuppressed) == "function" then
		_G.SetRewardPopupSuppressed(isSuppressed)
	end
end

local function setRewardPopupClosedCallback(callback)
	if typeof(_G.SetRewardPopupClosedCallback) == "function" then
		_G.SetRewardPopupClosedCallback(callback)
	end
end

local function buildBannerPresentation(unitName, index, bannerUnits)
	if not unitName or unitName == "" then
		return {
			title = "Banner " .. tostring(index),
			description = "Unavailable",
		}
	end

	local unitStats = Upgrades[unitName]
	local firstUpgrade = unitStats and unitStats.Upgrades and unitStats.Upgrades[1]
	local pieces = {}

	if unitStats and unitStats.Rarity then
		table.insert(pieces, unitStats.Rarity)
	end

	if unitStats and unitStats.Support then
		table.insert(pieces, "Support")
	elseif firstUpgrade and firstUpgrade.Type then
		table.insert(pieces, firstUpgrade.Type)
	end

	if unitStats and unitStats["Place Limit"] then
		table.insert(pieces, string.format("%sx place", formatStatValue(unitStats["Place Limit"])))
	end

	if firstUpgrade and firstUpgrade.Range then
		table.insert(pieces, string.format("%s range", formatStatValue(firstUpgrade.Range)))
	end

	if firstUpgrade and firstUpgrade.Cooldown then
		table.insert(pieces, string.format("%ss cd", formatStatValue(firstUpgrade.Cooldown)))
	end

	local featuredUnits = {}
	for _, bannerUnitName in ipairs(bannerUnits or {}) do
		if bannerUnitName and bannerUnitName ~= "" then
			table.insert(featuredUnits, bannerUnitName)
		end
	end

	return {
		title = unitName .. " Banner",
		description = #featuredUnits > 0
			and ("Featured: " .. table.concat(featuredUnits, ", "))
			or (#pieces > 0 and table.concat(pieces, " | ") or "Featured unit"),
	}
end

local function getMythicalColorSequence()
	local border = ReplicatedStorage.Borders:FindFirstChild("Mythical")
	if border and border:IsA("UIGradient") then
		return border.Color
	end

	return ColorSequence.new(Color3.fromRGB(255, 170, 0))
end

local function getNewSummonPreviewContainer(newSummons)
	local main = findChildPath(newSummons, {"Body", "Main"})
	local bannerRoot = main and main:FindFirstChild("Banner")

	return (main and (main:FindFirstChild("PlaceHolder") or main:FindFirstChild("Placeholder")))
		or (bannerRoot and (bannerRoot:FindFirstChild("PlaceHolder") or bannerRoot:FindFirstChild("Placeholder")))
end

local function getOrderedPreviewCards(container)
	if not container then
		return {}
	end

	local cards = {}

	for _, child in ipairs(container:GetChildren()) do
		local looksLikeCard = child:IsA("GuiObject")
			and child.Name ~= "Bar"
			and (child:FindFirstChild("Rectangle") or (child:FindFirstChild("Name") and child:FindFirstChild("Rarity")))

		if looksLikeCard then
			table.insert(cards, child)
		end
	end

	table.sort(cards, function(a, b)
		local layoutA = a.LayoutOrder ~= 0 and a.LayoutOrder or math.huge
		local layoutB = b.LayoutOrder ~= 0 and b.LayoutOrder or math.huge

		if layoutA ~= layoutB then
			return layoutA < layoutB
		end

		local numberA = tonumber(a.Name)
		local numberB = tonumber(b.Name)
		if numberA and numberB and numberA ~= numberB then
			return numberA < numberB
		end

		return a.Name < b.Name
	end)

	return cards
end

local function getPreviewViewportTarget(card)
	if not card then
		return nil
	end

	local rectangle = card:FindFirstChild("Rectangle")
	local rectangleIsViewport = rectangle and rectangle:IsA("ViewportFrame")
	local cardIsViewport = card:IsA("ViewportFrame")

	if cardIsViewport and rectangleIsViewport then
		warnPreviewOnce(
			"nested:" .. card:GetFullName(),
			"[SummonPreview] Nested ViewportFrame detected in",
			card:GetFullName(),
			"- make only Rectangle a ViewportFrame."
		)
		return rectangle
	end

	if rectangleIsViewport then
		return rectangle
	end

	if cardIsViewport then
		return card
	end

	return rectangle or card
end

local function getPreviewTextObject(card, objectName)
	return card and card:FindFirstChild(objectName, true)
end

local function getOrCreateSelectionScale(target)
	if not (target and target:IsA("GuiObject")) then
		return nil
	end

	local scale = target:FindFirstChild("BannerSelectionScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end

	scale = Instance.new("UIScale")
	scale.Name = "BannerSelectionScale"
	scale.Parent = target
	return scale
end

local function updateNewBannerSelectionVisual(newSummons)
	local selection = newSummons and findChildPath(newSummons, {"Selection", "Banners"})
	if not selection then
		return
	end

	for index = 1, 3 do
		local card = selection:FindFirstChild(tostring(index))
		if card and card:IsA("GuiObject") then
			local isSelected = index == currentBannerIndex
			local scale = getOrCreateSelectionScale(card)
			if scale then
				TweenService:Create(
					scale,
					TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{Scale = isSelected and 1.05 or 1}
				):Play()
			end

			local accentColor = isSelected and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
			setStrokeColor(card, accentColor)
			setStrokeColor(card:FindFirstChild("Bg"), accentColor)
		end
	end
end

local function updateNewSummonPreview()
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	local mythicalSequence = getMythicalColorSequence()
	local mythicalColor = mythicalSequence.Keypoints[1].Value
	local bannerUnits = getCurrentBannerUnits()
	local bannerRoot = findChildPath(newSummons, {"Body", "Main", "Banner"})
	local placeholder = getNewSummonPreviewContainer(newSummons)
	local previewCards = getOrderedPreviewCards(placeholder)
	local selection = findChildPath(newSummons, {"Selection", "Banners"})
	local safeBannerIndex = math.clamp(currentBannerIndex, 1, 3)
	local currentPresentation = buildBannerPresentation(bannerUnits[1], safeBannerIndex, bannerUnits)

	updateNewBannerSelectionVisual(newSummons)

	if not placeholder then
		warnPreviewOnce("placeholder_missing", "[SummonPreview] Placeholder/PlaceHolder not found under NewUI.Summons.")
	else
		warnPreviewOnce(
			"placeholder_found",
			"[SummonPreview] Using preview container:",
			placeholder:GetFullName(),
			"| class:",
			placeholder.ClassName,
			"| cards found:",
			#previewCards
		)
	end

	if bannerRoot then
		setTextValue(bannerRoot:FindFirstChild("Name"), currentPresentation.title)
		setTextValue(bannerRoot:FindFirstChild("Info"), currentPresentation.description)
	end

	if placeholder then
		for index, card in ipairs(previewCards) do
			local unitName = bannerUnits[index]
			local viewportContainer = getPreviewViewportTarget(card)
			local viewport = attachViewport(viewportContainer, unitName, index == 2 and CFrame.new(0, 0.2, 1) or CFrame.new(0, 0.1, 1))
			local nameLabel = getPreviewTextObject(card, "Name")
			local rarityLabel = getPreviewTextObject(card, "Rarity")

			warnPreviewOnce(
				"card:" .. card:GetFullName(),
				"[SummonPreview] Card",
				index,
				"| path:",
				card:GetFullName(),
				"| class:",
				card.ClassName,
				"| target:",
				viewportContainer and viewportContainer:GetFullName() or "nil",
				"| target class:",
				viewportContainer and viewportContainer.ClassName or "nil",
				"| unit:",
				unitName or "nil"
			)

			if nameLabel and nameLabel.Parent and nameLabel.Parent:IsA("ViewportFrame") then
				warnPreviewOnce(
					"name_in_viewport:" .. card:GetFullName(),
					"[SummonPreview] Name label is inside a ViewportFrame and may not render:",
					nameLabel:GetFullName()
				)
			end

			if rarityLabel and rarityLabel.Parent and rarityLabel.Parent:IsA("ViewportFrame") then
				warnPreviewOnce(
					"rarity_in_viewport:" .. card:GetFullName(),
					"[SummonPreview] Rarity label is inside a ViewportFrame and may not render:",
					rarityLabel:GetFullName()
				)
			end

			if viewport then
				viewport.ZIndex = 1
			end

			setTextValue(nameLabel, unitName or "")

			setTextValue(rarityLabel, unitName and "Mythical" or "")
			if rarityLabel then
				rarityLabel.TextColor3 = mythicalColor
				setGradientColor(rarityLabel, mythicalSequence)
				setStrokeColor(rarityLabel, Color3.fromRGB(0, 0, 0))
			end
		end
	end

	if selection then
		for index = 1, 3 do
			local bannerOptionUnits = getBannerUnitsForIndex(index)
			local featuredUnitName = bannerOptionUnits[1]
			local card = selection:FindFirstChild(tostring(index))
			if card then
				local presentation = buildBannerPresentation(featuredUnitName, index, bannerOptionUnits)
				local holder = card:FindFirstChild("Holder") or card:FindFirstChild("Bg") or card
				local viewport = attachViewport(holder, featuredUnitName, CFrame.new(0, 0.15, 1))
				if viewport then
					viewport.ZIndex = 1
				end

				setTextValue(findChildPath(card, {"Text", "Title"}), presentation.title)
				setTextValue(findChildPath(card, {"Text", "Description"}), presentation.description)
			end
		end
	end
end

local function updateNewSummonCurrencies()
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	local bottom = findChildPath(newSummons, {"Bottom"})
		or findChildPath(newSummons, {"Body", "Main", "Banner", "Bg", "Bottom"})
	if not bottom then return end

	setTextValue(findChildPath(bottom, {"Coins", "Text"}), formatCompactNumber(player.Coins.Value))
	setTextValue(findChildPath(bottom, {"Diamond", "Text"}), formatCompactNumber(player.Gems.Value))
	setTextValue(bottom:FindFirstChild("Text"), string.format("1x Summon: %d Gems | Lucky: %d", getSingleSummonCost(), player.LuckySpins.Value))
end

local function updateNewSummonTimer(secondsRemaining)
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	local bar = findChildPath(newSummons, {"Body", "Main", "Bar"})
		or findChildPath(newSummons, {"Body", "Main", "Banner", "Bar"})
	if not bar then return end

	local fill = findChildPath(bar, {"Bar", "Fill"})
		or findChildPath(bar, {"Fill"})
		or bar:FindFirstChild("Fill", true)
	if fill then
		fill.Size = UDim2.fromScale(math.clamp(1 - (secondsRemaining / 1800), 0, 1), 1)
	end

	local timerText = formatBannerCountdown(secondsRemaining)
	local timerLabel = findChildPath(bar, {"Bar", "Timer"})
		or findChildPath(bar, {"Timer"})
		or bar:FindFirstChild("Timer", true)
	local titleLabel = findChildPath(bar, {"Text"})
		or bar:FindFirstChild("Text", true)

	setTextValue(titleLabel, "Next Banner")
	setTextValue(timerLabel, timerText)
end

local function updateNewSummonLuckLabel(text, gradientColor, strokeColor)
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	local luckLabel = findChildPath(newSummons, {"Body", "Main", "Banner", "Luck"})
		or findChildPath(newSummons, {"Body", "Main", "Luck"})
	if not luckLabel then return end

	setTextValue(luckLabel, text)
	setGradientColor(luckLabel, gradientColor)
	setStrokeColor(luckLabel, strokeColor)
end

local function getNewAutoSellButtonRoot(newSummons, rarityName)
	local buttonIndex = AutoSellButtonOrder[rarityName]
	if not buttonIndex then
		return nil
	end

	return findChildPath(newSummons, {"Buttons", buttonIndex})
		or findChildPath(newSummons, {"Body", "Main", "Buttons", buttonIndex})
end

local function getOrCreateButtonScale(target)
	if not (target and target:IsA("GuiObject")) then
		return nil
	end

	local scale = target:FindFirstChild("AutoSellScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end

	scale = Instance.new("UIScale")
	scale.Name = "AutoSellScale"
	scale.Parent = target
	return scale
end

local function setNewAutoSellButtonState(rarityName, isActive)
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	local buttonRoot = getNewAutoSellButtonRoot(newSummons, rarityName)
	if not buttonRoot then return end

	local accentColor = isActive and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
	local label = buttonRoot:FindFirstChild("Text")
	local background = buttonRoot:FindFirstChild("Bg")
	local scale = getOrCreateButtonScale(buttonRoot)

	if label and label:IsA("TextLabel") then
		label.TextColor3 = accentColor
	end

	setStrokeColor(buttonRoot, accentColor)
	setStrokeColor(background, accentColor)
	setGradientColor(background, ColorSequence.new(accentColor))

	if scale then
		TweenService:Create(
			scale,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Scale = isActive and 1.08 or 1}
		):Play()
	end
end

local function updateNewAutoSummonVisual()
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	local buttonRoot = findChildPath(newSummons, {"Body", "Main", "Banner", "Buttons", "4"})
	if not buttonRoot then return end

	local accentColor = AutoSummon and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
	local label = buttonRoot:FindFirstChild("Text") or buttonRoot:FindFirstChild("Luck")
	local background = buttonRoot:FindFirstChild("Bg")

	if label and label:IsA("TextLabel") then
		label.TextColor3 = accentColor
	end

	setStrokeColor(buttonRoot, accentColor)
	setStrokeColor(background, accentColor)
end

local function populateNewSummonGemShop()
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	local content = findChildPath(newSummons, {"Gems", "Content"})
		or findChildPath(newSummons, {"Body", "Main", "Gems", "Content"})
	if not content then return end

	for index = 1, math.max(#MarketModule.Gems, 8) do
		local slot = content:FindFirstChild(tostring(index))
		local product = MarketModule.Gems[index]

		if slot then
			slot.Visible = product ~= nil

			if product then
				local productInfo = product
				local titleLabel = slot:FindFirstChild("Title")
				local priceLabel = slot:FindFirstChild("Text")
					or findChildPath(slot, {"Button", "Text"})
				local button = findChildPath(slot, {"Button", "Btn"})
					or findFirstGuiButton(slot:FindFirstChild("Button"))
					or findFirstGuiButton(slot)

				setTextValue(titleLabel, string.format("%s GEMS", formatCompactNumber(productInfo.Value)))
				setTextValue(priceLabel, string.format("%sR$", formatCompactNumber(productInfo.Price)))

				if button and button:GetAttribute("PromptProductID") ~= productInfo.ProductID then
					button:SetAttribute("PromptProductID", productInfo.ProductID)
					button.Activated:Connect(function()
						MarketPlaceService:PromptProductPurchase(player, productInfo.ProductID)
					end)
				end
			end
		end
	end
end

--warn('XO1')

local function updateBanner()
	--warn("Attribute changed.")
	for i, v in workspace.SummonNPC:GetChildren() do
		local folder = v:FindFirstChildOfClass("Folder")
		if folder then
			folder:ClearAllChildren()
		end
	end

	for _, Rarity in SummonNPCNames do
		local Model:Model = GetUnitModel[game.Workspace.CurrentHour:GetAttribute(Rarity)]:Clone()
		local Scale = Model:GetScale()
		Model:ScaleTo(Scale * ScaleMulti)
		local HRP = Model:WaitForChild("HumanoidRootPart")
		local Humanoid:Humanoid = Model:WaitForChild("Humanoid")
		local animations = Model:FindFirstChild("Animations")
		HRP.Anchored = true
		if HRP and Humanoid then
			pcall(function()

				HRP.CFrame = SummonNPC[Rarity]:WaitForChild("PositionPart").CFrame
				Model.Parent = SummonNPC[Rarity].Unit
				local animator = Humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", Humanoid)

				if animations then
					local track = animator:LoadAnimation(Model.Animations.Idle)
					track:Play()
					track:Destroy()
				end
			end)
		end
	end

	for i=1, 3 do
		if game.Workspace.CurrentHour:GetAttribute("Mythical"..i) ~= "" and game.Workspace.CurrentHour:GetAttribute("Mythical"..i) ~= nil then
			if GetUnitModel[game.Workspace.CurrentHour:GetAttribute("Mythical"..i)] then
				local FoundVp = FrameForViewport["Unit"..i]:FindFirstChildOfClass("ViewportFrame")
				if FoundVp then
					FoundVp:Destroy()
					--warn("Found vp wipe it")
				else
					--warn("Not Found vp")
				end

				local vp = ViewPortModule.CreateViewPort(game.Workspace.CurrentHour:GetAttribute("Mythical"..i))
				vp.Parent = FrameForViewport["Unit"..i]
				--FrameForViewport["Unit"..i].TextFrame.UnitName.Text = game.Workspace.CurrentHour:GetAttribute("Mythical"..i)

				FrameForViewport['UnitDesc'..i].Text.name.Text = game.Workspace.CurrentHour:GetAttribute("Mythical"..i)

				--vp.ZIndex = if i == 3 then 3 else FrameForViewport["Unit"..i].ZIndex
				vp.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.1,1))

				GradientsModule.addRarityGradient({FrameForViewport['UnitDesc'..i].Text.Rarity},"Mythical")
				--script.Parent.Parent.Parent.BannerSurfaceGui.BannerFrame[`Unit{i}`]:ClearAllChildren()
				--local vp2 = vp:Clone()
				--script.Parent.Parent.Parent.BannerSurfaceGui.BannerFrame[`Unit{i}`]:ClearAllChildren()
			end
		end
	end

	local FoundVp = FrameForViewport.SecretUnit1:FindFirstChildOfClass("ViewportFrame")
	if FoundVp then
		FoundVp:Destroy()
	end
	local FoundVp2 = FrameForViewport.SecretUnit2:FindFirstChildOfClass("ViewportFrame")
	if FoundVp2 then
		FoundVp2:Destroy()
	end
	local vp = ViewPortModule.CreateViewPort(SecretUnit1)
	vp.Parent = FrameForViewport.SecretUnit1
	vp.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.3,1) * CFrame.Angles(0,math.rad(180),0) )
	vp.ZIndex = 1
	vp.Ambient = Color3.new(0,0,0)
	vp.LightColor = Color3.new(0,0,0)

	local vp2 = ViewPortModule.CreateViewPort(SecretUnit2)
	vp2.Parent = FrameForViewport.SecretUnit2
	vp2.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp2.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.3,1) * CFrame.Angles(0,math.rad(180),0) )
	vp2.ZIndex = 1
	vp2.Ambient = Color3.new(0,0,0)
	vp2.LightColor = Color3.new(0,0,0)

	updateNewSummonPreview()
end

game.Workspace.CurrentHour.AttributeChanged:Connect(updateBanner)

local EvoUnits = {}

for _, unit in Upgrades do
	if unit.Evolve and unit.Evolve.EvolvedUnit then
		EvoUnits[unit.Evolve.EvolvedUnit] = true
	end
end

for _, rarity in Rarities do
	local Scroll = ChancesFrame.ScrollingFrame
	GradientsModule.addRarityGradient({Scroll[rarity].TitleBar,Scroll[rarity].TitleBar.UIStroke,Scroll[rarity].TitleBar.ImageCover,Scroll[rarity].TitleBar.TextLabel,Scroll[rarity].TitleBar.Percent},rarity,true)
end

--warn('XO2')

local blackList = {
	'Asaka Tano',
	'Asaka Tano (Outcast)',
	'Egg Bane',
	'Cad Bunny',
	--TEMP
	'Quinion Vas',
	'Tenth Brother',
	"Sixth Brother",
	"Sith Trooper",
	"Dart Wader Maskless",
}

for _, unit in Upgrades do
	if not EvoUnits[unit.Name] and not table.find(blackList, unit.Name) then
		if unit.Rarity == "Exclusive" then continue end
		local template = script.TemplateButton:Clone()
		template.Name = unit.Name
		template.Parent = ChancesFrame.ScrollingFrame[unit.Rarity].UnitHolder



		--print(unit.Name)
		local vp = ViewPortModule.CreateViewPort(unit.Name)

		if not vp then
			--warn("Failed to create viewport for:", unit.Name)
			continue
		end

		vp.ZIndex = 6
		vp.Parent = template

		ButtonAnimation.unitButtonAnimation(template)

		if unit.Rarity == "Secret" then
			vp.LightColor = Color3.new(0,0,0)
			vp.Ambient = Color3.new(0,0,0)
			GradientsModule.addRarityGradient({template.Image,template.GlowEffect,template:FindFirstChildOfClass("ViewportFrame")},unit.Rarity)
		else
			GradientsModule.addRarityGradient({template.Image,template.GlowEffect},unit.Rarity)
		end

	end
end

--warn('XO3')

local function closeSummonMenu()
	local chr = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
	if chr then
		chr:SetPrimaryPartCFrame(workspace.SummonTeleporters.TeleportOut.CFrame) 
		_G.CloseAll()
		UiHandler.EnableAllButtons()
	end
end

SummonFrame.Banner.X_Close.Activated:Connect(closeSummonMenu)

local newCloseButton = findChildPath(getNewSummonsFrame(), {"Body", "Closebtn", "Btn"})
if newCloseButton and not newCloseButton:GetAttribute("SummonCloseBound") then
	newCloseButton:SetAttribute("SummonCloseBound", true)
	newCloseButton.Activated:Connect(closeSummonMenu)
end

local MedalLib = require(ReplicatedStorage.Modules.MedalLib)

local Lighting = game:GetService("Lighting")
local NewUIBlur = Lighting.NewUIBlur

local function summon(amount, HolocronSummon, isLucky)
	if not _G.canSummon then return end
	if not isSummonVisible() then return end

	if not player.TutorialWin.Value and not player.TutorialLossGemsClaimed.Value then
		if amount ~= 10 then return end -- can only summon 10 if not tut

		warn('Tut is not completed')
		player.Character:PivotTo(workspace:WaitForChild('TutorialTeleportOut').CFrame)
	end



	_G.canSummon = false
	setAutomaticRewardPopupSuppressed(true)
	setRewardPopupClosedCallback(nil)
	summonSummaryPending = false

	local result = game.ReplicatedStorage.Functions.SummonBannerEvent:InvokeServer(amount, HolocronSummon, isLucky, currentBannerIndex)
	if typeof(result) ~= "table" then
		setAutomaticRewardPopupSuppressed(false)
		_G.canSummon = true
		UiHandler.PlaySound("Error")
		_G.Message(result, Color3.fromRGB(221, 0, 0))
		return
	end

	local summonSummary = buildSummonSummary(result)

	local Skip = nil
	if not isLucky then
		Skip = player:WaitForChild("Settings"):WaitForChild("SummonSkip").Value
		setSummonVisible(false)

		if Skip then
			SkipFrame.UIScale.Scale = 0
			SkipFrame.Visible = true
			TweenService:Create(SkipFrame.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Exponential), {Scale = 1}):Play()
		end
	end

	NewUIBlur.Enabled = false
	local conn = NewUIBlur.Changed:Connect(function()
		NewUIBlur.Enabled = false
	end)


	local templates = {}
	local traitDataCache = {}
	local shouldConfetti = false

	for towerindex, Data in result do
		local Unit = Data.Tower

		if Skip and Unit then
			local UnitStats = Upgrades[Unit.Name]
			if UnitStats then
				if UnitStats.Rarity == "Mythical" then
					shouldConfetti = true
				end

				local Template = SkipFrame.Frame.TemplateButton:Clone()
				Template.Name = Unit.Name
				Template.LayoutOrder = towerindex
				Template.Visible = true
				Template.Parent = SkipFrame.Frame
				Template.UIScale.Scale = 0

				local trait = Unit:GetAttribute("Trait")
				if trait and trait ~= "" then
					local traitInfo = getTraitInfo(trait, traitDataCache)
					if traitInfo then
						Template.TraitIcon.Visible = true
						Template.TraitIcon.Image = traitInfo.ImageID
						Template.TraitIcon.UIGradient.Color = TraitsModule.TraitColors[traitInfo.Rarity].Gradient
						Template.TraitIcon.UIGradient.Rotation = TraitsModule.TraitColors[traitInfo.Rarity].GradientAngle
						TweenService:Create(Template.TraitIcon.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
					end
				end

				if Unit:GetAttribute("Shiny") then
					Template.Shiny.Visible = true
				end

				local isTraitMythical = false
				if trait then
					isTraitMythical = isTraitMythicalOrBetter(trait, traitDataCache)
				end

				if Data.AutoSell and not Unit:GetAttribute("Shiny") and not isTraitMythical then
					Template.Sold.Visible = true
					TweenService:Create(Template.Sold.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
				end

				local ViewPort = ViewPortModule.CreateViewPort(Unit.Name)
				ViewPort.Parent = Template
				ViewPort.ZIndex = 7

				GradientsModule.addRarityGradient({Template.Image, Template.GlowEffect}, UnitStats.Rarity)
				table.insert(templates, Template)

				--MedalLib.triggerClip('UNIT_SUMMON', `{${UnitStats.Rarity}} {${Unit.Name}}`, {player}, {"SaveClip"}, {duration = 30})
			end
		elseif Skip and Data.Item then
			local item = Data.Item
			local Template = SkipFrame.Frame.TemplateButton:Clone()
			Template.Name = item.Name
			Template.LayoutOrder = towerindex
			Template.Visible = true
			Template.Parent = SkipFrame.Frame
			Template.UIScale.Scale = 0

			local ViewPort = ViewPortModule.CreateViewPort("Star")
			ViewPort.Parent = Template
			GradientsModule.addRarityGradient({Template.Image, Template.GlowEffect}, itemStatsModule.Star.Rarity)
			table.insert(templates, Template)
			shouldConfetti = true
		else
			local tower = Data.Tower
			if tower then
				UiHandler.PlaySound("Redeem")
				setSummonVisible(false)
				local Tower = GetUnitModel[tower.Name]
				local statsTower = Upgrades[tower.Name]

				local trait = tower:GetAttribute("Trait")
				local isTraitMythical = false
				if trait and trait ~= "" then
					isTraitMythical = isTraitMythicalOrBetter(trait, traitDataCache)
				end

				if Data.AutoSell and not tower:GetAttribute("Shiny") and not isTraitMythical then
					_G.Message("Unit Sold", Color3.fromRGB(255, 170, 0), true)
				end

				if Tower and statsTower then
					--MedalLib.triggerClip('UNIT_SUMMON', `{${statsTower.Rarity}} {${Tower.Name}}`, {player}, {"SaveClip"}, {duration = 30})
					if statsTower.Rarity == "Mythical" then
						shouldConfetti = true
					end

					local nextUnit = false
					ViewModule.Hatch({statsTower, tower, function() nextUnit = true end, false, AutoSummon})
					repeat task.wait() until nextUnit
				end
			elseif Data.Item then
				local item = Data.Item
				local nextItem = false
				shouldConfetti = true
				UiHandler.PlaySound("Redeem")
				setSummonVisible(false)
				ViewModule.Item({itemStatsModule.Star, item, function() nextItem = true end, "1", AutoSummon})
				repeat task.wait() until nextItem
			end
		end
	end

	if shouldConfetti then
		UiHandler.CreateConfetti()
	end

	--if Skip then
	--	task.wait(2)
	--end

	task.defer(function() -- 0.2, delay
		task.wait(0.2)
		for _, template in templates do
			local UIScale = template:FindFirstChild("UIScale")
			if UIScale then
				TweenService:Create(UIScale, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {Scale = 1}):Play()
			end
		end
	end)

	task.defer(function() -- 0.6
		task.wait(0.6)

		--warn('kaboom')

		if Skip then
			task.wait(1.5)
			TweenService:Create(SkipFrame.UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Exponential), {Scale = 0}):Play()
		end

		for _, v in SkipFrame.Frame:GetChildren() do
			if v:IsA("TextButton") and v.Name ~= "TemplateButton" then
				v:Destroy()
			end
		end

		local shouldShowSummonSummary = not AutoSummon
			and summonSummary ~= nil
			and typeof(_G.ShowRewardPopupSummary) == "function"

		_G.canSummon = true
		setAutomaticRewardPopupSuppressed(false)

		if shouldShowSummonSummary then
			summonSummaryPending = true
			setSummonVisible(false)
			setRewardPopupClosedCallback(function()
				summonSummaryPending = false
				setSummonVisible(true)
			end)
			_G.ShowRewardPopupSummary(summonSummary)
		else
			summonSummaryPending = false
			setRewardPopupClosedCallback(nil)
			setSummonVisible(true)
		end

		if AutoSummon then
			summon(1, HolocronSummon)
		end
	end)

	if not ReplicatedStorage:FindFirstChild('SummonDone') then
		Instance.new('BoolValue', ReplicatedStorage).Name = 'SummonDone'
	end

	conn:Disconnect()
	conn = nil
	NewUIBlur.Enabled = true
end



local ForceSummon = ReplicatedStorage.Remotes.ForceSummon
local Functions = ReplicatedStorage.Functions
local summonBannerEvent = Functions:WaitForChild("SummonBannerEvent")

local autoSummonButton = SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Auto_Summon
local autoColorSeqBottom  = autoSummonButton.Contents.UIGradient.Color
local autoColorSeq = autoSummonButton.Contents.Contents.UIGradient.Color -- Track base color
local toggleColorSeqBottom = ColorSequence.new(Color3.new(0.462745, 0, 0)) -- Bottom part of the button (I suck at naming things)
local toggleColorSeq = ColorSequence.new(Color3.new(255,0,0)) -- Top part of the button

local function connectGuiButtonOnce(button, attributeName, callback)
	if not button or not button:IsA("GuiButton") or button:GetAttribute(attributeName) then
		return
	end

	button:SetAttribute(attributeName, true)
	button.Activated:Connect(callback)
end

local function setGuiInteractivity(target, isActive)
	if not (target and target:IsA("GuiObject")) then
		return
	end

	pcall(function()
		target.Active = isActive
	end)

	pcall(function()
		target.Selectable = isActive
	end)
end

local function prepareBannerSelectionCard(card)
	if not (card and card:IsA("GuiObject")) then
		return
	end

	setGuiInteractivity(card, true)

	for _, descendant in ipairs(card:GetDescendants()) do
		if descendant:IsA("GuiButton") then
			setGuiInteractivity(descendant, true)
		elseif descendant:IsA("GuiObject") then
			setGuiInteractivity(descendant, false)
		end
	end
end

local function wireNewSummonButtons()
	local newSummons = getNewSummonsFrame()
	if not newSummons then return end

	connectGuiButtonOnce(findChildPath(newSummons, {"Body", "Closebtn", "Btn"}), "SummonCloseBound", closeSummonMenu)
	connectGuiButtonOnce(findFirstGuiButton(findChildPath(newSummons, {"Body", "Main", "Banner", "Buttons", "1"})), "SummonLuckyBound", function()
		summon(1, nil, true)
	end)
	connectGuiButtonOnce(findFirstGuiButton(findChildPath(newSummons, {"Body", "Main", "Banner", "Buttons", "2"})), "Summon1xBound", function()
		summon(1)
	end)
	connectGuiButtonOnce(findFirstGuiButton(findChildPath(newSummons, {"Body", "Main", "Banner", "Buttons", "3"})), "Summon10xBound", function()
		summon(10)
	end)
	connectGuiButtonOnce(findFirstGuiButton(findChildPath(newSummons, {"Body", "Main", "Banner", "Buttons", "4"})), "AutoSummonBound", function()
		ExitFrame.Visible = true
		AutoSummon = true
		updateNewAutoSummonVisual()
		summon(1)
	end)

	for rarityName, buttonIndex in pairs(AutoSellButtonOrder) do
		local targetRarityName = rarityName
		local buttonRoot = getNewAutoSellButtonRoot(newSummons, rarityName)
		connectGuiButtonOnce(findFirstGuiButton(buttonRoot), "AutoSellBound", function()
			local rarityObject = player:WaitForChild("AutoSell"):FindFirstChild(targetRarityName)
			local nextState = not (rarityObject and rarityObject.Value)
			setNewAutoSellButtonState(targetRarityName, nextState)
			SetAutoSellEvent:FireServer(targetRarityName, nextState)
		end)
	end
end

local function wireNewSummonSelection()
	local newSummons = getNewSummonsFrame()
	local selection = newSummons and findChildPath(newSummons, {"Selection", "Banners"})
	if not selection then return end

	for index = 1, 3 do
		local targetIndex = index
		local card = selection:FindFirstChild(tostring(targetIndex))
		prepareBannerSelectionCard(card)
		local button = (card and card:IsA("GuiButton") and card) or findFirstGuiButton(card)

		connectGuiButtonOnce(button, "BannerSelectBound", function()
			currentBannerIndex = targetIndex
			updateNewSummonPreview()
		end)
	end
end


ForceSummon.OnClientEvent:Connect(function()
	--print('we have been forced to summon!')
	summon(1)
end)


SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Summon_1x.Activated:Connect(function() summon(1) end)
SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Summon_10x.Activated:Connect(function() summon(10) end)
SummonFrame.Banner.Summon_Holocron.Activated:Connect(function() summon(1,true) end)
SummonFrame.Banner.Bottom_Bar.Bottom_Bar.Lucky_Summons.Activated:Connect(function() summon(1, nil, true) end)

ExitFrame.Trigger.Activated:Connect(function()
	AutoSummon = false
	ExitFrame.Visible = false
	updateNewAutoSummonVisual()
end)

autoSummonButton.Activated:Connect(function()
	ExitFrame.Visible = true

	AutoSummon = true
	updateNewAutoSummonVisual()
	summon(1)
end)



player:WaitForChild("MythicalPity").Changed:Connect(function()
	script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Bar.Size = UDim2.fromScale(player.MythicalPity.Value/400,1)
	script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Pity.Text = player.MythicalPity.Value.."/"..400

	--script.Parent.SummonFrame.Banner.Mythical.ProgressBar.Size = UDim2.new(player.MythicalPity.Value/400,0,1,0)
	--script.Parent.SummonFrame.Banner.Mythical.NumberLabel.Text = player.MythicalPity.Value.."/"..400
end)

player:WaitForChild("LegendaryPity").Changed:Connect(function()
	script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Bar.Size = UDim2.fromScale(player.LegendaryPity.Value/200,1)
	script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Pity.Text = player.LegendaryPity.Value.."/"..200
	-- 26/400

	--script.Parent.SummonFrame.Banner.Legendary.ProgressBar.Size = UDim2.new(player.LegendaryPity.Value/200,0,1,0)
	--script.Parent.SummonFrame.Banner.Legendary.NumberLabel.Text = player.LegendaryPity.Value.."/"..200
end)

task.wait(1)

script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Bar.Size = UDim2.fromScale(player.MythicalPity.Value/400,1)
script.Parent.SummonFrame.Banner.Pity_Bars.Mythical_Pity.Contents.Pity.Text = player.MythicalPity.Value.."/"..400

script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Bar.Size = UDim2.fromScale(player.LegendaryPity.Value/200,1)
script.Parent.SummonFrame.Banner.Pity_Bars.Legendary_Pity.Contents.Pity.Text = player.LegendaryPity.Value.."/"..200

task.wait(3)
wireNewSummonButtons()
wireNewSummonSelection()
populateNewSummonGemShop()
updateNewSummonCurrencies()
updateNewAutoSummonVisual()
updateBanner()

player.Coins.Changed:Connect(updateNewSummonCurrencies)
player.Gems.Changed:Connect(updateNewSummonCurrencies)
player.LuckySpins.Changed:Connect(updateNewSummonCurrencies)

IndexButton.MouseButton1Down:Connect(function()

	_G.CloseAll()

	ChancesFrame.Visible = true

end)

--ChancesFrame.Close.MouseButton1Down:Connect(function()

--	ChancesFrame.Visible = false
--	_G.CloseAll("SummonFrame")
--end)

SummonFrame.Side_Shop.Contents.Lucky_Crystal.Contents.Buy.MouseButton1Down:Connect(function()
	MarketPlaceService:PromptProductPurchase(player,MarketModule.Items[1].ProductID)
end)
SummonFrame.Side_Shop.Contents["Fortunate Crystal"].Contents.Buy.MouseButton1Down:Connect(function()
	MarketPlaceService:PromptProductPurchase(player,MarketModule.Items[2].ProductID)
end)

local PassesList = require(ReplicatedStorage.Modules.PassesList)

local function findProductID(id)
	local result = nil

	for i,v in MarketModule.Gems do
		if v.Name == id then
			result = v.ProductID
			break
		end
	end

	if not result then
		if PassesList.Information[id] then
			result = PassesList.Information[id].Id
		end
	end

	return result
end

-- shop
for i,v in SummonFrame.Side_Shop.Contents:GetChildren() do
	if v:IsA('Frame') and not string.match(v.Name, "Crystal") then
		v.Contents.Buy.Activated:Connect(function()
			MarketPlaceService:PromptProductPurchase(player, findProductID(v.Name))
		end)
	end
end



function UpdateAutoSell()
	for _, rarityObject in player:WaitForChild("AutoSell"):GetChildren() do
		local rarityButton = SummonFrame.Banner.Sell_Menu.Select_Rarity:FindFirstChild(rarityObject.Name)
		if not rarityButton then continue end
		rarityButton.IsActive.Value = rarityObject.Value
		if rarityButton.IsActive.Value  then
			rarityButton.Contents.Lines.UIGradient.Enabled = false
			rarityButton.Contents.Lines.ImageColor3 = Color3.fromRGB(0,255,0)
		else
			rarityButton.Contents.Lines.UIGradient.Enabled = true
			rarityButton.Contents.Lines.ImageColor3 = Color3.fromRGB(255,255,255)
		end

		setNewAutoSellButtonState(rarityObject.Name, rarityObject.Value)
	end
end

for _,object in SummonFrame.Banner.Sell_Menu.Select_Rarity:GetChildren() do
	if not object:IsA("GuiButton") then continue end
	object.Activated:Connect(function()
		object.IsActive.Value = not object.IsActive.Value
		--if object:FindFirstChild("ActiveImage") then
		if object.IsActive.Value  then
			object.Contents.Lines.UIGradient.Enabled = false
			object.Contents.Lines.ImageColor3 = Color3.fromRGB(0,255,0)
		else
			object.Contents.Lines.UIGradient.Enabled = true
			object.Contents.Lines.ImageColor3 = Color3.fromRGB(255,255,255)
		end
		--end
		SetAutoSellEvent:FireServer(object.Name, object.IsActive.Value)
	end)
end

for _, rarityObject in player:WaitForChild("AutoSell"):GetChildren() do
	rarityObject.Changed:Connect(UpdateAutoSell)
end

player:WaitForChild("AutoSell").ChildAdded:Connect(function(child)
	child.Changed:Connect(UpdateAutoSell)
	UpdateAutoSell()
end)
player:WaitForChild("AutoSell").ChildRemoved:Connect(UpdateAutoSell)
UpdateAutoSell()

MarketPlaceService.PromptProductPurchaseFinished:Connect(function(userID,productID,isPurchased)
	if not isPurchased then return end

	--if productID == 2659785711 then
	--	script.Sounds.Redeem:Play()
	--	local towerStats = Upgrades["Frenk"]
	--	ViewModule.Hatch({
	--		towerStats,
	--		game.Players.LocalPlayer.OwnedTowers:WaitForChild("Frenk")
	--	})
	--	_G.CloseAll()
	--	return
	--end

	--if productID == 2675907803 or 2678784918 or 2678786531 or 2678798950 then
	--	script.Sounds.Redeem:Play()
	--	local towerStats = Upgrades["Ice Man"]
	--	ViewModule.Hatch({
	--		towerStats,
	--		script.Units["Ice Man"]
	--	})
	--	_G.CloseAll()
	--	return
	--end

	local itemName do
		for _,info in MarketModule.Items do
			if info.ProductID == productID then
				itemName = info.Name
				break
			end
		end
	end

	if itemName == nil then return end
	local itemStats = itemStatsModule[itemName]
	ViewModule.Item({
		itemStats
	})

end)

local function numbertotime(number)
	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) %60
	local Seconds = math.floor(number % 60)

	if Mintus < 10 and Hours > 0 then
		Mintus = "0"..Mintus
	end

	if Seconds < 10 then
		Seconds = "0"..Seconds
	end

	if Hours > 0 then
		return `{Hours}:{Mintus}:{Seconds}`
	else
		return `{Mintus}:{Seconds}`
	end
end



local wasOpen = false
local onCooldown = false

local Zone = require(ReplicatedStorage.Modules.Zone)
local zone = Zone.new(workspace.SummonTeleporters.SummonArea)

--local zone = zone.fromRegion(workspace.SummonTeleporters.SummonArea.CFrame, workspace.SummonTeleporters.SummonArea.Size)

--warn('ACCTIVATEAHFUSAHDUIFAS')

zone.playerEntered:Connect(function(plr)
	if plr.Character:FindFirstChild('Humanoid') and plr == player then	
		if not game.Workspace.CurrentCamera:FindFirstChild("DepthOfField") then
			local depthOfField = Instance.new("DepthOfFieldEffect",game.Workspace.CurrentCamera)
		end

		debugSummonOpen(
			"zone:entered",
			"player=" .. tostring(plr.Name),
			"newExists=" .. tostring(getNewSummonsFrame() ~= nil),
			"legacyVisible=" .. tostring(SummonFrame.Visible)
		)
		openPreferredSummonMenu()
		UiHandler.DisableAllButtons()
	end
end)
zone.playerExited:Connect(function(plr)
	if not plr then return end
	local character = plr.Character or plr.CharacterAdded:Wait()
	if not character then return end

	if character:FindFirstChild('Humanoid') and plr == player then	
		if game.Workspace.CurrentCamera:FindFirstChild("DepthOfField") then
			game.Workspace.CurrentCamera:FindFirstChild("DepthOfField"):Destroy()
		end
		debugSummonOpen(
			"zone:exited",
			"player=" .. tostring(plr.Name),
			"newVisible=" .. tostring(getNewSummonsFrame() and getNewSummonsFrame().Visible),
			"legacyVisible=" .. tostring(SummonFrame.Visible)
		)
		closePreferredSummonMenu()
		--ChancesFrame.Visible = false
		UiHandler.EnableAllButtons()
	end
end)



local function ChangeChances(multiplayer,rareChance)
	local NoLuckChances = {
		Mythical = 0.1,
		Legendary = 1,
		Epic = 14.6,
		Rare = 27.7,
	}
	for Rarity, Chance in NoLuckChances do
		for i, v in SummonFrame.Banner:GetDescendants() do
			if v.Name == Rarity.."Chance" then
				if multiplayer ~= nil then
					if v.Name == "MythicalChance" and multiplayer == 1.5 then
						v.Text = 0.15 .. "%"
					else
						if v.Name ~= "RareChance" then
							v.Text = Chance * multiplayer .. "%"
						else
							v.Text = rareChance .. "%"
						end
					end
				else
					v.Text = Chance .. "%"
				end
			end
		end
	end
end

while true do
	task.wait(1)
	wireNewSummonButtons()
	wireNewSummonSelection()
	populateNewSummonGemShop()

	if player.Items["Holocron Summon Cube"].Value > 0 then
		SummonFrame.Banner.Summon_Holocron.Visible = true
	else
		SummonFrame.Banner.Summon_Holocron.Visible = false
	end
	SummonFrame.Banner.PriceLabel.Text = getSingleSummonCost()

	local untilNextHourToSeconds =  ( (math.floor( os.time()/1800 ) + 1) * 1800 ) - os.time()
	local timerText = formatBannerCountdown(untilNextHourToSeconds)

	--SummonFrame.Banner["Banner Timer"].Text = `Refreshes in: {currentMinutePerHour}:{string.format("%.2i",seconds)}`
	SummonFrame.Banner.Contents.Refresh_Bar.Contents.Timer.Text = timerText
	updateNewSummonTimer(untilNextHourToSeconds)
	updateNewSummonCurrencies()

	script.Parent.Buffs.Visible = true
	for i, v in script.Parent.Buffs:GetChildren() do
		if v:IsA("ImageLabel") and player.Buffs:FindFirstChild(v.Name) then
			--warn('VIBE CHECK THEY HAVE IT!' .. v.Name)
			local buff = player.Buffs:FindFirstChild(v.Name)
			local duration = numbertotime(math.max((buff.StartTime.Value + buff.Duration.Value) - os.time(),0))
			v.BuffText.Text = `x{buff.Multiplier.Value}: {duration}`
			if v.Visible == false then
				v.Visible = true
			end
		elseif v:IsA("ImageLabel") and not player.Buffs:FindFirstChild(v.Name) then
			if v.Visible == true then
				v.Visible = false
			end
		end
	end
	local Buffs = script.Parent.Buffs
	local LuckText = SummonFrame.Banner.LuckText
	local Colors = script.LuckTextColors

	local activeBuffs = {
		{
			name = "LuckyCrystal",
			multiplier = 1.5,
			chance = 25.1,
			text = "x1.5 Luck",
			gradient = Colors.LuckyCrystalG.Color,
			stroke = Colors.LuckyCrystalS.Color,
		},
		{
			name = "FortunateCrystal",
			multiplier = 2,
			chance = 22.5,
			text = "x2 Luck",
			gradient = Colors.UltraLuckG.Color,
			stroke = Colors.UltraLuckS.Color,
		},
	}

	local totalMultiplier = 1
	local selectedBuff = nil

	for _, buff in ipairs(activeBuffs) do
		if Buffs[buff.name].Visible then
			totalMultiplier *= buff.multiplier
			if not selectedBuff or buff.multiplier > selectedBuff.multiplier then
				selectedBuff = buff
			end
		end
	end

	if selectedBuff then
		-- Adjust chance however you want; here just using the chance from the most powerful buff
		ChangeChances(totalMultiplier, selectedBuff.chance)

		if player.OwnGamePasses['x2 Luck'].Value then
			totalMultiplier += 1
		end

		LuckText.Text = "x" .. totalMultiplier .. " Luck"
		LuckText.UIGradient.Color = selectedBuff.gradient
		LuckText.UIStroke.Color = selectedBuff.stroke
		updateNewSummonLuckLabel(LuckText.Text, selectedBuff.gradient, selectedBuff.stroke)
	else
		ChangeChances(nil)

		if player.OwnGamePasses['x2 Luck'].Value then
			LuckText.Text = "x2 Luck"
		else
			LuckText.Text = "x1 Luck"
		end

		LuckText.UIGradient.Color = CS{CSK(0, C3(.75, .75, .75)), CSK(1, C3(1, 1, 1))}
		LuckText.UIStroke.Color = Color3.new(0.494118, 0.494118, 0.494118)
		updateNewSummonLuckLabel(LuckText.Text, LuckText.UIGradient.Color, LuckText.UIStroke.Color)
	end

end
