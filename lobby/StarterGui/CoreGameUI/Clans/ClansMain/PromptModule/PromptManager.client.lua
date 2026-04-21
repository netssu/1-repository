local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PromptFrame = script.Parent.Parent.Parent.ClansFrame.Prompt
local PromptModule = require(script.Parent)
local ClanRemotes = ReplicatedStorage.Remotes.Clans
local Player = Players.LocalPlayer
local StringManipulation = require(ReplicatedStorage.AceLib.StringManipulation)
local NumberValueConvert = require(ReplicatedStorage.AceLib.NumberValueConvert)


repeat task.wait() until Player:FindFirstChild('CurrentClanLoaded')
local CurrentClan = Player.ClanData.CurrentClan
local InstancedClan = ReplicatedStorage.Clans:FindFirstChild(CurrentClan.Value)
local ContributedConnection = nil

local function updateRankConnection()
	InstancedClan = ReplicatedStorage.Clans:FindFirstChild(CurrentClan.Value)
	if ContributedConnection then
		ContributedConnection:Disconnect()
		ContributedConnection = nil
	end
	
	if InstancedClan then
		repeat task.wait() until InstancedClan:FindFirstChild('Loaded')
		
		local foundMember = InstancedClan.Members:FindFirstChild(Player.UserId)
		if foundMember then
			ContributedConnection = foundMember.Contributions.Vault.Changed:Connect(function()
				PromptFrame.Parent.Internal.Vault.BottomFrame.ContributionLabel.Text = NumberValueConvert.convert(foundMember.Contributions.Vault.Value)
			end)
			PromptFrame.Parent.Internal.Vault.BottomFrame.ContributionLabel.Text = NumberValueConvert.convert(foundMember.Contributions.Vault.Value)

			script.LocalRank.Value = foundMember.Rank.Value
			
			foundMember.Rank.Changed:Connect(function()
				script.LocalRank.Value = foundMember.Rank.Value
			end)
		end
	end
end

updateRankConnection()
CurrentClan.Changed:Connect(updateRankConnection)


local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end

local inactiveBG = Color3.fromRGB(50,50,50)
local inactiveText = Color3.fromRGB(125,125,125)

local activeBG = Color3.fromRGB(95, 255, 87)
local activeText = Color3.fromRGB(0,50,0)

local ttime = 0.2

-- Invite Frame
local InviteFrame = PromptFrame.Invite

InviteFrame.Close.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

local function safeToInvite(plr)
	if plr:FindFirstChild('DataLoaded') and plr:FindFirstChild('ClansLoaded') then
		return plr.ClanData.CurrentClan.Value == 'None'		
	end
end

InviteFrame.TextBox.Changed:Connect(function()
	local foundPlr = Players:FindFirstChild(InviteFrame.TextBox.Text)
	
	if foundPlr and safeToInvite(foundPlr) then
		tween(InviteFrame.Invite, ttime, {BackgroundColor3 = activeBG, TextColor3 = activeText})
	else
		tween(InviteFrame.Invite, ttime, {BackgroundColor3 = inactiveBG, TextColor3 = inactiveText})
	end
end)

InviteFrame.Invite.Activated:Connect(function()
	local foundPlr = Players:FindFirstChild(InviteFrame.TextBox.Text)
	if foundPlr and safeToInvite(foundPlr) then
		local result = ClanRemotes.InvitePlayer:InvokeServer(foundPlr.Name)
		_G.Message(result)
	end
	tween(InviteFrame.Invite, ttime, {BackgroundColor3 = inactiveBG, TextColor3 = inactiveText})
end)

InviteFrame.CloseTop.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

-- Leave Frame
local LeaveFrame = PromptFrame.LeaveClan

LeaveFrame.Deny.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

LeaveFrame.Confirm.Activated:Connect(function()
	PromptModule.disablePrompt()
	PromptModule.enablePrompt('Loading')
	ClanRemotes.LeaveClan:InvokeServer()
	PromptModule.disablePrompt()
end)

LeaveFrame.CloseTop.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

-- Modify Clan Frame
local ModifyClan = PromptFrame.EditClan

ModifyClan.Close.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

ModifyClan.CloseTop.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

local prev = nil
local function activateFrame(arg)
	if arg and arg == prev then return end

	if prev then
		ModifyClan[prev].Visible = false
	end
	
	if arg then
		ModifyClan.MainFrame.Visible = false
		ModifyClan[arg].Visible = true
	else
		ModifyClan.MainFrame.Visible = true
	end
	
	prev = arg
end

for i,v in ModifyClan.MainFrame.ButtonsContainer:GetChildren() do
	if v:IsA('GuiBase2d') then
		v.Activated:Connect(function()
			activateFrame(v.Name)
		end)
	end
