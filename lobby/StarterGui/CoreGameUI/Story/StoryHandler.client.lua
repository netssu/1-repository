local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local movingEvent = ReplicatedStorage.Events:WaitForChild("MovingElevator")
local elevatorEvent = ReplicatedStorage.Events:WaitForChild("Elevator")
local ownerLeavesElevator = ReplicatedStorage.Events:WaitForChild("OwnerLeavesElevator")

local gui = script.Parent.StoryFrame.Frame
local exitBtn = gui.Parent.Exit
local playBtn = gui.Bottom_Bar.Bottom_Bar.Play
local quickStart = gui.Parent.QuickStart
local camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:FindFirstChild("NewUI") or PlayerGui:WaitForChild("NewUI", 5)

local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)
local UIMapLoadingScreen = require(game.ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("UIMapLoadingScreen"))
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)
local Simplebar = require(ReplicatedStorage.Modules.Client.Simplebar)
local UIHandler = require(game.ReplicatedStorage.Modules.Client.UIHandler)
local ActLoader = require(script.ActLoader)

local LOCK_IMAGE = "rbxassetid://116387490078387"

local currentElevator = nil
local selectedStoryWorld = nil
local selectedStoryActIndex = nil
local selectedStoryMode = nil
local storyPlayerTemplateCache = nil
local storyUiConnections = {}
local notunlocked

ActLoader.setActs("Naboo Planet")
ActLoader.attachConnections()

local function numbertotime(number)
	if number == nil or number < 0 then
		return "--:--"
	end

	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) % 60
	local Seconds = math.floor(number % 60)

	if Mintus < 10 and Hours > 0 then
		Mintus = "0" .. Mintus
	end

	if Seconds < 10 then
		Seconds = "0" .. Seconds
	end

	if Hours > 0 then
		return `{Hours}:{Mintus}:{Seconds}`
	else
		return `{Mintus}:{Seconds}`
	end
end

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

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
	if not root then
		return nil
	end

	if root:IsA("GuiButton") then
		return root
	end

	local preferredButton = root:FindFirstChild("Btn", true)
		or root:FindFirstChild("Button", true)

	if preferredButton and preferredButton:IsA("GuiButton") then
		return preferredButton
	end

	return root:FindFirstChildWhichIsA("GuiButton", true)
end

