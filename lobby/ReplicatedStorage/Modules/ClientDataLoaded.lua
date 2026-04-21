local ReplicatedStorage = game:GetService("ReplicatedStorage")
local module = {}

local Players = game:GetService('Players')
local Player = Players.LocalPlayer

function module.getPlayerData()
	if not Player:FindFirstChild('DataLoaded') then
		local conn = nil
		local bindable = Instance.new('BindableEvent')
		
		conn = Player.ChildAdded:Connect(function(obj)
			if obj.Name == 'DataLoaded' then
				bindable:Fire()
			end
		end)
		
		bindable.Event:Wait()
		
		conn:Disconnect()
		conn = nil
		bindable:Destroy()
	end
	
	
	return Player
end


--[[
all of the code above is legit simplified to:
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild('Modules')
local ClientDataLoaded = require(Modules:WaitForChild('ClientDataLoaded'))

local Loaded = ClientDataLoaded.isDataLoaded()

if not Loaded then
	ClientDataLoaded.WaitUntilLoaded()
end

local PlayerData = ClientDataLoaded.getPlayerData()
--]]

_G.PlayerData = module.getPlayerData()


--[[
or:
repeat task.wait() until _G.PlayerData
local PlayerData = _G.PlayerData
--]]

return module