end

ModifyClan:GetPropertyChangedSignal('Visible'):Connect(function()
	if ModifyClan.Visible then
		activateFrame()
	end
end)

local ClanDescriptionInput = ModifyClan.Description.TextBox
local ClanEmblemInput = ModifyClan.Emblem.TextBox

ModifyClan.Description.Confirm.Activated:Connect(function()
	PromptModule.disablePrompt()
	PromptModule.enablePrompt('Loading')
	
	local success = ClanRemotes.EditClan:InvokeServer('Description', ClanDescriptionInput.Text)
	ClanDescriptionInput.Text = ''
	if not success or success ~= 'Success' then _G.Message(success) end
	
	PromptModule.disablePrompt()
end)

ModifyClan.Emblem.Confirm.Activated:Connect(function()
	PromptModule.disablePrompt()
	PromptModule.enablePrompt('Loading')

	local success = ClanRemotes.EditClan:InvokeServer('Emblem', ClanEmblemInput.Text)
	ClanEmblemInput.Text = ''
	if not success or success ~= 'Success' then _G.Message(success) end

	PromptModule.disablePrompt()
end)

ClanDescriptionInput:GetPropertyChangedSignal('Text'):Connect(function()
	ClanDescriptionInput.Text = StringManipulation.truncateToCharacterLength(ClanDescriptionInput.Text, 75)
	ClanDescriptionInput.Parent.CharacterLength.Text = #ClanDescriptionInput.Text

	if #ClanDescriptionInput.Text == 75 then
		ClanDescriptionInput.Parent.CharacterLength.TextColor3 = Color3.fromRGB(255,0,0)
	else
		ClanDescriptionInput.Parent.CharacterLength.TextColor3 = Color3.fromRGB(255,255,255)
	end
	
	if #ClanDescriptionInput.Text ~= 0 then
		tween(ClanDescriptionInput.Parent.Confirm, ttime, {BackgroundColor3 = activeBG, TextColor3 = activeText})
	else
		tween(ClanDescriptionInput.Parent.Confirm, ttime, {BackgroundColor3 = inactiveBG, TextColor3 = inactiveText})
	end
end)

ClanEmblemInput:GetPropertyChangedSignal('Text'):Connect(function()
	-- Numbers only
	local filtered = StringManipulation.truncateToCharacterLength(StringManipulation.stringToNumbers(ClanEmblemInput.Text), 75)

	if tostring(filtered) ~= tostring(ClanEmblemInput.Text) then
		ClanEmblemInput.Text = filtered
	end
	
	if #ClanEmblemInput.Text ~= 0 then
		tween(ClanEmblemInput.Parent.Confirm, ttime, {BackgroundColor3 = activeBG, TextColor3 = activeText})
	else
		tween(ClanEmblemInput.Parent.Confirm, ttime, {BackgroundColor3 = inactiveBG, TextColor3 = inactiveText})
	end
end)


-- Donate Gems
local VaultFrame = PromptFrame.Parent.Internal.Vault
local DonateFrame = PromptFrame.DonateGems
local DonateBox = DonateFrame.MainFrame.TextBox
local DonateConfirm = DonateFrame.MainFrame.Confirm

DonateFrame.Close.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

DonateFrame.CloseTop.Activated:Connect(function()
	PromptModule.disablePrompt()
end)

DonateBox:GetPropertyChangedSignal('Text'):Connect(function()
	if DonateBox.Text == '' then return end
	
	local filtered = StringManipulation.stringToNumbers(DonateBox.Text)
	if not tonumber(filtered) then DonateBox.Text = '' return end
	if Player.Gems.Value < tonumber(filtered) then
		filtered = Player.Gems.Value 
	end 

	if filtered ~= DonateBox.Text then
		DonateBox.Text = filtered
	end
	
	if #tostring(filtered) ~= 0 then
		DonateConfirm.Active = true
		tween(DonateConfirm, ttime, {BackgroundColor3 = activeBG, TextColor3 = activeText})
	else
		DonateConfirm.Active = false
		tween(DonateConfirm, ttime, {BackgroundColor3 = inactiveBG, TextColor3 = inactiveText})
	end
end)

DonateConfirm.Activated:Connect(function()
	if DonateBox.Text ~= '' then
		PromptModule.disablePrompt()
		PromptModule.enablePrompt('Loading')
		local result = ClanRemotes.DonateVault:InvokeServer(DonateBox.Text)
		_G.Message(result)
		
		DonateBox.Text = ''
		PromptModule.disablePrompt()
	end
end)


VaultFrame.BottomFrame.AddCurrencyButton.Activated:Connect(function()
	PromptModule.enablePrompt('DonateGems')
end)