local function findTextObject(root, name, recursive)
	if not root then
		return nil
	end

	local object = recursive and root:FindFirstChild(name, true) or root:FindFirstChild(name)
	if object and (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return object
	end

	return nil
end

local function findImageObject(root, name, recursive)
	if not root then
		return nil
	end

	local object = recursive and root:FindFirstChild(name, true) or root:FindFirstChild(name)
	if object and (object:IsA("ImageLabel") or object:IsA("ImageButton")) then
		return object
	end

	return nil
end

local function getTopLevelTextObjects(root)
	local objects = {}

	if not root then
		return objects
	end

	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			table.insert(objects, child)
		end
	end

	return objects
end

local function setTextIfExists(target, value)
	if target and (target:IsA("TextLabel") or target:IsA("TextButton")) then
		target.Text = tostring(value or "")
	end
end

local function setImageIfExists(target, image)
	if target and (target:IsA("ImageLabel") or target:IsA("ImageButton")) then
		target.Image = image or ""
	end
end

local function disconnectStoryUiConnections()
	for _, connection in ipairs(storyUiConnections) do
		connection:Disconnect()
	end

	table.clear(storyUiConnections)
end

local function getNewStoryMode()
	local currentNewUI = PlayerGui:FindFirstChild("NewUI") or NewUI
	if not currentNewUI then
		return nil
	end

	local storyMode = currentNewUI:FindFirstChild("StoryMode") or currentNewUI:FindFirstChild("StoryMode", true)
	if storyMode and storyMode:IsA("GuiObject") then
		return storyMode
	end

	return nil
end

local function getStoryModeTargetName()
	return getNewStoryMode() and "StoryMode" or "StoryFrame"
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

local function attachViewport(container, unitName)
	local targetViewport = getViewportTarget(container)
	if not targetViewport then
		return
	end

	clearViewportTarget(targetViewport)
	setPlaceholderGraphicsVisible(container, unitName == nil)

	local placeholderGraphic = container:IsA("GuiObject") and container:FindFirstChild("Placeholder")
	if placeholderGraphic and placeholderGraphic ~= targetViewport and placeholderGraphic:IsA("GuiObject") then
		placeholderGraphic.Visible = unitName == nil
	end

	if not unitName then
		return
	end

	local viewport = ViewPortModule.CreateViewPort(unitName, nil, true)
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

local function getNumberedGuiChildren(container, prefix)
	local children = {}
	if not container then
		return children
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and string.match(child.Name, "^" .. prefix .. "(%d+)$") then
			table.insert(children, child)
		end
	end

	table.sort(children, function(a, b)
		return tonumber(string.match(a.Name, "(%d+)$")) < tonumber(string.match(b.Name, "(%d+)$"))
	end)

	return children
end

local function setButtonIndicatorState(buttonRoot, enabled)
	if not buttonRoot then
		return
	end

	local normalizedNames = {
		check = true,
		checkmark = true,
		tick = true,
		mark = true,
	}

	for _, descendant in ipairs(buttonRoot:GetDescendants()) do
		local normalizedName = string.lower(string.gsub(descendant.Name, "[_%s]", ""))
		if normalizedNames[normalizedName] then
			if descendant:IsA("GuiObject") then
				descendant.Visible = enabled
			elseif descendant:IsA("ImageLabel") or descendant:IsA("ImageButton") then
				descendant.ImageTransparency = enabled and 0 or 1
			end

			if descendant.Name == "Checkmark" and (descendant:IsA("ImageLabel") or descendant:IsA("ImageButton")) then
				descendant.Image = enabled and "rbxassetid://14189590169" or ""
			end
		end
	end
end

local function setCardSelected(card, selected)
	if not card then
		return
	end

	local target = card:FindFirstChild("Bg") or card
	for _, descendant in ipairs(target:GetDescendants()) do
		if descendant:IsA("UIStroke") then
			descendant.Color = selected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(166, 40, 175)
		end
	end
end

local function setCardLocked(card, locked)
	if not card then
		return
	end

	card:SetAttribute("StoryLocked", locked)

	local lock = card:FindFirstChild("Lock") or card:FindFirstChild("Lock", true)
	if lock and (lock:IsA("ImageLabel") or lock:IsA("ImageButton")) then
		lock.Visible = locked
		lock.Image = LOCK_IMAGE
	end

	local holder = card:FindFirstChild("Holder") or card:FindFirstChild("Holder", true)
	if holder and (holder:IsA("ImageLabel") or holder:IsA("ImageButton")) then
		holder.ImageTransparency = locked and 0.25 or 0
	end
end

local function connectGuiAction(root, attributeName, callback)
	if not root then
		return
	end

	local target = findFirstGuiButton(root)
	if target then
		if target:GetAttribute(attributeName) then
			return
		end

		target:SetAttribute(attributeName, true)
		table.insert(storyUiConnections, target.Activated:Connect(callback))
		return
	end

	if not root:IsA("GuiObject") then
		return
	end

	if root:GetAttribute(attributeName) then
		return
	end

	root:SetAttribute(attributeName, true)
	root.Active = true

	table.insert(storyUiConnections, root.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			callback()
		end
	end))
end

local function getCurrentWorld()
	local currentWorldValue = script.ActLoader:FindFirstChild("CurrentWorld")
	if currentWorldValue and currentWorldValue.Value ~= "" then
		return currentWorldValue.Value
	end

	if currentElevator and StoryModeStats.Worlds[currentElevator.World.Value] then
		return StoryModeStats.Worlds[currentElevator.World.Value]
	end

	return StoryModeStats.Worlds[1]
end

local function getCurrentModeValue()
	if selectedStoryMode ~= nil then
		return selectedStoryMode
	end

	if currentElevator then
		return currentElevator.Mode.Value
	end

	return 1
end

local function getCurrentActIndex(world)
	local maxActs = #(StoryModeStats.LevelName[world] or {})
	local actIndex = selectedStoryActIndex

	if (not actIndex or actIndex < 1) and currentElevator and currentElevator.Level.Value > 0 then
		actIndex = currentElevator.Level.Value
	end

	if not actIndex or actIndex < 1 then
		actIndex = 1
	end

	if maxActs > 0 then
		actIndex = math.clamp(actIndex, 1, maxActs)
	end

	return actIndex
end

local function getModeText(modeValue)
	if modeValue == 2 then
		return "Hard"
	elseif modeValue == 3 then
		return "Infinite"
	end

	return "Normal"
end

local function getActDisplayText(world, actIndex)
	local actName = StoryModeStats.LevelName[world] and StoryModeStats.LevelName[world][actIndex]
	if not actName then
		return `Act {actIndex}`
	end

	return `ACT {actIndex} - {actName}`
