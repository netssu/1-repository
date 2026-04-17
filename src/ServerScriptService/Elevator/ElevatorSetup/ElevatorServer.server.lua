
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local SafeTeleport = require(ServerScriptService.SafeTeleport)
local StoryModeStats = require(ReplicatedStorage.StoryModeStats)
local AllFunc = require(ReplicatedStorage.Modules.VFX_Helper)
local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)

local WasMessage = false

local Message = ReplicatedStorage.Events.Client:WaitForChild("Message")
local movingEvent = ReplicatedStorage.Events:WaitForChild("MovingElevator")
local elevatorEvent = ReplicatedStorage.Events:WaitForChild("Elevator")
local elevator = script.Parent
local config = elevator.Config
local playersWaiting = {}
local moving = false
local choose = false
local quickstart = false
local timeExited = tick()

local gui = script.Parent.Door.Surface.Frame.InformationFrame

local function update()
	if #playersWaiting > 0 then
		script.Parent.Owner.Value = playersWaiting[1].Name
	end
	local world = StoryModeStats.Worlds[script.Parent.World.Value]
	if world then
		if script.Parent.Level.Value == 0 then
			gui.ActName.Text = "Infinity Mode"
		else
			local ActName = StoryModeStats.LevelName[world][script.Parent.Level.Value]
			if ActName then
				gui.ActName.Text = `Act {script.Parent.Level.Value} - {ActName}`  --script.Parent.Level.Value..". "..levelname
			else
				gui.ActName.Text = ""
			end
		end
		gui["Story Name"].Text = world
		if script.Parent.Mode.Value == 1 then
			gui["Mode Text"].Text = "Normal"
			gui["Mode Text"].HardGradient.Enabled = false
			gui["Mode Text"].NormalGradient.Enabled = true
		else
			gui["Mode Text"].Text = "Hard"
			gui["Mode Text"].NormalGradient.Enabled = false
			gui["Mode Text"].HardGradient.Enabled = true
		end

	else
		gui["Story Name"].Text = ""
	end
	--if StoryModeStats.Images[world] then
	--	gui.Parent.ImageLabel.Image = StoryModeStats.Images[world]
	--end
	if #playersWaiting == 0 then
		gui.Status.State.Text = "Empty"
		gui.ActName.Text = ""
		gui["Story Name"].Text = ""
		gui["Mode Text"].Text = ""
		gui.Status.Bar.Size = UDim2.new(0,0,1,0)
		--gui.Parent.ImageLabel.Image = ""
	end
	gui.Status.Players.Text = #playersWaiting.."/"..config.MaxPlayers.Value
end

script.ChangeStory.OnServerEvent:Connect(function(player,valuetype,newvalue)
	if #playersWaiting > 0 then
		if playersWaiting[1] == player and script.Parent:FindFirstChild(valuetype) then
			script.Parent[valuetype].Value = if newvalue == "Infinity" then 0 else newvalue
			update()
		end
	end
end)

script.Choose.OnServerEvent:Connect(function(player)
	if #playersWaiting > 0 then
		if playersWaiting[1] == player then
			choose = true
			script.Parent.Locked.Value = false
			update()
		end
	end
end)

script.QuickStart.OnServerEvent:Connect(function(player)
	if #playersWaiting > 0 then
		if playersWaiting[1] == player then
			quickstart = true
			update()
		end
	end
end)

script.FriendsOnly.OnServerEvent:Connect(function(player,value)
	if #playersWaiting > 0 then
		if playersWaiting[1] == player then
			script.Parent.FriendsOnly.Value = value
		end
	end
end)

local function Setup()

	print("Setup")
	playersWaiting = {}
	moving = false
	choose = false
	script.Parent.Level.Value = 1
	script.Parent.World.Value = 1
	script.Parent.Owner.Value = ""
	script.Parent.TimerActive.Value = false
	script.Parent.FriendsOnly.Value = false
	script.Parent.Timer.Value = 0
	script.Parent.Locked.Value = false
	script.Parent.Players:ClearAllChildren()
	update()

end

local function TeleportPlayers()
	warn('Teleporting Players')
	local placeId = PlaceData.Game
	local server = TeleportService:ReserveServerAsync(placeId)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = server
	local ownerPlayer = game.Players:FindFirstChild(script.Parent.Owner.Value)
	local ownerId = ownerPlayer and ownerPlayer.UserId or nil
	for i,v in pairs(playersWaiting) do
		ReplicatedStorage.Remotes.UI.Blackout:FireClient(v)
	end

	options:SetTeleportData({World = script.Parent.World.Value,Level = script.Parent.Level.Value,Mode = script.Parent.Mode.Value, OwnerId = ownerId})
	SafeTeleport(placeId, playersWaiting, options)
	print("Finished teleport")
end

local function MoveElevator()
	gui.Status.State.Text = "Teleporting..."
	moving = true
	for i, player in playersWaiting do
		movingEvent:FireClient(player)
	end
	TeleportPlayers()
	task.wait(15)
	Setup()
end

local function RunCountdown()
	local currentOwner = script.Parent.Owner.Value

	script.Parent.TimerActive.Value = true
	for i=50, 1, -1 do
		script.Parent.Timer.Value = i
		task.wait(1)
		if #playersWaiting < 1 then
			script.Parent.TimerActive.Value = false
			if currentOwner == script.Parent.Owner.Value then
				Setup()
			end
			return
		end
		if quickstart then
			script.Parent.Timer.Value = 0
			script.Parent.TimerActive.Value = false
			gui.Status.Bar.Size = UDim2.new(0,0,1,0)
			break
		end
	end

	if choose then
		quickstart = false
		MoveElevator()
		script.Parent.TimerActive.Value = false
	else
		if currentOwner == script.Parent.Owner.Value then
			quickstart = false
			timeExited = tick()

			for i, v in script.Parent.Players:GetChildren() do
				local plr = Players:FindFirstChild(v.Name)
				if plr then
					ReplicatedStorage.Events.OwnerLeavesElevator:FireClient(plr)
					local character = plr.Character or plr.CharacterAdded:Wait()
					character:SetPrimaryPartCFrame(script.Parent.TeleportOut.CFrame)
				end
				v:Destroy()
			end
			Setup()
			script.Parent.TimerActive.Value = false
		end
	end
