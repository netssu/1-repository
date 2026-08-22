------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")
local TweenService: TweenService = game:GetService("TweenService")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local challengesData = require(modules:WaitForChild("Data"):WaitForChild("ChallengesData"))

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local CHALLENGES_FRAME_NAME: string = "Challenges"
local QUEST_TOP_BAR_NAME: string = "QuestTopBar"
local CARD_NAMES: { string } = { "Daily", "Weekly", "VIP" }
local FRONT_NAME: string = "Front"
local BACK_NAME: string = "Back"
local PROGRESS_CIRCLE_NAME: string = "ProgressCircle"
local PROGRESS_BACKGROUND_NAME: string = "ProgressCircleBG"
local PROGRESS_AMOUNT_NAME: string = "Amount"
local UI_GRADIENT_NAME: string = "UIGradient"
local QUEST_SLOT_LABEL_NAMES: { string } = challengesData.QUEST_SLOT_NAMES
local NORMAL_QUESTS_PATH: string = "Profile.Quests"
local PREMIUM_QUESTS_PATH: string = "Profile.RacingPass.Quests"
local PREMIUM_OWNED_PATH: string = "Profile.RacingPass.RacingpassOwned"
local TWEEN_INFO: TweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local CARD_COLLAPSED_X_SCALE: number = 0
local PROGRESS_ROTATION_PER_COMPLETED: number = 44
local SECONDS_PER_DAY: number = 24 * 60 * 60

type DataConnection = {
	disconnect: (self: DataConnection) -> (),
}

type CardConfig = {
	name: string,
	isPremium: boolean,
	rootPath: string,
}

local CARD_CONFIGS: { CardConfig } = {
	{ name = "Daily", isPremium = false, rootPath = NORMAL_QUESTS_PATH },
	{ name = "Weekly", isPremium = false, rootPath = NORMAL_QUESTS_PATH },
	{ name = "VIP", isPremium = true, rootPath = PREMIUM_QUESTS_PATH },
}

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local challengesFrame: Frame?
local cardConnections: { RBXScriptConnection } = {}
local dataConnections: { DataConnection } = {}
local expandedSizes: { [GuiObject]: UDim2 } = {}
local flippingCards: { [GuiObject]: boolean } = {}
local timerConnection: RBXScriptConnection?
local isEnabled: boolean = false
local isPremiumOwned: boolean = false

------------------//FUNCTIONS
local function get_challenges_frame(): Frame?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local canvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	local frame = canvas and canvas:FindFirstChild(CHALLENGES_FRAME_NAME)
	if frame and frame:IsA("Frame") then
		return frame
	end

	return nil
end

local function get_card_config(cardName: string): CardConfig?
	for _, config in CARD_CONFIGS do
		if config.name == cardName then
			return config
		end
	end

	return nil
end

local function format_time(seconds: number): string
	local safeSeconds = math.max(0, math.floor(seconds))
	local hours = math.floor(safeSeconds / 3600)
	local minutes = math.floor((safeSeconds % 3600) / 60)
	local remainingSeconds = safeSeconds % 60
	return ("%02d:%02d:%02d"):format(hours, minutes, remainingSeconds)
end

local function format_reward(challenge: any): string
	local rewardText = ("+%dXP +$%d"):format(
		math.max(0, tonumber(challenge.RewardXP) or 0),
		math.max(0, tonumber(challenge.RewardCash) or 0)
	)
	if type(challenge.RewardItemType) == "string" and type(challenge.RewardItem) == "string" then
		local itemLabel = challenge.RewardItemType
		if itemLabel == "Livery" then
			itemLabel = "Car"
		elseif itemLabel == "Helmets" then
			itemLabel = "Helmet"
		end
		rewardText ..= (" +%s %s"):format(challenge.RewardItem, itemLabel)
	end
	return rewardText
end

