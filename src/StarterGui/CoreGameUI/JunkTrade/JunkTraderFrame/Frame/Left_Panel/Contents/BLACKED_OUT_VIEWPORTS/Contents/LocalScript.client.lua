local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

local FrameForViewport = script.Parent
local SecretUnit1 = "Anekan Skaivoker"
local SecretUnit2 = "Palpotin"
local SecretUnit3 = 'Dart Wader'

local FoundVp = FrameForViewport.SecretUnit1:FindFirstChildOfClass("ViewportFrame")
if FoundVp then
    FoundVp:Destroy()
end
local FoundVp2 = FrameForViewport.SecretUnit2:FindFirstChildOfClass("ViewportFrame")
if FoundVp2 then
    FoundVp2:Destroy()
end

local vp = ViewPortModule.CreateViewPort(SecretUnit1)
vp.Parent = FrameForViewport.SecretUnit1
vp.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.3,1) * CFrame.Angles(0,math.rad(180),0) )
vp.ZIndex = 1
vp.Ambient = Color3.new(0,0,0)
vp.LightColor = Color3.new(0,0,0)

local vp2 = ViewPortModule.CreateViewPort(SecretUnit2)
vp2.Parent = FrameForViewport.SecretUnit2
vp2.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp2.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.3,1) * CFrame.Angles(0,math.rad(180),0) )
vp2.ZIndex = 1
vp2.Ambient = Color3.new(0,0,0)
vp2.LightColor = Color3.new(0,0,0)

local vp2 = ViewPortModule.CreateViewPort(SecretUnit3)
vp2.Parent = FrameForViewport.SecretUnit3
vp2.WorldModel:FindFirstChildOfClass("Model"):SetPrimaryPartCFrame(vp2.WorldModel:FindFirstChildOfClass("Model").PrimaryPart.CFrame * CFrame.new(0,.3,1) * CFrame.Angles(0,math.rad(180),0) )
vp2.ZIndex = 1
vp2.Ambient = Color3.new(0,0,0)
vp2.LightColor = Color3.new(0,0,0)