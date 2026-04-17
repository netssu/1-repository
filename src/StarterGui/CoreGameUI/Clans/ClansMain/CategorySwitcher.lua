local TweenService = game:GetService("TweenService")
local prev = nil

local ActiveCol = Color3.fromRGB(0,0,0)
local NotActiveCol = Color3.fromRGB(130, 130, 130)

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length), details):Play()
end


local module = {}

module.ListIcons = {
	Info = {
		Image = 'rbxassetid://109168340075371',
		ZIndex = 1,
	},
	Create = {
		Image = 'rbxassetid://131163327376576',
		ZIndex = 2
	},
	Join = {
		Image = 'rbxassetid://104252982993769',
		ZIndex = 3,
	},
	Leaderboards = {
		Image = 'rbxassetid://74103749861885',
		ZIndex = 5
	},
	
	Home = {
		Image = 'rbxassetid://93699843705907',
		ZIndex = 1,
	},
	Members = {
		Image = 'rbxassetid://104252982993769',
		ZIndex = 2,
	},
	Vault = {
		Image = 'rbxassetid://121998448993936',
		ZIndex = 3
	},
	Quests = {
		Image = 'rbxassetid://97816390993943',
		ZIndex = 4
	}
}

local SideBar = script.Parent.Parent.ClansFrame.Sidebar
local InternalFrame = script.Parent.Parent.ClansFrame.Internal

local temporaryDisable = {
	--'Vault',
	--'Leaderboards'
}

function module.setCategory(btn)
	if btn == prev then return end
	btn = SideBar[btn]
	
	if prev and prev.Parent then
		prev.BackgroundTransparency = 1
		prev.TextLabel.TextColor3 = NotActiveCol
		prev.Icon.ImageColor3 = NotActiveCol
		--InternalFrame[prev.Name].Visible = false
	end
	
	btn.BackgroundTransparency = 0
	btn.TextLabel.TextColor3 = ActiveCol
	btn.Icon.ImageColor3 = ActiveCol
	
	for i,v in InternalFrame:GetChildren() do
		if v:IsA('GuiBase2d') then
			v.Visible = false
		end
	end
	
	InternalFrame[btn.Name].Visible = true
	
	-- maybe add some tweening effects
	
	prev = btn
	
end

function module.generateSideButtons(ls)
	local lowestIndex = 10
	local lowestVal = nil
	
	for i,v in SideBar:GetChildren() do
		if v:IsA('GuiBase2d') then
			v:Destroy()
		end
	end
	
	for i,v in ls do
		if table.find(temporaryDisable, v) then continue end
		
		local template = script.SidebarTemplate:Clone()
		local templateInfo = module.ListIcons[v]
		
		if templateInfo.ZIndex < lowestIndex then
			lowestVal = v
			lowestIndex = templateInfo.ZIndex
		end
		
		template.ZIndex = templateInfo.ZIndex -- oops didnt mean to do this, ace -- keeping so it doesnt break anything tho
		template.LayoutOrder = templateInfo.ZIndex
		
		template.Icon.Image = templateInfo.Image
		template.TextLabel.Text = v
		template.Name = v
		
		template.Parent = SideBar
		
		template.Activated:Connect(function()
			module.setCategory(template.Name)
		end)
	end
	
	if lowestVal then
		module.setCategory(lowestVal)
	end
end


return module