-- SERVICES
local tweenService = game:GetService('TweenService')

-- CONSTANTS
local MapFolder = workspace.Map:GetChildren()[1] :: Folder or workspace

-- VARIABLES
local plane = script.Parent
local team = plane:GetAttribute('Team')
local HRP = plane:WaitForChild("HumanoidRootPart")
local Humanoid = plane:WaitForChild("Humanoid")
local extraStepDistance = 1

local waypoints, cpoints, Mobs, End, endPos

local BaseWalkSpeed = Humanoid.WalkSpeed 

-- FUNCTIONS
local function round(n)
	return math.floor(n + 0.5)
end

local function UpdateSpeed()
	local currentGameSpeed = workspace.Info.GameSpeed.Value
	Humanoid.WalkSpeed = BaseWalkSpeed * currentGameSpeed
end

local function MoveNPC(Point, Character)	
	repeat
		task.wait()
		Character.Humanoid:MoveTo(Point)
	until (HRP.Position - Vector3.new(Point.X, HRP.Position.Y, Point.Z) ).magnitude <= 1 -- Adjust this for planes
end

-- INIT
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

UpdateSpeed()

workspace.Info.GameSpeed.Changed:Connect(UpdateSpeed)

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