end

local function unlockedActsCount(world)
	repeat task.wait() until player:FindFirstChild("DataLoaded")
	local count = 0

	for _, levelStat in ipairs(player.WorldStats[world].LevelStats:GetChildren()) do
		if levelStat.Clears.Value ~= 0 then
			count += 1
		end
	end

	return count
end

local function isActUnlocked(world, act)
	local WorldStats = player:WaitForChild("WorldStats")

	if world == "Naboo Planet" and (act == "1" or act == "Act1") then
		return true
	end

	local worldOrder = StoryModeStats.Worlds
	local previousWorldCleared = false

	for _, raidMap in ipairs(worldOrder) do
		if raidMap == world then
			local actNumber = tonumber(string.match(tostring(act), "(%d+)"))

			if actNumber == 1 and previousWorldCleared then
				return true
			end

			if actNumber and actNumber > 1 then
				local previousActClears = WorldStats[world].LevelStats["Act" .. tostring(actNumber - 1)].Clears.Value
				return previousActClears > 0
			end

			return false
		end

		local allCleared = true
		for levelIndex = 1, #StoryModeStats.LevelName[raidMap] do
			if WorldStats[raidMap].LevelStats["Act" .. tostring(levelIndex)].Clears.Value == 0 then
				allCleared = false
				break
			end
		end

		previousWorldCleared = allCleared
	end

	return false
end

local function getStoryWindow(totalCount, selectedIndex, windowSize)
	local maxWindow = math.min(totalCount, windowSize)
	local startIndex = math.max(1, selectedIndex - math.floor(maxWindow / 2))
	local maxStart = math.max(1, totalCount - maxWindow + 1)
	startIndex = math.min(startIndex, maxStart)

	local indices = {}
	for offset = 0, maxWindow - 1 do
		table.insert(indices, startIndex + offset)
	end

	return indices
end

local function getPlayerValuesSorted(elevator)
	local values = {}
	if not elevator then
		return values
	end

	for _, playerValue in ipairs(elevator.Players:GetChildren()) do
		table.insert(values, playerValue)
	end

	table.sort(values, function(a, b)
		if a.Name == elevator.Owner.Value then
			return true
		elseif b.Name == elevator.Owner.Value then
			return false
		end

		return a.Name < b.Name
	end)

	return values
end

local function applyStoryPlayerThumbnail(target, targetPlayer)
	if not (target and targetPlayer) then
		return
	end

	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(targetPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)

		if ok and target.Parent then
			target.Image = image
		end
	end)
end

local function updateNewStoryPlayerList(storyMode, elevator)
	local leftSection = storyMode and storyMode:FindFirstChild("LeftSection", true)
	local playerList = leftSection and leftSection:FindFirstChild("PlayerList", true)
	if not playerList then
		return
	end

	local template = playerList:FindFirstChild("ImageLabel")
	if not template then
		return
	end

	storyPlayerTemplateCache = template
	template.Visible = false

	local expectedCloneNames = {}
	for _, child in ipairs(playerList:GetChildren()) do
		if child ~= template and child:GetAttribute("StoryPlayerClone") then
			expectedCloneNames[child.Name] = false
		end
	end

	local playerValues = getPlayerValuesSorted(elevator)
	for index, playerValue in ipairs(playerValues) do
		local cloneName = "StoryPlayer_" .. playerValue.Name
		expectedCloneNames[cloneName] = true

		local clone = playerList:FindFirstChild(cloneName)
		if not clone then
			clone = template:Clone()
			clone.Name = cloneName
			clone.Visible = true
			clone:SetAttribute("StoryPlayerClone", true)
			clone.Parent = playerList
		end

		clone.LayoutOrder = index

		local targetPlayer = Players:FindFirstChild(playerValue.Name)
		if targetPlayer and clone.Image == "" then
			applyStoryPlayerThumbnail(clone, targetPlayer)
		end
	end

	for _, child in ipairs(playerList:GetChildren()) do
		if child ~= template
			and child:GetAttribute("StoryPlayerClone")
			and not expectedCloneNames[child.Name] then
			child:Destroy()
		end
	end

	local showcaseImage = findChildPath(leftSection, { "Bg", "ImageLabel" })
	if not (showcaseImage and (showcaseImage:IsA("ImageLabel") or showcaseImage:IsA("ImageButton"))) then
		showcaseImage = findImageObject(leftSection, "ImageLabel", true)
	end
	if showcaseImage == template then
		showcaseImage = nil
	end
	local ownerPlayer = elevator and Players:FindFirstChild(elevator.Owner.Value)
	if showcaseImage and ownerPlayer then
		applyStoryPlayerThumbnail(showcaseImage, ownerPlayer)
	end
