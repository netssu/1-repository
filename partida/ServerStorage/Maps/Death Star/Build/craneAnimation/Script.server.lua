local animationController = script.Parent.AnimationController
local animObject = script.Parent.craneAnimation

local animTrack = animationController:LoadAnimation(animObject)
animTrack.Looped = true

animTrack:Play()