--!strict

local GachaGuiUtil = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundController = require(ReplicatedStorage.Controllers.SoundController)

local NormalizedNameCache: {[string]: string} = {}
local DescendantLookupCacheByRoot: {[Instance]: {[string]: Instance}} =
	setmetatable({}, { __mode = "k" }) :: {[Instance]: {[string]: Instance}}
local RARITY_BUTTON_CLICK_INFO = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RARITY_BUTTON_BOUNCE_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RARITY_BUTTON_HOVER_SCALE = 1.07
local RARITY_BUTTON_PRESS_SCALE = 0.94
local RARITY_SECTION_TWEEN_INFO = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RARITY_LABEL_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RARITY_SECTION_PADDING = 2
local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)

local function getLighterRarityTextColor(color: Color3): Color3
	return color:Lerp(WHITE, 0.18)
end

local function getDarkerRarityTextColor(color: Color3): Color3
	return color:Lerp(BLACK, 0.22)
end

local function getCachedNormalizedName(name: string): string
	local cached = NormalizedNameCache[name]
	if cached then
		return cached
	end
	local normalized = string.lower(name:gsub("[^%w]", ""))
	NormalizedNameCache[name] = normalized
	return normalized
end

local function normalizeLookupNames(names: {string}): ({string}, {[string]: boolean})
	local normalizedNames: {string} = {}
	local normalizedSet: {[string]: boolean} = {}
	for _, name in ipairs(names) do
		local normalizedName = getCachedNormalizedName(name)
		if not normalizedSet[normalizedName] then
			normalizedSet[normalizedName] = true
			table.insert(normalizedNames, normalizedName)
		end
	end
	table.sort(normalizedNames)
	return normalizedNames, normalizedSet
end

local function buildLookupCacheKey(normalizedNames: {string}, className: string?): string
	local classPart = className or "*"
	return classPart .. "::" .. table.concat(normalizedNames, "|")
end

local function getRootLookupCache(root: Instance): {[string]: Instance}
	local cache = DescendantLookupCacheByRoot[root]
	if cache then
		return cache
	end
	cache = {}
	DescendantLookupCacheByRoot[root] = cache
	return cache
end

local function isCachedResultValid(
	root: Instance,
	candidate: Instance?,
	className: string?,
	nameSet: {[string]: boolean}
): boolean
	if not candidate then
		return false
	end
	if candidate ~= root and not candidate:IsDescendantOf(root) then
		return false
	end
	if className and not candidate:IsA(className) then
		return false
	end
	return nameSet[getCachedNormalizedName(candidate.Name)] == true
end

function GachaGuiUtil.FormatMoney(value: any): string
	local formatted = tostring(value)
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

function GachaGuiUtil.GetColorFromData(data: any): Color3
	if data and data.Rarity and data.Rarity.Color then
		return data.Rarity.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

function GachaGuiUtil.ToColorSequence(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, color),
	})
end

function GachaGuiUtil.NormalizeUiName(value: any): string
	return getCachedNormalizedName(tostring(value))
end

function GachaGuiUtil.MatchesAnyName(instance: Instance, names: { string }): boolean
	local normalizedName = GachaGuiUtil.NormalizeUiName(instance.Name)
	for _, name in ipairs(names) do
		if normalizedName == getCachedNormalizedName(name) then
			return true
		end
	end
	return false
end

function GachaGuiUtil.FindDescendantByNames(root: Instance?, names: { string }, className: string?): Instance?
	if not root then
		return nil
	end

	local normalizedNames, normalizedSet = normalizeLookupNames(names)
	local cacheKey = buildLookupCacheKey(normalizedNames, className)
	local rootCache = getRootLookupCache(root)
	local cachedResult = rootCache[cacheKey]
	if isCachedResultValid(root, cachedResult, className, normalizedSet) then
		return cachedResult
	end
	rootCache[cacheKey] = nil

	if (not className or root:IsA(className)) and normalizedSet[getCachedNormalizedName(root.Name)] == true then
		rootCache[cacheKey] = root
		return root
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if className and not descendant:IsA(className) then
			continue
		end
		if normalizedSet[getCachedNormalizedName(descendant.Name)] == true then
			rootCache[cacheKey] = descendant
			return descendant
		end
	end
	return nil
end

function GachaGuiUtil.FindDirectChildByNames(root: Instance?, names: { string }, className: string?): Instance?
	if not root then
		return nil
	end

	for _, name in ipairs(names) do
		local child = root:FindFirstChild(name)
		if child and (not className or child:IsA(className)) then
			return child
		end
	end

	return nil
end

