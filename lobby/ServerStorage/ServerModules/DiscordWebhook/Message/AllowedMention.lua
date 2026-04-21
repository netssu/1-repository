local allowedMention = {}
local HTTP_SERV = game:GetService('HttpService')

allowedMention.__index = allowedMention
allowedMention.__newindex = function() error('Cannot add new index') end
allowedMention.__metatable = 'Meta table locked'
allowedMention.__tostring = function(self)
	return HTTP_SERV:JSONEncode({
		parse = self.parse,
		users = self.users,
		roles = self.roles
	})
end

local function addNonDuplicate(tbl, data)
	for i=1, #tbl do
		if tbl[i] == data then 
			return
		end
	end
	
	tbl[#tbl+1] = data
end

function allowedMention:AddGlobalMention(str)
	assert(not self.sent, 'Cannot add global mention for message that has been sent')
	assert(typeof(str) == 'string', 'Argument 1 expected string but got ' .. typeof(str))
	assert(str == 'roles' or str == 'users' or str == 'everyone', 'Unknown global mention ' .. str .. ' expected one of the following roles, users or everyone')
	
	addNonDuplicate(self.parse, str)
end

function allowedMention:AddUserId(id)
	assert(not self.sent, 'Cannot add user id for message that has been sent')
	assert(typeof(id) == 'number' and math.floor(id) == id, 'Argument 1 expected int but got ' .. typeof(id))
	assert(#self.users <= 100, 'Cannot exceed 100 user ids')
	
	addNonDuplicate(self.users, id)
end

function allowedMention:AddRoleId(id)
	assert(not self.sent, 'Cannot add role id for message that has been sent')
	assert(typeof(id) == 'number' and math.floor(id) == id, 'Argument 1 expected int but got ' .. typeof(id))
	assert(#self.roles <= 100, 'Cannot exceed 100 role ids')
	
	addNonDuplicate(self.roles, id)
end

function allowedMention.new()
	
	local data = {
		sent = false,
		parse = {},
		users = {},
		roles = {}
	}
	
	return setmetatable(data, allowedMention)
end

return allowedMention