end

local function updateNewStoryLeftSection(storyMode, elevator, elevatorInformationFrame, world, actIndex, modeValue)
	local leftSection = storyMode and storyMode:FindFirstChild("LeftSection", true)
	if not leftSection then
		return
	end

	local statusText = elevatorInformationFrame.Status.State.Text
	local queueText = string.lower(statusText)
	if elevatorInformationFrame.Status.Players.Text ~= "" then
		queueText = `{queueText} {elevatorInformationFrame.Status.Players.Text}`
	end

	local topLevelTextObjects = getTopLevelTextObjects(leftSection)
	local directTextSlots = {}
	for _, textObject in ipairs(topLevelTextObjects) do
		if textObject.Name == "Text" then
			table.insert(directTextSlots, textObject)
		end
	end

	local titleLabel = findTextObject(leftSection, "Title", false)
	local nameLabel = findTextObject(leftSection, "Name", false)
	local difficultyLabel = findTextObject(leftSection, "Difficulty", false)

	setTextIfExists(titleLabel, statusText)
	setTextIfExists(nameLabel, world)
	setTextIfExists(difficultyLabel, getModeText(modeValue))

	if directTextSlots[1] then
		setTextIfExists(directTextSlots[1], getActDisplayText(world, actIndex))
	end

	if directTextSlots[2] and directTextSlots[2] ~= titleLabel then
		setTextIfExists(directTextSlots[2], statusText)
	end

	local queueContainer = leftSection:FindFirstChild("Queu", true)
	local queueTitle = findTextObject(queueContainer, "Title", true)
	setTextIfExists(queueTitle, queueText)

	local queueBar = queueContainer and queueContainer:FindFirstChild("Bar", true)
	local queueFill = queueBar and queueBar:FindFirstChild("Fill", true)
	if queueFill and queueFill:IsA("GuiObject") then
		queueFill.Size = elevatorInformationFrame.Status.Bar.Size
	end

	local queueFillBg = queueFill and queueFill:FindFirstChild("Bg")
	if queueFillBg and queueFillBg:IsA("GuiObject") then
		queueFillBg.Size = UDim2.fromScale(1, 1)
	end

	updateNewStoryPlayerList(storyMode, elevator)
end

