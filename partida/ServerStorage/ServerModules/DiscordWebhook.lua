--[[
	
	Discord Webhook module
	Version:- 1.0
	
	------------ DiscordWebhook ------------
	https://discordapp.com/api/webhooks/[id]/[token]
	webhook DiscordWebhook.new(string webhookId, string webhookToken)
	PostHandler webhook:GetPostHandler()
	Message webhook:NewMessage()
	FormatHelper webhook:GetFromatHelper()
	---------------------------------------
	
	------------- PostHandler -------------
	void PostHandler:QueueMessage() -- mainly for internal use
	void PostHandler:Resume()
	void PostHandler:Pause()
	void PostHandler:SuccessCallback(function successCallback)
	void PostHandler:FailedCallback(function failedCallback)
	---------------------------------------
	
	--------------- Message ---------------
	void Messahge:Send()
	void Message:Append(string txt)
	void Message:AppendLine(string txt)
	void Message:SetUsername(string txt)
	void Message:SetAvatarUrl(string url)
	void Message:SetTTS(boolean isTTS)
	string Message:GetUid()
	int Message:CountEmbeds()
	AllowedMention Message:GetAllowedMention()
	Embed Message:NewEmbed()
	----------------------------------------

	----------- AllowedMention -------------
	void AllowedMention:AddGlobalMention(string [roles, users, everyone])
	void AllowedMention:AddUserId(int id)
	void AllowedMention:AddRoleId(int id)
	----------------------------------------
	
	--------------- Embed ------------------
	void Embed:SetTitle(string title)
	void Embed:Append(string txt)
	void Embed:AppendLine(string txt)
	void Embed:SetURL(string url)
	void Embed:SetTimestamp([number epoch])
	void Embed:SetColor3(Color3 color3)
	void Embed:AppendFooter(string txt)
	void Embed:AppendFooterLine(string txt)
	void Embed:SetFooterIconURL(string url)
	void Embed:SetImageURL(string url)
	void Embed:SetThumbnailIconURL(string url)
	void Embed:SetAuthorName(string name)
	void Embed:SetAuthorURL(string url)
	void Embed:SetAuthorIconURL(string url)
	int  Embed:CountFields()
	Field Embed:NewField()
	----------------------------------------
	
	--------------- Field ------------------
	void Field:SetName(string name)
	void Field:Append(string txt)
	void Field:AppendLine(string txt)
	void Field:SetIsInline(boolean isInline)
	----------------------------------------
	
	------------- FormatHelper -------------
	string FormatHelper:Italic(string txt)
	string FormatHelper:Bold(string txt)
	string FormatHelper:BoldItalic(string txt)
	string FormatHelper:Underline(string txt)
	string FormatHelper:UnderlineItalic(string txt)
	string FormatHelper:UnderlineBold(string txt)
	string FormatHelper:UnderlineBoldItalic(string txt)
	string FormatHelper:Strikethrough(string txt)
	string FormatHelper:CodeblockLine(string txt)
	string FormatHelper:Codeblock(string txt, [string syntax])
	string FormatHelper:BlockQuote(string txt)
	string FormatHelper:MultiLineBlockQuote(string txt)
	string FormatHelper:Spoiler(string txt)
	string FormatHelper:URL(string url, [string txt]) 
	---------------------------------------
]]

local discordWebhook = {}
discordWebhook.__index = discordWebhook
discordWebhook.__newindex = function() error('Cannot add new index') end
discordWebhook.__metatable = 'Meta table locked'

local postHandler = require(script.PostHandler)
local message = require(script.Message)
local formatHelper = require(script.FormatHelper)

function discordWebhook:GetPostHandler()
	return self.postHandler
end

function discordWebhook:GetFromatHelper()
	return formatHelper
end

function discordWebhook:NewMessage()
	return message.new(self:GetPostHandler())
end

local DiscordChannels = {
	PurchaseLog = {
		webhookId = "1277780184447324221",
		webhookToken = "zcNWBCY_ctF3NCWemUVjXDeMc-I1sDpIWTIbAC5_rzlcPfVNzBsG02mdp7gG3C-fkxSf"
	},
	Summon = {
		webhookId = "1277719532152295494",
		webhookToken = "KBUucNFI4AJAm1_dxxovNZ65yCm_CoDbtZa34g3J14FE0VkpIc_YDmXG29mKGG31Y3BH"
	}
}

function discordWebhook.new(ChannelName)
	local channel = DiscordChannels[ChannelName]
	print(ChannelName, channel)
	--assert(channel ~= nil, "ChannelName has no valid channel")
	local webhookId, webHookToken = channel.webhookId, channel.webhookToken
	assert(typeof(webhookId) == 'string', 'Argument 1 expected string but got ' .. typeof(webhookId))
	assert(typeof(webHookToken) == 'string', 'Argument 2 expected string but got ' .. typeof(webHookToken))
	print(webhookId, webHookToken)
	local data = {
		postHandler = postHandler.new(webhookId, webHookToken)
	}
	print(data)
	return setmetatable(data, discordWebhook)
end

return discordWebhook