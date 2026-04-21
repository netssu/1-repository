if not game:GetService('RunService'):IsStudio() then
	return
end

local discordWebHook = require(script.Parent)

--https://discordapp.com/api/webhooks/[id]/[token]
local hook = discordWebHook.new('[id]', '[token]')
local formatHelper = hook:GetFromatHelper()

local avatarUrl = game:GetService('Players'):GetUserThumbnailAsync(1540993, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

-- basic message
local msg = hook:NewMessage()
msg:Append('test')
msg:AppendLine('1')
msg:Append('line2')
msg:SetUsername('Test script')
msg:SetAvatarUrl(avatarUrl)
msg:SetTTS(false)
msg:Send()

-- message with markdown
local msg = hook:NewMessage()
msg:AppendLine(formatHelper:UnderlineBold('Test script'))
msg:AppendLine(formatHelper:Spoiler('Sent from Roblox'))
msg:AppendLine(formatHelper:Codeblock([[
print('Hello world!')

local a = true
if a then
	print(a)
end
]], 'Lua'))
msg:SetUsername('Test script')
msg:SetAvatarUrl(avatarUrl)
msg:Send()


-- basic message with mention
local msg = hook:NewMessage()
local allowedMention = msg:GetAllowedMention()
allowedMention:AddGlobalMention('everyone')
msg:SetAvatarUrl(avatarUrl)
msg:Append('test')
msg:AppendLine('1')
msg:Append('line2 @everyone')
msg:SetUsername('Test script')
msg:SetAvatarUrl(avatarUrl)
msg:SetTTS(false)
msg:Send()

-- basic embed
local msg = hook:NewMessage()
msg:SetAvatarUrl(avatarUrl)
local embed = msg:NewEmbed()
embed:SetTitle('basic embed')
embed:Append('test')
embed:AppendLine('1')
embed:Append('line2')
msg:Send()

-- multiple embeds
local msg = hook:NewMessage()
msg:SetAvatarUrl(avatarUrl)
local embed1 = msg:NewEmbed()
embed1:SetTitle('Embed 1')
embed1:Append('embed 1 body')
embed1:SetColor3(Color3.fromRGB(0, 255, 0))
local embed2 = msg:NewEmbed()
embed2:SetTitle('Embed 2')
embed2:Append('embed 2 body')
embed2:SetColor3(Color3.fromRGB(0, 0, 255))
msg:Send()

-- complex embed with fields
local msg = hook:NewMessage()
msg:SetAvatarUrl(avatarUrl)
local embed = msg:NewEmbed()
embed:SetTitle('complex embed')
embed:Append('embed body')
embed:SetURL('https://www.roblox.com/users/1540993/profile')
embed:SetTimestamp(tick() - 86400) -- -1 day
embed:SetColor3(Color3.fromRGB(255, 0, 0))
embed:AppendFooter('embed footer')
embed:SetFooterIconURL(avatarUrl)
embed:SetImageURL(avatarUrl)
embed:SetThumbnailIconURL(avatarUrl)
embed:SetAuthorName('kingdom5')
embed:SetAuthorURL('https://www.roblox.com/users/1540993/profile')
embed:SetAuthorIconURL(avatarUrl)
local field1 = embed:NewField()
field1:SetName('field 1')
field1:Append('body1')
local field2 = embed:NewField()
field2:SetName('field 2')
field2:Append('body2')
local field3 = embed:NewField()
field3:SetName('field 3')
field3:Append('body3')
field3:SetIsInline(true)
local field4 = embed:NewField()
field4:SetName('field 4')
field4:Append('body4')
field4:SetIsInline(true)
msg:Send()

-- message spam test
for i=1, 10 do
	local msg = hook:NewMessage()
	msg:SetAvatarUrl(avatarUrl)
	msg:Append('message spam test ' .. i)
	msg:Send()
end