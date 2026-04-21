local Players = game:GetService('Players')
local PlayerGui = Players.LocalPlayer:WaitForChild('PlayerGui')
local BillboardGui = PlayerGui:WaitForChild('Billboards')

while task.wait(0.1) do
    for i,v in pairs(BillboardGui:GetChildren()) do
        if v.Adornee == nil then
            warn('BEGONE')
            v:Destroy()
        end
    end
end