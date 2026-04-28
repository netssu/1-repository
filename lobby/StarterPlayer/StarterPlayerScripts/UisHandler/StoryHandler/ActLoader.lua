-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CONSTANTS
local Player = Players.LocalPlayer
local StoryModeStats = require(ReplicatedStorage:WaitForChild("StoryModeStats"))
local ViewPortModule = require(ReplicatedStorage.Modules:WaitForChild("ViewPortModule"))

-- VARIABLES
local module = {}
local connections = {}
local prevWorld = nil
local prevAct = nil
local conn = {}

local PlayerGui = Player:WaitForChild("PlayerGui")
local NewUI = PlayerGui:WaitForChild("NewUI")
local StoryModeUI = NewUI:WaitForChild("StoryFrame")
local Main = StoryModeUI:WaitForChild("Body"):WaitForChild("Main")
local LeftSection = StoryModeUI:WaitForChild("LeftSection")

local Left_Panel = Main:WaitForChild("Left_Panel")
local Detail = Main:WaitForChild("Detail")

local ActsContainer = Left_Panel.Contents.Act.Bg
local WorldsContainer = Left_Panel.Contents.Location.Bg

local CurrentWorldValue = Instance.new("StringValue")
CurrentWorldValue.Name = "CurrentWorld"
CurrentWorldValue.Parent = script

-- FUNCTIONS
local function numbertotime(number)
	if number == nil or number < 0 then
		return "00:00:00"
	end

	local Hours = math.floor(number / 60 / 60)
	local Mintus = math.floor(number / 60) % 60
	local Seconds = math.floor(number % 60)

	return string.format("%02d:%02d:%02d", Hours, Mintus, Seconds)
end

local function isActUnlocked(world, act)
	local WorldStats = Player:WaitForChild("WorldStats")
	local Map = WorldStats[world].LevelStats

	local isUnlocked = false
	local unlocked = {}
	local nextWorld = nil
	local nextAct = nil
	local shouldBreak = false

	for _, RaidMap in pairs(StoryModeStats.Worlds) do
		unlocked[RaidMap] = {}

		for actVal = 1, 5 do
			if WorldStats[RaidMap].LevelStats["Act"..tostring(actVal)].Clears.Value ~= 0 then
				unlocked[RaidMap]["Act"..tostring(actVal)] = true
			else
				nextWorld = RaidMap
				nextAct = "Act" .. tostring(actVal)
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

local function findPlayer()
	for i, v in pairs(workspace:WaitForChild("StoryElevators"):GetChildren()) do
		if v:IsA("Model") then
			if v.Players:FindFirstChild(Player.Name) then
				return v
			end
		end
	end
	return nil
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

local function updateDifficultyVisuals(selectedDifficulty)
	local diffColors = {
		["Normal"] = Color3.fromRGB(81, 232, 81),    -- Verde
		["Hard"] = Color3.fromRGB(255, 170, 0),      -- Laranja
		["Hell Fire"] = Color3.fromRGB(255, 0, 0),   -- Vermelho
		["Infinite"] = Color3.fromRGB(170, 0, 255)   -- Roxo (Mude se quiser)
	}

	for _, diffName in ipairs({"Normal", "Hard", "Hell Fire", "Infinite"}) do
		local diffButton = Detail.Dificulty:FindFirstChild(diffName)
		if diffButton and diffButton:FindFirstChild("Bg") and diffButton.Bg:FindFirstChild("2") then
			local bg2 = diffButton.Bg["2"]
			if diffName == selectedDifficulty then
				if bg2:IsA("UIStroke") then
					bg2.Color = Color3.fromRGB(255, 255, 255)
				elseif bg2:IsA("GuiObject") then
					bg2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				end
			else
				if bg2:IsA("UIStroke") then
					bg2.Color = Color3.fromRGB(166, 40, 175)
				elseif bg2:IsA("GuiObject") then
					bg2.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
				end
			end
		end
	end

	Detail.Text.Difficulty.Text = selectedDifficulty
	LeftSection.Queu.Text.Difficulty.Text = selectedDifficulty

	local selectedColor = diffColors[selectedDifficulty] or Color3.fromRGB(255, 255, 255)
	Detail.Text.Difficulty.TextColor3 = selectedColor
	LeftSection.Queu.Text.Difficulty.TextColor3 = selectedColor
end

function module.setActs(world)
	if world then
		CurrentWorldValue.Value = world
	else
		CurrentWorldValue.Value = ""
	end

	if prevWorld then
		if prevWorld.Contents.Bg:FindFirstChild("UIStroke") then
			prevWorld.Contents.Bg.UIStroke.Color = Color3.fromRGB(166, 40, 175)
		end
		prevWorld = nil
	end

	local WorldButton = WorldsContainer:FindFirstChild(world)
	if not WorldButton then return end

	if WorldButton.Contents.Bg:FindFirstChild("UIStroke") then
		WorldButton.Contents.Bg.UIStroke.Color = Color3.fromRGB(255, 255, 255)
	end

	Detail.Text.Stage.Text = world
	LeftSection.Queu.Text.Map.Text = world

	prevWorld = WorldButton

	for i,v in pairs(connections) do
		v:Disconnect()
		v = nil
	end
	connections = {}

	local Acts = StoryModeStats.LevelName[world]
	local WorldImage = prevWorld.Contents.Image.Location_Image.Image

	local count = 1
	for i,v in pairs(Acts) do
		local ActButton = ActsContainer:FindFirstChild("Act"..count)
		if ActButton then
			ActButton.LayoutOrder = count

			ActButton.Contents.Text_Container.Act.Text = "Act " .. count
			ActButton.Contents.Image.Location_Image.Image = WorldImage
			ActButton.Contents.Text_Container.Title.Text = v

			local isUnlocked = isActUnlocked(world, "Act" .. tostring(count))
			ActButton.Contents.Locked.Visible = not isUnlocked
		end
		count += 1
	end

	module.selectAct("Act1")
