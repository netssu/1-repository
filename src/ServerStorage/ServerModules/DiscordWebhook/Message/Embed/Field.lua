local field = {}
local HTTP_SERV = game:GetService('HttpService')

field.__index = field
field.__newindex = function() error('Cannot add new index') end
field.__metatable = 'Meta table locked'
field.__tostring = function(self)
	return HTTP_SERV:JSONEncode({
		name = self.name,
		value = self.value,
		inline = self.inline
	})
end

function field:SetName(name)
	assert(not self.sent, 'Cannot set name for message that has been sent')
	assert(typeof(name) == 'string', 'Argument 1 expected string but got ' .. typeof(name))
	
	if #name > 256 then
		warn('Name must not exceed 256 characters')
		return
	end 
	
	self.name = name
end

function field:Append(txt)
	assert(not self.sent, 'Cannot append for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	local tmpVal = self.value .. txt
	if #tmpVal > 1024 then
		warn('Field content cannot exceed 1024 characters')
		return
	end 
	
	self.value = tmpVal
end

function field:AppendLine(txt)
	assert(not self.sent, 'Cannot append line for message that has been sent')
	assert(typeof(txt) == 'string', 'Argument 1 expected string but got ' .. typeof(txt))
	
	self:Append(txt .. '\n')
end

function field:SetIsInline(isInline)
	assert(not self.sent, 'Cannot set is inline for message that has been sent')
	assert(typeof(isInline) == 'boolean', 'Argument 1 expected string but got ' .. typeof(isInline))
	
	self.inline = isInline
end

function field.new()
	
	local data = {
		name = '',
		value = '',
		inline = false,
		sent = false
	}
	
	return setmetatable(data, field)
end

return field
