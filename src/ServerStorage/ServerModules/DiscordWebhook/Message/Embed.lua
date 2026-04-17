local embed = {}
local field = require(script.Field)
local HTTP_SERV = game:GetService('HttpService')

embed.__index = embed
embed.__newindex = function() error('Cannot add new index') end
embed.__metatable = 'Meta table locked'
embed.__tostring = function(self)
	local data = {}
	
	data.type = self.type
	
	if self.title ~= '' then
		data.title = self.title
	end
	
	if self.description ~= '' then
		data.description = self.description
	end
	
	if data.color ~= 0 then
		data.color = self.color
	end
	
	if self.url ~= '' then
		data.url = self.url
	end
	
	if self.timestamp ~= 0 then
		data.timestamp = self.timestamp
	end
	
	if self.footer.text ~= '' or self.footer.icon_url ~= '' then
		data.footer = {
			text = self.footer.text,
			icon_url = self.footer.icon_url
		}
	end
	
	if self.imgUrl ~= '' then
		data.image = {
			url = self.imgUrl
		}
	end
	
	if self.thumbnailIconUrl ~= '' then
		data.thumbnail = {
			url = self.thumbnailIconUrl
		}
	end
	
	if self.author.name ~= '' then
		data.author = {
			name = self.author.name,
			url = self.author.url,
			icon_url = self.author.iconUrl
		}
	end
	
	-- JSONEncode does not seem to call the tostring metatable correctly
	-- this is just a workaround
	if #self.fields > 0 then
		data.fields = {}
		for i=1, #self.fields do
			data.fields[i] = HTTP_SERV:JSONDecode(tostring(self.fields[i]))
		end
	end
	
-- 	debug only
--	print(HTTP_SERV:JSONEncode(data))
	return HTTP_SERV:JSONEncode(data)
end

function embed:SetTitle(title)
	assert(not self.sent, 'Cannot set title for message that has been sent')
	assert(typeof(title) == 'string', 'Argument 1 expected string but got ' .. typeof(title))
	
	if #title > 256 then
		warn('Title cannot exceed 256 characters')
		return
	end 
	
	self.title = title
end

function embed:Append(txt)
	assert(not self.sent, 'Cannot append for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	local tmpDesc = self.description .. txt
	if #tmpDesc > 2048 then
		warn('Append description cannot exceed 2048 characters')
		return
	end
	
	self.description = tmpDesc
end

function embed:AppendLine(txt)
	assert(not self.sent, 'Cannot append line for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	self:Append(txt .. '\n')
end

function embed:SetURL(url)
	assert(not self.sent, 'Cannot set url for message that has been sent')
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	
	self.url = url
end

function embed:SetTimestamp(epoch)
	assert(not self.sent, 'Cannot set timestamp for message that has been sent')
	
	if epoch == nil then epoch = tick() end
	
	assert(typeof(epoch) == 'number', 'Argument 1 expected int but got ' .. typeof(epoch))
	
	local tmpData = os.date('!*t', epoch)
	
	self.timestamp = 
		tmpData.year .. '-' 
		.. string.format("%02d",tmpData.month) .. '-'
		.. string.format("%02d",tmpData.day) .. 'T'
		.. string.format("%02d",tmpData.hour) .. ':'
		.. string.format("%02d",tmpData.min) .. ':'
		.. string.format("%02d",tmpData.sec) .. 'Z'
end

function embed:SetColor3(color3)
	assert(not self.sent, 'Cannot set color3 for message that has been sent')
	assert(typeof(color3) == 'Color3', 'Argument 1 expected color3 but got ' .. typeof(color3))
	
	local val = bit32.lshift(math.floor(color3.r * 255 + 0.5), 8)
	val = bit32.lshift(math.floor(color3.g * 255 + 0.5) + val, 8)
	val = val + math.floor(color3.b * 255 + 0.5)
	
	self.color = val
end

function embed:AppendFooter(txt)
	assert(not self.sent, 'Cannot append footer for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	local tmpDesc = self.footer.text .. txt
	if #tmpDesc > 2048 then
		warn('Append footer cannot exceed 2048 characters')
		return
	end
	
	self.footer.text = tmpDesc
end

function embed:AppendFooterLine(txt)
	assert(not self.sent, 'Cannot append footer line for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	self:AppendFooter(txt .. '\n')
end

function embed:SetFooterIconURL(url)
	assert(not self.sent, 'Cannot set footer icon url for message that has been sent')
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	
	self.footer.icon_url = url
end

function embed:SetImageURL(url)
	assert(not self.sent, 'Cannot set image url for message that has been sent')
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	
	self.imgUrl = url
end

function embed:SetThumbnailIconURL(url)
	assert(not self.sent, 'Cannot set thumbnail icon url for message that has been sent')
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	
	self.thumbnailIconUrl = url
end

function embed:SetAuthorName(name)
	assert(not self.sent, 'Cannot set author name for message that has been sent')
	assert(typeof(name) == 'string', 'Argument 1 expected string but got ' .. typeof(name))
	
	if #name > 256 then
		warn('Author name cannot exceed 256 characters')
	end 
	
	self.author.name = name
end

function embed:SetAuthorURL(url)
	assert(not self.sent, 'Cannot author url for message that has been sent')
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	
	self.author.url = url
end

function embed:SetAuthorIconURL(url)
	assert(not self.sent, 'Cannot set author icon url for message that has been sent')
	assert(typeof(url) == 'string', 'Argument 1 expected string but got ' .. typeof(url))
	assert(url:match('^https?://') ~= nil, 'Invalid url format passed')
	
	self.author.iconUrl = url
end

function embed:NewField()
	assert(not self.sent, 'Cannot add new field for message that has been sent')
	assert(#self.fields < 25, 'Cannot add more than 25 fields')
	
	local field = field.new()
	self.fields[#self.fields+1] = field
	return field
end

function embed:CountFields()
	return #self.fields
end

function embed.new()
	
	local data = {
		sent = false,
		type = 'rich',
		title = '',
		description = '',
		url = '',
		timestamp = 0,
		color = 0,
		footer = {text = '', icon_url = ''},
		imgUrl = '', -- webhooks cannot sed width or height
		thumbnailIconUrl = '', -- webhooks cannot sed width or height
		author = {name = '', url = '', iconUrl = ''},
		fields = {}
	}
	
	return setmetatable(data, embed)
end

return embed
