script.Parent.Position = script.Parent.Parent:WaitForChild("Start"..script.Parent.PathNumber.Value).Position

local Waypoints = script.Parent.Parent["Waypoints"..script.Parent.PathNumber.Value]

local Debris = game:GetService("Debris")

local points = #Waypoints:GetChildren()

local par = script.Parent

Debris:AddItem(par,15)

for i=1, points do
	script.Parent.CFrame = CFrame.new(script.Parent.Position, Waypoints[i].Position)
	script.Parent.Orientation = Vector3.new(script.Parent.Orientation.X - 180, script.Parent.Orientation.Y - 270, script.Parent.Orientation.Z)
	local wai = (par.Position - Waypoints[i].Position).magnitude * 0.015
	game.TweenService:Create(par,TweenInfo.new(wai,Enum.EasingStyle.Linear),{Position = Waypoints[i].Position}):Play()
	task.wait(wai)
end

script.Parent.CFrame = CFrame.new(script.Parent.Position, script.Parent.Parent.End.Position)
script.Parent.Orientation = Vector3.new(script.Parent.Orientation.X - 180, script.Parent.Orientation.Y - 270, script.Parent.Orientation.Z)
local wai = (par.Position - script.Parent.Parent.End.Position).magnitude * 0.015
game.TweenService:Create(par,TweenInfo.new(wai,Enum.EasingStyle.Linear),{Position = script.Parent.Parent.End.Position}):Play()
task.wait(wai)
script.Parent:Destroy()