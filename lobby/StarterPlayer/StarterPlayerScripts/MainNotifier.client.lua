local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local TextChatService = game:GetService("TextChatService")

local PlayerGui = Player:WaitForChild("PlayerGui")

repeat
	task.wait()
until Player:FindFirstChild("DataLoaded") and PlayerGui:FindFirstChild("GameGui")

local CoreGameUI = PlayerGui:WaitForChild("CoreGameUI")
local NewUI = PlayerGui:WaitForChild("NewUI")
local LegacyObtainedFrame = CoreGameUI.Notifier.Obtained
local LegacyTemplate = LegacyObtainedFrame.Rewards.Template
local LegacyBG = LegacyTemplate.BG
local LegacyAmount = LegacyTemplate.Amount
local LegacyClose = LegacyObtainedFrame.Close
local LegacyNotice = LegacyObtainedFrame.Notice
local NewObtainedFrame = NewUI:WaitForChild("RewardPopUp")
local Items = Player:WaitForChild("Items")

local Assets = { "rbxassetid://136316362283198" }
local Currency = {
	["Gems"] = "rbxassetid://131476601794300",
	["Willpower"] = "http://www.roblox.com/asset/?id=125102279720110",
}
local soundID = "1347153667"

local displayQueue = {}
local isDisplaying = false
local cancelTween = false
local CurrencyIsTrue = false
local counter = 0
local popupOpenedAt = 0
local lastDebugGiveCommand = nil
local lastDebugGiveAt = 0
local automaticRewardPopupsSuppressed = false
local rewardPopupClosedCallback = nil

local closeRewardPopup

local function findDescendantByName(root, name)
	if not root then
		return nil
	end

	return root:FindFirstChild(name, true)
end

local function findFirstGuiButton(root)
	if not root then
		return nil
	end

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

local function setTextValue(label, value)
	if not label then
		return
	end

	if label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox") then
		label.Text = value == nil and "" or tostring(value)
	end
end

local function copyViewportProperty(targetViewport, sourceViewport, propertyName)
	local readSuccess, value = pcall(function()
		return sourceViewport[propertyName]
	end)

	if not readSuccess then
		return
	end

	pcall(function()
		targetViewport[propertyName] = value
	end)
end

local function getViewportTarget(container)
	if not container then
		return nil
	end

	if container:IsA("ViewportFrame") then
		return container
	end

	local directViewport = container:FindFirstChild("ViewportFrame")
	if directViewport and directViewport:IsA("ViewportFrame") then
		return directViewport
	end

	return container:FindFirstChildWhichIsA("ViewportFrame", true)
end

local function clearViewportTarget(viewport)
	if not viewport then
		return
	end

	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then
			child:Destroy()
		end
	end
end

local function setPlaceholderGraphicsVisible(container, visible)
	if not (container and container:IsA("GuiObject")) then
		return
	end

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant ~= container
			and descendant.Name == "Placeholder"
			and descendant:IsA("GuiObject")
			and not descendant:IsA("ViewportFrame") then
			descendant.Visible = visible
		end
	end
end

local function clearDynamicRewardDisplay(container)
	if not container then
		return
	end

	local targetViewport = getViewportTarget(container)
	clearViewportTarget(targetViewport)

	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:GetAttribute("RewardPopupDynamicDisplay") == true then
			descendant:Destroy()
		end
	end

	setPlaceholderGraphicsVisible(container, true)
end

