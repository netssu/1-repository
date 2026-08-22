------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService: RunService = game:GetService("RunService")

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local dailyRewardData = require(modules:WaitForChild("Data"):WaitForChild("DailyRewardData"))

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local DAILY_REWARD_FRAME_NAME: string = "DailyReward"
local REWARDS_CONTAINER_NAME: string = "Rewards"
local REWARD_TEMPLATE_NAME: string = "Reward"
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local ACTION_REMOTE_NAME: string = "DailyRewardAction"
local DAILY_REWARD_PATH: string = "Profile.DailyReward"
local DAILY_GRID_MAX_COLUMNS: number = 4
local BACKGROUND_COLOR: Color3 = Color3.fromRGB(8, 20, 48)
local CARD_COLOR: Color3 = Color3.fromRGB(19, 43, 88)
local LOCKED_CARD_COLOR: Color3 = Color3.fromRGB(15, 29, 62)
local CLAIMED_CARD_COLOR: Color3 = Color3.fromRGB(25, 67, 69)
local WHITE_COLOR: Color3 = Color3.fromRGB(245, 249, 255)
local MUTED_COLOR: Color3 = Color3.fromRGB(168, 189, 220)
local GOLD_COLOR: Color3 = Color3.fromRGB(255, 201, 79)
local CYAN_COLOR: Color3 = Color3.fromRGB(76, 208, 255)
local PURPLE_COLOR: Color3 = Color3.fromRGB(186, 133, 255)
local GREEN_COLOR: Color3 = Color3.fromRGB(87, 225, 157)
local CLAIM_LABEL_NAME: string = "ClaimLabel"

type DataConnection = {
	disconnect: (self: DataConnection) -> (),
}

type CardView = {
	frame: Frame,
	valueLabel: TextLabel,
	statusLabel: TextLabel,
	button: ImageButton,
	buttonLabel: TextLabel,
}

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local dailyRewardFrame: Frame?
local titleLabel: TextLabel?
local cardViews: { [number]: CardView } = {}
local dataConnections: { DataConnection } = {}
local cardConnections: { RBXScriptConnection } = {}
local remoteConnection: RBXScriptConnection?
local timerConnection: RBXScriptConnection?
local dailyRewardAction: RemoteEvent?
local lastClockSecond: number = 0
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_daily_reward_frame(): Frame?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local canvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	local frame = canvas and canvas:FindFirstChild(DAILY_REWARD_FRAME_NAME)
	if frame and frame:IsA("Frame") then
		return frame
	end

	return nil
end

local function get_action_remote(): RemoteEvent?
	local profileRemotes = ReplicatedStorage:WaitForChild(PROFILE_REMOTES_FOLDER_NAME, 10)
	if not profileRemotes then
		return nil
	end

	local remote = profileRemotes:WaitForChild(ACTION_REMOTE_NAME, 10)
	return if remote and remote:IsA("RemoteEvent") then remote else nil
end

local function format_time(seconds: number): string
	local safeSeconds = math.max(0, math.floor(seconds))
	local days = math.floor(safeSeconds / 86400)
	local hours = math.floor((safeSeconds % 86400) / 3600)
	local minutes = math.floor((safeSeconds % 3600) / 60)
	local remainingSeconds = safeSeconds % 60
	if days > 0 then
		return ("%dd %02dh"):format(days, hours)
	end

	return ("%02d:%02d:%02d"):format(hours, minutes, remainingSeconds)
end

local function format_number(value: number): string
	local formatted = tostring(math.floor(value))
	while true do
		local replaced, count = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		formatted = replaced
		if count == 0 then
			return formatted
		end
	end
end

local function get_card_title(reward: dailyRewardData.Reward): string
	if reward.Type == "Cash" then
		return "CASH"
	elseif reward.Type == "XP" then
		return "XP"
	elseif reward.Type == "RacePassXP" then
		return "PASS XP"
	end

	return reward.Item or "ITEM"
end

local function get_reward_accent(reward: dailyRewardData.Reward): Color3
	if reward.Type == "Cash" then
		return GOLD_COLOR
	elseif reward.Type == "XP" then
		return CYAN_COLOR
	elseif reward.Type == "RacePassXP" then
		return PURPLE_COLOR
	end

	return GREEN_COLOR
end

local function get_daily_state(): dailyRewardData.State
	local rawState = dataUtility.client.get(DAILY_REWARD_PATH)
	if type(rawState) ~= "table" then
		return dailyRewardData.create_state(os.time())
	end

	local state = rawState :: dailyRewardData.State
	if type(state.Claimed) ~= "table" then
		state.Claimed = {}
	end
	return state
