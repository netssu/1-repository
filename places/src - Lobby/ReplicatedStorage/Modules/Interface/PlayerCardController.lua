------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local PLAYER_CARD_NAME: string = "PlayerCardBG"
local STATS_NAME: string = "Stats"
local XP_PROGRESS_NAME: string = "XPProgress"
local SETTINGS_FRAME_NAME: string = "Settings"
local MAX_LEVEL: number = 100
local DEFAULT_LEVEL_REQUIREMENT: number = 1

type DataConnection = {
	disconnect: (self: DataConnection) -> (),
}

------------------//DEPENDENCIES
local modules: Folder = ReplicatedStorage:WaitForChild("Modules")
local dataUtility = require(modules:WaitForChild("Data"):WaitForChild("DataUtility"))
local levelRequirements = require(modules:WaitForChild("Data"):WaitForChild("LevelRequirements"))
local interfaceController = require(modules:WaitForChild("Interface"):WaitForChild("InterfaceController"))

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local card: ImageLabel?
local stats: Frame?
local xpProgress: Frame?
local dataConnections: { DataConnection } = {}
local cardConnections: { RBXScriptConnection } = {}
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_canvas(): Frame?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	if not mainUi or not mainUi:IsA("ScreenGui") then
		return nil
	end

	local canvasInstance = mainUi:FindFirstChild(CANVAS_NAME)
	if canvasInstance and canvasInstance:IsA("Frame") then
		return canvasInstance
	end

	return nil
end

local function get_number(path: string, defaultValue: number): number
	local value = tonumber(dataUtility.client.get(path))
	return value or defaultValue
end

local function update_xp_progress(): ()
	if not xpProgress then
		return
	end

	local currentLevel = math.clamp(get_number("Profile.Level", 1), 1, MAX_LEVEL)
	local currentXp = math.max(0, get_number("Currency.XP", 0))
	local nextLevel = math.min(MAX_LEVEL, currentLevel + 1)
	local requiredXp = levelRequirements[nextLevel] or DEFAULT_LEVEL_REQUIREMENT
	local progress = math.clamp(currentXp / requiredXp, 0, 1)
	local statsBackground = xpProgress:FindFirstChild("statsBG")
	local progressBackground = statsBackground and statsBackground:FindFirstChild("ImageLabel")
	local progressFrame = progressBackground and progressBackground:FindFirstChild("Frame")
	local nextLevelLabel = statsBackground and statsBackground:FindFirstChild("NextLVL")
	local xpLeftLabel = statsBackground and statsBackground:FindFirstChild("XPLeft")

	if progressFrame and progressFrame:IsA("Frame") then
		progressFrame.Size = UDim2.new(if currentLevel >= MAX_LEVEL then 1 else progress, 0, 1, 0)
	end
	if nextLevelLabel and nextLevelLabel:IsA("TextLabel") then
		nextLevelLabel.Text = if currentLevel >= MAX_LEVEL then "MAX" else "LVL " .. tostring(nextLevel)
	end
	if xpLeftLabel and xpLeftLabel:IsA("TextLabel") then
		xpLeftLabel.Text = if currentLevel >= MAX_LEVEL then tostring(currentXp) .. "/MAX" else tostring(currentXp) .. "/" .. tostring(requiredXp) .. " XP"
	end
end

local function update_stats(): ()
	if not stats then
		return
	end

	local statsBackground = stats:FindFirstChild("statsBG")
	local winsLabel = statsBackground and statsBackground:FindFirstChild("Firstplaces")
	local matchesLabel = statsBackground and statsBackground:FindFirstChild("Matches")
	if winsLabel and winsLabel:IsA("TextLabel") then
		winsLabel.Text = "Total Wins    " .. tostring(get_number("Profile.Statistics.Wins", 0))
	end
	if matchesLabel and matchesLabel:IsA("TextLabel") then
		matchesLabel.Text = "Total Laps    " .. tostring(get_number("Profile.Statistics.Matches", 0))
	end
end