local function attachRewardDisplay(container, data)
	clearDynamicRewardDisplay(container)

	if not (container and data) then
		return
	end

	if data.isCurrency then
		local icon = Instance.new("ImageLabel")
		icon.Name = "RewardCurrencyIcon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 1)
		icon.Position = UDim2.new()
		icon.AnchorPoint = Vector2.zero
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Image = Currency[data.CurrencyName] or ""
		icon.ZIndex = 20
		icon:SetAttribute("RewardPopupDynamicDisplay", true)
		icon.Parent = container

		setPlaceholderGraphicsVisible(container, false)
		return
	end

	local targetViewport = getViewportTarget(container)
	if not targetViewport then
		return
	end

	setPlaceholderGraphicsVisible(container, false)

	local viewportName = data.viewportName or data.CurrencyName
	if not viewportName or viewportName == "" then
		return
	end

	local viewport = ViewPortModule.CreateViewPort(viewportName)
	if not viewport then
		return
	end

	copyViewportProperty(targetViewport, viewport, "BackgroundTransparency")
	copyViewportProperty(targetViewport, viewport, "ImageTransparency")
	copyViewportProperty(targetViewport, viewport, "ImageColor3")
	copyViewportProperty(targetViewport, viewport, "Ambient")
	copyViewportProperty(targetViewport, viewport, "LightColor")
	copyViewportProperty(targetViewport, viewport, "LightDirection")
	copyViewportProperty(targetViewport, viewport, "CurrentCamera")

	local worldModel = viewport:FindFirstChildOfClass("WorldModel")
	if worldModel then
		worldModel.Parent = targetViewport
	end

	if ViewPortModule.DestroyViewport then
		ViewPortModule.DestroyViewport(viewport)
	else
		viewport:Destroy()
	end
end

local function getLegacyPopupRefs()
	return {
		mode = "legacy",
		root = LegacyObtainedFrame,
		closeButton = LegacyClose,
		notice = LegacyNotice,
		bg = LegacyBG,
		amount = LegacyAmount,
	}
end

local function getProfileCardRefs(profile)
	return {
		root = profile,
		title = profile and profile:FindFirstChild("Title"),
		name = profile and profile:FindFirstChild("Name"),
		amount = profile and profile:FindFirstChild("Amount"),
		displayContainer = profile and (profile:FindFirstChild("Placeholder") or findDescendantByName(profile, "Placeholder")),
	}
end

local function getNewPopupRefs()
	local holder = NewObtainedFrame:FindFirstChild("Holder") or NewObtainedFrame:FindFirstChild("Hold")
	local profileTemplate = (holder and holder:FindFirstChild("Profile")) or NewObtainedFrame:FindFirstChild("Profile")
	local clickRoot = NewObtainedFrame:FindFirstChild("Click")
	local profileRefs = getProfileCardRefs(profileTemplate)

	return {
		mode = "new",
		root = NewObtainedFrame,
		holder = holder,
		profile = profileTemplate,
		profileTemplate = profileTemplate,
		closeButton = findFirstGuiButton(clickRoot),
		clickRoot = clickRoot,
		clickText = clickRoot and clickRoot:FindFirstChild("Text"),
		title = NewObtainedFrame:FindFirstChild("Title"),
		profileTitle = profileRefs.title,
		name = profileRefs.name,
		amount = profileRefs.amount,
		displayContainer = profileRefs.displayContainer,
	}
end

local function getActivePopupRefs()
	if NewObtainedFrame then
		return getNewPopupRefs()
	end

	return getLegacyPopupRefs()
end

local function getVisiblePopupRefs()
	local newRefs = getNewPopupRefs()
	if newRefs.root.Visible then
		return newRefs
	end

	return getLegacyPopupRefs()
end

local function getLevelRewardText()
	local playerLevel = Player:FindFirstChild("PlayerLevel")
	return playerLevel and tostring(playerLevel.Value) or "?"
end

local function FadeBlackBackGround(bg, fadeIn)
	local goal = {}
	goal.BackgroundTransparency = fadeIn and 0.15 or 1
	local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(bg, tweenInfo, goal)
	tween:Play()
end

local function MovingTextUpAndDown(textLabel)
	if not textLabel then
		return
	end

	cancelTween = true
	task.wait()

	cancelTween = false
	coroutine.wrap(function()
		local originalPosition = textLabel.Position
		while textLabel:IsDescendantOf(game) and textLabel.Visible and not cancelTween do
			local up = TweenService:Create(textLabel, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = originalPosition - UDim2.new(0, 0, 0.05, 0),
			})
			up:Play()
			up.Completed:Wait()

			if cancelTween then
				break
			end

			local down = TweenService:Create(textLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = originalPosition,
			})
			down:Play()
			down.Completed:Wait()
		end
	end)()
end

local function getPopupAnimationPriority(target)
	if not target then
		return 999
	end

	if target.Name == "Title" then
		return 1
	elseif target.Name == "Holder" or target.Name == "Hold" or target.Name == "Profile" then
		return 2
	elseif target.Name == "Click" then
		return 3
	end

	return 10
end

