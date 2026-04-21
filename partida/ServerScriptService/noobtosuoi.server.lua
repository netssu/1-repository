if true then return end
local RunService = game:GetService("RunService")
local info = workspace.Info
if RunService:IsStudio() then
	info.Versus.Value = true
	info.World.Value = 1
end