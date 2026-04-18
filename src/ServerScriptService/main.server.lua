local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local Framework = require(ReplicatedStorage.Framework)
local STUDIO_LIVE_DATASTORES_ATTRIBUTE = "ProfileStoreStudioUseLiveData"

local FrameworkStarted = false
local PendingCharacterLoadTokens = {}
local CharacterAddedConnections = {}
local CharacterDiedConnections = {}

if RunService:IsStudio() and game:GetAttribute(STUDIO_LIVE_DATASTORES_ATTRIBUTE) == nil then
	game:SetAttribute(STUDIO_LIVE_DATASTORES_ATTRIBUTE, true)
	print(string.format("[main.server] %s defaulted to true in Studio for live save/load", STUDIO_LIVE_DATASTORES_ATTRIBUTE))
end

Players.CharacterAutoLoads = false

local function DisconnectConnection(Connection)
	if Connection then
		Connection:Disconnect()
	end
end

local function CancelPendingCharacterLoad(Player)
	PendingCharacterLoadTokens[Player] = (PendingCharacterLoadTokens[Player] or 0) + 1
end

local function ScheduleCharacterLoad(Player, DelaySeconds)
	CancelPendingCharacterLoad(Player)
	local Token = PendingCharacterLoadTokens[Player]

	task.delay(math.max(DelaySeconds or 0, 0), function()
		if PendingCharacterLoadTokens[Player] ~= Token then
			return
		end
		if not FrameworkStarted or Player.Parent == nil then
			return
		end

		local CurrentCharacter = Player.Character
		if CurrentCharacter and CurrentCharacter.Parent ~= nil then
			local Humanoid = CurrentCharacter:FindFirstChildOfClass("Humanoid")
			if Humanoid and Humanoid.Health > 0 then
				return
			end
		end

		local Success, ErrorMessage = pcall(function()
			Player:LoadCharacter()
		end)
		if not Success and RunService:IsStudio() then
			warn(string.format("main.server: failed to load character for %s: %s", Player.Name, tostring(ErrorMessage)))
		end
	end)
end

local function BindCharacterLifecycle(Player, Character)
	CancelPendingCharacterLoad(Player)
	DisconnectConnection(CharacterDiedConnections[Player])
	CharacterDiedConnections[Player] = nil

	local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 10)
	if not Humanoid or not Humanoid:IsA("Humanoid") then
		return
	end

	CharacterDiedConnections[Player] = Humanoid.Died:Connect(function()
		if Player.Parent == nil then
			return
		end
		ScheduleCharacterLoad(Player, Players.RespawnTime)
	end)
end

local function HandlePlayerAdded(Player)
	DisconnectConnection(CharacterAddedConnections[Player])
	CharacterAddedConnections[Player] = Player.CharacterAdded:Connect(function(Character)
		BindCharacterLifecycle(Player, Character)
	end)

	if FrameworkStarted then
		if Player.Character then
			BindCharacterLifecycle(Player, Player.Character)
		else
			ScheduleCharacterLoad(Player, 0.1)
		end
	end
end

local function HandlePlayerRemoving(Player)
	CancelPendingCharacterLoad(Player)
	DisconnectConnection(CharacterAddedConnections[Player])
	DisconnectConnection(CharacterDiedConnections[Player])
	CharacterAddedConnections[Player] = nil
	CharacterDiedConnections[Player] = nil
end

Players.PlayerAdded:Connect(HandlePlayerAdded)
Players.PlayerRemoving:Connect(HandlePlayerRemoving)

for _, Player in Players:GetPlayers() do
	HandlePlayerAdded(Player)
end

Framework:Start():andThen(function()
	FrameworkStarted = true
	for _, Player in Players:GetPlayers() do
		if Player.Character then
			BindCharacterLifecycle(Player, Player.Character)
		else
			ScheduleCharacterLoad(Player, 0.1)
		end
	end

	if not RunService:IsStudio() then
		print("[S]: Server load completed")
	end

	local _Commands = require(ServerScriptService.Services.CommandsService)

end)
