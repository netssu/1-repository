local TeleportService = game:GetService("TeleportService")

local FunctionsFolder = game.ReplicatedStorage.Functions
local EventsFolder = game.ReplicatedStorage.Events
local ClientMessage = EventsFolder.Client.Message

local ChallengeElevatorsFolder = workspace.ChallengeElevators
local DataFolder = ChallengeElevatorsFolder.Data

local ChallengeTable = {}
task.wait(5)
for i,v in pairs(ChallengeElevatorsFolder:GetChildren()) do
	if string.find(v.Name, 'Challenge') then
        ChallengeTable[v.Name] = v
    end
end


local ChallengeModule = require(game.ReplicatedStorage.Modules.ChallengeModule)
local StoryModeStats = require(game.ReplicatedStorage.StoryModeStats)
local SafeTeleport = require(game.ServerScriptService.SafeTeleport)
local AllFunc = require(game.ReplicatedStorage.Modules.VFX_Helper)
local PlaceData = require(game.ServerStorage.ServerModules.PlaceData)
local WasMessage = false

local function isActUnlocked(Player, world, act)
	local WorldStats = Player:WaitForChild("WorldStats")

	-- Shortcut: first act of the first world is always unlocked
	if world == "Naboo Planet" and act == "1" then
		return true
	end

	local worldOrder = StoryModeStats.Worlds  -- Assumed to be in order
	local previousWorldCleared = false

	for i, RaidMap in ipairs(worldOrder) do
		if RaidMap == world then
			if act == "1" and previousWorldCleared then
				return true
			end

			local actNum = tonumber(act)
			if actNum and actNum > 1 then
				local prevActClears = WorldStats[world].LevelStats["Act" .. tostring(actNum - 1)].Clears.Value
				return prevActClears > 0
			end

			return false
		end

		-- Check if all 5 acts in this world are cleared
		local allCleared = true
		for a = 1, 5 do
			if WorldStats[RaidMap].LevelStats["Act" .. tostring(a)].Clears.Value == 0 then
				allCleared = false
				break
			end
		end

		previousWorldCleared = allCleared
	end

	return false
end


local ElevatorModules = {}