function GachaGuiUtil.FindMain(gui: ScreenGui): Instance?
	return gui:FindFirstChild("Main")
		or GachaGuiUtil.FindDescendantByNames(gui, { "Main" }, nil)
		or gui:FindFirstChildWhichIsA("Frame")
end

function GachaGuiUtil.FindGuiButtonByNames(root: Instance?, names: { string }): GuiButton?
	local found = GachaGuiUtil.FindDescendantByNames(root, names, "GuiButton")
	return if found and found:IsA("GuiButton") then found else nil
end

function GachaGuiUtil.FindTextLabelByNames(root: Instance?, names: { string }): TextLabel?
	local found = GachaGuiUtil.FindDescendantByNames(root, names, "TextLabel")
	return if found and found:IsA("TextLabel") then found else nil
end

function GachaGuiUtil.FindTopContainer(main: Instance?): Instance?
	return GachaGuiUtil.FindDirectChildByNames(main, { "Top" }, nil)
		or GachaGuiUtil.FindDescendantByNames(main, { "Top" }, nil)
end

function GachaGuiUtil.FindBottomLeftContainer(main: Instance?): Instance?
	return GachaGuiUtil.FindDirectChildByNames(main, { "BottomLeft" }, nil)
		or GachaGuiUtil.FindDescendantByNames(main, { "BottomLeft" }, nil)
end

function GachaGuiUtil.FindBottomMiddleContainer(main: Instance?): Instance?
	return GachaGuiUtil.FindDirectChildByNames(main, { "BottomMiddle" }, nil)
		or GachaGuiUtil.FindDescendantByNames(main, { "BottomMiddle" }, nil)
end

function GachaGuiUtil.FindLeftContainer(main: Instance?): Instance?
	return GachaGuiUtil.FindDirectChildByNames(main, { "Left" }, nil)
		or GachaGuiUtil.FindDescendantByNames(main, { "Left" }, nil)
end

function GachaGuiUtil.FindTopRightContainer(main: Instance?): Instance?
	return GachaGuiUtil.FindDirectChildByNames(main, { "TopRight" }, nil)
		or GachaGuiUtil.FindDescendantByNames(main, { "TopRight" }, nil)
end

function GachaGuiUtil.FindTopRightNormalContainer(main: Instance?): Instance?
	local topRight = GachaGuiUtil.FindTopRightContainer(main)
	if not topRight then
		return nil
	end

	return GachaGuiUtil.FindDirectChildByNames(topRight, { "Normal" }, nil)
		or GachaGuiUtil.FindDescendantByNames(topRight, { "Normal" }, nil)
		or GachaGuiUtil.FindDirectChildByNames(topRight, { "Frame" }, nil)
end

function GachaGuiUtil.FindTopNameLabel(main: Instance?): TextLabel?
	local top = GachaGuiUtil.FindTopContainer(main)
	local label = GachaGuiUtil.FindDirectChildByNames(top, { "NameStyle", "Name Style" }, "TextLabel")
	if label and label:IsA("TextLabel") then
		return label
	end

	return GachaGuiUtil.FindTextLabelByNames(top, { "NameStyle", "Name Style" })
end

function GachaGuiUtil.FindDescriptionLabel(
	root: Instance?,
	descriptionFrameNames: { string }?,
	descriptionNames: { string }?
): TextLabel?
	local top = GachaGuiUtil.FindTopContainer(root)
	local descriptionFrame = GachaGuiUtil.FindDirectChildByNames(top, descriptionFrameNames or { "DescriptionFrame" }, nil)
		or GachaGuiUtil.FindDescendantByNames(top, descriptionFrameNames or { "DescriptionFrame" }, nil)
	if descriptionFrame then
		local label = GachaGuiUtil.FindDirectChildByNames(descriptionFrame, descriptionNames or { "Description" }, "TextLabel")
		if label and label:IsA("TextLabel") then
			return label
		end

		label = GachaGuiUtil.FindTextLabelByNames(descriptionFrame, descriptionNames or { "Description" })
		if label then
			return label
		end
	end

	return nil
end

function GachaGuiUtil.FindBottomMiddleButton(main: Instance?, buttonNames: { string }): GuiButton?
	local bottomMiddle = GachaGuiUtil.FindBottomMiddleContainer(main)
	local button = GachaGuiUtil.FindDirectChildByNames(bottomMiddle, buttonNames, "GuiButton")
	if button and button:IsA("GuiButton") then
		return button
	end

	return GachaGuiUtil.FindGuiButtonByNames(bottomMiddle, buttonNames)
end

