local Replicated = game:GetService("ReplicatedStorage")
local RaidsRefresh = Replicated.Remotes.RaidsRefresh
local Player = game:GetService("Players").LocalPlayer
local prompt = Player.PlayerGui.RaidGui.Raids:WaitForChild("PromptRaid")
local yes = prompt:WaitForChild("Vote_Skip"):WaitForChild("Contents"):WaitForChild("Options"):WaitForChild("Yes")
local no = prompt:WaitForChild("Vote_Skip"):WaitForChild("Contents"):WaitForChild("Options"):WaitForChild("No")
local debounce = false

print('raid refresh!')

RaidsRefresh.OnClientEvent:Connect(function()
	warn('RAID EVENT EXECUTED')
	prompt.Visible = true

	yes.Activated:Connect(function()
		if debounce then return end
		debounce = true
		prompt.Visible = false
		RaidsRefresh:FireServer(true)
		
		task.wait(1, function()
			debounce = false
		end)
	end)

	no.Activated:Connect(function()
		prompt.Visible = false
		RaidsRefresh:FireServer(false)
	end)
end)
