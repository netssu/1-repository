local tweenService = game:GetService('TweenService')

local function tween(obj, length, details)
	if obj and length and details then
		tweenService:Create(obj,TweenInfo.new(length),details):Play()
	end
end
 
local plane = script.Parent
local team = plane:GetAttribute('Team')

local HRP = plane.HumanoidRootPart
local extraStepDistance = 1

local function round(n)
	return math.floor(n + 0.5)
end


local part = HRP

local waypoints, cpoints, Mobs, End, endPos
local MapFolder = workspace.Map:GetChildren()[1] :: Folder or workspace

if team then
	Mobs = workspace[team .. 'Mobs']
	waypoints = workspace[team .. 'Waypoints']
	End = workspace[team .. 'End']
	endPos = workspace[team .. 'Start'].Position
else
	waypoints = MapFolder['Waypoints']
	End = MapFolder['End']
	endPos = MapFolder['Start'].Position 
	Mobs = workspace['Mobs']
end

function MoveNPC(Point, Character)	
	repeat
		task.wait()
		Character.Humanoid:MoveTo(Point)
	until (HRP.Position - Vector3.new(Point.X, HRP.Position.Y, Point.Z) ).magnitude <= 1 -- Adjust this for planes
end

local count = #waypoints:GetChildren()


task.wait(0.5)

for waypoint = 1, count do
	-- AlignOrientation
	local target = (count - waypoint) + 1
	local targetPos = waypoints[target].Position	
	local direction = (targetPos - HRP.Position).unit
	local newDestination = targetPos + direction * extraStepDistance
	newDestination = Vector3.new(newDestination.X, HRP.Position.Y, newDestination.Z)
	
	plane.AlignOrientation.CFrame = CFrame.lookAt(HRP.Position, newDestination)
	plane.AlignOrientation.Enabled = true
	
	MoveNPC(newDestination, plane)
end


local targetPos = endPos

plane.AlignOrientation.CFrame = CFrame.lookAt(HRP.Position, targetPos)
plane.AlignOrientation.Enabled = true

MoveNPC(targetPos, plane)
script.Parent:Destroy()

