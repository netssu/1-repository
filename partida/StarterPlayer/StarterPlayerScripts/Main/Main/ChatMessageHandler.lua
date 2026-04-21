local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local ClanTags = require(ReplicatedStorage.ClansLib.ClanTags)
local TextGradient = require(ReplicatedStorage.AceLib.TextGradient)

local Events = game.ReplicatedStorage:WaitForChild("Events")
local ClientEventFolder =  Events:WaitForChild("Client")
local ChatMessageEvent = ClientEventFolder:WaitForChild("ChatMessage")

local Owners = {}
local Developers = {}
local Admins = {}

ChatMessageEvent.OnClientEvent:Connect(function(message)
	TextChatService.TextChannels.RBXSystem:DisplaySystemMessage(`{message}`)
end)


local hexColorText = ""
local text = "[Ultra VIP]"

local UltraVIPSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0,255,255))}
)


hexColorText = TextGradient.textGradient(text, UltraVIPSequence)

local ValidRoles = {
	["Owner"] = Color3.fromRGB(255, 128, 0),
	["Content Creator"] = Color3.fromRGB(255, 0, 0),
	["Developer"] = Color3.fromRGB(0, 4, 255),
	["Developer+"] = Color3.fromRGB(0, 4, 255),
	["Manager"] = Color3.fromRGB(93, 43, 0),
	['Community Manager'] = Color3.fromRGB(101,185,158),
}

TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")
	local player = ( message.TextSource and game.Players:FindFirstChild(message.TextSource.Name) ) or nil

	if player then
		local PlayerRoleInGroup = player:GetRoleInGroup(35339513)
		if player:FindFirstChild("DataLoaded") then
			if ValidRoles[PlayerRoleInGroup] then
				local hexColor = ValidRoles[PlayerRoleInGroup]:ToHex()
				props.PrefixText = `<font color="#{hexColor}">[{PlayerRoleInGroup}]</font>`
			elseif player.OwnGamePasses['Ultra VIP'].Value then
				local hexColor = Color3.fromRGB(220, 254, 84):ToHex()
				props.PrefixText = hexColorText
			elseif player.OwnGamePasses.VIP.Value == true then
				local hexColor = Color3.fromRGB(255, 255, 0):ToHex()
				props.PrefixText = `<font color="#{hexColor}">[VIP]</font>` 
			end
			
			if player:FindFirstChild('ClansLoaded') then
				local clan = player.ClanData.CurrentClan.Value
				local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
				
				if foundClan then
					local clanPrefix = `[{clan}] `
					
					local tagCol = ClanTags.Tags[foundClan.ActiveColor.Value] 
					
					if typeof(tagCol.Color) == 'table' then
						clanPrefix = TextGradient.textGradient(`[{clan}]`, ClanTags.generateColorSequence(tagCol.Color))
					else
						--`<font color="#{hexColor}">[VIP]</font>`
						local Sequence = ColorSequence.new({
							ColorSequenceKeypoint.new(0, tagCol.Color),
							ColorSequenceKeypoint.new(1, tagCol.Color)
						})
						
						clanPrefix = TextGradient.textGradient(`[{clan}]`, Sequence)
					end
					
					--ClanTags.Color3Tohex()
					--ClanTags.Tags
					
					props.PrefixText ..= ' ' .. clanPrefix
				end
			end
			
			props.PrefixText ..= ` [{player.DisplayName }]`
			
		end
	end

	return props	

end



return {}