function GachaGuiUtil.FindBottomLeftExitButton(main: Instance?): GuiButton?
	local bottomLeft = GachaGuiUtil.FindBottomLeftContainer(main)
	local exitButton = GachaGuiUtil.FindDirectChildByNames(bottomLeft, { "Exit" }, "GuiButton")
	if exitButton and exitButton:IsA("GuiButton") then
		return exitButton
	end

	return GachaGuiUtil.FindGuiButtonByNames(bottomLeft, { "Exit" })
end

function GachaGuiUtil.FindFirstTextLabel(root: Instance?): TextLabel?
	if not root then
		return nil
	end
	if root:IsA("TextLabel") then
		return root
	end
	local found = root:FindFirstChildWhichIsA("TextLabel", true)
	return if found and found:IsA("TextLabel") then found else nil
end

function GachaGuiUtil.FindSlotItemNameLabel(slotButton: ImageButton): TextLabel?
	local descriptionLabel = GachaGuiUtil.FindDirectChildByNames(slotButton, { "Description" }, "TextLabel")
	if descriptionLabel and descriptionLabel:IsA("TextLabel") then
		return descriptionLabel
	end

	for _, child in ipairs(slotButton:GetChildren()) do
		if child:IsA("TextLabel") and GachaGuiUtil.MatchesAnyName(child, { "Description" }) then
			return child
		end
	end

	for _, descendant in ipairs(slotButton:GetDescendants()) do
		if descendant:IsA("TextLabel") and GachaGuiUtil.MatchesAnyName(descendant, { "Description" }) then
			local currentParent = descendant.Parent
			local insideExtension = false
			while currentParent and currentParent ~= slotButton do
				if GachaGuiUtil.MatchesAnyName(currentParent, { "Extension" }) then
					insideExtension = true
					break
				end
				currentParent = currentParent.Parent
			end

			if not insideExtension then
				return descendant
			end
		end
	end

	local itemNameLabel = GachaGuiUtil.FindTextLabelByNames(slotButton, { "ItemName", "Item Name" })
	if itemNameLabel then
		return itemNameLabel
	end

	return GachaGuiUtil.FindFirstTextLabel(slotButton)
end

function GachaGuiUtil.FindSlotExtension(slotButton: ImageButton): Instance?
	return GachaGuiUtil.FindDirectChildByNames(slotButton, { "Extension" }, nil)
		or GachaGuiUtil.FindDescendantByNames(slotButton, { "Extension" }, nil)
end

function GachaGuiUtil.FindSlotExtensionDescriptionLabel(slotButton: ImageButton): TextLabel?
	local extension = GachaGuiUtil.FindSlotExtension(slotButton)
	if not extension then
		return nil
	end

	local descriptionLabel = GachaGuiUtil.FindDirectChildByNames(extension, { "Description" }, "TextLabel")
	if descriptionLabel and descriptionLabel:IsA("TextLabel") then
		return descriptionLabel
	end

	return GachaGuiUtil.FindTextLabelByNames(extension, { "Description" })
end

function GachaGuiUtil.SetVisibleOnInstance(target: Instance?, visible: boolean): ()
	if target and target:IsA("GuiObject") then
		target.Visible = visible
	end
end

function GachaGuiUtil.FindSlotScrollingFrame(gui: ScreenGui): ScrollingFrame?
	local main = GachaGuiUtil.FindMain(gui)
	if not main then
		return nil
	end

	local left = GachaGuiUtil.FindLeftContainer(main)
	local oldScrollingFrame = left and left:FindFirstChild("ScrollingFrame")
	if oldScrollingFrame and oldScrollingFrame:IsA("ScrollingFrame") then
		return oldScrollingFrame
	end

	local nestedLeftScrollingFrame = left and left:FindFirstChild("ScrollingFrame", true)
	if nestedLeftScrollingFrame and nestedLeftScrollingFrame:IsA("ScrollingFrame") then
		return nestedLeftScrollingFrame
	end

	local fallback: ScrollingFrame? = nil
	for _, descendant in ipairs(main:GetDescendants()) do
		if not descendant:IsA("ScrollingFrame") then
			continue
		end

		for _, child in ipairs(descendant:GetChildren()) do
			if child:IsA("ImageButton") then
				fallback = fallback or descendant
				if child:FindFirstChild("Lock", true) or child:FindFirstChild("Extension", true) or child:GetAttribute("SlotIndex") then
					return descendant
				end
			end
		end
	end

	return fallback
end

