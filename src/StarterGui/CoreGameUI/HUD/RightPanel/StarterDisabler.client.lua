local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)
local Player = Players.LocalPlayer

local plrData = ClientDataLoaded.getPlayerData()

local lvl5Restricted = false
local lvl10Restricted = false

if Player.Prestige.Value == 0 then
	local plrLevel = Player.PlayerLevel.Value

	if plrLevel < 5 then
		lvl5Restricted = true
		lvl10Restricted = true
	elseif plrLevel < 10 then
		lvl10Restricted = true
	end
end

if lvl5Restricted then
	script.Parent.Battlepass.Visible = false
	script.Parent.Parent.Quests.Visible = false
	script.Parent.Parent.LeftPanel.QuestFrame.Visible = false
end

if lvl10Restricted then
	script.Parent.Areas.Visible = false
end