------------------//SERVICES
local TweenService: TweenService = game:GetService("TweenService")
local Players: Players = game:GetService("Players")

------------------//CONSTANTS
local NOTIFICATION_CONFIG = {
	MaxVisible = 4,
	AnimateIn = 0.3,
	AnimateOut = 0.3,
	DefaultDuration = 4,

	Sounds = {
		success = "rbxassetid://6026984224",
		error = "rbxassetid://6026984224",
		warning = "rbxassetid://6026984224",
		info = "rbxassetid://6026984224",
		neutral = "rbxassetid://6026984224",
		action = "rbxassetid://6026984224" 
	}
}

local NOTIFICATION_TYPES = {
	success = { title = "SUCCESS" },
	error = { title = "ERROR" },
	warning = { title = "WARNING" },
	info = { title = "INFO" },
	neutral = { title = "NOTICE" },
	action = { title = "ACTION" }
}

------------------//VARIABLES
local NotificationController = {}
NotificationController.__index = NotificationController

local activeNotifications: {[string]: any} = {}
local notificationQueue: {any} = {}

local containerHolder: Frame? = nil
local originalTemplate: GuiObject? = nil

------------------//FUNCTIONS
local function get_ui_references(): boolean
	if containerHolder and originalTemplate then return true end

	local player = Players.LocalPlayer
	if not player then return false end

	local playerGui = player:WaitForChild("PlayerGui", 5)
	if not playerGui then return false end

	local mainGui = playerGui:WaitForChild("GUI", 5)
	if not mainGui then return false end

	containerHolder = mainGui:FindFirstChild("NotificationHolder")
	if not containerHolder then return false end

	local notifFrame = containerHolder:FindFirstChild("NotificationFrame")
	if not notifFrame then return false end

	originalTemplate = notifFrame
	originalTemplate.Visible = false 

	return true
end

local function play_sound(soundType: string): ()
	local soundId = NOTIFICATION_CONFIG.Sounds[soundType] or NOTIFICATION_CONFIG.Sounds.info
	if not soundId then return end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.5
	sound.Parent = game:GetService("SoundService")
	sound:Play()

	task.delay(2, function()
		if sound then sound:Destroy() end
	end)
end

local function is_duplicate_notification(message: string): boolean
	for _, notif in activeNotifications do
		if notif.data.message == message then
			return true
		end
	end

	for _, notifData in notificationQueue do
		if notifData.message == message then
			return true
		end
	end

	return false
end

local function create_notification_ui(notifData: any): (GuiObject, GuiButton?)
	local typeStyle = NOTIFICATION_TYPES[notifData.type] or NOTIFICATION_TYPES.info

	if notifData.callback and notifData.type == "action" then
		typeStyle = NOTIFICATION_TYPES.action
	end

	local notifFrame = originalTemplate:Clone()
	notifFrame.Name = "Notification_" .. tostring(tick())
	notifFrame.LayoutOrder = notifData.priority or 0

	local startTransparency = 1
	if notifFrame:IsA("CanvasGroup") then
		notifFrame.GroupTransparency = startTransparency
	else
		notifFrame.BackgroundTransparency = startTransparency
	end

	local header = notifFrame:FindFirstChild("Header")
	if header then
		local headText = header:FindFirstChild("HeadText")
		if headText then
			headText.Text = notifData.title or typeStyle.title
		end
	end

	local desc = notifFrame:FindFirstChild("Desc")
	if desc then
		desc.Text = notifData.message
	end

	local buyButton = notifFrame:FindFirstChild("BuyButton")
	if buyButton then
		if notifData.callback then
			buyButton.Visible = true

			local textHolder = buyButton:FindFirstChild("TextHolder")
			if textHolder then
				local mainText = textHolder:FindFirstChild("MainText")
				local shadowText = textHolder:FindFirstChild("TextShadow")

				local btnText = notifData.buttonText or "ACT"
				if mainText then mainText.Text = btnText end
				if shadowText then shadowText.Text = btnText end
			end
		else
			buyButton.Visible = false
		end
	end

	return notifFrame, buyButton
end

local function animate_in(notifFrame: GuiObject, onComplete: () -> ()): ()
	local originalSize = notifFrame.Size

	-- Começa pequeno (Amassado no Y)
	notifFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 0)
	notifFrame.Visible = true

	local tweenInfo = TweenInfo.new(
		NOTIFICATION_CONFIG.AnimateIn,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)

	local tweenArgs = { Size = originalSize }

	if notifFrame:IsA("CanvasGroup") then
		tweenArgs.GroupTransparency = 0
	else
		tweenArgs.BackgroundTransparency = 0 
	end

	local enterTween = TweenService:Create(notifFrame, tweenInfo, tweenArgs)
	enterTween:Play()

	enterTween.Completed:Connect(function()
		if onComplete then onComplete() end
	end)
