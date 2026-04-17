local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService('UserService')
local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ClansFrame = script.Parent.Parent.Parent.ClansFrame.Internal
local MembersFrame = ClansFrame.Members

local NumberValueConvert = require(ReplicatedStorage.AceLib.NumberValueConvert)
local TimeConverter = require(ReplicatedStorage.AceLib.TimeConverter)
local ClanPermissions = require(ReplicatedStorage.ClansLib.ClanPermissions)
local PromptModule = require(script.Parent.Parent.PromptModule)
local ClanUpgradeCalculation = require(ReplicatedStorage.ClansLib.ClanUpgradeCalculation)

local module = {}

local connections = {}
local managePlayerConnections = {}

local DataTable = {}
local IDs = {}

local ClanData = nil

function module.refreshClanMemberInfo()
	if ClanData then
		for i,v in ClanData.Members:GetChildren() do
			table.insert(IDs, tonumber(v.Name))
		end
		
		local success, result = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(IDs)
		end)
		
		if success and result and #result > 0 then
			local userInfo = result[1]
			--print("Username:", userInfo.Username)
			--print("DisplayName:", userInfo.DisplayName)
			userInfo.Thumbnail = nil
			local thumbSuccess, thumbnailUrl = pcall(function()
				return Players:GetUserThumbnailAsync(userInfo.Id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			end)
			userInfo.Thumbnail = thumbnailUrl or nil

			DataTable[userInfo.Id] = userInfo
		else
			print('Error getting IDs: - LITCH AN ERROR!')
			warn(success)
			warn(result)
		end
	else
		print('Clearing up member list')
	end
end

function module.Init(clan: string)
	for i,v in connections do
		v:Disconnect()
		v = nil
	end
	
	DataTable = {}
	IDs = {}

	for i,v in managePlayerConnections do
		v:Disconnect()
		v = nil
	end

	connections = {}
	managePlayerConnections = {}

	-- clan loaded
	-- Load Members
	ClanData = ReplicatedStorage.Clans[clan] :: Folder

	

	
	
	local success, result = nil

	

	for i,v in MembersFrame.ScrollingFrame:GetChildren() do
		if v:IsA('GuiBase2d') then
			v:Destroy()
		end
	end

	local LocalRank = ClanData.Members[Player.UserId].Rank
	local conn = LocalRank.Changed:Connect(function()
		for i,v in managePlayerConnections do
			v:Disconnect()
			v = nil
		end

		for i,v in MembersFrame.ScrollingFrame:GetChildren() do
			if v:IsA('GuiBase2d') then
				local rank = v.RankLabel.Text

				-- Can Promote
				v.ButtonsContainer.Promote.Visible = ClanPermissions.canPromote(LocalRank.Value, rank)
				v.ButtonsContainer.Demote.Visible = ClanPermissions.canDemote(LocalRank.Value, rank)
				v.ButtonsContainer.Kick.Visible = ClanPermissions.CanKick(LocalRank.Value, rank)
			end
		end
		
		MembersFrame.BottomFrame.InviteButton.Visible = ClanPermissions.canInvite(LocalRank.Value)
	end)

	MembersFrame.BottomFrame.InviteButton.Visible = ClanPermissions.canInvite(LocalRank.Value)

	local function newMemberCard(v: Folder)
		local Template = MembersFrame.ScrollingFrame.UIListLayout._TemplateMemberFrame:Clone()

		Template.Gems.Text = NumberValueConvert.convert(v.Contributions.Vault.Value)
		Template.Kills.Text = NumberValueConvert.convert(v.Contributions.Kills.Value)
		Template.XP.Text = NumberValueConvert.convert(v.Contributions.XP.Value)
		
		for i,poop in v.Contributions:GetChildren() do
			local conn = poop.Changed:Connect(function()
				Template.Gems.Text = NumberValueConvert.convert(v.Contributions.Vault.Value)
				Template.Kills.Text = NumberValueConvert.convert(v.Contributions.Kills.Value)
				Template.XP.Text = NumberValueConvert.convert(v.Contributions.XP.Value)
			end)
			
			table.insert(connections, conn)
		end
		

		local UserInformation = DataTable[tonumber(v.Name)]
		
		local foundUser = '(Failed To Load)'
		
		if UserInformation or v:FindFirstChild('Username') then
			if not UserInformation then
				-- save to assume they have a username card
				UserInformation = {
					Username = v.Username.Value,
					DisplayName = v.DisplayName.Value
				}
			end
			
			foundUser = UserInformation.Username
			if UserInformation.Username ~= UserInformation.DisplayName then
				Template.UsernameLabel.Text = `@{UserInformation.Username} ({UserInformation.DisplayName})`
			else
				Template.UsernameLabel.Text = `@{UserInformation.Username}`
			end
		else
			Template.UsernameLabel.Text = 'Failed to load'
		end

		Template.RankLabel.Text = v.Rank.Value
		Template.RankLabel.BackgroundColor3 = ClanPermissions.Permissions[v.Rank.Value].Color

		Template.PlayerImage.Image = (UserInformation and UserInformation.Thumbnail) or ''

		Template.LayoutOrder = ClanPermissions.Permissions[v.Rank.Value].Index
		Template.Name = v.Name
		Template.Parent = MembersFrame.ScrollingFrame

		-- Handle Promoting/Demoting lol
		Template.ButtonsContainer.Promote.Visible = ClanPermissions.canPromote(LocalRank.Value, v.Rank.Value)
		Template.ButtonsContainer.Demote.Visible = ClanPermissions.canDemote(LocalRank.Value, v.Rank.Value)
		Template.ButtonsContainer.Kick.Visible = ClanPermissions.CanKick(LocalRank.Value, v.Rank.Value)
		
	

		Template.ButtonsContainer.Promote.Activated:Connect(function()
			local targetRank = ClanPermissions.GetPromotedTo(Template.RankLabel.Text)
			PromptModule.enablePrompt('Confirmation', 'Promote', Template.Name, foundUser, targetRank)
		end)

		Template.ButtonsContainer.Demote.Activated:Connect(function()
			local targetRank = ClanPermissions.GetDemotedTo(Template.RankLabel.Text)
			PromptModule.enablePrompt('Confirmation', 'Demote', Template.Name, foundUser, targetRank)
		end)

		Template.ButtonsContainer.Kick.Activated:Connect(function()
			PromptModule.enablePrompt('Confirmation', 'Kick', Template.Name, foundUser)
		end)
		
		v:GetPropertyChangedSignal('Parent'):Connect(function()
			if not v.Parent then
				Template:Destroy()
			end
		end)
		
		v.Rank.Changed:Connect(function()
			Template.RankLabel.Text = v.Rank.Value
			Template.RankLabel.BackgroundColor3 = ClanPermissions.Permissions[v.Rank.Value].Color
			Template.LayoutOrder = ClanPermissions.Permissions[v.Rank.Value].Index
			
			Template.ButtonsContainer.Promote.Visible = ClanPermissions.canPromote(LocalRank.Value, v.Rank.Value)
			Template.ButtonsContainer.Demote.Visible = ClanPermissions.canDemote(LocalRank.Value, v.Rank.Value)
			Template.ButtonsContainer.Kick.Visible = ClanPermissions.CanKick(LocalRank.Value, v.Rank.Value)
		end)
	end

	for i,v in ClanData.Members:GetChildren() do
		newMemberCard(v)
	end

	local conn = ClanData.Members.ChildRemoved:Connect(function(plr)
		local found = MembersFrame.ScrollingFrame:FindFirstChild(plr.name)

		if found then
			found:Destroy()
		end
	end)

	local conn2 = ClanData.Members.ChildAdded:Connect(function(plr)
		newMemberCard(plr)
	end)

	table.insert(connections, conn)
	table.insert(connections, conn2)

	MembersFrame.BottomFrame.InviteButton.Activated:Connect(function()
		PromptModule.enablePrompt('Invite')
	end)
	
	local ClanSlotLevel = ClanData.Upgrades.UpgradeSlotLevel
	
	local function updateMemberCount()
		local total = ClanData.Members:GetChildren()
		local cap = ClanUpgradeCalculation.getMemberCapFromLevel(ClanSlotLevel.Value)
		MembersFrame.BottomFrame.MembersFrame.MemberLabel.Text = `Members: {#total} / {cap}`
	end
	
	updateMemberCount()
	
	local conn1 = ClanData.Members.ChildAdded:Connect(updateMemberCount)
	local conn2 = ClanData.Members.ChildRemoved:Connect(updateMemberCount)
	local conn3 = ClanSlotLevel.Changed:Connect(updateMemberCount)
	
	table.insert(connections, conn1)
	table.insert(connections, conn2)
	table.insert(connections, conn3)
	
	
	--[[
	Members = {
		--[[
		Example:
	
		['x_x6n'] = {
			Rank = 'Emperor',
			Contributions = {
				Kills = 0,
				Vault = 0,
				XP = 0,
			}
		}
		--]]
	--},
	--]]
end


return module
