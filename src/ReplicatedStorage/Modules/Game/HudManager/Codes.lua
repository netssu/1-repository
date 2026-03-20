------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//CONSTANTS
local SUCCESS_COLOR = Color3.fromRGB(85, 255, 127)
local ERROR_COLOR = Color3.fromRGB(255, 85, 85)
local WAIT_FEEDBACK_TIME = 2

------------------//VARIABLES
local CodesController = {}
local localPlayer = Players.LocalPlayer

local remotesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes")
local redeemRemote = remotesFolder:WaitForChild("RedeemCode")

local isDebounce = false
local originalTextColor = Color3.fromRGB(255, 255, 255) -- Default fallback

------------------//FUNCTIONS

local function get_ui_references()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	if not playerGui then return nil end

	local mainScreen = playerGui:WaitForChild("UI", 5) 
	if not mainScreen then 
		warn("CodesController: ScreenGui 'UI' not found.")
		return nil 
	end

	local codesFrame = mainScreen:FindFirstChild("Codes", true)
	if not codesFrame then return nil end

	local codesBG = codesFrame:FindFirstChild("CodesBG")
	local closeBT = codesFrame:FindFirstChild("CloseBT") 

	local confirmBT = codesBG and codesBG:FindFirstChild("ConfirmBT")
	local textboxBG = codesBG and codesBG:FindFirstChild("TextboxBG")
	local textBox = textboxBG and textboxBG:FindFirstChild("TextBox")

	return {
		Main = codesFrame,
		Container = codesBG,
		ConfirmBT = confirmBT,
		CloseBT = closeBT,
		TextBox = textBox
	}
end

local function set_feedback(ui, message, color)
	if not ui.TextBox then return end

	ui.TextBox.TextEditable = false
	ui.TextBox.Text = message
	ui.TextBox.TextColor3 = color
	ui.TextBox.ClearTextOnFocus = false

	task.delay(WAIT_FEEDBACK_TIME, function()
		if ui.TextBox and ui.TextBox.Parent then
			if ui.TextBox.Text == message then
				ui.TextBox.Text = ""
			end

			ui.TextBox.TextColor3 = originalTextColor
			ui.TextBox.TextEditable = true
			ui.TextBox.ClearTextOnFocus = true
			isDebounce = false
		end
	end)
end

local function request_redeem(ui)
	if isDebounce then return end

	local codeText = ui.TextBox.Text
	codeText = codeText:gsub("^%s*(.-)%s*$", "%1")

	if string.len(codeText) < 1 then return end

	isDebounce = true

	ui.TextBox.Text = "..." 
	ui.TextBox.TextEditable = false

	local result = redeemRemote:InvokeServer(codeText)

	if result == "SUCCESS" then
		set_feedback(ui, "SUCCESS!", SUCCESS_COLOR)
	elseif result == "ALREADY_REDEEMED" then
		set_feedback(ui, "ALREADY USED!", ERROR_COLOR)
	elseif result == "INVALID" then
		set_feedback(ui, "INVALID!", ERROR_COLOR)
	else
		set_feedback(ui, "ERROR!", ERROR_COLOR)
		warn("Codes Error:", result)
	end
end

local function setup_events(ui)
	if not ui.ConfirmBT then warn("CodesController: ConfirmBT not found") end
	if not ui.TextBox then warn("CodesController: TextBox not found") end
	if not ui.CloseBT then warn("CodesController: CloseBT not found") end

	if ui.ConfirmBT then
		ui.ConfirmBT.Activated:Connect(function()
			request_redeem(ui)
		end)
	end

	if ui.TextBox then
		ui.TextBox.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				request_redeem(ui)
			end
		end)

		ui.TextBox.Focused:Connect(function()
			if isDebounce then
				ui.TextBox.Text = ""
				ui.TextBox.TextColor3 = originalTextColor
				ui.TextBox.TextEditable = true
				isDebounce = false
			end
		end)
	end

	if ui.CloseBT then
		ui.CloseBT.Activated:Connect(function()
			ui.Main.Visible = false
		end)
	end
end

------------------//INIT

task.spawn(function()
	task.wait(1) 
	local ui = get_ui_references()
	if ui then
		if ui.TextBox then
			originalTextColor = ui.TextBox.TextColor3
		end

		setup_events(ui)
		print("CodesController: UI Loaded.")
	else
		warn("CodesController: Failed to load UI references.")
	end
end)

return CodesController