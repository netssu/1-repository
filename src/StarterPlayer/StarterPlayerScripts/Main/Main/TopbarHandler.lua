local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Simplebar = require(ReplicatedStorage.Modules.Client.Simplebar)
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)

repeat task.wait() until Player:FindFirstChild('DataLoaded')

local conn = nil

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

conn = UserInputService.InputBegan:Connect(function(key, gp)
	if not gp and not _G.CurrentlyOpen then
		if key.KeyCode == Enum.KeyCode.Tab then
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			_G.PlayerlistEnabled = true
			conn:Disconnect()
			conn = nil
		end
	end
end)


local UIHandler = require(ReplicatedStorage.Modules.Client.UIHandler)
local PlayerGui = Player:WaitForChild('PlayerGui')

local size = 0.5
local XSize = 44 -- 85

local CoreUI = PlayerGui:WaitForChild('CoreGameUI')
local GameUI = PlayerGui:WaitForChild('GameGui')
local UnitsUI = PlayerGui:WaitForChild('UnitsGui')

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

local name = 'Shop'
local button = Simplebar.createButton(name)
	:singleBind(true)
	:setColor(script[name])
	:setImage('rbxassetid://86654185211240')
	:setSize(size)
	:setUrgent(true)
	:setCustomXSize(XSize)
	:bindToFrame(CoreUI:WaitForChild('Shop'):WaitForChild('ShopFrame'))
	:setHoverText(name)

button:bindEvent(true, function()
	_G.CloseAll(name)
end)

button:bindEvent(false, function()
	_G.CloseAll(name)
end)

if not lvl10Restricted then
	local name = 'Auras'
	local button = Simplebar.createButton(name)
		:singleBind(true)
		:setColor(script[name])
		:setImage('rbxassetid://16988699757')
		:setSize(size * 1.2)
		:setCustomXSize(XSize)
		:bindToFrame(GameUI:WaitForChild('Auras'):WaitForChild('AurasFrame'))
		:setHoverText(name)

	button:bindEvent(true, function()
		_G.CloseAll(name)
		UIHandler.DisableAllButtons()
	end)

	button:bindEvent(false, function()
		_G.CloseAll(name)
		UIHandler.EnableAllButtons()
	end)
end

if not lvl5Restricted then
	local name = 'Items'
	local button = Simplebar.createButton(name)
		:singleBind(true)
		:setColor(script[name])
		:setImage('rbxassetid://90522875235973')
		:setSize(size)
		:setCustomXSize(XSize)
		:bindToFrame(CoreUI:WaitForChild('Items'):WaitForChild('ItemsFrame'))
		:setHoverText(name)

	button:bindEvent(true, function()
		_G.CloseAll(name)
	end)

	button:bindEvent(false, function()
		_G.CloseAll(name)
	end)
end

local name = 'Units'
local button = Simplebar.createButton(name)
	:singleBind(true)
	:setColor(script[name])
	:setImage('rbxassetid://139799678526551')
	:setSize(size)
	:setCustomXSize(XSize)
	:bindToFrame(UnitsUI:WaitForChild('Inventory'):WaitForChild('Units'))
	:setHoverText(name)

button:bindEvent(true, function()
	_G.CloseAll(name)
end)

button:bindEvent(false, function()
	_G.CloseAll(name)
end)

local GetUnits = ReplicatedStorage.GetUnitsButton

GetUnits.OnInvoke = function()
	return button.instance
end


-- Settings
local name = 'Settings'
local button = Simplebar.createButton(name)
	:singleBind(true)
	--:setColor(script[name]) -- white by default
	:setImage('rbxassetid://131059016517582')
	:setSize(size * 0.9)
	:setSide('Left')
	:setCustomXSize(44)
	--:bindToFrame(CoreUI:WaitForChild('DailyReward'):WaitForChild('DailyRewardFrame'))
	:bindToFrame(CoreUI:WaitForChild('Settings'):WaitForChild('SettingsFrame'))
	:setHoverText(name)

button:bindEvent(true, function()
	_G.CloseAll(name)
end)

button:bindEvent(false, function()
	_G.CloseAll(name)
end)

if not lvl5Restricted then
	local name = 'Achievements'
	local button = Simplebar.createButton(name)
		:singleBind(true)
		:setColor(script[name])
		:setImage('rbxassetid://80144273755421')
		:setSize(size)
		:setCustomXSize(44)
		:setSide('Left')
		:bindToFrame(CoreUI:WaitForChild('Achievements'):WaitForChild('AchievementsFrame'))
		:setHoverText(name)

	button:bindEvent(true, function()
		_G.CloseAll(name)
	end)

	button:bindEvent(false, function()
		_G.CloseAll(name)
	end)
end


local name = 'DailyReward'
local button = Simplebar.createButton(name)
	:singleBind(true)
	:setColor(script[name])
	:setImage('rbxassetid://114863773335807')
	:setSize(size* 0.8)
	:setSide('Left')
	:setCustomXSize(44)
	:bindToFrame(CoreUI:WaitForChild('DailyReward'):WaitForChild('DailyRewardFrame'))
	:setHoverText('Daily Rewards')

button:bindEvent(true, function()
	_G.CloseAll(name)
end)

button:bindEvent(false, function()
	_G.CloseAll(name)
end)

if not lvl10Restricted then
-- Clans
	local name = 'Clans'
	local button = Simplebar.createButton(name)
		:singleBind(true)
		:setColor(script[name])
		:setImage('rbxassetid://131163327376576')
		:setSize(size)
		:setCustomXSize(XSize)
		:bindToFrame(CoreUI:WaitForChild('Clans'):WaitForChild('ClansFrame'))
		:setHoverText(name)

	button:bindEvent(true, function()
		_G.CloseAll(name)
	end)

	button:bindEvent(false, function()
		_G.CloseAll(name)
	end)
end

local PlayerRestrictions = workspace:WaitForChild('NewPlayerRestrictions')

if not lvl10Restricted and not lvl5Restricted then
	for i,v in PlayerRestrictions:GetChildren() do
		v:Destroy()
	end
end

return {}