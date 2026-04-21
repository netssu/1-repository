local Animation = script.Animation
local AnimationTrack = script.Parent.Humanoid:LoadAnimation(Animation)
AnimationTrack.Looped = true
AnimationTrack:Play()