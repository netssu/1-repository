local animationController = script.Parent.AnimationController
local animObject = script.Parent.ShipAnimation
local animTrack = animationController:LoadAnimation(animObject)

-- Function to set transparency for parts "1" and "2"
local function setPartsTransparency(transparencyValue)
    for _, descendant in ipairs(script.Parent:GetDescendants()) do
        if descendant:IsA("BasePart") and (descendant.Name == "1" or descendant.Name == "2") then
            descendant.Transparency = transparencyValue
        end
    end
end

while true do
    -- Make parts "1" and "2" visible before starting the animation
    setPartsTransparency(0)
    animTrack:Play()

    -- Wait until the animation finishes
    repeat wait() until not animTrack.IsPlaying

    -- Make parts "1" and "2" transparent after the animation finishes
    setPartsTransparency(1)

    -- Wait 15 seconds before replaying the animation
    wait(15)
end