end

local function get_or_create_claim_label(button: ImageButton): TextLabel
	local existingLabel = button:FindFirstChild(CLAIM_LABEL_NAME)
	if existingLabel and existingLabel:IsA("TextLabel") then
		return existingLabel
	end

	local label = Instance.new("TextLabel")
	label.Name = CLAIM_LABEL_NAME
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.08, 0.15)
	label.Size = UDim2.fromScale(0.84, 0.7)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = WHITE_COLOR
	label.TextScaled = true
	label.Text = "CLAIM"
	label.ZIndex = button.ZIndex + 1
	label.Parent = button
	return label
end

local function set_model_visible(model: Model, isVisible: boolean): ()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = if isVisible then 0 else 1
			descendant.LocalTransparencyModifier = if isVisible then 0 else 1
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = if isVisible then 0 else 1
		end
	end
end

local function configure_viewport(viewport: ViewportFrame, model: Model): ()
	local camera = viewport:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = viewport
	end

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local focus = boundsCFrame.Position
	local distance = math.max(boundsSize.X, boundsSize.Y, boundsSize.Z) * 2.4
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.7, distance * 0.35, distance), focus)
	viewport.CurrentCamera = camera
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Ambient = Color3.fromRGB(190, 190, 190)
end

local function configure_reward_card(card: Frame, reward: dailyRewardData.Reward): CardView?
	local valueLabel = card:FindFirstChild("Title1")
	local statusLabel = card:FindFirstChild("Title2")
	local button = card:FindFirstChild("Button")
	if not valueLabel or not valueLabel:IsA("TextLabel") or not statusLabel or not statusLabel:IsA("TextLabel") then
		return nil
	end
	if not button or not button:IsA("ImageButton") then
		return nil
	end

	button:SetAttribute("UIAnimTarget", "ParentScale")
	local accent = get_reward_accent(reward)
	local cash = card:FindFirstChild("Cash")
	local xp = card:FindFirstChild("Xp")
	local viewport = card:FindFirstChild("ViewportFrame")
	local bg = card:FindFirstChild("Bg")
	local effect = card:FindFirstChild("Effect")

	card.LayoutOrder = reward.Id
	card.Visible = true
	card.ZIndex = 5
	card.ClipsDescendants = true
	if cash and cash:IsA("ImageLabel") then
		cash.Visible = reward.Type == "Cash"
		cash.ZIndex = 3
		cash.Position = UDim2.fromScale(0.12, 0.2)
		cash.Size = UDim2.fromScale(0.76, 0.56)
		local quantity = cash:FindFirstChild("Quantity")
		if quantity and quantity:IsA("TextLabel") then
			quantity.Text = format_number(reward.Amount or 0)
			quantity.ZIndex = 4
		end
	end
	if xp and xp:IsA("ImageLabel") then
		xp.Visible = reward.Type == "XP" or reward.Type == "RacePassXP"
		xp.ZIndex = 3
		xp.Position = UDim2.fromScale(0.12, 0.2)
		xp.Size = UDim2.fromScale(0.76, 0.56)
		local quantity = xp:FindFirstChild("Quantity")
		if quantity and quantity:IsA("TextLabel") then
			quantity.Text = format_number(reward.Amount or 0)
			quantity.ZIndex = 4
		end
	end
	if viewport and viewport:IsA("ViewportFrame") then
		viewport.Visible = reward.Type == "Helmets" or reward.Type == "Livery"
		viewport.ZIndex = 3
		viewport.Position = UDim2.fromScale(0.08, 0.2)
		viewport.Size = UDim2.fromScale(0.84, 0.56)
		local car = viewport:FindFirstChild("Car")
		local helmets = viewport:FindFirstChild("Helmets")
		local rig = viewport:FindFirstChild("Rig")
		if car and car:IsA("Model") then
			set_model_visible(car, reward.Type == "Livery")
		end
		if helmets and helmets:IsA("Model") then
			set_model_visible(helmets, reward.Type == "Helmets")
			if reward.Type == "Helmets" then
				configure_viewport(viewport, helmets)
			end
		end
		if rig and rig:IsA("Model") then
			set_model_visible(rig, false)
		end
		if car and car:IsA("Model") and reward.Type == "Livery" then
			configure_viewport(viewport, car)
		end
	end
	if bg and bg:IsA("ImageLabel") then
		bg.Visible = true
		bg.ZIndex = 1
	end
	if effect and effect:IsA("Frame") then
		effect.Visible = true
		effect.ZIndex = 1
	end

	local stroke = card:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		stroke.Color = accent
	end
	valueLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	valueLabel.Position = UDim2.fromScale(0.5, 0.11)
	valueLabel.Size = UDim2.fromScale(0.84, 0.15)
	valueLabel.TextScaled = false
	valueLabel.TextSize = 16
	valueLabel.TextWrapped = false
	valueLabel.Text = get_card_title(reward)
	valueLabel.TextColor3 = accent
	valueLabel.ZIndex = 7
	statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	statusLabel.Position = UDim2.fromScale(0.5, 0.91)
	statusLabel.Size = UDim2.fromScale(0.84, 0.12)
	statusLabel.TextScaled = false
	statusLabel.TextSize = 13
	statusLabel.TextWrapped = false
	statusLabel.Text = ("DAY %d  •  LOCKED"):format(reward.Id)
	statusLabel.TextColor3 = MUTED_COLOR
	statusLabel.ZIndex = 7
	local title1Aspect = valueLabel:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if title1Aspect then
		title1Aspect.AspectRatio = 5
	end
	local title2Aspect = statusLabel:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if title2Aspect then
		title2Aspect.AspectRatio = 7
	end
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.5, 0.78)
	button.Size = UDim2.fromScale(0.78, 0.2)
	button.ImageColor3 = accent
	button.ImageTransparency = 0
	button.AutoButtonColor = false
	button.ZIndex = 8
	local buttonAspect = button:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if buttonAspect then
		buttonAspect.AspectRatio = 3.4
	end
	local buttonLabel = get_or_create_claim_label(button)
	buttonLabel.Position = UDim2.fromScale(0.08, 0.15)
	buttonLabel.Size = UDim2.fromScale(0.84, 0.7)
	buttonLabel.TextScaled = false
	buttonLabel.TextSize = 15
	buttonLabel.Text = "LOCKED"
	buttonLabel.ZIndex = 9

	return {
		frame = card,
		valueLabel = valueLabel,
		statusLabel = statusLabel,
		button = button,
		buttonLabel = buttonLabel,
	}
