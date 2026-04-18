local module = {}

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--//Dependecies
local Packets = require(ReplicatedStorage.Modules.Game.Packets)
local CommandsData = require(ReplicatedStorage.Modules.Data.Commands)
local StyleAdminOptions = require(ReplicatedStorage.Modules.Data.StyleAdminOptions)
local Trove = require(ReplicatedStorage.Packages.Trove)

local GuiController = require(ReplicatedStorage.Controllers.GuiController)
local NotificationController = require(ReplicatedStorage.Controllers.NotificationController)
local UIanimations = require(ReplicatedStorage.Components.UIAnimation)

--//CONSTANTS
local MAIN_TROVE = nil
local DEFAULT_PLACEHOLDER_ATTRIBUTE = "DefaultPlaceholderText"
local AUTOCOMPLETE_VALUE_ATTRIBUTE = "AutocompleteValue"
local AUTOCOMPLETE_LABEL_ATTRIBUTE = "AutocompleteLabel"
local AUTOCOMPLETE_HINT_NAME = "AutocompleteHint"

local STATIC_PARAMETER_SUGGESTIONS = {
	Gamepass = {
		"GamePassVip",
		"SkipSpin",
		"ToxicEmotes",
		"AnimeEmotes",
	},
	Boolean = {
		"true",
		"false",
	},
	Stat = {
		"Yen",
		"Level",
		"Rating",
		"MVP",
		"Touchdowns",
		"Passing",
		"Tackles",
		"Wins",
		"Timer",
		"Intercepts",
		"Assists",
		"Possession",
		"SpinStyle",
		"SpinFlow",
		"LuckySpins",
	},
	Style = StyleAdminOptions.GetDisplayNames(),
}

--//Variables
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer.PlayerGui
local animated = false
local ADMIN_INIT_RETRY_DELAY = 2
local ADMIN_INIT_MAX_ATTEMPTS = 4

--// PRIVATE
local function normalizeAutocompleteText(text: string): string
	return string.lower(text):gsub("[%s_%-_]+", "")
end

local function computeLevenshteinDistance(leftText: string, rightText: string): number
	local leftLength = #leftText
	local rightLength = #rightText

	if leftLength == 0 then
		return rightLength
	end

	if rightLength == 0 then
		return leftLength
	end

	local previousRow = table.create(rightLength + 1)
	for rightIndex = 0, rightLength do
		previousRow[rightIndex] = rightIndex
	end

	for leftIndex = 1, leftLength do
		local currentRow = table.create(rightLength + 1)
		currentRow[0] = leftIndex

		local leftCharacter = string.sub(leftText, leftIndex, leftIndex)
		for rightIndex = 1, rightLength do
			local replacementCost = if leftCharacter == string.sub(rightText, rightIndex, rightIndex) then 0 else 1
			local deletionCost = previousRow[rightIndex] + 1
			local insertionCost = currentRow[rightIndex - 1] + 1
			local substituteCost = previousRow[rightIndex - 1] + replacementCost

			currentRow[rightIndex] = math.min(deletionCost, insertionCost, substituteCost)
		end

		previousRow = currentRow
	end

	return previousRow[rightLength]
end

local function computeSubsequenceGap(queryText: string, candidateText: string): number?
	local queryLength = #queryText
	if queryLength == 0 then
		return nil
	end

	local queryIndex = 1
	local totalGap = 0
	local lastMatch = 0

	for candidateIndex = 1, #candidateText do
		if string.sub(candidateText, candidateIndex, candidateIndex) == string.sub(queryText, queryIndex, queryIndex) then
			if lastMatch > 0 then
				totalGap += candidateIndex - lastMatch - 1
			end

			lastMatch = candidateIndex
			queryIndex += 1

			if queryIndex > queryLength then
				return totalGap
			end
		end
	end

	return nil
end