function GachaGuiUtil.GetSlotButtons(scrollingFrame: ScrollingFrame): { ImageButton }
	local buttons = {}
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("ImageButton") then
			table.insert(buttons, child)
		end
	end

	table.sort(buttons, function(a, b)
		local aOrder = a.LayoutOrder
		local bOrder = b.LayoutOrder
		if aOrder == bOrder then
			return a.Name < b.Name
		end
		return aOrder < bOrder
	end)

	return buttons
end

function GachaGuiUtil.EnsureSlotButtons(
	scrollingFrame: ScrollingFrame,
	maxSlots: number,
	slotPrefix: string,
	clickHandledAttributeName: string?
): { ImageButton }
	local buttons = GachaGuiUtil.GetSlotButtons(scrollingFrame)
	local template = buttons[1]
	if not template then
		return buttons
	end

	while #buttons < maxSlots do
		local clone = template:Clone()
		clone.Name = slotPrefix .. tostring(#buttons + 1)
		clone.Parent = scrollingFrame
		table.insert(buttons, clone)
	end

	for index, button in ipairs(buttons) do
		if index > maxSlots then
			button:SetAttribute("SlotIndex", index)
			button.Visible = false
			continue
		end

		button.Name = slotPrefix .. tostring(index)
		button.Visible = true
		button.LayoutOrder = index
		button:SetAttribute("SlotIndex", index)
		if clickHandledAttributeName and clickHandledAttributeName ~= "" then
			button:SetAttribute(clickHandledAttributeName, true)
		end
	end

	return GachaGuiUtil.GetSlotButtons(scrollingFrame)
end

function GachaGuiUtil.GetSelectedSlot(
	playerDataManager: any,
	player: Player,
	paths: { { string } },
	maxSlots: number,
	defaultSlot: number?
): number
	for _, path in ipairs(paths) do
		local selected = playerDataManager:Get(player, path)
		if typeof(selected) == "number" then
			return math.clamp(math.floor(selected), 1, maxSlots)
		end
	end

	return math.clamp(defaultSlot or 1, 1, maxSlots)
end

function GachaGuiUtil.GetSlotKey(slotIndex: number, slotPrefix: string?): string
	return (slotPrefix or "Slot") .. tostring(slotIndex)
end

function GachaGuiUtil.IsSlotUnlocked(unlockedSlots: { any }, slotIndex: number, freeSlotIndex: number?): boolean
	local resolvedFreeSlot = freeSlotIndex or 1
	if slotIndex == resolvedFreeSlot then
		return true
	end

	return table.find(unlockedSlots, slotIndex) ~= nil
end

local function getOrCreateRarityButtonScale(button: GuiButton): UIScale
	local existingScale = button:FindFirstChild("RarityButtonScale")
	if existingScale and existingScale:IsA("UIScale") then
		return existingScale
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "RarityButtonScale"
	uiScale.Scale = 1
	uiScale.Parent = button
	return uiScale
end

local function getRarityButtonGlow(button: GuiButton): GuiObject?
	local directGlow = button:FindFirstChild("Glow")
	if directGlow and directGlow:IsA("GuiObject") then
		return directGlow
	end

	local descendantGlow = GachaGuiUtil.FindDescendantByNames(button, { "Glow" }, nil)
	return if descendantGlow and descendantGlow:IsA("GuiObject") then descendantGlow else nil
end

local function tweenRarityButtonState(
	button: GuiButton,
	tweenService: TweenService,
	info: TweenInfo,
	scaleValue: number,
	rotationValue: number
): ()
	local uiScale = getOrCreateRarityButtonScale(button)
	tweenService:Create(uiScale, info, {
		Scale = scaleValue,
	}):Play()
	tweenService:Create(button, info, {
		Rotation = rotationValue,
	}):Play()
end

local function getEntryLabelOriginalState(entryLabel: TextLabel): {[string]: any}
	local strokeStates = {}
	for _, descendant in ipairs(entryLabel:GetDescendants()) do
		if descendant:IsA("UIStroke") then
			table.insert(strokeStates, {
				Instance = descendant,
				Transparency = descendant.Transparency,
			})
		end
	end

	return {
		Label = entryLabel,
		TextTransparency = entryLabel.TextTransparency,
		TextStrokeTransparency = entryLabel.TextStrokeTransparency,
		StrokeStates = strokeStates,
	}
end

local function getEntryLabelHeight(labelTemplate: TextLabel): number
	return math.max(labelTemplate.AbsoluteSize.Y, labelTemplate.Size.Y.Offset, labelTemplate.TextSize + 10, 24)
end

local function configureRarityEntryLabel(entryLabel: TextLabel, labelTemplate: TextLabel): ()
	local labelHeight = getEntryLabelHeight(labelTemplate)
	entryLabel.AutomaticSize = Enum.AutomaticSize.None
	entryLabel.Size = UDim2.new(1, 0, 0, labelHeight)
	entryLabel.TextScaled = false
	entryLabel.TextWrapped = false
	entryLabel.TextSize = math.max(labelTemplate.TextSize, math.floor(labelHeight * 0.5), 18)
end

local function trimTrailingZeroes(valueText: string): string
	local trimmedValue = valueText:gsub("0+$", "")
	trimmedValue = trimmedValue:gsub("%.$", "")
	return trimmedValue
end

local function formatRarityPercentageValue(percentageValue: any): string?
	if typeof(percentageValue) ~= "number" or percentageValue < 0 then
		return nil
	end

	local roundedValue = math.round(percentageValue * 100) / 100
	local formattedValue = trimTrailingZeroes(string.format("%.2f", roundedValue))
	if formattedValue == "" then
		formattedValue = "0"
	end

	return formattedValue .. "%"
end

local function getRarityButtonDisplayText(rarityName: string, groupData: any): string
	local formattedPercentage = formatRarityPercentageValue(groupData and groupData.Percentage)
	if formattedPercentage then
		return string.format("%s [%s]", rarityName, formattedPercentage)
	end

	return rarityName
end

local function resolveNestedTextLabel(
	root: Instance,
	containerNames: { string },
	preferredLabelNames: { string }?
): TextLabel?
	local container = GachaGuiUtil.FindDirectChildByNames(root, containerNames, nil)
		or GachaGuiUtil.FindDescendantByNames(root, containerNames, nil)
	if container then
		if container:IsA("TextLabel") then
			return container
		end

		if preferredLabelNames then
			local nestedLabel = GachaGuiUtil.FindDirectChildByNames(container, preferredLabelNames, "TextLabel")
			if nestedLabel and nestedLabel:IsA("TextLabel") then
				return nestedLabel
			end

			local descendantLabel = GachaGuiUtil.FindTextLabelByNames(container, preferredLabelNames)
			if descendantLabel then
				return descendantLabel
			end
		end

		local firstTextLabel = GachaGuiUtil.FindFirstTextLabel(container)
		if firstTextLabel then
			return firstTextLabel
		end
	end

	return GachaGuiUtil.FindTextLabelByNames(root, containerNames)
end

local function getRarityButtonFeaturedName(groupData: any, entryListKey: string?): string?
	if type(groupData) ~= "table" then
		return nil
	end

	local featuredName = groupData.FeaturedName or groupData.ButtonName or groupData.DisplayName
	if type(featuredName) == "string" and featuredName ~= "" then
		return featuredName
	end

	if entryListKey then
		local entryList = groupData[entryListKey]
		if type(entryList) == "table" and #entryList > 0 then
			local firstEntry = entryList[1]
			if type(firstEntry) == "string" and firstEntry ~= "" then
				return firstEntry
			end
		end
	end

	return nil
end

local function ensureTextLabelVisible(textLabel: TextLabel?): ()
	if not textLabel then
		return
	end

	textLabel.Visible = true
	local parent = textLabel.Parent
	if parent and parent:IsA("GuiObject") then
		parent.Visible = true
	end
end

function GachaGuiUtil.ConfigureRarityButtonDisplay(
	rarityButton: GuiButton,
	rarityName: string,
	groupData: any,
	entryListKey: string?
): ()
	local displayText = getRarityButtonDisplayText(rarityName, groupData)
	local featuredName = getRarityButtonFeaturedName(groupData, entryListKey)
	local rarityColor = if groupData and groupData.Color then groupData.Color else nil

	local percentageLabel = resolveNestedTextLabel(rarityButton, { "Porcentage", "Percentage", "Percent", "Chance" }, { "Text" })
	local rarityLabel = resolveNestedTextLabel(rarityButton, { "Rarity" }, nil)
	local nameLabel = resolveNestedTextLabel(
		rarityButton,
		{ "Name", "ItemName", "Item Name", "StyleName", "Style Name", "FlowName", "Flow Name" },
		{ "Text" }
	)
	local characterLabel = resolveNestedTextLabel(
		rarityButton,
		{ "Character", "CharacterName", "Character Name", "Personagem" },
		{ "Text" }
	)

	if percentageLabel then
		ensureTextLabelVisible(percentageLabel)
		percentageLabel.Text = displayText
		if rarityColor then
			percentageLabel.TextColor3 = getLighterRarityTextColor(rarityColor)
		end
	end

	if rarityLabel then
		ensureTextLabelVisible(rarityLabel)
		rarityLabel.Text = if percentageLabel and featuredName then featuredName else displayText
		if rarityColor then
			rarityLabel.TextColor3 = getDarkerRarityTextColor(rarityColor)
		end
	end

	if nameLabel and nameLabel ~= rarityLabel and nameLabel ~= percentageLabel and featuredName then
		ensureTextLabelVisible(nameLabel)
		nameLabel.Text = featuredName
		if rarityColor then
			nameLabel.TextColor3 = getDarkerRarityTextColor(rarityColor)
		end
	end

	if characterLabel and characterLabel ~= rarityLabel and characterLabel ~= percentageLabel and featuredName then
		ensureTextLabelVisible(characterLabel)
		characterLabel.Text = featuredName
		if rarityColor then
			characterLabel.TextColor3 = getDarkerRarityTextColor(rarityColor)
		end
	end
end

local function getRaritySectionContentHeight(listLayout: UIListLayout, entryStates: {any}): number
	local contentHeight = math.max(listLayout.AbsoluteContentSize.Y, 0)
	if contentHeight > 0 then
		return contentHeight
	end

	local totalHeight = 0
	for index, entryState in ipairs(entryStates) do
		local entryLabel = entryState.Label
		local labelHeight = math.max(entryLabel.AbsoluteSize.Y, entryLabel.Size.Y.Offset, entryLabel.TextSize + 6, 18)
		totalHeight += labelHeight
		if index < #entryStates then
			totalHeight += listLayout.Padding.Offset
		end
	end

	return totalHeight
end

local function setRaritySectionTransparency(
	entryStates: {any},
	tweenService: TweenService,
	expanded: boolean,
	instant: boolean?
): ()
	for _, entryState in ipairs(entryStates) do
		local entryLabel = entryState.Label
		local targetTextTransparency = if expanded then entryState.TextTransparency else 1
		local targetStrokeTransparency = if expanded then entryState.TextStrokeTransparency else 1

		if instant then
			entryLabel.TextTransparency = targetTextTransparency
			entryLabel.TextStrokeTransparency = targetStrokeTransparency
		else
			tweenService:Create(entryLabel, RARITY_LABEL_TWEEN_INFO, {
				TextTransparency = targetTextTransparency,
				TextStrokeTransparency = targetStrokeTransparency,
			}):Play()
		end

		for _, strokeState in ipairs(entryState.StrokeStates) do
			local stroke = strokeState.Instance
			if instant then
				stroke.Transparency = if expanded then strokeState.Transparency else 1
			else
				tweenService:Create(stroke, RARITY_LABEL_TWEEN_INFO, {
					Transparency = if expanded then strokeState.Transparency else 1,
				}):Play()
			end
		end
	end
end

function GachaGuiUtil.ConnectRarityHoverAnimation(
	button: GuiButton,
	tweenService: TweenService,
	trove: any,
	hoverInfo: TweenInfo,
	resetInfo: TweenInfo,
	hoverRotation: number
): ()
	local originalRotation = button.Rotation
	local isHovered = false

	trove:Add(button.MouseEnter:Connect(function()
		isHovered = true
		SoundController:PlayUiHover()
		tweenRarityButtonState(
			button,
			tweenService,
			hoverInfo,
			RARITY_BUTTON_HOVER_SCALE,
			originalRotation + hoverRotation
		)
	end), "Disconnect")

	trove:Add(button.MouseLeave:Connect(function()
		isHovered = false
		tweenRarityButtonState(button, tweenService, resetInfo, 1, originalRotation)
	end), "Disconnect")

	trove:Add(button.MouseButton1Down:Connect(function()
		tweenRarityButtonState(
			button,
			tweenService,
			RARITY_BUTTON_CLICK_INFO,
			RARITY_BUTTON_PRESS_SCALE,
			originalRotation + (if isHovered then (hoverRotation * 0.35) else 0)
		)
	end), "Disconnect")

	trove:Add(button.MouseButton1Up:Connect(function()
		tweenRarityButtonState(
			button,
			tweenService,
			RARITY_BUTTON_BOUNCE_INFO,
			(if isHovered then RARITY_BUTTON_HOVER_SCALE else 1),
			originalRotation + (if isHovered then hoverRotation else 0)
		)
	end), "Disconnect")

	trove:Add(button.Activated:Connect(function()
		SoundController:Play("Select")
	end), "Disconnect")
end

function GachaGuiUtil.SetupTopRightRarityFrame(
	normalContainer: Instance,
	groupedEntries: { [string]: any },
	displayOrder: { string },
	entryListKey: string,
	labelAttributeName: string,
	trove: any,
	tweenService: TweenService,
	hoverInfo: TweenInfo,
	resetInfo: TweenInfo,
	hoverRotation: number
): boolean
	if not normalContainer then
		return false
	end

	local labelTemplate = GachaGuiUtil.FindDirectChildByNames(normalContainer, { "NameStyle", "Name Style" }, "TextLabel")
	if not labelTemplate or not labelTemplate:IsA("TextLabel") then
		return false
	end

	local rarityButtons = {}
	for _, rarityName in ipairs(displayOrder) do
		local rarityButton = GachaGuiUtil.FindDirectChildByNames(normalContainer, { rarityName }, "ImageButton")
		if rarityButton and rarityButton:IsA("ImageButton") then
			rarityButtons[rarityName] = rarityButton
			rarityButton.Visible = false
		end
	end
	if next(rarityButtons) == nil then
		return false
	end

	local sectionAttributeName = labelAttributeName .. "Section"
	for _, child in ipairs(normalContainer:GetChildren()) do
		if child:GetAttribute(labelAttributeName) == true or child:GetAttribute(sectionAttributeName) == true then
			child:Destroy()
		end
	end

	labelTemplate.Visible = false

	local layoutOrder = 0
	for _, rarityName in ipairs(displayOrder) do
		local rarityButton = rarityButtons[rarityName]
		local groupData = groupedEntries[rarityName]
		local entryList = if groupData then groupData[entryListKey] else nil
		if not rarityButton or not rarityButton:IsA("ImageButton") or typeof(entryList) ~= "table" or #entryList == 0 then
			continue
		end

		layoutOrder += 1
		rarityButton.LayoutOrder = layoutOrder
		rarityButton.Visible = true
		rarityButton.Rotation = 0
		GachaGuiUtil.ConnectRarityHoverAnimation(rarityButton, tweenService, trove, hoverInfo, resetInfo, hoverRotation)
		GachaGuiUtil.ConfigureRarityButtonDisplay(rarityButton, rarityName, groupData, entryListKey)

		if groupData.Color then
			rarityButton.ImageColor3 = groupData.Color
			local glow = getRarityButtonGlow(rarityButton)
			if glow and (glow:IsA("ImageLabel") or glow:IsA("ImageButton")) then
				glow.ImageColor3 = groupData.Color
			end
		end

		layoutOrder += 1
		local entryContainer = Instance.new("Frame")
		entryContainer.Name = rarityName .. "Entries"
		entryContainer.BackgroundTransparency = 1
		entryContainer.BorderSizePixel = 0
		entryContainer.ClipsDescendants = true
		entryContainer.Size = UDim2.new(1, 0, 0, 0)
		entryContainer.LayoutOrder = layoutOrder
		entryContainer:SetAttribute(sectionAttributeName, true)

		local entryListLayout = Instance.new("UIListLayout")
		entryListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		entryListLayout.Padding = UDim.new(0, RARITY_SECTION_PADDING)
		entryListLayout.Parent = entryContainer

		local entryStates = {}
		for entryIndex, entryName in ipairs(entryList) do
			local entryLabel = labelTemplate:Clone()
			entryLabel.Name = entryName
			entryLabel.Text = entryName
			entryLabel.TextColor3 = if groupData.Color
				then getDarkerRarityTextColor(groupData.Color)
				else Color3.fromRGB(255, 255, 255)
			entryLabel.LayoutOrder = entryIndex
			entryLabel.Visible = true
			entryLabel:SetAttribute(labelAttributeName, true)
			configureRarityEntryLabel(entryLabel, labelTemplate)
			entryLabel.Parent = entryContainer
			table.insert(entryStates, getEntryLabelOriginalState(entryLabel))
		end

		entryContainer.Parent = normalContainer

		local isExpanded = true
		local function updateEntryContainer(expanded: boolean, instant: boolean?): ()
			isExpanded = expanded
			local targetHeight = if expanded then getRaritySectionContentHeight(entryListLayout, entryStates) else 0
			if instant then
				entryContainer.Size = UDim2.new(1, 0, 0, targetHeight)
			else
				tweenService:Create(entryContainer, RARITY_SECTION_TWEEN_INFO, {
					Size = UDim2.new(1, 0, 0, targetHeight),
				}):Play()
			end
			setRaritySectionTransparency(entryStates, tweenService, expanded, instant)
		end

		trove:Add(entryListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if isExpanded then
				entryContainer.Size = UDim2.new(1, 0, 0, getRaritySectionContentHeight(entryListLayout, entryStates))
			end
		end), "Disconnect")

		trove:Add(rarityButton.Activated:Connect(function()
			updateEntryContainer(not isExpanded, false)
		end), "Disconnect")

		updateEntryContainer(true, true)
	end

	return true
