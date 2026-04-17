local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClansFrame = script.Parent.Parent.Parent.ClansFrame
local QuestFrame = ClansFrame.Internal.Quests
local ClanQuestConfig = require(ReplicatedStorage.Configs.ClanQuestsConfig)

local module = {}

module.conns = {}

local function createNewQuestTemplate(v:Folder)
	local Template = QuestFrame.MainContainer.ScrollingFrame.UIListLayout.TemplateContainer:Clone()

	Template.QuestImage.Image = v.QuestIcon.Value
	Template.LayoutOrder = v.QuestID.Value
	Template.QuestNameLabel.Text = v.QuestName.Value
	Template.DescriptionLabel.Text = v.Description.Value

	local cfg = ClanQuestConfig[v.ConfigID.Value]
	-- Scrolling Bar + Connection

	local conn = v:GetPropertyChangedSignal('Parent'):Connect(function()
		if not v.Parent then
			Template:Destroy()
		end
	end)

	table.insert(module.conns, conn)

	Template.LevelFrame.XpLabel.Text = v.Progress.Value..'/'..v.TotalAmount.Value
	Template.LevelFrame.FillFrame.Front.Size = UDim2.fromScale(tonumber(v.Progress.Value)/tonumber(v.TotalAmount.Value), 1)
	
	if cfg.Type == 'Playtime' then
		Template.LevelFrame.XpLabel.Text ..= ' Minutes'
	end
	

	local conn = v.Progress.Changed:Connect(function()
		Template.LevelFrame.XpLabel.Text = v.Progress.Value..'/'..v.TotalAmount.Value
		Template.LevelFrame.FillFrame.Front.Size = UDim2.fromScale(tonumber(v.Progress.Value)/tonumber(v.TotalAmount.Value), 1)
		if cfg.Type == 'Playtime' then
			Template.LevelFrame.XpLabel.Text ..= ' Minutes'
		end
	end)

	local Rewards = cfg.Rewards
	
	for i,v in Rewards do
		Template.RewardsContainer[v.Type].Container.Item_Contents.Unit_Value.Text = v.Amount
		Template.RewardsContainer[v.Type].Visible = true
	end
	

	

	table.insert(module.conns, conn)

	Template.Parent = QuestFrame.MainContainer.ScrollingFrame
end


function module.Init(clan)
	for i,v in module.conns do -- clear up any previous connections
		v:Disconnect()
		v = nil
	end
	
	for i,v:Frame in QuestFrame.MainContainer.ScrollingFrame:GetChildren() do
		if v:IsA('GuiBase2d') then
			v:Destroy()
		end
	end
	
	local foundClan = ReplicatedStorage.Clans:FindFirstChild(clan)
	
	if foundClan then
		-- found clan, lets load the quests
		
		--[[
		local questTemplate = {
			QuestID = 1,
			QuestName = '',
			Progress = 0,
			TotalAmount = 0,
			QuestIcon = '',
		}
		--]]
		
		for i,v:Folder in foundClan.Quests:GetChildren() do
			createNewQuestTemplate(v)
		end
		
		local conn = foundClan.Quests.ChildAdded:Connect(function(v)
			createNewQuestTemplate(v)
		end)
		
		table.insert(module.conns, conn)
	end
end


return module