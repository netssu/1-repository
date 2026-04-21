local module = {}

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Player = Players.LocalPlayer
local Left_Panel = script.Parent.Parent.StoryFrame.Frame.Left_Panel
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local ActsContainer = Left_Panel.Contents.Act.Bg
local WorldsContainer = Left_Panel.Contents.Location.Bg
local ViewPortModule = require(ReplicatedStorage.Modules.ViewPortModule)

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
    local WorldStats = Player:WaitForChild('WorldStats')
	local Map = WorldStats[world].LevelStats
	
	local isUnlocked = false
	
	local unlocked = {}
	local nextWorld = nil
	local nextAct = nil
	local shouldBreak = false
	
	for _, RaidMap in StoryModeStats.Worlds do
		unlocked[RaidMap] = {}
		
		for actVal = 1, 5 do
            if WorldStats[RaidMap].LevelStats['Act'..tostring(actVal)].Clears.Value ~= 0 then
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

local v = script.Parent.Parent.StoryFrame.Frame.Right_Panel

function module.setActs(world)
    if world then
        script.CurrentWorld.Value = world
    else
        script.CurrentWorld.Value = ''
    end
    
	if prevWorld then
        prevWorld.Contents.Bg.UIStroke.Color = Color3.fromRGB(166, 40, 175)
		prevWorld = nil
	end
	
	local WorldButton = WorldsContainer[world]
	
    WorldButton.Contents.Bg.UIStroke.Color = Color3.fromRGB(255,255,255)
	v.Contents.Title.Contents.Stage.Text = world
    
    
	prevWorld = WorldButton
	
	for i,v in pairs(connections) do
		v:Disconnect()
		v = nil
	end
	
	local Acts = StoryModeStats.LevelName[world]
    --local WorldImage = StoryModeStats.Images[world]
    local WorldImage = prevWorld.Contents.Image.Location_Image.Image
    
    v.Map_Bg.Image = WorldImage
    
    
	local count = 1
	for i,v in pairs(Acts) do
		local ActButton = ActsContainer['Act'..count]
		
        ActButton.Contents.Text_Container.Act.Text = 'Act ' .. count
    
        ActButton.Contents.Image.Location_Image.Image = WorldImage
        
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
	for i, v in workspace:WaitForChild('StoryElevators'):GetChildren() do
		if v:IsA('Model') then
			if v.Players:FindFirstChild(game.Players.LocalPlayer.Name) then
				return v
			end
		end
	end
end

local function finishedWorld(world)
    local state = true
    
    for i,v in pairs(Player.WorldStats[world].LevelStats:GetChildren()) do
        state = v.Clears.Value ~= 0
        
        if not state then
            break
        end
    end
    
    return state
end

