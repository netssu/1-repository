-- SERVICES
local ServerStorage = game:GetService('ServerStorage')
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

-- CONSTANTS

-- VARIABLES
local ErrorService = require(ServerStorage.ServerModules.ErrorService)

-- FUNCTIONS
local function main()
    -- VARIABLES
    local SafeTeleport = require(ServerScriptService.SafeTeleport)
    local RaidModeStats = require(ReplicatedStorage.RaidModeStats)
    local AllFunc = require(ReplicatedStorage.Modules.VFX_Helper)
    local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)
    local RaidDataSync = require(ServerScriptService.ProfileServiceMain.Main.RaidDataSync)

    local WasMessage = false
    local CurrentEventMap = ReplicatedStorage.States.RaidMap.Value
    local Message = ReplicatedStorage.Events.Client:WaitForChild("Message")
    local movingEvent = ReplicatedStorage.Events:WaitForChild("MovingElevator")
    local elevatorEvent = ReplicatedStorage.Events:WaitForChild("RaidElevator")
    local elevator = script.Parent
    local config = elevator.Config
    local playersWaiting = {}
    local moving = false
    local choose = false
    local quickstart = false
    local timeExited = tick()
    local debounce = {}

    local gui = script.Parent.Door.Surface.Frame.InformationFrame

    -- FUNCTIONS
    local function update()
        if #playersWaiting > 0 then
            script.Parent.Owner.Value = playersWaiting[1].Name
        end
        local world = RaidModeStats.Worlds[script.Parent.World.Value]
        
        if world then
            if script.Parent.Level.Value == 0 then
                gui.ActName.Text = "Infinity Mode"
            else
                local ActName = RaidModeStats.LevelName[world][script.Parent.Level.Value]
                if ActName then
                    gui.ActName.Text = `Act {script.Parent.Level.Value} - {ActName}`
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

        if #playersWaiting == 0 then
            gui.Status.State.Text = "Empty"
            gui.ActName.Text = ""
            gui["Story Name"].Text = ""
            gui["Mode Text"].Text = ""
            gui.Status.Bar.Size = UDim2.new(0,0,1,0)
        end
        gui.Status.Players.Text = #playersWaiting.."/"..config.MaxPlayers.Value
    end

    local function isActUnlocked(Player, world, act)
        local WorldStats = Player:WaitForChild("RaidActData")

        if world == ReplicatedStorage.States.RaidMap.Value and tostring(act) == "1" then
            return true
        end

        local worldOrder = RaidModeStats.Worlds 
        local previousWorldCleared = false

        for i, RaidMap in ipairs(worldOrder) do
            if RaidMap == world then
                if act == "1" and previousWorldCleared then
                    return true
                end

                local actNum = tonumber(act)
                if actNum and actNum > 1 then
                    local prevActClears = WorldStats[world]["Act" .. tostring(actNum - 1)].TotalClears.Value
                    return prevActClears > 0
                end

                return false
            end

            local allCleared = true
            for a = 1, 5 do
                if WorldStats[RaidMap]["Act" .. tostring(a)].TotalClears.Value == 0 then
                    allCleared = false
                    break
                end
            end

            previousWorldCleared = allCleared
        end

        return false
    end

    local function Setup()
        playersWaiting = {}
        moving = false
        choose = false
        quickstart = false
        script.Parent.Level.Value = 1
        script.Parent.World.Value = 4
        script.Parent.Owner.Value = ""
        script.Parent.TimerActive.Value = false
        script.Parent.FriendsOnly.Value = false
        script.Parent.Infinite.Value = false
        script.Parent.Timer.Value = 0
        script.Parent.Locked.Value = false
        script.Parent.Players:ClearAllChildren()
        update()
    end

    local function TeleportPlayers()
        warn("Teleporting players")
        local placeId = PlaceData.Game
        local server = TeleportService:ReserveServer(placeId)
        local options = Instance.new("TeleportOptions")
        options.ReservedServerAccessCode = server
        local ownerPlayer = game.Players:FindFirstChild(script.Parent.Owner.Value)
        local ownerId = ownerPlayer and ownerPlayer.UserId or nil
        
        for i,v in pairs(playersWaiting) do
            ReplicatedStorage.Remotes.UI.Blackout:FireClient(v)
        end
        
        options:SetTeleportData({World = script.Parent.World.Value,Level = script.Parent.Level.Value, Raid = true,Mode = script.Parent.Mode.Value, OwnerId = ownerId, Infinity = script.Parent.Infinite.Value})
        SafeTeleport(placeId, playersWaiting, options)
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
        
        if currentOwner == script.Parent.Owner.Value and #playersWaiting > 0 then
            quickstart = false
            choose = false
            script.Parent.TimerActive.Value = false
            MoveElevator()
        else
            Setup()
        end
    end

    -- INIT
    script.ChangeStory.OnServerEvent:Connect(function(player,valuetype,newvalue)
        if #playersWaiting > 0 then
            if playersWaiting[1] == player and script.Parent:FindFirstChild(valuetype) then
                script.Parent[valuetype].Value = newvalue
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
    
    script.SelectAct.OnServerEvent:Connect(function(player, value)
        local actUnlocked = isActUnlocked(player, CurrentEventMap, value)
        if value and tonumber(value) and actUnlocked then
            if script.Parent.Owner.Value == player.Name then
                script.Parent.Level.Value = tonumber(value)
            end
        end
    end)

    elevator.Door.Touched:Connect(function(part)
        local player = Players:GetPlayerFromCharacter(part.Parent)
        local isWaiting = table.find(playersWaiting, player)

        if player then
            local RaidsRefresh = ReplicatedStorage.Remotes.RaidsRefresh
            RaidDataSync.checkIfReset(player)
            
            if player.RaidsRefresh.Value > 0 and player.RaidLimitData.Attempts.Value <= 0 then
                RaidsRefresh:FireClient(player)
            end
            
            if not debounce[player] then
                debounce[player] = true

                local connection
                connection = RaidsRefresh.OnServerEvent:Connect(function(p, valid)
                    if p ~= player then return end
                    if not valid then return end
                    
                    player.RaidsRefresh.Value -= 1
                    player.RaidLimitData.Attempts.Value += 10
                    player.RaidLimitData.OldReset.Value = os.time()
                    player.RaidLimitData.NextReset.Value = os.time() + 14400

                    connection:Disconnect()
                    task.delay(5, function()
                        debounce[player] = nil
                    end)
                end)
            end
            
            local canEnter = player:FindFirstChild('DataLoaded') and player.RaidLimitData.Attempts.Value > 0
            
            if not canEnter then
                require(script.DevProductPrompt).prompt(player)
                return
            end
            
            local value = AllFunc.HaveEquipUnits(player)
            if not value then
                if not WasMessage then
                    WasMessage = true
                    task.spawn(function()
                        task.wait(1)
                        WasMessage = false
                    end)
                    Message:FireClient(player,"Equip at Least 1 Unit ", Color3.new(1, 0, 0))
                end
                return
            end

            local requiredLevel = script.Parent.Level.Value
            if requiredLevel <= 0 then
                requiredLevel = #RaidModeStats.LevelName[RaidModeStats.Worlds[script.Parent.World.Value]]
            end

            if player and not isWaiting and #playersWaiting < config.MaxPlayers.Value and not moving and not script.Parent.Locked.Value and tick()-1 > timeExited and
                (script.Parent.FriendsOnly.Value == false or (script.Parent.FriendsOnly.Value == true and player:IsFriendsWith(Players[script.Parent.Owner.Value].UserId))) then
                
                table.insert(playersWaiting, player)
                local plrval = Instance.new("StringValue")
                plrval.Name = player.Name
                plrval.Parent = script.Parent.Players

                player.Character:PivotTo(elevator.TeleportIn.CFrame)

                if #playersWaiting > 0 then
                    script.Parent.Owner.Value = playersWaiting[1].Name
                end

                elevatorEvent:FireClient(player, elevator, "Raids")

                script.Parent.Locked.Value = true
                gui.Status.State.Text = "Choosing..."

                if not script.Parent.TimerActive.Value then
                    task.spawn(function()
                        RunCountdown()
                    end)
                end

                while not choose and #playersWaiting > 0 do
                    task.wait()
                end

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
                        local character = plr.Character
                        if not character then continue end
                        character:PivotTo(script.Parent.TeleportOut.CFrame)
                    end
                    v:Destroy()
                end
                Setup()
            end

            update()
            if player.Character then
                player.Character:PivotTo(script.Parent.TeleportOut.CFrame)
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        if table.find(playersWaiting,player) then
            if player.Name == script.Parent.Owner.Value then
                quickstart = false
                timeExited = tick()
                Setup()
                for i, v in script.Parent.Players:GetChildren() do
                    local plr = Players:FindFirstChild(v.Name)
                    if plr then
                        ReplicatedStorage.Events.OwnerLeavesElevator:FireClient(plr)
                        local character = plr.Character or plr.CharacterAdded:Wait()
                        character:PivotTo(elevator.Door.CFrame * CFrame.new(0,-5,-10))
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

    task.spawn(function()
        while task.wait(0.25) do
            if moving then 
                gui.Status.State.Text = "Teleporting..."
                continue
            end
            
            if script.Parent.TimerActive.Value then
                gui.Status.State.Text = "Waiting for players..."
                gui.Status.Bar.Size = UDim2.new((script.Parent.Timer.Value/50),0,1,0)
            end
        end
    end)
end

-- INIT
ErrorService.wrap(main)