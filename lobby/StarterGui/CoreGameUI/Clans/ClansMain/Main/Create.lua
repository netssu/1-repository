local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StringManipulation = require(ReplicatedStorage.AceLib.StringManipulation)
local Remotes = ReplicatedStorage.Remotes
local ClanRemotes = Remotes.Clans
local ClansFrame = script.Parent.Parent.Parent.ClansFrame
local Internal = ClansFrame.Internal
local CategorySwitcher = require(script.Parent.Parent.CategorySwitcher)

local PromptModule = require(script.Parent.Parent.PromptModule)

local module = {}

-- Filters
local InternalContainer = Internal['Create'].LeftContainer.Container

local ClanDescriptionInput = InternalContainer.ClanDescription.InputBox
local ClanEmblemInput = InternalContainer.ClanEmblem.InputBox
local ClanNameInput = InternalContainer.ClanName.InputBox

ClanDescriptionInput:GetPropertyChangedSignal('Text'):Connect(function()
	 -- 75 Characteres Maximum
	 -- Uppercase
	ClanDescriptionInput.Text = StringManipulation.truncateToCharacterLength(ClanDescriptionInput.Text, 75)
	ClanDescriptionInput.Parent.CharacterLength.Text = #ClanDescriptionInput.Text
	
	if #ClanDescriptionInput.Text == 75 then
		ClanDescriptionInput.Parent.CharacterLength.TextColor3 = Color3.fromRGB(255,0,0)
	else
		ClanDescriptionInput.Parent.CharacterLength.TextColor3 = Color3.fromRGB(255,255,255)
	end
end)

ClanEmblemInput:GetPropertyChangedSignal('Text'):Connect(function()
	-- Numbers only
	local filtered = StringManipulation.truncateToCharacterLength(StringManipulation.stringToNumbers(ClanEmblemInput.Text), 75)
	
	if tostring(filtered) ~= tostring(ClanEmblemInput.Text) then
		--print('FILTERING')
		ClanEmblemInput.Text = filtered
	end
end)

ClanNameInput:GetPropertyChangedSignal('Text'):Connect(function()
	-- 14 Characters Maximum
	-- Uppercase
	local filtered = StringManipulation.cleanString(string.upper(StringManipulation.truncateToCharacterLength(ClanNameInput.Text, 14)))

	ClanNameInput.Text = filtered	
	ClanNameInput.Parent.CharacterLength.Text = #ClanNameInput.Text
	
	if #filtered < 3 or #filtered == 14 then
		ClanNameInput.Parent.CharacterLength.TextColor3 = Color3.fromRGB(255,0,0)
	else
		ClanNameInput.Parent.CharacterLength.TextColor3 = Color3.fromRGB(255,255,255)
	end
end)



-- Button Events
Internal.Create.LeftContainer.CreateGems.Activated:Connect(function()
	PromptModule.enablePrompt('Loading')
	-- plr, clanName, clanDescription, clanEmblem, method
	-- Gems, Token
	local Result = ClanRemotes.CreateClan:InvokeServer(ClanNameInput.Text, ClanDescriptionInput.Text, ClanEmblemInput.Text, "Gems")

	if Result == 'Success' then
		print("Successfully created the clan")
		-- Load Frame
		CategorySwitcher.generateSideButtons({'Home', 'Members', 'Vault', 'Leaderboards'})
		PromptModule.disablePrompt()
	else
		_G.Message(Result, Color3.fromRGB(255,0,0))
		PromptModule.disablePrompt()
	end
end)

Internal.Create.LeftContainer.CreateRobux.Activated:Connect(function()
	PromptModule.enablePrompt('Loading')
	-- plr, clanName, clanDescription, clanEmblem, method
	-- Gems, Token
	local Result = ClanRemotes.CreateClan:InvokeServer(ClanNameInput.Text, ClanDescriptionInput.Text, ClanEmblemInput.Text, "Token")
	
	if Result == 'Success' then
		print("Successfully created the clan")
		-- Load Frame
		CategorySwitcher.generateSideButtons({'Home', 'Members', 'Vault', 'Leaderboards'})
		
		PromptModule.disablePrompt()
	else
		_G.Message(Result, Color3.fromRGB(255,0,0))
		PromptModule.disablePrompt()
	end
end)


return module