function module.selectAct(act)
	if prevAct then
        prevAct.Contents.Bg.UIStroke.Color = Color3.fromRGB(166, 40, 175)
		prevAct = nil
	end
	
	if act then
		local ActButton = ActsContainer[act]
		
		ActButton.Contents.Bg.UIStroke.Color = Color3.fromRGB(255,255,255)
		local elevator = findPlayer()
        
        if elevator then
            elevator.ElevatorServer.ChangeStory:FireServer('Level', tonumber(string.sub(act, -1)))
            elevator.ElevatorServer.Choose:FireServer()

			-- load act data
			task.spawn(function()
	            local locatedBossViewport = ViewPortModule.CreateViewPort(StoryModeStats.LevelName[script.CurrentWorld.Value][math.random(1,5)],nil,true)
	            local oldBossViewport = v:FindFirstChildOfClass("ViewportFrame")
	            locatedBossViewport.ZIndex = 4
	            locatedBossViewport.Size = UDim2.fromScale(0.783, 1.088)
	            locatedBossViewport.Position = UDim2.fromScale(0.795, 0.456)
				locatedBossViewport.AnchorPoint = Vector2.new(.5,.5)
				
				if oldBossViewport then
					if locatedBossViewport and locatedBossViewport.Name ~= oldBossViewport.Name then
						oldBossViewport:Destroy()
						local clone = locatedBossViewport:Clone()
						clone.Parent = v
					end
				else
					local clone = locatedBossViewport:Clone()
					clone.Parent = v
				end
			end)
            --if lastActiveButton and lastActiveButton ~= v["Act Frame"].ScrollingFrame.Infinite then
            --    lastActiveButton.ImageColor3 = Color3.new(1, 1, 1)
            --end
            
            

            v.Contents.Title.Contents.Act.Text = "Act " .. string.sub(tostring(act), -1) .. ' - ' .. ActButton.Contents.Text_Container.Title.Text
            --v["Act Frame"].ScrollingFrame.Infinite.ImageColor3 = Color3.new(0.184314, 1, 0) -- not sure what this is for (x_x)
            
            --lastActiveButton = v["Act Frame"].ScrollingFrame.Infinite
            
            local TotalClear = Player.WorldStats[script.CurrentWorld.Value].LevelStats[act].Clears.Value
            local FastestTime = numbertotime(Player.WorldStats[script.CurrentWorld.Value].LevelStats[act].FastestTime.Value)
            local InfiniteClears = Player.WorldStats[script.CurrentWorld.Value].InfiniteRecord.Value
            
            if tostring(InfiniteClears) == '-1' then InfiniteClears = 0 end
            
            v.Contents.Times.Contents.Infinite_Clears.Text = `Infinite record: <font color="#51E851">{InfiniteClears}</font>`
            v.Contents.Times.Contents.TextLabel.Text = `Clear Time: <font color="#51E851">{FastestTime}</font>`
            v.Contents.Times.Contents.Total_Clears.Text = `Total Clears: <font color="#51E851">{TotalClear}</font>`

            --v.Frame["Fastest Time"].Number.Text = ""
            
            
            v.Contents.Title.Contents.Difficulty.Text = "Normal"
            v.Contents.Title.Contents.Difficulty.HardGradient.Enabled = false
            v.Contents.Title.Contents.Difficulty.NormalGradient.Enabled = true
            v.Contents.Difficulty_Options.Bg.Hard.Contents.Glow.Visible = false
            v.Contents.Difficulty_Options.Bg.Normal.Contents.Glow.Visible = true
            v.Contents.Difficulty_Options.Bg.Infinite.Contents.Glow.Visible = false
            
            v.Contents.Difficulty_Options.Bg.Infinite.Visible = finishedWorld(script.CurrentWorld.Value)
            
            findPlayer().ElevatorServer.ChangeStory:FireServer("Mode",1)
            findPlayer().ElevatorServer.ChangeStory:FireServer("World",table.find(StoryModeStats.Worlds,script.CurrentWorld.Value))
            findPlayer().ElevatorServer.ChangeStory:FireServer("Level", string.sub(act, -1))
        end
        
        
        prevAct = ActButton
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

    for _,button in v.Contents.Difficulty_Options.Bg:GetChildren() do
        if not button:IsA('ImageButton') then continue end
        
        conn[button] = button.Activated:Connect(function()    
            if button.Name == "Normal" then
                v.Contents.Title.Contents.Difficulty.Text = "Normal"
                v.Contents.Title.Contents.Difficulty.HardGradient.Enabled = false
                v.Contents.Title.Contents.Difficulty.NormalGradient.Enabled = true
                v.Contents.Difficulty_Options.Bg.Hard.Contents.Glow.Visible = false
                v.Contents.Difficulty_Options.Bg.Normal.Contents.Glow.Visible = true
                v.Contents.Difficulty_Options.Bg.Infinite.Contents.Glow.Visible = false



                --v.Frame["Mode Text"].Text = "Normal"
                --v.Frame["Mode Text"].HardGradient.Enabled = false
                --v.Frame["Difficulty Frame"].Hard.GlowEffect.Visible = false
                --v.Frame["Mode Text"].NormalGradient.Enabled = true
                --v.Frame["Difficulty Frame"].Normal.GlowEffect.Visible = true
                findPlayer().ElevatorServer.ChangeStory:FireServer("Mode",1)
            elseif button.Name == 'Hard' then
                v.Contents.Title.Contents.Difficulty.Text = "Hard"
                v.Contents.Title.Contents.Difficulty.HardGradient.Enabled = true
                v.Contents.Title.Contents.Difficulty.NormalGradient.Enabled = false
                v.Contents.Difficulty_Options.Bg.Hard.Contents.Glow.Visible = true
                v.Contents.Difficulty_Options.Bg.Normal.Contents.Glow.Visible = false
                v.Contents.Difficulty_Options.Bg.Infinite.Contents.Glow.Visible = false




                --v.Frame["Mode Text"].Text = "Hard"
                --v.Frame["Mode Text"].NormalGradient.Enabled = false
                --v.Frame["Difficulty Frame"].Normal.GlowEffect.Visible = false
                --v.Frame["Mode Text"].HardGradient.Enabled = true
                --v.Frame["Difficulty Frame"].Hard.GlowEffect.Visible = true
                findPlayer().ElevatorServer.ChangeStory:FireServer("Mode",2)
            else
                -- infinite
                v.Contents.Title.Contents.Difficulty.Text = "Infinite"
                v.Contents.Title.Contents.Difficulty.HardGradient.Enabled = false
                v.Contents.Title.Contents.Difficulty.NormalGradient.Enabled = true
                v.Contents.Difficulty_Options.Bg.Hard.Contents.Glow.Visible = false
                v.Contents.Difficulty_Options.Bg.Normal.Contents.Glow.Visible = false
                v.Contents.Difficulty_Options.Bg.Infinite.Contents.Glow.Visible = true
                
                
                
                findPlayer().ElevatorServer.ChangeStory:FireServer("Mode",3)
                findPlayer().ElevatorServer.ChangeStory:FireServer("Level",0)
            end
        end)
    end

end


return module