--warn('yeld')
local ElevatorControls = {

	["RequestLeave"] = function(self, player)
		local playerIndex = table.find(self.CurrentPlayers, player)
		if not playerIndex then return end
		if self.CurrentPhase == 3 then
			return false
		end
		if self.HostPlayer == player then
			self:Reset()
		else
			table.remove(self.CurrentPlayers, playerIndex)
			local playerCharacter = player.Character
			if playerCharacter then
				playerCharacter:PivotTo(self.Elevator.TeleportOut.CFrame * CFrame.new(0,2,0))
			end
			self:Update()
		end
		return true

	end,
	["RequestStart"] = function(self, player)
		if not table.find(self.CurrentPlayers, player) or self.HostPlayer ~= player then return end
		if self.CurrentPhase ~= 3 then
			self:Start()
		end

		return true
	end,
	["EntranceTouched"] = function(self, part)
		local character = part.Parent
		local player = game.Players:GetPlayerFromCharacter(character)
		if not player then return end
		if table.find(self.CurrentPlayers, player) then return end --check if player already in room
		if self.OnCooldowns[`{player.Name}Entrance`] then return end
		local value = AllFunc.HaveEquipUnits(player)
		if not value then
			if not WasMessage  then
				WasMessage = true
				task.spawn(function()
					task.wait(1)
					WasMessage = false
				end)
				ClientMessage:FireClient(player,"Equip at Least 1 Unit ", Color3.new(1, 0, 0))
			end
			return
		end

		
		local playerStoryProgressFolder = player.StoryProgress
		local worldName = StoryModeStats.Worlds[self.ChallengeData.World]
		local worldUnlocked = isActUnlocked(player, worldName, "5")
		
		--warn('world:')
		--warn(self.ChallengeData.World)
		--print(StoryModeStats.Worlds[self.ChallengeData.World])
		if not worldUnlocked then
			ClientMessage:FireClient(player, `This story is not yet within your grasp - complete {worldName} first.`, Color3.fromRGB(255, 0, 0),nil,"Error")
			self.OnCooldowns[`{player.Name}Entrance`] = true
			task.delay(1,function()
				self.OnCooldowns[`{player.Name}Entrance`] = false
			end)
			return
		end

		--if player.LastChallengeCompletedUniqueId.Value == DataFolder.RefreshingAt.Value then 
		--	ClientMessage:FireClient(player, "Already Completed Challenge", Color3.fromRGB(255, 0, 0))
		--	self.OnCooldowns[`{player.Name}Entrance`] = true
		--	task.delay(1,function()
		--		self.OnCooldowns[`{player.Name}Entrance`] = false
		--	end)
		--	return 
		--end

		if #self.CurrentPlayers >= self.MaxPlayers or self.CurrentPhase == 3 then 

			return 
		end --no entry if reached max player
	




		if #self.CurrentPlayers == 0 then
			self.HostPlayer = player
		end



		table.insert(self.CurrentPlayers, player)

		character:PivotTo(self.Elevator.TeleportIn.CFrame * CFrame.new(0,2,0))
		EventsFolder.PlayerJoinChallenge:FireClient(player, true, self.Elevator, self.HostPlayer)

		if not self.TimerStarted then
			self:StartTimer()
		end

	end,
	["PlayerRemoving"] = function(self,player)
		local playerIndex = table.find(self.CurrentPlayers, player)
		if not playerIndex then return end

		--if self.CurrentPhase == 3 then
		--	return false
		--end

		if self.HostPlayer == player then
			self:Reset()
		else
			table.remove(self.CurrentPlayers, playerIndex)
			local playerCharacter = player.Character
			if playerCharacter then
				playerCharacter:PivotTo(self.Elevator.TeleportOut.CFrame * CFrame.new(0,2,0))
			end
			self:Update()
		end


	end,
	["Reset"] = function(self)
		for _,player in self.CurrentPlayers do
			task.spawn(function()
				local character = player.Character

				EventsFolder.PlayerJoinChallenge:FireClient(player, false, self.Elevator)

				if not character then return end
				character:PivotTo(self.Elevator.TeleportOut.CFrame * CFrame.new(0,2,0))
			end)

		end

		self.CurrentPlayers = {}
		self.TimerStarted = false
		self.CurrentTime = 0
		self.CurrentPhase = 1
		self.HostPlayer = nil

		self:Update()
	end,
	["StartTimer"] = function(self)

		task.spawn(function()

			self.CurrentPhase = 2
			self.TimerStarted = true
			self.CurrentTime = 60
			self:Update()

			while self.CurrentTime > 0 do
				task.wait(1)
				if self.CurrentPhase == 3 or self.CurrentPhase == 1 then
					return
				end
				self.CurrentTime -= 1
				self:Update()
			end

			self:Start()
		end)

	end,
	["Update"] = function(self)
		--handles updating data folder and the door ui
		local DoorPart = self.Elevator.Door
		local InformationFrame = DoorPart.Surface.Frame.InformationFrame
		local StatusFrame = InformationFrame.Status

		if not self.ChallengeData.World then
			warn("Challenge Data was not found")
			repeat task.wait() until self.ChallengeData.World
		end

		local worldName = StoryModeStats.Worlds[self.ChallengeData.World]
		--print(self.ChallengeData.World)
		--print(self.ChallengeData.Level)
		local levelName = StoryModeStats.LevelName[worldName][self.ChallengeData.Level]
		

		InformationFrame["Story Name"].Text = worldName
		InformationFrame.ActName.Text = `Act {self.ChallengeData.Level} - {levelName}`
		InformationFrame.Challenge.Text = self.ChallengeData.Name

		if self.CurrentPhase == 3 then
			StatusFrame.State.Text = "Teleporting..."
		else
			if #self.CurrentPlayers > 0 then
				StatusFrame.State.Text = "Waiting For Players..."
			else
				StatusFrame.State.Text = "Empty"
			end
		end



		StatusFrame.Players.Text = `{#self.CurrentPlayers}/{self.MaxPlayers}`
		StatusFrame.Bar.Size = UDim2.new(self.CurrentTime/ 60, 0, 1, 0)

	end,
	["Start"] = function(self)
		--coroutine.yield(self.CoroutineTimer)

		local world, level = self.ChallengeData.World, self.ChallengeData.Level
		local function TeleportPlayers()
			local placeId = PlaceData.Game
			local server = TeleportService:ReserveServer(placeId)
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = server
			
			
			
			options:SetTeleportData({
				OwnerId = self.HostPlayer and self.HostPlayer.UserId or nil,
				World = world,
				Level = level,
				Mode = 2, 
				ChallengeNumber = self.ChallengeData.ChallengeNumber, 
				ChallengeUniqueId = DataFolder.RefreshingAt.Value,
				ChallengeRewardNumber = self.ChallengeData.ChallengeRewardNumber
			})
			SafeTeleport(placeId, self.CurrentPlayers, options)
		end

		self.CurrentPhase = 3
		self:Update()

		for _, player in self.CurrentPlayers do
			EventsFolder.ChallengeStarting:FireClient(player)
		end
		print("Sent GUI")
		task.wait(3) -- allow loadinggui to be transfer
		print("Teleporting")
		local success = pcall(TeleportPlayers)
		self:Reset()


	end,
}
ElevatorControls.__index = ElevatorControls