local function updateDetailStats(detailContainer, world, actIndex)
	if not detailContainer then
		return
	end

	local levelStats = player.WorldStats[world].LevelStats["Act" .. tostring(actIndex)]
	local totalClear = levelStats and levelStats.Clears.Value or 0
	local fastestTime = levelStats and levelStats.FastestTime.Value or -1
	local infiniteRecord = player.WorldStats[world].InfiniteRecord.Value

	if infiniteRecord < 0 then
		infiniteRecord = 0
	end

	local statsText = `Clears total: {totalClear}\nClear Time: {numbertotime(fastestTime)}\nInfinite record:{infiniteRecord}`

	for _, descendant in ipairs(detailContainer:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local normalizedText = string.lower(descendant.Text or "")
			if string.find(normalizedText, "clears")
				or string.find(normalizedText, "clear time")
				or string.find(normalizedText, "infinite record") then
				descendant.Text = statsText
				break
			end
		end
	end
end

local function updateNewStoryDetail(storyMode, world, actIndex, modeValue)
	local detail = findChildPath(storyMode, { "Body", "Main", "Detail" })
	if not detail then
		return
	end

	local actLine = getActDisplayText(world, actIndex)

	local nameLabel = findTextObject(detail, "Name", false)
	local directTextLabel = findTextObject(detail, "Text", false)
	local difficultyLabel = findTextObject(detail, "Difficulty", false)

	setTextIfExists(nameLabel, world)
	setTextIfExists(directTextLabel, actLine)
	setTextIfExists(difficultyLabel, getModeText(modeValue))

	updateDetailStats(detail, world, actIndex)

	local previewName = StoryModeStats.LevelName[world] and StoryModeStats.LevelName[world][actIndex]
	if previewName then
		local previewContainer = detail:FindFirstChild("Placeholder", true)
			or detail:FindFirstChildWhichIsA("ViewportFrame", true)
		if previewContainer then
			attachViewport(previewContainer, previewName)
		end
	end
end

local function updateStoryCardText(card, mainText, completionText)
	if not card then
		return
	end

	local textContainer = card:FindFirstChild("Text")
	local mainLabel = textContainer and findTextObject(textContainer, "Text", false)
	local completionLabel = textContainer and findTextObject(textContainer, "Completion", false)

	setTextIfExists(mainLabel, mainText)
	setTextIfExists(completionLabel, completionText)
end

local function updateStoryCardImage(card, image)
	if not card then
		return
	end

	local holder = card:FindFirstChild("Holder")
	if holder and (holder:IsA("ImageLabel") or holder:IsA("ImageButton")) then
		holder.Image = image or ""
	end
end

local function handleStoryMapCardActivated(card)
	local elevator = currentElevator or findPlayer()
	local world = card and card:GetAttribute("StoryMapWorld")
	local locked = card and card:GetAttribute("StoryLocked")

	if not elevator or not world or world == "" then
		return
	end

	if locked then
		notunlocked()
		return
	end

	if elevator.Owner.Value ~= player.Name then
		return
	end

	selectedStoryWorld = world
	selectedStoryActIndex = 1

	ActLoader.setActs(world)
	ActLoader.attachConnections()
	ActLoader.selectAct("Act1")
end

local function handleStoryActCardActivated(card)
	local elevator = currentElevator or findPlayer()
	local actIndex = card and card:GetAttribute("StoryActIndex")
	local locked = card and card:GetAttribute("StoryLocked")

	if not elevator or not actIndex or actIndex < 1 then
		return
	end

	if locked then
		notunlocked()
		return
	end

	if elevator.Owner.Value ~= player.Name then
		return
	end

	selectedStoryActIndex = actIndex
	ActLoader.selectAct("Act" .. tostring(actIndex))
end

local function chooseStoryDifficulty(modeValue)
	local elevator = currentElevator or findPlayer()
	if not elevator or elevator.Owner.Value ~= player.Name then
		return
	end

	selectedStoryMode = modeValue
	elevator.ElevatorServer.ChangeStory:FireServer("Mode", modeValue)

	if modeValue == 3 then
		elevator.ElevatorServer.ChangeStory:FireServer("Level", 0)
	else
		elevator.ElevatorServer.ChangeStory:FireServer("Level", getCurrentActIndex(getCurrentWorld()))
	end
end

local function toggleStoryFriendsOnly(buttonRoot)
	local elevator = currentElevator or findPlayer()
	if not elevator or elevator.Owner.Value ~= player.Name then
		return
	end

	local nextState = not elevator.FriendsOnly.Value
	elevator.ElevatorServer.FriendsOnly:FireServer(nextState)
	setButtonIndicatorState(buttonRoot, nextState)
end

local function startStoryQuickStart()
	local elevator = currentElevator or findPlayer()
	if not elevator then
		return
	end

	if elevator.Owner.Value ~= player.Name then
		return
	end

	currentElevator = nil

	local storyMode = getNewStoryMode()
	if storyMode then
		storyMode.Visible = false
	end

	gui.Parent.Parent.PlayersFrame.Visible = false
	gui.Parent.QuickStart.Visible = false
	gui.Parent.Exit.Visible = false
	gui.Visible = false

	elevator.ElevatorServer.QuickStart:FireServer()
end

local function leaveStoryElevator()
	UIHandler.PlaySound("Close")
	UIHandler.EnableAllButtons()
	Simplebar.toggleSimplebar(true)

	local storyMode = getNewStoryMode()
	if storyMode then
		storyMode.Visible = false
	end

	gui.Visible = false
	gui.Parent.Visible = false

	UpdatePlayerFrame()
	script.Parent.PlayersFrame.Visible = false

	restoreCamera()
	elevatorEvent:FireServer()
end

local function wireNewStoryModeButtons(storyMode)
	if not storyMode then
		return
	end

	local closeButtonRoot = findChildPath(storyMode, { "Body", "Closebtn" })
	connectGuiAction(closeButtonRoot, "StoryModeCloseBound", leaveStoryElevator)

	local leftSection = storyMode:FindFirstChild("LeftSection", true)
	local quitButtonRoot = leftSection and leftSection:FindFirstChild("Quit", true)
	connectGuiAction(quitButtonRoot, "StoryModeQuitBound", leaveStoryElevator)

	local buttonsContainer = findChildPath(storyMode, { "Body", "Main", "Buttons" })
	local joinButtonRoot = buttonsContainer and (buttonsContainer:FindFirstChild("Join", true) or buttonsContainer:FindFirstChild("Play", true))
	connectGuiAction(joinButtonRoot, "StoryModeJoinBound", startStoryQuickStart)

	local friendsButtonRoot = buttonsContainer and (
		buttonsContainer:FindFirstChild("FriendsOnly", true)
		or buttonsContainer:FindFirstChild("Friends_Only", true)
	)
	connectGuiAction(friendsButtonRoot, "StoryModeFriendsOnlyBound", function()
		toggleStoryFriendsOnly(friendsButtonRoot)
	end)

	for _, difficultyName in ipairs({ "Normal", "Hard", "Infinite" }) do
		local difficultyRoot = buttonsContainer and buttonsContainer:FindFirstChild(difficultyName, true)
		connectGuiAction(difficultyRoot, "StoryModeDifficulty" .. difficultyName .. "Bound", function()
			if difficultyName == "Normal" then
				chooseStoryDifficulty(1)
			elseif difficultyName == "Hard" then
				chooseStoryDifficulty(2)
			else
				chooseStoryDifficulty(3)
			end
		end)
	end

	local mapsContainer = findChildPath(storyMode, { "Body", "Main", "Maps", "Contents" })
	for _, card in ipairs(getNumberedGuiChildren(mapsContainer, "Map")) do
		connectGuiAction(card, "StoryModeMapCardBound", function()
			handleStoryMapCardActivated(card)
		end)
	end

	for _, card in ipairs(getNumberedGuiChildren(mapsContainer, "Act")) do
		connectGuiAction(card, "StoryModeActCardBound", function()
			handleStoryActCardActivated(card)
		end)
	end
end

local function updateNewStoryFriendsOnlyState(storyMode, elevator)
	local buttonsContainer = findChildPath(storyMode, { "Body", "Main", "Buttons" })
	local friendsButtonRoot = buttonsContainer and (
		buttonsContainer:FindFirstChild("FriendsOnly", true)
		or buttonsContainer:FindFirstChild("Friends_Only", true)
	)

	setButtonIndicatorState(friendsButtonRoot, elevator and elevator.FriendsOnly.Value or false)
end

local function updateNewStoryMaps(storyMode, world, actIndex)
	local mapsContainer = findChildPath(storyMode, { "Body", "Main", "Maps", "Contents" })
	if not mapsContainer then
		return
	end

	local mapCards = getNumberedGuiChildren(mapsContainer, "Map")
	local actCards = getNumberedGuiChildren(mapsContainer, "Act")

	local selectedWorldIndex = table.find(StoryModeStats.Worlds, world) or 1
	local visibleWorldIndices = getStoryWindow(#StoryModeStats.Worlds, selectedWorldIndex, #mapCards)
	local totalActs = #(StoryModeStats.LevelName[world] or {})
	local visibleActIndices = getStoryWindow(totalActs, actIndex, #actCards)

	for slotIndex, card in ipairs(mapCards) do
		local worldIndex = visibleWorldIndices[slotIndex]
		local worldName = worldIndex and StoryModeStats.Worlds[worldIndex]
		local unlocked = worldName and isActUnlocked(worldName, "1")

		card.Visible = worldName ~= nil
		card:SetAttribute("StoryMapWorld", worldName or "")

		if worldName then
			updateStoryCardText(card, worldName, `Acts completed {unlockedActsCount(worldName)}/{#StoryModeStats.LevelName[worldName]}`)
			updateStoryCardImage(card, StoryModeStats.Images[worldName])
			setCardLocked(card, not unlocked)
			setCardSelected(card, worldName == world)
		end
	end

	for slotIndex, card in ipairs(actCards) do
		local visibleActIndex = visibleActIndices[slotIndex]
		local actName = visibleActIndex and StoryModeStats.LevelName[world][visibleActIndex]
		local unlocked = visibleActIndex and isActUnlocked(world, "Act" .. tostring(visibleActIndex))

		card.Visible = visibleActIndex ~= nil
		card:SetAttribute("StoryActIndex", visibleActIndex or 0)

		if visibleActIndex then
			updateStoryCardText(card, `Act {visibleActIndex}`, actName or "")
			updateStoryCardImage(card, StoryModeStats.Images[world])
			setCardLocked(card, not unlocked)
			setCardSelected(card, visibleActIndex == actIndex)
		end
	end
end

local function updateNewStoryMode(elevator, elevatorInformationFrame)
	local storyMode = getNewStoryMode()
	if not storyMode then
		return
	end

	wireNewStoryModeButtons(storyMode)

	local body = storyMode:FindFirstChild("Body")
	local leftSection = storyMode:FindFirstChild("LeftSection", true)
	local main = findChildPath(storyMode, { "Body", "Main" })
	local isOwner = elevator and elevator.Owner.Value == player.Name

	storyMode.Visible = elevator ~= nil

	if body and body:IsA("GuiObject") then
		body.Visible = elevator ~= nil
	end

	if leftSection and leftSection:IsA("GuiObject") then
		leftSection.Visible = elevator ~= nil
	end

	if main and main:IsA("GuiObject") then
		main.Visible = isOwner
	end

	if not elevator then
		return
	end

	local world = StoryModeStats.Worlds[elevator.World.Value] or selectedStoryWorld or getCurrentWorld()
	local actIndex = getCurrentActIndex(world)
	local modeValue = getCurrentModeValue()

	selectedStoryWorld = world
	selectedStoryActIndex = actIndex
	selectedStoryMode = modeValue

	updateNewStoryLeftSection(storyMode, elevator, elevatorInformationFrame, world, actIndex, modeValue)
	updateNewStoryMaps(storyMode, world, actIndex)
	updateNewStoryDetail(storyMode, world, actIndex, modeValue)
	updateNewStoryFriendsOnlyState(storyMode, elevator)
end

local function setStoryUiVisible(visible, elevator)
	local storyMode = getNewStoryMode()

	if storyMode then
		storyMode.Visible = visible
		if visible and elevator then
			local elevatorInformationFrame = elevator.Door.Surface.Frame.InformationFrame
			updateNewStoryMode(elevator, elevatorInformationFrame)
		end
		gui.Parent.Visible = false
		gui.Visible = false
		script.Parent.PlayersFrame.Visible = false
		return
	end

	gui.Parent.Visible = visible
	gui.Visible = visible
	script.Parent.PlayersFrame.Visible = visible
end

function findPlayer()
	for _, model in ipairs(game.Workspace.StoryElevators:GetChildren()) do
		if model:IsA("Model") and model.Players:FindFirstChild(player.Name) then
			return model
		end
	end
end

local function visfalse()
	for _, frame in ipairs(gui.WorldDetails:GetChildren()) do
		if frame:IsA("Frame") then
			frame.Visible = false
		end
	end
end

local informationFrame = script.Parent.PlayersFrame.StoryImage.InformationFrame

function UpdatePlayerFrame(elevator)
	local playersStorage = script.Parent.PlayersFrame.StoryImage.Players

	if elevator then
		currentElevator = elevator
		local elevatorInformationFrame = elevator.Door.Surface.Frame.InformationFrame

		local function updateInfo()
			informationFrame.Status.Players.Text = elevatorInformationFrame.Status.Players.Text
			informationFrame.ActName.Text = elevatorInformationFrame.ActName.Text
			informationFrame["Story Name"].Text = elevatorInformationFrame["Story Name"].Text
			informationFrame.Status.Bar.Size = elevatorInformationFrame.Status.Bar.Size

			if elevator.Mode.Value == 1 then
				informationFrame["Mode Text"].Text = "Normal"
				informationFrame["Mode Text"].HardGradient.Enabled = false
				informationFrame["Mode Text"].NormalGradient.Enabled = true
			else
				informationFrame["Mode Text"].Text = "Hard"
				informationFrame["Mode Text"].NormalGradient.Enabled = false
				informationFrame["Mode Text"].HardGradient.Enabled = true
			end

			for _, ui in ipairs(playersStorage:GetChildren()) do
				if (not ui:IsA("ImageLabel") or not ui.Visible) then
					continue
				end

				if elevator.Players:FindFirstChild(ui.Name) then
					continue
				end

				ui:Destroy()
			end

			for _, playerValue in ipairs(elevator.Players:GetChildren()) do
				local targetPlayer = game.Players:FindFirstChild(playerValue.Name)
				if not targetPlayer or playersStorage:FindFirstChild(playerValue.Name) then
					continue
				end

				local clonePlayerImage = playersStorage.TemplatePlayerImage:Clone()
				task.spawn(function()
					local playerHeadshot = game.Players:GetUserThumbnailAsync(targetPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
					clonePlayerImage.Image = playerHeadshot
				end)
				clonePlayerImage.Name = targetPlayer.Name
				clonePlayerImage.Visible = true
				clonePlayerImage.Parent = playersStorage
			end

			updateNewStoryMode(elevator, elevatorInformationFrame)
		end

		repeat
			updateInfo()
			task.wait()
		until currentElevator ~= elevator
	else
		gui.Visible = false
		gui.Parent.Visible = false
		currentElevator = nil
		selectedStoryWorld = nil
		selectedStoryActIndex = nil
		selectedStoryMode = nil

		local storyMode = getNewStoryMode()
		if storyMode then
			storyMode.Visible = false
		end

		script.Parent.PlayersFrame.Visible = false
		restoreCamera()
	end
end

movingEvent.OnClientEvent:Connect(function()
	currentElevator = nil
	gui.Visible = false

	local storyMode = getNewStoryMode()
	if storyMode then
		storyMode.Visible = false
	end
end)

elevatorEvent.OnClientEvent:Connect(function(elevator, gamemode)
	_G.CloseAll()
	UIHandler.DisableAllButtons()
	exitBtn.Visible = false
	quickStart.Visible = false
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = elevator.Camera.CFrame

	gui.Parent.Visible = true
	gui.Visible = elevator.Owner.Value == player.Name

	if elevator.Owner.Value == player.Name then
		selectedStoryWorld = "Naboo Planet"
		selectedStoryActIndex = 1
		selectedStoryMode = 1

		ActLoader.setActs("Naboo Planet")
		ActLoader.selectAct("Act1")
	end

	if getNewStoryMode() then
		setStoryUiVisible(true, elevator)
	else
		script.Parent.PlayersFrame.Visible = true
	end

	exitBtn.Visible = true

	UpdatePlayerFrame(elevator)

	repeat
		task.wait()
	until not gui.Visible and not (getNewStoryMode() and getNewStoryMode().Visible)

	if elevator:FindFirstChild("Players") then
		if elevator.Players:FindFirstChild(player.Name) then
			gui.Parent.Visible = false
			exitBtn.Visible = true
			quickStart.Visible = elevator.Owner.Value == player.Name and not getNewStoryMode()
		end
	else
		exitBtn.Visible = true
		restoreCamera()
	end
end)

exitBtn.Activated:Connect(function()
	leaveStoryElevator()
end)

playBtn.Activated:Connect(function()
	gui.Visible = false
	local elevator = findPlayer()

	if elevator and elevator.Owner.Value == player.Name then
		gui.Parent.QuickStart.Visible = true
	end
end)

quickStart.Activated:Connect(function()
	currentElevator = nil
	gui.Parent.Parent.PlayersFrame.Visible = false
	gui.Parent.QuickStart.Visible = false
	gui.Parent.Exit.Visible = false
	gui.Visible = false

	local elevator = findPlayer()
	if elevator then
		elevator.ElevatorServer.QuickStart:FireServer()
	end
end)

ownerLeavesElevator.OnClientEvent:Connect(function()
	UIHandler.PlaySound("Close")
	UIHandler.EnableAllButtons()
	UpdatePlayerFrame()
end)

notunlocked = function()
	UIHandler.PlaySound("Error")
	_G.Message("Not unlocked!", Color3.new(0.776471, 0.239216, 0.239216))
end

for _, worldButton in ipairs(gui.Left_Panel.Contents.Location.Bg:GetChildren()) do
	if not worldButton:IsA("ImageButton") then
		continue
	end

	worldButton.Activated:Connect(function()
		local worldUnlocked = isActUnlocked(worldButton.Name, "1")

		if worldUnlocked then
			ActLoader.setActs(worldButton.Name)
			ActLoader.attachConnections()

			selectedStoryWorld = worldButton.Name
			selectedStoryActIndex = 1
		else
			notunlocked()
		end
	end)

	local worldUnlocked = isActUnlocked(worldButton.Name, "1")
	if not worldUnlocked then
		worldButton.Contents.Locked.Visible = true
	else
		worldButton.Contents.Text_Container.Acts_Cleared.Text = `Acts Cleared: <font color="#E03DAF">  {unlockedActsCount(worldButton.Name)}/5</font>`
	end
end

local CheckMark = gui.Bottom_Bar.Bottom_Bar.Friends_Only.Contents.Check.Contents.Checkmark

gui.Bottom_Bar.Bottom_Bar.Friends_Only.Activated:Connect(function()
	CheckMark.Image = if CheckMark.Image == "" then "rbxassetid://14189590169" else ""

	local elevator = findPlayer()
	if elevator then
		elevator.ElevatorServer.FriendsOnly:FireServer(CheckMark.Image ~= "")
	end
end)
