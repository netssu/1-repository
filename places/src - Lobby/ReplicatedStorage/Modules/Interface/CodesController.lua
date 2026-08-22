------------------//SERVICES
local Players: Players = game:GetService("Players")
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local MAIN_UI_NAME: string = "MainUI"
local CANVAS_NAME: string = "Canvas"
local CODES_FRAME_NAME: string = "Codes"
local CODE_CONTENT_FRAME_NAME: string = "Codes"
local FOLLOW_DEVS_FRAME_NAME: string = "FollowDevs"
local CREATOR_HOLDER_NAME: string = "Devholder"
local TEXTBOX_BACKGROUND_NAME: string = "TextboxBG"
local TEXTBOX_NAME: string = "TextBox"
local SUBMIT_BUTTON_NAME: string = "Submit"
local CLEAR_BUTTON_NAME: string = "Clear"
local REDEEM_REMOTE_NAME: string = "RedeemCode"
local CREATOR_CARD_NAMES: { string } = { "Madshba", "Bloodzcene" }
local CREATOR_USERNAMES: { string } = { "@netssudev", "@herckaos" }
local STATUS_RESET_DELAY: number = 2

------------------//DEPENDENCIES
local profileRemotes: Folder = ReplicatedStorage:WaitForChild("ProfileRemotes")
local redeemCode: RemoteEvent = profileRemotes:WaitForChild(REDEEM_REMOTE_NAME) :: RemoteEvent

------------------//VARIABLES
local localPlayer: Player = Players.LocalPlayer
local playerGui: PlayerGui = localPlayer:WaitForChild("PlayerGui")
local textBox: TextBox?
local submitButton: GuiButton?
local clearButton: GuiButton?
local connections: { RBXScriptConnection } = {}
local isSubmitting: boolean = false
local isEnabled: boolean = false

------------------//FUNCTIONS
local function get_codes_frame(): Frame?
	local mainUi = playerGui:FindFirstChild(MAIN_UI_NAME)
	local canvas = mainUi and mainUi:FindFirstChild(CANVAS_NAME)
	local codesFrame = canvas and canvas:FindFirstChild(CODES_FRAME_NAME)
	if codesFrame and codesFrame:IsA("Frame") then
		return codesFrame
	end

	return nil
end

local function set_input_enabled(isInputEnabled: boolean): ()
	if textBox then
		textBox.TextEditable = isInputEnabled
		textBox.Active = isInputEnabled
	end
	if submitButton then
		submitButton.Active = isInputEnabled
	end
	if clearButton then
		clearButton.Active = isInputEnabled
	end
end

local function clear_text(): ()
	if textBox then
		textBox.Text = ""
	end
end

local function show_status(message: string): ()
	if not textBox then
		return
	end

	textBox.Text = message
	set_input_enabled(false)
	task.delay(STATUS_RESET_DELAY, function()
		if not isEnabled or not textBox then
			return
		end

		clear_text()
		set_input_enabled(true)
	end)
end

local function format_reward(cash: number, xp: number): string
	return ("+%d COINS  |  +%d XP"):format(cash, xp)
end

local function handle_redeem_result(isSuccessful: boolean, _code: string?, cash: number?, xp: number?, reason: string?): ()
	isSubmitting = false

	if isSuccessful then
		show_status(format_reward(tonumber(cash) or 0, tonumber(xp) or 0))
		return
	end

	local statusMessage = if reason == "ALREADY_CLAIMED" then "ALREADY CLAIMED!" else "INVALID CODE!"
	show_status(statusMessage)
end

local function bind_creator_cards(codesFrame: Frame): ()
	local followDevs = codesFrame:FindFirstChild(FOLLOW_DEVS_FRAME_NAME)
	local creatorHolder = followDevs and followDevs:FindFirstChild(CREATOR_HOLDER_NAME)
	if not creatorHolder or not creatorHolder:IsA("Frame") then
		return
	end

	for index, cardName in CREATOR_CARD_NAMES do
		local card = creatorHolder:FindFirstChild(cardName)
		if not card or not card:IsA("Frame") then
			continue
		end

		card.Visible = true
		local username = card:FindFirstChild("TextLabel")
		if username and username:IsA("TextLabel") then
			username.Text = CREATOR_USERNAMES[index]
		end

		local image = card:FindFirstChild("ImageLabel")
		if image and image:IsA("ImageLabel") then
			task.spawn(function()
				local creatorName = string.gsub(CREATOR_USERNAMES[index], "^@", "")
				local userIdSuccess, userId = pcall(function()
					return Players:GetUserIdFromNameAsync(creatorName)
				end)
				if not userIdSuccess then
					return
				end

				local thumbnailSuccess, thumbnail = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
				end)
				if thumbnailSuccess and image.Parent then
					image.Image = thumbnail
				end
			end)
		end
	end

	for _, card in creatorHolder:GetChildren() do
		if card:IsA("Frame") and not table.find(CREATOR_CARD_NAMES, card.Name) then
			card.Visible = false
		end
	end
end

local function disconnect_connections(): ()
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}
end

------------------//MAIN FUNCTIONS
local function codes_controller_enable(): boolean
	if isEnabled then
		return true
	end

	local codesFrame = get_codes_frame()
	local codeContent = codesFrame and codesFrame:FindFirstChild(CODE_CONTENT_FRAME_NAME)
	local textboxBackground = codeContent and codeContent:FindFirstChild(TEXTBOX_BACKGROUND_NAME)
	local textboxInstance = textboxBackground and textboxBackground:FindFirstChild(TEXTBOX_NAME)
	local submitInstance = codeContent and codeContent:FindFirstChild(SUBMIT_BUTTON_NAME)
	local clearInstance = codeContent and codeContent:FindFirstChild(CLEAR_BUTTON_NAME)
	if not codesFrame or not codeContent then
		warn("[CodesController] MainUI.Canvas.Codes not found")
		return false
	end
	if not textboxInstance or not textboxInstance:IsA("TextBox") then
		warn("[CodesController] Codes textbox not found")
		return false
	end
	if not submitInstance or not submitInstance:IsA("GuiButton") then
		warn("[CodesController] Codes submit button not found")
		return false
	end
	if not clearInstance or not clearInstance:IsA("GuiButton") then
		warn("[CodesController] Codes clear button not found")
		return false
	end

	textBox = textboxInstance
	submitButton = submitInstance
	clearButton = clearInstance
	isEnabled = true
	bind_creator_cards(codesFrame)

	table.insert(connections, clearButton.Activated:Connect(clear_text))
	table.insert(connections, submitButton.Activated:Connect(function()
		if isSubmitting or not textBox then
			return
		end

		local code = textBox.Text
		if code:match("^%s*$") then
			show_status("ENTER A CODE!")
			return
		end

		isSubmitting = true
		set_input_enabled(false)
		redeemCode:FireServer(code)
	end))
	table.insert(connections, redeemCode.OnClientEvent:Connect(handle_redeem_result))
	return true
end

local function codes_controller_disable(): ()
	if not isEnabled then
		return
	end

	disconnect_connections()
	textBox = nil
	submitButton = nil
	clearButton = nil
	isSubmitting = false
	isEnabled = false
end

------------------//INIT
return {
	enable = codes_controller_enable,
	disable = codes_controller_disable,
}
