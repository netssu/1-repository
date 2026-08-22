------------------//SERVICES
local MarketplaceService: MarketplaceService = game:GetService("MarketplaceService")
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local RACING_PASS_PAGE_NAME: string = "RacingPass"
local RACING_PASS_CONTENT_NAME: string = "RacingPass"
local REWARDS_NAME: string = "RacingpassRewards"
local FREE_PASS_NAME: string = "FreeRacingPass"
local PREMIUM_PASS_NAME: string = "VIPRacingPass"
local SCROLLING_FRAME_NAME: string = "ScrollingFrame"
local REWARD_TEMPLATE_NAME: string = "Reward"
local LEVEL_DISPLAY_NAME: string = "RacingpassLVL"
local LEVEL_LABEL_NAME: string = "Level"
local XP_FRAME_NAME: string = "XPbarFrame"
local XP_BACKGROUND_NAME: string = "XpBarBG"
local XP_BAR_NAME: string = "XpBar"
local XP_AMOUNT_NAME: string = "XPAmount"
local PASS_BACKGROUND_NAME: string = "RacingPassBG"
local PREMIUM_BACKGROUND_NAME: string = "VipPassBG"
local LOCKED_SHADE_NAME: string = "LockedShade"
local SKIP_ONE_NAME: string = "SkipOne"
local SKIP_FIVE_NAME: string = "SkipFive"
local COMPLETE_SKIP_NAME: string = "CompleteSkip"
local BUTTON_NAME: string = "Button"
local CASH_NAME: string = "Cash"
local XP_NAME: string = "Xp"
local QUANTITY_NAME: string = "Quantity"
local VIEWPORT_NAME: string = "ViewportFrame"
local TITLE_ONE_NAME: string = "Title1"
local TITLE_TWO_NAME: string = "Title2"
local PROFILE_REMOTES_FOLDER_NAME: string = "ProfileRemotes"
local ACTION_REMOTE_NAME: string = "RacingPassAction"
local MAX_XP_PROGRESS: number = 1
local EMPTY_REWARD_CARD_SCALE: number = 0.72
local UI_LIST_LAYOUT_NAME: string = "UIListLayout"
local LOCKED_COLOR: Color3 = Color3.fromRGB(117, 117, 117)
local UNLOCKED_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local CLAIMED_COLOR: Color3 = Color3.fromRGB(255, 226, 120)
local LOCKED_TEXT_COLOR: Color3 = Color3.fromRGB(210, 210, 210)
local PREMIUM_TEXT_COLOR: Color3 = Color3.fromRGB(255, 226, 120)

type DataConnection = {
	disconnect: (self: DataConnection) -> (),
}

