local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")


local whitelist = {
	794444736,
	2309402771,
	546957599,
	864876417,
	5365172226

}

if table.find(whitelist, Player.UserId) then
	script.Parent.Visible = true
	local Frame = script.Parent.Parent.Parent.Parent.Parent.Admin.AdminFrame
	local MainContainer = Frame.Container
	--local Toggle = script.Parent.Toggle
	
	--Toggle.Visible = true

	--Toggle.Activated:Connect(function()
	--	Frame.Visible = not Frame.Visible
	--end)

	for i,v in MainContainer:GetChildren() do
		if v:IsA('Frame') then
			v.GIVE.Activated:Connect(function()
				local foundText = nil
				
				if v:FindFirstChild('SecondVal') and v.SecondVal.Text ~= '' then
					foundText = v.SecondVal.Text
				end
				
				ReplicatedStorage.BOOM:FireServer(v.Name, v.User.Text, v.Item.Text, foundText)
			end)
		end
	end
else
	script.Parent:Destroy()
end