local function get_card_parts(card: GuiObject): (GuiButton?, GuiButton?)
	local front = card:FindFirstChild(FRONT_NAME)
	local back = card:FindFirstChild(BACK_NAME)
	local frontButton = if front and front:IsA("GuiButton") then front else nil
	local backButton = if back and back:IsA("GuiButton") then back else nil
	return frontButton, backButton
end

local function get_default_rotation(card: GuiObject): number?
	local front = card:FindFirstChild(FRONT_NAME)
	local progressCircle = front and front:FindFirstChild(PROGRESS_CIRCLE_NAME)
	local gradient = progressCircle and progressCircle:FindFirstChild(UI_GRADIENT_NAME)
	if not gradient or not gradient:IsA("UIGradient") then
		return nil
	end

	local defaultRotation = gradient:GetAttribute("DefaultRotation")
	if type(defaultRotation) ~= "number" then
		defaultRotation = gradient.Rotation
		gradient:SetAttribute("DefaultRotation", defaultRotation)
	end
	return defaultRotation
end

local function set_progress(card: GuiObject, completedCount: number): ()
	local front = card:FindFirstChild(FRONT_NAME)
	local progressCircle = front and front:FindFirstChild(PROGRESS_CIRCLE_NAME)
	local progressBackground = front and front:FindFirstChild(PROGRESS_BACKGROUND_NAME)
	local amount = progressBackground and progressBackground:FindFirstChild(PROGRESS_AMOUNT_NAME)
	local gradient = progressCircle and progressCircle:FindFirstChild(UI_GRADIENT_NAME)
	if not amount or not amount:IsA("TextLabel") or not gradient or not gradient:IsA("UIGradient") then
		return
	end

	local defaultRotation = get_default_rotation(card) or gradient.Rotation
	gradient.Rotation = defaultRotation - PROGRESS_ROTATION_PER_COMPLETED * completedCount
	amount.Text = ("%d/%d"):format(completedCount, #QUEST_SLOT_LABEL_NAMES)
end

local function get_category_data(config: CardConfig): { [string]: any }?
	local root = dataUtility.client.get(config.rootPath)
	if type(root) ~= "table" then
		return nil
	end

	local category = root[config.name]
	return if type(category) == "table" then category else nil
end

local function set_timer(categoryName: string, category: { [string]: any }): ()
	local topBar = challengesFrame and challengesFrame:FindFirstChild(QUEST_TOP_BAR_NAME)
	local categoryTopBar = topBar and topBar:FindFirstChild(categoryName)
	local timer = categoryTopBar and categoryTopBar:FindFirstChild("Timer")
	if not timer or not timer:IsA("TextLabel") then
		return
	end

	local refreshSeconds = challengesData.REFRESH_SECONDS[categoryName] or SECONDS_PER_DAY
	local lastRefresh = tonumber(category.LastRefresh) or os.time()
	timer.Text = format_time(refreshSeconds - (os.time() - lastRefresh))
end

local function render_card(config: CardConfig): ()
	local card = challengesFrame and challengesFrame:FindFirstChild(config.name)
	if not card or not card:IsA("GuiObject") then
		return
	end

	expandedSizes[card] = expandedSizes[card] or card.Size
	local category = get_category_data(config)
	if not category then
		return
	end

	local completedCount = 0
	local back = card:FindFirstChild(BACK_NAME)
	if not back then
		return
	end

	for _, slotName in QUEST_SLOT_LABEL_NAMES do
		local challenge = category[slotName]
		local questCard = back:FindFirstChild(slotName)
		if not questCard or not questCard:IsA("GuiObject") or type(challenge) ~= "table" then
			continue
		end

		local objective = questCard:FindFirstChild("QuestObjective")
		local reward = questCard:FindFirstChild("QuestReward")
		local isLocked = config.isPremium and not isPremiumOwned
		if objective and objective:IsA("TextLabel") then
			objective.Text = if isLocked then "Requires Racing Pass" elseif challenge.Completed == true then "Completed" else challengesData.format_objective(challenge)
		end
		if reward and reward:IsA("TextLabel") then
			reward.Text = format_reward(challenge)
		end
		if not isLocked and challenge.Completed == true then
			completedCount += 1
		end
	end

	set_progress(card, completedCount)
	set_timer(config.name, category)
end

local function render_cards(): ()
	if not challengesFrame then
		return
	end

	isPremiumOwned = dataUtility.client.get(PREMIUM_OWNED_PATH) == true
	for _, config in CARD_CONFIGS do
		render_card(config)
	end
end

local function update_timers(): ()
	if not challengesFrame or not challengesFrame.Visible then
		return
	end

	for _, config in CARD_CONFIGS do
		local category = get_category_data(config)
		if category then
			set_timer(config.name, category)
		end
	end
end

local function flip_card(card: GuiObject): ()
	if flippingCards[card] then
		return
	end

	local front, back = get_card_parts(card)
	if not front or not back then
		return
	end

	flippingCards[card] = true
	local expandedSize = expandedSizes[card] or card.Size
	expandedSizes[card] = expandedSize
	local collapsedSize = UDim2.new(
		CARD_COLLAPSED_X_SCALE,
		0,
		expandedSize.Y.Scale,
		expandedSize.Y.Offset
	)
	local shrink = TweenService:Create(card, TWEEN_INFO, { Size = collapsedSize })
	shrink:Play()
	shrink.Completed:Wait()

	local showBack = front.Visible
	front.Visible = not showBack
	back.Visible = showBack

	local expand = TweenService:Create(card, TWEEN_INFO, { Size = expandedSize })
	expand:Play()
	expand.Completed:Wait()
	flippingCards[card] = nil
end

local function bind_cards(): ()
	if not challengesFrame then
		return
	end

	for _, config in CARD_CONFIGS do
		local card = challengesFrame:FindFirstChild(config.name)
		if not card or not card:IsA("GuiObject") then
			continue
		end

		local front, back = get_card_parts(card)
		if front then
			front.Visible = true
			if back then
				back.Visible = false
			end
			table.insert(cardConnections, front.Activated:Connect(function()
				flip_card(card)
			end))
		end
		if back then
			table.insert(cardConnections, back.Activated:Connect(function()
				flip_card(card)
			end))
		end
	end
end

local function disconnect_data_connections(): ()
	for _, connection in dataConnections do
		connection:disconnect()
	end
	dataConnections = {}
end

local function bind_data(path: string, callback: () -> ()): ()
	local connection = dataUtility.client.bind(path, callback)
	if connection then
		table.insert(dataConnections, connection :: DataConnection)
	end
end

local function disconnect_card_connections(): ()
	for _, connection in cardConnections do
		connection:Disconnect()
	end
	cardConnections = {}
end

------------------//MAIN FUNCTIONS
local function challenges_controller_enable(): boolean
	if isEnabled then
		return true
	end

	challengesFrame = get_challenges_frame()
	if not challengesFrame then
		warn("[ChallengesController] Challenges UI not found")
		return false
	end

	dataUtility.client.ensure_remotes()
	isEnabled = true
	bind_cards()
	bind_data(NORMAL_QUESTS_PATH, render_cards)
	bind_data(PREMIUM_QUESTS_PATH, render_cards)
	bind_data(PREMIUM_OWNED_PATH, render_cards)
	timerConnection = RunService.RenderStepped:Connect(update_timers)
	render_cards()
	return true
end

local function challenges_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_card_connections()
	disconnect_data_connections()
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
	for card in flippingCards do
		flippingCards[card] = nil
	end
	expandedSizes = {}
	challengesFrame = nil
	isPremiumOwned = false
	isEnabled = false
end

------------------//INIT
return {
	enable = challenges_controller_enable,
	disable = challenges_controller_disable,
}
