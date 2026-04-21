local door = script.Parent
local animationController = door:WaitForChild("AnimationController")
local doorOpenAnim = door:WaitForChild("doorAnimation2")
local animTrack = animationController:LoadAnimation(doorOpenAnim)

-- Optionally widen the trigger's detection area.
local trigger = door:WaitForChild("ProximityTrigger")

local doorOpened = false

-- Set this value to a time (in seconds) earlier than the full animation length.
-- For example, if the full animation is 2 seconds, you might choose 1.5.
local freezeTime = 1.5

local function onTouched(hit)
    local character = hit.Parent
    local player = game.Players:GetPlayerFromCharacter(character)
    
    print('opening')
    if player and not doorOpened then
        doorOpened = true
        animTrack:AdjustSpeed(1)  -- Play animation normally.
        animTrack:Play()

        -- Monitor the animation until it reaches the freezeTime.
        spawn(function()
            while animTrack.IsPlaying and animTrack.TimePosition < freezeTime do
                wait(0.05)
            end
            -- Once reached, freeze the animation so it stays at this frame.
            if animTrack.TimePosition >= freezeTime then
                animTrack:AdjustSpeed(0)  -- This holds the door at the freeze frame.
            end
        end)
    end
end

trigger.Touched:Connect(onTouched)
