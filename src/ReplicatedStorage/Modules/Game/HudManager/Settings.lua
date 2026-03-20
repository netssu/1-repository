-- SERVICES
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- CONSTANTS
local localPlayer = Players.LocalPlayer
local SETTINGS_CONFIG = {
	{ key = "Music",   name = "Music",         desc = "Enable or disable the game music" },
	{ key = "SFX",     name = "Sound Effects", desc = "Enable or disable sound effects" },
	{ key = "Shadows", name = "Shadows",       desc = "Enable or disable game shadows" },
}
local TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- VARIABLES
local SettingsController = {}
local SoundController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Utility"):WaitForChild("SoundUtility"))
local settingsState = {
	Music   = true,
	SFX     = true,
	Shadows = true,
}

-- FUNCTIONS
local function get_ui()
	local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
	local gui       = playerGui:WaitForChild("GUI", 10)
	local settings  = gui:WaitForChild("Settings", 10)
	local scrolling = settings:WaitForChild("ScrollingFrame", 10)
	local template  = scrolling:WaitForChild("SettingHolder", 10)
	return {
		ScrollingFrame = scrolling,
		Template       = template,
	}
end

local function set_toggle_visual(holder, isOn, animate, sizeOff, sizeOn)
	local holderOff    = holder:WaitForChild("ToggleHolderOff")
	local holderOn     = holder:WaitForChild("ToggleHolderOn")
	
	if animate then
		if isOn then
			TweenService:Create(holderOff, TWEEN_INFO, { Size = UDim2.new(0, 0, sizeOff.Y.Scale, sizeOff.Y.Offset) }):Play()
			holderOn.Size    = UDim2.new(0, 0, sizeOn.Y.Scale, sizeOn.Y.Offset)
			holderOn.Visible = true
			TweenService:Create(holderOn, TWEEN_INFO, { Size = sizeOn }):Play()
		else
			TweenService:Create(holderOn, TWEEN_INFO, { Size = UDim2.new(0, 0, sizeOn.Y.Scale, sizeOn.Y.Offset) }):Play()
			holderOff.Size    = UDim2.new(0, 0, sizeOff.Y.Scale, sizeOff.Y.Offset)
			holderOff.Visible = true
			TweenService:Create(holderOff, TWEEN_INFO, { Size = sizeOff }):Play()
		end

		task.delay(TWEEN_INFO.Time, function()
			holderOff.Visible = not isOn
			holderOn.Visible  = isOn
			holderOff.Size    = sizeOff
			holderOn.Size     = sizeOn
		end)
		
	else
		holderOff.Visible = not isOn
		holderOn.Visible  = isOn
	end
end

local function apply_setting(key, isOn)
	if key == "Music" then
		SoundController.MuteMusic(not isOn)
	elseif key == "SFX" then
		SoundController.MuteSFX(not isOn)
	elseif key == "Shadows" then
		Lighting.GlobalShadows = isOn
	end
end

local function connect_button(holder, config)
	local holderOff = holder:WaitForChild("ToggleHolderOff")
	local holderOn  = holder:WaitForChild("ToggleHolderOn")
	
	local originalOffSize = holderOff.Size
	local originalOnSize = holderOn.Size
	
	local btnOff    = holderOff:WaitForChild("Button")
	local btnOn     = holderOn:WaitForChild("Button")
	
	
	local isDebouncing = false

	local function on_click()
		if isDebouncing then return end
		isDebouncing = true

		settingsState[config.key] = not settingsState[config.key]
		set_toggle_visual(holder, settingsState[config.key], true, originalOffSize, originalOnSize)
		apply_setting(config.key, settingsState[config.key])

		task.delay(TWEEN_INFO.Time, function()
			isDebouncing = false
		end)
	end

	btnOff.MouseButton1Click:Connect(on_click)
	btnOn.MouseButton1Click:Connect(on_click)
end

local function build_settings(ui)
	ui.Template.Visible = false
	for _, config in ipairs(SETTINGS_CONFIG) do
		local holder = ui.Template:Clone()
		holder.Name    = config.key .. "Holder"
		holder.Visible = true

		local settingName = holder:FindFirstChild("SettingName")
		local settingDesc = holder:FindFirstChild("SettingDesc")
		local toggleOff   = holder:FindFirstChild("ToggleHolderOff")
		local toggleOn    = holder:FindFirstChild("ToggleHolderOn")

		if not (settingName and settingDesc and toggleOff and toggleOn) then
			continue
		end

		settingName.Text = config.name
		settingDesc.Text = config.desc
		set_toggle_visual(holder, settingsState[config.key], false)
		connect_button(holder, config)
		holder.Parent = ui.ScrollingFrame
	end
end

-- INIT
task.spawn(function()
	local ui = get_ui()
	build_settings(ui)
end)

return SettingsController