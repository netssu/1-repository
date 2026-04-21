local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClanRemotes = ReplicatedStorage.Remotes.Clans
local SendMail = ClanRemotes.SendMailbox
local ClansFrame = script.Parent.Parent.ClansFrame.Internal
local Mailbox = ClansFrame.Home.MailboxFrame
local StringManipulation = require(ReplicatedStorage.AceLib.StringManipulation)

local module = {}

local InputBox = Mailbox.TextboxHolder.TextBox
local SendButton = Mailbox.TextboxHolder.SendButton

local PromptModule = require(script.Parent.PromptModule)

SendButton.Activated:Connect(function()
	if InputBox.Text ~= '' then
		PromptModule.enablePrompt('Loading')
		local savedText = InputBox.Text
		InputBox.Text = ''
		local success = SendMail:InvokeServer(savedText)
		PromptModule.disablePrompt()
		
		if not success then
			_G.Message('An error occurred')
		end
	end
end)

InputBox.Changed:Connect(function()
	local newString = StringManipulation.truncateToCharacterLength(StringManipulation.cleanString(InputBox.Text, true),100)
	
	if newString ~= InputBox.Text then
		InputBox.Text = newString
	end
end)



return module
