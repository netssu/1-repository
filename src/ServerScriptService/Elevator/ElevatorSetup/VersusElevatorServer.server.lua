
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
local quickstart = false
local timeExited = tick()

local gui = script.Parent.Door.Surface.Frame.InformationFrame

local function update()
	--if #playersWaiting > 0 then -- versus no owner
		--script.Parent.Owner.Value = playersWaiting[1].Name
	--end
	
	gui["Story Name"].Text = ""

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

script.QuickStart.OnServerEvent:Connect(function(player)
	if #playersWaiting > 0 then
		if playersWaiting[1] == player then
			quickstart = true
			update()
		end
	end
end)

local function Setup()
	playersWaiting = {}
	moving = false
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
	local server = TeleportService:ReserveServer(placeId)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = server
	
	
	local ownerPlayer = game.Players:FindFirstChild(script.Parent.Owner.Value)
	local ownerId = ownerPlayer and ownerPlayer.UserId or nil
	for i,v in pairs(playersWaiting) do
		ReplicatedStorage.Remotes.UI.Blackout:FireClient(v)
	end

	options:SetTeleportData({World = 1,Level = 1,Mode = script.Parent.Mode.Value, OwnerId = ownerId, Versus = true})
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
	task.wait(7)
	Setup()
end

local function RunCountdown()
	script.Parent.TimerActive.Value = true
	local i = 7
	while true do
		if #playersWaiting ~= config.MaxPlayers.Value then
			script.Parent.Timer.Value = 7
			task.wait(1) 
			continue
		end
		
		i -= 1


		script.Parent.Timer.Value = i
		task.wait(1)
		if #playersWaiting < 1 then
			script.Parent.TimerActive.Value = false
			Setup()
			return
		end
		if quickstart then
			script.Parent.Timer.Value = 0
			script.Parent.TimerActive.Value = false
			gui.Status.Bar.Size = UDim2.new(0,0,1,0)
			break
		end
		
		if i == 0 then
			break
		end
	end

	if #playersWaiting == config.MaxPlayers.Value then
		quickstart = false
		MoveElevator()
		script.Parent.TimerActive.Value = false
	else
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

elevator.Door.Touched:Connect(function(part)
	print('touched')
	local player = Players:GetPlayerFromCharacter(part.Parent)
    local isWaiting = table.find(playersWaiting, player)
        
    if player then
        if script.Parent.Players:FindFirstChild(player.Name) then
            return
        end

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


		local playerData = player

		
        local checks = {
            gotPlayer = player,
            notWaiting = not isWaiting,
            isElevatorFull = #playersWaiting < config.MaxPlayers.Value,
            notMoving = not moving,
            notLocked = not script.Parent.Locked.Value,
            appropriateTiem = tick()-1 > timeExited,
        }
        
        local allGood = true
        
		for i,v in checks do
			if not v then
				warn('Check failed:')
				warn(i)
				allGood = false
				break
			end
		end


		if allGood then
            print('passed all checks')
            
			table.insert(playersWaiting, player)
			local plrval = Instance.new("StringValue")
			plrval.Name = player.Name
			plrval.Parent = script.Parent.Players

			player.Character.PrimaryPart.CFrame = elevator.TeleportIn.CFrame

			--if #playersWaiting > 0 then
			--	script.Parent.Owner.Value = playersWaiting[1].Name
			--end

			elevatorEvent:FireClient(player, elevator, "Versus")

			--script.Parent.Locked.Value = true
			--gui.Status.State.Text = "Choosing..."

			task.spawn(function()
				RunCountdown()
			end)



			script.Parent.Locked.Value = false
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

while true do
	task.wait(1/3)
	if script.Parent.TimerActive.Value then
		gui.Status.State.Text = "Waiting for players..."
		gui.Status.Bar.Size = UDim2.new((script.Parent.Timer.Value/7),0,1,0)
	end
	if moving then 
		gui.Status.State.Text = "Teleporting..."
	end
end
