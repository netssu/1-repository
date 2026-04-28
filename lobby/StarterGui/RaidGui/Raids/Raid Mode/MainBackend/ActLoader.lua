local module = {}

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Player = Players.LocalPlayer
local Left_Panel = script.Parent.Parent.Frame.Left_Panel
local RaidModeStats = require(ReplicatedStorage.RaidModeStats)
local ActsContainer = Left_Panel.Contents.Act.Bg
local WorldsContainer = Left_Panel.Contents.Location.Bg

local connections = {}

local prevWorld = nil
-- 127, 3, 0 = red
local function numbertotime(number)
	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) %60
	local Seconds = math.floor(number % 60)

	if Mintus < 10 and Hours > 0 then
		Mintus = "0"..Mintus
	end

	if Seconds < 10 then
		Seconds = "0"..Seconds
	end

	if Hours > 0 then
		return `{Hours}:{Mintus}:{Seconds}`
	else
		return `{Mintus}:{Seconds}`
	end
end

local function isActUnlocked(world, act)
	local RaidActData = Player:WaitForChild('RaidActData')
	local Map = RaidActData[world]
	
	local isUnlocked = false
	
	local unlocked = {}
	local nextWorld = nil
	local nextAct = nil
	local shouldBreak = false
	
    for _, RaidMap in RaidModeStats.Worlds do
        if RaidMap ~= world then continue end -- temp
        
		unlocked[RaidMap] = {}
		
        for actVal = 1, 5 do
            
			if RaidActData[RaidMap]['Act'..tostring(actVal)].Completed.Value then
				unlocked[RaidMap]['Act'..tostring(actVal)] = true
			else
				nextWorld = RaidMap
				nextAct = 'Act' .. tostring(actVal)
				
				shouldBreak = true
				break
			end
		end
		
		if shouldBreak then
			break
		end
	end
	
	if (unlocked[world] and unlocked[world][act]) or (nextWorld == world and nextAct == act) then
		isUnlocked = true
	end

	return isUnlocked	
end

function module.setActs(world)
	if prevWorld then
		prevWorld.Contents.Bg.UIStroke.Color = Color3.fromRGB(127, 3, 0)
		prevWorld = nil
	end
	
	local WorldButton = WorldsContainer[world]
	
	WorldButton.Contents.Bg.UIStroke.Color = Color3.fromRGB(255,255,255)
	prevWorld = WorldButton
	
	for i,v in pairs(connections) do
		v:Disconnect()
		v = nil
	end
	
	local Acts = RaidModeStats.LevelName[world]
	local WorldImage = RaidModeStats.Images[world]
	
	local count = 1
	for i,v in pairs(Acts) do
		local ActButton = ActsContainer['Act'..count]
		
		ActButton.Contents.Text_Container.Act.Text = 'Act ' .. count
		ActButton.Contents.Bg.Location_Image.Image = WorldImage
		ActButton.Contents.Text_Container.Title.Text = v
		
		local isUnlocked = isActUnlocked(world, 'Act' .. tostring(count))
		ActButton.Contents.Locked.Visible = not isUnlocked
		
		--if isUnlocked and count == 1 then
		--	module.selectAct('Act1')
		--end
		
		count += 1
	end
	
	module.selectAct('Act1')
end

local prevAct = nil

local function findPlayer()
	for i, v in workspace.NewLobby.RaidElevators:GetChildren() do
		if v.Players:FindFirstChild(game.Players.LocalPlayer.Name) then
			return v
		end
	end
end

function module.selectAct(act)
	if prevAct then
		prevAct.Contents.Bg.UIStroke.Color = Color3.fromRGB(127, 3, 0)
		prevAct = nil
	end
	
	if act then
		local ActButton = ActsContainer[act]
		
		ActButton.Contents.Bg.UIStroke.Color = Color3.fromRGB(255,255,255)
		prevAct = ActButton
		
		local elevator = findPlayer()
        
        script.Parent.Parent.Frame.Right_Panel.Contents.Rewards_Frame.Bar.SecretUnit.Item_Contents.Unit_Value.Text = tostring(tonumber(string.sub(act, -1))/2) .. '%' -- temp
        
		if elevator then
			elevator.RaidElevatorServer.Choose:FireServer()
			--print('FIRING SERVER')
            --print(tonumber(string.sub(act, -1)))
			elevator.RaidElevatorServer.SelectAct:FireServer(tonumber(string.sub(act, -1)))
		end
	end
end

local conn = {}
function module.attachConnections()
	for i,v in pairs(conn) do
		v:Disconnect()
		v = nil
	end
	conn = {}
	
	for i,v in pairs(ActsContainer:GetChildren()) do
		if v:IsA('ImageButton') then
			local newConn = v.Activated:Connect(function()
				if not v.Contents.Locked.Visible then
					module.selectAct(v.Name)
				end
			end)
			
			table.insert(conn, newConn)
		end
	end
end


return module