end

elevator.Door.Touched:Connect(function(part)
	local player = Players:GetPlayerFromCharacter(part.Parent)
    local isWaiting = table.find(playersWaiting, player)
        
    if player then
        if script.Parent.Players:FindFirstChild(player.Name) then
            return
        end

        print('---------------')
        print('xo1')
		local value = AllFunc.HaveEquipUnits(player)
		if not value then
			if not WasMessage  then
				WasMessage = true
				task.spawn(function()
					task.wait(1)
					WasMessage = false
				end)
				Message:FireClient(player,"Equip at Least 1 Unit ", Color3.new(1, 0, 0))
			end
			return
		end

        print('xo2')

		local playerData = player

		local requiredLevel = script.Parent.Level.Value
		if requiredLevel <= 0 then
			requiredLevel = #StoryModeStats.LevelName[StoryModeStats.Worlds[script.Parent.World.Value]]
		end

        local checks = {
            gotPlayer = player,
            notWaiting = not isWaiting,
            isElevatorFull = #playersWaiting < config.MaxPlayers.Value,
            notMoving = not moving,
            notLocked = not script.Parent.Locked.Value,
            appropriateTiem = tick()-1 > timeExited,
        }
        
        local allGood = true
        
        --for i,v in pairs(checks) do
        --    if v then
        --        continue
        --    else
        --        print('One check was not fulfilled:')
        --        warn(i)
        --        print('Got value:')
        --        warn(v)
        --    end
        --end


		if allGood and
			(playerData.StoryProgress.World.Value > script.Parent.World.Value or (playerData.StoryProgress.World.Value == script.Parent.World.Value and playerData.StoryProgress.Level.Value >= requiredLevel)) and
            (script.Parent.FriendsOnly.Value == false or (script.Parent.FriendsOnly.Value == true and player:IsFriendsWith(Players[script.Parent.Owner.Value].UserId))) then
            print('WE IN!')
            
			table.insert(playersWaiting, player)
			local plrval = Instance.new("StringValue")
			plrval.Name = player.Name
			plrval.Parent = script.Parent.Players

			player.Character.PrimaryPart.CFrame = elevator.TeleportIn.CFrame

			if #playersWaiting > 0 then
				script.Parent.Owner.Value = playersWaiting[1].Name
			end

			elevatorEvent:FireClient(player, elevator, "Story")

			script.Parent.Locked.Value = true
			gui.Status.State.Text = "Choosing..."

			task.spawn(function()
				RunCountdown()
			end)

			while not choose and #playersWaiting > 0 do
				task.wait()
			end
			--repeat task.wait(0.1) until choose or #playersWaiting == 0

			script.Parent.Locked.Value = false
			--if not script.Parent.TimerActive.Value and choose then
			--	task.spawn(function()
			--		RunCountdown()
			--	end)

			--end
		end
	end
	update()
end)

elevatorEvent.OnServerEvent:Connect(function(player)
	local isWaiting = table.find(playersWaiting, player)
	if isWaiting then
		table.remove(playersWaiting, isWaiting)
		for i, v in script.Parent.Players:GetChildren() do
			if v.Name == player.Name then
				v:Destroy()
			end
		end
		
		ReplicatedStorage.Remotes.Elevator.LeavingElevator:FireClient(player)

		if player.Name == script.Parent.Owner.Value then
			quickstart = false
			timeExited = tick()
			for i, v in script.Parent.Players:GetChildren() do
				local plr = Players:FindFirstChild(v.Name)
				if plr then
					ReplicatedStorage.Events.OwnerLeavesElevator:FireClient(plr)
					local character = plr.Character-- or plr.CharacterAdded:Wait()
					if not character then continue end
					character:SetPrimaryPartCFrame(script.Parent.TeleportOut.CFrame)
				end
				v:Destroy()
			end
			Setup()
		end

		update()
		if player.Character then
			player.Character.PrimaryPart.CFrame = script.Parent.TeleportOut.CFrame
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	--print(player.Name)
	if table.find(playersWaiting,player) then
		print("Player in elevator")
		if player.Name == script.Parent.Owner.Value then
			print("Player is owner")
			quickstart = false
			timeExited = tick()
			Setup()
			for i, v in script.Parent.Players:GetChildren() do
				local plr = Players:FindFirstChild(v.Name)
				if plr then
					ReplicatedStorage.Events.OwnerLeavesElevator:FireClient(plr)
					local character = plr.Character or plr.CharacterAdded:Wait()
					character:SetPrimaryPartCFrame(elevator.Door.CFrame * CFrame.new(0,-5,-10))
				end
				v:Destroy()
			end
		else
			table.remove(playersWaiting, table.find(playersWaiting, player))
		end
	end
end)

script.Parent.Level.Changed:Connect(update)
script.Parent.World.Changed:Connect(update)

while true do
	task.wait(1/3)
	if script.Parent.TimerActive.Value then
		gui.Status.State.Text = "Waiting for players..."
		gui.Status.Bar.Size = UDim2.new((script.Parent.Timer.Value/50),0,1,0)
	end
	if moving then 
		gui.Status.State.Text = "Teleporting..."
	end
end