end

function GachaGuiUtil.FindLeftScrollButton(main: Instance?, frameName: string): GuiButton?
	local left = GachaGuiUtil.FindLeftContainer(main)
	if not left then
		return nil
	end

	local frame = GachaGuiUtil.FindDirectChildByNames(left, { frameName }, nil)
		or GachaGuiUtil.FindDescendantByNames(left, { frameName }, nil)
	if not frame then
		return nil
	end
	if frame:IsA("GuiButton") then
		return frame
	end

	local button = GachaGuiUtil.FindDirectChildByNames(frame, { "Button" }, "GuiButton")
	if button and button:IsA("GuiButton") then
		return button
	end

	button = GachaGuiUtil.FindGuiButtonByNames(frame, { "Button" })
	if button then
		return button
	end

	button = frame:FindFirstChildWhichIsA("GuiButton", true)
	return if button and button:IsA("GuiButton") then button else nil
end

function GachaGuiUtil.GetScrollingFrameWindowHeight(scrollingFrame: ScrollingFrame): number
	return math.max(scrollingFrame.AbsoluteWindowSize.Y, scrollingFrame.AbsoluteSize.Y, 0)
end

function GachaGuiUtil.GetScrollingFrameContentHeight(scrollingFrame: ScrollingFrame): number
	local contentHeight = math.max(scrollingFrame.AbsoluteCanvasSize.Y, 0)

	for _, descendant in ipairs(scrollingFrame:GetDescendants()) do
		if descendant:IsA("UIListLayout") or descendant:IsA("UIGridLayout") or descendant:IsA("UITableLayout") then
			contentHeight = math.max(contentHeight, descendant.AbsoluteContentSize.Y)
		end
	end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local bottomEdge = child.AbsolutePosition.Y - scrollingFrame.AbsolutePosition.Y + child.AbsoluteSize.Y
			contentHeight = math.max(contentHeight, bottomEdge)
		end
	end

	return contentHeight