end

function module.selectAct(act)
	if prevAct then
		if prevAct.Contents.Bg:FindFirstChild("UIStroke") then
			prevAct.Contents.Bg.UIStroke.Color = Color3.fromRGB(166, 40, 175)
		end
		prevAct = nil
	end

	if act then
		local ActButton = ActsContainer:FindFirstChild(act)
		if not ActButton then return end

		if ActButton.Contents.Bg:FindFirstChild("UIStroke") then
			ActButton.Contents.Bg.UIStroke.Color = Color3.fromRGB(255, 255, 255)
		end

		local elevator = findPlayer()

		if elevator then
			elevator.ElevatorServer.ChangeStory:FireServer("Level", tonumber(string.sub(act, -1)))
			elevator.ElevatorServer.Choose:FireServer()

			task.spawn(function()
				local actLevels = StoryModeStats.LevelName[CurrentWorldValue.Value]
				local randomActLevel = actLevels and actLevels[math.random(1, #actLevels)] or "Default"
				local locatedBossViewport = ViewPortModule.CreateViewPort(randomActLevel, nil, true)
				local oldBossViewport = Detail.Placeholder:FindFirstChildOfClass("ViewportFrame")

				locatedBossViewport.ZIndex = 4
				locatedBossViewport.Size = UDim2.fromScale(1, 1)
				locatedBossViewport.Position = UDim2.fromScale(0.5, 0.5)
				locatedBossViewport.AnchorPoint = Vector2.new(0.5, 0.5)

				if oldBossViewport then
					if locatedBossViewport and locatedBossViewport.Name ~= oldBossViewport.Name then
						oldBossViewport:Destroy()
						local clone = locatedBossViewport:Clone()
						clone.Parent = Detail.Placeholder
					end
				else
					local clone = locatedBossViewport:Clone()
					clone.Parent = Detail.Placeholder
				end
			end)

			local formattedActText = "Act " .. string.sub(tostring(act), -1) .. " - " .. ActButton.Contents.Text_Container.Title.Text
			Detail.Text.Act.Text = formattedActText
			LeftSection.Queu.Text.Act.Text = formattedActText

			local TotalClear = Player.WorldStats[CurrentWorldValue.Value].LevelStats[act].Clears.Value
			local FastestTime = numbertotime(Player.WorldStats[CurrentWorldValue.Value].LevelStats[act].FastestTime.Value)
			local InfiniteClears = Player.WorldStats[CurrentWorldValue.Value].InfiniteRecord.Value

			if tostring(InfiniteClears) == "-1" then InfiniteClears = 0 end

			Detail.Results.Infinite_Clears.Text = string.format("Infinite record: <font color=\"#51E851\">%s</font>", tostring(InfiniteClears))
			Detail.Results.TextLabel.Text = string.format("Clear Time: <font color=\"#51E851\">%s</font>", FastestTime)
			Detail.Results.Total_Clears.Text = string.format("Total Clears: <font color=\"#51E851\">%s</font>", tostring(TotalClear))

			updateDifficultyVisuals("Normal")

			Detail.Dificulty.Infinite.Visible = finishedWorld(CurrentWorldValue.Value)

			elevator.ElevatorServer.ChangeStory:FireServer("Mode", 1)
			elevator.ElevatorServer.ChangeStory:FireServer("World", table.find(StoryModeStats.Worlds, CurrentWorldValue.Value))
			elevator.ElevatorServer.ChangeStory:FireServer("Level", tonumber(string.sub(act, -1)))
		end

		prevAct = ActButton
	end
end

function module.attachConnections()
	for i,v in pairs(conn) do
		v:Disconnect()
		v = nil
	end
	conn = {}

	for i,v in pairs(ActsContainer:GetChildren()) do
		if v:IsA("ImageButton") or v:IsA("GuiButton") then
			local newConn = v.Activated:Connect(function()
				if not v.Contents.Locked.Visible then
					module.selectAct(v.Name)
				end
			end)
			table.insert(conn, newConn)
		end
	end

	for _, button in pairs(Detail.Dificulty:GetChildren()) do
		if button:IsA("ImageButton") or button:IsA("GuiButton") then
			conn[button] = button.Activated:Connect(function()
				local elevator = findPlayer()
				if not elevator then return end

				if button.Name == "Normal" then
					updateDifficultyVisuals("Normal")
					elevator.ElevatorServer.ChangeStory:FireServer("Mode", 1)
				elseif button.Name == "Hard" then
					updateDifficultyVisuals("Hard")
					elevator.ElevatorServer.ChangeStory:FireServer("Mode", 2)
				elseif button.Name == "Hell Fire" then
					updateDifficultyVisuals("Hell Fire")
					elevator.ElevatorServer.ChangeStory:FireServer("Mode", 3)
				elseif button.Name == "Infinite" then
					updateDifficultyVisuals("Infinite")
					elevator.ElevatorServer.ChangeStory:FireServer("Mode", 4)
					elevator.ElevatorServer.ChangeStory:FireServer("Level", 0)
				end
			end)
		end
	end
end

-- INIT
return module