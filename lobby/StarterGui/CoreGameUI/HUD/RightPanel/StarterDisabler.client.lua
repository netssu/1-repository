local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ClientDataLoaded = require(ReplicatedStorage.Modules.ClientDataLoaded)
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

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

local function findSideMenuItem(name)
	local newUI = PlayerGui:FindFirstChild("NewUI") or PlayerGui:WaitForChild("NewUI", 5)
	local sideMenu = newUI and (newUI:FindFirstChild("sideMenu") or newUI:WaitForChild("sideMenu", 5))
	if not sideMenu then return nil end

	local lowerName = string.lower(name)

	for _, item in sideMenu:GetDescendants() do
		if string.lower(item.Name) == lowerName then
			return item
		end
	end

	return nil
end

local function setVisibleIfExists(instance, visible)
	if instance and instance:IsA("GuiObject") then
		instance.Visible = visible
	end
end

if lvl5Restricted then
	setVisibleIfExists(script.Parent:FindFirstChild("Battlepass"), false)
	setVisibleIfExists(script.Parent.Parent:FindFirstChild("Quests"), false)

	local leftPanel = script.Parent.Parent:FindFirstChild("LeftPanel")
	if leftPanel then
		setVisibleIfExists(leftPanel:FindFirstChild("QuestFrame"), false)
	end

	setVisibleIfExists(findSideMenuItem("Battlepass"), false)
	setVisibleIfExists(findSideMenuItem("quest"), false)
end

if lvl10Restricted then
	setVisibleIfExists(script.Parent:FindFirstChild("Areas"), false)
	setVisibleIfExists(findSideMenuItem("areas"), false)
end