function NewChallengeElevator(Elevator)
	local val = ChallengeModule.GetCurrent()
	--warn('SET VAL;')
	--warn(val)
	
	
	local self = setmetatable({
		MaxPlayers = 4,

		ChallengeData = val,
		Elevator = Elevator,
		Connections = {},
		OnCooldowns = {},
		CurrentPlayers = {},
		TimerStarted = false,
		CurrentTime = 0,
		CurrentPhase = 1, -- 1: empty room, 2: waiting to-start/for-full-timer, 3:teleporting
		HostPlayer = nil

	}, ElevatorControls)

	--warn('THE')
	self:Update()
	--warn('GOLAITH')

	self.Connections["EntranceTouched"] = Elevator.Entrance.Touched:Connect(function(part) 
		self:EntranceTouched(part) 
	end)
	self.Connections["PlayerRemoving"] = game.Players.PlayerRemoving:Connect(function(player)
		self:PlayerRemoving(player)
	end)
	DataFolder.RefreshingAt:GetPropertyChangedSignal("Value"):Connect(function()
		self.ChallengeData = ChallengeModule.GetCurrent()
		self:Reset()
		self:Update()
	end)



	return self
end

local function UpdateChallengeData()
	--warn('update challeng data')
	local newChallenge, RefreshingAtTime, RNGtable = ChallengeModule.GetCurrent()

    --warn('newChallenge:')
    --warn(newChallenge)
    --print(RNGtable)

	--warn('xo1')

	DataFolder.World.Value = newChallenge.World
	DataFolder.Level.Value = newChallenge.Level
	DataFolder.ChallengeNumber.Value = newChallenge.ChallengeNumber
	DataFolder.ChallengeRewardNumber.Value = newChallenge.ChallengeRewardNumber
	DataFolder.RefreshingAt.Value = RefreshingAtTime

    for i = 1, 3 do
        local inst = ChallengeTable['Challenge' .. tostring(i)]
        local newChallenge = RNGtable[i]
        
        inst.World.Value = newChallenge.World
        inst.Level.Value = newChallenge.Level
        inst.ChallengeNumber.Value = newChallenge.ChallengeNumber
        inst.ChallengeRewardNumber.Value = newChallenge.ChallengeRewardNumber
        inst.RefreshingAt.Value = RefreshingAtTime
    end

	for _, module in ElevatorModules do
		module:Update()
	end

	task.wait(RefreshingAtTime - os.time())
		
	UpdateChallengeData()

end

for _, elevator in ChallengeElevatorsFolder:GetChildren() do
	if not elevator:IsA("Model") then continue end
	ElevatorModules[elevator] = NewChallengeElevator(elevator)
end

FunctionsFolder.RequestChallengeLeave.OnServerInvoke = function(player)
	local foundPlayerInModule
	for _, module in ElevatorModules do
		if not foundPlayerInModule then
			if table.find(module.CurrentPlayers, player) then
				foundPlayerInModule = module
			end
		end
	end
	return foundPlayerInModule:RequestLeave(player)
end
FunctionsFolder.RequestChallengeStart.OnServerInvoke = function(player)
	local foundPlayerInModule
	for _, module in ElevatorModules do
		if not foundPlayerInModule then
			if table.find(module.CurrentPlayers, player) then
				foundPlayerInModule = module
			end
		end
	end
	return foundPlayerInModule:RequestStart(player)
end

UpdateChallengeData()