------------------//SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

------------------//PACKAGES
local Trove = require(ReplicatedStorage.Packages.Trove)
local Packet = require(ReplicatedStorage.Modules.Game.Packets)

------------------//MODULES
local GuiController = require(ReplicatedStorage.Controllers.GuiController)
local NotificationController = require(ReplicatedStorage.Controllers.NotificationController)

------------------//CONSTANTS
local BUTTON_COOLDOWN = 1
local REWARD_NAMES = {
    SpinStyle = "Spin Styles",
    SpinFlow = "Spin Flows",
    Yen = "Yen"
}

------------------//VARIABLES
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local CodesGui = {
    _trove = nil,
    _isOpen = false,
    _isDebounce = false
}

------------------//FUNCTIONS

local function playButtonEffect(button)
    local originalSize = button.Size
    local tweenDown = TweenService:Create(button, TweenInfo.new(0.1), {Size = UDim2.fromScale(originalSize.X.Scale * 0.9, originalSize.Y.Scale * 0.9)})
    tweenDown:Play()
    tweenDown.Completed:Wait()
    TweenService:Create(button, TweenInfo.new(0.1), {Size = originalSize}):Play()
end

local function redeemCode(textBox, feedbackLabel)
    if CodesGui._isDebounce then return end
    
    local text = textBox.Text
    if text == "" or string.len(text) < 2 then return end
    
    CodesGui._isDebounce = true
    
    if feedbackLabel then 
        feedbackLabel.Text = "Checking..." 
        feedbackLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    
    local success, result = pcall(function()
        return Packet.RequestRedeemCode:Fire(text)
    end)
    
    if success and result then
        if result == "Success" then
            if feedbackLabel then 
                feedbackLabel.Text = "Success!" 
                feedbackLabel.TextColor3 = Color3.fromRGB(85, 255, 127)
            end
            NotificationController.NotifySuccess("Code Redeemed!", "Check your inventory for rewards!")
            textBox.Text = ""
            
        elseif result == "Already Redeemed" then
            if feedbackLabel then 
                feedbackLabel.Text = "Already Used!" 
                feedbackLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
            end
            NotificationController.NotifyWarning("Already Redeemed", "You've already used this code.")
            
        elseif result == "Invalid Code" then
            if feedbackLabel then 
                feedbackLabel.Text = "Invalid Code!" 
                feedbackLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
            end
            NotificationController.NotifyError("Invalid Code", "This code doesn't exist.")
            
        else
            if feedbackLabel then 
                feedbackLabel.Text = "Error!" 
                feedbackLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
            end
            NotificationController.NotifyError("Error", "Something went wrong. Try again.")
        end
    else
        if feedbackLabel then 
            feedbackLabel.Text = "Timeout!" 
            feedbackLabel.TextColor3 = Color3.fromRGB(255, 85, 85)
        end
        NotificationController.NotifyError("Connection Error", "Failed to connect to server.")
    end
    
    task.wait(BUTTON_COOLDOWN)
    
    if feedbackLabel then 
        feedbackLabel.Text = "REDEEM" 
        feedbackLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
    
    CodesGui._isDebounce = false
end

------------------//MAIN LOGIC

function CodesGui.OnOpen(gui: ScreenGui)
    CodesGui._trove = Trove.new()
    local trove = CodesGui._trove
    CodesGui._isOpen = true

    local main = gui:WaitForChild("Main")
    local frame = main:WaitForChild("Frame")
    local content = frame:WaitForChild("Content")
    
    local inputFrame = content:WaitForChild("Frame") 
    local imageLabel = inputFrame:WaitForChild("ImageLabel")
    local textBox = imageLabel:WaitForChild("TextBox")
    
    local redeemFrame = content:WaitForChild("Redeem") 
    local container = redeemFrame:WaitForChild("Container")
    local innerButton = container:WaitForChild("Button")
    local buttonLabel = innerButton:FindFirstChild("TextLabel")

    textBox.Text = ""
    textBox.PlaceholderText = "Enter code here..."
    
    trove:Connect(redeemFrame.Activated, function()
        playButtonEffect(redeemFrame)
        redeemCode(textBox, buttonLabel)
    end)
    
    trove:Connect(textBox.FocusLost, function(enterPressed)
        if enterPressed then
            redeemCode(textBox, buttonLabel)
        end
    end)
end

function CodesGui.OnClose()
    CodesGui._isOpen = false
    
    if CodesGui._trove then
        CodesGui._trove:Destroy()
        CodesGui._trove = nil
    end
end

------------------//INIT

function CodesGui.Start()
    GuiController.GuiOpened:Connect(function(guiName)
        if guiName == "CodesGui" then 
            local gui = playerGui:FindFirstChild("CodesGui")
            if gui then
                CodesGui.OnOpen(gui)
            end
        end
    end)

    GuiController.GuiClosed:Connect(function(guiName)
        if guiName == "CodesGui" then
            CodesGui.OnClose()
        end
    end)
end

return CodesGui