end

local function animate_out(notifFrame: GuiObject, onComplete: () -> ()): ()
	local tweenInfo = TweenInfo.new(
		NOTIFICATION_CONFIG.AnimateOut,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)

	-- Encolhe para 0 no Y
	local tweenArgs = { Size = UDim2.new(notifFrame.Size.X.Scale, notifFrame.Size.X.Offset, 0, 0) }

	if notifFrame:IsA("CanvasGroup") then
		tweenArgs.GroupTransparency = 1
	else
		tweenArgs.BackgroundTransparency = 1
	end

	local exitTween = TweenService:Create(notifFrame, tweenInfo, tweenArgs)
	exitTween:Play()

	exitTween.Completed:Connect(function()
		if onComplete then onComplete() end
	end)
end

local function remove_notification(notifId: string): ()
	local notif = activeNotifications[notifId]
	if not notif then return end

	animate_out(notif.frame, function()
		if notif.frame then notif.frame:Destroy() end
		activeNotifications[notifId] = nil

		if #notificationQueue > 0 then
			local nextNotif = table.remove(notificationQueue, 1)
			NotificationController:ShowInternal(nextNotif)
		end
	end)
end

------------------//MAIN FUNCTIONS
function NotificationController:ShowInternal(notifData: any): ()
	if is_duplicate_notification(notifData.message) then
		return
	end

	local visibleCount = 0
	for _ in activeNotifications do
		visibleCount += 1
	end

	if visibleCount >= NOTIFICATION_CONFIG.MaxVisible then
		table.insert(notificationQueue, notifData)
		return
	end

	if not get_ui_references() then return end

	local notifFrame, buyButton = create_notification_ui(notifData)
	notifFrame.Parent = containerHolder

	local notifId = "notif_" .. tostring(tick())
	activeNotifications[notifId] = {
		frame = notifFrame,
		data = notifData
	}

	if notifData.sound then
		play_sound(notifData.type)
	end

	animate_in(notifFrame, function()
		if not notifData.callback then
			task.delay(notifData.duration, function()
				remove_notification(notifId)
			end)
		end
	end)

	if notifData.callback and buyButton then
		buyButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				task.spawn(notifData.callback)
				remove_notification(notifId)
			end
		end)
	end
end

function NotificationController:Show(messageOrConfig: any, notifType: string?, duration: number?): ()
	local notifData = {}

	if type(messageOrConfig) == "table" then
		notifData = messageOrConfig
		notifData.message = notifData.message or "..."
		notifData.type = notifData.type or "info"
		notifData.duration = notifData.duration or NOTIFICATION_CONFIG.DefaultDuration
		notifData.sound = notifData.sound ~= false
		notifData.priority = notifData.priority or 0
		notifData.callback = notifData.callback
		notifData.buttonText = notifData.buttonText
		notifData.title = notifData.title
	else
		notifData.message = tostring(messageOrConfig)
		notifData.type = notifType or "info"
		notifData.duration = duration or NOTIFICATION_CONFIG.DefaultDuration
		notifData.sound = true
		notifData.priority = 0
	end

	if not NOTIFICATION_TYPES[notifData.type] then
		notifData.type = "info"
	end

	self:ShowInternal(notifData)
end

function NotificationController:Success(message: string, duration: number?): ()
	self:Show(message, "success", duration)
end

function NotificationController:Error(message: string, duration: number?): ()
	self:Show(message, "error", duration)
end

function NotificationController:Warning(message: string, duration: number?): ()
	self:Show(message, "warning", duration)
end

function NotificationController:Info(message: string, duration: number?): ()
	self:Show(message, "info", duration)
end

function NotificationController:Neutral(message: string, duration: number?): ()
	self:Show(message, "neutral", duration)
end

function NotificationController:Action(message: string, buttonText: string, callback: () -> (), duration: number?): ()
	self:Show({
		message = message,
		type = "action",
		buttonText = buttonText,
		callback = callback,
		duration = duration
	})
end

function NotificationController:ClearAll(): ()
	for notifId in activeNotifications do
		remove_notification(notifId)
	end
	table.clear(notificationQueue)
end

------------------//INIT
task.spawn(function()
	get_ui_references()
end)

return NotificationController
