local StarterGui = game:GetService('StarterGui')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

for i,v in pairs(StarterGui:GetChildren()) do
    v.Parent = ReplicatedStorage.CoreUI
end