local function update_card(): ()
	if not card then
		return
	end

	local profileImageButton = card:FindFirstChild("PlayerStatsbutton")
	local profileImage = profileImageButton and profileImageButton:FindFirstChild("ProfileImage")
	local username = card:FindFirstChild("Username")
	local level = card:FindFirstChild("Level")
	local money = card:FindFirstChild("Money")
	local rank = card:FindFirstChild("Rank")

	if profileImage and profileImage:IsA("ImageLabel") then
		local image = Players:GetUserThumbnailAsync(localPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		profileImage.Image = image
	end
	if username and username:IsA("TextLabel") then
		username.Text = localPlayer.Name
	end
	if level and level:IsA("TextButton") then
		level.Text = "LVL " .. tostring(get_number("Profile.Level", 1))
	end
	if money and money:IsA("TextLabel") then
		money.Text = "$" .. tostring(get_number("Currency.Cash", 0))
	end
	if rank and rank:IsA("TextLabel") then
		rank.Text = "RR " .. tostring(get_number("Profile.Statistics.Rank", 0))
	end

	update_stats()
	update_xp_progress()
end

local function disconnect_data_connections(): ()
	for _, connection in dataConnections do
		if connection and connection.disconnect then
			connection:disconnect()
		end
	end
	dataConnections = {}
end

local function bind_data(path: string, callback: () -> ()): ()
	local connection = dataUtility.client.bind(path, callback)
	if connection then
		table.insert(dataConnections, connection :: DataConnection)
	end
end

local function hide_card_overlays(): ()
	if stats then
		stats.Visible = false
	end
	if xpProgress then
		xpProgress.Visible = false
	end
end

local function open_settings(): ()
	hide_card_overlays()
	local settings = interfaceController.get_frame(SETTINGS_FRAME_NAME)
	if settings then
		interfaceController.navigate_to(SETTINGS_FRAME_NAME, "Home")
	end
end

local function toggle_stats(): ()
	if not stats then
		return
	end

	stats.Visible = not stats.Visible
	if stats.Visible and xpProgress then
		xpProgress.Visible = false
	end
	if stats.Visible then
		update_stats()
	end
end

local function toggle_xp_progress(): ()
	if not xpProgress then
		return
	end

	xpProgress.Visible = not xpProgress.Visible
	if xpProgress.Visible and stats then
		stats.Visible = false
	end
end

local function bind_card_buttons(): ()
	if not card then
		return
	end

	local statsButton = card:FindFirstChild("PlayerStatsbutton")
	local settingsButton = card:FindFirstChild("Settings")
	local levelButton = card:FindFirstChild("Level")
	if statsButton and statsButton:IsA("GuiButton") then
		table.insert(cardConnections, statsButton.Activated:Connect(toggle_stats))
	end
	if settingsButton and settingsButton:IsA("GuiButton") then
		table.insert(cardConnections, settingsButton.Activated:Connect(open_settings))
	end
	if levelButton and levelButton:IsA("GuiButton") then
		table.insert(cardConnections, levelButton.Activated:Connect(toggle_xp_progress))
	end
	if card:IsA("GuiObject") then
		table.insert(cardConnections, card.MouseEnter:Connect(function()
			if stats and not stats.Visible and xpProgress then
				xpProgress.Visible = true
			end
		end))
		table.insert(cardConnections, card.MouseLeave:Connect(function()
			if xpProgress then
				xpProgress.Visible = false
			end
		end))
	end
end

local function disconnect_card_connections(): ()
	for _, connection in cardConnections do
		connection:Disconnect()
	end
	cardConnections = {}
end

------------------//MAIN FUNCTIONS
local function player_card_controller_enable(): boolean
	if isEnabled then
		return true
	end

	local canvas = get_canvas()
	if not canvas then
		warn("[PlayerCardController] MainUI.Canvas not found")
		return false
	end

	local cardInstance = canvas:FindFirstChild(PLAYER_CARD_NAME)
	local statsInstance = canvas:FindFirstChild(STATS_NAME)
	local xpProgressInstance = canvas:FindFirstChild(XP_PROGRESS_NAME)
	if not cardInstance or not cardInstance:IsA("ImageLabel") then
		warn("[PlayerCardController] PlayerCardBG not found")
		return false
	end
	if not statsInstance or not statsInstance:IsA("Frame") then
		warn("[PlayerCardController] Stats not found")
		return false
	end
	if not xpProgressInstance or not xpProgressInstance:IsA("Frame") then
		warn("[PlayerCardController] XPProgress not found")
		return false
	end

	card = cardInstance
	stats = statsInstance
	xpProgress = xpProgressInstance
	dataUtility.client.ensure_remotes()
	update_card()
	bind_card_buttons()
	bind_data("Currency.Cash", update_card)
	bind_data("Currency.XP", update_xp_progress)
	bind_data("Profile.Level", update_card)
	bind_data("Profile.Statistics.Rank", update_card)
	bind_data("Profile.Statistics.Wins", update_stats)
	bind_data("Profile.Statistics.Matches", update_stats)
	isEnabled = true
	return true
end

local function player_card_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_data_connections()
	disconnect_card_connections()
	hide_card_overlays()
	card = nil
	stats = nil
	xpProgress = nil
	isEnabled = false
end

------------------//INIT
return {
	enable = player_card_controller_enable,
	disable = player_card_controller_disable,
}
