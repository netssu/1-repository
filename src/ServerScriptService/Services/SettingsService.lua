local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------//SERVICES
local PlayerDataManager = require(ReplicatedStorage.Packages.PlayerDataManager)
local Packets = require(ReplicatedStorage.Modules.Game.Packets)

local SettingsService = {}

------------------//CONSTANTS
local MAX_NUMBER_VALUE = 10
local MIN_NUMBER_VALUE = 0

------------------//FUNCTIONS
local SettingHandlers = {
	boolean = function(currentValue, _action)
		return not currentValue
	end,
	number = function(currentValue, action)
		if action == "increase" then
			return math.clamp(currentValue + 1, MIN_NUMBER_VALUE, MAX_NUMBER_VALUE)
		elseif action == "decrease" then
			return math.clamp(currentValue - 1, MIN_NUMBER_VALUE, MAX_NUMBER_VALUE)
		end
		return currentValue
	end,
}

function SettingsService.Init()
	Packets.ChangeSetting.OnServerEvent:Connect(function(player, settingKey, action)
		SettingsService.ChangeSetting(player, settingKey, action)
	end)
	
	print("[SettingsService] Initialized")
end

function SettingsService.ChangeSetting(player: Player, settingKey: string, action: string)
	local currentSettings = PlayerDataManager:Get(player, {"Settings"})
	
	if not currentSettings or currentSettings[settingKey] == nil then
		warn(`[SettingsService] Setting '{settingKey}' not found for {player.Name}`)
		return
	end
	
	local currentValue = currentSettings[settingKey]
	local valueType = typeof(currentValue)
	
	local handler = SettingHandlers[valueType]
	
	if handler then
		local newValue = handler(currentValue, action)
		
		if newValue ~= currentValue then
			local updatedSettings = {}
			for key, value in pairs(currentSettings) do
				updatedSettings[key] = value
			end
			updatedSettings[settingKey] = newValue
			
			PlayerDataManager:Set(player, {"Settings"}, updatedSettings)
			
			print(`[SettingsService] {player.Name} changed {settingKey} to {newValue}`)
		end
	else
		warn(`[SettingsService] No handler for type: {valueType}`)
	end
end

return SettingsService