end

local function get_or_build_cards(frame: Frame): { [number]: CardView }?
	local rewards = frame:FindFirstChild(REWARDS_CONTAINER_NAME)
	if not rewards or not rewards:IsA("Frame") then
		return nil
	end

	local grid = rewards:FindFirstChildWhichIsA("UIGridLayout")
	if grid then
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.FillDirectionMaxCells = DAILY_GRID_MAX_COLUMNS
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.VerticalAlignment = Enum.VerticalAlignment.Center
	end

	local existingCards: { [number]: CardView } = {}
	local hasAllCards = true
	for _, reward in dailyRewardData.Items do
		local existingCard = rewards:FindFirstChild("Reward" .. tostring(reward.Id))
		if not existingCard or not existingCard:IsA("Frame") then
			hasAllCards = false
			break
		end
	end

	if hasAllCards then
		for _, reward in dailyRewardData.Items do
			local card = rewards:FindFirstChild("Reward" .. tostring(reward.Id))
			local view = card and configure_reward_card(card :: Frame, reward)
			if not view then
				return nil
			end
			existingCards[reward.Id] = view
		end
		return existingCards
	end

	local template = rewards:FindFirstChild(REWARD_TEMPLATE_NAME)
	if not template or not template:IsA("Frame") then
		return nil
	end

	for _, child in rewards:GetChildren() do
		if child:IsA("GuiObject") and child.Name:match("^Reward%d+$") then
			child:Destroy()
		end
	end

	template.Name = "Reward1"
	for _, reward in dailyRewardData.Items do
		local card = if reward.Id == 1 then template else template:Clone()
		card.Name = "Reward" .. tostring(reward.Id)
		card.Parent = rewards
		local view = configure_reward_card(card, reward)
		if not view then
			return nil
		end
		existingCards[reward.Id] = view
	end

	return existingCards
end

local function bind_existing_interface(frame: Frame): boolean
	local title = frame:FindFirstChild("Tittle")
	local titleText = title and title:FindFirstChild("Play")
	local views = get_or_build_cards(frame)
	if not titleText or not titleText:IsA("TextLabel") or not views then
		return false
	end

	titleLabel = titleText
	cardViews = views
	return true
end

