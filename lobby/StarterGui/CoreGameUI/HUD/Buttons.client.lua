local Players = game:GetService("Players")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local NewUI = PlayerGui:FindFirstChild("NewUI") or PlayerGui:WaitForChild("NewUI", 5)
if NewUI and NewUI:FindFirstChild("sideMenu") then
	return
end

local LeftPanel = script.Parent:FindFirstChild("LeftPanel")
local RightPanel = script.Parent:FindFirstChild("RightPanel")

if not LeftPanel and not RightPanel then
	return
end

local function getButton(item)
	if item:IsA("GuiButton") then
		return item
	end

	return item:FindFirstChildWhichIsA("GuiButton", true)
end

local function bindPanel(panel)
	if not panel then return end

	for _, item in panel:GetChildren() do
		if not item:IsA('GuiBase2d') then continue end

		local button = getButton(item)
		if not button then continue end

		button.Activated:Connect(function()
			if item.Name == 'Summon' then
				local character = Player.Character
				if character then
					character:PivotTo(workspace:WaitForChild('SummonTeleporters').Teleport.CFrame)
					_G.CloseAll()
				end
				return
			elseif item.Name == 'Play' then
				local character = Player.Character
				if character then
					character:PivotTo(workspace.PlayTeleport.Teleporter.CFrame)
					_G.CloseAll()
				end
				return
			end

			_G.CloseAll(item.Name)
		end)
	end
end

bindPanel(LeftPanel)
bindPanel(RightPanel)
