local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService('UserService')
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ClansFrame = script.Parent.Parent.Parent.ClansFrame.Internal
local HomeFrame = ClansFrame.Home

local NumberValueConvert = require(ReplicatedStorage.AceLib.NumberValueConvert)
local TimeConverter = require(ReplicatedStorage.AceLib.TimeConverter)
local ClanPermissions = require(ReplicatedStorage.ClansLib.ClanPermissions)
local PromptModule = require(script.Parent.Parent.PromptModule)
local ClanUpgradeCalculation = require(ReplicatedStorage.ClansLib.ClanUpgradeCalculation)
local ClanTags = require(ReplicatedStorage.ClansLib.ClanTags)
local ClanLevelCalculation = require(ReplicatedStorage.ClansLib.ClanLevelCalculation)
local ClanRemotes = ReplicatedStorage.Remotes.Clans
local SendMailbox = ClanRemotes.SendMailbox
local PromptFrame = ClansFrame.Parent.Prompt

local module = {}

local connections = {}
local managePlayerConnections = {}

function module.Init(clan: string)
	for i,v in connections do
		v:Disconnect()
		v = nil
	end

	local ClanData : Folder = ReplicatedStorage.Clans[clan]
	local LocalRank = ClanData.Members[Player.UserId].Rank
	
	local leaveConn = nil
	
	local function updateInviteButton()
		HomeFrame.BottomFrame.InviteButton.Visible = ClanPermissions.canInvite(LocalRank.Value)
	end
	
	updateInviteButton()
	local conn = LocalRank.Changed:Connect(updateInviteButton)
	table.insert(connections, conn)
	
	local conn = HomeFrame.BottomFrame.InviteButton.Activated:Connect(function()
		PromptModule.enablePrompt('Invite')
	end)
	table.insert(connections, conn)
	
	local conn = HomeFrame.BottomFrame.LeaveButton.Activated:Connect(function()
		PromptModule.enablePrompt('LeaveClan')
	end)
	table.insert(connections, conn)

	HomeFrame.MainFrame.ClanNameLabel.Text = `[{ClanData.Name}]`
	
	local function updateColor()
		local tagColor = ClanTags.Tags[ClanData['ActiveColor'].Value].Color
		if typeof(tagColor) ~= 'table' then
			HomeFrame.MainFrame.ClanNameLabel.TextColor3 = tagColor
			HomeFrame.MainFrame.ClanNameLabel.UIGradient.Color = script.UIGradient.Color
		else
			local keypoints = {}
			local count = #tagColor
			for i, color in ipairs(tagColor) do
				local position = (i - 1) / (count - 1)
				table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
			end
			local gradient = ColorSequence.new(keypoints)
			HomeFrame.MainFrame.ClanNameLabel.TextColor3 = Color3.fromRGB(255,255,255)
			HomeFrame.MainFrame.ClanNameLabel.UIGradient.Color = gradient
		end
	end
	
	updateColor()
	
	local conn = ClanData['ActiveColor'].Changed:Connect(updateColor)
	table.insert(connections, conn)
	
	HomeFrame.MainFrame.DescriptionLabel.Text = ClanData['Description'].Value
	
	local conn = ClanData['Description'].Changed:Connect(function()
		HomeFrame.MainFrame.DescriptionLabel.Text = ClanData['Description'].Value
	end)
	
	table.insert(connections, conn)
	
	-- clan level
	local XPVal = ClanData.Stats.XP
	local Emblem = ClanData.Emblem
	local function update()
		-- level text
		local clanLvl, xpIntoLevel = ClanLevelCalculation.getLevelFromXP(XPVal.Value)
		local xpNeeded = ClanLevelCalculation.getXPToNextLevel(clanLvl)
		HomeFrame.MainFrame.ClanLevelFrame.LevelLabel.Text = `LVL. {clanLvl}`
		
		--[[
		local level, xpIntoLevel = module.getLevelFromXP(totalXP)
		local xpNeeded = module.getXPToNextLevel(level)

		-- Show on UI:
		-- "XP: " .. xpIntoLevel .. " / " .. xpNeeded
		--]]
		task.spawn(function()
			local A = NumberValueConvert.convert(xpIntoLevel)
			local B = NumberValueConvert.convert(xpNeeded)
			HomeFrame.MainFrame.ClanLevelFrame.XpLabel.Text = `{A} / {B} XP`
			HomeFrame.MainFrame.ClanLevelFrame.FillFrame.Front.Size = UDim2.fromScale(tonumber(xpIntoLevel)/tonumber(xpNeeded), 1)
			HomeFrame.MainFrame.ClanImage.Image = `rbxassetid://{Emblem.Value}`
		end)
	end
	
	update()

	local conn1 = XPVal.Changed:Connect(update)
	local conn2 = Emblem.Changed:Connect(update)

	table.insert(connections, conn1)
	table.insert(connections, conn2)
	
	
	local MailBox = HomeFrame.MailboxFrame.TextboxHolder.TextBox

	
	-- local rank
	local function updateLocalRank()
		HomeFrame.MainFrame.LocalRankLabel.Text = LocalRank.Value
		HomeFrame.MainFrame.LocalRankLabel.BackgroundColor3 = ClanPermissions.Permissions[LocalRank.Value].Color
		
		-- Update Mailbox status
		if ClanPermissions.canPost(LocalRank.Value) then
			HomeFrame.MailboxFrame.TextboxHolder.SendButton.Active = true
			HomeFrame.MailboxFrame.TextboxHolder.SendButton.Active = true
			MailBox.Interactable = true
			MailBox.PlaceholderText = 'Post a message to the clan mail'
		else
			HomeFrame.MailboxFrame.TextboxHolder.SendButton.Active = false
			HomeFrame.MailboxFrame.TextboxHolder.SendButton.Visible = false
			MailBox.Interactable = false
			MailBox.PlaceholderText = 'Your clan rank is not high enough'
			MailBox.Text = ''
		end
		
		local canChangeEmblem = ClanPermissions.CanChangeEmblem(LocalRank.Value)
		local canChangeDesc = ClanPermissions.CanChangeDescription(LocalRank.Value)
		HomeFrame.MainFrame.EditButton.Visible = canChangeDesc or canChangeEmblem 
		
		local EditFrame = PromptFrame.EditClan
		
		EditFrame.MainFrame.ButtonsContainer.Description.Visible = canChangeDesc
		EditFrame.MainFrame.ButtonsContainer.Emblem.Visible = canChangeEmblem
	end
	
	updateLocalRank()
	
	local conn1 = LocalRank.Changed:Connect(updateLocalRank)
	table.insert(connections, conn1)
	
	
	-- MemberCount
	local ClanSlotLevel = ClanData.Upgrades.UpgradeSlotLevel
	local function updateMemberCount()
		local total = ClanData.Members:GetChildren()
		local cap = ClanUpgradeCalculation.getMemberCapFromLevel(ClanSlotLevel.Value)
		HomeFrame.MailboxFrame.MembersFrame.MemberLabel.Text = `{#total} / {cap}`
	end

	updateMemberCount()
	
	local conn1 = ClanData.Members.ChildAdded:Connect(updateMemberCount)
	table.insert(connections, conn1)

	local conn1 = ClanData.Members.ChildRemoved:Connect(updateMemberCount)
	table.insert(connections, conn1)
	
	local conn1 = ClanSlotLevel.Changed:Connect(updateMemberCount)
	table.insert(connections, conn1)
	
	
	-- Leaderboard Stats
	local function updateStats()
		for i,v in HomeFrame.ClanRankFrame:GetChildren() do
			if v:IsA('GuiBase2d') then
				local StatInfo = ClanData.Stats:FindFirstChild(v.Name)
				if StatInfo then
					v.Total.StatisticLabel.Text = NumberValueConvert.convert(StatInfo.Value)
				end
			end
		end
	end
	
	updateStats()
	
	for i,v in ClanData.Stats:GetChildren() do
		local conn = v.Changed:Connect(updateStats)
		table.insert(connections, conn)
	end
		
	-- Clan Inbox
	local MailScroll = HomeFrame.MailboxFrame.MailboxScrollingFrame
	
	for i,v:Frame in MailScroll:GetChildren() do
		if v:IsA('GuiBase2d') then
			v:Destroy() -- clear old mail from clans you have left/been kiciked from
		end
	end
	
	local function createClanMessage(msg, index)
		local Template = MailScroll.UIListLayout.MailboxTextTemplate:Clone()
		
		Template.LayoutOrder = index
		Template.Text = msg
		Template.Name = index
		
		Template.Parent = MailScroll
	end
	
	for i,v in ClanData.ChatBox:GetChildren() do
		createClanMessage(v.Message.Value, v.Index.Value)
	end
	
	local conn1 = ClanData.ChatBox.ChildAdded:Connect(function(v)
		createClanMessage(v.Message.Value, v.Index.Value)
	end)
	
	local conn2 = ClanData.ChatBox.ChildRemoved:Connect(function(v)
		local foundLine = MailScroll:FindFirstChild(v.Index.Value)
		if foundLine then
			foundLine:Destroy()
		end
	end)
	
	table.insert(connections, conn1)
	table.insert(connections, conn2)
	
	-- Modify clan
	local conn1 = HomeFrame.MainFrame.EditButton.Activated:Connect(function()
		PromptModule.enablePrompt('EditClan')
	end)
	table.insert(connections, conn1)
end


return module
