local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local ClanRemotes = Remotes.Clans
local ClansFrame = script.Parent.Parent.ClansFrame
local Internal = ClansFrame.Internal
local ClanTags = require(ReplicatedStorage.ClansLib.ClanTags)
local PromptModule = require(script.Parent.PromptModule)

repeat task.wait() until ReplicatedStorage.ClanInvites:FindFirstChild(Player.UserId)

local module = {}

--local InvitesFrame = Internal.Join
local LocalInvitesFolder = ReplicatedStorage.ClanInvites:FindFirstChild(Player.UserId)
local JoinFrame = Internal.Join

local function sprint(msg)
	print(`[CLANSERVICE INVITE] {msg}`)
end

local function handleChild(obj)
	print(`[CLANSERVICE INVITING] FOUND AN INVITE FOR {obj.Name}`)
	local clanData = ReplicatedStorage.Clans[obj.Name]
	repeat task.wait() until clanData:FindFirstChild('Loaded')
	sprint('We have found the data sir')

	local template = JoinFrame.ScrollingFrame.UIListLayout._TemplateJoinFrame:Clone()

	template.Name = obj.Name

	template.Frame.ClanImage.Image = `rbxassetid://{clanData.Emblem.Value}`
	template.Frame.ClanName.Text = `[{obj.Name}]`
	template.Frame.ClanDescription.Text = clanData.Description.Value

	clanData.Description.Changed:Connect(function()
		template.Frame.ClanDescription.Text = clanData.Description.Value
	end)

	clanData.Emblem.Changed:Connect(function()
		template.Frame.ClanImage.Image = `rbxassetid://{clanData.Emblem.Value}`
	end)

	local function updateColor()
		local tagColor = ClanTags.Tags[clanData['ActiveColor'].Value].Color
		if typeof(tagColor) ~= 'table' then
			template.Frame.ClanName.TextColor3 = tagColor
			template.Frame.ClanName.UIGradient.Color = script.UIGradient.Color
		else
			local keypoints = {}
			local count = #tagColor
			for i, color in ipairs(tagColor) do
				local position = (i - 1) / (count - 1)
				table.insert(keypoints, ColorSequenceKeypoint.new(position, color))
			end
			local gradient = ColorSequence.new(keypoints)
			template.Frame.ClanName.TextColor3 = Color3.fromRGB(255,255,255)
			template.Frame.ClanName.UIGradient.Color = gradient			
		end
	end

	sprint('Updating the color sir')
	updateColor()

	local conn = clanData['ActiveColor'].Changed:Connect(updateColor)


	template.Frame.JoinButton.Activated:Connect(function()
		-- join clan
		PromptModule.disablePrompt()
		PromptModule.enablePrompt('Loading')
		local success = ClanRemotes.JoinClan:InvokeServer(clanData.Name)
		if success == 'Success' then
			template:Destroy()
		else
			_G.Message(success, Color3.fromRGB(255,100,100))
		end
		PromptModule.disablePrompt()
	end)

	sprint('Rodger dodger rodger')
	template.Parent = JoinFrame.ScrollingFrame


	local foundNoinvites = JoinFrame.ScrollingFrame:FindFirstChild('NoInvitesLabel')
	if foundNoinvites then
		foundNoinvites:Destroy()
	end
end

LocalInvitesFolder.ChildAdded:Connect(handleChild)
for i,v in LocalInvitesFolder:GetChildren() do
	handleChild(v)
end
print('[CLANSERVICE] PROCESSED INVITE LIB')


return module