local function getOrCreatePopupScale(target)
	if not (target and target:IsA("GuiObject")) then
		return nil
	end

	local scale = target:FindFirstChild("RewardPopupIntroScale")
	if scale and scale:IsA("UIScale") then
		return scale
	end

	scale = Instance.new("UIScale")
	scale.Name = "RewardPopupIntroScale"
	scale.Parent = target

	return scale
end

local function collectNewPopupIntroTargets(refs)
	local targets = {}

	if not refs then
		return targets
	end

	if refs.title and refs.title:IsA("GuiObject") and refs.title.Visible then
		table.insert(targets, refs.title)
	end

	if refs.holder then
		local profileTargets = {}

		for _, child in ipairs(refs.holder:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				local isTemplate = child == refs.profileTemplate
				local isClone = child:GetAttribute("RewardPopupProfileClone") == true

				if isTemplate or isClone then
					table.insert(profileTargets, child)
				end
			end
		end

		table.sort(profileTargets, function(a, b)
			if a.LayoutOrder ~= b.LayoutOrder then
				return a.LayoutOrder < b.LayoutOrder
			end

			return a.Name < b.Name
		end)

		for _, profileTarget in ipairs(profileTargets) do
			table.insert(targets, profileTarget)
		end
	end

	if refs.clickRoot and refs.clickRoot:IsA("GuiObject") and refs.clickRoot.Visible then
		table.insert(targets, refs.clickRoot)
	end

	if #targets == 0 and refs.root then
		for _, child in ipairs(refs.root:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				table.insert(targets, child)
			end
		end

		table.sort(targets, function(a, b)
			local priorityA = getPopupAnimationPriority(a)
			local priorityB = getPopupAnimationPriority(b)

			if priorityA ~= priorityB then
				return priorityA < priorityB
			end

			return a.Name < b.Name
		end)
	end

	return targets
end

local function playNewPopupIntro(refs)
	if not (refs and refs.root) then
		return
	end

	local targets = collectNewPopupIntroTargets(refs)

	for index, target in ipairs(targets) do
		local scale = getOrCreatePopupScale(target)
		if scale then
			scale.Scale = 0.001

			task.delay((index - 1) * 0.2, function()
				if not target:IsDescendantOf(game) then
					return
				end

				TweenService:Create(
					scale,
					TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end)
		end
	end
end

local function getSummaryEntryDisplayName(entry)
	if not entry then
		return "Reward"
	end

	return entry.displayName or entry.name or entry.CurrencyName or "Reward"
end

local function getSummaryEntryAmount(entry)
	return entry and (entry.quantity or entry.value or 1) or 1
end

local function getSummaryTotalQuantity(entries)
	local total = 0

	for _, entry in ipairs(entries or {}) do
		total += getSummaryEntryAmount(entry)
	end

	return total
end

local function getRewardCardTitle(entry, fallbackTitle)
	if entry and entry.wasSold then
		return "AUTO SOLD"
	end

	if entry and entry.isCurrency then
		return "LEVEL REWARD"
	end

	if entry and entry.rarity then
		return string.upper(tostring(entry.rarity))
	end

	return fallbackTitle or "REWARD"
end

local function formatSummaryEntryLine(entry)
	local suffix = entry and entry.wasSold and " (Sold)" or ""
	return string.format("%s x%s%s", getSummaryEntryDisplayName(entry), tostring(getSummaryEntryAmount(entry)), suffix)
end

local function formatSummaryEntries(entries)
	local lines = {}
	local maxLines = 5

	for index, entry in ipairs(entries or {}) do
		if index > maxLines then
			break
		end

		table.insert(lines, formatSummaryEntryLine(entry))
	end

	local hiddenCount = math.max(#(entries or {}) - maxLines, 0)
	if hiddenCount > 0 then
		table.insert(lines, string.format("+%d more", hiddenCount))
	end

	return table.concat(lines, "\n")
end

local function clearNewPopupProfiles(refs)
	if not refs then
		return
	end

	if refs.holder then
		for _, child in ipairs(refs.holder:GetChildren()) do
			if child:GetAttribute("RewardPopupProfileClone") == true then
				child:Destroy()
			end
		end
	end

	if refs.profileTemplate then
		clearDynamicRewardDisplay(getProfileCardRefs(refs.profileTemplate).displayContainer)
		refs.profileTemplate.Visible = false
	end
end

local function createNewPopupProfile(refs, layoutOrder)
	if not refs or not refs.profileTemplate then
		return nil
	end

	local profileInstance
	if refs.holder then
		profileInstance = refs.profileTemplate:Clone()
		profileInstance.Name = "Profile_" .. tostring(layoutOrder)
		profileInstance.LayoutOrder = layoutOrder
		profileInstance.Visible = true
		profileInstance:SetAttribute("RewardPopupProfileClone", true)
		profileInstance.Parent = refs.holder
	else
		profileInstance = refs.profileTemplate
		profileInstance.Visible = true
	end

	return getProfileCardRefs(profileInstance)
end

local function fillNewPopupProfile(profileRefs, entryData, fallbackTitle)
	if not (profileRefs and profileRefs.root and entryData) then
		return
	end

	local amount = getSummaryEntryAmount(entryData)
	setTextValue(profileRefs.title, getRewardCardTitle(entryData, fallbackTitle))
	setTextValue(profileRefs.name, getSummaryEntryDisplayName(entryData))
	setTextValue(profileRefs.amount, "x" .. tostring(amount))

	attachRewardDisplay(profileRefs.displayContainer, {
		isCurrency = entryData.isCurrency == true,
		CurrencyName = entryData.viewportName or entryData.name or entryData.CurrencyName,
		viewportName = entryData.viewportName or entryData.name or entryData.CurrencyName,
	})
end

local function populateNewPopupProfiles(refs, entries, fallbackTitle)
	clearNewPopupProfiles(refs)

	if not refs then
		return
	end

	local normalizedEntries = entries
	if not normalizedEntries or #normalizedEntries == 0 then
		normalizedEntries = {{
			name = "Reward",
			quantity = 1,
		}}
	end

	for index, entry in ipairs(normalizedEntries) do
		local profileRefs = createNewPopupProfile(refs, index)
		fillNewPopupProfile(profileRefs, entry, fallbackTitle)
	end
end

local function showNewSummaryPopup(data)
	local refs = getNewPopupRefs()
	local entries = data.summaryEntries or {}
	local featured = data.featuredEntry or entries[1]
	local totalQuantity = data.totalQuantity or getSummaryTotalQuantity(entries)

	refs.root.Visible = true
	FadeBlackBackGround(refs.root, true)
	popupOpenedAt = os.clock()

	if counter < 1 then
		MovingTextUpAndDown(refs.clickText)
	end

	setTextValue(refs.title, data.summaryTitle or (totalQuantity > 1 and "You've Earned" or "You've Got"))
	setTextValue(refs.clickText, "Click anywhere to close")
	populateNewPopupProfiles(refs, entries, totalQuantity > 1 and "SUMMON REWARD" or "NEW CARD")

	playNewPopupIntro(refs)
end

local function showLegacyPopup(data)
	local refs = getLegacyPopupRefs()

	refs.root.Visible = true
	FadeBlackBackGround(refs.root, true)

	if counter < 1 then
		MovingTextUpAndDown(refs.notice)
	end

	if data.isCurrency then
		CurrencyIsTrue = true

		local levelRewards = refs.root:FindFirstChild("LevelRewards")
		if not levelRewards then
			levelRewards = refs.amount:Clone()
			levelRewards.Name = "LevelRewards"
			levelRewards.Text = "Displaying Level Rewards"
			levelRewards.AnchorPoint = Vector2.new(0.5, 0.5)
			levelRewards.Position = UDim2.new(0.42, 0, 0.08, 0)
			levelRewards.TextSize = 36
			levelRewards.Parent = refs.root
			levelRewards.Visible = true

			local levelRewardsName = refs.amount:Clone()
			levelRewardsName.Name = "LevelDisplay"
			levelRewardsName.Text = "For Reaching Level " .. getLevelRewardText()
			levelRewardsName.AnchorPoint = Vector2.new(0.5, 0.5)
			levelRewardsName.Position = UDim2.new(0.4, 0, 0.3, 0)
			levelRewardsName.TextColor3 = Color3.new(1, 1, 1)
			levelRewardsName.Parent = refs.root
			levelRewardsName.Visible = true
		else
			levelRewards.Visible = true
		end

		refs.bg.Image = Currency[data.CurrencyName] or Assets[1]
		refs.amount.Text = "x" .. data.value
	else
		local viewport = ViewPortModule.CreateViewPort(data.CurrencyName)
		if viewport then
			viewport.Parent = refs.bg
			viewport.Size = UDim2.new(1, 0, 1, 0)
			viewport.ZIndex = 999999999
			viewport.AnchorPoint = Vector2.new(0.5, 0.5)
			viewport.Position = UDim2.new(0.5, 0, 0.35, 0)
		end

		refs.amount.Text = "x" .. data.value
	end
end

local function showNewPopup(data)
	if data and data.kind == "summary" then
		showNewSummaryPopup(data)
		return
	end

	local refs = getNewPopupRefs()

	refs.root.Visible = true
	FadeBlackBackGround(refs.root, true)
	popupOpenedAt = os.clock()

	if counter < 1 then
		MovingTextUpAndDown(refs.clickText)
	end

	setTextValue(refs.title, "You've Got")
	setTextValue(refs.clickText, "Click anywhere to close")
	populateNewPopupProfiles(refs, {{
		isCurrency = data.isCurrency,
		name = data.CurrencyName,
		displayName = data.CurrencyName,
		viewportName = data.viewportName or data.CurrencyName,
		quantity = data.value,
	}}, data.isCurrency and "LEVEL REWARD" or "NEW CARD")
	playNewPopupIntro(refs)
end

local function clearLegacyPopup()
	local viewport = LegacyBG:FindFirstChildOfClass("ViewportFrame")
	if viewport then
		viewport:Destroy()
	end

	for _, child in ipairs(LegacyObtainedFrame:GetChildren()) do
		if child.Name == "LevelRewards" or child.Name == "LevelDisplay" then
			child:Destroy()
		end
	end

	if CurrencyIsTrue then
		LegacyBG.Image = Assets[1]
	end

	CurrencyIsTrue = false
end

local function clearNewPopup()
	local refs = getNewPopupRefs()
	clearNewPopupProfiles(refs)
end

closeRewardPopup = function()
	local refs = getVisiblePopupRefs()
	if not refs.root.Visible then
		return
	end

	cancelTween = true
	counter = math.max(counter - 1, 0)

	if refs.mode == "new" then
		clearNewPopup()
	else
		clearLegacyPopup()
	end

	FadeBlackBackGround(refs.root, false)
	refs.root.Visible = false

	local closedCallback = rewardPopupClosedCallback
	rewardPopupClosedCallback = nil
	if typeof(closedCallback) == "function" then
		task.defer(closedCallback)
	end
end

local function bindPopupClosers()
	local legacyRefs = getLegacyPopupRefs()
	if legacyRefs.closeButton and not legacyRefs.closeButton:GetAttribute("RewardPopupCloseConnected") then
		legacyRefs.closeButton:SetAttribute("RewardPopupCloseConnected", true)
		legacyRefs.closeButton.Activated:Connect(closeRewardPopup)
	end

	local newRefs = getNewPopupRefs()
	if newRefs.closeButton and not newRefs.closeButton:GetAttribute("RewardPopupCloseConnected") then
		newRefs.closeButton:SetAttribute("RewardPopupCloseConnected", true)
		newRefs.closeButton.Activated:Connect(closeRewardPopup)
	end

	if not newRefs.root:GetAttribute("RewardPopupInputConnected") then
		newRefs.root:SetAttribute("RewardPopupInputConnected", true)
		newRefs.root.InputBegan:Connect(function(input, gameProcessedEvent)
			if gameProcessedEvent or not newRefs.root.Visible then
				return
			end

			if os.clock() - popupOpenedAt < 0.15 then
				return
			end

			local inputType = input.UserInputType
			if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
				closeRewardPopup()
			end
		end)
	end
end

local function playRewardSound()
	local sound = Instance.new("Sound")
	sound.SoundId = soundID
	sound.Parent = PlayerGui
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function enqueueRewardPopup(data)
	table.insert(displayQueue, data)

	if not isDisplaying then
		ProcessQueue()
	end
end

local function parseDebugGiveCommand(message)
	if typeof(message) ~= "string" then
		return nil
	end

	local trimmedMessage = string.match(message, "^%s*(.-)%s*$")
	if not trimmedMessage then
		return nil
	end

	local commandBody = string.match(trimmedMessage, "^!give%s+(.+)$")
	if not commandBody then
		return nil
	end

	local unitName, quantityText = string.match(commandBody, "^(.-)%s+(%d+)$")
	if not unitName then
		unitName = commandBody
		quantityText = "1"
	end

	unitName = string.match(unitName, "^%s*(.-)%s*$")
	local quantity = tonumber(quantityText) or 1

	if unitName == "" or quantity < 1 then
		return nil
	end

	return {
		isCurrency = false,
		CurrencyName = unitName,
		value = quantity,
	}
end

local function handleDebugGiveCommand(message, source)
	local parsed = parseDebugGiveCommand(message)
	if not parsed then
		return
	end

	local now = os.clock()
	local commandKey = string.lower(parsed.CurrencyName) .. ":" .. tostring(parsed.value)
	if lastDebugGiveCommand == commandKey and (now - lastDebugGiveAt) < 0.5 then
		return
	end

	lastDebugGiveCommand = commandKey
	lastDebugGiveAt = now

	warn("[RewardPopupDebug]", "source=" .. tostring(source), "unit=" .. parsed.CurrencyName, "quantity=" .. tostring(parsed.value))
	enqueueRewardPopup(parsed)
end

_G.ShowRewardPopupSummary = function(summaryData)
	if not summaryData then
		return
	end

	enqueueRewardPopup({
		kind = "summary",
		summaryTitle = summaryData.summaryTitle,
		summaryEntries = summaryData.entries or {},
		featuredEntry = summaryData.featured,
		totalQuantity = summaryData.totalQuantity,
	})
end

_G.SetRewardPopupSuppressed = function(isSuppressed)
	automaticRewardPopupsSuppressed = isSuppressed == true
end

_G.SetRewardPopupClosedCallback = function(callback)
	if callback == nil or typeof(callback) == "function" then
		rewardPopupClosedCallback = callback
	end
end

function DisplayCurrency(_, CurrencyName, Currencyvalue)
	if automaticRewardPopupsSuppressed then
		return
	end

	enqueueRewardPopup({
		isCurrency = true,
		CurrencyName = CurrencyName,
		value = Currencyvalue,
	})
end

function DisplayItem()
	for _, item in pairs(Items:GetChildren()) do
		local lastValue = item.Value
		item.Changed:Connect(function()
			pcall(function()
				ContentProvider:PreloadAsync(Assets)
			end)

			local diff = item.Value - lastValue
			lastValue = item.Value

			if diff <= 0 then
				return
			end

			if automaticRewardPopupsSuppressed then
				return
			end

			enqueueRewardPopup({
				isCurrency = false,
				CurrencyName = item.Name,
				value = diff,
			})
		end)
	end
end

function ProcessQueue()
	if #displayQueue <= 0 then
		isDisplaying = false
		return
	end

	isDisplaying = true

	local data = table.remove(displayQueue, 1)
	local refs = getActivePopupRefs()

	playRewardSound()
	counter += 1

	if refs.mode == "new" then
		showNewPopup(data)
	else
		showLegacyPopup(data)
	end

	refs.root:GetPropertyChangedSignal("Visible"):Wait()

	isDisplaying = false
	ProcessQueue()
end

bindPopupClosers()

Player.Chatted:Connect(function(message)
	handleDebugGiveCommand(message, "Player.Chatted")
end)

if TextChatService then
	TextChatService.SendingMessage:Connect(function(message)
		handleDebugGiveCommand(message.Text, "TextChatService.SendingMessage")
	end)
end

local level = Player:WaitForChild("PlayerLevel")
local LevelRewardRemote = ReplicatedStorage.Remotes.LevelRewards.LevelReward

level.Changed:Connect(function()
	local GemsReward, TraitPoints = LevelRewardRemote:InvokeServer()

	if GemsReward and TraitPoints == 0 then
		return
	end

	DisplayCurrency(true, "Gems", GemsReward)
	DisplayCurrency(true, "Willpower", TraitPoints)
end)

LevelRewardRemote.OnClientInvoke = function(Gems, Traits)
	if Gems and Traits == 0 or Gems == nil or Traits == nil then
		return
	end

	DisplayCurrency(true, "Gems", Gems)
	DisplayCurrency(true, "Willpower", Traits)
end

DisplayItem()