local function scoreCandidateText(queryText: string, candidateText: string): number
	if queryText == "" or candidateText == "" then
		return 0
	end

	local normalizedQuery = normalizeAutocompleteText(queryText)
	local normalizedCandidate = normalizeAutocompleteText(candidateText)
	if normalizedQuery == "" or normalizedCandidate == "" then
		return 0
	end

	if normalizedQuery == normalizedCandidate then
		return 10000 - math.abs(#normalizedCandidate - #normalizedQuery)
	end

	if string.sub(normalizedCandidate, 1, #normalizedQuery) == normalizedQuery then
		return 9000 - (#normalizedCandidate - #normalizedQuery)
	end

	local containsIndex = string.find(normalizedCandidate, normalizedQuery, 1, true)
	if containsIndex then
		return 7000 - containsIndex * 10 - (#normalizedCandidate - #normalizedQuery)
	end

	local subsequenceGap = computeSubsequenceGap(normalizedQuery, normalizedCandidate)
	if subsequenceGap ~= nil then
		return 5000 - subsequenceGap * 10 - (#normalizedCandidate - #normalizedQuery)
	end

	local editDistance = computeLevenshteinDistance(normalizedQuery, normalizedCandidate)
	local maxLength = math.max(#normalizedQuery, #normalizedCandidate)
	if maxLength == 0 then
		return 0
	end

	local similarity = 1 - (editDistance / maxLength)
	if similarity < 0.35 then
		return 0
	end

	return math.floor(similarity * 1000) - (#normalizedCandidate - #normalizedQuery)
end

local function getPlayerSuggestionEntries(): { [number]: { Label: string, Value: string } }
	local entries = {}
	local seen = {}

	local players = Players:GetPlayers()
	table.sort(players, function(leftPlayer, rightPlayer)
		if leftPlayer == localPlayer then
			return true
		end
		if rightPlayer == localPlayer then
			return false
		end
		return string.lower(leftPlayer.Name) < string.lower(rightPlayer.Name)
	end)

	for _, player in players do
		if not seen[player.Name] then
			seen[player.Name] = true
			table.insert(entries, {
				Label = player.Name,
				Value = player.Name,
			})
		end

		if player.DisplayName ~= player.Name and not seen[player.DisplayName] then
			seen[player.DisplayName] = true
			table.insert(entries, {
				Label = player.DisplayName,
				Value = player.Name,
			})
		end
	end

	return entries
end

local function getSuggestionEntries(parameterName: string): { [number]: { Label: string, Value: string } }
	if parameterName == "Player" then
		return getPlayerSuggestionEntries()
	end

	local rawSuggestions = STATIC_PARAMETER_SUGGESTIONS[parameterName]
	if not rawSuggestions then
		return {}
	end

	local entries = {}
	for _, suggestion in ipairs(rawSuggestions) do
		table.insert(entries, {
			Label = suggestion,
			Value = suggestion,
		})
	end

	return entries
end

local function findBestSuggestion(parameterName: string, rawText: string): ({ Label: string, Value: string }?)
	if rawText == "" then
		return nil
	end

	local normalizedQuery = normalizeAutocompleteText(rawText)
	local bestEntry = nil
	local bestScore = 0

	for _, entry in ipairs(getSuggestionEntries(parameterName)) do
		local score = math.max(scoreCandidateText(rawText, entry.Label), scoreCandidateText(rawText, entry.Value))
		if parameterName == "Player" and entry.Value == localPlayer.Name then
			local normalizedLabel = normalizeAutocompleteText(entry.Label)
			local normalizedValue = normalizeAutocompleteText(entry.Value)
			if string.sub(normalizedLabel, 1, #normalizedQuery) == normalizedQuery or string.sub(normalizedValue, 1, #normalizedQuery) == normalizedQuery then
				score += 500
			end
		end
		if score > bestScore then
			bestScore = score
			bestEntry = entry
		end
	end

	if bestScore < 600 then
		return nil
	end

	return bestEntry
end

local function ensureAutocompleteHint(parameterBox: TextBox): TextLabel
	local hintLabel = parameterBox:FindFirstChild(AUTOCOMPLETE_HINT_NAME)
	if not hintLabel or not hintLabel:IsA("TextLabel") then
		hintLabel = Instance.new("TextLabel")
		hintLabel.Name = AUTOCOMPLETE_HINT_NAME
		hintLabel.BackgroundTransparency = 1
		hintLabel.BorderSizePixel = 0
		hintLabel.Size = UDim2.fromScale(1, 1)
		hintLabel.Position = UDim2.fromScale(0, 0)
		hintLabel.AnchorPoint = Vector2.zero
		hintLabel.TextStrokeTransparency = 1
		hintLabel.Parent = parameterBox
	end

	hintLabel.Font = parameterBox.Font
	hintLabel.TextSize = parameterBox.TextSize
	hintLabel.TextWrapped = parameterBox.TextWrapped
	hintLabel.TextScaled = parameterBox.TextScaled
	hintLabel.RichText = true
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.TextYAlignment = parameterBox.TextYAlignment
	hintLabel.TextColor3 = Color3.fromRGB(155, 155, 155)
	hintLabel.TextTransparency = 0.35
	hintLabel.ZIndex = parameterBox.ZIndex + 1
	hintLabel.Visible = true

	return hintLabel
end

local function getTextBoxPadding(parameterBox: TextBox): number
	local padding = parameterBox:FindFirstChildOfClass("UIPadding")
	if not padding then
		return 0
	end

	return padding.PaddingLeft.Offset
end

local function buildSuggestionSuffix(rawText: string, suggestionText: string): string
	local normalizedQuery = normalizeAutocompleteText(rawText)
	local normalizedSuggestion = normalizeAutocompleteText(suggestionText)
	if normalizedQuery == "" or normalizedSuggestion == "" then
		return suggestionText
	end

	if string.sub(normalizedSuggestion, 1, #normalizedQuery) ~= normalizedQuery then
		return suggestionText
	end

	local matchedNormalized = 0
	for index = 1, #suggestionText do
		local character = string.sub(suggestionText, index, index)
		if not string.find(character, "[%s_%-]", 1) then
			matchedNormalized += 1
		end

		if matchedNormalized >= #normalizedQuery then
			return string.sub(suggestionText, index + 1)
		end
	end

	return ""
end

local function escapeRichText(text: string): string
	text = string.gsub(text, "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	text = string.gsub(text, "\"", "&quot;")
	return text
end

local function clearAutocompleteState(parameterBox: TextBox)
	local defaultPlaceholder = parameterBox:GetAttribute(DEFAULT_PLACEHOLDER_ATTRIBUTE) or parameterBox.Name
	local hintLabel = ensureAutocompleteHint(parameterBox)

	parameterBox.PlaceholderText = defaultPlaceholder
	parameterBox:SetAttribute(AUTOCOMPLETE_VALUE_ATTRIBUTE, nil)
	parameterBox:SetAttribute(AUTOCOMPLETE_LABEL_ATTRIBUTE, nil)

	hintLabel.Text = ""
	hintLabel.Position = UDim2.fromOffset(getTextBoxPadding(parameterBox), 0)
	hintLabel.Visible = true
end

local function updateAutocomplete(parameterBox: TextBox)
	local rawText = parameterBox.Text
	if rawText == "" then
		clearAutocompleteState(parameterBox)
		return
	end

	local suggestion = findBestSuggestion(parameterBox.Name, rawText)
	if not suggestion then
		clearAutocompleteState(parameterBox)
		return
	end

	local defaultPlaceholder = parameterBox:GetAttribute(DEFAULT_PLACEHOLDER_ATTRIBUTE) or parameterBox.Name
	local hintLabel = ensureAutocompleteHint(parameterBox)
	local suggestionSuffix = buildSuggestionSuffix(rawText, suggestion.Label)

	local hintText = ""
	if suggestionSuffix ~= "" then
		hintText = string.format(
			"<font transparency=\"1\">%s</font>%s",
			escapeRichText(rawText),
			escapeRichText(suggestionSuffix)
		)
	else
		hintText = string.format(
			"<font transparency=\"1\">%s</font>",
			escapeRichText(rawText)
		)
	end

	parameterBox.PlaceholderText = defaultPlaceholder
	parameterBox:SetAttribute(AUTOCOMPLETE_VALUE_ATTRIBUTE, suggestion.Value)
	parameterBox:SetAttribute(AUTOCOMPLETE_LABEL_ATTRIBUTE, suggestion.Label)

	hintLabel.Text = hintText
	hintLabel.Position = UDim2.fromOffset(getTextBoxPadding(parameterBox), 0)
	hintLabel.Visible = true
end

local function resolveParameterInput(parameterBox: TextBox): any
	local rawText = parameterBox.Text
	if rawText == "" then
		return nil
	end

	local resolvedValue = parameterBox:GetAttribute(AUTOCOMPLETE_VALUE_ATTRIBUTE)
	if typeof(resolvedValue) ~= "string" or resolvedValue == "" then
		resolvedValue = rawText
	end

	if string.lower(parameterBox.Name) == "boolean" then
		local loweredValue = string.lower(resolvedValue)
		if loweredValue == "true" then
			return true
		end
		if loweredValue == "false" then
			return false
		end
	end

	return resolvedValue
end

local function applyAutocompleteSelection(parameterBox: TextBox): boolean
	local selectedLabel = parameterBox:GetAttribute(AUTOCOMPLETE_LABEL_ATTRIBUTE)
	local selectedValue = parameterBox:GetAttribute(AUTOCOMPLETE_VALUE_ATTRIBUTE)

	local completedText = ""
	if parameterBox.Name == "Player" then
		if typeof(selectedValue) == "string" and selectedValue ~= "" then
			completedText = selectedValue
		end
	elseif typeof(selectedLabel) == "string" and selectedLabel ~= "" then
		completedText = selectedLabel
	elseif typeof(selectedValue) == "string" and selectedValue ~= "" then
		completedText = selectedValue
	end

	if completedText == "" then
		return false
	end

	parameterBox.Text = completedText
	updateAutocomplete(parameterBox)
	return true
end

local function getParametersText(parameterFrame: Frame, commandName: string)
	local insertedParameters = {}
	insertedParameters["Command"] = commandName

	for _, parameterBox in parameterFrame:GetChildren() do
		if not parameterBox:IsA("TextBox") then
			continue
		end

		local resolvedValue = resolveParameterInput(parameterBox)
		if resolvedValue == nil then
			continue
		end

		insertedParameters[parameterBox.Name] = resolvedValue
	end

	return insertedParameters
end

local function submitCommand(parameterFrame: Frame, command)
	local params = getParametersText(parameterFrame, command.PrivateName)

	local hasParams = false
	for key in params do
		if key ~= "Command" then
			hasParams = true
			break
		end
	end

	if not hasParams then
		return
	end

	Packets.Command:Fire(params)
end

local function setupCommands(scrollingFrame: ScrollingFrame)
	local commandTemplate = scrollingFrame:FindFirstChild("commandTemplate")
	if not commandTemplate then
		return
	end
	commandTemplate.Visible = false
	for _, command in CommandsData do
		local newCommand = scrollingFrame:FindFirstChild(command.Name) or commandTemplate:Clone()
		newCommand.Name = command.Name

		local parameterFrame = newCommand:FindFirstChild("Parameters")
		if not parameterFrame then
			continue
		end

		local parameterTemplate = parameterFrame:FindFirstChild("ParameterTemplate") :: TextBox
		if not parameterTemplate then
			continue
		end

		local nameHolder = newCommand:FindFirstChild("Image") or newCommand:FindFirstAncestorWhichIsA("ImageLabel")
		if not nameHolder then
			continue
		end
		local nameText = nameHolder:FindFirstChild("CommandName") or nameHolder:FindFirstChildWhichIsA("TextLabel")
		if not nameText then
			continue
		end
		nameText.Text = `{newCommand.Name}:`

		local fireButton = newCommand:FindFirstChild("Fire")
		if not fireButton or not fireButton:IsA("GuiButton") then
			continue
		end

		if not animated then
			UIanimations.new(fireButton)
			animated = true
		end

		local clickConnection = fireButton.MouseButton1Click:Connect(function()
			submitCommand(parameterFrame, command)
		end)

		MAIN_TROVE:Add(clickConnection, "Disconnect")

		for _, parameters in command.Parameters do
			local newParameter = parameterFrame:FindFirstChild(parameters)
			if not newParameter then
				newParameter = parameterTemplate:Clone()
				newParameter.Name = parameters
				newParameter.Visible = true
				newParameter.Parent = parameterFrame

				newParameter:SetAttribute(parameters, true)
			end

			if not newParameter:IsA("TextBox") then
				continue
			end

			newParameter.TextXAlignment = Enum.TextXAlignment.Left
			newParameter:SetAttribute(DEFAULT_PLACEHOLDER_ATTRIBUTE, parameters)
			newParameter.PlaceholderText = parameters
			clearAutocompleteState(newParameter)

			local textChangedConnection = newParameter:GetPropertyChangedSignal("Text"):Connect(function()
				updateAutocomplete(newParameter)
			end)
			MAIN_TROVE:Add(textChangedConnection, "Disconnect")

			local focusLostConnection = newParameter.FocusLost:Connect(function(enterPressed)
				updateAutocomplete(newParameter)
				if not enterPressed then
					return
				end

				applyAutocompleteSelection(newParameter)
			end)
			MAIN_TROVE:Add(focusLostConnection, "Disconnect")

			updateAutocomplete(newParameter)
		end

		newCommand.Visible = true
		newCommand.Parent = scrollingFrame
	end
end

local function setupAdminScreen()
	local adminScreen = playerGui:FindFirstChild("AdminGui")
	if not adminScreen then
		return
	end

	local mainFrame = adminScreen:FindFirstChild("Main") or adminScreen:FindFirstChildWhichIsA("Frame")
	if not mainFrame then
		return
	end

	local container = mainFrame:FindFirstChild("Settings")
	if not container then
		return
	end

	local content = container:FindFirstChild("Content")
	if not content then
		return
	end

	local scrollingFrame = content:FindFirstChildWhichIsA("ScrollingFrame")
	if not scrollingFrame then
		return
	end

	setupCommands(scrollingFrame)
end

local function requestAdminInit(): boolean
	for attempt = 1, ADMIN_INIT_MAX_ATTEMPTS do
		local success, result = pcall(function()
			return Packets.Admin:Fire("Init")
		end)

		if success then
			if result == "Loaded" then
				return true
			end

			if result ~= "TimedOut" then
				return false
			end
		end

		if attempt < ADMIN_INIT_MAX_ATTEMPTS then
			task.wait(ADMIN_INIT_RETRY_DELAY)
		end
	end

	warn("[AdminController] Timed out while requesting admin init")
	return false
end

--// PUBLIC
function module:Start()
	if Packets.Command then
		Packets.Command.OnClientEvent:Connect(function(parameters: {any})
			local eventType = parameters[1]
			
			if eventType == "Message" then
				print(parameters)
				local message = parameters[2]
				NotificationController.Notify("Command done", message, 2.5)
			elseif eventType == "Error" then
				local message = parameters[2]
				NotificationController.Notify("Command error", message, 3)
			end

		end)
	end

	task.spawn(requestAdminInit)

	GuiController.GuiOpened:Connect(function(guiName)
		if not (guiName == "AdminGui") then
			return
		end
		if MAIN_TROVE then
			return
		end

		MAIN_TROVE = Trove.new()

		setupAdminScreen()
	end)

	GuiController.GuiClosed:Connect(function(guiName)
		if not (guiName == "AdminGui") then
			return
		end

		if not MAIN_TROVE then
			return
		end

		MAIN_TROVE:Destroy()
		MAIN_TROVE = nil
	end)
end

return module
