local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ClanRemotes = ReplicatedStorage.Remotes.Clans

local function tween(obj, length, details)
	TweenService:Create(obj, TweenInfo.new(length, Enum.EasingStyle.Linear), details):Play()
end

local ClansFrame = script.Parent.Parent.ClansFrame
local PromptFrame = ClansFrame.Prompt

local module = {}

local LoadingFrame = PromptFrame['Loading']

local loadingBits = {
	[1] = LoadingFrame['1'],
	[2] = LoadingFrame['2'],
	[3] = LoadingFrame['3']
}

local tasks = {}

local baseSize = loadingBits[1].Size 
local sizeMultiplier = 1.2

local prev = 3
local count = 1

local switchtime = 0.4
local ttime = 0.2


local function CreateSignal()
	local Signal = Instance.new('BindableEvent')

	Signal.Event:Connect(function()
		Signal:Destroy()
	end)

	return Signal
end



local promptFuncs = {
	['Loading'] = function()
		for i,v in loadingBits do -- reset all of them
			v.ImageTransparency = 0.5
			v.Size = baseSize
		end
		
		local thread = task.spawn(function()			
			local newval = UDim2.fromScale(baseSize.X.Scale * sizeMultiplier, baseSize.Y.Scale * sizeMultiplier)

			while true do
				for i,v in pairs(loadingBits) do
					tween(loadingBits[prev], ttime, {ImageTransparency = 0.5, Size = baseSize})
					tween(loadingBits[count], ttime, {ImageTransparency = 0, Size = newval})

					task.wait(switchtime)

					count += 1
					if count == 4 then
						count = 1
					end

					prev += 1
					if prev == 4 then
						prev = 1
					end
				end	
			end
		end)
		
		table.insert(tasks, thread)
	end,
}

local ConfirmationFuncs = {
	['Promote'] = function(UserId, Username, TargetRank)
		-- are you sure you would like to promote player
		PromptFrame['Confirmation'].TextBox.Text = `Are you sure you would like to promote {Username} to {TargetRank}?`
		
		local Option = 'Confirm'
		local Signal:BindableEvent = CreateSignal()
		local conn1, conn2 = nil,nil

		conn1 = PromptFrame['Confirmation'].Confirm.Activated:Connect(function()
			Signal:Fire()
		end)
		
		conn2 = PromptFrame['Confirmation'].Deny.Activated:Connect(function()
			Option = 'Deny'
			Signal:Fire()
		end)

		Signal.Event:Wait()
		
		conn1:Disconnect()
		conn2:Disconnect()
		conn1 = nil
		conn2 = nil
		
		if Option == 'Confirm' then
			-- promote
			module.disablePrompt()
			module.enablePrompt('Loading')
			local result = ClanRemotes.ModifyMember:InvokeServer(UserId, 'Promote')
			_G.Message(result)
			module.disablePrompt()
		else
			-- cancel
			module.disablePrompt()
		end
	end,
	['Demote'] = function(UserId, Username, TargetRank)
		PromptFrame['Confirmation'].TextBox.Text = `Are you sure you would like to demote {Username} to {TargetRank}?`

		local Option = 'Confirm'
		local Signal:BindableEvent = CreateSignal()
		local conn1, conn2 = nil,nil

		conn1 = PromptFrame['Confirmation'].Confirm.Activated:Connect(function()
			Signal:Fire()
		end)

		conn2 = PromptFrame['Confirmation'].Deny.Activated:Connect(function()
			Option = 'Deny'
			Signal:Fire()
		end)

		Signal.Event:Wait()

		conn1:Disconnect()
		conn2:Disconnect()
		conn1 = nil
		conn2 = nil

		if Option == 'Confirm' then
			-- promote
			module.disablePrompt()
			module.enablePrompt('Loading')
			local result = ClanRemotes.ModifyMember:InvokeServer(UserId, 'Demote')
			_G.Message(result)
			module.disablePrompt()
		else
			-- cancel
			module.disablePrompt()
		end
	end,
	['Kick'] = function(UserId, Username)
		PromptFrame['Confirmation'].TextBox.Text = `Are you sure you would like to kick {Username}?`

		local Option = 'Confirm'
		local Signal:BindableEvent = CreateSignal()
		local conn1, conn2 = nil,nil

		conn1 = PromptFrame['Confirmation'].Confirm.Activated:Connect(function()
			Signal:Fire()
		end)

		conn2 = PromptFrame['Confirmation'].Deny.Activated:Connect(function()
			Option = 'Deny'
			Signal:Fire()
		end)

		Signal.Event:Wait()

		conn1:Disconnect()
		conn2:Disconnect()
		conn1 = nil
		conn2 = nil

		if Option == 'Confirm' then
			-- promote
			module.disablePrompt()
			module.enablePrompt('Loading')
			local result = ClanRemotes.ModifyMember:InvokeServer(UserId, 'Kick')
			_G.Message(result)
			module.disablePrompt()
		else
			-- cancel
			module.disablePrompt()
		end
	end,
}


function module.enablePrompt(prompt, message, targetID, targetUser, targetRank)
	ClansFrame.Internal.Interactable = false
	PromptFrame[prompt].Visible = true
	
	if promptFuncs[prompt] then
		promptFuncs[prompt]()
	end
	if ConfirmationFuncs[message] and prompt == 'Confirmation' then
		PromptFrame.Visible = true
		ConfirmationFuncs[message](targetID, targetUser, targetRank) -- this yields
	else
		PromptFrame.Visible = true
	end
end

function module.disablePrompt()
	ClansFrame.Internal.Interactable = true
	for i, thread in tasks do
		task.cancel(thread)
		thread = nil
	end
	
	for i,v in PromptFrame:GetChildren() do
		v.Visible = false
	end
	
	PromptFrame.Visible = false
end


return module