local ExperienceNotificationService = game:GetService('ExperienceNotificationService')

local Players = game:GetService('Players')
local Player = Players.LocalPlayer

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local function canPromptOptIn()
    local success, canPrompt = pcall(function()
        return ExperienceNotificationService:CanPromptOptInAsync()
    end)
    return success and canPrompt
end

if Player.TutorialWin.Value and Player.TutorialCompleted.Value then
    -- prompt
    task.wait(30)
    local success, canPrompt = canPromptOptIn()

    if canPrompt then
        ExperienceNotificationService:PromptOptIn()
    end
end