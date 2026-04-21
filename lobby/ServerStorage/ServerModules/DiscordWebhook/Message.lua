local message = {}
local embed = require(script.Embed)
local allowedMention = require(script.AllowedMention)
local HTTP_SERV = game:GetService('HttpService')

message.__index = message
message.__newindex = function() error('Cannot add new index') end
message.__metatable = 'Meta table locked'
message.__tostring = function(self)
	local data = {}
	
	data.content = self.content
	
	if self.username ~= '' then
		data.username = self.username
	end
	
	if self.avatar_url ~= '' then
		data.avatar_url = self.avatar_url
	end
	
	-- JSONEncode does not seem to call the tostring metatable correctly
	-- this is just a workaround
	if #self.embeds > 0 then
		data.embeds = {}
		for i=1, #self.embeds do
			data.embeds[i] = HTTP_SERV:JSONDecode(tostring(self.embeds[i]))
		end
	end
	
	local mentions = HTTP_SERV:JSONDecode(tostring(self.allowedMentions))
	if #mentions.parse > 0 or #mentions.users > 0 or #mentions.roles > 0 then
		data.allowed_mentions = mentions
	end
	
-- 	debug only
--	print(HTTP_SERV:JSONEncode(data))
	return HTTP_SERV:JSONEncode(data)
end

function message:Append(txt)
	assert(not self.sent, 'Cannot append data for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	local tmpMsg = self.content .. txt
	if #tmpMsg > 2000 then
		warn('Message body cannot exceed 2000 characters')
		return
	end
	
	self.content = tmpMsg
end

function message:AppendLine(txt)
	assert(not self.sent, 'Cannot append data for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	self:Append(txt .. '\n')
end

function message:SetUsername(username)
	assert(not self.sent, 'Cannot set username for message that has been sent')
	assert(typeof(username) == 'string', 'Argument 1 expected string but got ' .. typeof(username))
	assert(#username <= 80 and username ~= '', 'Username must be between 1 and 80 characters')
	
	self.username = username
end

function message:SetAvatarUrl(url)
	assert(not self.sent, 'Cannot set avatar url for message that has been sent')
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	
	self.avatar_url = url
end

function message:SetTTS(isTTS)
	assert(not self.sent, 'Cannot set text to speach for message that has been sent')
	assert(typeof(isTTS) == 'boolean', 'Argument 1 expected boolean but got ' .. typeof(isTTS))
	
	self.tts = isTTS
end

function message:Send()
	if not self.sent then
		self.sent = true
		self.allowedMentions.sent = true
		for _, embed in pairs(self.embeds) do
			embed.sent = true
			for _, field in pairs(embed.fields) do
				field.sent = true
			end
		end
		self.postHandler:QueueMessage(self)
	end
end

function message:NewEmbed()
	assert(not self.sent, 'Cannot add new embed for message that has been sent')
	assert(#self.embeds < 10, 'Cannot add more than 10 embeds to one message')
	
	local embed = embed.new()
	self.embeds[#self.embeds+1] = embed
	return embed
end

function message:CountEmbeds()
	return #self.embeds
end

function message:GetAllowedMention()
	return self.allowedMentions
end

function message:GetUid()
	return self.uid
end

function message.new(postHandler)
	
	local data = {
		uid = HTTP_SERV:GenerateGUID(false),
		postHandler = postHandler,
		sent = false,
		tts = false,
		avatar_url = '',
		username = '',
		content = '',
		embeds = {},
		allowedMentions = allowedMention.new()
	}
	
	return setmetatable(data, message)
end

return message