end

function GachaGuiUtil.GetScrollingFrameMaxY(scrollingFrame: ScrollingFrame): number
	local windowHeight = GachaGuiUtil.GetScrollingFrameWindowHeight(scrollingFrame)
	local contentHeight = GachaGuiUtil.GetScrollingFrameContentHeight(scrollingFrame)
	return math.max(contentHeight - windowHeight, 0)
end

local function getScrollingFrameStepSize(scrollingFrame: ScrollingFrame, fallbackStepScale: number): number
	local windowHeight = GachaGuiUtil.GetScrollingFrameWindowHeight(scrollingFrame)
	local fallbackStep = math.max(windowHeight * fallbackStepScale, 1)

	local layoutPadding = 0
	for _, descendant in ipairs(scrollingFrame:GetDescendants()) do
		if descendant:IsA("UIListLayout") then
			layoutPadding = math.max(layoutPadding, descendant.Padding.Offset)
		end
	end

	for _, child in ipairs(scrollingFrame:GetDescendants()) do
		if
			child:IsA("GuiObject")
			and child.Visible
			and child.AbsoluteSize.Y > 0
			and (
				child:GetAttribute("SlotIndex") ~= nil
				or child:IsA("ImageButton")
				or child.Name == "Slot1"
				or child.Name == "Slot"
			)
		then
			return math.max(child.AbsoluteSize.Y + layoutPadding, 1)
		end
	end

	return fallbackStep
end

function GachaGuiUtil.ScrollScrollingFrame(
	scrollingFrame: ScrollingFrame,
	tweenService: TweenService,
	stepScale: number,
	direction: number,
	tweenInfo: TweenInfo?
): ()
	scrollingFrame.ScrollingEnabled = true
	scrollingFrame.Active = true

	local step = getScrollingFrameStepSize(scrollingFrame, stepScale)
	local maxY = GachaGuiUtil.GetScrollingFrameMaxY(scrollingFrame)
	local targetY = math.clamp(scrollingFrame.CanvasPosition.Y + (step * direction), 0, maxY)

	tweenService:Create(scrollingFrame, tweenInfo or TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CanvasPosition = Vector2.new(scrollingFrame.CanvasPosition.X, targetY),
	}):Play()
end

function GachaGuiUtil.UpdateSpinDisplay(textLabel: TextLabel, amount: number): ()
	textLabel.Text = tostring(amount) .. " Spins"
end

return GachaGuiUtil