local function render_cards(): ()
	local state = get_daily_state()
	local now = os.time()
	local claimedCount = 0
	for _, reward in dailyRewardData.Items do
		local cardView = cardViews[reward.Id]
		if not cardView then
			continue
		end

		local claimed = dailyRewardData.is_claimed(state, reward.Id)
		local unlocked = dailyRewardData.is_unlocked(state, reward.Id, now)
		local remaining = dailyRewardData.get_remaining_time(state, reward.Id, now)
		if claimed then
			claimedCount += 1
		end

		cardView.frame.BackgroundColor3 = if claimed then CLAIMED_CARD_COLOR elseif unlocked then CARD_COLOR else LOCKED_CARD_COLOR
		cardView.statusLabel.Text = if claimed then ("DAY %d  •  CLAIMED"):format(reward.Id) elseif unlocked then ("DAY %d  •  READY"):format(reward.Id) else ("DAY %d  •  IN %s"):format(reward.Id, format_time(remaining))
		cardView.statusLabel.TextColor3 = if claimed then GREEN_COLOR elseif unlocked then get_reward_accent(reward) else MUTED_COLOR
		cardView.button.Active = not claimed and unlocked
		cardView.buttonLabel.Text = if claimed then "CLAIMED" elseif unlocked then "CLAIM" else "LOCKED"
		cardView.buttonLabel.TextColor3 = if claimed or unlocked then WHITE_COLOR else MUTED_COLOR
		cardView.button.ImageColor3 = if claimed then Color3.fromRGB(56, 113, 101) elseif unlocked then get_reward_accent(reward) else Color3.fromRGB(55, 73, 111)
	end

	if titleLabel then
		titleLabel.Text = ("DAILY REWARD  •  %d/%d"):format(
			claimedCount,
			dailyRewardData.get_reward_count()
		)
	end
end

local function update_clock(): ()
	local currentSecond = os.time()
	if currentSecond == lastClockSecond then
		return
	end
	lastClockSecond = currentSecond
	if dailyRewardFrame and dailyRewardFrame.Visible then
		render_cards()
	end
end

local function bind_data(path: string, callback: () -> ()): ()
	local connection = dataUtility.client.bind(path, callback)
	if connection then
		table.insert(dataConnections, connection :: DataConnection)
	end
end

local function bind_card_buttons(): ()
	for _, reward in dailyRewardData.Items do
		local cardView = cardViews[reward.Id]
		if not cardView then
			continue
		end

		table.insert(cardConnections, cardView.button.Activated:Connect(function()
			if cardView.button.Active and dailyRewardAction then
				dailyRewardAction:FireServer("Claim", reward.Id)
			end
		end))
	end
end

local function disconnect_data_connections(): ()
	for _, connection in dataConnections do
		connection:disconnect()
	end
	dataConnections = {}
end

local function disconnect_card_connections(): ()
	for _, connection in cardConnections do
		connection:Disconnect()
	end
	cardConnections = {}
end

local function on_action_result(isSuccessful: boolean, code: string, rewardId: number?, _reward: any): ()
	if not isSuccessful then
		warn(("[DailyRewardController] Claim %s for reward %s"):format(code, tostring(rewardId)))
	end
	render_cards()
end

------------------//MAIN FUNCTIONS
local function daily_reward_controller_enable(): boolean
	if isEnabled then
		return true
	end

	dailyRewardFrame = get_daily_reward_frame()
	if not dailyRewardFrame then
		warn("[DailyRewardController] DailyReward UI not found")
		return false
	end

	dataUtility.client.ensure_remotes()
	dailyRewardAction = get_action_remote()
	if not dailyRewardAction then
		warn("[DailyRewardController] DailyRewardAction remote not found")
		return false
	end
	if not bind_existing_interface(dailyRewardFrame) then
		warn("[DailyRewardController] Existing DailyReward UI is incomplete")
		return false
	end

	remoteConnection = dailyRewardAction.OnClientEvent:Connect(on_action_result)
	bind_card_buttons()
	bind_data(DAILY_REWARD_PATH, render_cards)
	timerConnection = RunService.Heartbeat:Connect(update_clock)
	isEnabled = true
	lastClockSecond = 0
	render_cards()
	dailyRewardAction:FireServer("Sync")
	return true
end

local function daily_reward_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_data_connections()
	disconnect_card_connections()
	if remoteConnection then
		remoteConnection:Disconnect()
		remoteConnection = nil
	end
	if timerConnection then
		timerConnection:Disconnect()
		timerConnection = nil
	end
	cardViews = {}
	titleLabel = nil
	dailyRewardFrame = nil
	dailyRewardAction = nil
	isEnabled = false
end

------------------//INIT
return {
	enable = daily_reward_controller_enable,
	disable = daily_reward_controller_disable,
}
