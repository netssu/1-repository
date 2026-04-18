--!strict

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameplayGuiVisibility = require(ReplicatedStorage.Modules.Game.GameplayGuiVisibility)

local GameplayGuiController = {}

local LocalPlayer: Player = Players.LocalPlayer
local PLAYER_GUI_NAMES: {[string]: boolean} = {
	GameGui = true,
	HudGui = true,
}
local CUTSCENE_ATTRIBUTES: {string} = {
	"FTAwakenCutsceneActive",
	"FTCutsceneHudHidden",
	"FTMatchCutsceneLocked",
	"FTPerfectPassCutsceneLocked",
	"FTTouchdownGameplayGuiOverride",
}

local Connections: {RBXScriptConnection} = {}
local CharacterConnections: {RBXScriptConnection} = {}
local BlockedEnforcementConnection: RBXScriptConnection? = nil
local BoundCharacter: Model? = nil
local Started: boolean = false

local function TrackConnection(Bucket: {RBXScriptConnection}, Connection: RBXScriptConnection): ()
	table.insert(Bucket, Connection)
end

local function DisconnectConnections(Bucket: {RBXScriptConnection}): ()
	for _, Connection in Bucket do
		Connection:Disconnect()
	end
	table.clear(Bucket)
end

local function StopBlockedEnforcement(): ()
	if BlockedEnforcementConnection then
		BlockedEnforcementConnection:Disconnect()
		BlockedEnforcementConnection = nil
	end
end

local function EnforceGameplayGuiHiddenIfBlocked(): ()
	if not GameplayGuiVisibility.IsGameplayGuiBlocked(LocalPlayer) then
		StopBlockedEnforcement()
		return
	end

	GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
	if BlockedEnforcementConnection then
		return
	end

	BlockedEnforcementConnection = RunService.Heartbeat:Connect(function()
		if not GameplayGuiVisibility.IsGameplayGuiBlocked(LocalPlayer) then
			StopBlockedEnforcement()
			return
		end
		GameplayGuiVisibility.EnforceGameplayGuiHidden(LocalPlayer)
	end)
end

local function BindCharacter(Character: Model): ()
	if BoundCharacter == Character then
		return
	end

	BoundCharacter = Character
	DisconnectConnections(CharacterConnections)

	for _, AttributeName in CUTSCENE_ATTRIBUTES do
		TrackConnection(CharacterConnections, Character:GetAttributeChangedSignal(AttributeName):Connect(function()
			EnforceGameplayGuiHiddenIfBlocked()
		end))
	end

	EnforceGameplayGuiHiddenIfBlocked()
end

function GameplayGuiController.Start(): ()
	if Started then
		return
	end
	Started = true

	local PlayerGui: PlayerGui =
		(LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")) :: PlayerGui

	TrackConnection(Connections, PlayerGui.ChildAdded:Connect(function(Child: Instance)
		if Child:IsA("ScreenGui") and PLAYER_GUI_NAMES[Child.Name] then
			task.defer(EnforceGameplayGuiHiddenIfBlocked)
		end
	end))

	for _, AttributeName in CUTSCENE_ATTRIBUTES do
		TrackConnection(Connections, LocalPlayer:GetAttributeChangedSignal(AttributeName):Connect(function()
			EnforceGameplayGuiHiddenIfBlocked()
		end))
	end

	TrackConnection(Connections, LocalPlayer.CharacterAdded:Connect(function(Character: Model)
		BindCharacter(Character)
	end))

	if LocalPlayer.Character then
		BindCharacter(LocalPlayer.Character)
	end

	task.defer(EnforceGameplayGuiHiddenIfBlocked)
end

return GameplayGuiController