type PassData = {
	RacingpassOwned: boolean?,
	RacingpassLevel: number?,
	NormalClaim: { [string]: boolean }?,
	PremiumClaim: { [string]: boolean }?,
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local racingPassData = require(modules:WaitForChild("Data"):WaitForChild("RacingPassData"))
local inventoryAssetRenderer = require(modules:WaitForChild("Interface"):WaitForChild("InventoryAssetRenderer"))
local inventoryCardEffects = require(modules:WaitForChild("Interface"):WaitForChild("InventoryCardEffects"))
local profileRemotes: Folder = ReplicatedStorage:WaitForChild(PROFILE_REMOTES_FOLDER_NAME)
local racingPassAction: RemoteEvent = profileRemotes:WaitForChild(ACTION_REMOTE_NAME) :: RemoteEvent

type Reward = racingPassData.Reward

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local freeScrollingFrame: ScrollingFrame?
local premiumScrollingFrame: ScrollingFrame?
local xpBar: Frame?
local xpAmount: TextLabel?
local levelLabel: TextLabel?
local premiumLockedShade: GuiObject?
local cardConnections: { RBXScriptConnection } = {}
local dataConnections: { DataConnection } = {}
local isEnabled: boolean = false
local isPremiumOwned: boolean = false

------------------//FUNCTIONS
local function get_racing_pass_canvas(): Frame?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local canvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	local page = canvas and canvas:FindFirstChild(RACING_PASS_PAGE_NAME)
	local content = page and page:FindFirstChild(RACING_PASS_CONTENT_NAME)
	if content and content:IsA("Frame") then
		return content
	end

	return nil
end

local function get_number(path: string, defaultValue: number): number
	return tonumber(dataUtility.client.get(path)) or defaultValue
end

local function get_pass_data(): PassData
	local passData = dataUtility.client.get("Profile.RacingPass")
	return if type(passData) == "table" then passData :: PassData else {}
end

local function format_number(value: number): string
	local text = tostring(math.floor(value))
	local left, number, right = string.match(text, "^([^%d]*%d)(%d*)(.-)$")
	if not left or not number or not right then
		return text
	end

	return left .. (number:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function scale_card_size(size: UDim2, scaleFactor: number): UDim2
	return UDim2.new(
		size.X.Scale * scaleFactor,
		size.X.Offset * scaleFactor,
		size.Y.Scale * scaleFactor,
		size.Y.Offset * scaleFactor
	)
end

local function center_scrolling_frame_items(scrollingFrame: ScrollingFrame): ()
	local layout = scrollingFrame:FindFirstChild(UI_LIST_LAYOUT_NAME)
	if layout and layout:IsA("UIListLayout") then
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
	end

	local centeredCanvasPositionY = math.max(
		0,
		(scrollingFrame.AbsoluteCanvasSize.Y - scrollingFrame.AbsoluteSize.Y) * 0.5
	)
	scrollingFrame.CanvasPosition = Vector2.new(scrollingFrame.CanvasPosition.X, centeredCanvasPositionY)
end

local function get_reward(passType: string, level: number): Reward?
	local rewards = racingPassData.REWARDS[passType]
	local reward = rewards and rewards[level]
	return if type(reward) == "table" then reward else nil
end

local function get_card_button(card: GuiObject): GuiButton?
	local button = card:FindFirstChild(BUTTON_NAME)
	if button and button:IsA("GuiButton") then
		return button
	end

	return nil
end

local function get_card_title(card: GuiObject, titleName: string): TextLabel?
	local title = card:FindFirstChild(titleName)
	if title and title:IsA("TextLabel") then
		return title
	end

	return nil
end

local function set_card_background(card: GuiObject, color: Color3): ()
	local background = card:FindFirstChild("Bg")
	if not background or not background:IsA("ImageLabel") then
		return
	end

	background.ImageColor3 = color
end

local function clear_reward_card(card: GuiObject): ()
	local cash = card:FindFirstChild(CASH_NAME)
	local xp = card:FindFirstChild(XP_NAME)
	local viewport = card:FindFirstChild(VIEWPORT_NAME)
	local cashQuantity = cash and cash:FindFirstChild(QUANTITY_NAME)
	local xpQuantity = xp and xp:FindFirstChild(QUANTITY_NAME)
	if cash and cash:IsA("GuiObject") then
		cash.Visible = false
	end
	if xp and xp:IsA("GuiObject") then
		xp.Visible = false
	end
	if viewport and viewport:IsA("ViewportFrame") then
		viewport.Visible = false
	end
	if cashQuantity and cashQuantity:IsA("TextLabel") then
		cashQuantity.Text = ""
	end
	if xpQuantity and xpQuantity:IsA("TextLabel") then
		xpQuantity.Text = ""
	end
end

local function get_asset_config(rewardType: string): { category: string, assetFolderNames: { string } }?
	if rewardType == "Suit" then
		return { category = "Suit", assetFolderNames = { "Suits" } }
	end
	if rewardType == "Livery" then
		return { category = "Livery", assetFolderNames = { "Livery" } }
	end
	if rewardType == "Helmets" then
		return { category = "Helmets", assetFolderNames = { "Helmets" } }
	end

	return nil
end

local function render_reward(card: GuiObject, reward: Reward?): ()
	clear_reward_card(card)
	if not reward then
		return
	end

	local cash = card:FindFirstChild(CASH_NAME)
	local xp = card:FindFirstChild(XP_NAME)
	local viewport = card:FindFirstChild(VIEWPORT_NAME)
	if reward.Type == "Cash" then
		local quantity = cash and cash:FindFirstChild(QUANTITY_NAME)
		if cash and cash:IsA("GuiObject") then
			cash.Visible = true
		end
		if quantity and quantity:IsA("TextLabel") then
			quantity.Text = "$" .. format_number(tonumber(reward.Amount) or 0)
		end
		return
	end

	local assetConfig = get_asset_config(reward.Type)
	if not assetConfig or not viewport or not viewport:IsA("ViewportFrame") or type(reward.Item) ~= "string" then
		return
	end

	viewport.Visible = inventoryAssetRenderer.render(viewport, assetConfig, reward.Item)
	if xp and xp:IsA("GuiObject") then
		xp.Visible = false
	end
end

local function is_claimed(passData: PassData, passType: string, level: number): boolean
	local claims = if passType == "Premium" then passData.PremiumClaim else passData.NormalClaim
	return type(claims) == "table" and claims[tostring(level)] == true
end

local function update_card_state(card: GuiObject, passData: PassData, passType: string, level: number): ()
	local reward = get_reward(passType, level)
	local title = get_card_title(card, TITLE_TWO_NAME)
	local claimed = is_claimed(passData, passType, level)
	local unlocked = (tonumber(passData.RacingpassLevel) or 1) >= level
	local lockedPremium = passType == "Premium" and not isPremiumOwned
	if not reward then
		if title then
			title.Text = ""
		end
		set_card_background(card, if unlocked then UNLOCKED_COLOR else LOCKED_COLOR)
		return
	end

	if lockedPremium then
		if title then
			title.Text = "PREMIUM"
			title.TextColor3 = PREMIUM_TEXT_COLOR
		end
		set_card_background(card, LOCKED_COLOR)
		return
	end

	if claimed then
		if title then
			title.Text = "CLAIMED"
			title.TextColor3 = CLAIMED_COLOR
		end
		set_card_background(card, CLAIMED_COLOR)
		return
	end

	if unlocked then
		if title then
			title.Text = "CLAIM"
			title.TextColor3 = UNLOCKED_COLOR
		end
		set_card_background(card, UNLOCKED_COLOR)
		return
	end

	if title then
		title.Text = "LOCKED"
		title.TextColor3 = LOCKED_TEXT_COLOR
	end
	set_card_background(card, LOCKED_COLOR)
end

local function refresh_xp_bar(): ()
	if not xpBar or not xpAmount or not levelLabel then
		return
	end

	local level = math.clamp(
		get_number("Profile.RacingPass.RacingpassLevel", racingPassData.MIN_LEVEL),
		racingPassData.MIN_LEVEL,
		racingPassData.MAX_LEVEL
	)
	local currentXp = math.max(0, get_number("Currency.RacePassXP", 0))
	levelLabel.Text = tostring(level)
	if level >= racingPassData.MAX_LEVEL then
		xpBar.Size = UDim2.new(MAX_XP_PROGRESS, 0, 1, 0)
		xpAmount.Text = tostring(currentXp) .. "/MAX"
		return
	end

	local requiredXp = racingPassData.LEVEL_REQUIREMENTS[level] or 1
	xpBar.Size = UDim2.new(math.clamp(currentXp / requiredXp, 0, MAX_XP_PROGRESS), 0, 1, 0)
	xpAmount.Text = tostring(currentXp) .. "/" .. tostring(requiredXp)
end

local function refresh_cards(): ()
	local passData = get_pass_data()
	isPremiumOwned = passData.RacingpassOwned == true
	if premiumLockedShade then
		premiumLockedShade.Visible = not isPremiumOwned
	end

	for _, config in {
		{ passType = "Normal", scrollingFrame = freeScrollingFrame },
		{ passType = "Premium", scrollingFrame = premiumScrollingFrame },
	} do
		local scrollingFrame = config.scrollingFrame
		if scrollingFrame then
			for level = racingPassData.MIN_LEVEL, racingPassData.MAX_LEVEL do
				local card = scrollingFrame:FindFirstChild(tostring(level))
				if card and card:IsA("GuiObject") then
					update_card_state(card, passData, config.passType, level)
				end
			end
		end
	end

	refresh_xp_bar()
end

local function prompt_purchase(productId: number): ()
	MarketplaceService:PromptProductPurchase(localPlayer, productId)
end

local function activate_card(passType: string, level: number): ()
	local reward = get_reward(passType, level)
	if not reward then
		return
	end

	if passType == "Premium" and not isPremiumOwned then
		prompt_purchase(racingPassData.PRODUCTS.RacingPass)
		return
	end

	local passData = get_pass_data()
	if (tonumber(passData.RacingpassLevel) or 1) < level or is_claimed(passData, passType, level) then
		return
	end

	racingPassAction:FireServer("Claim", level, passType)
end

local function bind_card_buttons(scrollingFrame: ScrollingFrame, passType: string): ()
	for level = racingPassData.MIN_LEVEL, racingPassData.MAX_LEVEL do
		local card = scrollingFrame:FindFirstChild(tostring(level))
		if not card or not card:IsA("GuiObject") then
			continue
		end

		local button = get_card_button(card)
		if not button then
			continue
		end

		button:SetAttribute("UIAnimTarget", "ParentScale")
		for _, connection in inventoryCardEffects.bind(button) do
			table.insert(cardConnections, connection)
		end
		table.insert(cardConnections, button.Activated:Connect(function()
			activate_card(passType, level)
		end))
	end
end

local function ensure_pass_cards(scrollingFrame: ScrollingFrame, passType: string): ()
	local template = scrollingFrame:WaitForChild(REWARD_TEMPLATE_NAME)
	template.Visible = false

	for level = racingPassData.MIN_LEVEL, racingPassData.MAX_LEVEL do
		local reward = get_reward(passType, level)
		local card = scrollingFrame:FindFirstChild(tostring(level))
		if not card or not card:IsA("GuiObject") then
			card = template:Clone()
			card.Name = tostring(level)
			card.LayoutOrder = level
			card.Parent = scrollingFrame
		end

		card.Visible = true
		card.Size = if reward then template.Size else scale_card_size(template.Size, EMPTY_REWARD_CARD_SCALE)
		local title = get_card_title(card, TITLE_ONE_NAME)
		if title then
			title.Text = tostring(level)
		end
		render_reward(card, reward)
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

local function on_action_result(isSuccessful: boolean, action: string, _value: any, _extra: any): ()
	if isSuccessful or action == "Claim" or action == "Purchase" then
		refresh_cards()
	end
end

local function disconnect_card_connections(): ()
	for _, connection in cardConnections do
		connection:Disconnect()
	end
	cardConnections = {}
end

------------------//MAIN FUNCTIONS
local function racing_pass_controller_enable(): boolean
	if isEnabled then
		return true
	end

	local content = get_racing_pass_canvas()
	local rewards = content and content:FindFirstChild(REWARDS_NAME)
	local freePass = rewards and rewards:FindFirstChild(FREE_PASS_NAME)
	local premiumPass = rewards and rewards:FindFirstChild(PREMIUM_PASS_NAME)
	local freeScroll = freePass and freePass:FindFirstChild(SCROLLING_FRAME_NAME)
	local premiumScroll = premiumPass and premiumPass:FindFirstChild(SCROLLING_FRAME_NAME)
	local xpFrame = content and content:FindFirstChild(XP_FRAME_NAME)
	local xpBackground = xpFrame and xpFrame:FindFirstChild(XP_BACKGROUND_NAME)
	local xpBarInstance = xpBackground and xpBackground:FindFirstChild(XP_BAR_NAME)
	local xpAmountInstance = xpBackground and xpBackground:FindFirstChild(XP_AMOUNT_NAME)
	local levelDisplay = content and content:FindFirstChild(LEVEL_DISPLAY_NAME)
	local levelInstance = levelDisplay and levelDisplay:FindFirstChild(LEVEL_LABEL_NAME)
	local passBackground = content and content:FindFirstChild(PASS_BACKGROUND_NAME)
	local premiumBackground = passBackground and passBackground:FindFirstChild(PREMIUM_BACKGROUND_NAME)
	local lockedShade = premiumBackground and premiumBackground:FindFirstChild(LOCKED_SHADE_NAME)
	if not content or not freeScroll or not freeScroll:IsA("ScrollingFrame") or not premiumScroll or not premiumScroll:IsA("ScrollingFrame") then
		warn("[RacingPassController] Racing Pass rewards UI not found")
		return false
	end
	if not xpBarInstance or not xpBarInstance:IsA("Frame") or not xpAmountInstance or not xpAmountInstance:IsA("TextLabel") or not levelInstance or not levelInstance:IsA("TextLabel") then
		warn("[RacingPassController] Racing Pass XP UI not found")
		return false
	end

	freeScrollingFrame = freeScroll
	premiumScrollingFrame = premiumScroll
	xpBar = xpBarInstance
	xpAmount = xpAmountInstance
	levelLabel = levelInstance
	premiumLockedShade = if lockedShade and lockedShade:IsA("GuiObject") then lockedShade else nil
	isEnabled = true
	dataUtility.client.ensure_remotes()
	ensure_pass_cards(freeScroll, "Normal")
	ensure_pass_cards(premiumScroll, "Premium")
	center_scrolling_frame_items(freeScroll)
	center_scrolling_frame_items(premiumScroll)
	bind_card_buttons(freeScroll, "Normal")
	bind_card_buttons(premiumScroll, "Premium")
	refresh_cards()

	local skipOne = content:FindFirstChild(SKIP_ONE_NAME)
	local skipFive = content:FindFirstChild(SKIP_FIVE_NAME)
	local completeSkip = content:FindFirstChild(COMPLETE_SKIP_NAME)
	if skipOne and skipOne:IsA("GuiButton") then
		table.insert(cardConnections, skipOne.Activated:Connect(function()
			prompt_purchase(racingPassData.PRODUCTS.SkipOne)
		end))
	end
	if skipFive and skipFive:IsA("GuiButton") then
		table.insert(cardConnections, skipFive.Activated:Connect(function()
			prompt_purchase(racingPassData.PRODUCTS.SkipFive)
		end))
	end
	if completeSkip and completeSkip:IsA("GuiButton") then
		table.insert(cardConnections, completeSkip.Activated:Connect(function()
			prompt_purchase(racingPassData.PRODUCTS.CompleteSkip)
		end))
	end
	if premiumBackground and premiumBackground:IsA("GuiButton") then
		table.insert(cardConnections, premiumBackground.Activated:Connect(function()
			if not isPremiumOwned then
				prompt_purchase(racingPassData.PRODUCTS.RacingPass)
			end
		end))
	end

	table.insert(cardConnections, racingPassAction.OnClientEvent:Connect(on_action_result))
	bind_data("Currency.RacePassXP", refresh_xp_bar)
	bind_data("Profile.RacingPass.RacingpassLevel", refresh_cards)
	bind_data("Profile.RacingPass.RacingpassOwned", refresh_cards)
	bind_data("Profile.RacingPass.NormalClaim", refresh_cards)
	bind_data("Profile.RacingPass.PremiumClaim", refresh_cards)
	return true
end

local function racing_pass_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_card_connections()
	disconnect_data_connections()
	freeScrollingFrame = nil
	premiumScrollingFrame = nil
	xpBar = nil
	xpAmount = nil
	levelLabel = nil
	premiumLockedShade = nil
	isPremiumOwned = false
	isEnabled = false
end

------------------//INIT
return {
	enable = racing_pass_controller_enable,
	disable = racing_pass_controller_disable,
}
